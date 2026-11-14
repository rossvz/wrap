import fcntl
import http.server
import json
import os
from pathlib import Path
import subprocess
import tempfile
import threading
import unittest


SCRIPT = Path(__file__).resolve().parents[2] / "bin/auto-deploy-home"


class AutoDeployTest(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory()
        self.addCleanup(self.directory.cleanup)
        self.base = Path(self.directory.name)
        self.origin = self.base / "origin"
        self.root = self.base / "home"
        self.origin.mkdir()
        self.root.mkdir()
        self.git("init", "-b", "main")
        self.git("config", "user.name", "Deployment test")
        self.git("config", "user.email", "test@example.com")
        (self.origin / "bin").mkdir()
        start = self.origin / "bin/start-home"
        start.write_text('#!/bin/bash\nprintf started > "$WRAP_HOME_ROOT/started"\nexit "${WRAP_TEST_START_EXIT:-0}"\n')
        start.chmod(0o755)
        self.git("add", ".")
        self.git("commit", "-m", "Initial application")
        self.sha = self.git("rev-parse", "HEAD")
        self.runs = [{"head_sha": self.sha, "head_branch": "main", "event": "push", "status": "completed", "conclusion": "success"}]

        case = self

        class Handler(http.server.BaseHTTPRequestHandler):
            def do_GET(self):
                self.send_response(200)
                self.end_headers()
                self.wfile.write(json.dumps({"workflow_runs": case.runs}).encode())

            def log_message(self, *args):
                pass

        self.server = http.server.ThreadingHTTPServer(("127.0.0.1", 0), Handler)
        threading.Thread(target=self.server.serve_forever, daemon=True).start()
        self.addCleanup(self.server.server_close)
        self.addCleanup(self.server.shutdown)
        commands = self.base / "commands"
        commands.mkdir()
        docker = commands / "docker"
        docker.write_text('#!/bin/bash\nprintf build\\n >> "$WRAP_HOME_ROOT/builds"\n')
        docker.chmod(0o755)
        self.env = dict(os.environ, WRAP_HOME_ROOT=str(self.root), WRAP_GIT_REMOTE=str(self.origin),
                        WRAP_GITHUB_API_URL=f"http://127.0.0.1:{self.server.server_port}",
                        PATH=f"{commands}:{os.environ['PATH']}")

    def git(self, *args):
        return subprocess.check_output(["git", "-C", str(self.origin), *args], stderr=subprocess.DEVNULL, text=True).strip()

    def run_deployer(self):
        return subprocess.run(["python3", str(SCRIPT)], env=self.env, capture_output=True, text=True)

    def assert_not_deployed(self):
        result = self.run_deployer()
        self.assertEqual(0, result.returncode, result.stderr)
        self.assertFalse((self.root / "started").exists())
        self.assertFalse((self.root / "deployed-revision").exists())

    def test_deploys_the_exact_successful_main_commit_once(self):
        result = self.run_deployer()
        self.assertEqual(0, result.returncode, result.stderr)
        self.assertEqual(self.sha, (self.root / "deployed-revision").read_text().strip())
        self.assertTrue((self.root / "started").exists())
        before = (self.root / "builds").read_text()
        self.assertEqual(0, self.run_deployer().returncode)
        self.assertEqual(before, (self.root / "builds").read_text())

    def test_waits_for_a_ci_run(self):
        self.runs = []
        self.assert_not_deployed()

    def test_rejects_failed_or_pending_ci(self):
        for status, conclusion in [("in_progress", None), ("completed", "failure")]:
            with self.subTest(status=status):
                self.runs[0].update(status=status, conclusion=conclusion)
                self.assert_not_deployed()

    def test_rejects_ci_for_another_revision_branch_or_event(self):
        for field, value in [("head_sha", "0" * 40), ("head_branch", "feature"), ("event", "pull_request")]:
            with self.subTest(field=field):
                original = self.runs[0][field]
                self.runs[0][field] = value
                self.assert_not_deployed()
                self.runs[0][field] = original

    def test_uses_the_latest_run_instead_of_an_older_success(self):
        self.runs.insert(0, dict(self.runs[0], conclusion="failure"))
        self.assert_not_deployed()

    def test_does_not_record_a_deployment_when_startup_fails(self):
        self.env["WRAP_TEST_START_EXIT"] = "1"
        self.assertNotEqual(0, self.run_deployer().returncode)
        self.assertFalse((self.root / "deployed-revision").exists())

    def test_does_not_start_an_outdated_build(self):
        docker = self.base / "commands/docker"
        docker.write_text('#!/bin/bash\ngit -C "$WRAP_GIT_REMOTE" commit --allow-empty -m "New main commit"\n')
        self.assert_not_deployed()

    def test_skips_when_another_deployment_holds_the_lock(self):
        with (self.root / "deploy.lock").open("w") as lock:
            fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
            self.assert_not_deployed()


if __name__ == "__main__":
    unittest.main()

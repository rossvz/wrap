# Home deployment

Wrap runs on `pop-os` (the Linux Mac mini) at `https://wrap.rossvz.com`.
Tailscale provides SSH access; Cloudflare Tunnel provides public HTTPS without router port forwarding.

## Deploy

Merges and pushes to `main` deploy automatically after the **CI** workflow succeeds for that exact commit.
The mini checks every two minutes with `wrap-autodeploy.timer`. It fetches the public GitHub repository,
checks the latest push CI run for the current `main` SHA, builds locally, and runs the same health-checked
container replacement as a manual deploy. Failed or pending CI leaves the running app unchanged.
If `main` changes during a build, that build is skipped and the next check considers the newer commit.

This uses GitHub's public API and requires no GitHub token, Tailscale CI credentials, public webhook,
or GitHub runner on the home server. Pull requests do not deploy. The Mac does not need to be online.
Manual and automatic deployments share a lock to prevent concurrent builds and container replacements.

The managed checkout is `/home/rossvz/apps/wrap/auto-source`; do not edit it by hand.
The last successful deployment SHA is `/home/rossvz/apps/wrap/deployed-revision` and is also recorded
as the app container's `org.opencontainers.image.revision` label.

From this checkout on the Mac, run `bin/deploy-home`. This syncs source without databases or secrets,
builds the Docker image on the Linux server, and replaces the app container after saving a database snapshot.
If the health check fails, the script restores the previous container. Database migrations are not reversed.
The historical `config/deploy.yml` still describes the retired VPS; do not use it for this host.

The app container is `wrap-home`, listening only on `127.0.0.1:4081` on the server.
SQLite databases and uploaded files persist in the `wrap_home_storage` Docker volume.
Docker starts at boot and restarts the app automatically. The existing Gang deployment is separate.

Secrets live in `/home/rossvz/apps/wrap/production.env`, mode 600, outside the synced source.
They originate from the local Rails master key and the existing 1Password entries referenced in `.kamal/secrets`.
`APP_HOST=wrap.rossvz.com` sets email links. The sender is `noreply@wrap.rossvz.com`.
Resend verifies this domain through the records in `docs/email-dns-records.txt`, managed in Cloudflare DNS.

## Tunnel

The locally managed Cloudflare tunnel is `wrap-home` (`4f25e564-1aaf-4dd6-830a-52cc7cb79f5e`).
Its configuration and credentials are under `/home/rossvz/.cloudflared/`.
`wrap-tunnel.service` runs under the `rossvz` systemd user manager; lingering is enabled for boot startup.
Only the `wrap.rossvz.com` ingress routes to the app; other requests receive 404.

Useful commands:

```bash
tailscale ssh pop-os 'docker logs --tail 100 wrap-home'
tailscale ssh pop-os 'systemctl --user status wrap-tunnel'
tailscale ssh pop-os 'journalctl --user -u wrap-tunnel -n 50 --no-pager'
tailscale ssh pop-os 'curl -f http://127.0.0.1:4081/up'
tailscale ssh pop-os 'systemctl --user list-timers wrap-autodeploy.timer'
tailscale ssh pop-os 'journalctl --user -u wrap-autodeploy -n 50 --no-pager'
tailscale ssh pop-os 'cat ~/apps/wrap/deployed-revision'
```

To check for a deployment immediately, run:

```bash
tailscale ssh pop-os 'systemctl --user start wrap-autodeploy.service'
```

To pause automatic deployment, stop the timer with
`systemctl --user disable --now wrap-autodeploy.timer` on the server.
This does not interrupt a deployment already running; inspect `wrap-autodeploy.service` before maintenance.
The service and timer definitions are versioned in `config/home/`. They are installed under
`~/.config/systemd/user/` on the mini, with user lingering enabled for boot startup.

## Backups

On the server, `~/apps/wrap/source/bin/backup-home` writes a dated archive under `~/apps/wrap/backups`.
Each SQLite database uses SQLite's backup API; archives also contain uploaded files.
The `wrap-backup.timer` user timer takes a snapshot daily.

On this Mac, `bin/fetch-home-backups` takes a fresh snapshot and copies the server archives to
`~/Library/Application Support/Wrap/backups`. The `com.rossvz.wrap-backup` LaunchAgent runs this daily
while the Mac is available. Check its logs under `~/Library/Logs/Wrap/`.
Archives are retained until manually removed. They contain private user data; keep them protected.

To restore, stop the app, save the current volume, and extract the chosen archive into the storage volume
with ownership `1000:1000`. Start the app and verify `/up` and sign-in before allowing traffic.
Use the original Rails master key. Do not overwrite a running database or mix SQLite snapshots with old WAL files.

## Availability

Home power and Internet outages take the site offline. Cloudflare supplies the tunnel and edge TLS,
not the Rails process or database storage. No data has been recovered from the retired VPS by this setup.

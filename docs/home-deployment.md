# Home deployment

Wrap runs on `pop-os` (the Linux Mac mini) at `https://wrap.rossvz.com`.
Tailscale provides SSH access; Cloudflare Tunnel provides public HTTPS without router port forwarding.

## Deploy

From this checkout on the Mac, run `bin/deploy-home`. This syncs source without databases or secrets,
builds the Docker image on the Linux server, and replaces the app container after saving a database snapshot.
If the health check fails, the script restores the previous container. Database migrations are not reversed.
The historical `config/deploy.yml` still describes the retired VPS; do not use it for this host.

The app container is `wrap-home`, listening only on `127.0.0.1:4081` on the server.
SQLite databases and uploaded files persist in the `wrap_home_storage` Docker volume.
Docker starts at boot and restarts the app automatically. The existing Gang deployment is separate.

Secrets live in `/home/rossvz/apps/wrap/production.env`, mode 600, outside the synced source.
They originate from the local Rails master key and the existing 1Password entries referenced in `.kamal/secrets`.
`APP_HOST=wrap.rossvz.com` sets email links. The sender remains `noreply@wrap.rosscodes.com`,
whose existing Resend DNS verification is managed at Netlify. Keep those DNS records and that domain active.

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
```

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

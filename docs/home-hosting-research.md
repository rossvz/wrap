# Home hosting options

Verified against official documentation on November 14, 2026. These findings do not configure or publish any service.

## Recommendation

For family and friends who should only need a browser, run Wrap on the existing Linux Mac mini and use a **named Cloudflare Tunnel with a domain already owned by the user**. Keep Tailscale for SSH and administration. This is a recommendation based on the capabilities below, rather than a measured reliability comparison. Tunnel service can cost $0; domain renewal, electricity, email delivery, and backups are separate costs.

If a `*.ts.net` address is acceptable, **Tailscale Funnel is the simplest zero-domain-cost alternative**. It needs no Tailscale installation for visitors, but its beta status and unspecified bandwidth ceiling make Cloudflare the stronger long-term choice for a custom-domain site.

## Tailscale

- **Serve** exposes a local service only to the tailnet. Access-control rules apply. Friends need Tailscale access; it is useful for a private preview. [Serve documentation](https://tailscale.com/docs/features/tailscale-serve)
- The current free Personal plan permits **6 users**, unlimited user devices, and 50 tagged resources. Legacy plans can differ; inspect the existing account before assuming its allowance. These are tailnet membership limits, not public Funnel website visitor limits. [Pricing](https://tailscale.com/pricing), [free plans](https://tailscale.com/docs/account/manage-plans/free-plans-discounts)
- **Funnel** is available on every plan and lets anyone access a local web service without Tailscale. The docs still label it **beta**. It requires Tailscale 1.38.3+, MagicDNS, HTTPS certificates, and permission via the `funnel` node attribute. Its hostname must be under the tailnet's `*.ts.net` domain; it does not support an arbitrary custom domain. Public listening ports are 443, 8443, and 10000, and traffic must use TLS. Bandwidth limits are not configurable, and the docs do not give a numeric allowance. [Funnel documentation](https://tailscale.com/docs/features/tailscale-funnel)

## Cloudflare

- Tunnel is available on all plans and connects outbound from the home server without a public IP or inbound router port forwarding. Cloudflare's free-tunnel announcement explicitly says the tunnel connection is free; optional Smart Routing is a different paid feature. [Tunnel overview](https://developers.cloudflare.com/tunnel/), [free tunnel announcement](https://blog.cloudflare.com/tunnel-for-everyone)
- A persistent published application needs a Cloudflare account, **a domain on Cloudflare**, and `cloudflared` on a server with Internet access. It maps, for example, `wrap.example.com` to a local HTTP service. [Setup prerequisites](https://developers.cloudflare.com/tunnel/get-started/)
- Visitors open the hostname in an ordinary browser. Publishing does not require paid Cloudflare Access; Access seats apply if you add Access authentication policies. Wrap's own authentication still needs to function. [Published applications](https://developers.cloudflare.com/cloudflare-one/networks/connectors/cloudflare-tunnel/routing-to-tunnel/)
- Avoid an anonymous Quick Tunnel for ongoing hosting: its `trycloudflare.com` address is temporary, and Cloudflare explicitly directs production users to create a persistent tunnel. [Quick Tunnels](https://developers.cloudflare.com/tunnel/get-started/quick-tunnels/)

## Operational implications

These are architectural implications, not provider guarantees: home power or Internet outages take the app offline; a tunnel does not host the Rails process or persist its database. Run the app and tunnel under restart supervision, keep database/files outside disposable containers, and make automatic off-machine backups. Before publishing, verify Rails host/HTTPS proxy settings, outbound magic-link email and its public URL, and any original VPS database recovery needs. Do not assume an old VPS disk still exists.

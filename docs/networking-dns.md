# Local DNS And Network Plan

The stack provides local service FQDNs with CoreDNS and routes browser/API traffic through Caddy.

## Network

Docker bridge network:

```text
secnet: 10.77.0.0/24
gateway: 10.77.0.1
dns: 10.77.0.53
fqdn proxy: 10.77.0.80
```

The service FQDNs all resolve to the single proxy address `10.77.0.80`. Treat that proxy endpoint as the `/32` service target: `10.77.0.80/32`.

A Docker bridge network cannot use `10.77.0.80/32` as the whole subnet for this stack because `/32` contains only one usable address and this compose file runs many containers. The practical design is a small private subnet for container IPAM plus a single `/32` DNS target for human-facing service names.

The monitor-only `fqdn-proxy.hq-sec.local` target used by Uptime Kuma is an internal health check name, not a user-facing DNS entry. It is intentionally omitted from the public-facing FQDN table below.

## FQDNs

| FQDN | Route |
| --- | --- |
| `wazuh.hq-sec.local` | Wazuh Dashboard |
| `wazuh-api.hq-sec.local` | Wazuh Manager API |
| `wazuh-indexer.hq-sec.local` | Wazuh Indexer |
| `graylog.hq-sec.local` | Graylog UI/API |
| `thehive.hq-sec.local` | TheHive UI/API |
| `shuffle.hq-sec.local` | Shuffle frontend |
| `shuffle-api.hq-sec.local` | Shuffle backend |
| `velociraptor.hq-sec.local` | Velociraptor GUI |
| `greenbone.hq-sec.local` | Greenbone Security Assistant |
| `vault.hq-sec.local` | Vault UI/API |
| `uptime.hq-sec.local` | Uptime Kuma |
| `ghost.hq-sec.local` | The Ghost local LLM API |
| `reports.hq-sec.local` | Reports dashboard |

## Linux Host Resolver

Start DNS and the desired profiles:

```bash
docker compose -f security-stack.compose.yml --profile dns --profile brain up -d
```

Use CoreDNS directly:

```bash
dig @127.0.0.1 -p 1053 graylog.hq-sec.local
curl http://graylog.hq-sec.local
```

To make the host use this DNS zone through systemd-resolved:

```bash
sudo resolvectl dns docker0 10.77.0.53
sudo resolvectl domain docker0 '~hq-sec.local'
resolvectl query graylog.hq-sec.local
```

If `docker0` is not the bridge interface name on your host, replace it with the interface attached to `secnet`.

## Files

- `The Hands/CoreDNS/Corefile`: CoreDNS server and upstream forwarding.
- `The Hands/CoreDNS/hosts.hq-sec`: FQDN-to-proxy records.
- `The Hands/FQDN proxy - Caddy/Caddyfile`: HTTP virtual hosts and upstream service routes.


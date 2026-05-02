# Suricata Assessment With IPFire Disabled

## Recommendation

IPFire and host firewall artifacts are currently disabled and archived under `.disabled-services/`. Keep the Suricata container as the active IDS sensor only when it has a useful monitoring vantage point, such as a TAP, SPAN, mirrored switch port, or host interface that sees relevant traffic.

## What Suricata Does And Does Not Do

The Suricata container detects and logs suspicious traffic. It does not act as a routed firewall, NAT gateway, or default-deny enforcement point. With IPFire disabled, do not treat Suricata as inbound traffic control.

## Why Keep The Container

Suricata can still provide high-value detection when `${SENSOR_INTERFACE}` receives endpoint, Docker host, or internal east-west traffic. Zeek should remain paired with Suricata when possible because Zeek provides protocol metadata and timelines that make IDS alerts easier to investigate.

## Operational Modes

| Mode | Firewall artifacts | Suricata container | Use when |
| --- | --- | --- | --- |
| Sensor-only | Disabled | Enabled | Current active IDS mode when `${SENSOR_INTERFACE}` sees meaningful traffic |
| Visibility-only Zeek | Disabled | Disabled | Use Zeek only when Suricata traffic is duplicate, noisy, or not useful |
| No network profile | Disabled | Disabled | No TAP/SPAN/mirror interface is available |
| Archived edge firewall | Archived in `.disabled-services/` | Optional | Restore only if an edge firewall requirement returns |

## Default For This Stack

Run Docker `network` profile only after confirming the interface sees useful traffic:

```bash
ip link show ${SENSOR_INTERFACE:-eth0}
tcpdump -i ${SENSOR_INTERFACE:-eth0} -c 20
```

If the interface does not see useful traffic, do not start the `network` profile. Suricata should produce meaningful alerts, not noise or empty telemetry.

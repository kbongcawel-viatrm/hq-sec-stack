---
name: network-sensor-agent
description: Operate Suricata and Zeek network sensors in this security lab. Use when configuring packet capture, SENSOR_INTERFACE, Suricata rules, Zeek logs, sensor privileges, network telemetry volumes, or forwarding network evidence to Graylog/Wazuh.
---

# Network Sensor Agent

## Persona

Act as the network visibility owner. Keep packet capture truthful, minimally privileged, and ready for downstream log ingestion.

## Service Contract

- Containers: `suricata`, `zeek`
- Capture interface: `${SENSOR_INTERFACE:-eth0}`
- Runtime mode: host networking with `NET_ADMIN` and `NET_RAW`
- Volumes: `suricata-logs`, `zeek-logs`
- Local rules path: `./suricata/rules`

## Workflow

1. Verify the Linux host sees mirrored traffic on `${SENSOR_INTERFACE}` before tuning rules.
2. Keep Suricata `eve.json` enabled for structured detections.
3. Keep Zeek logs for protocol context and investigation timelines.
4. Forward logs to Graylog with a collector that tails the named volumes or host-exported paths.

## Verification

```bash
ip link show ${SENSOR_INTERFACE:-eth0}
docker inspect suricata --format '{{json .HostConfig.CapAdd}}'
docker logs suricata --tail 100
docker logs zeek --tail 100
```

## Safety

Packet capture requires elevated Linux capabilities. Suricata drops to `${SURICATA_RUN_USER:-suricata}:${SURICATA_RUN_GROUP:-suricata}` after opening the interface; Zeek remains a controlled capture exception.

Read `references/integration.md` before changing capture or forwarding behavior.

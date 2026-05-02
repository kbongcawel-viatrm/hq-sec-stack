# Restore Reference

Generic restore pattern:

```bash
docker compose -f security-stack.compose.yml --profile <profile> stop <service>
docker run --rm \
  -v hq-sec-stack_<volume-name>:/restore \
  -v ./backups:/backups:ro \
  -v ./backup/scripts:/backup/scripts:ro \
  alpine:3.20 \
  sh /backup/scripts/restore-volume.sh <volume-name> /backups/<timestamp>/<volume-name>.tar.gz
docker compose -f security-stack.compose.yml --profile <profile> start <service>
```

Check archive integrity first:

```bash
sha256sum -c backups/<timestamp>/SHA256SUMS
```

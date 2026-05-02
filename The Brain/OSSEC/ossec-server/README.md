# OSSEC Server Stack

This project runs the OSSEC manager in Docker inside the `CBL-Mariner` WSL 2 distro.

## Services

- `ossec-server`: `atomicorp/ossec-docker:v3.6`
- `postfix-relay`: `juanluisbaptiste/postfix:latest`

The relay container accepts unauthenticated local SMTP on port `25` inside the Docker network and forwards it to the configured upstream SMTP server.

## Configuration files

- Compose file: [D:/codex-workspace/ossec-server/docker-compose.yml](D:/codex-workspace/ossec-server/docker-compose.yml)
- Local env file: [D:/codex-workspace/ossec-server/.env](D:/codex-workspace/ossec-server/.env)
- Example env file: [D:/codex-workspace/ossec-server/.env.example](D:/codex-workspace/ossec-server/.env.example)
- WSL daily logging script: [D:/codex-workspace/ossec-server/scripts/run-ossec-daily-logs.sh](D:/codex-workspace/ossec-server/scripts/run-ossec-daily-logs.sh)

## Important mail settings

The active mail relay settings live in:

- [D:/codex-workspace/ossec-server/.env](D:/codex-workspace/ossec-server/.env)

The relay container forwards local SMTP from OSSEC to the upstream SMTP provider configured there.

## Start or refresh the stack

```powershell
cmd /c D:\codex-workspace\transfer-ossec-to-wsl.cmd
wsl --cd /opt/ossec-server -d CBL-Mariner -u root --exec /usr/bin/sh -c 'mkdir -p data && docker compose pull && docker compose up -d'
```

## Check status

```powershell
wsl --cd /opt/ossec-server -d CBL-Mariner -u root --exec /usr/bin/sh -c 'docker compose ps'
```

## Restart after config changes

```powershell
wsl --cd /opt/ossec-server -d CBL-Mariner -u root --exec /usr/bin/sh -c 'docker compose restart postfix-relay ossec-server'
```

## Notes

- The WSL transfer helper now preserves the live `data` directory.
- OSSEC manager data persists in `/opt/ossec-server/data` inside WSL.
- Daily summaries are configured through OSSEC's native `<reports>` support in `ossec.conf`.
- Daily monitoring log files are written inside WSL to `/var/logs/The Brain/OSSEC/` and copied to `D:\CBL-Mariner\ossec\` by the Windows wrapper/scheduled task.


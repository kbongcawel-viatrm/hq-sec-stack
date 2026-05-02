#!/usr/bin/sh
set -eu

LOG_ROOT="/var/logs/ossec"
DATE_STAMP="${DATE_STAMP:-$(date +%m%d%Y)}"
TS="${RUN_TS:-$(date '+%Y-%m-%d %H:%M:%S %z')}"

INTEGRITY_LOG="${LOG_ROOT}/integritycheck-${DATE_STAMP}.log"
TAILALERTS_LOG="${LOG_ROOT}/tailalerts-${DATE_STAMP}.log"
SYSCHECK_LOG="${LOG_ROOT}/syscheck-${DATE_STAMP}.log"

mkdir -p "${LOG_ROOT}"

{
  echo "=== ${TS} Trigger integrity scan for HOST-LAPTOP (agent 003) ==="
  docker exec ossec-server /bin/sh -lc "cd /var/ossec && ./bin/agent_control -r -u 003"
  echo
} >> "${INTEGRITY_LOG}" 2>&1

{
  echo "=== ${TS} Tail OSSEC alerts ==="
  if [ -f /opt/ossec-server/data/logs/alerts/alerts.log ]; then
    tail -n 200 /opt/ossec-server/data/logs/alerts/alerts.log
  else
    echo "alerts.log not found"
  fi
  echo
  if [ -f /opt/ossec-server/data/logs/alerts/alerts.json ]; then
    echo "=== alerts.json ==="
    tail -n 200 /opt/ossec-server/data/logs/alerts/alerts.json
  fi
  echo
} >> "${TAILALERTS_LOG}" 2>&1

{
  echo "=== ${TS} Syscheck changes for HOST-LAPTOP (agent 003) ==="
  docker exec ossec-server /bin/sh -lc "cd /var/ossec && ./bin/syscheck_control -i 003"
  echo
  echo "=== ${TS} Syscheck registry changes for HOST-LAPTOP (agent 003) ==="
  docker exec ossec-server /bin/sh -lc "cd /var/ossec && ./bin/syscheck_control -r -i 003"
  echo
} >> "${SYSCHECK_LOG}" 2>&1

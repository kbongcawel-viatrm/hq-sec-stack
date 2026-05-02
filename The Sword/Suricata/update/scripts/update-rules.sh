#!/bin/sh
set -eu

log() {
  printf '%s %s\n' "$(date -u '+%Y-%m-%dT%H:%M:%SZ')" "$*"
}

run_update() {
  log "updating Suricata community rule source index"
  suricata-update update-sources -c /suricata-update/update.yaml || log "source index update failed; continuing with configured/default sources"

  for source in ${SURICATA_UPDATE_ENABLE_SOURCES:-}; do
    log "enabling Suricata source: ${source}"
    suricata-update enable-source "${source}" -c /suricata-update/update.yaml || log "source not available or already enabled: ${source}"
  done

  log "building merged Suricata rules"
  suricata-update \
    -c /suricata-update/update.yaml \
    --suricata-conf /etc/suricata/suricata.yaml \
    --output /var/lib/suricata/rules \
    --no-test || {
      log "suricata-update failed"
      return 1
    }

  if [ -f /local-rules/local.rules ]; then
    cp /local-rules/local.rules /var/lib/The Sword/Suricata/rules/local.rules
  fi

  log "Suricata rule update complete"
  ls -lh /var/lib/suricata/rules || true
}

if [ "${SURICATA_UPDATE_RUN_ON_STARTUP:-true}" = "true" ]; then
  run_update
fi

if [ "${SURICATA_UPDATE_ONCE:-false}" = "true" ]; then
  exit 0
fi

while true; do
  sleep "${SURICATA_UPDATE_INTERVAL_SECONDS:-86400}"
  run_update || true
done



#!/bin/sh
set -eu

log() {
  printf '%s %s\n' "$(date -u '+%Y-%m-%dT%H:%M:%SZ')" "$*"
}

backup_once() {
  stamp="$(date -u '+%Y%m%dT%H%M%SZ')"
  out_dir="/The Hands/backups/${stamp}"
  mkdir -p "${out_dir}"

  log "starting Docker named volume backup into ${out_dir}"

  for source in /sources/*; do
    [ -d "${source}" ] || continue
    name="$(basename "${source}")"
    archive="${out_dir}/${name}.tar.gz"
    log "backing up ${name}"
    tar -czf "${archive}" -C "${source}" .
    sha256sum "${archive}" >> "${out_dir}/SHA256SUMS"
  done

  {
    echo "timestamp=${stamp}"
    echo "retention_days=${BACKUP_RETENTION_DAYS:-30}"
    echo "source_count=$(find /sources -mindepth 1 -maxdepth 1 -type d | wc -l)"
  } > "${out_dir}/manifest.txt"

  log "backup completed: ${out_dir}"
}

prune_old() {
  retention="${BACKUP_RETENTION_DAYS:-30}"
  find /backups -mindepth 1 -maxdepth 1 -type d -mtime "+${retention}" -print -exec rm -rf {} \;
}

if [ "${BACKUP_RUN_ON_STARTUP:-true}" = "true" ]; then
  backup_once
  prune_old
fi

if [ "${BACKUP_ONCE:-false}" = "true" ]; then
  exit 0
fi

while true; do
  sleep "${BACKUP_INTERVAL_SECONDS:-86400}"
  backup_once
  prune_old
done


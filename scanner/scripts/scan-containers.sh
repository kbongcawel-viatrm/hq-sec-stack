#!/bin/sh
set -eu

log() {
  printf '%s %s\n' "$(date -u '+%Y-%m-%dT%H:%M:%SZ')" "$*"
}

scan_once() {
  stamp="$(date -u '+%Y%m%dT%H%M%SZ')"
  out_dir="/reports/${stamp}"
  mkdir -p "${out_dir}"

  log "starting Trivy image scan"
  grep -Ev '^\s*($|#)' /scanner/targets.txt | sort -u > "${out_dir}/images.txt"

  if [ ! -s "${out_dir}/images.txt" ]; then
    log "no scanner targets found"
    return 0
  fi

  summary="${out_dir}/summary.md"
  {
    echo "# Container Vulnerability Scan ${stamp}"
    echo
    echo "| Image | JSON report | Table report |"
    echo "| --- | --- | --- |"
  } > "${summary}"

  while IFS= read -r image; do
    safe_name="$(printf '%s' "${image}" | tr '/:@' '___' | tr -c 'A-Za-z0-9_.-' '_')"
    json_report="${out_dir}/${safe_name}.json"
    table_report="${out_dir}/${safe_name}.txt"
    log "scanning ${image}"
    trivy image --quiet --cache-dir /root/.cache/trivy --severity "${TRIVY_SEVERITY:-HIGH,CRITICAL}" --format json --output "${json_report}" --exit-code 0 "${image}" || true
    trivy image --quiet --cache-dir /root/.cache/trivy --severity "${TRIVY_SEVERITY:-HIGH,CRITICAL}" --format table --output "${table_report}" --exit-code "${TRIVY_EXIT_CODE:-0}" "${image}" || true
    echo "| \`${image}\` | \`${json_report}\` | \`${table_report}\` |" >> "${summary}"
  done < "${out_dir}/images.txt"

  ln -sfn "${out_dir}" /reports/latest
  log "scan completed: ${out_dir}"
}

if [ "${TRIVY_RUN_ON_STARTUP:-true}" = "true" ]; then
  scan_once
fi

if [ "${TRIVY_SCAN_ONCE:-false}" = "true" ]; then
  exit 0
fi

while true; do
  sleep "${TRIVY_SCAN_INTERVAL_SECONDS:-86400}"
  scan_once
done

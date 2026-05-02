#!/bin/sh
set -eu

log() {
  printf '%s %s\n' "$(date -u '+%Y-%m-%dT%H:%M:%SZ')" "$*"
}

kv_mount="${VAULT_KV_MOUNT:-secret}"
manifest="${VAULT_SECRET_MANIFEST:-/The Shield/vault/secrets/service-secrets.tsv}"
state_dir="/vault/state"
state_file="${state_dir}/last-rotation-month"
check_seconds="${VAULT_ROTATION_CHECK_SECONDS:-21600}"
rotation_day="${VAULT_ROTATION_DAY:-1}"
run_on_startup="${VAULT_ROTATION_RUN_ON_STARTUP:-false}"

mkdir -p "${state_dir}"

if [ -z "${VAULT_TOKEN:-}" ]; then
  log "VAULT_TOKEN is empty; rotator will wait until VAULT_ROTATOR_TOKEN is supplied through .env."
fi

wait_for_vault() {
  until vault status >/dev/null 2>&1; do
    log "waiting for Vault API at ${VAULT_ADDR:-http://vault:8200}"
    sleep 10
  done
}

random_value() {
  vault write -field=random_bytes sys/tools/random/48 format=base64
}

write_secret() {
  name="$1"
  value="$2"
  vault kv put "${kv_mount}/hq-sec-stack/${name}" value="${value}" rotated_at="$(date -u '+%Y-%m-%dT%H:%M:%SZ')" >/dev/null
}

rotate() {
  log "starting monthly hq-sec-stack secret rotation"
  while IFS='	' read -r service path env_var generator description; do
    case "${service}" in
      ""|\#*) continue ;;
    esac
    case "${generator}" in
      random) write_secret "${path}" "$(random_value)" ;;
    esac
  done < "${manifest}"

  while IFS='	' read -r service path env_var generator description; do
    case "${service}" in
      ""|\#*) continue ;;
    esac
    case "${generator}" in
      sha256:*)
        source_path="${generator#sha256:}"
        source_value="$(vault kv get -field=value "${kv_mount}/hq-sec-stack/${source_path}")"
        hash_value="$(printf '%s' "${source_value}" | sha256sum | awk '{print $1}')"
        write_secret "${path}" "${hash_value}"
        ;;
    esac
  done < "${manifest}"
  date -u '+%Y-%m' > "${state_file}"
  log "secret rotation completed"
}

should_rotate_now() {
  month="$(date -u '+%Y-%m')"
  day="$(date -u '+%d' | sed 's/^0//')"
  last_month=""
  if [ -f "${state_file}" ]; then
    last_month="$(cat "${state_file}")"
  fi

  if [ "${run_on_startup}" = "true" ] && [ -z "${last_month}" ]; then
    return 0
  fi

  if [ "${day}" = "${rotation_day}" ] && [ "${last_month}" != "${month}" ]; then
    return 0
  fi

  return 1
}

wait_for_vault

while true; do
  if [ -n "${VAULT_TOKEN:-}" ]; then
    if should_rotate_now; then
      rotate || log "rotation failed; will retry on next check"
    else
      log "rotation not due"
    fi
  else
    log "VAULT_TOKEN unavailable; skipping rotation check"
  fi
  sleep "${check_seconds}"
done



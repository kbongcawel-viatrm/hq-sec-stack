#!/bin/sh
set -eu

kv_mount="${VAULT_KV_MOUNT:-secret}"
manifest="${VAULT_SECRET_MANIFEST:-/The Shield/vault/secrets/service-secrets.tsv}"

random_value() {
  vault write -field=random_bytes sys/tools/random/48 format=base64
}

put_secret() {
  name="$1"
  value="${2:-$(random_value)}"
  vault kv put "${kv_mount}/hq-sec-stack/${name}" value="${value}" seeded_at="$(date -u '+%Y-%m-%dT%H:%M:%SZ')" >/dev/null
  echo "seeded ${kv_mount}/hq-sec-stack/${name}"
}

vault status >/dev/null

while IFS='	' read -r service path env_var generator description; do
  case "${service}" in
    ""|\#*) continue ;;
  esac
  case "${generator}" in
    random) put_secret "${path}" ;;
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
      put_secret "${path}" "${hash_value}"
      ;;
  esac
done < "${manifest}"



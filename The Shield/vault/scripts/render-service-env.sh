#!/bin/sh
set -eu

output="${1:-.env.vault}"
kv_mount="${VAULT_KV_MOUNT:-secret}"
manifest="${VAULT_SECRET_MANIFEST:-The Shield/vault/secrets/service-secrets.tsv}"
tmp="${output}.tmp"

if [ ! -f "${manifest}" ] && [ -f "/The Shield/vault/secrets/service-secrets.tsv" ]; then
  manifest="/The Shield/vault/secrets/service-secrets.tsv"
fi

vault status >/dev/null

{
  echo "# Generated from Vault by The Shield/vault/scripts/render-service-env.sh."
  echo "# Do not commit this file."
  echo "# Generated at $(date -u '+%Y-%m-%dT%H:%M:%SZ')"
  while IFS='	' read -r service path env_var generator description; do
    case "${service}" in
      ""|\#*) continue ;;
    esac
    value="$(vault kv get -field=value "${kv_mount}/hq-sec-stack/${path}")"
    printf '%s=%s\n' "${env_var}" "${value}"
  done < "${manifest}"
} > "${tmp}"

chmod 600 "${tmp}"
mv "${tmp}" "${output}"
echo "rendered ${output} from Vault"



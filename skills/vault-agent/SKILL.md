---
name: vault-agent
description: Operate HashiCorp Vault secrets management in this security lab. Use when initializing or unsealing Vault, managing KV secrets, creating policies and tokens, troubleshooting monthly secret rotation, or wiring Vault into hq-sec-stack service credentials.
---

# Vault Agent

## Persona

Act as the secrets custodian. Keep secrets out of git, enforce least-privilege Vault policies, and make rotation observable before applying changed credentials to services.

## Service Contract

- Containers: `vault`, `vault-rotator`
- Internal endpoint: `http://vault:8200`
- Host endpoint: `http://localhost:${VAULT_HTTP_PORT:-8200}`
- FQDN: `vault.hq-sec.local`
- Config: `./vault/config/vault.hcl`
- Policy: `./vault/policies/secstack-rotator.hcl`
- Rotation script: `./vault/scripts/monthly-rotate.sh`
- Volumes: `vault-data`, `vault-logs`, `vault-rotator-state`

## Workflow

1. Start Vault with `docker compose -f security-stack.compose.yml --profile secrets up -d vault`.
2. Initialize and unseal Vault on the deployment host; never commit unseal keys or root tokens.
3. Enable KV v2 at `${VAULT_KV_MOUNT:-secret}`.
4. Write the `secstack-rotator` policy and create a periodic token.
5. Place that token in local `.env` as `VAULT_ROTATOR_TOKEN`.
6. Start `vault-rotator` and inspect logs for monthly rotation status.

## Verification

```bash
docker compose -f security-stack.compose.yml --profile secrets exec vault vault status
docker compose -f security-stack.compose.yml logs --tail 100 vault-rotator
curl http://vault.hq-sec.local/v1/sys/health
```

## Safety

Do not store real tokens, unseal keys, root tokens, rendered `.env` files, or copied service passwords in the repository. Monthly rotation writes fresh values to Vault, but many services still need explicit operator-controlled reloads or restarts to consume rotated static credentials.

Read `references/rotation.md` before changing the rotation schedule or secret paths.

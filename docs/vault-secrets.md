# Vault Secret Management

The repository does not commit real secret values. Generate and store runtime secrets on the deployment host after Vault is initialized and unsealed.

```bash
docker compose -f security-stack.compose.yml --profile secrets exec vault vault secrets enable -path=secret kv-v2
docker compose -f security-stack.compose.yml --profile secrets exec vault sh /vault/scripts/seed-stack-secrets.sh
```

The source of truth for service secret requirements is:

```text
The Shield/vault/secrets/service-secrets.tsv
```

Each row maps a service to a Vault path, environment variable, generator, and description. When a service or container is added, review whether it needs credentials, API keys, tokens, signing secrets, encryption keys, webhook secrets, or bootstrap passwords. If it does, add the needed rows to this manifest in the same change.

The seed and monthly rotation scripts write:

```text
secret/hq-sec-stack/graylog/password-secret
secret/hq-sec-stack/graylog/root-password
secret/hq-sec-stack/graylog/root-password-sha2
secret/hq-sec-stack/wazuh/dashboard-password
secret/hq-sec-stack/thehive/play-secret
secret/hq-sec-stack/shuffle/app-secret
secret/hq-sec-stack/greenbone/admin-password
secret/hq-sec-stack/velociraptor/admin-password
secret/hq-sec-stack/uptime-kuma/admin-password
```

Render Vault values into a local ignored Compose env file:

```bash
VAULT_ADDR=http://127.0.0.1:8200 VAULT_TOKEN=<operator-token> sh "The Shield/vault/scripts/render-service-env.sh" .env.vault
```

`scripts/start-stack.sh` automatically includes `.env.vault` when it exists, after `.env`, so Vault-rendered values override lab defaults. It also attempts to refresh `.env.vault` on startup when the Vault CLI and `VAULT_TOKEN` are available.

Applying rotated Vault values to long-running services still requires an operator-controlled restart or reload for services that only read credentials at startup.

Do not commit `.env.vault`, rendered `.env` files, Vault tokens, unseal keys, root tokens, or application passwords.



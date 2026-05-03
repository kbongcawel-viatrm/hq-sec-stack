# GitHub Actions Configuration

This repository uses `.github/workflows/build-deploy.yml` for validation and manual deployment.

## Required Repository Secrets

Create these in `Settings -> Secrets and variables -> Actions -> Secrets`.

| Name | Purpose |
| --- | --- |
| `DEPLOY_HOST` | SSH host for the deployment target. |
| `DEPLOY_USER` | SSH user for the deployment target. |
| `DEPLOY_SSH_KEY` | Private key used by the workflow SSH action. |
| `DEPLOY_PATH` | Absolute path to the checkout on the remote host. |
| `CADDY_CROWDSEC_API_KEY` | CrowdSec bouncer key injected into the Caddy container at deploy time. |

The workflow copies `.env.example` to `.env` and then injects `CADDY_CROWDSEC_API_KEY` from GitHub Secrets before running Compose.
Keep the example file free of GitHub expression syntax such as `${{ secrets.* }}` because Docker Compose reads `.env` as a plain environment file.

## Required Repository Variables

Create these in `Settings -> Secrets and variables -> Actions -> Variables`.

| Name | Purpose | Default |
| --- | --- | --- |
| `DEPLOY_PORT` | SSH port for the deployment host. | `22` |
| `SECSTACK_PROFILES` | Default compose profiles used by deploys. | `dns secrets brain ops` |

## Optional Workflow Dispatch Input

The manual workflow run accepts a `profiles` input. Use it when you want to test or deploy a narrower set of compose profiles without changing repository settings.

Examples:

```text
all
brain
dns secrets brain ops
```

## Test Run

Use the workflow dispatch run first when validating repo settings:

1. Open the workflow in GitHub Actions.
2. Run it manually.
3. Optionally set `profiles` to the profile set you want to test.
4. Confirm the validate job passes before enabling deployment.

The validate job runs `docker compose config`, checks shell syntax, and pulls the core images needed for the main stack profiles.

# Environments

Environment manifests live under:

- `environments/dev/services.yaml`
- `environments/stage/services.yaml`
- `environments/prod/services.yaml`

## What Each Manifest Controls

Each environment file declares:

- image tag
- desired count
- deployment strategy
- config profile

## Promotion Intent

The environment manifests are the deployable truth for each stage of rollout:

- `dev` for rapid iteration
- `stage` for release candidate validation
- `prod` for approved production state

## Why Keep This Separate

Separating deployment state from application repos makes:

- approvals clearer
- rollback easier
- audit history more explicit
- coordinated multi-service releases easier to reason about

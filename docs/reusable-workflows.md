# Reusable CI/CD workflows

All shared CI/CD lives in `raksha-deployments/.github/workflows/reusable-*.yml`.
Each consumer repo's `ci.yml` and `deploy.yml` is a thin caller that picks the
right reusable jobs and supplies inputs. Edit the **reusable** workflow to
change behaviour everywhere; edit the **caller** to change behaviour in one
repo.

## What's available

| File                            | Purpose                                          |
|---------------------------------|--------------------------------------------------|
| `reusable-rust-ci.yml`          | fmt + clippy + test for a Cargo workspace        |
| `reusable-go-ci.yml`            | fmt + vet + build + test for one Go module       |
| `reusable-pnpm-ci.yml`          | install + typecheck + test + build (optional Postgres) |
| `reusable-terraform.yml`        | fmt -check + init -backend=false + validate     |
| `reusable-docker-build.yml`     | build (and optionally push to ECR) one image    |
| `reusable-ecs-deploy.yml`       | terraform apply + force-new-deployment per service |

Each workflow is self-documenting (header comment shows usage).

## Caller pattern (consumer repo `ci.yml`)

```yaml
name: ci
on: [push, pull_request]

jobs:
  rust:
    uses: raksha-labs/raksha-deployments/.github/workflows/reusable-rust-ci.yml@main
    with:
      needs-contracts: true
    secrets:
      CROSS_REPO_READ_TOKEN: ${{ secrets.CROSS_REPO_READ_TOKEN }}

  terraform:
    uses: raksha-labs/raksha-deployments/.github/workflows/reusable-terraform.yml@main
    with:
      working-directory: infra/terraform

  image:
    uses: raksha-labs/raksha-deployments/.github/workflows/reusable-docker-build.yml@main
    with:
      image-name: raksha-rule-control-api
      dockerfile: raksha-engine/apps/rule-control-api/Dockerfile
      consumer-repo-name: raksha-engine
      checkout-contracts: true
    secrets:
      CROSS_REPO_READ_TOKEN: ${{ secrets.CROSS_REPO_READ_TOKEN }}
```

## Caller pattern (consumer repo `deploy.yml`)

Pass tag through to both build (push) and deploy. The deploy job skips
gracefully if any image build was skipped (`build_image=false` redeploys
an existing tag):

```yaml
name: Deploy <Project>
on:
  workflow_dispatch:
    inputs:
      environment: { type: choice, options: [dev, stage, prod] }
      image_tag:   { type: string, default: latest }
      build_image: { type: boolean, default: true }

jobs:
  image-foo:
    if: ${{ inputs.build_image == 'true' }}
    uses: raksha-labs/raksha-deployments/.github/workflows/reusable-docker-build.yml@main
    with:
      image-name: raksha-foo
      dockerfile: …
      push: true
      tag: ${{ inputs.image_tag }}
    secrets:
      CROSS_REPO_READ_TOKEN: ${{ secrets.CROSS_REPO_READ_TOKEN }}
      AWS_INFRA_ROLE_ARN:    ${{ secrets.AWS_INFRA_ROLE_ARN }}

  deploy:
    needs: [image-foo]
    if: always() && !contains(needs.*.result, 'failure')
    uses: raksha-labs/raksha-deployments/.github/workflows/reusable-ecs-deploy.yml@main
    with:
      project-name: raksha-foo
      environment: ${{ inputs.environment }}
      services: "foo"
      tf-vars: |
        image_tag=${{ inputs.image_tag }}
        vpc_id=${{ vars.RAKSHA_FOO_VPC_ID }}
    secrets:
      AWS_INFRA_ROLE_ARN:        ${{ secrets.AWS_INFRA_ROLE_ARN }}
      TF_BACKEND_BUCKET:         ${{ secrets.TF_BACKEND_BUCKET }}
      TF_BACKEND_DYNAMODB_TABLE: ${{ secrets.TF_BACKEND_DYNAMODB_TABLE }}
```

## Central rollout

Run `dispatch-deploy.yml` from this repo to roll an entire bounded context
(or every group) in catalog `rollout_order`. It triggers each owning repo's
`deploy.yml` via `gh workflow run`. Required:

- Secret `CROSS_REPO_DISPATCH_TOKEN` — a PAT with `actions:write` on each
  consumer repo (or use a GitHub App).
- Each consumer repo's `deploy.yml` must accept the standard three inputs:
  `environment`, `image_tag`, `build_image`.

Example: roll the **delivery** bounded context to `stage` with the current
sha — one click in the Actions UI of `raksha-deployments`.

Current deploy groups:

- `portal`
- `detection`
- `delivery`
- `ingestion`
- `simulation`
- `all`

## Ref selection

Consumers pin to `@main` by default. Switch to a release tag
(`@v1.0`) once the reusable workflows stabilise so that a breaking change
in `raksha-deployments/main` doesn't immediately ripple to every repo's CI.

## Required org secrets / vars

Wire these once at the org or repo level (Settings → Secrets and variables):

| Scope    | Name                              | Purpose                           |
|----------|-----------------------------------|-----------------------------------|
| secret   | `CROSS_REPO_READ_TOKEN`           | clone raksha-contracts / raksha-deployments |
| secret   | `CROSS_REPO_DISPATCH_TOKEN`       | bulk-trigger consumer deploys     |
| secret   | `AWS_INFRA_ROLE_ARN`              | OIDC role for ECR + ECS + TF      |
| secret   | `TF_BACKEND_BUCKET`               | tfstate S3 bucket                 |
| secret   | `TF_BACKEND_DYNAMODB_TABLE`       | tfstate lock table                |
| variable | `AWS_REGION`                      | default eu-west-1                 |
| variable | `RAKSHA_<PROJECT>_*`              | project-specific tf vars          |

### Required repo variables for manual `dev` deploys

The deploy workflows now derive shared network placement from the
foundation-infra compatibility SSM contract (`/raksha/<env>/core/...`).
You do not need to set raw VPC IDs, subnet IDs, or peer security-group IDs
in GitHub.

Portal (`raksha-portal`)

- `RAKSHA_PORTAL_ALB_ACM_CERT_ARN`
- `RAKSHA_PORTAL_BACKEND_STATIC_ENV`
- `RAKSHA_PORTAL_BACKEND_SECRET_ENV`
- `RAKSHA_PORTAL_STATIC_ENV`
- `RAKSHA_PORTAL_SECRET_ENV`
- `RAKSHA_ADMIN_STATIC_ENV`
- `RAKSHA_ADMIN_SECRET_ENV`
- `RAKSHA_ADMIN_ALLOWED_CIDR_BLOCKS` (`[]` to disable the IP gate, or a Terraform list like `["203.0.113.10/32"]`)

Detection (`raksha-engine`)

- `RAKSHA_ENGINE_STATIC_ENV`
- `RAKSHA_ENGINE_SECRET_ENV`
- `RAKSHA_RULE_CONTROL_STATIC_ENV`
- `RAKSHA_RULE_CONTROL_SECRET_ENV`

Delivery (`raksha-notifier-gateway`)

- `RAKSHA_NOTIFIER_STATIC_ENV`
- `RAKSHA_NOTIFIER_SECRET_ENV`
- `RAKSHA_ALERT_CONTROL_STATIC_ENV`
- `RAKSHA_ALERT_CONTROL_SECRET_ENV`

Ingestion (`raksha-ingestion-gateway`)

- `RAKSHA_INGESTION_STATIC_ENV`
- `RAKSHA_INGESTION_SECRET_ENV`
- `RAKSHA_STREAM_CONTROL_STATIC_ENV`
- `RAKSHA_STREAM_CONTROL_SECRET_ENV`

Simulation (`raksha-simlab`)

- `RAKSHA_SIMLAB_STATIC_ENV`
- `RAKSHA_SIMLAB_SECRET_ENV`

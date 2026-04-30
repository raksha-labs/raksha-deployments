# GitHub Setup

## Required Repository Settings

Configure these settings after creating the GitHub repository:

- default branch: `main`
- branch protection on `main`
- required pull request reviews
- required status checks for CI workflows
- GitHub Actions enabled
- GitHub Environments created for `dev`, `stage`, and `prod`

## Required Environments

Create these GitHub Environments:

- `dev`
- `stage`
- `prod`

Use protection rules for `stage` and `prod` so promotion PRs and any rollout workflows cannot bypass approval.

## Bulk Repo Variable Setup

Do not set the deploy repo variables one-by-one in the GitHub UI.

Use the checked-in example file:

- `config/github/repo-vars.dev.example.json`

Copy it to a local values file, fill in the real AWS IDs / JSON env maps, then run:

```bash
cp raksha-deployments/config/github/repo-vars.dev.example.json /tmp/raksha-github-vars.dev.json
$EDITOR /tmp/raksha-github-vars.dev.json

export GITHUB_TOKEN=...   # PAT or GitHub App user token with repo admin/actions variable permissions
python3 raksha-deployments/scripts/apply_github_repo_vars.py \
  --config /tmp/raksha-github-vars.dev.json \
  --apply
```

Dry-run first if you want to inspect what will change:

```bash
python3 raksha-deployments/scripts/apply_github_repo_vars.py \
  --config /tmp/raksha-github-vars.dev.json
```

What the script does:

- creates `dev`, `stage`, and `prod` GitHub environments for each listed repo
- upserts repo-level Actions variables through the GitHub REST API
- prints the small `required_secrets` checklist per repo

What you no longer need to set manually:

- VPC IDs
- private/public subnet IDs
- peer caller security-group IDs

Those are now derived by the service Terraform from the shared core/platform
AWS contract in SSM (`/raksha/<env>/core/...`).

What it does not do:

- it does not store or push secret values from the checked-in example file
- secrets such as `AWS_INFRA_ROLE_ARN`, `CROSS_REPO_READ_TOKEN`, and `CROSS_REPO_DISPATCH_TOKEN` should still be set in GitHub Secrets
- `TF_BACKEND_BUCKET` and `TF_BACKEND_DYNAMODB_TABLE` are tfstate **resource names**, not credentials — set them as repo/org **variables** (Settings → Secrets and variables → Actions → Variables), not secrets, so they show unmasked in CI logs and stay easy to debug

The intended flow is:

1. fill one local JSON file
2. run one script
3. set the few remaining secrets once

## Recommended Status Checks

Recommended required checks on `main`:

- `Manifest Validation`
- `Docs Build`

## Promotion Workflow

This repo includes a manual GitHub Action to create a promotion PR:

- workflow: `Promote Service`

Inputs:

- target environment
- service key
- image tag

The workflow updates the environment manifest and opens a PR automatically.

## CODEOWNERS

Update `.github/CODEOWNERS` to point to the real owning GitHub team before enabling mandatory review from code owners.

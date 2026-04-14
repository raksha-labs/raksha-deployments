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

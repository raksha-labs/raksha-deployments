# Raksha Deployments

This repository owns environment deployment state for Raksha.

It separates release promotion from service build pipelines:

- service repositories build, test, and publish artifacts
- this repository pins which versions are deployed to each environment

## Scope

This repository should own:

- per-environment image version or digest pinning
- desired replica counts by environment
- deployment strategy declarations
- rollout sequencing
- environment-specific config references

This repository should not own:

- application source code
- shared infrastructure provisioning
- service-specific CI logic

## Layout

```text
catalog/
  services.yaml
environments/
  dev/
  stage/
  prod/
docs/
  release-model.md
```

## Operating Model

Recommended promotion flow:

1. A service repo builds and publishes an image.
2. Automation or an engineer opens a PR in `raksha-deployments`.
3. The PR updates the target environment manifest.
4. Merge triggers deployment for that environment.
5. Promotion to higher environments repeats through reviewed manifest changes.

## Service CI Versus Deployment CD

Each service repo should still keep its own GitHub Actions for:

- tests
- lint
- security checks
- image publishing

This repository is the source of truth for environment deployment intent, not a replacement for service CI.

## Documentation

This repo has its own MkDocs site.

Run locally:

```bash
mkdocs serve
```

Build static output:

```bash
mkdocs build
```

## CI

GitHub Actions in this repo should run:

- `yamllint` on catalog and environment manifests
- manifest consistency validation
- `mkdocs build --strict`
- manual promotion PR creation for `dev`, `stage`, and `prod`

# Raksha Deployments

This documentation site describes the environment deployment repository for Raksha.

`raksha-deployments` is the reviewed source of truth for what runs in each environment.

## Scope

This repository owns:

- service image version or tag pinning
- desired replica counts by environment
- rollout strategy declarations
- promotion sequencing
- environment-specific config profile references

This repository does not own:

- application source code
- infrastructure provisioning
- service-local CI logic

## Reading Order

1. Read [Service Catalog](service-catalog.md).
2. Read [Environments](environments.md).
3. Read [Release Model](release-model.md).

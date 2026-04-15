# Release Model

## Purpose

This repository is the reviewed record of what is deployed in each environment.

## Flow

1. Service CI in `raksha-platform`, `raksha-ingestion-gateway`, `raksha-engine`, or `raksha-notifier-gateway` publishes an image.
2. A PR updates the matching `environments/<env>/services.yaml` file.
3. Review verifies:
   - image version
   - desired count changes
   - deployment strategy
   - config profile
4. Merge triggers the environment rollout.

## Promotion Rules

- `dev` can move quickly and frequently.
- `stage` should represent release-candidate state.
- `prod` should require explicit approval and rollback readiness.

## Rollout Ordering

The service catalog defines `rollout_order` so automation can sequence deployments consistently:

1. control-plane APIs
2. control-plane UIs
3. ingestion runtime
4. detection runtime
5. notification runtime

## Future Extension

This repository can later grow to include:

- image digests instead of tags
- canary percentages
- environment-specific health gates
- deployment freeze windows
- automated PR generation from service CI

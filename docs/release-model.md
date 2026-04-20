# Release Model

## Purpose

This repository is the reviewed record of what is deployed in each environment.

## Flow

1. Service CI in `raksha-portal`, `raksha-engine`, `raksha-notifier-gateway`, `raksha-ingestion-gateway`, or `raksha-simlab` publishes an image.
2. A PR updates the matching `environments/<env>/services.yaml` file.
3. Review verifies:
   - image version
   - desired count changes
   - deployment strategy
   - config profile
4. Merge updates the reviewed deployment manifest consumed by the deploy workflows.

## Promotion Rules

- `dev` can move quickly and frequently.
- `stage` should represent release-candidate state.
- `prod` should require explicit approval and rollback readiness.

## Rollout Ordering

The service catalog defines `rollout_order` so automation can sequence deployments consistently:

1. `portal-backend` (NestJS — entry point for portal/admin UIs)
2. `portal`, `admin` (Next.js UIs)
3. `rule-control-api`, then `engine` (detection context)
4. `alert-control-api`, then `notifier-runtime` (delivery context)
5. `stream-control-api`, then `ingestion-gateway` (ingestion context)
6. `simlab-api` (simulation context)

## Future Extension

This repository can later grow to include:

- image digests instead of tags
- canary percentages
- environment-specific health gates
- deployment freeze windows
- automated PR generation from service CI

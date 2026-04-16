# Service Catalog

The service catalog lives in:

- `catalog/services.yaml`

It defines deployment metadata shared across environments, including:

- canonical service name
- source repository
- image repository
- deployment group
- rollout order
- default deployment strategy

## Current Services

The catalog covers the four bounded-context deploy groups:

| deploy_group | Services |
|---|---|
| `portal` | `portal-backend` (NestJS), `portal` (Next.js customer UI), `admin` (Next.js ops UI) — all from `raksha-portal/apps/*` |
| `detection` | `rule-control-api` (Go), `engine` (Rust) — from `raksha-engine/apps/*` |
| `delivery` | `alert-control-api` (Go), `notifier-runtime` (Rust) — from `raksha-notifier-gateway/apps/*` |
| `ingestion` | `stream-control-api` (Go), `ingestion-gateway` (Rust) — from `raksha-ingestion-gateway/apps/*` |

## Purpose

The catalog gives deployment automation one stable description of:

- what services exist
- where their artifacts come from
- how they should be sequenced

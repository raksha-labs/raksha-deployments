# Raksha Local Stack

One-command bring-up of the full system: portal + admin UIs, control-plane backend + gRPC, engine, event-gateway, notifier-gateway, plus Postgres, Redis, and MinIO. Lives alongside the other environment deployments at `raksha-deployments/environments/local/`.

```bash
cd raksha-deployments/environments/local
./stack           # build + start + wait for healthy
./stack logs      # follow logs
./stack status    # re-check health
./stack down      # stop (keep volumes)
./stack reset     # stop + wipe volumes (fresh DB)
```

## Endpoints after startup

| Service | URL |
|---|---|
| **Portal (user UI)** | http://localhost:3000 |
| **Admin (ops UI)** | http://localhost:3002 |
| control-plane REST | http://localhost:3001 |
| control-plane Swagger | http://localhost:3001/v1/openapi |
| control-plane gRPC | `localhost:50051` |
| event-gateway health | http://localhost:8080/health |
| event-gateway metrics | http://localhost:9092/metrics |
| notifier-gateway health | http://localhost:8082/health |
| notifier-gateway metrics | http://localhost:9093/metrics |
| engine metrics | http://localhost:9091/metrics |
| MinIO console | http://localhost:9001 (raksha / rakshadevsecret) |
| Postgres | `localhost:5432` (raksha / raksha) |
| Redis | `localhost:6379` |

## Databases

One shared Postgres instance, four databases auto-created and schema-loaded at first boot:

| Database | Owner | Schemas |
|---|---|---|
| `raksha_control` | control-plane | `tenants`, `iam`, `catalog`, `patterns`, `publications`, `notifications`, `runtime`, `audit` |
| `raksha_gateway` | event-gateway | `gateway_checkpoints`, `stream_leases`, `source_health_status`, `ingest_failures` |
| `raksha_gateway_raw` | event-gateway raw landing | `source_envelopes` (24h hot tier) |
| `raksha_notifier` | notifier-gateway | delivery_log, dead_letter, etc. |

Schemas are bind-mounted from each service repo — no copies.

## S3 archive

`event-gateway` is configured to archive envelopes to `s3://raksha-events/events/...` via MinIO. A 7-day lifecycle rule is applied automatically by the `minio-init` one-shot container.

## First-run cost

- Rust service builds (~5 minutes each, cached afterwards)
- Control-plane build (~2 minutes)
- Pulled images (Postgres/Redis/MinIO): ~1 minute
- Total cold-start: ~15 minutes
- Warm start: ~30 seconds

## Troubleshooting

**Postgres init failed**  
`./stack reset` and retry — the init scripts only run on an empty data volume.

**Rust build fails with `raksha-contracts not found`**  
Build contexts use `../../..` (raksha-labs/) so the Cargo path deps resolve. If the stack can't find a repo, you've got a sibling dir missing.

**event-gateway panics on startup with S3 error**  
Check MinIO is healthy (`./stack status`). If `archive.enabled=true` in `configs/event-gateway.toml` the bucket must exist.

**Service shows unhealthy forever**  
`./stack logs` — most common cause is a schema load failure on first DB init. `./stack reset` to rebuild.

## What this is *not*

- Not a production deployment — see `raksha-foundation-infra` and `raksha-deployments` for that.
- Not multi-tenant — one seed tenant UUID is baked in (`00000000-0000-0000-0000-000000000001`).
- Not HA — single instance per service, no replication.

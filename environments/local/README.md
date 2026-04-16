# Raksha Local Stack

One-command bring-up of the full bounded-context system: portal + admin UIs, the portal/backend NestJS API, the two Go control-APIs (rule-control-api + alert-control-api), the three Rust runtimes (engine, notifier-runtime, ingestion-gateway), plus Postgres, Redis, and MinIO. Lives at `raksha-deployments/environments/local/`.

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
| portal-backend REST | http://localhost:3001 |
| portal-backend Swagger | http://localhost:3001/v1/openapi |
| rule-control-api (detection CRUD) | http://localhost:8085 |
| alert-control-api (delivery CRUD) | http://localhost:8086 |
| ingestion-gateway health | http://localhost:8080/health |
| ingestion-gateway metrics | http://localhost:9092/metrics |
| notifier-runtime health | http://localhost:8082/health |
| notifier-runtime metrics | http://localhost:9093/metrics |
| engine metrics | http://localhost:9091/metrics |
| MinIO console | http://localhost:9001 (raksha / rakshadevsecret) |
| Postgres | `localhost:5432` (raksha / raksha) |
| Redis | `localhost:6379` |

## Databases

One shared Postgres instance, four databases auto-created and schema-loaded at first boot. Each repo's schema lives in that repo and is bind-mounted read-only into postgres at boot — no copies.

| Database | Owner repo | Owns schemas |
|---|---|---|
| `raksha_portal` | raksha-portal/apps/backend (NestJS) | `iam`, `tenants`, `catalog`, `notifications`, `inbox`, `audit`, `billing` |
| `raksha_engine` | raksha-engine/apps/rule-control-api (Go) | `engine.*` (patterns, drafts, versions, snapshots, rule_health, risk_scores) |
| `raksha_notifier` | raksha-notifier-gateway/apps/alert-control-api (Go) | `alerts.*`, `notifier.*` (occurrences, events, receivers, routes, delivery_attempts, receiver_health, snapshots) |
| `raksha_gateway` | raksha-ingestion-gateway/apps/ingestion-gateway (Rust) | gateway runtime tables |

## Peer auth tokens

Every cross-repo HTTP call uses a single env-var bearer token:

| Caller → Callee | Token env on caller | Token env on callee |
|---|---|---|
| portal-backend → rule-control-api | `PEER_TOKEN_ENGINE` | `RULE_CONTROL_INTERNAL_PEER_TOKEN` |
| portal-backend → alert-control-api | `PEER_TOKEN_NOTIFIER_GATEWAY` | `ALERT_CONTROL_INTERNAL_PEER_TOKEN` |
| engine → rule-control-api | `RAKSHA_CONFIG_SOURCE__PEER_TOKEN` | `RULE_CONTROL_INTERNAL_PEER_TOKEN` |
| notifier-runtime → alert-control-api | `ALERT_CONTROL_PEER_TOKEN` | `ALERT_CONTROL_INTERNAL_PEER_TOKEN` |

Local-stack uses fixed dev tokens (`dev-peer-token-engine`, `dev-peer-token-notifier-gateway`) wired through compose env so all sides match. **Never reuse in staging/prod.**

## Event flow (live in this stack)

```
ingestion-gateway → redis:events.* → engine
                                     ↓ compiles DSL via long-poll snapshots from rule-control-api
                                     ↓ matches → emits alerts
                                  redis:alerts.outbound → notifier-runtime
                                                          ↓ POSTs to alert-control-api
                                                          ↓ resolves receivers via long-poll snapshot
                                                          ↓ dispatches to channels
```

Every config change in the portal UI flows: **portal → portal-backend → rule-control-api / alert-control-api → snapshot rebuild → pg_notify → runtime long-poll wakes → ArcSwap apply** in under a second.

## S3 archive

`ingestion-gateway` archives envelopes to `s3://raksha-events/events/...` via MinIO with a 7-day lifecycle rule (created automatically by the `minio-init` one-shot container).

## First-run cost

- Rust service builds (~5 minutes each, cached afterwards): engine, notifier-runtime, ingestion-gateway
- Go service builds (~30 seconds each): rule-control-api, alert-control-api
- portal-backend NestJS build (~2 minutes), portal + admin Next.js (~1 minute each)
- Pulled images (Postgres/Redis/MinIO): ~1 minute
- **Total cold-start: ~20 minutes. Warm start: ~30 seconds.**

## Troubleshooting

**Postgres init failed**  
`./stack reset` and retry — the init scripts only run on an empty data volume.

**Rust build fails with `raksha-contracts not found`**  
Build contexts use `../../..` (raksha-labs/) for engine + notifier-runtime so the Cargo `path = "../raksha-contracts"` resolves. If the stack can't find a repo, a sibling dir is missing.

**rule-control-api or alert-control-api unhealthy**  
`./stack logs rule-control-api` (or `alert-control-api`). Most common cause: the Postgres bootstrap didn't finish before the Go service tried to query its DB. `./stack reset` to redo init in order.

**Engine never applies a snapshot**  
Check the engine logs for `applied config snapshot version N`. If you only see the startup message, rule-control-api hasn't returned a tenant snapshot yet — create a pattern via the portal first, or POST one directly to `http://localhost:8085/v1/tenants/{tid}/patterns` with the `dev-peer-token-engine` bearer.

**Notifier-runtime never delivers an alert**  
Check `notifier-runtime` logs. Most common: no receiver+route configured for the tenant. POST a receiver via `http://localhost:8086/v1/tenants/{tid}/receivers` and a route at `http://localhost:8086/v1/tenants/{tid}/routes`.

## What this is *not*

- Not a production deployment — see `raksha-foundation-infra` and the per-repo terraform for that.
- Not multi-tenant — one seed tenant UUID is baked in (`00000000-0000-0000-0000-000000000001`).
- Not HA — single instance per service, no replication.

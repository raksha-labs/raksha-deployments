#!/bin/bash
# Postgres bootstrap for the local-stack. Runs inside the postgres container
# on first init. Creates the per-context databases and loads each context's
# schema into its own database.
#
# Each repo bind-mounts its schema read-only under /schemas/<context>/.
#
# Order:
#   1. raksha_portal   — platform (NestJS backend) — /schemas/portal/*.sql
#   2. raksha_engine   — detection                 — /schemas/engine/schema.sql
#   3. raksha_notifier — delivery                  — /schemas/notifier/schema.sql
#   4. raksha_gateway  — ingestion (control + ops) — /schemas/gateway-control/schema.sql
#                                                     /schemas/gateway/schema.sql
#   5. raksha_simlab   — simulation                — /schemas/simlab/schema.sql

set -euo pipefail

psql_cmd() {
  PGOPTIONS="--client-min-messages=warning" \
    psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" "$@"
}

create_db() {
  local dbname="$1"
  echo "[bootstrap] creating database $dbname"
  psql_cmd -d postgres -c "CREATE DATABASE \"$dbname\" OWNER \"$POSTGRES_USER\";"
}

load_schema_dir() {
  local dbname="$1"
  local dir="$2"
  if [ ! -d "$dir" ]; then
    echo "[bootstrap] skip: $dir not mounted"
    return
  fi
  for f in $(ls -1 "$dir" | sort); do
    case "$f" in
      *.sql)
        echo "[bootstrap] loading $dir/$f into $dbname"
        psql_cmd -d "$dbname" -f "$dir/$f"
        ;;
    esac
  done
}

load_schema_file() {
  local dbname="$1"
  local file="$2"
  if [ ! -f "$file" ]; then
    echo "[bootstrap] skip: $file not mounted"
    return
  fi
  echo "[bootstrap] loading $file into $dbname"
  psql_cmd -d "$dbname" -f "$file"
}

# raksha_portal already exists (POSTGRES_DB).
load_schema_dir "$POSTGRES_DB" "/schemas/portal"

create_db "raksha_engine"
load_schema_file "raksha_engine" "/schemas/engine/schema.sql"

create_db "raksha_notifier"
load_schema_file "raksha_notifier" "/schemas/notifier/schema.sql"

create_db "raksha_gateway"
load_schema_file "raksha_gateway" "/schemas/gateway-control/schema.sql"
load_schema_file "raksha_gateway" "/schemas/gateway/schema.sql"

create_db "raksha_simlab"
load_schema_file "raksha_simlab" "/schemas/simlab/schema.sql"

create_db "raksha_ai"
load_schema_file "raksha_ai" "/schemas/ai/0001_init.sql"
load_schema_file "raksha_ai" "/schemas/ai/0002_alert_briefs.sql"
load_schema_file "raksha_ai" "/schemas/ai/0003_model_catalog.sql"
load_schema_file "raksha_ai" "/schemas/ai/0004_prompt_overrides.sql"
load_schema_file "raksha_ai" "/schemas/ai/seed_dev.sql"

create_db "raksha_risk_monitor"
load_schema_file "raksha_risk_monitor" "/schemas/risk-monitor/schema.sql"

echo "[bootstrap] all databases initialized"

# ---------------------------------------------------------------------------
# Per-service Postgres roles (defence in depth — mirrors prod intention)
#
# Each service role has CONNECT on its own database and full DML on the
# schemas it owns (per CLAUDE.md ownership map). The superuser `raksha`
# remains available for migrations and bootstrapping — service env vars in
# docker-compose.yml can keep using `raksha` for now; these roles are prep
# work for a future prod migration.
# ---------------------------------------------------------------------------

# rule_control_api → raksha_engine (engine.* schema)
psql_cmd -d postgres -c "CREATE ROLE rule_control_api LOGIN PASSWORD 'raksha' NOSUPERUSER NOCREATEDB NOCREATEROLE;" 2>/dev/null || true
psql_cmd -d postgres -c "GRANT CONNECT ON DATABASE raksha_engine TO rule_control_api;" 2>/dev/null || true
psql_cmd -d raksha_engine -c "GRANT USAGE ON SCHEMA engine TO rule_control_api;" 2>/dev/null || true
psql_cmd -d raksha_engine -c "GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA engine TO rule_control_api;" 2>/dev/null || true
psql_cmd -d raksha_engine -c "ALTER DEFAULT PRIVILEGES IN SCHEMA engine GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO rule_control_api;" 2>/dev/null || true
psql_cmd -d raksha_engine -c "GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA engine TO rule_control_api;" 2>/dev/null || true
psql_cmd -d raksha_engine -c "ALTER DEFAULT PRIVILEGES IN SCHEMA engine GRANT USAGE, SELECT ON SEQUENCES TO rule_control_api;" 2>/dev/null || true

# stream_control_api → raksha_gateway (control.* schema)
psql_cmd -d postgres -c "CREATE ROLE stream_control_api LOGIN PASSWORD 'raksha' NOSUPERUSER NOCREATEDB NOCREATEROLE;" 2>/dev/null || true
psql_cmd -d postgres -c "GRANT CONNECT ON DATABASE raksha_gateway TO stream_control_api;" 2>/dev/null || true
psql_cmd -d raksha_gateway -c "GRANT USAGE ON SCHEMA control TO stream_control_api;" 2>/dev/null || true
psql_cmd -d raksha_gateway -c "GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA control TO stream_control_api;" 2>/dev/null || true
psql_cmd -d raksha_gateway -c "ALTER DEFAULT PRIVILEGES IN SCHEMA control GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO stream_control_api;" 2>/dev/null || true
psql_cmd -d raksha_gateway -c "GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA control TO stream_control_api;" 2>/dev/null || true
psql_cmd -d raksha_gateway -c "ALTER DEFAULT PRIVILEGES IN SCHEMA control GRANT USAGE, SELECT ON SEQUENCES TO stream_control_api;" 2>/dev/null || true

# alert_control_api → raksha_notifier (alerts.* + notifier.* schemas)
psql_cmd -d postgres -c "CREATE ROLE alert_control_api LOGIN PASSWORD 'raksha' NOSUPERUSER NOCREATEDB NOCREATEROLE;" 2>/dev/null || true
psql_cmd -d postgres -c "GRANT CONNECT ON DATABASE raksha_notifier TO alert_control_api;" 2>/dev/null || true
psql_cmd -d raksha_notifier -c "GRANT USAGE ON SCHEMA alerts TO alert_control_api;" 2>/dev/null || true
psql_cmd -d raksha_notifier -c "GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA alerts TO alert_control_api;" 2>/dev/null || true
psql_cmd -d raksha_notifier -c "ALTER DEFAULT PRIVILEGES IN SCHEMA alerts GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO alert_control_api;" 2>/dev/null || true
psql_cmd -d raksha_notifier -c "GRANT USAGE ON SCHEMA notifier TO alert_control_api;" 2>/dev/null || true
psql_cmd -d raksha_notifier -c "GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA notifier TO alert_control_api;" 2>/dev/null || true
psql_cmd -d raksha_notifier -c "ALTER DEFAULT PRIVILEGES IN SCHEMA notifier GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO alert_control_api;" 2>/dev/null || true
psql_cmd -d raksha_notifier -c "GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA alerts TO alert_control_api;" 2>/dev/null || true
psql_cmd -d raksha_notifier -c "GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA notifier TO alert_control_api;" 2>/dev/null || true
psql_cmd -d raksha_notifier -c "ALTER DEFAULT PRIVILEGES IN SCHEMA alerts GRANT USAGE, SELECT ON SEQUENCES TO alert_control_api;" 2>/dev/null || true
psql_cmd -d raksha_notifier -c "ALTER DEFAULT PRIVILEGES IN SCHEMA notifier GRANT USAGE, SELECT ON SEQUENCES TO alert_control_api;" 2>/dev/null || true

# simlab_api → raksha_simlab (simlab.* schema)
psql_cmd -d postgres -c "CREATE ROLE simlab_api LOGIN PASSWORD 'raksha' NOSUPERUSER NOCREATEDB NOCREATEROLE;" 2>/dev/null || true
psql_cmd -d postgres -c "GRANT CONNECT ON DATABASE raksha_simlab TO simlab_api;" 2>/dev/null || true
psql_cmd -d raksha_simlab -c "GRANT USAGE ON SCHEMA simlab TO simlab_api;" 2>/dev/null || true
psql_cmd -d raksha_simlab -c "GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA simlab TO simlab_api;" 2>/dev/null || true
psql_cmd -d raksha_simlab -c "ALTER DEFAULT PRIVILEGES IN SCHEMA simlab GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO simlab_api;" 2>/dev/null || true
psql_cmd -d raksha_simlab -c "GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA simlab TO simlab_api;" 2>/dev/null || true
psql_cmd -d raksha_simlab -c "ALTER DEFAULT PRIVILEGES IN SCHEMA simlab GRANT USAGE, SELECT ON SEQUENCES TO simlab_api;" 2>/dev/null || true

# portal_backend → raksha_portal (iam.*, tenants.*, audit.*, billing.*, inbox.* schemas)
psql_cmd -d postgres -c "CREATE ROLE portal_backend LOGIN PASSWORD 'raksha' NOSUPERUSER NOCREATEDB NOCREATEROLE;" 2>/dev/null || true
psql_cmd -d postgres -c "GRANT CONNECT ON DATABASE raksha_portal TO portal_backend;" 2>/dev/null || true
for schema in iam tenants audit billing inbox ops; do
  psql_cmd -d raksha_portal -c "GRANT USAGE ON SCHEMA ${schema} TO portal_backend;" 2>/dev/null || true
  psql_cmd -d raksha_portal -c "GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA ${schema} TO portal_backend;" 2>/dev/null || true
  psql_cmd -d raksha_portal -c "ALTER DEFAULT PRIVILEGES IN SCHEMA ${schema} GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO portal_backend;" 2>/dev/null || true
  psql_cmd -d raksha_portal -c "GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA ${schema} TO portal_backend;" 2>/dev/null || true
  psql_cmd -d raksha_portal -c "ALTER DEFAULT PRIVILEGES IN SCHEMA ${schema} GRANT USAGE, SELECT ON SEQUENCES TO portal_backend;" 2>/dev/null || true
done

echo "[bootstrap] per-service roles created"

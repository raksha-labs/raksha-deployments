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
#   4. raksha_gateway  — ingestion                 — /schemas/gateway/schema.sql
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

# Raw-envelope landing DB: same schema, separate database so hot-tier
# retention (7d in local) can be wiped without touching gateway metadata.
create_db "raksha_gateway_raw"
load_schema_file "raksha_gateway_raw" "/schemas/gateway/schema.sql"

create_db "raksha_simlab"
load_schema_file "raksha_simlab" "/schemas/simlab/schema.sql"

create_db "raksha_ai"
load_schema_file "raksha_ai" "/schemas/ai/0001_init.sql"
load_schema_file "raksha_ai" "/schemas/ai/seed_dev.sql"

create_db "raksha_risk_monitor"
load_schema_file "raksha_risk_monitor" "/schemas/risk-monitor/schema.sql"

echo "[bootstrap] all databases initialized"

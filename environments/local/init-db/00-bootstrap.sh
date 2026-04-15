#!/bin/bash
# Postgres bootstrap for the local-stack. Runs inside the postgres container
# on first init. Creates the per-service databases and loads each service's
# schema into its own database.
#
# Schemas are bind-mounted read-only under /schemas/<service>/.
#
# Order:
#   1. raksha_control    — control-plane (NestJS)      — all /schemas/control-plane/*
#   2. raksha_gateway    — event-gateway operational   — /schemas/event-gateway/schema.sql
#   3. raksha_gateway_raw — event-gateway raw_landing  — same schema (hot-tier envelopes)
#   4. raksha_notifier   — notifier-gateway            — /schemas/notifier/*

set -euo pipefail

psql_cmd() {
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
    local full="$dir/$f"
    case "$f" in
      *.sql)
        echo "[bootstrap] loading $full into $dbname"
        psql_cmd -d "$dbname" -f "$full"
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

# The default POSTGRES_DB created by the image is raksha_control — so the
# control-plane DB already exists. Load its ordered schema files there.
load_schema_dir "$POSTGRES_DB" "/schemas/control-plane"

create_db "raksha_gateway"
load_schema_file "raksha_gateway" "/schemas/event-gateway/schema.sql"

create_db "raksha_gateway_raw"
load_schema_file "raksha_gateway_raw" "/schemas/event-gateway/schema.sql"

create_db "raksha_notifier"
load_schema_dir "raksha_notifier" "/schemas/notifier"

echo "[bootstrap] all databases initialized"

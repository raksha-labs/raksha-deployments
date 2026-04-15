#!/usr/bin/env bash
# Raksha local-stack bring-up script.
#
# Usage:
#   ./start.sh          # build + start + wait for healthy
#   ./start.sh logs     # follow logs after start
#   ./start.sh down     # stop + remove containers (keeps volumes)
#   ./start.sh reset    # stop + remove containers AND volumes (fresh DB)
#   ./start.sh status   # print health of each service
set -euo pipefail

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd "$SCRIPT_DIR"

COMPOSE="docker compose"

cmd_up() {
  echo "==> validating compose file"
  $COMPOSE config -q

  echo "==> building images (may take several minutes on first run)"
  $COMPOSE build

  echo "==> starting stack"
  $COMPOSE up -d

  echo "==> waiting for services to become healthy"
  local deadline=$(( $(date +%s) + 300 ))
  while true; do
    if status_ok; then
      echo "==> all services healthy"
      break
    fi
    if (( $(date +%s) > deadline )); then
      echo "!!! timeout waiting for services to become healthy" >&2
      cmd_status
      exit 1
    fi
    sleep 3
  done

  cmd_status
  cat <<EOF

==> endpoints
  portal (user UI)        http://localhost:3000
  admin  (ops UI)         http://localhost:3002
  control-plane REST      http://localhost:3001
  control-plane Swagger   http://localhost:3001/v1/openapi
  control-plane gRPC      localhost:50051
  event-gateway health    http://localhost:8080/health
  event-gateway metrics   http://localhost:9092/metrics
  notifier-gateway health http://localhost:8082/health
  engine metrics          http://localhost:9091/metrics
  minio console           http://localhost:9001 (raksha / rakshadevsecret)
  postgres                localhost:5432 (raksha / raksha)
  redis                   localhost:6379

==> next steps
  ./start.sh logs         # tail logs
  ./start.sh status       # re-check health
  ./start.sh down         # stop (keep data)
  ./start.sh reset        # stop + wipe volumes
EOF
}

cmd_down() {
  $COMPOSE down
}

cmd_reset() {
  $COMPOSE down -v
}

cmd_logs() {
  $COMPOSE logs -f --tail=100
}

cmd_status() {
  echo "==> service status"
  # Prints the health of each non-oneshot service.
  for svc in postgres redis minio control-plane engine event-gateway notifier-gateway portal admin; do
    local health
    health=$(docker inspect -f '{{if .State.Health}}{{.State.Health.Status}}{{else}}{{.State.Status}}{{end}}' "raksha-local-${svc}-1" 2>/dev/null || echo "missing")
    printf "  %-22s %s\n" "$svc" "$health"
  done
}

status_ok() {
  for svc in postgres redis minio control-plane engine event-gateway notifier-gateway portal admin; do
    local health
    health=$(docker inspect -f '{{if .State.Health}}{{.State.Health.Status}}{{else}}{{.State.Status}}{{end}}' "raksha-local-${svc}-1" 2>/dev/null || echo "missing")
    case "$health" in
      healthy|running) ;;
      *) return 1 ;;
    esac
  done
  return 0
}

case "${1:-up}" in
  up)     cmd_up ;;
  down)   cmd_down ;;
  reset)  cmd_reset ;;
  logs)   cmd_logs ;;
  status) cmd_status ;;
  *) echo "usage: $0 {up|down|reset|logs|status}" >&2; exit 2 ;;
esac

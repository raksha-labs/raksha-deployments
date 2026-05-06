#!/usr/bin/env bash
# Opens an SSM port-forward tunnel to Grafana running in the prod VPC.
# Usage: ./tunnel-grafana.sh [local-port]   default: 3000
# Then open http://localhost:3000

set -euo pipefail

LOCAL_PORT="${1:-3099}"
BASTION="i-02a80fd0a83f2b283"
REMOTE_HOST="grafana.raksha-prod.internal"
REMOTE_PORT="3000"
REGION="eu-west-1"
PROFILE="${AWS_PROFILE:-raksha-prod}"

echo "Grafana tunnel: localhost:${LOCAL_PORT} → ${REMOTE_HOST}:${REMOTE_PORT}"
echo "Open http://localhost:${LOCAL_PORT}  (3099 avoids conflict with local portal:3000/3001/3002)"
echo "Press Ctrl+C to close."
echo

aws ssm start-session \
  --target "$BASTION" \
  --document-name AWS-StartPortForwardingSessionToRemoteHost \
  --parameters "{\"host\":[\"${REMOTE_HOST}\"],\"portNumber\":[\"${REMOTE_PORT}\"],\"localPortNumber\":[\"${LOCAL_PORT}\"]}" \
  --region "$REGION" \
  --profile "$PROFILE"

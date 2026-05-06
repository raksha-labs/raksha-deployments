#!/usr/bin/env bash
# Opens an SSM port-forward tunnel to the prod RDS Postgres instance.
# Usage: ./tunnel-postgres.sh [local-port]   default: 5433
#   (5433 avoids colliding with a local Postgres on 5432)
#
# Connect with:
#   psql "postgresql://raksha_admin:<pass>@localhost:<local-port>/raksha_engine?sslmode=require"
# Get the password:
#   aws secretsmanager get-secret-value \
#     --secret-id raksha/prod/foundation/database_admin_url \
#     --query SecretString --output text --region eu-west-1 --profile raksha-prod

set -euo pipefail

LOCAL_PORT="${1:-5433}"
BASTION="i-02a80fd0a83f2b283"
REMOTE_HOST="raksha-prod.cveoeogm818u.eu-west-1.rds.amazonaws.com"
REMOTE_PORT="5432"
REGION="eu-west-1"
PROFILE="${AWS_PROFILE:-raksha-prod}"

echo "Postgres tunnel: localhost:${LOCAL_PORT} → ${REMOTE_HOST}:${REMOTE_PORT}"
echo "Connect: psql postgresql://raksha_admin@localhost:${LOCAL_PORT}/<db>?sslmode=require"
echo "Press Ctrl+C to close."
echo

aws ssm start-session \
  --target "$BASTION" \
  --document-name AWS-StartPortForwardingSessionToRemoteHost \
  --parameters "{\"host\":[\"${REMOTE_HOST}\"],\"portNumber\":[\"${REMOTE_PORT}\"],\"localPortNumber\":[\"${LOCAL_PORT}\"]}" \
  --region "$REGION" \
  --profile "$PROFILE"

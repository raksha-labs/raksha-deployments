#!/usr/bin/env bash
set -euo pipefail

SERVICES_FILE="${1:-environments/prod/services.yaml}"
ERRORS=0

while IFS= read -r line; do
  if [[ "$line" =~ image_tag:\ *(.+)$ ]]; then
    tag="${BASH_REMATCH[1]}"
    if [[ "$tag" == "latest" || "$tag" == "prod-approved" || "$tag" == "main" ]]; then
      echo "ERROR: mutable image tag '$tag' found in $SERVICES_FILE"
      ERRORS=$((ERRORS + 1))
    fi
  fi
done < "$SERVICES_FILE"

if [[ $ERRORS -gt 0 ]]; then
  echo "Found $ERRORS mutable image tag(s). Use SHA-pinned or immutable semver tags."
  exit 1
fi

echo "All image tags OK."

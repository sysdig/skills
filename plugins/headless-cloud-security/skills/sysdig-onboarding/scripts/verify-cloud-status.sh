#!/usr/bin/env bash
# verify-cloud-status.sh — Check Sysdig cloud account onboarding status
#
# Usage:
#   verify-cloud-status.sh <provider> [cloud_account_id] [--expect]
#
# Arguments:
#   provider         — aws, gcp, or azure
#   cloud_account_id — (optional) cloud provider account ID to check
#                      (e.g., AWS account ID, GCP project ID)
#   --expect         — exit 2 if account not found or no features enabled
#                      (for retry loops in post-apply verification)
#
# Environment (set before calling, e.g. via `source .secrets/env`):
#   SYSDIG_SECURE_API_TOKEN — API token
#   SYSDIG_BASE_URL         — API base URL
#
# If env vars are not set, falls back to sourcing .secrets/env from cwd.
#
# Output:
#   JSON with account status fields. Token NEVER appears in output.
#
# API:
#   Uses /api/cloudauth/v1/accounts (legacy API, YELLOW flag).
#   This replaces the deprecated /api/cloud/v2/accounts endpoint.

set -euo pipefail

PROVIDER_ARG="${1:?Usage: verify-cloud-status.sh <provider> [cloud_account_id] [--expect]}"
CLOUD_ACCOUNT_ID="${2:-}"
EXPECT_MODE=false

# Check for --expect flag in any position
for arg in "$@"; do
  if [[ "$arg" == "--expect" ]]; then
    EXPECT_MODE=true
  fi
done

# Map short provider name to API enum
case "$PROVIDER_ARG" in
  aws)   PROVIDER="PROVIDER_AWS" ;;
  gcp)   PROVIDER="PROVIDER_GCP" ;;
  azure) PROVIDER="PROVIDER_AZURE" ;;
  *)     echo "ERROR: provider must be aws, gcp, or azure" >&2; exit 1 ;;
esac

# Load token/config if env vars are not set
# Priority: env var > .sysdig-token > .secrets/env
if [[ -z "${SYSDIG_SECURE_API_TOKEN:-}" || -z "${SYSDIG_BASE_URL:-}" ]]; then
  if [[ -f ".sysdig-token" ]]; then
    source ".sysdig-token"
  fi
  # .secrets/env may have SYSDIG_BASE_URL even if token came from .sysdig-token
  if [[ -z "${SYSDIG_SECURE_API_TOKEN:-}" || -z "${SYSDIG_BASE_URL:-}" ]]; then
    if [[ -f ".secrets/env" ]]; then
      source ".secrets/env"
    fi
  fi
  if [[ -z "${SYSDIG_SECURE_API_TOKEN:-}" || -z "${SYSDIG_BASE_URL:-}" ]]; then
    echo "ERROR: SYSDIG_SECURE_API_TOKEN and SYSDIG_BASE_URL must be set." >&2
    echo "Either edit .sysdig-token, export them, or create .secrets/env" >&2
    exit 1
  fi
fi

# Strip trailing slash
SYSDIG_BASE_URL="${SYSDIG_BASE_URL%/}"

# Fetch accounts via cloudauth/v1 API (legacy, YELLOW flag)
# stderr redirected to /dev/null to prevent any header/token leakage
RESPONSE=$(curl -s -S \
  -H "Authorization: Bearer ${SYSDIG_SECURE_API_TOKEN}" \
  "${SYSDIG_BASE_URL}/api/cloudauth/v1/accounts?provider=${PROVIDER}" \
  2>/dev/null) || {
    echo "ERROR: API call failed (check token and base URL)" >&2
    exit 1
  }

if [[ -n "$CLOUD_ACCOUNT_ID" ]]; then
  # Filter by cloud provider account ID (providerId field)
  MATCH=$(echo "$RESPONSE" | jq -r --arg pid "$CLOUD_ACCOUNT_ID" \
    '.accounts // [] | [.[] | select(.providerId == $pid)] | if length == 0 then empty else .[0] end | {
      sysdigAccountId: .id,
      providerId: .providerId,
      provider: .provider,
      alias: .providerAlias,
      enabled: .enabled,
      features: (
        if .feature then
          (.feature | to_entries | map(select(.value.enabled == true) | .key) | sort)
        else [] end
      )
    }' 2>/dev/null)

  if [[ -z "$MATCH" ]]; then
    echo "Account $CLOUD_ACCOUNT_ID not found for provider $PROVIDER_ARG"
    if [[ "$EXPECT_MODE" == "true" ]]; then
      exit 2
    fi
  else
    # In expect mode, verify at least one feature is enabled
    if [[ "$EXPECT_MODE" == "true" ]]; then
      feat_count=$(echo "$MATCH" | jq '.features | length' 2>/dev/null || echo "0")
      if [[ "$feat_count" -eq 0 ]]; then
        echo "Account found but no features enabled yet"
        exit 2
      fi
    fi
    echo "$MATCH"
  fi
else
  # List all accounts for this provider (summary)
  echo "$RESPONSE" | jq '[.accounts // [] | .[] | {
    providerId: .providerId,
    alias: .providerAlias,
    enabled: .enabled,
    features: (
      if .feature then
        (.feature | to_entries | map(select(.value.enabled == true) | .key) | sort)
      else [] end
    )
  }]' 2>/dev/null
fi

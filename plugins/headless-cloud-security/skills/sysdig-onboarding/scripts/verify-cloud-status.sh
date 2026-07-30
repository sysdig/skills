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
# Environment (set before calling, e.g. via `source .sysdig-token`):
#   SYSDIG_SECURE_API_TOKEN — API token
#   SYSDIG_BASE_URL         — API base URL
#
# If env vars are not set, falls back to .sysdig-token then .secrets/env from
# cwd. Fallback files are PARSED for the known variables, never
# sourced/executed.
#
# Output:
#   JSON with account status fields. Token NEVER appears in output or
#   process arguments (the Authorization header is fed to curl via a
#   private pipe, not argv).
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
# Priority: env var (incl. bridged legacy/MCP aliases) > .sysdig-token > .secrets/env
# resolve_sysdig_credentials bridges legacy vars (e.g. SYSDIG_MCP_API_TOKEN /
# SYSDIG_MCP_API_HOST) into the canonical names.
source "$(dirname "${BASH_SOURCE[0]}")/resolve-credentials.sh"
resolve_sysdig_credentials
# This script reads SYSDIG_BASE_URL; mirror the canonical SYSDIG_SECURE_URL into it.
[[ -z "${SYSDIG_BASE_URL:-}" && -n "${SYSDIG_SECURE_URL:-}" ]] && SYSDIG_BASE_URL="${SYSDIG_SECURE_URL}"

if [[ -z "${SYSDIG_SECURE_API_TOKEN:-}" || -z "${SYSDIG_BASE_URL:-}" ]]; then
  # Fallback files are parsed for the known variables — never executed
  load_sysdig_token_file ".sysdig-token" || true
  # .secrets/env may have SYSDIG_BASE_URL even if token came from .sysdig-token
  if [[ -z "${SYSDIG_SECURE_API_TOKEN:-}" || -z "${SYSDIG_BASE_URL:-}" ]]; then
    load_sysdig_token_file ".secrets/env" || true
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
HTTP_RESPONSE=$(curl -s -m 15 \
  -K <(printf 'header = "Authorization: Bearer %s"\n' "$SYSDIG_SECURE_API_TOKEN") \
  -w $'\n%{http_code}' \
  "${SYSDIG_BASE_URL}/api/cloudauth/v1/accounts?provider=${PROVIDER}" \
  2>/dev/null) || {
    echo "ERROR: API call failed (network error or timeout)" >&2
    exit 1
  }

HTTP_CODE="${HTTP_RESPONSE##*$'\n'}"
RESPONSE="${HTTP_RESPONSE%$'\n'*}"
case "$HTTP_CODE" in
  200) ;;
  401|403)
    echo "ERROR: Sysdig API rejected the token (HTTP ${HTTP_CODE}) — invalid, expired, or wrong region for ${SYSDIG_BASE_URL}" >&2
    exit 1
    ;;
  *)
    echo "ERROR: Sysdig API returned HTTP ${HTTP_CODE} from ${SYSDIG_BASE_URL}" >&2
    exit 1
    ;;
esac

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
    }' 2>/dev/null) || MATCH=""

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

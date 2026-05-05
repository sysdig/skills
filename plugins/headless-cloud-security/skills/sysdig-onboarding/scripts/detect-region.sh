#!/usr/bin/env bash
# detect-region.sh — Auto-detect Sysdig SaaS region from API token
#
# Usage:
#   detect-region.sh
#
# Environment (set before calling, e.g. via `source .sysdig-token`):
#   SYSDIG_SECURE_API_TOKEN — API token (REQUIRED)
#
# If env var is not set, falls back to .sysdig-token then .secrets/env from cwd.
#
# Output on success:
#   Region detected: <region_id>
#   API URL: <api_url>
#   Secure URL: <secure_url>
#
# Exit codes:
#   0 — Region detected
#   1 — No region matched (invalid token or all endpoints unreachable)
#   2 — Missing prerequisites (curl not found, token not set)
#
# Token NEVER appears in output or logs.

set -euo pipefail

# --- Colors ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

pass() { echo -e "  ${GREEN}✓${NC} $1"; }
fail() { echo -e "  ${RED}✗${NC} $1"; }
warn() { echo -e "  ${YELLOW}!${NC} $1"; }

# --- Prerequisites ---
if ! command -v curl &>/dev/null; then
  fail "curl is required but not installed"
  exit 2
fi

# --- Token ---
# Priority: env var > .sysdig-token > .secrets/env
if [[ -z "${SYSDIG_SECURE_API_TOKEN:-}" ]]; then
  if [[ -f ".sysdig-token" ]]; then
    source ".sysdig-token"
  elif [[ -f ".secrets/env" ]]; then
    source ".secrets/env"
  fi
fi

if [[ -z "${SYSDIG_SECURE_API_TOKEN:-}" ]]; then
  fail "SYSDIG_SECURE_API_TOKEN is not set"
  echo "  Set the env var, edit .sysdig-token, or create .secrets/env" >&2
  exit 2
fi

# --- Region definitions ---
# Format: region_id|api_url|secure_url
REGIONS=(
  "us1|https://secure.sysdig.com/api|https://secure.sysdig.com"
  "us2|https://us2.app.sysdig.com/api|https://us2.app.sysdig.com"
  "us4|https://app.us4.sysdig.com/api|https://app.us4.sysdig.com"
  "eu1|https://eu1.app.sysdig.com/api|https://eu1.app.sysdig.com"
  "eu2|https://app.eu2.sysdig.com/api|https://app.eu2.sysdig.com"
  "us3|https://app.us3.sysdig.com/api|https://app.us3.sysdig.com"
  "au1|https://app.au1.sysdig.com/api|https://app.au1.sysdig.com"
  "in1|https://app.in1.sysdig.com/api|https://app.in1.sysdig.com"
  "me2|https://app.me2.sysdig.com/api|https://app.me2.sysdig.com"
)

echo "Probing Sysdig regions..."

for entry in "${REGIONS[@]}"; do
  IFS='|' read -r region_id api_url secure_url <<< "$entry"

  # Probe via secure_url/api/users/me — consistent across all regions.
  # api_url has inconsistent path prefixes (/api on some, not others).
  HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" -m 5 \
    -H "Authorization: Bearer ${SYSDIG_SECURE_API_TOKEN}" \
    "${secure_url}/api/users/me" 2>/dev/null) || HTTP_CODE="000"

  if [[ "$HTTP_CODE" == "200" ]]; then
    pass "Region detected: ${region_id}"
    echo ""
    echo "Region detected: ${region_id}"
    echo "API URL: ${api_url}"
    echo "Secure URL: ${secure_url}"
    exit 0
  fi
done

fail "No region matched — token may be invalid or endpoints unreachable"
exit 1

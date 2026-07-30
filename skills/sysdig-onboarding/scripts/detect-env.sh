#!/usr/bin/env bash
# detect-env.sh — Detect existing Sysdig environment variables
#
# Usage:
#   detect-env.sh [--json]
#
# Checks for known Sysdig-related environment variables (current and legacy)
# that may contain API tokens or endpoint URLs. Reports which are set without
# revealing their values.
#
# Output (text mode):
#   Lists detected variables with their category and recommendation.
#
# Output (--json mode):
#   JSON object with token_var, url_var (best match for each), and full list.
#
# Exit codes:
#   0 — At least one token variable detected
#   1 — No token variables found
#
# SECURITY: Variable VALUES are never printed — only names and SET/UNSET status.

set -euo pipefail

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

JSON_MODE=false
[[ "${1:-}" == "--json" ]] && JSON_MODE=true

# --- Credential variable priority lists ---
# Single source of truth: SYSDIG_TOKEN_VARS / SYSDIG_URL_VARS in
# resolve-credentials.sh (shared with detect-region.sh, verify-cloud-status.sh).
source "$(dirname "${BASH_SOURCE[0]}")/resolve-credentials.sh"

# --- Check which variables are set ---
best_token=""
best_url=""
found_tokens=()
found_urls=()

for var in "${SYSDIG_TOKEN_VARS[@]}"; do
  if [[ -n "${!var+x}" && -n "${!var}" ]]; then
    found_tokens+=("$var")
    [[ -z "$best_token" ]] && best_token="$var"
  fi
done

for var in "${SYSDIG_URL_VARS[@]}"; do
  if [[ -n "${!var+x}" && -n "${!var}" ]]; then
    found_urls+=("$var")
    [[ -z "$best_url" ]] && best_url="$var"
  fi
done

# --- Output ---
if [[ "$JSON_MODE" == "true" ]]; then
  # Build JSON arrays
  token_json="["
  for i in "${!found_tokens[@]}"; do
    [[ $i -gt 0 ]] && token_json+=","
    token_json+="\"${found_tokens[$i]}\""
  done
  token_json+="]"

  url_json="["
  for i in "${!found_urls[@]}"; do
    [[ $i -gt 0 ]] && url_json+=","
    url_json+="\"${found_urls[$i]}\""
  done
  url_json+="]"

  cat <<ENDJSON
{
  "best_token_var": "${best_token}",
  "best_url_var": "${best_url}",
  "token_vars_found": ${token_json},
  "url_vars_found": ${url_json},
  "has_token": $([ -n "$best_token" ] && echo "true" || echo "false"),
  "has_url": $([ -n "$best_url" ] && echo "true" || echo "false")
}
ENDJSON
else
  echo "Sysdig Environment Detection"
  echo "============================="
  echo ""

  if [[ ${#found_tokens[@]} -gt 0 ]]; then
    echo -e "  ${GREEN}✓${NC} Token found: ${found_tokens[*]}"
    if [[ "$best_token" != "SYSDIG_SECURE_API_TOKEN" ]]; then
      echo -e "  ${YELLOW}!${NC} Recommended: bridge to SYSDIG_SECURE_API_TOKEN"
    fi
  else
    echo "  No Sysdig token variables detected."
  fi

  echo ""

  if [[ ${#found_urls[@]} -gt 0 ]]; then
    echo -e "  ${GREEN}✓${NC} URL found: ${found_urls[*]}"
  else
    echo "  No Sysdig URL variables detected."
  fi
fi

# Exit 0 if we found a token, 1 if not
[[ -n "$best_token" ]]

#!/usr/bin/env bash
# detect-region.sh — Auto-detect Sysdig SaaS region from API token
#
# Usage:
#   detect-region.sh [--save-url]
#
#   --save-url  On success, write `export SYSDIG_BASE_URL="<secure_url>"` into
#               ./.sysdig-token (replacing an existing SYSDIG_BASE_URL line, or
#               appending one). The file is rewritten in place with mode 600
#               and its contents are never printed — the agent must not open,
#               cat or grep .sysdig-token to edit that line itself.
#
# Environment (set before calling, e.g. via `source .sysdig-token`):
#   SYSDIG_SECURE_API_TOKEN — API token (REQUIRED)
#
# If the env var is not set, falls back to .sysdig-token then .secrets/env
# from cwd. Fallback files are PARSED for the known variables, never
# sourced/executed.
#
# All regions are probed in parallel (single ~5s wall-clock wave instead of
# a sequential sweep); when several respond, the first entry in the priority
# list wins.
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
# Token NEVER appears in output, logs, or process arguments (the
# Authorization header is fed to curl via a private pipe, not argv).

set -euo pipefail

# --- Colors ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

pass() { echo -e "  ${GREEN}✓${NC} $1"; }
fail() { echo -e "  ${RED}✗${NC} $1"; }
warn() { echo -e "  ${YELLOW}!${NC} $1"; }

# --- Arguments ---
SAVE_URL=0
for arg in "$@"; do
  case "$arg" in
    --save-url) SAVE_URL=1 ;;
    -h | --help)
      sed -n '2,/^$/p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
      exit 0 ;;
    *)
      fail "Unknown argument: $arg (usage: detect-region.sh [--save-url])"
      exit 2 ;;
  esac
done

# save_base_url <url> — set SYSDIG_BASE_URL in ./.sysdig-token without ever
# printing the file (it holds the token).
save_base_url() {
  local file=".sysdig-token" url="$1" tmp
  if [[ ! -f "$file" ]]; then
    warn "No .sysdig-token in $(pwd) — SYSDIG_BASE_URL not saved"
    return 0
  fi
  tmp=$(mktemp "${file}.XXXXXX")
  chmod 600 "$tmp"
  if ! awk -v url="$url" '
      /^[[:space:]]*(export[[:space:]]+)?SYSDIG_BASE_URL=/ {
        if (!done) print "export SYSDIG_BASE_URL=\"" url "\""
        done = 1
        next
      }
      { print }
      END { if (!done) print "export SYSDIG_BASE_URL=\"" url "\"" }
    ' "$file" >"$tmp"; then
    rm -f "$tmp"
    fail "Could not update SYSDIG_BASE_URL in .sysdig-token"
    return 1
  fi
  mv "$tmp" "$file"
  pass "Saved SYSDIG_BASE_URL=${url} to .sysdig-token"
}

# --- Prerequisites ---
if ! command -v curl &>/dev/null; then
  fail "curl is required but not installed"
  exit 2
fi

# --- Token ---
# Priority: env var (incl. bridged legacy/MCP aliases) > .sysdig-token > .secrets/env
# resolve_sysdig_credentials bridges legacy vars (e.g. SYSDIG_MCP_API_TOKEN)
# into the canonical SYSDIG_SECURE_API_TOKEN this script reads.
source "$(dirname "${BASH_SOURCE[0]}")/resolve-credentials.sh"
resolve_sysdig_credentials

if [[ -z "${SYSDIG_SECURE_API_TOKEN:-}" ]]; then
  load_sysdig_token_file ".sysdig-token" || true
fi
if [[ -z "${SYSDIG_SECURE_API_TOKEN:-}" ]]; then
  load_sysdig_token_file ".secrets/env" || true
fi

if [[ -z "${SYSDIG_SECURE_API_TOKEN:-}" ]]; then
  fail "SYSDIG_SECURE_API_TOKEN is not set"
  echo "  Set the env var, edit .sysdig-token, or create .secrets/env" >&2
  exit 2
fi

# --- Region definitions ---
# Format: region_id|api_url|secure_url — ordered by priority; when more than
# one endpoint accepts the token, the earliest entry wins.
REGIONS=(
  "us1|https://secure.sysdig.com/api|https://secure.sysdig.com"
  "us2|https://us2.app.sysdig.com/api|https://us2.app.sysdig.com"
  "us4|https://app.us4.sysdig.com/api|https://app.us4.sysdig.com"
  "eu1|https://eu1.app.sysdig.com/api|https://eu1.app.sysdig.com"
  "eu2|https://app.eu2.sysdig.com/api|https://app.eu2.sysdig.com"
  "us3|https://app.us3.sysdig.com/api|https://app.us3.sysdig.com"
  "au1|https://app.au1.sysdig.com/api|https://app.au1.sysdig.com"
  "in1|https://app.in1.sysdig.com/api|https://app.in1.sysdig.com"
  "jp1|https://app.jp1.sysdig.com/api|https://app.jp1.sysdig.com"
  "me2|https://app.me2.sysdig.com/api|https://app.me2.sysdig.com"
  # Legacy US1 host: report the canonical region id (us1) with the legacy URLs,
  # so downstream region/Shield config receives a supported region value.
  "us1|https://app.sysdigcloud.com/api|https://app.sysdigcloud.com"
)

echo "Probing Sysdig regions..."

PROBE_DIR=$(mktemp -d)
trap 'rm -rf "$PROBE_DIR"' EXIT

# Probe via secure_url/api/users/me — consistent across all regions.
# api_url has inconsistent path prefixes (/api on some, not others).
# All probes run in parallel; each writes its HTTP code to $PROBE_DIR/<index>.
for i in "${!REGIONS[@]}"; do
  IFS='|' read -r _ _ secure_url <<< "${REGIONS[$i]}"
  (
    code=$(curl -s -o /dev/null -w "%{http_code}" -m 5 \
      -K <(printf 'header = "Authorization: Bearer %s"\n' "$SYSDIG_SECURE_API_TOKEN") \
      "${secure_url}/api/users/me" 2>/dev/null) || code="000"
    printf '%s' "$code" > "${PROBE_DIR}/${i}"
  ) &
done
wait

for i in "${!REGIONS[@]}"; do
  IFS='|' read -r region_id api_url secure_url <<< "${REGIONS[$i]}"
  code="000"
  [[ -s "${PROBE_DIR}/${i}" ]] && read -r code < "${PROBE_DIR}/${i}" || true

  if [[ "$code" == "200" ]]; then
    pass "Region detected: ${region_id}"
    echo ""
    echo "Region detected: ${region_id}"
    echo "API URL: ${api_url}"
    echo "Secure URL: ${secure_url}"
    if [[ "$SAVE_URL" -eq 1 ]]; then
      save_base_url "$secure_url"
    fi
    exit 0
  fi
done

fail "No region matched — token may be invalid or endpoints unreachable"
exit 1

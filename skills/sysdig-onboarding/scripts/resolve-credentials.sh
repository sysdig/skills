#!/usr/bin/env bash
# resolve-credentials.sh — Canonical Sysdig credential resolution (sourced library)
#
# Usage (source, do not execute):
#   source "$(dirname "${BASH_SOURCE[0]}")/resolve-credentials.sh"
#   resolve_sysdig_credentials
#
# Why this exists:
#   Tokens and URLs reach the onboarding flow under many env var names —
#   the current standard (SYSDIG_SECURE_API_TOKEN / SYSDIG_SECURE_URL) plus
#   several legacy/tool-specific aliases, including the MCP server's
#   SYSDIG_MCP_API_TOKEN / SYSDIG_MCP_API_HOST. Scripts that call the Sysdig
#   API only read the canonical names, so a user who has *only* a legacy var
#   set (e.g. MCP-server credentials) would otherwise hit "token is not set".
#
#   resolve_sysdig_credentials bridges the first legacy match into the
#   canonical SYSDIG_SECURE_API_TOKEN / SYSDIG_SECURE_URL deterministically,
#   in code — so it no longer depends on the agent remembering to do it.
#
# This is the single source of truth for the bash priority lists. Keep it
# aligned with sysdig-api/scripts/lib.py (TOKEN_VARS / HOST_VARS).
#
# SECURITY: Variable VALUES are never printed — only names (to stderr).

# --- Token variables (ordered by preference: current first, then legacy) ---
SYSDIG_TOKEN_VARS=(
  "SYSDIG_SECURE_API_TOKEN"         # Terraform provider, MCP server, current standard
  "TF_VAR_sysdig_secure_api_token"  # Terraform variable (same token)
  "SECURE_API_TOKEN"                # sysdig-cli-scanner, Harbor scanner
  "SYSDIG_SECURE_TOKEN"             # GitHub Actions
  "SYSDIG_MCP_API_TOKEN"            # legacy MCP-specific override (deprecated)
  "SDC_SECURE_TOKEN"                # Python SDK, sdc_client (legacy)
  "SDC_TOKEN"                       # sdc_client generic fallback (legacy)
)

# --- URL variables (ordered by preference) ---
SYSDIG_URL_VARS=(
  "SYSDIG_SECURE_URL"               # GitHub Actions, Backstage, MCP server
  "SYSDIG_BASE_URL"                 # Onboarding skill
  "SYSDIG_SECURE_ENDPOINT"          # Backstage integration
  "SYSDIG_MCP_API_HOST"             # legacy MCP-specific override (deprecated)
  "SDC_SECURE_URL"                  # Python SDK, sdc_client (legacy)
  "SDC_URL"                         # sdc_client generic (legacy)
  "SDC_MONITOR_URL"                 # Python SDK Monitor (reveals region)
)

# load_sysdig_token_file <path> — Load credentials from a token file WITHOUT
# executing it. These files live in the user's working directory and may not
# have been written by this skill, so they are parsed line-by-line for the
# known assignments instead of being sourced — `source` would execute
# arbitrary shell code from an untrusted directory.
# Recognized lines (optionally prefixed with `export `, values in quotes,
# trailing comments allowed):
#   SYSDIG_TOKEN="..."                (helper variable inside .sysdig-token)
#   SYSDIG_SECURE_API_TOKEN="..."     (canonical; may reference "$SYSDIG_TOKEN")
#   SYSDIG_BASE_URL="..." / SYSDIG_SECURE_URL="..."
# Exports SYSDIG_SECURE_API_TOKEN / SYSDIG_BASE_URL when found and not
# already set. Returns 1 if the file does not exist.
load_sysdig_token_file() {
  local file="$1"
  [[ -f "$file" ]] || return 1
  local line key val helper_token=""
  while IFS= read -r line || [[ -n "$line" ]]; do
    line="${line#"${line%%[![:space:]]*}"}"   # strip leading whitespace
    line="${line#export }"
    case "$line" in
      SYSDIG_TOKEN=* | SYSDIG_SECURE_API_TOKEN=* | SYSDIG_BASE_URL=* | SYSDIG_SECURE_URL=*) ;;
      *) continue ;;
    esac
    key="${line%%=*}"
    val="${line#*=}"
    val="${val%%[[:space:]]#*}"               # strip trailing comment
    val="${val%"${val##*[![:space:]]}"}"      # strip trailing whitespace
    val="${val%\"}"; val="${val#\"}"          # strip surrounding quotes
    val="${val%\'}"; val="${val#\'}"
    # Resolve the one known indirection used by .sysdig-token — never eval
    [[ "$val" == "\$SYSDIG_TOKEN" || "$val" == "\${SYSDIG_TOKEN}" ]] && val="$helper_token"
    case "$key" in
      SYSDIG_TOKEN) helper_token="$val" ;;
      SYSDIG_SECURE_API_TOKEN)
        if [[ -z "${SYSDIG_SECURE_API_TOKEN:-}" && -n "$val" ]]; then
          export SYSDIG_SECURE_API_TOKEN="$val"
        fi ;;
      SYSDIG_BASE_URL | SYSDIG_SECURE_URL)
        if [[ -z "${SYSDIG_BASE_URL:-}" && -n "$val" ]]; then
          export SYSDIG_BASE_URL="$val"
        fi ;;
    esac
  done < "$file"
  return 0
}

# resolve_sysdig_credentials — Bridge the first matching legacy var into the
# canonical SYSDIG_SECURE_API_TOKEN / SYSDIG_SECURE_URL when those are unset.
# Exports nothing it cannot find; leaves already-set canonical vars untouched.
resolve_sysdig_credentials() {
  if [[ -z "${SYSDIG_SECURE_API_TOKEN:-}" ]]; then
    local var
    for var in "${SYSDIG_TOKEN_VARS[@]}"; do
      if [[ -n "${!var+x}" && -n "${!var}" ]]; then
        export SYSDIG_SECURE_API_TOKEN="${!var}"
        [[ "$var" != "SYSDIG_SECURE_API_TOKEN" ]] &&
          echo "  Bridged ${var} → SYSDIG_SECURE_API_TOKEN" >&2
        break
      fi
    done
  fi

  if [[ -z "${SYSDIG_SECURE_URL:-}" ]]; then
    local var
    for var in "${SYSDIG_URL_VARS[@]}"; do
      if [[ -n "${!var+x}" && -n "${!var}" ]]; then
        export SYSDIG_SECURE_URL="${!var}"
        [[ "$var" != "SYSDIG_SECURE_URL" ]] &&
          echo "  Bridged ${var} → SYSDIG_SECURE_URL" >&2
        break
      fi
    done
  fi
}

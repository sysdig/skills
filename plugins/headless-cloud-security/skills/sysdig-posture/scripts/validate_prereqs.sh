#!/usr/bin/env bash
# validate_prereqs.sh — check posture-skill local prerequisites.
#
# Required tools: terraform, go
# Optional:       one of aws | gcloud | az (for live-resource inspection)
#
# Sysdig credentials are NOT checked here. The skill verifies the Sysdig
# MCP server is available (which proves SYSDIG_SECURE_API_TOKEN /
# SYSDIG_SECURE_URL are set) before invoking this script.
#
# Output on stdout (JSON):
#   {
#     "ok": bool,                         # true iff all required tools present
#     "missing": [<required tools not found>],
#     "versions": {<tool>: "<version>", ...},
#     "cloud_cli_available": bool
#   }
#
# Exit 0 only when "ok" is true.

set -euo pipefail

missing=()
versions_json=""

record_version() {
  local name="$1"
  shift
  if ! command -v "$name" >/dev/null 2>&1; then
    missing+=("$name")
    return
  fi
  local ver
  ver="$("$@" 2>&1 | head -n1 | sed 's/"/\\"/g')"
  versions_json+="\"$name\":\"$ver\","
}

record_version terraform terraform version
record_version go go version

cloud_found="false"
for cli in aws gcloud az; do
  if command -v "$cli" >/dev/null 2>&1; then
    cloud_found="true"
    break
  fi
done

versions_json="${versions_json%,}"

overall_ok="true"
if [ "${#missing[@]}" -gt 0 ]; then
  overall_ok="false"
fi

missing_json=""
if [ "${#missing[@]}" -gt 0 ]; then
  for m in "${missing[@]}"; do
    missing_json+="\"$m\","
  done
  missing_json="${missing_json%,}"
fi

cat <<EOF
{
  "ok": $overall_ok,
  "missing": [$missing_json],
  "versions": {$versions_json},
  "cloud_cli_available": $cloud_found
}
EOF

[ "$overall_ok" = "true" ] || exit 1

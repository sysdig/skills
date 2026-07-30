#!/usr/bin/env bash
# render-recap.sh — Render the Step 5b confirmation table (STRICT format)
#
# Usage:
#   render-recap.sh <rows-file>
#
# rows-file format:
#   target: cloud | kubernetes | host      (first non-empty line)
#   <Setting><TAB><Value><TAB><Source>     (one row per line)
#
# The script owns the STRICT recap contract from
# references/confirmation-flow.md: canonical row order, canonical row schema
# (unknown settings are rejected, required rows enforced — including
# `AWS Profile` + `Caller` whenever the Provider row says AWS), and the
# markdown pipe-table format. Agents write the rows file, run this script,
# and show its output VERBATIM.
#
# Exit codes:
#   0 — table rendered
#   1 — validation error (message on stderr; fix the rows file and re-run)

set -euo pipefail

err() { echo "ERROR: $*" >&2; exit 1; }

[[ $# -eq 1 ]] || err "usage: render-recap.sh <rows-file>"
FILE="$1"
[[ -f "$FILE" ]] || err "rows file not found: $FILE"

# --- Canonical schemas (order matters; * = required, aws = required when AWS) ---
# Encoded as "flag|Setting name" lines to stay bash-3.2 compatible.
SCHEMA_CLOUD="*|Target
*|Provider
*|Account ID
aws|AWS Profile
aws|Caller
*|Scope
*|Sysdig Region
*|Capabilities
 |Log capture mode
 |Cloud Logs regions
 |Host Scanning extras
 |Host Scanning regions
 |Workload Scanning
*|Backend"

SCHEMA_KUBERNETES="*|Target
*|Distribution
*|Cluster Name
*|Namespace
*|Sysdig Region
*|Features
 |Windows node coverage"

# Host schema mirrors the Linux Host table in references/confirmation-flow.md.
# Architecture / Feature Profile / Driver are optional per that file's omission
# rules (no auto-detect / Custom profile / default kmod driver).
SCHEMA_HOST="*|Target
*|Distribution
 |Architecture
*|Install Method
*|Sysdig Region
 |Feature Profile
*|Features
 |Driver"

# --- Parse rows file ---
TARGET=""
ROW_NAMES=()
ROW_VALUES=()
ROW_SOURCES=()

line_no=0
while IFS= read -r line || [[ -n "$line" ]]; do
  line_no=$((line_no + 1))
  line="${line%$'\r'}"
  [[ -z "${line//[[:space:]]/}" ]] && continue
  case "$line" in
    \#*) continue ;;
    target:*)
      TARGET="${line#target:}"
      TARGET="${TARGET//[[:space:]]/}"
      continue
      ;;
  esac
  IFS=$'\t' read -r name value source extra <<< "$line"
  [[ -n "${extra:-}" ]] && err "line ${line_no}: more than 3 tab-separated fields"
  [[ -n "${name:-}" && -n "${value:-}" && -n "${source:-}" ]] || \
    err "line ${line_no}: expected Setting<TAB>Value<TAB>Source, got: $line"
  # Escape pipes so values can't break the markdown table
  value="${value//|/\\|}"
  source="${source//|/\\|}"
  # Reject duplicates
  i=0
  while [[ $i -lt ${#ROW_NAMES[@]} ]]; do
    [[ "${ROW_NAMES[$i]}" == "$name" ]] && err "duplicate setting: $name"
    i=$((i + 1))
  done
  ROW_NAMES+=("$name")
  ROW_VALUES+=("$value")
  ROW_SOURCES+=("$source")
done < "$FILE"

case "$TARGET" in
  cloud)      SCHEMA="$SCHEMA_CLOUD" ;;
  kubernetes) SCHEMA="$SCHEMA_KUBERNETES" ;;
  host)       SCHEMA="$SCHEMA_HOST" ;;
  "")         err "missing 'target: cloud|kubernetes|host' line" ;;
  *)          err "unknown target '$TARGET' (expected cloud, kubernetes, or host)" ;;
esac

[[ ${#ROW_NAMES[@]} -gt 0 ]] || err "no rows found"

# --- AWS conditional: Provider row value mentions AWS ---
is_aws=false
i=0
while [[ $i -lt ${#ROW_NAMES[@]} ]]; do
  if [[ "${ROW_NAMES[$i]}" == "Provider" ]]; then
    case "${ROW_VALUES[$i]}" in
      *AWS*|*aws*|*Amazon*) is_aws=true ;;
    esac
  fi
  i=$((i + 1))
done

# --- Validate: every provided setting must exist in the schema ---
i=0
while [[ $i -lt ${#ROW_NAMES[@]} ]]; do
  found=false
  while IFS='|' read -r _flag sname; do
    [[ "$sname" == "${ROW_NAMES[$i]}" ]] && found=true
  done <<< "$SCHEMA"
  [[ "$found" == "true" ]] || \
    err "unknown setting '${ROW_NAMES[$i]}' for target '$TARGET' (the row schema is canonical — see references/confirmation-flow.md)"
  i=$((i + 1))
done

# --- Validate required rows & render in canonical order ---
OUTPUT="| Setting | Value | Source |"$'\n'"|---------|-------|--------|"
while IFS='|' read -r flag sname; do
  idx=-1
  i=0
  while [[ $i -lt ${#ROW_NAMES[@]} ]]; do
    [[ "${ROW_NAMES[$i]}" == "$sname" ]] && idx=$i
    i=$((i + 1))
  done
  if [[ $idx -ge 0 ]]; then
    OUTPUT="${OUTPUT}"$'\n'"| ${sname} | ${ROW_VALUES[$idx]} | ${ROW_SOURCES[$idx]} |"
  else
    case "$flag" in
      '*') err "missing required row: $sname" ;;
      aws) [[ "$is_aws" == "true" ]] && \
             err "missing required row for AWS: $sname (load-bearing for account-identity pinning)" ;;
    esac
  fi
done <<< "$SCHEMA"

printf '%s\n' "$OUTPUT"

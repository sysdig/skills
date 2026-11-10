#!/usr/bin/env bash
# lint_config.sh — Post-generation checks for configs the skill writes
#
# Usage:
#   lint_config.sh [--user-filled] <file> [file...]
#   Flags may appear anywhere in the argument list — `lint_config.sh cfg.yaml
#   --user-filled` works too. Use `--` to lint a file whose name starts with `-`.
#
# Run after Step 7 file generation, BEFORE terraform init/plan or
# helm template. Catches the classic generation mistakes mechanically:
#   1. Unresolved {{PLACEHOLDER}} tokens
#   2. Dangling feature markers (`# === X ===` without `# === END X ===`)
#   3. Mutually-exclusive marker pairs both present
#      (CDR vs CDR_CLOUDLOGS, CIEM Advanced vs CIEM_ADVANCED_CLOUDLOGS)
#   4. WARN (non-fatal): secret-looking literals on credential keys — fresh
#      generation must use var references or REPLACE_WITH placeholders.
#
# --user-filled  Skip check 4. Use it for the RE-LINT after the user pastes
#                their own Agent Access Key into dragent.yaml / values.yaml.
#                That is the documented happy path, so warning there trains
#                operators to ignore lint output — exactly what this flag
#                prevents. Never pass it on a freshly generated file.
#
# Output: `OK <file>` / `WARN <file>: ...` / `ERROR <file>: ...` lines.
# Exit codes: 0 — no errors (warnings allowed); 1 — one or more errors.

set -euo pipefail

# Flags are accepted in any position: options-after-filenames is the natural
# order and used to fail with `ERROR --user-filled: file not found`, which the
# skill treats as "do not hand any install command to the user".
USER_FILLED=false
FILES=()
END_OF_OPTS=false
for arg in "$@"; do
  if [[ "$END_OF_OPTS" == true ]]; then
    FILES+=("$arg"); continue
  fi
  case "$arg" in
    --user-filled) USER_FILLED=true ;;
    --) END_OF_OPTS=true ;;
    -*) echo "unknown option: $arg (known: --user-filled)" >&2; exit 1 ;;
    *) FILES+=("$arg") ;;
  esac
done

[[ ${#FILES[@]} -ge 1 ]] || { echo "usage: lint_config.sh [--user-filled] <file> [file...]" >&2; exit 1; }
set -- "${FILES[@]}"

ERRORS=0
problem() { echo "ERROR $1: $2"; ERRORS=$((ERRORS + 1)); }
warning() { echo "WARN $1: $2"; }

for f in "$@"; do
  if [[ ! -f "$f" ]]; then
    problem "$f" "file not found"
    continue
  fi
  if [[ ! -s "$f" ]]; then
    problem "$f" "file is empty"
    continue
  fi

  file_errors=$ERRORS

  # 1. Unresolved placeholders. Skip comment lines (`#` / `//`) and the generic
  #    `{{PLACEHOLDER}}` documentation token: every template ships a header
  #    banner like "# Replace {{PLACEHOLDER}} values before deploying", which is
  #    instructional prose, not a substitutable placeholder. Real placeholders
  #    are named ({{SYSDIG_ACCESS_KEY}}, {{CLOUD_LOGS_REGIONS}}, ...) and live on
  #    config lines, so they are still caught.
  leftover=$(grep -n -E '\{\{[A-Za-z0-9_]+\}\}' "$f" 2>/dev/null \
    | grep -v -E '^[0-9]+:[[:space:]]*(#|//)' \
    | grep -v '{{PLACEHOLDER}}' || true)
  if [[ -n "$leftover" ]]; then
    while IFS= read -r hit; do
      problem "$f" "unresolved placeholder at line ${hit%%:*}: $(echo "$hit" | grep -o -E '\{\{[A-Za-z0-9_]+\}\}' | head -1)"
    done <<< "$leftover"
  fi

  # 2. Dangling markers: every `=== X ... ===` needs `=== END X ===` and
  #    vice versa. Openings may carry an annotation after the name
  #    (`# === CSPM (Cloud Security Posture Management) ===`) — the name is
  #    everything up to the first ` (` or the closing ` ===`.
  openings=""
  ends=""
  while IFS= read -r mline; do
    [[ -z "$mline" ]] && continue
    m="${mline#*=== }"       # drop through the first '=== '
    m="${m%% ===*}"          # keep up to the closing ' ==='
    m="${m%% (*}"            # strip the '(annotation)' if present
    [[ -z "$m" ]] && continue
    case "$m" in
      END\ *) ends="${ends}${m#END }"$'\n' ;;
      *)      openings="${openings}${m}"$'\n' ;;
    esac
  done <<< "$(grep -h -E '=== .* ===' "$f" 2>/dev/null || true)"

  while IFS= read -r m; do
    [[ -z "$m" ]] && continue
    grep -qxF "$m" <<< "$ends" || problem "$f" "marker '${m}' has no closing '=== END ${m} ==='"
  done <<< "$(sort -u <<< "$openings")"
  while IFS= read -r m; do
    [[ -z "$m" ]] && continue
    grep -qxF "$m" <<< "$openings" || problem "$f" "marker 'END ${m}' has no opening '=== ${m} ... ==='"
  done <<< "$(sort -u <<< "$ends")"

  # 3. Mutually-exclusive marker pairs (same Terraform resource addresses)
  if grep -qxF "CDR" <<< "$openings" && grep -qxF "CDR_CLOUDLOGS" <<< "$openings"; then
    problem "$f" "both CDR and CDR_CLOUDLOGS markers present — keep exactly one (duplicate resource addresses)"
  fi
  if grep -qxF "CIEM Advanced" <<< "$openings" && grep -qxF "CIEM_ADVANCED_CLOUDLOGS" <<< "$openings"; then
    problem "$f" "both CIEM Advanced and CIEM_ADVANCED_CLOUDLOGS markers present — keep exactly one"
  fi

  # 4. Hardcoded secret-looking literals on credential keys.
  #    Allowed values: var./local. references, ${...} interpolation,
  #    {{...}} handled above, REPLACE_WITH/PASTE_YOUR placeholders.
  #    Skipped with --user-filled: after the user pastes their own key the
  #    literal is expected, and warning on the happy path is noise.
  suspects=""
  if [[ "$USER_FILLED" == "false" ]]; then
    suspects=$(grep -n -E '^[^#]*(api_token|access_key|customerid|secret)[[:space:]"'"'"']*[:=]' "$f" 2>/dev/null || true)
  fi
  if [[ -n "$suspects" ]]; then
    while IFS= read -r hit; do
      [[ -z "$hit" ]] && continue
      lineno="${hit%%:*}"
      content="${hit#*:}"
      # Measure EVERY credential-keyed assignment on the line, taking the value
      # from the delimiter that follows the keyword. Splitting the line on its
      # first delimiter instead misses a literal that is not the first pair:
      #   tags = { Name = "prod", access_key = "AKIA..." }
      #     -> the first pair is `tags`/`Name`, so the real literal never gets
      #        measured at all.
      #
      # The key must *be* an assignment, so it is anchored to line start, `{`
      # or `,` (with an optional YAML `- `). Matching the keyword anywhere on
      # the line instead measures it inside someone else's value:
      #   description = "... export TF_VAR_sysdig_secure_api_token=<token>"
      #     -> the skill's own generated variables.tf warned on every AWS run,
      #        which teaches users to ignore lint. Excluding it by value length
      #        would only work while that placeholder stays short.
      #   This anchor is a heuristic, not a parser: a credential-shaped
      #   assignment sitting immediately after a comma *inside* a string would
      #   still match. Parsing HCL and YAML properly is not worth it in a lint
      #   that must run with no dependencies.
      #
      # The value is a quoted string taken whole, or an unquoted bare token:
      #   api_token = "abc,defghijklmnopqrstuvwxyz"
      #     -> bounding the value at the first `,` measured `"abc` and missed a
      #        comma-bearing literal.
      # The bare branch excludes quotes and whitespace deliberately. ERE is
      # leftmost-longest, so an unbounded fallback out-matched the quoted
      # branch whenever a same-line `# comment` followed the value, and the
      # comment text landed in the value — wrong in both directions:
      #   access_key = "AKIA..."  # TODO: move to var.access_key later
      #     -> `var.` in the comment excluded a real secret as a reference.
      #   access_key = "short"  # replace with the real key
      #     -> the comment padded a 5-char value past the length threshold.
      pairs=$(grep -o -E '(^|[{,])[[:space:]]*(-[[:space:]]+)?[A-Za-z0-9_.-]*(api_token|access_key|customerid|secret)[A-Za-z0-9_.-]*[[:space:]"'"'"']*[:=][[:space:]]*("[^"]*"|'"'"'[^'"'"']*'"'"'|[^,}"'"'"'[:space:]]*)' <<< "$content" || true)
      while IFS= read -r pair; do
        [[ -z "$pair" ]] && continue
        pair="${pair#[\{,]}"                                  # drop the anchor
        pair="${pair#"${pair%%[![:space:]]*}"}"
        pair="${pair#-}"                                       # YAML sequence dash
        pair="${pair#"${pair%%[![:space:]]*}"}"
        key="${pair%%[[:space:]:=]*}"
        key="${key//\"/}"
        key="${key//\'/}"
        rhs="${pair#*[:=]}"
        # Trim surrounding whitespace, then unwrap at most one layer of quotes.
        # Never strip characters out of the value itself: the previous
        # `tr -d ',}'` deleted those from the payload too, so a 20-char literal
        # ending in `}` measured 19 and slipped under the threshold.
        val="${rhs#"${rhs%%[![:space:]]*}"}"
        val="${val%"${val##*[![:space:]]}"}"
        case "$val" in
          '"'*'"'|"'"*"'") val="${val:1:${#val}-2}" ;;
        esac
        # References and placeholders are the required output, not secrets.
        # Matched against the WHOLE value: as substrings, `{{PLACEHOLDER}}` or
        # `var.` pasted in front of a real key hid it from the whole check.
        case "$val" in
          var.*|local.*|*\$\{*) continue ;;
          \{\{*\}\}|REPLACE_WITH*|PASTE_YOUR*) continue ;;
        esac
        if [[ ${#val} -ge 20 ]]; then
          warning "$f" "line ${lineno}: credential key '${key}' has a literal value — freshly generated configs must use a var reference or REPLACE_WITH_ placeholder (fine if the user already pasted their real key)"
        fi
      done <<< "$pairs"
    done <<< "$suspects"
  fi

  [[ $ERRORS -eq $file_errors ]] && echo "OK $f"
done

[[ $ERRORS -eq 0 ]] || exit 1
exit 0

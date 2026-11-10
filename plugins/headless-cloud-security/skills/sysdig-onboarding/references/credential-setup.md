# Credential Setup & Context Detection (Step 2b detail)

Procedural detail for [SKILL.md](../SKILL.md) **Step 2b**. The skill picks the
credential type from the target chosen in Step 1, sets it up, then detects the
user's environment. The prerequisite gate, config-only bypass path, and
identity-pinning rules stay in SKILL.md — they are load-bearing.

## 2b-i. Credential setup (target-dependent)

### For Cloud Accounts (API Token)

The token is stored in `.sysdig-token` — a local file the user edits
directly. The skill NEVER reads its contents; it only `source`s it.

🔴 STRICT — never display `.sysdig-token`. Do not open it with a file-read
tool and do not print any of its lines with `cat`, `head`, `tail`, `grep`,
`sed`, `awk` or `diff` — every line of that output can carry the token, and
anything a command prints enters the conversation. The only operations on it
are:

- **Does it exist and is it non-empty?** `test -s .sysdig-token` (exit code
  0 = yes; prints nothing)
- **Has the user replaced the placeholder?** `grep -c PASTE_YOUR_TOKEN_HERE .sysdig-token`
  (prints only a count: `0` = replaced, `1` = still the placeholder)
- **Use it:** `source .sysdig-token && <command>`
- **Set the region URL:** `scripts/detect-region.sh --save-url` (step 5)

1. If Step 0b detected `has_token`: generate `.sysdig-token` that bridges
   the detected variable (e.g., `export SYSDIG_SECURE_API_TOKEN="${SDC_SECURE_TOKEN}"`)
   instead of asking the user to paste a token. Tell the user:
   "I detected an existing Sysdig token in `$VAR` — using it."
2. Check `echo "${SYSDIG_SECURE_API_TOKEN:+SET}"`. If set, skip to 5.
3. If `.sysdig-token` doesn't exist, create it with your agent's file-write tool:
   ```bash
   # Sysdig Secure API Token — Find at: Sysdig > Settings > API Token
   # SECURITY: chmod 600, git-ignored. Do not commit or share.
   SYSDIG_TOKEN="PASTE_YOUR_TOKEN_HERE"
   export SYSDIG_SECURE_API_TOKEN="$SYSDIG_TOKEN"
   export TF_VAR_sysdig_secure_api_token="$SYSDIG_TOKEN"
   export SYSDIG_BASE_URL=""  # filled automatically after region detection
   ```
   Then `chmod 600 .sysdig-token` and ensure `.gitignore` includes it.
4. Ask the user to paste their token in the file (NEVER in the chat).
   **Returning users:** If `.sysdig-token` already exists, skip to step 5.
5. **Validate and save the region URL.** Run
   `source .sysdig-token && scripts/detect-region.sh --save-url`. On success
   the script itself writes `export SYSDIG_BASE_URL="<detected URL>"` into
   `.sysdig-token` (replacing that line, or appending it if missing) without
   printing the file. Do NOT edit that line yourself — any edit needs the
   file's content, which means reading the token.
   If the token is only in the environment (no `.sysdig-token`), run
   `scripts/detect-region.sh` directly — it reads `SYSDIG_SECURE_API_TOKEN`
   and auto-bridges legacy/MCP aliases (e.g. `SYSDIG_MCP_API_TOKEN`).
6. If **valid**: show the detected region and continue.
7. If **invalid**: ask user to verify. Max 2 retries.

### For Kubernetes / Linux Hosts (Agent Access Key)

These targets use the **Agent Access Key** (Settings → Agent Keys in
Sysdig UI), NOT the Secure API Token. Do NOT ask for or validate the
API Token.

1. **Region detection** — try in order, stop at first hit:
   a. If Step 0b detected `has_url`: derive the region from the URL.
   b. Else if an API Token is already available (env var
      `SYSDIG_SECURE_API_TOKEN`, existing `.sysdig-token` file, or Step 0b
      `has_token`): run `scripts/detect-region.sh` opportunistically — it
      only reads the token, never writes or stores. The script auto-bridges
      legacy/MCP token vars (e.g. `SYSDIG_MCP_API_TOKEN`, `SDC_SECURE_TOKEN`,
      `SECURE_API_TOKEN`) into the canonical name itself, so no manual
      `VAR=… scripts/detect-region.sh` prefix is needed. Do NOT write
      `.sysdig-token` in the K8s/Linux flow. Use the detected region.
   c. Else ask the user for their Sysdig region (see
      [regions.md](regions.md)).
   Do NOT prompt for an API Token just to detect the region — asking the
   user for the region directly is faster.
2. The Agent Access Key will be placed directly in the generated
   configuration (Helm `values.yaml` or `dragent.yaml`) as a placeholder.
   Tell the user: "You'll need your **Agent Access Key** — find it in
   Sysdig UI → Settings → Agent Keys. I'll add a placeholder in the
   config for you to fill in."
3. **Do NOT create `.sysdig-token` for K8s**/Linux-only onboarding.
   Never auto-fetch the Access Key from the API — multiple keys may
   exist, the token may lack permission, or the user may have been given
   a specific admin-provisioned key.

## 2b-ii. Context detection commands (per target)

Run proactively in parallel via a subagent. **Only run `validate_prereqs.sh`
when the provider is already known** (e.g., user said "onboard my AWS
account"); otherwise defer to after Step 3a.

**For Cloud Accounts:**
- `scripts/validate_prereqs.sh <provider> --json` — check required tools
- `aws sts get-caller-identity` — detect AWS account ID, caller ARN, and active profile
- `aws configure list-profiles` — list available AWS profiles
- `gcloud config get-value project` — detect GCP project
- `az account show --query id -o tsv` — detect Azure subscription

**For Kubernetes:**
- `scripts/validate_prereqs.sh kubernetes --json` — check kubectl, helm
- `kubectl config current-context` — detect active cluster
- `kubectl cluster-info` — verify connectivity
- `helm repo list` — check if sysdig repo is added
- `kubectl get ns sysdig-agent --ignore-not-found` — returning user check

**For Linux Hosts:**
- `scripts/validate_prereqs.sh host --json` — check required tools

Pre-fill detected values (account ID, cluster name, etc.) in wizard
options. Skip detection for CLIs that aren't installed.

# Confirmation Flow (Step 5b)

After the discovery interview and before generating configuration, present
a confirmation summary for user review.

**The table is script-rendered.** Write the collected settings to
`.sysdig-recap.tsv` with your agent's file-write tool — first line `target: cloud`,
`target: kubernetes`, or `target: host`, then one
`Setting<TAB>Value<TAB>Source` row per line — and run
`scripts/render-recap.sh .sysdig-recap.tsv`. Show its output **verbatim**.
The script owns the 🔴 STRICT row order, the canonical row schema, and the
markdown table format documented below; it exits with a clear error when a
setting name is unknown or a required row is missing (including
`AWS Profile`/`Caller` on AWS) — fix the rows file and re-run. Only if the
script cannot be run (non-bash client) reproduce the schemas below by hand,
exactly.

## Recap Rendering Rules

These rules are tiered. Drift on a 🔴 STRICT item breaks a user affordance or
account-pinning transparency; 🟡 SOFT items have a prescribed default with
minor variance allowed; 🟢 items are the author's choice.

### 🔴 STRICT — do not drift

1. **Question wording is verbatim** (see [Edit Protocol](#edit-protocol)):
   `Review your configuration. What would you like to do?` Never move
   "Looks good" into the question body — it is an option label only.
2. **Top-level options are verbatim** — three, single-select: `Looks good —
   proceed`, `Edit a setting`, `Start over`. Never drop `Start over`.
   (One other confirmation triad exists — the config-only bypass at the prereq
   gate — and is pinned verbatim in the "Config-only path" subsection of
   `SKILL.md`, not here.)
3. **The edit flow is two-step.** When the user picks `Edit a setting`, present
   the second-level picker — never flatten both steps into one menu.
4. **The row schema is canonical per target type** (tables below; enforced by
   `render-recap.sh`). Do NOT add rows the schema doesn't list. Do NOT omit
   rows except per the omission rules.
5. **Tables are markdown** (pipe-delimited with a separator row; the script
   emits this). Do NOT substitute Unicode box-drawing (`┌─┬─┐`) or ASCII art.

### 🟡 SOFT — minor wording variance OK

- **Intro sentence** before the table — any sentence that clearly transitions
  from the interview to review is fine.

### 🟢 Author's choice

- Section heading style, caption emoji, and the closing sentence after the
  question.

## Confirmation Table Format

The row schemas below are 🔴 STRICT (see rule 4). Add and omit rows only as the
schema and its omission rules allow.

**`Source` column.** Normally one of the step / auto-detect labels shown below.
On the **config-only path** (the user bypassed the prereq gate or asked for
config-only output — see the "Config-only path" subsection in `SKILL.md`), a
value that would normally be auto-detected but couldn't be (missing tool or
credentials) is instead `User-supplied` (the user answered directly) or
`Parameterized` (left as an explicit input for the next stage to fill). Use
those `Source` values so the recap makes clear what was detected versus what
still has to be supplied at apply time.

### Cloud Accounts

| Setting | Value | Source |
|---------|-------|--------|
| Target | Cloud Account | Step 1 |
| Provider | AWS | Step 3a |
| Account ID | 123456789012 | Auto-detected |
| AWS Profile | default | Step 2b |
| Caller | arn:aws:iam::123456789012:user/alice | Step 2b |
| Scope | Single Account | Step 3b |
| Sysdig Region | us1 | Step 2 |
| Capabilities | Foundational + Threat Detection + Advanced Identity + Host Scanning | Step 3d |
| Validated Exposure | Enabled | Step 3d-v |
| Log capture mode | EventBridge | Step 3d-ii |
| Cloud Logs regions | us-east-1, eu-west-1 | Step 3d-ii |
| Host Scanning extras | Container scanning | Step 3d-iii |
| Host Scanning regions | us-east-1, us-west-2 | Step 3d-iii |
| Workload Scanning | ECS + Lambda | Step 3d-iv |
| Backend | Local | Step 3e |

`AWS Profile` and `Caller` are load-bearing for the account-identity-pinning
CHAIN RULE — keep them in the recap so the user can see exactly which account
and profile will be onboarded.

**Omission rules** (the only authorized deviations from the schema):
- Omit `AWS Profile` + `Caller` when the provider is GCP or Azure.
- `Validated Exposure` reads `Enabled` or `Disabled` for AWS, GCP and Azure.
- Omit `Log capture mode` + `Cloud Logs regions` when neither Threat Detection
  nor Advanced Identity Analysis is selected.
- Omit `Host Scanning extras` + `Host Scanning regions` when Host Scanning is
  not selected.
- Omit `Workload Scanning` when Workload Scanning is not selected. When it is,
  the value lists the serverless targets chosen in Step 3d-iv: `ECS`,
  `ECS + Lambda` or `Lambda` for AWS. For GCP and Azure it lists every
  selected workload type (e.g. `Cloud Run, GKE, Cloud Functions`) — see the
  provider notes below.
- **GCP:** the `Account ID` row holds the **Project ID**; `Capabilities` reads
  `Foundational` plus any of `Threat Detection` / `Advanced Identity` /
  `Host Scanning` / `Workload Scanning`. Omit `Log capture mode` +
  `Cloud Logs regions` (GCP CDR is a project-wide Pub/Sub sink — no mode or
  region choice) and `Host Scanning regions`
  (GCP agentless scanning takes no region input). `Host Scanning extras` shows
  the selected scanning types (e.g. `Container scanning, Malware scanning`);
  `Workload Scanning` shows the selected workload types (e.g.
  `Cloud Run, GKE, Cloud Functions`). `Source` is `Step 3d (GCP)`.
- **Azure:** the `Account ID` row holds the **Subscription ID** (show the
  **Tenant ID** alongside); `Capabilities` reads `Foundational` plus any of
  `Threat Detection` / `Host Scanning` / `Workload Scanning`. When Threat
  Detection is selected, show an `Event Hub region` row. Omit `Log capture mode`
  (Azure CDR always uses an Event Hub — no mode choice), `Cloud Logs regions`
  and `Host Scanning regions` (Azure scanning takes no region input),
  and `Advanced Identity` (tenant-only — not offered at single-subscription
  scope). `Host Scanning extras` shows
  `Container scanning` when selected (Azure has no malware type);
  `Workload Scanning` shows the selected workload types (e.g. `Azure Container
  Instances/Apps, Azure Functions, AKS`). `Source` is `Step 3d (Azure)`.

### Kubernetes

| Setting | Value | Source |
|---------|-------|--------|
| Target | Kubernetes | Step 1 |
| Distribution | EKS | Step 4 |
| Cluster Name | prod-cluster | Step 4 |
| Namespace | sysdig-agent | Step 4 |
| Sysdig Region | us1 | Step 2 |
| Features | Runtime, Posture, Vulnerability scanning | Step 4 |
| Windows node coverage | No | Step 4 |

If `Windows node coverage` is `Yes`, only host posture and host vulnerability
scanning apply on Windows nodes; all other features are unavailable there.

**Omission rules** (the only authorized deviations from the schema):
- Omit `Windows node coverage` when the cluster has no Windows nodes.

### Linux Host

| Setting | Value | Source |
|---------|-------|--------|
| Target | Linux Host | Step 1 |
| Distribution | Ubuntu 22.04 | Auto-detected / Step 5 |
| Architecture | x86_64 | Auto-detected |
| Install Method | DEB package | Step 5 |
| Sysdig Region | us1 | Step 2 |
| Feature Profile | Detect & Respond | Step 5 |
| Features | syscall_detections, drift_control, activity_audit, response_actions | Step 5 |
| Driver | kmod | Step 5 |

`Feature Profile` is one of "Detect & Respond", "Posture & Compliance",
"Full Protection", or "Custom". `Driver` is one of `kmod` (default),
`universal_ebpf`, or `legacy_ebpf`. The `Features` row expands to the
features that the chosen profile enables (or the user's individual picks
under `Custom`).

**Omission rules** (the only authorized deviations from the schema):
- Omit `Architecture` when auto-detection wasn't run.
- Omit `Feature Profile` when the `Custom` profile is chosen (the expanded
  `Features` row carries the selection instead).

**Always show `Driver`, including the default `kmod`.** The user was asked about
it, and it is the row with real consequences: `kmod` compiles a kernel module and
needs `dkms` + matching kernel headers, which is where package installs fail
(e.g. Amazon Linux 2023 ships without `dkms` — see
[host-shield.md §6.2](host-shield.md)). Hiding the default deprives the user of
the chance to correct it before install.

## Edit Protocol

🔴 STRICT — the question wording, the three top-level options, and the two-step
structure below are verbatim. Do not flatten the two steps into one menu and do
not drop `Start over`.

Ask a structured question:

```json
{
  "question": "Review your configuration. What would you like to do?",
  "header": "Confirmation",
  "multiSelect": false,
  "options": [
    {"label": "Looks good — proceed", "description": "Generate configuration and run terraform plan"},
    {"label": "Edit a setting", "description": "Change one value without restarting"},
    {"label": "Start over", "description": "Restart the interview from the beginning"}
  ]
}
```

### If "Edit a setting" is selected:

Show only options relevant to the current target type:

**Cloud Accounts:**
```json
{
  "question": "Which setting do you want to change?",
  "header": "Edit Setting",
  "multiSelect": false,
  "options": [
    {"label": "Provider"},
    {"label": "Account / Profile"},
    {"label": "Scope"},
    {"label": "Region"},
    {"label": "Capabilities"},
    {"label": "Validated Exposure"},
    {"label": "Log capture mode"},
    {"label": "Per-feature regions"},
    {"label": "Backend"}
  ]
}
```

**Kubernetes:**
```json
{
  "question": "Which setting do you want to change?",
  "header": "Edit Setting",
  "multiSelect": false,
  "options": [
    {"label": "Distribution"},
    {"label": "Cluster name"},
    {"label": "Namespace"},
    {"label": "Region"},
    {"label": "Features"}
  ]
}
```

**Linux Host:**
```json
{
  "question": "Which setting do you want to change?",
  "header": "Edit Setting",
  "multiSelect": false,
  "options": [
    {"label": "Distribution"},
    {"label": "Install method"},
    {"label": "Region"},
    {"label": "Feature profile"},
    {"label": "Driver"}
  ]
}
```

Then:
1. Re-present ONLY the original wizard dialog for that setting
2. After they answer, update the confirmation table
3. Re-display the updated table
4. Ask for confirmation again
5. Do NOT restart the interview from Step 1

For **Account / Profile**, re-run the Step 2b-ii identity-pinning flow
(switch `AWS_PROFILE` / `gcloud config set project` / `az account set`,
re-detect, and re-confirm the account/project and caller) rather than a single
wizard dialog — then update the `Account ID` row and, on AWS, the `AWS Profile`
and `Caller` rows together.

For **Capabilities**, re-run both turns of Step 3d — the gateway (3d (a)) and,
if the user keeps optionals, the multi-select (3d (b)) — rather than a single
dialog, then re-resolve any dependent sub-steps (log capture, host scanning
extras, per-feature regions, Lambda/Workload scanning) that
the new selection adds or removes.

For **Validated Exposure**, re-ask Step 3d-v and update `{{VALIDATED_EXPOSURE_ENABLED}}`
and the `Validated Exposure` row. Editing **Capabilities** does not change it. Editing
**Scope** does: re-ask Step 3d-v with the picker for the new scope (single or
organization), because the organization question tells the user the setting
reaches every member account.

## Don'ts

Each rule blocks a specific observed drift:

- Do NOT put "Looks good" in the question body — it is an option label only.
- Do NOT flatten the two-step edit flow into a single menu.
- Do NOT drop the `Start over` top-level option.
- Do NOT add rows the schema doesn't list.
- Do NOT omit rows except per the omission rules above.
- Do NOT swap the markdown table for ASCII/Unicode box-drawing art.

## Ambiguity Check (Pre-Generation Gate)

Before proceeding to generation, verify completeness:

| Condition | Resolution |
|-----------|-----------|
| Threat Detection selected but no Cloud Logs regions chosen | Ask the Cloud Logs region question (resolves `EVENT_BRIDGE_REGIONS` in EventBridge mode or `CLOUD_LOGS_REGIONS` in CloudTrail/S3 mode) |
| Advanced Identity Analysis selected but Threat Detection not | Enable the CDR (Cloud Logs) block anyway — it supplies the data — and tell the user Cloud Logs is being enabled for it |
| Host Scanning selected but no Host Scanning regions chosen | Ask the Host Scanning region question (resolves `AGENTLESS_SCANNING_REGIONS`) |
| Cloud account (AWS, GCP or Azure) and `VALIDATED_EXPOSURE_ENABLED` unresolved | Ask Step 3d-v and resolve to the bare word `true` or `false` (the template already quotes the placeholder) — never leave the placeholder or drop the key |
| Host Scanning selected but `AGENTLESS_SCANNING_FLAGS` unresolved | Resolve to the chosen flags map or `{}` (host disks only) — never leave the placeholder |
| Org scope from member account | Warn: "You appear to be on a member account. Org-scope requires management account credentials." |
| Backend mismatches provider | Warn: "S3 backend with Azure provider — is this intentional?" |
| CloudTrail/S3 mode but no trail info | Ask for trail name (or bucket ARN + SNS topic ARN), whether to create the SNS topic (`create_topic`), the SNS topic region, the KMS key if the bucket is encrypted, and the Cloud Logs regions — every `*_CLOUDLOGS` placeholder must be resolved |
| EventBridge mode and `{{EVENT_BRIDGE_EVENT_PATTERN}}` still present | This is an **optional, delete-by-default** placeholder. If the user did **not** customize log sources (Default Setup), **delete** the placeholder line and its comment block entirely. If they did, resolve it to the `event_pattern = <<-EOF … EOF` block (see [log-source-customization.md](log-source-customization.md)). Never leave the literal `{{…}}` token and never emit an empty `event_pattern`. |

If any ambiguity exists, resolve it before allowing generation to proceed.
Show: `**Configuration completeness:** 100%` (or the specific missing items).

# Interview Questions Reference

Structured-question JSON specifications (header, question, options,
`multiSelect`) for each step of the discovery interview. Pass them to your
agent's structured-question tool, or render them as a numbered plain-text list
when it has none — see `agent-capabilities.md`.
SKILL.md references this file instead of embedding JSON inline.

## Picker rules (apply to every question in this file)

🔴 STRICT — these hold for every picker below, and for any picker you add:

1. **Render each picker as written.** The question text, `header`,
   `multiSelect` value, option labels and their order are all normative. Do not
   paraphrase labels, reorder them, drop options, or invent new ones.
2. **Never merge two pickers into one.** Where a step specifies a gateway
   question plus a follow-up, ask them as two separate turns. Collapsing them
   destroys the opt-out semantics.
3. **No opt-out option inside a `multiSelect: true` picker.** An additive
   multi-select carries additive options only — never add "None",
   "Foundational only", "… only", "No thanks", "No extras" or "Skip" to one.
   Ticking an opt-out alongside add-ons is self-contradictory. An opt-out
   belongs in a preceding single-select gateway; where a step has no gateway,
   **an empty selection is the opt-out** and the step says what it resolves to.
4. **No per-option "(Recommended)" tag in an additive multi-select** — the
   recommendation belongs on the gateway (see Step 3d (a)).

---

## Step 1: Target & Mode

Ask **one structured question** for the target. Guided mode is the default
— do NOT ask the user to choose a mode.

```json
{
  "question": "What type of infrastructure do you want to connect to Sysdig?",
  "header": "Target",
  "multiSelect": false,
  "options": [
    {"label": "Cloud Account", "description": "Connect your cloud account to Sysdig"},
    {"label": "Kubernetes", "description": "Deploy Sysdig Shield on a K8s cluster"},
    {"label": "Linux Host", "description": "Install Host Shield on standalone Linux servers"}
  ]
}
```

After the user selects a target, add a brief note:

> If you'd prefer to provide all configuration at once instead of answering
> step by step, just tell me and I'll switch to autonomous mode.

Then continue to Step 2 (guided mode).

Each session handles **one target**. For multiple, complete the current one
and suggest a new session for the next.

---

## Step 3a: Cloud Provider

```json
{
  "question": "Which cloud provider are you connecting?",
  "header": "Provider",
  "multiSelect": false,
  "options": [
    {"label": "AWS", "description": "Amazon Web Services"},
    {"label": "GCP", "description": "Google Cloud Platform"},
    {"label": "Azure", "description": "Microsoft Azure"}
  ]
}
```

---

## Step 3b: Scope

Adapt labels per provider (Account/Project/Subscription, Organization/Org/Tenant):

```json
{
  "question": "Single account or entire organization?",
  "header": "Scope",
  "multiSelect": false,
  "options": [
    {"label": "Single Account", "description": "One AWS account / GCP project / Azure subscription"},
    {"label": "Organization", "description": "All accounts under your AWS Org / GCP Org / Azure Tenant"}
  ]
}
```

For **organizations**, follow up with:
- Management account ID confirmation
- Include/exclude account filters (optional)
- Auto-onboarding for new accounts (yes/no)

Auto-detect the account/project/subscription ID from active credentials
(e.g., `aws sts get-caller-identity`). **Always show the detected ID and
ask the user to confirm.**

---

## Step 3c: Preflight Checklist

**This step is context-aware.** Cross-reference what was already verified:
- **Token + region** validated in Step 0b → skip Sysdig items
- **`validate_prereqs.sh`** passed in Step 2b → skip CLI + Terraform items
- **`aws sts get-caller-identity`** succeeded → skip credentials item

**If ALL items are already verified, skip this step entirely** and proceed
to Step 3d. Do NOT show a redundant checklist for things already confirmed.

If some items remain unverified, show **only** the unchecked items:

> **Before we continue, make sure you have ready:**
>
> **Credentials & access:** *(skip if detected in Step 2b)*
> - [ ] Cloud CLI installed and authenticated (`aws` / `gcloud` / `az`)
> - [ ] Sufficient IAM permissions (org scope -> management account access)
>
> **Sysdig:** *(skip if validated in Step 0b)*
> - [ ] Sysdig Secure API token (Settings -> API Token in Sysdig)
> - [ ] Your Sysdig SaaS region URL
>
> **Tools:** *(skip if validate_prereqs.sh passed)*
> - [ ] Terraform >= 1.10.0
>
> **Optional (for remote state):**
> - [ ] S3 bucket / GCS bucket / Azure Storage for Terraform state
>
> Do you have everything ready, or do you need help with any of these?

See [permissions.md](permissions.md) for detailed permission requirements.
**Do NOT proceed until the user confirms** (only when checklist is shown).

---

## Step 3d: Security Capabilities

> **GCP:** skip the AWS gateway + picker in 3d(a)/3d(b) and the AWS-only
> sub-steps (3d-ii log capture, 3d-iv Lambda). Use the
> **Step 3d (GCP)** section below — the foundational set (Inventory, Posture &
> Compliance, Basic Identity Capabilities) is always included; only **Host
> Scanning** and **Workload Scanning** are optional.
>
> **Azure:** skip the AWS gateway + picker in 3d(a)/3d(b) and the AWS-only
> sub-steps. Use the **Step 3d (Azure)** section below — the foundational set
> (Inventory, Posture & Compliance, Basic Identity Capabilities) is always
> included; **Threat Detection**, **Host Scanning**, and **Workload Scanning**
> are optional. Azure has **no Advanced Identity Analysis** at single-subscription
> scope (tenant-only).

The first connection always establishes a read-only trust relationship with
your cloud account. Then ask in two clean turns: first whether to add optional
capabilities at all, and only if yes, which ones.

Briefly explain before showing the first selector:

> **First, I'll set up the foundational connection** — this creates a read-only trust
> relationship with your cloud account. It always includes **CSPM** (cloud
> security posture management) and **CIEM Basic** (identity & entitlement
> analysis): asset inventory, posture and compliance checks, and foundational
> identity analysis. This is always included.
>
> On top of that, you can optionally enable:
>
> **Threat Detection** — Captures cloud audit logs (Cloud Logs) for real-time
> threat detection.
>
> **Advanced Identity Analysis** — Usage-based, least-privilege analysis on top
> of the foundational identity analysis. Builds on Threat Detection's Cloud Logs
> data.
>
> **Host Scanning (Agentless)** — Scans your hosts for known vulnerabilities
> without installing agents. Optional container-scanning and malware (Preview)
> sub-options.
>
> **Workload Scanning** — Scans container images in ECS tasks and Lambda
> functions for vulnerabilities (AWS only).
>

### Step 3d (a) — gateway question (single-select)

```json
{
  "question": "Add optional capabilities on top of the foundational connection?",
  "header": "Optional capabilities",
  "multiSelect": false,
  "options": [
    {"label": "Yes, let's add some", "description": "Choose from the available capabilities next (recommended for production coverage)"},
    {"label": "No, foundational is enough", "description": "Continue with just the read-only foundational connection"}
  ]
}
```

If the user picks "No, foundational is enough", skip Step 3d (b) and every
capability-dependent sub-step below (3d-ii log capture, 3d-iii host scanning
sub-options & regions, Lambda scanning). Still show the DSPM
note at the end of this step, then ask Step 3d-v (Validated Exposure) and
proceed to Step 3e.

### Step 3d (b) — capability multi-select (only if gateway = Yes)

The picker mirrors the Sysdig AWS UI guided onboarding, which presents Cloud
Logs as two sections — **Threat Detection** and **Advanced Identity Analysis**.

🔴 Two separate turns — 3d (a) then 3d (b). Do **not** fold them into one
picker, and do **not** carry the gateway's "No, foundational is enough" answer
(or any "Foundational only" / "None" variant) into this multi-select as a
checkbox: the opt-out lives only in 3d (a). Render the four labels below
exactly as written. See [Picker rules](#picker-rules-apply-to-every-question-in-this-file).

```json
{
  "question": "Which capabilities do you want to enable?",
  "header": "Capabilities",
  "multiSelect": true,
  "options": [
    {"label": "Threat Detection", "description": "Capture cloud audit logs (Cloud Logs) for real-time threat detection"},
    {"label": "Advanced Identity Analysis", "description": "Usage-based least-privilege analysis; builds on Threat Detection's data"},
    {"label": "Host Scanning (Agentless)", "description": "Scan hosts for vulnerabilities, no agents"},
    {"label": "Workload Scanning", "description": "Scan ECS + Lambda container images (AWS only)"}
  ]
}
```

Do NOT tag individual capabilities "(Recommended)" — each carries its own
trade-offs (cost, data volume) that depend on the user's situation. The
"recommended for production coverage" signal lives on the gateway "Yes" option
in 3d (a). As prose, you may note that enabling all available capabilities
gives the most comprehensive coverage, but never pre-label any single option.

**Provider scope of this picker:** Workload Scanning as framed here (ECS/Lambda)
is **AWS-specific**. For **GCP**, do NOT use this picker — use the **Step 3d
(GCP)** section below (Threat Detection, Advanced Identity Analysis, Host
Scanning, Workload Scanning). For **Azure**, do NOT use this picker either — use
the **Step 3d (Azure)** section below (Threat Detection, Host Scanning, Workload
Scanning; no Advanced Identity Analysis at single-subscription scope).

**Selection dependencies — resolve before generating Terraform:**
- **Advanced Identity Analysis** needs the Cloud Logs data source. If it is
  selected without Threat Detection, enable Threat Detection's CDR block anyway
  (the advanced-CIEM Terraform references the Cloud Logs module) and tell the
  user Cloud Logs is being enabled because Advanced Identity Analysis builds on
  it. This also means the log-capture-method and Cloud Logs region questions
  below still apply.

After the capability selection (or after the gateway, if the user declined
optionals), mention what else exists so users don't miss capabilities this
guided flow doesn't configure:

> One more capability can be enabled in the Sysdig UI — **DSPM** (data security
> posture management), which can't be configured through Terraform. Tell me if
> you want it and I'll point you to the setup.

For the capability-to-feature mapping and template markers, see
[features.md](features.md).

---

## Step 3d (GCP): Capabilities & Sub-options

For **GCP**, the foundational set — Inventory, Posture & Compliance, and Basic
Identity Capabilities — is always included (no gateway needed). Optional add-ons
are **Threat Detection**, **Advanced Identity Analysis**, **Host Scanning**, and
**Workload Scanning** (all GA in the GCP modules). Use this section instead of
3d(a)/3d(b) and the AWS-only sub-steps.

### GCP capability multi-select

```json
{
  "question": "Which additional coverage do you want to enable?",
  "header": "Coverage",
  "multiSelect": true,
  "options": [
    {"label": "Threat Detection", "description": "Real-time detection from GCP Audit Logs via a Pub/Sub push subscription"},
    {"label": "Advanced Identity Analysis", "description": "Usage-based least-privilege analysis; builds on Threat Detection's log data"},
    {"label": "Host Scanning", "description": "Agentless vulnerability scanning; requires permission to create temporary snapshots"},
    {"label": "Workload Scanning", "description": "Scan running containers and Artifact Registry images"}
  ]
}
```

Foundational (CSPM + Basic Identity) is always generated regardless of this
selection; if the user enables none, generate the foundational-only config.
Keep only the selected feature markers: `CDR` (Threat Detection), `CIEM Advanced`
(Advanced Identity), `VM` (Host Scanning), `WORKLOAD_SCANNING`; strip the rest.

**Dependency:** Advanced Identity Analysis needs the CDR (Pub/Sub) data source —
if it is selected without Threat Detection, enable CDR anyway (keep the `CDR`
block; the advanced-CIEM resource references the pub-sub component) and tell the
user Threat Detection is being enabled because Advanced Identity builds on it.
Unlike AWS, GCP CDR has **no** log-capture-method or region question — the
Pub/Sub sink is project-wide.

> **Domain-wide delegation note:** *Workspace* directory insights (user/group
> membership, MFA/login reporting) require a manual domain-wide-delegation step
> after apply — see [gcp.md §5](gcp.md). This is **separate** from Advanced
> Identity Analysis (the CDR-backed CIEM upgrade above); mention it, but it is
> not a wizard question.

### GCP Host Scanning → Select Scanning Types

If **Host Scanning** is selected, ask which scanning types. Maps to
`{{AGENTLESS_SCANNING_FLAGS}}`. The GCP agentless-scan resource takes **no
region input** (unlike AWS), so there is no region question.

Host-disk vulnerability scanning is what Host Scanning always does; these are
additive extras on top of it. Both extras are optional, so **no "host disks
only" option belongs in this picker** (Picker rule 3) — an empty selection
already means host disks only.

```json
{
  "question": "Select scanning types (you can change these later).",
  "header": "Scanning types",
  "multiSelect": true,
  "options": [
    {"label": "Container scanning", "description": "Also scan running containers found on the host"},
    {"label": "Malware scanning (Preview)", "description": "Detect malware on host file systems — Preview"}
  ]
}
```

Resolve the flags map: include `"SCANNING_HOST_CONTAINER_ENABLED" : "true"` when
Container scanning is selected and `"SCANNING_MALWARE_ENABLED" : "true"` when
Malware scanning is selected. If the user selects neither, resolve to an empty
map `{}` — host disks only.

### GCP Workload Scanning → Select Workload Types

If **Workload Scanning** is selected, ask which workload types (choose at least
one). Keep each selected type's feature sub-block in the template and remove the
unselected ones.

```json
{
  "question": "Choose at least one workload type to scan.",
  "header": "Workload types",
  "multiSelect": true,
  "options": [
    {"label": "Cloud Run", "description": "Scan Cloud Run container workloads"},
    {"label": "Cloud Functions", "description": "Scan Cloud Functions"},
    {"label": "GKE", "description": "Scan GKE workloads"}
  ]
}
```

Keep the UI labels (Cloud Run / Cloud Functions / GKE — GCP-native names).
Marker mapping: Cloud Run → `WORKLOAD_CLOUDRUN` (CONTAINERS), GKE →
`WORKLOAD_GKE` (KUBERNETES), Cloud Functions → `WORKLOAD_FUNCTIONS` (FUNCTIONS).
At least one sub-block must remain.

---

## Step 3d (Azure): Capabilities & Sub-options

For **Azure** (single subscription), the foundational set — Inventory, Posture &
Compliance, and Basic Identity Capabilities — is always included (no gateway
needed). Optional add-ons are **Threat Detection**, **Host Scanning**, and
**Workload Scanning**. Azure has **no** Advanced Identity Analysis at
single-subscription scope (usage-based CIEM is tenant-only). Use this section
instead of 3d(a)/3d(b) and the AWS-only sub-steps.

### Azure capability multi-select

```json
{
  "question": "Which additional coverage do you want to enable?",
  "header": "Coverage",
  "multiSelect": true,
  "options": [
    {"label": "Threat Detection", "description": "Real-time detection from Azure Activity Logs streamed via an Event Hub"},
    {"label": "Host Scanning", "description": "Agentless VM vulnerability scanning; requires the Microsoft.ManagedServices provider and permission to create temporary snapshots"},
    {"label": "Workload Scanning", "description": "Scan container images across Azure Container Instances/Apps, Azure Functions, and AKS"}
  ]
}
```

Foundational (CSPM + Basic Identity) is always generated regardless of this
selection; if the user enables none, generate the foundational-only config. Keep
only the selected feature markers: `CDR` (Threat Detection), `VM` (Host
Scanning), `WORKLOAD_SCANNING`; strip the rest. There is **no `CIEM Advanced`
block for Azure single subscription** — do not offer or generate it.

> **Entra ID admin consent:** Basic Identity reads Entra ID directory data only
> after a manual admin-consent step in the Azure portal after apply (see
> [azure.md §5](azure.md#5-basic-identity-entra-id-admin-consent)). Mention it,
> but it is not a wizard question.

### Azure Threat Detection → Event Hub region

If **Threat Detection** is selected, ask for the Azure region for the Event Hub
infrastructure. This resolves `{{AZURE_REGION}}` on the `event-hub` module —
Azure CDR **does** need a region (unlike GCP's project-wide Pub/Sub sink).

```json
{
  "question": "Which Azure region should host the Event Hub for log streaming?",
  "header": "Event Hub region",
  "multiSelect": false,
  "options": [
    {"label": "eastus", "description": "East US"},
    {"label": "westeurope", "description": "West Europe"},
    {"label": "westus2", "description": "West US 2"}
  ]
}
```

Offer common regions but accept any valid Azure region name the user provides.
Only ask this when Threat Detection is selected; omit it otherwise.

### Azure Host Scanning → Select Scanning Types

If **Host Scanning** is selected, ask which scanning types. Maps to
`{{AGENTLESS_SCANNING_FLAGS}}`. Azure offers **only Container scanning** (no
malware scanning type). The Azure agentless resource takes **no region input**.

Azure has exactly one extra here, so this is a **single-select** — an opt-out
alongside an add-on is only legal in a single-select (Picker rule 3).

```json
{
  "question": "Select scanning types (you can change these later).",
  "header": "Scanning types",
  "multiSelect": false,
  "options": [
    {"label": "Container scanning", "description": "Also scan running containers found on the host"},
    {"label": "Host disks only", "description": "No extras — host-disk vulnerabilities only"}
  ]
}
```

Resolve the flags map: `"SCANNING_HOST_CONTAINER_ENABLED" : "true"` when Container
scanning is selected (else `"false"`), and **always**
`"SCANNING_MALWARE_ENABLED" : "false"` (no malware type on Azure). Example:
`{ "SCANNING_HOST_CONTAINER_ENABLED" : "true", "SCANNING_MALWARE_ENABLED" : "false" }`.

### Azure Workload Scanning → Select Workload Types

If **Workload Scanning** is selected, ask which workload types (choose at least
one). Keep each selected type's feature sub-block and remove the unselected ones;
set the module toggles `aks_enabled` / `functions_enabled` to match.

```json
{
  "question": "Choose at least one workload type to scan.",
  "header": "Workload types",
  "multiSelect": true,
  "options": [
    {"label": "Azure Container Instances and Container Apps", "description": "Scan ACA/ACI container workloads"},
    {"label": "Azure Functions", "description": "Scan Azure Functions (containers only)"},
    {"label": "Azure Kubernetes Service", "description": "Scan AKS workloads"}
  ]
}
```

Marker + toggle mapping:
- ACA/ACI → `WORKLOAD_ACA_ACI` (`FEATURE_SECURE_WORKLOAD_SCANNING_CONTAINERS`); base module, no toggle.
- AKS → `WORKLOAD_AKS` (`FEATURE_SECURE_WORKLOAD_SCANNING_KUBERNETES`); set `aks_enabled = true`.
- Azure Functions → `WORKLOAD_FUNCTIONS` (`FEATURE_SECURE_WORKLOAD_SCANNING_FUNCTIONS`); set `functions_enabled = true`.

Set `{{AKS_ENABLED}}` / `{{FUNCTIONS_ENABLED}}` to `true`/`false` per the
selection. At least one sub-block must remain.

---

## Step 3d-ii: Log Capture Method (AWS only)

If **Threat Detection** or **Advanced Identity Analysis** is selected AND
provider is AWS (Advanced Identity Analysis requires the same Cloud Logs data):

```json
{
  "question": "How should cloud audit logs be captured?",
  "header": "Log capture",
  "multiSelect": false,
  "options": [
    {"label": "EventBridge", "description": "Recommended — simpler setup, no existing trail needed"},
    {"label": "CloudTrail/S3", "description": "For existing trails or data event needs"}
  ]
}
```

Default to EventBridge. If CloudTrail/S3, see [aws.md](aws.md) for the full set
of sub-questions (trail name, bucket/SNS ARN, **SNS topic creation, SNS topic
region**, KMS) — they resolve `{{CLOUDTRAIL_BUCKET_ARN}}`,
`{{CLOUDTRAIL_SNS_TOPIC_ARN}}`, `{{CREATE_SNS_TOPIC}}`, `{{SNS_TOPIC_REGION}}`,
and (optionally) `{{KMS_KEY_ARN}}`. Resolve all of them — never emit a literal
`{{...}}` token.

### Cloud Logs Region Selection

Ask which regions to monitor for **Cloud Logs / threat detection** — for
**either** capture method. The answer resolves `{{EVENT_BRIDGE_REGIONS}}` in
EventBridge mode or `{{CLOUD_LOGS_REGIONS}}` in CloudTrail/S3 mode (two distinct
template placeholders). These are the Cloud Logs regions only, kept separate
from Host Scanning regions (asked in Step 3d-iii). EventBridge is available in
**every AWS commercial (standard
partition) region**, so the user is not limited to the list below — these are
common choices for quick selection. Offer "Other" (or accept free-text) for any
region code not shown (e.g. `ca-central-1`, `sa-east-1`, `ap-northeast-1`,
`ap-south-1`). AWS GovCloud (`us-gov-*`) and China (`cn-*`) use separate region
codes — if the customer operates there, confirm the specific region code with them.

```json
{
  "question": "Which AWS regions should be monitored for cloud audit logs (threat detection)?",
  "header": "Cloud Logs regions",
  "multiSelect": true,
  "options": [
    {"label": "us-east-1", "description": "US East (N. Virginia) — recommended, captures global events"},
    {"label": "us-east-2", "description": "US East (Ohio)"},
    {"label": "us-west-2", "description": "US West (Oregon)"},
    {"label": "eu-west-1", "description": "Europe (Ireland)"},
    {"label": "eu-central-1", "description": "Europe (Frankfurt)"},
    {"label": "ap-southeast-1", "description": "Asia Pacific (Singapore)"},
    {"label": "ap-southeast-2", "description": "Asia Pacific (Sydney)"},
    {"label": "ap-northeast-1", "description": "Asia Pacific (Tokyo)"},
    {"label": "All active regions", "description": "Monitor every region with active resources"}
  ]
}
```

**Note:** Always include `us-east-1` — it captures global service events
(IAM, CloudFront, Route53, etc.) regardless of where resources run. The options
above are not exhaustive; any AWS commercial region that hosts resources can be
monitored — use "Other" to add a region code that isn't listed.

**"All active regions" precedence:** it is a superset, not an add-on. If the
user ticks it alongside individual regions, it wins — resolve to all active
regions, ignore the individual ticks, and say so in one line rather than
re-asking.

### Select Sources (optional, EventBridge only)

The UI's EventBridge setup has an optional **"Select Sources"** step to customize
which log sources are forwarded. **Default Setup (all sources) is recommended**
and is what the template generates when `{{EVENT_BRIDGE_EVENT_PATTERN}}` is
omitted — do **not** raise this unless the user wants to trim log
volume/cost. If they do, load
[log-source-customization.md](log-source-customization.md) for the picker, the
checkbox→`event_pattern` mapping, and the generation algorithm. Not applicable to
the CloudTrail/S3 capture method or to GCP/Azure.

---

## Step 3d-iii: Host Scanning Sub-options & Regions (AWS)

If **Host Scanning (Agentless)** is selected AND provider is AWS, ask two
follow-ups (sub-options + regions). For **GCP**, the agentless-scan resource
takes the same container/malware flags — asked in the **Step 3d (GCP)** section
(Select Scanning Types) — but **no region input**, so use that section instead.
For **Azure**, the agentless feature resource takes a Container-scanning flag
(malware is always off) — asked in the **Step 3d (Azure)** section (Select
Scanning Types) — and **no region input**, so use that section instead.

### Sub-options (container & malware scanning)

These map to **feature flags** on `FEATURE_SECURE_AGENTLESS_SCANNING`, not
module variables. They resolve `{{AGENTLESS_SCANNING_FLAGS}}` to a map literal.

```json
{
  "question": "Host Scanning covers host-disk vulnerabilities. Enable any of these extras?",
  "header": "Host Scanning extras",
  "multiSelect": true,
  "options": [
    {"label": "Container scanning", "description": "Also scan running containers found on the host"},
    {"label": "Malware scanning (Preview)", "description": "Detect malware on scanned hosts — Preview feature"}
  ]
}
```

Both extras are optional and host-disk scanning happens regardless, so **no
"host disks only" option belongs in this picker** (Picker rule 3) — an empty
selection already means host disks only.

Resolve the flags map: include `"SCANNING_HOST_CONTAINER_ENABLED" : "true"` when
Container scanning is selected and `"SCANNING_MALWARE_ENABLED" : "true"` when
Malware scanning is selected. If the user selects neither, resolve to an empty
map `{}` — host disks only. Recommend enabling Container scanning for fuller
coverage.

### Host Scanning regions

Ask which regions to scan — this is a **separate** question from Cloud Logs
regions and resolves `{{AGENTLESS_SCANNING_REGIONS}}`. Same region guidance as
above (any AWS commercial region; "Other" for unlisted codes), including the
"All active regions" precedence rule — it is a superset and wins over
individual ticks.

```json
{
  "question": "Which AWS regions should Host Scanning cover?",
  "header": "Host Scanning regions",
  "multiSelect": true,
  "options": [
    {"label": "us-east-1", "description": "US East (N. Virginia)"},
    {"label": "us-east-2", "description": "US East (Ohio)"},
    {"label": "us-west-2", "description": "US West (Oregon)"},
    {"label": "eu-west-1", "description": "Europe (Ireland)"},
    {"label": "eu-central-1", "description": "Europe (Frankfurt)"},
    {"label": "ap-southeast-1", "description": "Asia Pacific (Singapore)"},
    {"label": "ap-southeast-2", "description": "Asia Pacific (Sydney)"},
    {"label": "All active regions", "description": "Scan every region with active resources"}
  ]
}
```

---

## Step 3d-iv: Serverless workload scanning

If **Workload Scanning** is selected, ask which serverless workload types to
scan. Show only the options that apply to the chosen provider. Scanning is
**agentless**: no sidecar, Dockerfile change, ECS task-definition mutation, or
CloudFormation macro is involved. What each selection changes in the generated
Terraform is in the mapping table below.

**AWS** (Lambda + ECS/Fargate):

```json
{
  "question": "Which serverless workloads should Sysdig scan for vulnerabilities?",
  "header": "Serverless scanning",
  "multiSelect": true,
  "options": [
    {"label": "Lambda functions", "description": "Scan AWS Lambda functions for vulnerabilities"},
    {"label": "ECS / Fargate tasks", "description": "Scan ECS / Fargate task container images for vulnerabilities"}
  ]
}
```

**GCP** (Cloud Run):

```json
{
  "question": "Which serverless workloads should Sysdig scan for vulnerabilities?",
  "header": "Serverless scanning",
  "multiSelect": true,
  "options": [
    {"label": "Cloud Run services", "description": "Scan GCP Cloud Run services for vulnerabilities"}
  ]
}
```

These three (Lambda, ECS/Fargate, Cloud Run) are the only serverless
workload-scanning targets that exist. Recommend enabling all available options
for comprehensive coverage.

**Carry the answer into generation (AWS).** The AWS templates express these
selections as a module input plus per-target feature resources inside the
`WORKLOAD_SCANNING` block, so the answer resolves one placeholder and decides
two sub-markers:

| Selection | `{{LAMBDA_SCANNING_ENABLED}}` | Markers to keep |
|---|---|---|
| ECS / Fargate only | `false` | `WORKLOAD_ECS` — remove `WORKLOAD_LAMBDA` |
| Lambda only | `true` | `WORKLOAD_LAMBDA` — remove `WORKLOAD_ECS` |
| Both | `true` | keep both |

Do **not** leave the `FUNCTIONS` feature resource in place with
`lambda_scanning_enabled = false` — the module only grants the role its
`lambda:*` permissions when that flag is true, so the combination produces
Lambda scans that fail on access. Full rationale and the underlying cloud-side
config keys are in
[features.md](features.md#serverless-workload-scanning-aws-terraform).

For **GCP**, the same shape already applies: keep the `WORKLOAD_CLOUDRUN`
sub-marker inside the GCP `WORKLOAD_SCANNING` block (alongside `WORKLOAD_GKE` /
`WORKLOAD_FUNCTIONS` for the other workload types) and remove the ones the user
did not select. The GCP module has no per-target variable, so there is no
placeholder to resolve there.

---

## Step 3d-v: Validated Exposure

Ask for every AWS, GCP and Azure cloud account, single or organization scope,
whatever was chosen in Step 3d — it is an option of the foundational Posture
feature. Do not offer it for IBM Cloud or OCI. Single-select, asked as its own
turn.

Briefly explain before showing it:

> **Validated Exposure** confirms which of your internet-facing endpoints are
> actually reachable. Enabling it authorizes Sysdig to actively probe those
> endpoints from Sysdig scanner IPs. It is off unless you turn it on.

**Single account / project / subscription:**

```json
{
  "question": "Enable Validated Exposure on this account?",
  "header": "Exposure",
  "multiSelect": false,
  "options": [
    {"label": "Enable Validated Exposure", "description": "Sysdig actively probes internet-facing endpoints to confirm which exposures are reachable"},
    {"label": "Not now", "description": "Posture runs without active probing"}
  ]
}
```

**Organization / tenant scope** — the flag is set on the management account and
applies to every member account, so the question says so:

```json
{
  "question": "Enable Validated Exposure for the organization? It applies to every member account.",
  "header": "Exposure",
  "multiSelect": false,
  "options": [
    {"label": "Enable Validated Exposure", "description": "Sysdig actively probes internet-facing endpoints in every member account to confirm which exposures are reachable"},
    {"label": "Not now", "description": "Posture runs without active probing"}
  ]
}
```

Resolve `{{VALIDATED_EXPOSURE_ENABLED}}` to `true` for "Enable Validated
Exposure" and `false` for "Not now". Write the bare word: the template already
wraps the placeholder in quotes, so the result is `"true"` / `"false"`. Never
remove the key or leave the placeholder.

---

## Step 3e: Terraform Backend

Only show backend options that match the user's cloud provider. Do NOT offer
backends from other providers (e.g., don't show GCS/Azure for an AWS user).

**AWS:**
```json
{
  "question": "Where should Terraform store its state?",
  "header": "Backend",
  "multiSelect": false,
  "options": [
    {"label": "Local", "description": "Simple, no setup — good for testing (no locking/backup)"},
    {"label": "S3", "description": "AWS S3 bucket with native locking"}
  ]
}
```

**GCP:**
```json
{
  "question": "Where should Terraform store its state?",
  "header": "Backend",
  "multiSelect": false,
  "options": [
    {"label": "Local", "description": "Simple, no setup — good for testing (no locking/backup)"},
    {"label": "GCS", "description": "Google Cloud Storage bucket"}
  ]
}
```

**Azure:**
```json
{
  "question": "Where should Terraform store its state?",
  "header": "Backend",
  "multiSelect": false,
  "options": [
    {"label": "Local", "description": "Simple, no setup — good for testing (no locking/backup)"},
    {"label": "Azure Storage", "description": "Azure Storage Account container"}
  ]
}
```

See [terraform-backends.md](terraform-backends.md).

> **Pre-fill:** If `environment.yaml` has defaults for features or backend,
> confirm with user instead of asking from scratch.

# Interview Questions Reference

AskUserQuestion JSON specifications for each step of the discovery interview.
SKILL.md references this file instead of embedding JSON inline.

---

## Step 1: Target & Mode

Use **one AskUserQuestion call** for the target. Guided mode is the default
— do NOT ask the user to choose a mode.

```json
{
  "question": "What type of infrastructure do you want to connect to Sysdig?",
  "header": "Target",
  "multiSelect": false,
  "options": [
    {"label": "Cloud Account", "description": "Connect your cloud account to Sysdig"},
    {"label": "Kubernetes", "description": "Deploy Sysdig Shield on a K8s cluster"},
    {"label": "Linux Host", "description": "Install Host Shield on standalone servers (coming soon)"}
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
    {"label": "GCP", "description": "Google Cloud Platform (experimental)"},
    {"label": "Azure", "description": "Microsoft Azure (experimental)"}
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

The first connection always establishes a read-only trust relationship with
your cloud account. Then ask what additional connections to enable.

Briefly explain before showing the selector:

> **First, I'll set up the foundational connection** — this creates a read-only trust
> relationship with your cloud account. It enables asset inventory, security
> posture checks, and foundational identity analysis. This is always included.
>
> On top of that, you can optionally enable:
>
> **Cloud Logs** — Captures cloud audit logs for real-time threat detection
> and deeper identity analysis.
>
> **Agentless Scanning** — Scans hosts and workloads for known
> vulnerabilities without installing agents.

```json
{
  "question": "The foundational connection is always set up. What additional connections do you want to enable?",
  "header": "Connections",
  "multiSelect": true,
  "options": [
    {"label": "Cloud Logs", "description": "Capture audit logs for real-time threat detection"},
    {"label": "Agentless Scanning", "description": "Scan hosts and workloads for vulnerabilities"},
    {"label": "No thanks, foundational is enough", "description": "Continue with just the foundational connection"}
  ]
}
```

Recommend enabling both for comprehensive coverage.

For the capability-to-feature mapping and template markers, see
[features.md](features.md).

---

## Step 3d-ii: Log Capture Method (AWS only)

If Cloud Logs is selected AND provider is AWS:

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

Default to EventBridge. If CloudTrail/S3, see [aws.md](aws.md) for
sub-questions (trail name, bucket/SNS ARN, KMS).

### Log Region Selection (EventBridge)

If EventBridge is selected, ask which regions to monitor:

```json
{
  "question": "Which AWS regions should be monitored for threats?",
  "header": "Regions",
  "multiSelect": true,
  "options": [
    {"label": "us-east-1", "description": "US East (N. Virginia) — recommended, captures global events"},
    {"label": "us-west-2", "description": "US West (Oregon)"},
    {"label": "eu-west-1", "description": "Europe (Ireland)"},
    {"label": "eu-central-1", "description": "Europe (Frankfurt)"},
    {"label": "ap-southeast-1", "description": "Asia Pacific (Singapore)"},
    {"label": "All active regions", "description": "Monitor every region with active resources"}
  ]
}
```

**Note:** Always include `us-east-1` — it captures global service events
(IAM, CloudFront, Route53, etc.) regardless of where resources run.

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

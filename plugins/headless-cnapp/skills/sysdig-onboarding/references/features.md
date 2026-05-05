# Sysdig Secure Feature Matrix

## Security Capabilities (User-Facing)

The onboarding skill presents features as progressive **capabilities** so
users don't need to know security acronyms. The first connection is always
included; Cloud Logs and Agentless Scanning are optional add-ons.

| Capability | What it does (plain language) | Technical features | Template markers |
|------------|-----------------------------|--------------------|-----------------|
| **First connection** (always) | Creates a read-only trust relationship with your cloud account. Enables asset inventory, security posture checks, and foundational identity analysis. | CSPM, CIEM Basic | `CSPM`, `CIEM Basic` |
| **Cloud Logs** (optional) | Captures cloud audit logs so Sysdig can detect threats in real time. Also upgrades identity analysis with actual usage data. | CDR, CIEM Advanced | `CDR` or `CDR_CLOUDLOGS`, `CIEM Advanced` or `CIEM_ADVANCED_CLOUDLOGS` |
| **Agentless Scanning** (optional) | Scans your hosts and workloads for known vulnerabilities — no agents required. | VM Agentless, VM Workload (ECS/Lambda, AWS only) | `VM`, `WORKLOAD_SCANNING` |

**Recommended:** Enable all capabilities for comprehensive coverage. Start
with the first connection alone if you want the lightest footprint first,
then add Cloud Logs and Agentless Scanning later.

> **Capability-to-marker mapping:** When generating Terraform, the agent uses
> the "Template markers" column to decide which `# === MARKER ===` sections
> to keep or remove from the template files. See the detailed feature docs
> below for module references and dependencies.

---

## Overview

Sysdig Secure features for cloud accounts are enabled through Terraform
modules. Each feature has its own module and a corresponding
`sysdig_secure_cloud_auth_account_feature` resource.

---

## Features (Technical Reference)

### CSPM — Cloud Security Posture Management

**What it does:** Continuously evaluates cloud resource configurations against
security benchmarks and compliance standards (CIS, PCI-DSS, NIST, SOC2, etc.).
Detects misconfigurations, reports violations, and provides remediation guidance.

**Terraform module (per provider):**
- AWS: `sysdiglabs/secure/aws//modules/config-posture`
- GCP: `sysdiglabs/secure/google//modules/config-posture`
- Azure: `sysdiglabs/secure/azurerm//modules/config-posture`

**Feature type:** `FEATURE_SECURE_CONFIG_POSTURE`

**Dependencies:** Requires the onboarding module.

**What it creates:** A read-only IAM role/service principal that inventories
cloud resources. No data leaves the cloud account — Sysdig reads metadata only.

---

### CDR — Cloud Detection and Response

**What it does:** Analyzes cloud platform logs in real-time to detect threats,
suspicious API calls, and anomalous behavior. Uses Falco rules adapted for
cloud audit trails.

**Log sources per provider:**
- AWS: CloudTrail events (via EventBridge or S3)
- GCP: Audit Logs → Pub/Sub PUSH subscription
- Azure: Activity Logs → Event Hub

**AWS CDR integration modes:**
- **EventBridge** (recommended, default): Creates EventBridge rules that
  capture CloudTrail management events and forward them to Sysdig via API
  destination. No existing CloudTrail trail required. Simpler setup.
  Module: `sysdiglabs/secure/aws//modules/integrations/event-bridge`
- **CloudTrail/S3**: Connects to an EXISTING CloudTrail trail's S3 bucket.
  Sysdig reads logs directly from S3, notified via SNS. Use this when you
  already have a well-configured trail or need to include data events.
  Module: `sysdiglabs/secure/aws//modules/integrations/cloud-logs`
  Requires: existing trail's `bucket_arn` and `topic_arn` (or create topic).

**Terraform module (per provider):**
- AWS (EventBridge): `sysdiglabs/secure/aws//modules/integrations/event-bridge`
- AWS (CloudTrail/S3): `sysdiglabs/secure/aws//modules/integrations/cloud-logs`
- GCP: `sysdiglabs/secure/google//modules/pub-sub`
- Azure: `sysdiglabs/secure/azurerm//modules/event-hub`

**Feature type:** `FEATURE_SECURE_THREAT_DETECTION`

**Dependencies:** Requires the onboarding module. Independent of CSPM (can be
enabled without it, though both are recommended).

**What it creates:**
- AWS (EventBridge): EventBridge rules + SQS queues in selected regions
- AWS (CloudTrail/S3): IAM role for S3 read access + SNS subscription
- GCP: Pub/Sub topic + PUSH subscription + log sink
- Azure: Event Hub namespace + diagnostic settings

**Note:** CDR requires choosing which regions to monitor. For organizations,
all regions are typically included.

---

### CIEM — Cloud Infrastructure Entitlement Management

CIEM comes in two levels:

#### CIEM Basic

**What it does:** Analyzes IAM resources to identify overly permissive roles,
risky policies, and data exfiltration paths. Based on static analysis of
resource properties.

**How to enable:** Automatically available when CSPM (config-posture) is
enabled. Uses the same posture data.

**Feature type:** `FEATURE_SECURE_IDENTITY_ENTITLEMENT`

**Dependencies:** Requires config-posture component.

#### CIEM Advanced

**What it does:** Adds usage-based analysis on top of basic CIEM. Identifies
permissions that are granted but never used, suggests least-privilege policies,
and provides actual usage context.

**How to enable:** Requires BOTH config-posture AND CDR log ingestion.
The feature resource combines components from both modules.

**Feature type:** `FEATURE_SECURE_IDENTITY_ENTITLEMENT` (same type, but with
additional components)

**Dependencies:** Requires config-posture + CDR module (event-bridge or cloud-logs / pub-sub / event-hub).

**GCP-specific:** Advanced CIEM on GCP can also leverage domain-wide
delegation for deeper Workspace identity analysis.

---

### Vulnerability Management — Agentless Scanning

**What it does:** Scans cloud workloads (EC2 instances, container images,
Lambda functions, etc.) for known vulnerabilities without deploying agents.
Creates temporary snapshots for analysis.

**Terraform module (per provider):**
- AWS: `sysdiglabs/secure/aws//modules/agentless-scanning`
- GCP: `sysdiglabs/secure/google//modules/agentless-scan`
- Azure: `sysdiglabs/secure/azurerm//modules/agentless-scanning`

**Feature type:** `FEATURE_SECURE_AGENTLESS_SCANNING`

**Dependencies:** Requires the onboarding module. Independent of CSPM and CDR.

**What it creates:**
- AWS: IAM role + KMS key for snapshot encryption, in selected regions
- GCP: Service account + permissions for snapshot access
- Azure: Role assignment for disk snapshot access

**Note:** Requires selecting target regions. Operates asynchronously — initial
scan results may take up to 24 hours.

---

### Vulnerability Management — Workload Scanning (ECS + Lambda)

**What it does:** Scans container images running in ECS tasks and Lambda
functions for known vulnerabilities. Unlike agentless scanning (which
uses EBS snapshots for EC2), this module integrates directly with the
container and serverless runtimes.

**Terraform module:**
- AWS: `sysdiglabs/secure/aws//modules/vm-workload-scanning`

**Feature types:**
- `FEATURE_SECURE_WORKLOAD_SCANNING_CONTAINERS` — ECS
- `FEATURE_SECURE_WORKLOAD_SCANNING_FUNCTIONS` — Lambda

**Key variables:**
- `lambda_scanning_enabled` (bool, default: false) — Enable Lambda scanning

**Dependencies:** Requires the onboarding module. Independent of CSPM,
CDR, and agentless scanning.

**Note:** GCP and Azure equivalents are not yet available in the Terraform
modules. AWS-only for now.

---

### DSPM — Data Security Posture Management

**What it does:** Discovers and classifies sensitive data across cloud
storage (S3 buckets, databases, etc.). Powered by Bedrock Data integration.

**How to enable:** DSPM cannot be automated via Terraform. It requires:
1. Contacting your Sysdig account representative to enable the feature
2. Deploying the Bedrock Data Outpost component (manual, via Sysdig)

The onboarding trust relationship (step 1 of the UI wizard) is automatically
satisfied by the onboarding module.

**Feature type:** None — no `sysdig_secure_cloud_auth_account_feature`
resource exists for DSPM as of provider v3.4.3.

---

## Dependency Chain

```
Onboarding Module (always required)
│
├─→ Config Posture Module
│   ├─→ CSPM feature (FEATURE_SECURE_CONFIG_POSTURE)
│   └─→ CIEM Basic feature (FEATURE_SECURE_IDENTITY_ENTITLEMENT)
│         [components: config-posture only]
│
├─→ CDR Module (EventBridge or CloudTrail/S3 / PubSub / EventHub)
│   ├─→ CDR feature (FEATURE_SECURE_THREAT_DETECTION)
│   └─→ CIEM Advanced feature (FEATURE_SECURE_IDENTITY_ENTITLEMENT)
│         [components: config-posture + CDR]
│
├─→ Agentless Scanning Module
│   └─→ VM feature (FEATURE_SECURE_AGENTLESS_SCANNING)
│
├─→ Workload Scanning Module
│   ├─→ VM Containers feature (FEATURE_SECURE_WORKLOAD_SCANNING_CONTAINERS)
│   └─→ VM Functions feature (FEATURE_SECURE_WORKLOAD_SCANNING_FUNCTIONS)
│
└─→ DSPM (manual — requires Sysdig support)
```

**Important:** When enabling CIEM Advanced, the feature resource must reference
components from BOTH config-posture and CDR modules. This is a common source
of configuration errors.

---

## Recommended Starting Configuration

For most users, we recommend enabling all three blocks:

1. **Block 1 — Establish Trust** (always included) — Read-only, immediate value
2. **Block 2 — Cloud Logs** — Enables real-time threat detection (CDR) + advanced identity analysis
3. **Block 3 — Agentless Scanning** — If running workloads in the cloud

This order minimizes permissions at each step. Users can start with Block 1
alone and add Blocks 2–3 later in a follow-up session.

---

## Provider Feature Support Matrix

| Feature | AWS | GCP | Azure | OCI |
|---------|-----|-----|-------|-----|
| CSPM | Yes | Yes | Yes | Yes |
| CDR | Yes | Yes | Yes | No |
| CIEM Basic | Yes | Yes | Yes | No |
| CIEM Advanced | Yes | Yes | Yes | No |
| Agentless VM | Yes | Yes | Yes | No |
| Workload Scanning (ECS) | Yes | No | No | No |
| Workload Scanning (Lambda) | Yes | No | No | No |
| DSPM | Manual | Manual | Manual | No |

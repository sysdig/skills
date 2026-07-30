# Sysdig Secure Feature Matrix

## Capability → Marker Mapping (generator-facing)

The user-facing capability wording, picker JSON, and ask-time dependency
handling live in [interview-questions.md](interview-questions.md#step-3d-security-capabilities)
— do not restate them here. This file owns the **capability → technical
feature → template marker** mapping the generator uses to decide which
`# === MARKER ===` sections to keep or remove.

| Capability | Technical features | Template markers |
|------------|--------------------|-----------------|
| **First connection** (always) | CSPM, CIEM Basic | `CSPM`, `CIEM Basic` |
| **Threat Detection** (optional) | CDR | `CDR` or `CDR_CLOUDLOGS` |
| **Advanced Identity Analysis** (optional) | CIEM Advanced | `CIEM Advanced` or `CIEM_ADVANCED_CLOUDLOGS` — **also keep** the matching `CDR`/`CDR_CLOUDLOGS` block, which supplies the log data |
| **Host Scanning (Agentless)** (optional) | VM Agentless (+ flags) | `VM` |
| **Workload Scanning** (optional; templates generate AWS + GCP + Azure) | VM Workload | `WORKLOAD_SCANNING`, plus the serverless sub-markers `WORKLOAD_ECS` / `WORKLOAD_LAMBDA` (AWS) — see [Serverless workload scanning](#serverless-workload-scanning-aws-terraform) |

> **Generation consequence of the dependency rules** (the ask-time behavior is
> in interview-questions.md): when **Advanced Identity Analysis** is selected,
> keep the `CDR`/`CDR_CLOUDLOGS` block even if Threat Detection was not
> separately chosen — the `CIEM_ADVANCED*` block references the
> `event-bridge` / `cloud-logs` module and won't validate without it.

> **Mutually-exclusive markers — keep exactly one of each pair:**
> `CDR` vs `CDR_CLOUDLOGS`, and `CIEM Advanced` vs `CIEM_ADVANCED_CLOUDLOGS`.
> Each pair defines the **same** Terraform resource addresses, so keeping both
> fails with a duplicate-resource error; keep the variant matching the chosen
> log capture method (EventBridge → `CDR`/`CIEM Advanced`; CloudTrail/S3 →
> `CDR_CLOUDLOGS`/`CIEM_ADVANCED_CLOUDLOGS`). The `CIEM_ADVANCED*` blocks
> reference `module.event-bridge` / `module.cloud-logs`, so when Advanced
> Identity Analysis is selected you must keep the matching CDR block too —
> otherwise the generated file has a dangling module reference and won't validate.

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
- GCP: `sysdiglabs/secure/google//modules/integrations/pub-sub`
- Azure: `sysdiglabs/secure/azurerm//modules/integrations/event-hub`

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

### Vulnerability Management — Agentless Host Scanning

**What it does:** Scans cloud **hosts** (EC2 instances and other VMs) for known
vulnerabilities without deploying agents. Creates temporary disk snapshots for
analysis. This is host scanning only — container and serverless workloads are
covered by **Workload Scanning** below, which is a separate module and decision.

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

**Sub-options (AWS — feature flags):** Two extras are set as `flags` on the
`FEATURE_SECURE_AGENTLESS_SCANNING` resource, not as module variables (confirmed
against a UI Terraform export):

| Flag | Capability | Notes |
|------|-----------|-------|
| `SCANNING_HOST_CONTAINER_ENABLED` | Container scanning — also scan running containers found on the host | General availability |
| `SCANNING_MALWARE_ENABLED` | Malware scanning | **Preview** |

Set the selected flags to `"true"` in the `flags` map and add
`lifecycle { ignore_changes = [flags] }` so later UI toggles aren't reverted by
Terraform. Resolve the `{{AGENTLESS_SCANNING_FLAGS}}` placeholder to a map
literal, e.g. `{ "SCANNING_HOST_CONTAINER_ENABLED" : "true" }`, or `{}` when the
user wants host-disk scanning only.

**Note:** Requires selecting target regions. Operates asynchronously — initial
scan results may take up to 24 hours.

---

### Vulnerability Management — Workload Scanning (containers + serverless)

**What it does:** Scans container and serverless workloads for known
vulnerabilities. Unlike host scanning (which uses disk snapshots for VMs), this
integrates directly with the container and serverless runtimes.

**Platforms covered, per provider:**
- **AWS:** ECS Fargate and AWS Lambda (zip and container packaging).
- **Azure:** Azure Functions, AKS, and Azure Container Apps.
- **GCP:** GKE, Cloud Run, and GCP Functions.

For Kubernetes workloads on EKS, the Sysdig agent is the recommended path — it
adds runtime visibility and in-cluster image scanning that complement the
agentless coverage above.

> **How to enable:** These onboarding templates generate AWS (ECS Fargate +
> Lambda), GCP (Cloud Run + GKE + Cloud Functions), and Azure (Container
> Instances/Apps + Functions + AKS) workload scanning directly via Terraform.

**Terraform module (generated by these templates):**
- AWS: `sysdiglabs/secure/aws//modules/vm-workload-scanning`
- GCP: `sysdiglabs/secure/google//modules/vm-workload-scanning`
- Azure: `sysdiglabs/secure/azurerm//modules/vm-workload-scanning`

**Feature types:**
- `FEATURE_SECURE_WORKLOAD_SCANNING_CONTAINERS` — containers (AWS ECS Fargate; GCP Cloud Run; Azure Container Instances/Apps)
- `FEATURE_SECURE_WORKLOAD_SCANNING_KUBERNETES` — Kubernetes (GCP GKE; Azure AKS)
- `FEATURE_SECURE_WORKLOAD_SCANNING_FUNCTIONS` — serverless (AWS Lambda; GCP Cloud Functions; Azure Functions)

<a id="serverless-workload-scanning-aws-terraform"></a>

**Serverless scanning is agentless.** No sidecar, Dockerfile change, ECS
task-definition mutation, or CloudFormation macro is involved — scanning is
performed by Sysdig against the images the workloads reference. Enablement is
the module input plus the per-target feature resources inside the
`WORKLOAD_SCANNING` block:

| User selection (Step 3d-iv) | `{{LAMBDA_SCANNING_ENABLED}}` | Markers to keep |
|---|---|---|
| ECS / Fargate only | `false` | `WORKLOAD_ECS` — remove `WORKLOAD_LAMBDA` |
| Lambda only | `true` | `WORKLOAD_LAMBDA` — remove `WORKLOAD_ECS` |
| Both | `true` | keep both |
| Neither | — | remove the whole `WORKLOAD_SCANNING` block |

> **Why `lambda_scanning_enabled` and the LAMBDA marker must agree.** The
> module's base IAM role grants ECR read only — that is everything ECS/Fargate
> scanning needs, since Sysdig scans the ECR images the tasks reference. Lambda
> is the only target that adds IAM (`lambda:GetFunction`, `ListFunctions`,
> `GetLayerVersion`, …), and the module attaches that policy **only** when
> `lambda_scanning_enabled = true`. Keeping
> `FEATURE_SECURE_WORKLOAD_SCANNING_FUNCTIONS` with the flag left `false` tells
> Sysdig to scan Lambda against a role that cannot read it, and every scan
> fails with an access error. There is **no** ECS-specific module variable and
> **no** ECS-specific IAM.

**Key variables (AWS `vm-workload-scanning` module):**
- `lambda_scanning_enabled` (bool, default: false) — the only feature toggle the
  module exposes. Grants the role its `lambda:*` read permissions. ECS/Fargate
  has no counterpart variable — it rides on the always-created ECR read grant.

**Dependencies:** Requires the onboarding module. Independent of CSPM,
CDR, and host scanning.

**Recommending this capability:**
- **AWS:** a strong fit for customers running ECS Fargate or Lambda. For
  EKS / Kubernetes workloads, recommend the Sysdig agent, which delivers
  runtime and in-cluster vulnerability coverage.
- **GCP:** generated directly by these templates (Cloud Run / GKE / Cloud
  Functions); select at least one workload type.
- **Azure:** generated directly by these templates (Container Instances/Apps /
  Azure Functions / AKS); select at least one workload type.

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

> **Scope:** This chain describes the **Terraform modules** and the
> `sysdig_secure_cloud_auth_account_feature` **API resources** they create —
> i.e. how onboarding automation wires things together. It is **not** the
> product-level relationship a customer sees in the UI. In this Terraform/API
> view, every feature resource binds to the onboarding module's account
> (`module.onboarding.sysdig_secure_account_id`), so the onboarding module is
> always required here. Only CIEM (Basic and Advanced) additionally depends on
> the Config Posture module/components; CDR, agentless host scanning, and
> workload scanning do not. At the product level the onboarding/trust step and
> the security features are conceptually independent — don't read this diagram
> as customer-facing feature dependencies.

```
Onboarding Module (always required — Terraform/API binding, not a product dependency)
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
│   ├─→ VM Kubernetes feature (FEATURE_SECURE_WORKLOAD_SCANNING_KUBERNETES — GCP/Azure)
│   └─→ VM Functions feature (FEATURE_SECURE_WORKLOAD_SCANNING_FUNCTIONS)
│
└─→ DSPM (manual — requires Sysdig support)
```

**Important:** When enabling CIEM Advanced, the feature resource must reference
components from BOTH config-posture and CDR modules. This is a common source
of configuration errors.

---

## Recommended Enablement Order

For most users, the field-recommended order to enable capabilities is:

1. **CSPM + Basic CIEM** (Trust / Foundational) — always included; read-only,
   immediate value
2. **Host Scanning (Agentless)** — vulnerability scanning for cloud hosts
3. **Workload Scanning** — if applicable (see provider support below)
4. **Threat Detection / Advanced Identity Analysis (Cloud Logs)** — real-time
   threat detection plus usage-based identity analysis

The skill does not enforce a strict enablement order — users can enable
capabilities in any sequence and add more later in a follow-up session. This
order reflects the recommended progression and should drive the guidance the
skill gives when advising customers.

---

## Provider Feature Support Matrix

| Feature | AWS | GCP | Azure | OCI |
|---------|-----|-----|-------|-----|
| CSPM | Yes | Yes | Yes | Yes |
| CDR | Yes | Yes | Yes | No |
| CIEM Basic | Yes | Yes | Yes | No |
| CIEM Advanced | Yes | Yes | Yes | No |
| Agentless Host Scanning | Yes | Yes | Yes | No |
| Workload Scanning | Yes¹ | Yes² | Yes² | No |
| DSPM | Manual | Manual | Manual | No |

**Workload Scanning support notes:**

- ¹ **AWS:** ECS Fargate and Lambda, configured directly by these onboarding
  Terraform templates (`vm-workload-scanning` module). EKS / Kubernetes
  workloads are covered through the Sysdig agent (runtime + in-cluster image
  scanning).
- ² **GCP** (Cloud Run, GKE, Cloud Functions) and **Azure** (Azure Container
  Instances/Apps, Azure Functions, AKS) workload scanning are generated directly
  by these templates. Single-subscription Azure covers all three workload types;
  Advanced Identity (usage-based CIEM) remains tenant-scope only.

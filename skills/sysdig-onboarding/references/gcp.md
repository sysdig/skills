# GCP Cloud Onboarding Reference

Guidance for onboarding a Google Cloud project to Sysdig Secure. A foundational
set is always included, plus opt-in Threat Detection, Advanced Identity
Analysis, Host Scanning, and Workload Scanning. In the product UI the
foundational wizard covers posture + identity + scanning, and the more complex
capabilities (Threat Detection, and the Advanced Identity that builds on it) are
added afterward from the overview page; this skill can configure them all in one
guided pass.

## Table of Contents

1. [Feature model](#1-feature-model)
2. [Prerequisites and Permissions](#2-prerequisites-and-permissions)
3. [Single Project Setup](#3-single-project-setup)
4. [Terraform Module Reference](#4-terraform-module-reference)
5. [Domain-Wide Delegation (identity insights)](#5-domain-wide-delegation)
6. [Organization Setup](#6-organization-setup)
7. [Troubleshooting](#7-troubleshooting)

---

## 1. Feature model

| Group | Capability | Feature type(s) | Template marker |
|-------|-----------|-----------------|-----------------|
| **Foundational** (always) | Inventory + Posture & Compliance | `FEATURE_SECURE_CONFIG_POSTURE` | `CSPM` |
| **Foundational** (always) | Basic Identity Capabilities | `FEATURE_SECURE_IDENTITY_ENTITLEMENT` (basic) | `CIEM Basic` |
| **Additional** (opt-in) | Threat Detection | `FEATURE_SECURE_THREAT_DETECTION` | `CDR` |
| **Additional** (opt-in) | Advanced Identity Analysis (needs Threat Detection) | `FEATURE_SECURE_IDENTITY_ENTITLEMENT` (advanced) | `CIEM Advanced` |
| **Additional** (opt-in) | Host Scanning (agentless) | `FEATURE_SECURE_AGENTLESS_SCANNING` | `VM` |
| **Additional** (opt-in) | Workload Scanning | `FEATURE_SECURE_WORKLOAD_SCANNING_*` | `WORKLOAD_SCANNING` |

Foundational capabilities are always enabled — read-only, providing immediate
inventory, compliance, and configuration-based identity analysis. **Threat
Detection** (CDR — GCP Audit Logs via a Pub/Sub push subscription), **Advanced
Identity Analysis** (usage-based CIEM; requires Threat Detection), **Host
Scanning**, and **Workload Scanning** are opt-in. In the product UI these
expanded capabilities are added after the foundational wizard from the overview
page; the skill configures them in the same guided pass. The Pub/Sub module
ships sensible defaults (project-wide sink, no region choice); advanced tuning
(data-access audit config, ingestion filters, real-time inventory — the last
needs the `google-beta` provider) is available but optional.

**Host Scanning** has two sub-options ("Select Scanning Types"), set as feature
flags on the agentless-scanning resource:

| Flag | Capability | Status |
|------|-----------|--------|
| `SCANNING_HOST_CONTAINER_ENABLED` | Container scanning — also scan running containers found on the host | GA |
| `SCANNING_MALWARE_ENABLED` | Malware scanning (host file systems only) | Preview |

**Workload Scanning** ("Select Workload Types", choose at least one) maps each
workload type to its own feature resource, all sharing one module:

| Workload type | Feature type |
|---------------|--------------|
| Cloud Run | `FEATURE_SECURE_WORKLOAD_SCANNING_CONTAINERS` |
| GKE | `FEATURE_SECURE_WORKLOAD_SCANNING_KUBERNETES` |
| Cloud Functions | `FEATURE_SECURE_WORKLOAD_SCANNING_FUNCTIONS` |

---

## 2. Prerequisites and Permissions

### Tools Required
- Terraform >= 1.10.0
- Google Cloud CLI (`gcloud`), authenticated (`gcloud auth login`)

### Required APIs

These APIs must be enabled on the project before onboarding. The skill emits a
standalone `gcp_api_enablement.tf` (the wizard's "Set Up GCP APIs" step) that
enables them, or enable them manually with `gcloud services enable`:

- `cloudasset.googleapis.com`
- `admin.googleapis.com` (Workspace directory — for domain-wide delegation)
- `iam.googleapis.com`
- `iamcredentials.googleapis.com`
- `cloudresourcemanager.googleapis.com`
- `serviceusage.googleapis.com`

The Service Usage API (`serviceusage.googleapis.com`) must already be enabled on
the management project for Terraform to enable the rest.

### Installer Permissions

Run `scripts/check_permissions.sh gcp [single|organization]` to verify before
applying. The installer needs these roles on the target project (grouped as the
onboarding UI presents them):

| Purpose | Role |
|---------|------|
| IAM & role assignment | `roles/iam.roleAdmin`, `roles/resourcemanager.projectIamAdmin` |
| API enablement | `roles/serviceusage.serviceUsageAdmin` |
| Service account management | `roles/iam.serviceAccountAdmin`, `roles/iam.serviceAccountKeyAdmin` |
| Keyless authentication (Workload Identity Federation) | `roles/iam.workloadIdentityPoolAdmin` |

These are **setup-only** permissions. The roles Sysdig itself uses after
connection follow least privilege (read-only).

**Organization (additional roles at org level):**

| Role | Why it's needed |
|------|-----------------|
| `roles/iam.organizationRoleAdmin` | Manage custom roles across the organization |
| `roles/resourcemanager.organizationAdmin` | Manage organization-level resources |

### Roles Granted to Sysdig Service Accounts

Onboarding creates service accounts (`sysdig-onboarding-${suffix}` for setup and
`sysdig-posture-${suffix}` for ongoing posture) and grants them read-only roles
such as `roles/iam.browser`, `roles/cloudasset.viewer`,
`roles/iam.workloadIdentityUser`, `roles/logging.viewer`,
`roles/cloudfunctions.viewer`, `roles/cloudbuild.builds.viewer`, and
`roles/orgpolicy.policyViewer`. No data leaves the project — Sysdig reads
metadata only.

### Official Permissions Reference

For the complete and current list, see the Sysdig documentation:
https://docs.sysdig.com/en/sysdig-secure/connect-gcp/

---

## 3. Single Project Setup

The onboarding flow follows the UI wizard's steps:

1. **Customize Your Coverage** — Foundational (Inventory, Posture & Compliance,
   Basic Identity Capabilities) is always included. Optionally enable **Threat
   Detection**, **Advanced Identity Analysis**, **Host Scanning**, and
   **Workload Scanning**.
2. **Permissions Check** — confirm the installer roles above (verified by
   `check_permissions.sh gcp single`).
3. **Enter Project Details** — Project ID and GCP project region.
4. **Select Scanning Types** *(only if Host Scanning)* — Container scanning and
   Malware scanning (Preview).
5. **Select Workload Types** *(only if Workload Scanning)* — Cloud Run, Cloud
   Functions, GKE (choose at least one).
6. **Configure Terraform environment and gcloud CLI.**
7. **Set Up GCP APIs** — apply `gcp_api_enablement.tf` first (separate folder),
   or enable the APIs manually.
8. **Deploy Terraform** — apply `gcp_single_project.tf`.

Terraform source: `sysdiglabs/secure/google` (modules pinned `~> 2.0`).

Modules used:
- `//modules/onboarding` — registers the project, creates service accounts + workload identity pools
- `//modules/config-posture` — Foundational (CSPM + Basic Identity)
- `//modules/agentless-scan` — Host Scanning
- `//modules/vm-workload-scanning` — Workload Scanning (Cloud Run / GKE / Cloud Functions)

Downstream modules take `project_id = module.onboarding.project_id` so the
project is resolved once, from the onboarding module.

---

## 4. Terraform Module Reference

| Module | Purpose | Key inputs | Key output |
|--------|---------|-----------|------------|
| `onboarding` | Project registration + identity federation | `project_id` | `sysdig_secure_account_id`, `project_id`, `is_organizational`, `organization_domain` |
| `config-posture` | Posture & Compliance + Basic Identity | `project_id`, `sysdig_secure_account_id` | `service_principal_component_id` |
| `integrations/pub-sub` | Threat Detection (CDR) | `project_id`, `sysdig_secure_account_id` | `pubsub_datasource_component_id`, `post_ciem_basic_delay` |
| `agentless-scan` | Host Scanning | `project_id`, `sysdig_secure_account_id` | `agentless_scan_component_id` |
| `vm-workload-scanning` | Workload Scanning | `project_id`, `sysdig_secure_account_id`, `is_organizational`, `organization_domain` | `vm_workload_scanning_component_id` |

Each capability is registered with a `sysdig_secure_cloud_auth_account_feature`
resource that references the module's component ID. Basic Identity and
agentless-scanning use `lifecycle { ignore_changes = [flags] }` so later UI
toggles are not reverted by Terraform. **Advanced Identity has no module of its
own** — it reuses the config-posture and pub-sub components (`concat`) with
`CIEM_FEATURE_MODE = "advanced"`, so the CDR (pub-sub) block must be present
whenever it is enabled.

> **Cloud Run serverless scanning:** Cloud Run coverage is vulnerability
> scanning only, and it is agentless — no agent or sidecar is involved.
> Enable it by keeping the `WORKLOAD_CLOUDRUN` sub-marker
> (`FEATURE_SECURE_WORKLOAD_SCANNING_CONTAINERS`) inside the
> `WORKLOAD_SCANNING` block, alongside `WORKLOAD_GKE` / `WORKLOAD_FUNCTIONS`
> for the other workload types.

---

## 5. Domain-Wide Delegation

**When it's needed:** Basic Identity Capabilities work without it, but the
*advanced* identity insights — unused-permission criticality, excessive
permissions, Workspace user/group membership, and MFA/login/admin reporting —
require domain-wide delegation (DWD) so Sysdig can read Google Workspace
directory data. DWD is a **manual** Google Admin Console step; it cannot be
automated with Terraform.

**Steps** (full detail:
https://docs.sysdig.com/en/sysdig-secure/connect-gcp/):

1. In the Google Cloud Console, open the onboarding project's **Service
   Accounts** and find `sysdig-posture-xxxxxx@<project_id>.iam.gserviceaccount.com`.
   Copy its **OAuth 2 Client ID**.
2. In the Google Admin Console, go to **Security → Access and data control → API
   controls → Manage Domain Wide Delegation → Add New**.
3. Paste the Client ID and add these read-only OAuth scopes:
   ```
   https://www.googleapis.com/auth/cloud-identity.groups.readonly,
   https://www.googleapis.com/auth/admin.directory.user.readonly,
   https://www.googleapis.com/auth/admin.directory.group.readonly,
   https://www.googleapis.com/auth/admin.directory.group.member.readonly,
   https://www.googleapis.com/auth/cloud-platform.read-only,
   https://www.googleapis.com/auth/logging.read,
   https://www.googleapis.com/auth/admin.reports.audit.readonly,
   https://www.googleapis.com/auth/admin.reports.usage.readonly
   ```
4. Authorize, then create a custom admin role (Google Admin Console →
   **Account → Admin Roles**) granting the service account the needed privileges.

If skipped during onboarding, you can configure it later from the **Identity and
Access** page in Sysdig Secure.

---

## 6. Organization Setup

Organization-scope onboarding covers a folder/project hierarchy from a single
management project. Key parameters:

- `include_folders` / `exclude_folders`
- `include_projects` / `exclude_projects`

The onboarding module surfaces `is_organizational` and `organization_domain`,
which the workload-scanning module consumes. Organization onboarding also
requires the additional org-level installer roles listed in §2.

---

### Connecting a project to multiple Sysdig accounts

Yes — a single GCP project can be onboarded to more than one Sysdig account at
the same time. The `onboarding` and `config-posture` modules apply a **random
suffix** to every resource they create (service accounts, workload-identity
pools/providers, Pub/Sub topic + sink, agentless service account), so a second
onboarding produces a distinct, non-colliding set and does not disturb the
first. Run each onboarding from its **own Terraform working directory/state**;
`terraform destroy` then removes only that account's suffixed resources.

## 7. Troubleshooting

| Symptom | Cause | Resolution |
|---------|-------|-----------|
| `Error 403: ... API has not been used/enabled` | Required API not enabled | Apply `gcp_api_enablement.tf` (or `gcloud services enable`) before the deploy config; wait a minute for propagation |
| `terraform apply` fails enabling APIs | Service Usage API not enabled on the management project | `gcloud services enable serviceusage.googleapis.com --project <project>` once, then re-run |
| Permission denied creating service accounts / roles | Installer missing a setup role | Re-check with `check_permissions.sh gcp single`; grant the missing role from §2 |
| Account connects but identity insights are empty | Domain-wide delegation not configured | Complete the DWD steps in §5 |
| Workload scanning shows no results | No workload type selected, or images not yet scanned | Confirm at least one workload type was enabled; initial scans can take time to populate |

For issues not covered here, see https://docs.sysdig.com/en/sysdig-secure/connect-gcp/.

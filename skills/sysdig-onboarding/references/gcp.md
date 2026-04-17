# GCP Cloud Onboarding Reference

> **Status:** Stub — will be completed in Phase 4 with real module variables,
> examples, and tested configurations.

## Table of Contents

1. [Prerequisites and Permissions](#1-prerequisites-and-permissions)
2. [Single Project Setup](#2-single-project-setup)
3. [Organization Setup](#3-organization-setup)
4. [Terraform Module Reference](#4-terraform-module-reference)
5. [Domain-Wide Delegation (Advanced CIEM)](#5-domain-wide-delegation)
6. [Troubleshooting](#6-troubleshooting)

---

## 1. Prerequisites and Permissions

### Tools Required
- Terraform >= 1.10.0
- Google Cloud CLI (`gcloud`), authenticated

### Installer Permissions

Run `scripts/check_permissions.sh gcp [single|organization]` to verify before
applying.

**Single project — Installer needs these roles on the target project:**

| Role | Why it's needed |
|------|-----------------|
| `roles/iam.serviceAccountAdmin` | Create Sysdig service accounts |
| `roles/iam.roleAdmin` | Create custom IAM roles |
| `roles/resourcemanager.projectIamAdmin` | Assign project-level IAM bindings |
| `roles/iam.serviceAccountKeyAdmin` | Create service account keys |
| `roles/serviceusage.serviceUsageAdmin` | Enable required Google APIs |
| `roles/iam.workloadIdentityPoolAdmin` | Create workload identity pools/providers |

**Organization (additional roles at org level):**

| Role | Why it's needed |
|------|-----------------|
| `roles/iam.organizationRoleAdmin` | Manage custom roles across the organization |
| `roles/resourcemanager.organizationAdmin` | Manage organization-level resources |

### Roles Granted to Sysdig Service Accounts

Sysdig creates two service accounts:
- `sysdig-onboarding-${suffix}` — Initial auth and setup
- `sysdig-posture-${suffix}` — Ongoing posture/compliance

| Role | Purpose |
|------|---------|
| `roles/iam.browser` | Read-only IAM configuration browsing |
| `roles/cloudasset.viewer` | Cloud asset inventory enumeration |
| `roles/iam.workloadIdentityUser` | Workload identity federation |
| `roles/logging.viewer` | Access cloud audit logs |
| `roles/cloudfunctions.viewer` | Inspect Cloud Functions |
| `roles/cloudbuild.builds.viewer` | Monitor Cloud Build pipelines |
| `roles/orgpolicy.policyViewer` | Review organization policies |

### Required APIs
<!-- TODO Phase 4: List specific APIs that must be enabled per feature -->

### Official Permissions Reference

For the complete and latest list, consult:
https://docs.sysdig.com/en/sysdig-secure/gcp-permissions-and-resources/

---

## 2. Single Project Setup

<!-- TODO Phase 4 -->

Terraform source: `sysdiglabs/secure/google`

Modules used:
- `//modules/onboarding`
- `//modules/config-posture`
- `//modules/pub-sub` — For CDR
- `//modules/agentless-scan` — For VM

---

## 3. Organization Setup

<!-- TODO Phase 4 -->

Key parameters:
- `include_folders` / `exclude_folders`
- `include_projects` / `exclude_projects`

---

## 4. Terraform Module Reference

<!-- TODO Phase 4 -->

---

## 5. Domain-Wide Delegation

<!-- TODO Phase 4: Multi-step manual process for advanced CIEM -->

Required for advanced CIEM on GCP. Involves:
- Creating a custom admin role in Google Workspace Admin
- Authorizing the Sysdig service account for domain-wide delegation
- Cannot be fully automated with Terraform

---

## 6. Troubleshooting

<!-- TODO Phase 4 -->

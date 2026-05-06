# AWS Cloud Onboarding Reference

> **Status:** Incomplete — sections marked `<!-- TODO -->` are pending
> validation and will be filled in as content matures.

## Table of Contents

1. [Prerequisites and Permissions](#1-prerequisites-and-permissions)
2. [Single Account Setup](#2-single-account-setup)
3. [Organization Setup](#3-organization-setup)
4. [Terraform Module Reference](#4-terraform-module-reference)
5. [Feature-Specific Configuration](#5-feature-specific-configuration)
6. [Troubleshooting](#6-troubleshooting)

---

## 1. Prerequisites and Permissions

### Tools Required
- Terraform >= 1.10.0
- AWS CLI v2, configured with credentials (`aws configure` or env vars)

### Installer Permissions

These are the permissions the person running Terraform needs. Run
`scripts/check_permissions.sh aws [single|organization]` to verify before
applying.

**Single account:**

| Policy / Permission | Why it's needed |
|---------------------|-----------------|
| `IAMFullAccess` | Create Sysdig's IAM roles (`sysdig-secure-onboarding-*`, `sysdig-secure-posture-*`) |

**Organization (additional):**

| Policy / Permission | Why it's needed |
|---------------------|-----------------|
| `AWSOrganizationsReadOnlyAccess` | List accounts and OUs in the organization |
| `AWSCloudFormationFullAccess` | Deploy CloudFormation StackSets to member accounts |
| `AWSKeyManagementServicePowerUser` | Manage KMS keys for encrypted log forwarding |

**Pre-flight check actions** (tested by `check_permissions.sh`):

| Scope | IAM Actions Tested |
|-------|--------------------|
| Always | `iam:CreateRole`, `iam:AttachRolePolicy`, `iam:PutRolePolicy`, `iam:CreatePolicy` |
| Organization | `organizations:ListAccounts`, `organizations:DescribeOrganization` |
| Organization | `cloudformation:CreateStackSet`, `cloudformation:CreateStackInstances` |
| CDR | `events:PutRule`, `events:PutTargets` (EventBridge) |
| VM | `ec2:CreateSnapshot`, `ec2:DescribeSnapshots` (Agentless scanning) |

> **Note:** This list reflects the documented requirements at the time of
> writing and may be incomplete or outdated. If `terraform apply` fails
> with an `AccessDenied` on an action not listed here, consult the
> official Sysdig permissions reference linked below for the current
> requirements.

### IAM Roles Created by Sysdig

| Role | Purpose | Permissions |
|------|---------|-------------|
| `sysdig-secure-onboarding-XXXX` | Integration management | `AWSAccountManagementReadOnlyAccess` (single), `AWSOrganizationsReadOnlyAccess` (org) |
| `sysdig-secure-posture-XXXX` | Resource inventory for CSPM | `SecurityAudit` + custom inline policy (see below) |

**Custom inline policy on posture role:**
- `account:GetContactInformation`
- `account:GetAccountAlias`
- `elasticfilesystem:DescribeAccessPoints`
- `lambda:GetFunction`, `lambda:GetRuntimeManagementConfig`
- `macie2:ListClassificationJobs`
- `waf-regional:ListRuleGroups`, `waf-regional:ListRules`
- `organizations:ListAccounts` (organization only)

### Official Permissions Reference

For the complete and latest list, consult:
https://docs.sysdig.com/en/sysdig-secure/aws-permissions-and-resources/

---

## 2. Single Account Setup

<!-- TODO: Complete with tested Terraform configuration -->

Terraform source: `sysdiglabs/secure/aws`

Modules used:
- `//modules/onboarding` — Always required
- `//modules/config-posture` — For CSPM + CIEM Basic
- `//modules/integrations/event-bridge` — For CDR + CIEM Advanced
- `//modules/agentless-scanning` — For Vulnerability Management

---

## 3. Organization Setup

<!-- TODO: Complete with tested Terraform configuration -->

Key differences from single account:
- `is_organizational = true` on onboarding module
- Include/exclude OUs: `include_ouids`, `exclude_ouids`
- Include/exclude accounts: `include_accounts`, `exclude_accounts`
- `enable_automatic_onboarding = true` for auto-discovering new accounts
- CloudFormation StackSet deployment across member accounts

---

## 4. Terraform Module Reference

<!-- TODO: Document all module variables with types and defaults -->

### `sysdiglabs/secure/aws//modules/onboarding`

Key variables:
- `is_organizational` (bool, default: false)
- `is_gov_cloud_onboarding` (bool, default: false)
- `region` (string)
- `include_ouids` / `exclude_ouids` (set(string))
- `include_accounts` / `exclude_accounts` (set(string))
- `enable_automatic_onboarding` (bool, default: false)
- `tags` (map(string))

### `sysdiglabs/secure/aws//modules/config-posture`

<!-- TODO -->

### `sysdiglabs/secure/aws//modules/integrations/event-bridge`

<!-- TODO -->

### CDR Integration Mode — Interview Sub-Questions

When the user selects **CloudTrail/S3** mode (instead of the default
EventBridge), ask these follow-up questions:

1. **CloudTrail trail name** — to auto-discover bucket and SNS topic:
   ```bash
   aws cloudtrail describe-trails --trail-name-list <trail-name> \
       --query 'trailList[0].{S3Bucket:S3BucketName,SNSTopic:SnsTopicARN}'
   ```
   Show the discovered values and ask for confirmation before using them.
2. **Or directly:** S3 bucket ARN and SNS topic ARN (if the user doesn't
   have a trail name handy).
3. **KMS encryption:** Whether the bucket uses KMS encryption. If yes, ask
   for the KMS key ARN and uncomment the `kms_key_arn` line in the generated
   template. If no, leave it commented out.

### `sysdiglabs/secure/aws//modules/agentless-scanning`

<!-- TODO -->

### `sysdiglabs/secure/aws//modules/vm-workload-scanning`

Key variables:
- `sysdig_secure_account_id` (string) — from onboarding module
- `lambda_scanning_enabled` (bool, default: false) — enable Lambda scanning
- `is_organizational` (bool, default: false) — for organization deployments
- `include_ouids` / `exclude_ouids` (set(string)) — org filters
- `include_accounts` / `exclude_accounts` (set(string)) — org filters

---

## 5. Feature-Specific Configuration

<!-- TODO: Document sysdig_secure_cloud_auth_account_feature resources -->

Feature enablement uses `sysdig_secure_cloud_auth_account_feature` resources:
- `FEATURE_SECURE_CONFIG_POSTURE` — CSPM
- `FEATURE_SECURE_IDENTITY_ENTITLEMENT` — CIEM (basic or advanced)
- `FEATURE_SECURE_THREAT_DETECTION` — CDR
- `FEATURE_SECURE_AGENTLESS_SCANNING` — Vulnerability Management (EC2)
- `FEATURE_SECURE_WORKLOAD_SCANNING_CONTAINERS` — VM (ECS)
- `FEATURE_SECURE_WORKLOAD_SCANNING_FUNCTIONS` — VM (Lambda)

---

## 6. Troubleshooting

<!-- TODO: Document common issues encountered during onboarding -->

Common areas to watch:
- IAM permission errors during `terraform apply`
- EventBridge rules not forwarding in all target regions
- Sysdig account not appearing in UI after apply
- Trust policy issues with cross-account roles

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

Sysdig documents the installer prerequisites as **AWS managed policies**, not
granular actions. Because these are broad (`IAMFullAccess` = `iam:*`,
`AWSCloudFormationFullAccess` = `cloudformation:*`), they already cover the
tag companions (`iam:TagPolicy`, `cloudformation:TagResource`, …) that a
hand-rolled least-privilege policy can miss — see the pre-flight note below.

| Managed policy | When required | Why it's needed |
|----------------|---------------|-----------------|
| `IAMFullAccess` | **Always** | Create Sysdig's IAM roles and policies (`sysdig-secure-onboarding-*`, `sysdig-secure-posture-*`), which are created **with tags** |
| `AWSCloudFormationFullAccess` | Organization scope, **or** single account with Threat Detection or Host Scanning | Those capabilities deploy via CloudFormation StackSets **even for a single account** — not only org scope |
| `AWSOrganizationsReadOnlyAccess` | Organization scope only | List accounts and OUs in the organization |
| `AWSKeyManagementServicePowerUser` | When Host Scanning (agentless) or encrypted log forwarding is enabled | Create/manage the KMS keys those features provision |

> **Not just organization scope:** CloudFormation StackSets are used for
> single-account Threat Detection and Host Scanning, so
> `AWSCloudFormationFullAccess` is required for single-account installs that
> enable any of those — not only for organization-wide installs.

**Pre-flight check actions** (tested by `check_permissions.sh`):

| Scope | IAM Actions Tested |
|-------|--------------------|
| Always | `iam:CreateRole`, `iam:AttachRolePolicy`, `iam:PutRolePolicy`, `iam:CreatePolicy`, `iam:TagRole`, `iam:TagPolicy` |
| Organization | `organizations:ListAccounts`, `organizations:DescribeOrganization` |
| Organization | `cloudformation:CreateStackSet`, `cloudformation:CreateStackInstances`, `cloudformation:TagResource` |
| CDR | `events:PutRule`, `events:PutTargets`, `events:TagResource`, `sqs:CreateQueue`, `sqs:TagQueue` (EventBridge) |
| VM | `ec2:DescribeSnapshots`, `kms:CreateKey`, `kms:TagResource` (Agentless scanning) |

> **Tag companions matter:** Sysdig modules create IAM policies, CloudFormation
> StackSets, EventBridge rules, SQS queues, and KMS keys **with tags**. AWS
> requires the matching `*:Tag*` action alongside each `Create*`, so a minimal
> policy that grants `CreatePolicy`/`CreateStackSet` but omits `TagPolicy`/
> `TagResource` fails at `terraform apply`. The pre-flight probes both.

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

Key variables:
- `sysdig_secure_account_id` (string) — from onboarding module
- `regions` (set(string)) — regions to forward events from; always include
  `us-east-1` for global events (resolves `{{EVENT_BRIDGE_REGIONS}}`)
- `is_organizational` (bool) + `include_ouids` / `exclude_ouids` /
  `include_accounts` / `exclude_accounts` — org-scope filters
- `event_pattern` (string, optional) — the CloudWatch event pattern controlling
  **which** log sources EventBridge forwards. **Omit for Default Setup** (the
  module's built-in default forwards all sources). Set it only for the UI's
  "Select Sources" customization. Resolves `{{EVENT_BRIDGE_EVENT_PATTERN}}` —
  see [log-source-customization.md](log-source-customization.md) for the
  checkbox→pattern mapping and generation algorithm.
- `rule_state` (string) — default
  `"ENABLED_WITH_ALL_CLOUDTRAIL_MANAGEMENT_EVENTS"`; leave at default. It is an
  independent knob from `event_pattern` (the module's own default sets both), so
  customizing `event_pattern` does not require changing `rule_state`.

### CDR Integration Mode — Interview Sub-Questions

When the user selects **CloudTrail/S3** mode (instead of the default
EventBridge), ask these follow-up questions. Together they resolve every
CloudTrail/S3 placeholder in the template — `{{CLOUDTRAIL_BUCKET_ARN}}`,
`{{CLOUDTRAIL_SNS_TOPIC_ARN}}`, `{{CREATE_SNS_TOPIC}}`, `{{SNS_TOPIC_REGION}}`,
`{{KMS_KEY_ARN}}`, and `{{CLOUD_LOGS_REGIONS}}`. Never leave one unresolved.

1. **CloudTrail trail name** — to auto-discover bucket and SNS topic:
   ```bash
   aws cloudtrail describe-trails --trail-name-list <trail-name> \
       --query 'trailList[0].{S3Bucket:S3BucketName,SNSTopic:SnsTopicARN}'
   ```
   Show the discovered values and ask for confirmation before using them.
   Resolves `{{CLOUDTRAIL_BUCKET_ARN}}` and `{{CLOUDTRAIL_SNS_TOPIC_ARN}}`.
   **Note:** `describe-trails` returns `S3BucketName` (a bucket *name*, not an
   ARN). Construct `{{CLOUDTRAIL_BUCKET_ARN}}` as `arn:aws:s3:::<bucket-name>`
   before substituting. `SnsTopicARN` is already a full ARN — use it as-is.
2. **Or directly:** S3 bucket ARN and SNS topic ARN (if the user doesn't
   have a trail name handy).
3. **SNS topic** — set `{{CREATE_SNS_TOPIC}}`:
   - If the trail already publishes to an SNS topic (the `SnsTopicARN` above is
     present), use that ARN as `topic_arn` and set `create_topic = false`.
   - If there is no existing topic, set `create_topic = true` (the module
     creates and subscribes one) and use the desired topic ARN.
4. **SNS topic region** — set `{{SNS_TOPIC_REGION}}` (the `aws.sns` provider
   alias needs it). Derive it from the region segment of the SNS topic ARN
   (`arn:aws:sns:<region>:<acct>:<topic>`); if creating a new topic, use the
   account's primary region. Do not ask the user if it can be derived.
5. **KMS encryption:** Whether the bucket uses KMS encryption. If yes, ask
   for the KMS key ARN and uncomment the `kms_key_arn` line in the generated
   template (resolving `{{KMS_KEY_ARN}}`). If no, leave it commented out.
6. **Regions to monitor** — set `{{CLOUD_LOGS_REGIONS}}`. Ask the same region
   multi-select used for EventBridge (see interview-questions.md "Cloud Logs
   Region Selection"); CloudTrail/S3 resolves `CLOUD_LOGS_REGIONS` (not
   `EVENT_BRIDGE_REGIONS`). Always include `us-east-1` for global events.

### `sysdiglabs/secure/aws//modules/agentless-scanning`

<!-- TODO -->

### `sysdiglabs/secure/aws//modules/vm-workload-scanning`

Key variables:
- `sysdig_secure_account_id` (string) — from onboarding module
- `lambda_scanning_enabled` (bool, default: false) — enable Lambda scanning.
  **The only feature toggle the module exposes** — there is no ECS counterpart.
- `is_organizational` (bool, default: false) — for organization deployments
- `include_ouids` / `exclude_ouids` (set(string)) — org filters
- `include_accounts` / `exclude_accounts` (set(string)) — org filters

IAM created by the module:

| Policy | When | Actions |
|---|---|---|
| ECR read | always | `ecr:GetDownloadUrlForLayer`, `BatchGetImage`, `BatchCheckLayerAvailability`, `ListImages`, `GetAuthorizationToken` |
| Lambda read | only if `lambda_scanning_enabled = true` | `lambda:GetFunction`, `GetFunctionConfiguration`, `GetRuntimeManagementConfig`, `ListFunctions`, `ListTags`, `GetLayerVersionByArn`, `GetLayerVersion`, `ListLayers`, `ListLayerVersions` |

> **ECS / Fargate needs no extra IAM and no extra variable.** ECS scanning
> works off the always-created ECR read grant, because Sysdig scans the ECR
> images the tasks reference; the task/service inventory comes from the base
> onboarding + CSPM role. There are **no** `ecs:*` actions in the module. No
> sidecar, agent, or task-definition change is required either.
>
> Enablement per target is a `sysdig_secure_cloud_auth_account_feature`
> resource, which the templates carry as sub-markers of `WORKLOAD_SCANNING`:
>
> | Target | Feature type | Sub-marker | Module input |
> |---|---|---|---|
> | ECS / Fargate | `FEATURE_SECURE_WORKLOAD_SCANNING_CONTAINERS` | `WORKLOAD_ECS` | — |
> | Lambda | `FEATURE_SECURE_WORKLOAD_SCANNING_FUNCTIONS` | `WORKLOAD_LAMBDA` | `lambda_scanning_enabled = true` |
>
> Keeping `WORKLOAD_LAMBDA` while `lambda_scanning_enabled` stays `false`
> produces Lambda scans against a role with no `lambda:*` permissions. See
> [features.md](features.md#serverless-workload-scanning-aws-terraform).

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

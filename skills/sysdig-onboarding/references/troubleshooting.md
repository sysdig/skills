# Troubleshooting Guide

Common errors and their solutions, organized by category. This document is
enriched continuously as we test onboarding scenarios and collect feedback
from support teams and field engineers.

## Knowledge Sources for Enrichment

This guide should be periodically enriched with real-world issues from:

- **Glean** — Search for onboarding-related knowledge articles, runbooks,
  and past resolutions shared by engineering and support teams
- **DevRev** — Collect customer support tickets related to onboarding
  failures, permission issues, and post-install problems
- **Field engineering notes** — Issues reported by SEs during customer
  onboarding engagements
- **DEVLOG.md** — Promote recurring patterns from our own testing sessions

When adding entries from these sources, include the source reference
(e.g., "Source: DevRev ticket #1234") for traceability.

---

## Cloud Account Onboarding

### Permissions / IAM

#### AWS CLI installed but not authenticated

- **Symptoms:** `validate_prereqs.sh aws` reports "AWS CLI: INSTALLED" but
  `check_permissions.sh` fails with "Unable to locate credentials" or
  "ExpiredToken". The AWS CLI binary exists but has no valid session.
- **Cause:** The user has AWS CLI installed but hasn't configured credentials.
  Common scenarios: fresh install without `aws configure`, expired SSO session,
  or missing `AWS_PROFILE` / `AWS_ACCESS_KEY_ID` environment variables.
- **Fix options:**
  1. **Named profile:** `aws configure --profile sysdig-onboarding` then
     `export AWS_PROFILE=sysdig-onboarding`
  2. **SSO login:** `aws sso login --profile <profile-name>`
  3. **Environment variables:** Set `AWS_ACCESS_KEY_ID` and
     `AWS_SECRET_ACCESS_KEY` (less recommended — prefer profiles)
  4. **IAM Identity Center:** `aws configure sso`
- **Prevention:** `validate_prereqs.sh` checks both installation AND
  authentication. Always run it before proceeding.
- **Source:** Test 5b — skill correctly detected CLI-installed-but-not-authenticated

#### Insufficient IAM permissions for Terraform apply

- **Symptoms:** `check_permissions.sh` reports multiple FAIL results for
  write operations (e.g., `iam:CreateRole`, `iam:AttachRolePolicy`,
  `events:PutRule`). If all write permissions are denied, `terraform apply`
  **will** fail — not "might" or "very likely," but **will**.
- **Cause:** The IAM identity (user or role) running Terraform lacks the
  required permissions. Common when using read-only roles, restrictive SCPs,
  or permission boundaries.
- **Fix:**
  1. Review the failed checks — each lists the specific IAM action needed
  2. The skill can generate a `generated/sysdig-required-policy.json` with
     the minimum IAM policy needed for onboarding
  3. Attach the policy to the IAM identity and re-run `check_permissions.sh`
- **Important:** A partial `terraform apply` (where only data sources succeed)
  is safe — Terraform creates no AWS resources if IAM write calls fail. The
  state will contain only data sources, which can be cleaned with
  `terraform destroy` or simply deleted.
- **Source:** Test 3 — 9/15 write operations denied, terraform apply failed as expected

---

### Terraform Errors

#### Terraform state drift during offboarding (resources deleted outside Terraform)

- **Symptoms:** `terraform plan -destroy` or `terraform destroy` shows fewer
  resources than expected. Some resources show "will be destroyed" while
  others silently disappear from state during the refresh phase.
- **Cause:** Resources (e.g., IAM roles, policies) were deleted outside
  Terraform — manually via the AWS console, by another automation tool, or
  by an AWS Organization SCP cleanup.
- **How Terraform handles it:** During `terraform plan` or `terraform destroy`,
  the AWS provider runs a **refresh** phase that reads each resource from the
  API. If a resource no longer exists, the provider automatically removes it
  from state. This is normal behavior — Terraform auto-reconciles drift.
- **When `terraform state rm` is actually needed:** Only when the refresh
  itself fails — e.g., the provider gets an API error (not "not found" but an
  actual error like timeout, permission denied, or malformed response) that
  prevents it from reading the resource. In that case, manually remove the
  unreachable resource with `terraform state rm <resource_address>` and retry.
- **Example from testing:** 61 resources in state, 2 IAM roles manually
  deleted → refresh auto-removed 5 resources (2 roles + 3 attached policies),
  `terraform destroy` succeeded for the remaining 37 with zero errors.
- **Source:** Test 5 — corrupted state scenario

#### Terraform apply fails with SCP error

- **Symptoms:** `terraform apply` fails with an error containing "explicit deny
  in a service control policy" and an SCP ARN like
  `arn:aws:organizations::ACCOUNT:policy/ORGID/service_control_policy/POLICYID`.
  Some resources may be created successfully while others fail.
- **Cause:** An AWS Organization Service Control Policy (SCP) is blocking one or
  more actions required by the Sysdig Terraform module. SCPs override IAM
  permissions — even `AdministratorAccess` cannot bypass them. SCPs only apply
  to member accounts, not the management account.
- **Note on detection:** `check_permissions.sh` falls back to service-level
  probes when `SimulatePrincipalPolicy` is unavailable (common on cross-account
  assumed roles). These probes confirm basic service access but cannot detect
  action-level SCP restrictions (e.g., an SCP blocking `events:PutRule` while
  `events:ListRules` succeeds).
- **Remediation options:**
  1. **Modify the SCP** — Add an exception for Sysdig-related roles (e.g.,
     allow actions for roles matching `sysdig-*` or the specific session principal)
  2. **Temporarily detach the SCP** during onboarding, then re-attach afterward
  3. **Skip the blocked capability** — Security posture works independently of
     threat detection. If only EventBridge actions are blocked, proceed with
     a posture-only connection
  4. **Use alternative log capture mode** — If EventBridge is blocked, try
     CloudTrail/S3 mode which uses different AWS services
- **Partial success handling:** Terraform creates resources incrementally. If
  posture resources succeed but threat detection fails, the posture resources
  are fully functional.
  Check current state with `terraform state list`. After fixing the SCP, re-run
  `terraform apply` — Terraform only creates the missing resources. Do NOT run
  `terraform destroy` unless you want to remove everything including the working
  posture resources.
- **Source:** Test 4a v2 (2026-02-26) — SCP blocking `events:PutRule` on member account

---

### Sysdig / API

<!-- Entries will be added during Phase 2-5 testing -->

---

## Kubernetes Cluster Onboarding

### Helm Installation

<!-- Entries will be added during Phase 3 testing -->

---

### Agent Connectivity

<!-- Entries will be added during Phase 3 testing -->

---

## Linux Host Onboarding

### Package Installation

<!-- Entries will be added during Phase 6 testing -->

---

### Agent Runtime

<!-- Entries will be added during Phase 6 testing -->

---

## Pre-Flight Checks

These checks should be performed before any onboarding to prevent common
failures:

### All Types
- [ ] Sysdig API token is valid (not expired, has correct scope)
- [ ] Correct Sysdig region identified
- [ ] Network connectivity to Sysdig endpoints (no firewall blocking)

### Cloud Accounts
- [ ] Terraform >= 1.10.0 installed
- [ ] Cloud CLI installed and authenticated
- [ ] Installer has required permissions
- [ ] Target account/project/subscription is accessible

### Kubernetes
- [ ] kubectl can reach the cluster
- [ ] Helm v3.10+ installed
- [ ] Namespace can be created or exists
- [ ] Cluster has outbound internet access (port 443)

### Linux Hosts
- [ ] SSH/root access available
- [ ] Kernel version >= 3.10
- [ ] Package manager functional (apt/yum/dnf)
- [ ] Outbound connectivity to collector endpoint

---

## Post-Install Health Checks

### Cloud Accounts
1. Check Integrations > Cloud Accounts in Sysdig
2. Verify account status shows "Connected" (may take up to 15 min)
3. For security posture: Check Compliance > Posture for resource inventory
4. For threat detection: Check Events for cloud audit trail
5. For agentless scanning: Check Vulnerabilities for scan results (up to 24h)

### Kubernetes
1. `kubectl get pods -n sysdig-agent` — all pods Running
2. `kubectl logs -n sysdig-agent -l sysdig/component=cluster --tail=50` — no errors
3. Check Sysdig > Integrations > Kubernetes for cluster
4. Check Sysdig > Vulnerabilities for runtime scan results

### Linux Hosts
1. `systemctl status sysdig-agent` — active (running)
2. `journalctl -u sysdig-agent --since "5 min ago"` — no errors
3. Check Sysdig > Integrations > Hosts for the host

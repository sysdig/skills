# Troubleshooting Guide

Common errors encountered during Sysdig Secure onboarding and their
resolutions, organized by deployment type and component.

Each entry follows a **symptom → cause → fix** structure so it can be
consumed without prior context about the deployment.

---

## Cloud Account Onboarding

### Permissions / IAM

#### AWS CLI installed but not authenticated

- **Symptoms:** `validate_prereqs.sh aws` reports "AWS CLI: INSTALLED" but
  `check_permissions.sh` fails with "Unable to locate credentials" or
  "ExpiredToken". The AWS CLI binary exists but has no valid session.
- **Cause:** AWS CLI is installed but credentials are not configured or
  the current session has expired. Common scenarios: fresh install
  without `aws configure`, expired SSO session, or missing `AWS_PROFILE` /
  `AWS_ACCESS_KEY_ID` environment variables.
- **Fix options:**
  1. **Named profile:** `aws configure --profile sysdig-onboarding` then
     `export AWS_PROFILE=sysdig-onboarding`
  2. **SSO login:** `aws sso login --profile <profile-name>`
  3. **Environment variables:** Set `AWS_ACCESS_KEY_ID` and
     `AWS_SECRET_ACCESS_KEY` (less recommended — prefer profiles)
  4. **IAM Identity Center:** `aws configure sso`
- **Prevention:** `validate_prereqs.sh` checks both installation **and**
  authentication. Always run it before proceeding to permission checks.

#### Insufficient IAM permissions for Terraform apply

- **Symptoms:** `check_permissions.sh` reports multiple FAIL results for
  write operations such as `iam:CreateRole`, `iam:AttachRolePolicy`, or
  `events:PutRule`. When write permissions are denied, `terraform apply`
  will fail.
- **Cause:** The IAM identity (user or role) running Terraform lacks the
  required permissions. Common when using read-only roles, restrictive
  Service Control Policies (SCPs), or permission boundaries.
- **Fix:**
  1. Review the failed checks — each lists the specific IAM action needed.
  2. Generate `generated/sysdig-required-policy.json` with the minimum IAM
     policy needed for onboarding.
  3. Attach the policy to the IAM identity and re-run
     `check_permissions.sh`.
- **Recovery from a partial apply:** Terraform creates resources
  incrementally, so an apply that fails on a denied IAM write may have
  already created earlier resources before aborting. **Always inspect
  state first** with `terraform state list` before cleaning up:
  - **State contains only data sources** (no `aws_iam_role`,
    `aws_iam_policy`, etc.): nothing was created in AWS. Safe to delete
    the state file or run `terraform destroy`.
  - **State contains real resources:** AWS resources exist and must be
    removed before deleting state, or they will be orphaned. Run
    `terraform destroy` (which requires the same write permissions —
    fix permissions first), or remove the resources manually via the
    AWS console / CLI and then `terraform state rm` each one.
  Never delete the state file without confirming via
  `terraform state list` that it holds no real resources.

---

### Terraform Errors

#### Terraform state drift during offboarding

- **Symptoms:** `terraform plan -destroy` or `terraform destroy` shows
  fewer resources than expected. Some resources show "will be destroyed"
  while others silently disappear from state during the refresh phase.
- **Cause:** Resources (e.g., IAM roles, policies) were deleted outside
  Terraform — manually via the AWS console, by another automation tool,
  or by an AWS Organization SCP cleanup.
- **How Terraform handles it:** During `terraform plan` or
  `terraform destroy`, the AWS provider runs a **refresh** phase that
  reads each resource from the API. If a resource no longer exists, the
  provider automatically removes it from state. This is normal behavior —
  Terraform auto-reconciles drift.
- **When `terraform state rm` is actually needed:** Only when the refresh
  itself fails — e.g., the provider gets an API error (not "not found"
  but an actual error like timeout, permission denied, or malformed
  response) that prevents it from reading the resource. In that case,
  manually remove the unreachable resource with
  `terraform state rm <resource_address>` and retry.
- **Example:** A state with 61 resources, where 2 IAM roles have been
  deleted manually, will refresh to remove 5 resources (2 roles plus 3
  policies attached to them); `terraform destroy` then succeeds for the
  remaining 56 with zero errors.

#### Terraform apply fails with SCP error

- **Symptoms:** `terraform apply` fails with an error containing
  "explicit deny in a service control policy" and an SCP ARN like
  `arn:aws:organizations::ACCOUNT:policy/ORGID/service_control_policy/POLICYID`.
  Some resources may be created successfully while others fail.
- **Cause:** An AWS Organization Service Control Policy (SCP) is blocking
  one or more actions required by the Sysdig Terraform module. SCPs
  override IAM permissions — even `AdministratorAccess` cannot bypass
  them. SCPs only apply to member accounts, not the management account.
- **Note on detection:** `check_permissions.sh` falls back to
  service-level probes when `SimulatePrincipalPolicy` is unavailable
  (common on cross-account assumed roles). These probes confirm basic
  service access but cannot detect action-level SCP restrictions
  (e.g., an SCP blocking `events:PutRule` while `events:ListRules`
  succeeds), so SCP-driven failures may only surface at apply time.
- **Remediation options:**
  1. **Modify the SCP** — Add an exception for Sysdig-related roles
     (e.g., allow actions for roles matching `sysdig-*` or the specific
     session principal).
  2. **Temporarily detach the SCP** during onboarding, then re-attach
     afterward.
  3. **Skip the blocked capability** — Security posture works
     independently of threat detection. If only EventBridge actions are
     blocked, proceed with a posture-only connection.
  4. **Use alternative log capture mode** — If EventBridge is blocked,
     try CloudTrail/S3 mode which uses different AWS services.
- **Partial success handling:** Terraform creates resources
  incrementally. If posture resources succeed but threat detection
  fails, the posture resources are fully functional. Check current state
  with `terraform state list`. After fixing the SCP, re-run
  `terraform apply` — Terraform only creates the missing resources. Do
  **not** run `terraform destroy` unless you want to remove everything,
  including the working posture resources.

---

### Sysdig / API

<!-- TODO: API and onboarding-flow errors -->

---

## Kubernetes Cluster Onboarding

### Helm Installation

<!-- TODO: Helm install, chart version, and namespace errors -->

---

### Agent Connectivity

<!-- TODO: Collector connectivity, TLS, and proxy errors -->

---

## Linux Host Onboarding

### Package Installation

<!-- TODO: apt/yum/dnf installation errors -->

---

### Agent Runtime

<!-- TODO: Agent service, kernel module, and eBPF errors -->

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

# Known Issues

Catalog of known issues, bugs, and limitations affecting Sysdig Secure
onboarding. Each entry follows a **symptom → cause → workaround** structure
and includes status and any relevant external references.

---

## Format

Each entry follows this structure:

```
### [ID] Short title
- **Affected:** Provider / Component / Version
- **Severity:** Critical / High / Medium / Low
- **Description:** What happens
- **Workaround:** How to work around it (if any)
- **Status:** Open / Fixed in vX.Y / Won't fix
- **References:** Links to public docs, upstream issues, etc.
```

---

## Cloud Onboarding

### [AWS-001] simulate-principal-policy reports SCP denials on management accounts

- **Affected:** AWS / `check_permissions.sh` / All versions
- **Severity:** Medium
- **Description:** When an SCP is active in the organization,
  `aws iam simulate-principal-policy` returns
  `AllowedByOrganizations: false` and `implicitDeny` for the management
  account — even though AWS management accounts are exempt from SCPs at
  runtime. Without compensation, the pre-flight check would report a
  false failure for actions blocked by SCPs while the actual
  `terraform apply` succeeds.
- **Workaround:** `check_permissions.sh` auto-detects management accounts
  and downgrades SCP-related failures to warnings when run from a
  management account.
- **Status:** Fixed — auto-detection in `check_permissions.sh`.

### [AWS-002] SCP-based failures cannot be reproduced from the management account

- **Affected:** AWS / All / All versions
- **Severity:** Low (operational limitation)
- **Description:** AWS SCPs do not apply to the management account of an
  organization. Diagnosing SCP-blocked onboarding therefore requires
  credentials from a **member account**, not the management account.
- **Workaround:** From the management account, use
  `aws sts assume-role` with `OrganizationAccountAccessRole` (or another
  cross-account role) to obtain credentials in the affected member
  account, then re-run the failing command.
- **Status:** Documented limitation — no fix needed.

### [AWS-003] check_permissions.sh falls back to service probes on cross-account assumed roles

- **Affected:** AWS / `check_permissions.sh` / All versions
- **Severity:** Medium
- **Description:** When running from a cross-account assumed role (e.g.,
  `OrganizationAccountAccessRole` in a member account),
  `iam:SimulatePrincipalPolicy` itself fails — the assumed role typically
  lacks this permission even with `AdministratorAccess` attached. The
  script automatically detects this and falls back to service-level
  probes: read-only API calls to each required service (IAM,
  EventBridge, S3, etc.) that confirm basic access. Service-level probes
  detect full service blocks (e.g., an SCP denying all EventBridge
  actions) but **cannot** detect action-level restrictions (e.g., an
  SCP blocking `events:PutRule` while `events:ListRules` succeeds).
- **Workaround:** Automatic — the script falls back to service-level
  probes when `SimulatePrincipalPolicy` is unavailable. For action-level
  SCP restrictions, watch for SCP errors during `terraform apply` and
  consult `references/troubleshooting.md` ("Terraform apply fails with
  SCP error") for remediation.
- **Status:** Fixed — service-level fallback probes implemented.

---

## Kubernetes / Shield

<!-- TODO: Cluster Shield Helm install, RBAC, and runtime issues -->

---

## Linux / Host Shield

<!-- TODO: Host Shield install, kernel, and eBPF issues -->

---

## Sysdig Product Improvement Suggestions

Issues that aren't bugs but represent gaps where Sysdig product
improvements (mainly APIs) would simplify the onboarding experience.

### Template

```
### [IMPROVEMENT-ID] Short title
- **Area:** API / UI / Terraform Provider / Documentation
- **Current behavior:** What exists today
- **Desired behavior:** What would make onboarding easier
- **Impact:** How many users / scenarios this affects
- **Workaround:** How the skill handles it today
```

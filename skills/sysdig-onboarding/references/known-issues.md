# Known Issues

Catalog of known issues, bugs, and limitations discovered during testing or
reported by support teams. Each entry includes workarounds where available.

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
- **References:** Links to tickets, docs, etc.
```

---

## Cloud Onboarding

### [AWS-001] simulate-principal-policy reports SCP denials on management accounts
- **Affected:** AWS / check_permissions.sh / All versions
- **Severity:** Medium
- **Description:** When an SCP is active in the organization, `aws iam
  simulate-principal-policy` returns `AllowedByOrganizations: false` and
  `implicitDeny` for the management account — even though AWS management
  accounts are exempt from SCPs at runtime. This causes the pre-flight check
  to report a false failure for actions blocked by SCPs. The actual `terraform
  apply` succeeds. Fixed in the skill as of 2026-02-26 (warns instead of fails
  when running from management account).
- **Workaround:** The updated `check_permissions.sh` detects management
  accounts and downgrades SCP-related failures to warnings.
- **Status:** Fixed (check_permissions.sh auto-detects management account)
- **References:** Test 4a (2026-02-26), DEVLOG 2026-02-26

### [AWS-002] SCP-based failures cannot be reproduced from the management account
- **Affected:** AWS / All / All versions
- **Severity:** Low (testing/tooling limitation)
- **Description:** AWS SCPs do not apply to the management account of an
  organization. To test SCP-blocked onboarding, credentials from a **member
  account** are required. The management account can assume roles into member
  accounts via `OrganizationAccountAccessRole`.
- **Workaround:** Use `aws sts assume-role` to obtain credentials for a member
  account before running SCP-restricted tests.
- **Status:** Resolved — member account 402830379190 created for Test 4a v2
- **References:** Test 4a (2026-02-26), Test 4a v2 (2026-02-26)

### [AWS-003] check_permissions.sh falls back to service probes on cross-account assumed roles
- **Affected:** AWS / check_permissions.sh / All versions
- **Severity:** Medium
- **Description:** When running from a cross-account assumed role (e.g.,
  `OrganizationAccountAccessRole` in a member account),
  `iam:SimulatePrincipalPolicy` itself fails — the assumed role typically
  lacks this permission even with `AdministratorAccess`. The script
  automatically detects this and falls back to service-level probes: read-only
  API calls to each required service (IAM, EventBridge, S3, etc.) that confirm
  basic access. Service-level probes detect full service blocks (e.g., an SCP
  denying all EventBridge actions) but cannot detect action-level restrictions
  (e.g., an SCP blocking `events:PutRule` while `events:ListRules` succeeds).
- **Workaround:** Automatic — the script falls back to service-level probes
  when `SimulatePrincipalPolicy` is unavailable. For action-level SCP
  restrictions, users should watch for SCP errors during `terraform apply`
  and consult `references/troubleshooting.md` for remediation.
- **Status:** Fixed — service-level fallback probes implemented
- **References:** Test 4a v2 (2026-02-26), DEVLOG 2026-02-26

---

## Kubernetes / Shield

<!-- Entries will be added during Phase 3 -->

---

## Linux / Host Shield

<!-- Entries will be added during Phase 6 -->

---

## Sysdig Product Improvement Suggestions

Issues that aren't bugs but represent gaps where Sysdig product improvements
(mainly APIs) would simplify the onboarding experience.

<!-- Entries will be added from DEVLOG.md when recurring patterns emerge -->

### Template

```
### [IMPROVEMENT-ID] Short title
- **Area:** API / UI / Terraform Provider / Documentation
- **Current behavior:** What exists today
- **Desired behavior:** What would make onboarding easier
- **Impact:** How many users / scenarios this affects
- **Workaround:** How we handle it in the skill today
```

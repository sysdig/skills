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

### [CLOUD-001] Transient connection/health error immediately after apply (IAM/RBAC propagation)

- **Affected:** AWS / GCP / Azure / All versions
- **Severity:** Low (cosmetic, self-healing)
- **Description:** Right after `terraform apply`, the cloud account's health
  check may report a single transient error — for example, an Azure Event Hub
  namespace showing "N user errors over the last 15 minutes", or an AWS/GCP
  role or binding briefly reading as unreachable. Cloud IAM is eventually
  consistent: a role assignment or IAM binding created during apply can take one
  to a few minutes to become effective, so a backend health probe that runs
  before propagation completes gets a 401/403, which the provider records as a
  user error. The account status page can keep showing this stale error until
  the next scheduled validation (which may be up to ~24h later), even though
  ingestion and consumption are already healthy.
- **Workaround:** No action needed — it self-heals once propagation completes.
  To clear the stale status immediately instead of waiting for the next
  scheduled check, re-run validation for the account:
  `POST /api/cloudauth/v1/accounts/{accountId}/validate` (re-runs the connection
  check only; it does not change configuration). When in doubt, confirm live
  health from the provider's own metrics (e.g., Azure Event Hub `UserErrors` vs
  `IncomingMessages`/`OutgoingMessages`) rather than the last cached status.
- **Status:** Documented behavior — cloud IAM propagation timing, not an
  onboarding defect.

### [AZURE-001] check_permissions.sh resolves a service-principal identity when there is no signed-in user

- **Affected:** Azure / `check_permissions.sh` / All versions
- **Severity:** Medium
- **Description:** When the Azure CLI is authenticated non-interactively as a
  service principal (`az login --service-principal`) rather than a delegated
  user, `az ad signed-in-user show` returns nothing. Without compensation the
  pre-flight cannot read the identity's object id, so every RBAC and Entra ID
  role check falls through to "cannot verify" and reports false negatives — even
  when the service principal actually holds Owner plus Application Administrator
  and Privileged Role Administrator.
- **Workaround:** Automatic — when no signed-in user is found, the script
  detects a service-principal login and resolves the service principal's object
  id (`az ad sp show --id <appId>`), then runs the same RBAC and Entra role
  queries against it.
- **Status:** Fixed — service-principal fallback in `check_permissions.sh`.
- **Note — `ARM_CLIENT_*` environment credentials are a different case.**
  Terraform authenticates directly from `ARM_CLIENT_ID` / `ARM_CLIENT_SECRET` /
  `ARM_TENANT_ID` / `ARM_SUBSCRIPTION_ID` without any Azure CLI session, but the
  pre-flight script drives the `az` CLI. With only those variables exported and
  no `az login`, the script stops at `Cannot determine Azure subscription. Run
  'az login'` and never reaches the fallback above. Either skip the pre-flight in
  that mode and rely on the apply-time errors, or establish an Azure CLI session
  first with `az login --service-principal -u "$ARM_CLIENT_ID" -p
  "$ARM_CLIENT_SECRET" --tenant "$ARM_TENANT_ID"`, then `az account set
  --subscription "$ARM_SUBSCRIPTION_ID"`.
  Note that `az login` accepts a client secret only as a command-line argument, so
  the secret is visible in the process list (`ps`) and, if typed rather than
  expanded from an environment variable, in shell history. On a shared or
  CI-audited host, prefer a certificate (`-p /path/to/cert.pem`), a federated
  token (`--federated-token`), or a managed identity (`--identity`) — or skip the
  pre-flight.

---

## Kubernetes / Shield

<!-- TODO: Cluster Shield Helm install, RBAC, and runtime issues -->

---

## Linux / Host Shield

### [HOST-001] Container reports `healthy` while the agent inside crash-loops

- **Affected:** Linux host / Docker install method (`quay.io/sysdig/agent-slim`) / agent 14.x
- **Severity:** High
- **Description:** A fatal error in any agent **subprocess** (posture analyzer,
  host scanner, …) terminates the whole agent, and `--restart always` relaunches
  it — typically every ~2 seconds. The image healthcheck does not track the agent
  process, so `docker ps` keeps reporting `Up … (healthy)` and
  `docker ps`-based verification passes. The log shows repeated
  `Sent msgtype=10 (DIRTY_SHUTDOWN_REPORT)` from changing PIDs,
  `error_handler:150: agent didn't terminate cleanly`, and no
  `Sent msgtype=1 (METRICS)`. The most common trigger is the Docker socket
  bind-mounted somewhere other than the container-internal
  `/var/run/docker.sock`: the container-scanning component connects to
  `unix:///var/run/docker.sock` inside the container and ignores
  `system.runtimes.docker[].socket` in the config file.
- **Workaround:** Verify container liveness with
  `docker inspect sysdig-agent --format '{{.RestartCount}} {{.State.Running}}'`,
  a `Fatal` / `DIRTY_SHUTDOWN` count of 0 in
  `/opt/draios/logs/draios.log` (read via `docker exec`), and a stable PID across
  `Sent msgtype=1` lines — never `docker ps` alone. Mount the socket at
  `/var/run/docker.sock` and recreate the container.
- **Status:** Open (agent behaviour: a subprocess fatal is not scoped to that
  subprocess)
- **References:** https://docs.sysdig.com/en/sysdig-secure/install-agent-containers/

---

### [HOST-002] Re-onboarding the same host publishes no new posture/vulnerability results

- **Affected:** Linux host / all install methods
- **Severity:** Low
- **Description:** Scan work is deduplicated per host identity (host ID / MAC),
  not per agent installation. Re-installing on a host that was scanned recently —
  a driver change, a package→container migration, a re-run the same day — gets no
  work assigned: `host-scanner: already extracted sbom recently: skipping scan`,
  and the posture analyzer sits in `polling for pending scan requests` with
  nothing to do. Nothing is wrong with the install, but a verification that
  requires `published scan result` or a fresh SBOM reports a false failure.
- **Workaround:** Verify that the analyzers are **armed** (started, config
  accepted, checks retrieved, backend reachable) rather than that results were
  published. Results appear on the backend's next scheduled scan for that host.
- **Status:** Working as designed (backend deduplication)
- **References:** —

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

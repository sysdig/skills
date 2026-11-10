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

### [CLOUD-002] `terraform apply` turns off Validated Exposure set in Sysdig

- **Affected:** AWS / GCP / Azure / configurations whose `config_posture`
  feature resource has no `lifecycle { ignore_changes = [flags] }`, or that use
  a `sysdiglabs/sysdig` provider older than 3.11.2
- **Severity:** Medium
- **Description:** Validated Exposure is stored as a flag on the Posture
  feature. When the Terraform configuration does not ignore that resource's
  `flags`, every `terraform apply` writes back the flags the configuration
  declares — none — and turns Validated Exposure off again after it was enabled
  in Sysdig. Provider versions before 3.11.2 also drop feature flags whenever
  the cloud account resource itself is updated.
- **Workaround:** Add `lifecycle { ignore_changes = [flags] }` to the
  `sysdig_secure_cloud_auth_account_feature` resource of type
  `FEATURE_SECURE_CONFIG_POSTURE`, set the provider constraint to
  `>= 3.11.2, < 4.0.0`, delete only the
  `provider "registry.terraform.io/sysdiglabs/sysdig"` block from
  `.terraform.lock.hcl`, and run `terraform init` (without `-upgrade`, which
  would also move modules and other providers to newer versions). The next
  `terraform plan` should show no change to that resource; review any change it
  shows to other existing resources before applying.
- **Status:** Fixed in configurations generated by this skill; older
  configurations need the workaround once.

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

### [HOST-003] `draios-agent-kmodule` driver build fails silently without `dkms` (Amazon Linux 2023)

- **Affected:** Linux host / rpm install / Amazon Linux 2023 (and minimal RHEL images)
- **Severity:** High
- **Description:** The kmodule package builds the driver from an RPM `%post`
  scriptlet that shells out to `dkms`, which is not preinstalled. The scriptlet
  fails with `dkms: command not found` (exit status 127) but `yum`/`dnf` reports
  the transaction as successful, so the agent starts with no syscall source while
  the service, auth, connectivity and credential checks all pass.
- **Workaround:** Install `dkms` before the agent
  (`yum install -y dkms kernel-devel-$(uname -r)`). On an affected host:
  `dnf install -y dkms && dnf reinstall -y draios-agent-kmodule && systemctl restart dragent`.
  Confirm with `Successfully loaded scap driver` in
  `/opt/draios/logs/draios.log` plus `lsmod | grep sysdigcloud_probe`. Where
  `dkms` or matching headers are unavailable, use the `universal_ebpf` driver.
- **Status:** Open (packaging: a failed driver build should fail the install)
- **References:** —

---

### [HOST-004] Telemetry log lines never reach journald at the default log level

- **Affected:** Linux host / all install methods
- **Severity:** High
- **Description:** `Sent msgtype=1 (METRICS)`, the collector handshake and the
  driver-load line are all **Information** level. With `log_level: warn` — a
  common setting, and the one the generated config uses — the console/journald
  sink drops them, so `journalctl -u dragent --grep "Sent msgtype=1"` returns
  nothing on a fully healthy agent. Verification that reads journald concludes
  the agent never authenticated. `docker logs` is the same console sink under the
  same gate, so it fails identically on container installs.
  Config rejections and self-disabled features were also missing from journald in
  the observed run, but `log_level` does not explain those: they are `Critical`,
  which `warn` does not gate. Cause unknown — read them from the file sink on
  observation, not on this theory.
- **Workaround:** Read `/opt/draios/logs/draios.log` (written because
  `log_persist: true`; root-only, so `sudo`, or `docker exec` for a container
  install). Raising `log_level` to `info` should surface the Information lines in
  journald (untested) and will not help with the `Critical` ones.
- **Status:** Working as designed for the Information lines (log-level
  semantics); documentation issue. The `Critical` half is unexplained.
- **References:** —

---

### [HOST-005] The agent initializes twice; the first feature summary reports almost everything disabled

- **Affected:** Linux host / all install methods
- **Severity:** Low
- **Description:** The agent runs two initialization passes ~12 s apart. The
  first happens before the backend handshake and logs a feature summary with
  `secure`, drift control, malware control, dns detection, response actions,
  baseliner and memdump all `Disabled`; the second flips them to `Enabled`.
  There are no `DIRTY_SHUTDOWN` lines — it is a planned re-init, not a crash. A
  verification that greps the whole log for `disabled` hits the stale first
  summary and reports healthy capabilities as dead.
- **Workaround:** Read only the **last** `Feature manager initialization
  completed` block and take each capability's state from it. The capability lines
  precede that line, so slice backwards from its line number:
  `n=$(sudo grep -n "Feature manager initialization completed" /opt/draios/logs/draios.log | tail -1 | cut -d: -f1)`
  then `sudo sed -n "$(( n > 40 ? n - 40 : 1 )),${n}p" …`. A whole-file grep also
  hits the stale block, so any `disabl*` hit below `$n` is expected, not a
  failure.
- **Status:** Working as designed
- **References:** —

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

### [HOST-006] Agent crash-loops when a feature is set in both its flat and nested form

- **Affected:** Linux host / all install methods
- **Severity:** High
- **Description:** The agent runtime treats the flat top-level feature switch
  (e.g. `live_logs.enabled`, `drift_control.enabled`,
  `secure_audit_streams.enabled`, `network_topology.enabled`,
  `sysdig_capture_enabled`) and its nested `features.*` counterpart as
  **alternate keys**. If both appear in `dragent.yaml` the agent fails to start:
  `Failed to init configuration. Exception message: live_logs.enabled and
  features.investigations.live_logs.enabled are alternate keys but exist in the
  same yaml file`, exits 70, and (under `--restart always` / systemd) restarts
  continuously. On the Docker method this can present as a container that
  restarts every ~2 s while `docker ps` still reports `healthy`.
- **Workaround:** Emit each feature in **one** form only. Use the nested
  `features.*` tree and do not also emit the flat spelling. Response actions are
  gated by the same mechanism — resolve `features.respond.response_actions.enabled`
  from the profile's §5.2 row (via the `{{RESPONSE_ACTIONS_ENABLED}}` placeholder),
  not hardcoded `true`; a profile that does not select response (e.g. Posture &
  Compliance) must resolve it `false` so remote kill/quarantine is not armed.
- **Status:** Fixed — the generated config uses the nested tree only. Confirmed
  live on the **container (Docker)** method: no init crash, and the nested keys
  are honoured — including `captures`, which drives the `memdump` capability
  (`Enabled` for nested `captures: true`, `Disabled` for `false`), so it is not
  silently lost. The **rpm** package method also accepted the nested-only config
  in a prior run. Package-method confirmation on **deb** is the one remaining
  live check; the config parser is the same agent binary across methods, so the
  behaviour is expected to be identical.
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

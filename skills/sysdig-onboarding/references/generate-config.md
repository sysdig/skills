# Generate Configuration (Step 7 detail)

Procedural detail for [SKILL.md](../SKILL.md) **Step 7**. Read ALL required
templates in a single parallel batch at the start of the step — main template +
`variables.tf` + optional `backend_*.tf`. Do not read templates before Step 7.
**Proceed directly to file generation with no intermediate output** — do not
explain which templates you read, which sections you are removing, or which
capabilities were excluded. Just say you are generating the configuration and
write the files.

## For cloud accounts

1. Select template from `templates/` (e.g., `aws_single_account.tf`).
2. Replace all `{{PLACEHOLDER}}` values with user's answers. A few placeholders
   are **optional and delete-by-default** (e.g. `{{EVENT_BRIDGE_EVENT_PATTERN}}`):
   when there's no value, delete the placeholder line (and its comment block)
   rather than substituting — never leave a literal `{{...}}` token.
3. **AWS account pinning:** Always set `profile` and `allowed_account_ids`
   in the `provider "aws"` block using the values confirmed in Step 2b.
   This ensures Terraform fails fast if credentials don't match the
   intended account. See template comments for the pattern.
4. Remove unselected capabilities using `# === MARKER ===` / `# === END MARKER ===`
   delimiters. See [features.md](features.md).
5. If remote backend, include matching `templates/backend_*.tf`.
6. Adapt for special requirements. See provider references.
7. **Lint:** run `scripts/lint_config.sh` on every generated file — it must
   report `OK` (no leftover `{{...}}`, balanced markers, no
   mutually-exclusive marker pair). Fix errors and re-run before continuing.
8. Present completed Terraform for review.
9. Token is in `.sysdig-token` (Step 0b). Use
   `source .sysdig-token && terraform plan`. Ensure `.gitignore`
   covers `*.tfvars` and `.sysdig-token`.
10. Run `source .sysdig-token && terraform init` and
    `source .sysdig-token && terraform plan` proactively.
    For AWS with a specific profile, put the prefix on the `terraform`
    invocation — `source .sysdig-token && AWS_PROFILE=<name> terraform plan`
    (a prefix on `source` does not reach terraform).

    **Generate the files into the directory these commands run from** — the
    current working directory. Terraform reads the configuration from the
    working directory and never searches upward, so a config written anywhere
    else leaves `terraform plan` reporting `No configuration files`, which
    reads like a generation failure but is not one. Note that `terraform init`
    exits 0 in a directory with no configuration at all ("Terraform
    initialized in an empty directory!"), so init succeeding proves nothing
    here. Write `.sysdig-token` alongside the config so
    `source .sysdig-token` resolves too. Do not `cd` and do not add
    `-chdir=<dir>`: neither form matches the `allowed-tools` patterns in
    SKILL.md, so both turn a pre-approved terraform call into a permission
    prompt. This holds for the isolated-directory option in
    [incremental-onboarding.md](incremental-onboarding.md) Merge Strategy too —
    an isolated directory is one the terraform commands *run from*, not one the
    skill changes into.

**Terraform plan summary:** After `terraform plan`, parse the summary line
and present a structured overview:
```
**Plan:** 8 to create, 0 to change, 0 to destroy
- 2 IAM roles, 2 IAM policies, 4 Sysdig feature registrations
```

Then offer `terraform apply` — **only with explicit user approval**.

## For Kubernetes clusters

Read [shield.md §6–7](shield.md) for Helm commands and values
reference. Generate `values.yaml` from `templates/shield-values.yaml`:
replace `{{PLACEHOLDER}}` values, flip `enabled: true` for selected features
(see [shield.md §5.2](shield.md) for profile mapping), and remove
unused PROXY/CUSTOM_CA sections. Run `scripts/lint_config.sh values.yaml`
(must report `OK`), then `helm template` proactively to validate, then
present `helm upgrade --install` for user approval.

**Agent Access Key:** leave `sysdig_endpoint.access_key` as its literal
`REPLACE_WITH_YOUR_SYSDIG_AGENT_ACCESS_KEY` placeholder — it is **not** a
`{{PLACEHOLDER}}` and the skill must not fill it. The user edits that line in
`values.yaml` directly (Sysdig UI → Settings → Agent Keys), the same as they
edit `.sysdig-token` for the Cloud path. Never ask the user to paste the key in
chat, never pass it via `helm --set`, and never route it through a
`! export`-style env var — the commands the agent runs execute in fresh subshells
that don't inherit the user's interactive shell, so that value never reaches
Helm. See [shield.md §7.2](shield.md) for the full rule.

**Windows nodes:** If the cluster has Windows nodes and Windows coverage was
selected, also set `host_windows.enabled: true` and enable **only**
`host_posture` and `host_vulnerability_management` in the Windows feature
block — leave every other Windows feature off (they are silently dropped /
no-ops on Windows). The Windows DaemonSet ships in the same `sysdig/shield`
chart and is configured through the same `values.yaml`. See
[shield.md "Windows Nodes (Kubernetes DaemonSet)"](shield.md).

## For Linux hosts

Read [host-shield.md](host-shield.md) for driver types (§2), feature profiles
and mapping (§4c/§5), and install methods (§6). Generate the config from
`templates/host-shield.yaml` (NOT `dragent.yaml` — that's only the on-host
filename at `/opt/draios/etc/dragent.yaml`):

1. Replace all `{{PLACEHOLDER}}` values with the user's answers (access key,
   region, driver type — see [host-shield.md §7.2/§7.4](host-shield.md)).
   **`{{SYSDIG_API_URL}}`, `{{COLLECTOR_HOST}}` and `{{COLLECTOR_PORT}}` are
   mandatory, SaaS included** — resolve all three from the region table in
   [host-shield.md §7.2](host-shield.md). The `region` shorthand is ignored by
   the agent runtime: without `api_url` host posture and host vulnerability
   scanning are silently disabled, and without `collector.host` every
   non-us1 region silently talks to the us1 collector.
2. Set each feature's nested `enabled` per the profile → feature mapping in
   [host-shield.md §5.2](host-shield.md). The profile-varying runtime switches
   are `{{..._ENABLED}}` placeholders in the nested tree
   (`{{DRIFT_CONTROL_ENABLED}}`, `{{MALWARE_CONTROL_ENABLED}}`,
   `{{ACTIVITY_AUDIT_ENABLED}}`, `{{CAPTURES_ENABLED}}`, `{{LIVE_LOGS_ENABLED}}`,
   `{{NETWORK_SECURITY_ENABLED}}`, `{{RESPONSE_ACTIONS_ENABLED}}`): resolve each
   to `true`/`false` from its §5.2 column — `lint_config.sh` errors on any left
   unresolved. Every other feature ships a fixed value; set it directly per §5.2.
   Two rules that are easy to miss:
   - **Nested `features.*` only — never emit the flat spelling of the same
     feature.** The agent treats the flat form (`drift_control.enabled`,
     `live_logs.enabled`, `secure_audit_streams.enabled`,
     `network_topology.enabled`, `sysdig_capture_enabled`, …) and its nested
     counterpart as *alternate keys*: emitting both crash-loops the agent with
     `Failed to init configuration … are alternate keys but exist in the same
     yaml file` (exit 70). The nested tree is honoured on a package/container
     install — see [host-shield.md §5.1b](host-shield.md). Set every capability
     in the nested tree only; a feature the §5.2 mapping does not enable is
     `false` (never guess `true` — `live_logs: true` streams container logs the
     user did not ask for). `event_forwarder` is pinned `false` in the template.
   - **Response actions are armed only by `enabled`, and it is destructive.** The
     per-action trigger map arms nothing on its own — the agent reports
     `response actions: Disabled` without the key ([host-shield.md §5.1c](host-shield.md)).
     Resolve `{{RESPONSE_ACTIONS_ENABLED}}` to `true` only for a profile that
     selected response (Detect & Respond, Full); a Posture & Compliance host must
     resolve it `false`, or it ships remote kill/quarantine armed on a host that
     never opted in.
3. Remove unused PROXY / CUSTOM_CA sections using
   `# === MARKER ===` / `# === END MARKER ===` delimiters.
4. Run `scripts/lint_config.sh <generated-file>` — it must report `OK` before
   you hand any install command to the user. It catches unresolved
   `{{PLACEHOLDER}}` tokens and dangling feature markers mechanically. If you
   re-lint **after** the user has pasted their Agent Access Key into the file,
   pass `--user-filled` so the credential-literal warning stays quiet on that
   expected step (never pass it on a freshly generated file).
5. Provide install commands from [host-shield.md §6](host-shield.md), branching
   on the install method chosen in §4b. **The generated config is the same file
   in both branches** — there is no env-var configuration path, so a container
   without the mounted file gets no features, no `api_url` and no collector:
   - **Package (DEB §6.1 / RPM §6.2)** — install the package, place the config at
     `/opt/draios/etc/dragent.yaml` (mode `600`), then
     `systemctl enable --now dragent`.
   - **Docker container (§6.3)** — place the config on the host (e.g.
     `/opt/sysdig/dragent.yaml`, mode `600`) and bind-mount it read-only:
     `-v /opt/sysdig/dragent.yaml:/opt/draios/etc/dragent.yaml:ro`. Never pass
     the access key or collector as `-e` flags (readable via `docker inspect`,
     kept in shell history). Build the mount list from the selected
     features — `-v /:/host:ro` plus `-v /dev:/host/dev` whenever host posture
     or host vulnerability management is on. The Docker socket mount is paired
     with `host_scanner.host_fs_mount_path` (§6.3): with the key unset (the
     template's default) mount the socket at the container-internal path
     `/var/run/docker.sock`; when **host vulnerability management** is selected,
     add `host_scanner.host_fs_mount_path: /host` +
     `kspm_analyzer.host_root: /host` to the config and mount the socket at
     `/host/var/run/docker.sock` instead — otherwise the scanner inventories the
     container's own filesystem. Never mix a `/host` socket mount with the key
     unset: that crash-loops the agent. The container starts on `docker run`
     (`--restart always` covers reboots).
   In both branches the **user** fills the Agent Access Key by editing the file;
   the skill never puts it on a command line or asks for it in chat.
6. Run post-install verification from [host-shield.md §8](host-shield.md). See
   [verification.md](verification.md) for the subagent procedure.

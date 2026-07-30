# Runtime (threat-detection) policies — MCP tools

The "initial run of enable/disable policies": turn on the recommended
Sysdig-managed runtime detection policies, via the Sysdig MCP server (no
token/`curl`).

## Tools

| Purpose | Tool |
|---|---|
| List policies | `list_runtime_policies` |
| Enable / disable one | `update_runtime_policy` |

## Model

A **runtime policy** detects threats and is simply on or off (`enabled`). Each
has `id`, `name`, `enabled`, `severity`, `origin`, and `type` — the detection
source. Observed `type` values: `falco` (syscall/runtime), `drift`, `malware`,
`machine_learning`, `k8s_audit`, `windows`, and cloud logs (`aws_cloudtrail`
and variants, `gcp_auditlog`, `azure_entra`/`azure_platformlogs`, `okta`,
`github`, `guardduty`).

`origin`: `Sysdig` = managed (recommended baseline); `Secure UI` = tenant-authored
(custom). Filter `origin == "Sysdig"` for the managed baseline.

## Enable/disable — `update_runtime_policy`

Args: `policy_id`, `enabled` (bool). The tool does the read-modify-write
(the API requires a full-object PUT; the tool GETs the policy, flips `enabled`,
and PUTs it back) — you just pass the target state.

## Baseline guidance & safety

- **Prefer enabling `origin: Sysdig` (managed)** policies for the relevant
  detection types (`falco`, `drift`, `malware`, `machine_learning`, `k8s_audit`
  for Kubernetes; cloud-log types only where that cloud is connected).
- **Enabling adds detections/alerts** — it does not block workloads or deploys
  (unlike VM `admission_control`); blast radius is alert volume. Confirm before a
  bulk enable.
- **Do not bulk-disable** managed policies (silently removes coverage) and
  **never delete** a policy — only on explicit request.
- Per-rule / per-policy tuning belongs to the dedicated tuning skill; this flow is
  on/off only.

## Idempotency

Skill-side pre-check: if a policy is already at the desired `enabled` value,
**skip** — don't re-issue `update_runtime_policy`. Report
`enabled`/`disabled`/`skipped`/`failed`.

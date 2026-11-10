# Autonomous Mode (Step 3-AUTO)

In autonomous mode the user provides all parameters at once. Accept as
inline text, a YAML/JSON block, or an existing `environment.yaml`.

## Required Parameters

```yaml
target: cloud              # cloud | kubernetes | host
provider: aws              # aws | gcp | azure
scope: single              # single | organization
sysdig_region: us1         # us1, us2, eu1, au1, me1, us4
blocks: [trust, threat_detection, advanced_identity, host_scanning, workload_scanning]
                           # trust always required; the rest are optional.
                           # workload_scanning is AWS-only.
cdr_mode: eventbridge      # eventbridge | cloudtrail (AWS; applies when
                           # threat_detection or advanced_identity is selected)
log_sources: all           # optional, EventBridge only. "all" (default) =
                           # Default Setup → DELETE the {{EVENT_BRIDGE_EVENT_PATTERN}}
                           # placeholder line. To trim, list tokens from the
                           # canonical table in log-source-customization.md, e.g.
                           # [cloudtrail_management, console_signin, guardduty];
                           # build event_pattern per that file's algorithm.
host_scanning_extras: [container, malware]  # optional; malware is Preview
validated_exposure: false  # optional; true | false (default). Resolves
                           # {{VALIDATED_EXPOSURE_ENABLED}} on config_posture.
backend: local             # local | s3 | gcs | azurerm
```

Per-feature regions follow the same options
as the guided flow — see [interview-questions.md](interview-questions.md) Step 3d
and [features.md](features.md) for the capability→marker mapping. Older inputs
using `cloud_logs` (→ `threat_detection`) and `scanning` (→ `host_scanning`)
should be mapped to the names above.

## Flow

1. Parse and validate — report missing/invalid params specifically
2. Show Trust Preamble (Step 0) — always
3. Run preflight checks (Step 6) — halt on failure
4. Show confirmation table (Step 5b) — user must approve before generation
5. Generate configuration (Step 7) and present for review
6. Run `terraform init` + `terraform plan` automatically
7. **PAUSE for explicit user approval before `terraform apply`**
8. After apply: verify (Step 8) and update logs (Step 9)

If any param is missing, ask only for that specific value.

**Optional placeholders are deleted, not left unresolved.** When `log_sources`
is omitted or `all`, remove the `{{EVENT_BRIDGE_EVENT_PATTERN}}` placeholder line
(and its comment block) from the template — never leave the literal `{{…}}`
token or emit an empty `event_pattern`.

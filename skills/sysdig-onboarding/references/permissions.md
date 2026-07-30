# Permission Pre-Flight (Step 6a detail)

Agent-facing guide for the cloud permission pre-flight — permission issues
are the #1 onboarding failure cause, so this runs BEFORE generating
configuration. The full command catalog, risk tiers, and copy-paste
`settings.json` patterns live in
[permission-patterns.md](permission-patterns.md).

## How to run

Spawn a subagent (a small/fast model, e.g. Haiku, is sufficient) to run:

```
scripts/check_permissions.sh <provider> <scope> <features> [--aws-profile NAME]
```

- `<provider>`: `aws` | `gcp` | `azure`
- `<scope>`: `single` | `organization`
- `<features>`: comma-separated keys from the mapping below
- Pass `--aws-profile <name>` whenever the user confirmed a specific AWS
  profile in Step 2b (identity pinning).

The subagent returns a structured pass/fail/warn summary — relay failures,
not the raw output.

## Capability → `<features>` keys

Pass every selected capability's key (comma-separated) so the preflight
checks each one's permissions:

| Capability | `<features>` key |
|-----------|------------------|
| Foundational (always) | `cspm` |
| Threat Detection | `cdr` (EventBridge) or `cdr_cloudlogs` (CloudTrail/S3) |
| Advanced Identity Analysis | `ciem` **plus** the `cdr`/`cdr_cloudlogs` key (on AWS the `ciem` key adds no probe on its own — its permissions ride on the Cloud Logs module, so the `cdr`/`cdr_cloudlogs` key is what matters) |
| Host Scanning (Agentless) | `vm` |
| Workload Scanning | `workload_scanning` |

Example: Host + Workload Scanning on one account → `cspm,vm,workload_scanning`.

## When SimulatePrincipalPolicy is unavailable (fallback)

The script prefers `aws iam simulate-principal-policy` (action-level
accuracy). Cross-account **assumed roles** commonly cannot use it — the
script then falls back to **service-level probes** (read-only calls per
service) automatically. Caveats to relay when the fallback ran:

- Reduced granularity — probes confirm service access, not individual actions.
- Probes **cannot detect action-level SCP restrictions** (e.g. an SCP that
  blocks `events:PutRule` but allows `events:ListRules`). If
  `terraform apply` later fails with an SCP error, see
  [troubleshooting.md](troubleshooting.md).
- **Management accounts** are exempt from SCPs at runtime — SCP denials
  reported there by simulation are warnings (known false positive), not
  failures.

## If checks fail

Do not proceed to generation. Explain the missing permissions in plain
language, offer to write `sysdig-required-policy.json` with the missing
actions so an admin can grant them, and re-run the pre-flight via subagent
after the user confirms the fix.

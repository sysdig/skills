# Incremental Onboarding

Support adding features to an already-onboarded account without full
re-onboarding.

## Detection

Check for existing onboarding state:

1. Read `environment.yaml` — check if the account already appears in `accounts:`
2. If a Terraform working directory exists, run `terraform state list` to
   identify which modules/features are already deployed

## Flow

1. Show what's already configured:
   ```
   **Existing setup for AWS 123456789012:**
   - Connection (security posture, identity analysis) — active
   - Threat Detection (Cloud Logs) — not configured
   - Host Scanning (Agentless) — not configured
   ```

2. Ask what to add. Offer the same capability set as initial onboarding (see
   [interview-questions.md](interview-questions.md) Step 3d), minus anything
   already deployed. Omit AWS-only items (Workload Scanning)
   for GCP/Azure accounts:
   ```json
   {
     "question": "Which capabilities do you want to add to this account?",
     "header": "Add Features",
     "multiSelect": true,
     "options": [
       {"label": "Threat Detection", "description": "Cloud Logs for real-time threat detection"},
       {"label": "Advanced Identity Analysis", "description": "Usage-based least-privilege; builds on Threat Detection's data"},
       {"label": "Host Scanning (Agentless)", "description": "Host-disk vulnerability scanning (+ container/malware sub-options)"},
       {"label": "Workload Scanning", "description": "Scan ECS + Lambda container images (AWS only)"}
     ]
   }
   ```
   Additive options only — do not add a "None" / "nothing more" checkbox here
   (see [interview-questions.md](interview-questions.md) Picker rules); if the
   user wants nothing, they submit an empty selection and this step ends.
   Run the matching Step 3d sub-questions (log capture method, per-feature
   regions, Host Scanning extras) for whatever the
   user adds.

3. Generate only the delta Terraform — add new module blocks to the existing
   configuration file, keeping existing resources untouched

4. Run `terraform plan` — should show only new resources (additions),
   zero changes to existing resources

## Merge Strategy

- **Same Terraform directory:** Append new module blocks and feature
  registrations to the existing `.tf` file. Terraform handles the merge
  automatically — existing resources won't be touched.
- **New Terraform directory:** If the user prefers isolation, generate a
  separate config that references the same Sysdig account. Note: this
  requires the onboarding module output (account ID) to be shared via
  `terraform_remote_state` or a data source.

## When to Use `terraform import`

Only needed when:
- Resources were created outside Terraform (e.g., via Sysdig or another tool)
- The user wants to bring existing resources under Terraform management
- There's a state mismatch between what Terraform knows and what exists

Do NOT use import for standard incremental onboarding — just add new blocks.

## Dependency Warnings

| Adding | Requires | Warning |
|--------|----------|---------|
| Threat Detection | Onboarding module | Already present if Connection exists |
| Advanced Identity Analysis | Threat Detection (Cloud Logs) + Connection | "Advanced Identity Analysis needs both Connection and Cloud Logs" |
| Host Scanning (Agentless) | Onboarding module | Already present if Connection exists |
| Workload Scanning | Onboarding module (AWS only) | Omit for GCP/Azure |

## Confirmation Table

Add an "existing" vs "new" indicator:

| Capability | Status |
|-----------|--------|
| Security posture | existing |
| Identity analysis (foundational) | existing |
| Threat Detection (EventBridge) | **new** |
| Advanced Identity Analysis | **new** |

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
   - Cloud Logs (threat detection) — not configured
   - Agentless Scanning — not configured
   ```

2. Ask what to add:
   ```json
   {
     "question": "Which blocks do you want to add to this account?",
     "header": "Add Features",
     "multiSelect": true,
     "options": [
       {"label": "Cloud Logs", "description": "Block 2 — real-time threat detection"},
       {"label": "Agentless Scanning", "description": "Block 3 — vulnerability scanning"}
     ]
   }
   ```

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
| Cloud Logs | Onboarding module | Already present if Connection exists |
| Advanced identity analysis | Cloud Logs + Connection | "Advanced identity analysis needs both Connection and Cloud Logs" |
| Agentless Scanning | Onboarding module | Already present if Connection exists |

## Confirmation Table

Add an "existing" vs "new" indicator:

| Capability | Status |
|-----------|--------|
| Security posture | existing |
| Identity analysis (foundational) | existing |
| Cloud Logs (EventBridge) | **new** |
| Identity analysis (advanced) | **new** |

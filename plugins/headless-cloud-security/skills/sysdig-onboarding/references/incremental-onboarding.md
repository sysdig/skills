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

2. Ask what to add. **Use the account's own provider picker from
   [interview-questions.md](interview-questions.md)** — Step 3d for AWS, Step 3d
   (GCP), or Step 3d (Azure) — with the capabilities already deployed removed
   from the options. Do not reproduce a picker here: the three differ in which
   capabilities exist (Azure has no Advanced Identity Analysis at
   single-subscription scope) and in how Workload Scanning is framed (ECS/Lambda
   for AWS, Cloud Run/GKE/Cloud Functions for GCP, Container Instances-Apps/
   Functions/AKS for Azure), and a copy here drifts from them.
   [features.md](features.md) is the source of truth for which capabilities a
   provider supports at all.

   Additive options only — do not add a "None" / "nothing more" checkbox here
   (see [interview-questions.md](interview-questions.md) Picker rules); if the
   user wants nothing, they submit an empty selection and this step ends.
   Run the matching Step 3d sub-questions (log capture method, per-feature
   regions, Host Scanning extras, and the Workload Scanning workload-type
   question for the account's provider) for whatever the user adds.

3. Generate only the delta Terraform — add new module blocks to the existing
   configuration file, keeping existing resources untouched. **Two exceptions,
   checked independently** — without them the apply resets posture flags set
   in Sysdig, Validated Exposure among them:
   - If the existing `config_posture` feature resource has no
     `lifecycle { ignore_changes = [flags] }`, add that block (and no `flags`
     argument) to it.
   - If the `sysdiglabs/sysdig` provider constraint allows anything older than
     3.11.2, or `.terraform.lock.hcl` pins an older version, set the constraint
     to `>= 3.11.2, < 4.0.0`. Then delete only the
     `provider "registry.terraform.io/sysdiglabs/sysdig"` block from
     `.terraform.lock.hcl` and run a plain `terraform init`, which re-resolves
     that one provider. Do **not** use `terraform init -upgrade`: it also moves
     every module and every other provider to the newest version its constraint
     allows — a new major where a module is unpinned or a provider has no upper
     bound — and so changes existing resources. A plain `terraform init` without
     the lock edit fails on the old lock entry.

   Validated Exposure itself is not asked here: on an existing account
   Terraform never changes it (`ignore_changes`), so it is changed in Sysdig.

4. Run `terraform plan` — should show only new resources (additions),
   zero changes to existing resources. If it shows an update or replacement of
   an existing resource, stop and show it to the user before any apply; a newer
   provider can change resources it already manages.

## Merge Strategy

- **Same Terraform directory:** Append new module blocks and feature
  registrations to the existing `.tf` file. Terraform handles the merge
  automatically — existing resources won't be touched.
- **New Terraform directory:** If the user prefers isolation, generate a
  separate config that references the same Sysdig account. Note: this
  requires the onboarding module output (account ID) to be shared via
  `terraform_remote_state` or a data source.

  The isolated directory has to *be* the working directory the terraform
  commands run from — the skill never `cd`s into it and never passes
  `-chdir=`, because neither form matches the `allowed-tools` patterns and both
  turn every pre-approved terraform call into a permission prompt (see
  [generate-config.md](generate-config.md) step 10). So ask the user to run the
  session from that directory — or to run the terraform commands there
  themselves — and generate into the working directory as usual.

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
| Workload Scanning | Onboarding module | Supported on AWS, GCP and Azure — the workload types offered differ per provider ([features.md](features.md)) |

## Confirmation Table

Add an "existing" vs "new" indicator:

| Capability | Status |
|-----------|--------|
| Security posture | existing |
| Identity analysis (foundational) | existing |
| Threat Detection (EventBridge) | **new** |
| Advanced Identity Analysis | **new** |

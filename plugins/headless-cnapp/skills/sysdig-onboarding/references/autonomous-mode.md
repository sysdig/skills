# Autonomous Mode (Step 3-AUTO)

In autonomous mode the user provides all parameters at once. Accept as
inline text, a YAML/JSON block, or an existing `environment.yaml`.

## Required Parameters

```yaml
target: cloud              # cloud | kubernetes | host
provider: aws              # aws | gcp | azure
scope: single              # single | organization
sysdig_region: us1         # us1, us2, eu1, au1, me1, us4
blocks: [trust, cloud_logs, scanning]  # trust is always required
cdr_mode: eventbridge      # eventbridge | cloudtrail (AWS + cloud_logs only)
backend: local             # local | s3 | gcs | azurerm
```

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

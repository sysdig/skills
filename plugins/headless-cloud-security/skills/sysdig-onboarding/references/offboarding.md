# Offboarding Guide

Disconnect a cloud account from Sysdig by destroying the Terraform-managed
resources. This is a first-class flow, not an afterthought.

## Pre-Destroy Checklist

Before running `terraform destroy`:

- [ ] Confirm the account to disconnect (show from `environment.yaml`)
- [ ] Verify the correct Terraform working directory and state file
- [ ] Run `terraform state list` to review what will be destroyed
- [ ] Warn about data loss (cloud audit logs, scan history will stop updating)
- [ ] Confirm the user has noted any findings they want to preserve

## Dependency-Aware Destroy Ordering

Sysdig API enforces feature dependencies. Destroying in the wrong order
causes **409 Conflict** errors. The destroy order is the **reverse** of the
onboarding dependency chain:

### Correct Destroy Order

1. **Feature registrations** (advanced identity, threat detection, scanning, posture, foundational identity)
2. **Integration modules** (EventBridge/CloudLogs, Agentless Scanning)
3. **Config Posture module**
4. **Onboarding module** (last — everything depends on it)

### In Practice

`terraform destroy` handles ordering automatically via dependency graph.
Manual ordering is only needed for **partial destroy** using `-target`:

```bash
# Example: remove only Cloud Logs while keeping the base connection
terraform destroy \
  -target=module.event_bridge \
  -target=sysdig_secure_cloud_auth_account_feature.threat_detection \
  -target=sysdig_secure_cloud_auth_account_feature.identity_entitlement_advanced
```

**Warning:** Always destroy the feature registration AND the module together.
Destroying only the module leaves orphaned feature registrations in Sysdig.

## Partial Destroy (Remove One Block)

To remove a specific block while keeping others:

1. Identify which resources belong to the block (use `terraform state list`)
2. Use `-target` flags to destroy only those resources
3. Remove the corresponding Terraform code blocks
4. Run `terraform plan` to verify no drift

## State Cleanup

If destroy fails partway:

1. Run `terraform state list` to see remaining resources
2. Check if resources still exist in the cloud (e.g., `aws iam get-role`)
3. For resources deleted outside Terraform, the next `terraform plan` will
   auto-reconcile during refresh
4. For resources stuck in state due to API errors, use
   `terraform state rm <resource_address>` as a last resort

## Post-Destroy Verification

1. Run `terraform state list` — should be empty
2. Run `verify-cloud-status.sh <provider> <account_id>` — account should
   show no enabled features (or not appear at all)
3. Check Sysdig > Integrations > Cloud Accounts — status should update
   within a few minutes

## Update Session Files

After successful offboarding:
1. Update `customer-log.md` with offboarding details
2. Remove the account entry from `environment.yaml`
3. Optionally archive the Terraform directory

## S3 Bucket Cleanup (AWS)

The sysdig-monitor module may have created Kinesis Firehose backup buckets
(`sysdig-backup-bucket-{region}-{account}`). These may not have
`force_destroy = true`, so Terraform can't delete them if they contain
objects. Check for and empty these buckets before destroy if needed:

```bash
aws s3 ls | grep sysdig-backup-bucket
aws s3 rm s3://sysdig-backup-bucket-us-east-1-123456789012 --recursive
```

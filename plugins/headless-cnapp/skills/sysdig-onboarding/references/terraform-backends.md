# Terraform State Backends

## Overview

Terraform stores its state file so it can manage resources across runs
(`plan`, `apply`, `destroy`). The choice of backend affects collaboration,
locking, and disaster recovery.

---

## Backend Comparison

| Backend | When to use | Requires | Locking | Backup |
|---------|------------|----------|---------|--------|
| **Local** (default) | Testing, single operator | Nothing extra | No | No |
| **S3** | AWS-native teams | S3 bucket | Yes (native S3 locking) | Yes (S3 versioning) |
| **GCS** | GCP-native teams | GCS bucket | Yes (built-in) | Yes (GCS versioning) |
| **Azure Storage** | Azure-native teams | Storage account + container | Yes (blob lease) | Yes (blob versioning) |

**Recommendation:** Match the backend to the cloud provider being onboarded
(e.g., S3 for AWS accounts). Local state has no locking or backup — only
suitable for testing and single-operator scenarios.

---

## State Key Naming Convention

Use a consistent key path to keep each account's state isolated while
grouped under a common prefix for discoverability:

```
sysdig-onboarding/<provider>/<account_id>
```

Examples:
- `sysdig-onboarding/aws/123456789012`
- `sysdig-onboarding/gcp/my-project-id`
- `sysdig-onboarding/azure/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx`

---

## Backend Configuration Details

### S3 Backend

```hcl
terraform {
  backend "s3" {
    bucket         = "my-terraform-state"
    key            = "sysdig-onboarding/aws/123456789012"
    region         = "us-east-1"
    use_lockfile = true
    encrypt      = true
  }
}
```

**Prerequisites:**
- S3 bucket must exist (create manually or with a separate Terraform config)
- The IAM identity running Terraform needs `s3:GetObject`, `s3:PutObject`,
  `s3:DeleteObject` on the bucket

### GCS Backend

```hcl
terraform {
  backend "gcs" {
    bucket = "my-terraform-state"
    prefix = "sysdig-onboarding/gcp/my-project-id"
  }
}
```

**Prerequisites:**
- GCS bucket must exist
- The service account running Terraform needs `storage.objects.*` on the bucket

### Azure Storage Backend

```hcl
terraform {
  backend "azurerm" {
    resource_group_name  = "terraform-state-rg"
    storage_account_name = "tfstate"
    container_name       = "tfstate"
    key                  = "sysdig-onboarding/azure/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
  }
}
```

**Prerequisites:**
- Resource group, storage account, and blob container must exist
- The identity running Terraform needs `Storage Blob Data Contributor` role

---

## environment.yaml Backend Sub-Schemas

When the user selects a remote backend, persist the configuration in
`environment.yaml` so subsequent sessions reuse it automatically:

```yaml
terraform:
  backend: s3          # or gcs, azurerm, local
  s3:                  # Only when backend: s3
    bucket: "my-terraform-state"
    region: "us-east-1"
    use_lockfile: true
  gcs:                 # Only when backend: gcs
    bucket: "my-terraform-state"
  azurerm:             # Only when backend: azurerm
    resource_group_name: "terraform-state-rg"
    storage_account_name: "tfstate"
    container_name: "tfstate"
```

The state key is NOT stored in `environment.yaml` — it is generated
dynamically from the provider and account ID using the naming convention
above.

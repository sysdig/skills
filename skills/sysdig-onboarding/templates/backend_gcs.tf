# Sysdig Secure — Terraform Backend (GCS)
#
# State key: sysdig-onboarding/{{PROVIDER}}/{{ACCOUNT_ID}}
# Requires: GCS bucket pre-created.

terraform {
  backend "gcs" {
    bucket = "{{GCS_BUCKET}}"
    prefix = "sysdig-onboarding/{{PROVIDER}}/{{ACCOUNT_ID}}"
  }
}

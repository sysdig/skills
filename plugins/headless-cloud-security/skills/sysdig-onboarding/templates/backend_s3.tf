# Sysdig Secure — Terraform Backend (S3)
#
# State key: sysdig-onboarding/{{PROVIDER}}/{{ACCOUNT_ID}}
# Requires: S3 bucket pre-created. Uses native S3 locking (TF >= 1.10).

terraform {
  backend "s3" {
    bucket       = "{{S3_BUCKET}}"
    key          = "sysdig-onboarding/{{PROVIDER}}/{{ACCOUNT_ID}}"
    region       = "{{S3_REGION}}"
    use_lockfile = true
    encrypt      = true
  }
}

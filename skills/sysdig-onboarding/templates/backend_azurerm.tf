# Sysdig Secure — Terraform Backend (Azure Storage)
#
# State key: sysdig-onboarding/{{PROVIDER}}/{{ACCOUNT_ID}}
# Requires: Storage account and container pre-created.

terraform {
  backend "azurerm" {
    resource_group_name  = "{{AZURE_RG}}"
    storage_account_name = "{{AZURE_SA}}"
    container_name       = "{{AZURE_CONTAINER}}"
    key                  = "sysdig-onboarding/{{PROVIDER}}/{{ACCOUNT_ID}}"
  }
}

# Sysdig Secure — Shared Variables
#
# This file defines variables common to all provider templates.
# Copy this alongside the provider-specific .tf file.

variable "sysdig_secure_api_token" {
  description = "Sysdig Secure API token. Set via env: export TF_VAR_sysdig_secure_api_token=<token>"
  type        = string
  sensitive   = true
}

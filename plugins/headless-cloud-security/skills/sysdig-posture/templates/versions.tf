terraform {
  required_version = ">= 1.0"

  required_providers {
    sysdig = {
      source  = "sysdiglabs/sysdig"
      version = "~> 3.7"
    }
  }
}

# The Sysdig provider reads credentials from the environment:
#
#   SYSDIG_SECURE_URL         regional base URL, no trailing slash
#                             e.g. https://us2.app.sysdig.com
#   SYSDIG_SECURE_API_TOKEN   API token — never hardcode in this file
#
provider "sysdig" {}

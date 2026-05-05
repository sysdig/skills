# Posture custom control.
# Requires versions.tf in the same directory — copy it alongside this file.
resource "sysdig_secure_posture_control" "{{CONTROL_TF_ID}}" {
  name                = "{{NAME}}"
  description         = "{{DESCRIPTION}}"
  resource_kind       = "{{RESOURCE_KIND}}"
  severity            = "{{SEVERITY}}" # Low | Medium | High

  # Rego source lives next to this .tf in a separate file for easier
  # iteration via the test_posture_rego MCP tool.
  rego = file("${path.module}/{{REGO_FILENAME}}")

  remediation_details = <<-EOT
    {{REMEDIATION_DETAILS}}
  EOT
}

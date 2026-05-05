# Custom Posture Policy — Sysdig Terraform provider
#
# Requires a versions.tf in the same directory (see custom_control.tf for the
# provider block — do not duplicate the terraform {} block here).
#
# Placeholders to replace before applying:
#   {{POLICY_TF_ID}}          — Terraform resource identifier (lowercase, underscores)
#   {{NAME}}                  — Human-readable policy name (unique per tenant)
#   {{DESCRIPTION}}           — Short description of what this policy covers
#   {{IS_ACTIVE}}             — true to enable evaluation, false to deploy inactive
#   {{GROUP_NAME}}            — Top-level section name (e.g. "S3 Controls")
#   {{GROUP_DESCRIPTION}}     — Short description of the group
#   {{REQUIREMENT_NAME}}      — Requirement name (e.g. "Encryption at Rest")
#   {{REQUIREMENT_DESCRIPTION}} — Short description of the requirement
#   {{CONTROL_NAME}}          — Exact name of the control as deployed in Sysdig
#                               (matches the `name` attribute of the
#                               sysdig_secure_posture_control resource, or the
#                               literal name if the control is in a different
#                               Terraform workspace)

resource "sysdig_secure_posture_policy" "{{POLICY_TF_ID}}" {
  name        = "{{NAME}}"
  description = "{{DESCRIPTION}}"
  is_active   = {{IS_ACTIVE}}

  # Duplicate this group block for additional top-level sections.
  group {
    name        = "{{GROUP_NAME}}"
    description = "{{GROUP_DESCRIPTION}}"

    # Duplicate this requirement block for additional requirements within the group.
    requirement {
      name        = "{{REQUIREMENT_NAME}}"
      description = "{{REQUIREMENT_DESCRIPTION}}"

      # Duplicate this control block for additional controls under this requirement.
      control {
        name    = "{{CONTROL_NAME}}"
        enabled = true
      }
    }
  }
}

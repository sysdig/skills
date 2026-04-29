# Environment Defaults — `environment.yaml`

The `environment.yaml` file stores structured, reusable data about the
customer's environment. Unlike `customer-log.md` (a chronological journal),
this file is machine-readable and used to pre-fill the discovery interview
in subsequent sessions.

## Schema

```yaml
sysdig:
  region: <region>            # e.g., us1, eu1, us2, au1
defaults:
  features: [<feature>, ...]  # e.g., [cspm, cdr]
  tags: { <key>: <value> }    # Optional — default tags for resources
terraform:                    # Terraform settings (reused across sessions)
  backend: local|s3|gcs|azurerm
  # Backend-specific keys (s3/gcs/azurerm) — see references/terraform-backends.md
accounts:                     # Cloud accounts onboarded
  - provider: aws|gcp|azure
    scope: single|organization|tenant
    account_id: "<id>"
    features: [...]
    onboarded: "YYYY-MM-DD"
clusters: []                  # Kubernetes clusters onboarded
hosts: []                     # Linux hosts onboarded
```

## Rules

- Always show proposed changes to the user and ask for confirmation before
  writing to this file.
- Only store facts that were confirmed during the session — never infer or
  guess values.
- Keep the file minimal: no comments beyond the schema above, no session
  history (that goes in `customer-log.md`).
- **If file writes are denied** (Write/Edit tool blocked by permissions),
  present the full content to the user in a code block and say: "I couldn't
  write this file automatically. Please save the content above to
  `<filename>`." This ensures no session data is lost even in restricted
  environments. Apply this fallback to both `customer-log.md` and
  `environment.yaml`.

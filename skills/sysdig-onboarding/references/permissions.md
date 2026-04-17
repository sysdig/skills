# Permissions Catalog

Authoritative catalog of all commands and file operations the
sysdig-onboarding skill executes, with ready-to-copy `settings.json`
patterns for Claude Code.

## Table of Contents

- [Quick Setup](#quick-setup)
- [Tier 1: Safe Patterns (auto-allow)](#tier-1-safe-patterns-auto-allow)
- [Tier 2: Destructive Commands (keep manual)](#tier-2-destructive-commands-keep-manual)
- [Full Command Catalog](#full-command-catalog)
- [File Operations Catalog](#file-operations-catalog)
- [Permission Patterns Reference](#permission-patterns-reference)
- [Maintenance Convention](#maintenance-convention)

---

## Quick Setup

Add these patterns to your `.claude/settings.json` (or
`.claude/settings.local.json` for project-specific settings) under
`permissions.allow` to auto-allow read-only commands while keeping
destructive operations manual.

**Copy this snippet into your `settings.json`:**

```json
{
  "permissions": {
    "allow": [
      "Bash(terraform init*)",
      "Bash(terraform validate*)",
      "Bash(terraform plan*)",
      "Bash(terraform state list*)",
      "Bash(terraform state show*)",
      "Bash(terraform output*)",
      "Bash(aws sts get-caller-identity*)",
      "Bash(aws iam simulate-principal-policy*)",
      "Bash(*validate_prereqs*)",
      "Bash(*check_permissions*)",
      "Bash(*verify*cloud*)",
      "Bash(helm version*)",
      "Bash(helm template*)",
      "Bash(helm repo list*)",
      "Bash(helm list*)",
      "Bash(helm show values*)",
      "Bash(kubectl cluster-info*)",
      "Bash(kubectl config current-context*)",
      "Bash(kubectl version*)",
      "Bash(kubectl get *)",
      "Bash(kubectl describe *)",
      "Bash(kubectl logs *)",
      "Bash(kubectl auth can-i *)",
      "Bash(gcloud auth list*)",
      "Bash(gcloud config get-value*)",
      "Bash(gcloud projects test-iam-permissions*)",
      "Bash(az account show*)",
      "Bash(az role assignment list*)",
      "Bash(az ad signed-in-user show*)",
      "Bash(az rest --method GET*)",
      "Bash(command -v *)",
      "Bash(terraform version*)",
      "Bash(uname *)",
      "Bash(systemctl status *)"
    ]
  }
}
```

These are all **read-only** — they inspect state but never create, modify,
or delete resources. Destructive commands (`terraform apply`, `helm install`,
etc.) are intentionally excluded so Claude always asks before executing them.

---

## Tier 1: Safe Patterns (auto-allow)

Commands that never modify resources. Safe to auto-allow unconditionally.

| Pattern | Commands Matched | Risk |
|---------|-----------------|------|
| `Bash(terraform init*)` | `terraform init`, `terraform init -backend-config=...` | None — downloads providers/modules |
| `Bash(terraform validate*)` | `terraform validate` | None — syntax check only |
| `Bash(terraform plan*)` | `terraform plan`, `terraform plan -destroy` | None — preview only |
| `Bash(terraform state list*)` | `terraform state list` | None — lists resources |
| `Bash(terraform state show*)` | `terraform state show <resource>` | None — inspects one resource |
| `Bash(terraform output*)` | `terraform output`, `terraform output -json` | None — reads outputs |
| `Bash(terraform version*)` | `terraform version` | None — version check |
| `Bash(aws sts get-caller-identity*)` | `aws sts get-caller-identity` | None — identity check |
| `Bash(aws iam simulate-principal-policy*)` | `aws iam simulate-principal-policy --action-names ...` | None — permission test |
| `Bash(aws iam get-role *)` | `aws iam get-role --role-name <probe>` | None — fallback probe |
| `Bash(aws events list-rules *)` | `aws events list-rules --limit 1` | None — fallback probe |
| `Bash(aws sqs list-queues *)` | `aws sqs list-queues --max-results 1` | None — fallback probe |
| `Bash(aws s3api list-buckets *)` | `aws s3api list-buckets --max-buckets 1` | None — fallback probe |
| `Bash(aws sns list-topics*)` | `aws sns list-topics` | None — fallback probe |
| `Bash(aws ec2 describe-snapshots *)` | `aws ec2 describe-snapshots --owner-ids self --max-results 1` | None — fallback probe |
| `Bash(aws kms list-keys *)` | `aws kms list-keys --limit 1` | None — fallback probe |
| `Bash(aws organizations list-roots *)` | `aws organizations list-roots --max-items 1` | None — fallback probe |
| `Bash(aws cloudformation list-stack-sets *)` | `aws cloudformation list-stack-sets --max-results 1` | None — fallback probe |
| `Bash(*validate_prereqs*)` | `scripts/validate_prereqs.sh <type>` | None — checks tool availability |
| `Bash(*check_permissions*)` | `scripts/check_permissions.sh <provider> ...` | None — tests permissions |
| `Bash(*verify*cloud*)` | `scripts/verify-cloud-status.sh <provider> ...` | None — reads Sysdig API |
| `Bash(helm version*)` | `helm version --short` | None — version check |
| `Bash(helm template*)` | `helm template ...` | None — renders locally |
| `Bash(helm repo list*)` | `helm repo list` | None — lists configured repos |
| `Bash(helm list*)` | `helm list -n sysdig-agent` | None — lists releases |
| `Bash(helm show values*)` | `helm show values sysdig/shield` | None — reads chart defaults |
| `Bash(kubectl cluster-info*)` | `kubectl cluster-info` | None — connectivity check |
| `Bash(kubectl config current-context*)` | `kubectl config current-context` | None — context name |
| `Bash(kubectl version*)` | `kubectl version -o json` | None — version info |
| `Bash(kubectl get *)` | `kubectl get pods -n sysdig-agent`, etc. | None — read-only |
| `Bash(kubectl describe *)` | `kubectl describe pod ...` | None — read-only |
| `Bash(kubectl logs *)` | `kubectl logs -n sysdig-agent <pod>` | None — reads logs |
| `Bash(kubectl auth can-i *)` | `kubectl auth can-i create deployments` | None — RBAC check |
| `Bash(gcloud auth list*)` | `gcloud auth list --filter=status:ACTIVE ...` | None — identity check |
| `Bash(gcloud config get-value*)` | `gcloud config get-value project` | None — reads config |
| `Bash(gcloud projects test-iam-permissions*)` | `gcloud projects test-iam-permissions ...` | None — permission test |
| `Bash(az account show*)` | `az account show`, `az account show --query ...` | None — identity check |
| `Bash(az role assignment list*)` | `az role assignment list --assignee ...` | None — reads RBAC |
| `Bash(az ad signed-in-user show*)` | `az ad signed-in-user show --query id ...` | None — identity check |
| `Bash(az rest --method GET*)` | `az rest --method GET --url https://graph...` | None — read-only API |
| `Bash(command -v *)` | `command -v terraform`, `command -v aws`, etc. | None — checks if tool exists |
| `Bash(uname *)` | `uname -r` | None — kernel version |
| `Bash(systemctl status *)` | `systemctl status sysdig-agent` | None — service status |

---

## Tier 2: Destructive Commands (keep manual)

These commands create, modify, or delete resources. They should **NOT** be
auto-allowed — Claude will prompt for confirmation each time.

| Command | When Used | What It Does |
|---------|-----------|--------------|
| `terraform apply` | Step 7: Execute configuration | Creates cloud resources (IAM roles, EventBridge, CloudTrail, etc.) |
| `terraform destroy` | Step 8: Offboarding | Deletes all Terraform-managed resources |
| `terraform state rm` | Step 8: Recovery | Removes a resource from state (after manual deletion) |
| `helm install` | Kubernetes onboarding | Deploys Sysdig Shield to the cluster |
| `helm upgrade` | Kubernetes updates | Modifies the Sysdig Shield deployment |
| `kubectl apply` | Kubernetes configuration | Creates Kubernetes resources |
| `kubectl delete` | Kubernetes cleanup | Removes Kubernetes resources |
| `systemctl start` | Host Shield setup | Starts the agent service |
| `systemctl enable` | Host Shield setup | Enables the agent on boot |
| `apt install` / `yum install` | Host Shield setup | Installs system packages |

---

## Full Command Catalog

Every command the skill executes, organized by workflow step.

### Step 3: Cloud Account Detection

| Command | Category | Risk |
|---------|----------|------|
| `aws sts get-caller-identity` | READ-ONLY | None — detects active AWS account |
| `gcloud auth list --filter=status:ACTIVE --format="value(account)"` | READ-ONLY | None — detects active GCP account |
| `gcloud config get-value project` | READ-ONLY | None — gets default project |
| `az account show` | READ-ONLY | None — detects active Azure subscription |

### Step 6a: Tool Prerequisites (`validate_prereqs.sh`)

| Command | Category | Risk |
|---------|----------|------|
| `command -v terraform` | READ-ONLY | None — tool existence check |
| `command -v aws` / `gcloud` / `az` / `kubectl` / `helm` | READ-ONLY | None — tool existence check |
| `terraform version` | READ-ONLY | None — version check |
| `helm version --short` | READ-ONLY | None — version check |
| `aws sts get-caller-identity --query Account --output text` | READ-ONLY | None — auth verification |
| `aws sts get-caller-identity --query Arn --output text` | READ-ONLY | None — identity for perm check |
| `gcloud auth list --filter=status:ACTIVE ...` | READ-ONLY | None — auth verification |
| `gcloud config get-value project` | READ-ONLY | None — project check |
| `az account show --query name --output tsv` | READ-ONLY | None — subscription info |
| `az account show --query tenantId --output tsv` | READ-ONLY | None — tenant info |
| `kubectl cluster-info` | READ-ONLY | None — cluster connectivity |
| `kubectl config current-context` | READ-ONLY | None — context name |
| `uname -r` | READ-ONLY | None — kernel version (host shield) |

### Step 6b: Permission Pre-flight (`check_permissions.sh`)

| Command | Category | Risk |
|---------|----------|------|
| `aws iam simulate-principal-policy --policy-source-arn <arn> --action-names <action>` | READ-ONLY | None — simulates only |
| `gcloud projects test-iam-permissions <project> --permissions=<perms>` | READ-ONLY | None — tests only |
| `az account show --query id --output tsv` | READ-ONLY | None — subscription ID |
| `az ad signed-in-user show --query id --output tsv` | READ-ONLY | None — user object ID |
| `az role assignment list --assignee <id> --scope /subscriptions/<id>` | READ-ONLY | None — lists roles |
| `az role assignment list --assignee <id> --all` | READ-ONLY | None — lists all roles |
| `az rest --method GET --url https://graph.microsoft.com/...` | READ-ONLY | None — Entra ID role check |

#### Fallback Service Probes (when SimulatePrincipalPolicy is unavailable)

| Command | Category | Risk |
|---------|----------|------|
| `aws iam get-role --role-name sysdig-nonexistent-probe-<ts>` | READ-ONLY | None — probes IAM access (expects NoSuchEntity) |
| `aws organizations list-roots --max-items 1` | READ-ONLY | None — probes Organizations access |
| `aws cloudformation list-stack-sets --max-results 1` | READ-ONLY | None — probes CloudFormation access |
| `aws events list-rules --limit 1` | READ-ONLY | None — probes EventBridge access |
| `aws sqs list-queues --max-results 1` | READ-ONLY | None — probes SQS access |
| `aws s3api list-buckets --max-buckets 1` | READ-ONLY | None — probes S3 access |
| `aws sns list-topics` | READ-ONLY | None — probes SNS access |
| `aws ec2 describe-snapshots --owner-ids self --max-results 1` | READ-ONLY | None — probes EC2 access |
| `aws kms list-keys --limit 1` | READ-ONLY | None — probes KMS access |

### Step 7: Generate & Execute Configuration

| Command | Category | Risk |
|---------|----------|------|
| `terraform init` | SETUP | Low — downloads providers, creates `.terraform/` |
| `terraform plan` | READ-ONLY | None — preview only |
| `terraform apply` | **DESTRUCTIVE** | Creates cloud resources (IAM, EventBridge, etc.) |
| `helm upgrade --install sysdig sysdig/shield -f values.yaml` | **DESTRUCTIVE** | Deploys Sysdig Shield to Kubernetes |
| `helm uninstall sysdig -n sysdig-agent` | **DESTRUCTIVE** | Removes Sysdig Shield from cluster |

### Step 8: Post-Installation Verification

| Command | Category | Risk |
|---------|----------|------|
| `terraform state list` | READ-ONLY | None — resource count |
| `scripts/verify-cloud-status.sh <provider> <account_id>` | READ-ONLY | None — Sysdig API check |
| `kubectl get pods -n sysdig-agent` | READ-ONLY | None — pod status |
| `kubectl logs -n sysdig-agent <pod>` | READ-ONLY | None — pod logs |
| `systemctl status sysdig-agent` | READ-ONLY | None — service status |
| `journalctl -u sysdig-agent --since "5 min ago"` | READ-ONLY | None — agent logs |

### Step 8: Offboarding (if applicable)

| Command | Category | Risk |
|---------|----------|------|
| `terraform plan -destroy` | READ-ONLY | None — preview only |
| `terraform destroy` | **DESTRUCTIVE** | Deletes all managed resources |
| `terraform state rm <resource>` | **DESTRUCTIVE** | Removes resource from state |

---

## File Operations Catalog

Files the skill creates or modifies via Write/Edit tools.

### Generated Files (Step 7)

| File | Operation | When | Risk |
|------|-----------|------|------|
| `main.tf` | Write | After interview — from template | None — local file |
| `variables.tf` | Write | With main.tf | None — local file |
| `backend.tf` | Write | If remote backend selected | None — local file |
| `terraform.tfvars` | Write | If not already present | None — local file (contains token placeholder) |
| `.gitignore` | Write | If not present | None — local file |
| `values.yaml` | Write | Kubernetes onboarding | None — local file |
| `sysdig-required-policy.json` | Write | If permissions missing (Step 6b) | None — local file |

### Session Files (Step 9)

| File | Operation | When | Risk |
|------|-----------|------|------|
| `customer-log.md` | Write/Edit | End of every session | None — local file |
| `environment.yaml` | Write/Edit | End of every session | None — local file |

### Template Files (Read only)

| File | Operation | When |
|------|-----------|------|
| `templates/aws_single_account.tf` | Read | AWS single account onboarding |
| `templates/aws_organization.tf` | Read | AWS organization onboarding |
| `templates/gcp_single_project.tf` | Read | GCP single project onboarding |
| `templates/gcp_organization.tf` | Read | GCP organization onboarding |
| `templates/azure_single_sub.tf` | Read | Azure single subscription onboarding |
| `templates/azure_tenant.tf` | Read | Azure tenant onboarding |
| `templates/backend_s3.tf` | Read | S3 backend configuration |
| `templates/backend_gcs.tf` | Read | GCS backend configuration |
| `templates/backend_azurerm.tf` | Read | Azure Storage backend configuration |

---

## Permission Patterns Reference

### Format

Claude Code permission patterns use the format `Tool(glob_pattern)`:

- `Bash(terraform init*)` — matches any Bash command starting with
  `terraform init`
- `Bash(*validate_prereqs*)` — matches any command containing
  `validate_prereqs`
- `Write(/path/to/dir/*)` — allows writing files under a directory

Wildcards: `*` matches any characters. A space before `*` enforces word
boundary (`Bash(ls *)` matches `ls -la` but not `lsof`).

### Where to add patterns

- **Global** (all projects): `~/.claude/settings.json`
- **Project** (shared, committed): `.claude/settings.json`
- **Local** (personal, gitignored): `.claude/settings.local.json`

### Full Tier 1 pattern list (copy-paste ready)

These are the patterns used in SKILL.md `allowed-tools`. Only commands the
agent runs **directly** need patterns here. Commands that run inside scripts
(e.g., AWS/GCP/Azure probes in `check_permissions.sh`) are covered by the
script-level pattern and don't need individual entries.

```json
// Terraform (read-only, auto-run)
"Bash(terraform init*)",
"Bash(terraform validate*)",
"Bash(terraform plan*)",
"Bash(terraform state list*)",
"Bash(terraform state show*)",
"Bash(terraform output*)",
"Bash(terraform version*)",
// Terraform with token sourcing
"Bash(source * && terraform init*)",
"Bash(source * && terraform validate*)",
"Bash(source * && terraform plan*)",
"Bash(source * && terraform state*)",
// AWS CLI (read-only)
"Bash(aws sts get-caller-identity*)",
"Bash(aws iam simulate-principal-policy*)",
"Bash(source * && aws sts*)",
// Kubernetes (read-only)
"Bash(kubectl get *)",
"Bash(kubectl logs *)",
"Bash(kubectl cluster-info*)",
"Bash(kubectl config current-context*)",
// Helm (read-only + repo setup)
"Bash(helm version*)",
"Bash(helm template*)",
"Bash(helm repo add *)",
"Bash(helm repo update*)",
// Skill scripts (each covers ALL internal commands)
"Bash(*validate_prereqs*)",
"Bash(*check_permissions*)",
"Bash(*verify*cloud*)",
"Bash(*detect-region*)",
// Utilities
"Bash(command -v *)"
```

> **Script-internal commands** (no individual patterns needed): The scripts
> above internally run AWS probes (`aws iam get-role`, `aws events list-rules`,
> `aws sqs list-queues`, `aws s3api list-buckets`, `aws sns list-topics`,
> `aws ec2 describe-snapshots`, `aws kms list-keys`, `aws organizations
> list-roots`, `aws cloudformation list-stack-sets`), GCP commands (`gcloud
> auth list`, `gcloud config get-value`, `gcloud projects
> test-iam-permissions`), Azure commands (`az account show`, `az role
> assignment list`, `az ad signed-in-user show`, `az rest --method GET`),
> and system commands (`uname`, `systemctl status`, `journalctl`). These
> all execute within the script's bash process and are covered by the
> script-level glob pattern.

---

## Maintenance Convention

When adding a new command to the skill:

1. **Add it to this catalog** under the appropriate step and category
2. **Classify it**: READ-ONLY, SETUP, or DESTRUCTIVE
3. **Add a pattern** to the Tier 1 list (if read-only) or document it in
   Tier 2 (if destructive)
4. **Update `.claude/settings.local.json`** if testing requires the new
   command
5. **Cross-reference** with `CLAUDE.md` conventions if the command affects
   the test infrastructure

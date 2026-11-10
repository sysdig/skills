# Permission Patterns & Command Catalog

User- and maintainer-facing reference: every command the sysdig-onboarding
skill executes, its risk classification, and ready-to-copy `settings.json`
patterns for Claude Code. The agent-facing pre-flight procedure (capability
mapping, fallback behavior, failure handling) is in
[permissions.md](permissions.md).

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

> This snippet is an optional user-side convenience subset. The
> authoritative in-skill allow-list is the `allowed-tools` frontmatter in
> [SKILL.md](../SKILL.md), mirrored in full under
> [Permission Patterns Reference](#permission-patterns-reference) — keep
> both in sync when commands change.

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
      "Bash(*scripts/validate_prereqs.sh *)",
      "Bash(*scripts/check_permissions.sh *)",
      "Bash(*scripts/verify-cloud-status.sh *)",
      "Bash(*scripts/render-recap.sh *)",
      "Bash(*scripts/lint_config.sh *)",
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
      "Bash(az account show*)",
      "Bash(az role assignment list*)",
      "Bash(az ad signed-in-user show*)",
      "Bash(command -v *)",
      "Bash(terraform version*)",
      "Bash(uname *)",
      "Bash(systemctl status *)",
      "Bash(journalctl -u dragent*)",
      "Bash(sudo test -s /opt/draios/logs/draios.log*)",
      "Bash(sudo grep * /opt/draios/logs/draios.log*)",
      "Bash(sudo sed -n * /opt/draios/logs/draios.log*)",
      "Bash(sudo tail * /opt/draios/logs/draios.log*)",
      "Bash(lsmod*)",
      "Bash(cat /etc/os-release*)",
      "Bash(dpkg --print-architecture*)",
      "Bash(docker logs sysdig-agent*)",
      "Bash(docker inspect sysdig-agent*)",
      "Bash(docker exec sysdig-agent grep*)",
      "Bash(docker exec sysdig-agent tail*)"
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
| `Bash(aws events describe-rule *)` | `aws events describe-rule --name <probe>` | None — fallback probe |
| `Bash(aws sqs get-queue-attributes *)` | `aws sqs get-queue-attributes --queue-url <probe> --attribute-names QueueArn` | None — fallback probe |
| `Bash(aws s3api list-buckets *)` | `aws s3api list-buckets --max-buckets 1` | None — fallback probe |
| `Bash(aws sns list-topics*)` | `aws sns list-topics` | None — fallback probe |
| `Bash(aws ec2 describe-snapshots *)` | `aws ec2 describe-snapshots --owner-ids self --max-results 5` | None — fallback probe |
| `Bash(aws kms describe-key *)` | `aws kms describe-key --key-id <probe>` | None — fallback probe |
| `Bash(aws organizations list-roots *)` | `aws organizations list-roots --max-items 1` | None — fallback probe |
| `Bash(aws cloudformation list-stack-sets *)` | `aws cloudformation list-stack-sets --max-results 1` | None — fallback probe |
| `Bash(*scripts/validate_prereqs.sh *)` | `scripts/validate_prereqs.sh <type>` | None — checks tool availability |
| `Bash(*scripts/check_permissions.sh *)` | `scripts/check_permissions.sh <provider> ...` | None — tests permissions |
| `Bash(*scripts/verify-cloud-status.sh *)` | `scripts/verify-cloud-status.sh <provider> ...` | None — reads Sysdig API |
| `Bash(*scripts/render-recap.sh *)` | `scripts/render-recap.sh .sysdig-recap.tsv` | None — renders the Step 5b recap table locally |
| `Bash(*scripts/lint_config.sh *)` | `scripts/lint_config.sh <generated files>` | None — local static checks on generated configs |
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
| `Bash(az account show*)` | `az account show`, `az account show --query ...` | None — identity check |
| `Bash(az role assignment list*)` | `az role assignment list --assignee ...` | None — reads RBAC |
| `Bash(az ad signed-in-user show*)` | `az ad signed-in-user show --query id ...` | None — identity check |
| `Bash(command -v *)` | `command -v terraform`, `command -v aws`, etc. | None — checks if tool exists |
| `Bash(test -s .sysdig-token)` | `test -s .sysdig-token` | None — exit code only, never prints the file |
| `Bash(grep -c PASTE_YOUR_TOKEN_HERE .sysdig-token)` | placeholder check | None — prints a match count, never the file |
| `Bash(echo "${SYSDIG_SECURE_API_TOKEN:+SET}")` | token presence check | None — prints `SET` or nothing, never the token value |
| `Bash(uname *)` | `uname -r` | None — kernel version |
| `Bash(systemctl status *)` | `systemctl status dragent` | None — service status |
| `Bash(journalctl -u dragent*)` | `journalctl -u dragent --no-pager -n 100 ...` | None — reads agent logs |
| `Bash(cat /etc/os-release*)` | `cat /etc/os-release` | None — distro detection |
| `Bash(dpkg --print-architecture*)` | `dpkg --print-architecture` | None — architecture detection |
| `Bash(docker logs sysdig-agent*)` | `docker logs sysdig-agent` | None — reads container logs |
| `Bash(docker inspect sysdig-agent*)` | `docker inspect sysdig-agent --format '{{.RestartCount}} {{.State.Running}}'` | None — reads container state (restart count / running) |
| `Bash(docker exec sysdig-agent grep*)` | `docker exec sysdig-agent grep -c Fatal /opt/draios/logs/draios.log` | None — reads the in-container agent log; `grep` cannot modify it |
| `Bash(docker exec sysdig-agent tail*)` | `docker exec sysdig-agent tail -n 5 /opt/draios/logs/draios.log` | None — reads the in-container agent log |

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
| `systemctl start` (e.g. `systemctl start dragent`) | Host Shield setup | Starts the agent service |
| `systemctl enable` (e.g. `systemctl enable --now dragent`) | Host Shield setup | Enables the agent on boot |
| `systemctl restart` (e.g. `systemctl restart dragent`) | Host Shield setup / recovery | Restarts the agent service (e.g. after a config or credential fix) |
| `apt install` / `yum install` | Host Shield setup | Installs system packages |
| `systemctl disable --now dragent` | Host offboarding | Stops the agent and removes it from boot |
| `docker rm -f sysdig-agent` / `docker rmi` | Host offboarding (Docker) | Removes the agent container / image |
| `apt-get purge` / `yum remove` (`draios-agent*`) | Host offboarding | Uninstalls the agent packages |
| `rm -rf /opt/draios` / `rm -rf /opt/sysdig` | Host offboarding | Deletes the config (which holds the Agent Access Key), state, sigdb and logs that package removal leaves behind |

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

### Step 2b: Tool Prerequisites (`validate_prereqs.sh`)

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
| `test -s .sysdig-token` | READ-ONLY | None — exit code only, never prints the file |
| `grep -c PASTE_YOUR_TOKEN_HERE .sysdig-token` | READ-ONLY | None — match count only, never prints the file |
| `source .sysdig-token && scripts/detect-region.sh --save-url` | SETUP | Rewrites only the `SYSDIG_BASE_URL` line of `.sysdig-token` (mode 600); never prints it |
| `uname -r` | READ-ONLY | None — kernel version (host shield) |

### Step 6a: Permission Pre-flight (`check_permissions.sh`)

| Command | Category | Risk |
|---------|----------|------|
| `aws iam simulate-principal-policy --policy-source-arn <arn> --action-names <action>` | READ-ONLY | None — simulates only |
| Cloud Resource Manager `projects:testIamPermissions` (REST, via `curl` inside `check_permissions.sh`) | READ-ONLY | None — tests only |
| `az account show --query id --output tsv` | READ-ONLY | None — subscription ID |
| `az ad signed-in-user show --query id --output tsv` | READ-ONLY | None — user object ID |
| `az role assignment list --assignee <id> --scope /subscriptions/<id>` | READ-ONLY | None — lists roles |
| `az role assignment list --assignee <id> --all` | READ-ONLY | None — lists all roles |
| `az rest --method GET --url https://graph.microsoft.com/...` | READ-ONLY | None — Entra ID role check |

Capability → `<features>` argument mapping: see [permissions.md](permissions.md).


#### Fallback Service Probes (when SimulatePrincipalPolicy is unavailable)

| Command | Category | Risk |
|---------|----------|------|
| `aws iam get-role --role-name sysdig-nonexistent-probe-<ts>` | READ-ONLY | None — probes IAM access (expects NoSuchEntity) |
| `aws organizations list-roots --max-items 1` | READ-ONLY | None — probes Organizations access |
| `aws cloudformation list-stack-sets --max-results 1` | READ-ONLY | None — probes CloudFormation access |
| `aws events describe-rule --name <probe>` | READ-ONLY | None — probes EventBridge (`events:DescribeRule`, in the onboarding policy) |
| `aws sqs get-queue-attributes --queue-url <probe> --attribute-names QueueArn` | READ-ONLY | None — probes SQS (`sqs:GetQueueAttributes`, in the onboarding policy) |
| `aws s3api list-buckets --max-buckets 1` | READ-ONLY | None — probes S3 access |
| `aws sns list-topics` | READ-ONLY | None — probes SNS access |
| `aws ec2 describe-snapshots --owner-ids self --max-results 5` | READ-ONLY | None — probes EC2 access (`--max-results` must be >= 5) |
| `aws kms describe-key --key-id <probe>` | READ-ONLY | None — probes KMS (`kms:DescribeKey`, in the onboarding policy) |

### Step 5b / Step 7: Local rendering & lint helpers

| Command | Category | Risk |
|---------|----------|------|
| `scripts/render-recap.sh .sysdig-recap.tsv` | READ-ONLY | None — renders the confirmation table from a local rows file |
| `scripts/lint_config.sh <files>` | READ-ONLY | None — checks generated configs for leftover placeholders/markers |

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
| `systemctl status dragent` | READ-ONLY | None — service status |
| `sudo test -s /opt/draios/logs/draios.log` | READ-ONLY | None — file-sink precondition for Checks 1b–6 |
| `sudo grep ... /opt/draios/logs/draios.log` | READ-ONLY | None — auth, connectivity, credential, config-error and capability checks (the file sink is root-only) |
| `sudo sed -n '<from>,<to>p' /opt/draios/logs/draios.log` | READ-ONLY | None — reads the last feature-summary block (Check 6a) |
| `lsmod` | READ-ONLY | None — confirms the `kmod` driver is loaded (Check 1b) |
| `journalctl -u dragent --no-pager -n 100` | READ-ONLY | None — fallback only: "is the unit producing anything at all". It does **not** carry the Information-level lines Checks 2–4 need |
| `docker logs sysdig-agent` | READ-ONLY | None — container liveness / crash-loop only (Docker install). Same `log_level` gate as journald, so **not** a source for Checks 2–4 |
| `docker inspect sysdig-agent --format '{{.RestartCount}} {{.State.Running}}'` | READ-ONLY | None — crash-loop detection (Docker install) |
| `docker exec sysdig-agent grep ... /opt/draios/logs/draios.log` | READ-ONLY | None — the file log lives inside the container; this is the Docker equivalent of the `sudo grep` rows above, for Checks 2–6 |

### Step 8: Offboarding (if applicable)

| Command | Category | Risk |
|---------|----------|------|
| `terraform plan -destroy` | READ-ONLY | None — preview only |
| `terraform destroy` | **DESTRUCTIVE** | Deletes all managed resources |
| `terraform state rm <resource>` | **DESTRUCTIVE** | Removes resource from state |
| `apt-get -s purge <packages>` | READ-ONLY | None — dry run; always run before the real purge |
| `apt-get purge` / `yum remove` (`draios-agent*`) | **DESTRUCTIVE** | Uninstalls the agent (leaves the config behind — see next row) |
| `rm -rf /opt/draios` / `rm -rf /opt/sysdig` | **DESTRUCTIVE** | Required: package removal leaves `dragent.yaml` with the Agent Access Key on disk |
| `find /etc /opt ... -iname '*sysdig*'` | READ-ONLY | None — final leftover sweep |

---

## File Operations Catalog

Files the skill creates or modifies with the agent's file-write and file-edit tools.

### Generated Files (Step 7)

| File | Operation | When | Risk |
|------|-----------|------|------|
| `main.tf` | Write | After interview — from template | None — local file |
| `variables.tf` | Write | With main.tf | None — local file |
| `backend.tf` | Write | If remote backend selected | None — local file |
| `terraform.tfvars` | Write | If not already present | None — local file (contains token placeholder) |
| `.gitignore` | Write | If not present | None — local file |
| `values.yaml` | Write | Kubernetes onboarding | None — local file |
| `sysdig-required-policy.json` | Write | If permissions missing (Step 6a) | None — local file |

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
- `Bash(*scripts/validate_prereqs.sh *)` — matches a command containing the
  script path anywhere (the leading `*` covers the plugin install path and
  `AWS_PROFILE=…` / `source .sysdig-token &&` prefixes)
- `Write(/path/to/dir/*)` — allows writing files under a directory

Wildcards: `*` matches any characters. A space before `*` enforces word
boundary (`Bash(ls *)` matches `ls -la` but not `lsof`).

**Keep patterns anchored.** Because `*` matches anything, a substring
pattern like `Bash(*verify*cloud*)` is satisfied by any command that merely
contains those words — far more than the script it was meant to allow.
Anchor script patterns to the full file name (`*scripts/verify-cloud-status.sh *`)
and command patterns to the exact binary + subcommand prefix.

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
// Terraform (read-only/preview verbs only — never apply/destroy/state rm)
"Bash(terraform version*)",
"Bash(terraform init*)",
"Bash(terraform validate*)",
"Bash(terraform plan*)",
"Bash(terraform state list*)",
"Bash(terraform state show*)",
"Bash(terraform output*)",
// Same verbs with the AWS profile pin and/or token sourcing
"Bash(AWS_PROFILE=* terraform init*)",
"Bash(AWS_PROFILE=* terraform validate*)",
"Bash(AWS_PROFILE=* terraform plan*)",
"Bash(AWS_PROFILE=* terraform state list*)",
"Bash(AWS_PROFILE=* terraform state show*)",
"Bash(AWS_PROFILE=* terraform output*)",
"Bash(source .sysdig-token && terraform init*)",
"Bash(source .sysdig-token && terraform validate*)",
"Bash(source .sysdig-token && terraform plan*)",
"Bash(source .sysdig-token && terraform state list*)",
"Bash(source .sysdig-token && terraform state show*)",
"Bash(source .sysdig-token && terraform output*)",
"Bash(source .sysdig-token && AWS_PROFILE=* terraform init*)",
"Bash(source .sysdig-token && AWS_PROFILE=* terraform validate*)",
"Bash(source .sysdig-token && AWS_PROFILE=* terraform plan*)",
"Bash(source .sysdig-token && AWS_PROFILE=* terraform state list*)",
"Bash(source .sysdig-token && AWS_PROFILE=* terraform state show*)",
"Bash(source .sysdig-token && AWS_PROFILE=* terraform output*)",
// Cloud CLIs (identity / read-only checks; switching accounts prompts)
"Bash(aws sts get-caller-identity*)",
"Bash(aws iam simulate-principal-policy*)",
"Bash(aws configure list-profiles*)",
"Bash(AWS_PROFILE=* aws sts get-caller-identity*)",
"Bash(AWS_PROFILE=* aws iam simulate-principal-policy*)",
"Bash(source .sysdig-token && aws sts *)",
"Bash(gcloud auth list*)",
"Bash(gcloud config get-value *)",
"Bash(az account show*)",
"Bash(az role assignment list*)",
"Bash(az ad signed-in-user show*)",
// Kubernetes (read-only)
"Bash(kubectl get *)",
"Bash(kubectl describe *)",
"Bash(kubectl logs *)",
"Bash(kubectl auth can-i *)",
"Bash(kubectl cluster-info*)",
"Bash(kubectl config current-context*)",
"Bash(kubectl version*)",
// Helm (read-only + pinned repo setup; install/upgrade/uninstall prompt)
"Bash(helm version*)",
"Bash(helm template*)",
"Bash(helm repo add sysdig https://charts.sysdig.com)",
"Bash(helm repo update*)",
"Bash(helm repo list*)",
"Bash(helm list*)",
"Bash(helm show values*)",
// Skill scripts (anchored to file names; each covers ALL internal commands)
"Bash(*scripts/validate_prereqs.sh *)",
"Bash(*scripts/check_permissions.sh *)",
"Bash(*scripts/verify-cloud-status.sh *)",
"Bash(*scripts/detect-region.sh*)",
"Bash(*scripts/detect-env.sh*)",
"Bash(*scripts/render-recap.sh *)",
"Bash(*scripts/lint_config.sh *)",
// Local file/setup helpers
"Bash(mkdir -p *)",
"Bash(chmod 600 *)",
"Bash(command -v *)",
"Bash(ls *)",
// Token presence check — prints SET or nothing, never the value
"Bash(echo \"${SYSDIG_SECURE_API_TOKEN:+SET}\")",
// .sysdig-token checks — exit code / match count only, never the content
"Bash(test -s .sysdig-token)",
"Bash(grep -c PASTE_YOUR_TOKEN_HERE .sysdig-token)",
// Host (Linux) read-only. The draios-agent package registers the `dragent`
// unit; systemctl start/enable/restart are Tier 2 and deliberately absent.
"Bash(systemctl status dragent*)",
"Bash(systemctl is-active dragent*)",
"Bash(journalctl -u dragent*)",
"Bash(uname *)",
"Bash(cat /etc/os-release*)",
"Bash(dpkg --print-architecture*)",
"Bash(docker logs sysdig-agent*)",
// Docker install verification: container state + the in-container file log
// (/opt/draios/logs/draios.log does not exist on the host).
"Bash(docker inspect sysdig-agent*)",
"Bash(docker exec sysdig-agent grep*)",
"Bash(docker exec sysdig-agent tail*)"
```

> **Script-internal commands** (no individual patterns needed): The scripts
> above internally run AWS probes (`aws iam get-role`, `aws events describe-rule`,
> `aws sqs get-queue-attributes`, `aws s3api list-buckets`, `aws sns list-topics`,
> `aws ec2 describe-snapshots`, `aws kms describe-key`, `aws organizations
> list-roots`, `aws cloudformation list-stack-sets`), GCP commands (`gcloud
> auth list`, `gcloud config get-value`, `gcloud auth print-access-token` +
> `curl` to the Cloud Resource Manager `testIamPermissions` REST API — gcloud
> has no `projects test-iam-permissions` subcommand), Azure commands (`az account show`, `az role
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

# Azure Cloud Onboarding Reference

Terraform-driven onboarding of a Microsoft Azure **subscription** to Sysdig
Secure, using the `sysdiglabs/secure/azurerm` module family. This reference
covers **single-subscription** scope end to end; tenant / management-group
scope is summarized in §3.

## Table of Contents

1. [Prerequisites and Permissions](#1-prerequisites-and-permissions)
2. [Single Subscription Setup](#2-single-subscription-setup)
3. [Tenant-Wide Setup](#3-tenant-wide-setup)
4. [Terraform Module Reference](#4-terraform-module-reference)
5. [Basic Identity: Entra ID Admin Consent](#5-basic-identity-entra-id-admin-consent)
6. [Troubleshooting](#6-troubleshooting)

---

## 1. Prerequisites and Permissions

### Tools Required
- Terraform >= 1.5.0
- Azure CLI (`az`), authenticated (`az login --tenant <TENANT_ID>`)

### Subscription prerequisite — resource provider registration

Host Scanning uses **Azure Lighthouse** for delegated, cross-subscription disk
access. The `Microsoft.ManagedServices` resource provider must be registered on
the target subscription before applying (the onboarding wizard lists this in its
Permissions Check). Register it once:

```bash
az provider register --namespace Microsoft.ManagedServices --subscription <SUBSCRIPTION_ID>
```

This is a one-time subscription setting, not a Terraform resource — there is no
separate enablement config to apply (unlike GCP's API-enablement step).

### Installer Permissions

Run `scripts/check_permissions.sh azure [single|tenant] [features]` to verify
before applying.

Azure uses **two permission systems** — both are needed. These are **setup-only**
roles for the identity running Terraform; the roles Sysdig itself receives are
read-only (see below).

**Entra ID roles (tenant-level, always required):**

| Role | Why it's needed |
|------|-----------------|
| `Application Administrator` | Create the Sysdig service principal in Entra ID |
| `Privileged Role Administrator` | Assign Entra ID roles (Directory Readers) to the Sysdig SP |

**Azure RBAC roles (subscription-level):**

| Role | Required for | Why it's needed |
|------|-------------|-----------------|
| `User Access Administrator` | All features | Assign the read-only RBAC roles to the Sysdig service principal on the target subscription |
| `Contributor` | Threat Detection (CDR) | Create the Event Hub, namespace and diagnostic settings that forward Azure activity logs |
| `Owner` | Host Scanning, Workload Scanning | Assign the disk-snapshot and container-access roles and set up Azure Lighthouse |

> `Owner` (rather than `Contributor`) is required when Host or Workload Scanning
> is enabled, because those features assign roles — a capability `Contributor`
> lacks. Threat Detection (CDR) only creates resources, so `Contributor` **or**
> `Owner` is enough for it. For a Foundational-only (CSPM + Basic Identity)
> onboarding, `User Access Administrator` is sufficient.
>
> The roles may be held directly on the subscription or inherited from a parent
> management group — `check_permissions.sh` accepts either.

**Feature → installer-permission matrix:**

| Feature | Entra ID roles | RBAC roles |
|---------|---------------|------------|
| Posture & Compliance (CSPM) | App Admin, Priv Role Admin | User Access Admin |
| Basic Identity (CIEM basic) | App Admin, Priv Role Admin | User Access Admin |
| Threat Detection (CDR) | App Admin, Priv Role Admin | User Access Admin, Contributor (or Owner) |
| Host Scanning (agentless) | App Admin, Priv Role Admin | User Access Admin, Owner |
| Workload Scanning | App Admin, Priv Role Admin | User Access Admin, Owner |

### Roles granted to the Sysdig service principal (read-only end state)

Onboarding creates a read-only identity in Entra ID and grants it least-privilege
roles on the subscription:

| Type | Role | Purpose |
|------|------|---------|
| Entra ID | `Directory Readers` | List users and service principals (Basic Identity) |
| Azure RBAC | `Reader` | Read-only resource discovery (CSPM) |
| Azure RBAC | `Security Reader` | Read security-related configuration |
| Azure RBAC | Custom / scanning roles | Temporary disk snapshots (Host Scanning) and read-only container-registry inspection (Workload Scanning), assigned only when those features are selected |

### Required IDs
- Tenant ID
- Subscription ID
- Region (only when Threat Detection / CDR is enabled — for the Event Hub)

### Official permissions reference

For the complete and latest list, consult:
https://docs.sysdig.com/en/sysdig-secure/azure-permissions-and-resources/

---

## 2. Single Subscription Setup

Terraform source: `sysdiglabs/secure/azurerm` (pin `version = "~> 3.0"`).

### Feature model

| Tier | Capability | Notes |
|------|-----------|-------|
| Foundational (always) | Inventory, Posture & Compliance (CSPM) | Resource discovery + compliance |
| Foundational (always) | Basic Identity Capabilities (CIEM basic) | Config-based IAM hygiene; reading Entra ID directory data needs a manual admin-consent step (§5) |
| Optional | Threat Detection (CDR) | Streams Activity Logs via an Event Hub — **requires a region** |
| Optional | Host Scanning (agentless) | VM disk vulnerability scanning via Azure Lighthouse; Container scanning is an opt-in scanning type |
| Optional | Workload Scanning | Container-image scanning for Azure Container Instances/Apps, Azure Functions, and AKS |

> **Advanced Identity (usage-based CIEM) is not available at single-subscription
> scope.** It requires tenant/organizational onboarding (Directory Readers is a
> tenant-level permission). See §3.

### Steps

1. **Register the resource provider** (§1) if Host Scanning is planned.
2. **Authenticate:** `az login --tenant <TENANT_ID>`, then select the
   subscription: `az account set --subscription <SUBSCRIPTION_ID>`.
3. **Verify permissions:** `scripts/check_permissions.sh azure single <features>`.
4. **Generate `main.tf`** from `templates/azure_single_sub.tf`: fill Tenant ID,
   Subscription ID, the Sysdig URL, and — for the selected features — the Event
   Hub region, the agentless scanning-types flags, and the workload toggles.
   Keep only the selected feature blocks (between `# === MARKER ===` delimiters).
5. **Provide the token** via environment, never in the file:
   `export TF_VAR_sysdig_secure_api_token="<token>"`.
6. **Deploy:** `terraform init && terraform plan && terraform apply`.
   Onboarding finalizes in the Sysdig backend within 15 minutes to 1 hour.
7. **Basic Identity:** complete the Entra ID admin-consent step (§5).

### Scanning types (Host Scanning)

Azure exposes a single scanning type — **Container scanning** (scan running
containers found on host disks). Set on the `FEATURE_SECURE_AGENTLESS_SCANNING`
resource via `flags`:

```hcl
flags = {
  "SCANNING_HOST_CONTAINER_ENABLED" : "true",   # Container scanning selected
  "SCANNING_MALWARE_ENABLED"        : "false"    # no malware scanning type on Azure
}
```

`SCANNING_MALWARE_ENABLED` is always `"false"` on Azure — malware scanning is not
offered for Azure host scanning. The flags are set at onboarding and can be
toggled later in the Sysdig UI.

### Workload types (Workload Scanning)

Choose at least one. Each selected type adds a feature resource; AKS and
Functions also flip a module toggle:

| Workload type | Module toggle | Feature type |
|---------------|---------------|--------------|
| Azure Container Instances & Container Apps | (base — none) | `FEATURE_SECURE_WORKLOAD_SCANNING_CONTAINERS` |
| Azure Kubernetes Service (AKS) | `aks_enabled = true` | `FEATURE_SECURE_WORKLOAD_SCANNING_KUBERNETES` |
| Azure Functions (containers only) | `functions_enabled = true` | `FEATURE_SECURE_WORKLOAD_SCANNING_FUNCTIONS` |

Container Instances/Apps scanning is provided by the base module (no toggle); set
`aks_enabled` / `functions_enabled` to `false` for any type not selected.

---

## 3. Tenant-Wide Setup

Tenant / management-group scope onboards multiple subscriptions under a
management-group hierarchy and unlocks capabilities that are tenant-scoped:

- **Advanced Identity (usage-based CIEM):** `CIEM_FEATURE_MODE = "advanced"` on
  the `FEATURE_SECURE_IDENTITY_ENTITLEMENT` resource, with components combining
  the CSPM service principal and the Event Hub component. Requires
  organizational onboarding with CIEM enabled — not available for a single
  subscription.
- **Management-group scoping:** `include_management_groups` /
  `exclude_management_groups` and `include_subscriptions` /
  `exclude_subscriptions` on the onboarding module select the covered
  subscriptions.
- RBAC roles are assigned at the root management-group level rather than a single
  subscription; Entra ID roles are tenant-wide regardless of scope.

Tenant onboarding uses `templates/azure_tenant.tf`.

> **Tenant scope is Experimental — the template is not verified against the
> current 3.x modules.** `azure_tenant.tf` leaves its module versions unpinned
> and reads `module.config-posture.config_posture_component_id`, an
> output the 3.x `config-posture` module does not expose (it is
> `service_principal_component_id`), so `terraform plan` fails on it. Present
> tenant onboarding as Experimental, and reconcile every module input and output
> in the template against the module reference in §4 before applying.

---

## 4. Terraform Module Reference

All modules share `source = "sysdiglabs/secure/azurerm//modules/<name>"`,
`version = "~> 3.0"`.

| Module | Purpose | Key inputs | Key output |
|--------|---------|-----------|------------|
| `onboarding` | Register the subscription; create the Sysdig SP | `subscription_id`, `tenant_id` | `sysdig_secure_account_id`, `subscription_id`, `is_organizational` |
| `config-posture` | CSPM + Basic Identity data source | `subscription_id`, `sysdig_secure_account_id` | `service_principal_component_id`, `sysdig_cspm_sp_object_id` |
| `integrations/event-hub` | CDR log streaming | `subscription_id`, `region`, `sysdig_secure_account_id` | `event_hub_component_id` |
| `agentless-scanning` | Host disk scanning via Lighthouse | `subscription_id`, `sysdig_secure_account_id` | `service_principal_component_id` |
| `vm-workload-scanning` | Container-image scanning | `subscription_id`, `sysdig_secure_account_id`, `sysdig_cspm_sp_object_id`, `aks_enabled`, `functions_enabled` | `service_principal_component_id` |

Downstream modules take `subscription_id = module.onboarding.subscription_id`
and `account_id = module.onboarding.sysdig_secure_account_id`. Feature resources
(`sysdig_secure_cloud_auth_account_feature`) reference each module's component-id
output.

The Sysdig provider is pinned `>= 3.11.2, < 4.0.0`; the `azurerm` provider `~> 3`. The
`azuread` provider is configured with the tenant ID so the onboarding module can
create the Entra ID application.

---

## 5. Basic Identity: Entra ID Admin Consent

Basic Identity Capabilities analyze configuration-based IAM risks from the data
Sysdig already collects. To additionally **read Entra ID directory data** (users,
groups, service principals), the Sysdig service principal needs admin consent —
a manual step in the Azure portal after `terraform apply`:

1. In the Azure portal, go to **Microsoft Entra ID → App registrations** and open
   the Sysdig application created by onboarding.
2. Open **API permissions** and review the requested Microsoft Graph read-only
   directory permissions.
3. Select **Grant admin consent for `<tenant>`** and confirm.

This is a one-time action that requires a Privileged Role Administrator (or
Global Administrator). CSPM and posture work without it; only Entra ID directory
insights depend on it. It cannot be automated with Terraform.

---

## 6. Troubleshooting

**`Microsoft.ManagedServices` not registered.** Host Scanning apply fails
creating the Lighthouse definition/assignment. Register the provider on the
subscription and re-apply:
`az provider register --namespace Microsoft.ManagedServices`.

**`AuthorizationFailed` when assigning roles.** The installer identity lacks
`Owner` (or `User Access Administrator`) at the subscription scope. Host and
Workload Scanning both assign roles and need `Owner`. Verify with
`scripts/check_permissions.sh azure single <features>` and check the assignment
scope covers the target subscription (not only a management group).

**Entra ID role creation denied.** Creating the Sysdig application/service
principal requires `Application Administrator`, and assigning `Directory Readers`
requires `Privileged Role Administrator`. These are Entra ID roles, separate from
Azure RBAC — confirm both under **Entra ID → Roles and administrators**.

**Basic Identity shows no directory data.** The Entra ID admin-consent step (§5)
has not been completed. Grant admin consent on the Sysdig app registration.

**Wrong subscription targeted.** The `azurerm` provider resolves the subscription
from the `subscription_id` argument (and `ARM_SUBSCRIPTION_ID` / the active
`az account`). Confirm `az account show` reports the intended subscription before
apply, and that the `subscription_id` in the config matches.

**Event Hub region.** Threat Detection requires a valid Azure region for the
Event Hub. Use a region name accepted by Azure (e.g. `eastus`, `westeurope`); an
invalid region fails at apply.

**Onboarding the same subscription to a second Sysdig account.** This is not a
supported configuration. The Sysdig service principal is shared per tenant
(one identity linked to the Sysdig application), and the subscription-scoped
`Reader` role assignment and the Entra diagnostic setting use stable names — a
second, concurrent onboarding of the same subscription assigns the same
principal the same role at the same scope, which Azure rejects as a duplicate.
Onboard each subscription to a single Sysdig account.

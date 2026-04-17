# Azure Cloud Onboarding Reference

> **Status:** Stub — will be completed in Phase 5 with real module variables,
> examples, and tested configurations.

## Table of Contents

1. [Prerequisites and Permissions](#1-prerequisites-and-permissions)
2. [Single Subscription Setup](#2-single-subscription-setup)
3. [Tenant-Wide Setup](#3-tenant-wide-setup)
4. [Terraform Module Reference](#4-terraform-module-reference)
5. [Security Principals](#5-security-principals)
6. [Troubleshooting](#6-troubleshooting)

---

## 1. Prerequisites and Permissions

### Tools Required
- Terraform >= 1.10.0
- Azure CLI (`az`), authenticated (`az login`)

### Installer Permissions

Run `scripts/check_permissions.sh azure [single|tenant]` to verify before
applying.

Azure uses **two permission systems** — both are needed:

**Entra ID Roles (tenant-level, always required):**

| Role | Why it's needed |
|------|-----------------|
| `Application Administrator` | Create the Sysdig Service Principal in Entra ID |
| `Privileged Role Administrator` | Attach Entra ID roles (Directory Readers) to Sysdig SP |

**Azure RBAC Roles (subscription-level):**

| Role | Required for | Why it's needed |
|------|-------------|-----------------|
| `User Access Administrator` | All features | Attach RBAC roles to Sysdig SP |
| `Contributor` | CDR, CIEM, VM | Create Event Hub, diagnostic settings, snapshots |

**Feature-permission matrix:**

| Feature | Entra ID Roles | RBAC Roles |
|---------|---------------|------------|
| CSPM | App Admin, Priv Role Admin | User Access Admin |
| CDR | App Admin, Priv Role Admin | User Access Admin, Contributor |
| CIEM | App Admin, Priv Role Admin | User Access Admin, Contributor |
| VM (agentless) | App Admin, Priv Role Admin | User Access Admin, Contributor |

### Roles Granted to Sysdig Service Principal

| Type | Role | Purpose |
|------|------|---------|
| Entra ID | `Directory Readers` | List users and service principals |
| Azure RBAC | `Reader` | Read-only resource discovery (CSPM) |
| Azure RBAC | `Contributor` | CDR/CIEM/VM infrastructure (Event Hub, snapshots) |
| Azure RBAC | Custom role | `Microsoft.Web/sites/config/list/action` (App Service auth settings) |

**Scope:**
- **Single subscription**: RBAC roles assigned at subscription level
- **Tenant**: RBAC roles assigned at root management group level
- Entra ID roles are always tenant-wide regardless of scope

### Required IDs
- Tenant ID
- Subscription ID(s)
- Installer Service Principal ID (or user object ID)
- Root Management Group ID (for tenant-wide)

### Official Permissions Reference

For the complete and latest list, consult:
https://docs.sysdig.com/en/sysdig-secure/azure-permissions-and-resources/

---

## 2. Single Subscription Setup

<!-- TODO Phase 5 -->

Terraform source: `sysdiglabs/secure/azurerm`

Modules used:
- `//modules/onboarding`
- `//modules/config-posture`
- `//modules/event-hub` — For CDR
- `//modules/agentless-scanning` — For VM

---

## 3. Tenant-Wide Setup

<!-- TODO Phase 5 -->

Key parameters:
- Management group scoping
- Multi-subscription deployment

---

## 4. Terraform Module Reference

<!-- TODO Phase 5 -->

---

## 5. Security Principals

Azure uses a dual-principal model:

- **Installer principal**: Your user or service principal. Sysdig never
  accesses it. Needs Entra ID + RBAC roles to create resources.
- **Sysdig service principal**: Created during onboarding with limited
  read-only roles. This is what Sysdig uses to access your environment.

<!-- TODO Phase 5: Detail exact roles for each principal -->

---

## 6. Troubleshooting

<!-- TODO Phase 5 -->

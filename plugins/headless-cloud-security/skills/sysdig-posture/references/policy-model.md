# Posture Policy Model

## Hierarchy

A custom policy is a four-level nested structure. Each level has a defined purpose and contains the level below it.

| Level | Purpose | Contains | Notes |
|---|---|---|---|
| Policy | Top-level deployable unit; bound to zones via UI. | Group(s) | A policy with no zone assignment is never evaluated. |
| Group | Top-level section within a policy; organisational only. | Requirement(s) | Display-only; does not affect evaluation logic. |
| Requirement | Rule cluster; can contain sub-requirements. | Control(s) and/or sub-Requirement(s) | Flat (single level) is almost always sufficient. |
| Control | Evaluatable leaf; references an existing control by exact `name`. | (leaf) | `enabled` flag toggles without removing the block. |

This skill always creates **custom policies**. Built-in Sysdig policies are read-only — they can be listed but never modified, added to, or deleted via Terraform.

## Referencing a control in Terraform

The `control { name = "..." }` block expects a string — the exact name of the control as deployed in Sysdig. There are three possible forms:

| Form | Example | Behaviour |
|---|---|---|
| Resource attribute reference | `name = sysdig_secure_posture_control.s3_versioning.name` | **Use this.** Works and creates an implicit dependency so Terraform applies the control before the policy. |
| Literal string | `name = "S3 Bucket without versioning"` | Works, but no dependency — policy may apply before the control exists if the names don't match exactly. |
| Numeric ID reference | `name = sysdig_secure_posture_control.s3_versioning.id` | **Wrong.** `name` expects a string, `.id` resolves to a number. |

Always prefer the resource attribute reference form unless the control is not in the current Terraform configuration.

## New policy vs. extend existing

Apply these rules in order, picking the first that matches:

1. If no custom policies exist → **create a new policy**.
2. If a custom policy already covers the same resource family and has a logical home for the new control → **extend it** (add the control under an existing or new requirement, or under a new group).
3. Otherwise → **create a new policy**.

## Requirement structure — flat vs. nested

**Use flat (single requirement level) when:**
- All controls in the group enforce the same theme (e.g. all S3 encryption checks).
- There are fewer than ~8 controls per group.
- The user does not need sub-grouping for reporting purposes.

**Use nested (requirement → sub-requirement) when:**
- Controls split clearly into two or more sub-themes that benefit from separate pass/fail reporting.
- Compliance mapping requires explicit sub-sections (e.g. mapping to CIS sub-controls).

When in doubt, start flat. Adding nesting later is non-destructive; removing it requires migrating controls.

## Evaluation cadence

Posture controls are evaluated on a **daily schedule**. There is no immediate feedback after `terraform apply`. Set this expectation explicitly: the user will not see results in the Sysdig Secure UI until the next scheduled scan runs.

## Zone assignment — UI only

After `terraform apply`, the policy exists but is **not evaluated** until it is assigned to at least one zone. Zone assignment is done exclusively via the Sysdig Secure UI:

**Policies → Posture Policies → [policy name] → Zones**

This skill does not create, modify, delete, or assign zones.

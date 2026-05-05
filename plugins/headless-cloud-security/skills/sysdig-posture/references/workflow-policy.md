# Workflow — Define a Custom Policy

End-to-end flow for creating or extending a custom policy and attaching one or more custom controls to it.

No API writes. All creation happens via `terraform apply` on user approval.

## Steps

Preflight (MCP availability, local tools, Terraform credentials) is handled in [SKILL.md](../SKILL.md#prerequisites) before routing here — assume it has passed.

### 1. Identify the goal

Ask the user which of these they want to do:

- **(a) Create a new custom policy** — name, description, and requirement structure TBD.
- **(b) Add a control to an existing custom policy** — extend an existing policy with a new control under an existing or new requirement, or under a new group.

### 2. Discover the landscape

What you need depends on the goal from step 1:

- **(a) Create a new policy** — list custom controls (see *Listing custom controls* below) to know what can be attached. The list of existing policies is not needed for this path.
- **(b) Extend an existing policy** — list both custom policies and custom controls.

Present a concise summary — policy names with active/inactive status, and control names with resource kind. Do not dump raw JSON into chat.

#### Listing custom policies

Call the `list_posture_policies` MCP tool with `{ "is_custom": true, "is_active": true }`. The tool returns `{ data, totalCount }`; use `data` as-is — `list_posture_policies` is not paginated.

#### Listing custom controls

`list_posture_controls` is paginated and the caller walks pages. The `is_custom` filter is applied **after** paging, so:

- A single page can return far fewer items than `page_size` (most controls are built-in, only a handful per page survive `is_custom: true`).
- `totalCount` reflects the *unfiltered* total. Do **not** loop until `len(accumulator) >= totalCount` — that will over-run by orders of magnitude.

Walk the pages until a page returns an empty `data` array:

1. Call `list_posture_controls` with `{ "is_custom": true, "page_number": 1, "page_size": 100 }` (default page size is 100; max is 200).
2. Append the page's `data` to your accumulator.
3. If `data` is non-empty, call again with `page_number` incremented by 1 and the same `page_size`. Repeat.
4. Stop when a page returns `data: []`. The accumulator now holds every custom control.

For most tenants a single page is enough; the loop is a safety net for tenants with many custom controls. If the user only needs to verify a control by name, a single page is usually sufficient — only walk all pages when the user wants the full inventory.

### 2b. Mini-checkpoint — new policy or extend existing?

Use `AskUserQuestion` immediately after presenting the landscape.

**If no custom policies exist:** skip the question; inform the user there are no custom policies yet and proceed to create one.

**If custom policies exist:** present them as options plus "Create a new policy." Once the user picks:

- **Extend existing** → follow up with a second question:
  > What do you want to do with `<policy name>`?
  > - Add a control to an existing requirement
  > - Add a new requirement (and attach a control to it)
  > - Add a new group (top-level section)

### 3. Shape the requirement tree

Walk the user through where the control should live. When asking, briefly remind them what each level is:

- **Group** — a top-level section of the policy, organisational only (e.g. "S3 Controls"). Which group does the control belong to? Create a new group if needed.
- **Requirement** — a named cluster of related controls inside a group (e.g. "Encryption at Rest"). Which requirement does the control belong to? Create a new requirement if needed.
- **Nesting** — requirements can contain sub-requirements, but flat is almost always sufficient. See [policy-model.md](policy-model.md).

For how to reference the control inside the generated `control { name = "..." }` block, see [policy-model.md — Referencing a control in Terraform](policy-model.md#referencing-a-control-in-terraform).

### 4. Checkpoint before generation

Confirm the following in a single summary before generating any Terraform:

| Field | Value |
|---|---|
| Policy name | |
| Policy description | |
| Group name | |
| Requirement name (and parent if nested) | |
| Control name(s) — exact string(s) | |
| `is_active` | true / false |
| Target directory | |

**Do not proceed until the user confirms.**

### 5. Generate Terraform

Copy `templates/custom_policy.tf` into the target directory. Replace all `{{PLACEHOLDERS}}` with the confirmed values.

If the target directory already has a `versions.tf`, skip copying it. If it does not, copy `templates/versions.tf` alongside `custom_policy.tf`.

Run proactively:

```
terraform init
terraform validate
terraform plan
```

Preflight already confirmed the provider can authenticate — either from env vars in this shell or from the user's existing provider configuration. If `terraform plan` returns a credentials error anyway, surface it and re-run preflight.

Present the plan summary. Offer `terraform apply` — only on explicit user approval.

### 6. Set expectations

After a successful apply, remind the user of two things:

1. **Zone assignment** — the policy is not evaluated until it is assigned to a zone. Direct the user to:
   **Policies → Posture Policies → [policy name] → Zones** in the Sysdig Secure UI.
   This skill does not manage zones.

2. **Evaluation cadence** — controls run on a daily schedule. Results will not appear immediately after apply; they will be visible after the next scheduled posture scan.

## What this workflow does not do

- Call Posture policy write endpoints directly.
- Create or modify built-in Sysdig policies.
- Create, modify, delete, or assign zones.

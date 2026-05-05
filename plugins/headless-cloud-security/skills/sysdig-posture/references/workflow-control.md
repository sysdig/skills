# Workflow — Define a Custom Control

End-to-end flow for authoring a Posture custom control. The skill produces (a) a `control.rego` file, (b) a `.tf` file wrapping it with `sysdig_secure_posture_control`, and (c) a validated Rego body that has passed `TestRego` against the sample `input` for the chosen kind.

No API writes. All creation happens via `terraform apply` on user approval.

## Inputs to gather up front

Use `AskUserQuestion` where the option set is bounded; otherwise confirm freeform answers in a single summary before generation.

| Field | Example | Notes |
|---|---|---|
| Control name | `S3 - Buckets must enforce encryption at rest` | Unique per tenant |
| Description | Short human-readable summary | Required, non-empty |
| Resource kind | `AWS_S3_BUCKET` | From the `list_posture_resource_kinds` MCP tool |
| Severity | `Low` / `Medium` / `High` | One of those three |
| Rule intent | Plain-language description of what makes the resource risky | Drives the Rego |
| Remediation details | What a reader should do when the control fires | Required, non-empty |
| Target directory | Where `.tf` + `.rego` should land | Default: cwd |

## Steps

Preflight (MCP availability, local tools, Terraform credentials) is handled in [SKILL.md](../SKILL.md#prerequisites) before routing here — assume it has passed.

Steps 1–3 gather and confirm every input. Steps 4–9 generate, validate, and (with approval) deploy. Do not start step 4 until step 3 has a confirmed value for every row in the field table above.

### 1. Capture the user's intent

Ask the user for a one- or two-sentence description of the control: what resource it covers, what condition makes the resource risky, plus any severity / remediation hints they want to include. This single answer typically supplies the description, rule intent, and a strong signal for the resource kind.

Do not pick a kind, fetch a sample, or write any files yet.

### 2. Extract candidate field values

From the user's description, derive a candidate value for every row in the field table:

- **Resource kind** — call the `list_posture_resource_kinds` MCP tool once (no arguments). Map the cloud / service mentioned (e.g. "S3 bucket") to the canonical kind from that list (`AWS_S3_BUCKET`). The casing returned by the tool is what the API and the Terraform provider expect — use it verbatim. If the description is ambiguous between several kinds (e.g. "EC2" → instance vs. volume vs. security group), keep all plausible candidates as a shortlist; resolve in step 3.
- **Control name** — derive from the intent (e.g. `S3 - Buckets must enforce encryption at rest`) if the user didn't state one.
- **Description** — condense the user's own words into a single short line.
- **Severity** — only set if the user explicitly stated it; otherwise leave blank for step 3.
- **Rule intent** — the user's "what makes it risky" phrasing, kept as-is. This drives the Rego in step 5.
- **Remediation details** — extract if mentioned; otherwise leave blank.
- **Target directory** — default to cwd unless the user implied a different path.

Do not fetch the sample input or write files in this step.

### 3. Confirm fields in one round

Present the candidates and unset fields as a single summary, marking each as `(extracted)` or `(needs input)`. Use `AskUserQuestion` for bounded sets — severity (`Low` / `Medium` / `High`) and the resource-kind shortlist if more than one candidate survived step 2 — and freeform for the rest.

The user either confirms the summary, edits values inline, or rejects. Re-ask only the fields that changed. Generation must not begin until every field has a confirmed value.

### 4. Fetch the sample `input`

Call the `get_posture_resource_template` MCP tool with `{ "resource_kind": "<kind>" }`. The tool returns the sample JSON object. Show only the fields that look relevant to the user's rule (full samples can be hundreds of lines — don't dump the whole thing).

Use this sample to ground the Rego: field names and casing match what the platform passes to `input` at evaluation time. The sample is also exactly what `test_posture_rego` will bind to `input` in step 6 — same embedded fixture, same handler — so what you read here is what your rule will see.

### 5. Author Rego on disk

Create `control.rego` in the user's target directory. Start from the required shape:

```rego
package sysdig

import future.keywords.if
import future.keywords.in

default risky := false

risky if {
  # condition against input.*
}
```

Translate the user's plain-language intent into Rego, referencing the sample `input` for field paths. See [rego-cheatsheet.md](rego-cheatsheet.md) for idioms and traps.

### 6. Iterate with `test_posture_rego`

For each revision: read `control.rego` from disk and call `test_posture_rego` with `{ "resource_kind": "<kind>", "rego": "<file content>" }`. Interpret the `{ passed, message }` response as three states (full mapping in [rego-cheatsheet.md](rego-cheatsheet.md#iteration-loop)):

- `message` non-empty → **compile_error** — read `message`; consult the cheatsheet's *Common mistakes*.
- `message` empty, `passed: true` → **sample_compliant** — rule did not flag the fixture.
- `message` empty, `passed: false` → **sample_risky** — rule flagged the fixture.

Neither `sample_compliant` nor `sample_risky` is universally good — compare against what the user expects against the step-4 fixture: a non-compliant fixture should produce `sample_risky`, a compliant one `sample_compliant`. Adjust and retry until expectation matches.

When useful, walk through a second mental sample (the opposite case). The API only evaluates against the embedded fixture, so this is reasoning-only.

### 7. Generate Terraform

Copy `templates/versions.tf` and `templates/custom_control.tf` into the target directory. If `versions.tf` already exists there (e.g. from a previous deployment), skip copying it — do not duplicate the provider block.

Replace placeholders in `custom_control.tf`:

| Placeholder | Value |
|---|---|
| `{{CONTROL_TF_ID}}` | A valid Terraform identifier derived from the name (lowercase, underscores) |
| `{{NAME}}` | Control name as the user provided it |
| `{{DESCRIPTION}}` | Short description |
| `{{RESOURCE_KIND}}` | The resource kind, e.g. `AWS_S3_BUCKET` |
| `{{SEVERITY}}` | `Low` / `Medium` / `High` |
| `{{REGO_FILENAME}}` | Usually `control.rego` |
| `{{REMEDIATION_DETAILS}}` | Remediation text (multi-line OK; the template uses a heredoc) |

### 8. Validate + plan

Run proactively:

```
terraform init
terraform validate
terraform plan
```

Preflight already confirmed the provider can authenticate — either from env vars in this shell or from the user's existing provider configuration. If `terraform plan` returns a credentials error anyway, surface it and re-run preflight.

Present the plan summary. Offer `terraform apply` — only on explicit user approval.

### 9. Offer the next step

Ask whether the user wants to attach this control to a policy. If yes, route into the policy workflow ([workflow-policy.md](workflow-policy.md)).

## What this workflow does not do

- Call Posture control write endpoints directly.
- Create or modify built-in Sysdig controls.
- Attach the control to a policy — that's the policy workflow.
- Create, modify, delete, or assign zones.

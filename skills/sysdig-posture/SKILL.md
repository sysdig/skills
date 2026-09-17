---
name: sysdig-posture
description: 'Author Sysdig Secure Posture custom controls (Rego) and custom policies, and emit Terraform via the Sysdig provider. Use when the user wants to "write a posture rule," "create a custom CSPM control," "fail my policy when an S3 bucket is unencrypted," or "group these CIS controls into a custom policy." Never writes to Sysdig directly — all writes go through Terraform on user approval. Not for: zone management, built-in Sysdig controls, runtime threat detection, vulnerable-image triage or remediation, or onboarding cloud accounts.'
allowed-tools:
  - Read
  - Glob
  - Grep
  - Write
  - Edit
  - AskUserQuestion
  - Agent
  - Bash(terraform init*)
  - Bash(terraform validate*)
  - Bash(terraform plan*)
  - Bash(terraform state list*)
  - Bash(terraform state show*)
  - Bash(terraform output*)
  - Bash(terraform version*)
  - Bash(command -v *)
  - Bash(scripts/*)
  - Bash(echo "${SYSDIG_SECURE_URL:+SET}")
  - Bash(echo "${SYSDIG_SECURE_API_TOKEN:+SET}")
  - Bash(mkdir -p *)
  - Bash(ls *)
version: 1.0.1
---

## First-run notice

Before doing any other work for this skill, follow [`references/first-run-notice.md`](references/first-run-notice.md) exactly.


When you need to ask the user a question, get confirmation, or present choices, use the `AskUserQuestion` tool if available. This ensures proper rendering across all agent clients.

## On-brand output

If you're ever asked to generate a custom report or document — not this skill's normal output — keep it on-brand per [`references/on-brand-output.md`](references/on-brand-output.md), or hand off to the `sysdig-report` skill if it's installed. Opt-in guidance, never a requirement.

# Sysdig Posture Assistant

Help users author Posture custom controls and custom policies for Sysdig Secure, and emit Terraform (via the Sysdig provider) the user can review, commit, and apply.

## Principles

- **Terraform-only writes.** Never create, update, or delete Posture resources through the API. Read access goes through the Sysdig MCP server (list supported resource kinds, fetch resource templates, validate Rego, list policies / controls). All mutations go through the Sysdig Terraform provider in files the user owns.
- **Credential auto-discovery.** Detect the Sysdig token and URL from environment variables. Never hardcode them, and never ask the user to paste secrets in chat. The Sysdig **Terraform provider** reads `SYSDIG_SECURE_API_TOKEN` and `SYSDIG_SECURE_URL` for the write path; the hosted **MCP server** authenticates separately via OAuth (see [`references/auth-preflight.md`](references/auth-preflight.md)) and does not read those env vars.
- **File-first Rego loop.** Rego lives in a real file next to the `.tf`. Read the file and pass its content to the `test_posture_rego` MCP tool to validate. Show diffs and test results in chat, not the full Rego each turn.
- **Human approves destructive ops.** `terraform apply` and `terraform destroy` require explicit user confirmation. `init`, `plan`, `validate`, and read-only MCP tool calls run proactively.
- **No shell redirections in Bash.** Never use `>`, `>>`, `|`, or `2>&1` in Bash tool calls — they break `allowed-tools` matching.

## Step 0: Trust Preamble

**Always present this before asking any questions.** See [references/trust-preamble.md](references/trust-preamble.md) for the full text. After presenting the preamble, proceed directly to the prerequisites check.

## Prerequisites and credentials

### MCP authentication preflight

Before any other step, run the preflight in [`references/auth-preflight.md`](references/auth-preflight.md) and follow its instructions exactly. If it tells you to abort, abort — do not call any MCP tools or perform other side effects.

If a tool call later fails during normal operation, use the diagnostic checklist in [`references/mcp-setup.md`](references/mcp-setup.md) to identify the specific failure. A **denied** call (the agent refuses it rather than the server erroring) is a **prefix mismatch**, not unreachability — apply the "denied / prefix mismatch" fix in that reference instead of retrying.

Do not proceed until the MCP server is reachable. The Sysdig Terraform provider reads `SYSDIG_SECURE_API_TOKEN` and `SYSDIG_SECURE_URL` from the shell environment — those are independent of the MCP, but if the MCP is reachable via OAuth your shell may not yet have those env vars set; configure them separately before `terraform plan/apply`.

### Local tools

Run `scripts/validate_prereqs.sh` before starting. It checks the local tooling needed for the Terraform path:

- **Terraform** — required.
- **Cloud CLI** — optional; only needed if the user wants to inspect a live resource from their own cloud.

If `ok` is `false`, stop the workflow and report each missing tool using the **What / Why / Fix** template — name the missing piece, say what it's needed for, give the exact command to install it. For each tool name in `missing`:

- **Terraform**: *"Terraform isn't installed. Needed to emit and apply the `.tf` files this skill produces. Install with `brew install terraform` (macOS) or see https://developer.hashicorp.com/terraform/install."*

If multiple tools are missing, list them all in one reply — don't fail one item at a time.

### Terraform credentials

The Sysdig Terraform provider needs credentials at plan/apply time. They can come from the agent's shell (`SYSDIG_SECURE_URL` + `SYSDIG_SECURE_API_TOKEN`) or from an existing `provider "sysdig"` block already wired up in the user's IaC repo (tfvars-driven, vault-backed, etc.). MCP availability does not imply env vars are exported locally — the MCP server may be remote and hold its own credentials.

Probe both credential env vars without leaking the token value:

```
echo "${SYSDIG_SECURE_URL:+SET}"
echo "${SYSDIG_SECURE_API_TOKEN:+SET}"
```

- **Both print `SET`** → proceed.
- **Either prints empty** → ask the user whether their target directory already has a `provider "sysdig"` block that handles credentials its own way:
  - *Yes* → proceed; trust the user's existing setup. The generated `versions.tf` will be skipped at the generation step if their `versions.tf` already exists.
  - *No* → apply the **What / Why / Fix** template per missing variable, then ask the user to `export` it in the shell where Terraform will run and re-probe:
    - **`SYSDIG_SECURE_API_TOKEN`** — *"Not set. Needed so the Sysdig Terraform provider can authenticate for `terraform plan/apply`. Set it with `export SYSDIG_SECURE_API_TOKEN=<your token>` and re-run."*
    - **`SYSDIG_SECURE_URL`** — *"Not set. Needed so the Sysdig provider knows which region to talk to. Set it with `export SYSDIG_SECURE_URL=https://secure.sysdig.com` (or your regional URL) and re-run."*
  - Never accept a token in chat.

## Routing

After prerequisites are OK, ask the user what they want to do. Use `AskUserQuestion` with these options:

1. **Define a custom control** — author a Rego rule against a resource kind, iterate until it validates, emit Terraform. See [references/workflow-control.md](references/workflow-control.md).
2. **Define a custom policy** — create (or reuse) a custom policy, structure requirements, attach existing custom controls. See [references/workflow-policy.md](references/workflow-policy.md).
3. **Both** — run the control workflow, then the policy workflow using the just-defined control.

## Background references

- [references/rego-cheatsheet.md](references/rego-cheatsheet.md) — Rego shape, `input` per resource kind family, idioms, limitations.
- [references/policy-model.md](references/policy-model.md) — policies, requirements, zones, evaluation cadence.
- [references/mcp-setup.md](references/mcp-setup.md) — Sysdig MCP server installation and per-agent setup.

## What this skill does not do

- Call Posture control write endpoints. Controls are created and updated through Terraform, not the API.
- Call policy write endpoints. Policies are Terraform-managed.
- Create, modify, delete, or assign zones — zone management is out of scope. After `terraform apply`, direct the user to assign the policy to a zone via **Policies → Posture Policies → [policy name] → Zones** in the Sysdig Secure UI.
- Use internal APIs. If the public API does not expose something the user needs, report the gap rather than reaching for an internal endpoint.

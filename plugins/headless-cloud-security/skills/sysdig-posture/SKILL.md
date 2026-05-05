---
name: sysdig-posture
description: >
  Author Sysdig Secure Posture custom controls (Rego) and custom policies, and
  emit Terraform using the Sysdig provider. API access is read-only: discover
  supported resource kinds, validate Rego, list policies / controls.
  All writes happen through Terraform, never through the API.
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
  - Bash(go version*)
  - Bash(command -v *)
  - Bash(echo "${SYSDIG_SECURE_URL:+SET}")
  - Bash(echo "${SYSDIG_SECURE_API_TOKEN:+SET}")
  - Bash(*validate_prereqs*)
  - Bash(mkdir -p *)
  - Bash(ls *)
---

## First-run notice (Public Beta)

Before doing any other work for this skill, perform this one-time check:

1. If `~/.config/sysdig-bloom/disclaimer-shown-v1` exists, skip the rest of this section.
2. Otherwise, display the following message to the user verbatim, preserving the markdown link, in a single message:

   > This plugin is a Public Beta release. It is provided “as is” and “as available,” without warranties of any kind. By installing this plugin, you agree to the Public Beta Terms available in the [repository readme](https://github.com/sysdig/skills#public-beta-terms).

3. Create the marker file `~/.config/sysdig-bloom/disclaimer-shown-v1` using the Write tool (any short content, e.g. the current UTC timestamp). The Write tool creates parent directories automatically and avoids the shell-redirection restrictions imposed by some skills' allowed-tools lists.
4. Then continue with the user's request.


When you need to ask the user a question, get confirmation, or present choices, use the `AskUserQuestion` tool if available. This ensures proper rendering across all agent clients.

# Sysdig Posture Assistant

Help users author Posture custom controls and custom policies for Sysdig Secure, and emit Terraform (via the Sysdig provider) the user can review, commit, and apply.

## Principles

- **Terraform-only writes.** Never create, update, or delete Posture resources through the API. Read access goes through the Sysdig MCP server (list supported resource kinds, fetch resource templates, validate Rego, list policies / controls). All mutations go through the Sysdig Terraform provider in files the user owns.
- **Credential auto-discovery.** Detect the Sysdig token and URL from environment variables. Never hardcode them, and never ask the user to paste secrets in chat. The MCP server and the Terraform provider both read `SYSDIG_SECURE_API_TOKEN` and `SYSDIG_SECURE_URL`.
- **File-first Rego loop.** Rego lives in a real file next to the `.tf`. Read the file and pass its content to the `test_posture_rego` MCP tool to validate. Show diffs and test results in chat, not the full Rego each turn.
- **Human approves destructive ops.** `terraform apply` and `terraform destroy` require explicit user confirmation. `init`, `plan`, `validate`, and read-only MCP tool calls run proactively.
- **No shell redirections in Bash.** Never use `>`, `>>`, `|`, or `2>&1` in Bash tool calls — they break `allowed-tools` matching.

## Prerequisites

### MCP availability

Verify that the Sysdig MCP server is available by checking that the `get_customer_settings` tool exists. If it is not available, stop and **output the message below verbatim — do not paraphrase, expand, restructure, or drop sentences**:

> **Sysdig MCP server isn't reachable** (the tool `get_customer_settings` is missing). To register it in Claude Code:
>
> ```
> claude mcp add sysdig -- npx -y @sysdig/secure-mcp-server
> ```
>
> Set `SYSDIG_SECURE_API_TOKEN` and `SYSDIG_SECURE_URL` first, then re-run `/sysdig-posture`. For other agents (Cursor, Codex, OpenCode) and troubleshooting: [`references/mcp-setup.md`](references/mcp-setup.md).

Do not proceed until the MCP server is reachable. The same env vars are picked up by the Sysdig Terraform provider, so once the MCP check passes, `terraform plan/apply` will authenticate from the same place.

### Local tools

Run `scripts/validate_prereqs.sh` before starting. It checks the local tooling needed for the Terraform path:

- **Terraform** — required.
- **Go** — required by the Sysdig Terraform provider build path.
- **Cloud CLI** — optional; only needed if the user wants to inspect a live resource from their own cloud.

If `ok` is `false`, surface the install command for each entry in `missing` and stop.

### Terraform credentials

The Sysdig Terraform provider needs credentials at plan/apply time. They can come from the agent's shell (`SYSDIG_SECURE_URL` + `SYSDIG_SECURE_API_TOKEN`) or from an existing `provider "sysdig"` block already wired up in the user's IaC repo (tfvars-driven, vault-backed, etc.). MCP availability does not imply env vars are exported locally — the MCP server may be remote and hold its own credentials.

Probe both env vars without leaking the token value:

```
echo "${SYSDIG_SECURE_URL:+SET}"
echo "${SYSDIG_SECURE_API_TOKEN:+SET}"
```

- **Both print `SET`** → proceed.
- **Either prints empty** → ask the user whether their target directory already has a `provider "sysdig"` block that handles credentials its own way:
  - *Yes* → proceed; trust the user's existing setup. The generated `versions.tf` will be skipped at the generation step if their `versions.tf` already exists.
  - *No* → ask the user to `export` the missing variable in the shell where Terraform will run, then re-probe. Never accept a token in chat.

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

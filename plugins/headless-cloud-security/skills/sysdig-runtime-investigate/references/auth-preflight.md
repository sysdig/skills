# MCP authentication preflight

Run this check **before any other step** in any skill that depends on the Sysdig MCP server.

The hosted Sysdig MCP server exposes its full tool catalog only after the user has authenticated. Until then, only the OAuth bootstrap pair (`authenticate`, `complete_authentication`) is visible to the agent. A skill that calls a real MCP tool before the user has authenticated will fail mid-flow — possibly after performing side effects like file writes, git operations, or chat output. This preflight prevents that by detecting authentication state *before* the skill starts.

## How to check

Scan the agent's currently available tool list. Do not call any tool to perform this check — just look at the names of tools that are visible.

**Do not narrate the check.** Once you've identified the state, output the action specified for that state and nothing else. The user does not need to hear about "states," tool names, or probes — that vocabulary is internal to this preflight. For State 1, proceed silently. For State 2 and State 3, emit the verbatim message as the entirety of your response.

## How Sysdig tools are named

The skills refer to Sysdig MCP tools by their **bare tool name** — `get_customer_settings`, `run_sysql`, `list_runtime_events`, and so on. The fully-qualified name your agent sees depends on the client and on the name the server was registered under, for example:

- `get_customer_settings` (Claude Code, `claude mcp add … secure-mcp-server …`)
- `mcp__plugin_<plugin-name>_<server-name>__get_customer_settings` (Claude Code plugin install)
- `mcp__claude_ai_<Connector_Name>__get_customer_settings` (claude.ai / organization-managed connector)
- `<server-name>_get_customer_settings`, `<server-name>.get_customer_settings`, or just `get_customer_settings` (other clients)

**Match by tool-name suffix and ignore the prefix.** Whenever a skill says "call `run_sysql`", call the visible tool whose name ends in `run_sysql` and that belongs to the Sysdig MCP server. Never assume a particular server name.

To identify **which** server is the Sysdig one, look for the server that exposes Sysdig-specific tools such as `get_customer_settings`, `run_sysql`, and `list_runtime_events` together. If more than one server matches, prefer the one whose name refers to Sysdig (e.g. contains `sysdig` or `secure`), and ask the user if it is still ambiguous.

## The three states

### State 1 — a Sysdig tool ending in `get_customer_settings` is visible

The server is registered, the user has authenticated, and the full tool catalog is reachable. **Proceed with the skill.**

### State 2 — a Sysdig server is visible but exposes only `authenticate` / `complete_authentication`

The server is registered but the user hasn't signed in yet. Because `authenticate` is generic to any OAuth-protected MCP server, only treat it as the Sysdig server when its name refers to Sysdig (e.g. contains `sysdig` or `secure`). **Stop** and tell the user verbatim:

> The Sysdig MCP server is registered but needs sign-in. In Claude Code, run `/mcp`, select the Sysdig MCP server entry, and click **Authenticate** (your browser opens to finish). Once it's done, re-invoke this skill.

Do **not** call the `authenticate` tool yourself. That tool opens a browser without user warning, which is a hostile experience. Always let the user drive the `/mcp` flow.

### State 3 — no Sysdig MCP server is visible at all

The server is not registered. **Stop** and tell the user verbatim:

> The Sysdig MCP server isn't registered. In Claude Code, register it with:
>
>     claude mcp add --transport http secure-mcp-server https://<region>/mcp/secure
>
> Use your tenant's regional URL — sign in to Sysdig Secure in your browser, copy the hostname, and append `/mcp/secure`. The full per-region list is in [references/mcp-setup.md](mcp-setup.md). Restart Claude Code, then run `/mcp` → select the Sysdig server → **Authenticate**, and re-invoke this skill.

## Why the check looks for `get_customer_settings` specifically

`get_customer_settings` is a universal Sysdig tool — every tenant has customer settings, it has no required arguments, and it isn't gated by any license tier. It is also the tool the previous (stdio-mode) skills used as their availability probe, so it remains the established convention. Its presence in the tool list is a reliable proxy for "the catalog is fully available." We don't call it during the preflight; the *visibility* of the tool name is the signal.

## What this preflight is not for

- **Mid-flow auth failures.** If an MCP tool call returns a 401 during normal operation (e.g. a token expired mid-session), surface the error to the user and ask them to re-run `/mcp` → Authenticate. The preflight only catches "not yet authenticated"; it doesn't replace error handling.
- **Tool-call diagnostics.** If you're investigating a single tool failure (rather than auth state), use the troubleshooting checklist in [references/mcp-setup.md](mcp-setup.md) instead.

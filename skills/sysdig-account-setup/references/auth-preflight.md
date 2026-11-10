# MCP authentication preflight

Run this check **before any other step**. This skill runs entirely on the Sysdig
MCP server — both read-only lookups (`get_current_user`, `list_zones`) and
mutations (the `create_*`/`update_*`/`set_*` write tools). The MCP catalog is only
fully visible after the user has authenticated.

## How to check

Scan the agent's currently available tool list. Do not call any tool to perform
this check — just look at the names of visible tools.

**Do not narrate the check.** Once you've identified the state, output the action
for that state and nothing else. For State 1, proceed silently. For State 2 and
State 3, emit the verbatim message as your entire response.

## How Sysdig tools are named

The skills refer to Sysdig MCP tools by their **bare tool name** (`get_current_user`,
`list_zones`, …). The fully-qualified name your agent sees depends on the client and
on the name the server was registered under — e.g. `mcp__secure-mcp-server__…`,
`mcp__plugin_<plugin-name>_<server-name>__…`, `mcp__claude_ai_<Connector_Name>__…`,
or a client-specific form. **Match by tool-name suffix and ignore the prefix**; never
assume a particular server name. The Sysdig server is the one exposing Sysdig tools
such as `get_current_user`, `get_customer_settings`, and `list_zones` together; if
several match, prefer the one whose name refers to Sysdig and ask the user if still
ambiguous.

### State 1 — a Sysdig tool ending in `get_current_user` is visible

The server is registered and authenticated. **Proceed with the skill.**

### State 2 — a Sysdig server is visible but exposes only `authenticate` / `complete_authentication`

Registered but not signed in (`authenticate` is generic to any OAuth MCP server —
only treat it as Sysdig's when the server name refers to Sysdig). **Stop** and tell
the user verbatim:

> The Sysdig MCP server is registered but needs sign-in. In Claude Code, run `/mcp`, select the Sysdig MCP server entry, and click **Authenticate** (your browser opens to finish). Once it's done, re-invoke this skill.

Do **not** call the `authenticate` tool yourself — it opens a browser without
warning. Let the user drive the `/mcp` flow.

### State 3 — no Sysdig MCP server is visible

Not registered. **Stop** and tell the user verbatim:

> The Sysdig MCP server isn't registered. In Claude Code, register it with:
>
>     claude mcp add --transport http secure-mcp-server https://<region>/mcp/secure
>
> Use your tenant's regional URL — sign in to Sysdig Secure in your browser, copy the hostname, and append `/mcp/secure`. Restart Claude Code, then run `/mcp` → select the Sysdig server → **Authenticate**, and re-invoke this skill.

## Note

This preflight only catches "not yet authenticated". This skill runs entirely on
the MCP server (no API token / `curl`), so if any MCP call returns 401 mid-flow
(session expired), surface the error and ask the user to re-run `/mcp` →
Authenticate.

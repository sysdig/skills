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

Match by **suffix, not exact prefix** — the prefix varies by install mode
(`mcp__secure-mcp-server__…` for user-level `claude mcp add`,
`mcp__plugin_<plugin-name>_secure-mcp-server__…` for plugin install). The server
name (`secure-mcp-server`) and tool names are invariant.

### State 1 — a tool ending in `secure-mcp-server__get_current_user` is visible

The server is registered and authenticated. **Proceed with the skill.**

### State 2 — only tools ending in `secure-mcp-server__authenticate` and `secure-mcp-server__complete_authentication` are visible

Registered but not signed in. **Stop** and tell the user verbatim:

> The Sysdig MCP server is registered but needs sign-in. In Claude Code, run `/mcp`, select the Sysdig MCP server entry, and click **Authenticate** (your browser opens to finish). Once it's done, re-invoke this skill.

Do **not** call any `*secure-mcp-server__authenticate` tool yourself — it opens a
browser without warning. Let the user drive the `/mcp` flow.

### State 3 — no tool whose name contains `secure-mcp-server` is visible

Not registered. **Stop** and tell the user verbatim:

> The Sysdig MCP server isn't registered. In Claude Code, register it with:
>
>     claude mcp add --transport http secure-mcp-server https://<region>/mcp/secure
>
> Use your tenant's regional URL — sign in to Sysdig Secure in your browser, copy the hostname, and append `/mcp/secure`. Restart Claude Code, then run `/mcp` → `secure-mcp-server` → **Authenticate**, and re-invoke this skill.

## Note

This preflight only catches "not yet authenticated". This skill runs entirely on
the MCP server (no API token / `curl`), so if any MCP call returns 401 mid-flow
(session expired), surface the error and ask the user to re-run `/mcp` →
Authenticate.

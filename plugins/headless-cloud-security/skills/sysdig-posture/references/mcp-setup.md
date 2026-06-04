# Sysdig MCP server — installation and setup

The Sysdig MCP server gives the Sysdig skills direct, read access to your Sysdig Secure tenant — vulnerability findings, runtime threats, posture controls, workload inventory, runtime events. It is **hosted by Sysdig** and reachable over HTTPS, per region. You register it once with your agent; there is nothing to install or run locally.

## What this is

A Model Context Protocol server, hosted by Sysdig per region, that exposes your Sysdig Secure tenant's data as tools your agent can call.

- **Transport**: HTTP (streamable, MCP-compliant).
- **Registration name**: `secure-mcp-server` — keep this exact name; anything else makes the server harder to find and debug.
- **Authentication**: OAuth. The first time a skill needs the server, you authenticate once in your browser and the agent stores the session token. There is no API token to copy or paste.
- **Some of the tools it exposes**: `get_customer_settings`, `list_zones`, `list_vulnerability_findings_by_image`, `run_sysql`, `generate_sysql`, `test_posture_rego`, `list_runtime_events`, `get_skill_state`, `save_skill_state`.

> **Using an API token instead of OAuth** (for headless / CI environments that can't drive a browser) is a feature of the Sysdig MCP server itself, configured at registration time by adding an `Authorization: Bearer <token>` request header. See the Sysdig MCP server documentation for token-based setup. The skills work identically in either mode.

## Per-region URLs

The hosted MCP server lives at `<region-url>/mcp/secure`. Find your region's row and use the **MCP server URL** in the registration command below. The **Sysdig UI URL** is what you see in your browser when signed in to Sysdig Secure — use it to identify which region you're in.

| Region | Code | Sysdig UI URL | MCP server URL |
|---|---|---|---|
| US East (N. Virginia) | us1 | `https://secure.sysdig.com` | `https://secure.sysdig.com/mcp/secure` |
| US West (Oregon) | us2 | `https://us2.app.sysdig.com` | `https://us2.app.sysdig.com/mcp/secure` |
| US West (Dallas) | us4 | `https://app.us4.sysdig.com` | `https://app.us4.sysdig.com/mcp/secure` |
| EU Central (Frankfurt) | eu1 | `https://eu1.app.sysdig.com` | `https://eu1.app.sysdig.com/mcp/secure` |
| EU North (Stockholm) | eu2 | `https://app.eu2.sysdig.com` | `https://app.eu2.sysdig.com/mcp/secure` |
| Asia Pacific (Sydney) | au1 | `https://app.au1.sysdig.com` | `https://app.au1.sysdig.com/mcp/secure` |
| Asia Pacific (Mumbai) | in1 | `https://app.in1.sysdig.com` | `https://app.in1.sysdig.com/mcp/secure` |
| Middle East (Dammam) | me2 | `https://app.me2.sysdig.com` | `https://app.me2.sysdig.com/mcp/secure` |

> **If your region isn't in the table above**, the hosted MCP server isn't available there — the table is the source of truth for where it's reachable. Tenants in an unlisted region can still use these skills by self-hosting the Sysdig MCP server and registering that URL instead.

> If you're unsure of your region, sign in to Sysdig Secure in your browser and read the hostname from the URL bar — that's your UI URL; append `/mcp/secure` to get the MCP server URL.

## Claude Code — register the server

Run one command, substituting **your region's MCP server URL** from the table above:

```bash
claude mcp add --transport http secure-mcp-server https://us2.app.sysdig.com/mcp/secure
```

The registration is saved automatically — there is no environment variable to set or persist. Restart Claude Code if it was already running, then authenticate:

- The first time a Sysdig skill needs the server, run `/mcp`, select `secure-mcp-server`, and click **Authenticate**. Your browser opens once; the session is authenticated for the rest of your work.

Add `--scope user` to make the registration available across all your projects, or use the default (`local`) for the current project only.

## Other agents (Cursor, OpenAI Codex, OpenCode, Claude Desktop, ChatGPT, Gemini, …)

Every MCP-capable client can use the same hosted server — an HTTP MCP server at your region's `/mcp/secure` URL, authenticated via OAuth. The exact mechanics differ per client (a config file, a settings panel, or a CLI command), but the essentials are identical:

- **Transport**: HTTP (streamable).
- **Server name**: `secure-mcp-server`.
- **URL**: your region's MCP server URL from the table above — e.g. `https://us2.app.sysdig.com/mcp/secure`.
- **Auth**: OAuth, no token. The client drives the browser flow on first request.

> **Multi-region caveat.** There is no region-independent URL yet. Set the URL for **your** tenant's region, and adjust whatever command or configuration your client uses if you move to a different region.

Example MCP config snippet, for clients that follow the standard MCP server schema — **edit the URL to your region**:

```json
{
  "mcpServers": {
    "secure-mcp-server": {
      "type": "http",
      "url": "https://us2.app.sysdig.com/mcp/secure"
    }
  }
}
```

Consult your client's MCP documentation for the exact config-file location and reload procedure. Keep the server name as `secure-mcp-server`.

## Verifying it's installed and active

In Claude Code:

```bash
claude mcp list
```

You should see a `secure-mcp-server` row with status `connected`. In a running session, `/mcp` opens the MCP status panel showing the auth state per server.

For the strongest end-to-end check, ask the agent to call `get_customer_settings`. If it returns a JSON object describing your tenant's settings, the server is reachable and authenticated.

## Troubleshooting

### Agent diagnostic checklist

When the MCP server isn't reachable, **do not show a generic message**. Run these checks in order, stop at the first failure, and report the specific problem with its fix:

1. **Server registered?** Run `claude mcp list` and look for a `secure-mcp-server` entry.
   - If **missing**: it was never registered. Show the `claude mcp add` command above with the user's regional MCP server URL.
   - If **present but not `connected`**: continue to step 2.

2. **Authenticated?** In a session, run `/mcp`, find `secure-mcp-server`, and check its auth state. If it shows "needs auth," click **Authenticate** to drive the browser flow. If OAuth previously succeeded but tools have stopped working, the session token may have expired — re-authenticate the same way.

3. **Correct region URL?** If the server returns network/DNS errors or talks to the wrong tenant, the registered URL is for the wrong region. Remove the entry (`claude mcp remove secure-mcp-server`) and re-add it with the correct MCP server URL from the region table.

4. **Local override?** A `secure-mcp-server` entry hardcoded in a project `.mcp.json`, `.claude/settings.local.json`, or `~/.claude/settings.json` takes precedence over your registration. If it points at the wrong region, remove or correct it.

Report exactly what failed, what you checked, and the specific fix. Do not dump this entire checklist to the user.

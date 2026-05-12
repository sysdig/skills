# Sysdig MCP server — installation and setup

The Sysdig MCP server provides Sysdig skills with direct access to your Sysdig Secure tenant — vulnerability findings, runtime threats, posture controls, workload inventory, runtime events. It must be registered with your agent before MCP-dependent skills can run.

## What this is

The Sysdig MCP server is a Model Context Protocol server that exposes your Sysdig Secure tenant's data as tools your agent can call directly. It runs locally as an `npx` subprocess and connects to your tenant over HTTPS.

- **Source**: `@sysdig/secure-mcp-server` on npm
- **Registration name**: `secure-mcp-server` — anything else makes the server harder to find and debug
- **Some of the tools it exposes**: `get_customer_settings`, `list_zones`, `list_plans`, `list_candidate_remediation_jobs`, `list_vulnerability_findings_by_image`, `run_sysql`, `generate_sysql`, `get_skill_state`, `save_skill_state`, `get_event_process_tree`, `list_runtime_events`

## Required environment variables

Set these in the shell that launches your agent. Sysdig skills will not work without them.

| Variable | Required? | Description |
|---|---|---|
| `SYSDIG_SECURE_API_TOKEN` | yes | API token with access to your tenant. Find it in Sysdig Secure → Settings → User Profile → API Tokens. Treat as a secret — don't commit it or paste it into chat. |
| `SYSDIG_SECURE_URL` | yes | Your tenant's base URL, e.g. `https://us2.app.sysdig.com`. The exact host depends on your SaaS region — copy it from the URL bar after signing in to Sysdig Secure. |
| `SYSDIG_MCP_API_TOKEN` | no | Override token used by the MCP layer specifically. Defaults to `SYSDIG_SECURE_API_TOKEN`. |
| `SYSDIG_MCP_API_HOST` | no | Override host used by the MCP layer specifically. Defaults to `SYSDIG_SECURE_URL`. |

## Install path A — Claude Code plugin marketplace

Register the marketplace and install the plugin:

```bash
/plugin marketplace add sysdig/skills
/plugin install headless-cloud-security@sysdig-skills
```

The marketplace install loads everything automatically — plugin skills, the Sysdig MCP server, and per-skill MCP dependencies. No manual MCP registration needed.

If the skill refuses because the MCP isn't reachable, the registration didn't take. Recovery:

```bash
/plugin uninstall headless-cloud-security@sysdig-skills
/plugin install headless-cloud-security@sysdig-skills
```

…then restart your Claude Code session.

## Install path B — single skill via `npx skills` or manual symlink

If you installed only one skill — via `npx skills install sysdig/skills <skill-name>`, by symlinking the skill folder into another agent's skills directory, or by copying it manually — the MCP server is **not** auto-registered. Register it yourself:

```bash
claude mcp add secure-mcp-server -- npx -y @sysdig/secure-mcp-server
```

Make sure `SYSDIG_SECURE_API_TOKEN` and `SYSDIG_SECURE_URL` are exported in the shell that starts Claude Code — the MCP subprocess inherits them. Restart Claude Code after running the command so the new registration is picked up.

## Install path C — Cursor, OpenAI Codex, OpenCode, other MCP clients

Each agent client has its own MCP config file, but the server invocation is the same across all of them: run `npx -y @sysdig/secure-mcp-server` with the Sysdig env vars in scope.

Example MCP config snippet (works for any client following the standard MCP server schema):

```json
{
  "mcpServers": {
    "secure-mcp-server": {
      "command": "npx",
      "args": ["-y", "@sysdig/secure-mcp-server"],
      "env": {
        "SYSDIG_SECURE_API_TOKEN": "${SYSDIG_SECURE_API_TOKEN}",
        "SYSDIG_SECURE_URL": "${SYSDIG_SECURE_URL}"
      }
    }
  }
}
```

For the exact config-file location and reload procedure, consult your client's MCP setup documentation. Keep the server name as `secure-mcp-server`.

## Verifying it's installed and active

In Claude Code, run:

```bash
claude mcp list
```

You should see a `secure-mcp-server` row with status `connected`. In a running session, `/mcp` opens an interactive MCP status panel.

For the strongest end-to-end check, ask the agent to call `get_customer_settings`. If it returns a JSON object describing your tenant's settings, the server is installed, authenticated, and reachable.

## Troubleshooting

### Agent diagnostic checklist

When the MCP server isn't reachable, **do not show a generic message**. Run these checks in order, stop at the first failure, and report the specific problem with its fix:

1. **Node.js installed?** Run `node --version`. If missing: *"Node.js is not installed. The Sysdig MCP server runs as an npx subprocess and requires Node.js ≥ 18. Install it from https://nodejs.org/ or via your package manager (`brew install node`, `apt install nodejs`, etc.)."*

2. **npx available?** Run `which npx` (or `where npx` on Windows). If missing: *"npx is not available. It ships with npm ≥ 5.2 (bundled with Node.js). Reinstall or upgrade Node.js from https://nodejs.org/."*

3. **MCP server registered?** Run `claude mcp list` and look for a `secure-mcp-server` entry.
   - If **missing**: the server was never registered. Show the install command for the user's setup (marketplace install for Claude Code, `claude mcp add` for single-skill installs — see Install paths A and B above).
   - If **present but not `connected`**: the registration exists but the subprocess is failing. Continue to step 4.

4. **Local MCP config overriding the plugin?** Check whether a local MCP configuration is overriding the plugin's `.mcp.json`. Look for a `secure-mcp-server` entry in project-level `.mcp.json`, `.claude/settings.local.json`, or `~/.claude/settings.json` that hardcodes `env` values (especially `SYSDIG_SECURE_URL` or `SYSDIG_SECURE_API_TOKEN`). A local override takes precedence over the plugin's `.mcp.json` and over shell environment variables — if it points to a different region or has a stale token, the MCP server will connect to the wrong tenant or fail auth silently. Fix: remove the local override so the plugin's `.mcp.json` is used and credentials come from shell env vars, or update the hardcoded values to match the intended region.

5. **Environment variables set?** Check that `SYSDIG_SECURE_API_TOKEN` and `SYSDIG_SECURE_URL` are exported in the current shell (run `env | grep SYSDIG_SECURE`). Report which ones are missing. Remind the user these must be set in the shell that launches the agent — setting them after the session starts won't help.

6. **Token valid?** If the env vars are set but the MCP returns `401` or `403`: *"The API token was rejected by Sysdig. It may be expired or lack the required scopes. Regenerate it in Sysdig Secure → Settings → User Profile → API Tokens, re-export it, and restart the agent session."*

7. **URL correct?** If the MCP returns network/DNS errors: *"SYSDIG_SECURE_URL doesn't resolve. Verify it matches your Sysdig region — sign in to Sysdig Secure in your browser and copy the host from the URL bar."* Show the regions table from the "Required environment variables" section above.

8. **npx cache stale?** If tools exist but look outdated after a server upgrade: *"The npx cache may be holding an old version. Clear it with `rm -rf ~/.npm/_npx/*`, then restart the agent."*

Report exactly what failed, what you checked, and the specific fix. Do not dump this entire checklist to the user.

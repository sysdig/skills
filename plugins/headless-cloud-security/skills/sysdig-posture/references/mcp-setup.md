# Sysdig MCP server — installation and setup

The Sysdig MCP server provides Sysdig skills with direct access to your Sysdig Secure tenant — vulnerability findings, runtime threats, posture controls, workload inventory, runtime events. It must be registered with your agent before MCP-dependent skills can run.

## What this is

The Sysdig MCP server is a Model Context Protocol server that exposes your Sysdig Secure tenant's data as tools your agent can call directly. It runs locally as an `npx` subprocess and connects to your tenant over HTTPS.

- **Source**: `@sysdig/secure-mcp-server` on npm
- **Registration name**: `sysdig` — anything else makes the server harder to find and debug
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

If you installed the full Sysdig plugin via the Claude Code marketplace:

```bash
/plugin install sysdig-secure@sysdig-skills
```

…the MCP server is registered automatically — no manual step needed. If you installed this way and the skill is still refusing because the MCP isn't reachable, the registration didn't take. Recovery:

```bash
/plugin uninstall sysdig-secure@sysdig-skills
/plugin install sysdig-secure@sysdig-skills
```

…then restart your Claude Code session.

## Install path B — single skill via `npx skills` or manual symlink

If you installed only one skill — via `npx skills install sysdig/skills <skill-name>`, by symlinking the skill folder into another agent's skills directory, or by copying it manually — the MCP server is **not** auto-registered. Register it yourself:

```bash
claude mcp add sysdig -- npx -y @sysdig/secure-mcp-server
```

Make sure `SYSDIG_SECURE_API_TOKEN` and `SYSDIG_SECURE_URL` are exported in the shell that starts Claude Code — the MCP subprocess inherits them. Restart Claude Code after running the command so the new registration is picked up.

## Install path C — Cursor, OpenAI Codex, OpenCode, other MCP clients

Each agent client has its own MCP config file, but the server invocation is the same across all of them: run `npx -y @sysdig/secure-mcp-server` with the Sysdig env vars in scope.

Example MCP config snippet (works for any client following the standard MCP server schema):

```json
{
  "mcpServers": {
    "sysdig": {
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

For the exact config-file location and reload procedure, consult your client's MCP setup documentation. Keep the server name as `sysdig`.

## Verifying it's installed and active

In Claude Code, run:

```bash
claude mcp list
```

You should see a `sysdig` row with status `connected`. In a running session, `/mcp` opens an interactive MCP status panel.

For the strongest end-to-end check, ask the agent to call `get_customer_settings`. If it returns a JSON object describing your tenant's settings, the server is installed, authenticated, and reachable.

## Troubleshooting

- **`tool not found`** — the server registration is missing or named something other than `sysdig`. Re-run the Path B `claude mcp add` command.
- **`401` / `403` when the agent calls a tool** — the API token is missing, expired, or doesn't have the required scopes. Regenerate the token in Sysdig Secure → Settings → User Profile → API Tokens and re-export it before launching the agent.
- **`network` / `DNS` errors** — `SYSDIG_SECURE_URL` doesn't match your tenant's region. Sign in to Sysdig Secure in your browser and copy the host from the URL bar.
- **Tool list looks stale after a server upgrade** — the `npx` cache may be holding an old `secure-mcp-server`. Clear it:
  ```bash
  rm -rf ~/.npm/_npx/*
  ```
  then restart your agent.

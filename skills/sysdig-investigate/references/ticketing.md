# Optional ticketing systems

The investigate skill can optionally create a tracking ticket per image after building the remediation plan. Ticketing is **always optional** — the user can skip it regardless of whether a system is configured.

## Supported systems

The skill connects to a ticketing system through any compatible MCP server (hosted or local) — the host agent decides which to use. The skill itself only needs the standard ticketing tool surface (search / create / update). Names below are common implementations, not requirements.

### Jira / Atlassian

| Option | How to add | Notes |
|--------|-----------|-------|
| **Hosted Atlassian MCP (recommended)** | `claude mcp add --transport sse atlassian https://mcp.atlassian.com/v1/sse` (Claude Code) — OAuth login on first call | No tokens to manage; works with Cloud sites |
| Local stdio MCP | `npx -y --package=mcp-atlassian mcp-atlassian` with `JIRA_API_TOKEN`, `JIRA_BASE_URL`, `JIRA_USER_EMAIL` | Useful for environments without browser-based OAuth |
| `jira` CLI | <https://github.com/ankitpokhrel/jira-cli>, then `jira init` | Fallback when no MCP is registered |

Tools the skill expects (any equivalent will do): `searchJiraIssuesUsingJql` / `jira_search_issues`, `createJiraIssue` / `jira_create_issue`, `editJiraIssue` / `jira_update_issue`.

### Linear

| Option | How to add | Notes |
|--------|-----------|-------|
| **Hosted Linear MCP (recommended)** | `claude mcp add --transport sse linear https://mcp.linear.app/sse` — OAuth login | |
| `linear` CLI | <https://github.com/evangodon/linear-cli>, then `linear auth` | Fallback |

### GitHub Projects

| Option | How to add | Notes |
|--------|-----------|-------|
| **Hosted GitHub MCP (recommended)** | `claude mcp add --transport http github https://api.githubcopilot.com/mcp/ -H "Authorization: Bearer $GITHUB_PERSONAL_ACCESS_TOKEN"` | Requires PAT with `project` scope |
| `gh project` CLI | Built into `gh`; run `gh auth refresh -s project` | Fallback |

> **Don't have any of these?** Tell the user how to install the one they want (commands above) before declining ticketing — they may not realise their agent supports them.

## Detection algorithm

For each candidate system, in this order:

1. Check whether MCP tools matching that system's surface are available (any namespace — `jira_*`, `mcp__atlassian__*`, `linear_*`, `github__*`, etc.).
2. If not, check whether the corresponding CLI is on `$PATH` and authenticated.
3. If multiple are available, ask the user which to use.
4. If none are available and the user wants ticketing, **show the install commands above** and pause until the user confirms a system is ready, or accepts to skip ticketing.
5. If the user does not want ticketing, set `ticketing_system: null` in state and proceed without tickets.

## Skipping ticketing entirely

The user can decline tickets at any point:

- Decline the "Do you want to create tracking tickets?" prompt → no system is contacted.
- Set `ticketing_system: null` in state on first run to remember the preference for the session.

The handoff to `/sysdig-remediate` works with or without a ticket. Without one, the call is `/sysdig-remediate <image_reference> (image_id: <image_id>)`. With one, it includes `ticket: <ticket_key>` so remediate can append the PR link on completion.

## Assignee determination

Assignee is **always** derived from Sysdig-side signals only — never from git log or repository activity (those are PR reviewers, handled in `/sysdig-remediate`).

Priority chain:

1. `workload_owner` — owner annotation/label on the running workload (e.g. `team`, `owner`, `app.kubernetes.io/owner`).
2. `zone_owner` — owner of the selected Sysdig zone.
3. `previous_ticket_assignee` — assignee of the most recent ticket already filed for this image.
4. Leave unassigned.

Always confirm the suggestion with the user before setting the assignee.

## Existing-ticket search

Before creating a new ticket, search the configured system for tickets that reference the same image (by image name in the summary, or full image reference in the description). If an open ticket is found, propose **updating** it instead of creating a duplicate.

When updating, never modify the original description — append below a `----` separator with a dated update section.

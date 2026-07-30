# Ticketing — systems, detection, assignee, templates

`/sysdig-remediate` is the **sole ticket creator** in the Sysdig vulnerability workflow. Ticketing is one of the deliverables chosen in step 1b — when the user picks `pr` only, no ticketing system is contacted.

## Supported systems

The skill connects to Jira through any compatible MCP server (hosted or local) — the host agent decides which to use. The skill itself only needs the standard ticketing tool surface (search / create / update).

| Option | How to add | Notes |
|--------|-----------|-------|
| **Hosted Atlassian MCP (recommended)** | `claude mcp add --transport sse atlassian https://mcp.atlassian.com/v1/sse` (Claude Code) — OAuth login on first call | No tokens to manage; works with Cloud sites |
| Local stdio MCP | `npx -y --package=mcp-atlassian mcp-atlassian` with `JIRA_API_TOKEN`, `JIRA_BASE_URL`, `JIRA_USER_EMAIL` | Useful for environments without browser-based OAuth |
| `jira` CLI | <https://github.com/ankitpokhrel/jira-cli>, then `jira init` | Fallback when no MCP is registered |

Tools the skill expects (any equivalent will do): `searchJiraIssuesUsingJql` / `jira_search_issues`, `createJiraIssue` / `jira_create_issue`, `editJiraIssue` / `jira_update_issue`.

> **Don't have any of these?** Show the user the install commands above before ruling the
> ticket deliverable out — they may not realise their agent supports them.

Tickets created through Sysdig's own Jira integration (UI-driven) live in the same Jira instance — dedup (step 2b) finds them via the JQL search, which is why that search includes CVE ids alongside the image name.

## Detection algorithm

1. Check whether MCP tools matching the Jira surface are available (any namespace — `jira_*`, `mcp__atlassian__*`, etc.).
2. If not, check whether the `jira` CLI is on `$PATH` and authenticated.
3. If neither is available and the user wants a ticket deliverable, show the install commands above and pause until the user confirms a system is ready, or switches the deliverable to `pr` only.

## Assignee determination

Assignee is **always** derived from Sysdig-side signals only — never from git log or repository activity (those are PR reviewers, step 3c).

Priority chain:

1. `workload_owner` — owner annotation/label on the running workload (e.g. `team`, `owner`, `app.kubernetes.io/owner`).
2. `zone_owner` — owner of the relevant Sysdig zone.
3. `previous_ticket_assignee` — assignee of the most recent ticket for this image (from `ticket_assignees` state or a dedup hit).
4. Leave unassigned.

Always confirm the suggestion with the user before setting the assignee.

## Create template

**Summary:** `[Sysdig] Fix Critical/High vulnerabilities in <image_reference>`

**Description (Jira wiki markup — adapt syntax if the tenant renders Markdown):**

```
h2. Vulnerability Report

This ticket was created by the Sysdig remediate skill on <date>.

h2. Vulnerable Image

||Property||Value||
|Image|{noformat}<image_reference>{noformat}|
|Base OS|<base_os>|
|Environments|<comma-separated list>|
|Affected workloads|<workloads_count> (<workloads_internet_exposed_count> internet-exposed)|

h2. Critical & High CVEs

||CVE||Severity||Package||Installed||Safe Fix Version||CVSS||Exploitable||
|<cve_id>|<severity>|<package>|<installed_version>|<safe_target_version or "none available">|<cvss>|<yes/no>|
(repeat for each CVE)

h2. Fix Version Resolution

For each package with a fix, the safe target version verified by chain analysis
(candidate versions that introduce new Critical/High CVEs are skipped):

- *<package>*: <installed_version> → *<safe_target_version>*
  Resolution chain: <installed_version> → <v1> → <safe_target_version> (skipped <v1>: <new CVE id>)
- *<package>*: <installed_version> → *<safe_target_version>* (unassessed — no Critical/High known to Sysdig, but the version has not been observed in your environment; verify against upstream advisories)
- *<package>*: no safe fix available — versions checked: <list>, each introduces <reason>.

h2. Impact Assessment

<fixable_exposed_explanation>

*Network exposure:* <network_mitigated_explanation>
*Acceptable risk:* <has_acceptable_findings_explanation>

h2. Remediation

<!-- When a PR was opened this session: -->
PR: <pr_url> — updates <package> to <safe_target_version>. This ticket tracks it to merge/deploy.

<!-- Ticket-only (PR to follow later): -->
Run `/sysdig-remediate <image_reference> (image_id: <image_id>, ticket: <THIS_TICKET_KEY>)`
to open the fix PR; this ticket will be updated with the PR link on completion.

h2. References

- Sysdig job global_id: {noformat}<job_global_id>{noformat}   <!-- only if a tracked job exists -->
- Detection date: <date>
```

**Priority mapping:**
- `severity_normalized >= 0.9` → Critical
- `severity_normalized >= 0.7` → High
- otherwise → Medium

## Update template

When updating an existing ticket (adopted in dedup, or passed via `ticket:`): **never remove or modify the existing description**. Append below a separator:

```
----

h2. Update — <date>

_Added by Sysdig remediate skill._

h3. PR / Patch
- <link to PR>   <!-- hosted forge -->
- Patch: <absolute path to .patch file>   <!-- local mode -->
- Branch: `sysdig/fix-<cve-id>-<image-name>`   <!-- hosted forge only -->
- Reviewers: <list>

h3. Resolution Details
- <package>: <installed_version> → <safe_target_version>
- Resolution chain: <installed_version> → <v1> → <safe_target_version> (only if intermediate versions skipped)

h3. Status
- <"done — PR opened, awaiting review" | "failed — no safe fix available (analysis above)" | "failed — repo not found">
```

If a new Critical CVE was discovered relative to the existing ticket, note it but do **not** silently re-prioritise — leave priority and assignee untouched unless the user explicitly asks otherwise.

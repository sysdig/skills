---
name: sysdig-investigate
description: >
  Investigate vulnerable images in a Sysdig-monitored environment. Fetches and ranks
  images by risk, lets the user choose a focus (zero-day, critical in-use, exposed, all),
  builds a remediation plan, optionally creates a tracking ticket (Jira / Linear /
  GitHub Projects) using Sysdig-side signals to determine the assignee, and hands off
  to /sysdig-remediate.
  Triggers on: "investigate", "what should I fix", "show me vulnerable images",
  "prioritize vulnerabilities", "/sysdig-investigate".
---

## First-run notice (Public Beta)

Before doing any other work for this skill, perform this one-time check:

1. If `~/.config/sysdig-bloom/disclaimer-shown-v1` exists, skip the rest of this section.
2. Otherwise, display the following message to the user verbatim, preserving the markdown link, in a single message:

   > This plugin is a Public Beta release. It is provided “as is” and “as available,” without warranties of any kind. By installing this plugin, you agree to the Public Beta Terms available in the [repository readme](https://github.com/sysdig/skills#public-beta-terms).

3. Create the marker file `~/.config/sysdig-bloom/disclaimer-shown-v1` using the Write tool (any short content, e.g. the current UTC timestamp). The Write tool creates parent directories automatically and avoids the shell-redirection restrictions imposed by some skills' allowed-tools lists.
4. Then continue with the user's request.


When you need to ask the user a question, get confirmation, or present choices, use the `AskUserQuestion` tool if available. This ensures proper rendering across all agent clients.

Investigate vulnerable images in a Sysdig-monitored environment, build a remediation plan,
optionally file a tracking ticket per image, and hand off to `/sysdig-remediate`.

## State

State is read and written via the Sysdig MCP server tools.

| Operation | Tool | Arguments |
|-----------|------|-----------|
| Read state | `get_skill_state` | `{ "skill_state": "investigate" }` |
| Write state | `save_skill_state` | `{ "skill_state": "investigate", "version": <n>, "data": { ... } }` |
| Delete state | `delete_skill_state` | `{ "skill_state": "investigate" }` |

A `null` response from `get_skill_state` means no state exists yet — start with `{ "version": 0 }`.

### Schema

```json
{
  "version": 1,
  "last_run": "2025-03-15T10:00:00Z",
  "environment": "production",
  "focus": "actually_exploitable_findings",
  "images_found": 42,
  "images_planned": 5,
  "images_remediated": 2,
  "ticketing_system": "jira",
  "ticket_assignees": [
    {
      "image_reference": "quay.io/myorg/my-service:1.2.3",
      "assignee": "jane.doe@example.com",
      "source": "workload_owner",
      "last_confirmed": "2025-03-15"
    }
  ],
  "tickets": [
    {
      "image_reference": "quay.io/myorg/my-service:1.2.3",
      "ticket_key": "PROJ-123",
      "ticket_url": "https://example.atlassian.net/browse/PROJ-123",
      "status": "open",
      "assignee": "jane.doe@example.com",
      "created": "2025-03-15"
    }
  ],
  "ticket_history": [
    {
      "date": "2025-03-15",
      "image": "quay.io/myorg/my-service:1.2.3",
      "action": "created",
      "ticket_key": "PROJ-123",
      "assignee_source": "workload_owner"
    }
  ],
  "plan": [ /* per-image plan entries with status pending|remediated|skipped */ ]
}
```

### Read/write rules

- **Get** the state at the start of every session by calling the MCP tool `get_skill_state` with `{ "skill_state": "investigate" }`. A `null` response means no state exists yet — start with `{ "version": 0 }`.
- **Save** the state at the end of every session by calling the MCP tool `save_skill_state` with `{ "skill_state": "investigate", "version": <n>, "data": { ... } }`. Read the current contents first, merge new data, then pass the full merged object as `data`.
- **Version argument** — the server uses `version` for optimistic concurrency. Pass it as a separate argument (do not include it inside `data`):
  - First write (`get_skill_state` returned `null`) → call with `version: 0`. The server creates the record.
  - Subsequent writes → call with the same `version` value the previous `get_skill_state` returned. On success the server bumps it; on conflict it returns 409.
  - On 409 → call `get_skill_state` again, merge your changes into the freshly-read state, and retry once with the new version.
- **Matching keys** for upsert:
  - `ticket_assignees`: match on `image_reference`
  - `tickets`: match on `ticket_key`
  - `ticket_history`: always append (no dedup)
  - `plan`: upsert by `global_id`
- Dates use `YYYY-MM-DD` format; timestamps use ISO 8601.
- `ticketing_system` is `"jira" | "linear" | "github_projects" | null`. `null` means the user opted out or no system is configured.

**Ticketing is optional.** All ticket-related fields are absent or empty when the user skipped ticket creation.

## Steps

### 0. Prerequisites

Verify that the Sysdig MCP server is available by checking that the `get_customer_settings` tool exists. If it is not available, stop and **output the message below verbatim — do not paraphrase, expand, restructure, or drop sentences**:

> **Sysdig MCP server isn't reachable** (the tool `get_customer_settings` is missing). To register it in Claude Code:
>
> ```
> claude mcp add sysdig -- npx -y @sysdig/secure-mcp-server
> ```
>
> Set `SYSDIG_SECURE_API_TOKEN` and `SYSDIG_SECURE_URL` first, then re-run `/sysdig-investigate`. For other agents (Cursor, Codex, OpenCode) and troubleshooting: [`references/mcp-setup.md`](references/mcp-setup.md).

Do not proceed until the MCP server is reachable.
If the `get_customer_settings` tool responds, check if the flag `sage.next.enabled` is set to true. 
If not, jump to step 1b

### 1. Load existing plans

Using the tool `list_plans` check if there are existing plans the company is working on. A plan is a set of jobs (images to remediate) in a particular scope (one or more zones) for a particular `target_measure`.
List plans to the user and ask if he wants to work on one of them. Last choice must be a free search using an existing zone and a choosen `target_measure`.
If the user picks up a plan, fetch and present images using the tool `list_plan_remediation_jobs` and the plan_id the user selected and then jump and point 4a.

### 1b. Load vulnerable images using findings APIs

Refer to [zones](references/zones.md) to fetch user available zones.
Ask the user to pick a zone. Always include a zone "Entire Infrastructure" (no zone)

Then, using the tool `list_vulnerability_findings_by_image` use the user selected zones, to fetch the 10 most vulnerable images to the user.
Ask: _"Which of these would you like to remediate? (say 'all', pick numbers, or describe a filter)"_
Skip to step 5.

### 2. Discover zones

Refer to [zones](references/zones.md) to fetch user available zones.
Ask the user to pick a zone. Always include a zone "Entire Infrastructure" (no zone)

### 3. Choose focus

Ask the user what they want to focus on:

> "What would you like to investigate?"
> 1. **finding_count**: total distinct CVE+package findings.
> 2. **exposure_time_weighted**: age-weighted sum of findings (longer exposure = higher score).
> 3. **exposure_time_avg**: average age of Critical+High findings.
> 4. **sla_compliance**: lexicographic urgency based on oldest-bucket age vs SLA threshold.
> 5. **actually_exploitable_findings**: count of in-use, network-reachable findings.

Map the user's choice to `target_measure` parameter.

### 4. Fetch and present images

Call `list_candidate_remediation_jobs` with:
- `target_measure`: the selected target_measure
- `scope`: a JSON like { zones: [<user selected zone ids>] }
- `limit`: `10`

If the result is empty, tell the user there are no matching vulnerabilities in that
environment and stop.

### 4a. Fetch and present images

Present the results as a ranked table, sorted by internet-exposed first, then by
severity score descending:

| # | Image | Ranking Summary | Finding Percentage | Finding Count | Resource Count
|---|-------|--------|--------------------|---------------|
| 1 | quay.io/org/app:1.2 | 9 actually exploitable findings | 30% | 17 | 23
| 2 | quay.io/org/svc:2.0 | 16 actually exploitable findings | 12% | 43 | 44

Ask: _"Which of these would you like to remediate? (say 'all', pick numbers, or describe a filter)"_

### 5. Build a remediation plan

For the selected images, fetch information about the image using this SysQL query template:

- if the selected metric is actually_exploitable_findings run this query:

```
MATCH KubeWorkload HAS Container RUNS Image AFFECTED_BY Vulnerability
  WHERE Image.imageId = '<image_id>' 
  AND Vulnerability.severity IN ['Critical', 'High'] 
  AND Vulnerability.inUse = true 
  AND Vulnerability.hasFix = true 
  AND KubeWorkload.isExposed = true
  RETURN DISTINCT Image, count(DISTINCT KubeWorkload), count(DISTINCT Vulnerability);
```

- for all other metrics:

```
MATCH KubeWorkload HAS Container RUNS Image AFFECTED_BY Vulnerability
  WHERE Image.imageId = '<image_id>' 
  AND Vulnerability.severity IN ['Critical', 'High']
  RETURN DISTINCT Image.imageReference, 
  count(DISTINCT KubeWorkload) AS workloads_count, 
  KubeWorkload.isExposed, 
  RETURN DISTINCT Image, count(DISTINCT KubeWorkload), count(DISTINCT Vulnerability);
  ```

When more than one image is selected, present a
plan table for explicit user approval before proceeding:

```
## Remediation Plan — <environment>

| # | Image | Workloads Count | Workload Exposed | Fixables | Critical (total) | High (total) |
|---|-------|-------|-----------|---------|-----|-----|
| 1 | quay.io/org/app:1.2 | 12 | Yes | 23 | 3 | 20 |
| 2 | quay.io/org/svc:2.0 | 3  | No  | 12 | 1 | 11 |

Total: 2 images selected.
```
If the users is doing a free investigation, ask him to create a plan with the selected filters (zone + metric). Use the `create_plan` tool and ask the user all needed parameters.
Once done:
Ask: _"Which one do you want to fix?"_

Wait for explicit approval. The user can say "skip #2", "only exposed ones", etc.

### 5b. Optional ticketing

Refer to [ticketing](references/ticketing.md) for supported systems and required configuration.

#### Detect available ticketing systems

Check whether any of these are reachable via MCP or CLI:

- **Jira** — `jira-mcp-server` MCP tools (`jira_search_issues`, `jira_create_issue`, `jira_update_issue`) or `jira` CLI.
- **Linear** — `linear` MCP tools or `linear` CLI.
- **GitHub Projects** — `github` MCP tools (`add_project_item`) or `gh project` CLI.

Record the detected system as `ticketing_system` in state. If none are found, set `ticketing_system: null`.

#### Ask whether to create tickets

Ask the user:

> _"Do you want to create tracking tickets for any of these images? (yes / no / pick which)"_

**Ticketing is fully optional.** If the user says no — or no ticketing system was detected and the user does not want to configure one — skip the rest of this step entirely and go to step 6 with no `ticket_key`.

If a ticketing system is available but the user wants to use a different one, ask them to configure it; if they decline, proceed without ticketing.

If the user wants to use a system that is detected but missing credentials (token, project, user, etc.), ask for the missing configuration before proceeding.

#### For each image where the user wants a ticket

##### a. Search for existing tickets

Before creating a new ticket, search the configured system for existing tickets that reference the same image:

- Search by image name in ticket summaries (e.g. `summary ~ "<image-name>"`).
- Also search the image reference in ticket descriptions.

If existing tickets are found:

- If any are still **open**, propose **updating** the existing ticket instead of creating a duplicate. Show the ticket summary and ask the user to confirm.
- Extract the assignee from the most recent ticket for this image and record it as `previous_ticket_assignee` for use in the assignee priority chain below.

##### b. Determine assignee (Sysdig-side signals only)

Use the first signal that yields a result. **Do not use git log / file authors here** — those are PR reviewers and live in `/sysdig-remediate`.

1. **`workload_owner`** — owner annotation/label on the running workload. Query via SysQL, e.g.:
   ```
   MATCH KubeWorkload HAS Container RUNS Image
     WHERE Image.imageReference CONTAINS '<image_name>'
     RETURN DISTINCT KubeWorkload.labels, KubeWorkload.annotations;
   ```
   Inspect labels/annotations like `owner`, `team`, `app.kubernetes.io/owner`.
2. **`zone_owner`** — if the selected zone defines an owner, use it.
3. **`previous_ticket_assignee`** — from `ticket_assignees` state for this image, or from a prior open ticket discovered in step 5b.a.
4. Leave unassigned.

Present the proposed assignee with its source, e.g.:

- _"Suggesting @platform-team as assignee — workload has label `team: platform-team`."_
- _"Suggesting @jane.doe — they were assigned to the previous ticket (PROJ-100) for this image."_

Always confirm with the user before setting the assignee. Record the choice and its source in `ticket_assignees`.

##### c. Create or update the ticket

Show the draft to the user before any write operation.

**Summary:** `[Sysdig] Fix Critical/High vulnerabilities in <image_reference>`

**Description (Jira / Markdown — adapt syntax for Linear / GitHub Projects):**
```
h2. Vulnerability Report

This ticket was created by the Sysdig investigate skill after scanning
the *<environment>* environment on <date>.

h2. Vulnerable Image

||Property||Value||
|Image|{noformat}<image_reference>{noformat}|
|Base OS|<base_os>|
|Environments|<comma-separated list>|
|Affected workloads|<workloads_count> (<workloads_internet_exposed_count> internet-exposed)|

h2. Critical & High CVEs

||CVE||Severity||Package||Installed||Fix Version||CVSS||Exploitable||
|<cve_id>|<severity>|<package>|<installed_version>|<fix_version or "none available">|<cvss>|<yes/no>|
(repeat for each CVE)

h2. Impact Assessment

<actually_exploitable_explanation>

*Network exposure:* <network_mitigated_explanation>
*Acceptable risk:* <has_acceptable_findings_explanation>

h2. Recommended Actions

For each CVE, describe what needs to happen:
- *<CVE-ID>* (<severity>): Update <package> from <installed_version> to a safe target version.
- *<CVE-ID>* (<severity>): No fix available — monitor for upstream patch.

h2. Next Step

Run `/sysdig-remediate <image_reference> (image_id: <image_id>, ticket: <THIS_TICKET_KEY>)`
to attempt a code fix; this ticket will be updated automatically with the PR link
on completion.

h2. References

- Sysdig investigation global_id: {noformat}<global_id>{noformat}
- Detection date: <date>
```

**Priority:**
- `severity_normalized >= 0.9` → Critical
- `severity_normalized >= 0.7` → High
- otherwise → Medium

**Updating an existing ticket** (when step 5b.a found one): never remove or modify the existing description. Append below a separator and a new section:

```
----

h2. Update — <date>

_Added by Sysdig investigate skill._

h3. New/Updated CVEs
... (only include changes since the last update)

h3. Recommended Actions
- <updated action items>
```

After the create or update operation, record the result in state:

- Append/upsert into `tickets` (matched by `ticket_key`).
- Append into `ticket_history` (always append).
- Attach `ticket_key` to that image's `plan` entry so step 6 can pass it to `/sysdig-remediate`.

### 6. Hand off to `/sysdig-remediate`

For each approved image (in order), invoke `/sysdig-remediate` passing the image reference,
`image_id`, and the optional `ticket_key` if a ticket was created or matched in step 5b:

```
/sysdig-remediate <image_reference> (image_id: <image_id>)
/sysdig-remediate <image_reference> (image_id: <image_id>, ticket: <ticket_key>)
```

The `ticket` argument is optional. When present, `/sysdig-remediate` will update that ticket with the PR link on completion. When absent, `/sysdig-remediate` opens the PR without touching any ticketing system.

#### Branching paths

After step 5b, the user is on one of these paths:

- **investigate → ticket → stop** — ticket created, someone else will pick it up later and run `/sysdig-remediate <image> (..., ticket: <key>)`.
- **investigate → ticket → remediate** — ticket created, immediately hand off; remediate updates the ticket on PR open.
- **investigate → remediate (no ticket)** — user skipped ticketing entirely; remediate opens the PR with no ticket update.
- **investigate (no ticket) → stop** — user reviewed the plan and chose not to act now.

After each image completes, update its plan entry `status` to `remediated` (or `skipped`
if the user chose to skip it), then ask whether to continue with the next image.

### 7. Save state

Call the MCP tool `save_skill_state` with `{ "skill_state": "investigate", "version": <n>, "data": { ... } }`. Refer to the [State](#state) section above for the full schema. Persist in `data`:

- `last_run`, `environment`, `focus`, `images_found`, `images_planned`, `images_remediated`, `plan`
- `ticketing_system` (or `null` if the user skipped ticketing)
- `ticket_assignees`, `tickets`, `ticket_history` (only if any ticket activity happened)

> **Version on write**: pass the same `version` value returned by the `get_skill_state` call at the start of the session — or `0` if the call returned `null` (no prior state). The server bumps the version itself. See [Read/write rules](#readwrite-rules). Do not include `version` inside `data`.

Save state even if the session ended before remediation started — the plan entries with
`status: "pending"` allow the user to resume from where they left off.

On a 409 conflict, call `get_skill_state` again, merge the plan entries (upsert by `global_id`) into the freshly-read state, and retry once with the new `version`.

## Important rules

- Always read state at the start (via script) and write state at the end — even for short sessions.
- Keep the conversation focused: one environment per session.
- Do not perform fix analysis or open PRs here — that is the job of `/sysdig-remediate`.
- Always sort the image table: internet-exposed first, then by severity score descending.
- When the user says "all", still present the plan table and ask for explicit confirmation
  before handing off to `/sysdig-remediate`.
- Never invoke `/sysdig-remediate` on an image without the user's explicit approval.
- **Ticketing is always optional** — proceed without a ticket whenever the user declines or no ticketing system is configured.
- For ticket assignees, use **Sysdig-side signals only** (`workload_owner`, `zone_owner`, `previous_ticket_assignee`). Never use git log / file authors here — those belong to PR review in `/sysdig-remediate`.
- Always search for an existing open ticket before creating a new one. Prefer updating over duplicating.
- When updating an existing ticket, never remove or modify the original description — append below a `----` separator.
- Never set an assignee without confirming with the user first.

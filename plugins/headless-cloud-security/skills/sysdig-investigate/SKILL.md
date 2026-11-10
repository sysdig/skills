---
name: sysdig-investigate
description: >
  Investigate and prioritize vulnerable images in a Sysdig-monitored environment via two
  flows, routed from the user's goal. Plans flow — plan-driven prioritization: pick an
  admin-configured Plan (or explore ranked jobs under an ad-hoc scope and measure) and
  walk the prioritized remediation jobs one at a time. Findings flow — ad-hoc findings
  analysis: filter, regroup, sort, and page vulnerability findings the way the
  Vulnerability Management UI table does. Hands any chosen image off to /sysdig-remediate,
  which owns tickets, PRs, job tracking, and job closing.
  Triggers on: "investigate", "what should I fix", "what should I fix first", "show me my
  vulnerable images", "prioritize vulnerabilities", "which images are affected by
  CVE-...", "show me all Critical CVEs in production", "/sysdig-investigate".
  Not for opening PRs, applying fixes, or creating/updating tickets — use
  /sysdig-remediate for all of those.
allowed-tools:
  - AskUserQuestion
  - Read
  - Write
  - mcp__secure-mcp-server__get_customer_settings
  - mcp__secure-mcp-server__get_skill_state
  - mcp__secure-mcp-server__save_skill_state
  - mcp__secure-mcp-server__delete_skill_state
  - mcp__secure-mcp-server__list_plans
  - mcp__secure-mcp-server__list_plan_remediation_jobs
  - mcp__secure-mcp-server__get_plan_target_measure
  - mcp__secure-mcp-server__list_plan_categories
  - mcp__secure-mcp-server__list_plan_category_measures
  - mcp__secure-mcp-server__list_zones
  - mcp__secure-mcp-server__query_vulnerability_findings
  - mcp__secure-mcp-server__explore_jobs
  - mcp__secure-mcp-server__get_job_impact
  - mcp__secure-mcp-server__list_artifacts
  - mcp__secure-mcp-server__list_plan_activities
  - mcp__secure-mcp-server__create_artifact
  - mcp__secure-mcp-server__list_scope_labels
  - mcp__secure-mcp-server__list_scope_label_values
  - mcp__secure-mcp-server__run_sysql
  - mcp__secure-mcp-server__get_plan_report_options
  - mcp__secure-mcp-server__get_plan_report_data
  - mcp__secure-mcp-server__save_plan_report
  - mcp__secure-mcp-server__get_brand_kit
  - mcp__secure-mcp-server__get_design_tokens
version: 1.0.3
---

## First-run notice

Before doing any other work for this skill, follow [`references/first-run-notice.md`](references/first-run-notice.md) exactly.


This skill describes steps by capability, not by tool name: *ask a structured question*, *get explicit confirmation*, *write a file*, *run a command*. Follow [`references/agent-capabilities.md`](references/agent-capabilities.md) for how to do each one with your agent's tools, and what to do when a capability is missing — including when nobody can answer a question.

## On-brand output

Plan reports → generate a branded PDF via the plan report flow (`get_plan_report_options` → `get_plan_report_data` → `save_plan_report`); the server renders it on-brand, stores it as a plan artifact, and returns a download link (see step 2f — wrap up the Plans session; this is **Path C** in the reference). This skill's other outputs are chat tables and handoffs — not presentation documents.

If you're ever asked to produce a *custom* report or document, follow [`references/on-brand-output.md`](references/on-brand-output.md) within what this skill can actually call: it carries the brand kit (`get_brand_kit` / `get_design_tokens`) for content you render yourself (**Path B**), but not the governed author → validate → render tools — for a PDF outside a Plan, hand off to the `sysdig-report` skill if it's installed. Opt-in guidance — never a requirement to make a report.

This skill **investigates and prioritizes — it never remediates**. It has two flows, chosen in step 1 from the user's goal:

**Plans flow — plan-driven prioritization.** Work through ranked remediation jobs, either from an existing admin-configured Plan or from a free investigation (`explore_jobs` under a custom scope and measure). Jobs are walked one at a time; each job's outcome is a handoff to `/sysdig-remediate`, a skip, or stopping the session.

**Findings flow — ad-hoc findings analysis.** Mirrors the Vulnerability Management UI table: an iterative filter / regroup / sort / page loop over `query_vulnerability_findings`. Use it when the user has a slicing question ("show me all Critical CVEs with a fix in production") rather than a backlog to work through.

**Boundaries.** This skill never creates or updates tickets, never opens PRs, never calls `track_job`, and never calls `close_job`. All deliverables — the ticket, the PR, job tracking at the commit point, and closing the job once work is filed — live in `/sysdig-remediate`. The goal of a session here is a prioritized understanding and clean handoffs, not deliverables.

> **To act on an image, hand off to `/sysdig-remediate`.** It asks whether the user wants
> a ticket, a PR, or both; deduplicates existing work (artifacts, Sysdig-created tickets,
> external tickets and PRs); resolves safe fix versions; and closes the job once the work
> is filed.

## Conversation rules

- **Narrate high-level actions, not individual tool calls.** Say what you are doing at a meaningful level ("loading plan details", "querying findings grouped by image") — do not announce every tool call by name, and do not ask permission for obvious next steps in the flow. Silent tool calls with no user-facing context are not acceptable; narrating every micro-step is also not acceptable.
- **Announce every skill handoff.** Before invoking another skill, name it explicitly and summarize what it'll do, then wait for confirmation.
- **Internal identifiers stay internal.** Never surface configuration keys (like the customer-settings flag read in step 0a), raw `target_measure` ids, or `global_id`s in user-facing messages — translate them into plain language ("plan-driven prioritization isn't enabled for this tenant", the measure's display name, the image reference).
- **Plans free path only — always discover measures and scopes live, never read them from skill text.** These rules apply on the free investigation path (`explore_jobs`). On the Plan path, scope and measure are already defined by the plan — skip discovery entirely. When any question about available measures, categories, scopes, zones, or label values arises on the free path, call the relevant tools (`list_plan_categories`, `list_plan_category_measures`, `list_zones`, `list_scope_labels`, `list_scope_label_values`) to get the current data. The static lists in this skill are last-resort fallbacks only.
- **Plans free path only — propose, don't list.** Use the conversation context to infer what the user cares about (environment, team priorities, risk posture, urgency) and suggest the single most fitting measure and scope with a one-line rationale. Let the user confirm or redirect — don't present a neutral menu and wait.
- **Plans free path only — zone-first for scope.** If the customer has zones configured, always propose a zone as the primary scope. Zones are the semantically meaningful groupings in Sysdig (e.g. production, staging) and give the most actionable signal. Offer label-based narrowing (namespace, cluster, workload) as a follow-up refinement, not the primary choice. If no zones are configured, fall through to label-based scoping.
- **Findings flow only — one slice at a time.** After each result table, propose the single most useful next move (narrow, pivot the grouping, re-sort, page, or hand an image off) based on what the data actually shows — don't enumerate every possible refinement each turn.

## State

Read state via `get_skill_state`, write via `save_skill_state`. Schema and rules: see [references/state.md](references/state.md). Treat null as { "version": 0 }.

## Steps

### 0. Trust preamble

**Always present this before asking any questions.** See [references/trust-preamble.md](references/trust-preamble.md) for the full text. After presenting the preamble, proceed directly to step 0a — do not ask for confirmation.

### 0a. Prerequisites

**MCP authentication preflight.** Before any other step, run the preflight in [`references/auth-preflight.md`](references/auth-preflight.md) and follow its instructions exactly. If it tells you to abort, abort — do not call any MCP tools or perform other side effects.

If a tool call later fails during normal operation, use the diagnostic checklist in [`references/mcp-setup.md`](references/mcp-setup.md) to identify the specific failure.

Do not proceed until the MCP server is reachable.

Once the preflight passes, call `get_customer_settings` and note the `sage.next.enabled` flag — step 1 uses it: the Plans flow requires it; the Findings flow does not. Note it silently — do not mention the flag name or the settings payload to the user.

### 1. Goal routing

Classify the user's goal from what they've said so far, announce the route in one line, and proceed. Ask only when genuinely ambiguous.

| Signal | Route |
|---|---|
| Backlog / plan / prioritization language: "what should I fix first", "work through the backlog", "prioritize", mentions of Plans, jobs, SLA, remediation campaigns | **Plans flow** (step 2) |
| Ad-hoc slicing language: "show me all …", "which images are affected by CVE-…", "filter by …", "group by …", questions about a specific CVE, package, namespace, or cloud account | **Findings flow** (step 3) |
| Bare `/sysdig-investigate` or "investigate" with no other signal | Genuinely ambiguous — ask |

**Announce, don't interrogate.** When the signal is clear, state the route and keep moving, e.g.:

> _"This sounds like plan-driven prioritization — I'll start from your remediation Plans. (Say 'ad-hoc' if you'd rather slice the findings directly.)"_

or

> _"This is an ad-hoc findings question — I'll query the findings directly. (Say 'plans' if you'd rather work through your remediation backlog.)"_

**When genuinely ambiguous**, ask one structured question with exactly two options: work through the prioritized remediation backlog (Plans) vs. explore/slice the findings data (Findings).

**Gate on `sage.next.enabled`:** if the Plans flow is chosen but the flag is false, tell the user plan-driven prioritization isn't enabled for this tenant and continue with the Findings flow instead. Never name the flag itself in the conversation — it's an internal setting key; the plain-language message is the user-facing form.

### 2. Plans flow

#### 2a. Pick an existing plan or start fresh

Call `list_plans` to check if there are existing plans. Present them as a short table — plan name, zones, and the measure's **display name** with its one-line explainer — and ask whether they'd like to work on one, or "none of these — start a free investigation." Resolve measure display names via `list_plan_categories` + `list_plan_category_measures` (one pass covers every plan in the table); never show raw `target_measure` ids like `exposure_time_weighted` in the table.

- If the user picks an existing plan → present the plan overview (step 2b), then jump to step 2d.
- If the user picks "none" (or no plans exist) → free investigation: proceed to step 2c.

#### 2b. Plan overview (Plan path only)

Present the plan overview in this structure before showing the jobs table. Build it from live tool calls:

**1 — Hero.** Plan title, measure display name and one-line explainer (from `list_plan_category_measures` for the plan's `target_measure`), owner if present. Never show the raw `target_measure` id — only the human-readable display name.

**2 — What this measures.** A concise explanation of what the measure means and why it matters, derived from `list_plan_category_measures`. Do not read this from skill text.

**3 — Scope.** Zones covered by the plan, from the plan data.

**4 — Current state.** Current measure value and trend from `get_plan_target_measure`. Format: _"Current value: X — as of `<date>`."_ Include trend direction if available: _"down −Y vs `<prev_date>` — good for this measure."_

**5 — Past session context.** Call both in parallel:
- `list_artifacts(parent_kind: "plan", parent_id: <plan_id>)` — work products and session notes attached to the plan and its jobs
- `list_plan_activities(plan_id: <plan_id>)` — the audit event timeline: when jobs changed state, when artifacts were attached, when jobs were added to the plan

Synthesize into a brief summary before the jobs table. Examples:
- _"From a previous session (2026-06-05): 2 jobs handed to `/sysdig-remediate`, tickets PROJ-12 and PROJ-13 filed."_ (from note artifacts + `artifact_attached` events)
- _"Job `quay.io/org/svc:2.0` was closed on 2026-06-04."_ (from `job_state_changed` events — skip it in the jobs table)

Skip silently if no artifacts or activities exist.

**6 — Top job** (present this block only after the step 2d fetch — it needs the ranked jobs). _"The riskiest jobs have already been ranked by impact. Right now the top job is `<image>`, which `<ranking_summary>`."_

#### 2c. Free path — discover scope and measure

**Scope.** Refer to [zones](references/zones.md) to fetch the user's available zones.

- If zones are configured: propose the most relevant zone based on the conversation context (e.g. if the user mentioned "prod" or "production", suggest the matching zone). Always include "Entire Infrastructure" (no zone filter) as an alternative. Pass the zone ID — never the zone name — to downstream tools.
- If no zones are configured: fall through to label-based scoping — call `list_scope_labels` to discover available dimensions (namespace, cluster, workload, etc.) and `list_scope_label_values` to enumerate valid values. Propose the narrowest scope that matches what the user described.
- In either case, offer label-based rules as additional narrowing on top of the zone if the user wants to focus further (e.g. a specific namespace within production).

**Measure.** Call `list_plan_categories` to discover the categories supported by this tenant. For each category, call `list_plan_category_measures` to get its compatible `target_measure` values. **Do not present the full list and ask the user to pick.** Read the conversation context and propose the single most fitting measure with a one-line rationale — by its **display name** and explainer from `list_plan_category_measures`. The backticked ids below are the `target_measure` values you pass to tools, never the words you show the user. Examples:

- "what can we fix today" or "exploitable" → propose `fixable_exposed_findings`
- "we've had these vulnerabilities for months" or "exposure" → propose `exposure_time_weighted`
- "SLA" or "compliance deadline" → propose `sla_compliance`
- No strong signal → propose `findings` as a broad starting point and explain why

Confirm with the user before proceeding. If they redirect, adjust without re-presenting the full list unless they ask for it.

**Static fallback** (only if `list_plan_categories` and `list_plan_category_measures` both fail — present the plain-language descriptions below, not the ids):
- `findings` — total distinct CVE+package findings
- `exposure_time_weighted` — age-weighted sum; older findings weigh more
- `exposure_time_avg` — average age of Critical+High findings
- `sla_compliance` — urgency based on oldest-bucket age vs. SLA threshold
- `fixable_exposed_findings` — in-use, network-reachable, AND has a fix available

Map the confirmed choice to the `target_measure` parameter.

#### 2d. Fetch and present the ranked jobs

**Plan path:** `list_plan_remediation_jobs` takes a single `state` (not a list), so call it twice — in parallel — for the two states worth showing:
- `list_plan_remediation_jobs(plan_id: <plan_id>, state: "open", limit: 10)`
- `list_plan_remediation_jobs(plan_id: <plan_id>, state: "in_progress", limit: 10)`

Never request the other three states: `closed` and `archived` jobs are finished work, and a `skipped` job is one the user has already declined.

Each call returns its own rows already ranked by the plan's measure, but the two rankings are independent and there is no cross-call ordering key to merge them on — **so do not interleave or re-sort them.** Present the `open` rows first, in the order that call returned them, then the `in_progress` rows as a second group under the same header, labelled _"already in progress"_. If the same `global_id` comes back in both (it changed state between the two calls), keep it in the `in_progress` group only.

The top job is therefore the first `open` row. If there are no `open` rows at all, use the first `in_progress` row instead and say that it is already underway.

If both calls come back empty the plan has nothing to walk: _"`<plan title>` has no open or in-progress jobs — everything in its scope is remediated, closed, or skipped."_ Offer the Free path (step 2c) for a different scope or measure, and stop. Do not enter step 2e.

**Free path:** call `explore_jobs` with:
- `target_measure`: the confirmed measure from step 2c
- Scope: build from the confirmed scope in step 2c.
  - **For zone-based scoping use the top-level `zone_ids: number[]` convenience field** — the server resolves these to ZoneFilters internally. Do NOT place raw zone IDs inside `scope.zones`, which expects structured `ZoneFilter` objects (`[{ ref_id, snapshot_rules }]`) and 422s on integers.
  - For label-based narrowing, use `scope.raw` rules (`{ operator, rules: [{ key, op, value }] }`); can be layered on top of `zone_ids`.
  - Never hard-code scope values — always use IDs and label values discovered via the live tools.
- `states`: `["open", "in_progress"]`
- `limit`: `10`

If the result is empty, tell the user there are no matching vulnerabilities in that environment and stop.

Each `explore_jobs` row carries a `tracked: bool` field:
- `tracked: true` — a persisted Job already in the catalog (Plan-path jobs are always tracked).
- `tracked: false` — a virtual candidate computed on-the-fly. **Do not promote it** — `track_job` belongs to `/sysdig-remediate`, which calls it only at its commit point (when the user confirms a deliverable).

Present the results as a ranked table, **preserving the tool's row order** — the rows are already ranked by the measure; re-sorting would change which job is "the top one". On the Plan path that means the two `state` groups from above, each kept in its own returned order:

| # | Image | Tracked | Ranking Summary | Finding Percentage | Finding Count | Resource Count |
|---|-------|---------|--------|--------------------|---------------|----------------|
| 1 | quay.io/org/app:1.2 | Yes | 9 fixable+exposed findings | 30% | 17 | 23 |
| 2 | quay.io/org/svc:2.0 | No  | 16 fixable+exposed findings | 12% | 43 | 44 |

After the table, tell the user how much they're seeing. If the API response includes a total count, print _"Showing top 10 of N — say 'more' to expand or describe a filter."_; otherwise print _"Showing the top 10. Say 'more' to fetch additional results or 'filter' to narrow."_ When the user says "more", re-call with a higher `limit` — on the Plan path that is both `state` calls, not just one.

_"The riskiest jobs have already been ranked by impact. Let's start with the top one."_ Then proceed to step 2e for the top-ranked job. The user can say "skip this one" or "start with #3" to redirect.

#### 2e. Walk the jobs one at a time

For the current job:

1. **Read its artifacts first** (tracked jobs only): `list_artifacts(parent_kind: "job", parent_id: <job_global_id>)`. Surface what exists — _"This job already has a ticket: `<reference_key>` (`<reference_url>`)"_, _"A PR was opened previously: `<reference_url>`"_, _"Previous session note: `<content>`"_. Existing work does not block the handoff — `/sysdig-remediate` runs its own dedup and will adopt or update it. Untracked candidates have no artifacts by definition (no catalog row) — skip this call.
2. **Show impact** (tracked jobs only): call `get_job_impact`. It requires **both** `job_id` and `target_measure` — passing the job id alone is rejected. Pass:
   - `job_id`: the job's catalog `global_id`
   - `target_measure`: on the Plan path, the plan's own measure (the one presented in step 2b); on the Free path, the measure confirmed in step 2c. The job's impact is only meaningful relative to the measure it is being ranked by.
   - `zone_ids`: the zone IDs of the scope this session is working in — the plan's scope zones on the Plan path (the ones presented in step 2b), the confirmed zone on the Free path. For label-based scoping pass `scope.raw` rules instead. If the scope carries no zone IDs, omit both and tell the user the impact numbers are customer-wide, not scoped.

   Untracked candidates from `explore_jobs` have no catalog row and 404 here — skip the call for them and summarize from the `explore_jobs` row you already have. If the response carries `found_in_scope: false`, the job has no findings under this scope: say that rather than presenting its zeroed counts.

   Present a concise summary — what the job's findings are, workload spread, exposure — at the level a decision needs, not a data dump.
3. **Offer exactly three options** (structured question): **Remediate** (hand off to `/sysdig-remediate`), **Skip** (move on, recording why), or **Stop** (wrap up the session).

**Remediate.** Announce the handoff and confirm:

> _"Handing off to `/sysdig-remediate` for `<image_reference>` — it will ask whether you want a ticket, a PR, or both, dedup existing work, and close the job when the work is filed. Continue?"_

Invoke it as:
```
/sysdig-remediate <image_reference> (image_id: <image_id>, job_id: <job_global_id>)
```
Pass `job_id` only for tracked jobs (the catalog `global_id`). For untracked candidates omit it — `/sysdig-remediate` re-discovers the candidate itself:
```
/sysdig-remediate <image_reference> (image_id: <image_id>)
```
When `/sysdig-remediate` hands back, record the outcome in the session tally (state `plan` entry → `handed_off`) and move to the next job. Do not attach artifacts for work `/sysdig-remediate` did — it records its own.

**Skip.** Ask for a one-line reason (or infer it from what the user said). If the job is `tracked: true`, record it server-side:
```
create_artifact(
  parent_kind: "job",
  parent_id: <job_global_id>,
  artifact_type: "note",
  content: "Skipped in investigate session on <date>: <reason>."
)
```
If the job is untracked, record the skip in skill state only — **never call `track_job` just to attach a note** (tracking writes a permanent catalog row; that decision belongs to `/sysdig-remediate`'s commit point). Job states other than `closed` cannot be set via MCP, so a skip is always expressed as an artifact or a state entry, never a state change.

**Stop.** Go to step 2f.

**Transition:** if there are remaining open/in-progress jobs, say _"Let's now focus on the next top priority job: `<image_reference>`, which `<ranking_summary>`."_ and repeat step 2e. Do not re-present the full table unless the user asks.

**Queue empty:**

> _"You've worked through all the prioritized jobs in this session. `<N>` handed off to `/sysdig-remediate` (`<images>`), `<M>` skipped. The plan's measure will continue to update as fixes land and the next scan runs."_

Then go to step 2f.

#### 2f. Wrap up the Plans session

1. **Plan path only** — attach a session report to the plan:
   ```
   create_artifact(
     parent_kind: "plan",
     parent_id: <plan_global_id>,
     artifact_type: "note",
     content: "Investigate session on <date>: <N> of <M> jobs handed to /sysdig-remediate (<images>). Skipped: <images+reasons or 'none'>."
   )
   ```
   On the free path there is no plan to attach to — give the same summary in chat instead.
2. **Optional — branded plan report (Plan path).** If the user wants a shareable, on-brand PDF of the plan (beyond the note above), generate one through the report engine rather than hand-writing it.

   **Check first, offer second.** Scan the visible tool names for one ending in `get_plan_report_options` — don't call anything. If it isn't there, this region doesn't serve plan reports yet: skip this step silently, leave the note from step 1 as the session record, and don't mention a PDF you can't produce. Only offer the report when the tool is visible:
   - `get_plan_report_options(plan_id)` — discover the presets, components, and time ranges for this plan.
   - `get_plan_report_data(plan_id, preset=…, time_range=…)` — build it from plan data; show the returned **outline** (block titles / types) to confirm scope before saving.
   - `save_plan_report(plan_id, preset=…, time_range=…, summary=…)` — the server validates, renders the branded PDF, and stores it as a report artifact. On-brand by construction — never hand-write report styling. Check the result before you announce anything:
     - `saved: true` → give the user the returned `download_path`. If it's `null`, fall back to `source_path`; if both are null, say the report was stored but no download link came back — never print `null` at the user.
     - `saved: false` → a normal result, not an error: it carries `validation_errors` (JSON-Pointer paths) and a `hint`. Say the report didn't validate, fix those paths, and retry. Don't claim a report was saved.
     - A **permission** failure on this step is possible even though steps 1–2 worked: saving writes an artifact to the plan, so it needs plan write access where the first two only read. Tell the user they can't store a report on this plan and offer the outline from `get_plan_report_data` instead — don't retry.

   This is **Path C** in [`references/on-brand-output.md`](references/on-brand-output.md) — the one path that persists the report (Path A's `render_report` returns a PDF and stores nothing).
3. Save state (step 4).

### 3. Findings flow

Mirror the Vulnerability Management UI table: an iterative slice-and-dice loop. Each turn: translate the user's question into one `query_vulnerability_findings` call, present the rows, then propose the single most useful next move.

**Pick the starting `group_by` from the question's subject:**

| The user asks about… | `group_by` |
|---|---|
| images ("most vulnerable images", "images running X") | `image` |
| a CVE or CVE properties ("who's affected by CVE-2024-1234", "exploitable CVEs") | `cve` |
| cloud resources / accounts / regions | `resource` |
| packages / components ("where is log4j") | `component` |
| raw finding rows (image × CVE pairs) | `none` |

**Build filters** as structured `{field, op, value}` objects. Common fields (the full ~55-field list per grouping lives in the tool's own validation — an invalid field returns an error message listing the valid ones for that `group_by`; surface it and correct):

- Severity & risk: `severity`, `cvssScore`, `epssScore`, `epssPercentile`
- Fixability & exploit: `hasFix`, `hasExploit`, `hasException`, `knownRansomwareCampaignUse`, `cisaKevDueDate`
- Runtime context: `inUse` (the vulnerable package is actually loaded at runtime — not merely installed)
- Identity: `cveId`, `component` fields, image fields, `namespace`, `cluster`, `node`, `accountId`, `region`, `cloudProvider`, `zoneId`
- Dates: `publicationDate`, `fixDate`

Example — "show me all Critical CVEs with a fix, in use, in production":

```jsonc
{
  "group_by": "cve",
  "filters": [
    { "field": "severity", "op": "eq", "value": "critical" },
    { "field": "hasFix", "op": "eq", "value": true },
    { "field": "inUse", "op": "eq", "value": true },
    { "field": "zoneId", "op": "in", "value": [<production zone id>] }
  ],
  "sort": { "field": "cvssScore", "direction": "desc" },
  "limit": 50
}
```

Resolve zone names to IDs via [zones](references/zones.md) — never pass names.

**Present rows at UI-table granularity** — a markdown table with the columns the grouping returns. After the table, report scale honestly. When `meta.total` is present: _"Showing the first 50 of `<total>` — say 'more' to page, or narrow the filter."_ Otherwise use `meta.hasMore`: _"Showing the first 50 — there are more; say 'more' to page, or narrow the filter."_ when true; _"That's all `<meta.count>` matching rows."_ when false.

**Iterate.** Propose the next move from what the data shows: **narrow** (add a filter), **pivot** (same filters, different `group_by` — e.g. from a CVE list to the images affected by one of them), **re-sort** (single field + direction only — the backend does not support multi-column sort), or **page** (pass `cursor.next` back as `cursor`, keeping every other parameter — including `sort` — identical, or the keyset cursor breaks).

**Do not mass-export.** Rows are UI-table summary data with a hard `limit ≤ 200` per call. Never loop the cursor to dump the full result set, and decline requests to export "everything" — point the user to Sysdig Reporting for bulk extracts.

**SysQL escape hatch — out-of-API questions only.** When the question needs relationships the findings API doesn't model (workload ownership labels, network exposure paths, cluster topology), use `run_sysql`, e.g.:

```
MATCH KubeWorkload HAS Container RUNS Image
  WHERE Image.imageReference CONTAINS '<image_name>'
  RETURN DISTINCT KubeWorkload.labels, KubeWorkload.annotations;
```

Never use SysQL for what `query_vulnerability_findings` can answer — the findings API is the UI-consistent source for findings data.

**Handoff.** Whenever the user wants to act on an image surfaced by any slice, use the same handoff as the Plans flow:

> _"Handing off to `/sysdig-remediate` for `<image_reference>` — it will ask whether you want a ticket, a PR, or both, dedup existing work, and close the job when the work is filed. Continue?"_

```
/sysdig-remediate <image_reference> (image_id: <image_id>)
```

(`image_id` when the rows carry it — by-image rows nest it as `image.id` and the reference as `image.ref`; Findings-flow slices have no `job_id`.) When it hands back, continue slicing or wrap up.

**Wrap up:** summarize the session's slices and handoffs in chat, then save state (step 4).

### 4. Save state

Call the MCP tool `save_skill_state` with `{ "skill_state": "investigate", "version": <n>, "data": { ... } }`. Refer to [references/state.md](references/state.md) for the full schema. Persist in `data`: `last_run`, `flow`, `environment`, `focus`, `images_found`, and the per-image `plan` entries — surfaced-but-undecided jobs as `pending`, decided ones as `handed_off` / `skipped`. The `pending` entries are what makes resume work.

> **Version on write**: pass the same `version` value returned by the `get_skill_state` call at the start of the session — or `0` if the call returned `null` (no prior state). The server bumps the version itself. Do not include `version` inside `data`.

Save state even if the session ended early — `plan` entries with `status: "pending"` let the user resume where they left off.

On a 409 conflict, call `get_skill_state` again, merge the plan entries (upsert by `global_id` when present, else by `image_reference` — Findings-flow entries have no `global_id`) into the freshly-read state, and retry once with the new `version`.

## Error handling

Every failure surfaced to the user follows the same **what / why / fix** shape:

1. **What** — the specific operation that failed.
2. **Why** — the underlying cause in concrete terms.
3. **Fix** — the exact next action or command, copy-pasteable.

Apply this template to:

- **`query_vulnerability_findings` validation errors** — the tool's error message lists the valid fields/ops for the chosen `group_by`. Show the relevant part to the user, correct the call, and retry once. Never silently retry the same invalid call.
- **`explore_jobs` errors** beyond the "empty result" case (4xx/5xx, scope mismatch, missing zone access).
- **SysQL failures** in the Findings-flow escape hatch (malformed query, MCP timeout).
- **`save_skill_state` conflicts** — after one merge-and-retry attempt fails, surface the conflict with what/why/fix instead of silently retrying.
- **A denied MCP tool call** — the agent refuses a Sysdig MCP call rather than the server returning an error. This is a permissions issue, not unreachability: the agent's settings don't pre-approve that tool. Point the user to the "Tool calls come back denied" fix in [`references/mcp-setup.md`](references/mcp-setup.md) instead of retrying.

## Important rules

- Always read state at the start and write state at the end — even for short sessions.
- Keep the conversation focused: one environment per session.
- **This skill produces no deliverables.** Never create or update tickets, never open PRs, never apply fixes — `/sysdig-remediate` owns all of it.
- **Never call `track_job` or `close_job`.** Tracking happens at `/sysdig-remediate`'s commit point; closing happens there when work is filed. This skill doesn't have these tools and must not work around that.
- Never invoke `/sysdig-remediate` on an image without the user's explicit approval.
- Never re-order ranked-jobs tables — the server ranking (by measure) is the priority order; present rows as returned. On the Plan path, the `open` and `in_progress` calls are two separate rankings: keep each group in its own returned order and never merge them into one sorted list.
- **Respect the user's "no".** When the user skips an image, mark the matching `plan` entry `skipped` and never re-suggest it within the session.
- **Artifacts are the primary source of truth.** When `skill_state` and job/plan artifacts conflict, trust the artifacts — they are server-side, survive across agents and sessions, and reflect what actually happened. Update `skill_state` to match, never the reverse.
- **Always read before acting.** Call `list_artifacts` for a plan at session start and for each tracked job before offering options on it.
- **Findings flow: never mass-export.** `limit ≤ 200` per call, no cursor-draining loops, no bulk raw dumps. Point bulk needs to Sysdig Reporting.
- **Terminology — findings vs vulnerabilities.** Use "findings" for the runtime-weighted unit measures rank on (what `explore_jobs` and the findings API return). Use "vulnerabilities" only for catalog-level CVE data. Do not use them interchangeably.
- **Terminology — severities.** Always PascalCase in prose: `Critical`, `High`, `Medium`, `Low`. (Filter *values* in `query_vulnerability_findings` calls use the API's lowercase form, e.g. `"critical"`.)
- **Terminology — numbers carry units.** On first occurrence in a message, always include the unit: "30 days", "137 findings", "12.7%".

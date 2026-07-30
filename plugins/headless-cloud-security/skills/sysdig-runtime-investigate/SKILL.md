---
name: sysdig-runtime-investigate
description: >
  Use this skill when investigating a runtime threat detected by Sysdig
  end-to-end. Surfaces the highest-priority threat, scores vulnerability
  vs runtime correlations on a 1-5 confidence scale, deep-dives into
  network blast radius or suspicious-binary VirusTotal lookups depending
  on the event class, reconstructs the affected workload's activity audit
  trail (commands, connections, file accesses) as a timeline around the
  detection, and hands the case off to Jira or PagerDuty.
  Triggers on: "investigate runtime threat", "what is this Falco alert",
  "triage this SOC alert", "analyze runtime incident". Not for
  vulnerability prioritization (use `sysdig-investigate`) or remediation
  (use `sysdig-remediate`).
allowed-tools:
  - Read
  - Write
  - Glob
  - Grep
  - AskUserQuestion
  - WebFetch
  - Bash(env*)
  - Bash(curl *ipinfo.io*)
  - Bash(curl *ip-api.com*)
  - Bash(curl *virustotal.com*)
  - Bash(curl *events.pagerduty.com*)
  - mcp__secure-mcp-server__get_skill_state
  - mcp__secure-mcp-server__save_skill_state
  - mcp__secure-mcp-server__delete_skill_state
  - mcp__secure-mcp-server__list_runtime_events
  - mcp__secure-mcp-server__count_runtime_events
  - mcp__secure-mcp-server__discover_runtime_event_field_values
  - mcp__secure-mcp-server__get_event_info
  - mcp__secure-mcp-server__get_event_process_tree
  - mcp__secure-mcp-server__list_activity_audit_events
  - mcp__secure-mcp-server__get_activity_audit_event
  - mcp__secure-mcp-server__trace_activity_audit_command
  - mcp__secure-mcp-server__list_threats_engine_groups
  - mcp__secure-mcp-server__get_threats_engine_group
  - mcp__secure-mcp-server__get_threats_engine_threat
  - mcp__secure-mcp-server__list_threats_engine_threats_by_group
  - mcp__secure-mcp-server__list_threats_engine_resources_by_group
  - mcp__secure-mcp-server__run_sysql
  - mcp__secure-mcp-server__query_vulnerability_findings
  - mcp__secure-mcp-server__list_runtime_scan_results
  - mcp__secure-mcp-server__get_scan_result
  - mcp__secure-mcp-server__fetch_threat_intelligence_feed
version: 1.0.1
---

## First-run notice (Public Beta)

Before doing any other work for this skill, perform this one-time check:

1. If `~/.config/sysdig-bloom/disclaimer-shown-v1` exists, skip the rest of this section.
2. Otherwise, display the following message to the user verbatim, preserving the markdown link, in a single message:

   > This plugin is a Public Beta release. It is provided “as is” and “as available,” without warranties of any kind. By installing this plugin, you agree to the Public Beta Terms available in the [repository readme](https://github.com/sysdig/skills#public-beta-terms).

3. Create the marker file `~/.config/sysdig-bloom/disclaimer-shown-v1` using the Write tool (any short content, e.g. the current UTC timestamp). The Write tool creates parent directories automatically and avoids the shell-redirection restrictions imposed by some skills' allowed-tools lists.
4. Then continue with the user's request.


When you need to ask the user a question, get confirmation, or present choices, use the `AskUserQuestion` tool if available. This ensures proper rendering across all agent clients.

## Input

Two invocation forms:

- `/sysdig-runtime-investigate` — interactive. The skill surfaces the top-priority threats and asks you to pick one.
- `/sysdig-runtime-investigate <event_id>` — directed. The skill investigates the given event/threat directly.

## Principles

**Glossary.** This skill uses these terms with specific meanings — keep them straight in user-facing text and in the case body:

- **threat** — a Threats Engine grouping (rule-level rollup of related events).
- **event** — a single security signal: Falco syscall, CloudTrail entry, or k8s_audit record.
- **case** — the report this skill produces and writes to `/tmp`.
- **incident** — multiple correlated threats folded into the same case.
- **image / workload / host** — compute targets at three levels: image artifact, Kubernetes workload (Pod, Deployment, etc.), and underlying VM or bare-metal host.

These are the rules of the game. **Phases are a floor, not a ceiling.** The chosen threat is a starting point — the goal is the full attack chain, which often spans multiple Threats Engine groups, multiple resources, and events that don't appear correlated at first.

- **Investigate freely.** Phases are a floor; cross-cluster, cross-account, cross-threat-group correlation is expected when the signals support it.
  - Do: fold related threat groups into the same case; pivot to CloudTrail when you see IMDS theft; expand the time window when an AWS access-key creation lines up with a K8s threat.
  - Don't: stop at the first threat group; treat the trigger event as the whole story.
- **Keep the user informed.** Drop a one-line status update between non-trivial calls — what you just found, what you're doing next.
  - Do: name the dimension you're pivoting to before the next call ("Process tree shows xmrig — looking for related cluster activity").
  - Don't: emit silent multi-call blocks; batch tool calls without narration.
- **Cite every claim.** Every fact in the case body references its source — event ID, MCP (Model Context Protocol) tool name, REST path, or external URL.
  - Do: attach the source inline for every CVE, IOC (indicator of compromise), process, and timestamp.
  - Don't: paraphrase data without provenance; leave claims dangling.
- **Don't fabricate.** If a CVE, IOC, or process didn't appear in the data, don't write it.
  - Do: omit fields the data didn't provide and record the limitation on the case object.
  - Don't: invent details to fill gaps; infer beyond what the data supports.
- **Two-tier output.** The full case goes to a markdown file in `/tmp`. The user sees a 2-paragraph summary in chat plus the file path.
  - Do: keep tables, evidence dumps, and long traces in the file.
  - Don't: paste tables into chat; force the user to scroll for the verdict.
- **Read-only by design.** This skill investigates and reports only. Remediation goes to `sysdig-runtime-remediate` (for live response actions on the running threat) or `sysdig-remediate` (for image-level CVE fixes).
  - Do: hand off to `sysdig-runtime-remediate` when the user wants to act on the live threat (kill, isolate, pause), or to `sysdig-remediate` when the fix is a vulnerable image.
  - Don't: run `kubectl delete`, `terraform apply`, or any destructive operation directly.
- **Always classify with MITRE.** Assign one MITRE ATT&CK tactic to the trigger event — it drives the correlation gate and the watchlist mapping.
  - Do: pick the more specific tactic when two could apply; record the secondary on `case.tactic_secondary`.
  - Don't: skip classification; defer it to a later phase.
- **Always include `event.id`.** Surface it in the file footer and any handoff payload — it's the audit trail.
  - Do: pass the event ID through Jira and PagerDuty payloads verbatim.
  - Don't: redact, abbreviate, or drop the event ID anywhere downstream.
- **Don't write cache or state to disk.** The `/tmp` report file is the only persistent artifact.
  - Do: use MCP shared skill state for cross-skill context.
  - Don't: write working state, raw event payloads, or secrets to disk.

## State

State is read and written via the Sysdig MCP server tools.

| Operation | Tool | Arguments |
|-----------|------|-----------|
| Read state | `get_skill_state` | `{ "skill_state": "runtime-investigate" }` |
| Write state | `save_skill_state` | `{ "skill_state": "runtime-investigate", "version": <n>, "data": { ... } }` |
| Delete state | `delete_skill_state` | `{ "skill_state": "runtime-investigate" }` |

A `null` response from `get_skill_state` means no state exists yet — start with `{ "version": 0 }`.

### Schema

```json
{
  "version": 1,
  "last_run": "2026-05-04T18:30:00Z",
  "preferred_jira_project": "RUNTIME",
  "preferred_handoff": "jira",
  "recent_cases": [
    {
      "event_id": "abc123",
      "cluster": "prod-eu-1",
      "tactic": "c2",
      "case_file": "/tmp/sysdig-runtime-investigate-abc123-20260504-1830.md",
      "started": "2026-05-04T18:30:00Z",
      "completed": "2026-05-04T18:42:00Z",
      "handoff": { "destination": "jira", "ticket_key": "RUNTIME-1234", "ticket_url": "https://example.atlassian.net/browse/RUNTIME-1234" }
    }
  ]
}
```

### Read/write rules

- **Get** at the start of every session via `get_skill_state` with `{ "skill_state": "runtime-investigate" }`. A `null` response means no state — start with `{ "version": 0 }`.
- **Save** at the end of every session via `save_skill_state` with `{ "skill_state": "runtime-investigate", "version": <n>, "data": { ... } }`. Read the current contents first, merge new data, then pass the full merged object as `data`.
- **Version argument** — the server uses `version` for optimistic concurrency. Pass it as a separate argument (do not include it inside `data`):
  - First write (`get_skill_state` returned `null`) → call with `version: 0`.
  - Subsequent writes → call with the same `version` value the previous `get_skill_state` returned.
  - On 409 conflict → call `get_skill_state` again, merge your changes into the freshly-read state, retry once with the new version.
- **Matching keys** for upsert in `recent_cases`: match on `event_id`. Cap the list at the 10 most recent entries; drop the oldest when over.
- Timestamps use ISO 8601. The `case_file` path is informational only — files in `/tmp` may be cleaned up by the OS.
- `preferred_handoff` is `"jira" | "pagerduty" | "both" | "skip" | null`. `null` means the user hasn't expressed a preference.

## Steps

You run a 4-phase pipeline directly — no subagents.

```
Phase 0 ──→ Phase 1 ──→ Phase 2 ────→ Phase 3
Preflight   Surface     Investigate    Synthesise + report
                        (free-form)    (file + summary + handoff)
```

### Phase 0 — Preflight

0. **Trust Preamble.** Always present this before doing anything else. See [`references/trust-preamble.md`](references/trust-preamble.md) for the full text. After presenting the preamble, proceed directly to Step 0a — do NOT ask for confirmation. The preamble is informational.

0a. **MCP authentication preflight.** Before any other step — including the state read below — run the preflight in [`references/auth-preflight.md`](references/auth-preflight.md) and follow its instructions exactly. This skill **requires** the Sysdig MCP: it is the only source for Threats Engine, runtime events, process trees, SysQL, vulnerability scans, and the threat-intel feed. If the preflight returns State 2 (registered but not authenticated) or State 3 (not reachable), emit its verbatim message and **stop** — no data calls, no state read, no file writes. Do NOT call `mcp__secure-mcp-server__authenticate` autonomously. Only continue past this step on State 1 (catalog reachable).

0b. **Read shared state.** Call `mcp__secure-mcp-server__get_skill_state` with `{ "skill_state": "runtime-investigate" }`. A `null` response means no prior state — start with `{ "version": 0 }`. If state exists, hydrate `preferred_jira_project`, `preferred_handoff`, and `recent_cases` onto the working session so Phase 3 can default to the user's prior choices instead of re-asking.

1. **Reporting / CTI (cyber threat intelligence) probe (no-block).** Detect available destinations and CTI tools dynamically. Do not require any specific env-var name — match by pattern.

   - Jira / case tracking: scan for MCP tools matching `mcp__atlassian__*`, `mcp__*jira*`, `mcp__*linear*`. Mark the first match.
   - Jira project key: scan env vars matching `*JIRA_PROJECT*` (e.g. `SYSDIG_RUNTIME_JIRA_PROJECT`). If matched, surface the value as the default project for Phase 3 handoff.
   - PagerDuty / on-call: scan env vars matching `*PAGERDUTY*`, `*PD_TOKEN*`, `*PD_ROUTING_KEY*`.
   - VirusTotal: scan env vars matching `*VIRUSTOTAL*`, `*VT_API*`, `*VT_KEY*`.

   Record what was found. Do **not** prompt yet if nothing was detected — defer that to Phase 3 handoff.

2. **Announce connectivity.** Before moving on, surface a single user-facing line summarising what's wired up. Mark each integration `✓` (detected), `—` (missing), or `✗` (probe failed). The Sysdig MCP is always `✓` here — Step 0a already guaranteed it. Example:

   - `Connectivity: Sysdig MCP ✓ · Jira ✓ · PagerDuty — · VirusTotal —. Will skip binary VT enrichment and PagerDuty handoff.`

   **Data-egress notice.** Immediately after the connectivity line, when any third-party enrichment is reachable, disclose in one line what indicators will leave the environment and to which service — so the user can veto before any external call:

   - `Enrichment will send: binary SHA256 hashes → VirusTotal · public (non-private) IPs → ipinfo.io (fallback ip-api.com) · CVE IDs → NVD/CISA KEV/Exploit-DB/GHSA. Private/internal IPs (RFC1918, link-local, loopback, CGNAT) are never sent. No Sysdig event contents, hostnames, or Sysdig credentials leave the environment — the VirusTotal call carries only the hash plus your VirusTotal API key.`

   Only list the destinations that are actually reachable (`✓`). If the user declines, skip the corresponding enrichment and record it as `skipped: user declined egress`. This is the only narration during Phase 0 — the per-step results above are recorded silently on the case object. Don't prompt beyond the egress veto; just inform.

3. **Entry-point detection.** Parse the invocation argument:
   - No argument → `interactive` mode.
   - Anything else → `directed` mode, store the value as the event ID.

4. **Resume check (directed mode only).** If `recent_cases` (from step 0b) has an entry whose `event_id` matches the current trigger, surface a one-line resume summary and ask the user via `AskUserQuestion` how to proceed:

   > "You investigated `<event_id>` <N> hours ago — case file `<case_file>`, handoff `<destination>:<key>` if any. Continue with the saved case, refresh (re-run Phase 2), or start fresh (clear the prior entry)?"

   - **Continue** → skip Phase 1 + Phase 2; jump to Phase 3 with the saved case (read the file from disk if it still exists; otherwise treat as `refresh`).
   - **Refresh** → keep the saved entry but re-investigate; merge new findings.
   - **Start fresh** → drop the prior entry from `recent_cases` and re-run.

   **Staleness default.** If the prior `completed` timestamp is more than 4 hours ago, runtime data has likely shifted — pre-select **Refresh** as the default. Below 4 hours, default to **Continue**.

   Interactive mode does not pause here — Phase 1 will surface fresh threats and any prior case will only show up in the picker as `(seen <N>h ago)`.

### Phase 1 — Surface

**Interactive flow:**

1. List the top open threats — Threats Engine is exposed via MCP. Call `mcp__secure-mcp-server__list_threats_engine_groups` with `limit=5`, sorted by `lastSignal:desc`, `status=open`.

   If Threats Engine returns empty (unavailable or quiet in this tenant), fall back to runtime events for the same window: `mcp__secure-mcp-server__list_runtime_events` with last 24h, limit 10.

2. Present the result as a markdown table:

   | # | Severity | Rule / aiGeneratedName | Resource | Last seen |
   |---|----------|------------------------|----------|-----------|

   Ask via `AskUserQuestion`: "Which one do you want to investigate?"

3. **Incident-scope detection at surface time.** Before diving into the chosen threat, scan the other surfaced groups. Multi-stage attacks frequently span more than one Threats Engine grouping. Treat all groups sharing cluster + ±2h, OR `aws.accountId` + ±2h, OR same image as the **same incident** — one investigation, one case body, one narrative. Record them on `case.incident_threat_groups`.

   If these conditions hold, the chosen threat is one facet of a larger incident — fold all matching groups into the same case object. Tag them on `case.incident_threat_groups` (id, name, resource, last_seen, why_related). Phase 2's cluster-wide sweep then has a head start — these groups' constituent events should also appear in the sweep, but flagging them upfront lets the report's "Incident scope" section name them by their AI-generated title rather than as anonymous events.

**Directed flow:**

1. Resolve the specific threat. The trigger ID may be a threat ID, a group ID, or an event ID — try in that order: `mcp__secure-mcp-server__get_threats_engine_threat` (single-threat detail); on 404 `mcp__secure-mcp-server__get_threats_engine_group`, then `mcp__secure-mcp-server__list_threats_engine_threats_by_group` with the ID; if all 404, fall back to `mcp__secure-mcp-server__get_event_info` with the event ID.

**Classification — MITRE ATT&CK tactic.** From the rule name, rule source, and event labels, assign one MITRE tactic to the threat. Store it on the case as `case.tactic`. Phase 2 watchlist mapping reads this value. See [`references/mitre-tactics.md`](references/mitre-tactics.md) for the keyword-to-tactic table and the secondary-tactic rule.

**Process tree (Sysdig MCP).** If the threat has an `event_id` (the Threats Engine returns `securityEvent` references with IDs), call `mcp__secure-mcp-server__get_event_process_tree` with the event ID to retrieve the structured process tree. Store the parsed result (parent → child chain, command lines, sha256 if present) on `case.process_tree`.

**Process evidence from `aiGeneratedDescription` (always runs — useful even alongside the structured tree).** The description carries natural-language context the structured tree doesn't ("locale repeatedly", "curl --upload to external IP"). Parse it for process names (e.g. `systemd`, `sshd`, `bash`, `curl`, `wget`, `nc`, `nslookup`) and chain hints ("spawned by", "child of"). Store as `case.process_evidence` (list of strings).

The two are complementary: `case.process_tree` is structured ground truth, `case.process_evidence` is the AI's narrative read of the same chain. The report renders both in "What happened" — the tree as a tree, the evidence as a one-liner.

Store the threat, classification, secondary tactic (if any), process tree (if available), and process evidence on the working case object.

### Phase 2 — Investigate (free-form, signal-driven)

**Goal:** reconstruct the full attack chain starting from the user's pick. Span multiple threat groups, multiple resources, multiple event sources if the signals lead there. The chain is the deliverable — phase boundaries from earlier versions of this skill (e.g. separate enrichment / classifier / synthesis stages) are explicitly *not* prescribed steps anymore.

Tell the user what you're doing as you go. Examples of good status updates:

- "Process tree shows Tomcat → bash → xmrig — looks like miner persistence. Looking for related cluster activity."
- "IMDS (Instance Metadata Service) theft on the host. Expanding to CloudTrail in the same AWS account."
- "Found two more threat groups on the same account in the same hour — folding them in as the same campaign."
- "Runtime scan for the workload came back empty — pulling image-level vuln findings instead."

#### Available signals (chase them when relevant)

These are the ingredients. The order is yours.

**Time scoping — read before any event query.** `list_runtime_events`, `count_runtime_events`, and `discover_runtime_event_field_values` accept only `scope_hours` — a window counted *back from now*. There is no absolute start/end, and `filter_expr` has no timestamp field. So a "±2h around the trigger" or "last 7 days" window is **not** something `scope_hours` gives you when the trigger isn't recent: set `scope_hours` wide enough to reach past the trigger (`scope_hours ≈ hours_since_trigger + 2`), then **post-filter the returned events by their timestamp** down to the band you actually want. Treat every "±2h" / "7-day" phrasing below as the *target band after client-side filtering*, not a parameter you can pass directly.

- **Tenant-wide critical sweep (sanity check)** — once early in Phase 2, call `mcp__secure-mcp-server__list_runtime_events` with `filter_expr = "severity in (0,1,2,3)"` and *no scope filter* across the ±2h window around the trigger. Catches cross-domain signals the cluster/account-filtered queries miss (GitHub `cloudProvider.account.id`, Okta `cloudProvider.tenantId`, anything without K8s labels). Fold in any hit whose image-org, repo name, or actor matches the trigger.
- **Process tree** of the trigger event — `mcp__secure-mcp-server__get_event_process_tree`. Almost always the highest-yield single artifact. Falls back to `aiGeneratedDescription` parsing if the MCP returns empty.
- **Activity audit trail** of the affected workload — the agent-captured record of every command, network connection, and file access around the trigger, independent of whether each tripped a rule. This is what a human analyst pulls in the Secure UI to answer *"what else did this workload do around the detection?"* — dwell time, lateral-movement setup, dropped files, C2 callbacks. Use the MCP tool `list_activity_audit_events` scoped to the **container / pod / workload** (never the bare host) and centred on the trigger time. **Unlike `list_runtime_events`, the activity audit tools take a real absolute window (`from`/`to` as ISO-8601, epoch, or a relative offset like `2h`/`7d`, max 2 weeks)** — so a "±2h around the trigger" band is a direct parameter, *not* the `scope_hours` post-filter workaround. For a suspicious command (dropper, reverse shell, miner), pass its entry id to `trace_activity_audit_command` to reconstruct the child processes, connections, and files it spawned in the same session — the audit-trail counterpart to the process tree. See [`references/activity-audit.md`](references/activity-audit.md) for tools, filter fields, scoping, and the timeline output shape. The trail feeds the "Activity audit timeline" report section and cross-references into the network/binary IOC enrichment.
- **Prior events on the affected resource** — last 7 days, via `mcp__secure-mcp-server__list_runtime_events` with a `filter_expr` matching the workload (`kubernetes.cluster.name + namespace + workload`) or host (`host.hostName`). For K8s workloads, also pull host-level events on the same node — escapes hide there.
- **Cluster-wide activity in a ±2h window** around the trigger. Same MCP tool, three filters in parallel. **The `source` values are tenant/region/backend-specific — confirm the real ones with `mcp__secure-mcp-server__discover_runtime_event_field_values` on the `source` field before filtering, rather than assuming a literal.** Known values at the time of writing: `syscall`, `k8s_audit`, `awscloudtrail` + `awscloudtrail_stateful` (AWS — note there is **no** bare `cloudtrail` value), `azure_platformlogs` + `azure_entra` (Azure), `gcp_auditlog` (GCP). If a `source` filter comes back empty, re-run discover (its `suggested` bucket lists what's actually firing, `other` lists what the tenant knows) and widen to the values it reports.
  - `kubernetes.cluster.name = "<cluster>" and source = "syscall"` (other resources in the cluster)
  - `kubernetes.cluster.name = "<cluster>" and source = "k8s_audit"` (Attach/Exec Pod, Deployment Created, etc.)
  - `kubernetes.cluster.name = "<cluster>" and source in ("awscloudtrail", "awscloudtrail_stateful")` (cluster-tagged cloud events, if any — swap in the Azure/GCP source values from discover when the cluster runs there)
- **Cloud-account-wide activity** when the resource has `aws.accountId` / `azure.subscriptionId` / `gcp.projectId`. Cloud audit-log and agentless-ML events live under the *account* dimension, not the cluster. **This is the difference between catching multi-stage cross-cloud attacks (IMDS credential theft → IAM access-key creation → audit-log tampering → storage exfiltration) and missing them.** Filter by the matching dimension and that cloud's source values (verify with discover first):
  - AWS — `aws.accountId = "<account>" and source in ("awscloudtrail", "awscloudtrail_stateful", "agentless-aws-ml")`
  - Azure — `azure.subscriptionId = "<subscription>" and source in ("azure_platformlogs", "azure_entra")`
  - GCP — `gcp.projectId = "<project>" and source in ("gcp_auditlog")`
- **Other threat groups in this incident** — fold them into the same case — do not investigate separately. Other threat groups already tagged in Phase 1 as part of this incident — pull their constituent events via `mcp__secure-mcp-server__list_threats_engine_threats_by_group` and their affected resources via `mcp__secure-mcp-server__list_threats_engine_resources_by_group` (both keyed by the group ID) to merge into the chain. If new groups appear in the cluster window during Phase 2 investigation, fold them in too. Cross-type is allowed: a CLOUD threat may be the same incident as a K8S_WORKLOAD threat.
- **Sibling resources / posture / RBAC (role-based access control)** via `mcp__secure-mcp-server__run_sysql`. SysQL schema differs between tenants — adjust query shape if rejected. Example queries: `MATCH KubeWorkload AS wl WHERE wl.cluster = '<c>' RETURN wl.namespace, wl.name`, `MATCH Resource VIOLATES Control`, `MATCH KubeServiceAccount HAS KubeRoleBinding HAS KubeClusterRole`.
- **Vulnerability surface** — start with `mcp__secure-mcp-server__query_vulnerability_findings` scoped to the running image, filtered to the notable CVEs:

  ```json
  {
    "group_by": "cve",
    "filters": [
      { "field": "imageId", "op": "eq", "value": "<running image's config digest>" },
      { "field": "severity", "op": "in", "value": ["critical", "high"] },
      { "field": "hasFix", "op": "eq", "value": true },
      { "field": "hasExploit", "op": "eq", "value": true }
    ]
  }
  ```

  **Scope by the right identifier.** `imageId` expects the image **config digest** — the `sha256:…` that runtime detection resolves the running container to (the threat detail's image id; equivalently `metadata.imageId` from `get_scan_result` in the scan-result step below). This is a *different* sha256 from the registry **manifest** digest (findingsapi field `imageDigest`, `metadata.digest`) — cross them and the query returns zero rows with no error. If you only have the pullstring, use `imageReference` (e.g. `…/app:1.0.0`) instead, accepting that a mutable tag may span builds.

  **Filtering.** The tool applies **no** default filters, so set the triage filters explicitly: severity critical/high, `hasFix` true, `hasExploit` true. That narrows to the actionable, weaponized CVEs the MITRE-tactic gate and CTI step below consume. If the result comes back empty, widen by dropping `hasExploit`, then `hasFix`, before concluding the image is clean.

  `group_by: "cve"` returns one deduplicated row per CVE, ranked by the grouping's default risk order. Read rows from the response's `data` array; `meta.hasMore` + the `cursor` token page further, and `severity` comes back capitalized (`Critical`) in responses even though the filter value is lowercase. For running/in-use package detail — which vulnerable packages are actually loaded on the workload or host — use `mcp__secure-mcp-server__list_runtime_scan_results` (filter by `kubernetes.cluster.name`/`namespace`/`workload` or `host.hostName`, sort `runningVulnTotalBySeverity`) and pass the returned `resultId` to `mcp__secure-mcp-server__get_scan_result` for the full packages + vulnerabilities breakdown.
- **External CTI** for the top 5 critical/high CVEs that pass the MITRE-tactic gate (see `references/correlation-guide.md`): NVD, CISA KEV (Known Exploited Vulnerabilities), Exploit-DB, GHSA (GitHub Security Advisory) via `WebFetch`. Don't fetch CTI for tactic-mismatched CVEs.
- **Sysdig threat-intel feed** via `mcp__secure-mcp-server__fetch_threat_intelligence_feed` — Sysdig-curated CVEs / zero-days / active-attack notes. Cross-reference any IOCs you collect.
- **VirusTotal (VT)** for binary IOCs when a SHA256 surfaces on event fields and a VT key is present (Phase 0 records the env var). When the threat lacks `proc.sha256`, look across other events on the same container — drift detection events typically carry the hash.
- **GeoIP** for network IOCs via `curl https://ipinfo.io/<ip>/json` (fallback `ip-api.com`).

#### Patterns to recognise (not steps to execute)

When any of these rule names fire in the data you've pulled, that's the signal to expand. The action column is *what direction to look*, not a fixed query. See [`references/watchlist-patterns.md`](references/watchlist-patterns.md) for the full hit-to-pivot table covering IMDS theft, persistent cloud creds, defense evasion, S3 exfil, privesc, lateral movement, runtime compromise, recon, and prompt-injection.

#### MITRE-tactic correlation

Read `references/correlation-guide.md` for the MITRE-tactic gate and 1–5 scoring heuristics. Render only pairs ≥ 4 in the case body. Boosts (cap at 5): KEV +1, VT malicious_count≥5 +1.

#### Stop conditions

You're done when:
- The chain has a coherent narrative (initial access → execution → … → impact, or bounded by available data), AND
- You've followed every watchlist hit at least one hop, AND
- You've pulled the activity audit trail for the affected container/pod/workload around the trigger (or recorded why it was unavailable) — the timeline is part of the deliverable, AND
- You've asked yourself *"is there another threat group within the cluster + ±2h / account + ±2h window that belongs to this same incident?"* — and either folded it in or recorded why not.

If you find yourself making more than ~4 follow-on calls per signal, stop and synthesise. Diminishing returns.

### Phase 3 — Synthesise & report

Four steps, in this order:

1. **Ask the user for the report format** via `AskUserQuestion`: "How do you want the report rendered? `Markdown` (default — plays nice with Jira/PagerDuty handoff) / `HTML` (renders Mermaid diagrams in browser, self-contained) / `Both`."

   If `AskUserQuestion` is not available, default to `Markdown` and mention HTML as a follow-up option in the summary.

2. **Write the file(s) to disk.** Base path: `/tmp/sysdig-runtime-investigate-<event_id_short>-<UTC-yyyymmdd-hhmm>`.
   - `Markdown` → write `<base>.md` with Block 1 of `references/reporting-templates.md` verbatim. Always written when chosen — also the body of Jira/PagerDuty handoff downstream.
   - `HTML` → write `<base>.html` using Block 4 wrapper from the same file. The Block 1 markdown content is pasted into the wrapper's `<script id="md">` block. Marked + mermaid CDN scripts render the page in the browser.
   - `Both` → write both files, same base name.

3. **Print a 2-paragraph summary to the user.** Use Block 0 of `reporting-templates.md` — short, no tables. Cite the file path(s) so they can read it if they want. Then ask `AskUserQuestion`: "Where do you want to report this case?" with options derived from what Phase 0 detected (`Jira`, `PagerDuty`, `Both`, `Just show it`).

Handoff:
- **Jira** → Build the Block 2 payload from the templates (body = file content). If the project key is unknown, call `mcp__atlassian__getVisibleJiraProjects` and ask the user. **Preview before submitting.** Render a short block — `Project · Issue type · Summary · Severity · Labels · Body length (chars)` — then ask via `AskUserQuestion`: "Submit, edit, or cancel?". Only on **Submit** call `mcp__atlassian__createJiraIssue`. Capture key + URL and surface them with an undo line: *"Undo: open the ticket and click Close."*
- **PagerDuty** → Build the Block 3 payload (`custom_details.case` = file content, truncate to ~30 KB if larger). **Preview before submitting.** Render `Routing key (last 4) · Severity · Dedup key · Summary · Source · custom_details size (KB)` and ask via `AskUserQuestion`: "Submit, edit, or cancel?". Only on **Submit** send via:

  ```bash
  printf '%s' "$PAYLOAD_JSON" | curl -sS -X POST \
    -H "Content-Type: application/json" \
    --data-binary @- \
    https://events.pagerduty.com/v2/enqueue
  ```

  Capture the `dedup_key` and incident URL from the response. Surface them with an undo line: *"Undo: resolve the incident with `event_action: resolve` and the same dedup key."*

- **Both** → run the Jira preview-and-submit first, then the PagerDuty preview-and-submit. Confirm each separately; declining one does not cancel the other.

- **Just show** → no extra action; the file path was already cited in the summary.

If the user picks **Edit** at the preview step, ask which fields to change, apply the edits to the payload, and re-show the preview. Loop until the user picks Submit or Cancel.

After handoff, surface the link/key (if any) to the user — one short line.

4. **Offer to act on the threat (optional handoff to remediation).** After the reporting handoff is complete (or skipped), ask via `AskUserQuestion`: _"Want me to act on this threat now? `sysdig-runtime-remediate` will propose response actions (kill, isolate, pause, etc.), explain the consequences on the live workload, and execute only what you approve."_ Options: `Yes — invoke sysdig-runtime-remediate` / `No`.

   - On **Yes** — announce the handoff explicitly per principle C-03 (_"Handing off to `sysdig-runtime-remediate` with `<event_id>`. The case file you just generated will be its starting context."_), then invoke `sysdig-runtime-remediate <event_id>`.
   - On **No** — proceed silently to step 5. The user can always come back later with `/sysdig-runtime-remediate <event_id>` — the case file and shared state will still be there.

   Skip this step if `sysdig-runtime-remediate` is not registered in the current plugin (back-compat for environments running an older Bloom).

5. **Persist shared state.** Before exiting, call `mcp__secure-mcp-server__save_skill_state` with `{ "skill_state": "runtime-investigate", "version": <version-from-phase-0>, "data": { ... } }`. Merge the freshly-read state from Phase 0 with the new entries: append this case to `recent_cases` (upsert by `event_id`, cap at 10), update `last_run`, and update `preferred_jira_project` / `preferred_handoff` if the user picked a destination. Skip silently if the Sysdig MCP isn't loaded.

## Error Handling

**Status vocabulary.** Every section of the case object uses the house status set: `done`, `pending`, `in_progress`, `failed`, `skipped`. The reason goes in a separate `reason` field so the report and the summary can render either status alone or status + reason.

```json
{ "vulnerabilities": { "status": "skipped", "reason": "no scan data" } }
{ "cloudtrail": { "status": "skipped", "reason": "no integration in tenant" } }
{ "vt": { "status": "skipped", "reason": "no API key" } }
{ "cti.nvd": { "status": "failed", "reason": "rate-limited" } }
```

**User-facing error template.** Every error message the user sees follows three lines: **what** failed, **why**, and the **fix** (a copy-pasteable command or concrete next step). Keep the whole thing under four lines. Examples:

> Can't reach Sysdig — the MCP server isn't registered or authenticated.
> Register it with `claude mcp add --transport http secure-mcp-server https://<region>/mcp/secure`, then run `/mcp` → Sysdig → Authenticate.
> Per-region URLs are in references/mcp-setup.md. Then re-run.

> No threats matched the last 24h.
> Either the tenant is quiet or the time window is too tight.
> Widen the time window (e.g. 7 days) or pick a specific event ID.

> Couldn't open the Jira ticket — Atlassian MCP returned 403.
> Your token doesn't have `write:jira-work` for project `RUNTIME`.
> Refresh the token in the Atlassian admin console and retry, or pick another destination.

Truncation, skipped enrichments, and other partial-success cases must be flagged in the 2-paragraph chat summary too — never let the user discover them only by reading the case file.

| Situation | Behavior |
|-----------|----------|
| Sysdig MCP preflight returns State 2 or State 3 | Abort in Phase 0a per `auth-preflight.md` — emit its verbatim message and stop. No data calls, no state read, no file writes. |
| An MCP tool call comes back **denied** (the agent refuses the call rather than the server erroring) | Not an auth or reachability failure — the tool isn't on the agent's allowlist, usually a **prefix mismatch**. `allowed-tools` lists the canonical `mcp__secure-mcp-server__*` names (per `mcp-setup.md`), but the server may be registered under a different prefix in this agent (e.g. a plugin-managed name). The bare tool names match 1:1; only the prefix differs. Tell the user: confirm the registered name with `claude mcp list`, then either re-register it as `secure-mcp-server` (the mandated name — see `mcp-setup.md`) or add the actual `mcp__<prefix>__*` pattern to the agent's permitted tools, and re-run. Do not loop retrying the denied call. |
| Trigger ID resolves to neither a threat nor a group (`get_threats_engine_threat`, `get_threats_engine_group`, and `list_threats_engine_threats_by_group` all 404) | Fall back to `mcp__secure-mcp-server__get_event_info` with the same ID. If that 404s too, tell the user the ID wasn't found and offer interactive mode. |
| No qualifying threats / events found in Phase 1 | Tell the user, offer to widen the time window. |
| Vulnerability lookup empty | When `mcp__secure-mcp-server__query_vulnerability_findings` returns an empty `data` array, widen by relaxing filters (drop `hasExploit`, then `hasFix`, then severity) before concluding the image is clean. If still empty, try `mcp__secure-mcp-server__list_runtime_scan_results` (filter by workload/host) then `mcp__secure-mcp-server__get_scan_result`. If still nothing, record `{ "vulnerabilities": { "status": "skipped", "reason": "no scan data" } }` and continue. |
| `WebFetch` to a public CTI source fails or rate-limits | Mark that source `{ "status": "failed", "reason": "<rate-limited \| network \| 4xx>" }` and continue. Don't retry in a loop. |
| VirusTotal API key not detected | Record `{ "vt": { "status": "skipped", "reason": "no API key" } }`. |
| No Jira and no PagerDuty detected | Ask whether the user wants to configure one or just show the file path. |
| Atlassian MCP / PagerDuty curl errors during handoff | Record `{ "handoff": { "status": "failed", "reason": "<error>" } }`, surface the error, print the file path, offer to retry or switch destination. |
| Activity audit trail empty or capture not enabled | `list_activity_audit_events` returns no entries for the scoped container/pod/workload. Not a failure — the agent's command/connection/file capture may be off, or the workload was genuinely quiet. Record `{ "activity_audit": { "status": "skipped", "reason": "no activity audit data for this scope" } }` and flag in the summary that audit context was unavailable. |
| Activity audit window exceeds 2 weeks | `from`/`to` span is capped at 2 weeks server-side. Narrow the window (centre tighter on the trigger) and re-issue. |
| `mcp__secure-mcp-server__list_runtime_events` cursor pagination drops `filter_expr` | Known MCP quirk — paginating with `cursor` returns events from the wrong scope. Don't paginate; widen `scope_hours` and re-issue with the original filter. |
| A list_runtime_events call returns >100 events | Tighten the time window or split the filter. Never silently drop the section — record `{ "status": "done", "truncated": true, "shown": <n>, "total": <m> }`. |
| Cloud audit-log integration (CloudTrail / GCP Audit / Azure Activity) not present in tenant | Cloud-account sweep returns empty (no `source` values for that provider — confirm with discover). Record `{ "cloudtrail": { "status": "skipped", "reason": "no integration in tenant" } }` on the case; flag in the summary that cloud-API signals (storage / IAM / IMDS) were unavailable. |
| SysQL schema rejects a query | Try the alternate relation shapes (`HAS` vs `BINDS_TO`, etc.). If all fail, record `{ "status": "failed", "reason": "schema mismatch" }` and continue. The skill should not block on schema mismatches. |

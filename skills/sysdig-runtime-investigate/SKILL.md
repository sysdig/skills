---
name: sysdig-runtime-investigate
description: >
  Investigate a runtime threat detected by Sysdig end-to-end. Surfaces the
  highest-priority threat, enumerates affected images, scores vulnerability
  vs runtime correlations on a 1-5 confidence scale, deep-dives into
  network blast radius or suspicious-binary VT lookups depending on the
  event class, and hands the case off to Jira or PagerDuty. Triggers on:
  "investigate runtime threat", "what is this Falco alert", runtime
  incident triage, SOC investigation, Falco alert analysis.
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

## Investigation principles

These are the rules of the game. **Phases are a floor, not a ceiling.** The chosen threat is a *starting point* — the goal is to reconstruct the full attack path, which often spans multiple Threats Engine groups, multiple resources, and events that don't appear correlated at first.

- **Follow signals.** If you see IMDS theft, expand to CloudTrail. If you see an AWS access-key creation in the same hour as a K8s threat, fold it in. Cross-cluster, cross-account, cross-threat-group correlation is expected when the signals support it. Trust your judgment on what to pull next.
- **Keep the user informed.** Between non-trivial calls (multi-second waits, new dimensions, new hypotheses) drop a one-line status update: what you just found and what you're doing next. Silent multi-call blocks are the wrong UX for an investigation.
- **Cite everything.** Every claim in the case body references its source (event ID, MCP tool, REST path, external URL).
- **Don't fabricate.** If the data didn't say it, don't write it.
- **Two-tier output.** The full case goes to a markdown file in `/tmp`. The user sees a 2-paragraph summary. Long tables are for the file, not the chat.

## Steps

You run a 4-phase pipeline directly — no subagents.

```
Phase 0 ──→ Phase 1 ──→ Phase 2 ────→ Phase 3
Preflight   Surface     Investigate    Synthesise + report
                        (free-form)    (file + summary + handoff)
```

### Phase 0 — Preflight

1. **Sysdig credentials (hard-block).** Probe for both a token and a host before any call:

   ```bash
   env | grep -iE 'SYSDIG.*(TOKEN|KEY)' >/dev/null && echo "token-found" || echo "TOKEN-MISSING"
   env | grep -iE 'SYSDIG.*(HOST|URL)'  >/dev/null && echo "host-found"  || echo "HOST-MISSING"
   ```

   If either reports `MISSING`, stop and surface the regions table plus `export` commands. Do not start Phase 1 until both are bound.

   Export the canonical pair: `export SYSDIG_SECURE_URL='<region URL>'` and `export SYSDIG_SECURE_API_TOKEN='<token>'`.

   | Region | Host URL |
   |---|---|
   | US East (Virginia) | `https://us2.app.sysdig.com` |
   | US West (Oregon) | `https://app.us4.sysdig.com` |
   | US West (GCP) | `https://us4.app.sysdig.com` |
   | EU Central (Frankfurt) | `https://eu1.app.sysdig.com` |
   | AP South (Sydney) | `https://app.au1.sysdig.com` |

   Recommended exports:

   ```bash
   export SYSDIG_SECURE_URL='https://eu1.app.sysdig.com'
   export SYSDIG_SECURE_API_TOKEN='<token>'
   ```

   Canonical names are `SYSDIG_SECURE_API_TOKEN` + `SYSDIG_SECURE_URL`. Legacy names — `SYSDIG_API_*`, `SYSDIG_MCP_*`, `SECURE_*` — still work.

2. **Sysdig MCP probe.** Scan available tool names for any matching `mcp__sysdig__*`. The skill is bundled with the Sysdig MCP server (declared in the plugin's `.mcp.json`); if it's loaded you get higher-quality enrichment for free. Record the boolean `mcp_sysdig_available` for downstream phases.

   The MCP unlocks: SysQL queries (Phase 2 sibling/posture lookups), real process trees (Phase 2), and Sysdig's threat-intelligence feed (Phase 2 network enrichment). When the MCP is **not** available, those steps degrade gracefully — the case still renders, just thinner.

   If `mcp_sysdig_available` is false and the user wants the richer enrichment, point them at [`references/mcp-setup.md`](references/mcp-setup.md) — it covers the `claude mcp add sysdig` command and equivalents for Cursor / Codex / OpenCode.

3. **Reporting / CTI probe (no-block).** Detect available destinations and CTI tools dynamically. Do not require any specific env-var name — match by pattern.

   - Jira / case tracking: scan for MCP tools matching `mcp__atlassian__*`, `mcp__*jira*`, `mcp__*linear*`. Mark the first match.
   - Jira project key: scan env vars matching `*JIRA_PROJECT*` (e.g. `SYSDIG_RUNTIME_JIRA_PROJECT`). If matched, surface the value as the default project for Phase 3 handoff.
   - PagerDuty / on-call: scan env vars matching `*PAGERDUTY*`, `*PD_TOKEN*`, `*PD_ROUTING_KEY*`.
   - VirusTotal: scan env vars matching `*VIRUSTOTAL*`, `*VT_API*`, `*VT_KEY*`.

   Record what was found. Do **not** prompt yet if nothing was detected — defer that to Phase 3 handoff.

4. **Entry-point detection.** Parse the invocation argument:
   - No argument → `interactive` mode.
   - Anything else → `directed` mode, store the value as the event ID.

### Phase 1 — Surface

**Interactive flow:**

1. Try Threats Engine first (no MCP equivalent yet — vendored script):

   ```bash
   python3 $SKILL_DIR/scripts/fetch_threats.py --list 5
   ```

   If the script exits with code 2 (Threats Engine unavailable in the tenant), fall back to the events API:

   - If `mcp_sysdig_available` → call `mcp__sysdig__list_runtime_events` with last 24h, limit 10.
   - Otherwise → `python3 $SKILL_DIR/scripts/fetch_events.py --recent --hours 24 --limit 10`.

2. Present the result as a markdown table:

   | # | Severity | Rule / aiGeneratedName | Resource | Last seen |
   |---|----------|------------------------|----------|-----------|

   Ask via `AskUserQuestion`: "Which one do you want to investigate?"

3. **Incident-scope detection at surface time.** Before diving into the chosen threat, scan the other surfaced groups. Multi-stage attacks frequently span more than one Threats Engine grouping. Treat all groups sharing cluster + ±2h, OR `aws.accountId` + ±2h, OR same image as the **same incident** — one investigation, one case body, one narrative. Record them on `case.incident_threat_groups`.

   If these conditions hold, the chosen threat is one facet of a larger incident — fold all matching groups into the same case object. Tag them on `case.incident_threat_groups` (id, name, resource, last_seen, why_related). Phase 2's cluster-wide sweep then has a head start — these groups' constituent events should also appear in the sweep, but flagging them upfront lets the report's "Incident scope" section name them by their AI-generated title rather than as anonymous events.

**Directed flow:**

1. Try Threats Engine (vendored script — same reason as above):

   ```bash
   python3 $SKILL_DIR/scripts/fetch_threats.py --threat <event_id>
   ```

   If the script exits 2, fall back to the events API:

   - If `mcp_sysdig_available` → call `mcp__sysdig__get_event_info` with the event ID.
   - Otherwise → `python3 $SKILL_DIR/scripts/fetch_events.py --event <event_id>`.

**Classification — MITRE ATT&CK tactic.** From the rule name, rule source, and event labels, assign one MITRE tactic to the threat. Store it on the case as `case.tactic`. Phase 2 watchlist mapping reads this value.

| Tactic | Rule keywords / signals |
|---|---|
| `discovery` | discovery, recon, geolocation, system info, list, enumeration, scan |
| `execution` | exec, run_binary, suspicious_binary, interpreter, command, fork |
| `persistence` | cron, systemd, service install, startup, autorun, ssh key add |
| `defense_evasion` | drift, tamper, log delete, history wipe, masquerade, base64-encoded |
| `credential_access` | credential, keychain, /etc/shadow, kubernetes secret, token, dump |
| `lateral_movement` | lateral, kubectl exec, pivot, ssh from container, network in cluster |
| `collection` | tar, copy of /etc, screenshot, clipboard, archive |
| `c2` | outbound, c2, dns tunneling, http_request, reverse shell, beacon |
| `exfiltration` | exfil, large outbound, dns exfil, scp out, curl --upload |
| `impact` | crypto, miner, ransomware, destructive, drop tables |

If the rule sits cleanly in two tactics (e.g. "Reverse Shell" → `c2` + `execution`), pick the more specific one for the watchlist mapping (`c2`) and record both on `case.tactic_secondary` for the report.

**Process tree (preferred — Sysdig MCP).** If `mcp_sysdig_available` and the threat has an `event_id` (the Threats Engine returns `securityEvent` references with IDs), call `mcp__sysdig__get_event_process_tree` with the event ID to retrieve the structured process tree. Store the parsed result (parent → child chain, command lines, sha256 if present) on `case.process_tree`.

**Process evidence from `aiGeneratedDescription` (always runs — useful even alongside the structured tree).** The description carries natural-language context the structured tree doesn't ("locale repeatedly", "curl --upload to external IP"). Parse it for process names (e.g. `systemd`, `sshd`, `bash`, `curl`, `wget`, `nc`, `nslookup`) and chain hints ("spawned by", "child of"). Store as `case.process_evidence` (list of strings).

The two are complementary: `case.process_tree` is structured ground truth, `case.process_evidence` is the AI's narrative read of the same chain. The report renders both in "What happened" — the tree as a tree, the evidence as a one-liner.

Store the threat, classification, secondary tactic (if any), process tree (if available), and process evidence on the working case object.

### Phase 2 — Investigate (free-form, signal-driven)

**Goal:** reconstruct the full attack chain starting from the user's pick. Span multiple threat groups, multiple resources, multiple event sources if the signals lead there. The chain is the deliverable — phase boundaries from earlier versions of this skill (e.g. separate enrichment / classifier / synthesis stages) are explicitly *not* prescribed steps anymore.

Tell the user what you're doing as you go. Examples of good status updates:

- "Process tree shows Tomcat → bash → xmrig — looks like miner persistence. Looking for related cluster activity."
- "IMDS theft on the host. Expanding to CloudTrail in the same AWS account."
- "Found two more threat groups on the same account in the same hour — folding them in as the same campaign."
- "Vuln scan for the image rejected — falling back to MCP image-findings."

#### Available signals (chase them when relevant)

These are the ingredients. The order is yours.

- **Tenant-wide critical sweep (sanity check)** — once early in Phase 2, call `mcp__sysdig__list_runtime_events` with `filter_expr = "severity in (0,1,2,3)"` and *no scope filter* across the ±2h window around the trigger. Catches cross-domain signals the cluster/account-filtered queries miss (GitHub `cloudProvider.account.id`, Okta `cloudProvider.tenantId`, anything without K8s labels). Fold in any hit whose image-org, repo name, or actor matches the trigger.
- **Process tree** of the trigger event — `mcp__sysdig__get_event_process_tree`. Almost always the highest-yield single artifact. Falls back to `aiGeneratedDescription` parsing if the MCP returns empty.
- **Prior events on the affected resource** — last 7 days, via `mcp__sysdig__list_runtime_events` with a `filter_expr` matching the workload (`kubernetes.cluster.name + namespace + workload`) or host (`host.hostName`). For K8s workloads, also pull host-level events on the same node — escapes hide there.
- **Cluster-wide activity in a ±2h window** around the trigger. Same MCP tool, three filters in parallel:
  - `kubernetes.cluster.name = "<cluster>" and source = "syscall"` (other resources in the cluster)
  - `kubernetes.cluster.name = "<cluster>" and source = "k8s_audit"` (Attach/Exec Pod, Deployment Created, etc.)
  - `kubernetes.cluster.name = "<cluster>" and source = "cloudtrail"` (cluster-tagged cloud events, if any)
- **Cloud-account-wide activity** when the resource has `aws.accountId` / `azure.subscriptionId` / `gcp.projectId`. CloudTrail / agentless-aws-ml / agentless-okta-ml events live under the *account* dimension, not the cluster. **This is the difference between catching multi-stage cross-cloud attacks (IMDS credential theft → IAM access-key creation → CloudTrail tampering → S3 exfiltration) and missing them.** Filter: `aws.accountId = "<account>" and source in ("cloudtrail", "agentless-aws-ml")`.
- **Other threat groups in this incident** — fold them into the same case — do not investigate separately. Other threat groups already tagged in Phase 1 as part of this incident — pull their constituent events / resources via `fetch_threats.py --group <id>` to merge into the chain. If new groups appear in the cluster window during Phase 2 investigation, fold them in too. Cross-type is allowed: a CLOUD threat may be the same incident as a K8S_WORKLOAD threat.
- **Sibling resources / posture / RBAC** via `mcp__sysdig__run_sysql`. SysQL schema differs between tenants — adjust query shape if rejected. Example queries: `MATCH KubeWorkload AS wl WHERE wl.cluster = '<c>' RETURN wl.namespace, wl.name`, `MATCH Resource VIOLATES Control`, `MATCH KubeServiceAccount HAS KubeRoleBinding HAS KubeClusterRole`.
- **Vulnerability surface** — `python3 $SKILL_DIR/scripts/fetch_vulns.py` (with `--cluster --namespace --workload`, `--host`, or `--host --image`). On `scan_found: false` or image-label rejection, fall back to `mcp__sysdig__list_vulnerability_findings_by_image` with the image digest from the threat detail.
- **External CTI** for the top 5 critical/high CVEs that pass the MITRE-tactic gate (see `references/correlation-guide.md`): NVD, CISA KEV, Exploit-DB, GHSA via `WebFetch`. Don't fetch CTI for tactic-mismatched CVEs.
- **Sysdig threat-intel feed** via `mcp__sysdig__fetch_threat_intelligence_feed` — Sysdig-curated CVEs / zero-days / active-attack notes. Cross-reference any IOCs you collect.
- **VirusTotal** for binary IOCs when a SHA256 surfaces on event fields and a VT key is present (Phase 0 records the env var). When the threat lacks `proc.sha256`, look across other events on the same container — drift detection events typically carry the hash.
- **GeoIP** for network IOCs via `curl https://ipinfo.io/<ip>/json` (fallback `ip-api.com`).

#### Patterns to recognise (not steps to execute)

When any of these rule names fire in the data you've pulled, that's the signal to expand. The action column is *what direction to look*, not a fixed query.

| Watchlist hit | Suggests | Expand toward |
|---|---|---|
| `Contact EC2 Instance Metadata Service*`, `Read Service Account Token` | IAM/IMDS credential theft | CloudTrail by `aws.accountId` for the same hour |
| `Create Access Key for User`, `IAM*Backdoor*`, `EC2 Instance Create Access Key for User` | Persistent cloud creds | Cross-reference K8s pods active in the same window; pull RBAC of any related SA |
| `CloudTrail Logging Disabled`, `CloudTrail Trail Deleted`, `Delete Bucket Public Access Block` | Defense evasion / exfil prep | The full cloud-account sweep — what else did the same identity do? |
| `S3 Bucket Made Public`, `Suspicious S3 Activity`, `Cloud Storage Access from Unexpected Identity` | Data exfil | CloudTrail S3 events; identify which bucket and what objects |
| `Launch Root User Container`, `Privileged Pod Created`, `Mounted Sensitive Path` | Privesc | Sibling pods in the same cluster + RBAC of the SA |
| `Attach/Exec Pod`, `kubectl Exec to Sensitive Namespace` | Lateral movement | Pods exec'd into; their image, process tree, prior events |
| `Binary Drift`, `Linux Kernel Module Injection Detected`, `Malware Detection`, `Drop and Execute /tmp Binary` | Active runtime compromise | Process tree, hash → VT, image scan |
| `Detected reconnaissance script` | Recon | Prior events on same resource, what came after |
| `Suspicious AI Prompt detected` | Prompt-injection RCE | Process tree + `aiGeneratedDescription` to confirm cmd matches prompt |

#### MITRE-tactic correlation

Read `references/correlation-guide.md` for the MITRE-tactic gate and 1–5 scoring heuristics. Render only pairs ≥ 4 in the case body. Boosts (cap at 5): KEV +1, VT malicious_count≥5 +1.

#### Stop conditions

You're done when:
- The chain has a coherent narrative (initial access → execution → … → impact, or bounded by available data), AND
- You've followed every watchlist hit at least one hop, AND
- You've asked yourself *"is there another threat group within the cluster + ±2h / account + ±2h window that belongs to this same incident?"* — and either folded it in or recorded why not.

If you find yourself making more than ~4 follow-on calls per signal, stop and synthesise. Diminishing returns.

### Phase 3 — Synthesise & report

Three steps, in this order:

1. **Ask the user for the report format** via `AskUserQuestion`: "How do you want the report rendered? `Markdown` (default — plays nice with Jira/PagerDuty handoff) / `HTML` (renders Mermaid diagrams in browser, self-contained) / `Both`."

   If `AskUserQuestion` is not available, default to `Markdown` and mention HTML as a follow-up option in the summary.

2. **Write the file(s) to disk.** Base path: `/tmp/sysdig-runtime-investigate-<event_id_short>-<UTC-yyyymmdd-hhmm>`.
   - `Markdown` → write `<base>.md` with Block 1 of `references/reporting-templates.md` verbatim. Always written when chosen — also the body of Jira/PagerDuty handoff downstream.
   - `HTML` → write `<base>.html` using Block 4 wrapper from the same file. The Block 1 markdown content is pasted into the wrapper's `<script id="md">` block. Marked + mermaid CDN scripts render the page in the browser.
   - `Both` → write both files, same base name.

3. **Print a 2-paragraph summary to the user.** Use Block 0 of `reporting-templates.md` — short, no tables. Cite the file path(s) so they can read it if they want. Then ask `AskUserQuestion`: "Where do you want to report this case?" with options derived from what Phase 0 detected (`Jira`, `PagerDuty`, `Both`, `Just show it`).

Handoff:
- **Jira** → Build Block 2 payload from the templates. Body = file content. If project key is unknown, call `mcp__atlassian__getVisibleJiraProjects` and ask the user. Create via `mcp__atlassian__createJiraIssue`. Capture key + URL and surface them.
- **PagerDuty** → Build Block 3 payload. `custom_details.case` = file content (truncate to ~30 KB if larger). Send via:

  ```bash
  printf '%s' "$PAYLOAD_JSON" | curl -sS -X POST \
    -H "Content-Type: application/json" \
    --data-binary @- \
    https://events.pagerduty.com/v2/enqueue
  ```

  Capture the `dedup_key` and incident URL from the response.
- **Just show** → no extra action; the file path was already cited in the summary.

After handoff, surface the link/key (if any) to the user — one short line.

## Error Handling

| Situation | Behavior |
|-----------|----------|
| Sysdig auth missing | Stop in Phase 0 with the regions table and `export` instructions. No data calls. |
| `fetch_threats.py --threat <id>` returns 404 | Script auto-falls-back to `--group <id>` (and tags the result `_resolved_as: "group"`); if both 404, fall back to events API for the same ID. |
| No qualifying threats / events found in Phase 1 | Tell the user, offer to widen the time window. |
| `fetch_vulns.py` returns `scan_found: false` | Try `mcp__sysdig__list_vulnerability_findings_by_image` with the image digest from the threat detail. If still nothing, record `"vulnerabilities": "no scan data"` and continue. |
| `fetch_vulns.py --image` rejected (HTTP 400 on scope label) | Script already retries with alternate label candidates; if all fail, fall back to MCP `list_vulnerability_findings_by_image`. |
| Sysdig MCP not loaded | SysQL / process tree / threat-intel-feed unavailable. Record limitations as needed. The investigation still produces a case from threats + events + vulns + external CTI. |
| `WebFetch` to a public CTI source fails or rate-limits | Mark that source `lookup_failed` and continue. Don't retry in a loop. |
| VirusTotal API key not detected | Skip VT. Note `"vt": "skipped — no API key"`. |
| No Jira and no PagerDuty detected | Ask whether the user wants to configure one or just show the file path. |
| Atlassian MCP / PagerDuty curl errors during handoff | Surface the error, print the file path, offer to retry or switch destination. |
| `mcp__sysdig__list_runtime_events` cursor pagination drops `filter_expr` | Known MCP quirk — paginating with `cursor` returns events from the wrong scope. Don't paginate; widen `scope_hours` and re-issue with the original filter. |
| A list_runtime_events call returns >100 events | Tighten the time window or split the filter. Never silently drop the section — record a "result truncated" limitation. |
| CloudTrail integration not present in tenant | Cloud-account sweep returns empty. Note `"cloudtrail": "no integration in tenant"` on the case; flag in the summary that S3 / IAM / IMDS cloud-API signals were unavailable. |
| SysQL schema rejects a query | Try the alternate relation shapes (`HAS` vs `BINDS_TO`, etc.). If all fail, record the limitation and continue. The skill should not block on schema mismatches. |

## Important rules

- **Investigate freely.** Phases are a floor. The chosen threat is a starting point; the goal is the full attack chain, including events and threat groups outside the original pick.
- **Keep the user informed** — one-line status updates between non-trivial calls. What you found, what you're doing next.
- **Two-tier output.** Full markdown to `/tmp/sysdig-runtime-investigate-<event_id>-<UTC-ts>.md`. User-facing chat output is a 2-paragraph summary plus the file path. Tables and full evidence tables go to the file, never to chat.
- **Cite every claim.** Event IDs, MCP tool names, REST paths, external URLs.
- **Don't fabricate.** If a CVE / IOC / process didn't appear in the data, don't write it.
- **Never invoke destructive remediation.** This skill investigates and reports only. Remediation goes to `/sysdig-remediate`.
- **Always include `event.id`** in the file footer and any handoff payload — it's the audit trail.
- **Always assign a MITRE tactic** to the trigger. It informs the correlation gate and the watchlist mapping.
- **Don't write cache or state to disk.** The `/tmp` report file is the only persistent artifact.

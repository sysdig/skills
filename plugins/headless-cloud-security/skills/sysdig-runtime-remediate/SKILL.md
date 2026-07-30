---
name: sysdig-runtime-remediate
description: >
  Close the runtime loop on a Sysdig-detected threat: turn the
  investigation context into proposed response actions, analyse the
  blast radius on the affected workload, and execute (or file) the
  actions the user approves — one at a time, with explicit
  confirmation. Triggers: "remediate this runtime threat",
  "respond to event <id>", "act on this incident",
  "isolate / kill / pause that container",
  "/sysdig-runtime-remediate". Not for vulnerability fixes (use
  sysdig-remediate) or threat investigation itself (use
  sysdig-runtime-investigate).
allowed-tools:
  - Read
  - Write
  - Glob
  - Grep
  - AskUserQuestion
  - Bash(command -v*)
  - Bash(kubectl get*)
  - Bash(kubectl describe*)
  - Bash(kubectl logs*)
  - Bash(kubectl version*)
  - Bash(kubectl config current-context*)
  - Bash(kubectl auth can-i*)
  - Bash(kubectl patch*)
  - Bash(kubectl label*)
  - Bash(kubectl annotate*)
  - Bash(kubectl scale*)
  - Bash(kubectl delete networkpolicy*)
  - Bash(kubectl rollout*)
  - Bash(aws sts get-caller-identity*)
  - Bash(aws iam get-role*)
  - Bash(aws iam list-*)
  - Bash(aws iam get-role-policy*)
  - Bash(aws iam get-access-key-last-used*)
  - Bash(aws cloudtrail lookup-events*)
  - Bash(aws iam attach-role-policy*)
  - Bash(aws iam detach-role-policy*)
  - Bash(aws iam delete-access-key*)
  - Bash(aws iam update-access-key*)
  - Bash(curl *events.pagerduty.com*)
  - mcp__secure-mcp-server__list_runtime_events
  - mcp__secure-mcp-server__get_event_info
  - mcp__secure-mcp-server__get_event_process_tree
  - mcp__secure-mcp-server__run_sysql
  - mcp__secure-mcp-server__get_customer_settings
  - mcp__secure-mcp-server__list_response_actions
  - mcp__secure-mcp-server__submit_response_action
  - mcp__secure-mcp-server__get_response_action_status
  - mcp__secure-mcp-server__list_response_action_executions
  - mcp__secure-mcp-server__undo_response_action
  - mcp__secure-mcp-server__get_capture_storage
  - mcp__atlassian__getVisibleJiraProjects
  - mcp__atlassian__createJiraIssue
version: 1.0.1
---

## First-run notice (Public Beta)

Before doing any other work for this skill, perform this one-time check:

1. If `~/.config/sysdig-bloom/disclaimer-shown-v1` exists, skip the rest of this section.
2. Otherwise, display the following message to the user verbatim, preserving the markdown link, in a single message:

   > This plugin is a Public Beta release. It is provided "as is" and "as available," without warranties of any kind. By installing this plugin, you agree to the Public Beta Terms available in the [repository readme](https://github.com/sysdig/skills#public-beta-terms).

3. Create the marker file `~/.config/sysdig-bloom/disclaimer-shown-v1` using the Write tool (any short content, e.g. the current UTC timestamp).
4. Then continue with the user's request.

When you need to ask a question, get confirmation, or present choices, use the `AskUserQuestion` tool if available.

## Input

Three invocation forms:

- `/sysdig-runtime-remediate` — no argument. Ask the user for an `event_id`.
- `/sysdig-runtime-remediate <event_id>` — directed. Load the case for that event.
- Auto-handoff from `sysdig-runtime-investigate` — the predecessor skill invokes this one with the event_id already loaded. Open with: _"`sysdig-runtime-investigate` handed off `<event_id>`. Loading the case file and starting Step B (architecture probe)."_

## Principles

The flow is **Steps A through F**, not rigid phases. Steps describe shape; the LLM decides ordering within and across them when the signals support it. The hard guardrails are non-negotiable:

- **Read-only probing runs immediately.** Step B's kubectl/SysQL/AWS reads are read-only; no confirmation gate beyond initial per-session authorization for the surface.
- **Every destructive action requires its own explicit yes.** Per Bloom S-01 and S-03: no batch confirmation, no implicit consent.
- **Show before doing.** For every action, restate the exact payload, the expected effect, what it breaks (per [`references/consequence-analysis-guide.md`](references/consequence-analysis-guide.md)), reversibility, and the undo path. Then ask.
- **Just-in-time authorization for kubectl / AWS.** Detect availability at the start. Only ask to authorize the surface when an action actually needs it. Session-scoped (in-memory only, never persisted).
- **Narrate every step.** Before every tool call — SysQL query, kubectl, AWS CLI, Response Actions API submission, MCP write — say what you're about to do.
- **One question per turn.** Never bundle.
- **Status vocabulary.** `done` / `pending` / `in_progress` / `failed` / `skipped` / `cleared` / `still_active` / `inconclusive`.
- **Cite every claim.** Findings in Step B reference their source (SysQL query, kubectl command, AWS API call, MCP tool, case file line).
- **Don't fabricate.** If the case file didn't say what role the pod assumes, don't guess. Say "unknown — probe with X" or ask.

## Steps

```
Step A ──→ Step B ──→ Step C ──→ Step D ──→ Step E ──→ Step F
Understand  Probe     Propose    Execute    Watch       Report &
context     blast     actions    (per-      (~5 min)    persist
            radius                action)
```

### Step 0 — Preflight

Run all of these before Step A. Surface a single one-line connectivity summary at the end.

1. **Trust preamble.** Present [`references/trust-preamble.md`](references/trust-preamble.md) verbatim. Do not pause for confirmation; the preamble is informational.
2. **MCP authentication preflight (hard-block).** Run the preflight in [`references/auth-preflight.md`](references/auth-preflight.md) and follow its instructions exactly. This skill requires the Sysdig MCP for state, event lookups, and Response Actions — degraded mode is not supported. If the preflight returns State 2 (registered but not authenticated) or State 3 (not reachable), emit its verbatim message and **stop** — no data calls, no state read, no file writes.
3. **Response Actions canary.** Call `mcp__secure-mcp-server__list_response_actions` once (no arguments). If it errors, surface the message and stop — the Response Actions API is unreachable, so nothing can be remediated. Success only proves the API is reachable and returns the tenant-wide **capability catalog** — it does **not** mean any given action can execute on *this* cluster or host. Per-scope **responder availability** (a CLUSTER responder may not be deployed on the target cluster) and **remote-storage configuration** (needed by output-producing actions) are tenant/cluster-specific and are confirmed later, in Step C and at submit time. Do not promise the user an action is runnable on the strength of this canary alone.
4. **kubectl & AWS availability detection (no authorization yet).** Run `command -v kubectl` and `command -v aws`. Record availability. Do **not** ask to authorize either surface yet; that happens in Step D when an action actually needs it.
5. **Ticketing probe (no-block).** Look for `mcp__atlassian__*` (Jira) and the standard PagerDuty env vars. Used by the file-as-ticket fallback in Step D.

Connectivity line example:

> _Sysdig ✓ · MCP ✓ · Response Actions API ✓ · kubectl detected (unauthorized) · aws detected (unauthorized) · Jira ✓ · PagerDuty —. Light tier will use Jira if you decline an action._

### Step A — Understand the context

Goal: load the threat into memory along with an explicit **inventory** of what's known and what's missing.

1. **Resolve the input.**
   - Auto-handoff or `<event_id>` argument → load the case directly.
   - No argument → ask for an event ID via `AskUserQuestion`.
2. **Find the prior case file.** Look for `/tmp/sysdig-runtime-investigate-<event_id_short>-*.md`. If it exists, read it and treat the contents as authoritative for what the threat is and where it lives.
3. **Gating prompt — no prior case.** If no case file exists, ask via `AskUserQuestion` how to proceed:
   - **Auto-investigate (recommended)** — announce the handoff and invoke `sysdig-runtime-investigate <event_id>`. When it completes, read the new case file and continue.
   - **Lightweight** — do minimal inline investigation in Step B (process tree, immediate workload metadata, no cross-cluster sweep). No case file written.
   - **Raw** — proceed without investigation. Banner-warn: _"Consequence analysis will be best-effort — much of Step B will say 'unknown'."_
4. **Inventory.** Print a structured summary to the user — what's known (from case file + event lookup + state) and what's missing:
   ```
   Known:
     - event.id, threat type, MITRE tactic
     - cluster, namespace, workload kind/name, container id, process tree
     - cloud account / identity (AWS / GCP / Azure, if surfaced), correlated CVEs
     - prior investigation handoff (Jira/PagerDuty ticket, if any)
   Gaps:
     - <e.g.> ServiceAccount and RBAC not yet enumerated
     - <e.g.> Cloud identity not confirmed
     - <e.g.> Inbound/outbound Service map unknown
   ```

### Step B — Architecture & blast-radius probe (read-only)

Goal: produce the mini-map described in [`references/consequence-analysis-guide.md`](references/consequence-analysis-guide.md). Read-only — no destructive ops here, no authorization gate beyond per-surface read access.

1. **SysQL first.** Run the queries in [`references/architecture-probing.md`](references/architecture-probing.md) under the "Sysdig MCP — SysQL recipes" section. Workload identity, Service/Ingress map, ServiceAccount + RBAC, cloud identity.
2. **kubectl read-only (optional).** If kubectl is detected and the user has not authorized any kubectl access yet, **first verify the local context actually points at the threat's cluster** — don't ask for a grant you can't use. Run `kubectl config current-context` (read-only, pre-authorized) and compare it against the threat's `kubernetes.cluster.name`. If they clearly **mismatch**, say so plainly — _"Local kube-context is `<ctx>`, but the threat is on `<cluster>`; kubectl probing here would target the wrong cluster"_ — and do **not** offer the grant. Instead offer to skip kubectl (continue MCP-only, degraded) or let the user switch context and re-run Step B. Only when the context matches (or you can't tell) ask: _"Authorize **read-only** kubectl access (`get`, `describe`, `logs`) for cluster `<context>` for this session? This lets me probe pod ownership, NetworkPolicy state, PDB/HPA constraints, and sidecars. yes / read-only / no."_ On yes or read-only, run the kubectl recipes from `architecture-probing.md`. On no, declare the gap and continue with degraded fidelity.
3. **Cloud identity read-only (optional).** If the threat implicates cloud identity (case file mentions IRSA / Workload Identity, IMDS access, IAM role usage), probe it as follows. The out-of-band CLI path here is worked through with **AWS** — for **GCP / Azure**, the local CLI recipes are not bundled, so rely on the SysQL cloud-identity recipe plus the in-product **CLOUD responder** actions (`FETCH_CLOUD_LOGS`, `IAM_QUARANTINE`), which are provider-uniform — see [`references/response-actions-catalog.md`](references/response-actions-catalog.md). For AWS, when the AWS CLI is detected, **first verify the active credentials match the threat's account.** Run `aws sts get-caller-identity` (read-only, pre-authorized) and compare the returned `Account` against the threat's `aws.accountId`. If they **mismatch**, say so — _"Active AWS profile is account `<id>`, but the threat is in `<accountId>`; these reads would hit the wrong account"_ — and do **not** offer the grant; offer to skip (note the cloud-identity gap) or let the user switch profile and re-run. Only when the account matches (or you can't tell) ask: _"Authorize **read-only** AWS CLI access with profile `<profile>` for account `<id>` for this session? This lets me check the IAM role, attached policies, and recent CloudTrail activity. yes / read-only / no."_ On yes or read-only, run the AWS recipes from `architecture-probing.md`.
4. **Render the mini-map.** Use the shape shown in `consequence-analysis-guide.md`. Lead with workload identity, then inbound, outbound, sidecars, cloud identity, PDB/HPA, RBAC. Cite the source for every line.

### Step C — Propose actions with consequence analysis

Goal: a single, ordered checklist of candidate actions, each with its full consequence analysis. Accept user response as either checkbox selections or natural language.

1. **Discover applicable actions.** Call `mcp__secure-mcp-server__list_response_actions` with `context_event_id: <event_id>` to get Sysdig's tenant-specific catalog with parameter schemas, scoped to the event's responder context. Two outcomes:
   - **Non-empty** → treat it as the executable set for this event; propose only from it.
   - **Empty (`{"data":[]}`)** → this is **inconclusive, not "nothing is possible"** (the API can't always resolve responder availability from event context alone). Fall back to the full catalog (call `list_response_actions` with no `context_event_id`) and apply the availability preflight below.

   Pair the catalog with the threat patterns in [`references/threat-patterns.md`](references/threat-patterns.md) and your reasoning over the investigation + probe findings.
2. **Availability preflight (before you propose).** There is no read-only "list responders / storage config" endpoint, so confirm what can actually run using the cheap signals available, and be honest about residual uncertainty:
   - **Responder scope.** Every action has a `responderType` (`HOST` / `CLUSTER` / `CLOUD`). A CLUSTER responder may not be deployed on the target cluster; submitting then returns HTTP 400 `responder_not_found`. Use `list_response_actions` with `context_event_id` (if non-empty) and `mcp__secure-mcp-server__list_response_action_executions` (which `responderType`s have recently **completed** in this tenant) as hints. When unconfirmed, label the action's availability `unconfirmed` rather than `available`.
   - **Storage dependency.** `GET_LOGS`, `CAPTURE`, and `FILE_ACQUIRE` write artifacts and require capture storage; without it they return HTTP 412 `storage_not_configured`. Before proposing them, call `mcp__secure-mcp-server__get_capture_storage`: if it returns `isEnabled: false` or no bucket, mark these storage-dependent actions `unavailable` up front rather than discovering the 412 at submit.
   - **Parameter resolvability.** HOST + container-scoped actions (`KILL_CONTAINER`, `STOP_CONTAINER`, `PAUSE_CONTAINER`, container-scoped `FILE_ACQUIRE`) need a runtime `container.id`. If neither the event payload, the process tree, nor a context-matched kubectl can supply it, mark the action **un-parameterizable** and don't propose it as runnable.
   - **Fail-fast at execution.** The first submit of a given responder scope (or the first storage-dependent action) is the authoritative capability probe. On `responder_not_found`, mark **all** remaining same-scope candidates `unavailable`; on `storage_not_configured`, mark **all** storage-dependent candidates `unavailable` — then re-present the revised set instead of marching the user through actions that will fail identically. See Error handling.
3. **Build the checklist.** For each candidate action, render the format from `consequence-analysis-guide.md`:
   ```
   [ ] <ACTION_TYPE> (<short scope, e.g. "PID 4823 in container abc123">)
       What it does:  <one sentence>
       Expected:      <intended effect, where it shows up>
       Breaks:        <concrete consequences pulled from Step B>
       Reversibility: <yes via undo / no — explain how>
       Surface:       <Sysdig API / kubectl / AWS CLI>
       Responder:     <HOST / CLUSTER / CLOUD — availability: confirmed | unconfirmed>
       Preconditions: <e.g. needs RA storage / needs container.id (resolved? y/n) / needs CLUSTER responder>
   ```
   If an action's availability is `unconfirmed` or a precondition is unmet, say so in the line and order it accordingly — don't present a likely-to-fail action as the confident first move.
4. **Order with explicit reasoning.** Lead the list with the action you'd recommend first; explain *why this order* in one or two sentences referencing what Step B found. Per the generic principle in `threat-patterns.md`: evidence first, containment second, destruction last. Prefer actions whose availability is **confirmed** over `unconfirmed` ones when they achieve the same containment.
5. **Ask once.** Via `AskUserQuestion` with a free-form option: _"Pick which actions to run, in this order, or describe what you'd prefer in your own words."_ Accept structured selections or free-form descriptions; parse natural-language responses against the action list and confirm your interpretation back to the user before proceeding.

### Step D — Execute, one at a time, with strong announcement

For each accepted action **in the proposed order**:

1. **Re-state the action.** Even if you proposed it three turns ago, restate immediately before execution: exact payload, expected effect, what to watch, undo path, cancel option.
2. **Repeat the disclaimer when destructive.** If `reversibility = no`, include: _"This action is **not reversible** by the API. If you change your mind, recovery requires `<concrete manual step>`."_
3. **Just-in-time authorization (if needed).** If the action requires a surface (`kubectl` mutating, `aws` mutating) and you only have read-only authorization for that surface, ask now: _"This action needs **write** access to `<surface>` (specifically: `<command shape>`). Authorize for this action? yes / no (file as ticket instead)."_
4. **Execute.**
   - Sysdig API: call `mcp__secure-mcp-server__submit_response_action` with `action_type` and `parameters`. Capture the execution `id` from the response, then poll `mcp__secure-mcp-server__get_response_action_status` with that `action_execution_id` until status is `COMPLETED` or `FAILED`. Surface the result inline.
   - kubectl: run the exact command shown in step 1. Capture stdout/exit-code.
   - AWS CLI: run the exact command shown in step 1. Capture stdout/exit-code.
5. **Decline → file-as-ticket fallback.** If the user declines this action, offer: _"File this as a Jira ticket / PagerDuty incident with the exact command and rationale, so a human can execute manually? yes / skip."_ Build the payload from the action's rendered block (Step C) plus the consequence analysis from Step B.
6. **Narrate result.** One line before the next action: _"`<ACTION>` `<status>`. `<key detail>`. Next: `<NEXT_ACTION>`."_

### Step E — Verification watcher

Only if at least one action ran (status `executed`). Skip if everything was filed or skipped.

1. Capture the workload selector (cluster + namespace + workload, or container id, or pod name — whichever survives the action).
2. Poll `mcp__secure-mcp-server__list_runtime_events` at ~30 s intervals, up to 10 polls (~5 min), filtering for the **same rule that fired** on the **same workload**.
3. Narrate progress: _"Watcher 1/10: 0 re-fires. ... 5/10: 0 re-fires."_ Once per minute is plenty; don't spam.
4. Close as:
   - `cleared` — full window, no re-fires.
   - `still_active` — at least one re-fire. Surface the new event id, prompt the user to consider next steps (escalate to a heavier action, file a ticket).
   - `inconclusive` — the workload disappeared mid-window (action was successful enough to remove the watch target). Treat as success-with-caveat.

### Step F — Report

1. **Present the report inline.** Render the following sections in the chat:
   - Header: event ID, threat summary, remediation outcome.
   - Context inventory from Step A.
   - Architecture mini-map from Step B (mark which lines came from which probe).
   - Action table: action / proposed reason / user decision / execution status / undo URL.
   - Watcher timeline from Step E.
   - Audit trail with UTC timestamps for every action taken.
2. **Append to the investigation ticket** if one was created during this session (Jira/PagerDuty). Add a section "Remediation log" with the action table.
3. **2-paragraph chat summary.** Lead with the outcome (`cleared` / `still_active` / `inconclusive`), then the actions taken. Mention any filed tickets explicitly.

## Error handling

Apply the canonical Bloom three-line error template (**what** / **why** / **fix**) for every failure path. Keep messages under four lines. Examples:

> Response Actions API returned 403 on `submit ISOLATE_NETWORK`.
> Your token is missing the `containment-response-actions.exec` permission.
> Either ask an admin to grant it, or pick `file as ticket` to record the proposed action and re-run after the grant.

> `submit ISOLATE_NETWORK` returned HTTP 400 `responder_not_found` (scope `clusterName:<cluster>`).
> No CLUSTER responder is deployed on that cluster — only the node/host agent is registered.
> Mark every remaining CLUSTER-scope action `unavailable`, re-present the revised set (HOST/CLOUD only, plus file-as-ticket), and recommend deploying the Sysdig cluster responder for in-product remediation. Do **not** submit the other CLUSTER actions — they fail identically.

> `submit GET_LOGS` returned HTTP 412 `storage_not_configured`.
> This action stores an artifact, but Response Actions remote storage isn't configured in the tenant.
> Mark `GET_LOGS` / `CAPTURE` / `FILE_ACQUIRE` all `unavailable` for this run; ask an admin to configure RA remote storage, or proceed with non-storage actions (ISOLATE/KILL/restart).

> kubectl probe failed: `error: You must be logged in to the server (Unauthorized)`.
> The current kube-context's credentials expired.
> Refresh with `kubectl config use-context <ctx>` / SSO login, then re-run Step B.

> Watcher couldn't find the container in `list_runtime_events`.
> The container ID is gone — the kill succeeded.
> Closing the watcher as `inconclusive` (success-with-caveat).

> A `mcp__secure-mcp-server__*` call came back **denied** (the agent refused it, not a server error).
> Prefix mismatch, not an auth/reachability failure — the Sysdig MCP server is registered under a different prefix than `secure-mcp-server`, so `allowed-tools` doesn't match.
> Run `claude mcp list`, then re-register as `secure-mcp-server` or add the real `mcp__<name>__*` to permitted tools, and re-run. See the "denied / prefix mismatch" section in [`references/mcp-setup.md`](references/mcp-setup.md). Do not retry the denied call.

## Important rules

- **Never bundle confirmations.** Every destructive action gets its own explicit yes, even when the user said "yes to all three" earlier.
- **Never execute a non-destructive action without confirmation either.** Read-only probing in Step B runs immediately, but anything in Step D — including data-gathering actions like FILE_ACQUIRE that consume tenant quota — needs a yes for that specific action.
- **Never persist surface authorizations.** kubectl/AWS authorization is per-session, in-memory only. Next session asks again.
- **Never act outside the threat's scope.** If the user asks to remediate something unrelated, refuse and point them at a fresh `/sysdig-runtime-remediate` invocation.
- **Always cite undo when an action is reversible.** Give the exact undo call — `mcp__secure-mcp-server__undo_response_action` with `action_execution_id: <id>` — in the report and in the chat summary.

## Handoff phrasing

- **When invoked from `sysdig-runtime-investigate`:** _"`sysdig-runtime-investigate` handed off `<event_id>`. Loading the case file and starting Step B."_
- **When auto-invoking investigate first:** _"No prior investigation found for `<event_id>`. Handing off to `sysdig-runtime-investigate` to build the case file — I'll resume here once it returns."_
- **When falling back to file-as-ticket:** _"You declined to execute `<ACTION>`. Filing it as a `<destination>` ticket with the exact command and rationale so a human can run it manually."_

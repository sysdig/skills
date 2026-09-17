---
name: sysdig-remediate
description: >
  Remediate one specific vulnerable container image and deliver the fix as a PR/MR, a
  tracking ticket, or both — this skill is the sole ticket creator in the Sysdig
  vulnerability workflow. Deduplicates existing work (job artifacts, Sysdig-created Jira
  tickets, external tickets and PRs) read-only, fetches Critical/High CVEs from Sysdig,
  resolves a safe fix version via chain analysis, opens a PR/MR (GitHub/GitLab) or emits
  a local patch, creates or updates the Jira ticket, records artifacts on the remediation job,
  and closes the job once the work is filed.
  Triggers: "fix the nginx image", "patch CVE-2024-1234 in api-server", "remediate
  quay.io/org/app:tag", "create a ticket for CVE-2024-9999", "file a Jira ticket for this
  image", "/sysdig-remediate <image>".
  Not for: discovery, prioritization, or slicing findings — use /sysdig-investigate.
allowed-tools:
  - Read
  - Write
  - AskUserQuestion
  - Bash(git status*)
  - Bash(git log*)
  - Bash(git diff*)
  - Bash(git apply*)
  - Bash(git checkout -b sysdig/fix-*)
  - Bash(git add*)
  - Bash(git commit -m*)
  - Bash(git push origin sysdig/fix-*)
  - Bash(git push origin --delete sysdig/fix-*)
  - Bash(gh auth status*)
  - Bash(gh search code*)
  - Bash(gh search repos*)
  - Bash(gh api repos/*)
  - Bash(gh api user*)
  - Bash(gh pr create*)
  - Bash(gh pr list*)
  - Bash(gh pr view*)
  - Bash(gh pr close*)
  - Bash(glab auth status*)
  - Bash(glab api*)
  - Bash(glab mr create*)
  - Bash(glab mr list*)
  - Bash(glab mr view*)
  - Bash(glab mr close*)
  - mcp__secure-mcp-server__get_customer_settings
  - mcp__secure-mcp-server__get_skill_state
  - mcp__secure-mcp-server__save_skill_state
  - mcp__secure-mcp-server__delete_skill_state
  - mcp__secure-mcp-server__run_sysql
  - mcp__secure-mcp-server__explore_jobs
  - mcp__secure-mcp-server__track_job
  - mcp__secure-mcp-server__close_job
  - mcp__secure-mcp-server__list_artifacts
  - mcp__secure-mcp-server__create_artifact
  - mcp__atlassian__searchJiraIssuesUsingJql
  - mcp__atlassian__createJiraIssue
  - mcp__atlassian__editJiraIssue
  - mcp__atlassian__addCommentToJiraIssue
version: 1.0.2
---

## First-run notice

Before doing any other work for this skill, follow [`references/first-run-notice.md`](references/first-run-notice.md) exactly.

*Uses: Sysdig MCP, GitHub (`gh`) or GitLab (`glab`), `git`, optional Jira MCP/CLI for tickets.*

Remediate a single vulnerable image end to end: **choose the deliverable** (ticket, PR, or both), **dedup** existing work read-only, **analyze** (Critical/High CVEs → chain analysis → safe fix version), **commit** (track the job), **execute** (open the PR and/or create/update the ticket), **record and close** (artifacts + `close_job`). This skill is the **sole ticket creator** in the Sysdig vulnerability workflow — `/sysdig-investigate` only investigates and hands off.

> **To find and prioritize which images to remediate, run `/sysdig-investigate` first.**
> It walks ranked remediation jobs (Plans flow) or slices findings ad hoc (Findings flow) and
> hands the chosen image to this skill.

## On-brand output

This skill's deliverables — PRs and Jira tickets — are rendered by their own systems, so on-brand styling doesn't apply to them. If you're ever asked to produce a custom report or document instead, keep it on-brand per [`references/on-brand-output.md`](references/on-brand-output.md) (or hand off to the `sysdig-report` skill, if it's installed) — opt-in guidance, never a requirement.

## Conversation rules

- **Narrate before every tool call.** Before invoking any tool — SysQL query, `gh` / `glab` command, `git` operation, MCP write — say what you're about to do and which tool you're using. No silent calls.
- **Announce every skill handoff.** Before invoking another skill, name it explicitly and summarize what it'll do, then wait for confirmation.
- **Pause for confirmation before any write.** Branch creation, commits, PR/MR opens, ticket creation and updates, `track_job`, and `close_job` all require an explicit user yes. Read-only queries do not.
- **One question per turn.** Never bundle compound choices. Ask one question, wait for the answer, then ask the next.
- **Status vocabulary.** When reporting outcomes, use `done` / `pending` / `in_progress` / `failed` / `skipped` plus a one-line detail.

## Input

This skill expects a single image to work on. The image can be provided in any of these ways:
- As an argument: `/sysdig-remediate quay.io/org/app:tag`
- With an `image_id`: `/sysdig-remediate quay.io/org/app:tag (image_id: <id>)`
- With a remediation job (from `/sysdig-investigate`'s handoff): `/sysdig-remediate quay.io/org/app:tag (image_id: <id>, job_id: <global_id>)`
- With an existing ticket: `/sysdig-remediate quay.io/org/app:tag (image_id: <id>, ticket: <ticket_key>)`
- Interactively: if no image is provided, ask the user to specify one or run `/sysdig-investigate` to select from a prioritized list.

`job_id` is the tracked remediation job's `global_id` — when present, dedup (step 2) uses it directly instead of re-discovering the job. `ticket:` pre-selects a ticket to update instead of creating one.

## State

Read state via `get_skill_state`, write via `save_skill_state`. Schema and rules: see [references/state.md](references/state.md). Treat null as { "version": 0 }. **State is a convenience cache only** — image→repo mappings, version chains, reviewers. It is never a dedup authority: what work already exists is established from job artifacts and external searches (step 2), all server-side.

## Steps

### 0. Trust preamble

**Always present this before asking any questions.** See [`references/trust-preamble.md`](references/trust-preamble.md) for the full text. After presenting the preamble, proceed directly to step 0b — the preamble is informational, do not ask for confirmation.

### 0b. Prerequisites

Run all checks before any real work. Announce each result on its own line so the user knows which paths are open before they commit to a flow.

1. **Sysdig MCP authentication preflight** — required. Run the preflight in [`references/auth-preflight.md`](references/auth-preflight.md) and follow its instructions exactly. If it tells you to abort, abort — do not call any MCP tools or perform other side effects. If a tool call later fails during normal operation, use the diagnostic checklist in [`references/mcp-setup.md`](references/mcp-setup.md) to identify the specific failure. A **denied** `mcp__secure-mcp-server__*` call (the agent refuses it rather than the server erroring) is a **prefix mismatch**, not unreachability — apply the "denied / prefix mismatch" fix in that reference instead of retrying.
2. **Source control** — run the selection algorithm in [`references/source_control.md`](references/source_control.md) to detect a configured GitHub (`gh`/MCP), GitLab (`glab`/MCP), or a local folder the user points at. Record `source.kind` ∈ {`github`, `gitlab`, `local`, `none`} and `source.handle` (org/group/path) in working memory; later steps key off these. `none` is allowed — it just rules out the PR deliverable.
3. **Ticketing** — detect whether a Jira MCP/CLI is reachable, per [`references/ticketing.md`](references/ticketing.md). Record availability; absence just rules out the ticket deliverable.

Announce a one-line status summary, e.g.:

> _Sysdig MCP: connected · GitHub (`gh`): connected · Jira: connected._

If the **Sysdig MCP** check fails, do not proceed — the diagnostic checklist above will have already reported the specific problem and fix.

If **both** source control and ticketing are unavailable, stop:

> I can't deliver anything for `<image>` — no source forge (for a PR) and no ticketing system (for a ticket) is configured. Configure at least one (see `references/source_control.md` / `references/ticketing.md`), then re-run.

### 1. Load project context

Call the MCP tool `get_skill_state` with `{ "skill_state": "remediate" }`. A `null` response means no state exists yet — start with `{ "version": 0 }`. Note any existing:
- `image_repo_mappings` — reuse known repo for this image instead of re-searching (confirm with user if older than 30 days)
- `repo_reviewers` — use as top-priority signal for PR reviewers (step 3c)
- `vulnerability_resolutions` — skip re-resolution if the same package+from_version was already verified clean
- `version_chains` — skip re-analysis if the same package+version was already investigated
- `ticket_assignees` — prior confirmed assignees per image (a hint for step 5b, never an authority)

**Resume.** If `remediation_history` has at least one entry from the last 14 days, surface a resume summary to the user before continuing — name the most recent image, the date, the PR or ticket key if present, and ask what to do next:

> _"Last session: remediated `quay.io/myorg/my-service:1.2.3` on 2026-06-22 — PR myorg/my-service#42, ticket PROJ-123. Continue with a new image, refresh state for that one, or pick up where it stalled?"_

Wait for the user's answer before proceeding.

### 1b. Choose the deliverable

Ask upfront what this session should produce (AskUserQuestion), before any analysis:

> _"What should this remediation deliver for `<image>`?"_
> 1. **PR + ticket (recommended)** — open the fix PR and file/update a tracking ticket that references it.
> 2. **PR only** — open the fix PR, no ticket.
> 3. **Ticket only** — file/update a tracking ticket with the full analysis; the PR can follow later.

Constrain the options by what step 0b found: no forge → only "Ticket only"; no ticketing → only "PR only"; a `ticket:` argument → the ticket half means *updating that ticket*. If the choice implies an integration that is detected but missing credentials, ask for the missing configuration before proceeding.

Record the choice as `deliverable` ∈ {`both`, `pr`, `ticket`} in working memory. Every later step keys off it. The user can change it later (e.g. downgrade to ticket-only when no safe fix exists) — renegotiate explicitly, never silently.

### 2. Dedup — strictly read-only

Before any analysis, establish what work already exists. **No writes in this step**: no `track_job`, no ticket or PR creation, no artifacts. Report what exists and let the user decide to adopt, update, or create fresh.

**a. Remediation job + artifacts.**
- If a `job_id` was handed in, use it directly: `list_artifacts(parent_kind: "job", parent_id: <job_id>)`.
- Otherwise call `explore_jobs` to locate the job. `explore_jobs` requires a `target_measure` and returns a ranked page, not a global by-image search. Pass `target_measure: "findings"` and the widest scope (omit `zone_ids`/`scope`) with `states: ["open", "in_progress"]`, then look for a row matching the image reference. This is **best-effort**: treat "no row" as *"no tracked job found here"*, not *"no tracked job exists"* — fall back to the external search (step b) and the user's decision. If a matching row has `tracked: true`, fetch its artifacts with `list_artifacts`. If `tracked: false` — or no row matches — skip the artifact lookup. **Never call `track_job` here** — tracking-to-check writes a permanent catalog row for a job the user may never commit to.
- Keep the job row (id, `tracked`, ranking) in working memory for steps 4 and 6.
- Existing `jira_ticket` artifacts → adoption candidates for the ticket half. Existing `pull_request` artifacts → check the PR's current state in step b.

**b. External search.**
- Jira (when connected): search open tickets by image-name fragment in summaries, the full image reference in descriptions, **and the Critical/High CVE ids** — tickets created by Sysdig's own Jira integration reliably name the CVE even when the image pullstring is formatted differently, and this text search is the only way they're discoverable. Bound the CVE probe: **one JQL query**, ORing at most the ~10 most notable CVE ids (KEV / exploit-flagged first, then CVSS descending) — never one search per CVE; an image can carry hundreds. **Parenthesize the OR group** (JQL's AND binds tighter than OR — without parens the open-tickets filter silently applies to the last clause only) and fetch a small page with minimal fields (e.g. `maxResults` 20; key/summary/status is enough to present hits). E.g. JQL `(summary ~ "<image-name>" OR description ~ "<image_reference>" OR text ~ "<cve_id_1>" OR text ~ "<cve_id_2>") AND statusCategory != Done ORDER BY updated DESC`. A full page back means the probe is too broad — tighten to the image name plus the top few CVEs instead of paging. When the CVE list isn't known upfront, re-run the CVE-id part after step 3a and surface any late hits before the commit point.
- Forge: `gh pr list --search "<image-name>"` / `glab mr list --search "<image-name>"` for open PRs/MRs touching this image or its packages. Review any hit before treating it as a valid fix: read the diff, identify which packages it updates, and cross-reference against the Critical/High fixable findings (step 3 provides them — revisit the PR verdict after analysis if needed).
- A ticket found by JQL may have been created through Sysdig's Jira integration (UI-driven) — treat its live Jira status the same way: open → adoption candidate; closed → history, propose fresh.

**c. Synthesize and decide.** Present one consolidated picture:

> _"Existing work for `<image>`: job artifact ticket PROJ-100 (open), JQL also found PROJ-113 naming CVE-2024-9999 (closed — historical), open PR myorg/svc#42 (bumps golang 1.20→1.23 — does **not** cover CVE-2024-9999). Adopt PROJ-100 for the ticket half? And the PR doesn't fix everything — update it, or open a new one?"_

- Adopted ticket → treat its key as if passed via `ticket:` (the execute step updates it instead of creating).
- Adopted PR that fully addresses the findings → skip the PR half of execution; still record/cross-link it in steps 5–6.
- Nothing found or user wants fresh → create path.
- **Provisional when CVEs aren't known yet.** The CVE-id ticket search can't run until step 3a. If the user picks "create fresh" here before CVEs are known, treat that as provisional — step 3a may surface a ticket that changes it.

### 3. Analysis core

#### 3a. Fetch vulnerability details

Call `run_sysql` to fetch the image's Critical/High vulnerability set — the catalog unit (one row per distinct CVE × package, no runtime join). If you have the `image_id`, use this query:

```
MATCH Image AFFECTED_BY Vulnerability
  WHERE Image.imageId CONTAINS '<image_id>' AND Vulnerability.severity IN ['Critical', 'High']
  RETURN DISTINCT Image, Vulnerability;
```

If you only have the `image_name` (image reference), use this one:

```
MATCH Image AFFECTED_BY Vulnerability
  WHERE Image.imageReference CONTAINS '<image_name>' AND Vulnerability.severity IN ['Critical', 'High']
  RETURN DISTINCT Image, Vulnerability;
```

The returned `Vulnerability` entities carry the package (name, installed version), severity, CVSS, fix availability, and the Sysdig-suggested fix version. The fix versions are the initial `candidate` inputs to the chain analysis (step 3d); the rest feeds fix-case selection (step 3e) and the ticket's CVE table.

**Re-run the deferred duplicate check now.** With the Critical/High CVE ids known, run the CVE-id part of the step 2b Jira search — same bounds: one query, at most the ~10 most notable ids (KEV / exploit-flagged first, then CVSS descending). If it finds an open ticket not seen in step 2, show it and let the user revise the step 2c decision **before** the commit point (step 4). Never create a fresh ticket while an unreviewed CVE-id match is outstanding.

If no Critical or High CVEs are returned, tell the user there is nothing to remediate and stop (nothing is tracked or closed — no writes have happened yet).

> **Why SysQL and not `query_vulnerability_findings`:** the findings API serves runtime-joined
> rows (CVE × package × running resource) — on a widely deployed image the same CVE×package
> pair repeats once per resource (measured on staging: `nginx:latest` = 12,780 Critical/High
> rows for ~150 distinct pairs), and its rows carry neither the suggested fix version nor
> CVSS. This step needs the deduplicated catalog set, which is exactly what SysQL's
> `RETURN DISTINCT` provides. The findings API remains the right surface for
> `/sysdig-investigate`'s Findings-flow slicing — different question, different unit.

#### 3b. Find the source repository

Skip this step entirely when `deliverable` is `ticket` and no PR adoption is in play — the ticket path doesn't need the repo. (Still useful when the user wants the repo named in the ticket; offer, don't insist.)

Use the source kind selected in step 0b (`source.kind` ∈ `github` / `gitlab` / `local`). For per-provider command syntax, see [`references/source_control.md`](references/source_control.md).

**Local mode.** The repo is the folder. Skip the search strategies below, verify the working tree is clean (`git status --porcelain` empty — refuse if dirty), and go to step 3c.

**GitHub or GitLab.** First check `image_repo_mappings` in the state for a known mapping. If found and less than 30 days old, propose it to the user for confirmation. If confirmed, skip the search strategies below.

Otherwise, identify the repository that owns the image build. Use the following strategies in order, stopping as soon as a confident match is found. The examples use GitHub `gh search` syntax — for GitLab use the `glab api` group-scoped equivalents documented in `source_control.md`.

**name match:**
Extract the image name from the image reference (e.g. `my-service` from `quay.io/myorg/my-service:tag`).
Search the configured forge for repositories in the same org/group whose name matches or closely matches the image name.

**Dockerfile search:**
Search across repos for a `Dockerfile` that references the image name or its base image.
Example (GitHub): `gh search code "FROM <base-image>" filename:Dockerfile org:<org>`.

**Kubernetes manifest search:**
Search for YAML files that reference the full image string.
Example (GitHub): `gh search code "<image_reference>" extension:yaml org:<org>`.

**ask the user:**
If no confident match is found, ask one question at a time:

1. First, present the top candidate repos: _"I found these repositories that might own this image: `<list>`. Which one, or none of these?"_
2. Only if the user picks "none of these", ask the follow-up: _"Switch to local-folder mode? Provide a path, or cancel."_

Do not bundle the two questions — wait for the answer to (1) before asking (2).

IMPORTANT: If the repo does not belong to the user or any of their organizations/groups, WARN the user and ask whether to continue.
NEVER commit or open PRs/MRs to repos that are not owned by the user or by an org/group the user belongs to.

Once the repo is identified, fetch the default branch (`gh api repos/<owner>/<repo> --jq .default_branch` or the `glab` equivalent — never assume `main`/`master`) and look for:
- A `Dockerfile` or `Dockerfile.*`
- Dependency manifests: `package.json`, `requirements.txt`, `pom.xml`, `go.mod`, `Gemfile`, etc.

#### 3c. Identify PR reviewers

Only required when the PR half is in play and a source repo was found (or a local folder was provided).

**Commit history on the affected file:**

Once you know which file will be patched (the `Dockerfile` for Case A, the relevant dependency manifest for Case B), fetch the commit history for that specific file:
- GitHub: list commits filtered by path = `<affected_file>` via `gh api` or the GitHub MCP, limit 5
- GitLab: equivalent `glab api` call against the project, limit 5
- Local: `git log --follow --pretty=format:'%H %ae %an' -n 5 -- <affected_file>`
- Exclude bot authors: skip any login or email containing `bot`, `renovate`, `dependabot`, `github-actions`, `[bot]`
- Record the remaining authors (login for github/gitlab, name+email for local) as `file_authors` (most recent first)

**Priority chain — derive `suggested_reviewers`:**

Use the first signal that yields a result:
1. **State-known reviewers** — if `repo_reviewers` already contains an entry for this repository, use those values as defaults (they were confirmed by the user in a previous session). Still present them for confirmation, but mark them as "previously confirmed".
2. `file_authors` (commit log on the affected file).
3. Leave unassigned.

Store `suggested_reviewers` and present them to the user for confirmation before setting them — the user can accept, change, or skip. In `local` mode, "reviewers" is informational only (no PR to attach them to); record the confirmed list in state for future sessions, but don't attempt to assign.

> **Note:** `file_authors` is reviewer-only. Ticket **assignees** come from Sysdig-side
> signals in step 5b (workload owner, zone owner, previous ticket assignee) — never from
> git log.

#### 3d. Resolve the safe target version (fix chain analysis)

Before proposing any fix, verify that the candidate fix version does not itself introduce new Critical or High vulnerabilities. Repeat until a clean version is found or no safe version exists.

Chain analysis is catalog work: it evaluates candidate versions that are (ideally) not deployed on this image, checking each one across everything Sysdig has observed — including the same package version running on other assets. It is best-effort by nature: an empty result alone only means no *known* Critical/High vulnerabilities — the presence probe in algorithm step 3 distinguishes a scanned-and-clean version from one Sysdig has never observed.

**Algorithm — run this for every package that has a fix available:**

1. Take the fix version suggested by Sysdig in step 3a (call it `candidate`).
2. Query Sysdig for vulnerabilities in `candidate`:
   ```
    MATCH Package AFFECTED_BY Vulnerability
    WHERE Package.name =~ '(?i).*<package>.*' AND Package.version =~ '(?i).*<candidate>.*'
       AND Vulnerability.severity IN ['Critical', 'High']
       RETURN Package, Vulnerability;
   ```
3. If the query returns no results → disambiguate before trusting it. Probe whether Sysdig knows the version at all:
   ```
    MATCH Package
    WHERE Package.name =~ '(?i).*<package>.*' AND Package.version =~ '(?i).*<candidate>.*'
       RETURN Package LIMIT 1;
   ```
   - Package node found → `candidate` is **observed and clean** (scanned, no known Critical/High). Use it.
   - No node → `candidate` is **unassessed** — never observed in this environment (the common case for a new fix version). Still use it as the best available recommendation, but record its chain entry as `unassessed` (see [references/state.md](references/state.md)) and carry the caveat into the PR body and ticket: _"`<candidate>` has no Critical/High findings known to Sysdig, but has not been observed in your environment — verify against upstream advisories before merging."_
4. If the query returns results → find the lowest fix version among those new CVEs and set it as the new `candidate`. Go to step 2.
5. Repeat up to **5 iterations**. If no clean version is found after 5 iterations, treat it as Case C (no safe fix available); the chain still goes into the ticket so the analysis isn't lost.

**Example:** Go 1.20 → CVE fixed in 1.23 → but 1.23 has new Critical → fixed in 1.25 → 1.25 is clean → recommend 1.25.

Keep track of the full chain found (e.g. `1.20 → 1.23 → 1.25`) to include it in the PR description and the ticket so reviewers understand why the version jump is larger than expected.

Run the chain analysis **regardless of deliverable** — the ticket-only path needs the safe fix version and chain in the ticket body just as much as the PR path needs it in the diff.

#### 3e. Assess fixability and choose the remediation action

Pick the right case based on what's fixable. Full per-case detail (action algorithm, error paths, escalation rules) lives in [`references/fix-cases.md`](references/fix-cases.md).

| Case | Trigger | Action |
|------|---------|--------|
| A | Base OS / system package CVE with safe fix | PR against the Dockerfile (+ ticket per deliverable) |
| B | Application dependency CVE with safe fix | PR against the dependency manifest (+ ticket per deliverable) |
| C | No safe fix version available | No PR possible — deliver a full-analysis ticket instead (renegotiate deliverable if it was PR-only) |
| D | Repo not located within configured source | No PR possible — offer local mode; else deliver a full-analysis ticket |

Present the user with the proposed action before doing anything:

> _"For `my-service`: I found the repo `myorg/my-service` and can open a PR to update Go from `1.20` to `1.25` (skipping `1.23` which has a Critical CVE), plus file a Jira ticket referencing it. Shall I proceed?"_

### 4. Commit point — track the job

Runs only after the user has explicitly confirmed the proposed deliverable(s) in step 3e — this is the moment intent becomes a work item.

If a remediation job row is in play (from `job_id` or the step 2a `explore_jobs` match) and it is `tracked: false`, promote it now:

```
track_job(remediation_target_type: "container_image", <image reference/id fields from the explore_jobs row>)
```

- `track_job` is idempotent on an unchanged vulnerability set — re-tracking an already-tracked job is safe.
- **422 means the image is no longer detected** in the environment (rotated out or already fixed). Stop with: _"This image is no longer detected in your environment — it may already have been fixed or rotated out. Nothing to remediate."_ Do not create any deliverable.

If the job is already tracked, or no remediation job row exists for this image (pure Findings-flow/manual entry), skip the call. Artifacts (step 6) require a tracked job; without one, deliverables still proceed — they just can't be recorded on a job.

**Never call `track_job` before this point** — not during dedup, not during analysis.

### 5. Execute the deliverable

Order when `deliverable` is `both`: open the PR first, then create/update the ticket referencing it (so the ticket links the PR from birth). If the ticket was adopted in step 2 with `ticket:` semantics, the same order holds — PR first, then append the update.

#### 5a. PR path (deliverable `pr` or `both`)

The existing-PR check already happened in step 2b — by the time you reach 5a no unaccounted duplicate PR exists.

**GitHub or GitLab — open a PR/MR** (per-provider mechanics in [`references/source_control.md`](references/source_control.md) — on a hosted forge, branch creation and the file commit go through the forge API (`gh api` / `glab api`); no local clone is required. Render the proposed change as a unified diff for the review in item 3 either way):

1. Create a new branch: `sysdig/fix-<cve-id>-<image-name>` off the default branch.
2. Make the minimal change needed (Dockerfile FROM update, or dependency version bump), using the safe target version from step 3d.
3. **Show the diff before opening.** Print the full file diff (`git diff <default-branch>..HEAD`) and the rendered PR body inline, then pause for an explicit user yes. A summary is not a substitute for the diff itself.
4. Open the PR/MR with:
   - **Title:** `fix: patch <CVE-ID> in <image-name>`
   - **Body:**
     ```
     ## Summary
     This PR updates <package> from `<installed_version>` to `<safe_target_version>`
     to fix <CVE-ID> (<severity>, CVSS <score>).

     ## Vulnerability details
     - CVE: <cve_id>
     - Package: <package> <installed_version> → <safe_target_version>
     - Severity: <severity>
     - Affected image: <image_reference>
     - Affected workloads: <workloads_count> (<workloads_internet_exposed_count> internet-exposed)

     ## Version resolution
     <!-- Include if intermediate versions were skipped or the target is unassessed -->
     The direct fix version (<first_candidate>) was skipped because it introduces
     new Critical/High CVEs. Resolution chain: <installed_version> → <v1> → <v2> → <safe_target_version>.
     <!-- When the target is unassessed: -->
     <safe_target_version> has no Critical/High findings known to Sysdig, but has not
     been observed in your environment — verify against upstream advisories before merging.

     ## References
     - Sysdig job global_id: <job_global_id>   <!-- only if a tracked job exists -->
     - Tracking ticket: <ticket_url>   <!-- only if the ticket half exists/is adopted -->
     ```
   - **Reviewers:** if `suggested_reviewers` was populated in step 3c, request review from those users (after confirming with the user).

For provider-specific syntax (`gh pr create` vs `glab mr create`, branch creation, file commits), see [`references/source_control.md`](references/source_control.md).

**After the PR opens, tell the user how to undo it.** Print the rollback commands explicitly:

- GitHub: `gh pr close <num> && git push origin --delete sysdig/fix-<cve-id>-<image-name>`
- GitLab: `glab mr close <num> && git push origin --delete sysdig/fix-<cve-id>-<image-name>`

**Local mode — emit a patch:**

No branch, no commit, no push — the user reviews and applies the diff themselves. Write two artifacts to the folder root:

1. `sysdig-fix-<cve-id>.patch` — `git diff` of the proposed change against the current HEAD. Apply with `git apply <patch>`.
2. `sysdig-fix-<cve-id>.md` — the same body content the PR would have had (Summary, Vulnerability details, Version resolution, References).

Tell the user the absolute paths of both artifacts. Do not run `git commit`, `git push`, or modify any branch.

#### 5b. Ticket path (deliverable `ticket` or `both`)

This skill is the **sole ticket creator**. Systems, detection, the assignee signal chain, and the full create/update templates live in [`references/ticketing.md`](references/ticketing.md). The flow:

1. **Determine the assignee — Sysdig-side signals only** (never git log / file authors):
   1. `workload_owner` — owner annotation/label on the running workload. Query via SysQL:
      ```
      MATCH KubeWorkload HAS Container RUNS Image
        WHERE Image.imageReference CONTAINS '<image_name>'
        RETURN DISTINCT KubeWorkload.labels, KubeWorkload.annotations;
      ```
      Inspect labels/annotations like `owner`, `team`, `app.kubernetes.io/owner`.
   2. `zone_owner` — if the relevant zone defines an owner, use it.
   3. `previous_ticket_assignee` — from the `ticket_assignees` state hint or a ticket discovered in step 2.
   4. Leave unassigned.

   Present the proposed assignee with its source (e.g. _"Suggesting @platform-team — workload has label `team: platform-team`."_) and **always confirm with the user before setting it**. Record the confirmed choice in `ticket_assignees` state.

2. **Draft the ticket** from the template in [`references/ticketing.md`](references/ticketing.md) — including the CVE table, impact assessment, **safe fix version and resolution chain from step 3d**, and the PR link when one was opened. **Show the full draft to the user before any write.**

3. **Create or update:**
   - Creating: use the detected Jira surface (`createJiraIssue` or equivalent).
   - Updating an adopted ticket: never remove or modify the existing description — append below a `----` separator per the update template in `references/ticketing.md`.

4. Report the ticket key and URL back.

If the ticket write fails, report it in the canonical what / why / fix shape and include the full drafted text so the user can apply it by hand — then continue to step 6 for whatever else succeeded.

### 6. Record and close

Only possible when a tracked remediation job exists (step 4). Without one, skip to step 7 — the PR/ticket still stand on their own.

1. **Record each deliverable as an artifact** (artifacts are recording wrappers — they never create the underlying ticket/PR, they record it after the fact):
   ```
   create_artifact(
     parent_kind: "job",
     parent_id: <job_global_id>,
     artifact_type: "pull_request",
     reference_key: "<owner/repo#num>",
     reference_url: "<pr_url>",
     title: "fix: patch <CVE-ID> in <image-name>"
   )
   ```
   ```
   create_artifact(
     parent_kind: "job",
     parent_id: <job_global_id>,
     artifact_type: "jira_ticket",
     reference_key: "<ticket_key>",
     reference_url: "<ticket_url>",
     title: "[Sysdig] Fix Critical/High vulnerabilities in <image_reference>"
   )
   ```
   Skip any artifact whose deliverable was adopted-and-unchanged and already recorded on the job (step 2a told you).

   **Local mode:** a `.patch` file is not a filed deliverable — never `close_job` for it. If a tracked job exists, record a `note` artifact with the patch paths so the session stays findable; the job remains open until a PR or ticket is actually filed.

2. **Close the job — close-when-filed policy.** If at least one deliverable was filed this session (PR opened or ticket created/updated), close the job after the artifacts are recorded:
   ```
   close_job(job_id: <job_global_id>)
   ```
   This is a deliberate, user-approved policy: the job leaves the plan's job queue when the work is **filed**, not when the image is confirmed fixed — the artifact trail keeps the work findable from the Sysdig UI. Closing is irreversible via MCP. If nothing was filed (user backed out), do **not** close — the job stays in the queue for the next session.

   If `close_job` fails: _"I couldn't close this job automatically. It will reappear in the next session, but the PR/ticket artifacts are already attached."_ Move on.

### 7. Update state

Merge the knowledge discovered during this session into the state and save it via `save_skill_state` with `{ "skill_state": "remediate", "version": <n>, "data": { ... } }`. Use the matching keys defined in [references/state.md](references/state.md) to upsert entries.

Always persist:
- **`image_repo_mappings`** — if a source repo was identified in step 3b
- **`repo_reviewers`** — if reviewers were confirmed by the user (step 3c). Replace the existing entry for this repo with the newly confirmed list.
- **`ticket_assignees`** — if an assignee was confirmed (step 5b)
- **`vulnerability_resolutions`** — for each package that was upgraded
- **`version_chains`** — for any fix chain with more than one step
- **`remediation_history`** — one entry per session, always appended, including `deliverable`, `prs_opened`, `ticket_created` or `ticket_updated`, `job_id`, and `job_closed`

> **Version on write**: pass the same `version` value returned by the `get_skill_state` call in step 1 — or `0` if the call returned `null` (no prior state). The server bumps the version itself. See [Read/write rules](references/state.md#readwrite-rules). Do not include `version` inside `data`.

Update the state even if the session was partially completed (e.g. PR opened but the ticket write failed).

### 8. Summary

At the end, present a summary table to the user:

| Image | CVEs found | Deliverable | PR | Ticket | Job |
|-------|-----------|-------------|-----|--------|-----|
| quay.io/org/app:1.2 | 3 Critical, 5 High | both | myorg/app#42 | PROJ-123 (created) | closed |

## Important rules

- **This skill is the sole ticket creator.** `/sysdig-investigate` never creates tickets — if the user arrived without one, this skill files it (with their approval).
- **Dedup is strictly read-only.** Step 2 performs no writes: no `track_job`, no ticket/PR creation, no artifacts. `skill_state` is a convenience cache and never a dedup authority — job artifacts and the external Jira/forge searches are.
- **`track_job` fires only at the commit point** (step 4, after the user confirms the deliverable) — never during dedup or analysis. A 422 means the image is no longer detected: stop, create nothing.
- **Artifacts are recording wrappers.** They never create tickets or PRs; they record `reference_key`/`reference_url` after the deliverable exists.
- **Close-when-filed.** `close_job` runs when a PR was opened or a ticket was filed this session — not when the fix is confirmed deployed. Never close when nothing was filed. Closing is irreversible via MCP.
- Never open a PR or create a ticket without showing the user the draft (full diff / full ticket body) and getting explicit confirmation.
- Never guess a repo mapping — if not confident, ask the user.
- Always run the fix chain analysis (step 3d) before proposing any version upgrade — never suggest a fix version without first verifying it is clean. Run it for the ticket-only path too.
- Cap the fix chain at 5 iterations. If no clean version is found within 5 steps, treat as Case C.
- If the chain skips versions, always explain why in the PR body and the ticket so reviewers understand the larger-than-expected version jump.
- When updating an existing ticket, NEVER remove or modify the original description — always append below a separator (`----`).
- For PR reviewers, use git log on the affected file. For ticket assignees, use Sysdig-side signals only (workload owner, zone owner, previous ticket assignee). Never cross the two.
- Reviewer and assignee suggestions are only suggestions — always confirm with the user before setting them.
- At the start of the skill, load the state (step 1) and reuse known mappings/reviewers/chains as hints — confirm mappings older than 30 days.
- Always save the state (step 7), even for partial sessions.
- This skill works on **one image at a time**. To choose the image, run `/sysdig-investigate` first.

## Handoff phrasing

Use these exact openings to keep the user oriented across multi-skill workflows:

- **When invoked from `/sysdig-investigate`'s handoff:** _"`/sysdig-investigate` handed off `<image>` (job `<job_id>`). Loading state and starting remediation — first, what should this deliver?"_
- **Case C (no safe fix) with deliverable `pr`:** _"No safe fix version exists — a PR isn't possible. I can file a full-analysis ticket instead (versions checked, why none are safe) so the work isn't lost. File it?"_
- **Case D (repo not found) after local-mode was declined:** _"I couldn't locate the source repository and no local folder was provided. I can still file/update the tracking ticket with the full analysis, record it on the job, and close the job as filed. Proceed?"_

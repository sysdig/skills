---
name: sysdig-remediate
description: >
  Remediate one specific vulnerable container image. Fetches Critical/High
  CVEs from Sysdig, resolves a safe fix version via chain analysis, and
  opens a PR/MR (GitHub/GitLab) or emits a local patch.
  Triggers: "fix the nginx image", "patch CVE-2024-1234 in api-server",
  "remediate quay.io/org/app:tag", "/sysdig-remediate <image>".
  Not for: discovery, prioritization, or ticket creation — use /sysdig-investigate.
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
  - Bash(gh search code*)
  - Bash(gh api repos/*)
  - Bash(gh pr create*)
  - Bash(gh pr list*)
  - Bash(gh pr view*)
  - Bash(gh pr close*)
  - Bash(glab api*)
  - Bash(glab mr create*)
  - Bash(glab mr list*)
  - Bash(glab mr view*)
  - Bash(glab mr close*)
  - mcp__sysdig__get_customer_settings
  - mcp__sysdig__get_skill_state
  - mcp__sysdig__save_skill_state
  - mcp__sysdig__delete_skill_state
  - mcp__sysdig__run_sysql
---

## First-run notice (Public Beta)

Before doing any other work for this skill, perform this one-time check:

1. If `~/.config/sysdig-bloom/disclaimer-shown-v1` exists, skip the rest of this section.
2. Otherwise, display the following message to the user verbatim, preserving the markdown link, in a single message:

   > This plugin is a Public Beta release. It is provided “as is” and “as available,” without warranties of any kind. By installing this plugin, you agree to the Public Beta Terms available in the [repository readme](https://github.com/sysdig/skills#public-beta-terms).

3. Create the marker file `~/.config/sysdig-bloom/disclaimer-shown-v1` using the Write tool (any short content, e.g. the current UTC timestamp). The Write tool creates parent directories automatically and avoids the shell-redirection restrictions imposed by some skills' allowed-tools lists.
4. Then continue with the user's request.

*Uses: Sysdig MCP, GitHub (`gh`) or GitLab (`glab`), `git`, optional Jira/Linear/GitHub Projects MCP for ticket updates.*

Remediate a single vulnerable image in a Sysdig-monitored environment in four steps: **locate** the source (GitHub, GitLab, or a local folder), **resolve** a safe fix version through chain analysis, **open** a PR/MR (or emit a `.patch` for local mode), and **optionally update** a ticket if a key was passed in. This skill **never creates tickets** — that work lives in `/sysdig-investigate`.

> **To find and prioritize which images to remediate, run `/sysdig-investigate` first.**
> `/sysdig-investigate` fetches the investigation list, ranks images, optionally creates a tracking ticket, and hands off to this skill.

## Conversation rules

- **Narrate before every tool call.** Before invoking any tool — SysQL query, `gh` / `glab` command, `git` operation, MCP write — say what you're about to do and which tool you're using. No silent calls.
- **Announce every skill handoff.** Before invoking another skill, name it explicitly and summarize what it'll do, then wait for confirmation.
- **Pause for confirmation before any write.** Branch creation, commits, PR/MR opens, and ticket updates all require an explicit user yes. Read-only queries do not.
- **One question per turn.** Never bundle compound choices ("which repo, or switch to local?"). Ask one question, wait for the answer, then ask the next.
- **Status vocabulary.** When reporting outcomes, use `done` / `pending` / `in_progress` / `failed` / `skipped` plus a one-line detail.

## Input

This skill expects a single image to work on. The image can be provided in any of these ways:
- As an argument: `/sysdig-remediate quay.io/org/app:tag`
- With an `image_id`: `/sysdig-remediate quay.io/org/app:tag (image_id: <id>)`
- With an existing ticket: `/sysdig-remediate quay.io/org/app:tag (image_id: <id>, ticket: <ticket_key>)`
- Interactively: if no image is provided, ask the user to specify one or run `/sysdig-investigate` to select from the investigation list.

The `ticket` argument is optional. When present, this skill updates the referenced ticket with the PR link on completion. When absent, the skill opens the PR without touching any ticketing system. **This skill never creates new tickets** — if a ticket is desired, run `/sysdig-investigate` to file one first.

## State

Read state via `get_skill_state`, write via `save_skill_state`. Schema and rules: see [references/state.md](references/state.md). Treat null as { "version": 0 }.

## Steps

### 0. Trust preamble

**Always present this before asking any questions.** See [`references/trust-preamble.md`](references/trust-preamble.md) for the full text. After presenting the preamble, proceed directly to step 0b — the preamble is informational, do not ask for confirmation.

### 0b. Prerequisites

Run all checks before any real work. Announce each result on its own line so the user knows which paths are open before they commit to a flow.

1. **Sysdig MCP** — verify the `get_customer_settings` tool is available. Required. If it is not available or the call fails, **do not show a generic error message**. Instead, follow the "Agent diagnostic checklist" in [`references/mcp-setup.md`](references/mcp-setup.md) — run the checks in order, identify the specific failure, and report only the relevant problem and its fix to the user.
2. **Source control** — run the selection algorithm in [`references/source_control.md`](references/source_control.md) to detect a configured GitHub (`gh`/MCP), GitLab (`glab`/MCP), or a local folder the user points at. Record `source.kind` ∈ {`github`, `gitlab`, `local`} and `source.handle` (org/group/path) in working memory; later steps key off these. Required.
3. **Ticketing (optional)** — detect whether a ticketing MCP/CLI is reachable (Jira / Linear / GitHub Projects). Used by step 1b (adopt an existing ticket) and step 4b (PR ↔ ticket cross-link). If absent, those steps are skipped silently — do not block.

Announce a one-line status summary, e.g.:

> _Sysdig MCP: connected · <source_control_system> (`<cli_command>`): connected · <ticketing>: not connected — ticket updates will be skipped._

If the **Sysdig MCP** check fails, do not proceed — the diagnostic checklist above will have already reported the specific problem and fix.

If the **source control** check fails (no forge configured and the user cannot provide a local folder), stop with:

> I cannot remediate `<image>` without access to its source. The skill produces a code patch — there is no useful tracking-only mode. Configure a forge or point me at a local working tree, then re-run.

Do not proceed until both required checks pass.

### 1. Load project context

Call the MCP tool `get_skill_state` with `{ "skill_state": "remediate" }`. A `null` response
means no state exists yet — start with `{ "version": 0 }`. Note any existing:
- `image_repo_mappings` — reuse known repo for this image instead of re-searching (confirm with user if older than 30 days)
- `repo_reviewers` — use as top-priority signal for PR reviewers (step 3b)
- `vulnerability_resolutions` — skip re-resolution if the same package+from_version was already verified clean
- `version_chains` — skip re-analysis if the same package+version was already investigated

**Resume.** If `remediation_history` has at least one entry from the last 14 days, surface a resume summary to the user before continuing — name the most recent image, the date, the PR or ticket key if present, and ask what to do next:

> _"Last session: remediated `quay.io/myorg/my-service:1.2.3` on 2026-04-22 — PR myorg/my-service#42, ticket PROJ-123. Continue with a new image, refresh state for that one, or pick up where it stalled?"_

Wait for the user's answer before proceeding to step 1b.

### 1b. (Optional) Best-effort search for an existing ticket

Run only when **no `ticket` argument was passed in** and the skill was invoked standalone (not from `/sysdig-investigate`'s handoff). This step never creates tickets — it only discovers an existing one to adopt.

1. Use the ticketing availability already detected in step 0a. If none is reachable, skip this step silently. For supported systems and tool surfaces, see [`sysdig-investigate/references/ticketing.md`](../../sysdig-investigate/references/ticketing.md).
2. Otherwise, ask the user (default **No**): _"No ticket was passed. Search for an open ticket related to `<image_name>` first?"_
3. If yes, search the system by image-name fragment in summaries (and the full image reference in descriptions). Filter to open tickets.
4. Result handling:
   - **Exactly one match** — show its key, summary, and assignee; ask the user to confirm adopting it.
   - **Multiple matches** — present the top 3 and let the user pick one or skip.
   - **No match** — tell the user; proceed with no ticket. Do not offer to create — direct them to `/sysdig-investigate` if they want one.
5. If the user confirms a ticket, treat its key as if it had been passed via the `ticket:` argument for the rest of this session — step 4b will update it on PR open.

### 2. Fetch vulnerability details for selected images

For each selected image, call `run_sysql` to find info about the image. If you have the `image_id`, use this query:

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

If no Critical or High CVEs are returned, skip this image and tell the user.

> **Note on ticketing:** ticket _creation_ and assignee determination live
> in `/sysdig-investigate` — this skill **never creates tickets**. It will
> only update an existing ticket with the PR link (step 4b). The ticket
> key can come from either the `ticket:` input argument or the optional
> best-effort search in step 1b.

### 3. Find the source repository

Use the source kind selected in step 0a (`source.kind` ∈ `github` / `gitlab` / `local`). For per-provider command syntax, see [`references/source_control.md`](references/source_control.md).

**Local mode.** The repo is the folder. Skip the search strategies below, verify the working tree is clean (`git status --porcelain` empty — refuse if dirty), and go to step 3a.

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

### 3a. Search for existing PRs

In `local` mode there is no remote PR list — skip this step and go to step 3b.

Otherwise, check if the repo already has a PR open that refers to the same image. If so, surface it to the user. If they want to track that PR rather than open a new one, skip step 4a and go directly to step 4b (update the ticket with the existing PR's link, if a ticket key is set), then step 5.

### 3b. Identify PR reviewers

Only required if a source repo was found (or a local folder was provided) in step 3.

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

> **Note:** ticket assignees are determined upstream in `/sysdig-investigate`
> using Sysdig-side signals (workload owner, zone owner, previous ticket
> assignee). Do not propose a ticket assignee here — `file_authors` is
> reviewer-only.

### 3c. Resolve the safe target version (fix chain analysis)

Before proposing any fix, verify that the candidate fix version does not itself introduce new Critical or High vulnerabilities. Repeat until a clean version is found or no safe version exists.

**Algorithm — run this for every package that has a fix available:**

1. Take the fix version suggested by Sysdig (call it `candidate`).
2. Query Sysdig for vulnerabilities in `candidate`:
   ```
    MATCH Package AFFECTED_BY Vulnerability
    WHERE Package.name =~ '(?i).*<package>.*' AND Package.version =~ '(?i).*<candidate>.*'
       AND Vulnerability.severity IN ['Critical', 'High']
       RETURN Package, Vulnerability;
   ```
3. If the query returns no results → `candidate` is clean. Use it.
4. If the query returns results → find the lowest fix version among those new CVEs and set it as the new `candidate`. Go to step 2.
5. Repeat up to **5 iterations**. If no clean version is found after 5 iterations, treat it as Case C (no safe fix available); record the chain so the ticket update in step 4b can include it (if a ticket key is set).

**Example:** Go 1.20 → CVE fixed in 1.23 → but 1.23 has new Critical → fixed in 1.25 → 1.25 is clean → recommend 1.25.

Keep track of the full chain found (e.g. `1.20 → 1.23 → 1.25`) to include it in the PR description (and any ticket update) so reviewers understand why the version jump is larger than expected.

### 3d. Assess fixability and choose remediation action

Pick the right case based on what's fixable. Full per-case detail (action algorithm, error paths, escalation rules) lives in [`references/fix-cases.md`](references/fix-cases.md).

| Case | Trigger | Action |
|------|---------|--------|
| A | Base OS / system package CVE with safe fix | Open PR against the Dockerfile |
| B | Application dependency CVE with safe fix | Open PR against the dependency manifest |
| C | No safe fix version available | No PR — append analysis to ticket (if set), otherwise stop and refer to `/sysdig-investigate` |
| D | Repo not located within configured source | No PR — offer local mode, otherwise escalate via ticket / `/sysdig-investigate` |

Present the user with the proposed action before doing anything:

> _"For `my-service`: I found the repo `myorg/my-service` and can open a PR to update Go from `1.20` to `1.25` (skipping `1.23` which has a Critical CVE). Shall I proceed?"_

### 4. Open PR (and optionally update ticket)

If a PR is possible (Case A or B) and the user confirms, go to step 4a. After the PR is opened — or in Case C/D — go to step 4b only if **a ticket key is set**, either from the `ticket:` input argument or adopted in step 1b. Both sources go through the same update flow so the PR ↔ ticket cross-link always lands.

#### 4a. Open PR (or emit patch in local mode)

The existing-PR check already happened in step 3a — by the time you reach 4a no duplicate PR exists.

**GitHub or GitLab — open a PR/MR:**

1. Create a new branch: `sysdig/fix-<cve-id>-<image-name>` off the default branch.
2. Make the minimal change needed (Dockerfile FROM update, or dependency version bump), using the safe target version from step 3c.
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
     <!-- Only include if intermediate versions were skipped -->
     The direct fix version (<first_candidate>) was skipped because it introduces
     new Critical/High CVEs. Resolution chain: <installed_version> → <v1> → <v2> → <safe_target_version>.

     ## References
     - Sysdig investigation: global_id `<global_id>`
     - Tracking ticket: <ticket_url>   <!-- only if a ticket key is set -->
     ```
   - **Reviewers:** if `suggested_reviewers` was populated in step 3b, request review from those users (after confirming with the user).
   - **Ticket cross-link:** if a ticket key is set (from the `ticket:` argument or step 1b), include `Tracking ticket: <ticket_url>` in the References section. Step 4b will mirror the link in the ticket itself, so the PR ↔ ticket relationship is bidirectional.

For provider-specific syntax (`gh pr create` vs `glab mr create`, branch creation, file commits), see [`references/source_control.md`](references/source_control.md).

**After the PR opens, tell the user how to undo it.** Print the rollback commands explicitly so the user has a clear path back if the change turns out to be wrong:

- GitHub: `gh pr close <num> && git push origin --delete sysdig/fix-<cve-id>-<image-name>`
- GitLab: `glab mr close <num> && git push origin --delete sysdig/fix-<cve-id>-<image-name>`

**Local mode — emit a patch:**

No branch, no commit, no push — the user reviews and applies the diff themselves. Write two artifacts to the folder root:

1. `sysdig-fix-<cve-id>.patch` — `git diff` of the proposed change against the current HEAD. Apply with `git apply <patch>`.
2. `sysdig-fix-<cve-id>.md` — the same body content the PR would have had (Summary, Vulnerability details, Version resolution, References).

Tell the user the absolute paths of both artifacts. Do not run `git commit`, `git push`, or modify any branch.

#### 4b. Update existing ticket (only if a ticket key is set)

**This skill never creates tickets.** Run only when a ticket key was either passed via the `ticket:` argument or adopted in step 1b (best-effort search). Otherwise skip this step.

When updating the ticket:

- **Never remove or modify the existing description.** Always append new information below the existing content.
- Add a separator and new section:

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
- <"done — PR opened, awaiting review" | "failed — no safe fix available (see Case C below)" | "failed — repo not found">
```

- If a new Critical CVE was discovered relative to the existing ticket, note it but do **not** silently re-prioritise — leave priority and assignee untouched unless the user explicitly asks otherwise.
- Report back the ticket key and URL when the update succeeds.

If the ticket update fails, report it in the canonical what / why / fix shape, then continue — do not block on the ticket update:

> _"Ticket update failed — `<reason>` (e.g. ticket not found, permission denied). Fix: `<concrete next step — re-auth, correct the ticket key, or paste the update text below into the ticket manually>`."_

Always include the update text the agent was about to write so the user can apply it by hand if automation can't recover.

### 5. Update state

After all actions are complete, merge the knowledge discovered during this session into the
state and save it by calling the MCP tool `save_skill_state` with
`{ "skill_state": "remediate", "version": <n>, "data": { ... } }`. Use the matching keys
defined in the schema section to upsert entries.

Always persist:
- **`image_repo_mappings`** — if a source repo was identified in step 3
- **`repo_reviewers`** — if reviewers were confirmed by the user (step 3b). Replace the existing entry for this repo with the newly confirmed list.
- **`vulnerability_resolutions`** — for each package that was upgraded
- **`version_chains`** — for any fix chain with more than one step
- **`remediation_history`** — one entry per session, always appended, including `reviewers_confirmed` and `ticket_updated` (the key of the ticket updated in step 4b, if any)

> **Version on write**: pass the same `version` value returned by the `get_skill_state` call in step 1 — or `0` if the call returned `null` (no prior state). The server bumps the version itself. See [Read/write rules](references/state.md#readwrite-rules). Do not include `version` inside `data`.

Update the state even if the session was partially completed (e.g. user opened a PR but skipped the ticket update).

### 6. Summary

At the end, present a summary table to the user:

| Image | CVEs found | Action taken | PR / Ticket |
|-------|-----------|--------------|-------------|
| ...   | ...       | ...          | ...         |

## Important rules

- **Never create tickets in this skill.** Ticket creation lives in `/sysdig-investigate`. This skill only updates the ticket referenced by the optional `ticket` input argument.
- Never open a PR without showing the user the draft and getting explicit confirmation.
- Never guess a repo mapping — if not confident, ask the user.
- Always run the fix chain analysis (step 3c) before proposing any version upgrade — never suggest a fix version without first verifying it is clean.
- Cap the fix chain at 5 iterations to avoid infinite loops. If no clean version is found within 5 steps, treat as Case C.
- If the chain skips versions, always explain why in the PR body (and ticket update, if applicable) so reviewers understand the larger-than-expected version jump.
- At the start of the skill, load the state via the `get_skill_state` MCP tool to check for previously discovered image→repo mappings, version chains, and PR reviewers. Reuse known mappings in step 3 instead of re-searching (but confirm with the user if the mapping is older than 30 days). Reuse known reviewers in step 3b as the top-priority signal.
- Always save the state via the `save_skill_state` MCP tool in step 5, even if the session was partially completed (e.g. user opened the PR but skipped the ticket update).
- When updating an existing ticket, NEVER remove or modify the original description — always append below a separator (`----`).
- For PR reviewers, use git log on the affected file. Do not propose ticket assignees from git log — assignee determination is done upstream in `/sysdig-investigate` using Sysdig-side signals.
- Reviewer suggestions are only suggestions — always confirm with the user before requesting review.
- In Case C/D (no PR possible) with no ticket key set (neither passed via `ticket:` nor adopted in step 1b), stop and tell the user to run `/sysdig-investigate` to file a tracking ticket.
- This skill works on **one image at a time**. To select which image to remediate (and optionally file a tracking ticket), run `/sysdig-investigate` first.

## Handoff phrasing

Use these exact openings to keep the user oriented across multi-skill workflows:

- **When invoked from `/sysdig-investigate`'s handoff:** _"`/sysdig-investigate` handed off `<image>` (ticket `<key>`). Loading state and starting remediation."_
- **When a ticket is needed but none is set** (Case C/D, no `ticket:` argument, no adoption in step 1b): _"Pausing remediation — handing off to `/sysdig-investigate` to file a tracking ticket. I'll resume once you provide a ticket key."_ Then stop.

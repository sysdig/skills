---
name: sysdig-remediate
description: Remediate a vulnerable container image by fetching its Critical/High CVEs from Sysdig, resolving safe fix versions through chain analysis, and producing the minimal patch (Dockerfile base bump or dependency upgrade) against the source — opens a PR/MR on GitHub or GitLab, or emits a .patch file when the user provides a local folder. Source access is mandatory. If an existing ticket key is passed in, updates that ticket with the PR link; this skill never creates new tickets — ticket creation lives in /sysdig-investigate. Persists image-to-repo mappings, PR reviewer history, and version chains across sessions.
---

## First-run notice (Public Beta)

Before doing any other work for this skill, perform this one-time check:

1. If `~/.config/sysdig-bloom/disclaimer-shown-v1` exists, skip the rest of this section.
2. Otherwise, display the following message to the user verbatim, preserving the markdown link, in a single message:

   > This plugin is a Public Beta release. It is provided “as is” and “as available,” without warranties of any kind. By installing this plugin, you agree to the Public Beta Terms available in the [repository readme](https://github.com/sysdig/skills#public-beta-terms).

3. Create the marker file `~/.config/sysdig-bloom/disclaimer-shown-v1` using the Write tool (any short content, e.g. the current UTC timestamp). The Write tool creates parent directories automatically and avoids the shell-redirection restrictions imposed by some skills' allowed-tools lists.
4. Then continue with the user's request.


When you need to ask the user a question, get confirmation, or present choices, use the `AskUserQuestion` tool if available. This ensures proper rendering across all agent clients.

Remediate a single vulnerable image in a Sysdig-monitored environment. Locates the source code (GitHub, GitLab, or a local folder the user provides) and — where possible — opens a PR/MR or emits a patch file. If a ticket key is passed in, updates that ticket with the PR link on completion. This skill **never creates tickets** — run `/sysdig-investigate` first to discover/triage images and (optionally) file a tracking ticket.

> **To find and prioritize which images to remediate, run `/sysdig-investigate` first.**
> `/sysdig-investigate` fetches the investigation list, ranks images, optionally creates a tracking ticket, and hands off to this skill.

## Input

This skill expects a single image to work on. The image can be provided in any of these ways:
- As an argument: `/sysdig-remediate quay.io/org/app:tag`
- With an `image_id`: `/sysdig-remediate quay.io/org/app:tag (image_id: <id>)`
- With an existing ticket: `/sysdig-remediate quay.io/org/app:tag (image_id: <id>, ticket: <ticket_key>)`
- Interactively: if no image is provided, ask the user to specify one or run `/sysdig-investigate` to select from the investigation list.

The `ticket` argument is optional. When present, this skill updates the referenced ticket with the PR link on completion. When absent, the skill opens the PR without touching any ticketing system. **This skill never creates new tickets** — if a ticket is desired, run `/sysdig-investigate` to file one first.

## State

State is read and written via the Sysdig MCP server tools.

| Operation | Tool | Arguments |
|-----------|------|-----------|
| Read state | `get_skill_state` | `{ "skill_state": "remediate" }` |
| Write state | `save_skill_state` | `{ "skill_state": "remediate", "version": <n>, "data": { ... } }` |
| Delete state | `delete_skill_state` | `{ "skill_state": "remediate" }` |

A `null` response from `get_skill_state` means no state exists yet — start with `{ "version": 0 }`.
Every time a skill finds something new, it should update the state and save it back.

### Schema

```json
{
  "version": 1,
  "image_repo_mappings": [
    {
      "image_reference": "quay.io/myorg/my-service:1.2.3",
      "repository": "myorg/my-service",
      "confidence": "high",
      "discovered": "2025-03-15"
    }
  ],
  "repo_reviewers": [
    {
      "repository": "myorg/my-service",
      "reviewers": ["jane-doe", "john-smith"],
      "last_confirmed": "2025-03-15"
    }
  ],
  "vulnerability_resolutions": [
    {
      "package": "golang",
      "from_version": "1.20",
      "to_version": "1.25",
      "cves_fixed": ["CVE-2024-1234", "CVE-2024-5678"],
      "date": "2025-03-15"
    }
  ],
  "version_chains": [
    {
      "package": "golang",
      "chain": [
        { "version": "1.20", "status": "vulnerable" },
        { "version": "1.23", "status": "skipped", "reason": "CVE-2024-9999" },
        { "version": "1.25", "status": "clean" }
      ],
      "date": "2025-03-15"
    }
  ],
  "remediation_history": [
    {
      "date": "2025-03-15",
      "zone": { "ref_id": "123", "name": "production" },
      "image": "quay.io/myorg/my-service:1.2.3",
      "summary": "A short summary of the actions taken for the remediation",
      "prs_opened": ["myorg/my-service#42"],
      "reviewers_confirmed": ["jane-doe"],
      "ticket_updated": "PROJ-123"
    }
  ]
}
```

> **Breaking change (SSPROD-67797):** earlier versions of this skill stored
> `ticket_assignee` (top level), and `jira_tickets` / `assignee_confirmed`
> inside `remediation_history`. Those fields have moved to the
> `sysdig-investigate` skill state. If `get_skill_state` returns any of
> them, ignore them — they will be dropped on the next write.

### Read/write rules

- **Get** the state at the start of every session (step 1) by calling the MCP tool `get_skill_state` with `{ "skill_state": "remediate" }`. A `null` response means no state exists yet — start with `{ "version": 0 }`.
- **Save** the state at the end of every session (step 5) by calling the MCP tool `save_skill_state` with `{ "skill_state": "remediate", "version": <n>, "data": { ... } }`. Read the current contents first, merge new data (append to arrays, update existing entries by matching key fields), then pass the full merged object as `data`.
- **Version argument** — the server uses `version` for optimistic concurrency. Pass it as a separate argument (do not include it inside `data`):
  - First write (`get_skill_state` returned `null`) → call with `version: 0`. The server creates the record.
  - Subsequent writes → call with the same `version` value the previous `get_skill_state` returned. On success the server bumps it; on conflict it returns 409.
  - On 409 → call `get_skill_state` again, merge your changes into the freshly-read state, and retry once with the new version.
- **Matching keys** for upsert:
  - `image_repo_mappings`: match on `image_reference`
  - `repo_reviewers`: match on `repository`
  - `vulnerability_resolutions`: match on `package` + `from_version`
  - `version_chains`: match on `package` + first chain entry version
  - `remediation_history`: always append (no dedup)
- When updating an existing entry, replace it entirely with the new version (do not deep-merge fields).
- Dates use `YYYY-MM-DD` format.

## Steps

### 0. Prerequisites

**Sysdig MCP server.** Verify that the Sysdig MCP server is available by checking that the `get_customer_settings` tool exists. If it is not available, stop and **output the message below verbatim — do not paraphrase, expand, restructure, or drop sentences**:

> **Sysdig MCP server isn't reachable** (the tool `get_customer_settings` is missing). To register it in Claude Code:
>
> ```
> claude mcp add sysdig -- npx -y @sysdig/secure-mcp-server
> ```
>
> Set `SYSDIG_SECURE_API_TOKEN` and `SYSDIG_SECURE_URL` first, then re-run `/sysdig-remediate`. For other agents (Cursor, Codex, OpenCode) and troubleshooting: [`references/mcp-setup.md`](references/mcp-setup.md).

Do not proceed until the MCP server is reachable.

**Source code access (mandatory).** This skill produces a code patch — without source access there is nothing to deliver. Run the selection algorithm in [`references/source_control.md`](references/source_control.md) to detect a configured GitHub (`gh`/MCP), GitLab (`glab`/MCP), or a local folder the user points at. Record the chosen `source.kind` ∈ {`github`, `gitlab`, `local`} and `source.handle` (org/group/path) in working memory; later steps key off these.

If no source is reachable and the user cannot provide a local folder, stop with:

> I cannot remediate `<image>` without access to its source. The skill produces a code patch — there is no useful tracking-only mode. Configure a forge or point me at a local working tree, then re-run.

### 1. Load project context

Call the MCP tool `get_skill_state` with `{ "skill_state": "remediate" }`. A `null` response
means no state exists yet — start with `{ "version": 0 }`. Note any existing:
- `image_repo_mappings` — reuse known repo for this image instead of re-searching (confirm with user if older than 30 days)
- `repo_reviewers` — use as top-priority signal for PR reviewers (step 3b)
- `vulnerability_resolutions` — skip re-resolution if the same package+from_version was already verified clean
- `version_chains` — skip re-analysis if the same package+version was already investigated

### 1b. (Optional) Best-effort search for an existing ticket

Run only when **no `ticket` argument was passed in** and the skill was invoked standalone (not from `/sysdig-investigate`'s handoff). This step never creates tickets — it only discovers an existing one to adopt.

1. Detect whether a ticketing MCP/CLI is reachable (Jira / Linear / GitHub Projects). For supported systems and tool surfaces, see [`sysdig-investigate/references/ticketing.md`](../../sysdig-investigate/references/ticketing.md).
2. If none is reachable, skip this step silently.
3. Otherwise, ask the user (default **No**): _"No ticket was passed. Search for an open ticket related to `<image_name>` first?"_
4. If yes, search the system by image-name fragment in summaries (and the full image reference in descriptions). Filter to open tickets.
5. Result handling:
   - **Exactly one match** — show its key, summary, and assignee; ask the user to confirm adopting it.
   - **Multiple matches** — present the top 3 and let the user pick one or skip.
   - **No match** — tell the user; proceed with no ticket. Do not offer to create — direct them to `/sysdig-investigate` if they want one.
6. If the user confirms a ticket, treat its key as if it had been passed via the `ticket:` argument for the rest of this session — step 4b will update it on PR open.

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

Use the source kind selected in step 0 (`source.kind` ∈ `github` / `gitlab` / `local`). For per-provider command syntax, see [`references/source_control.md`](references/source_control.md).

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
If no confident match is found, present the top candidate repos to the user and ask:
"I found these repositories that might own this image — which one is correct, or should I switch to local-folder mode?"

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

Assess what kind of fix is possible using the safe target version resolved in step 3c:

**Case A — base OS / system package CVE (safe fix available):**
- The CVE affects a package installed by the OS package manager (apt, yum, apk)
- Fix: update the `FROM` line in the Dockerfile to a newer base image version, or add a `RUN apt-get upgrade` layer
- Action: **suggest a PR** against the Dockerfile

**Case B — application dependency CVE (safe fix available):**
- The CVE affects an npm, pip, maven, go, or gem package
- Fix: update the dependency version in the relevant manifest/lockfile
- Action: **suggest a PR** against the dependency file

**Case C — no safe fix version available:**
- Either no patched version exists, or every candidate version introduces new Critical/High CVEs
- Action: **no PR possible.** If a ticket key is set (via the `ticket:` argument or step 1b), append the analysis (versions checked, why none work) to that ticket via step 4b. If no ticket is set, stop and tell the user: _"No safe fix version is available. Run `/sysdig-investigate` to file a tracking ticket so this is not lost."_

**Case D — repo not located within the configured source:**
- The user has a configured forge (step 0 verified this), but step 3 failed to identify which repo owns the image build, and the user couldn't disambiguate.
- Action: **no PR possible.** Offer to switch to `local` mode (the user provides a folder path) and re-run step 3. If they decline: if a ticket key is set, append a note to that ticket via step 4b. Otherwise stop and tell the user: _"Source repo could not be located. Provide a local folder, or run `/sysdig-investigate` to file a tracking ticket."_

Present the user with the proposed action before doing anything:
"For `my-service`: I found the repo `myorg/my-service` and can open a PR to update Go from `1.20` to `1.25` (skipping `1.23` which has a Critical CVE). Shall I proceed?"

### 4. Open PR (and optionally update ticket)

If a PR is possible (Case A or B) and the user confirms, go to step 4a. After the PR is opened — or in Case C/D — go to step 4b only if **a ticket key is set**, either from the `ticket:` input argument or adopted in step 1b. Both sources go through the same update flow so the PR ↔ ticket cross-link always lands.

#### 4a. Open PR (or emit patch in local mode)

The existing-PR check already happened in step 3a — by the time you reach 4a no duplicate PR exists.

**GitHub or GitLab — open a PR/MR:**

1. Create a new branch: `sysdig/fix-<cve-id>-<image-name>` off the default branch.
2. Make the minimal change needed (Dockerfile FROM update, or dependency version bump), using the safe target version from step 3c.
3. Open the PR/MR with:
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
- <"PR opened — awaiting review" | "No safe fix available — see Case C analysis below" | "Repo not found">
```

- If a new Critical CVE was discovered relative to the existing ticket, note it but do **not** silently re-prioritise — leave priority and assignee untouched unless the user explicitly asks otherwise.
- Report back the ticket key and URL when the update succeeds.

If `ticket_key` update fails (ticket not found, permission error), warn the user and continue — do not block on the ticket update.

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

> **Version on write**: pass the same `version` value returned by the `get_skill_state` call in step 1 — or `0` if the call returned `null` (no prior state). The server bumps the version itself. See [Read/write rules](#readwrite-rules). Do not include `version` inside `data`.

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

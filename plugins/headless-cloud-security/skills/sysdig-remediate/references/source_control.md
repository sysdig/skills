# Source Control

The remediate skill is **mandatory-bound to source code**: the only deliverable is a patch (PR/MR or local diff) that fixes a vulnerability in the code that builds the image. Without read+write access to that code the skill has nothing to produce — stop the run with a clear message rather than fall back to a tracking-only workflow.

## Supported systems

The skill connects to a source control system through a CLI or any compatible MCP server (hosted or local) — the host agent decides which to use. Names below are common implementations, not requirements: any MCP that exposes equivalent capabilities (search, read, list commits, create branch, open PR) works.

One of the following must be available:

- **GitHub** — `gh` CLI or a GitHub MCP server
- **GitLab** — `glab` CLI or a GitLab MCP server
- **Local folder** — direct access to a checked-out working tree the user points the skill at (typically a git repo, but a plain source tree is acceptable for read-only inspection)

If none of these is reachable, stop the skill and tell the user that source access is mandatory. There is no useful tracking-only mode for this skill — opening a Jira/Linear/GH-Projects ticket without a patch is what `sysdig-investigate` already does.

## Selection algorithm

Run this in step 0 of `SKILL.md`, before touching any other tool. Stop on the first match — do not silently combine sources for one image.

1. **Check the cached mapping.** Read `image_repo_mappings` from the skill state. If an entry for the target image is less than 30 days old, infer the source kind from its `repository` field (e.g. `org/repo` → github; full HTTPS URL on a non-github host → gitlab; absolute filesystem path → local) and skip ahead to the **verify auth** step for just that kind.

2. **Probe each provider in this order: GitHub → GitLab.**
   - GitHub: `gh auth status` exits 0, *or* a GitHub MCP tool is callable. Resolve the user's orgs once via `gh api user/orgs --jq '.[].login'` and cache the list — step 4 needs it for org-scoped search.
   - GitLab: `glab auth status` exits 0, *or* a GitLab MCP tool is callable. Read `GITLAB_HOST` so self-hosted instances work — never hardcode `gitlab.com`.

3. **Probe the local fallback.** If the user passed a folder argument (e.g. `--source <path>`) or there is a `.git` directory under the cwd that the user confirms corresponds to the image, use `local`.

4. **None found.** Ask the user (via `AskUserQuestion` if available):

   > Remediation needs the source that builds this image. I couldn't find a configured source. Pick one:
   > 1. Configure `gh` or `glab` and retry
   > 2. Provide a local folder path
   > 3. Cancel

   On option 3 (or if the chosen option still doesn't work), stop with:

   > I cannot remediate `<image>` without access to its source. The skill produces a code patch — there is no useful tracking-only mode. Configure a forge or point me at a local working tree, then re-run.

5. **Record the choice** in working memory as `source.kind` ∈ {`github`, `gitlab`, `local`} and `source.handle` (the org/user, the GitLab group, or the absolute path). Later steps key off these.

If multiple providers are available, prefer the one that already owns the cached mapping for this image; otherwise prefer the order above. Don't re-ask the user once a choice has been made for the current image.

## Verifying auth before real work

Before step 4 starts traversing the repo, do one cheap read to fail fast. A successful probe means more than "credentials exist" — it confirms the API/host pair actually answers.

| Source | Probe | Pass criterion |
|---|---|---|
| GitHub | `gh api user --jq .login` | exit 0, non-empty output |
| GitLab | `glab api /user --jq .username` | exit 0, non-empty output |
| Local | `git -C <path> rev-parse --is-inside-work-tree` | exit 0, prints `true` |

If the probe fails, surface the error verbatim and ask the user to fix auth or switch source kinds. Do not silently fall back to a different provider — the user should know which credentials the agent is using.

## Capabilities the skill needs

Whatever the chosen source, the skill must be able to do all of these. If any one is impossible (e.g. read-only token, no PR scope), warn the user up-front and offer to switch to `local` mode rather than discovering it mid-flow.

| Capability | Used by | GitHub | GitLab | Local |
|---|---|---|---|---|
| Search code by content/filename | step 4 — find repo | `gh search code` / MCP `search_code` | `glab api` search (group-scoped) | `grep -r` on tree |
| Read file at default branch | step 4d — decide fix | `gh api repos/.../contents/...` / MCP `get_file_contents` | `glab api` files | direct file read |
| List commits filtered by path | step 4b — reviewers | `gh api repos/.../commits?path=` | `glab api` commits | `git log -- <path>` |
| Create branch | step 5a | `gh api ... refs` / MCP `create_branch` | `glab api branches` | `git checkout -b` |
| Commit a file change | step 5a | `gh api ... contents` / MCP `push_files` | `glab api` commit | `git commit` |
| Open a PR / MR | step 5a | `gh pr create` | `glab mr create` | n/a — emit `.patch` |
| Search existing PRs / MRs | step 4a | `gh pr list --search` | `glab mr list` | n/a |

## Per-system notes

### GitHub

- **Auth.** Prefer `gh auth status`; if it fails, `GITHUB_TOKEN` must be set with `repo`, `read:org`, and `read:user` scopes. The skill never asks the user to paste a token in chat — auto-discover from env vars only.
- **Org scoping.** Always restrict code search to orgs the user belongs to: `gh api user/orgs --jq '.[].login'`. Never push to a repo outside that set without explicit user confirmation (this rule lives in `SKILL.md` step 4 — restating here so the reference is self-contained).
- **Default branch.** `gh api repos/<owner>/<repo> --jq .default_branch`. Branch off this — never assume `main`/`master`. Many Sysdig customers still ship from `master` or have customised default-branch names.
- **Search examples.**
  - Repo by name: `gh search repos "<image-name> org:<org>"`
  - Dockerfile: `gh search code "FROM <base-image-name>" filename:Dockerfile org:<org>`
  - Manifest deploy: `gh search code "<image-reference>" extension:yaml org:<org>`

### GitLab

- **Auth.** `glab auth status`; or `GITLAB_TOKEN` + `GITLAB_HOST` for self-hosted. Read `GITLAB_HOST` rather than hardcoding `gitlab.com` — many Sysdig customers run self-hosted GitLab and the API base URL must match.
- **Group scoping.** GitLab search is project-scoped by default. Use group-level search to mirror GitHub's org-wide search:
  `glab api "/groups/<group>/search?scope=blobs&search=<query>"`
- **MR vs PR.** Replace "pull request" wording with "merge request" in user-facing prompts when `source.kind == gitlab`. Keep the PR title/body template from `SKILL.md` step 5a otherwise identical — assignee and reviewer fields map to GitLab's `assignee_id` / `reviewer_ids`.
- **Default branch.** `glab api projects/<id> --jq .default_branch`. Same rule as GitHub: branch off the actual default, not an assumed one.

### Local folder

This mode exists for users who can't or won't grant the agent forge access (regulated environments, air-gapped networks, or simply preference). It is a first-class mode, not a degraded one.

- The user provides an absolute path. Verify it exists, is a git working tree (`.git/` present), and is clean (`git status --porcelain` empty). A dirty tree confuses the diff — refuse and ask the user to commit/stash first.
- The "find the repo" logic in step 4 collapses to: *the repo is this folder*. Skip code search.
- For commit history (step 4b), use `git log --follow --pretty=format:'%H %ae %an' -n 5 -- <affected_file>`. Author email is on the same line so the bot-filter from `SKILL.md` step 4b applies unchanged (skip logins/emails containing `bot`, `renovate`, `dependabot`, `github-actions`, `[bot]`).
- Instead of opening a PR (step 5a), write two artifacts to the folder root and tell the user the paths:
  1. `sysdig-fix-<cve-id>.patch` — `git diff` of the proposed change against current HEAD. Apply with `git apply <patch>`.
  2. `sysdig-fix-<cve-id>.md` — the body content the PR would have had (summary, version-resolution chain, references). Lift the markdown straight from `SKILL.md` step 5a; the user can paste it into whatever PR template their workflow expects.
- Do **not** run `git commit`, `git push`, or modify any branch in local mode. Review and merge are the user's call.

## Failure handling

| Symptom | Likely cause | Action |
|---|---|---|
| Probe succeeds but code search returns no candidates | Image built from a repo outside the user's org/group, or under a different name | Ask the user for the repo name; on a second miss, offer local-folder mode. |
| Probe succeeds but PR creation 403s | Token lacks write scope, branch protection blocks direct push | Switch to local-folder mode rather than fighting the token; emit a patch artifact and tell the user why you switched. |
| Local folder is dirty | Uncommitted work in the working tree | Refuse to write a patch. Ask the user to commit/stash and retry — never silently include unrelated changes in the diff. |
| Cached mapping points at a repo the user no longer has access to | Org membership changed, repo archived/renamed | Drop the cached entry, re-run the selection algorithm, surface this to the user so they aren't surprised by a re-search. |
| Two providers both authenticated, neither has the cached mapping | Genuinely ambiguous | Use the probe order (GitHub before GitLab). If the search misses on the first, fall back to the second and tell the user which one you used. |

## What this file deliberately does NOT cover

- *Which* file to patch and *which* version to bump — see `SKILL.md` step 4c/4d (fix-chain analysis).
- PR / ticket body templating — see `SKILL.md` step 5a/5b.
- Reviewer/assignee selection logic — see `SKILL.md` step 4b.

This reference is the connection layer only: detecting a source, authenticating, and translating capability calls per provider.

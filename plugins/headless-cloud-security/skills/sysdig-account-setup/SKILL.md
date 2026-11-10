---
name: sysdig-account-setup
description: >
  Baseline account setup for Sysdig Secure after a tenant is connected. Guided,
  interactive, modular setup via the Sysdig MCP server: (1) access baseline —
  teams, users, and roles; (2) vulnerability management policy baseline —
  Pipeline vs runtime, one policy or split; (3) compliance standards — assign
  posture policies (CIS, PCI, NIST, …) to zones; (4) runtime threat-detection —
  enable/disable the recommended managed detection policies. Reviews current
  state, proposes a structure, and applies changes idempotently with explicit
  confirmation before anything that mutates the tenant. Use right after onboarding
  to leave an account usable out of the box. Fine-grained policy tuning is out of
  scope.
allowed-tools:
  - Read
  - Write
  - AskUserQuestion
  - mcp__secure-mcp-server__get_current_user
  - mcp__secure-mcp-server__get_user_permissions
  - mcp__secure-mcp-server__list_zones
  - mcp__secure-mcp-server__list_teams
  - mcp__secure-mcp-server__create_team
  - mcp__secure-mcp-server__update_team
  - mcp__secure-mcp-server__save_team_membership
  - mcp__secure-mcp-server__list_users
  - mcp__secure-mcp-server__create_user
  - mcp__secure-mcp-server__update_user
  - mcp__secure-mcp-server__list_roles
  - mcp__secure-mcp-server__get_default_role
  - mcp__secure-mcp-server__list_vulnerability_policies
  - mcp__secure-mcp-server__list_vulnerability_bundles
  - mcp__secure-mcp-server__create_vulnerability_policy
  - mcp__secure-mcp-server__update_vulnerability_policy
  - mcp__secure-mcp-server__list_posture_policies
  - mcp__secure-mcp-server__get_zone_posture_policies
  - mcp__secure-mcp-server__set_zone_posture_policies
  - mcp__secure-mcp-server__list_runtime_policies
  - mcp__secure-mcp-server__update_runtime_policy
version: 1.0.2
---

## First-run notice

Before doing any other work for this skill, follow [`references/first-run-notice.md`](references/first-run-notice.md) exactly.


This skill describes steps by capability, not by tool name: *ask a structured question*, *get explicit confirmation*, *write a file*, *run a command*. Follow [`references/agent-capabilities.md`](references/agent-capabilities.md) for how to do each one with your agent's tools, and what to do when a capability is missing — including when nobody can answer a question.

## On-brand output

If you're ever asked to generate a custom report or document — not this skill's normal output — keep it on-brand per [`references/on-brand-output.md`](references/on-brand-output.md), or hand off to the `sysdig-report` skill if it's installed. Opt-in guidance, never a requirement.

# Sysdig Account Setup

You configure the operational baseline of a freshly connected Sysdig Secure
tenant. Onboarding connects the infrastructure; this skill leaves the account
usable. All work is done through the **Sysdig MCP server** — no API token or
`curl` is needed; the MCP's authenticated session (the same one used for reads)
performs the writes, and the write tools encapsulate the API's sharp edges
(mandatory team scopes, posture replace-semantics, full-object policy updates).

It is **modular** — the user picks which domain(s) to set up:

- **Access baseline** — teams, users, and roles (people can log in, land on the
  right team, and have the right permissions). See
  [references/teams-users-roles.md](references/teams-users-roles.md) and Flow A.
- **Vulnerability policy baseline** — a VM policy for Pipeline and/or runtime,
  one policy or split. See [references/vm-policies.md](references/vm-policies.md)
  and Flow B.
- **Compliance standards** — assign posture policies (CIS, PCI, NIST, …) to
  zones. See [references/compliance.md](references/compliance.md) and Flow C.
- **Runtime threat-detection** — enable/disable the recommended managed detection
  policies (on/off only). See [references/runtime-policies.md](references/runtime-policies.md)
  and Flow D.

**Out of scope (do not attempt here):** fine-grained policy/rule/control tuning,
SSO/SAML, SCIM, and per-user profile preferences. Those are separate milestones.
If the user asks, say they are not part of this baseline yet and point them to a
future session.

## Principles

- **Ask, don't assume.** Interview the user before creating anything.
- **Explain WHY, not just WHAT.** People trust changes they understand.
- **One question per turn.** Never bundle unrelated choices.
- **Narrate high-level actions, not tool calls.** Say "listing the current
  teams", not "calling `list_teams`".
- **Idempotent by construction.** Always read current state first and match
  existing resources before creating. Re-running the skill must never duplicate.
- **Never bundle confirmations.** Every mutating batch (create teams, invite
  users, assign roles, create/enable policies) gets its own explicit yes.
  Inviting a user sends them an email — treat it as outward-facing and confirm.
- **Read the backend before asking.** Discover the current teams/users/policies/
  assignments first and reuse what's already there instead of re-prompting; the
  backend is the source of truth (no persisted skill state).

## Preflight

1. **MCP auth** — before anything else, run the check in
   [references/auth-preflight.md](references/auth-preflight.md). Do not proceed
   until the MCP catalog is available (State 1). This skill needs the MCP server;
   there is no token/`curl` fallback.
2. **Trust preamble** — present [references/trust-preamble.md](references/trust-preamble.md)
   verbatim, then proceed directly to Step 0 (do not ask for confirmation; it is
   informational).

## Flow

### Step 0 — Admin check (shared)

Confirm the caller can make the changes: call `get_current_user` (and
`get_user_permissions` if needed). Baseline setup needs admin-level permissions;
each flow needs different ones:
- **Flow A** (access): `teams.create`, `users.create`, `memberships.edit`
- **Flow B** (VM): `secure.vm.policies.write`
- **Flow C** (compliance): `posture-policies.edit`
- **Flow D** (runtime): `policies.edit`

If the user is not an Admin (or lacks the permission for a selected flow),
**stop** for that flow and tell them they need an Admin — do not attempt its
mutating steps.

### Step 0b — Choose domain(s)

Ask which baseline(s) the user wants to set up now (one question, multi-select):

- **Access baseline** — teams, users, roles → run **Flow A**.
- **Vulnerability policy baseline** — Pipeline/runtime VM policy → run **Flow B**.
- **Compliance standards** — assign posture standards to zones → run **Flow C**.
- **Runtime threat-detection** — enable/disable managed detection policies → run
  **Flow D**.

Run the selected flows in order; a user may pick any combination. Skip the
flow(s) they don't choose.

---

## Flow A — Access baseline (teams, users, roles)

### Step A1 — Discover current state (read-only)

- `list_teams`, `list_users`, `list_roles`.
- Summarize what already exists (team count, the default team, user count,
  available roles). This grounds the interview and prevents re-proposing what's
  there. The backend is the source of truth — this live read is what makes the
  skill idempotent and safely re-runnable; there is no persisted skill state.
  Mutate nothing in this step.

### Step A2 — Team structure

Interview the user on how they want teams organized. Offer baseline options:

- **(a) Keep the default team only** — smallest footprint; fine for small teams.
- **(b) Split by environment/product** — e.g. `secure-prod`, `secure-dev`; a
  common baseline.
- **(c) Custom** — the user names the teams.

For any team that should be scoped to specific zones, offer the zone list via
`list_zones` and collect `zone_ids` (otherwise all zones). Do not create anything
yet — collect intent.

### Step A3 — Default roles per team

Present the built-in **standard team roles** from the `ROLE_TEAM_*` table in the
reference (these are always available; do **not** rely on `list_roles`, which
returns only tenant-defined *custom* roles and is empty on a fresh tenant).
`get_default_role` takes a role's **display name** and returns the permissions it
grants — use it to explain trade-offs. For each team, pick the
`standard_team_role` new members get by default and pass the **`ROLE_TEAM_*`
enum** (not the display name). Only surface custom roles (`list_roles` →
`custom_team_role_id`) if the user explicitly wants one. Collect intent.

### Step A4 — Invite users

Collect the users to add: email (required), first/last name, target team + role,
and whether they are an account Admin. Also ask **whether to send each user an
invitation email now**: `create_user` defaults to `send_activation_email: false`
(creates the account silently — no email), and only `send_activation_email: true`
emails the person so they can activate/log in. Since "Invite users" implies they
should be able to log in, confirm this choice explicitly — sending the email is
the outward-facing act. Collect intent; do not create yet.

### Step A5 — Apply (idempotent, confirmed per batch)

Confirm and apply in dependency order, matching against the Step A1 lists:

1. **Teams** — match by name. Missing → `create_team` (for `product: secure` the
   tool auto-includes the mandatory `HOST_CONTAINER` **scope** — pass explicit
   `scopes` only to narrow *what data* the team sees; set zone **visibility**
   separately via `is_all_zones` (default) xor `zone_ids`). Present → `update_team`
   if fields differ, else skip. Skip immutable/system default teams.
2. **Users** — match by email. Missing → `create_user`; set
   `send_activation_email: true` **only** for users the person chose to invite
   (that email send is the outward-facing act — confirm it specifically);
   otherwise it defaults to `false` and the account is created silently. Present →
   skip creation (optionally `update_user` for name/admin fixes).
3. **Memberships & roles** — `save_team_membership` (idempotent upsert) with the
   chosen `standard_team_role`, using the numeric `team_id`/`user_id` resolved
   from the `list_teams`/`list_users` results.

Confirm each batch separately. Report every action as
`created` / `updated` / `skipped` / `failed` with the resource name. On a tool
error, surface the message and stop that batch — do not retry blindly.

---

## Flow B — Vulnerability policy baseline

Read [references/vm-policies.md](references/vm-policies.md) first — model (bundles
+ stages), enforcement blast radius, and the tools.

### Step B1 — Discover current state (read-only)

`list_vulnerability_policies` (existing policies + their stages) and
`list_vulnerability_bundles` (available rule sets). Summarize; mutate nothing.

### Step B2 — Choose shape (Pipeline vs runtime, one vs split)

Interview:
- Which **stages**: `pipeline`, `runtime`, `registry`. Default baseline =
  `pipeline` + `runtime`. Note a `pipeline` stage **gates CI by its mere presence**
  (a failing scan can break the build) — call this out. **Do not** add
  `admission_control` with `behaviour: reject` unless the user explicitly asks — it
  can block Kubernetes deployments.
- **One policy for everything** (single multi-stage policy) **or split** (one per
  stage). Explain the trade-off.
- Which **bundle(s)**: default to `Severe vulnerabilities with a Fix`; match by
  name in `list_vulnerability_bundles` and pass its `id`. Collect intent.

### Step B3 — Apply (idempotent, confirmed)

Match policies by name (Step B1 list). Missing → `create_vulnerability_policy`;
present → `update_vulnerability_policy` if bundles/stages differ, else skip.
**Confirm before creating any gating stage** (`pipeline`, or `admission_control`
with `reject`) — state the blast radius. Report
`created`/`updated`/`skipped`/`failed`. Never delete an existing policy unless the
user explicitly asks.

---

## Flow C — Compliance standards (Posture)

Read [references/compliance.md](references/compliance.md) first. A compliance
standard = a **posture policy**; you make it active by assigning it to a **zone**.

### Step C1 — Discover catalog + current state (read-only)

- `list_posture_policies` (`is_custom=false, is_active=true`) → the catalog of
  built-in standards (each has `id`, `name`, `zones[]`).
- `list_zones` → the zones to assign to.
- `get_zone_posture_policies({ zone_id })` per candidate zone → current
  assignment. Summarize which standards are already assigned where. Mutate nothing.

### Step C2 — Choose standard(s) + target zone(s)

Interview: which standard(s) (e.g. CIS AWS Foundations, PCI DSS, NIST, or
`All Posture Findings` as a broad default) and which zone(s). Match standards by
name in the catalog and use their `id`. Collect intent.

### Step C3 — Assign (idempotent, confirmed)

Per (zone, standards): if all chosen IDs are already assigned, **skip**. Otherwise
call `set_zone_posture_policies({ zone_id, policy_ids, mode: "add" })` — `add`
(the default) unions with the current assignment, so other standards on the zone
are preserved. Only use `mode: "replace"`/`"remove"` on explicit request (replace
is destructive — confirm). Pass only IDs read from the catalog. Confirm before
applying. Report `assigned`/`skipped`/`failed` per (zone, standard).

---

## Flow D — Runtime threat-detection policies (enable/disable)

Read [references/runtime-policies.md](references/runtime-policies.md) first.
Runtime policies are on/off; this flow does the initial enablement of recommended
managed policies — no per-rule tuning.

### Step D1 — Discover current state (read-only)

`list_runtime_policies`. Summarize per `type` (falco, drift, malware,
machine_learning, k8s_audit, cloud types, windows): how many managed
(`origin: Sysdig`) exist and how many are already `enabled`. Mutate nothing.

### Step D2 — Choose what to enable

Interview: which detection categories are relevant to the connected environment
(e.g. `falco`/`drift`/`malware`/`k8s_audit` for Kubernetes; a cloud type only
where that cloud is connected). Default proposal = enable the managed
(`origin: Sysdig`) policies for the relevant categories that are currently off.
Collect intent. Do not propose bulk-disabling.

### Step D3 — Apply (idempotent, confirmed)

Per policy: if already at the desired state, **skip** (pre-check). Otherwise call
`update_runtime_policy({ policy_id, enabled })` — the tool does the
read-modify-write (full-object PUT) for you. **Confirm before a bulk enable** — it
raises alert volume (it does not block workloads). **Never bulk-disable** managed
policies or delete any policy unless explicitly asked. Report
`enabled`/`disabled`/`skipped`/`failed`.

---

## Wrap-up (shared)

- Print a summary table of everything applied (teams/users/roles, VM policies,
  compliance standards, and/or runtime policies), summarized live from the same
  `list_*` reads — nothing is persisted; a re-run re-discovers current state.
- Suggest next steps in a new session (not part of this baseline yet):
  fine-grained policy/rule/control tuning and per-user profile preferences.

## Handling edge cases

- **Not an Admin / missing permission** → stop the affected flow at Step 0 with a
  clear message.
- **MCP not available** → stop at preflight (see auth-preflight.md); there is no
  token fallback.
- **Name/email collisions** → treat as "already exists", update or skip; never
  duplicate.
- **Partial failure mid-apply** → report what succeeded and stop the failing
  batch. A re-run resumes cleanly on its own: the Discover step re-reads the
  backend and list-then-match skips what already applied (no saved state needed).
- **File writes denied** → present summaries in a code block instead.

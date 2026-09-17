---
name: sysdig-sysql
description: >
  SysQL query language reference for Sysdig Secure. Use when writing, debugging, or
  explaining SysQL graph queries against the Sysdig security datastore. Triggers on:
  SysQL queries, Sysdig inventory/vulnerability/posture/identity/runtime queries,
  "write a SysQL query", "query sysdig for", "find vulnerable images", "show me
  workloads", or any task involving MATCH/RETURN syntax against Sysdig entities.
  Also use when exploring the SysQL schema (entities, fields, relationships).
  Each query's entities and fields are validated against the live schema before it
  is shown and run, and the results are presented with follow-up suggestions.
allowed-tools:
  - AskUserQuestion
  - Read
  - Write
  - mcp__secure-mcp-server__run_sysql
  - mcp__secure-mcp-server__generate_sysql
  - mcp__secure-mcp-server__get_sysql_entity
  - mcp__secure-mcp-server__list_sysql_entities
version: 1.0.2
---

## First-run notice

Before doing any other work for this skill, follow [`references/first-run-notice.md`](references/first-run-notice.md) exactly.

When you need to ask the user a question, get confirmation, or present choices, use the `AskUserQuestion` tool if available. This ensures proper rendering across all agent clients.

## On-brand output

This skill's output is SysQL query results (tables in chat), not a presentation document. If you're ever asked to turn results into a custom report or document, keep it on-brand per [`references/on-brand-output.md`](references/on-brand-output.md) (or hand off to the `sysdig-report` skill, if it's installed) — opt-in guidance, never a requirement.

# SysQL Query Language

SysQL is a Sysdig proprietary, graph query language. It models cloud and container security data as a graph of **entities** (resources, vulnerabilities, controls, identities, runtime events) connected by **relationships** (`AFFECTED_BY`, `HAS_INSTALLED`, `IN`, `VIOLATES`, …). Translate the user's natural-language request into a precise query, validate its entities and fields against the live schema, show the query, run it, and present the result.

Refer to [`references/sysql_reference.md`](references/sysql_reference.md) for the complete language reference.

## Trust preamble

**What I'll do:**

- Build a SysQL query from your natural-language question.
- **Validate it against the live Sysdig schema before running** — confirm every entity, field and relationship really exists, and correct guessed names (e.g. a wrong `Vulnerability.fixAvailableAt` → the real `fixDate`).
- **Show you each query right before I run it** — the main one *and* every exploratory or diagnostic one — in a fenced code block, but **only once it's validated against the live schema** (never a draft, guess, or invalid query). I never state a finding without showing the query behind it, and close with the synthesised analysis. This holds for **every** question, including every follow-up.
- Suggest follow-up questions so you can dig deeper.
- Fall back to the `generate_sysql` MCP tool if I can't build a valid query, then show you that query with its results like any other.

**What I won't do:**

- SysQL is **read-only**: no mutation, deletion, or write operations.
- Never read, write, or display credential values. Tokens come from your environment.
- I won't discover field/entity mistakes at run time when I can catch them first: I verify them against the live schema before running.
- I'll only ask you about a genuinely ambiguous value (when several **real** values plausibly match your intent).

## Workflow

> ### 🔒 Golden rule — show before you run
> You may **not** call `run_sysql` unless its exact query is already printed in a fenced ```sql block in your reply, immediately above that call. **Every** query, **no exceptions** — the main query *and* every count / existence / diagnostic check. If you state **any** result — a number, "0 rows", "no GCP data", "there are 18 EC2s", "0 overlap" — the query that produced it **must** appear right above it. A finding without its query is a bug. (You'd be most tempted to skip this for quick diagnostic counts — don't.)

### 0. Preflight

Run the preflight in [`references/auth-preflight.md`](references/auth-preflight.md) and follow it exactly — the MCP server must be reachable for `run_sysql`/`generate_sysql`. If it says abort, abort. If a later tool call fails, use the diagnostic checklist in [`references/mcp-setup.md`](references/mcp-setup.md).

Step 2 (live-schema validation) is the **primary** correctness check. It uses the MCP schema tools (`list_sysql_entities` to discover, `get_sysql_entity` to inspect one entity), which share the same MCP authentication as `run_sysql` — so no extra credentials are needed: if the server is reachable for queries, it's reachable for the schema. If a schema tool call fails, follow step 2's fallback.

### 1. Draft — internal, do not show yet

Work out the query **shape**: which entities and relationships to use. Discover them **live via MCP** — `list_sysql_entities` for the entity list, then `get_sysql_entity` for the fields + relationships of each entity you'll use. Use the language syntax in [`references/sysql_reference.md`](references/sysql_reference.md). Reuse data already in the query before traversing (e.g. `RuntimeEvent.hostName` instead of joining `Host`); always filter zones by numeric **zone ID**. Self-check it answers the question (e.g. "critical vulns" needs `severity = 'Critical'`, not a bare `MATCH Vulnerability`). Add a sensible `LIMIT` (default 50, max 1000).

This draft is **scratch — do not print it.** Never guess field or relationship names — they come from the MCP schema tools (step 2); the draft only settles which entities/relationships you'll use.

Apply these **filter conventions as you write**:
- **Names / free-text** (workload, image, package, control, CVE, username): use a case-insensitive regex match, e.g. `c.name =~ '(?i).*nginx.*'`, not `=`.
- **Resource types**: substring/case-insensitive match, e.g. `r.type =~ '(?i).*s3.*'`.
- **Traversal & branching — keep it minimal and adherent to the question**: traverse only the entities the question is about, via the **most direct relationship** between them. The live schema usually exposes a direct (often virtual) edge — use `EC2Instance HAS_ACCESS S3Bucket`, **don't** hand-expand it through `IAMInstanceProfile → IAMRole → …` that the question never mentioned, just to keep one `MATCH`. A single linear `MATCH` is fine for a **direct** chain; to branch from the same node, or to avoid routing through irrelevant entities, use **multiple `MATCH`** clauses that repeat the shared alias, each with an explicit relationship (`MATCH k AFFECTED_BY Vulnerability AS v` / `MATCH k GENERATES RuntimeEvent AS e`). **No** comma multi-path (`MATCH a REL b, a REL c`) and **no** Cypher-style `WITH <var>`.
- **Negation**: `field =~ '^(?!value).*'` (SysQL has no `!~`).
- **IPs in RETURN**: guard with `WHERE entity.publicIPs != NULL` (or `privateIPs`).
- **Enumerations / regions**: normalise from your own knowledge — severities are `Critical`, `High`, `Medium`, `Low`, `Info`; regions are canonical cloud regions (`us1`/`virginia` → `us-east-1`, `oregon` → `us-west-2`, `frankfurt` → `eu-central-1`, …). Use single quotes for string literals.

### 2. Build the final query from the live schema (authoritative)

The **live schema — not the static docs — decides which fields and relationships are real.** For every entity in the draft, fetch its live definition and set the query's fields/relationships from it:

1. For each distinct entity, call **`get_sysql_entity`** (`entity_name: <EntityName>`) once — reuse the result within the session, don't re-fetch. The response is authoritative: its `fields` are the only valid field names, and its `relationships` (each with a name + target entity) the only valid traversals. (Use `list_sysql_entities` first if you're unsure an entity exists.)
2. Make every `entity.field` and every relationship in the query a name that actually appears in these responses. Replace any guess that isn't there — e.g. `Container` has `imageReference`, **not** `image`/`imageName`; `Vulnerability` has `fixDate`, **not** `fixAvailableAt`. For a multi-hop path, fetch **each** hop's entity and chain through its real relationships.

The query is final only once every field and relationship is confirmed against these live responses.

**Fallback (degraded).** If the schema tools are unavailable (server unreachable or erroring), draft from your own knowledge of the data model and let the `run_sysql` `422` be the validator; reach for `generate_sysql` sooner. This is the only situation where a query may be shown without prior live validation.

### 3. Show each query live, then run it

**Before every `run_sysql` call, print the query you're about to run** in a fenced ```sql block — the user watches each query in real time, in order, right before it executes. Then call `run_sysql`. Show **only a validated query** — one whose entities, fields and relationships you've confirmed in step 2; **never** show a draft, a guess, or an unvalidated query.

Run as many queries as the analysis needs — discovery, the main query, **diagnostics when results are empty** ("are there any exposed EC2s at all?"), drill-downs — and show **each** one in its own block before its call.

- **`422` parse error** (rare, since step 2 validated it) → fix it and show **only** the corrected, valid query for the re-run; don't leave an invalid query standing. Common cause: SysQL is not Cypher, so `WITH <var>` carried into a following `MATCH` is invalid — use repeated `MATCH` with a shared alias (see [`references/sysql_reference.md`](references/sysql_reference.md)). After **2** failed fixes, fall back to `generate_sysql`.
- **0 rows** is **not** an error.

> Every query you display is **valid and validated**. **Never run a query the user hasn't just seen**, and **never state a finding** (a count, "there are 18…", "0 overlap") **without the query shown right above it.** This holds for the first question and every follow-up.

### 4. Present the analysis at the end

The queries are already shown inline (step 3) — **don't re-list them.** Close with the synthesised answer: a one-line headline, then the results as a table (lead with the most important columns — severity, name, affected resource). When results are empty or partial, add a short explanation of what the data does and doesn't cover (a small table or bullets), grounded in the queries already shown above.

**Limits and truncation.** If no `LIMIT` was set, the server default is 50; max is 1000. When the row count equals the `LIMIT`, the result is likely truncated — say so:

> Showing 50 of (likely more) results. Increase `LIMIT` (max 1000) or add filters to narrow down.

### 5. Suggest follow-ups

Suggest 3 in-scope follow-up questions to help the user dig deeper. When results are available, fill placeholders (e.g. `<resource-name>`) with values from the question or the results; when none are available yet, show placeholders as inline code. Keep them coherent with the question and within [Scope](#scope).

When the user picks a follow-up (or asks anything new), **restart from step 1** — validate against the live schema, show each validated query right before running it, and close with the analysis. Every time.

## Schema tools (MCP)

The live SysQL schema is fetched through the MCP server (same authentication as `run_sysql` — no extra credentials):

- **`list_sysql_entities`** (optional `show_hidden`) — the list of queryable entities, for live discovery.
- **`get_sysql_entity`** (`entity_name`, optional `show_hidden`) — one entity's real fields + relationships. The validation workhorse (step 2): call it for each entity you'll use.

## Examples

### Full flow (schema-validated, query shown first)

> User: "vulnerabilities with known exploits, with the date a fix became available"

Draft → validate with `get_sysql_entity` (`entity_name: Vulnerability`) — the response has `hasExploit`, `hasFix`, `fixDate`, `cvssScore` but **no** `fixAvailableAt`, so use `fixDate` → show the query → run via `run_sysql`:

```sql
MATCH Image AS i HAS_INSTALLED Package AS p AFFECTED_BY Vulnerability AS v
WHERE v.hasExploit = true AND v.hasFix = true
RETURN i.imageReference, v.name, v.severity, v.fixDate
ORDER BY v.severity DESC
LIMIT 50;
```

Then the results table, then 3 follow-ups.

### Multi-hop, fields from the live schema

> User: "list the container images running in the `prod-cluster` k8s cluster"

`Container`'s fields aren't known up front, so don't guess. Call `get_sysql_entity` for `KubeWorkload` (shows a `HAS`/`RUNS` → `Container` relationship) and for `Container` (shows `imageReference`, **not** `image`/`imageName`). Build and show the validated query, then run:

```sql
MATCH KubeWorkload AS k HAS Container AS c
WHERE k.clusterName =~ '(?i).*prod-cluster.*'
RETURN DISTINCT c.imageReference
LIMIT 50;
```

### Disambiguating a value (the only time a question is asked)

> User: "Which workloads violate the S3 control?"

The control filter is a case-insensitive substring match, so no lookup is needed. Only if several **real** controls plausibly match the intent do you ask via `AskUserQuestion` before running.

### More examples

```sql
# Workloads in production affected by critical vulns
MATCH KubeWorkload AS k AFFECTED_BY Vulnerability AS v
WHERE v.severity = 'Critical' AND k.namespaceName = 'production'
RETURN k.name, k.clusterName, v.name, v.cvssScore;

# Branch from the same node: workloads with a critical vuln AND a runtime event
MATCH KubeWorkload AS k AFFECTED_BY Vulnerability AS v WHERE v.severity = 'Critical'
MATCH k GENERATES RuntimeEvent AS e
RETURN DISTINCT k.name, k.namespaceName;
```

## Error handling

Report problems with the **What happened → Why → What to do next** pattern.

- **`run_sysql`/`generate_sysql` tools missing.** The MCP server isn't reachable → follow the diagnostic checklist in [`references/mcp-setup.md`](references/mcp-setup.md); report only the specific failing step.
- **A tool call comes back _denied_.** The agent refuses a `mcp__secure-mcp-server__*` call rather than the server erroring — a **prefix mismatch**, not unreachability: the server is registered under a different prefix → apply the "denied / prefix mismatch" fix in [`references/mcp-setup.md`](references/mcp-setup.md); don't retry the denied call.
- **Schema validation unavailable.** A schema tool (`list_sysql_entities` / `get_sysql_entity`) errors or the server is unreachable → draft from your own knowledge and let the `run_sysql` execution surface a `422` parse error, then fix from that message.
- **Execution error / `422`.** Handled by step 3 (read the parse error → fix → re-validate → re-run, max 2, then `generate_sysql`). Surface to the user only if the fallback also fails — don't pretend it succeeded.
- **Empty result set.** The query is valid but returned zero rows.
  - *Why (likely):* a filter value that doesn't exist in this tenant, a too-strict filter, or data outside your scope.
  - *Fix:* list the real values with a `RETURN DISTINCT Entity.field` query, loosen the filter, or check the zone/account scope. Offer to re-run with the change.
- **Result hit `LIMIT`.** Communicate the likely truncation; offer to raise `LIMIT` (max 1000), paginate with `OFFSET`, or add filters.

## Scope

You can analyze the CSPM areas listed in [`references/cspm_questions.md`](references/cspm_questions.md). If a question falls outside, apologize and suggest a possible in-scope alternative.

### Risks and findings

We talk about **risks** for misconfigurations or risky conditions (e.g. exposed workloads with critical vulnerabilities, publicly exposed S3 buckets, resources with failed controls) and about **findings** when a risk is actually present (e.g. critical vulnerabilities, publicly exposed resources, vulnerabilities with an exploit, failed controls).

## References

- [`references/sysql_reference.md`](references/sysql_reference.md) — complete language reference (syntax). Entities, fields and relationships come from the live MCP schema tools (`list_sysql_entities` / `get_sysql_entity`), not from a static file.
- [`references/cspm_questions.md`](references/cspm_questions.md) — catalog of supported CSPM questions and scope.
- [`references/mcp-setup.md`](references/mcp-setup.md) — register the `secure-mcp-server` and the diagnostic checklist.
- [`references/auth-preflight.md`](references/auth-preflight.md) — pre-flight to run before any MCP call.

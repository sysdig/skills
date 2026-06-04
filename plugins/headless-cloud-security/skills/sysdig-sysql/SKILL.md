---
name: sysdig-sysql
description: >
  SysQL query language reference for Sysdig Secure. Use when writing, debugging, or
  explaining SysQL graph queries against the Sysdig security datastore. Triggers on:
  SysQL queries, Sysdig inventory/vulnerability/posture/identity/runtime queries,
  "write a SysQL query", "query sysdig for", "find vulnerable images", "show me
  workloads", or any task involving MATCH/RETURN syntax against Sysdig entities.
  Also use when exploring the SysQL schema (entities, fields, relationships).
allowed-tools:
  - AskUserQuestion
  - Read
  - Write
  - mcp__secure-mcp-server__run_sysql
  - mcp__secure-mcp-server__generate_sysql
---

## First-run notice (Public Beta)

Before doing any other work for this skill, perform this one-time check:

1. If `~/.config/sysdig-bloom/disclaimer-shown-v1` exists, skip the rest of this section.
2. Otherwise, display the following message to the user verbatim, preserving the markdown link, in a single message:

   > This plugin is a Public Beta release. It is provided "as is" and "as available," without warranties of any kind. By installing this plugin, you agree to the Public Beta Terms available in the [repository readme](https://github.com/sysdig/skills#public-beta-terms).

3. Create the marker file `~/.config/sysdig-bloom/disclaimer-shown-v1` using the Write tool (any short content, e.g. the current UTC timestamp). The Write tool creates parent directories automatically and avoids the shell-redirection restrictions imposed by some skills' allowed-tools lists.
4. Then continue with the user's request.

When you need to ask the user a question, get confirmation, or present choices, use the `AskUserQuestion` tool if available. This ensures proper rendering across all agent clients.

# SysQL Query Language

SysQL is a Sysdig proprietary, graph query language. It models cloud and container security data as a graph of **entities** (resources, vulnerabilities, controls, identities, runtime events) connected by **relationships** (`AFFECTED_BY`, `HAS_INSTALLED`, `IN`, `VIOLATES`, …). Translate the user's natural-language request into a precise SysQL query, run it, and present the result.

Refer to [`references/sysql_reference.md`](references/sysql_reference.md) for the complete language reference.

## Trust preamble

**What I'll do:**

- Build SysQL queries from your natural-language question.
- **Read** data from your Sysdig Secure datastore via the `run_sysql` MCP tool.
- Show the query I'm about to run, so you can inspect it before results come back.
- If I can't build a working query in 3 attempts, fall back to the `generate_sysql` MCP tool and show you the regenerated query before running it.
- Communicate when results are truncated by `LIMIT`.

**What I won't do:**

- SysQL is **read-only**: no mutation, deletion, or write operations against your Sysdig data.
- Never read, write, or display credential values. Tokens come from your environment.

**What I'll ask before:**

- Disambiguating filter values (e.g. which `Control` you mean) when the user request matches multiple.

## Workflow

### 0. Prerequisites

**MCP authentication preflight.** Before any other step, run the preflight in [`references/auth-preflight.md`](references/auth-preflight.md) and follow its instructions exactly. If it tells you to abort, abort — do not call any MCP tools or perform other side effects.

If a tool call later fails during normal operation, use the diagnostic checklist in [`references/mcp-setup.md`](references/mcp-setup.md) to identify the specific failure.

Do not proceed until the MCP server is reachable.

### 1. Identify entities and relationships

Use [`references/schema.md`](references/schema.md) to find relevant entities and their fields. Each entity section lists its fields (with type and description) and the names of its public relationships. Use [`references/relationships.md`](references/relationships.md) to discover direct and indirect paths between entities that lack an obvious relationship.

### 2. Check existing entities first

Before traversing to a new entity to read a field, check whether entities **already in your query** carry the data you need. Example: `RuntimeEvent.hostName` already contains the hostname — no need to traverse to `Host`.

### 3. Resolve filter values

When applying filters (`WHERE Entity.property = "foo"`), make sure the value actually exists. Common subroutines:

1. **Controls** — if the question relates to violating or accepting controls, fetch the list first:
   ```
   MATCH Control RETURN DISTINCT Control.name LIMIT 1000;
   ```
   Match the user's intent to one of the returned names. When ambiguous, present the candidates with `AskUserQuestion` and let the user pick.

2. **Cloud resource types** — if the user names a specific resource type:
   ```
   MATCH CloudResource RETURN DISTINCT CloudResource.type LIMIT 1000;
   ```
   Match the user's intent against the result; ask for clarification when ambiguous.

3. **Kubernetes workload types** are: `Job`, `ReplicaSet`, `StatefulSet`, `Pod`, `Deployment`, `CronJob`, `DaemonSet`.

4. **Regions** — when the question involves regions, run a query first to list the available regions without filters, then answer the user's question.

5. **Use regex matching when in doubt**:
   ```
   MATCH CloudResource AFFECTED_BY Vulnerability
   WHERE Vulnerability.packageName =~ '(?i).*glibc.*'
   RETURN DISTINCT CloudResource, Vulnerability;
   ```
   ```
   MATCH S3Bucket VIOLATES Control
   WHERE S3Bucket.isExposed = true AND Control.name =~ '(?i).*s3.*'
   RETURN DISTINCT S3Bucket, Control
   LIMIT 50;
   ```

6. **Always use zone IDs** when filtering by zone, not zone names. Zones are addressed by their numeric ID.

### 4. Write the query

Use the syntax in [`references/sysql_reference.md`](references/sysql_reference.md). Prefer composing the query yourself; fall back to the `generate_sysql` MCP tool only when the manual attempt fails 3 consecutive times with syntax errors (see [Error handling](#error-handling)).

You can enrich the query with context from earlier questions in the conversation to answer follow-ups, but keep names of Kubernetes and cloud resources intact.

### 5. Self-check before running

Verify that the query actually answers the user's question before running it. If it does not, rewrite it.

> Example:
> User: "list my critical vulnerabilities"
> Wrong: `MATCH Vulnerability RETURN Vulnerability;` (missing severity filter)
> Right: `MATCH Vulnerability WHERE Vulnerability.severity = "Critical" RETURN Vulnerability;`

### 6. Show, then run

Print the final query in a fenced code block so the user can read it. SysQL is read-only, so no explicit confirmation is required — proceed straight to `run_sysql`.

You can run multiple queries to answer a single user question when more detail is needed.

### 7. Present results

Open with a one-line headline (e.g., "7 critical vulnerabilities with known exploits") before the table.

Format results as a table. Lead with the most important columns (severity, name, affected resource).

**Limits and truncation.**

- If no `LIMIT` is specified in the query, the server default is 50.
- The server returns a maximum of 1000 rows per query.
- When the result row count equals `LIMIT`, the result set is likely truncated — say so explicitly:

> Showing 50 of (likely more) results. Increase `LIMIT` (max 1000) or add filters to narrow down.

### 8. Suggest follow-ups

Suggest 3 follow-up questions at the end of the answer to help the user deep-dive, scoped to the supported areas.

- When previous results are available, fill placeholders (e.g. `<resource-name>`) with values from the user question or the query result.
- When no results are available yet, format placeholders as inline code, e.g. `` `Resource Name` ``.
- Suggestions must be coherent with the user question and in scope (see [Scope](#scope)).

## Examples

### Filtered query

> User: "Show me critical vulnerabilities with known exploits."

The skill responds with the query and then the results:

```sql
MATCH Vulnerability AS v
WHERE v.severity = 'Critical' AND v.hasExploit = true
RETURN v.name, v.cvssScore, v.epssScore
ORDER BY v.cvssScore DESC
LIMIT 20;
```

| name | cvssScore | epssScore |
|---|---|---|
| CVE-2024-… | 9.8 | 0.92 |
| … | … | … |

### Disambiguating a filter value

> User: "Which workloads violate the S3 control?"

The skill first fetches available controls (step 3.1), then asks via `AskUserQuestion`:

> Multiple controls match "S3". Which one?
> - `S3 Bucket Encryption Disabled`
> - `S3 Bucket Public Read`
> - `S3 Versioning Disabled`

Once the user picks, the query is built and executed.

### Aggregate, with truncation notice

```sql
# Top 5 most vulnerable workloads by vuln count
WITH k, count(v) AS vulnCount FROM (
  MATCH KubeWorkload AS k AFFECTED_BY Vulnerability AS v
)
MATCH k
RETURN k.name, vulnCount
ORDER BY vulnCount DESC
LIMIT 5;
```

Showing top 5 of (likely more) results — increase `LIMIT` to widen the view.

### More examples

```sql
# Workloads in production affected by critical vulns
MATCH KubeWorkload AS k AFFECTED_BY Vulnerability AS v
WHERE v.severity = 'Critical' AND k.namespaceName = 'production'
RETURN k.name, k.clusterName, v.name, v.cvssScore;

# AWS IAM users with admin access
MATCH IAMUser AS u
WHERE u.isAdmin = true
RETURN u.name, u.arn, u.lastActiveDate;

# Workloads violating compliance controls
MATCH KubeWorkload AS k VIOLATES Control AS c
WHERE c.severity = 'High'
RETURN k.name, k.namespaceName, c.name, c.description;

# Temporal: vulns found in the last 7 days
MATCH Vulnerability AS v
WHERE v.firstSeen >= daysAgo(7)
RETURN v.name, v.severity, v.firstSeen
ORDER BY v.firstSeen DESC;

# EXISTS: workloads that have at least one critical vuln
MATCH KubeWorkload AS k
WHERE EXISTS { k AFFECTED_BY Vulnerability AS v WHERE v.severity = 'Critical' }
RETURN k.name, k.namespaceName;
```

## Error handling

Report problems with the **What happened → Why → What to do next** pattern. Common cases:

- **`run_sysql`/`generate_sysql` tools missing.**
  - *What:* The Sysdig MCP server is not reachable.
  - *Why:* The plugin's MCP server is not running, not registered, or the env vars `SECURE_API_TOKEN`/`SECURE_URL` are missing.
  - *Fix:* Follow the diagnostic checklist in [`references/mcp-setup.md`](references/mcp-setup.md). Report only the specific failing step to the user.

- **Syntax error returned by `run_sysql`.**
  - Try to fix the query locally (typo in entity/field name, missing alias, wrong relationship direction). Iterate up to **3 times**.
  - If still failing, hand off to `generate_sysql` with a clear natural-language description of the intent. Show the regenerated query, then run it.

- **Query generation fails completely (after retries and `generate_sysql`).**
  - *What:* Be honest — say you couldn't produce a query that answers the question. Do **not** pretend you succeeded.
  - *Why:* Briefly explain what you tried (entities, filters) and why it didn't work.
  - *Fix:* Ask the user for more details or to clarify the request.

- **Empty result set.**
  - *What:* The query is valid but returned zero rows.
  - *Why (likely):* misspelled filter value, filter too strict, or the data is not in the user's scope.
  - *Fix:* Suggest one of — list available values for the filter (e.g. `RETURN DISTINCT Entity.field`); loosen the filter; or check the zone/account scope. Offer to re-run with the suggested change.

- **Result hit `LIMIT`.**
  - *What:* The number of returned rows equals the query's `LIMIT`.
  - *Why:* The result set is likely truncated.
  - *Fix:* Communicate the truncation explicitly and offer to raise `LIMIT` (max 1000), add `OFFSET` for pagination, or add filters to narrow the scope.

## Scope

You can analyze the CSPM areas listed in [`references/cspm_questions.md`](references/cspm_questions.md). If a question falls outside, apologize and suggest a possible in-scope alternative.

### Risks and findings

We talk about **risks** for misconfigurations or risky conditions in the user's infrastructure, for example:

- Exposed workloads with critical vulnerabilities
- Publicly exposed EC2 instances with critical vulnerabilities
- Publicly exposed S3 buckets and storage resources in general
- Publicly exposed EC2 instances with access to S3 buckets
- Publicly exposed Azure Data Blob
- Publicly exposed Azure VM with critical vulnerabilities
- Resources with failed controls

We talk about **findings** when a risk is found in the user's infrastructure, for example:

- Critical vulnerabilities
- Publicly exposed resources
- Critical/high vulnerabilities that require privilege
- Privilege control failures
- Vulnerabilities that have an exploit
- Vulnerabilities in use
- Failed controls

## References

- [`references/schema.md`](references/schema.md) — Compact, LLM-optimised reference of entities, queries, unions, fields, and relationship names. Hidden internal entities are inlined into the public node that backs them.
- [`references/relationships.md`](references/relationships.md) — Per-entity navigation map: every public relationship as `source --[ field : EDGE ]--> destination`, plus a flat appendix for quick lookup.
- [`references/mcp-setup.md`](references/mcp-setup.md) — How to register the `secure-mcp-server` with each supported agent, and the diagnostic checklist when tools aren't reachable.
- [`references/sysql_reference.md`](references/sysql_reference.md) — Complete language reference.
- [`references/cspm_questions.md`](references/cspm_questions.md) — Catalog of supported CSPM questions and scope.

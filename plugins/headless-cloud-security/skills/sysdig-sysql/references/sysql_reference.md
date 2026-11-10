# SysQL Query Language Reference
This describes the SYSQL query language and its structure.

## Query Structure

```
[WITH items FROM ( MATCH … [ORDER BY …] [LIMIT n] )]*
(MATCH Entity [AS alias] [RELATIONSHIP Entity [AS alias] [OVER Entity, ...]]* [WHERE filters])+
[OPTIONAL MATCH Entity RELATIONSHIP alias [WHERE filters]]
RETURN [DISTINCT] fields
[ORDER BY field ASC|DESC, ...]
[LIMIT n [OFFSET n]];
```

Every query **must** have `MATCH` and `RETURN`. Default `LIMIT` is 50, max 1000. Max `OFFSET` is 10000. `WITH … FROM (…)` stages are optional and always come first — see [WITH ... FROM (...) subquery stages](#with--from--subquery-stages).

### Multiple / branching paths — NO comma syntax

**Keep the path minimal and adherent to the question.** Traverse only the entities you're asked about, via the **most direct relationship** between them — the schema usually exposes a direct (often virtual) edge that already hides intermediaries (e.g. `EC2Instance HAS_ACCESS S3Bucket`). Do **not** lengthen a path through entities the question never mentioned (`EC2Instance ASSOCIATED_WITH IAMInstanceProfile CONTAINS IAMRole HAS_ACCESS S3Bucket`) just to keep a single `MATCH` — use the direct edge, or multiple `MATCH` clauses.

A single linear `MATCH` is fine for a **direct** chain — `MATCH e1 REL1 e2 REL2 e3 RETURN …` (e.g. `MATCH Vulnerability AFFECTS Package IN_USE Container RUNS Image RETURN …`). SysQL does **not** support comma-separated multi-paths inside a `MATCH`. To **branch** from the same node (two relationships off one entity, not a single chain), or to avoid routing through irrelevant entities, use **multiple `MATCH`** clauses that repeat the shared entity/alias, each with an explicit relationship — they are joined together.

❌ **Not valid** (comma multi-path — fails at run time):
```
MATCH KubeWorkload AS k AFFECTED_BY Vulnerability AS v, k RUNS Container AS c
RETURN k.name, v.name, c.name;
```
(also invalid: `MATCH a, b` and Cypher-style `MATCH (a)-[]->(b), (a)-[]->(c)`.)

✅ **Valid** — repeat `MATCH`, share the alias:
```
MATCH KubeWorkload AS k AFFECTED_BY Vulnerability AS v
MATCH k RUNS Container AS c
WHERE v.severity = 'Critical'
RETURN k.name, v.name, c.name;
```

> **No Cypher-style `WITH`.** SysQL's only `WITH` is the subquery/aggregation form `WITH … FROM ( … )` (see [WITH ... FROM (...) subquery stages](#with--from--subquery-stages)). There is **no** `WITH <var>` that pipes a variable into a following `MATCH` — `MATCH … WITH k MATCH …` is invalid. To require a second condition on the same node, use repeated `MATCH` (each with an explicit relationship, sharing the alias):
> ```
> MATCH KubeWorkload AS k AFFECTED_BY Vulnerability AS v WHERE v.severity = 'Critical' AND v.hasFix = true
> MATCH k GENERATES RuntimeEvent AS e WHERE e.ruleName =~ '(?i).*Launch Sensitive Mount Container.*'
> RETURN DISTINCT k.name, k.namespaceName, k.clusterName;
> ```

## Clauses

| Clause | Purpose |
|---|---|
| `MATCH Entity` | Start pattern — defines which entities/relationships to traverse |
| `MATCH E1 REL E2` | Traverse relationship REL from E1 to E2 |
| `AS alias` | Alias an entity for use in WHERE/RETURN |
| `WHERE` | Filter (after MATCH/OPTIONAL MATCH). Supports `AND`, `OR`, `NOT`, `()` |
| `OPTIONAL MATCH` | Like MATCH but returns null for unmatched (LEFT JOIN) |
| `RETURN` | Select output. Supports `DISTINCT`, `alias.field AS name` |
| `ORDER BY` | Sort by fields. `ASC` (default) or `DESC` |
| `LIMIT n` | Max rows (default 50, max 1000) |
| `OFFSET n` | Skip rows for pagination (max 10000). Goes inside LIMIT clause |
| `OVER E1, E2` | Specify intermediate entities for relationship traversal |
| `WITH ... FROM (...)` | Subquery stage — run an inner query first, project a few nodes/aggregates out of it, continue matching from them. Only form of `WITH`; see the section below |

## `WITH ... FROM (...)` subquery stages

The **only** `WITH` in SysQL. A stage runs an inner query, projects a few items out of it, and the rest of the query continues from those items. Stages always come **before** the main `MATCH` and can be chained.

```
WITH <items> FROM ( MATCH … [WHERE …] [MATCH …] [OPTIONAL MATCH …] [ORDER BY …] [LIMIT n] )
[WITH <items> FROM ( … )]*
MATCH … [WHERE …] RETURN … [ORDER BY …] [LIMIT n];
```

`<items>` is a comma-separated list of:

| Item | Example | Notes |
|---|---|---|
| Node alias | `k`, `k AS dk` | Continues as that entity in later parts |
| `DISTINCT` node | `DISTINCT k AS dk` | **Alias required.** One row per entity, however many inner matches it had |
| Aggregate | `count(v) AS c`, `count(DISTINCT v.name) AS c`, `collect(DISTINCT v.name) AS cves` | **Alias required.** Non-aggregated items in the list are the implicit `GROUP BY` |
| Property | `k.name AS n` | Scalar, usable in a later `WHERE` (`c.name = n`) |

Nothing else goes in the list: no literals, arithmetic, relationships, list comprehensions or `EXISTS`.

### Rules

- **The main part must start with `MATCH`.** `WITH … FROM (…) RETURN …` is a parse error. For a plain "rank by count" you don't need a stage at all — `RETURN k.name, count(v) AS c ORDER BY c DESC LIMIT 20` already groups and sorts.
- **A stage is a scope boundary.** Later parts see only the projected aliases; everything else from the inner query is gone. A chained stage sees only what its predecessor projected.
- **`ORDER BY` / `LIMIT` go inside the parentheses** and apply to the stage's rows before the main part runs. Inside a stage, `ORDER BY` may use a property of a projected node (`ORDER BY k.name`, `ORDER BY v.cvssScore`). It **cannot** use an aggregate alias defined in the same list — `WITH k, count(v) AS c FROM (… ORDER BY c DESC LIMIT 20)` fails with `Variable 'c' not declared` — and, once the list has an aggregate, it cannot order by a node that is not projected either (`ORDER BY v.cvssScore` with only `k` projected is rejected at run time).
- **An aggregate alias used in the main part must appear in `RETURN` or `WHERE`.** `RETURN k.name, c ORDER BY c DESC` works; `RETURN k.name ORDER BY c DESC` (alias only in `ORDER BY`) fails at run time with `Variable 'c' not defined`.
- **`WHERE` on an aggregate alias in the main part works like `HAVING`**: `MATCH k IN Zone AS z WHERE c > 10 RETURN k.name, c`.
- **No `WHERE` directly on the projection** (`WITH k, count(v) AS c WHERE c > 10 FROM (…)` is invalid): filter in the next part's `WHERE`.
- **Two `LIMIT`s, two meanings.** The stage `LIMIT` counts stage rows (entities, after `DISTINCT`/aggregation); the outer `LIMIT` counts result rows (default 50, max 1000). A stage `ORDER BY` without a `LIMIT` is wasted work.
- **If a stage looks ignored** — rows come back that violate the stage's filter — the tenant's backend does not support stages yet and ran the query without them: rewrite without the stage (move the filter into the main `WHERE`, and rank with aggregates in `RETURN`).

### Performance: sorting and top-N on very numerous entities

In the main part, every pattern before `RETURN` is fully expanded first; `ORDER BY` and `LIMIT` apply to the **joined row set** at the very end. `Vulnerability`, `Package`, `Container`, `Image`, `RuntimeEvent` and `CloudResource` count in the millions per tenant, and a virtual edge like `AFFECTED_BY` is a 4-hop path underneath. So

```sql
# ❌ Slow: materialises every workload×vulnerability row, then sorts the lot to keep 50
MATCH KubeWorkload AS k AFFECTED_BY Vulnerability AS v WHERE v.severity = 'Critical'
RETURN k.name, v.name, v.cvssScore ORDER BY v.cvssScore DESC LIMIT 50;
```

sorts the whole join before it can return anything. Move the sort and the limit into a stage, on the smallest set that defines the ranking, then join from the survivors:

1. **Sort and limit the entity you rank by, inside a stage, with its own filters.** Then traverse from the N survivors — the expensive hop runs N times, not millions.
2. **Filter each side before joining the numerous side.** When the question constrains one side ("in production", "exposed", "in zone 42"), put that side in a stage (chain stages if both sides are constrained) so the numerous entity is only expanded from already-filtered nodes.
3. **"Top N X with their Y" → `LIMIT N` on X, in the stage.** A row `LIMIT` in the main part cuts in the middle of an X's Y rows and returns fewer X than asked; a stage `LIMIT` counts X.
4. **Ranking by count.** If the count is the whole answer, aggregate in `RETURN` with no stage. Use a stage only when you need to join more data *after* aggregating (zone, container, owner) or filter by the aggregate (`WHERE c > 10`); keep the main part to one cheap hop, because the stage cannot `LIMIT` by the aggregate yet.
5. **Deduplicate before expanding.** `WITH DISTINCT k AS dk FROM (…)` makes the main part expand once per entity instead of once per inner match.
6. **Sort in the main part only on what is left.** After a stage with `LIMIT 50`, an `ORDER BY` in the main part sorts ≤ 50 × fan-out rows — fine. Without the stage it sorts everything.

```sql
# ✅ Top 50 exploitable critical vulnerabilities by CVSS, with the workloads they hit
WITH v FROM (MATCH Vulnerability AS v WHERE v.severity = 'Critical' AND v.hasExploit = true ORDER BY v.cvssScore DESC LIMIT 50)
MATCH KubeWorkload AS k AFFECTED_BY v
RETURN v.name, v.cvssScore, k.name, k.namespaceName ORDER BY v.cvssScore DESC;

# ✅ First 20 production workloads (by name) and their critical vulnerabilities — LIMIT counts workloads
WITH k FROM (MATCH KubeWorkload AS k WHERE k.namespaceName = 'production' ORDER BY k.name LIMIT 20)
MATCH k AFFECTED_BY Vulnerability AS v WHERE v.severity = 'Critical'
RETURN k.name, v.name, v.cvssScore;

# ✅ Both sides constrained: production workloads → their 50 worst critical vulns → the packages to fix
WITH k FROM (MATCH KubeWorkload AS k WHERE k.namespaceName = 'production')
WITH k, v FROM (MATCH k AFFECTED_BY Vulnerability AS v WHERE v.severity = 'Critical' ORDER BY v.cvssScore DESC LIMIT 50)
MATCH v AFFECTS Package AS p
RETURN k.name, v.name, v.cvssScore, p.name ORDER BY v.cvssScore DESC;

# ✅ Workloads with more than 10 critical vulns, with their zone, most affected first (HAVING-style)
WITH k, count(v) AS c FROM (MATCH KubeWorkload AS k AFFECTED_BY Vulnerability AS v WHERE v.severity = 'Critical')
MATCH k IN Zone AS z WHERE c > 10
RETURN k.name, z.name, c ORDER BY c DESC LIMIT 20;

# ✅ Workloads that have at least one critical vuln, expanded once each
WITH DISTINCT k AS dk FROM (MATCH KubeWorkload AS k AFFECTED_BY Vulnerability AS v WHERE v.severity = 'Critical')
MATCH dk HAS Container AS c
RETURN dk.name, c.name LIMIT 100;
```

## Operators

### Comparison
`=`, `!=`, `<`, `>`, `<=`, `>=`

### String
`CONTAINS` (substring), `=~` (regex — Java syntax, use `(?i)` for case-insensitive)

### Set
`IN [...]`, `NOT IN [...]` — lists use **square brackets**, e.g. `IN ['High', 'Critical']` (not `(...)`).

### Enums
Enum fields (e.g. `Vulnerability.severity`) are **not** strings — `=~` and `CONTAINS` do **not** apply to them. Filter with:
- equality: `severity = 'Critical'`
- a list: `severity IN ['High', 'Critical']` (square brackets)
- a range — enums are **ordered**, so comparisons work: `severity >= 'High'` (also `>`, `<`, `<=`); e.g. "high or greater" → `severity >= 'High'`.

### Logical
`AND`, `OR`, `NOT`, `()` for grouping

### Arithmetic
`+`, `-`, `*`, `/`

## Functions

### Aggregation
| Function | Description |
|---|---|
| `count(x)` | Count matching elements |
| `sum(x)` | Sum (numeric) |
| `min(x)` | Minimum value |
| `max(x)` | Maximum value |
| `avg(x)` | Average (numeric) |
| `collect(x)` | Aggregate into list |

`DISTINCT` can be used inside aggregates: `collect(DISTINCT v.severity)`. Non-aggregated `RETURN` fields act as implicit `GROUP BY` keys.

### Temporal
| Function | Description |
|---|---|
| `now()` | Current timestamp |
| `daysAgo(n)` | Timestamp n days ago |
| `hoursAgo(n)` | Timestamp n hours ago |
| `minutesAgo(n)` | Timestamp n minutes ago |
| `secondsAgo(n)` | Timestamp n seconds ago |
| `weeksAgo(n)` | Timestamp n weeks ago |
| `monthsAgo(n)` | Timestamp n months ago |
| `toDate(s)` | Parse string to date |
| `millisToDate(n)` | Milliseconds to date |
| `secondsToDate(n)` | Seconds to date |

### String
`toLower(s)`, `toUpper(s)`, `trim(s)`, `ltrim(s)`, `rtrim(s)`, `toString(x)`, `substring(s, start, len)`, `split(s, delim)`, `concat(a, b, ...)`

### Math
`abs(x)`, `rand()`, `isNaN(x)`, `size(x)`

### List
`range(start, end)`, `head(list)`, `tail(list)`, `sort(list)`

### Entity
`id(node)`, `labels(node)`, `keys(node)`

## Key Entity Categories

| Category | Key Entities |
|---|---|
| **Kubernetes** | KubeWorkload, KubeNode, KubeCluster, KubeNamespace, KubeService, KubeResource, KubeIngress |
| **Vulnerabilities** | Vulnerability, ExternalVulnerability, Package, SBOMComponent, Application, Image |
| **Cloud (AWS)** | AWSAccount, CloudResource (`platform = "AWS"`), IAMUser, IAMRole, IAMGroup, IAMPolicy |
| **Cloud (GCP)** | GCPProject, CloudResource (`platform = "GCP"`), GCPIAMUser, GCPIAMRole, GCPServiceAccount |
| **Cloud (Azure)** | AzureSubscription, CloudResource (`platform = "Azure"`), AzureIAMUser, AzureIAMRole, AzureServicePrincipal |
| **Compute** | Container, Host, Instance, RuntimeResource |
| **Detections** | RuntimeEvent, Threat, Malware |
| **Posture** | Control, Policy, RiskFinding |
| **Identity (CIEM)** | CloudUser, CloudRole, ScopedIAMUser, CIEMAccessUser |
| **Environment** | Zone, Owner, Region |

Browse entities and their field definitions with the live schema tools — `list_sysql_entities` (entity names) then `get_sysql_entity` (one entity's fields + relationships), via MCP.

## Common Relationship Patterns

| Pattern | Meaning |
|---|---|
| `E AFFECTED_BY Vulnerability` | Entity is vulnerable |
| `E HAS_INSTALLED Package` | Entity has package installed |
| `E GENERATES RuntimeEvent` | Entity produced a runtime event |
| `E VIOLATES Control` | Entity fails a compliance control |
| `E ACCEPTS Control` | Entity complies with a control |
| `E IN Zone` | Entity belongs to a zone |
| `E IN KubeNamespace` | Entity is in a namespace |
| `CloudIAMGroup MEMBER_OF CloudIAMUser` | Group has user as member |
| `E EXPOSED_BY KubeService` | Entity is exposed via service |
| `KubeWorkload RUNS Container` | Workload runs container |

For an entity's relationships (direct and virtual, with direction and destination), call `get_sysql_entity` and read its `relationships`.

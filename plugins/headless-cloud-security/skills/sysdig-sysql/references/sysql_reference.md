# SysQL Query Language Reference
This describes the SYSQL query language and its structure.

## Query Structure

```
MATCH Entity [AS alias] [RELATIONSHIP Entity [AS alias] [OVER Entity, ...]]*
[WHERE filters]
[OPTIONAL MATCH Entity RELATIONSHIP alias [WHERE filters]]
RETURN [DISTINCT] fields
[ORDER BY field ASC|DESC, ...]
[LIMIT n [OFFSET n]];
```

Every query **must** have `MATCH` and `RETURN`. Default `LIMIT` is 50, max 1000. Max `OFFSET` is 10000.

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
| `WITH ... FROM (...)` | Subquery — pipe results from an inner query to an outer one |
| `EXISTS { pattern }` | Test for existence of a subpattern in WHERE |

## Operators

### Comparison
`=`, `!=`, `<`, `>`, `<=`, `>=`

### String
`CONTAINS` (substring), `=~` (regex — Java syntax, use `(?i)` for case-insensitive)

### Set
`IN [...]`, `NOT IN [...]`

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

Browse the full per-entity list with field definitions in [`references/schema.md`](references/schema.md).

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

For the complete relationship map of any entity (direct and virtual paths, direction, destination), see [`references/relationships.md`](references/relationships.md).

# Rego Cheatsheet — Sysdig Posture custom controls

## Resource kinds you can target

Supported resource kinds, grouped by family. The kind determines the shape of `input`.

| Family | Examples |
|---|---|
| AWS | `AWS_ACCOUNT`, `AWS_S3_BUCKET`, `AWS_CLOUD_TRAIL`, `AWS_IAM_ROLE`, `AWS_INSTANCE`, ... |
| Azure | `AZURE_MICROSOFT_SQL_SERVERS`, `AZURE_MICROSOFT_STORAGE_STORAGEACCOUNTS`, `AZURE_MICROSOFT_COMPUTE_VIRTUALMACHINES`, ... |
| GCP | `GCP_COMPUTE_GOOGLEAPIS_COM_INSTANCE`, `GCP_IAM_GOOGLEAPIS_COM_ROLE`, ... |
| IBM, OCI | `IBM_*`, `OCI_*` analogues |
| Kubernetes workloads | `DEPLOYMENT`, `STATEFULSET`, `DAEMONSET`, `CRONJOB`, `JOB`, `REPLICASET` |
| Kubernetes network / RBAC | `INGRESS`, `SERVICE`, `NETWORKPOLICY`, `NAMESPACE`, `SECRET`, `ROLE`, `ROLEBINDING`, `CLUSTERROLE`, `CLUSTERROLEBINDING`, `SERVICEACCOUNT` |

Unsupported kinds fail validation with `resource kind not found`.

## Required Rego shape

```rego
package sysdig

import future.keywords.if
import future.keywords.in

default risky := false

risky if {
  # your condition against input.*
}
```

Hard rules:

- Package **must** be `sysdig`.
- A rule named `risky` **must** resolve to a boolean.
- Always set `default risky := false` — without it, missing fields turn the rule into "undefined" and evaluation fails.
- Import `future.keywords.if` and `future.keywords.in` so the `risky if { ... }` and `some x in collection` forms compile.

The platform only looks at `risky`. `output`, `violation`, `msg`, and other conventional Rego names are ignored.

## What `input` looks like

Field names and casing in `input` exactly match the sample fixture — what you read there is what the rule binds to.

**Cloud resources** — `input` is the resource JSON. Field names match the provider's API (e.g. Azure uses `input.properties.publicNetworkAccess`; AWS uses `input.BucketName`). Cloud resources also expose `input.Labels` (tag map) regardless of provider.

Azure SQL:

```rego
package sysdig

import future.keywords.if
import future.keywords.in

default risky := false

risky if { input.properties.publicNetworkAccess == "Enabled" }
```

AWS S3:

```rego
package sysdig

import future.keywords.if
import future.keywords.in

default risky := false

risky if { not input.ServerSideEncryptionConfiguration }
risky if {
  some rule in input.ServerSideEncryptionConfiguration.Rules
  rule.ApplyServerSideEncryptionByDefault.SSEAlgorithm == "AES256"
  input.Labels.classification == "sensitive"
}
```

**Kubernetes workloads** — `input` is the full manifest as an object. Use standard Kubernetes paths: `input.metadata.*`, `input.spec.*`, `input.spec.template.spec.containers[_]`, etc. There is no `input.workload` wrapper for custom controls.

Deployment:

```rego
package sysdig

import future.keywords.if
import future.keywords.in

default risky := false

risky if {
  some c in input.spec.template.spec.containers
  c.securityContext.privileged == true
}

risky if {
  input.spec.template.spec.hostNetwork == true
}
```

Service:

```rego
package sysdig

import future.keywords.if
import future.keywords.in

default risky := false

risky if {
  input.spec.type == "LoadBalancer"
  not input.metadata.annotations["service.beta.kubernetes.io/load-balancer-source-ranges"]
}
```

## Useful idioms

**Multiple risky branches (OR):**

```rego
risky if { input.encryption.enabled == false }
risky if { input.encryption.algorithm == "AES128" }
```

**Helpers for readability:**

```rego
risky if { exposed_to_internet }
exposed_to_internet if {
  some rule in input.SecurityGroupRules
  rule.CidrIp == "0.0.0.0/0"
}
```

**Handle missing fields — use `not` or `object.get`:**

```rego
risky if { not input.logging.enabled }
risky if { object.get(input, "retentionDays", 0) < 30 }
```

**Comprehensions:**

```rego
risky if {
  public_buckets := { b | some b in input.buckets; b.acl == "public-read" }
  count(public_buckets) > 0
}
```

**Guards on labels / tags:**

```rego
risky if {
  input.Labels.environment == "production"
  input.publiclyAccessible == true
}
```

## Style conventions

These conventions emerged from the existing Sysdig posture-control corpus. Follow them so generated rules look like authored ones.

- **Compare strings via `lower()`.** When matching user-supplied or cloud-provider strings, lowercase both sides (`lower(input.X) == "enabled"`). Don't introduce `upper()` or `strings.equal_fold`; the corpus has standardized on `lower()`.
- **`==` for equality, never `=`.** Single `=` is unification, not comparison.
- **Iterate with `some x in arr`.** Don't use the index-based `arr[_]` pattern; the corpus has standardized away from it.
- **`contains(lower(x), lower(needle))` for fuzzy substring matches.** For exact tokens (IPs, ARN prefixes, state strings) use literal `==`.
- **Scope rules to the subset they apply to.** When a check is meaningful only for some instances of a kind, guard with the qualifying conditions first so the rule doesn't fire (or fail silently) on instances where the check doesn't apply.

## Limitations

- **No `output` payload.** The evaluator only reads `risky`. You cannot return custom fields on violations.
- **No actual-vs-expected reports.** Custom controls produce plain pass / fail; the richer attribute-level reports are only for Sysdig's built-in controls.
- **No external data.** `import data.<anything>`, bundles, or shared libraries are not available. Everything must come from `input`.
- **No custom Sysdig builtins.** Only standard OPA builtins are available.
- **No `http.send`.** Rejected at compile time as an unsafe builtin — `unsafe built-in function calls in expression: http.send`. Don't use it.
- **No side effects.** Rego is pure evaluation — no API calls, no logs, no mutation.
- **Resource kind is fixed at create time.** You cannot repoint an existing control to a different kind. This skill makes `resource_kind` an explicit choice up front for that reason.

## Common mistakes

- Forgetting `default risky := false` — the rule is undefined when `input` paths are missing, and evaluation fails.
- Wrong package name — only `package sysdig` is queried; anything else evaluates to nothing.
- Returning a value (`risky := "yes"`) or a set (`risky[x] if ...`) — `risky` must be a scalar bool.
- Assuming the shape from provider docs instead of the sample — always look at the real `input` from `get_posture_resource_template` for your kind to see the true field names and casing (e.g. Azure camelCase under `input.properties`, AWS PascalCase at the top level).
- Misjudging when to use `not input.X`. The fixture is one snapshot; real data may omit fields entirely. Two related traps:
  - **Underdefensive**: if absence implies the risky state, you need `not input.Field` explicitly. Functions like `count()` and `some x in X` evaluate to undefined when the field is missing and don't fire — so missing fields silently pass under `default risky := false`.
  - **Overdefensive**: for a boolean field where absence and `false` should both flag, `not input.Field` already covers both. Don't add a redundant `input.Field == false` branch.
- Using `http.send` — rejected at compile time (`unsafe built-in function calls in expression: http.send`).
- Using `import data.*` or helper libraries — no external data is available; everything must come from `input`.
- Expecting `output` to populate violation details — it doesn't.

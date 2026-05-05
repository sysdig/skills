# Rego Cheatsheet — Sysdig Posture custom controls

A Posture custom control is a Rego rule you author and attach to Sysdig policies. This skill iterates on Rego **on disk** and validates it via the `test_posture_rego` MCP tool, then emits the final Rego into a Terraform file via the Sysdig provider. Writes to Sysdig (create / update / delete) happen through Terraform, never the API.

## Iteration loop

1. Pick a supported `resourceKind` — call the `list_posture_resource_kinds` MCP tool.
2. Fetch a sample `input` for that kind — call `get_posture_resource_template` with `{ "resource_kind": "<kind>" }`.
3. Write Rego in `control.rego` next to the target `.tf`.
4. Validate — read `control.rego` and call `test_posture_rego` with `{ "resource_kind": "<kind>", "rego": "<file content>" }`. Interpret the `{ passed, message }` response as:
   - `message` non-empty → **compile_error** — Rego failed to compile or evaluate; `message` has the error.
   - `message` empty and `passed: true` → **sample_compliant** — rule evaluated `risky: false` against the fixture (your control did not flag the sample).
   - `message` empty and `passed: false` → **sample_risky** — rule evaluated `risky: true` against the fixture (your control flagged the sample).

   `passed` is the inverse of the rule's `risky` output, **not** a compile/run flag. Whether `sample_compliant` or `sample_risky` is the *desired* outcome depends on whether the fixture for that kind represents a compliant or non-compliant resource — always inspect the sample.
5. Once green, embed the Rego into `templates/custom_control.tf` (via `file("${path.module}/control.rego")`) and run `terraform validate`.

## Resource kinds you can target

Pick one supported kind — it determines the shape of `input`.

| Family | Examples |
|---|---|
| AWS | `AWS_ACCOUNT`, `AWS_S3_BUCKET`, `AWS_CLOUD_TRAIL`, `AWS_IAM_ROLE`, `AWS_INSTANCE`, ... |
| Azure | `AZURE_MICROSOFT_SQL_SERVERS`, `AZURE_MICROSOFT_STORAGE_STORAGEACCOUNTS`, `AZURE_MICROSOFT_COMPUTE_VIRTUALMACHINES`, ... |
| GCP | `GCP_COMPUTE_GOOGLEAPIS_COM_INSTANCE`, `GCP_IAM_GOOGLEAPIS_COM_ROLE`, ... |
| IBM, OCI | `IBM_*`, `OCI_*` analogues |
| Kubernetes workloads | `DEPLOYMENT`, `STATEFULSET`, `DAEMONSET`, `CRONJOB`, `JOB`, `REPLICASET` |
| Kubernetes network / RBAC | `INGRESS`, `SERVICE`, `NETWORKPOLICY`, `NAMESPACE`, `SECRET`, `ROLE`, `ROLEBINDING`, `CLUSTERROLE`, `CLUSTERROLEBINDING`, `SERVICEACCOUNT` |

If a kind is not supported, validation fails with `resource kind not found`. Use the kind name verbatim as returned by `list_posture_resource_kinds`.

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

The fixture returned by `get_posture_resource_template` is the exact `input` that `test_posture_rego` binds during evaluation — same embedded JSON, same handler. What you see there is what the rule will see.

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
  public_buckets := { b | b := input.buckets[_]; b.acl == "public-read" }
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
- Using `http.send` — rejected at compile time (`unsafe built-in function calls in expression: http.send`).
- Using `import data.*` or helper libraries — no external data is available; everything must come from `input`.
- Expecting `output` to populate violation details — it doesn't.

## Why this skill doesn't write controls via the API

Posture control write endpoints exist and work, but this skill writes controls exclusively through the Sysdig Terraform provider. The value is a reviewable, committable `.tf` file the user owns — direct API writes skip that entirely. Translate any control mutation you see in older Sysdig material into attributes on `sysdig_secure_posture_control`.

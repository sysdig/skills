# Vulnerability Management (VM) policies — MCP tools

Baseline vulnerability policy setup via the Sysdig MCP server (no token/`curl`).

## Tools

| Purpose | Tool |
|---|---|
| List policies | `list_vulnerability_policies` |
| List rule bundles | `list_vulnerability_bundles` |
| Create / update policy | `create_vulnerability_policy`, `update_vulnerability_policy` |

## Model

A **VM policy** = one or more **bundles** (rule sets; UI "Vulnerability Rule
Bundles") + optional **stages**. Stage `name` enum: `pipeline`, `runtime`,
`registry`, `admission_control`.

- `create_vulnerability_policy` args: `name`, `bundles: [{id}]` (≥1; get IDs from
  `list_vulnerability_bundles`, match by name — don't hardcode), optional
  `stages: [{name, configuration:[{scope, behaviour, unknownImageAction}]}]`.
- **"One policy for everything" vs "split":** one multi-stage policy vs separate
  policies per stage — the choice the user weighs.
- Default baseline bundle: `Severe vulnerabilities with a Fix`.

## ⚠️ Enforcement blast radius

- **`pipeline`** — gates CI/CD by its mere presence; a failing scan can break the
  build. (`behaviour` warn/reject applies only to `admission_control`, not here.)
- **`admission_control`** with `behaviour: reject` — can **block Kubernetes
  deployments**. Baseline default = `pipeline` + `runtime` (no admission); add
  admission `reject` only on explicit request, after stating the blast radius.
- `runtime` / `registry` — evaluate existing/registry images; lower blast radius.

## Idempotency

Match by policy **name** (`list_vulnerability_policies` returns each policy's
stages, so the stage-diff needs no extra read). Missing →
`create_vulnerability_policy`; present → `update_vulnerability_policy` if
bundles/stages differ, else skip. Never delete an existing policy unless the user
explicitly asks. Report `created`/`updated`/`skipped`/`failed`.

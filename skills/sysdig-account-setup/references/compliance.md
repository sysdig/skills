# Compliance standards (Posture) — MCP tools

Choosing "which compliance standard to have" = assigning **Posture policies**
(each policy is a compliance standard/framework) to **zones**, via the Sysdig MCP
server (no token/`curl`).

## Tools

| Purpose | Tool |
|---|---|
| List the standards catalog | `list_posture_policies` |
| Read a zone's current assignment | `get_zone_posture_policies` |
| Assign / unassign standards to a zone | `set_zone_posture_policies` |
| List zones | `list_zones` |

## Model

- A **Posture policy** = a compliance standard/framework. Built-in examples: CIS
  benchmarks (AWS/EKS/Linux/Kubernetes), `AWS Foundational Security Best
  Practices`, PCI DSS, NIST, C5:2020, CCPA, BSI 200-1, Australian ISM,
  `All Posture Findings` (catch-all). Each has `id`, `name`, `zones[]`.
- A standard is **active for a zone** once the zone's assignment includes its ID.
- Catalog: `list_posture_policies(is_custom=false, is_active=true)` for built-in
  standards; `is_custom=true` for tenant-authored ones.

## Assigning — `set_zone_posture_policies`

Args: `zone_id`, `policy_ids: [int]`, `mode` (`add` default | `remove` | `replace`).

- **The underlying API PUT replaces the whole assignment.** The tool makes this
  safe: `mode: "add"` (default) reads the current assignment and **unions** your
  IDs in, so other standards stay assigned. Use `mode: "remove"` to unassign, and
  `mode: "replace"` only on explicit request (destructive to other assignments —
  confirm first).
- Pass only IDs from `list_posture_policies` — an unknown ID makes the API reject
  the whole call.

## Idempotency

Per (zone, standards): if all chosen IDs are already assigned
(`get_zone_posture_policies`), **skip**; otherwise `set_zone_posture_policies`
with `mode: "add"`. Re-running a zone that already has the desired standards
changes nothing. Report `assigned`/`skipped`/`failed`. Never unassign an existing
standard unless the user explicitly asks.

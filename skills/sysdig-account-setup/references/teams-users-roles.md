# Teams, users & roles — MCP tools

All operations go through the Sysdig MCP server (authenticated session — no token
or `curl`). The write tools encapsulate the API's requirements, so you mostly pass
intent.

## Tools

| Purpose | Tool |
|---|---|
| List teams | `list_teams` |
| Create / update team | `create_team`, `update_team` |
| Add/update a user's team membership + role | `save_team_membership` |
| List users | `list_users` |
| Create / update user | `create_user`, `update_user` |
| List roles / read a built-in role | `list_roles`, `get_default_role` |
| Zones (for scoped teams) | `list_zones` |

## Teams

`create_team` — key args: `name` (unique), `product` (`secure`|`monitor`,
default `secure`), `standard_team_role` **xor** `custom_team_role_id`,
`is_all_zones` (default true) **xor** `zone_ids`, optional `description`,
`is_default_team`, `scopes`.

- **Secure teams need a `HOST_CONTAINER` scope.** The tool **auto-defaults** one
  (`expression: container`, matches all) when you pass no `scopes`, so a plain
  `create_team(name, product="secure")` works. Pass explicit `scopes` only to
  narrow (e.g. `{type: "HOST_CONTAINER", expression: 'kubernetes.cluster.name in ("prod")'}`);
  a scope `expression` must be non-empty (`host`/`container` for all, or a
  querylang filter).
- Scope visibility with `is_all_zones` OR `zone_ids` (mutually exclusive); get
  zone IDs from `list_zones`.
- `update_team` for changes; the tool handles the API's full-object/version
  requirements. Skip immutable/system default teams.

## Users

`create_user` — email + name + whether they are an account admin (`is_admin`),
plus optional `products` (adds the user to those products' **default** teams only,
e.g. `["secure"]`). **Explicit team + role placement is owned by
`save_team_membership`, not `create_user`** — don't set team scope at create time;
create the user, then assign the chosen team(s)/role via `save_team_membership`.
The `send_activation_email` arg **defaults to `false`** (the account is created
silently, no email); set it **`true`** to email the person an invitation so they
can activate and log in — that send is the **outward-facing** act, confirm it
first. Match existing users by email (`list_users`) before creating. `update_user`
for name/admin fixes.

## Roles

Two kinds:
- **Standard team roles** — built-in; the `standard_team_role` arg is an **enum
  identifier, not a display name**:

  | UI display name | enum | notes |
  |---|---|---|
  | Team Manager | `ROLE_TEAM_MANAGER` | manages team + members |
  | Advanced User | `ROLE_TEAM_EDIT` | edit; value used by default teams |
  | Standard User | `ROLE_TEAM_STANDARD` | sensible default for new teams |
  | View Only | `ROLE_TEAM_READ` | read-only |
  | Service Manager | `ROLE_TEAM_SERVICE_MANAGER` | service-account mgmt |
  | (no access) | `ROLE_TEAM_NONE` | rarely used |

  `get_default_role(<display name>)` returns the permissions a role grants (to
  explain trade-offs); it does not return the enum — pass the enum from the table.
- **Custom roles** — tenant-defined; `list_roles` lists them (empty on a fresh
  tenant). Reference by `custom_team_role_id`. Baseline defaults to a standard role
  (`ROLE_TEAM_STANDARD`); use a custom role only on explicit request.

## Idempotency

Match teams by `name`, users by `email`; `save_team_membership` is an upsert.
Read the current lists first (Step A1), match, and only create/update on an actual
change. Re-running must never duplicate.

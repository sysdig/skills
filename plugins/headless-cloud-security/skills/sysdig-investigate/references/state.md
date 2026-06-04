State is read and written via the Sysdig MCP server tools.

| Operation | Tool | Arguments |
|-----------|------|-----------|
| Read state | `get_skill_state` | `{ "skill_state": "investigate" }` |
| Write state | `save_skill_state` | `{ "skill_state": "investigate", "version": <n>, "data": { ... } }` |
| Delete state | `delete_skill_state` | `{ "skill_state": "investigate" }` |

A `null` response from `get_skill_state` means no state exists yet — start with `{ "version": 0 }`.

### Schema

```json
{
  "version": 1,
  "last_run": "2025-03-15T10:00:00Z",
  "environment": "production",
  "focus": "actually_exploitable_findings",
  "images_found": 42,
  "images_planned": 5,
  "images_remediated": 2,
  "ticketing_system": "jira",
  "ticket_assignees": [
    {
      "image_reference": "quay.io/myorg/my-service:1.2.3",
      "assignee": "jane.doe@example.com",
      "source": "workload_owner",
      "last_confirmed": "2025-03-15"
    }
  ],
  "tickets": [
    {
      "image_reference": "quay.io/myorg/my-service:1.2.3",
      "ticket_key": "PROJ-123",
      "ticket_url": "https://example.atlassian.net/browse/PROJ-123",
      "status": "open",
      "assignee": "jane.doe@example.com",
      "created": "2025-03-15"
    }
  ],
  "ticket_history": [
    {
      "date": "2025-03-15",
      "image": "quay.io/myorg/my-service:1.2.3",
      "action": "created",
      "ticket_key": "PROJ-123",
      "assignee_source": "workload_owner"
    }
  ],
  "plan": [ /* per-image plan entries with status pending|remediated|skipped */ ]
}
```

### Read/write rules

- **Get** the state at the start of every session by calling the MCP tool `get_skill_state` with `{ "skill_state": "investigate" }`. A `null` response means no state exists yet — start with `{ "version": 0 }`.
- **Resume summary** — only when `get_skill_state` returned a non-`null` value. Skip on a fresh read (`null` state), since there are no `plan` entries to inspect. Otherwise, if the state has one or more `plan` entries still in `status: "pending"` (populated by step 7's writer — see the [State schema](#schema)), print a one-line summary before doing anything else and let the user choose how to proceed:

  > _"Last run YYYY-MM-DD — `<pending_count>` of `<total_count>` images still pending in zone `<zone>`, focus `<focus>`. Continue, refresh, or start fresh?"_

  Treat state older than 15 days as stale and recommend refresh; treat `delete_skill_state` as the "start fresh" action.
- **Save** the state at the end of every session by calling the MCP tool `save_skill_state` with `{ "skill_state": "investigate", "version": <n>, "data": { ... } }`. Read the current contents first, merge new data, then pass the full merged object as `data`.
- **Version argument** — the server uses `version` for optimistic concurrency. Pass it as a separate argument (do not include it inside `data`):
  - First write (`get_skill_state` returned `null`) → call with `version: 0`. The server creates the record.
  - Subsequent writes → call with the same `version` value the previous `get_skill_state` returned. On success the server bumps it; on conflict it returns 409.
  - On 409 → call `get_skill_state` again, merge your changes into the freshly-read state, and retry once with the new version.
- **Matching keys** for upsert:
  - `ticket_assignees`: match on `image_reference`
  - `tickets`: match on `ticket_key`
  - `ticket_history`: always append (no dedup)
  - `plan`: upsert by `global_id`
- Dates use `YYYY-MM-DD` format; timestamps use ISO 8601.
- `ticketing_system` is `"jira" | "linear" | "github_projects" | null`. `null` means the user opted out or no system is configured.

**Ticketing is optional.** All ticket-related fields are absent or empty when the user skipped ticket creation.

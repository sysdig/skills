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
  "last_run": "2026-07-08T10:00:00Z",
  "flow": "plans",
  "environment": "production",
  "focus": "fixable_exposed_findings",
  "images_found": 42,
  "plan": [
    {
      "global_id": "abc-123",
      "image_reference": "quay.io/myorg/my-service:1.2.3",
      "image_id": "sha256:…",
      "status": "handed_off",
      "skip_reason": null,
      "date": "2026-07-08"
    }
  ]
}
```

- `flow` is `"plans" | "findings"` — which flow the session used.
- `focus` is the confirmed `target_measure` (Plans flow) or a one-line description of the slice (Findings flow, e.g. `"critical+fix+inUse in production, by cve"`).
- `plan` entries track per-image session outcomes: `pending` (surfaced, not yet decided), `handed_off` (sent to `/sysdig-remediate`), `skipped` (with `skip_reason`). `global_id` is present only for tracked jobs; Findings-flow entries carry `image_reference`/`image_id` only.
- **No ticket fields.** Tickets, PRs, and job closing belong to `/sysdig-remediate` and its state. This skill never records deliverables — job artifacts (server-side) are the source of truth for what work exists.

### Read/write rules

- **Get** the state at the start of every session by calling `get_skill_state` with `{ "skill_state": "investigate" }`. A `null` response means no state exists yet — start with `{ "version": 0 }`.
- **Resume summary** — only when `get_skill_state` returned a non-`null` value. If the state has one or more `plan` entries still in `status: "pending"`, print a one-line summary before doing anything else and let the user choose how to proceed:

  > _"Last run YYYY-MM-DD — `<pending_count>` of `<total_count>` images still pending (`<flow>` flow, focus `<focus>`). Continue, refresh, or start fresh?"_

  Treat state older than 15 days as stale and recommend refresh; treat `delete_skill_state` as the "start fresh" action.
- **Save** the state at the end of every session with the full merged object as `data` (read current contents first, merge, write).
- **Version argument** — the server uses `version` for optimistic concurrency. Pass it as a separate argument (do not include it inside `data`):
  - First write (`get_skill_state` returned `null`) → call with `version: 0`. The server creates the record.
  - Subsequent writes → call with the same `version` value the previous `get_skill_state` returned. On success the server bumps it; on conflict it returns 409.
  - On 409 → call `get_skill_state` again, merge your changes into the freshly-read state, and retry once with the new version.
- **Matching key** for upsert: `plan` entries match on `global_id` when present, else on `image_reference`.
- Dates use `YYYY-MM-DD` format; timestamps use ISO 8601.

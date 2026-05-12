# sysdig-remediate — state schema and read/write rules

State is read and written via the Sysdig MCP server tools.

| Operation | Tool | Arguments |
|-----------|------|-----------|
| Read state | `get_skill_state` | `{ "skill_state": "remediate" }` |
| Write state | `save_skill_state` | `{ "skill_state": "remediate", "version": <n>, "data": { ... } }` |
| Delete state | `delete_skill_state` | `{ "skill_state": "remediate" }` |

A `null` response from `get_skill_state` means no state exists yet — start with `{ "version": 0 }`.
Every time a skill finds something new, it should update the state and save it back.

## Schema

```json
{
  "version": 1,
  "image_repo_mappings": [
    {
      "image_reference": "quay.io/myorg/my-service:1.2.3",
      "repository": "myorg/my-service",
      "confidence": "high",
      "discovered": "2025-03-15"
    }
  ],
  "repo_reviewers": [
    {
      "repository": "myorg/my-service",
      "reviewers": ["jane-doe", "john-smith"],
      "last_confirmed": "2025-03-15"
    }
  ],
  "vulnerability_resolutions": [
    {
      "package": "golang",
      "from_version": "1.20",
      "to_version": "1.25",
      "cves_fixed": ["CVE-2024-1234", "CVE-2024-5678"],
      "date": "2025-03-15"
    }
  ],
  "version_chains": [
    {
      "package": "golang",
      "chain": [
        { "version": "1.20", "status": "vulnerable" },
        { "version": "1.23", "status": "skipped", "reason": "CVE-2024-9999" },
        { "version": "1.25", "status": "clean" }
      ],
      "date": "2025-03-15"
    }
  ],
  "remediation_history": [
    {
      "date": "2025-03-15",
      "zone": { "ref_id": "123", "name": "production" },
      "image": "quay.io/myorg/my-service:1.2.3",
      "summary": "A short summary of the actions taken for the remediation",
      "prs_opened": ["myorg/my-service#42"],
      "reviewers_confirmed": ["jane-doe"],
      "ticket_updated": "PROJ-123"
    }
  ]
}
```

## Read/write rules

- **Get** the state at the start of every session (step 1) by calling the MCP tool `get_skill_state` with `{ "skill_state": "remediate" }`. A `null` response means no state exists yet — start with `{ "version": 0 }`.
- **Save** the state at the end of every session (step 5) by calling the MCP tool `save_skill_state` with `{ "skill_state": "remediate", "version": <n>, "data": { ... } }`. Read the current contents first, merge new data (append to arrays, update existing entries by matching key fields), then pass the full merged object as `data`.
- **Version argument** — the server uses `version` for optimistic concurrency. Pass it as a separate argument (do not include it inside `data`):
  - First write (`get_skill_state` returned `null`) → call with `version: 0`. The server creates the record.
  - Subsequent writes → call with the same `version` value the previous `get_skill_state` returned. On success the server bumps it; on conflict it returns 409.
  - On 409 → call `get_skill_state` again, merge your changes into the freshly-read state, and retry once with the new version.
- **Matching keys** for upsert:
  - `image_repo_mappings`: match on `image_reference`
  - `repo_reviewers`: match on `repository`
  - `vulnerability_resolutions`: match on `package` + `from_version`
  - `version_chains`: match on `package` + first chain entry version
  - `remediation_history`: always append (no dedup)
- When updating an existing entry, replace it entirely with the new version (do not deep-merge fields).
- Dates use `YYYY-MM-DD` format.

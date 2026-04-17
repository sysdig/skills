# Session Diff (Returning User)

When `environment.yaml` exists, show a one-line summary of the last session
before the first wizard panel. This gives returning users instant context.

## Format

```
**Previous session:** <provider> <account_id>, <capabilities>, <region>
```

**Examples:**

```
**Previous session:** AWS 123456789012, Connection + Cloud Logs + Scanning, us1
**Previous session:** GCP my-project-123, Connection, eu1
**Previous session:** Azure sub-abc123, Connection + Cloud Logs, us2
```

For multiple accounts in `environment.yaml`:

```
**Previous sessions:** 2 cloud accounts onboarded (AWS 123..., GCP my-proj...)
```

## Rules

- Read `environment.yaml` at the start of every session
- If it exists, show the one-line summary, then proceed to Step 1
- Pre-fill wizard defaults from the last session's values
- If it does NOT exist, skip the summary and mention you'll create one at the end
- Never show more than 2 lines of summary — this is a quick context reminder

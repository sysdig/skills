# Binary event enrichment

Apply this when the event classification is `binary_exec` or `filesystem_drift`.

## Inputs

Extract from the event payload:

- `proc.exepath` — full path of the executable
- `proc.args` — argv string
- `proc.sha256` — hash if Sysdig surfaced it on the event (not always present)

## Steps

1. **Resolve the hash.**
   - If `proc.sha256` is on the event, use it.
   - Otherwise, skip VirusTotal and record `"vt": "skipped — no hash on event"` in the case object's `limitations`.

2. **VirusTotal lookup** (only if a hash is available AND a VT API key was detected in Phase 0).

   Phase 0 records the matched env var name. Use that name (e.g. `$VT_API_KEY`, `$VT_KEY`, or `$VIRUSTOTAL_API_KEY`) in the header — do not alias.

   ```bash
   curl -s -H "x-apikey: ${VT_API_KEY:-${VT_KEY:-$VIRUSTOTAL_API_KEY}}" \
     "https://www.virustotal.com/api/v3/files/<sha256>"
   ```

   Capture: `last_analysis_stats.malicious`, `popular_threat_classification.suggested_threat_label` (family), `first_submission_date`, `last_submission_date`.

   If the response is 404, the binary is unknown to VT — record `vt: { unknown: true }`.

   If no API key was detected, skip VirusTotal entirely and add `"vt": "skipped — no API key"` to `limitations`.

## Output shape

Attach to the case object as `case.binary_enrichment`:

```json
{
  "hash": "abcd...",
  "vt": {
    "malicious_count": 17,
    "family": "Mirai",
    "first_seen": "2024-08-01T...",
    "last_seen": "2026-04-20T...",
    "unknown": false
  },
  "limitations": []
}
```

If a step fails, push a string into `limitations` (e.g. `"VT API key not detected"`, `"no hash on event"`) and continue.

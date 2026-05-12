# Network event enrichment

Apply this when the event classification is `network`.

## Inputs

From the event payload extract any of the following fields (Falco exposes these as `output_fields`):

- `fd.rip` — remote IP
- `fd.sip` — source IP
- `fd.rport` / `fd.sport` — ports
- `fd.name` — full socket name (often `tcp:1.2.3.4:443`)

Also extract any DNS-like field if present (`dns.qname`, `dns.qtype`).

## Steps

1. **Geolocate every distinct remote IP.** Prefer `ipinfo.io` (no API key, generous free tier):

   ```bash
   curl -s https://ipinfo.io/<ip>/json
   ```

   On HTTP 429 or non-2xx, fall back to:

   ```bash
   curl -s http://ip-api.com/json/<ip>
   ```

   Capture: `country`, `region`, `city`, `org` (ASN owner). Cache per-IP in working memory for the run.

2. **Sysdig threat intelligence cross-check.** If `mcp_sysdig_available` (set in Phase 0), call `mcp__secure-mcp-server__fetch_threat_intelligence_feed` once per investigation. The feed returns Sysdig-curated CVEs / zero-days / active-attack notes. Cross-reference each remote IP's ASN owner against entries that mention IP/ASN-based indicators, and each DNS query name against entries that mention domains.

   Record matches as `ti_matches: [{indicator: "1.2.3.4", source: "Sysdig TI feed", note: "<headline>"}]`.

   When the MCP is not loaded, set `ti_matches: "skipped — Sysdig MCP not loaded"` and continue.

3. **Lateral candidates via prior events.** Look for other recent activity on the same workload — same rule fired before, or other events on adjacent resources. Prefer the MCP when available:

   - If `mcp_sysdig_available` → call `mcp__secure-mcp-server__list_runtime_events` with `scope_hours=168`, `limit=100`, and `filter_expr`:

     ```
     ruleName = "<rule_name>" and kubernetes.cluster.name = "<cluster>" and kubernetes.namespace.name = "<namespace>" and kubernetes.workload.name = "<workload>"
     ```

   - Otherwise → use the vendored script as fallback:

     ```bash
     python3 $SKILL_DIR/scripts/fetch_events.py --prior \
       --rule "<rule_name>" \
       --cluster "<cluster>" --namespace "<namespace>" --workload "<workload>" \
       --hours 168
     ```

   Look at the returned event list for distinct `(cluster, namespace, workload)` tuples that appear alongside this rule. Treat them as potential lateral candidates.

   If the events API returns no prior matches, set `lateral_candidates: []` and continue.

## Output shape

Attach to the case object as `case.network_enrichment`:

```json
{
  "remote_ips": [
    { "ip": "1.2.3.4", "country": "RU", "asn_owner": "Some ASN" }
  ],
  "ti_matches": [
    { "indicator": "1.2.3.4", "source": "Sysdig TI feed", "note": "..." }
  ],
  "lateral_candidates": [
    { "cluster": "...", "namespace": "...", "workload": "..." }
  ],
  "limitations": []
}
```

If a step fails or is unavailable, push a string into `limitations` (e.g. `"ipinfo.io rate-limited; used ip-api.com"`, `"Sysdig MCP not loaded — TI cross-check skipped"`) and continue.

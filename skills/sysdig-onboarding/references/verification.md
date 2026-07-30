# Post-Installation Verification (Step 8 detail)

Procedural detail for [SKILL.md](../SKILL.md) **Step 8**. **Always run
verification checks via a subagent** (Agent tool) to keep the main conversation
clean. The subagent handles retries and verbose output, then returns a
structured result. The work is mechanical — a small/fast model (e.g. Haiku)
is sufficient when the client supports choosing one.

## Cloud accounts

Spawn a subagent to:
1. Run `terraform state list` — report resource count.
2. Run `scripts/verify-cloud-status.sh <provider> <account_id> --expect`.
   If account not yet visible, retry with backoff (60s, 120s, 180s). Max 3
   cycles with `[Verification 1/3]` headers. The Sysdig API endpoints and
   response fields the script relies on are documented in [api.md](api.md).
3. Return a structured result: feature status, resource count, pass/fail.

On subagent completion, present the receipt to the user. On max retries
reached: "Check Sysdig > Integrations > Cloud Accounts in ~15 min."

**Transient health error right after apply.** If a feature or component reports
a single connection/health error on the first check (common immediately after
apply — cloud IAM/RBAC is eventually consistent, so a role assignment or binding
created during apply may not have propagated when the first health probe runs;
see [known-issues.md](known-issues.md) `[CLOUD-001]`), it is expected and
self-healing. Wait ~2 minutes for propagation, then `POST
/api/cloudauth/v1/accounts/{account_id}/validate` once to force a fresh
connection check and re-read status (this re-runs validation only — it does not
change configuration). A single error at apply time that clears on
re-validation is not a failure; do not report it as one.

If `terraform apply` fails, consult [troubleshooting.md](troubleshooting.md).

## Kubernetes clusters

Spawn a subagent to run the 5-check verification sequence defined in
[shield.md §6 "Post-Installation Verification"](shield.md).
Checks: pod status, DaemonSet coverage, agent auth, backend connectivity,
driver health. Wait 30s before starting; retry up to 3 times at 30s intervals.
On failure, consult [shield.md §9](shield.md) for remediation.

## Linux hosts

Spawn a subagent to run the 6-check sequence from
[host-shield.md §8](host-shield.md). Wait ~60s before starting (agent
initialization); retry up to 3 times at 30s intervals.

The package install (`draios-agent`) registers the systemd unit **`dragent`**.
For **Docker installs** there is no unit: replace `journalctl -u dragent` with
`docker logs sysdig-agent` in Checks 2–4, read the file log inside the container
(`docker exec sysdig-agent grep ... /opt/draios/logs/draios.log`, no `sudo`) for
Checks 5–6, and replace Check 1 with the four probes below.

🔴 **`docker ps` is not a liveness check.** The image healthcheck reports
`Up … (healthy)` while the agent inside restarts every ~2 seconds — a fatal in
any agent subprocess (e.g. a Docker socket mounted at the wrong path) takes the
whole agent down, and `--restart always` relaunches it. Never accept
`docker ps` / `healthy` as Check 1. Instead:

```bash
docker inspect sysdig-agent --format '{{.RestartCount}} {{.State.Running}}'   # expect: 0 true
docker exec sysdig-agent grep -c Fatal /opt/draios/logs/draios.log            # expect: 0
docker exec sysdig-agent grep -c DIRTY_SHUTDOWN /opt/draios/logs/draios.log   # expect: 0
docker exec sysdig-agent grep 'Successfully loaded scap driver' /opt/draios/logs/draios.log
```

Then confirm **PID stability** — the in-container supervisor can restart the
agent without Docker's `RestartCount` moving:
`docker exec sysdig-agent grep 'Sent msgtype=1' /opt/draios/logs/draios.log | tail -5`
→ the same PID on every line. A changing PID, or zero `msgtype=1` lines
alongside `msgtype=10 (DIRTY_SHUTDOWN_REPORT)`, is a crash loop ⇒ **FAIL**, stop
and go to [host-shield.md §9](host-shield.md). (The `{{...}}` above are Docker
Go-template fields — pass them verbatim, they are not placeholders to fill.)

🔴 **Two log sinks — journald is not enough.** Checks 2–4 read journald;
Checks 5–6 read `/opt/draios/logs/draios.log`. The generated config sets
`log_persist: true`, which routes detail to that **file** sink: config
rejections and features the agent disabled itself never reach journald
(`journalctl -u dragent --grep 'Config file error'` returns
`-- No entries --` on an install whose config the agent rejected). Runtime
telemetry travels over the collector and is unaffected, so Checks 1–4 return
4/4 PASS while a selected capability is dead. Never report a pass on Checks
1–4 alone.

1. **Service status** — `systemctl status dragent` → expect `active (running)`.
   If this reports `Unit dragent.service could not be found`, the agent is not
   installed — **stop here**, report that, and go to
   [host-shield.md §9](host-shield.md). Do not run Checks 2–4 against a
   non-existent unit and do not report the resulting empty output as a pass.
2. **Agent auth** — `journalctl -u dragent --no-pager -n 100 --grep "Sent msgtype=1"`
   → expect at least one `Sent msgtype=1` line.
3. **Backend connectivity** — `journalctl -u dragent --no-pager -n 100 --grep "handshake"`
   → a handshake line (`handshake exchanged successfully`, or `BE handshake rsp -
   metric profile with N metrics`) confirms it, but **its absence is not a
   failure**: the wording is build-dependent and agent 14.7.2 emits neither on a
   healthy install. Check 2's accepted `Sent msgtype=1 (METRICS)` is the
   authoritative connectivity signal — if that is present, pass this check and
   note the handshake line was not emitted.
4. **Credential validation** — `journalctl -u dragent --no-pager -n 50 --grep "ERR_INVALID_CUSTOMER_KEY"`
   → expect **no** matches (a match means the wrong key — needs the Agent Access
   Key, not the Secure API Token).
5. **Config errors / self-disabled features (file log)** —
   `sudo grep -nE 'Critical|Config file error at key:|is enabled but .* is not set' /opt/draios/logs/draios.log`
   → expect **no** matches. Any hit is a **FAIL**: report the offending
   config key verbatim (`Config file error at key: <key>`) or the feature the
   agent disabled, and fix per [host-shield.md §8 Check 5](host-shield.md).
6. **Every selected capability is live** — for each feature the user chose,
   confirm the agent did not log that it disabled it (per-capability greps in
   [host-shield.md §8 Check 6](host-shield.md)). Report each as **live** or
   **disabled (reason)**. Selected-but-disabled ⇒ overall FAIL, regardless of
   Checks 1–4. The bar is **armed** — analyzer started, config accepted, backend
   reachable — **not** a published scan result: the backend deduplicates scan
   work per host identity, so `already extracted sbom recently: skipping scan`
   or a posture analyzer `polling for pending scan requests` with nothing
   assigned is a **pass** on a host that was scanned recently (re-install,
   container recreate, driver change). Report it as "armed; no scan assigned —
   host scanned recently", never as a failure.

**Empty output is not a pass.** Checks 2–6 rely on log greps: if a grep returns
nothing, distinguish "the agent is still initializing" (retry per the schedule
above) from "no logs at all" (`journalctl -u dragent --no-pager -n 5` also
returns nothing → treat as failure, not success). The same rule applies to
Checks 5–6 against the file sink: an empty result only counts when the file
exists and has content (`sudo tail -n 5 /opt/draios/logs/draios.log`, or
`docker exec sysdig-agent tail -n 5 /opt/draios/logs/draios.log` for a container
install); a missing or empty `/opt/draios/logs/draios.log` is a failure to
investigate, not a clean bill of health. On a Docker install the host has no
`/opt/draios` at all — a host-side grep returns nothing on a *healthy* agent, so
running these checks outside the container manufactures a false pass.

On failure, consult [host-shield.md §9](host-shield.md) for remediation, plus
[troubleshooting.md](troubleshooting.md) and [known-issues.md](known-issues.md).

## Windows nodes (Kubernetes)

Windows Host Shield runs only as a Kubernetes DaemonSet (`<release>-host-windows`)
on Windows worker nodes. Verify via the same Kubernetes pod sequence as Linux
clusters above, but scope it to the Windows Host Shield pods. The component
label `sysdig/component=host` is shared with the Linux Host Shield, so also
filter by the Windows OS node label to target *only* Windows pods:

```bash
# Windows Host Shield pods only:
kubectl get pods -n sysdig-agent \
  -l sysdig/component=host,app.kubernetes.io/name=shield \
  --field-selector spec.nodeName!="" -o wide | grep -i win
# Or address the DaemonSet directly:
kubectl get ds -n sysdig-agent sysdig-host-windows
```

Only **host posture** and **host vulnerability** data appear in Sysdig for
Windows nodes — the Windows DaemonSet carries **no** runtime/threat, network, or
investigation telemetry. (That is a property of this delivery path, not of
Windows support in general — the standalone MSI install covers more.) See [shield.md "Windows Nodes (Kubernetes DaemonSet)"](shield.md)
for the full label selector and `/healthz` health-probe details.

## Sysdig Links

After verification, show clickable URLs (plain text, not Markdown links)
using the Sysdig Secure URL from Step 0b. Keep the message short —
don't re-list enabled features.

> Cloud Accounts: {{SYSDIG_SECURE_URL}}/#/data-sources/cloud-accounts/{{PROVIDER}}?accountId={{SYSDIG_ACCOUNT_ID}}&statusFilter=All
> Inventory: {{SYSDIG_SECURE_URL}}/#/inventory
> Events (if CDR): {{SYSDIG_SECURE_URL}}/#/events?last=86400

**Internal IDs:** The Sysdig internal account ID (UUID from
`module.onboarding.sysdig_secure_account_id` or the cloudauth API) is
an internal identifier. It is fine to embed in backlink URLs (e.g., the
`accountId` query param above), but do NOT display it as standalone
information in conversation, reports, or summary tables. User-facing
identifiers should be the cloud provider's own account/project/
subscription ID.

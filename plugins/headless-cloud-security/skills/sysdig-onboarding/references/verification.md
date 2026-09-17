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

Spawn a subagent to run the 7-check sequence (numbered 1, 1b, 2–6) from
[host-shield.md §8](host-shield.md). Wait ~60s before starting (agent
initialization); retry up to 3 times at 30s intervals.

The package install (`draios-agent`) registers the systemd unit **`dragent`**.
For **Docker installs** there is no unit: replace Check 1 with the four probes
below and read **every** other check from the file log inside the container
(`docker exec sysdig-agent grep ... /opt/draios/logs/draios.log`, no `sudo`).
`docker logs sysdig-agent` is the console sink under the same `log_level: warn`
gate as journald, so it is **not** a substitute for Checks 2–4 — use it only for
liveness.

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

🔴 **Read the file sink, not journald — for every check.** The generated config
sets `log_level: warn`, which gates the console/journald sink, and every line
these checks look for (`Sent msgtype=1 (METRICS)`, the handshake, the
driver-load line) is **Information** level. On a perfectly healthy agent
journald therefore has **none** of them: an observed run concluded "the agent
has never authenticated … the absence of any `Sent msgtype=1` line after 3
retries is definitive" while `/opt/draios/logs/draios.log` held five such lines.
Config rejections and self-disabled features (Check 5) were also absent from
journald, but `log_level` does not explain that: those lines are `Critical`,
which `warn` does not gate. Read them from the file sink on observation, cause
unknown.

`/opt/draios/logs/draios.log` is authoritative for Checks 1b–6 and needs `sudo`
(root-only; `docker exec` on a container install). Use journald only to answer
"is the unit producing anything at all"; raising `log_level` to `info` should add
the **Information** lines there, but that is untested and does nothing for the
`Critical` ones.

🔴 **Precondition — the file sink exists.** Checks 4 and 5 pass on the *absence*
of matches, and `grep` on a missing or unreadable file yields zero matches too.
Run this before Check 1b and stop on failure; otherwise a broken sink reports as
a clean bill of health:

```bash
sudo test -s /opt/draios/logs/draios.log || echo "FAIL: file sink missing or empty — log_persist not applied; every 'no matches' below is meaningless"
```

Docker install: `docker exec sysdig-agent test -s /opt/draios/logs/draios.log`.

1. **Service status** — `systemctl status dragent` → expect `active (running)`.
   If this reports `Unit dragent.service could not be found`, the agent is not
   installed — **stop here**, report that, and go to
   [host-shield.md §9](host-shield.md). Do not run Checks 2–4 against a
   non-existent unit and do not report the resulting empty output as a pass.
   - **1b. Driver loaded** (package installs) —
     `sudo grep -E 'Successfully loaded scap driver|Cannot load the probe' /opt/draios/logs/draios.log`
     and, for the `kmod` driver, `lsmod | grep sysdigcloud_probe`. A failed
     driver build (missing `dkms` on rpm hosts, kernel-headers mismatch
     anywhere) leaves the agent running with no syscall source while Checks 1–4
     still pass ⇒ FAIL, see [host-shield.md §6.2](host-shield.md).
2. **Agent auth** — `sudo grep "Sent msgtype=1" /opt/draios/logs/draios.log | tail -5`
   → expect at least one `Sent msgtype=1 (METRICS)` line. **Never** run this
   against journald: it is empty there by design (see above), which reads as a
   failure on a healthy host.
3. **Backend connectivity** — `sudo grep -i "handshake" /opt/draios/logs/draios.log | tail -3`
   → a handshake line (`handshake exchanged successfully`, or `BE handshake rsp -
   metric profile with N metrics`) confirms it, but **its absence is not a
   failure**: the wording is build-dependent and agent 14.7.2 emits neither on a
   healthy install. Check 2's accepted `Sent msgtype=1 (METRICS)` is the
   authoritative connectivity signal — if that is present, pass this check and
   note the handshake line was not emitted.
4. **Credential validation** — `sudo grep "ERR_INVALID_CUSTOMER_KEY" /opt/draios/logs/draios.log`
   → expect **no** matches (a match means the wrong key — needs the Agent Access
   Key, not the Secure API Token).
5. **Config errors / self-disabled features (file log)** —
   `sudo grep -nE 'Critical|Config file error at key:|is enabled but .* is not set' /opt/draios/logs/draios.log`
   → expect **no** matches. Any hit is a **FAIL**: report the offending
   config key verbatim (`Config file error at key: <key>`) or the feature the
   agent disabled, and fix per [host-shield.md §8 Check 5](host-shield.md).
6. **Every selected capability is live** — take each capability's
   `Enabled` / `Disabled` from the **last** summary block. The capability lines
   precede the `completed` line, so read backwards from it:

   ```bash
   n=$(sudo grep -n "Feature manager initialization completed" /opt/draios/logs/draios.log | tail -1 | cut -d: -f1)
   [ -n "$n" ] || echo "FAIL: no feature summary in the log — the agent never finished initializing"
   sudo sed -n "$(( n > 40 ? n - 40 : 1 )),${n}p" /opt/draios/logs/draios.log
   ```

   🔴 The agent initializes **twice** (~12s
   apart); the first pass runs before the backend handshake and reports almost
   everything `Disabled`. A `grep -i disabled` over the whole file hits that
   stale block and reports six capabilities dead on a healthy host — always
   select the last block (by line number / PID). There are no
   `DIRTY_SHUTDOWN` lines around it: it is a planned re-init, not a crash.
   A selected capability still `Disabled` in the last block is usually a missing
   enable key rather than a broken host — `features.respond.response_actions`
   needs an explicit `enabled: true`, and every capability lives in the nested
   `features.*` tree (never emit its flat top-level spelling too — that crash-
   loops the agent, [host-shield.md §5.1b/§5.1c](host-shield.md)). Then confirm per-capability
   greps in [host-shield.md §8 Check 6](host-shield.md). Report each as **live** or
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

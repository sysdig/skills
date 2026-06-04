# Threat patterns — guidance, not recipes

This file gives the LLM a few worked examples of how to reason about
common runtime threats — what to look for, what order of actions usually
makes sense, what evidence-preservation steps to consider, what NOT to do
on instinct.

These are **patterns to recognise**, not steps to execute. The actual
ordering and choice for the threat in front of you comes from the
investigation case file plus the [`consequence-analysis-guide.md`](consequence-analysis-guide.md).

For any pattern below, the agent should be able to explain to the user
*why* the suggested ordering applies to **this specific** investigated
threat. If you can't explain it, you don't have enough context — probe
more in Step B.

## Cryptominer (xmrig / similar)

**Typical surface:** a process inside an otherwise-normal-looking
container (often a web app or a poorly-secured ML pod). Heavy CPU,
outbound traffic to mining pools (port 3333 / 5555 / 14444 / well-known
mining DNS).

**Common reasoning path:**

1. **Acquire evidence first.** The binary itself is the strongest IOC for
   downstream hunting (sha256, embedded config, peer list). Run
   `FILE_ACQUIRE` on the process binary before any containment.
2. **Isolate the network.** Mining pools are an outbound dependency —
   `ISOLATE_NETWORK` stops the mining without losing the running process
   tree. Confirm no sidecar collateral first (see consequence-analysis).
3. **Kill the process, not the container.** `KILL_PROCESS` removes the
   threat while keeping the container's filesystem and other processes
   intact — useful when the threat is a foreign process injected into a
   legitimate workload. If the container's main process *is* the miner
   (e.g., a malicious image), `KILL_CONTAINER` is appropriate.
4. **Watch for respawn.** The watcher matters here: persistence
   mechanisms (cron, systemd, K8s controllers reapplying the manifest)
   will bring it back. `still_active` after the watch window is a strong
   hint that the source is the image itself or an upstream actor.

**What NOT to do on instinct:**

- `DELETE_POD` first. If the pod has a controller, it'll come back —
  with the same compromised image. You've lost forensics for nothing.
- `ROLLOUT_RESTART` on the assumption that "a fresh container = clean".
  If the image is the source, every new pod is compromised.

## Terminal shell in container (interactive shell / nsenter / `kubectl exec`)

**Typical surface:** Falco rule "Terminal shell in container" or similar.
Could be a legitimate operator debugging, could be an attacker pivot.

**Common reasoning path:**

1. **Triage legitimacy first.** Check the Sysdig event for
   `k8s_audit` exec calls, the user identity, source IP. Cross-reference
   with the investigation's correlation findings — does this user
   normally exec into prod pods?
2. **If legitimate** → mark the case `cleared` (operator action), file
   a `GET_LOGS` for the session if the rule captures the command
   stream, and close. No destructive action.
3. **If suspicious** → `FILE_ACQUIRE` on `/proc/<pid>/exe` of the shell
   to preserve the binary, then `KILL_PROCESS` on the shell. Don't
   `KILL_CONTAINER` until you've confirmed the shell isn't PID 1 of a
   legitimate workload.
4. **Then check what else happened.** `kubectl exec` is often a footprint
   for a larger attack — pull recent events on the same pod/namespace.

## Outbound connection to known-bad IP / IOC hit

**Typical surface:** Falco network rule, threat-intel feed match, or
Sysdig CTI cross-reference.

**Common reasoning path:**

1. **`ISOLATE_NETWORK` first.** Stops further exfiltration / C2 traffic
   without losing in-memory state.
2. **Snapshot state for forensics.** If the pod is stateful, run
   `KUBERNETES_VOLUME_SNAPSHOT`. If not, `FILE_ACQUIRE` on relevant
   artifacts identified in the investigation (any dropped binaries,
   `/tmp/*`, etc.).
3. **Now you have time to think.** With the network cut and evidence
   captured, decide whether to keep the pod alive for further analysis
   or terminate.

**Important nuance:** `ISOLATE_NETWORK` may break the Sysdig agent's
ability to receive new rule evaluations on this pod if the agent
deployment is namespace-scoped. Verify the agent runs in a different
namespace or with hostNetwork before applying.

## Credential theft / IMDS access

**Typical surface:** event series showing access to the cloud metadata
endpoint (`169.254.169.254`) from a pod, followed by suspicious AWS API
calls.

**Common reasoning path:**

1. **Cloud first, then runtime.** Kill the pod first and you've lost the
   pod but the *credentials are still out there*. The attacker has them.
2. Verify in CloudTrail what the stolen role has been doing in the last
   N hours (see [`architecture-probing.md`](architecture-probing.md) for
   the lookup-events query).
3. **Revoke the credentials in AWS** before doing anything to the pod.
   Options, ordered by surgical-ness:
   - Attach an `AWSDenyAll`-equivalent policy to the assumed role to cut
     any active session immediately.
   - Rotate any long-lived access keys the threat may have created.
   - Disable the IAM user / SA mapping at the OIDC trust level.
4. **Then containment on the pod.** `ISOLATE_NETWORK` to prevent further
   credential exfil, `KILL_PROCESS` on the offending process, and so on.
5. **Audit downstream.** Once contained, hunt for everything the
   credentials touched while live (CloudTrail, GuardDuty findings, S3
   access logs).

The order matters: kill the pod first → the active session continues
because the credentials are cached in the attacker's hands, not in the
pod. Cloud-side revocation is what stops the bleed.

## Lateral movement attempt

**Typical surface:** RBAC abuse (a workload SA doing `pods/exec`,
`secrets/get` across namespaces), or kubelet credential abuse, or service
account token theft.

**Common reasoning path:**

1. **Do not act only on the source pod.** Lateral movement means the
   threat is already somewhere else. The "source" is just one footprint.
2. Pull recent k8s_audit events for the abused identity (the SA, the
   user, the impersonator) — cluster-wide, ±2h window.
3. Identify every workload the identity reached. Each one is a candidate
   target for containment.
4. **Containment in dependency order.** Start with the highest-privilege
   target (the one that, if cleaned, prevents further lateral moves) and
   work outward.
5. **Then revoke the identity.** Delete the abused RoleBinding /
   ClusterRoleBinding, or rotate the SA's token via deleting/recreating
   the Secret if a long-lived token is in play.

## Defense evasion (process masquerading, logging tampering, falco-agent kill)

**Typical surface:** a rule that fires for unusual modifications to
logging configs, audit log deletion, killing of the Sysdig agent, or
suspicious renames of system binaries.

**Common reasoning path:**

1. **Treat the signal as truncated.** If defenses are being disabled, the
   actual activity is broader than what made it into events.
2. **Snapshot first, hard.** `KUBERNETES_VOLUME_SNAPSHOT` for any
   stateful workload involved, `FILE_ACQUIRE` for relevant binaries.
3. **Then `PAUSE_CONTAINER`** rather than kill — pause freezes process
   state for forensic inspection without losing in-memory evidence.
4. Coordinate with the user before any kill — these threats are exactly
   the kind where keeping the process alive (paused) is more valuable
   than immediate containment.

## Recon (network scans, secret enumeration)

**Typical surface:** unusual port-scan activity, repeated
`kubernetes/secrets` LIST calls from a workload that shouldn't be doing
them.

**Common reasoning path:**

1. Recon is the *precursor*, not the attack. The attack hasn't happened
   yet (probably).
2. `ISOLATE_NETWORK` is often disproportionate — it stops the recon but
   may also stop legitimate workload traffic.
3. Often the right action is a combination of **file-as-ticket** (loop
   in the workload owner) + **KILL_PROCESS** on the specific scanner
   binary if one is identifiable.
4. Always investigate the *why* — recon from a legitimate-looking
   workload almost always means a compromised dependency or a malicious
   image update upstream.

## Generic principle: evidence before destruction

For any threat where the source isn't fully understood, the rough order
of preference is:

```
FILE_ACQUIRE / GET_LOGS / VOLUME_SNAPSHOT
         ↓
ISOLATE_NETWORK or PAUSE_CONTAINER (containment without state loss)
         ↓
KILL_PROCESS or KILL_CONTAINER (state loss accepted)
         ↓
DELETE_POD or ROLLOUT_RESTART (full reset)
```

You can deviate from this order, but the LLM should be able to justify
**why** the deviation makes sense for this specific case before
recommending it to the user.

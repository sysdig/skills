# Consequence-analysis guide

This file is heuristics for **Step B (Architecture & blast radius)**. It is
the LLM's checklist of questions to ask before proposing a destructive
action — not a recipe to follow blindly.

The goal of Step B is to be able to truthfully say, for every action the
skill is about to propose:

> "If we do **X**, I expect **Y**. Specifically, **Z** will keep working,
> and **W** will break or degrade. To recover, we'd need to **R**."

If any of Y / Z / W / R is uncertain, either probe further or downgrade
the action's confidence in Step C.

## The four questions

For every container/pod/host that any candidate action would touch:

### 1. Is it stateful?

- Does the pod own a PVC? Is it backed by a CSI snapshotter or just
  in-cluster storage?
- Is it part of a StatefulSet (ordinal identity matters, restart order
  matters)? If yes, `DELETE_POD` and `ROLLOUT_RESTART` have side effects
  the user must know about: ordered re-initialisation, possibly
  re-attaching volumes.
- Are there emptyDir volumes carrying state that would be lost?

If the workload is stateful and forensics matter, `KUBERNETES_VOLUME_SNAPSHOT`
should run before any destructive action.

### 2. Who depends on it?

- Which Services point to its label selector? Which Ingresses route to
  those Services?
- Which Deployments / Pods make outbound calls to it? Look for ServiceName
  resolution in init containers, sidecars, ConfigMaps with hostnames.
- Is there a Cron or Job that targets it explicitly?
- Is it behind an HPA? Killing it triggers scale-down, then scale-up,
  potentially burning through HPA's stabilisation window.
- Is it covered by a PDB? `DELETE_POD` will be refused if eviction violates
  the budget.

A single-replica Deployment with no Services pointing at it has very
different blast radius from a 3-replica frontend behind a public Ingress.

### 3. What does it depend on?

- Which Secrets / ConfigMaps does it mount? If `ISOLATE_NETWORK` is on the
  table, can it still read them at startup? (Mounted secrets are cached;
  external secret operators are not.)
- Which ServiceAccount does it run as? What RBAC does that SA have? Is
  there a Role that the threat could have already exploited (e.g., create
  pods, exec into pods, read secrets cluster-wide)?
- For IRSA (AWS) / Workload Identity (GCP) / Workload Identity (Azure)
  setups: what cloud role/identity does the SA assume? Has it been used
  recently (cloud audit log — CloudTrail / GCP Audit / Azure Activity, or
  the `FETCH_CLOUD_LOGS` CLOUD responder action)?
- Are there CRDs (SecretProviderClass, ExternalSecret, VaultStaticSecret)
  that bind it to external state?
- Is it part of a service mesh? Istio / linkerd sidecars need their
  control-plane reachable — `ISOLATE_NETWORK` will sever that link and
  the sidecar will start failing health checks.

### 4. What's the recovery path?

- If we run this action and it makes things worse, what's the rollback?
- Is the undo a single API call (most reversible Response Actions), a
  rolled-back NetworkPolicy, a re-applied manifest, a re-pushed image, a
  manual SRE pageout?
- How long does recovery take in wall-clock time? "5 seconds to undo a
  PAUSE" is very different from "10 minutes to roll back a Deployment".

## Surfacing the answer

Per the principle "Lead with the outcome", Step B's output to the user is
a **mini-map**, not a wall of text. Suggested shape:

```
Affected workload: store-frontend (Deployment, 3 replicas)
  Cluster:       prod-eu-1
  Namespace:     ecommerce
  Owner:         (none surfaced — RBAC creator wasn't recorded)
  Stateful?      No emptyDir, no PVCs.
  Behind:        Service store-frontend (ClusterIP) → Ingress ecom-public
                 (TLS-terminating, exposes /api/store/*)
  Dependencies:  Deployment cart (calls /products), Job nightly-export
  Sidecars:      istio-proxy (Istio mesh; control-plane is istiod.istio-system)
  Identity:      IRSA → arn:aws:iam::123456789012:role/store-frontend-prod
                 Recent CloudTrail (1h): no IAM API activity
  PDB / HPA:     PDB minAvailable=1, HPA 3-10 replicas, currently 3
  RBAC:          service-account 'store-frontend' has Role 'reader' in this
                 namespace (get/list pods, configmaps, secrets)
```

Below the mini-map, name explicitly the things that would break **per
candidate action**:

```
ISOLATE_NETWORK on this pod will:
  ✓ Cut outbound calls from the cryptominer (intended effect)
  ⚠ Cut the istio-proxy → istiod control plane → sidecar drops out of mesh
    within ~30s. Pod's readiness probe (/healthz on 8080) is not affected
    directly, but mesh-routed callers will see the pod as unhealthy and
    stop sending traffic.
  ⚠ Service 'store-frontend' will have 2/3 endpoints healthy for the
    duration; cart's calls will fail-over but with possibly higher
    latency.
  ✓ Reversible via DELETE_NETWORK_POLICY (single API call).
```

## Probing without authorization

If the user has **not** authorized `kubectl` or AWS CLI access yet, Step B
runs whatever it can via Sysdig MCP only:

- `run_sysql` for workload/RBAC/Service mappings.
- `get_event_process_tree` for the process chain.
- `list_runtime_events` for recent activity on the
  same workload (last 7 days).

If MCP-only probing leaves dependency gaps, **say so** and offer the user
the choice: authorize `kubectl` read-only access for richer probing, or
proceed with degraded analysis (and constrain the action set accordingly).
Read-only authorization (just `get` and `describe`) is a much weaker grant
than full kubectl, and most users will accept it for the probing benefit.

See [`architecture-probing.md`](architecture-probing.md) for the exact
queries and commands.

## When to downgrade or refuse

Some signals mean "don't act yet, or act with a lighter action":

- **Untyped / unmonitored dependencies.** If the SysQL graph shows
  callers/callees you can't identify, the blast radius is unknown —
  prefer PAUSE_CONTAINER (reversible, freezes state) over KILL_*.
- **Active forensic value.** If the threat involves credential theft,
  lateral movement, or unknown malware, kill loses evidence. Run
  FILE_ACQUIRE / GET_LOGS / KUBERNETES_VOLUME_SNAPSHOT first.
- **High traffic / production-critical.** If the workload is on a
  business-critical Ingress and ISOLATE_NETWORK would drop the entire
  user-facing path, downgrade to per-process containment (KILL_PROCESS)
  or escalate via file-as-ticket so a human approves the outage window.
- **PDB conflicts.** If `DELETE_POD` would violate a PodDisruptionBudget,
  the API call fails. Propose ROLLOUT_RESTART (respects PDB) or
  KILL_CONTAINER (operates below the K8s API).

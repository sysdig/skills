# Response Actions catalog — semantic guide

This file describes each Sysdig Response Action **as a primitive** — what it
does, what it doesn't do, what it typically breaks, and whether it's
undoable. It is **not** a threat-class → action lookup table. The decision
of which action(s) fit a given threat lives in
[`threat-patterns.md`](threat-patterns.md) and in the LLM's own reasoning
over the investigation findings.

When in doubt about parameter shapes, query the live API for the most
accurate definition for the current tenant:

Call `mcp__secure-mcp-server__list_response_actions`.

The list is contextual — pass `context_event_id: <id>` to scope it to a
specific event and get only the actions Sysdig itself believes are
applicable, plus their parameter requirements. An empty result is
**inconclusive** (the API couldn't resolve responder availability from the
event alone), not proof that nothing can run.

## Base URL and auth

- Base path: `/secure/response-actions/v1alpha1/`
- Auth: Bearer token (the same one used elsewhere in this plugin — auto-
  discovered from `SYSDIG_SECURE_API_TOKEN` and friends).
- Required permissions:
  - `containment-response-actions.exec` — for any action that contains or
    mutates the workload (KILL_*, STOP_*, PAUSE_*, DELETE_POD,
    ROLLOUT_RESTART, FILE_QUARANTINE, ISOLATE_NETWORK).
  - `containment-response-actions.read` — for listing / status / undo.
  - `data-gathering-response-actions.exec` — for FILE_ACQUIRE, GET_LOGS,
    KUBERNETES_VOLUME_SNAPSHOT.
  - `data-gathering-response-actions.read` — for listing / status /
    downloading acquired files.

If the user's token lacks the relevant permission, the API returns 403.
Surface the missing permission name in the file-as-ticket fallback so the
ticket can request the right grant.

## The action types

Action types are sent as the `actionType` field in the submit payload. The
list below covers every type the API documents at the time of writing. The
`isUndoable` column is the value the API returns from
`GET /secure/response-actions/v1alpha1/actions`.

### Containment actions

These change the state of a live workload. They require explicit user
confirmation **for that specific action** before submission.

#### KILL_PROCESS
- **Does:** sends SIGKILL to a process inside a running container.
- **Doesn't:** affect the container or pod. If the container's main process
  is what you kill, the container exits; the orchestrator's restart policy
  decides what happens next (almost always: restart with a fresh PID).
- **Typical params:** `processId` (PID), `containerId` (or equivalent
  workload selector — call `list-actions --context-event-id <id>` to see
  what the tenant expects).
- **Reversibility:** None. The process is gone. A respawn of the same
  binary brings the threat back.
- **Forensic cost:** in-memory state of that process is lost. If forensics
  matter, run `FILE_ACQUIRE` on the binary first.

#### KILL_CONTAINER
- **Does:** kills the container at the container-runtime level (containerd
  / dockerd kills the process namespace).
- **Doesn't:** delete the pod. Kubernetes restart policy is what controls
  the next state.
- **Reversibility:** None on its own. `restartPolicy: Always` (the default
  for Deployments) brings a new container up; `restartPolicy: Never`
  (Jobs) leaves the pod terminated.
- **Forensic cost:** filesystem state in the container's writable layer is
  lost when it's removed. Volume mounts persist. Snapshot first if needed.

#### STOP_CONTAINER
- **Does:** sends a graceful stop (SIGTERM → grace → SIGKILL) to the
  container.
- **Doesn't:** delete the pod or change the restart policy.
- **Reversibility:** Yes — pair undo is `START_CONTAINER`. Use the undo
  endpoint (`DELETE /action-executions/<id>`); do not submit `START_*`
  directly.

#### PAUSE_CONTAINER
- **Does:** freezes the cgroup of the container (`kubectl exec` equivalent
  of `runc pause`). The processes stay resident but don't get scheduled.
- **Doesn't:** unmount anything, lose memory state, or trigger any restart
  signals.
- **Reversibility:** Yes — pair undo is `UNPAUSE_CONTAINER`. Use the undo
  endpoint.
- **Good for:** preserving forensic state of a live process tree while
  blocking further activity. Often the first containment step for
  evidence-sensitive threats.

#### DELETE_POD
- **Does:** removes the pod object from the Kubernetes API.
- **Doesn't:** prevent the controller from creating a replacement (the
  Deployment / StatefulSet / DaemonSet will reschedule). For one-off pods
  (no controller) it really is gone.
- **Reversibility:** None on its own. The controller's behaviour determines
  what happens next.
- **Notable interaction:** PDBs can refuse the eviction — be ready to fall
  back to STOP_CONTAINER.

#### ROLLOUT_RESTART
- **Does:** triggers `kubectl rollout restart` semantics on the owning
  workload (Deployment / StatefulSet / DaemonSet). Pods are replaced
  according to the rollout strategy.
- **Doesn't:** change the image, env, or any spec field. New pods come up
  with the same config — useful when the threat is from a runtime injection
  that won't survive a fresh container, useless when the threat is from a
  compromised image (the new pods will be just as compromised).
- **Reversibility:** None directly, but the workload's revision history
  allows manual rollback if needed.

#### ISOLATE_NETWORK
- **Does:** applies a Kubernetes NetworkPolicy that denies all ingress and
  egress for the affected pod's labels.
- **Doesn't:** disconnect existing TCP connections (they may continue until
  timeout). Doesn't affect host networking or hostNetwork-mode pods.
- **Reversibility:** Yes — pair undo is `DELETE_NETWORK_POLICY`. Use the
  undo endpoint.
- **⚠ Common side effects:**
  - Sidecar proxies (Istio, linkerd) lose their control-plane connection
    and start failing readiness probes.
  - SecretProviderClass / external-secrets pods can't reach their backend.
  - kube-dns lookups break; pods relying on cross-namespace DNS fail to
    resolve.
  - Sysdig agent itself can lose connectivity if the pod is in a namespace
    covered by the policy — most agents run on host network, but verify
    before applying.

#### FILE_QUARANTINE
- **Does:** moves the named file to a quarantine path on disk inside the
  container (the responder agent handles the move).
- **Doesn't:** delete the file. Restoration is supported via
  `FILE_UNQUARANTINE`.
- **Reversibility:** Yes — pair undo is `FILE_UNQUARANTINE`. Use the undo
  endpoint.
- **Good for:** disabling a suspicious binary without losing it, while a
  human reviews.

### Data-gathering actions

These are read-only (no workload state change) and don't require the
destructive-action disclaimer. They still consume tenant-side quota and
storage, so confirm before running.

#### FILE_ACQUIRE
- **Does:** pulls a copy of a named file from the affected container or
  host into Sysdig-managed object storage.
- **Output retrieval:** `GET /action-executions/<id>/acquired-file`
  returns a downloadable URL (or the bytes, per the tenant's setup).
- **Use:** capture forensic evidence (binaries, configs, logs) before any
  destructive action removes them.

#### GET_LOGS
- **Does:** captures container stdout/stderr at the moment of execution.
- **Use:** quick triage when the investigation case file didn't already
  include them.

#### KUBERNETES_VOLUME_SNAPSHOT
- **Does:** triggers a CSI VolumeSnapshot of a PVC mounted by the affected
  pod.
- **Reversibility:** Snapshot deletion via `KUBERNETES_DELETE_VOLUME_SNAPSHOT`
  (use the undo endpoint).
- **Use:** evidence preservation for stateful workloads before deleting
  the pod or wiping a volume.

#### CAPTURE
- **Does:** triggers a Sysdig syscall capture on the host where the
  affected container runs. The resulting `.scap` file becomes the canonical
  forensic artifact for the threat — every syscall, every network flow,
  every file event during the capture window.
- **Use:** when the investigation needs more than just process-tree and
  log-level evidence — e.g., to reconstruct an attacker's exact actions
  for IR or legal evidence.
- **Cost:** the capture file can be large (hundreds of MB). Plan a
  destination and a retention policy before triggering.

### Cloud-side actions (CLOUD responder)

These run via the cloud integration and affect cloud-provider state (IAM,
storage, networking), not the workload. They require the cloud responder
to be deployed and the relevant cloud credentials on the Sysdig side.

#### IAM_QUARANTINE
- **Does:** attaches a deny-all (or restrictive) policy to an IAM identity
  (user, role) so any active session loses effective permissions. Cloud-
  provider-specific under the hood, surfaced uniformly via the API.
- **Reversibility:** Yes — pair undo is `IAM_UNQUARANTINE`. Use the undo
  endpoint.
- **Use:** primary action for credential-theft threats. Cuts the bleed
  immediately, regardless of where the credentials are being used from.
  See [`threat-patterns.md`](threat-patterns.md) → "Credential theft" for
  ordering relative to runtime containment.

#### MAKE_PRIVATE_CLOUD_RESOURCE
- **Does:** flips a publicly-exposed cloud resource (S3 bucket, EBS
  snapshot, RDS snapshot, depending on provider) to private. Useful when
  the threat exposed a resource to the internet.
- **Reversibility:** Yes — pair undo is `UNDO_MAKE_PRIVATE_CLOUD_RESOURCE`.

#### CLOUD_VOLUME_SNAPSHOT
- **Does:** snapshot a cloud-managed volume (EBS, persistent disk, managed
  disk) without going through Kubernetes. For workloads not in K8s, or for
  evidence of the underlying disk independent of the pod lifecycle.
- **Reversibility:** Yes — pair undo is `UNDO_CLOUD_VOLUME_SNAPSHOT`.

#### FETCH_CLOUD_LOGS
- **Does:** pulls cloud-provider audit logs (CloudTrail, GCP Audit, Azure
  Activity) into Sysdig for the relevant identity / resource / time window.
- **Use:** post-incident audit when the investigation needs cloud-side
  context that wasn't surfaced as Sysdig events. Often paired with
  `IAM_QUARANTINE` to validate the credential-theft hypothesis.

## How to map a desired action to a payload

Don't infer the parameter schema from this file — the tenant's live
catalog is authoritative. The recommended flow:

1. Call `mcp__secure-mcp-server__list_response_actions` with
   `context_event_id: <event_id>`. The response includes a `parameters`
   array per action with name, type, required, description.
2. Fill the params from the investigation case file (container ID, PID,
   workload selectors, etc.).
3. Submit via `mcp__secure-mcp-server__submit_response_action` with
   `action_type` and `parameters`.
4. Capture the returned execution `id`. Poll
   `mcp__secure-mcp-server__get_response_action_status` with
   `action_execution_id` until `COMPLETED` or `FAILED`.

## Status and undo

- Status is one of `ENQUEUED`, `IN_PROGRESS`, `COMPLETED`, `FAILED`.
- Undo (for actions whose `isUndoable` is true) goes through
  `mcp__secure-mcp-server__undo_response_action` (do NOT submit the pair
  action directly — the API rejects manual submission of pair-undo types
  like `START_CONTAINER`, `UNPAUSE_CONTAINER`, `FILE_UNQUARANTINE`,
  `DELETE_NETWORK_POLICY`, `KUBERNETES_DELETE_VOLUME_SNAPSHOT`).
- When surfacing undo to the user, render the exact call they could run:

  ```
  mcp__secure-mcp-server__undo_response_action  action_execution_id=b137bf86-...
  ```

## Responder types

The `responderType` field on a returned action metadata block tells you
where the action runs:

- `HOST` — executed by the Sysdig agent on the underlying node.
- `CLUSTER` — executed via the cluster-wide responder (typically for K8s
  API operations like DELETE_POD, ROLLOUT_RESTART).
- `CLOUD` — executed via the cloud integration (currently rare; verify
  per-tenant availability).

If `list-actions` returns no `CLUSTER` responder for a K8s action, the
tenant likely hasn't deployed the cluster-side responder — surface that
gap as a "fix: deploy the K8s responder per the Sysdig Secure docs" hint
in the file-as-ticket fallback.

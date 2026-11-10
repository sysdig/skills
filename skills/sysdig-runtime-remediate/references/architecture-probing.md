# Architecture probing — read-only recipes

This file is a recipe book for **Step B**. Every command and query in here
is **read-only** by design — none of them mutate state, none of them
require the destructive-action disclaimer. They produce the inputs the LLM
needs for [`consequence-analysis-guide.md`](consequence-analysis-guide.md).

Three surfaces, used in this order of preference:

1. **Sysdig MCP** — always available when the skill is wired up. No
   authorization gate.
2. **kubectl** — only after the user authorizes (or read-only authorizes)
   the kubectl surface for this session.
3. **AWS CLI** — only after the user authorizes (or read-only authorizes)
   the AWS surface for this session.

Always narrate before running anything ("I'll check which Services point to
this workload, using SysQL..."). Per principle C-01, no silent probes.

## Sysdig MCP — SysQL recipes

Run via `run_sysql`. SysQL schema varies by tenant
— if a query is rejected, try the alternate relation shapes listed below.

### Identify the workload from a container ID

```cypher
MATCH KubeWorkload AS w HAS KubePod AS p HAS Container AS c
  WHERE c.id CONTAINS '<container_id_prefix>'
  RETURN w.cluster, w.namespace, w.kind, w.name, p.name, c.name
  LIMIT 5;
```

If the relation `HAS` is rejected, try the alternates `BINDS_TO`,
`CONTAINS`, `OWNS` — Sysdig's SysQL evolves and tenants may be on
different vocabularies.

### Find what points to a workload (Services / Ingresses)

```cypher
MATCH KubeService AS s POINTS_TO KubeWorkload AS w
  WHERE w.cluster = '<cluster>' AND w.namespace = '<ns>' AND w.name = '<wl>'
  RETURN s.name, s.type, s.selector;
```

```cypher
MATCH KubeIngress AS i ROUTES_TO KubeService AS s POINTS_TO KubeWorkload AS w
  WHERE w.cluster = '<cluster>' AND w.namespace = '<ns>' AND w.name = '<wl>'
  RETURN i.name, i.hosts, s.name;
```

### Identify the ServiceAccount and RBAC

```cypher
MATCH KubeWorkload AS w USES KubeServiceAccount AS sa
  WHERE w.cluster = '<cluster>' AND w.namespace = '<ns>' AND w.name = '<wl>'
  RETURN sa.name;
```

```cypher
MATCH KubeServiceAccount AS sa HAS KubeRoleBinding AS rb BINDS KubeRole AS r
  WHERE sa.namespace = '<ns>' AND sa.name = '<sa_name>'
  RETURN rb.name, r.name, r.rules;
```

The same shape applies to `KubeClusterRoleBinding`/`KubeClusterRole` for
cluster-wide RBAC.

### Cloud identity (IRSA / Workload Identity)

```cypher
MATCH KubeServiceAccount AS sa ASSUMES CloudIamRole AS r
  WHERE sa.namespace = '<ns>' AND sa.name = '<sa_name>'
  RETURN r.arn, r.policies;
```

### Recent events on the same workload

Use `list_runtime_events` directly:

```json
{
  "filter_expr": "kubernetes.cluster.name = '<cluster>' and kubernetes.namespace.name = '<ns>' and kubernetes.workload.name = '<wl>'",
  "scope_hours": 168,
  "limit": 50
}
```

7 days is a reasonable window; widen if the threat seems to span longer
dormancy periods.

## kubectl — read-only recipes

These run only after the user authorizes the kubectl surface (full or
read-only). Always print the exact command before running it (principle
S-02).

### Verify the context matches the threat FIRST

Before asking the user to authorize kubectl, confirm the local context
actually points at the threat's cluster — otherwise the grant is useless
and every probe targets the wrong cluster.

```bash
kubectl config current-context
```

Compare the result against the threat's `kubernetes.cluster.name`. Context
names are local aliases, so they rarely match verbatim — look for a clear,
defensible correspondence, and when the local context is plainly a
*different* cluster, say so and skip kubectl rather than offering a
dead-end grant. The same caution applies to `container.id`: HOST
container-scoped Response Actions need a runtime container ID that only a
**context-matched** cluster can supply:

```bash
kubectl -n <ns> get pod <pod> -o jsonpath='{.status.containerStatuses[*].containerID}'
```

### Identify the owning workload from a pod

```bash
kubectl -n <ns> get pod <pod> -o jsonpath='{.metadata.ownerReferences}' | jq .
```

```bash
kubectl -n <ns> get pod <pod> -o yaml | head -200
```

### Service and Ingress mapping

```bash
kubectl -n <ns> get svc -o json | jq --arg labels "<workload_label_selector>" \
  '.items[] | select(.spec.selector | to_entries | map("\(.key)=\(.value)") | join(",") | contains($labels)) | {name: .metadata.name, type: .spec.type, selector: .spec.selector}'
```

```bash
kubectl -n <ns> get ingress -o json | jq '.items[] | {name: .metadata.name, rules: .spec.rules}'
```

### NetworkPolicy currently in effect on the pod's labels

```bash
kubectl -n <ns> get networkpolicy -o json | jq '.items[] | {name: .metadata.name, podSelector: .spec.podSelector, policyTypes: .spec.policyTypes}'
```

Useful before submitting `ISOLATE_NETWORK` — confirm the Response Action
won't collide with an existing policy.

### PodDisruptionBudget and HorizontalPodAutoscaler

```bash
kubectl -n <ns> get pdb -o json | jq '.items[] | {name: .metadata.name, minAvailable: .spec.minAvailable, maxUnavailable: .spec.maxUnavailable, selector: .spec.selector}'
```

```bash
kubectl -n <ns> get hpa -o json | jq '.items[] | {name: .metadata.name, target: .spec.scaleTargetRef.name, min: .spec.minReplicas, max: .spec.maxReplicas, current: .status.currentReplicas}'
```

### Sidecar and mesh detection

```bash
kubectl -n <ns> get pod <pod> -o jsonpath='{.spec.containers[*].name}'
kubectl -n <ns> get pod <pod> -o jsonpath='{.metadata.annotations}' | jq .
```

Look for `istio-proxy`, `linkerd-proxy`, `envoy`, `vault-agent`, or
`secrets-store-csi-driver` containers, and annotations like
`sidecar.istio.io/inject: "true"`. Each one shifts the consequence
analysis.

### Mounted secrets and configmaps

```bash
kubectl -n <ns> get pod <pod> -o jsonpath='{.spec.containers[*].envFrom}' | jq .
kubectl -n <ns> get pod <pod> -o jsonpath='{.spec.volumes}' | jq '.[] | {name, secret: .secret.secretName, configMap: .configMap.name}'
```

## AWS CLI — read-only recipes

Only after the user authorizes the AWS surface. The user must also confirm
the active profile and region before any call.

> **Cloud coverage.** AWS is the worked example for the out-of-band CLI path.
> The skill does **not** bundle `gcloud` / `az` recipes — for **GCP** (Workload
> Identity, Cloud Audit Logs) and **Azure** (Workload Identity, Activity /
> Entra logs), prefer the SysQL cloud-identity recipe above plus the in-product
> **CLOUD responder** Response Actions (`FETCH_CLOUD_LOGS`, `IAM_QUARANTINE`,
> `MAKE_PRIVATE_CLOUD_RESOURCE`), which Sysdig surfaces uniformly across
> providers — see [`response-actions-catalog.md`](response-actions-catalog.md).
> If you do have a GCP/Azure CLI authorized out of band, the read-only intent
> below maps directly (identity → `gcloud iam` / `az role assignment`; audit
> log → Cloud Logging / `az monitor activity-log`), but treat those as
> user-driven, not skill-bundled.

### Verify the account matches the threat FIRST

Before asking the user to authorize AWS reads, confirm the active
credentials are for the threat's account — otherwise every call hits the
wrong account.

```bash
aws sts get-caller-identity
```

Compare the returned `Account` against the threat's `aws.accountId`. If
they differ, say so and skip AWS probing (record the cloud-identity gap)
rather than offering a dead-end grant — or let the user switch profile
(`AWS_PROFILE` / `--profile`) and re-run. Note that a stolen **IMDS /
instance-role** credential belongs to the *node's* account; confirm you're
in that account, not a personal default profile.

### IAM role identity (IRSA / Workload Identity)

```bash
aws --profile <profile> iam get-role --role-name <role_name>
aws --profile <profile> iam list-attached-role-policies --role-name <role_name>
aws --profile <profile> iam list-role-policies --role-name <role_name>
```

For inline policies, fetch and pretty-print each:

```bash
aws --profile <profile> iam get-role-policy \
  --role-name <role_name> --policy-name <policy_name>
```

### Recent CloudTrail activity for the role

CloudTrail is the canonical source for "was this role's credentials abused".

```bash
aws --profile <profile> cloudtrail lookup-events \
  --lookup-attributes AttributeKey=Username,AttributeValue=<role_session_name> \
  --max-results 50 \
  --start-time $(date -u -d '1 hour ago' +%Y-%m-%dT%H:%M:%SZ)
```

If the threat hit an EC2 instance via IMDS, the session name in
CloudTrail is the instance ID prefixed with the role name. Adjust
accordingly.

### Active access keys for the role

If the threat may have created a long-lived access key:

```bash
aws --profile <profile> iam list-access-keys --user-name <user_or_role>
aws --profile <profile> iam get-access-key-last-used --access-key-id <key_id>
```

## What to capture for the user

Per [`consequence-analysis-guide.md`](consequence-analysis-guide.md), the
output of Step B is the mini-map. Pull only what's needed for that view —
don't dump entire `kubectl get -o yaml` blobs into chat. Summarise:

- Workload identity (kind, replicas, owner if discoverable)
- Stateful storage (PVCs, snapshotters)
- Inbound traffic (Services pointing at it, Ingresses routing to those)
- Outbound dependencies (what it calls — best inferred from the process
  tree + recent events)
- Sidecars and mesh participation
- ServiceAccount + cloud identity + recent activity
- PDB / HPA constraints
- RBAC the threat may have already exercised

Cite the source (SysQL query name, kubectl command, AWS API call) inline,
the same way `sysdig-runtime-investigate` cites every claim. Provenance
matters more than verbosity.

# Kubernetes Onboarding Reference (Sysdig Shield)

## Table of Contents

1. [Overview](#1-overview)
2. [Prerequisites](#2-prerequisites)
3. [Supported Distributions](#3-supported-distributions)
4. [Interview Questions](#4-interview-questions)
5. [Feature Reference](#5-feature-reference)
6. [Helm Installation & Verification](#6-helm-installation)
7. [Values Configuration](#7-values-configuration)
8. [Distribution-Specific Notes](#8-distribution-specific-notes)
9. [Troubleshooting](#9-troubleshooting)

---

## 1. Overview

Sysdig Shield for Kubernetes is deployed via the **`sysdig/shield`** Helm chart
(not the legacy `sysdig-deploy` chart). It installs two components in a single
Helm release:

- **Cluster Shield** (Deployment, 2 replicas): Cluster-level security —
  Kubernetes audit logging, admission control, cluster posture (KSPM),
  container vulnerability scanning, and Kubernetes metadata collection.
- **Host Shield** (DaemonSet, one pod per node): Node-level security —
  Falco-based runtime threat detection, host posture, host vulnerability
  scanning, drift control, malware control, and file integrity monitoring.

Both components are configured through a single `values.yaml`. Features are
toggled individually via `features.*` keys, so you can start with a subset
and add more later with `helm upgrade`.

> **Important — Agent Access Key, not API Token:** The Shield chart requires
> the **Agent Access Key** (`sysdig_endpoint.access_key`), found in Sysdig UI →
> **Settings → Agent Keys**. This is different from the Secure API Token used
> for cloud account onboarding. The agent connects to the Sysdig collector
> (data plane), not the API (control plane).

---

## 2. Prerequisites

| Requirement | Minimum / Notes |
|-------------|----------------|
| `kubectl` | Configured with cluster access |
| Helm | v3.10+ |
| Kubernetes | v1.25+ recommended |
| Linux kernel | 3.10+ on worker nodes (for Host Shield eBPF/kmod) |
| Outbound ports | 443 to Sysdig collector, 6443 for K8s audit webhook |
| Intra-cluster ports | 12000 (KSPM), 4222 (container vulnerability mgmt) |
| Sysdig Agent Access Key | From Sysdig UI → Settings → Agent Keys |
| CPU architectures | x86_64, ARM64 |

### Hardware requirements per node

Shield images total ~1.5 GB. Nodes with less than 3 GB free disk will hit
`DiskPressure` and evict pods.

| Component | CPU request | CPU limit | Memory request | Memory limit |
|-----------|:-----------:|:---------:|:--------------:|:------------:|
| **Host Shield** (per node) | 250m | 1000m | 384Mi | 1Gi |
| **Host Shield kmod init** (per node, transient) | 250m | 1000m | 384Mi | 1Gi |
| **Cluster Shield** (per replica, 2 default) | 500m | 1500m | 512Mi | 1536Mi |

**Per-node total** (Host Shield): 250m CPU, 384Mi memory (requests).
**Per-cluster total** (Cluster Shield, 2 replicas): 1000m CPU, 1024Mi memory (requests).
**Disk**: ~1.5 GB for images + ephemeral storage. Nodes with < 3 GB free disk
will trigger `DiskPressure` and evict all pods.

> **Small clusters warning:** On clusters with very small nodes (e.g., t3.micro
> with 8 GB disk), Shield images alone can fill the disk. Ensure at least
> 10 GB ephemeral storage per node.

> **EKS Fargate:** Host Shield (DaemonSet) cannot run on Fargate nodes — no
> host-level access. Shield cluster-level features still work. If the cluster has
> both Fargate and EC2 node groups, Host Shield runs only on EC2 nodes.

---

## 3. Supported Distributions

| Distribution | Shield | Host Shield | Notes |
|-------------|:-:|:-:|-------|
| Vanilla Kubernetes | Yes | Yes | |
| Amazon EKS | Yes | Yes | Fargate: Shield only (no Host Shield) |
| Google GKE | Yes | Yes | Must use `universal_ebpf` driver (COS has no kernel headers) |
| GKE Autopilot | Yes | Limited | Set `cluster_type: gke-autopilot`, `universal_ebpf`, non-privileged |
| Azure AKS | Yes | Yes | |
| Red Hat OpenShift 4.x+ | Yes | Yes | May need SCC adjustments |
| Rancher RKE/RKE2 | Yes | Yes | |
| k3s | Yes | Yes | Verify containerd socket path |
| IBM IKS | Yes | Yes | |
| Oracle OKE | Yes | Yes | |

---

## 4. Interview Questions

When onboarding a Kubernetes cluster, gather the following information.
Skip questions when answers can be inferred from context.

### 4a. Cluster name

Auto-detect if possible:
```bash
kubectl config current-context
```

Ask the user to confirm or provide a descriptive name (e.g.,
`prod-us-east-1`, `staging-gke`). This name appears in Sysdig UI.

### 4b. Kubernetes distribution

```
Which Kubernetes distribution are you using?
→ Vanilla K8s / EKS / GKE / GKE Autopilot / AKS / OpenShift 4.x+ / RKE2 / k3s / IKS / OKE
```

The distribution determines:
- **Host Shield driver** (see §4d)
- **Cluster type** setting (`generic` or `gke-autopilot`)
- **Privileged mode** requirements

### 4c. Feature profile

Instead of asking about 15+ individual toggles, offer profiles:

```
Which security profile do you want to start with?

1. Detect & Respond (recommended)
   Runtime threat detection, K8s audit logging, drift control, activity audit

2. Posture & Compliance
   Cluster posture (KSPM), host posture, admission control

3. Full Protection
   All of the above + container/host vulnerability scanning, malware control,
   file integrity monitoring, network security, live logs, rapid response

4. Custom
   Pick individual features from the full list
```

If **Custom**, walk through each feature from the Feature Reference table (§5).

### 4c-ii. Post-selection: mention available features

After the user confirms their profile, briefly mention what else is available
without asking them to choose. Keep it to one short paragraph, not a list of
15 features. Example:

> **Good to know:** Beyond what we're enabling now, Shield also supports
> malware detection, file integrity monitoring, network security policies,
> live container logs, forensic captures, and rapid response shells. You can
> enable any of these later with a `helm upgrade` — no reinstall needed.
>
> There are also Sysdig Monitor features (Prometheus, StatsD, app checks,
> Kubernetes events) available in the same chart if you use Sysdig Monitor.

This sets expectations without overwhelming the user or turning the interview
into a feature catalog.

### 4d. Host Shield driver

| Driver | When to use |
|--------|------------|
| `kmod` (default) | Standard Linux with kernel headers available |
| `universal_ebpf` | **GKE (COS)**, immutable/container-optimized OS, no kernel headers |
| `legacy_ebpf` | Older kernels without CO-RE support |

**Auto-select logic:**
- GKE / GKE Autopilot → `universal_ebpf` (COS kernel has no headers; kmod fails)
- EKS with Bottlerocket → `universal_ebpf` (immutable OS, no kernel headers)
- OpenShift / standard Linux / Amazon Linux → `kmod` (default)
- If user reports kmod failure → suggest `universal_ebpf`

### 4e. Namespace

Default: `sysdig-agent`. Confirm with user. Created automatically by Helm
(`--create-namespace`).

### 4f. Proxy / air-gap

```
Does the cluster use an HTTP proxy or pull images from a private registry?
→ No / HTTP/HTTPS proxy / Private registry (air-gap)
```

If proxy: gather `http_proxy`, `https_proxy`, `no_proxy` values.
If air-gap: gather private registry URL.

### 4g. Custom CA certificates

```
Does the cluster need custom CA certificates for outbound TLS?
→ No / Yes (provide PEM certificate)
```

---

## 5. Feature Reference

All features are configured under `features.*` in `values.yaml`.

### 5.1 Feature Table

| Feature | Component | Values Path | Default | Description |
|---------|-----------|-------------|---------|-------------|
| **Kubernetes Metadata** | Cluster | `features.kubernetes_metadata.enabled` | `true` | Cluster visibility in Sysdig UI (always on) |
| **K8s Audit Logging** | Cluster | `features.detections.kubernetes_audit.enabled` | `false` | API server audit trail for threat detection |
| **Admission Control** | Cluster | `features.admission_control.enabled` | `false` | Block non-compliant deployments |
| **Cluster Posture (KSPM)** | Cluster | `features.posture.cluster_posture.enabled` | `false` | CIS benchmark compliance scanning |
| **Container Vuln Scanning** | Cluster | `features.vulnerability_management.container_vulnerability_management.enabled` | `false` | Scan running container images |
| **Drift Control** | Host | `features.detections.drift_control.enabled` | `false` | Detect filesystem changes in running containers |
| **Malware Control** | Host | `features.detections.malware_control.enabled` | `false` | Detect known malware in containers |
| **File Integrity Monitoring** | Host | `features.detections.file_integrity_monitoring.enabled` | `false` | Monitor critical file changes on hosts |
| **Host Posture** | Host | `features.posture.host_posture.enabled` | `false` | Host-level CIS benchmarks |
| **Host Vuln Scanning** | Host | `features.vulnerability_management.host_vulnerability_management.enabled` | `false` | Scan host OS packages for vulnerabilities |
| **Activity Audit** | Host | `features.investigations.activity_audit.enabled` | `false` | Audit trail of container/host activity |
| **Live Logs** | Host | `features.investigations.live_logs.enabled` | `false` | Stream container logs in Sysdig UI |
| **Network Security** | Host | `features.investigations.network_security.enabled` | `false` | Network policy generation and enforcement |
| **Captures** | Host | `features.investigations.captures.enabled` | `false` | System call capture for forensics |
| **Rapid Response** | Host | `features.respond.rapid_response.enabled` | `false` | Live container investigation shell |
| **Response Actions** | Host | `features.respond.response_actions.enabled` | `false` | Automated response to threats |

### 5.2 Profile → Feature Mapping

| Feature | Detect & Respond | Posture & Compliance | Full Protection |
|---------|:---:|:---:|:---:|
| kubernetes_metadata | Yes | Yes | Yes |
| kubernetes_audit | Yes | — | Yes |
| drift_control | Yes | — | Yes |
| activity_audit | Yes | — | Yes |
| cluster_posture | — | Yes | Yes |
| host_posture | — | Yes | Yes |
| admission_control | — | Yes | Yes |
| container_vulnerability_management | — | — | Yes |
| host_vulnerability_management | — | — | Yes |
| malware_control | — | — | Yes |
| file_integrity_monitoring | — | — | Yes |
| network_security | — | — | Yes |
| live_logs | — | — | Yes |
| rapid_response + response_actions | — | — | Yes |
| captures | — | — | Yes |

---

## 6. Helm Installation

### Add the Sysdig Helm repository

```bash
helm repo add sysdig https://charts.sysdig.com
helm repo update
```

### Install

```bash
helm upgrade --install --create-namespace \
  -n sysdig-agent \
  -f values.yaml \
  sysdig sysdig/shield
```

> **Note:** For automatic rollback on failure, use `--atomic` (Helm 3.x)
> or `--rollback-on-failure` (Helm 4.x, where `--atomic` was removed).

### Upgrade (after editing values.yaml)

```bash
helm upgrade sysdig sysdig/shield \
  -n sysdig-agent \
  -f values.yaml
```

### Uninstall

```bash
helm uninstall sysdig -n sysdig-agent
```

### Post-Installation Verification

Run these checks **proactively** after `helm install` completes. Wait ~30
seconds before starting (pods need time to pull images and start).

#### Check 1 — Pod status

```bash
kubectl get pods -n sysdig-agent
```

**Expected:** All pods `Running`, no `CrashLoopBackOff` / `Init:Error` /
`ImagePullBackOff`. If not ready yet, retry up to 3 times at 30s intervals.

#### Check 2 — DaemonSet coverage

```bash
kubectl get ds -n sysdig-agent
```

**Expected:** `DESIRED == READY` (one Host Shield pod per schedulable node).
If `READY < DESIRED`, identify which nodes are missing pods.

> **Note:** On GKE Autopilot and EKS Fargate, the Host Shield DaemonSet may
> not run (or run with limited features). Skip checks 2, 3, and 5 for these
> distributions — only the cluster component pods need to be verified.

#### Check 3 — Agent authentication

```bash
kubectl logs -n sysdig-agent -l sysdig/component=host -c sysdig-host-shield --tail=50
```

**Look for:**
- `Sent msgtype=1 (METRICS) to collector` → **PASS** — agent authenticated,
  sending data to Sysdig.
- `ERR_INVALID_CUSTOMER_KEY` → **FAIL** — wrong credential. The Shield chart
  needs the **Agent Access Key** (Settings → Agent Keys), NOT the Secure API
  Token. They look similar but are different values.

If no metrics line appears, wait 30s and retry — the agent needs ~60s to
establish its first connection.

#### Check 4 — Backend connectivity

```bash
kubectl logs -n sysdig-agent -l sysdig/component=cluster --tail=50
```

**Look for:**
- `handshake exchanged successfully` → **PASS** — connected to Sysdig backend.
- `component ready` (kubernetes-metadata) → **PASS** — metadata flowing.
- `loaded N rules` (audit group) → **PASS** — audit rules active.
- Connection refused / timeout → **FAIL** — check region setting, proxy
  config, or firewall rules blocking port 443.

#### Check 5 — Driver health (if Host Shield pods fail)

Only needed if Host Shield pods are in `Init:CrashLoopBackOff`:

```bash
kubectl logs -n sysdig-agent <host-pod> -c sysdig-host-shield-kmodule --tail=20
```

**Look for:**
- `Kernel headers not found` or `Cannot load the probe` → kmod driver cannot
  compile or find a prebuilt module. **Fix:** set `host.driver: universal_ebpf`
  in `values.yaml` and run `helm upgrade`. This is expected on GKE (COS),
  Bottlerocket, Flatcar, and other immutable OS.

#### Verification summary

| Check | Command | Pass criteria |
|-------|---------|---------------|
| Pod status | `kubectl get pods -n sysdig-agent` | All Running |
| DaemonSet | `kubectl get ds -n sysdig-agent` | DESIRED == READY |
| Agent auth | Host Shield logs | `Sent msgtype=1 (METRICS)` present, no `ERR_INVALID_CUSTOMER_KEY` |
| Backend | Shield cluster logs | `handshake exchanged successfully` present |
| Driver | Host Shield init logs | No `Cannot load the probe` errors |

---

## 7. Values Configuration

Generate values from the template `templates/shield-values.yaml`,
replacing `{{PLACEHOLDER}}` markers with actual values.

### 7.1 Cluster identity

```yaml
cluster_config:
  name: "my-cluster"          # Shown in Sysdig UI
  cluster_type: generic       # generic | gke-autopilot
```

### 7.2 Sysdig connection

```yaml
sysdig_endpoint:
  region: us1                 # Named region auto-configures collector/API
  access_key: "REPLACE_WITH_YOUR_SYSDIG_AGENT_ACCESS_KEY"
```

**Region shorthand** (`us1`, `us2`, `us4`, `eu1`, `eu2`, `au1`, `in1`, `me2`)
auto-configures the collector host and API URL. No manual `collector.host` or
`api_url` needed for SaaS deployments. For on-prem, set `region: custom` and
provide `api_url` and `collector.host`/`collector.port` explicitly.

### 7.3 Features

All under `features.*`. See the Feature Reference table (§5) for the full list.
Each feature is `enabled: true` or `enabled: false`.

### 7.4 Host Shield driver

```yaml
host:
  driver: universal_ebpf      # kmod | universal_ebpf | legacy_ebpf
  privileged: true             # Required for posture and vuln mgmt
```

### 7.5 Proxy

```yaml
proxy:
  http_proxy: "http://proxy.example.com:3128"
  https_proxy: "http://proxy.example.com:3128"
  no_proxy: "localhost,127.0.0.1,10.0.0.0/8"
```

### 7.6 Custom CA

```yaml
ssl:
  verify: true
  ca:
    certs:
      - |
        -----BEGIN CERTIFICATE-----
        ...
        -----END CERTIFICATE-----
```

### 7.7 Air-gap / private registry

The Shield chart pulls images from `quay.io/sysdig/`. For air-gapped clusters,
override image registries:

```yaml
host:
  image:
    registry: "registry.internal.example.com"
cluster:
  image:
    registry: "registry.internal.example.com"
```

Mirror the required images before installing.

---

## 8. Distribution-Specific Notes

### GKE (Container-Optimized OS)

GKE standard nodes use Container-Optimized OS (COS), which has **no kernel
headers and no precompiled kmod probes**. The `kmod` driver will fail with:

```
Kernel headers not found in /host/lib/modules/6.x.x+/build
Download of sysdigcloud-probe failed (404)
Cannot load the probe
```

**Fix:** Set `host.driver: universal_ebpf`. This uses CO-RE eBPF which does not
require kernel headers. The interview should auto-select this for GKE.

### GKE Autopilot

Autopilot restricts privileged containers and host access:

```yaml
cluster_config:
  cluster_type: gke-autopilot
host:
  driver: universal_ebpf
  privileged: false
```

Host Shield features that require privileged mode (posture, vulnerability
management) will not work on Autopilot.

### OpenShift 4.x

May require Security Context Constraints (SCC). The chart creates its own
RBAC. If pods fail to schedule, check SCC:

```bash
oc get scc | grep sysdig
```

### EKS with Fargate

Fargate pods run in isolated micro-VMs with no host access. Host Shield
(DaemonSet) pods will **not be scheduled on Fargate nodes** — this is expected.
Shield (Deployment) works normally. If the cluster has mixed node
groups (EC2 + Fargate), Host Shield runs only on EC2 nodes.

### k3s / RKE2

Usually works with default settings. If the containerd socket is at a
non-standard path, override via:

```yaml
host:
  additional_settings:
    cri:
      socket_path: /run/k3s/containerd/containerd.sock
```

---

## 9. Troubleshooting

### Host Shield pods in `Init:CrashLoopBackOff`

**Symptom:** Host Shield DaemonSet pods fail in the init container
(`sysdig-host-shield-kmodule`).

**Cause:** The `kmod` driver cannot compile or find a precompiled kernel module
for the node's kernel version. Common on COS, Bottlerocket, Flatcar, and other
immutable OS.

**Fix:** Change the driver to `universal_ebpf`:
```yaml
host:
  driver: universal_ebpf
```
Then: `helm upgrade sysdig sysdig/shield -n sysdig-agent -f values.yaml`

---

### `ERR_INVALID_CUSTOMER_KEY` in logs

**Symptom:** Host Shield logs show:
```
Received error message: ERR_INVALID_CUSTOMER_KEY (Unauthorized agent access key)
```

**Cause:** The `sysdig_endpoint.access_key` contains the wrong credential.
This is the **Agent Access Key** (Settings → Agent Keys), NOT the Secure API
Token (Settings → API Token). They are different values.

**Fix:** Replace `access_key` in `values.yaml` with the correct Agent Access
Key and run `helm upgrade`.

---

### Pods stuck in `ImagePullBackOff`

**Symptom:** Pods cannot pull Sysdig images from `quay.io`.

**Fixes:**
1. **Proxy:** Ensure `proxy.https_proxy` is configured if outbound access
   requires a proxy.
2. **Air-gap:** Override image registries (see §7.7) and mirror images.
3. **Pull secret:** Create and reference an image pull secret:
   ```yaml
   host:
     image:
       pull_secrets:
         - name: sysdig-pull-secret
   cluster:
     image:
       pull_secrets:
         - name: sysdig-pull-secret
   ```

---

### Admission controller blocking deployments

**Symptom:** `kubectl apply` fails with a webhook admission error.

**Fixes:**
1. **Check pod health:** `kubectl get pods -n sysdig-agent -l sysdig/component=cluster`
2. **Disable dry_run:** If using `dry_run: true` (default), the controller only
   logs but doesn't block. Set `dry_run: false` to enforce.
3. **Emergency bypass:**
   ```bash
   kubectl delete validatingwebhookconfiguration sysdig-shield-cluster
   ```
   Re-enable with `helm upgrade`.

---

### Cluster not appearing in Sysdig UI

**Symptom:** Pods are running but the cluster doesn't show in Sysdig.

**Checks:**
1. Verify the access key is correct (see `ERR_INVALID_CUSTOMER_KEY` above)
2. Verify region matches your Sysdig account (wrong region = data goes nowhere)
3. Check Shield cluster component logs:
   ```bash
   kubectl logs -n sysdig-agent -l sysdig/component=cluster --tail=50
   ```
4. Allow up to 10 minutes for initial appearance
5. Verify outbound connectivity to the collector:
   ```bash
   kubectl exec -n sysdig-agent deployment/sysdig-shield-cluster -- \
     wget -qO- --timeout=5 https://collector.sysdigcloud.com/healthz || echo "UNREACHABLE"
   ```

---

### Pods `Evicted` / `DiskPressure` on nodes

**Symptom:** Dozens of Shield pods in `Evicted` state. New pods stay `Pending`
with message: `node(s) had untolerated taint {node.kubernetes.io/disk-pressure}`.

**Cause:** Shield images total ~1.5 GB. Nodes with small disks (< 10 GB
ephemeral storage) run out of space when pulling images, triggering kubelet
`DiskPressure`. Once tainted, no new pods can schedule.

**Fixes:**
1. **Use larger nodes** — ensure at least 10 GB ephemeral storage per node.
2. **Clean up disk** — remove unused images on affected nodes:
   ```bash
   # On the node (via SSH or node shell):
   crictl rmi --prune
   ```
3. **Pre-pull images** — on constrained clusters, pre-pull Shield images
   during a maintenance window before installing the Helm chart.
4. **Check node disk** from kubectl:
   ```bash
   kubectl describe nodes | grep -A 3 "Conditions:" | grep DiskPressure
   ```

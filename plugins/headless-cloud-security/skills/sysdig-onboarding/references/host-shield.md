# Linux Host Onboarding Reference (Host Shield)

## Table of Contents

1. [Overview](#1-overview)
2. [Prerequisites](#2-prerequisites)
3. [Supported Platforms](#3-supported-platforms)
4. [Interview Questions](#4-interview-questions)
5. [Feature Reference](#5-feature-reference)
6. [Installation Methods](#6-installation-methods)
7. [Configuration](#7-configuration)
8. [Post-Install Verification](#8-post-install-verification)
9. [Troubleshooting](#9-troubleshooting)

---

## 1. Overview

Host Shield installs the Sysdig agent on standalone Linux servers (outside
Kubernetes) for runtime security, vulnerability management, and compliance.

Two components run on the host:

- **Agent Runtime** (`dragent` service) — syscall-level monitoring via a kernel
  module or eBPF probe. Provides runtime threat detection, drift control,
  malware control, activity audit, captures, and response actions.
- **Host Shield** — posture analysis, host vulnerability scanning, container
  vulnerability scanning (for non-orchestrated containers), and in-use package
  detection.

Both are installed via a single package (`draios-agent`) and configured through
a YAML file at `/opt/draios/etc/dragent.yaml`.

> **Agent Access Key, not API Token:** Host Shield requires the **Agent Access
> Key** (`sysdig_endpoint.access_key`), found in Sysdig UI → **Settings →
> Agent Keys**. This is different from the Secure API Token used for cloud
> account onboarding.

---

## 2. Prerequisites

| Requirement | Minimum / Notes |
|-------------|----------------|
| Linux kernel | 3.10+ (for eBPF); kernel headers for kmod driver |
| Root / sudo | Required for installation and service management |
| Outbound port | 6443 to Sysdig collector (or 443 with `-alt` region) |
| Sysdig Agent Access Key | From Sysdig UI → Settings → Agent Keys |
| CPU architectures | x86_64, ARM64 |
| Disk | ~500 MB for agent + probe assets |

### Driver types

| Driver | When to use |
|--------|------------|
| `kmod` (default) | Standard Linux with kernel headers available |
| `universal_ebpf` | Immutable/container-optimized OS, no kernel headers |
| `legacy_ebpf` | Older kernels without CO-RE support |

---

## 3. Supported Platforms

| Distribution | Architectures | Notes |
|---|---|---|
| Debian / Ubuntu | x86_64, ARM64 | |
| CentOS / RHEL / Fedora | x86_64, ARM64 | |
| Amazon Linux 2 / 2023 | x86_64, ARM64 | |
| SLES | x86_64 | `zypper`, not `yum` — use §6.2b |
| Alpine | x86_64 | Docker container method only |

---

## 4. Interview Questions

When onboarding a Linux host, gather the following. Skip questions when
answers can be auto-detected.

### 4a. Distribution detection

Auto-detect from the host:

```bash
cat /etc/os-release 2>/dev/null || cat /etc/redhat-release 2>/dev/null
uname -m
```

Confirm the detected distro and architecture with the user.

### 4b. Install method

```json
{
  "question": "How do you want to install the Sysdig agent?",
  "header": "Install",
  "multiSelect": false,
  "options": [
    {"label": "Package manager", "description": "DEB or RPM package — recommended for servers with direct internet access"},
    {"label": "Docker container", "description": "Privileged container — for hosts where native packages are not practical"}
  ]
}
```

Auto-select based on distro: Debian/Ubuntu → DEB (§6.1),
CentOS/RHEL/Fedora/Amazon → RPM via yum/dnf (§6.2), SLES → RPM via
**zypper** (§6.2b — the yum commands do not exist there).
If Docker is detected but no distro, default to Docker container method.

### 4c. Feature profile

Instead of asking about 12+ individual toggles, offer profiles:

```json
{
  "question": "Which security profile do you want to start with?",
  "header": "Profile",
  "multiSelect": false,
  "options": [
    {"label": "Detect & Respond", "description": "Runtime threat detection, drift control, activity audit, response actions"},
    {"label": "Posture & Compliance", "description": "Host posture (CIS benchmarks), host vulnerability scanning"},
    {"label": "Full Protection", "description": "All of the above plus malware control, captures, container VM, in-use detection"},
    {"label": "Custom", "description": "Pick individual features from the full list"}
  ]
}
```

If **Custom**, walk through each feature from the Feature Reference table (§5).

### 4c-ii. Post-selection: mention available features

After the user confirms their profile, briefly mention what else is available:

> **Good to know:** Beyond what we're enabling now, Host Shield also supports
> malware detection, file integrity monitoring, ML-based policies, forensic
> captures, and rapid response shells. You can enable any of these later by
> editing the config and restarting the agent — no reinstall needed.

### 4d. Proxy / air-gap

```json
{
  "question": "Does the host use an HTTP proxy or need to pull images from a private registry?",
  "header": "Proxy",
  "multiSelect": false,
  "options": [
    {"label": "No", "description": "Direct internet access"},
    {"label": "HTTP/HTTPS proxy", "description": "Provide proxy URL(s)"},
    {"label": "Air-gap", "description": "No internet — provide private registry URL"}
  ]
}
```

If proxy: gather `http_proxy`, `https_proxy`, `no_proxy` values.

---

## 5. Feature Reference

All features are configured under `features.*` in the Host Shield config.

### 5.1 Feature Table

| Feature | Config Path | Default | Description |
|---------|-------------|---------|-------------|
| **Syscall Detections (RTD)** | `features.detections.syscall_detections.enabled` | `true` | Falco-based runtime threat detection |
| **DNS Detection** | `features.detections.dns_detection.enabled` | `false` | DNS-based threat detection |
| **Drift Control** | `features.detections.drift_control.enabled` | `false` | Detect filesystem changes in containers |
| **Malware Control** | `features.detections.malware_control.enabled` | `false` | Detect known malware |
| **ML Policies** | `features.detections.ml_policies.enabled` | `false` | Machine learning-based anomaly detection |
| **Hash Detection** | `features.detections.hash_detection.enabled` | `false` | Hash-based file detection |
| **Activity Audit** | `features.investigations.activity_audit.enabled` | `false` | Audit trail of host/container activity |
| **Captures** | `features.investigations.captures.enabled` | `false` | System call capture for forensics |
| **Live Logs** | `features.investigations.live_logs.enabled` | `false` | Stream container logs in Sysdig UI |
| **Network Security** | `features.investigations.network_security.enabled` | `false` | Network policy generation |
| **Event Forwarder** | `features.investigations.event_forwarder.enabled` | `false` | Forward events to SIEM integrations |
| **Host Posture** | `features.posture.host_posture.enabled` | `false` | CIS benchmark compliance scanning |
| **Rapid Response** | `features.respond.rapid_response.enabled` | `false` | Live investigation shell |
| **Response Actions** | `features.respond.response_actions.enabled` **+** per-action `trigger` | `false` | Automated response (kill, quarantine). The trigger map alone arms nothing — see §5.1c |
| **Host Vuln Scanning** | `features.vulnerability_management.host_vulnerability_management.enabled` | `false` | Scan OS packages for CVEs |
| **Container Vuln Scanning** | `features.vulnerability_management.container_vulnerability_management.enabled` | `false` | Scan non-orchestrated container images |
| **In-Use Detection** | `features.vulnerability_management.in_use.enabled` | `true` | Detect actively used vulnerable packages |

### 5.1b Which key the agent runtime actually reads

🔴 **Emit the nested `features.*` tree ONLY. Never also emit the flat
top-level spelling of the same feature — the agent rejects the pair and
crash-loops.** The runtime treats the flat and nested spellings as *alternate
keys*: if both are present it fails to start with

```
Failed to init configuration. Exception message: live_logs.enabled and
features.investigations.live_logs.enabled are alternate keys but exist in the
same yaml file
```

(exit 70, continuous restart). So "emit both forms, unknown keys are ignored" is
**wrong** for these keys: the duplicate is fatal, not ignored.

The nested tree alone is honoured. A nested-only config produces a feature
manager summary (§8 Check 6) that lists selected capabilities as `Enabled` —
`drift control`, `malware control`, `secure audit`, `network topology`,
`live logs`, host posture, vulnerability management, and `response actions`
(given its `enabled` key, §5.1c) — so the nested `features.detections.*` /
`features.investigations.*` keys are read, not inert.

`captures` is honoured from the nested key too: setting
`features.investigations.captures.enabled` drives the agent's capture capability
(it toggles the `memdump` capability in the §8 Check 6 summary — `Enabled` when
the nested key is `true`, `Disabled` when `false`). The separate on-demand
`sysdig_capture_enabled` scalar is not something this template sets.

For reference only — these are the flat spellings the Shield chart would write
on Kubernetes. **Do not put them in the host `dragent.yaml`; they collide with
the nested tree above.**

| Feature | Nested (emit this) | Flat spelling (do NOT also emit) |
|---|---|---|
| Drift Control | `features.detections.drift_control.enabled` | `drift_control.enabled` |
| Malware Control | `features.detections.malware_control.enabled` | `malware_control.enabled` |
| Activity Audit | `features.investigations.activity_audit.enabled` | `secure_audit_streams.enabled` |
| Captures | `features.investigations.captures.enabled` | `sysdig_capture_enabled` (scalar bool) |
| Live Logs | `features.investigations.live_logs.enabled` | `live_logs.enabled` |
| Event Forwarder | `features.investigations.event_forwarder.enabled` | `local_forwarder.enabled` |
| Network Security | `features.investigations.network_security.enabled` | `network_topology.enabled` |

> **Do not read "capability X showed Enabled" as proof the config key worked.**
> The backend can enable a capability by policy regardless of the file — an
> observed run had the agent enable `hash_detection` while the config said
> `enabled: false`. Only a capability that is **off** by default and **on** after
> your change proves the key was read.

> **`feature.mode` can override these keys.** The agent's mode selector resolves
> the final feature state, and its per-mode presets set exactly these keys — so a
> host whose base `dragent.yaml` already carries a `feature.mode` may have the
> nested `enabled` values here overridden. This skill does not emit `feature.mode`
> and the interaction is unverified; if a selected capability reads the wrong
> state in the §8 Check 6 summary, capture `feature.mode` from the config
> alongside the summary block.

### 5.1c Response actions need an explicit `enabled`

The per-action trigger map does **not** arm the feature:

```yaml
features:
  respond:
    response_actions:
      enabled: true          # ← without this the whole feature is false
      kill_process:
        trigger: all
```

Omit `enabled` and the agent reports `response actions: Disabled` while every
config check passes — no `Critical`, no `Config file error at key:`, no "is
enabled but … is not set". The user consented to remote kill/quarantine when
they chose the profile, so treat a missing `enabled` as a correctness bug, not
a nicety. Verify it via the feature summary (§8 Check 6), never by the presence
of the trigger map.

Actions the config file maps: `kill_process`, `kill_container`,
`start_container`, `stop_container`, `pause_container`, `unpause_container`,
`file_quarantine` (+ `quarantine_path`), `file_unquarantine`, `file_acquire`.
Alongside `enabled`, the feature also accepts `queue_length`, `timeout` and
`host`.

### 5.2 Profile → Feature Mapping

| Feature | Detect & Respond | Posture & Compliance | Full Protection |
|---------|:---:|:---:|:---:|
| syscall_detections | Yes | — | Yes |
| drift_control | Yes | — | Yes |
| activity_audit | Yes | — | Yes |
| response_actions | Yes | — | Yes |
| host_posture | — | Yes | Yes |
| host_vulnerability_management | — | Yes | Yes |
| malware_control | — | — | Yes |
| captures | — | — | Yes |
| container_vulnerability_management | — | — | Yes |
| in_use | — | — | Yes |
| dns_detection | — | — | Yes |
| ml_policies | — | — | Yes |
| live_logs | — | — | — |
| network_security | — | — | — |
| event_forwarder | — | — | — |
| hash_detection | — | — | — |
| rapid_response | — | — | — |

**A feature with no `Yes` in its row is `false` in that profile — including the
rows that are `—` everywhere.** Never guess a value for a feature this table
does not enable: set its nested `enabled` to `false`. Guessing `true` for
`live_logs` would grant remote log streaming the user never selected. Under the
**Custom** profile the value is whatever the user explicitly picked, in the
nested tree only (§5.1b — never emit the flat spelling alongside it).

These profile-varying runtime switches ship as `{{..._ENABLED}}` placeholders
in the nested tree — `drift_control` (`{{DRIFT_CONTROL_ENABLED}}`),
`malware_control` (`{{MALWARE_CONTROL_ENABLED}}`), `activity_audit`
(`{{ACTIVITY_AUDIT_ENABLED}}`), `captures` (`{{CAPTURES_ENABLED}}`), `live_logs`
(`{{LIVE_LOGS_ENABLED}}`), `network_security` (`{{NETWORK_SECURITY_ENABLED}}`),
and `response_actions` (`{{RESPONSE_ACTIONS_ENABLED}}`).
Resolve each to `true`/`false` from its column above; `lint_config.sh` errors on
any left unresolved, so a switch you forget fails lint rather than shipping a
value nobody chose. **`response_actions` is a placeholder because it arms remote
kill/quarantine — a Posture & Compliance profile (where §5.2 marks it `—`) must
resolve it `false` so those destructive actions are not armed on a host that
never opted in.** (For the three named profiles `live_logs` and
`network_security` are always `false`; they are placeholders for the Custom
profile.) Every other feature carries a fixed value in the template.

`event_forwarder` / `local_forwarder.enabled` is **pinned to `false`** in the
template, Custom included, until the skill also generates the forwarder's own
config: on the non-Helm path `local_forwarder.enabled: true` needs a separate
`local_forwarder_config.yaml`, and without it the agent logs `is enabled but …
is not set` ⇒ Check 5 FAIL. Offer it as a manual follow-up, not a toggle.

---

## 6. Installation Methods

### 6.1 DEB Package (Debian / Ubuntu)

```bash
curl -s https://download.sysdig.com/DRAIOS-GPG-KEY.public \
  -o /usr/share/keyrings/sysdig-keyring.asc
echo "deb [signed-by=/usr/share/keyrings/sysdig-keyring.asc] https://download.sysdig.com/stable/deb stable-$(dpkg --print-architecture)/" \
  > /etc/apt/sources.list.d/sysdig.list
apt-get update
# only needed for kmod / legacy_ebpf — if unavailable see §6.2c
apt-get install -y linux-headers-$(uname -r)
apt-get install -y draios-agent
```

### 6.2 RPM Package (CentOS / RHEL / Fedora / Amazon Linux)

```bash
rpm --import https://download.sysdig.com/DRAIOS-GPG-KEY.public
curl -s -o /etc/yum.repos.d/draios.repo https://download.sysdig.com/stable/rpm/draios.repo
# only needed for kmod / legacy_ebpf — if unavailable see §6.2c
yum install -y dkms kernel-devel-$(uname -r)
yum install -y draios-agent
```

`dnf` is a drop-in replacement for `yum` on Fedora, RHEL 8+ and Amazon Linux
2023 (Amazon Linux 2 has `yum` only). The `kmod` driver additionally needs
`dkms`, which is in EPEL on RHEL if the base repos do not carry it:
`yum install -y https://dl.fedoraproject.org/pub/epel/epel-release-latest-<major>.noarch.rpm`.
`kernel-devel` itself comes from BaseOS — EPEL will **not** fix a missing one
(that is the running-kernel/repo mismatch in §6.2c).

🔴 **`dkms` must be installed *before* the agent, and it is not preinstalled on
Amazon Linux 2023.** The `draios-agent-kmodule` package builds the driver from a
`%post` scriptlet that shells out to `dkms`; without it the scriptlet fails
while the package manager still reports overall success:

```
/var/tmp/rpm-tmp.XXXXXX: line 2: dkms: command not found
warning: %post(draios-agent-kmodule-14.7.2-1.x86_64) scriptlet failed, exit status 127
Error in POSTIN scriptlet in rpm package draios-agent-kmodule
```

The agent then runs with no syscall source. Recovery on a host where this
already happened:

```bash
dnf install -y dkms
dnf reinstall -y draios-agent-kmodule
systemctl restart dragent
```

Always confirm the driver actually loaded afterwards (§8 Check 1b) — a failed
kmodule build is invisible to the service, auth and connectivity checks.

### 6.2b SLES (zypper)

SUSE has no `yum`, and `zypper` reads repositories from `/etc/zypp/repos.d/`,
not `/etc/yum.repos.d/` — the §6.2 command block does **not** work here. The
kernel headers package is also named per kernel flavor
(`kernel-default-devel`, `kernel-azure-devel`, `kernel-rt-devel`, …), not
`kernel-devel`, and must be pinned to the running kernel the same way §6.2
pins `kernel-devel-$(uname -r)`:

```bash
rpm --import https://download.sysdig.com/DRAIOS-GPG-KEY.public
zypper addrepo --refresh https://download.sysdig.com/stable/rpm/draios.repo
zypper --non-interactive refresh
# only needed for kmod / legacy_ebpf — if unavailable see §6.2c
KREL="$(uname -r)"          # e.g. 5.14.21-150500.55.83-default
zypper --non-interactive install "kernel-${KREL##*-}-devel-${KREL%-*}"
zypper --non-interactive install draios-agent
```

> **Derived, not published.** Sysdig's package-install page lists SUSE Linux
> Enterprise Server as supported but documents `apt` and `yum` commands only —
> there is no published zypper path. The block above is the SUSE equivalent of
> §6.2, and is unverified against a live SLES host until an rpm e2e covers it.
> If `zypper install draios-agent` cannot resolve the repo, verify
> `/etc/zypp/repos.d/draios.repo` and fall back to the Docker method (§6.3).

### 6.2c Kernel headers are conditional — do not let this block the install

The header/devel package is needed **only** for the `kmod` and `legacy_ebpf`
drivers. It is routinely unavailable for the running kernel (the repos carry
headers for the *current* kernel, not the one an unpatched host booted), which
looks like:

```
No package kernel-devel-<version> available          # yum / dnf
E: Unable to locate package linux-headers-<version>  # apt
```

Two ways forward, in order of preference:

1. **Switch the driver to `universal_ebpf`** — no headers, no compilation,
   requires kernel 5.8+. On a package install the driver is chosen by the
   **service environment file**, not by `dragent.yaml`, so set **both**:

   ```bash
   # /etc/default/dragent (DEB) or /etc/sysconfig/dragent (RPM)
   SYSDIG_AGENT_DRIVER=universal_ebpf
   ```

   plus `system.driver_type: universal_ebpf` in the config (§7.4) so the file
   alone still describes the install, then `systemctl restart dragent`. This is
   the recommended driver on 5.8+ anyway, and the only option on immutable /
   container-optimized OS.
2. Update the kernel, reboot into it, then install the matching headers.

Do not report the header failure as an onboarding failure — pick option 1,
regenerate the config with the new driver, and continue.

### 6.3 Docker Container

Use when native packages are not practical. Requires privileged mode and host
namespaces. Uses the Universal eBPF driver (no kernel module needed, requires
kernel 5.8+).

**The container is configured by the same `dragent.yaml` the package installs
use** — generated from `templates/host-shield.yaml`, placed on the host, and
bind-mounted read-only. Do **not** configure it through `-e ACCESS_KEY` /
`-e COLLECTOR`:

- An env var on `docker run` is readable by anyone who can call `docker
  inspect` (or the Docker API), and it lands in shell history — the skill never
  puts a real credential on a command line.
- Those two env vars carry nothing but the key and collector. There is no env
  form of the `features.*` tree, so an env-only container **cannot deliver the
  feature profile the user selected** (no posture, no vulnerability management)
  and never receives the mandatory `api_url` (§7.2).

**Step 1 — place the config on the host** (any host path; `/opt/sysdig` below):

```bash
mkdir -p /opt/sysdig
install -m 600 dragent.yaml /opt/sysdig/dragent.yaml
```

The user then fills the Agent Access Key into
`/opt/sysdig/dragent.yaml` by editing that file — the same rule as the package
path (§7.1) and as `values.yaml` on Kubernetes.

**Step 2 — run the container:**

```bash
docker run -d --name sysdig-agent \
  --restart always \
  --privileged --net host --pid host \
  -e SYSDIG_AGENT_DRIVER=universal_ebpf \
  -v /opt/sysdig/dragent.yaml:/opt/draios/etc/dragent.yaml:ro \
  -v /var/run/docker.sock:/var/run/docker.sock \
  -v /proc:/host/proc:ro \
  -v /sys/kernel/debug:/sys/kernel/debug:ro \
  --shm-size=512m \
  quay.io/sysdig/agent-slim
```

`SYSDIG_AGENT_DRIVER` stays an env var — it is read by the image entrypoint,
not by the agent config parser. Set `system.driver_type: universal_ebpf` in the
mounted file as well (§7.4) so the file alone describes the install.

🔴 **With the config generated above — which does not set
`host_scanner.host_fs_mount_path` — the Docker socket must be mounted at the
container-internal default, `/var/run/docker.sock`, not under `/host`.** The
container-vulnerability component (`host-scanner`) then connects to
`unix:///var/run/docker.sock` *inside* the container and does not read
`system.runtimes.docker[].socket` from the config file. Mounted only at
`/host/var/run/docker.sock`, it fails fatally:

```
host-scanner: failed to connect to the docker API at unix:///var/run/docker.sock: no such file or directory
host-scanner: {"level":"fatal","message":"application encountered an unrecoverable error"}
```

**A fatal in any agent subprocess terminates the whole agent**, which
`--restart always` then restarts — so a mis-mounted socket does not degrade one
feature, it presents as a container that restarts every ~2 seconds while
`docker ps` still reports `healthy` (§8, Docker liveness). The log shows
repeated `Sent msgtype=10 (DIRTY_SHUTDOWN_REPORT)` from changing PIDs and no
`Sent msgtype=1 (METRICS)` at all.

> **Why this differs from the published container example — `host_scanner.host_fs_mount_path`
> and the socket path are a matched pair.** Sysdig's container example mounts the
> socket at `/host/var/run/docker.sock` *and* sets
> `host_scanner.host_fs_mount_path: /host`. That key tells `host-scanner` where
> the host filesystem is mounted inside the container: with it set the scanner
> prefixes every host path — the Docker socket included — with `/host`; with it
> unset it resolves container-internal paths. The config *source* is irrelevant
> here (the entrypoint merges `ADDITIONAL_CONF` into the same `dragent.yaml`) —
> only the key decides. **Use one row whole, never one value from each:**
>
> | `host_scanner.host_fs_mount_path` | Socket mount | Host VM scans |
> |---|---|---|
> | unset | `-v /var/run/docker.sock:/var/run/docker.sock` | the **container's** filesystem — wrong inventory |
> | `/host` (+ `-v /:/host:ro`) | `-v /var/run/docker.sock:/host/var/run/docker.sock` | the host filesystem |
>
> Mixing them — the `/host` socket mount with the key unset — is the crash loop
> above, observed on a live Docker install.

🔴 **Docker + host vulnerability management requires the second row.** The
template does not emit `host_scanner.host_fs_mount_path`, which is correct for
the package path (the host root *is* `/`) but leaves the container path scanning
its own filesystem — a silent wrong-inventory failure in the same class as the
`api_url` warning in §7.2, not a crash. When the user selects **host
vulnerability management** on the Docker method, add to the generated config:

```yaml
host_scanner:
  host_fs_mount_path: /host
kspm_analyzer:
  host_root: /host          # explicit; the image also defaults SYSDIG_HOST_ROOT=/host
```

and then mount the socket under `/host` to keep the pair intact:

```bash
  -v /:/host:ro \
  -v /var/run/docker.sock:/host/var/run/docker.sock \
```

Runtime detection, drift, malware, activity audit and response actions are
unaffected by this key — a Docker install *without* host vulnerability
management stays on the first row (the command in Step 2 above).

**How to tell which filesystem was scanned** (there is no log line for it):
compare the package inventory Sysdig reports for the host against the host's own
package list —

```bash
dpkg -l | grep -c '^ii'      # Debian/Ubuntu host
rpm -qa | wc -l              # RPM host
```

A host scan reports the same order of magnitude and includes host-only packages
(kernel, `openssh-server`, the distro's init). A container-root scan reports the
agent image's short list instead, with no kernel package at all — that is the
signature of a missing `host_fs_mount_path` on the Docker method.

#### Mounts are a function of the selected features

The four mounts above are the **runtime-detection minimum**. They do not
support posture or host vulnerability management: the posture analyzer
(`kspm-analyzer`) `chroot`s into the host filesystem, and without it every host
check degrades silently —

```
kspm-analyzer: could not verify if bash is installed on host, assuming it is not installed
  error: status 127: err chroot: failed to run command 'sh': No such file or directory
```

Add mounts per the capabilities selected in §4c:

| Selected capability | Additional mounts |
|---|---|
| Host posture (`features.posture.host_posture`) | `-v /:/host:ro` `-v /dev:/host/dev` |
| Host vulnerability management (`features.vulnerability_management.host_vulnerability_management`) | `-v /:/host:ro` `-v /dev:/host/dev` |
| Container vulnerability management on Podman instead of Docker | `-v /run/podman/podman.sock:/run/podman/podman.sock` |

`/:/host:ro` is what the image's own `SYSDIG_HOST_ROOT=/host` default expects;
with it in place the analyzer runs the full host benchmark (and the Docker
benchmark, when the socket is mounted). Emit the union of the base mounts and
every row that applies — never hand the user the minimal list when they
selected posture or vulnerability management.

---

## 7. Configuration

### 7.1 Config File Location

**One config file, both install methods.** Generate it from
`templates/host-shield.yaml`, replace every `{{PLACEHOLDER}}` marker, put it on
the host, and let the agent read it at `/opt/draios/etc/dragent.yaml`:

| Install method | Where the file lives on the host | How the agent sees it |
|---|---|---|
| DEB / RPM (§6.1, §6.2) | `/opt/draios/etc/dragent.yaml` | directly |
| Docker (§6.3) | any path, e.g. `/opt/sysdig/dragent.yaml` | bind-mounted `:ro` onto `/opt/draios/etc/dragent.yaml` |

There is no env-var or `--set`-style configuration path for a host install: if a
setting is not in this file, the agent does not have it. `chmod 600` the file —
it holds the Agent Access Key, which the **user** fills in by editing the file
(never passed on a command line, never pasted in chat).

### 7.2 Sysdig Connection

```yaml
sysdig_endpoint:
  access_key: "{{SYSDIG_ACCESS_KEY}}"
  region: {{SYSDIG_REGION}}
  api_url: {{SYSDIG_API_URL}}       # required — see below
  collector:
    host: {{COLLECTOR_HOST}}
    port: {{COLLECTOR_PORT}}
```

🔴 **`region` alone is not enough on a package install — always emit `api_url`
and `collector` explicitly, SaaS regions included.** The agent runtime
(`dragent`, which parses this file) has no `region` key at all: it ignores the
shorthand, defaults `collector` to `collector.sysdigcloud.com:6443`, and leaves
its API endpoint **empty**. Two consequences, both silent:

- **Host posture is disabled outright** — `dragent.log` shows
  `Error: KSPM Analyzer is enabled but sysdig_api_endpoint is not set.
  Disabling KSPM Analyzer.`
- **Host / container vulnerability scanning has no destination** — the scanner
  logs `host-scanner: request failed: Get "https:///api/team/infrastructure":
  http: no Host in request URL`.

Runtime telemetry keeps flowing over the collector, so the service, auth,
handshake and credential checks all still pass — the user believes posture and
vulnerability scanning are onboarded when they are not. `api_url` is
**required** whenever `features.posture.host_posture` or
`features.vulnerability_management.*` is enabled, and on any region other than
us1 an explicit `collector.host` is required too (the default is the us1
collector).

Resolve all three values from this table:

| Region | Collector | API URL |
|--------|-----------|---------|
| us1 | collector.sysdigcloud.com | https://secure.sysdig.com |
| us2 | ingest-us2.app.sysdig.com | https://us2.app.sysdig.com |
| us3 | ingest.us3.sysdig.com | https://app.us3.sysdig.com |
| us4 | ingest.us4.sysdig.com | https://app.us4.sysdig.com |
| eu1 | ingest-eu1.app.sysdig.com | https://eu1.app.sysdig.com |
| eu2 | ingest.eu2.sysdig.com | https://app.eu2.sysdig.com |
| au1 | ingest.au1.sysdig.com | https://app.au1.sysdig.com |
| in1 | ingest.in1.sysdig.com | https://app.in1.sysdig.com |
| jp1 | ingest.jp1.sysdig.com | https://app.jp1.sysdig.com |
| me2 | ingest.me2.sysdig.com | https://app.me2.sysdig.com |

All collectors use port **6443** (`{{COLLECTOR_PORT}}`). For environments where
6443 is blocked, use the `-alt` region variant (e.g., `us1-alt`) and port
**443**; the collector host and API URL are unchanged.

> **Prefer the tenant's own value over this table.** Sysdig UI → **Settings →
> Agent Installation** (and the agent install params it renders) reports the
> collector for that specific tenant, which can differ from the regional default
> — a us1 tenant returning `collector-static.sysdigcloud.com` instead of
> `collector.sysdigcloud.com` is normal and both work. If the user gives you a
> collector from their tenant, use it verbatim; this table is the fallback for
> when they do not have it to hand.

For on-prem: set `region: custom` and provide the same `api_url` /
`collector.host` / `collector.port` keys, pointed at your own endpoints.

**Flat aliases.** The agent accepts either spelling for these three; the nested
`sysdig_endpoint` form above and the flat form below are equivalent, so a config
that mixes documentation examples still works:

| Nested (template) | Flat alias |
|---|---|
| `sysdig_endpoint.access_key` | `customerid` |
| `sysdig_endpoint.api_url` | `sysdig_api_endpoint` |
| `sysdig_endpoint.collector.host` / `.port` | `collector` / `collector_port` |

### 7.3 Features

All under `features.*`. See the Feature Reference table (§5) for the full list.
Each feature is `enabled: true` or `enabled: false`.

### 7.4 System Driver

```yaml
system:
  driver_type: universal_ebpf    # kmod | universal_ebpf | legacy_ebpf
  root_path: /
```

🔴 **This key alone does not switch the driver on a package install.** The
DEB/RPM service takes the driver from `SYSDIG_AGENT_DRIVER` in
`/etc/default/dragent` (DEB) / `/etc/sysconfig/dragent` (RPM), and the container
takes it from the `-e SYSDIG_AGENT_DRIVER` env var (§6.3) — both read by the
startup path, not by the config parser. Emit `driver_type` **and** set the
env var for the install method in use; see §6.2c.

### 7.5 Proxy

The agent runtime takes a **nested `http_proxy` mapping with host and port**,
not URL strings. Split the proxy URL the user gave in §4d into host + port:

```yaml
http_proxy:
  proxy_host: "proxy.example.com"
  proxy_port: 3128
  ssl: false                  # true only if the proxy endpoint itself is https
  ssl_verify_certificate: true
  # proxy_user / proxy_password if the proxy needs auth
```

A top-level `proxy:` block with `http_proxy` / `https_proxy` / `no_proxy` URL
strings is the **Helm chart** form. In this file it is an unknown key: the agent
ignores it silently and connects direct — no error, no proxy.

The posture (`kspm-analyzer`) and host vulnerability scanner subprocesses do not
read this file's proxy settings; they inherit the service environment. For those,
also set the standard variables in the distro environment file and restart:

```bash
# /etc/default/dragent (DEB) or /etc/sysconfig/dragent (RPM)
HTTP_PROXY=http://proxy.example.com:3128
HTTPS_PROXY=http://proxy.example.com:3128
NO_PROXY=localhost,127.0.0.1
```

### 7.6 TLS and Custom CA

The default is already TLS **with** certificate verification, so a correct
config for the normal case contains **no** ssl keys at all. In this file `ssl`
is a **boolean** (`ssl: true`, default) and verification is
`ssl_verify_certificate: true` (default) — an `ssl:` mapping with a `verify:`
child (the Helm-chart form) is rejected:

```
Critical, configuration:2362: Config file error at key: ssl
```

and the agent refuses to start. For a custom CA, give the bundle path instead
(absolute, or relative to `/opt/draios/etc`):

```yaml
ca_certificate: /opt/draios/etc/custom-ca.pem
ssl_verify_certificate: true
```

`ca_certificate` at the top level is the CA used for the **collector**
connection. A CA needed to trust an intercepting **proxy** goes under the proxy
block instead (`http_proxy.ca_certificate`, §7.5).

### 7.7 Post-Config Steps

After placing the config on the host:

```bash
systemctl enable dragent
systemctl start dragent
```

On Debian/Ubuntu, `sudo service dragent restart` is equivalent.

For Docker installs, the container starts as soon as `docker run` returns
(`--restart always` keeps it up across reboots). To apply a **config change**,
edit the host-side file and `docker restart sysdig-agent`. If the edit replaced
the file rather than modifying it in place (most editors write a new inode, and
`install`/`cp` of a fresh copy always does), the bind mount still points at the
old inode — recreate the container instead:

```bash
docker rm -f sysdig-agent
# then re-run the docker run command from §6.3
```

---

## 8. Post-Install Verification

Run these checks proactively after starting the agent. Wait ~60 seconds for
the agent to initialize.

🔴 **Read the FILE sink. journald cannot answer any of these checks.** The
generated config sets `log_level: warn`, which gates the console/journald sink —
and every line these checks look for (`Sent msgtype=1 (METRICS)`, the handshake,
the driver-load line) is **Information** level. It is therefore *never* in
journald on a correctly configured host, while `/opt/draios/logs/draios.log`
(populated by `log_persist: true`) has all of them.

Following journald-based checks literally produces a **false failure on a
perfectly healthy agent** — an observed run reported "the agent has never
authenticated … the absence of any `Sent msgtype=1` line after 3 retries is
definitive" while the file sink held five such lines.

Config rejections and self-disabled features (Check 5) were **also** absent from
journald in that run, but `log_level` does not explain it: those lines are
`Critical`, which `warn` does not gate. Treat them as file-sink-only on
observation, cause unknown — do not assume raising `log_level` will surface them.

So: `/opt/draios/logs/draios.log` is the authoritative source for Checks 1b–6
(needs `sudo`; `docker exec` on a container install). journald is a fallback
for "is the unit even producing anything" and for warnings/errors only. Raising
`log_level` to `info` should put the **Information** lines in journald too —
untested, and it will not help with the `Critical` ones above.

⚠️ **`docker logs` is not an alternative.** It is the console sink, gated by the
same `log_level: warn`. On a container install read the file sink *inside* the
container (`docker exec sysdig-agent grep … /opt/draios/logs/draios.log`, no
`sudo` — the container runs as root); a host-side grep finds nothing because the
host has no `/opt/draios`.

🔴 **Gate every "no matches" check on the file existing.** Checks 4 and 5 pass on
*absence* of matches, and `grep` on a missing or unreadable file also yields zero
matches — a FAIL that reads as a PASS. Run this once before Check 1b:

```bash
sudo test -s /opt/draios/logs/draios.log || echo "FAIL: file sink missing or empty — log_persist not applied; every 'no matches' below is meaningless"
```

(Docker install: `docker exec sysdig-agent test -s /opt/draios/logs/draios.log`.)
If it fails, stop and fix the sink — do not report Checks 2–6 at all.

> **Service name.** The `draios-agent` package registers the systemd unit
> **`dragent`**, which is what every command below uses. If `systemctl` reports
> `Unit dragent.service could not be found`, the agent is not installed —
> report that rather than continuing; the log-grep checks would return empty
> output that looks like a pass. Docker installs have no systemd unit: use the
> container name `sysdig-agent` (`docker logs sysdig-agent`) and the
> Docker-specific Check 1 below.

### Check 1 — Service status

```bash
systemctl status dragent
```

**Expected:** `active (running)`. If `failed`, check logs (§9).

#### Check 1 (Docker installs) — the container is up **and the agent inside it is not restarting**

🔴 **`docker ps` is not a liveness check for this container.** The image's
healthcheck reports `Up … (healthy)` while the agent process inside restarts
every ~2 seconds — that is exactly what a mis-mounted Docker socket looks like
(§6.3), and `docker ps` alone reports it as a pass. Run all four:

```bash
docker inspect sysdig-agent --format '{{.RestartCount}} {{.State.Running}}'
docker exec sysdig-agent grep -c Fatal /opt/draios/logs/draios.log
docker exec sysdig-agent grep -c DIRTY_SHUTDOWN /opt/draios/logs/draios.log
docker exec sysdig-agent grep 'Successfully loaded scap driver' /opt/draios/logs/draios.log
```

> The `{{...}}` in `docker inspect --format` are Docker's own Go-template
> fields. Pass them verbatim — they are not skill placeholders to substitute.

**Expected:**

| Command | Pass | Fail means |
|---|---|---|
| `docker inspect … RestartCount State.Running` | `0 true` | a non-zero and *growing* count is a crash loop (Docker's own restarts) |
| `grep -c Fatal` | `0` | a subprocess died fatally — **it takes the whole agent with it** |
| `grep -c DIRTY_SHUTDOWN` | `0` | the agent is being killed and re-launched repeatedly |
| `grep 'Successfully loaded scap driver'` | one line naming the driver, e.g. `universal_ebpf` | no syscall source — runtime detection is dead |

**PID stability.** The in-container restart loop can run *without* Docker's
`RestartCount` moving (the supervisor inside the container restarts the agent,
not Docker). Confirm the PID is stable across the last few telemetry lines:

```bash
docker exec sysdig-agent grep 'Sent msgtype=1' /opt/draios/logs/draios.log | tail -5
```

Log lines carry the emitting PID: **the same PID on all of them is the pass
signal; a changing PID means the agent is restarting** even if the container
never did. Zero `Sent msgtype=1` lines together with `Sent msgtype=10
(DIRTY_SHUTDOWN_REPORT)` lines is the crash loop.

Only after these pass do Checks 2–6 mean anything. On a container install **all**
of them read the file sink *inside* the container —
`docker exec sysdig-agent grep … /opt/draios/logs/draios.log` (no `sudo`, the
container runs as root). `docker logs sysdig-agent` is the console sink and is
subject to the same `log_level` gate as journald, so it cannot answer Checks 2–4
either; use it only for the liveness probes above.

### Check 1b — Driver loaded (package installs)

A failed driver build leaves the agent running with no syscall source, and
Checks 1–4 all still pass. On rpm hosts this is the `dkms` failure mode from
§6.2; on any host it is a kernel-headers mismatch.

```bash
sudo grep -E 'Successfully loaded scap driver|Cannot load the probe' /opt/draios/logs/draios.log
lsmod | grep sysdigcloud_probe          # kmod driver only
```

**Expected:** a `Successfully loaded scap driver` line naming the driver
(`kmod` / `universal_ebpf`), and for `kmod` a loaded `sysdigcloud_probe`
module. `Cannot load the probe`, or an empty `lsmod` on a `kmod` install, is a
**FAIL** — see §6.2 (`dkms`) and §9 (headers / driver switch).

### Check 2 — Agent authentication

```bash
sudo grep "Sent msgtype=1" /opt/draios/logs/draios.log | tail -5
```

**Expected:** At least one `Sent msgtype=1 (METRICS) len=… to collector at
host=<collector> port=<port>` line — confirms the agent authenticated and is
sending data.

🔴 **Do not run this against journald — or `docker logs`.** With `log_level: warn`
these lines are Information-level and reach neither sink, so grepping either one
for `msgtype=1` returns nothing on a *healthy* agent. That empty result is the
single most likely cause of a false onboarding failure.

If the file has no match either, the agent may still be initializing — wait 30s
and retry (and confirm the file itself is non-empty: `sudo tail -n 5
/opt/draios/logs/draios.log`).

### Check 3 — Backend connectivity

```bash
sudo grep -i "handshake" /opt/draios/logs/draios.log | tail -3
```

**Expected:** a handshake line such as `handshake exchanged successfully`, or a
`BE handshake rsp - metric profile with N metrics` line.

🔴 **Absence of the literal string is not a failure.** The handshake wording is
build-dependent — agent 14.7.2 emits no `handshake exchanged successfully` line
at all on a perfectly healthy install. **Check 2 is the authoritative
connectivity signal:** an accepted `Sent msgtype=1 (METRICS)` to
`host=<collector> port=<port>` proves the agent connected, authenticated and is
shipping data. Treat this check as supporting evidence only:

- `Sent msgtype=1` present, no handshake line → **PASS** (report "handshake
  line not emitted by this agent build").
- `Sent msgtype=1` absent → the connection is the problem; check region
  setting, `collector.host`, proxy config (§7.5), firewall rules on the
  collector port, and Check 1's crash-loop signals.

### Check 4 — Credential validation

```bash
sudo grep "ERR_INVALID_CUSTOMER_KEY" /opt/draios/logs/draios.log
```

**Expected:** No matches — and, like Check 5, that only means anything if the
file-sink precondition passed; `grep` on a missing file reports no matches too. If
present, the `access_key` is wrong. Host Shield needs the **Agent Access Key**
(Settings → Agent Keys), NOT the Secure API Token.

### Check 5 — Config errors and self-disabled features (file log)

🔴 **journald is not enough.** The config is emitted with `log_persist: true`,
which routes detail to the **file** sink. In the observed run these messages were
in `/opt/draios/logs/draios.log` and **not** in `journalctl -u dragent` — note
that `log_level` does *not* explain it here (these lines are `Critical`, which
`warn` does not gate), so the cause is unknown and raising `log_level` is not a
workaround. Checks 1–4 pass on an install where a selected capability is dead, so
always run this check too:

```bash
sudo grep -nE 'Critical|Config file error at key:|is enabled but .* is not set' /opt/draios/logs/draios.log
```

**Expected:** no matches — **only meaningful if the file-sink precondition
above passed**, since `grep` on a missing file also reports no matches. Any hit is
a **FAIL** — report the offending key
verbatim, e.g.:

| Log line | Meaning | Fix |
|----------|---------|-----|
| `Config file error at key: ssl` | `ssl` used as a mapping; it is a boolean | §7.6 — drop the `ssl:` block, use `ca_certificate` |
| `Config file error at key: features.vulnerability_management.host_vulnerability_management.host.dirs_to_scan` | YAML list on a comma-separated-string key | Remove it (defaults cover OS package dirs) or use `host_scanner.additional_host_dirs_to_scan` |
| `KSPM Analyzer is enabled but sysdig_api_endpoint is not set. Disabling KSPM Analyzer.` | `api_url` missing → host posture off | §7.2 — set `sysdig_endpoint.api_url` |
| `host-scanner: request failed: Get "https:///api/team/infrastructure"` | `api_url` missing → host vuln scanning has no destination | §7.2 — set `sysdig_endpoint.api_url` |

`Critical` in this log means the agent rejected the config file; fix the key,
`systemctl restart dragent`, and re-run Checks 1–5.

### Check 6 — Every selected capability is actually live

For **each** feature the user chose in §4c, confirm the agent did **not**
disable it. Nothing in Checks 1–4 covers this: features are self-disabled
silently when a dependency (usually `api_url`) is missing, and a feature whose
enable key the runtime never read (§5.1b, §5.1c) looks identical to one that was
never selected.

#### 6a. The feature summary is the authoritative answer

The agent prints a per-capability summary at the end of initialization. **Read
the LAST one only:**

The per-capability lines **precede** the `completed` line, so take the last
`completed` line's number and read backwards from it. Do not `grep` the whole
file — that hits the stale first block (see below):

```bash
n=$(sudo grep -n "Feature manager initialization completed" /opt/draios/logs/draios.log | tail -1 | cut -d: -f1)
[ -n "$n" ] || echo "FAIL: no feature summary in the log — the agent never finished initializing"
sudo sed -n "$(( n > 40 ? n - 40 : 1 )),${n}p" /opt/draios/logs/draios.log
```

If the block comes back without capability lines, widen it
(`$(( n > 80 ? n - 80 : 1 ))`) rather than falling back to a whole-file grep.

🔴 **The agent initializes twice, ~12 s apart** — the first pass runs *before*
the backend handshake and reports almost everything `Disabled`
(`secure: Disabled, drift control: Disabled, malware control: Disabled, dns
detection: Disabled, response actions: Disabled, baseliner: Disabled, memdump:
Disabled`); the second pass flips them to `Enabled`. This is a clean planned
re-init, **not** a crash — there are no `DIRTY_SHUTDOWN` lines. A naive
`grep -i disabled` over the whole file hits the stale first summary and reports
six capabilities dead on a healthy host. Always take the last summary block (by
line number or PID) and read each capability's state from it, e.g.:

```
    response actions: Enabled
    drift control: Enabled
    malware control: Enabled
```

Selected-but-`Disabled` in the **last** block ⇒ **FAIL**, and the cause is
usually a missing enable key rather than a broken host: check that the
capability's nested `enabled` is set (`response_actions.enabled`, §5.1c) and
that its flat spelling was **not** also emitted (§5.1b — the pair crash-loops
the agent, which shows as a restart loop rather than a `Disabled` line).

#### 6b. Component-level confirmation

```bash
# Hits from the FIRST init block are expected (§HOST-005) — only lines at or
# after the last "Feature manager initialization completed" ($n from 6a) count.
sudo grep -niE 'disabl(ing|ed)|not set|is enabled but' /opt/draios/logs/draios.log
```

**Expected:** no hits with a line number ≥ `$n`. Hits below `$n` are the stale
first summary and are **not** a failure — without that filter 6a and 6b return
contradictory verdicts on the same healthy host.

Then, per capability:

| Selected capability | Confirm ("armed") | FAIL signal |
|---------------------|-------------------|-------------|
| Host posture | `sudo grep -i kspm /opt/draios/logs/draios.log` shows the analyzer starting, checks retrieved, events sender enabled, and polling for scan requests | `Disabling KSPM Analyzer` |
| Host / container vuln scanning | `sudo grep -i host-scanner /opt/draios/logs/draios.log` shows the platform detected (e.g. `detected environment: Saas`), backend scanning enabled, and no URL errors | `no Host in request URL`, `request failed` |
| Syscall detections / drift / malware / ML | `sudo grep -iE 'policies loaded\|security_mgr' /opt/draios/logs/draios.log` | `Critical` on a `features.detections.*` key |
| **Response actions** | the last feature summary (6a) shows `response actions: Enabled` | `response actions: Disabled` ⇒ `features.respond.response_actions.enabled` is missing (§5.1c) — the trigger map alone proves nothing |

Report per capability: **live** or **disabled (reason)**. A run where every
selected capability is not confirmed live is **not** a pass, even at 4/4 on
Checks 1–4.

**The pass condition is "armed", not "results published".** Do **not** require
`published scan result` or a fresh SBOM: the backend deduplicates per host
identity (same host ID / MAC), so a host that was scanned recently — a
re-install, a driver change, a container recreated on a host that already ran
the agent — is legitimately given no work:

```
host-scanner: already extracted sbom recently: skipping scan
kspm-analyzer: polling for pending scan requests        (with nothing assigned)
```

That is a healthy, correctly-configured install and must be reported as a pass.
Analyzer started + configuration accepted + reaching the backend is the bar; a
published result is stronger evidence when it happens to appear, not a
requirement. Say so in the receipt ("posture armed; no scan assigned — host
scanned recently") rather than reporting a failure.

### Verification Summary

| Check | Command | Pass Criteria |
|-------|---------|---------------|
| **File sink (precondition)** | `sudo test -s /opt/draios/logs/draios.log` | Non-empty. If it fails, every "no matches" row below is meaningless — stop |
| Service | `systemctl status dragent` | active (running) |
| Service (Docker) | `docker inspect … RestartCount State.Running` + `Fatal` / `DIRTY_SHUTDOWN` counts + stable PID | `0 true`, both counts `0`, PID stable — **not** `docker ps` "healthy" |
| Driver | file-log grep `Successfully loaded scap driver` (+ `lsmod` for kmod) | Driver named; no `Cannot load the probe` |
| Auth | **file-log** grep `Sent msgtype=1` | At least one match |
| Connectivity | **file-log** grep `handshake` | Handshake line **or** an accepted `Sent msgtype=1` (the handshake string is build-dependent) |
| Credential | **file-log** grep `ERR_INVALID_CUSTOMER_KEY` | No matches |
| Config / self-disable | `sudo grep -nE 'Critical\|Config file error at key:\|is enabled but .* is not set' /opt/draios/logs/draios.log` | No matches |
| Capabilities live | **last** feature summary block + per-feature greps (Check 6) | Every selected feature `Enabled` / armed (published results not required) |

Every row above reads `/opt/draios/logs/draios.log` (root-only, so `sudo`).
**Neither journald nor `docker logs` is a substitute:** both are the
console-gated sink, and `log_level: warn` keeps the Information-level lines out of
them, so those greps return nothing on a healthy host.

For Docker installs: run the Docker Check 1 above instead of `systemctl status`,
and read the file sink **inside** the container —
`docker exec sysdig-agent grep -nE '...' /opt/draios/logs/draios.log`
(the host has no `/opt/draios`, so a host-side grep silently finds nothing).

---

## 9. Troubleshooting

The `systemctl` / `journalctl` commands in this section target the `dragent`
unit. For Docker installs, substitute `docker logs sysdig-agent` /
`docker restart sysdig-agent`, and read `/opt/draios/logs/draios.log` with
`docker exec sysdig-agent grep …` — that file exists only inside the container.

### Container Reports `healthy` While the Agent Restarts in a Loop (Docker)

**Symptom:** `docker ps` shows `Up … (healthy)`, but no data reaches Sysdig. The
log carries repeated `Sent msgtype=10 (DIRTY_SHUTDOWN_REPORT)` lines from
different PIDs, `error_handler:150: agent didn't terminate cleanly`, and **no**
`Sent msgtype=1 (METRICS)`.

**Cause:** a fatal error in an agent **subprocess** terminates the whole agent,
which is then restarted — so a single mis-configured component looks like a
whole-agent crash loop rather than one dead feature. The image healthcheck does
not track the agent process, so it keeps reporting `healthy` throughout. The
most common trigger is the Docker socket mounted at the wrong path:

```
host-scanner: failed to connect to the docker API at unix:///var/run/docker.sock: no such file or directory
host-scanner: {"level":"fatal","message":"application encountered an unrecoverable error"}
```

**Fix:** mount the socket at the container-internal default
(`-v /var/run/docker.sock:/var/run/docker.sock`), not under `/host` — see §6.3.
Then `docker rm -f sysdig-agent` and re-run with the corrected mounts.

**Diagnose any variant of this** with the Docker Check 1 sequence in §8: a
`Fatal` line in `/opt/draios/logs/draios.log` names the subprocess that is
taking the agent down.

---

### Host Posture Returns Nothing on a Container Install (Docker)

**Symptom:** the analyzer starts but every host check is inconclusive:

```
kspm-analyzer: could not verify if bash is installed on host, assuming it is not installed
  error: status 127: err chroot: failed to run command 'sh': No such file or directory
```

**Cause:** the posture analyzer `chroot`s into the host filesystem, which the
container can only see if the host root is mounted.

**Fix:** add `-v /:/host:ro` and `-v /dev:/host/dev` and recreate the container
(§6.3 — mounts depend on the selected features).

---

### Agent Not Starting

**Symptom:** `systemctl status dragent` shows `failed`.

Check recent logs:

```bash
journalctl -u dragent --since "5 min ago" --no-pager
```

Common causes:
- Missing or invalid `access_key` in config
- Config file syntax error (YAML is whitespace-sensitive)
- Permission denied — agent must run as root

---

### Driver Build Failed Silently — `dkms: command not found` (rpm)

**Symptom:** `yum` / `dnf` reports the install succeeded, but no syscall data
arrives and the file log has no `Successfully loaded scap driver` line. Scroll
back through the install output for:

```
warning: %post(draios-agent-kmodule-…) scriptlet failed, exit status 127
Error in POSTIN scriptlet in rpm package draios-agent-kmodule
```

**Cause:** `draios-agent-kmodule` builds the driver from a `%post` scriptlet that
calls `dkms`, which is not preinstalled on Amazon Linux 2023 (and some minimal
RHEL images). The package manager treats a failed scriptlet as a warning.

**Fix:**

```bash
dnf install -y dkms
dnf reinstall -y draios-agent-kmodule
systemctl restart dragent
```

Then re-run §8 Check 1b. Installing `dkms` up front (§6.2) avoids it entirely.
On hosts where `dkms` or matching headers are unavailable, switch to
`universal_ebpf` instead (§7.4).

---

### A Capability Shows `Enabled` That the Config Set to `false`

**Symptom:** the feature summary reports a capability as `Enabled` although the
config has `enabled: false` — most commonly `hash detection`.

**Cause:** the backend can enable capabilities by policy, independently of the
on-host config. This is not drift and not a config error.

**Fix:** none needed. Two consequences worth remembering:

- Do not chase it as a misconfiguration; change it in the Sysdig policy instead.
- **Never** use "the summary says Enabled" as proof that a config key was read.
  Only a capability that is off by default and on after your change proves that
  (§5.1b).

---

### Kernel Module / eBPF Probe Load Failure

**Symptom:** Agent starts but logs show `Cannot load the probe`.

The agent needs either a kernel module or eBPF probe to intercept syscalls.

```bash
# Debian/Ubuntu — install kernel headers
apt-get install -y linux-headers-$(uname -r)

# CentOS/RHEL — install kernel development headers
yum install -y kernel-devel-$(uname -r)

# SLES — flavor-specific, pinned to the running kernel (§6.2b)
KREL="$(uname -r)"; zypper --non-interactive install "kernel-${KREL##*-}-devel-${KREL%-*}"
```

After installing headers, restart: `systemctl restart dragent`

If headers are unavailable (container-optimized OS), switch to universal_ebpf.
On a package install the driver comes from the **service environment file** —
setting only `system.driver_type` does not change it:

```bash
# /etc/default/dragent (DEB) or /etc/sysconfig/dragent (RPM)
SYSDIG_AGENT_DRIVER=universal_ebpf
```

```yaml
# dragent.yaml — keep the file self-describing (§7.4)
system:
  driver_type: universal_ebpf
```

Then `systemctl restart dragent`. See §6.2c for the full fallback order.

---

### Connection Refused / Timeout to Collector

1. Confirm outbound connectivity on port 6443:
   ```bash
   curl -v telnet://collector.sysdigcloud.com:6443
   ```
2. If 6443 is blocked, use an `-alt` region (port 443)
3. If a proxy is required, set the nested `http_proxy` mapping
   (`proxy_host` / `proxy_port`) per §7.5 — a top-level `proxy:` block is the
   Helm-chart form and is ignored here
4. Verify the region matches your Sysdig account

---

### ERR_INVALID_CUSTOMER_KEY

**Symptom:** Logs show `ERR_INVALID_CUSTOMER_KEY`.

**Cause:** Wrong credential. The agent needs the **Agent Access Key** (Settings
→ Agent Keys), NOT the Secure API Token (Settings → API Token). They look
similar but are different values.

**Fix:** Replace `access_key` in config and restart: `systemctl restart dragent`

---

### High CPU Usage

The agent captures all syscalls by default. To reduce overhead on busy hosts:

```yaml
# In dragent.yaml additional_settings
sampling_ratio: 10
```

Start with `10` and tune. Higher values reduce threat detection fidelity.

---

### Host Not Appearing in Sysdig UI

After starting the agent, the host should appear in Sysdig Secure →
**Integrations → Data Sources** within a few minutes. If not:

1. Verify access key is correct (no `ERR_INVALID_CUSTOMER_KEY` in logs)
2. Verify region matches your Sysdig account
3. Check collector connectivity (curl test above)
4. Allow up to 10 minutes for initial appearance

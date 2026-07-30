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
| SLES | x86_64 | |
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

Auto-select based on distro: Debian/Ubuntu → DEB, CentOS/RHEL/Amazon/SLES → RPM.
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
| **Response Actions** | `features.respond.response_actions` | per-action | Automated response (kill, quarantine, capture) |
| **Host Vuln Scanning** | `features.vulnerability_management.host_vulnerability_management.enabled` | `false` | Scan OS packages for CVEs |
| **Container Vuln Scanning** | `features.vulnerability_management.container_vulnerability_management.enabled` | `false` | Scan non-orchestrated container images |
| **In-Use Detection** | `features.vulnerability_management.in_use.enabled` | `true` | Detect actively used vulnerable packages |

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

---

## 6. Installation Methods

### 6.1 DEB Package (Debian / Ubuntu)

```bash
curl -s https://download.sysdig.com/DRAIOS-GPG-KEY.public \
  -o /usr/share/keyrings/sysdig-keyring.asc
echo "deb [signed-by=/usr/share/keyrings/sysdig-keyring.asc] https://download.sysdig.com/stable/deb stable-$(dpkg --print-architecture)/" \
  > /etc/apt/sources.list.d/sysdig.list
apt-get update
apt-get install -y linux-headers-$(uname -r)
apt-get install -y draios-agent
```

### 6.2 RPM Package (CentOS / RHEL / Fedora / Amazon Linux / SLES)

```bash
rpm --import https://download.sysdig.com/DRAIOS-GPG-KEY.public
curl -s -o /etc/yum.repos.d/draios.repo https://download.sysdig.com/stable/rpm/draios.repo
yum install -y kernel-devel-$(uname -r)
yum install -y draios-agent
```

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

🔴 **The Docker socket must be mounted at the container-internal default,
`/var/run/docker.sock` — not under `/host`.** The container-vulnerability
component (`host-scanner`) connects to `unix:///var/run/docker.sock` *inside*
the container and does not read `system.runtimes.docker[].socket` from the
config file. Mounted only at `/host/var/run/docker.sock`, it fails fatally:

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

**Two log sinks, both mandatory.** Checks 1–4 read journald
(`journalctl -u dragent`); Checks 5–6 read the file sink
(`/opt/draios/logs/draios.log`, populated because the generated config sets
`log_persist: true`). Config rejections and silently self-disabled features
appear **only** in the file sink, so a 4/4 result on journald alone says
nothing about whether posture or vulnerability scanning actually came up.

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

Only after these pass do Checks 2–6 mean anything. For Checks 2–4 use
`docker logs sysdig-agent` in place of `journalctl -u dragent`; for Checks 5–6
read the file sink inside the container with `docker exec sysdig-agent grep …`
(no `sudo` — the container runs as root).

### Check 2 — Agent authentication

```bash
journalctl -u dragent --no-pager -n 100 --grep "Sent msgtype=1"
```

**Expected:** At least one `Sent msgtype=1 (METRICS)` line — confirms the
agent authenticated and is sending data to the Sysdig collector.

If no match, the agent may still be initializing. Wait 30s and retry.

### Check 3 — Backend connectivity

```bash
journalctl -u dragent --no-pager -n 100 --grep "handshake"
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
journalctl -u dragent --no-pager -n 50 --grep "ERR_INVALID_CUSTOMER_KEY"
```

**Expected:** No matches. If present, the `access_key` is wrong. Host Shield
needs the **Agent Access Key** (Settings → Agent Keys), NOT the Secure API
Token.

### Check 5 — Config errors and self-disabled features (file log)

🔴 **journald is not enough.** The config is emitted with `log_persist: true`,
which routes detail to the **file** sink. Config errors and
feature-self-disable messages appear only in `/opt/draios/logs/draios.log` and
**never** in `journalctl -u dragent` — Checks 1–4 pass on an install where a
selected capability is dead. Always run this check too:

```bash
sudo grep -nE 'Critical|Config file error at key:|is enabled but .* is not set' /opt/draios/logs/draios.log
```

**Expected:** no matches. Any hit is a **FAIL** — report the offending key
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
silently when a dependency (usually `api_url`) is missing.

```bash
sudo grep -niE 'disabl(ing|ed)|not set|is enabled but' /opt/draios/logs/draios.log
```

Then, per capability:

| Selected capability | Confirm ("armed") | FAIL signal |
|---------------------|-------------------|-------------|
| Host posture | `sudo grep -i kspm /opt/draios/logs/draios.log` shows the analyzer starting, checks retrieved, events sender enabled, and polling for scan requests | `Disabling KSPM Analyzer` |
| Host / container vuln scanning | `sudo grep -i host-scanner /opt/draios/logs/draios.log` shows the platform detected (e.g. `detected environment: Saas`), backend scanning enabled, and no URL errors | `no Host in request URL`, `request failed` |
| Syscall detections / drift / malware / ML | `sudo grep -iE 'policies loaded\|security_mgr' /opt/draios/logs/draios.log` | `Critical` on a `features.detections.*` key |

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
| Service | `systemctl status dragent` | active (running) |
| Service (Docker) | `docker inspect … RestartCount State.Running` + `Fatal` / `DIRTY_SHUTDOWN` counts + stable PID | `0 true`, both counts `0`, PID stable — **not** `docker ps` "healthy" |
| Auth | journalctl grep `Sent msgtype=1` | At least one match |
| Connectivity | journalctl grep `handshake` | Handshake line **or** an accepted `Sent msgtype=1` (the handshake string is build-dependent) |
| Credential | journalctl grep `ERR_INVALID_CUSTOMER_KEY` | No matches |
| Config / self-disable | `sudo grep -nE 'Critical\|Config file error at key:\|is enabled but .* is not set' /opt/draios/logs/draios.log` | No matches |
| Capabilities live | file-log greps per selected feature (Check 6) | Every selected feature armed (published results not required) |

For Docker installs: run the Docker Check 1 above instead of `systemctl status`,
replace `journalctl -u dragent` with `docker logs sysdig-agent`, and read the
file sink **inside** the container —
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

### Kernel Module / eBPF Probe Load Failure

**Symptom:** Agent starts but logs show `Cannot load the probe`.

The agent needs either a kernel module or eBPF probe to intercept syscalls.

```bash
# Debian/Ubuntu — install kernel headers
apt-get install -y linux-headers-$(uname -r)

# CentOS/RHEL — install kernel development headers
yum install -y kernel-devel-$(uname -r)
```

After installing headers, restart: `systemctl restart dragent`

If headers are unavailable (container-optimized OS), switch to universal_ebpf:

```yaml
system:
  driver_type: universal_ebpf
```

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

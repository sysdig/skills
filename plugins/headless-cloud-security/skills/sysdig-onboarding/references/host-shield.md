# Linux Host Onboarding Reference (Host Shield)

## Table of Contents

1. [Overview](#1-overview)
2. [Prerequisites](#2-prerequisites)
3. [Supported Platforms](#3-supported-platforms)
4. [Feature Selection](#4-feature-selection)
5. [Installation Methods](#5-installation-methods)
6. [Configuration](#6-configuration)
7. [Troubleshooting](#7-troubleshooting)

---

## 1. Overview

Host Shield installs the Sysdig agent directly on standalone Linux servers
(outside Kubernetes) to provide:

- **Runtime Threat Detection** — Falco-based syscall monitoring detects
  suspicious process behavior, file access, and network activity in real time.
- **Host Vulnerability Scanning** — Scans installed OS packages against known
  CVE databases and reports findings in Sysdig Secure.
- **File Integrity Monitoring (FIM)** — Detects unauthorized changes to
  critical files and directories (e.g., `/etc`, `/usr/bin`).

The agent runs as a privileged system service (`dragent`) and communicates
with the Sysdig backend over TLS on port 6443 (collector) or 443 (API).

---

## 2. Prerequisites

- Linux kernel 3.10+ (required for eBPF probe support)
- Root or sudo access on the target host
- Outbound connectivity: port 443 to the Sysdig collector endpoint
- Sysdig Access Key (available in Sysdig Secure → Settings → Agent
  Installation)
- For kernel module mode: kernel headers installed
  (`linux-headers-$(uname -r)` on Debian/Ubuntu,
  `kernel-devel` on CentOS/RHEL)

---

## 3. Supported Platforms

| Distribution          | Architectures  |
|-----------------------|----------------|
| Debian / Ubuntu       | x86_64, ARM64  |
| CentOS / RHEL         | x86_64, ARM64  |
| Amazon Linux 2 / 2023 | x86_64, ARM64  |
| SLES                  | x86_64         |
| Alpine                | x86_64         |

---

## 4. Feature Selection

Ask the user which features to enable using the following question spec:

```json
{
  "question": "Which host security features do you want to enable?",
  "header": "Host Features",
  "multiSelect": true,
  "options": [
    {
      "label": "Runtime Threat Detection",
      "description": "Falco-based syscall monitoring for host processes"
    },
    {
      "label": "Host Vulnerability Scanning",
      "description": "Scan installed packages for known CVEs"
    },
    {
      "label": "File Integrity Monitoring",
      "description": "Detect unauthorized changes to critical files"
    }
  ]
}
```

Also collect:

- **Distribution and version** — from the supported platforms table above
  (e.g., "Ubuntu 22.04", "Amazon Linux 2023")
- **Install method** — one of:
  - `deb` — DEB package (Debian/Ubuntu)
  - `rpm` — RPM package (CentOS/RHEL/Amazon Linux/SLES)
  - `docker` — Privileged Docker container
  - `binary` — Standalone binary (Alpine or custom environments)

---

## 5. Installation Methods

### 5.1 DEB Package (Debian / Ubuntu)

```bash
curl -sS https://download.sysdig.com/stable/deb/sysdig.gpg.key | apt-key add -
echo "deb https://download.sysdig.com/stable/deb stable-$(dpkg --print-architecture)/" \
  > /etc/apt/sources.list.d/sysdig.list
apt-get update
apt-get install -y draios-agent
```

### 5.2 RPM Package (CentOS / RHEL / Amazon Linux / SLES)

```bash
rpm --import https://download.sysdig.com/stable/rpm/draios-signing.key
cat > /etc/yum.repos.d/draios.repo <<'EOF'
[draios]
name=Draios
baseurl=https://download.sysdig.com/stable/rpm/$basearch
enabled=1
gpgcheck=1
gpgkey=https://download.sysdig.com/stable/rpm/draios-signing.key
EOF
yum install -y draios-agent
```

### 5.3 Docker Container

Use this method when you cannot install native packages or prefer an isolated
deployment. The container requires privileged mode and host namespaces to
access kernel interfaces.

```bash
docker run -d --name sysdig-agent \
  --privileged --net host --pid host \
  -v /var/run/docker.sock:/host/var/run/docker.sock \
  -v /dev:/host/dev \
  -v /proc:/host/proc:ro \
  -v /boot:/host/boot:ro \
  -v /lib/modules:/host/lib/modules:ro \
  -v /usr:/host/usr:ro \
  -v /etc:/host/etc:ro \
  -e ACCESS_KEY={{SYSDIG_ACCESS_KEY}} \
  -e COLLECTOR={{COLLECTOR_ENDPOINT}} \
  quay.io/sysdig/agent
```

Replace `{{SYSDIG_ACCESS_KEY}}` and `{{COLLECTOR_ENDPOINT}}` with values from
Sysdig Secure → Settings → Agent Installation.

### 5.4 Binary (Alpine / Custom Environments)

Download the standalone binary from
`https://download.sysdig.com/stable/bin/` matching the target architecture,
mark it executable, and run it with the same environment variables as the
Docker method.

---

## 6. Configuration

### 6.1 Config File Location

For DEB/RPM installs, the agent reads its configuration from:

```
/etc/sysdig/dragent.yaml
```

Use the template at `templates/dragent.yaml` as a starting point. Copy it to
the target host and replace all `{{PLACEHOLDER}}` markers before starting the
agent.

### 6.2 Key Settings

| Setting                  | Description                                              |
|--------------------------|----------------------------------------------------------|
| `customerid`             | Sysdig Access Key (from Secure → Settings → Agent)       |
| `collector`              | Collector hostname for the Sysdig region                 |
| `collector_port`         | Collector port — typically 6443                          |
| `ssl`                    | Must be `true` for all production deployments            |
| `tags`                   | Comma-separated `key:value` pairs for host metadata      |
| `security.enabled`       | Enables runtime threat detection (Falco)                 |
| `security.fim.enabled`   | Enables File Integrity Monitoring                        |
| `host_scanner.enabled`   | Enables host vulnerability scanning                      |
| `sampling_ratio`         | Syscall sampling (1 = all events; higher = less data)    |

### 6.3 Collector Endpoints by Region

| Sysdig Region | Collector Endpoint             |
|---------------|--------------------------------|
| US East (us1) | collector.sysdigcloud.com      |
| US West (us2) | ingest-us2.app.sysdig.com      |
| US West GCP (us3) | ingest.us3.sysdig.com      |
| US West GCP (us4) | ingest.us4.sysdig.com      |
| EU Central (eu1)  | ingest-eu1.app.sysdig.com  |
| EU North (eu2)    | ingest.eu2.sysdig.com      |
| AP Sydney (au1)   | ingest.au1.sysdig.com      |
| AP Mumbai (in1)   | ingest.in1.sysdig.com      |
| ME South (me2)    | ingest.me2.sysdig.com      |

### 6.4 Post-Install Steps

After placing `dragent.yaml` on the host:

```bash
# Enable and start the agent service
systemctl enable dragent
systemctl start dragent

# Verify it is running
systemctl status dragent
```

For Docker installs, no separate service management is needed — the container
starts automatically with `--restart=always` if that flag is added to the
`docker run` command.

---

## 7. Troubleshooting

### Agent Not Starting

Check recent service logs:

```bash
journalctl -u dragent --since "5 min ago"
```

Common causes:
- Missing or invalid `customerid` in `dragent.yaml`
- Config file syntax error (YAML is whitespace-sensitive)

### Kernel Module / eBPF Probe Load Failure

The agent needs either a kernel module or eBPF probe to intercept syscalls.

```bash
# Debian/Ubuntu — install kernel headers
apt-get install -y linux-headers-$(uname -r)

# CentOS/RHEL — install kernel development headers
yum install -y kernel-devel-$(uname -r)
```

After installing headers, restart the agent:

```bash
systemctl restart dragent
```

### Connection Refused / Timeout to Collector

1. Confirm outbound port 443 is open from the host:
   ```bash
   curl -v telnet://collector.sysdigcloud.com:6443
   ```
2. If a proxy is required, set `http_proxy` in the `dragent.yaml` or in the
   systemd unit's environment file (`/etc/sysdig/dragent.env`).
3. Verify the `collector` value matches the Sysdig region (see table above).

### High CPU Usage

The agent captures all syscalls by default. To reduce overhead:

```yaml
# dragent.yaml — increase sampling ratio to capture 1-in-N events
sampling_ratio: 10
```

Start with `10` and tune based on observed CPU impact. Note that higher values
reduce the fidelity of threat detection.

### Verifying Agent Registration

After the agent starts, it should appear in Sysdig Secure under
**Integrations → Agents** within a few minutes. If it does not appear:

1. Check the access key is correct (`customerid` in `dragent.yaml`).
2. Confirm the collector endpoint matches the Sysdig region.
3. Review agent logs for authentication errors:
   ```bash
   journalctl -u dragent | grep -i "error\|auth\|connect"
   ```

# Offboarding Guide

Disconnecting is a first-class flow, not an afterthought. Two paths, by target:

- **Cloud accounts** — destroy the Terraform-managed resources (this page,
  from [Pre-Destroy Checklist](#pre-destroy-checklist) down).
- **Linux hosts** — remove the agent and, critically, the credential it left on
  disk: [Linux host offboarding](#linux-host-offboarding).

For Kubernetes, `helm uninstall <release> -n <namespace>` removes the Shield
components; the Agent Access Key lives only in the release values.

## Pre-Destroy Checklist

Before running `terraform destroy`:

- [ ] Confirm the account to disconnect (show from `environment.yaml`)
- [ ] Verify the correct Terraform working directory and state file
- [ ] Run `terraform state list` to review what will be destroyed
- [ ] Warn about data loss (cloud audit logs, scan history will stop updating)
- [ ] Confirm the user has noted any findings they want to preserve

## Dependency-Aware Destroy Ordering

Sysdig API enforces feature dependencies. Destroying in the wrong order
causes **409 Conflict** errors. The destroy order is the **reverse** of the
onboarding dependency chain:

### Correct Destroy Order

1. **Feature registrations** (advanced identity, threat detection, scanning, posture, foundational identity)
2. **Integration modules** (EventBridge/CloudLogs, Agentless Scanning)
3. **Config Posture module**
4. **Onboarding module** (last — everything depends on it)

### In Practice

`terraform destroy` handles ordering automatically via dependency graph.
Manual ordering is only needed for **partial destroy** using `-target`:

```bash
# Example: remove only Cloud Logs while keeping the base connection
terraform destroy \
  -target=module.event_bridge \
  -target=sysdig_secure_cloud_auth_account_feature.threat_detection \
  -target=sysdig_secure_cloud_auth_account_feature.identity_entitlement_advanced
```

**Warning:** Always destroy the feature registration AND the module together.
Destroying only the module leaves orphaned feature registrations in Sysdig.

## Partial Destroy (Remove One Block)

To remove a specific block while keeping others:

1. Identify which resources belong to the block (use `terraform state list`)
2. Use `-target` flags to destroy only those resources
3. Remove the corresponding Terraform code blocks
4. Run `terraform plan` to verify no drift

## State Cleanup

If destroy fails partway:

1. Run `terraform state list` to see remaining resources
2. Check if resources still exist in the cloud (e.g., `aws iam get-role`)
3. For resources deleted outside Terraform, the next `terraform plan` will
   auto-reconcile during refresh
4. For resources stuck in state due to API errors, use
   `terraform state rm <resource_address>` as a last resort

## Post-Destroy Verification

1. Run `terraform state list` — should be empty
2. Run `verify-cloud-status.sh <provider> <account_id>` — account should
   show no enabled features (or not appear at all)
3. Check Sysdig > Integrations > Cloud Accounts — status should update
   within a few minutes

## Update Session Files

After successful offboarding:
1. Update `customer-log.md` with offboarding details
2. Remove the account entry from `environment.yaml`
3. Optionally archive the Terraform directory

## Linux host offboarding

Removing the agent from a standalone Linux host. **Read the credential warning
first — package removal alone leaves a working Agent Access Key on disk.**

🔴 **`apt-get purge` / `yum remove` does NOT delete
`/opt/draios/etc/dragent.yaml`.** The config is placed on the host after
installation, so it is not a package-managed conffile: the purge leaves it
behind **with the Agent Access Key in plain text**, along with
`dragent.yaml.bak` / `dragent.auto.yaml`, the malware signature DB under
`/opt/draios/run/db/`, and the logs. An offboarding that stops at package
removal reports success while the host still holds a live tenant credential.
`rm -rf /opt/draios` is a required step, not a tidy-up.

### 1. Stop the agent

```bash
# Package install
systemctl disable --now dragent

# Docker install
docker rm -f sysdig-agent
docker rmi quay.io/sysdig/agent-slim      # optional: reclaim the image
```

### 2. Remove the software

```bash
# DEB
apt-get purge -y draios-agent draios-agent-slim draios-agent-kmodule

# RPM
yum remove -y draios-agent draios-agent-slim draios-agent-kmodule
```

**Build-chain cleanup (DEB).** The `kmod` driver pulls in a build chain (`dkms`,
kernel headers, compilers). To remove it:

- **Do not** run `apt-get autoremove --purge` with
  `-o APT::AutoRemove::RecommendsImportant=false -o
  APT::AutoRemove::SuggestsImportant=false`. Those options make apt collect
  packages that were already on the host and are only held by Recommends — on a
  plain Ubuntu 22.04 server it proposed **164** packages when the install had
  added **62**.
- Plain `apt-get autoremove` under-removes (typically only `dkms` and
  `dctrl-tools`).
- The safe method: take the newly-installed package list from the install
  transaction output (`/var/log/apt/history.log` if it was not recorded), purge
  exactly that list, and **dry-run first** —
  `apt-get -s purge <list>` — then diff what apt says it would remove against
  what was asked. Proceed only when there are no extras.

### 3. Remove the leftovers (credential, state, logs)

```bash
rm -rf /opt/draios      # config incl. the Agent Access Key, .bak files, sigdb, logs
rm -rf /opt/sysdig      # host-side config dir used by the Docker install method
```

### 4. Remove the repository and signing key

```bash
# DEB
rm -f /etc/apt/sources.list.d/sysdig.list /usr/share/keyrings/sysdig-keyring.asc
apt-get update

# RPM
rm -f /etc/yum.repos.d/draios.repo
rpm -e gpg-pubkey-$(rpm -qa gpg-pubkey --qf '%{version}-%{release} %{summary}\n' \
  | grep -i draios | cut -d' ' -f1) 2>/dev/null || true
```

### 5. Verify nothing is left

```bash
systemctl status dragent          # expect: Unit dragent.service could not be found
find /etc /opt /usr/share/keyrings /var/lib/systemd /usr/lib/systemd \
  -iname '*sysdig*' -o -iname '*draios*' 2>/dev/null
```

**Expected:** the `find` returns nothing. Any hit still on the host must be
reviewed before calling the offboarding complete — treat a surviving
`dragent.yaml` (any name, any directory) as an exposed credential: delete it and
tell the user to rotate the Agent Access Key in Sysdig UI → Settings → Agent
Keys if the host was shared or is being decommissioned to someone else.

The host stops reporting immediately; it disappears from Sysdig Secure →
**Integrations → Data Sources** after the backend's inactivity window.

---

## S3 Bucket Cleanup (AWS)

The sysdig-monitor module may have created Kinesis Firehose backup buckets
(`sysdig-backup-bucket-{region}-{account}`). These may not have
`force_destroy = true`, so Terraform can't delete them if they contain
objects. Check for and empty these buckets before destroy if needed:

```bash
aws s3 ls | grep sysdig-backup-bucket
aws s3 rm s3://sysdig-backup-bucket-us-east-1-123456789012 --recursive
```

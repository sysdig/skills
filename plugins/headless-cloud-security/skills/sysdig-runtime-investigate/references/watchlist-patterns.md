# Watchlist patterns — which signals to chase

When any of these rule names fire in the data you've pulled, that's the signal to expand. The action column is *what direction to look*, not a fixed query.

| Watchlist hit | Suggests | Expand toward |
|---|---|---|
| `Contact EC2 Instance Metadata Service*`, `Read Service Account Token` | IAM/IMDS credential theft | CloudTrail by `aws.accountId` for the same hour |
| `Create Access Key for User`, `IAM*Backdoor*`, `EC2 Instance Create Access Key for User` | Persistent cloud creds | Cross-reference K8s pods active in the same window; pull RBAC of any related SA (service account) |
| `CloudTrail Logging Disabled`, `CloudTrail Trail Deleted`, `Delete Bucket Public Access Block` | Defense evasion / exfil prep | The full cloud-account sweep — what else did the same identity do? |
| `S3 Bucket Made Public`, `Suspicious S3 Activity`, `Cloud Storage Access from Unexpected Identity` | Data exfil | CloudTrail S3 events; identify which bucket and what objects |
| `Launch Root User Container`, `Privileged Pod Created`, `Mounted Sensitive Path` | Privesc | Sibling pods in the same cluster + RBAC of the SA |
| `Attach/Exec Pod`, `kubectl Exec to Sensitive Namespace` | Lateral movement | Pods exec'd into; their image, process tree, prior events |
| `Binary Drift`, `Linux Kernel Module Injection Detected`, `Malware Detection`, `Drop and Execute /tmp Binary` | Active runtime compromise | Process tree, hash → VT, image scan |
| `Detected reconnaissance script` | Recon | Prior events on same resource, what came after |
| `Suspicious AI Prompt detected` | Prompt-injection RCE | Process tree + `aiGeneratedDescription` to confirm cmd matches prompt |

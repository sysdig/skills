# Confirmation Flow (Step 5b)

After the discovery interview and before generating configuration, present
a confirmation summary for user review.

## Confirmation Table Format

### Cloud Accounts

| Setting | Value | Source |
|---------|-------|--------|
| Target | Cloud Account | Step 1 |
| Provider | AWS | Step 3a |
| Account ID | 123456789012 | Auto-detected |
| Scope | Single Account | Step 3b |
| Sysdig Region | us1 | Step 2 |
| Connections | Connection + Cloud Logs + Scanning | Step 3d |
| Log capture mode | EventBridge | Step 3d-ii |
| Monitored regions | us-east-1, eu-west-1 | Step 3d-ii |
| Backend | Local | Step 3e |

### Kubernetes

| Setting | Value | Source |
|---------|-------|--------|
| Target | Kubernetes | Step 1 |
| Distribution | EKS | Step 4 |
| Cluster Name | prod-cluster | Step 4 |
| Namespace | sysdig-agent | Step 4 |
| Sysdig Region | us1 | Step 2 |
| Features | Runtime, Posture, Vulnerability scanning | Step 4 |

### Linux Host

| Setting | Value | Source |
|---------|-------|--------|
| Target | Linux Host | Step 1 |
| Distribution | Ubuntu 22.04 | Step 5 |
| Install Method | DEB package | Step 5 |
| Sysdig Region | us1 | Step 2 |
| Features | Runtime, File integrity monitoring | Step 5 |

## Edit Protocol

Use AskUserQuestion:

```json
{
  "question": "Review your configuration. What would you like to do?",
  "header": "Confirmation",
  "multiSelect": false,
  "options": [
    {"label": "Looks good — proceed", "description": "Generate configuration and run terraform plan"},
    {"label": "Edit a setting", "description": "Change one value without restarting"},
    {"label": "Start over", "description": "Restart the interview from the beginning"}
  ]
}
```

### If "Edit a setting" is selected:

Show only options relevant to the current target type:

**Cloud Accounts:**
```json
{
  "question": "Which setting do you want to change?",
  "header": "Edit Setting",
  "multiSelect": false,
  "options": [
    {"label": "Provider"},
    {"label": "Scope"},
    {"label": "Region"},
    {"label": "Connections"},
    {"label": "Log capture mode"},
    {"label": "Backend"}
  ]
}
```

**Kubernetes:**
```json
{
  "question": "Which setting do you want to change?",
  "header": "Edit Setting",
  "multiSelect": false,
  "options": [
    {"label": "Distribution"},
    {"label": "Cluster name"},
    {"label": "Namespace"},
    {"label": "Region"},
    {"label": "Features"}
  ]
}
```

**Linux Host:**
```json
{
  "question": "Which setting do you want to change?",
  "header": "Edit Setting",
  "multiSelect": false,
  "options": [
    {"label": "Distribution"},
    {"label": "Install method"},
    {"label": "Region"},
    {"label": "Features"}
  ]
}
```

Then:
1. Re-present ONLY the original wizard dialog for that setting
2. After they answer, update the confirmation table
3. Re-display the updated table
4. Ask for confirmation again
5. Do NOT restart the interview from Step 1

## Ambiguity Check (Pre-Generation Gate)

Before proceeding to generation, verify completeness:

| Condition | Resolution |
|-----------|-----------|
| Cloud Logs selected but no regions chosen | Ask region selection question |
| Org scope from member account | Warn: "You appear to be on a member account. Org-scope requires management account credentials." |
| Backend mismatches provider | Warn: "S3 backend with Azure provider — is this intentional?" |
| CloudTrail/S3 mode but no trail info | Ask for trail name and bucket ARN |

If any ambiguity exists, resolve it before allowing generation to proceed.
Show: `**Configuration completeness:** 100%` (or the specific missing items).

# MCP Integrations for Remediation Workflows

After onboarding your cloud accounts, you can connect MCP servers to enable
remediation workflows directly from Claude Code — fix posture violations,
create tickets, and manage PRs without leaving the terminal.

## GitHub MCP Server

Create PRs to fix Infrastructure-as-Code issues found by Sysdig (posture
violations, misconfigured resources, vulnerable dependencies).

**Install:**

```bash
claude mcp add github -- npx -y @modelcontextprotocol/server-github
```

Set your GitHub token:

```bash
export GITHUB_PERSONAL_ACCESS_TOKEN="ghp_..."
```

**Example workflows:**

- "Sysdig found an S3 bucket without encryption. Create a PR to fix it."
- "Fix the IAM policy that Sysdig flagged as overly permissive."
- "Create a PR adding `force_destroy = true` to the Terraform S3 bucket."

## Jira MCP Server

Create and track tickets for security findings that need team coordination.

**Install:**

```bash
claude mcp add jira -- npx -y @anthropic/mcp-server-jira
```

Configure:

```bash
export JIRA_URL="https://yourcompany.atlassian.net"
export JIRA_EMAIL="you@company.com"
export JIRA_API_TOKEN="..."
```

**Example workflows:**

- "Create a Jira ticket for the CIEM finding on the over-privileged role."
- "Open a security issue for the unencrypted RDS instance Sysdig found."
- "Track remediation of all critical posture violations as Jira tasks."

## When to Suggest

Suggest these integrations after a successful onboarding when the user has:

- **GitHub**: An IaC repository (Terraform, CloudFormation) that defines the
  infrastructure Sysdig is now monitoring. PR-based fixes close the loop
  between detection and remediation.
- **Jira**: A team workflow where security findings need to be tracked,
  assigned, and prioritized through a ticketing system.

Both can be installed in the same environment for a combined workflow:
Sysdig detects → Claude creates a fix PR → Jira ticket tracks the change.

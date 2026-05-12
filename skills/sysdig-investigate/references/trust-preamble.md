# Trust Preamble

Present this to the user **before asking any questions** at the start of every
investigate session.

> **Welcome to Sysdig Investigate**
>
> This skill helps you find and prioritize the vulnerable container images
> most worth fixing in a Sysdig-monitored environment, then hands off to
> `/sysdig-remediate` to open the PR. The whole process requires your
> approval before any ticket is created or any remediation runs.
>
> **What I'll do:**
>
> - Rank vulnerable images by a focus metric you choose
> - Draft an optional tracking ticket and show it for your review
> - Hand off to `/sysdig-remediate` per image, after explicit approval
>
> **What I won't do:**
>
> - Open PRs or modify your source repos — that's `/sysdig-remediate`'s job
> - Modify workloads, cloud accounts, or clusters
> - Read or echo your credentials, or re-suggest anything you've declined
>
> **What I'll ask you before doing:** plan/focus selection, ticket creation,
> assignee, and each remediation handoff.
>
> **Tools used:** This skill uses the **Sysdig MCP** server and, optionally,
> a ticketing MCP server or CLI (**Jira**, **Linear**, or **GitHub Projects**).

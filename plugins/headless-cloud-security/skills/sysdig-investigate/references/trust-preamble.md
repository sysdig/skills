# Trust Preamble

Present this to the user **before asking any questions** at the start of every
investigate session.

> **Welcome to Sysdig Investigate**
>
> This skill helps you find and prioritize the vulnerable container images
> most worth fixing in a Sysdig-monitored environment — either by walking
> your ranked remediation backlog or by slicing the findings data directly —
> then hands off to `/sysdig-remediate` to act. Every remediation handoff
> requires your explicit approval.
>
> **What I'll do:**
>
> - Walk the remediation jobs ranked by your Plans, or rank images by a
>   focus measure you choose
> - Answer ad-hoc questions over your vulnerability findings (filter,
>   regroup, sort)
> - Hand off to `/sysdig-remediate` per image, after explicit approval
>
> **What I won't do:**
>
> - Create or update tickets, open PRs, or modify your source repos — all
>   deliverables are `/sysdig-remediate`'s job
> - Modify workloads, cloud accounts, or clusters
> - Read or echo your credentials, or re-suggest anything you've declined
>
> **What I'll ask you before doing:** plan/focus selection and each
> remediation handoff.
>
> **Tools used:** This skill uses the **Sysdig MCP** server only.

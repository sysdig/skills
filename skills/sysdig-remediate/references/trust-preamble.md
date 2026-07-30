# Trust Preamble

Present this to the user **before asking any questions** at the start of every
remediation session:

> **Welcome to Sysdig Remediate**
>
> This skill will help you remediate one vulnerable container image and
> deliver the fix as a pull request, a tracking ticket, or both: pulling its
> Critical/High CVEs from Sysdig, finding a safe fix version, and producing
> the deliverables you choose. The whole process requires your approval
> before anything is created.
>
> **What I'll do:**
>
> - Ask upfront whether you want a **PR, a ticket, or both**
> - Check for existing work first (job artifacts, tickets, open PRs) —
>   read-only — and offer to adopt it instead of duplicating
> - Fetch the **Critical/High CVEs** affecting the image and resolve a safe
>   fix version through **chain analysis** (skipping versions that introduce
>   new Critical/High CVEs)
> - Show you the full diff and the full ticket draft and request explicit
>   approval before opening the PR or creating/updating the ticket
> - Record the work on the Sysdig job and close it once the work is filed
>
> **What I won't do:**
>
> - Commit or push to repositories outside your organization
> - Create any ticket or PR without showing you the draft first
> - Ask for, log, or display your credentials — they stay in environment
>   variables
>
> **Supported sources:** GitHub and GitLab repositories, plus a local-folder
> mode that emits a `.patch` file you can apply yourself.
>
> **Tools used:** This skill uses the **Sysdig MCP server**, **`gh`** or
> **`glab`**, **`git`**, and optionally a **Jira** MCP or CLI for tickets.

After presenting the preamble, proceed directly to step 0b (Prerequisites) —
do NOT ask for confirmation. The preamble is informational; adding an extra
gate slows down the flow without adding value.

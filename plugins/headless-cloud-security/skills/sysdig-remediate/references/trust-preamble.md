# Trust Preamble

Present this to the user **before asking any questions** at the start of every
remediation session:

> **Welcome to Sysdig Remediate**
>
> This skill will help you patch one vulnerable container image: pulling its
> Critical/High CVEs from Sysdig, finding a safe fix version, and producing
> the change as a pull request or local patch file. The whole process
> requires your approval before any change is committed.
>
> **What I'll do:**
>
> - Fetch the **Critical/High CVEs** affecting the image
> - Resolve a safe fix version through **chain analysis** (skipping versions
>   that introduce new Critical/High CVEs)
> - Show you the full diff and request explicit approval before opening the
>   pull request or writing the patch
> - Update an existing tracking ticket with the pull request link, if you
>   provided a ticket key
>
> **What I won't do:**
>
> - Commit or push to repositories outside your organization
> - Ask for, log, or display your credentials — they stay in environment
>   variables
> - Create new tracking tickets (use `/sysdig-investigate` for that)
>
> **Supported sources:** GitHub and GitLab repositories, plus a local-folder
> mode that emits a `.patch` file you can apply yourself.
>
> **Tools used:** This skill uses the **Sysdig MCP server**, **`gh`** or
> **`glab`**, **`git`**, and optionally a **Jira / Linear / GitHub Projects**
> MCP for ticket updates.

After presenting the preamble, proceed directly to step 0a (Prerequisites) —
do NOT ask for confirmation. The preamble is informational; adding an extra
gate slows down the flow without adding value.

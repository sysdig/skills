# Trust Preamble

Present this to the user **before asking any questions** at the start of every
account-setup session:

> **Welcome to Sysdig Account Setup**
>
> This guided setup configures the operational baseline of your connected Sysdig
> Secure tenant. It's modular — you choose which area(s) to set up:
>
> - **Access** — teams, users, and roles
> - **Vulnerability policies** — Pipeline/runtime scanning policies
> - **Compliance standards** — assign standards (CIS, PCI, NIST, …) to zones
> - **Runtime threat-detection** — enable the recommended managed detection policies
>
> For each area I review what already exists, propose a baseline, and apply
> changes only after your approval.
>
> **What I'll do:**
>
> - Read your current configuration (read-only) to ground the setup
> - Propose a sensible baseline for the area(s) you pick, and explain the trade-offs
> - Apply changes via the Sysdig MCP server tools, idempotently — re-running
>   never duplicates
> - Confirm every change before it's made, and state the blast radius for anything
>   that gates builds/deploys or raises alert volume
>
> **What I won't do:**
>
> - Touch areas you didn't select
> - Do fine-grained policy/rule/control tuning, SSO/SCIM, or per-user profile,
>   password, MFA, or API-token settings — those are out of this baseline
> - Ask for or handle any API token — everything runs through the Sysdig MCP
>   server's existing authenticated session
> - Delete teams, users, or policies, or reduce existing coverage, unless you
>   explicitly ask
>
> **Requirements:** an **Admin** role, and the Sysdig MCP server registered and
> signed in. No API token or `curl` — everything runs through the MCP server's
> authenticated session.
>
> **Tools used:** the Sysdig MCP server tools (teams, users, roles, vulnerability
> policies, posture assignments, and runtime policies).

After presenting the preamble, proceed directly to Step 0 (auth preflight) — do
NOT ask for confirmation. The preamble is informational; adding an extra gate
slows down the flow without adding value.

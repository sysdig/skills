# Experimental Provider Handling (Azure tenant / GCP organization)

Detail for [SKILL.md](../SKILL.md) **Step 3a / 3b**. **Azure tenant scope** and
**GCP organization scope** are **experimental**: Terraform generation and
permission validation work, but the guided flow has not been tested end-to-end.
**Azure single subscription and GCP single project are Supported** — no
disclaimer. Present the disclaimer below once when it applies, then apply the
flow behavior for the rest of the session.

## Experimental provider disclaimer

When the selected provider is **Azure with tenant / management-group scope**, or
**GCP with organization scope** (whether chosen via the picker/scope question or
stated by the user), present this notice once before continuing the interview.
Substitute `{provider}` with the actual name ("Azure tenant" or "GCP
organization"). Introduce the notice with the exact preface line below — do not
improvise:

> Before we continue, here's the current status of {provider} support:

Then present this block:

> **{provider} support is experimental**
>
> The onboarding flow for {provider} has not been fully tested yet.
> Here's what that means:
>
> - **What works well:** Terraform configuration generation, permission
>   validation, and post-deployment verification — built on the same
>   infrastructure as the fully tested AWS flow.
> - **What may need your input:** Provider-specific edge cases
>   (organization scoping, troubleshooting) may require you to fill in
>   details I can't fully guide you through yet.
> - **Recommendation:** Review the generated Terraform carefully before
>   applying, and keep the
>   [Sysdig docs](https://docs.sysdig.com/) handy for provider-specific
>   questions.
>
> Want to proceed?

Wait for confirmation before continuing. If the user declines, offer to
switch to AWS or Kubernetes instead.

## Experimental flow behavior

For the remainder of an experimental provider session:

- After generating Terraform (Step 7), explicitly tell the user to
  review it before applying — do not assume the template covers all
  edge cases.
- If the user hits an error you cannot diagnose from known-issues.md
  or troubleshooting.md, say so honestly: "This is an area where the
  experimental flow has gaps — here's what I'd try, but you may need
  to check the Sysdig docs or open a support ticket."
- Do NOT invent troubleshooting steps. If the reference doc is a stub,
  acknowledge the gap rather than guessing.

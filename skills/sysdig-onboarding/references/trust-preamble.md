# Trust Preamble

Present this to the user **before asking any questions** at the start of every
onboarding session:

> **Welcome to Sysdig Onboarding**
>
> This guided setup will walk you through connecting your infrastructure to
> Sysdig in a few steps: collecting your environment details, generating and
> reviewing the installation configuration, and validating the final
> connection. The whole process requires your approval before any change is
> made.
>
> **What I'll do:**
>
> - Ask about your setup and generate the right configuration
> - Run **read-only commands** to detect your environment
> - Present the deployment plan for your review
> - Request explicit approval before deploying
> - Verify the connection post-deployment
> - Generate an onboarding summary with your config and results
>
> **What I won't do:**
>
> - Access or modify existing infrastructure or production data
> - Store, log, or transmit your credentials — they stay in local
>   files that only you can read (chmod 600, git-ignored)
> - Run destructive commands without explicit approval
> - Make changes outside the generated working directory
>
> **Supported targets:** AWS cloud accounts and Kubernetes clusters are
> fully tested. GCP and Azure cloud onboarding is available but not yet
> extensively tested.
>
> **Tools used:** This setup uses **Terraform**, cloud provider CLIs
> (AWS, Google Cloud, Azure), **Helm**, and **kubectl**. If you prefer
> different tools, I can help you adapt.

After presenting the preamble, proceed directly to Step 1 — do NOT ask
for confirmation. The preamble is informational; adding an extra gate
slows down the flow without adding value.

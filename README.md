# Sysdig Headless Cloud Security

## Summary

Sysdig's cloud security expertise, packaged as agent skills that work natively in your AI environment.

## Description

Headless Cloud Security brings Sysdig's runtime-grounded security knowledge directly into Claude, so security teams can onboard, investigate, and operate cloud security workflows without leaving their AI environment.

Built for enterprises that have adopted coding agents as part of their standard toolchain, Headless Cloud Security packages over a decade of cloud security expertise as reusable skills covering environment onboarding, vulnerability management, risk analysis, and runtime threat investigation. Every action is designed to keep humans in control, with structured logging for full auditability.

Sysdig's runtime layer, powered by [Falco](https://falco.org/), provides the high-fidelity, deterministic signals that make agent-driven security workflows trustworthy. The platform adapts to how your security program operates, not the other way around.

## Public Beta Terms

Thank you for downloading the Public Beta/early preview release of the Sysdig Headless Cloud Security plugin (the “Plugin”). Customer’s use of the Plugin is voluntary and at Customer’s sole discretion.  Customer use is subject to these Public Beta Terms (the “Terms”).

By downloading, installing, or using the Plugin, Customer represents and agrees that:

- The individual accepting or using the Plugin is authorized to bind Customer and Customer’s organization to these Terms;
- The Plugin is intended to operate solely within Customer’s internal AI tool that is compatible with the Plugin for Customer’s internal business purposes;
- The Plugin constitutes a beta, preview, or other non-generally available offering and is subject to the applicable preview release, beta feature, trial use, warranty disclaimer, limitation of liability, and related provisions set forth in the commercial purchase agreement, master subscription agreement, or other governing agreement between Customer and Sysdig;
- The Plugin incorporates agentic artificial intelligence capabilities, which may act autonomously or semi-autonomously based on Customer prompts, configured parameters, permissions, policies, and instructions to generate outputs, make recommendations, make decisions, or take actions on Customer’s behalf.

Customer acknowledges and agrees that Customer is solely responsible for: (i) reviewing, validating, monitoring, and supervising all outputs, decisions, recommendations, and actions generated or taken by the Plugin; and (ii) ensuring the accuracy, completeness, legality, appropriateness, and security of any resulting outputs, actions, or downstream effects.

The Plugin is provided “as is” and “as available,” without warranties of any kind, and Customer assumes all risks arising from or related to its download, installation, use, outputs, and operation.

## How to use

Once installed, describe what you need in plain language. Examples:

- *"Onboard my AWS account to Sysdig"*
- *"Show me the highest-risk vulnerabilities in production"*
- *"Investigate this runtime alert and tell me if it's exploitable"*

### Prerequisites

- A **Sysdig Secure** account
- A supported AI coding agent — **Claude Code** is the primary target; **Cursor**, **OpenAI Codex**, and **OpenCode** can use the bare skills via [Compatibility with other agents](#compatibility-with-other-agents)
- **Python 3** — required by skill scripts (uses stdlib only, no `pip install` needed)
- A **Sysdig API token** — *only* if you use `sysdig-onboarding` or `sysdig-posture`. Generate one under **Settings → Sysdig Secure API**. Every other skill authenticates via OAuth and needs no token.

### Install in Claude Code

```bash
/plugin marketplace add sysdig/skills
```

```bash
/plugin install headless-cloud-security@sysdig-skills
```

The marketplace install loads the plugin skills and any per-skill MCP server dependencies declared in `agents/*.yaml`. The hosted Sysdig MCP server is **not** bundled — register it separately (next step).

### Register the Sysdig MCP server

Most skills reach your tenant through the hosted Sysdig MCP server, authenticated with OAuth — there is no token to copy. Register it once, pointing at your region's MCP URL (your region URL + `/mcp/secure`):

```bash
claude mcp add --transport http secure-mcp-server https://us2.app.sysdig.com/mcp/secure
```

Replace `us2.app.sysdig.com` with **your** region URL from the table below — the MCP URL is always your region URL + `/mcp/secure`. Then run `/mcp` → `secure-mcp-server` → **Authenticate** for the one-time OAuth sign-in. Once authenticated, describe what you need in plain language and the right skill loads automatically.

**Sysdig region URLs:**

| Region | URL |
|--------|-----|
| US East (us1) | `https://secure.sysdig.com` |
| US West — Oregon (us2) | `https://us2.app.sysdig.com` |
| US West — GCP (us3) | `https://app.us3.sysdig.com` |
| US West — GCP Dallas (us4) | `https://app.us4.sysdig.com` |
| EU Central — Frankfurt (eu1) | `https://eu1.app.sysdig.com` |
| EU North — Stockholm (eu2) | `https://app.eu2.sysdig.com` |
| AP Sydney (au1) | `https://app.au1.sysdig.com` |
| AP Mumbai (in1) | `https://app.in1.sysdig.com` |
| ME South — Dammam (me2) | `https://app.me2.sysdig.com` |
| AP Tokyo (jp1) | `https://app.jp1.sysdig.com` |

> If your region isn't listed, self-host the Sysdig MCP server and register that URL instead. For other agents (Cursor, OpenAI Codex, OpenCode, Claude Desktop, ChatGPT, Gemini, …), register an HTTP MCP server at your region's `/mcp/secure` URL with OAuth — see each skill's `references/mcp-setup.md`.

### API token — only for some skills

`sysdig-onboarding` and `sysdig-posture` call the Sysdig REST API or Terraform provider directly, so they need a token in your environment. (Every other skill uses OAuth — skip this section.) Export it in your shell profile, using your region URL from the [table above](#register-the-sysdig-mcp-server):

```bash
export SYSDIG_SECURE_URL="https://us2.app.sysdig.com"     # your Sysdig region URL
export SYSDIG_SECURE_API_TOKEN="your-api-token"
```

Skills auto-discover these. **Never paste credentials in chat.** The hosted MCP server ignores these variables.

### Compatibility with other agents

Every skill follows the [Agent Skills specification](https://agentskills.io/specification) and is published as a stand-alone unit under [`skills/<skill-name>/`](./skills) at the repo root. These bare-skill copies are kept in sync with the plugin contents on every publish, so they always reflect the latest released skill set.

#### Install with `npx skills` (recommended)

The [`skills`](https://www.npmjs.com/package/skills) CLI works with any spec-compliant agent. To install a single skill:

```bash
npx skills install sysdig/skills <skill-name>
```

For example, to install the onboarding skill:

```bash
npx skills install sysdig/skills sysdig-onboarding
```

`npx skills` reads each skill's `SKILL.md` and copies it (along with its scripts and references) into the appropriate skills directory for your agent.

#### Manual install (clone and symlink)

If you prefer to manage the files yourself:

```bash
git clone https://github.com/sysdig/skills.git ~/sysdig-skills

# Example: link every published skill into your agent's skills directory
ln -s ~/sysdig-skills/skills/* <agent-skills-dir>/
```

#### MCP server registration

The Sysdig MCP server is never bundled — you register it yourself with `claude mcp add` (see [Register the Sysdig MCP server](#register-the-sysdig-mcp-server) above) regardless of install method. Per-skill `agents/*.yaml` dependencies on other MCP servers (Jira, GitHub, …) are also **not** loaded by either of the two methods above; register those with your agent yourself too.

## Skills shipped today

| Skill | What it does |
|-------|--------------|
| [`sysdig-account-setup`](plugins/headless-cloud-security/skills/sysdig-account-setup) | Baseline account setup for Sysdig Secure after a tenant is connected. Guided, interactive, modular setup via the Sysdig MCP server: (1) access baseline — teams, users, and roles; (2) vulnerability management policy baseline — Pipeline vs runtime, one policy or split; (3) compliance standards — assign posture policies (CIS, PCI, NIST, …) to zones; (4) runtime threat-detection — enable/disable the recommended managed detection policies. Reviews current state, proposes a structure, and applies changes idempotently with explicit confirmation before anything that mutates the tenant. Use right after onboarding to leave an account usable out of the box. Fine-grained policy tuning is out of scope. |
| [`sysdig-investigate`](plugins/headless-cloud-security/skills/sysdig-investigate) | Investigate and prioritize vulnerable images in a Sysdig-monitored environment via two flows, routed from the user's goal. Plans flow — plan-driven prioritization: pick an admin-configured Plan (or explore ranked jobs under an ad-hoc scope and measure) and walk the prioritized remediation jobs one at a time. Findings flow — ad-hoc findings analysis: filter, regroup, sort, and page vulnerability findings the way the Vulnerability Management UI table does. Hands any chosen image off to /sysdig-remediate, which owns tickets, PRs, job tracking, and job closing. Triggers on: "investigate", "what should I fix", "what should I fix first", "show me my vulnerable images", "prioritize vulnerabilities", "which images are affected by CVE-...", "show me all Critical CVEs in production", "/sysdig-investigate". Not for opening PRs, applying fixes, or creating/updating tickets — use /sysdig-remediate for all of those. |
| [`sysdig-onboarding`](plugins/headless-cloud-security/skills/sysdig-onboarding) | Interactive onboarding assistant for Sysdig Secure. Guides users through connecting AWS, GCP and Azure cloud accounts, Kubernetes clusters (including Windows nodes), and Linux hosts to Sysdig, plus serverless workload scanning (AWS ECS/Fargate, AWS Lambda, GCP Cloud Run). Presents security capabilities in plain language instead of jargon. Supports guided (interview) and autonomous (all-at-once) modes. Generates Terraform configurations for cloud accounts and Helm values for Kubernetes, validates prerequisites, deploys, and verifies connectivity. |
| [`sysdig-posture`](plugins/headless-cloud-security/skills/sysdig-posture) | Author Sysdig Secure Posture custom controls (Rego) and custom policies, and emit Terraform via the Sysdig provider. Use when the user wants to "write a posture rule," "create a custom CSPM control," "fail my policy when an S3 bucket is unencrypted," or "group these CIS controls into a custom policy." Never writes to Sysdig directly — all writes go through Terraform on user approval. Not for: zone management, built-in Sysdig controls, runtime threat detection, vulnerable-image triage or remediation, or onboarding cloud accounts. |
| [`sysdig-remediate`](plugins/headless-cloud-security/skills/sysdig-remediate) | Remediate one specific vulnerable container image and deliver the fix as a PR/MR, a tracking ticket, or both — this skill is the sole ticket creator in the Sysdig vulnerability workflow. Deduplicates existing work (job artifacts, Sysdig-created Jira tickets, external tickets and PRs) read-only, fetches Critical/High CVEs from Sysdig, resolves a safe fix version via chain analysis, opens a PR/MR (GitHub/GitLab) or emits a local patch, creates or updates the Jira ticket, records artifacts on the remediation job, and closes the job once the work is filed. Triggers: "fix the nginx image", "patch CVE-2024-1234 in api-server", "remediate quay.io/org/app:tag", "create a ticket for CVE-2024-9999", "file a Jira ticket for this image", "/sysdig-remediate <image>". Not for: discovery, prioritization, or slicing findings — use /sysdig-investigate. |
| [`sysdig-runtime-investigate`](plugins/headless-cloud-security/skills/sysdig-runtime-investigate) | Use this skill when investigating a runtime threat detected by Sysdig end-to-end. Surfaces the highest-priority threat, scores vulnerability vs runtime correlations on a 1-5 confidence scale, deep-dives into network blast radius or suspicious-binary VirusTotal lookups depending on the event class, reconstructs the affected workload's activity audit trail (commands, connections, file accesses) as a timeline around the detection, and hands the case off to Jira or PagerDuty. Triggers on: "investigate runtime threat", "what is this Falco alert", "triage this SOC alert", "analyze runtime incident". Not for vulnerability prioritization (use `sysdig-investigate`) or remediation (use `sysdig-remediate`). |
| [`sysdig-runtime-remediate`](plugins/headless-cloud-security/skills/sysdig-runtime-remediate) | Close the runtime loop on a Sysdig-detected threat: turn the investigation context into proposed response actions, analyse the blast radius on the affected workload, and execute (or file) the actions the user approves — one at a time, with explicit confirmation. Triggers: "remediate this runtime threat", "respond to event <id>", "act on this incident", "isolate / kill / pause that container", "/sysdig-runtime-remediate". Not for vulnerability fixes (use sysdig-remediate) or threat investigation itself (use sysdig-runtime-investigate). |
| [`sysdig-sysql`](plugins/headless-cloud-security/skills/sysdig-sysql) | SysQL query language reference for Sysdig Secure. Use when writing, debugging, or explaining SysQL graph queries against the Sysdig security datastore. Triggers on: SysQL queries, Sysdig inventory/vulnerability/posture/identity/runtime queries, "write a SysQL query", "query sysdig for", "find vulnerable images", "show me workloads", or any task involving MATCH/RETURN syntax against Sysdig entities. Also use when exploring the SysQL schema (entities, fields, relationships). Each query's entities and fields are validated against the live schema before it is shown and run, and the results are presented with follow-up suggestions. |

The list above is generated automatically on every publish from each skill's `SKILL.md` frontmatter.

## Repository layout

```
skills/
├── .claude-plugin/
│   └── marketplace.json                  # marketplace index (generated)
├── plugins/
│   └── headless-cloud-security/          # the published Claude Code plugin
│       ├── .claude-plugin/plugin.json
│       └── skills/<skill-name>/          # one directory per skill
└── skills/
    └── <skill-name>/                     # bare-skill mirror (spec-compliant)
```

## Scanning these skills with SkillSpector

If you audit agent skills with [SkillSpector](https://github.com/NVIDIA/SkillSpector), this repository ships a reviewed baseline (`.skillspector-baseline.yaml`) that suppresses known false positives and intended-by-design findings, each with an explanation. Pass it so only new or genuinely actionable findings surface:

```bash
# Scan one skill with the shipped baseline (scan per-skill —
# SkillSpector's --recursive mode does not apply --baseline).
skillspector scan skills/<skill-name> --baseline .skillspector-baseline.yaml
```

The baseline is also copied inside each skill directory, so a single-skill install still carries it:

```bash
skillspector scan skills/<skill-name> --baseline skills/<skill-name>/.skillspector-baseline.yaml
```

Suppressed findings are reported as suppressed (with their justification) rather than dropped silently — for example, threat-detection documentation that references attacker techniques (IMDS endpoints, credential paths), the intentionally privileged Sysdig host agent, and documented credential auto-discovery from `SYSDIG_*` environment variables. Findings **not** in the baseline are real and worth reviewing.

## Maintenance and contributions

This repository is published and maintained by Sysdig through an automated pipeline. **Direct pull requests are not accepted** — any direct changes will be overwritten on the next publish. See [`CONTRIBUTING.md`](./CONTRIBUTING.md).

### Reporting security issues

Do **not** disclose security findings in public forums. Email [`secops@sysdig.com`](mailto:secops@sysdig.com) with details.

## License

See [`LICENSE`](./LICENSE).

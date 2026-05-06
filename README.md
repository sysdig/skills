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

- A **Sysdig Secure** account with API access
- A **Sysdig API token** — generate one under **Settings → Sysdig Secure API** in your Sysdig instance
- A supported AI coding agent — **Claude Code** is the primary target; **Cursor**, **OpenAI Codex**, and **OpenCode** can use the bare skills via [Compatibility with other agents](#compatibility-with-other-agents)
- **Python 3** — required by skill scripts (uses stdlib only, no `pip install` needed)

### Set up credentials

Skills auto-discover Sysdig credentials from your environment. Export them in your shell profile:

```bash
export SYSDIG_SECURE_URL="https://us2.app.sysdig.com"     # your Sysdig region URL
export SYSDIG_SECURE_API_TOKEN="your-api-token"
```

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

**Never paste credentials in chat.** Skills read them from environment variables only.

### Install in Claude Code

```bash
/plugin marketplace add sysdig/skills
/plugin install headless-cloud-security@sysdig-skills
```

The marketplace install loads everything automatically: the plugin skills, the Sysdig MCP server (`.mcp.json`), and any per-skill MCP server dependencies declared in `agents/*.yaml`.

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

The `.mcp.json` and per-skill MCP server dependencies that ship inside `plugins/headless-cloud-security/` are **not** loaded by either of the two methods above. You must register the Sysdig MCP server — and any other MCP servers a skill depends on (Jira, GitHub, …) — with your agent yourself. For Claude Code, prefer the marketplace install above; it loads everything automatically.

## Skills shipped today

| Skill | What it does |
|-------|--------------|
| [`sysdig-investigate`](plugins/headless-cloud-security/skills/sysdig-investigate) | Investigate vulnerable images in a Sysdig-monitored environment. Fetches and ranks images by a chosen risk metric (finding_count, exposure_time_weighted, exposure_time_avg, sla_compliance, or actually_exploitable_findings), builds a remediation plan, optionally creates a tracking ticket (Jira / Linear / GitHub Projects) using Sysdig-side signals to determine the assignee, and hands off to /sysdig-remediate. Triggers on: "investigate", "what should I fix", "show me vulnerable images", "prioritize vulnerabilities", "/sysdig-investigate". |
| [`sysdig-onboarding`](plugins/headless-cloud-security/skills/sysdig-onboarding) | Interactive onboarding assistant for Sysdig Secure. Guides users through connecting AWS, GCP, or Azure cloud accounts and Kubernetes clusters to Sysdig. Presents security capabilities in plain language instead of jargon. Supports guided (interview) and autonomous (all-at-once) modes. Generates Terraform configurations for cloud accounts and Helm values for Kubernetes, validates prerequisites, deploys, and verifies connectivity. |
| [`sysdig-posture`](plugins/headless-cloud-security/skills/sysdig-posture) | Author Sysdig Secure Posture custom controls (Rego) and custom policies, and emit Terraform using the Sysdig provider. API access is read-only: discover supported resource kinds, validate Rego, list policies / controls. All writes happen through Terraform, never through the API. |
| [`sysdig-remediate`](plugins/headless-cloud-security/skills/sysdig-remediate) | Remediate a vulnerable container image by fetching its Critical/High CVEs from Sysdig, resolving safe fix versions through chain analysis, and producing the minimal patch (Dockerfile base bump or dependency upgrade) against the source — opens a PR/MR on GitHub or GitLab, or emits a .patch file when the user provides a local folder. Source access is mandatory. If an existing ticket key is passed in, updates that ticket with the PR link; this skill never creates new tickets — ticket creation lives in /sysdig-investigate. Persists image-to-repo mappings, PR reviewer history, and version chains across sessions. |
| [`sysdig-runtime-investigate`](plugins/headless-cloud-security/skills/sysdig-runtime-investigate) | Investigate a runtime threat detected by Sysdig end-to-end. Surfaces the highest-priority threat, enumerates affected images, scores vulnerability vs runtime correlations on a 1-5 confidence scale, deep-dives into network blast radius or suspicious-binary VT lookups depending on the event class, and hands the case off to Jira or PagerDuty. Triggers on: "investigate runtime threat", "what is this Falco alert", runtime incident triage, SOC investigation, Falco alert analysis. |

The list above is generated automatically on every publish from each skill's `SKILL.md` frontmatter.

## Repository layout

```
skills/
├── .claude-plugin/
│   └── marketplace.json                  # marketplace index (generated)
├── plugins/
│   └── headless-cloud-security/          # the published Claude Code plugin
│       ├── .claude-plugin/plugin.json
│       ├── .mcp.json                     # Sysdig MCP server declaration
│       └── skills/<skill-name>/          # one directory per skill
└── skills/
    └── <skill-name>/                     # bare-skill mirror (spec-compliant)
```

## Maintenance and contributions

This repository is published and maintained by Sysdig through an automated pipeline. **Direct pull requests are not accepted** — any direct changes will be overwritten on the next publish. See [`CONTRIBUTING.md`](./CONTRIBUTING.md).

### Reporting security issues

Do **not** disclose security findings in public forums. Email [`secops@sysdig.com`](mailto:secops@sysdig.com) with details.

## License

See [`LICENSE`](./LICENSE).

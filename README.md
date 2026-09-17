# Sysdig Headless Cloud Security

## Summary

Sysdig's cloud security expertise, packaged as agent skills that work natively in your AI environment.

## Description

Headless Cloud Security brings Sysdig's runtime-grounded security knowledge directly into Claude, so security teams can onboard, investigate, and operate cloud security workflows without leaving their AI environment.

Built for enterprises that have adopted coding agents as part of their standard toolchain, Headless Cloud Security packages over a decade of cloud security expertise as reusable skills covering environment onboarding, vulnerability management, risk analysis, and runtime threat investigation. Every action is designed to keep humans in control, with structured logging for full auditability.

Sysdig's runtime layer, powered by [Falco](https://falco.org/), provides the high-fidelity, deterministic signals that make agent-driven security workflows trustworthy. The platform adapts to how your security program operates, not the other way around.

<a id="public-beta-terms"></a>

## Terms

Use of the Sysdig Headless Cloud Security plugin (the “Plugin”) is governed by the [Sysdig Artificial Intelligence Addendum and Acceptable Use Policy](https://sysdig.com/legal/), incorporated into the agreement between Customer and Sysdig.

The Plugin incorporates agentic artificial intelligence, which may act autonomously or semi-autonomously based on Customer prompts, configured parameters, permissions, policies, and instructions to generate outputs, make recommendations, make decisions, or take actions on Customer’s behalf. Customer is solely responsible for: (i) reviewing, validating, monitoring, and supervising all outputs, decisions, recommendations, and actions generated or taken by the Plugin; and (ii) ensuring the accuracy, completeness, legality, appropriateness, and security of any resulting outputs, actions, or downstream effects.

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

> If your region isn't listed, the hosted MCP server isn't available there yet — contact your Sysdig representative about availability. If it is listed, other agents (Cursor, OpenAI Codex, OpenCode, Claude Desktop, ChatGPT, Gemini, …) can register the same server: an HTTP MCP server at your region's `/mcp/secure` URL, with OAuth — see each skill's `references/mcp-setup.md`.

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
| [`sysdig-account-setup`](plugins/headless-cloud-security/skills/sysdig-account-setup) | Sets up a newly connected Sysdig account: teams and user roles, vulnerability policies, compliance standards, and runtime threat detection — reviewing what already exists and confirming every change before applying it. |
| [`sysdig-investigate`](plugins/headless-cloud-security/skills/sysdig-investigate) | Finds and prioritizes vulnerable container images, either by working through an administrator-defined remediation plan or by filtering and sorting vulnerability findings directly. |
| [`sysdig-onboarding`](plugins/headless-cloud-security/skills/sysdig-onboarding) | Connects your cloud accounts, Kubernetes clusters, Linux hosts, and serverless workloads to Sysdig — generating the Terraform or Helm configuration, deploying it, and verifying that data arrives. |
| [`sysdig-posture`](plugins/headless-cloud-security/skills/sysdig-posture) | Writes custom security posture controls and policies for you, delivered as Terraform so you review and apply them yourself. |
| [`sysdig-remediate`](plugins/headless-cloud-security/skills/sysdig-remediate) | Fixes one vulnerable container image: identifies a safe upgrade, opens a pull request with the change, and files or updates the tracking ticket. |
| [`sysdig-runtime-investigate`](plugins/headless-cloud-security/skills/sysdig-runtime-investigate) | Investigates a detected runtime threat end to end — what happened, how far it reached, whether it relates to a known vulnerability — and hands the case to Jira or PagerDuty. |
| [`sysdig-runtime-remediate`](plugins/headless-cloud-security/skills/sysdig-runtime-remediate) | Responds to a detected runtime threat by proposing containment actions, showing what each would affect, and carrying out only the ones you approve. |
| [`sysdig-sysql`](plugins/headless-cloud-security/skills/sysdig-sysql) | Helps you write, run, and understand SysQL queries against your Sysdig security data, checking each query against the live schema before running it. |

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

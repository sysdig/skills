# Sysdig Skills

> **Headless Cloud Security** — Sysdig's runtime-grounded security expertise, packaged as agent skills that work natively in your AI environment.

Sysdig Skills brings Sysdig's cloud security knowledge directly into [Claude Code](https://docs.claude.com/en/docs/claude-code/overview) and other [Agent Skills spec](https://agentskills.io/specification)–compatible coding agents, so security teams can onboard, investigate, and operate cloud security workflows without leaving their AI environment.

Built for enterprises that have adopted coding agents as part of their standard toolchain, this repository packages over a decade of cloud security expertise as reusable skills covering environment onboarding, vulnerability management, risk analysis, and runtime threat investigation. Every action is designed to keep humans in control, with structured logging for full auditability.

Sysdig's runtime layer, powered by [Falco](https://falco.org/), provides the high-fidelity, deterministic signals that make agent-driven security workflows trustworthy.

## Available plugins

| Plugin | Description |
|--------|-------------|
| [`headless-cloud-security`](plugins/headless-cloud-security) | Sysdig Secure agent skills: cloud onboarding, API exploration, SysQL queries, UI deep links, vulnerability investigation, remediation, and zero-day monitoring. |

### Skills shipped today

| Skill | What it does |
|-------|--------------|
| [`sysdig-onboarding`](plugins/headless-cloud-security/skills/sysdig-onboarding) | Interactive onboarding assistant. Connects AWS, GCP, or Azure accounts, deploys Sysdig Shield on Kubernetes, and installs host agents. |

More skills are added as they mature — see [Maintenance and contributions](#maintenance-and-contributions).

## Prerequisites

- A **Sysdig Secure** account with API access
- A **Sysdig API token** — generate one under **Settings → Sysdig Secure API** in your Sysdig instance
- A supported AI coding agent — **Claude Code** is the primary target; **Cursor**, **OpenAI Codex**, and **OpenCode** can use the bare skills via [Compatibility with other agents](#compatibility-with-other-agents)
- **Python 3** — required by skill scripts (uses stdlib only, no `pip install` needed)

## Installation

### Claude Code (recommended)

From any Claude Code session:

```bash
# Step 1: Register Sysdig Skills as a marketplace (one-time setup)
/plugin marketplace add sysdig/skills

# Step 2: Install the Headless Cloud Security plugin
/plugin install headless-cloud-security@sysdig-skills
```

Claude Code picks up updates automatically on subsequent marketplace refreshes.

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

## Usage

Once installed, describe what you need in plain language. Examples:

- *"Onboard my AWS account to Sysdig"*
- *"Show me the highest-risk vulnerabilities in production"*
- *"Investigate this runtime alert and tell me if it's exploitable"*
- *"Generate a Terraform plan to deploy Sysdig Shield in my cluster"*

Each skill's `SKILL.md` documents its behavior, the scripts it ships, and the environment variables it reads. The agent loads the right skill automatically based on your prompt.

## Compatibility with other agents

Every skill follows the [Agent Skills specification](https://agentskills.io/specification) and is installable as a stand-alone unit. For agents other than Claude Code (Cursor, OpenAI Codex, OpenCode, …), copy or symlink the bare skill folder into the agent's skills directory:

```bash
git clone https://github.com/sysdig/skills.git ~/sysdig-skills

# Example: link every published skill into your agent's skills directory
ln -s ~/sysdig-skills/skills/* <agent-skills-dir>/
```

The bare `skills/<skill-name>/` directories at the repo root are kept in sync with the plugin contents on every promotion, so they always reflect the latest published skill set.

The `.mcp.json` and per-skill MCP server dependencies that ship inside `plugins/headless-cloud-security/` are **not** loaded by this method. You must register the Sysdig MCP server — and any other MCP servers a skill depends on (Jira, GitHub, …) — with your agent yourself. For Claude Code, prefer the marketplace install above; it loads everything automatically.

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

### Reporting issues

- **Bug reports, feature requests, feedback:** open a GitHub [issue](https://github.com/sysdig/skills/issues) — please include the skill name, the agent you are using, and steps to reproduce.
- **Security issues:** do **not** open a public issue. Email [`infosec-team@sysdig.com`](mailto:infosec-team@sysdig.com).

## License

See [`LICENSE`](./LICENSE).

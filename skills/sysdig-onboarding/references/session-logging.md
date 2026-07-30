# Session Logging — Customer Log & Environment Defaults

Two files persist across sessions with distinct roles:

- **`customer-log.md`** — Session history, issues encountered, environment
  quirks, and narrative context. This is the chronological journal.
- **`environment.yaml`** — Structured, reusable defaults (region, features,
  onboarded targets). This is the machine-readable state. See
  [environment-defaults.md](environment-defaults.md) for the schema.

## At the start of each session

- Read `environment.yaml` if it exists. Use its values to pre-fill the
  discovery interview (see the Discovery Interview Flow in SKILL.md).
- Read `customer-log.md` if it exists. Use prior context (provider quirks,
  past issues, environment notes) to anticipate problems.
- If the most recent entry's status says the configuration was generated but
  **not applied** (the config-only path), offer to apply it now — read the
  entry's next-step / owner note and rejoin the normal apply/verify path
  (Step 8 in SKILL.md) — before starting a fresh interview.

## During the session

- Document any issues encountered, workarounds applied, or environment-specific
  quirks (e.g., "AWS org has SCPs that block certain IAM actions",
  "customer uses a proxy for outbound traffic").

## At the end of each session

- Update `customer-log.md` with:
  - A short **run status sentence** (see below)
  - What was onboarded (provider, scope, features)
  - Issues encountered and how they were resolved
  - Environment-specific notes for future sessions
  - Suggested next steps

## Customer log format

Use standard session log format: date heading, run status sentence, target
(provider + scope + account ID), features enabled, issues/resolutions,
environment notes, and recommended next steps.

## Run status sentence

Every entry records a short, plain status sentence — human- and agent-readable,
**not a fixed enum**. On a normal run it can be as simple as "Applied and
verified". On the **config-only path** (the user bypassed the prereq gate or
asked for config-only output — see the "Config-only path" subsection in
`SKILL.md`) the sentence must convey four facts, in whatever concise phrasing
fits:

1. what was **generated**,
2. what was **validated** — or that validation was skipped, and why,
3. what was **not done** and **why** (missing tool / missing credentials / user
   asked for config only),
4. the **intended next step / owner** (e.g. "apply from CI/CD").

Example: `config-only — Terraform written and validated offline (terraform
validate); not applied (AWS credentials missing); apply from CI/CD`. A later
session reads this sentence to decide whether to offer to finish the apply.

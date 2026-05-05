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

## During the session

- Document any issues encountered, workarounds applied, or environment-specific
  quirks (e.g., "AWS org has SCPs that block certain IAM actions",
  "customer uses a proxy for outbound traffic").

## At the end of each session

- Update `customer-log.md` with:
  - What was onboarded (provider, scope, features)
  - Issues encountered and how they were resolved
  - Environment-specific notes for future sessions
  - Suggested next steps

## Customer log format

Use standard session log format: date heading, target (provider + scope +
account ID), features enabled, issues/resolutions, environment notes, and
recommended next steps.

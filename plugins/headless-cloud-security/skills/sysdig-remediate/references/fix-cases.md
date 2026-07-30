# sysdig-remediate — fix cases

Step 3e branches on what kind of fix is possible. Use the safe target version resolved in step 3d, then pick the matching case below.

## Case A — base OS / system package CVE (safe fix available)

- The CVE affects a package installed by the OS package manager (apt, yum, apk).
- Fix: update the `FROM` line in the Dockerfile to a newer base image version, or add a `RUN apt-get upgrade` layer.
- Action: **PR against the Dockerfile** (step 5a), plus the ticket half per the chosen deliverable.

## Case B — application dependency CVE (safe fix available)

- The CVE affects an npm, pip, maven, go, or gem package.
- Fix: update the dependency version in the relevant manifest/lockfile.
- Action: **PR against the dependency file** (step 5a), plus the ticket half per the chosen deliverable.

## Case C — no safe fix version available

- Either no patched version exists, or every candidate version introduces new Critical/High CVEs (the chain analysis in step 3d hit its 5-iteration cap).
- Action: **no PR possible — deliver the analysis as a ticket instead.**
  - If the deliverable already includes a ticket: put the full chain analysis (versions checked, why none are safe) in the ticket body's "Fix Version Resolution" section.
  - If the deliverable was `pr` only: renegotiate — _"No safe fix version exists — a PR isn't possible. I can file a full-analysis ticket instead so the work isn't lost. File it?"_ If the user declines, stop; nothing is tracked or closed.
  - A filed analysis ticket counts as "filed" for the close-when-filed policy (step 6).

## Case D — repo not located within the configured source

- The user has a configured forge (step 0b verified this), but step 3b failed to identify which repo owns the image build, and the user couldn't disambiguate.
- Action: **no PR possible.**
  - Offer to switch to `local` mode (the user provides a folder path) and re-run step 3b.
  - If they decline: deliver the ticket half (create or update) with a "source repo not found" note in the Remediation section, record the artifact, and close the job as filed (step 6).
  - If they decline the ticket too, stop; nothing is tracked or closed.

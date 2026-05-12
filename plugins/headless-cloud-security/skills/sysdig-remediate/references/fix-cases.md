# sysdig-remediate — fix cases

Step 3d branches on what kind of fix is possible. Use the safe target version resolved in step 3c, then pick the matching case below.

## Case A — base OS / system package CVE (safe fix available)

- The CVE affects a package installed by the OS package manager (apt, yum, apk).
- Fix: update the `FROM` line in the Dockerfile to a newer base image version, or add a `RUN apt-get upgrade` layer.
- Action: **suggest a PR** against the Dockerfile (step 4a).

## Case B — application dependency CVE (safe fix available)

- The CVE affects an npm, pip, maven, go, or gem package.
- Fix: update the dependency version in the relevant manifest/lockfile.
- Action: **suggest a PR** against the dependency file (step 4a).

## Case C — no safe fix version available

- Either no patched version exists, or every candidate version introduces new Critical/High CVEs (the chain analysis in step 3c hit its 5-iteration cap).
- Action: **no PR possible.**
  - If a ticket key is set (via the `ticket:` argument or step 1b), append the analysis (versions checked, why none work) to that ticket via step 4b.
  - If no ticket is set, stop and tell the user: _"No safe fix version is available. Run `/sysdig-investigate` to file a tracking ticket so this is not lost."_

## Case D — repo not located within the configured source

- The user has a configured forge (step 0a verified this), but step 3 failed to identify which repo owns the image build, and the user couldn't disambiguate.
- Action: **no PR possible.**
  - Offer to switch to `local` mode (the user provides a folder path) and re-run step 3.
  - If they decline and a ticket key is set, append a note to that ticket via step 4b.
  - If they decline and no ticket is set, stop and tell the user: _"Source repo could not be located. Provide a local folder, or run `/sysdig-investigate` to file a tracking ticket."_

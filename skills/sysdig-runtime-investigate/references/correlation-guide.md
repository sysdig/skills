# Correlation & Confidence Grading Guide

## Confidence Scores

| Score | Meaning | Example |
|-------|---------|---------|
| **5** | Direct match — finding directly enables or explains the rule | CVE in the executed binary; posture gap the rule explicitly detects |
| **4** | Strong — same execution chain or attack surface | CVE in library loaded by the triggering process; network exposure + C2 rule |
| **3** | Moderate — same component or security domain | Critical CVE in the same image; container hardening gap + container escape rule |
| **2** | Weak — same resource, different domain | *(not shown in report)* |
| **1** | Unrelated | *(not shown in report)* |

Only pairs with score `>= 4` (after boosts applied per SKILL.md) appear in the rendered case.

## MITRE-tactic alignment — gating heuristic

Before applying the heuristics below, tag each item with a MITRE ATT&CK tactic:

- **Rule tactic** — derive from the rule name and source. Examples:
  - "System Geolocation Discovery" → `Discovery` (T1082)
  - "Suspicious Outbound Connection" → `Command and Control` (T1071)
  - "Container Escape Detected" → `Privilege Escalation` (T1611)
  - "Reverse Shell" → `Command and Control` (T1059) and `Initial Access`
- **CVE tactic** — derive from CVSS attack vector + description. Examples:
  - telnetd remote auth-bypass → `Initial Access`
  - sudo local privesc → `Privilege Escalation`
  - libcurl DNS rebinding RCE → `Execution`

A rule × CVE pair scores at the heuristic level **only if the tactics align in a plausible attack chain**:

- **Same tactic**: score normally per the heuristics below.
- **Adjacent in kill chain** (e.g. Initial Access → Execution → Persistence; Discovery → Lateral Movement): score normally.
- **Distant or unrelated** tactics: cap the score at **3** regardless of what the heuristics return. The CVE may exist on the resource, but its presence does not explain the rule that fired.

This axis is what stops "Geolocation Discovery" rule from being tied to a critical telnetd CVE on the same host just because both are present — the tactics are unrelated.

## Rule-to-CVE Matching Heuristics

Apply only after the MITRE-tactic gate above lets the pair through.

1. **Package name match**: The CVE affects a package whose name appears in the rule's process name, binary path, or description. Score **5**.
2. **In-use + exploitable boost**: CVE is both `in_use: true` and `exploitable: true` in a package within the same image. Score **4** minimum (raise to 5 if package name matches a process in the rule).
3. **Same image, critical severity**: CVE is critical severity in the same container image referenced by the rule. Score **3** — only if the tactic gate did not cap it lower.
4. **CISA KEV**: KEV is no longer a floor. KEV match is a `+1` boost applied **after** the heuristics return (see "External boosts" in SKILL.md). KEV on a tactic-mismatched CVE does not lift the row above 3.
5. **Different component**: CVE is in the same resource but a different package with no connection to the rule's execution chain. Score **2** — omit.

## Rule-to-Posture Matching Heuristics

Apply only if posture data is available on the threat detail or fetched via SysQL (`Resource VIOLATES Control`). The MITRE-tactic gate also applies here: a posture control about logging won't correlate to a Discovery rule.

1. **Privilege escalation controls**: Match with rules about unauthorized execution, container escape, privilege escalation, or setuid/setgid. Score **5** if the rule detects privilege escalation directly; **4** if the rule detects execution that would benefit from escalated privileges.
2. **Network exposure controls**: Match with rules about C2 communication, data exfiltration, reverse shells, or unexpected network connections. Score **5** if the rule detects network-based threats; **4** if exposure amplifies the threat's impact.
3. **Container hardening controls** (read-only rootfs, dropped capabilities, non-root user): Match with rules about file modification, binary drift, container escape. Score **4** if the rule involves file system writes or new binaries; **3** for general container runtime rules.
4. **Resource limit controls** (CPU/memory limits): Only score **3** if the rule involves resource abuse (cryptomining, DoS). Otherwise **2** — omit.
5. **Logging/auditing controls**: Score **3** if the rule involves evasion or log tampering. Otherwise **2** — omit.

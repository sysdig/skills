# MITRE ATT&CK tactic classifier

From the rule name, rule source, and event labels, assign one MITRE tactic to the trigger event. Store it on the case as `case.tactic`. Phase 2 watchlist mapping reads this value.

| Tactic | Rule keywords / signals |
|---|---|
| `discovery` | discovery, recon, geolocation, system info, list, enumeration, scan |
| `execution` | exec, run_binary, suspicious_binary, interpreter, command, fork |
| `persistence` | cron, systemd, service install, startup, autorun, ssh key add |
| `defense_evasion` | drift, tamper, log delete, history wipe, masquerade, base64-encoded |
| `credential_access` | credential, keychain, /etc/shadow, kubernetes secret, token, dump |
| `lateral_movement` | lateral, kubectl exec, pivot, ssh from container, network in cluster |
| `collection` | tar, copy of /etc, screenshot, clipboard, archive |
| `c2` | outbound, c2, dns tunneling, http_request, reverse shell, beacon |
| `exfiltration` | exfil, large outbound, dns exfil, scp out, curl --upload |
| `impact` | crypto, miner, ransomware, destructive, drop tables |

If the rule sits cleanly in two tactics (e.g. "Reverse Shell" → `c2` + `execution`), pick the more specific one for the watchlist mapping (`c2`) and record both on `case.tactic_secondary` for the report.

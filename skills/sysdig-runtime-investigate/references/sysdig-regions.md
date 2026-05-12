# Sysdig Secure regions

Set `SYSDIG_SECURE_URL` to the host URL of your tenant's region. Pair it with `SYSDIG_SECURE_API_TOKEN`.

| Region | Host URL |
|---|---|
| US East (us1) | `https://secure.sysdig.com` |
| US West — Oregon (us2) | `https://us2.app.sysdig.com` |
| US West — GCP (us3) | `https://app.us3.sysdig.com` |
| US West — GCP Dallas (us4) | `https://app.us4.sysdig.com` |
| EU Central — Frankfurt (eu1) | `https://eu1.app.sysdig.com` |
| EU North — Stockholm (eu2) | `https://app.eu2.sysdig.com` |
| AP Sydney (au1) | `https://app.au1.sysdig.com` |
| AP Mumbai (in1) | `https://app.in1.sysdig.com` |
| AP Tokyo (jp1) | `https://app.jp1.sysdig.com` |
| ME South — Dammam (me2) | `https://app.me2.sysdig.com` |

Recommended exports:

```bash
export SYSDIG_SECURE_URL='https://eu1.app.sysdig.com'
export SYSDIG_SECURE_API_TOKEN='<token>'
```

Canonical names are `SYSDIG_SECURE_API_TOKEN` + `SYSDIG_SECURE_URL`. Legacy names — `SYSDIG_API_*`, `SYSDIG_MCP_*`, `SECURE_*` — still work.

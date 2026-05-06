# Sysdig APIs — Cloud Onboarding Verification

## Authentication

All calls use header `Authorization: Bearer <SECURE_API_TOKEN>`.

Base URL by region (see [regions.md](regions.md) for full list):
- US East (us1): `https://secure.sysdig.com`
- US West (us2): `https://us2.app.sysdig.com`
- US West GCP (us3): `https://app.us3.sysdig.com`
- US West GCP (us4): `https://app.us4.sysdig.com`
- EU Central (eu1): `https://eu1.app.sysdig.com`
- EU North (eu2): `https://app.eu2.sysdig.com`
- AP Sydney (au1): `https://app.au1.sysdig.com`
- AP Mumbai (in1): `https://app.in1.sysdig.com`
- ME South (me2): `https://app.me2.sysdig.com`

API paths are appended to the base URL, e.g. `https://secure.sysdig.com/api/cloudauth/v1/accounts`.

> **Note — Next-Gen API endpoints:** Sysdig documents a separate set of
> "Next-Gen" API endpoints at `https://api.{region}.sysdig.com` (e.g.,
> `api.us1.sysdig.com`, `api.eu1.sysdig.com`). As of 2026-03-18, these
> endpoints return 404 for the current API paths used by this skill
> (`/api/users/me`, `/api/cloudauth/v1/accounts`). They appear to serve a
> different, newer API surface. **Do not use them** for onboarding
> verification — use the base URLs above instead.

---

## `GET /api/cloudauth/v1/accounts`

List onboarded cloud accounts. Supports filtering by provider and feature
enablement status.

**Query parameters:**
- `provider` — `PROVIDER_AWS`, `PROVIDER_GCP`, `PROVIDER_AZURE`
- `featureSecureConfigPostureEnabled` — boolean
- `featureSecureThreatDetectionEnabled` — boolean
- `featureSecureIdentityEntitlementEnabled` — boolean
- `featureSecureAgentlessScanningEnabled` — boolean
- `limit`, `offset` — pagination

**Key response fields (per account):**

| Field | Description |
|---|---|
| `id` | Sysdig internal account UUID |
| `providerId` | Cloud provider account ID (e.g., AWS account number) |
| `provider` | `PROVIDER_AWS`, `PROVIDER_GCP`, `PROVIDER_AZURE` |
| `providerAlias` | Human-readable account name |
| `enabled` | Whether the account is active |
| `feature` | Object with feature enablement status |
| `components` | Array of deployed infrastructure components |

---

## `GET /api/cloudauth/v1/accounts/{accountId}`

Get details for a specific account (by Sysdig UUID, not provider ID).

**Query parameters:**
- `verbosity` — `VERBOSITY_INFO`, `VERBOSITY_FULL`, `VERBOSITY_DETAIL`

---

## `GET /api/cloudauth/v1/accounts/{accountId}/feature/{featureType}`

Get the status of a specific feature on an account.

**Feature types:**
- `FEATURE_SECURE_CONFIG_POSTURE`
- `FEATURE_SECURE_THREAT_DETECTION`
- `FEATURE_SECURE_IDENTITY_ENTITLEMENT`
- `FEATURE_SECURE_AGENTLESS_SCANNING`

---

## `POST /api/cloudauth/v1/accounts/{accountId}/validate`

Validate that the cloud account connection is working (role is
reachable, credentials are valid).

---

## Verification wrapper

Use `scripts/verify-cloud-status.sh` for safe programmatic checks:

```bash
# List all AWS accounts
verify-cloud-status.sh aws

# Check specific account
verify-cloud-status.sh aws 123456789012

# Example output:
# {
#   "sysdigAccountId": "00000000-0000-0000-0000-000000000000",
#   "providerId": "123456789012",
#   "provider": "PROVIDER_AWS",
#   "alias": "",
#   "enabled": true,
#   "features": [
#     "FEATURE_SECURE_AGENTLESS_SCANNING",
#     "FEATURE_SECURE_CONFIG_POSTURE",
#     "FEATURE_SECURE_IDENTITY_ENTITLEMENT",
#     "FEATURE_SECURE_THREAT_DETECTION"
#   ]
# }
```

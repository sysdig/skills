# Sysdig SaaS Regions

## How to Determine Your Region

Check the URL you use to log into Sysdig Secure:

| If your URL contains... | Your region is... |
|------------------------|-------------------|
| `secure.sysdig.com` or `app.sysdigcloud.com` | US East (us1) |
| `us2.app.sysdig.com` | US West (us2) |
| `app.us3.sysdig.com` | US West - GCP (us3) |
| `app.us4.sysdig.com` | US West - GCP (us4) |
| `eu1.app.sysdig.com` | EU Central (eu1) |
| `app.eu2.sysdig.com` | EU North (eu2) |
| `app.au1.sysdig.com` | AP Sydney (au1) |
| `app.in1.sysdig.com` | AP Mumbai (in1) |
| `app.jp1.sysdig.com` | AP Tokyo (jp1) |
| `app.me2.sysdig.com` | ME South (me2) |

---

## Region Details

### US East — Virginia (us1)

| Endpoint | URL |
|----------|-----|
| Secure UI | `https://secure.sysdig.com` |
| API | `https://secure.sysdig.com/api` |
| Collector | `collector.sysdigcloud.com` |
| Sysdig Secure URL (Terraform) | `https://secure.sysdig.com` |

### US West — Oregon (us2)

| Endpoint | URL |
|----------|-----|
| Secure UI | `https://us2.app.sysdig.com` |
| API | `https://us2.app.sysdig.com/api` |
| Collector | `ingest-us2.app.sysdig.com` |
| Sysdig Secure URL (Terraform) | `https://us2.app.sysdig.com` |

### US West GCP (us3)

| Endpoint | URL |
|----------|-----|
| Secure UI | `https://app.us3.sysdig.com` |
| API | `https://app.us3.sysdig.com/api` |
| Collector | `ingest.us3.sysdig.com` |
| Sysdig Secure URL (Terraform) | `https://app.us3.sysdig.com` |

### US West GCP — Dallas (us4)

| Endpoint | URL |
|----------|-----|
| Secure UI | `https://app.us4.sysdig.com` |
| API | `https://app.us4.sysdig.com/api` |
| Collector | `ingest.us4.sysdig.com` |
| Sysdig Secure URL (Terraform) | `https://app.us4.sysdig.com` |

### EU Central — Frankfurt (eu1)

| Endpoint | URL |
|----------|-----|
| Secure UI | `https://eu1.app.sysdig.com` |
| API | `https://eu1.app.sysdig.com/api` |
| Collector | `ingest-eu1.app.sysdig.com` |
| Sysdig Secure URL (Terraform) | `https://eu1.app.sysdig.com` |

### EU North — Stockholm (eu2)

| Endpoint | URL |
|----------|-----|
| Secure UI | `https://app.eu2.sysdig.com` |
| API | `https://app.eu2.sysdig.com/api` |
| Collector | `ingest.eu2.sysdig.com` |
| Sysdig Secure URL (Terraform) | `https://app.eu2.sysdig.com` |

### Asia Pacific — Sydney (au1)

| Endpoint | URL |
|----------|-----|
| Secure UI | `https://app.au1.sysdig.com` |
| API | `https://app.au1.sysdig.com/api` |
| Collector | `ingest.au1.sysdig.com` |
| Sysdig Secure URL (Terraform) | `https://app.au1.sysdig.com` |

### Asia Pacific — Mumbai (in1)

| Endpoint | URL |
|----------|-----|
| Secure UI | `https://app.in1.sysdig.com` |
| API | `https://app.in1.sysdig.com/api` |
| Collector | `ingest.in1.sysdig.com` |
| Sysdig Secure URL (Terraform) | `https://app.in1.sysdig.com` |

### Asia Pacific — Tokyo (jp1)

| Endpoint | URL |
|----------|-----|
| Secure UI | `https://app.jp1.sysdig.com` |
| API | `https://app.jp1.sysdig.com/api` |
| Collector | _see [official docs](https://docs.sysdig.com/en/docs/administration/saas-regions-and-ip-ranges/)_ |
| Sysdig Secure URL (Terraform) | `https://app.jp1.sysdig.com` |

### Middle East — Dammam (me2)

| Endpoint | URL |
|----------|-----|
| Secure UI | `https://app.me2.sysdig.com` |
| API | `https://app.me2.sysdig.com/api` |
| Collector | `ingest.me2.sysdig.com` |
| Sysdig Secure URL (Terraform) | `https://app.me2.sysdig.com` |

---

## Terraform Provider Configuration

Use the Sysdig Secure URL from the table above as `sysdig_secure_url`:

```hcl
provider "sysdig" {
  sysdig_secure_url       = "https://eu1.app.sysdig.com"  # Your region's URL
  sysdig_secure_api_token = var.sysdig_secure_api_token     # From env var
}
```

Set the API token via environment variable:
```bash
export SYSDIG_SECURE_API_TOKEN="<your-api-token>"
```

To find your API token: Sysdig → Settings → User Profile → Sysdig API Token.

---

## Official Reference

For the latest list of regions (new regions may be added over time), consult
the official documentation:

https://docs.sysdig.com/en/docs/administration/saas-regions-and-ip-ranges/

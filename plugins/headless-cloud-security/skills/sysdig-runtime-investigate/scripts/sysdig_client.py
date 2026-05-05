#!/usr/bin/env python3
"""Shared Sysdig API client. Stdlib only — no external deps."""

import json
import os
import sys
import urllib.error
import urllib.parse
import urllib.request

REGIONS = [
    ("US East (Virginia)", "https://us2.app.sysdig.com"),
    ("US West (Oregon)", "https://app.us4.sysdig.com"),
    ("US West (GCP)", "https://us4.app.sysdig.com"),
    ("EU Central (Frankfurt)", "https://eu1.app.sysdig.com"),
    ("AP South (Sydney)", "https://app.au1.sysdig.com"),
]


def _detect(*candidates):
    for name in candidates:
        val = os.environ.get(name)
        if val:
            return val
    return None


def _missing_creds_message():
    lines = [
        "Error: Sysdig credentials not found in environment.",
        "  Set one token var: SYSDIG_SECURE_API_TOKEN, SYSDIG_API_TOKEN, SECURE_API_TOKEN, or SYSDIG_MCP_API_TOKEN (legacy)",
        "  Set one host var:  SYSDIG_SECURE_URL, SYSDIG_API_HOST, SECURE_BACKEND, or SYSDIG_MCP_API_HOST (legacy)",
        "",
        "Available regions:",
    ]
    for label, url in REGIONS:
        lines.append(f"  {label}: {url}")
    return "\n".join(lines)


class SysdigClient:
    def __init__(self):
        host = _detect("SYSDIG_SECURE_URL", "SYSDIG_API_HOST", "SECURE_BACKEND", "SYSDIG_MCP_API_HOST")
        token = _detect("SYSDIG_SECURE_API_TOKEN", "SYSDIG_API_TOKEN", "SECURE_API_TOKEN", "SYSDIG_MCP_API_TOKEN")
        if not host or not token:
            print(_missing_creds_message(), file=sys.stderr)
            sys.exit(1)
        self.base_url = host.rstrip("/")
        self.token = token

    def _request(self, path, params=None, timeout=30):
        url = f"{self.base_url}{path}"
        if params:
            url += "?" + urllib.parse.urlencode(params)
        req = urllib.request.Request(
            url, headers={"Authorization": f"Bearer {self.token}"}
        )
        return urllib.request.urlopen(req, timeout=timeout)

    def get(self, path, params=None):
        """Fetch JSON. Exit 1 on network/auth errors, exit 2 on 404."""
        try:
            with self._request(path, params) as resp:
                return json.loads(resp.read())
        except urllib.error.HTTPError as e:
            body = e.read().decode("utf-8", errors="replace")[:500]
            print(f"Error: HTTP {e.code} from {path}: {body}", file=sys.stderr)
            sys.exit(2 if e.code == 404 else 1)
        except urllib.error.URLError as e:
            print(f"Error: network error to {path}: {e}", file=sys.stderr)
            sys.exit(1)

    def get_optional(self, path, params=None):
        """Like get(), but returns None on any failure instead of exiting."""
        try:
            with self._request(path, params, timeout=10) as resp:
                return json.loads(resp.read())
        except Exception:
            return None

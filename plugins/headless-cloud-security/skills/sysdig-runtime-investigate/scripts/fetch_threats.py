#!/usr/bin/env python3
"""Fetch threats from the Sysdig Threats Engine API.

Note: /api/v1/threatsEngine is currently a private Sysdig API (not part of
the public OpenAPI). Exits 2 on 404 so callers can detect that the endpoint
is unavailable in the target tenant and fall back to the events API.
"""

import argparse
import json
import os
import sys
import time

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from sysdig_client import SysdigClient  # noqa: E402

BASE = "/api/v1/threatsEngine"


def _unwrap_list(data, key):
    """Sysdig endpoints sometimes wrap arrays in {'data': [...]} or {key: [...]}."""
    if isinstance(data, list):
        return data
    if isinstance(data, dict):
        return data.get("data") or data.get(key) or []
    return []


def fetch_recent_groups(client, hours, limit):
    now_ns = int(time.time() * 1_000_000_000)
    from_ns = now_ns - (hours * 3600 * 1_000_000_000)
    return client.get(
        f"{BASE}/groups",
        params={
            "from": str(from_ns),
            "to": str(now_ns),
            "limit": limit,
            "status": "open",
            "sort": "lastSignal,desc",
        },
    )


def fetch_group_detail(client, group_id):
    group = client.get(f"{BASE}/groups/{group_id}")
    resources = client.get(f"{BASE}/groups/{group_id}/resources")
    threats = client.get(f"{BASE}/groups/{group_id}/threats")
    return {
        "group": group,
        "resources": _unwrap_list(resources, "resources"),
        "threats": _unwrap_list(threats, "threats"),
    }


def fetch_threat_detail(client, threat_id):
    """Fetch a single threat. Falls back to fetch_group_detail when the
    Threats Engine returns 404 — the agent regularly mixes up group IDs
    (returned by --list) and threat IDs, and a transparent fallback saves
    a retry per investigation."""
    detail = client.get_optional(f"{BASE}/threats/{threat_id}")
    if detail is not None:
        return detail
    fallback = client.get_optional(f"{BASE}/groups/{threat_id}")
    if fallback is not None:
        return {
            "_resolved_as": "group",
            "_note": "ID was not a threat ID; resolved as a group instead",
            "group": fallback,
            "resources": _unwrap_list(
                client.get_optional(f"{BASE}/groups/{threat_id}/resources"),
                "resources",
            ),
            "threats": _unwrap_list(
                client.get_optional(f"{BASE}/groups/{threat_id}/threats"),
                "threats",
            ),
        }
    print(
        f"Error: HTTP 404 from /api/v1/threatsEngine/{{threats,groups}}/{threat_id}",
        file=sys.stderr,
    )
    sys.exit(2)


def fetch_top_n(client, hours, limit):
    """Top N open groups, each enriched with its first threat detail."""
    raw = fetch_recent_groups(client, hours, limit)
    groups = _unwrap_list(raw, "groups")
    if not groups and hours < 72:
        raw = fetch_recent_groups(client, 72, limit)
        groups = _unwrap_list(raw, "groups")

    enriched = []
    for group in groups[:limit]:
        gid = group.get("id") or group.get("groupId")
        if not gid:
            continue
        threats = _unwrap_list(
            client.get_optional(f"{BASE}/groups/{gid}/threats"), "threats"
        )
        first_threat = None
        if threats:
            tid = threats[0].get("id") or threats[0].get("threatId")
            if tid:
                first_threat = client.get_optional(f"{BASE}/threats/{tid}")
        enriched.append({"group": group, "first_threat": first_threat})

    return {"groups": enriched}


def main():
    parser = argparse.ArgumentParser(
        description="Fetch threats from Sysdig Threats Engine API."
    )
    mode = parser.add_mutually_exclusive_group(required=True)
    mode.add_argument(
        "--list",
        type=int,
        metavar="N",
        nargs="?",
        const=5,
        help="Top N open groups with first threat each (default 5)",
    )
    mode.add_argument("--threat", metavar="ID", help="Single threat detail")
    mode.add_argument("--group", metavar="ID", help="Group + resources + threats")
    parser.add_argument(
        "--hours", type=int, default=24, help="Time window for --list (default 24)"
    )
    args = parser.parse_args()

    client = SysdigClient()

    if args.list is not None:
        result = fetch_top_n(client, args.hours, args.list)
    elif args.threat:
        result = fetch_threat_detail(client, args.threat)
    else:
        result = fetch_group_detail(client, args.group)

    json.dump(result, sys.stdout, indent=2)
    print()


if __name__ == "__main__":
    main()

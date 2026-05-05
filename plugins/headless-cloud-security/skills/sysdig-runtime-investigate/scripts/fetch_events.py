#!/usr/bin/env python3
"""Fetch runtime events from the Sysdig events API.

Endpoint: /secure/events/v1/events (public, in OpenAPI).
Filter syntax: Sysdig filter expression — `field op "value" [and ...]` —
passed as a single URL-encoded `filter` query param.
Severity is numeric: 0 = critical, 1 = high, 2 = medium, 3 = low, 4 = info.
"""

import argparse
import json
import os
import sys
import time

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from sysdig_client import SysdigClient  # noqa: E402

BASE = "/secure/events/v1/events"


def _ns(seconds_ago=0):
    return int((time.time() - seconds_ago) * 1_000_000_000)


def _build_filter(parts):
    """Combine non-empty Sysdig filter expressions with `and`."""
    return " and ".join(p for p in parts if p)


def fetch_recent(client, hours, limit, severity_max=1):
    """Recent events with severity <= severity_max (default critical+high)."""
    params = {
        "from": str(_ns(hours * 3600)),
        "to": str(_ns(0)),
        "filter": f"severity<={severity_max}",
        "limit": limit,
    }
    return client.get(BASE, params=params)


def fetch_event(client, event_id):
    return client.get(f"{BASE}/{event_id}")


def fetch_prior(client, rule, cluster, namespace, workload, hostname, hours, limit):
    """Prior events matching a rule on a workload/host — used by Phase 2 lateral candidates lookup."""
    parts = []
    if rule:
        parts.append(f'ruleName="{rule}"')
    if cluster:
        parts.append(f'kubernetes.cluster.name="{cluster}"')
    if namespace:
        parts.append(f'kubernetes.namespace.name="{namespace}"')
    if workload:
        parts.append(f'kubernetes.workload.name="{workload}"')
    if hostname:
        parts.append(f'host.hostName="{hostname}"')

    expr = _build_filter(parts)
    if not expr:
        print("Error: --prior requires at least one of --rule/--cluster/--namespace/--workload/--hostname", file=sys.stderr)
        sys.exit(1)

    params = {
        "from": str(_ns(hours * 3600)),
        "to": str(_ns(0)),
        "filter": expr,
        "limit": limit,
    }
    return client.get(BASE, params=params)


def main():
    parser = argparse.ArgumentParser(
        description="Fetch Sysdig runtime events (public events API)."
    )
    mode = parser.add_mutually_exclusive_group(required=True)
    mode.add_argument("--recent", action="store_true", help="Recent high+critical events")
    mode.add_argument("--event", metavar="ID", help="Single event detail")
    mode.add_argument("--prior", action="store_true", help="Prior events for Phase 2 lateral candidates lookup")

    parser.add_argument("--hours", type=int, default=24, help="Time window in hours")
    parser.add_argument("--limit", type=int, default=20, help="Max events")
    parser.add_argument("--severity-max", type=int, default=1,
                        help="Max severity number (0=crit,1=high,2=med,3=low). --recent only")
    parser.add_argument("--rule", help="--prior: rule name match")
    parser.add_argument("--cluster", help="--prior: kubernetes cluster")
    parser.add_argument("--namespace", help="--prior: kubernetes namespace")
    parser.add_argument("--workload", help="--prior: kubernetes workload")
    parser.add_argument("--hostname", help="--prior: host hostname")

    args = parser.parse_args()
    client = SysdigClient()

    if args.recent:
        result = fetch_recent(client, args.hours, args.limit, args.severity_max)
    elif args.event:
        result = fetch_event(client, args.event)
    else:
        result = fetch_prior(
            client, args.rule, args.cluster, args.namespace, args.workload,
            args.hostname, args.hours, args.limit,
        )

    json.dump(result, sys.stdout, indent=2)
    print()


if __name__ == "__main__":
    main()

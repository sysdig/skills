#!/usr/bin/env python3
"""Fetch and analyze runtime vulnerability scan results from Sysdig.

Returns pre-analyzed JSON with summary counts and high-signal CVEs.
High-signal = critical+in-use, exploitable, or CISA KEV.

Endpoint: /secure/vulnerability/v1/runtime-results (public OpenAPI).
Filter syntax: Sysdig filter expression (same as the events API).
"""

import argparse
import json
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from sysdig_client import SysdigClient  # noqa: E402

BASE = "/secure/vulnerability/v1"
VULNS_DETAIL_BASE = "/api/scanning/vulns/v2"


# Image scope-label name varies by tenant. Try these in order; first that
# returns 2xx wins. If all fail, the script tells the caller to fall back
# to the MCP `list_vulnerability_findings_by_image` tool.
_IMAGE_LABEL_CANDIDATES = ["image.name", "container.image.repo", "imageRepo"]


def build_filter(args, image_label="image.name"):
    parts = []
    if args.cluster and args.namespace and args.workload:
        parts.append(f'kubernetes.cluster.name="{args.cluster}"')
        parts.append(f'kubernetes.namespace.name="{args.namespace}"')
        parts.append(f'kubernetes.workload.name="{args.workload}"')
    if args.host:
        parts.append(f'host.hostName="{args.host}"')
    if args.image:
        parts.append(f'{image_label}="{args.image}"')
    return " and ".join(parts) if parts else None


def fetch_runtime_results(client, args):
    """Hit /runtime-results, retrying with alternate image labels on 4xx.
    Returns the raw response dict, or None if all candidates were rejected."""
    candidates = _IMAGE_LABEL_CANDIDATES if args.image else [None]
    for label in candidates:
        filter_str = (
            build_filter(args, image_label=label) if label else build_filter(args)
        )
        if not filter_str:
            return None
        result = client.get_optional(
            f"{BASE}/runtime-results", params={"filter": filter_str, "limit": 5}
        )
        if result is not None:
            return result
    if args.image:
        print(
            "Error: runtime-results rejected all image label candidates "
            f"({_IMAGE_LABEL_CANDIDATES}). Fall back to MCP "
            "list_vulnerability_findings_by_image for image-level vulns.",
            file=sys.stderr,
        )
    return None


def parse_severity(v):
    sev_val = v.get("severity", "unknown")
    if isinstance(sev_val, dict):
        return sev_val.get("value", "unknown").lower()
    return str(sev_val).lower()


def parse_cvss(v):
    cvss_obj = v.get("cvssScore", {})
    if not isinstance(cvss_obj, dict):
        return 0.0
    val = cvss_obj.get("value", {})
    if isinstance(val, dict):
        return float(val.get("score", 0))
    if isinstance(val, (int, float)):
        return float(val)
    return 0.0


def parse_cisa_kev(v):
    kev = v.get("cisaKev", False)
    if isinstance(kev, bool):
        return kev
    if isinstance(kev, dict):
        return len(kev) > 0
    return bool(kev)


def parse_fix_version(v):
    fix = v.get("fixVersion", "") or ""
    return "" if fix == "None" else fix.strip()


def fetch_cve_description(client, cve_name):
    resp = client.get_optional(f"{VULNS_DETAIL_BASE}/vulnerability/{cve_name}")
    return resp.get("description", "") if resp else ""


def analyze_scan(detailed_result, client=None):
    """Cross-reference packages and vulnerabilities, return clean analysis."""
    packages = detailed_result.get("packages", {})
    vulns = detailed_result.get("vulnerabilities", {})

    vuln_to_pkgs = {}
    for pkg in packages.values():
        for vref in pkg.get("vulnerabilitiesRefs") or []:
            vuln_to_pkgs.setdefault(vref, []).append({
                "name": pkg.get("name", ""),
                "version": pkg.get("version", ""),
                "isRunning": pkg.get("isRunning", False),
            })

    total = {"critical": 0, "high": 0, "medium": 0, "low": 0}
    in_use = {"critical": 0, "high": 0, "medium": 0, "low": 0}
    exploitable_count = 0
    cisa_kev_count = 0
    fix_available_count = 0

    high_signal = []
    seen_cves = set()

    for vid, v in vulns.items():
        sev = parse_severity(v)
        cvss = parse_cvss(v)
        exploitable = v.get("exploitable", False) or False
        cisa_kev = parse_cisa_kev(v)
        fix_version = parse_fix_version(v)
        has_fix = bool(fix_version)
        cve_name = v.get("name", vid)

        pkgs = vuln_to_pkgs.get(vid, [])
        is_in_use = any(p["isRunning"] for p in pkgs)
        pkg_names = sorted({p["name"] for p in pkgs if p["name"]})

        if sev in total:
            total[sev] += 1
        if is_in_use and sev in in_use:
            in_use[sev] += 1
        if exploitable:
            exploitable_count += 1
        if cisa_kev:
            cisa_kev_count += 1
        if has_fix:
            fix_available_count += 1

        if sev not in ("critical", "high"):
            continue

        is_high_signal = is_in_use or exploitable or cisa_kev
        if not is_high_signal or cve_name in seen_cves:
            continue
        seen_cves.add(cve_name)

        if cisa_kev:
            rank = 0
        elif exploitable and sev == "critical" and is_in_use:
            rank = 1
        elif sev == "critical" and has_fix:
            rank = 2
        elif exploitable:
            rank = 3
        else:
            rank = 4

        high_signal.append({
            "cve": cve_name,
            "description": "",
            "cvss": cvss,
            "severity": sev,
            "exploitable": exploitable,
            "in_use": is_in_use,
            "cisa_kev": cisa_kev,
            "fix_available": has_fix,
            "fix_version": fix_version,
            "packages": pkg_names,
            "_rank": rank,
        })

    high_signal.sort(key=lambda x: (x["_rank"], -x["cvss"]))
    high_signal = high_signal[:10]
    for entry in high_signal:
        del entry["_rank"]

    if client:
        for entry in high_signal:
            entry["description"] = fetch_cve_description(client, entry["cve"])

    policy_result = "unknown"
    for key in detailed_result:
        if "policy" in key.lower():
            val = detailed_result[key]
            if isinstance(val, str) and val.lower() in ("passed", "failed"):
                policy_result = val.lower()

    return {
        "total_by_severity": total,
        "in_use_by_severity": in_use,
        "exploitable_count": exploitable_count,
        "cisa_kev_count": cisa_kev_count,
        "fix_available_count": fix_available_count,
        "policy_result": policy_result,
        "high_signal_vulns": high_signal,
    }


def main():
    parser = argparse.ArgumentParser(description="Fetch and analyze Sysdig runtime vulns")
    parser.add_argument("--cluster", help="Kubernetes cluster name")
    parser.add_argument("--namespace", help="Kubernetes namespace")
    parser.add_argument("--workload", help="Kubernetes workload name")
    parser.add_argument("--host", help="Hostname (host or docker_on_host bucket)")
    parser.add_argument("--image", help="Container image repo (with --host for docker_on_host)")
    parser.add_argument("--result-id", help="Fetch a specific scan result by ID")
    args = parser.parse_args()

    client = SysdigClient()

    if args.result_id:
        detail = client.get(f"{BASE}/results/{args.result_id}")
        analysis = analyze_scan(detail, client)
        json.dump({"scan_found": True, **analysis}, sys.stdout, indent=2)
        print()
        return

    if not (args.cluster and args.namespace and args.workload) and not args.host:
        print(
            "Error: provide --cluster/--namespace/--workload, --host [--image], or --result-id",
            file=sys.stderr,
        )
        sys.exit(1)

    results = fetch_runtime_results(client, args)
    if results is None:
        json.dump({"scan_found": False}, sys.stdout, indent=2)
        print()
        return

    data = results.get("data", results) if isinstance(results, dict) else results
    if isinstance(data, dict):
        items = data.get("data", [])
    else:
        items = data if isinstance(data, list) else []

    if not items:
        json.dump({"scan_found": False}, sys.stdout, indent=2)
        print()
        return

    best_item = items[0]
    for item in items:
        if item.get("runningVulnTotalBySeverity"):
            best_item = item
            break

    result_id = best_item.get("resultId") or best_item.get("id")
    if not result_id:
        json.dump({"scan_found": False}, sys.stdout, indent=2)
        print()
        return

    detail = client.get(f"{BASE}/results/{result_id}")
    analysis = analyze_scan(detail, client)
    json.dump({"scan_found": True, **analysis}, sys.stdout, indent=2)
    print()


if __name__ == "__main__":
    main()

"""Interpret an unfiltered run without converting zero findings to approval.

Usage: python3 scripts/codeql-audit/summarize_results.py EVIDENCE_DIRECTORY CODEQL

Only the two explicit official Swift suites are selected. The skill catalog
has no third-party Swift pack. The CLI requests local in addition to default;
support is query-dependent: Swift's PathInjectionConfig uses RemoteFlowSource,
while CommandInjectionConfig uses FlowSource (both local and remote). The flag
does not rewrite those configurations. No guessed YAML model is injected.
sources.csv, sinks.csv and calls.csv support human model-gap review, particularly
FileHandle, POSIX open/read, AppKit file selection and security-scoped URLs.
Missing models and non-Swift packaging code remain separate audit limitations.
"""

import csv
import json
import subprocess
import sys
from pathlib import Path

from check_evidence import query_paths


def query_rule_ids(inventory: Path, codeql: Path) -> frozenset[str]:
    identifiers: list[str] = []
    for query in sorted(query_paths(inventory)):
        result = subprocess.run(
            [str(codeql), "resolve", "metadata", "--format=json", "--", query],
            check=True, capture_output=True, text=True,
        )
        metadata = json.loads(result.stdout)
        if not isinstance(metadata, dict) or not isinstance(metadata.get("id"), str) or not metadata["id"]:
            raise ValueError(f"Resolved query lacks a rule ID: {query}")
        identifiers.append(metadata["id"])
    if len(identifiers) != len(set(identifiers)):
        raise ValueError("Resolved query inventory contains duplicate rule IDs")
    return frozenset(identifiers)


def diagnostic_count(path: Path) -> int:
    with path.open(encoding="utf-8", newline="") as stream:
        rows = list(csv.reader(stream))
    if not rows or len(rows[0]) != 3 or any(len(row) != 3 for row in rows[1:]):
        raise ValueError(f"Missing or malformed diagnostic CSV: {path.name}")
    return len(rows) - 1


def finding_counts(path: Path, expected_rules: frozenset[str]) -> dict[str, int]:
    if not expected_rules:
        raise ValueError("Expected rule inventory must not be empty")
    document = json.loads(path.read_text(encoding="utf-8"))
    if not isinstance(document, dict) or document.get("version") != "2.1.0":
        raise ValueError("Expected SARIF 2.1.0")
    runs = document.get("runs")
    if not isinstance(runs, list) or not runs:
        raise ValueError("SARIF contains no runs")
    counts: dict[str, int] = {}
    for run in runs:
        if not isinstance(run, dict) or not isinstance(run.get("results"), list):
            raise ValueError("SARIF run lacks a results array")
        tool = run.get("tool")
        if not isinstance(tool, dict) or not isinstance(tool.get("driver"), dict):
            raise ValueError("SARIF run lacks tool provenance")
        driver = tool["driver"]
        if driver.get("name") != "CodeQL" or driver.get("semanticVersion") != "2.27.2":
            raise ValueError("SARIF must identify the pinned CodeQL 2.27.2 tool")
        rules = driver.get("rules")
        if not isinstance(rules, list) or not rules or any(
            not isinstance(rule, dict) or not isinstance(rule.get("id"), str) or not rule["id"]
            for rule in rules
        ):
            raise ValueError("SARIF lacks a nonempty rule inventory")
        actual_rules = frozenset(rule["id"] for rule in rules)
        # CodeQL serializes diagnostic queries as notification descriptors,
        # not rule descriptors. All selected queries must still be present.
        notifications = driver.get("notifications", [])
        if not isinstance(notifications, list) or any(
            not isinstance(item, dict) or not isinstance(item.get("id"), str) or not item["id"]
            for item in notifications
        ):
            raise ValueError("SARIF notification descriptors are malformed")
        notification_ids = frozenset(item["id"] for item in notifications)
        missing = expected_rules - actual_rules - notification_ids
        if missing or actual_rules - expected_rules or len(rules) != len(actual_rules):
            raise ValueError(
                f"SARIF rule inventory mismatch: missing={sorted(missing)}, "
                f"unexpected={sorted(actual_rules - expected_rules)}"
            )
        invocations = run.get("invocations")
        if not isinstance(invocations, list) or not invocations:
            raise ValueError("SARIF lacks execution provenance")
        for invocation in invocations:
            if not isinstance(invocation, dict) or invocation.get("executionSuccessful") is not True:
                raise ValueError("SARIF reports unsuccessful or unspecified execution")
        for result in run["results"]:
            if not isinstance(result, dict) or not isinstance(result.get("ruleId"), str):
                raise ValueError("SARIF result lacks ruleId")
            rule_id: str = result["ruleId"]
            if rule_id not in actual_rules:
                raise ValueError(f"SARIF result references an unexpected rule: {rule_id}")
            counts[rule_id] = counts.get(rule_id, 0) + 1
    return counts


def main(evidence: Path, codeql: Path) -> None:
    expected_rules = query_rule_ids(evidence / "queries.json", codeql)
    counts = finding_counts(evidence / "raw/results.sarif", expected_rules)
    sources = diagnostic_count(evidence / "sources.csv")
    sinks = diagnostic_count(evidence / "sinks.csv")
    calls = diagnostic_count(evidence / "calls.csv")
    report = {
        "status": "analysis-complete-review-required",
        "findings_by_rule": counts,
        "total_findings": sum(counts.values()),
        "validated_rule_ids": sorted(expected_rules),
        "recognized_sources": sources,
        "recognized_sinks": sinks,
        "project_calls": calls,
        "requested_threat_models": ["default", "local"],
        "model_review": "PENDING: compare file API call sites with recognized sources/sinks",
        "limitations": [
            "No custom Swift models; missing FileHandle/POSIX/AppKit coverage is not a pass",
            "Swift local coverage is query-dependent; PathInjectionConfig is remote-only despite the CLI flag",
            "SwiftPM direct-build configuration only; inactive conditional code is not proven covered",
            "Not a scan of Python/shell packaging code or an assurance of filesystem race safety",
            "Zero results never establishes security or release approval",
        ],
    }
    (evidence / "results/summary.json").write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")


if __name__ == "__main__":
    main(Path(sys.argv[1]), Path(sys.argv[2]))

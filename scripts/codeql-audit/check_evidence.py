"""Fail closed on incomplete AST extraction, finalization, or suite selection.

The pinned upstream quality guard additionally checks baseline LoC, the source
archive, and extractor errors. This gate requires every tracked Sources Swift
file to have AST evidence; source archive membership alone is insufficient.
"""

import csv
import json
import sys
from pathlib import Path


def query_paths(path: Path) -> frozenset[str]:
    value = json.loads(path.read_text(encoding="utf-8"))
    if not isinstance(value, list) or not value or not all(isinstance(item, str) for item in value):
        raise ValueError(f"Invalid or empty resolved query inventory: {path.name}")
    return frozenset(value)


def verify_suite(selected: frozenset[str], official: frozenset[str]) -> None:
    if not official or selected != official:
        raise ValueError("Suite must equal the complete union of both official suites")


def verify_extraction(expected: frozenset[str], extracted: frozenset[str]) -> None:
    if not expected or expected != extracted:
        raise ValueError(
            f"AST coverage mismatch: missing={sorted(expected - extracted)}, "
            f"unexpected={sorted(extracted - expected)}, expected_count={len(expected)}"
        )


def extracted_paths(path: Path) -> frozenset[str]:
    with path.open(encoding="utf-8", newline="") as stream:
        reader = csv.DictReader(stream)
        if reader.fieldnames != ["path", "lines"]:
            raise ValueError("Unexpected extracted-files CSV columns; update the gate explicitly")
        rows = list(reader)
    if any(not row["path"] or int(row["lines"]) <= 0 for row in rows):
        raise ValueError("Extracted source file has no AST lines")
    return frozenset(row["path"] for row in rows)


def verify_quality(path: Path) -> None:
    value = json.loads(path.read_text(encoding="utf-8"))
    if not isinstance(value, dict) or value.get("finalised") is not True:
        raise ValueError("CodeQL database is not finalized")
    for key in ("baseline_loc", "project_files"):
        count = value.get(key)
        if type(count) is not int or count <= 0:
            raise ValueError(f"Missing or empty database metric: {key}")
    if type(value.get("extractor_errors")) is not int or value["extractor_errors"] != 0:
        raise ValueError("Extractor errors must be exactly zero")


def main(evidence: Path) -> None:
    verify_quality(evidence / "database-quality.json")
    selected = query_paths(evidence / "queries.json")
    verify_suite(selected, query_paths(evidence / "official-queries.json"))
    expected = frozenset((evidence / "expected-files.txt").read_text(encoding="utf-8").splitlines())
    verify_extraction(expected, extracted_paths(evidence / "extracted-files.csv"))
    (evidence / "coverage.txt").write_text(
        f"PASS: {len(expected)} of {len(expected)} tracked Sources Swift files have AST evidence.\n"
        f"PASS: complete official suite union ({len(selected)} queries).\n"
        "PASS: finalized database, nonzero baseline/source archive, zero extractor errors.\n",
        encoding="utf-8",
    )


if __name__ == "__main__":
    main(Path(sys.argv[1]))

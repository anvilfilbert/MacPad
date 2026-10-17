"""Report supplemental local flows and exact file-API sites requiring manual review.

This is not a new framework model. The supplement retains shipped path barriers
and flow steps and uses shipped LocalFlowSource/PathInjectionSink. FileHandle
read(upToCount:), POSIX descriptors, and AppKit selected URLs may lack models.
Same-line source/sink matches are navigation aids, not proof of complete modeling.
Review the boundary CSV against the raw diagnostics and source at the recorded SHA.
"""

import csv
import json
import sys
from pathlib import Path

from summarize_results import finding_counts


def rows(path: Path) -> list[tuple[str, int, str]]:
    with path.open(encoding="utf-8", newline="") as stream:
        values = list(csv.reader(stream))
    if not values or len(values[0]) != 3 or any(len(row) != 3 for row in values[1:]):
        raise ValueError(f"Invalid source/sink/call diagnostic: {path.name}")
    return [(path, int(line), label) for path, line, label in values[1:]]


def file_boundaries(calls: list[tuple[str, int, str]]) -> list[tuple[str, int, str]]:
    # Deliberately broad navigation inventory, not a security finding classifier.
    names = ("open", "read", "write", "FileHandle", "contents", "coordinate", "url", "URL", "bookmark")
    return [row for row in calls if any(name in row[2] for name in names)]


def main(evidence: Path) -> None:
    sources = rows(evidence / "sources.csv")
    sinks = rows(evidence / "sinks.csv")
    boundaries = file_boundaries(rows(evidence / "calls.csv"))
    source_locations = {(path, line) for path, line, _ in sources}
    sink_locations = {(path, line) for path, line, _ in sinks}
    with (evidence / "supplement/file-boundaries-review.csv").open("w", encoding="utf-8", newline="") as stream:
        writer = csv.writer(stream)
        writer.writerow(["path", "line", "call", "source_at_line", "sink_at_line"])
        for path, line, call in boundaries:
            writer.writerow([path, line, call, (path, line) in source_locations, (path, line) in sink_locations])
    report = {
        "status": "supplement-executed-local-input-coverage-not-complete",
        "review_candidates_by_rule": finding_counts(
            evidence / "supplement/raw/results.sarif", frozenset({"macpad-audit/local-path-flow-review"}),
        ),
        "modeled_local_sources": sum(label.startswith("local:") for _, _, label in sources),
        "file_boundary_calls_for_review": len(boundaries),
        "required_manual_checks": [
            "Map exact CSV call sites to source/sink diagnostics; inspect FileHandle and POSIX read boundaries",
            "Trace AppKit selected URLs and bookmark-derived paths through open/save/coordinated writes",
            "Distinguish intended user-selected files from unauthorized path influence",
            "Verify regular-file checks, FIFO rejection, bounded reads, symlinks and external-change protection",
            "Review non-Swift packaging separately; zero supplemental flows does not establish coverage",
        ],
    }
    (evidence / "supplement/results/summary.json").write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")


if __name__ == "__main__":
    main(Path(sys.argv[1]))

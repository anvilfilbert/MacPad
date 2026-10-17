"""Integration checks for evidence gates and artifact preparation; no app build."""

import json
import os
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

from check_evidence import extracted_paths, verify_extraction, verify_suite
from publish_evidence import sanitize
from summarize_results import finding_counts
from summarize_local_inputs import main as summarize_local_inputs


class EvidenceTests(unittest.TestCase):
    def test_non_ci_preflight_retains_actionable_log_without_building(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory) / "audit"
            result = subprocess.run(
                ["bash", str(Path(__file__).with_name("run.sh")), directory, "0" * 40, str(root)],
                check=False, capture_output=True, env=os.environ | {"GITHUB_ACTIONS": "false"},
            )
            self.assertNotEqual(result.returncode, 0)
            log = (root / "evidence/build.log").read_text(encoding="utf-8")
            self.assertIn("expected GITHUB_ACTIONS=true; observed not true", log)
            self.assertIn("No extraction attempted", log)
            self.assertFalse((root / "tools").exists())
            self.assertFalse((root / "codeql.db").exists())

    def test_complete_evidence_passes_and_partial_evidence_fails(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / "database-quality.json").write_text(json.dumps({
                "finalised": True, "baseline_loc": 12, "project_files": 2, "extractor_errors": 0,
            }), encoding="utf-8")
            for name in ("queries.json", "official-queries.json"):
                (root / name).write_text('["security.ql", "experimental.ql"]', encoding="utf-8")
            (root / "expected-files.txt").write_text("Sources/Core.swift\nSources/App.swift\n", encoding="utf-8")
            (root / "extracted-files.csv").write_text(
                '"path","lines"\n"Sources/Core.swift",8\n"Sources/App.swift",4\n', encoding="utf-8",
            )
            command = [sys.executable, str(Path(__file__).with_name("check_evidence.py")), str(root)]
            subprocess.run(command, check=True, capture_output=True, text=True)
            self.assertIn("2 of 2", (root / "coverage.txt").read_text(encoding="utf-8"))
            (root / "extracted-files.csv").write_text('"path","lines"\n"Sources/Core.swift",8\n', encoding="utf-8")
            result = subprocess.run(command, check=False, capture_output=True, text=True)
            self.assertNotEqual(result.returncode, 0)
            self.assertIn("Sources/App.swift", result.stderr)

    def test_empty_inventory_and_dropped_queries_fail(self) -> None:
        with self.assertRaises(ValueError):
            verify_extraction(frozenset(), frozenset())
        with self.assertRaises(ValueError):
            verify_suite(frozenset({"security.ql"}), frozenset({"security.ql", "experimental.ql"}))
        with self.assertRaises(ValueError):
            verify_suite(frozenset(), frozenset())

    def test_finalization_and_extraction_errors_fail(self) -> None:
        from check_evidence import verify_quality

        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "quality.json"
            for finalized, errors, lines in ((False, 0, 1), (True, 1, 1), (True, 0, 0)):
                with self.subTest(finalized=finalized, errors=errors, lines=lines):
                    path.write_text(json.dumps({
                        "finalised": finalized, "extractor_errors": errors,
                        "baseline_loc": lines, "project_files": 1,
                    }), encoding="utf-8")
                    with self.assertRaises(ValueError):
                        verify_quality(path)

    def test_archived_file_without_ast_lines_fails(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "extracted.csv"
            path.write_text('"path","lines"\n"Sources/App.swift",0\n', encoding="utf-8")
            with self.assertRaises(ValueError):
                extracted_paths(path)

    def test_sarif_interpretation_preserves_rules_and_rejects_failed_execution(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "results.sarif"
            path.write_text(json.dumps({"version": "2.1.0", "runs": [{
                "tool": {"driver": {"name": "CodeQL", "semanticVersion": "2.27.2", "rules": [{"id": "swift/path-injection"}]}},
                "results": [{"ruleId": "swift/path-injection"}],
                "invocations": [{"executionSuccessful": True}],
            }]}), encoding="utf-8")
            expected = frozenset({"swift/path-injection"})
            self.assertEqual(finding_counts(path, expected), {"swift/path-injection": 1})
            with self.assertRaisesRegex(ValueError, "rule inventory mismatch"):
                finding_counts(path, expected | {"swift/command-injection"})
            path.write_text(json.dumps({"version": "2.1.0", "runs": [{
                "tool": {"driver": {"name": "CodeQL", "semanticVersion": "2.27.2", "rules": [{"id": "swift/path-injection"}]}},
                "results": [], "invocations": [{"executionSuccessful": False}],
            }]}), encoding="utf-8")
            with self.assertRaises(ValueError):
                finding_counts(path, expected)

    def test_sarif_missing_tool_provenance_cannot_claim_completion(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "results.sarif"
            path.write_text(json.dumps({"version": "2.1.0", "runs": [{
                "results": [], "invocations": [{"executionSuccessful": True}],
            }]}), encoding="utf-8")
            with self.assertRaisesRegex(ValueError, "tool provenance"):
                finding_counts(path, frozenset({"swift/path-injection"}))

    def test_sarif_diagnostic_queries_use_notification_descriptors(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "results.sarif"
            path.write_text(json.dumps({"version": "2.1.0", "runs": [{
                "tool": {"driver": {
                    "name": "CodeQL", "semanticVersion": "2.27.2",
                    "rules": [{"id": "swift/path-injection"}],
                    "notifications": [{"id": "swift/diagnostics/extraction-errors"}],
                }},
                "results": [], "invocations": [{"executionSuccessful": True}],
            }]}), encoding="utf-8")
            expected = frozenset({"swift/path-injection", "swift/diagnostics/extraction-errors"})
            self.assertEqual(finding_counts(path, expected), {})

    def test_privacy_redaction_preserves_relative_source_and_rejects_secrets(self) -> None:
        prefix = "/" + "Users" + "/example/work"
        raw = json.dumps({"uri": f"{prefix}/Sources/App.swift", "message": "finding preserved"})
        cleaned = json.loads(sanitize(raw, ((prefix, "$WORKSPACE"),)))
        self.assertEqual(cleaned["uri"], "$WORKSPACE/Sources/App.swift")
        self.assertEqual(cleaned["message"], "finding preserved")
        with self.assertRaises(ValueError):
            sanitize(prefix, ())
        with self.assertRaises(ValueError):
            sanitize("gh" + "p_" + "a" * 30, ())

    def test_artifact_preparation_preserves_both_sarif_copies_and_rejects_private_data(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory) / "audit"
            evidence = root / "evidence"
            (evidence / "raw").mkdir(parents=True)
            (evidence / "results").mkdir()
            sarif = json.dumps({"version": "2.1.0", "runs": [{"results": [{
                "ruleId": "example", "message": {"text": "preserved"},
                "uri": str(root / "source/Sources/App.swift"),
            }]}]})
            for folder in ("raw", "results"):
                (evidence / folder / "results.sarif").write_text(sarif, encoding="utf-8")
            destination = Path(directory) / "artifact"
            command = [sys.executable, str(Path(__file__).with_name("publish_evidence.py")), str(root)]
            environment = os.environ | {"GITHUB_WORKSPACE": str(root), "RUNNER_TEMP": directory}
            subprocess.run(command + [str(destination)], check=True, env=environment, capture_output=True)
            self.assertEqual(
                (destination / "raw/results.sarif").read_bytes(),
                (destination / "results/results.sarif").read_bytes(),
            )
            self.assertNotIn(directory, (destination / "raw/results.sarif").read_text(encoding="utf-8"))
            self.assertEqual(len(json.loads((destination / "artifact-sha256.json").read_text(encoding="utf-8"))), 2)
            (evidence / "build.log").write_text("gh" + "p_" + "x" * 30, encoding="utf-8")
            rejected = Path(directory) / "rejected-artifact"
            result = subprocess.run(command + [str(rejected)], check=False, env=environment, capture_output=True)
            self.assertNotEqual(result.returncode, 0)
            self.assertFalse(rejected.exists())

    def test_local_supplement_keeps_unmodeled_file_calls_visible(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            evidence = Path(directory)
            (evidence / "supplement/raw").mkdir(parents=True)
            (evidence / "supplement/results").mkdir()
            (evidence / "sources.csv").write_text(
                'path,line,kind\nSources/Editor.swift,10,local: external\n', encoding="utf-8",
            )
            (evidence / "sinks.csv").write_text('path,line,kind\n', encoding="utf-8")
            (evidence / "calls.csv").write_text(
                'path,line,target\nSources/Editor.swift,12,call to read(upToCount:)\n', encoding="utf-8",
            )
            (evidence / "supplement/raw/results.sarif").write_text(json.dumps({
                "version": "2.1.0", "runs": [{
                    "tool": {"driver": {
                        "name": "CodeQL", "semanticVersion": "2.27.2",
                        "rules": [{"id": "macpad-audit/local-path-flow-review"}],
                    }},
                    "results": [], "invocations": [{"executionSuccessful": True}],
                }],
            }), encoding="utf-8")
            summarize_local_inputs(evidence)
            report = json.loads((evidence / "supplement/results/summary.json").read_text(encoding="utf-8"))
            self.assertEqual(report["status"], "supplement-executed-local-input-coverage-not-complete")
            self.assertEqual(report["modeled_local_sources"], 1)
            self.assertEqual(report["file_boundary_calls_for_review"], 1)
            self.assertIn(
                'Sources/Editor.swift,12,call to read(upToCount:),False,False',
                (evidence / "supplement/file-boundaries-review.csv").read_text(encoding="utf-8"),
            )


if __name__ == "__main__":
    unittest.main()

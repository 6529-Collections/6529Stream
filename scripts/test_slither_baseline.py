#!/usr/bin/env python3
"""Focused tests for the normalized first-party Slither baseline gate."""

from __future__ import annotations

import copy
import importlib.util
import json
import tempfile
import unittest
from contextlib import redirect_stderr, redirect_stdout
from io import StringIO
from pathlib import Path
from types import SimpleNamespace
from unittest.mock import patch


CHECKER_PATH = Path(__file__).with_name("check_slither_baseline.py")
CHECKER_SPEC = importlib.util.spec_from_file_location(
    "check_slither_baseline", CHECKER_PATH
)
assert CHECKER_SPEC is not None and CHECKER_SPEC.loader is not None
checker = importlib.util.module_from_spec(CHECKER_SPEC)
CHECKER_SPEC.loader.exec_module(checker)

REPO_ROOT = Path(__file__).resolve().parents[1]
BASELINE_PATH = REPO_ROOT / "ops" / "SLITHER_BASELINE.json"
MARKDOWN_PATH = REPO_ROOT / "ops" / "SLITHER_BASELINE.md"


def load_baseline() -> dict[str, object]:
    with BASELINE_PATH.open(encoding="utf-8") as handle:
        return json.load(handle)


def raw_element(
    path: str,
    name: str,
    start: int,
    end: int,
    *,
    element_type: str = "function",
    signature: str = "",
) -> dict[str, object]:
    return {
        "type": element_type,
        "name": name,
        "source_mapping": {
            "filename_relative": path,
            "filename_absolute": f"D:/first-checkout/{path}",
            "filename_short": path,
            "start": 123,
            "length": 45,
            "starting_column": 2,
            "ending_column": 9,
            "lines": list(range(start, end + 1)),
        },
        "type_specific_fields": {"signature": signature},
    }


def raw_detector() -> dict[str, object]:
    return {
        "id": "unstable-slither-id",
        "check": "unused-return",
        "impact": "Medium",
        "confidence": "Medium",
        "description": "presentation text is deliberately not identity",
        "elements": [
            raw_element(
                "smart-contracts/Example.sol", "settle", 10, 20, signature="settle()"
            ),
            raw_element(
                "smart-contracts/Example.sol",
                "ignored",
                17,
                17,
                element_type="expression",
            ),
            raw_element(
                "smart-contracts/Example.sol", "helper", 30, 35, signature="helper()"
            ),
        ],
    }


class SlitherBaselineTests(unittest.TestCase):
    def assert_invalid(self, data: dict[str, object], expected: str) -> None:
        with self.assertRaises(checker.SlitherBaselineError) as raised:
            checker.validate_baseline_data(REPO_ROOT, data)
        self.assertIn(expected, str(raised.exception))

    def test_committed_baseline_and_markdown_validate(self) -> None:
        data = checker.validate_baseline(REPO_ROOT, BASELINE_PATH, MARKDOWN_PATH)
        self.assertEqual(data["counts"], {"High": 3, "Medium": 30, "total": 33})
        self.assertEqual(len(data["findings"]), 33)
        self.assertEqual(
            MARKDOWN_PATH.read_text(encoding="utf-8"), checker.render_markdown(data)
        )

    def test_committed_triage_boundary_is_exact_and_all_open(self) -> None:
        rows = load_baseline()["findings"]
        triage: dict[str, int] = {}
        for row in rows:
            triage[row["triage_class"]] = triage.get(row["triage_class"], 0) + 1
            self.assertEqual(row["status"], "Open")
            self.assertEqual(row["source_kind"], "first_party_production")
        self.assertEqual(triage, checker.EXPECTED_TRIAGE_COUNTS)

    def test_cli_requires_one_explicit_mode(self) -> None:
        with redirect_stderr(StringIO()):
            with self.assertRaises(SystemExit):
                checker.parse_args([])
            with self.assertRaises(SystemExit):
                checker.parse_args(["--baseline-only", "--run-slither"])

    def test_candidate_report_normalizes_without_current_baseline_validation(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            raw_path = root / "raw.json"
            output_path = root / "candidate.json"
            raw_path.write_text(
                json.dumps(
                    {
                        "success": True,
                        "error": None,
                        "results": {"detectors": [raw_detector()]},
                    }
                ),
                encoding="utf-8",
            )

            result = checker.main(
                [
                    "--repo-root",
                    str(root),
                    "--candidate-slither-json",
                    str(raw_path),
                    "--candidate-output",
                    str(output_path),
                ]
            )

            self.assertEqual(result, 0)
            report = json.loads(output_path.read_text(encoding="utf-8"))
            self.assertEqual(
                report["schema_version"], checker.CANDIDATE_SCHEMA_VERSION
            )
            self.assertEqual(
                report["scope_counts"]["first_party_production"]["total"], 1
            )
            self.assertEqual(len(report["first_party_production_findings"]), 1)
            self.assertNotIn("status", report["first_party_production_findings"][0])

    def test_candidate_report_refuses_canonical_output(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            raw_path = Path(temp_dir) / "raw.json"
            raw_path.write_text(
                json.dumps({"success": True, "error": None, "results": {}}),
                encoding="utf-8",
            )
            error = StringIO()
            with redirect_stderr(error):
                result = checker.main(
                    [
                        "--repo-root",
                        str(REPO_ROOT),
                        "--candidate-slither-json",
                        str(raw_path),
                        "--candidate-output",
                        str(BASELINE_PATH),
                    ]
                )
            self.assertEqual(result, 1)
            self.assertIn("cannot overwrite", error.getvalue())

    def test_candidate_report_refuses_input_output_alias(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            raw_path = root / "raw.json"
            raw_contents = json.dumps(
                {"success": True, "error": None, "results": {}}
            )
            raw_path.write_text(raw_contents, encoding="utf-8")
            error = StringIO()
            with redirect_stderr(error):
                result = checker.main(
                    [
                        "--repo-root",
                        str(root),
                        "--candidate-slither-json",
                        "raw.json",
                        "--candidate-output",
                        str(raw_path.resolve()),
                    ]
                )
            self.assertEqual(result, 1)
            self.assertIn("cannot overwrite", error.getvalue())
            self.assertEqual(raw_path.read_text(encoding="utf-8"), raw_contents)

    def test_ci_and_release_workflows_retain_live_slither_gates(self) -> None:
        ci = (REPO_ROOT / ".github/workflows/ci.yml").read_text(encoding="utf-8")
        release = (REPO_ROOT / ".github/workflows/release-mode.yml").read_text(
            encoding="utf-8"
        )
        documentation = (REPO_ROOT / "docs/slither.md").read_text(encoding="utf-8")
        self.assertIn("slither-baseline:", ci)
        self.assertIn("timeout-minutes: 45", ci)
        self.assertIn("45-minute timeout", documentation)
        self.assertIn("version: v1.7.1", ci)
        self.assertIn("solc-select install 0.8.19", ci)
        self.assertIn("solc-select use 0.8.19", ci)
        self.assertIn("make slither-baseline-check", ci)
        self.assertIn("solc-select install 0.8.19", release)
        self.assertIn("solc-select use 0.8.19", release)
        self.assertIn("make slither-baseline-check", release)
        self.assertLess(
            release.index("make slither-baseline-check"),
            release.index("scripts/check_release_mode.py --phase"),
        )

    def test_baseline_only_cli_succeeds(self) -> None:
        output = StringIO()
        with redirect_stdout(output):
            result = checker.main(
                ["--repo-root", str(REPO_ROOT), "--baseline-only"]
            )
        self.assertEqual(result, 0)
        self.assertIn("schema, provenance, and Markdown mirror", output.getvalue())

    def test_fingerprint_ignores_presentation_metadata_and_secondary_order(self) -> None:
        first = raw_detector()
        second = copy.deepcopy(first)
        second["id"] = "another-unstable-id"
        second["description"] = "different wording and absolute checkout"
        second["elements"][0]["source_mapping"].update(
            {
                "filename_absolute": "C:/another/worktree/smart-contracts/Example.sol",
                "filename_short": "Example.sol",
                "start": 999999,
                "length": 2,
                "starting_column": 40,
                "ending_column": 41,
            }
        )
        second["elements"] = [
            second["elements"][0],
            second["elements"][2],
            second["elements"][1],
        ]
        normalized_first = checker.normalize_detector(first)
        normalized_second = checker.normalize_detector(second)
        self.assertIsNotNone(normalized_first)
        self.assertEqual(normalized_first, normalized_second)

    def test_fingerprint_changes_when_semantic_node_changes(self) -> None:
        first = raw_detector()
        second = copy.deepcopy(first)
        second["elements"][1]["name"] = "differentIgnoredNode"
        left = checker.normalize_detector(first)
        right = checker.normalize_detector(second)
        self.assertNotEqual(left["fingerprint"], right["fingerprint"])

    def test_slither_json_must_report_valid_success(self) -> None:
        detector = raw_detector()
        with self.assertRaisesRegex(
            checker.SlitherBaselineError, "success=true and error=null"
        ):
            checker.normalized_slither_findings(
                {"success": False, "error": "compile failed", "results": {}}
            )
        with self.assertRaisesRegex(
            checker.SlitherBaselineError, "duplicate fingerprints"
        ):
            checker.normalized_slither_findings(
                {
                    "success": True,
                    "error": None,
                    "results": {"detectors": [detector, copy.deepcopy(detector)]},
                }
            )

    def test_primary_source_classification_is_fail_closed(self) -> None:
        self.assertEqual(
            checker.classify_source("smart-contracts/Math.sol"), "vendored"
        )
        self.assertEqual(
            checker.classify_source("smart-contracts/NewModule.sol"),
            "first_party_production",
        )
        self.assertEqual(checker.classify_source("test/Foo.t.sol"), "test")
        self.assertEqual(checker.classify_source("script/Deploy.s.sol"), "script")
        self.assertEqual(checker.classify_source("lib/Foo.sol"), "other")

    def test_production_hash_ignores_test_and_script_only_changes(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            for relative, value in (
                ("smart-contracts/A.sol", "contract A {}\n"),
                ("test/A.t.sol", "contract ATest {}\n"),
                ("script/A.s.sol", "contract ADeploy {}\n"),
            ):
                path = root / relative
                path.parent.mkdir(parents=True, exist_ok=True)
                path.write_text(value, encoding="utf-8", newline="\n")
            initial = checker.solidity_tree_sha256(root)
            (root / "test/A.t.sol").write_text("changed test\n", encoding="utf-8")
            (root / "script/A.s.sol").write_text("changed script\n", encoding="utf-8")
            self.assertEqual(checker.solidity_tree_sha256(root), initial)
            (root / "smart-contracts/A.sol").write_text(
                "contract A { uint256 value; }\n", encoding="utf-8"
            )
            self.assertNotEqual(checker.solidity_tree_sha256(root), initial)

    def test_baseline_rejects_capture_count_tampering(self) -> None:
        data = load_baseline()
        data["capture_counts"]["High"] += 1
        data["capture_counts"]["total"] += 1
        self.assert_invalid(data, "capture_counts must be")

    def test_baseline_rejects_stale_source_hash(self) -> None:
        data = load_baseline()
        data["provenance"]["solidity_tree_sha256"] = "sha256:" + "0" * 64
        self.assert_invalid(data, "solidity_tree_sha256 is stale")

    def test_baseline_rejects_capture_provenance_tampering(self) -> None:
        mutations = (
            ("analyzed_commit", "0" * 40, "analyzed_commit must be"),
            ("captured_at_utc", "2026-07-22T10:02:34Z", "captured_at_utc must be"),
            ("capture_command", "slither arbitrary", "capture_command must be"),
            ("gate_command", "slither arbitrary --fail-none", "gate_command must be"),
            ("capture_native_exit_code", 123, "capture_native_exit_code must retain"),
            ("raw_json_size_bytes", 1, "raw_json_size_bytes must be"),
            ("raw_json_sha256", "sha256:" + "0" * 64, "raw_json_sha256 must be"),
        )
        for field, value, message in mutations:
            with self.subTest(field=field):
                data = load_baseline()
                data["provenance"][field] = value
                self.assert_invalid(data, message)

    def test_baseline_rejects_stale_fingerprint(self) -> None:
        data = load_baseline()
        data["findings"][0]["fingerprint"] = "sha256:" + "0" * 64
        self.assert_invalid(data, "fingerprint is stale")

    def test_baseline_rejects_missing_secondary_source_anchor(self) -> None:
        data = load_baseline()
        row = next(item for item in data["findings"] if len(item["semantic_elements"]) > 1)
        element = next(item for item in row["semantic_elements"] if item != row["source"])
        element["path"] = "smart-contracts/DoesNotExist.sol"
        row["semantic_elements"].sort(key=checker.semantic_sort_key)
        row["fingerprint"] = checker.semantic_fingerprint(row)
        self.assert_invalid(data, "points to missing source")

    def test_baseline_rejects_unreviewed_design_row_classification(self) -> None:
        data = load_baseline()
        row = next(
            item for item in data["findings"] if item["detector"] == "arbitrary-send-eth"
        )
        row["triage_class"] = "pending_disposition"
        self.assert_invalid(data, "design-review detector")

    def test_live_compare_reports_exact_scope_counts(self) -> None:
        baseline = load_baseline()
        actual = [checker.finding_identity(row) for row in baseline["findings"]]
        diagnostic = copy.deepcopy(actual[0])
        diagnostic["source"]["path"] = "test/Diagnostic.t.sol"
        for element in diagnostic["semantic_elements"]:
            element["path"] = "test/Diagnostic.t.sol"
        diagnostic["fingerprint"] = checker.semantic_fingerprint(diagnostic)
        counts = checker.compare_live_findings(baseline, actual + [diagnostic])
        self.assertEqual(counts["first_party_production"], checker.EXPECTED_COUNTS)
        self.assertEqual(counts["test"], {"High": 1, "Medium": 0, "total": 1})

    def test_live_compare_fails_on_addition_and_removal(self) -> None:
        baseline = load_baseline()
        actual = [checker.finding_identity(row) for row in baseline["findings"]]
        changed = actual[0]
        old_source = copy.deepcopy(changed["source"])
        changed["source"]["start_line"] += 1
        changed["source"]["end_line"] += 1
        for element in changed["semantic_elements"]:
            if element == old_source:
                element["start_line"] += 1
                element["end_line"] += 1
        changed["fingerprint"] = checker.semantic_fingerprint(changed)
        with self.assertRaises(checker.SlitherBaselineError) as raised:
            checker.compare_live_findings(baseline, actual)
        message = str(raised.exception)
        self.assertIn("unreviewed first-party row", message)
        self.assertIn("stale/removed baseline row", message)

    def test_live_command_is_high_medium_only_and_fail_none(self) -> None:
        command = checker.slither_command(Path("result.json"))
        for flag in (
            "--exclude-low",
            "--exclude-informational",
            "--exclude-optimization",
            "--json-types",
            "--fail-none",
        ):
            self.assertIn(flag, command)
        self.assertEqual(command[command.index("--json-types") + 1], "detectors")

    def test_render_markdown_mode_writes_deterministic_mirror(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            output_path = Path(temp_dir) / "SLITHER_BASELINE.md"
            result = checker.main(
                [
                    "--repo-root",
                    str(REPO_ROOT),
                    "--baseline",
                    str(BASELINE_PATH),
                    "--markdown",
                    str(output_path),
                    "--render-markdown",
                ]
            )
            self.assertEqual(result, 0)
            self.assertEqual(
                output_path.read_text(encoding="utf-8"),
                checker.render_markdown(load_baseline()),
            )

    def test_version_parsers_require_exact_tokens(self) -> None:
        self.assertEqual(
            checker.parse_forge_version("forge Version: 1.7.1\nCommit SHA: abc"),
            "1.7.1",
        )
        self.assertEqual(
            checker.parse_forge_version("forge Version: 1.7.10"), "1.7.10"
        )
        self.assertNotEqual(
            checker.parse_forge_version("forge Version: 1.7.10"),
            checker.EXPECTED_FOUNDRY_VERSION,
        )
        self.assertEqual(
            checker.parse_solc_version(
                "solc, the solidity compiler commandline interface\n"
                "Version: 0.8.19+commit.7dd6d404.Windows.msvc"
            ),
            "0.8.19",
        )
        self.assertEqual(
            checker.parse_solc_version("Version: 0.8.190+commit.example"),
            "0.8.190",
        )
        self.assertNotEqual(
            checker.parse_solc_version("Version: 0.8.190+commit.example"),
            checker.EXPECTED_SOLC_VERSION,
        )

    def test_live_run_rejects_nonzero_native_exit(self) -> None:
        failed = SimpleNamespace(returncode=7, stdout="", stderr="native failure")
        with patch.object(checker, "validate_live_tool_versions"), patch.object(
            checker.subprocess, "run", return_value=failed
        ):
            with self.assertRaisesRegex(
                checker.SlitherBaselineError, "exited 7 despite --fail-none"
            ):
                checker.run_slither(REPO_ROOT)


if __name__ == "__main__":
    unittest.main()

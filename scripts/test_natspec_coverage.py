#!/usr/bin/env python3
"""Focused tests for the NatSpec coverage checker."""

from __future__ import annotations

import importlib.util
import sys
import tempfile
import unittest
from contextlib import redirect_stderr, redirect_stdout
from io import StringIO
from pathlib import Path


SCRIPT_PATH = Path(__file__).with_name("check_natspec_coverage.py")
SPEC = importlib.util.spec_from_file_location("check_natspec_coverage", SCRIPT_PATH)
assert SPEC is not None and SPEC.loader is not None
checker = importlib.util.module_from_spec(SPEC)
sys.modules[SPEC.name] = checker
SPEC.loader.exec_module(checker)


def write_text(path: Path, value: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(value, encoding="utf-8", newline="\n")


def write_json(path: Path, value: object) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    checker.write_json(path, value)


def surface_report(*, functions: list[dict], events: list[dict], errors: list[dict]) -> dict:
    return {
        "schema_version": checker.SURFACE_SCHEMA,
        "contracts": {
            "Example": {
                "source": "smart-contracts/Example.sol",
                "functions": functions,
                "events": events,
                "custom_errors": errors,
            }
        },
    }


def function(name: str, signature: str) -> dict:
    return {"name": name, "signature": signature}


def event(name: str, signature: str) -> dict:
    return {"name": name, "signature": signature}


def error(name: str, signature: str) -> dict:
    return {"name": name, "signature": signature}


class NatSpecCoverageTests(unittest.TestCase):
    def test_accepts_committed_baseline(self) -> None:
        repo_root = Path(__file__).resolve().parents[1]
        baseline = repo_root / checker.DEFAULT_BASELINE
        if not baseline.exists():
            self.skipTest("NatSpec baseline is generated later in the PR")

        with redirect_stdout(StringIO()), redirect_stderr(StringIO()):
            result = checker.main(["--repo-root", str(repo_root)])

        self.assertEqual(result, 0)

    def test_accepts_documented_surface(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            report_path = root / checker.DEFAULT_SURFACE_REPORT
            baseline_path = root / checker.DEFAULT_BASELINE
            write_text(
                root / "smart-contracts/Example.sol",
                """// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

contract Example {
    /// @notice Emitted when a value changes.
    event ValueChanged(uint256 indexed value);

    /// @notice Reverts when value is zero.
    error ValueZero();

    /// @notice Returns the current value.
    function value() external view returns (uint256) {
        return 1;
    }
}
""",
            )
            write_json(
                report_path,
                surface_report(
                    functions=[function("value", "value()")],
                    events=[event("ValueChanged", "ValueChanged(uint256)")],
                    errors=[error("ValueZero", "ValueZero()")],
                ),
            )
            write_json(baseline_path, checker.baseline_from_gaps([]))

            with redirect_stdout(StringIO()), redirect_stderr(StringIO()):
                result = checker.main(
                    [
                        "--repo-root",
                        str(root),
                        "--surface-report",
                        str(report_path),
                        "--baseline",
                        str(baseline_path),
                    ]
                )

            self.assertEqual(result, 0)

    def test_rejects_missing_function_natspec_without_baseline(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            report_path = root / checker.DEFAULT_SURFACE_REPORT
            baseline_path = root / checker.DEFAULT_BASELINE
            write_text(
                root / "smart-contracts/Example.sol",
                """// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

contract Example {
    function value() external view returns (uint256) {
        return 1;
    }
}
""",
            )
            write_json(
                report_path,
                surface_report(
                    functions=[function("value", "value()")],
                    events=[],
                    errors=[],
                ),
            )
            write_json(baseline_path, checker.baseline_from_gaps([]))

            result = checker.main(
                [
                    "--repo-root",
                    str(root),
                    "--surface-report",
                    str(report_path),
                    "--baseline",
                    str(baseline_path),
                ]
            )

            self.assertEqual(result, 1)

    def test_rejects_missing_event_and_error_natspec_without_baseline(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            report_path = root / checker.DEFAULT_SURFACE_REPORT
            baseline_path = root / checker.DEFAULT_BASELINE
            write_text(
                root / "smart-contracts/Example.sol",
                """// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

contract Example {
    event ValueChanged(uint256 indexed value);
    error ValueZero();
}
""",
            )
            write_json(
                report_path,
                surface_report(
                    functions=[],
                    events=[event("ValueChanged", "ValueChanged(uint256)")],
                    errors=[error("ValueZero", "ValueZero()")],
                ),
            )
            write_json(baseline_path, checker.baseline_from_gaps([]))

            result = checker.main(
                [
                    "--repo-root",
                    str(root),
                    "--surface-report",
                    str(report_path),
                    "--baseline",
                    str(baseline_path),
                ]
            )

            self.assertEqual(result, 1)

    def test_accepts_explicit_baseline_for_current_gap(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            report_path = root / checker.DEFAULT_SURFACE_REPORT
            baseline_path = root / checker.DEFAULT_BASELINE
            write_text(
                root / "smart-contracts/Example.sol",
                """// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

contract Example {
    function value() external view returns (uint256) {
        return 1;
    }
}
""",
            )
            report = surface_report(
                functions=[function("value", "value()")],
                events=[],
                errors=[],
            )
            write_json(report_path, report)
            write_json(baseline_path, checker.baseline_from_gaps(checker.coverage_gaps(root, report)))

            with redirect_stdout(StringIO()), redirect_stderr(StringIO()):
                result = checker.main(
                    [
                        "--repo-root",
                        str(root),
                        "--surface-report",
                        str(report_path),
                        "--baseline",
                        str(baseline_path),
                    ]
                )

            self.assertEqual(result, 0)

    def test_rejects_stale_baseline_after_doc_is_added(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            report_path = root / checker.DEFAULT_SURFACE_REPORT
            baseline_path = root / checker.DEFAULT_BASELINE
            source = root / "smart-contracts/Example.sol"
            write_text(
                source,
                """// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

contract Example {
    function value() external view returns (uint256) {
        return 1;
    }
}
""",
            )
            report = surface_report(
                functions=[function("value", "value()")],
                events=[],
                errors=[],
            )
            write_json(report_path, report)
            write_json(baseline_path, checker.baseline_from_gaps(checker.coverage_gaps(root, report)))
            write_text(
                source,
                """// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

contract Example {
    /// @notice Returns the value.
    function value() external view returns (uint256) {
        return 1;
    }
}
""",
            )

            result = checker.main(
                [
                    "--repo-root",
                    str(root),
                    "--surface-report",
                    str(report_path),
                    "--baseline",
                    str(baseline_path),
                ]
            )

            self.assertEqual(result, 1)

    def test_tracks_public_variable_getter_natspec(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            report_path = root / checker.DEFAULT_SURFACE_REPORT
            write_text(
                root / "smart-contracts/Example.sol",
                """// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

contract Example {
    uint256 public value;

    /// @notice Documented generated getter.
    uint256 public documentedValue;
}
""",
            )
            report = surface_report(
                functions=[
                    function("value", "value()"),
                    function("documentedValue", "documentedValue()"),
                ],
                events=[],
                errors=[],
            )
            write_json(report_path, report)
            gaps = checker.coverage_gaps(root, report)

            self.assertEqual(len(gaps), 1)
            self.assertEqual(gaps[0].item.signature, "value()")
            self.assertEqual(gaps[0].status, "public_variable_getter_missing_natspec")


if __name__ == "__main__":
    unittest.main(verbosity=2)

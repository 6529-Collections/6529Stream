#!/usr/bin/env python3
"""Focused tests for the metadata aggregate release checker."""

from __future__ import annotations

import importlib.util
import json
import sys
import tempfile
import unittest
from pathlib import Path


SCRIPT_PATH = Path(__file__).with_name("check_metadata_aggregate_release.py")
REPO_ROOT = SCRIPT_PATH.parent.parent
SPEC = importlib.util.spec_from_file_location("check_metadata_aggregate_release", SCRIPT_PATH)
assert SPEC is not None and SPEC.loader is not None
checker = importlib.util.module_from_spec(SPEC)
sys.modules[SPEC.name] = checker
SPEC.loader.exec_module(checker)


def write(path: Path, value: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(value, encoding="utf-8", newline="\n")


def fixture_repo(root: Path, per_surface_functions: int, include_all: bool = True) -> None:
    write(
        root / "docs" / "collection-metadata-contract.md",
        "# CMC\n\nThe initial aggregate ceiling is 80 external/public\n"
        "functions across those genesis metadata surfaces, including inherited\n"
        "views, with a v1 soft target of 60 or fewer.\n",
    )
    surfaces = checker.METADATA_SURFACES if include_all else checker.METADATA_SURFACES[:2]
    contracts = [
        {
            "name": name,
            "functions": [f"fn{i}()" for i in range(per_surface_functions)],
            "bytecodeHash": "0x" + "ab" * 32,
        }
        for name in surfaces
    ]
    write(
        root / "release-artifacts" / "latest" / "protocol-surface-report.json",
        json.dumps({"contracts": contracts}),
    )


class MetadataAggregateTests(unittest.TestCase):
    def test_committed_repo_passes_vacuously_with_missing_surfaces(self) -> None:
        aggregate, hard, soft, missing = checker.validate_repo(REPO_ROOT)
        self.assertEqual((hard, soft), (80, 60))
        self.assertTrue(missing)

    def test_accepts_aggregate_under_ceiling(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            fixture_repo(root, per_surface_functions=10)
            aggregate, hard, soft, missing = checker.validate_repo(root)
            self.assertEqual(aggregate, 50)
            self.assertEqual(missing, [])

    def test_missing_surface_reports_vacuous_pass(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            fixture_repo(root, per_surface_functions=10, include_all=False)
            aggregate, _, _, missing = checker.validate_repo(root)
            self.assertEqual(aggregate, 0)
            self.assertEqual(len(missing), 3)

    def test_rejects_aggregate_over_hard_ceiling(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            fixture_repo(root, per_surface_functions=17)
            with self.assertRaises(checker.MetadataAggregateError) as ctx:
                checker.validate_repo(root)
            self.assertIn("exceeds the pinned hard ceiling 80", str(ctx.exception))


if __name__ == "__main__":
    unittest.main()

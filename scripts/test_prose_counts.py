#!/usr/bin/env python3
"""Focused tests for the prose count checker."""

from __future__ import annotations

import importlib.util
import sys
import tempfile
import unittest
from pathlib import Path


SCRIPT_PATH = Path(__file__).with_name("check_prose_counts.py")
REPO_ROOT = SCRIPT_PATH.parent.parent
SPEC = importlib.util.spec_from_file_location("check_prose_counts", SCRIPT_PATH)
assert SPEC is not None and SPEC.loader is not None
checker = importlib.util.module_from_spec(SPEC)
sys.modules[SPEC.name] = checker
SPEC.loader.exec_module(checker)


def write(path: Path, value: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(value, encoding="utf-8", newline="\n")


def matrix_text(total: str = "5", numbered: str = "3", probes: str = "two") -> str:
    return (
        "# Matrix\n\nThis inventory is exhaustive: "
        f"{total} deployable production contracts — the {numbered} numbered "
        f"entries below plus the {probes} Permanent-class probe contracts of "
        "entries 4-5 (one at this revision).\n\n"
        "the fourteen [AA-GATES] suites\n\n"
        "Mandatory genesis contracts:\n\n```text\n 1 StreamCore\n 2 StreamGov\n"
        " 3 StreamRegistry\n 4 GGP probe\n 5 Shared probe\n```\n"
    )


def fixture_repo(root: Path, matrix: str) -> None:
    write(root / "docs" / "launch-conformance-matrix.md", matrix)
    write(
        root / "docs" / "stream-long-term-architecture.md",
        "# Umbrella\n\n| Parameter | Host | Normative home |\n| --- | --- | --- |\n"
        "| `A` | core | [`docs/a.md`](a.md) |\n",
    )
    gates = "\n".join(f"{n}. Gate {n}." for n in range(1, 15))
    write(
        root / "docs" / "stream-artist-authority.md",
        "# Artist\n\n## Conformance Gates [AA-GATES]\n\n" + gates + "\n",
    )
    write(
        root / "docs" / "collection-metadata-contract.md",
        "# CMC\n\n## Genesis Museum Schema Set [CMC-GENESIS-SCHEMAS]\n\n"
        "| Schema name | Minimal required fields (home) |\n| --- | --- |\n"
        "| `STREAM_A_V1` | a |\n| `STREAM_B_V1` | b |\n",
    )


class ProseCountTests(unittest.TestCase):
    def test_committed_repo_counts_derive(self) -> None:
        counts = checker.validate_repo(REPO_ROOT)
        self.assertEqual(counts["numbered"], 35)
        self.assertEqual(counts["probes"], 23)
        self.assertEqual(counts["total"], 58)

    def test_accepts_consistent_fixture(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            fixture_repo(root, matrix_text())
            counts = checker.validate_repo(root)
            self.assertEqual(counts["total"], 5)
            self.assertEqual(counts["schemas"], 2)

    def test_rejects_owning_statement_arithmetic_drift(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            fixture_repo(root, matrix_text(total="6"))
            with self.assertRaises(checker.ProseCountError) as ctx:
                checker.validate_repo(root)
            self.assertIn("arithmetic drifts", str(ctx.exception))

    def test_rejects_restated_total_outside_owner(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            fixture_repo(root, matrix_text())
            write(
                root / "docs" / "status.md",
                "# Status\n\nGenesis ships 5 deployable production contracts.\n",
            )
            with self.assertRaises(checker.ProseCountError) as ctx:
                checker.validate_repo(root)
            self.assertIn("restates the deployable-contract total", str(ctx.exception))

    def test_rejects_suite_count_drift(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            fixture_repo(root, matrix_text())
            gates = "\n".join(f"{n}. Gate {n}." for n in range(1, 14))
            write(
                root / "docs" / "stream-artist-authority.md",
                "# Artist\n\n## Conformance Gates [AA-GATES]\n\n" + gates + "\n",
            )
            with self.assertRaises(checker.ProseCountError) as ctx:
                checker.validate_repo(root)
            self.assertIn("[AA-GATES] suites", str(ctx.exception))


if __name__ == "__main__":
    unittest.main()

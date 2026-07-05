#!/usr/bin/env python3
"""Focused tests for the baseline-record header checker."""

from __future__ import annotations

import importlib.util
import sys
import tempfile
import unittest
from contextlib import redirect_stderr, redirect_stdout
from io import StringIO
from pathlib import Path


SCRIPT_PATH = Path(__file__).with_name("check_baseline_record_headers.py")
REPO_ROOT = SCRIPT_PATH.parent.parent
SPEC = importlib.util.spec_from_file_location("check_baseline_record_headers", SCRIPT_PATH)
assert SPEC is not None and SPEC.loader is not None
checker = importlib.util.module_from_spec(SPEC)
sys.modules[SPEC.name] = checker
SPEC.loader.exec_module(checker)


HEADER_BLOCK = (
    "Baseline record — not a specification. This document describes as-built\n"
    "or operational state; the normative target is the specification set\n"
    "indexed in [`docs/spec-policy.md`](spec-policy.md), and where this\n"
    "document conflicts with a specification home, the specification wins.\n"
)


def write(path: Path, value: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(value, encoding="utf-8", newline="\n")


def fixture_repo(root: Path) -> None:
    write(
        root / "docs" / "spec-policy.md",
        "# Policy\n\n## Specification Inventory\n\n"
        "| Document | Primary layer | Status |\n| --- | --- | --- |\n"
        "| [`docs/spec-a.md`](spec-a.md) | Permanent | Draft |\n",
    )
    write(root / "docs" / "spec-a.md", "# Spec A\n\nSpecification status: Draft\n")


class BaselineRecordHeaderTests(unittest.TestCase):
    def test_committed_repo_reports_only_the_missing_header_class(self) -> None:
        """The committed tree runs cleanly or reports only header absence.

        The checker is staged while the docs/ backfill of the pinned
        header block is incomplete; any other failure class is a
        regression in the checker itself.
        """
        with redirect_stdout(StringIO()), redirect_stderr(StringIO()):
            try:
                checker.validate_repo(REPO_ROOT)
            except checker.BaselineRecordHeaderError as exc:
                self.assertIn("pinned baseline-record block", str(exc))

    def test_inventory_and_excluded_docs_are_skipped(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            fixture_repo(root)
            write(root / "docs" / "README.md", "# Index\n\nNo header needed.\n")
            write(root / "docs" / "adr" / "0001-x.md", "# ADR\n\nDecision.\n")
            checker.validate_repo(root)

    def test_accepts_pinned_header_with_superseded_by_extension(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            fixture_repo(root)
            write(
                root / "docs" / "royalty.md",
                "# Royalty Policy\n\n"
                + HEADER_BLOCK.rstrip("\n")
                + " For\ntarget royalty behavior this document is superseded by\n"
                "[`docs/spec-a.md`](spec-a.md).\n\nBody.\n",
            )
            checker.validate_repo(root)

    def test_rejects_missing_and_drifted_headers(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            fixture_repo(root)
            write(root / "docs" / "bare.md", "# Bare\n\nThis is not the header.\n")
            with self.assertRaises(checker.BaselineRecordHeaderError) as ctx:
                checker.validate_repo(root)
            self.assertIn("docs/bare.md", str(ctx.exception))

    def test_rejects_header_not_directly_beneath_title(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            fixture_repo(root)
            write(
                root / "docs" / "late.md",
                "# Late\n\nSome intro paragraph first.\n\n" + HEADER_BLOCK,
            )
            with self.assertRaises(checker.BaselineRecordHeaderError):
                checker.validate_repo(root)


if __name__ == "__main__":
    unittest.main()

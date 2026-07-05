#!/usr/bin/env python3
"""Focused tests for the normative language lint."""

from __future__ import annotations

import importlib.util
import sys
import tempfile
import unittest
from pathlib import Path


SCRIPT_PATH = Path(__file__).with_name("check_normative_language.py")
REPO_ROOT = SCRIPT_PATH.parent.parent
SPEC = importlib.util.spec_from_file_location("check_normative_language", SCRIPT_PATH)
assert SPEC is not None and SPEC.loader is not None
checker = importlib.util.module_from_spec(SPEC)
sys.modules[SPEC.name] = checker
SPEC.loader.exec_module(checker)


def write(path: Path, value: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(value, encoding="utf-8", newline="\n")


def fixture_repo(root: Path, spec_body: str) -> None:
    write(
        root / "docs" / "spec-policy.md",
        "# Policy\n\n## Specification Inventory\n\n"
        "| Document | Primary layer | Status |\n| --- | --- | --- |\n"
        "| [`docs/spec-a.md`](spec-a.md) | Permanent | Draft |\n",
    )
    write(
        root / "docs" / "launch-conformance-matrix.md",
        "# Matrix\n\nGate row cites [SPX-CORE].\n",
    )
    write(root / "docs" / "spec-a.md", "# Spec A\n\n## Core [SPX-CORE]\n\n" + spec_body)
    write(root / "docs" / "adr" / "0004-admin-governance.md", "# ADR 0004\n\nBody.\n")


class NormativeLanguageTests(unittest.TestCase):
    def test_committed_repo_reports_only_sweep_candidates(self) -> None:
        """The committed tree passes or flags only unlicensed 'should' text.

        The ADR 0014 decision V9 must-ward sweep is a pending Review-entry
        condition; unresolved candidates keep this lint staged.
        """
        try:
            checker.validate_repo(REPO_ROOT)
        except checker.NormativeLanguageError as exc:
            self.assertIn("unlicensed 'should'", str(exc))

    def test_accepts_musts_and_licensed_shoulds(self) -> None:
        body = (
            "1. Core must reject zero.\n"
            "2. The ceremony should also deploy the lens; a deployment that "
            "omits it records the rationale in the deployment manifest.\n"
        )
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            fixture_repo(root, body)
            sections, cited = checker.validate_repo(root)
            self.assertEqual(sections, 1)
            self.assertEqual(cited, 1)

    def test_flags_unlicensed_should_in_cited_section(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            fixture_repo(root, "1. Core should reject zero.\n")
            with self.assertRaises(checker.NormativeLanguageError) as ctx:
                checker.validate_repo(root)
            self.assertIn("unlicensed 'should'", str(ctx.exception))

    def test_ignores_sections_the_matrix_does_not_cite(self) -> None:
        body = "Prose.\n\n## Extras [SPX-EXTRA]\n\n1. Extras should exist.\n"
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            fixture_repo(root, "1. Core must reject zero.\n\n" + body)
            checker.validate_repo(root)


if __name__ == "__main__":
    unittest.main()

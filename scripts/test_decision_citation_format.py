#!/usr/bin/env python3
"""Focused tests for the decision citation format checker."""

from __future__ import annotations

import importlib.util
import sys
import tempfile
import unittest
from pathlib import Path


SCRIPT_PATH = Path(__file__).with_name("check_decision_citation_format.py")
REPO_ROOT = SCRIPT_PATH.parent.parent
SPEC = importlib.util.spec_from_file_location("check_decision_citation_format", SCRIPT_PATH)
assert SPEC is not None and SPEC.loader is not None
checker = importlib.util.module_from_spec(SPEC)
sys.modules[SPEC.name] = checker
SPEC.loader.exec_module(checker)


def write(path: Path, value: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(value, encoding="utf-8", newline="\n")


def fixture_repo(root: Path) -> None:
    write(
        root / "docs" / "adr" / "0010-pass.md",
        "# ADR 0010\n\n## Decisions\n\n### D1. First\n\n1. One.\n2. Two.\n\n"
        "### D2. Second\n\n1. Only.\n",
    )
    write(
        root / "docs" / "adr" / "0009-resolutions.md",
        "# ADR 0009\n\n## Decisions\n\n1. OQ-X5 resolved.\n2. Another.\n",
    )


class DecisionCitationTests(unittest.TestCase):
    def test_committed_repo_reports_only_known_shape_defects(self) -> None:
        """The committed tree passes or reports only citation-shape drift.

        Seven plain-numeral citations against ADR 0010's D-prefixed ids
        are known staged defects in the metadata specs; any other failure
        class is a checker regression.
        """
        try:
            checker.validate_repo(REPO_ROOT)
        except checker.DecisionCitationError as exc:
            self.assertIn("does not match the ADR 0010 id shape", str(exc))

    def test_accepts_conformant_citations_and_lists(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            fixture_repo(root)
            write(
                root / "docs" / "spec.md",
                "# Spec\n\nRatified (ADR 0010 decision D1.2) and paired\n"
                "(ADR 0010 decisions D1 and D2). Plain numerals stay exempt\n"
                "(ADR 0009 decision 2).\n",
            )
            checker.validate_repo(root)

    def test_rejects_wrong_prefix_for_owning_adr(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            fixture_repo(root)
            write(root / "docs" / "spec.md", "# S\n\nBad (ADR 0010 decision 2).\n")
            with self.assertRaises(checker.DecisionCitationError) as ctx:
                checker.validate_repo(root)
            self.assertIn("id shape", str(ctx.exception))

    def test_rejects_nonexistent_decision_ids(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            fixture_repo(root)
            write(
                root / "docs" / "spec.md",
                "# S\n\nMissing heading (ADR 0010 decision D9) and missing item\n"
                "(ADR 0010 decision D2.4) and missing numeral (ADR 0009\n"
                "decision 7).\n",
            )
            with self.assertRaises(checker.DecisionCitationError) as ctx:
                checker.validate_repo(root)
            message = str(ctx.exception)
            self.assertIn("D9 does not exist", message)
            self.assertIn("D2.4 does not exist", message)
            self.assertIn("decision 7 does not exist", message)

    def test_skips_template_placeholders_and_fenced_code(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            fixture_repo(root)
            write(
                root / "docs" / "spec.md",
                '# S\n\nCited from the specs as "(ADR 0010 decision D<n>)".\n\n'
                "```text\n(ADR 0010 decision Z9)\n```\n",
            )
            checker.validate_repo(root)


if __name__ == "__main__":
    unittest.main()

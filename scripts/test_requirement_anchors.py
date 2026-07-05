#!/usr/bin/env python3
"""Focused tests for the requirement anchor checker."""

from __future__ import annotations

import importlib.util
import sys
import tempfile
import unittest
from pathlib import Path


SCRIPT_PATH = Path(__file__).with_name("check_requirement_anchors.py")
REPO_ROOT = SCRIPT_PATH.parent.parent
SPEC = importlib.util.spec_from_file_location("check_requirement_anchors", SCRIPT_PATH)
assert SPEC is not None and SPEC.loader is not None
checker = importlib.util.module_from_spec(SPEC)
sys.modules[SPEC.name] = checker
SPEC.loader.exec_module(checker)


def write(path: Path, value: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(value, encoding="utf-8", newline="\n")


class RequirementAnchorTests(unittest.TestCase):
    def test_committed_repo_anchors_resolve(self) -> None:
        anchors, citations = checker.validate_repo(REPO_ROOT)
        self.assertGreater(anchors, 200)
        self.assertGreater(citations, 1000)

    def test_accepts_heading_lead_in_and_bare_anchor_homes(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            write(
                root / "docs" / "spec.md",
                "# Spec\n\n## Mint Rules [MPX-MINT]\n\nSee [MPX-GATE] and\n"
                "[MPX-EDITIONS].\n\n## Gates\n\nRequirements [MPX-GATE]:\n\n"
                "1. Gate one.\n\n## Editions\n\n[MPX-EDITIONS]\n\nPosture prose.\n",
            )
            checker.validate_repo(root)

    def test_rejects_citation_without_home(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            write(
                root / "docs" / "spec.md",
                "# Spec\n\nCites the missing [MPX-ABSENT] anchor.\n",
            )
            with self.assertRaises(checker.RequirementAnchorError) as ctx:
                checker.validate_repo(root)
            self.assertIn("[MPX-ABSENT]", str(ctx.exception))

    def test_rejects_two_home_sections_for_one_anchor(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            write(
                root / "docs" / "a.md",
                "# A\n\n## One\n\nRequirements [MPX-DUP]:\n\n1. Rule.\n",
            )
            write(
                root / "docs" / "b.md",
                "# B\n\n## Two\n\nRequirements [MPX-DUP]:\n\n1. Rule.\n",
            )
            with self.assertRaises(checker.RequirementAnchorError) as ctx:
                checker.validate_repo(root)
            self.assertIn("2 home sections", str(ctx.exception))

    def test_wrapped_prose_colon_is_not_a_second_home(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            write(
                root / "docs" / "spec.md",
                "# Spec\n\n## Scope\n\nRequirements [MPX-SCOPE]:\n\n1. Rule.\n\n"
                "## Other\n\nThese rules apply verbatim to other\n"
                "requests [MPX-SCOPE]:\na subject is one commitment.\n",
            )
            checker.validate_repo(root)

    def test_excluded_namespaces_are_ignored(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            write(
                root / "docs" / "spec.md",
                "# Spec\n\nTracker ids [P0-PAY-001] and markers **[OQ-X9]** are\n"
                "not requirement anchors.\n",
            )
            checker.validate_repo(root)


if __name__ == "__main__":
    unittest.main()

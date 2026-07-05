#!/usr/bin/env python3
"""Focused tests for the enum literal cross-check."""

from __future__ import annotations

import importlib.util
import sys
import tempfile
import unittest
from pathlib import Path


SCRIPT_PATH = Path(__file__).with_name("check_enum_literal_cross_check.py")
REPO_ROOT = SCRIPT_PATH.parent.parent
SPEC = importlib.util.spec_from_file_location("check_enum_literal_cross_check", SCRIPT_PATH)
assert SPEC is not None and SPEC.loader is not None
checker = importlib.util.module_from_spec(SPEC)
sys.modules[SPEC.name] = checker
SPEC.loader.exec_module(checker)


def write(path: Path, value: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(value, encoding="utf-8", newline="\n")


LIFECYCLE_BLOCK = (
    "Lifecycle reconciliation matrix\n\n```text\n"
    "Token condition        StreamTokenLifecycle     TokenURIReadStatus     EntropyStatus\n"
    "nonexistent            UNKNOWN                  NONEXISTENT            NONE\n"
    "burned                 BURNED                   BURNED                 FINALIZED\n"
    "```\n"
)


def fixture_repo(root: Path, matrix_extra: str = "", entropy_members: str = "NONE,\n    FINALIZED\n") -> None:
    write(
        root / "docs" / "spec-policy.md",
        "# Policy\n\n## Specification Inventory\n\n"
        "| Document | Primary layer | Status |\n| --- | --- | --- |\n"
        "| [`docs/spec-a.md`](spec-a.md) | Permanent | Draft |\n",
    )
    write(
        root / "docs" / "launch-conformance-matrix.md",
        "# Matrix\n\n" + LIFECYCLE_BLOCK + "\nAlso `GOOD_LITERAL = 1`.\n" + matrix_extra,
    )
    write(
        root / "docs" / "stream-long-term-architecture.md",
        "# Umbrella\n\n```solidity\nenum StreamTokenLifecycle {\n    UNKNOWN,\n"
        "    BURNED\n}\n```\n",
    )
    write(
        root / "docs" / "metadata-router-and-renderer.md",
        "# Router\n\n```solidity\nenum TokenURIReadStatus {\n    NONEXISTENT,\n"
        "    BURNED\n}\n```\n",
    )
    write(
        root / "docs" / "stream-entropy-coordinator.md",
        "# Coordinator\n\n```solidity\nenum EntropyStatus {\n    "
        + entropy_members
        + "}\n```\n",
    )
    write(root / "docs" / "spec-a.md", "# Spec A\n\n`GOOD_LITERAL` is pinned (= 1).\n")


class EnumLiteralTests(unittest.TestCase):
    def test_committed_repo_literals_resolve(self) -> None:
        literal_count, lifecycle_count = checker.validate_repo(REPO_ROOT)
        self.assertGreater(literal_count, 80)
        self.assertGreater(lifecycle_count, 10)

    def test_accepts_consistent_fixture(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            fixture_repo(root)
            checker.validate_repo(root)

    def test_rejects_lifecycle_literal_missing_from_owning_enum(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            fixture_repo(root, entropy_members="NONE\n")
            with self.assertRaises(checker.EnumLiteralError) as ctx:
                checker.validate_repo(root)
            self.assertIn("EntropyStatus.FINALIZED", str(ctx.exception))

    def test_rejects_entropy_unknown_member(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            fixture_repo(root, entropy_members="UNKNOWN,\n    NONE,\n    FINALIZED\n")
            with self.assertRaises(checker.EnumLiteralError) as ctx:
                checker.validate_repo(root)
            self.assertIn("UNKNOWN", str(ctx.exception))

    def test_rejects_matrix_literal_with_no_home(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            fixture_repo(root, matrix_extra="\nAnd `ORPHAN_LITERAL` too.\n")
            with self.assertRaises(checker.EnumLiteralError) as ctx:
                checker.validate_repo(root)
            self.assertIn("ORPHAN_LITERAL", str(ctx.exception))

    def test_rejects_pinned_value_drift(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            fixture_repo(root, matrix_extra="\nAnd `GOOD_LITERAL = 2`.\n")
            with self.assertRaises(checker.EnumLiteralError) as ctx:
                checker.validate_repo(root)
            self.assertIn("GOOD_LITERAL = 2", str(ctx.exception))


if __name__ == "__main__":
    unittest.main()

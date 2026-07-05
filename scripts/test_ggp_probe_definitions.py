#!/usr/bin/env python3
"""Focused tests for the GGP probe definition checker."""

from __future__ import annotations

import importlib.util
import sys
import tempfile
import unittest
from pathlib import Path


SCRIPT_PATH = Path(__file__).with_name("check_ggp_probe_definitions.py")
REPO_ROOT = SCRIPT_PATH.parent.parent
SPEC = importlib.util.spec_from_file_location("check_ggp_probe_definitions", SCRIPT_PATH)
assert SPEC is not None and SPEC.loader is not None
checker = importlib.util.module_from_spec(SPEC)
sys.modules[SPEC.name] = checker
SPEC.loader.exec_module(checker)


def write(path: Path, value: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(value, encoding="utf-8", newline="\n")


def fixture_repo(root: Path, home_body: str) -> None:
    write(
        root / "docs" / "stream-long-term-architecture.md",
        "# Umbrella\n\n## Governed Gas Parameters [LTA-GGP]\n\n"
        "| Parameter | Host | Normative home |\n| --- | --- | --- |\n"
        "| `A_GAS_LIMIT` | core | [`docs/a.md`](a.md) [A-GGP] |\n",
    )
    write(root / "docs" / "a.md", "# A\n\n## Gas [A-GGP]\n\n" + home_body)
    write(
        root / "docs" / "stream-entropy-coordinator.md",
        "# Coordinator\n\nRequirements [EC-TIME]:\n\n1. The shared entropy "
        "cadence probe records runs with `evidenceHash`.\n",
    )


GOOD_HOME = (
    "The parameter `A_GAS_LIMIT` has failure-direction class "
    "`FAIL_CLOSED_PRECHECK` and its named probe executes the guarded path, "
    "committing the run to `evidenceHash`.\n"
)


class ProbeDefinitionTests(unittest.TestCase):
    def test_committed_repo_probe_definitions_hold(self) -> None:
        ggp_count, gtp_count = checker.validate_repo(REPO_ROOT)
        self.assertEqual(ggp_count, 22)
        self.assertEqual(gtp_count, 1)

    def test_accepts_sentence_level_assignment(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            fixture_repo(root, GOOD_HOME)
            self.assertEqual(checker.validate_repo(root), (1, 1))

    def test_accepts_section_level_contextual_assignment(self) -> None:
        body = (
            "`A_GAS_LIMIT` bounds the guarded read. The parameter's "
            "release-manifest failure-direction class is `FORWARDING_CAP`.\n"
            "Its named probe replays the read and commits to `evidenceHash`.\n"
        )
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            fixture_repo(root, body)
            self.assertEqual(checker.validate_repo(root), (1, 1))

    def test_rejects_missing_class(self) -> None:
        body = "`A_GAS_LIMIT` has a probe committing to `evidenceHash`.\n"
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            fixture_repo(root, body)
            with self.assertRaises(checker.ProbeDefinitionError) as ctx:
                checker.validate_repo(root)
            self.assertIn("no pinned failure-direction class", str(ctx.exception))

    def test_rejects_ambiguous_classes(self) -> None:
        body = (
            "`A_GAS_LIMIT` is `FORWARDING_CAP` with a probe and `evidenceHash`. "
            "Also `A_GAS_LIMIT` is `MIN_GAS_GATE`.\n"
        )
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            fixture_repo(root, body)
            with self.assertRaises(checker.ProbeDefinitionError) as ctx:
                checker.validate_repo(root)
            self.assertIn("ambiguous failure-direction classes", str(ctx.exception))

    def test_rejects_missing_probe_definition(self) -> None:
        body = (
            "`A_GAS_LIMIT` is `FORWARDING_CAP`; runs commit to `evidenceHash`.\n"
        )
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            fixture_repo(root, body)
            with self.assertRaises(checker.ProbeDefinitionError) as ctx:
                checker.validate_repo(root)
            self.assertIn("no probe definition", str(ctx.exception))


if __name__ == "__main__":
    unittest.main()

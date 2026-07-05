#!/usr/bin/env python3
"""Focused tests for the traceability extractor and artifact checker."""

from __future__ import annotations

import importlib.util
import json
import sys
import tempfile
import unittest
from pathlib import Path


SCRIPT_PATH = Path(__file__).with_name("check_traceability_artifact.py")
REPO_ROOT = SCRIPT_PATH.parent.parent
SPEC = importlib.util.spec_from_file_location("check_traceability_artifact", SCRIPT_PATH)
assert SPEC is not None and SPEC.loader is not None
checker = importlib.util.module_from_spec(SPEC)
sys.modules[SPEC.name] = checker
SPEC.loader.exec_module(checker)


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
    write(
        root / "docs" / "spec-a.md",
        "# Spec A\n\n## Core [SPX-CORE]\n\n1. Core must reject zero.\n"
        "2. Core may accept one.\n\nThe boundary must stay closed.\n",
    )


def artifact(entries: list[dict]) -> dict:
    return {"schema": checker.ARTIFACT_SCHEMA, "requirements": entries}


class TraceabilityTests(unittest.TestCase):
    def test_committed_repo_extracts_requirements(self) -> None:
        requirements = checker.extract_requirements(REPO_ROOT)
        self.assertGreater(len(requirements), 300)
        self.assertFalse(
            (REPO_ROOT / checker.DEFAULT_ARTIFACT_PATH).exists(),
            "wire the artifact validation into CI once the artifact lands",
        )

    def test_extraction_grammar_is_deterministic(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            fixture_repo(root)
            requirements = checker.extract_requirements(root)
            self.assertEqual(
                sorted(requirements), ["SPX-CORE.1", "SPX-CORE.p1"]
            )

    def test_accepts_closed_world_artifact(self) -> None:
        entries = [
            {
                "id": "SPX-CORE.1",
                "document": "docs/spec-a.md",
                "mappedTo": [{"kind": "gate-row", "name": "Core boundary"}],
            },
            {
                "id": "SPX-CORE.p1",
                "document": "docs/spec-a.md",
                "mappedTo": [{"kind": "test", "name": "test_boundary"}],
            },
        ]
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            fixture_repo(root)
            path = root / "trace.json"
            write(path, json.dumps(artifact(entries)))
            requirements = checker.extract_requirements(root)
            self.assertEqual(checker.validate_artifact(root, path, requirements), 2)

    def test_rejects_unmapped_and_unknown_requirements(self) -> None:
        entries = [
            {"id": "SPX-CORE.1", "document": "docs/spec-a.md", "mappedTo": []},
            {
                "id": "SPX-GONE.9",
                "document": "docs/spec-a.md",
                "mappedTo": [{"kind": "test", "name": "x"}],
            },
        ]
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            fixture_repo(root)
            path = root / "trace.json"
            write(path, json.dumps(artifact(entries)))
            requirements = checker.extract_requirements(root)
            with self.assertRaises(checker.TraceabilityError) as ctx:
                checker.validate_artifact(root, path, requirements)
            message = str(ctx.exception)
            self.assertIn("SPX-CORE.1: unmapped requirement", message)
            self.assertIn("SPX-GONE.9", message)
            self.assertIn("SPX-CORE.p1", message)


if __name__ == "__main__":
    unittest.main()

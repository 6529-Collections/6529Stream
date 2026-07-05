#!/usr/bin/env python3
"""Focused tests for the spec bundle checker, with rehearsal fixtures."""

from __future__ import annotations

import hashlib
import importlib.util
import json
import sys
import tempfile
import unittest
from pathlib import Path


SCRIPT_PATH = Path(__file__).with_name("check_spec_bundle.py")
REPO_ROOT = SCRIPT_PATH.parent.parent
SPEC = importlib.util.spec_from_file_location("check_spec_bundle", SCRIPT_PATH)
assert SPEC is not None and SPEC.loader is not None
checker = importlib.util.module_from_spec(SPEC)
sys.modules[SPEC.name] = checker
SPEC.loader.exec_module(checker)


def write(path: Path, value: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(value, encoding="utf-8", newline="\n")


def rehearsal_repo(root: Path) -> list[dict]:
    write(
        root / "docs" / "spec-policy.md",
        "# Policy\n\n## Specification Inventory\n\n"
        "| Document | Primary layer | Status |\n| --- | --- | --- |\n"
        "| [`docs/spec-a.md`](spec-a.md) | Permanent | Final |\n"
        "| [`docs/adr/`](adr/README.md) | Decision records | Per-ADR status |\n",
    )
    write(root / "docs" / "spec-a.md", "# Spec A\n\nSpecification status: Final\n")
    write(root / "docs" / "adr" / "README.md", "# ADRs\n")
    digest = hashlib.sha256((root / "docs" / "spec-a.md").read_bytes()).hexdigest()
    return [{"path": "docs/spec-a.md", "status": "Final", "sha256": digest}]


def bundle_payload(documents: list[dict]) -> dict:
    return {
        "schema": checker.BUNDLE_SCHEMA,
        "specBundleHash": checker.bundle_hash(documents),
        "documents": documents,
    }


class SpecBundleTests(unittest.TestCase):
    def test_committed_repo_has_no_bundle_yet(self) -> None:
        self.assertFalse((REPO_ROOT / checker.DEFAULT_BUNDLE_PATH).exists())
        inventory = checker.inventory_documents(REPO_ROOT)
        self.assertEqual(len(inventory), 12)
        self.assertNotIn("docs/adr/README.md", inventory)

    def test_accepts_rehearsal_bundle(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            documents = rehearsal_repo(root)
            path = root / "spec-bundle.json"
            write(path, json.dumps(bundle_payload(documents)))
            self.assertEqual(checker.validate_bundle(root, path), 1)

    def test_rejects_non_final_status_and_hash_drift(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            documents = rehearsal_repo(root)
            documents[0]["status"] = "Draft"
            documents[0]["sha256"] = "00" * 32
            path = root / "spec-bundle.json"
            write(path, json.dumps(bundle_payload(documents)))
            with self.assertRaises(checker.SpecBundleError) as ctx:
                checker.validate_bundle(root, path)
            message = str(ctx.exception)
            self.assertIn("not Final", message)
            self.assertIn("does not recompute", message)

    def test_rejects_missing_inventory_document(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            documents = rehearsal_repo(root)
            write(root / "docs" / "spec-b.md", "# Spec B\n")
            write(
                root / "docs" / "spec-policy.md",
                "# Policy\n\n## Specification Inventory\n\n"
                "| Document | Primary layer | Status |\n| --- | --- | --- |\n"
                "| [`docs/spec-a.md`](spec-a.md) | Permanent | Final |\n"
                "| [`docs/spec-b.md`](spec-b.md) | Permanent | Final |\n",
            )
            path = root / "spec-bundle.json"
            write(path, json.dumps(bundle_payload(documents)))
            with self.assertRaises(checker.SpecBundleError) as ctx:
                checker.validate_bundle(root, path)
            self.assertIn("docs/spec-b.md is not enumerated", str(ctx.exception))

    def test_rejects_bundle_hash_drift(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            documents = rehearsal_repo(root)
            payload = bundle_payload(documents)
            payload["specBundleHash"] = "11" * 32
            path = root / "spec-bundle.json"
            write(path, json.dumps(payload))
            with self.assertRaises(checker.SpecBundleError) as ctx:
                checker.validate_bundle(root, path)
            self.assertIn("specBundleHash does not recompute", str(ctx.exception))


if __name__ == "__main__":
    unittest.main()

#!/usr/bin/env python3
"""Negative and current-source checks for auction flows documentation."""
from __future__ import annotations
import tempfile
import shutil
from urllib.parse import unquote
from tools.docs.doc_contract import LINK
import unittest
from pathlib import Path
from tools.docs import check_auction_flows as checker

ROOT = Path(__file__).resolve().parents[2]

class CurrentDocumentationTests(unittest.TestCase):
    def validate_changed(self, transform):
        original = ROOT / checker.DEFAULT_DOC
        text = original.read_text(encoding="utf-8")
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            for match in LINK.finditer(text):
                raw = match.group(1)
                if raw.startswith(("#", "mailto:")) or "://" in raw:
                    continue
                target = (original.parent / unquote(raw.split("#", 1)[0])).resolve()
                relative = target.relative_to(ROOT)
                destination = root / relative
                if target.is_dir():
                    destination.mkdir(parents=True, exist_ok=True)
                else:
                    destination.parent.mkdir(parents=True, exist_ok=True)
                    shutil.copyfile(target, destination)
            sources = [source for source, _ in checker.SOURCE_TERMS]
            sources.append("smart-contracts/domains/mint/StreamFixedPriceSaleAdapter.sol")
            for source in sources:
                destination = root / source
                destination.parent.mkdir(parents=True, exist_ok=True)
                shutil.copyfile(ROOT / source, destination)
            path = root / checker.DEFAULT_DOC
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text(transform(text), encoding="utf-8")
            checker.validate_auction_flows(root, path)

    def test_committed_document(self):
        checker.validate_auction_flows(ROOT, ROOT / checker.DEFAULT_DOC)

    def test_rejects_removed_current_api(self):
        token = checker.REQUIRED_TERMS[0]
        with self.assertRaisesRegex(ValueError, "missing current"):
            self.validate_changed(lambda text: text.replace(token, "REMOVED"))

    def test_rejects_removed_maturity_boundary(self):
        with self.assertRaisesRegex(ValueError, "missing current"):
            self.validate_changed(lambda text: text.replace("not production-ready", "ready").replace("not\nproduction-ready", "ready"))

    def test_rejects_missing_local_target(self):
        with self.assertRaisesRegex(ValueError, "missing linked target"):
            self.validate_changed(lambda text: text + "\n[missing](missing-current-api.sol)\n")

    def test_rejects_repository_escape(self):
        with self.assertRaisesRegex(ValueError, "escapes repository"):
            self.validate_changed(lambda text: text + "\n[escape](../../../../../../outside.md)\n")

    def test_rejects_legacy_executable_example(self):
        with self.assertRaisesRegex(ValueError, "legacy API"):
            self.validate_changed(lambda text: text + "\n```solidity\nmintDrop(payload);\n```\n")

    def test_allows_editorial_heading_changes(self):
        self.validate_changed(lambda text: text.replace("## ", "### "))

if __name__ == "__main__":
    unittest.main()

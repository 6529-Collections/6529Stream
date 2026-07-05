#!/usr/bin/env python3
"""Focused tests for the Numeric ID Catalog checker."""

from __future__ import annotations

import importlib.util
import json
import sys
import tempfile
import unittest
from pathlib import Path


SCRIPT_PATH = Path(__file__).with_name("check_numeric_id_catalog.py")
REPO_ROOT = SCRIPT_PATH.parent.parent
SPEC = importlib.util.spec_from_file_location("check_numeric_id_catalog", SCRIPT_PATH)
assert SPEC is not None and SPEC.loader is not None
checker = importlib.util.module_from_spec(SPEC)
sys.modules[SPEC.name] = checker
SPEC.loader.exec_module(checker)


def write(path: Path, value: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(value, encoding="utf-8", newline="\n")


def fixture_repo(root: Path) -> None:
    write(
        root / "docs" / "launch-conformance-matrix.md",
        "# Matrix\n\n## Numeric ID Catalog\n\nRequirements [LCM-IDS]:\n\n"
        "The v1 catalog must cover `SaleKind` and `EntropyStatus` families.\n\n"
        "## Next\n\nOther.\n",
    )


def catalog(enums: list[dict]) -> dict:
    return {
        "schema": checker.CATALOG_SCHEMA,
        "schemaVersion": 1,
        "schemaURI": "ipfs://catalog",
        "schemaHash": "0x" + "ab" * 32,
        "canonicalizationId": "RFC8785",
        "supersedesCatalogHash": None,
        "enums": enums,
    }


GOOD_ENUMS = [
    {"name": "SaleKind", "home": "docs/sales.md", "values": {"FIXED_PRICE": 0, "AUCTION": 1}},
    {"name": "EntropyStatus", "home": "docs/ec.md", "values": {"NONE": 0, "FINALIZED": 1}},
]


class NumericIdCatalogTests(unittest.TestCase):
    def test_committed_repo_has_no_catalog_yet(self) -> None:
        self.assertFalse((REPO_ROOT / checker.DEFAULT_CATALOG_PATH).exists())
        required = checker.required_enum_families(REPO_ROOT)
        self.assertIn("SaleKind", required)
        self.assertIn("GovernanceActionStatus", required)

    def test_accepts_closed_world_catalog(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            fixture_repo(root)
            path = root / "catalog.json"
            write(path, json.dumps(catalog(GOOD_ENUMS)))
            enums, required = checker.validate_catalog(root, path)
            self.assertEqual(enums, 2)
            self.assertEqual(required, 2)

    def test_rejects_missing_coverage_family(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            fixture_repo(root)
            path = root / "catalog.json"
            write(path, json.dumps(catalog(GOOD_ENUMS[:1])))
            with self.assertRaises(checker.NumericIdCatalogError) as ctx:
                checker.validate_catalog(root, path)
            self.assertIn("EntropyStatus has no catalog entry", str(ctx.exception))

    def test_rejects_duplicate_values_and_name_vocabulary(self) -> None:
        bad = [
            {
                "name": "SaleKind",
                "home": "docs/sales.md",
                "values": {"FIXED_PRICE": 0, "AUCTION": 0, "CORE_NATIVE": 1},
            },
            GOOD_ENUMS[1],
        ]
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            fixture_repo(root)
            path = root / "catalog.json"
            write(path, json.dumps(catalog(bad)))
            with self.assertRaises(checker.NumericIdCatalogError) as ctx:
                checker.validate_catalog(root, path)
            message = str(ctx.exception)
            self.assertIn("assigned to both", message)
            self.assertIn("not catalog members", message)

    def test_rejects_missing_supersession_fields(self) -> None:
        payload = catalog(GOOD_ENUMS)
        del payload["supersedesCatalogHash"]
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            fixture_repo(root)
            path = root / "catalog.json"
            write(path, json.dumps(payload))
            with self.assertRaises(checker.NumericIdCatalogError) as ctx:
                checker.validate_catalog(root, path)
            self.assertIn("supersedesCatalogHash", str(ctx.exception))


if __name__ == "__main__":
    unittest.main()

#!/usr/bin/env python3
"""Focused tests for custom error catalog generation."""

from __future__ import annotations

import importlib.util
import json
import tempfile
import unittest
from contextlib import redirect_stderr, redirect_stdout
from io import StringIO
from pathlib import Path
from typing import Any


SCRIPT_PATH = Path(__file__).with_name("generate_custom_error_catalog.py")
SPEC = importlib.util.spec_from_file_location("generate_custom_error_catalog", SCRIPT_PATH)
assert SPEC is not None and SPEC.loader is not None
generator = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(generator)


def write_json(path: Path, value: Any) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", encoding="utf-8", newline="\n") as handle:
        json.dump(value, handle, indent=2, ensure_ascii=False)
        handle.write("\n")


def write_traceability_files(root: Path) -> None:
    for paths in generator.TRACEABILITY_BY_CATEGORY.values():
        for test_path in paths:
            path = root / test_path
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text("// traceability fixture\n", encoding="utf-8")


def fixture_surface() -> dict[str, Any]:
    return {
        "schema_version": "6529stream.protocol-surface-report.v1",
        "contracts": {
            "ExampleCore": {
                "source": "smart-contracts/ExampleCore.sol",
                "artifact_path": "out/ExampleCore.sol/ExampleCore.json",
                "custom_errors": [
                    {
                        "name": "FunctionAdminUnauthorized",
                        "signature": "FunctionAdminUnauthorized()",
                        "selector": "0x12345678",
                        "inputs": [],
                    },
                    {
                        "name": "MetadataFrozen",
                        "signature": "MetadataFrozen(uint256)",
                        "selector": "0xabcdef12",
                        "inputs": [
                            {
                                "index": 0,
                                "name": "collectionId",
                                "type": "uint256",
                                "internal_type": "uint256",
                            }
                        ],
                    },
                    {
                        "name": "MetadataMutationPaused",
                        "signature": "MetadataMutationPaused()",
                        "selector": "0xaaaaaaaa",
                        "inputs": [],
                    },
                ],
            },
            "ExampleRoyalty": {
                "source": "smart-contracts/ExampleRoyalty.sol",
                "artifact_path": "out/ExampleRoyalty.sol/ExampleRoyalty.json",
                "custom_errors": [
                    {
                        "name": "ERC2981InvalidDefaultRoyalty",
                        "signature": "ERC2981InvalidDefaultRoyalty(uint256,uint256)",
                        "selector": "0x87654321",
                        "inputs": [],
                    }
                ],
            },
            "ExampleRevenueResolver": {
                "source": "smart-contracts/ExampleRevenueResolver.sol",
                "artifact_path": "out/ExampleRevenueResolver.sol/ExampleRevenueResolver.json",
                "custom_errors": [
                    {
                        "name": "InvalidPrimaryTemplateTotal",
                        "signature": "InvalidPrimaryTemplateTotal(uint256)",
                        "selector": "0xbbbbbbbb",
                        "inputs": [],
                    }
                ],
            },
            "ExamplePrimarySaleSettlement": {
                "source": "smart-contracts/ExamplePrimarySaleSettlement.sol",
                "artifact_path": "out/ExamplePrimarySaleSettlement.sol/ExamplePrimarySaleSettlement.json",
                "custom_errors": [
                    {
                        "name": "SettlementAlreadyConsumed",
                        "signature": "SettlementAlreadyConsumed(bytes32)",
                        "selector": "0xcccccccc",
                        "inputs": [],
                    }
                ],
            },
        },
    }


class CustomErrorCatalogTests(unittest.TestCase):
    def test_committed_catalog_is_current_and_matches_surface(self) -> None:
        root = Path(__file__).resolve().parents[1]
        surface = root / "release-artifacts" / "latest" / "protocol-surface-report.json"
        output = root / "release-artifacts" / "latest" / "custom-error-catalog.json"
        if not output.exists():
            self.skipTest("custom error catalog is generated during this PR")

        with redirect_stdout(StringIO()), redirect_stderr(StringIO()):
            self.assertEqual(generator.check_catalog(root, surface, output), 0)

        surface_data = json.loads(surface.read_text(encoding="utf-8"))
        catalog_data = json.loads(output.read_text(encoding="utf-8"))
        surface_count = sum(
            len(contract["custom_errors"])
            for contract in surface_data["contracts"].values()
        )
        self.assertEqual(catalog_data["summary"]["custom_error_count"], surface_count)
        self.assertEqual(len(catalog_data["entries"]), surface_count)

    def test_catalog_classifies_security_relevant_errors(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            surface = root / "surface.json"
            output = root / "catalog.json"
            write_traceability_files(root)
            write_json(surface, fixture_surface())

            generator.generate_catalog(root, surface, output)
            catalog = json.loads(output.read_text(encoding="utf-8"))
            entries = {entry["id"]: entry for entry in catalog["entries"]}

            admin = entries["ExampleCore:FunctionAdminUnauthorized()"]
            self.assertEqual(admin["category"], "access_control")
            self.assertEqual(admin["severity"], "critical")
            self.assertIn("test/StreamCustomErrorNegative.t.sol", admin["traceability"]["tests"])

            metadata = entries["ExampleCore:MetadataFrozen(uint256)"]
            self.assertEqual(metadata["category"], "metadata_integrity")
            self.assertEqual(metadata["severity"], "high")
            self.assertIn("refresh release artifacts", metadata["caller_action"])

            paused = entries["ExampleCore:MetadataMutationPaused()"]
            self.assertEqual(paused["category"], "pause_emergency")
            self.assertEqual(paused["severity"], "high")
            self.assertIn("unpaused", paused["caller_action"])

            royalty = entries[
                "ExampleRoyalty:ERC2981InvalidDefaultRoyalty(uint256,uint256)"
            ]
            self.assertEqual(royalty["category"], "configuration")
            self.assertEqual(royalty["severity"], "medium")

            resolver = entries[
                "ExampleRevenueResolver:InvalidPrimaryTemplateTotal(uint256)"
            ]
            self.assertEqual(resolver["category"], "revenue_assignment_safety")
            self.assertIn("resolver assignment", resolver["caller_action"])

            settlement = entries[
                "ExamplePrimarySaleSettlement:SettlementAlreadyConsumed(bytes32)"
            ]
            self.assertEqual(settlement["category"], "primary_settlement_safety")
            self.assertIn("primary-sale settlement", settlement["caller_action"])

    def test_catalog_records_duplicate_selectors_for_review(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            write_traceability_files(root)
            surface = fixture_surface()
            surface["contracts"]["Other"] = {
                "source": "smart-contracts/Other.sol",
                "artifact_path": "out/Other.sol/Other.json",
                "custom_errors": [
                    {
                        "name": "FunctionAdminUnauthorized",
                        "signature": "FunctionAdminUnauthorized()",
                        "selector": "0x12345678",
                        "inputs": [],
                    }
                ],
            }
            surface_path = root / "surface.json"
            output = root / "catalog.json"
            write_json(surface_path, surface)

            generator.generate_catalog(root, surface_path, output)
            catalog = json.loads(output.read_text(encoding="utf-8"))

            duplicate = catalog["summary"]["duplicate_selectors"]["0x12345678"]
            self.assertEqual(
                duplicate,
                [
                    "ExampleCore:FunctionAdminUnauthorized()",
                    "Other:FunctionAdminUnauthorized()",
                ],
            )

    def test_check_detects_drift(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            surface = root / "surface.json"
            output = root / "catalog.json"
            write_traceability_files(root)
            write_json(surface, fixture_surface())

            generator.generate_catalog(root, surface, output)
            with redirect_stdout(StringIO()), redirect_stderr(StringIO()):
                self.assertEqual(generator.check_catalog(root, surface, output), 0)

            catalog = json.loads(output.read_text(encoding="utf-8"))
            catalog["entries"][0]["category"] = "wrong"
            write_json(output, catalog)

            with redirect_stdout(StringIO()), redirect_stderr(StringIO()):
                self.assertEqual(generator.check_catalog(root, surface, output), 1)

    def test_invalid_selector_fails_generation(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            write_traceability_files(root)
            surface = fixture_surface()
            surface["contracts"]["ExampleCore"]["custom_errors"][0]["selector"] = "0x1234"
            surface_path = root / "surface.json"
            output = root / "catalog.json"
            write_json(surface_path, surface)

            with self.assertRaisesRegex(
                generator.CustomErrorCatalogError,
                "invalid selector",
            ):
                generator.generate_catalog(root, surface_path, output)

    def test_unknown_error_name_fails_generation(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            write_traceability_files(root)
            surface = fixture_surface()
            surface["contracts"]["ExampleCore"]["custom_errors"][0] = {
                "name": "TotallyNewBoundary",
                "signature": "TotallyNewBoundary()",
                "selector": "0x12345678",
                "inputs": [],
            }
            surface_path = root / "surface.json"
            output = root / "catalog.json"
            write_json(surface_path, surface)

            with self.assertRaisesRegex(
                generator.CustomErrorCatalogError,
                "not covered by custom error category map",
            ):
                generator.generate_catalog(root, surface_path, output)

    def test_missing_traceability_file_fails_validation(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            surface = root / "surface.json"
            output = root / "catalog.json"
            write_json(surface, fixture_surface())

            with self.assertRaisesRegex(
                generator.CustomErrorCatalogError,
                "references missing test traceability file",
            ):
                generator.generate_catalog(root, surface, output)


if __name__ == "__main__":
    unittest.main(verbosity=2)

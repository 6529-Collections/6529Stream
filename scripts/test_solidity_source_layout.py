#!/usr/bin/env python3
"""Self-tests for the fail-closed Solidity source-layout checker."""

from __future__ import annotations

import json
import shutil
import tempfile
import unittest
from pathlib import Path

import check_solidity_source_layout as checker


REPO_ROOT = Path(__file__).resolve().parents[1]


class SoliditySourceLayoutTests(unittest.TestCase):
    def fixture(self) -> tempfile.TemporaryDirectory[str]:
        temp = tempfile.TemporaryDirectory()
        root = Path(temp.name)
        shutil.copytree(REPO_ROOT / "smart-contracts", root / "smart-contracts")
        return temp

    @staticmethod
    def errors(root: Path) -> list[str]:
        return checker.check_repository(root)

    def test_committed_repository_passes(self) -> None:
        self.assertEqual(self.errors(REPO_ROOT), [])

    def test_duplicate_old_path_fails(self) -> None:
        with self.fixture() as temp:
            root = Path(temp)
            path = root / checker.MANIFEST_PATH
            payload = json.loads(path.read_text(encoding="utf-8"))
            payload["moves"][1] = dict(payload["moves"][0])
            path.write_text(json.dumps(payload), encoding="utf-8")
            self.assertTrue(any("old_path values must be unique" in error for error in self.errors(root)))

    def test_duplicate_new_path_fails(self) -> None:
        with self.fixture() as temp:
            root = Path(temp)
            path = root / checker.MANIFEST_PATH
            payload = json.loads(path.read_text(encoding="utf-8"))
            payload["moves"][1]["new_path"] = payload["moves"][0]["new_path"]
            path.write_text(json.dumps(payload), encoding="utf-8")
            self.assertTrue(any("new_path values must be unique" in error for error in self.errors(root)))

    def test_migration_base_tamper_fails(self) -> None:
        with self.fixture() as temp:
            root = Path(temp)
            path = root / checker.MANIFEST_PATH
            payload = json.loads(path.read_text(encoding="utf-8"))
            payload["migration_base_commit"] = "0" * 40
            path.write_text(json.dumps(payload), encoding="utf-8")
            self.assertTrue(any("exact reviewed migration base" in error for error in self.errors(root)))

    def test_equivalence_receipt_digest_tamper_fails(self) -> None:
        with self.fixture() as temp:
            root = Path(temp)
            path = root / checker.MANIFEST_PATH
            payload = json.loads(path.read_text(encoding="utf-8"))
            payload["equivalence_receipt_canonical_sha256"] = "0" * 64
            path.write_text(json.dumps(payload), encoding="utf-8")
            self.assertTrue(
                any("exact reviewed historical receipt digest" in error for error in self.errors(root))
            )

    def test_duplicate_manifest_member_fails(self) -> None:
        with self.fixture() as temp:
            root = Path(temp)
            path = root / checker.MANIFEST_PATH
            text = path.read_text(encoding="utf-8").replace(
                '  "migration_base_commit":',
                '  "migration_base_commit": "0",\n  "migration_base_commit":',
                1,
            )
            path.write_text(text, encoding="utf-8")
            self.assertTrue(
                any("duplicate JSON member: migration_base_commit" in error for error in self.errors(root))
            )

    def test_policy_tamper_fails(self) -> None:
        with self.fixture() as temp:
            root = Path(temp)
            path = root / checker.MANIFEST_PATH
            payload = json.loads(path.read_text(encoding="utf-8"))
            payload["policy"]["allowed_top_level_directories"].append("misc")
            path.write_text(json.dumps(payload), encoding="utf-8")
            self.assertTrue(any("exact reviewed source-layout policy" in error for error in self.errors(root)))

    def test_move_map_tamper_fails(self) -> None:
        with self.fixture() as temp:
            root = Path(temp)
            path = root / checker.MANIFEST_PATH
            payload = json.loads(path.read_text(encoding="utf-8"))
            payload["moves"][0]["old_path"] = "smart-contracts/OtherAddress.sol"
            payload["moves"][0]["new_path"] = (
                "smart-contracts/vendor/openzeppelin/OtherAddress.sol"
            )
            current = root / "smart-contracts/vendor/openzeppelin/Address.sol"
            current.rename(current.with_name("OtherAddress.sol"))
            path.write_text(json.dumps(payload), encoding="utf-8")
            self.assertTrue(any("exact reviewed 120-row migration map" in error for error in self.errors(root)))

    def test_missing_manifest_target_fails(self) -> None:
        with self.fixture() as temp:
            root = Path(temp)
            payload = json.loads((root / checker.MANIFEST_PATH).read_text(encoding="utf-8"))
            (root / payload["moves"][0]["new_path"]).unlink()
            self.assertTrue(any("manifest targets are missing" in error for error in self.errors(root)))

    def test_approved_future_nested_source_passes(self) -> None:
        with self.fixture() as temp:
            root = Path(temp)
            extra = root / "smart-contracts/domains/access/Unexpected.sol"
            extra.write_text("pragma solidity 0.8.19; contract Unexpected {}\n", encoding="utf-8")
            self.assertEqual(self.errors(root), [])

    def test_top_level_source_fails(self) -> None:
        with self.fixture() as temp:
            root = Path(temp)
            extra = root / "smart-contracts/Unexpected.sol"
            extra.write_text("pragma solidity 0.8.19; contract Unexpected {}\n", encoding="utf-8")
            errors = self.errors(root)
            self.assertTrue(any("top-level Solidity sources are forbidden" in error for error in errors))

    def test_unapproved_directory_fails(self) -> None:
        with self.fixture() as temp:
            root = Path(temp)
            path = root / checker.MANIFEST_PATH
            payload = json.loads(path.read_text(encoding="utf-8"))
            source = root / payload["moves"][0]["new_path"]
            target = root / "smart-contracts/misc/Address.sol"
            target.parent.mkdir(parents=True)
            source.replace(target)
            payload["moves"][0]["new_path"] = "smart-contracts/misc/Address.sol"
            path.write_text(json.dumps(payload), encoding="utf-8")
            self.assertTrue(any("unapproved top-level directory" in error for error in self.errors(root)))

    def test_abi_compatibility_directory_rejects_contract(self) -> None:
        with self.fixture() as temp:
            root = Path(temp)
            path = root / "smart-contracts/interfaces/compatibility/IStreamCompatibility.sol"
            text = path.read_text(encoding="utf-8").replace(
                "interface IStreamCompatibility", "contract IStreamCompatibility"
            )
            path.write_text(text, encoding="utf-8")
            self.assertTrue(
                any("must not declare a concrete contract" in error for error in self.errors(root))
            )

    def test_any_interface_directory_rejects_concrete_contract(self) -> None:
        with self.fixture() as temp:
            root = Path(temp)
            extra = root / "smart-contracts/interfaces/stream/FutureConcrete.sol"
            extra.write_text(
                "pragma solidity 0.8.19;\ncontract FutureConcrete {}\n",
                encoding="utf-8",
            )
            self.assertTrue(
                any("must not declare a concrete contract" in error for error in self.errors(root))
            )

    def test_interface_directory_allows_helper_library(self) -> None:
        with self.fixture() as temp:
            root = Path(temp)
            extra = root / "smart-contracts/interfaces/stream/FutureTypes.sol"
            extra.write_text(
                "pragma solidity 0.8.19;\nlibrary FutureTypes {}\n",
                encoding="utf-8",
            )
            self.assertEqual(self.errors(root), [])

    def test_concrete_compatibility_directory_rejects_interface(self) -> None:
        with self.fixture() as temp:
            root = Path(temp)
            path = root / "smart-contracts/compatibility/StreamArtistApprovals.sol"
            text = path.read_text(encoding="utf-8").replace(
                "library StreamArtistApprovals", "interface StreamArtistApprovals"
            )
            path.write_text(text, encoding="utf-8")
            self.assertTrue(any("must not declare an interface" in error for error in self.errors(root)))

    def test_unresolved_relative_import_fails(self) -> None:
        with self.fixture() as temp:
            root = Path(temp)
            path = root / "smart-contracts/core/StreamCore.sol"
            text = path.read_text(encoding="utf-8").replace(
                '"../vendor/openzeppelin/ERC721.sol"', '"./Missing.sol"'
            )
            path.write_text(text, encoding="utf-8")
            self.assertTrue(any("relative import does not resolve" in error for error in self.errors(root)))

    def test_escaping_relative_import_fails(self) -> None:
        with self.fixture() as temp:
            root = Path(temp)
            path = root / "smart-contracts/core/StreamCore.sol"
            text = path.read_text(encoding="utf-8").replace(
                '"../vendor/openzeppelin/ERC721.sol"', '"../../../Outside.sol"'
            )
            path.write_text(text, encoding="utf-8")
            self.assertTrue(any("escapes the repository" in error for error in self.errors(root)))

    def test_backslash_import_fails(self) -> None:
        with self.fixture() as temp:
            root = Path(temp)
            path = root / "smart-contracts/core/StreamCore.sol"
            text = path.read_text(encoding="utf-8").replace(
                '"../vendor/openzeppelin/ERC721.sol"', '"..\\vendor\\openzeppelin\\ERC721.sol"'
            )
            path.write_text(text, encoding="utf-8")
            self.assertTrue(any("relative import is not normalized" in error for error in self.errors(root)))

    def test_dot_segment_import_fails(self) -> None:
        with self.fixture() as temp:
            root = Path(temp)
            path = root / "smart-contracts/core/StreamCore.sol"
            text = path.read_text(encoding="utf-8").replace(
                '"../vendor/openzeppelin/ERC721.sol"',
                '"../vendor/./openzeppelin/ERC721.sol"',
            )
            path.write_text(text, encoding="utf-8")
            self.assertTrue(any("relative import is not normalized" in error for error in self.errors(root)))

    def test_backslash_manifest_path_fails(self) -> None:
        with self.fixture() as temp:
            root = Path(temp)
            path = root / checker.MANIFEST_PATH
            payload = json.loads(path.read_text(encoding="utf-8"))
            payload["moves"][0]["old_path"] = payload["moves"][0]["old_path"].replace(
                "/", "\\"
            )
            path.write_text(json.dumps(payload), encoding="utf-8")
            self.assertTrue(any("must use forward slashes" in error for error in self.errors(root)))

    def test_stale_old_path_outside_manifest_fails(self) -> None:
        with self.fixture() as temp:
            root = Path(temp)
            docs = root / "docs"
            docs.mkdir()
            docs.joinpath("stale.md").write_text(
                "See smart-contracts/" + "StreamCore.sol.\n", encoding="utf-8"
            )
            self.assertTrue(any("stale pre-migration source path" in error for error in self.errors(root)))

    def test_stale_old_path_in_javascript_fails(self) -> None:
        with self.fixture() as temp:
            root = Path(temp)
            scripts = root / "scripts"
            scripts.mkdir()
            scripts.joinpath("stale.js").write_text(
                "const source = 'smart-contracts/" + "StreamCore.sol';\n",
                encoding="utf-8",
            )
            self.assertTrue(any("stale pre-migration source path" in error for error in self.errors(root)))

    def test_case_folded_stale_old_path_fails(self) -> None:
        with self.fixture() as temp:
            root = Path(temp)
            docs = root / "docs"
            docs.mkdir()
            docs.joinpath("stale.md").write_text(
                "See SMART-CONTRACTS/" + "STREAMCORE.SOL.\n",
                encoding="utf-8",
            )
            self.assertTrue(any("stale pre-migration source path" in error for error in self.errors(root)))


if __name__ == "__main__":
    unittest.main(verbosity=2)

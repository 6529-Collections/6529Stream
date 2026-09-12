#!/usr/bin/env python3
"""Self-tests for the fail-closed Solidity source-layout checker."""

from __future__ import annotations

import json
import hashlib
import shutil
import tempfile
import unittest
from pathlib import Path

from tools.build import check_solidity_source_layout as checker
from tools.build import refresh_solidity_source_inventory as inventory


REPO_ROOT = Path(__file__).resolve().parents[2]


class SoliditySourceLayoutTests(unittest.TestCase):
    def fixture(self) -> tempfile.TemporaryDirectory[str]:
        temp = tempfile.TemporaryDirectory()
        root = Path(temp.name)
        shutil.copytree(REPO_ROOT / "smart-contracts", root / "smart-contracts")
        receipt = root / checker.HISTORICAL_RECEIPT_PATH
        receipt.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(REPO_ROOT / checker.HISTORICAL_RECEIPT_PATH, receipt)
        active_path = root / checker.CURRENT_MANIFEST_PATH
        active = json.loads(active_path.read_text(encoding="utf-8"))
        active["frozen_evidence"] = []
        active_path.write_text(json.dumps(active), encoding="utf-8")
        return temp

    @staticmethod
    def errors(root: Path) -> list[str]:
        return checker.check_repository(root)

    @staticmethod
    def add_current_source(root: Path, path: Path) -> None:
        manifest_path = root / checker.CURRENT_MANIFEST_PATH
        manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
        manifest["source_paths"] = sorted(set(manifest["source_paths"]) | {path.relative_to(root).as_posix()})
        manifest_path.write_text(json.dumps(manifest), encoding="utf-8")

    @staticmethod
    def mutate_current(root: Path, mutation) -> None:
        path = root / checker.CURRENT_MANIFEST_PATH
        value = json.loads(path.read_text(encoding="utf-8"))
        mutation(value)
        path.write_text(json.dumps(value), encoding="utf-8")

    def test_committed_repository_passes(self) -> None:
        self.assertEqual(self.errors(REPO_ROOT), [])

    def test_refresh_only_updates_paths_and_is_idempotent(self) -> None:
        with self.fixture() as temp:
            root = Path(temp)
            active_path = root / checker.CURRENT_MANIFEST_PATH
            before = json.loads(active_path.read_bytes())
            historical_paths = (checker.MANIFEST_PATH, checker.HISTORICAL_RECEIPT_PATH)
            historical = {path: (root / path).read_bytes() for path in historical_paths}
            source = root / "smart-contracts/interfaces/stream/mint/IInventoryExample.sol"
            source.write_bytes(b"pragma solidity ^0.8.19;\ninterface IInventoryExample {}\n")
            self.assertTrue(inventory.refresh(root))
            after = json.loads(active_path.read_bytes())
            self.assertEqual(set(after["source_paths"]) - set(before["source_paths"]), {source.relative_to(root).as_posix()})
            self.assertEqual({k: v for k, v in before.items() if k != "source_paths"},
                             {k: v for k, v in after.items() if k != "source_paths"})
            self.assertEqual(historical, {path: (root / path).read_bytes() for path in historical_paths})
            self.assertFalse(inventory.refresh(root))

    def test_refresh_check_reports_drift_without_writing(self) -> None:
        with self.fixture() as temp:
            root = Path(temp)
            active_path = root / checker.CURRENT_MANIFEST_PATH
            before = active_path.read_bytes()
            source = root / "smart-contracts/interfaces/stream/mint/IInventoryExample.sol"
            source.write_bytes(b"pragma solidity ^0.8.19;\ninterface IInventoryExample {}\n")
            self.assertTrue(inventory.refresh(root, check=True))
            self.assertEqual(before, active_path.read_bytes())

    def test_refresh_rejects_invalid_layout_without_writing(self) -> None:
        with self.fixture() as temp:
            root = Path(temp)
            active_path = root / checker.CURRENT_MANIFEST_PATH
            before = active_path.read_bytes()
            source = root / "smart-contracts/domains/mint/IMisplaced.sol"
            source.write_bytes(b"pragma solidity ^0.8.19;\ninterface IMisplaced {}\n")
            with self.assertRaisesRegex(checker.SourceLayoutError, "shared protocol interface belongs"):
                inventory.refresh(root)
            self.assertEqual(before, active_path.read_bytes())

    def test_refresh_cannot_drop_a_historical_destination(self) -> None:
        with self.fixture() as temp:
            root = Path(temp)
            active_path = root / checker.CURRENT_MANIFEST_PATH
            before = active_path.read_bytes()
            current = checker.load_current_manifest(root)
            move = checker.load_manifest(root)["moves"][0]
            (root / checker.current_target(move["new_path"], current)).unlink()
            with self.assertRaises(checker.SourceLayoutError):
                inventory.refresh(root)
            self.assertEqual(before, active_path.read_bytes())

    def test_historical_git_object_archive_has_one_exact_stale_path_exception(
        self,
    ) -> None:
        old_path = f"{checker.EXPECTED_SOURCE_ROOT}/StreamArtistApprovals.sol"
        self.assertEqual(
            {
                Path(
                    "docs/architecture/"
                    "artist-record-event-reconstruction-historical-git-objects-v1.json"
                ): {old_path: 2},
                Path(
                    "tools/protocol/check_artist_record_event_reconstruction_correction.py"
                ): {old_path: 2},
                Path(
                    "tools/protocol/test_artist_record_event_reconstruction_correction.py"
                ): {old_path: 1},
            },
            checker.STALE_PATH_EVIDENCE_ALLOWLIST,
        )

    def test_historical_archive_exception_rejects_another_stale_path(self) -> None:
        with self.fixture() as temp:
            root = Path(temp)
            archive = (
                root
                / "docs/architecture/"
                "artist-record-event-reconstruction-historical-git-objects-v1.json"
            )
            archive.parent.mkdir(parents=True)
            archive.write_text(
                "smart-contracts/" + "StreamCore.sol\n",
                encoding="utf-8",
            )
            self.assertTrue(
                any(
                    "stale pre-migration source path" in error
                    for error in self.errors(root)
                )
            )

    def test_historical_archive_exception_rejects_extra_duplicate(self) -> None:
        with self.fixture() as temp:
            root = Path(temp)
            archive = (
                root
                / "docs/architecture/"
                "artist-record-event-reconstruction-historical-git-objects-v1.json"
            )
            archive.parent.mkdir(parents=True)
            old_path = f"{checker.EXPECTED_SOURCE_ROOT}/StreamArtistApprovals.sol"
            archive.write_text("\n".join([old_path] * 3), encoding="utf-8")
            self.assertTrue(
                any(
                    "historical stale-path evidence count or case drift" in error
                    for error in self.errors(root)
                )
            )

    def test_historical_archive_exception_rejects_case_mutation(self) -> None:
        with self.fixture() as temp:
            root = Path(temp)
            archive = (
                root
                / "docs/architecture/"
                "artist-record-event-reconstruction-historical-git-objects-v1.json"
            )
            archive.parent.mkdir(parents=True)
            old_path = f"{checker.EXPECTED_SOURCE_ROOT}/StreamArtistApprovals.sol"
            archive.write_text(
                old_path + "\n" + old_path.replace("Approvals", "approvals"),
                encoding="utf-8",
            )
            self.assertTrue(
                any(
                    "historical stale-path evidence count or case drift" in error
                    for error in self.errors(root)
                )
            )

    def test_historical_archive_exception_rejects_allowed_path_in_another_file(
        self,
    ) -> None:
        with self.fixture() as temp:
            root = Path(temp)
            path = root / "docs/architecture/unrelated.json"
            path.parent.mkdir(parents=True)
            path.write_text(
                f"{checker.EXPECTED_SOURCE_ROOT}/StreamArtistApprovals.sol\n",
                encoding="utf-8",
            )
            self.assertTrue(
                any(
                    "stale pre-migration source path" in error
                    for error in self.errors(root)
                )
            )

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
            self.add_current_source(root, extra)
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
            extra = root / "smart-contracts/interfaces/stream/core/FutureTypes.sol"
            extra.write_text(
                "pragma solidity 0.8.19;\nlibrary FutureTypes {}\n",
                encoding="utf-8",
            )
            self.add_current_source(root, extra)
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


    def test_current_inventory_rejects_unlisted_source(self) -> None:
        with self.fixture() as temp:
            root = Path(temp)
            extra = root / "smart-contracts/core/Unexpected.sol"
            extra.write_text("pragma solidity ^0.8.19; contract Unexpected {}", encoding="utf-8")
            self.assertTrue(any("not listed in the current inventory" in x for x in self.errors(root)))

    def test_flat_stream_interface_rejected_even_when_listed(self) -> None:
        with self.fixture() as temp:
            root = Path(temp)
            extra = root / "smart-contracts/interfaces/stream/IFlat.sol"
            extra.write_text("pragma solidity ^0.8.19; interface IFlat {}", encoding="utf-8")
            self.add_current_source(root, extra)
            self.assertTrue(any("grouped by domain" in x for x in self.errors(root)))

    def test_domain_source_cannot_hide_shared_inline_interface(self) -> None:
        with self.fixture() as temp:
            root = Path(temp)
            path = root / "smart-contracts/domains/mint/StreamMintManager.sol"
            with path.open("a", encoding="utf-8") as stream:
                stream.write("\ninterface IHiddenProtocol { function core() external view returns (address); }\n")
            self.assertTrue(any("shared protocol interface" in x for x in self.errors(root)))

    def test_current_inventory_allows_shared_enum_and_struct_file(self) -> None:
        with self.fixture() as temp:
            root = Path(temp)
            extra = root / "smart-contracts/interfaces/stream/core/ExampleTypes.sol"
            extra.write_text("pragma solidity ^0.8.19; enum State { NONE, READY } struct Record { uint256 id; }", encoding="utf-8")
            self.add_current_source(root, extra)
            self.assertEqual(self.errors(root), [])

    def test_current_layout_cannot_rebind_historical_manifest(self) -> None:
        with self.fixture() as temp:
            root = Path(temp)
            self.mutate_current(root, lambda x: x["historical_manifest"].update(sha256="0" * 64))
            self.assertTrue(any("exact frozen historical bytes" in x for x in self.errors(root)))

    def test_historical_manifest_whitespace_is_still_byte_bound(self) -> None:
        with self.fixture() as temp:
            root = Path(temp)
            with (root / checker.MANIFEST_PATH).open("ab") as stream:
                stream.write(b"\n")
            self.assertTrue(any("historical file byte identity" in x for x in self.errors(root)))

    def test_current_relocation_cannot_point_outside_inventory(self) -> None:
        with self.fixture() as temp:
            root = Path(temp)
            self.mutate_current(root, lambda x: x["relocations"][0].update(new_path="smart-contracts/core/Missing.sol"))
            self.assertTrue(any("directly into current inventory" in x for x in self.errors(root)))

    def test_current_relocation_cannot_form_a_chain(self) -> None:
        with self.fixture() as temp:
            root = Path(temp)
            def change(value):
                target = value["relocations"][1]["old_path"]
                value["relocations"][0]["new_path"] = target
                value["source_paths"] = sorted(value["source_paths"] + [target])
            self.mutate_current(root, change)
            self.assertTrue(any("retired" in x or "flat" in x for x in self.errors(root)))

    def test_retired_domain_reference_is_rejected_in_tools(self) -> None:
        with self.fixture() as temp:
            root = Path(temp)
            stale = json.loads((root / checker.CURRENT_MANIFEST_PATH).read_text())["relocations"][0]["old_path"]
            path = root / "tools/example.py"
            path.parent.mkdir()
            path.write_text(repr(stale), encoding="utf-8")
            self.assertTrue(any("stale pre-migration source path" in x for x in self.errors(root)))

    def test_frozen_exception_requires_matching_file_identity(self) -> None:
        with self.fixture() as temp:
            root = Path(temp)
            stale = json.loads((root / checker.CURRENT_MANIFEST_PATH).read_text())["relocations"][0]["old_path"]
            relative = "deployments/current/sepolia-current-rc-1/compilation/example.json"
            path = root / relative
            path.parent.mkdir(parents=True)
            path.write_text(json.dumps({"historical_source": stale}), encoding="utf-8")
            digest = hashlib.sha256(path.read_bytes()).hexdigest()
            self.mutate_current(root, lambda x: x["frozen_evidence"].append({"path": relative, "sha256": digest, "purpose": "historical prepared compilation"}))
            self.assertEqual(self.errors(root), [])
            with path.open("ab") as stream:
                stream.write(b" ")
            self.assertTrue(any("frozen evidence byte identity" in x for x in self.errors(root)))

    def test_frozen_directory_is_not_a_blanket_exemption(self) -> None:
        with self.fixture() as temp:
            root = Path(temp)
            stale = json.loads((root / checker.CURRENT_MANIFEST_PATH).read_text())["relocations"][0]["old_path"]
            path = root / "deployments/current/sepolia-current-rc-1/compilation/unlisted.json"
            path.parent.mkdir(parents=True)
            path.write_text(json.dumps({"source": stale}), encoding="utf-8")
            self.assertTrue(any("stale pre-migration source path" in x for x in self.errors(root)))

    def test_single_file_history_exception_does_not_cover_neighbor(self) -> None:
        with self.fixture() as temp:
            root = Path(temp)
            relative = "test/fixtures/warning-dispositions/forge-size-output.txt"
            path = root / relative
            path.parent.mkdir(parents=True)
            path.write_text("historical transcript", encoding="utf-8")
            row = {"path": relative, "sha256": hashlib.sha256(path.read_bytes()).hexdigest(), "purpose": "retained warning transcript"}
            self.mutate_current(root, lambda x: x["frozen_evidence"].append(row))
            self.assertEqual(self.errors(root), [])
            neighbor = relative + ".new.txt"
            (root / neighbor).write_bytes(path.read_bytes())
            self.mutate_current(root, lambda x: x["frozen_evidence"][0].update(path=neighbor))
            self.assertTrue(any("operational path cannot be exempted" in x for x in self.errors(root)))

    def test_operational_file_cannot_be_frozen_exempt(self) -> None:
        with self.fixture() as temp:
            root = Path(temp)
            self.mutate_current(root, lambda x: x["frozen_evidence"].append({"path": "tools/active.py", "sha256": "0" * 64, "purpose": "attempted exemption"}))
            self.assertTrue(any("operational path cannot be exempted" in x for x in self.errors(root)))


if __name__ == "__main__":
    unittest.main(verbosity=2)

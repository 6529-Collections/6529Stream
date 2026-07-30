#!/usr/bin/env python3
"""Regression tests for the issue #670 mechanical adapter vectors."""

from __future__ import annotations

import copy
import json
import shutil
import tempfile
import unittest
from pathlib import Path
from unittest import mock

import check_issue_670_adapter_freeze as checker
import generate_issue_670_adapter_freeze as generator


SCRIPT_DIR = Path(__file__).resolve().parent
REPO_ROOT = SCRIPT_DIR.parent
VECTOR_PATH = REPO_ROOT / generator.DEFAULT_OUTPUT
MATRIX_PATH = REPO_ROOT / generator.DEFAULT_MATRIX_OUTPUT
SUPPLEMENT_PATH = REPO_ROOT / generator.DEFAULT_FINALITY_SUPPLEMENT


class Issue670AdapterFreezeTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.vector, cls.raw = checker.load_json_strict(VECTOR_PATH)
        cls.matrix, cls.matrix_raw = checker.load_json_strict(MATRIX_PATH)
        cls.supplement, _ = checker.load_json_strict(SUPPLEMENT_PATH)

    def test_committed_artifact_is_current_and_canonical(self) -> None:
        validated = checker.check_artifact(VECTOR_PATH, REPO_ROOT)
        self.assertEqual(validated["schema_version"], generator.SCHEMA_VERSION)
        self.assertEqual(
            validated["source"]["packet_source_commit"],
            generator.PACKET_SOURCE_COMMIT,
        )
        self.assertEqual(
            validated["evidence_class"],
            "mechanical_candidate_vectors",
        )
        self.assertFalse(validated["status"]["acceptance_freeze_satisfied"])
        self.assertFalse(validated["status"]["implementation_authorized"])
        self.assertFalse(validated["status"]["production_readiness_evidence"])
        self.assertEqual(self.raw, generator.canonical_json_bytes(validated))

    def test_revenue_vectors_cover_only_pinned_mechanics(self) -> None:
        revenue = self.vector["revenue_resolver_packet"]
        adapter = revenue["adapter_interface"]
        self.assertEqual(len(adapter["entries"]), 12)
        self.assertEqual(adapter["interface_id"], "0xb4165b1a")
        self.assertEqual(
            [item["calldata_length_bytes"] for item in revenue["operations"]],
            [1444, 1668, 1636, 2052, 1604, 1476, 1572, 1444, 2084],
        )
        self.assertEqual(
            revenue["abi_schema"]["dependencies_v1"]["words"],
            19,
        )
        self.assertEqual(
            revenue["abi_schema"]["intent_header_v1"]["words"],
            18,
        )
        self.assertEqual(revenue["abi_schema"]["result"]["bytes"], 928)
        event = revenue["events"][0]
        self.assertEqual(
            event["topic0"],
            "0x9759cccc3dc5dfb9a69774dba31ee80379f23bc686a951a46bdfbdb95227ea63",
        )
        self.assertEqual(event["indexed_argument_count"], 3)
        self.assertEqual(event["data_bytes"], 128)

        interfaces = {
            item["name"]: item["interface_id"]
            for item in revenue["dependency_read_interfaces"]
        }
        self.assertEqual(interfaces["CORE_READ_INTERFACE_V1"], "0xb1fc0266")
        self.assertEqual(
            interfaces["FACTORY_READ_INTERFACE_V1"],
            "0x0200c7a8",
        )
        self.assertEqual(
            interfaces["ARTIST_READ_INTERFACE_V1"],
            "0xed34ed02",
        )
        self.assertEqual(
            interfaces["MINT_MANAGER_INTERFACE_ID"],
            "0xb4074ed7",
        )

    def test_artist_vectors_cover_all_supplied_selectors_and_typehashes(self) -> None:
        artist = self.vector["artist_registry_packet"]
        adapter = artist["adapter_interface"]
        self.assertEqual(len(adapter["operations"]), 57)
        self.assertEqual(adapter["entry_selector_xor"], "0x2efcc794")
        self.assertEqual(adapter["full_interface_id"], "0x7cdddcdd")
        self.assertEqual(
            [item["number"] for item in adapter["operations"]],
            list(range(1, 58)),
        )
        self.assertEqual(artist["abi_schema"]["validation_context_v1"]["words"], 23)
        self.assertEqual(artist["abi_schema"]["field_bank"]["words"], 24)
        self.assertEqual(artist["abi_schema"]["result"]["bytes"], 512)
        self.assertEqual(
            artist["constants"]["erc1271_selector_and_magic"],
            "0x1626ba7e",
        )

        family_heads = {
            item["family"]: item["head_words"]
            for item in artist["abi_schema"]["families"]
        }
        self.assertEqual(
            family_heads,
            {
                "F": 47,
                "Q": 48,
                "U": 48,
                "R": 48,
                "QU": 49,
                "G": 49,
                "L": 49,
                "X": 49,
                "D": 49,
                "B": 53,
                "CI": 51,
                "IR": 51,
                "M": 53,
            },
        )
        self.assertEqual(len(artist["eip712"]["supplied_typehashes"]), 26)
        self.assertEqual(
            len(artist["eip712"]["supplied_typehash_assignments"]),
            31,
        )
        self.assertEqual(
            sum(
                item["status"] == "required_external"
                for item in artist["eip712"]["supplied_typehash_assignments"]
            ),
            2,
        )
        self.assertEqual(
            {
                item["registry_write"]
                for item in artist["eip712"]["missing_typehashes"]
            },
            {"refuseArtistBinding", "revokeArtistDelegation"},
        )

    def test_known_keccak_and_selector_vectors(self) -> None:
        self.assertEqual(
            generator.keccak_hex(b""),
            "0xc5d2460186f7233c927e7db2dcc703c0e500b653ca82273b7bfad8045d85a470",
        )
        self.assertEqual(
            generator.selector("supportsInterface(bytes4)"),
            "0x01ffc9a7",
        )
        self.assertEqual(
            generator.selector("isValidSignature(bytes32,bytes)"),
            "0x1626ba7e",
        )

    def test_generated_matrix_applies_only_the_reviewed_finality_overlay(
        self,
    ) -> None:
        validated = checker.check_operation_matrix(
            MATRIX_PATH, SUPPLEMENT_PATH
        )
        self.assertEqual(
            self.matrix_raw,
            generator.operation_matrix_json_bytes(validated),
        )
        self.assertEqual(
            validated["implementation_stop_overlays"],
            [generator.finality_stop_overlay()],
        )
        effective = validated["effective_implementation_stops"]
        self.assertEqual(effective["12"], [])
        self.assertEqual(effective["13"], [])
        self.assertEqual(effective["22"], [generator.FINALITY_STOP_ID])

        for row in validated["operations"]:
            row_id = row[0]
            if row_id in {12, 13}:
                self.assertEqual(row[17], [generator.FINALITY_STOP_ID])
                continue
            self.assertEqual(effective[str(row_id)], row[17])

    def test_checker_rejects_mechanical_and_maturity_mutations(self) -> None:
        mutations = (
            (
                "packet hash",
                lambda value: value["source"]["files"]["revenue_packet"].__setitem__(
                    "sha256", "sha256:" + "00" * 32
                ),
            ),
            (
                "revenue selector",
                lambda value: value["revenue_resolver_packet"][
                    "adapter_interface"
                ]["entries"][3].__setitem__("selector", "0x00000000"),
            ),
            (
                "revenue length",
                lambda value: value["revenue_resolver_packet"]["operations"][
                    0
                ].__setitem__("calldata_length_bytes", 1445),
            ),
            (
                "event topic",
                lambda value: value["revenue_resolver_packet"]["events"][
                    0
                ].__setitem__("topic0", "0x" + "00" * 32),
            ),
            (
                "artist selector",
                lambda value: value["artist_registry_packet"][
                    "adapter_interface"
                ]["operations"][56].__setitem__("selector", "0x00000000"),
            ),
            (
                "artist family head",
                lambda value: value["artist_registry_packet"]["abi_schema"][
                    "families"
                ][0].__setitem__("head_words", 48),
            ),
            (
                "typehash",
                lambda value: value["artist_registry_packet"]["eip712"][
                    "supplied_typehashes"
                ][0].__setitem__("value", "0x" + "00" * 32),
            ),
        )
        for label, mutate in mutations:
            with self.subTest(label=label):
                candidate = copy.deepcopy(self.vector)
                mutate(candidate)
                with self.assertRaisesRegex(
                    generator.AdapterFreezeError,
                    "stale or invalid",
                ):
                    checker.validate_artifact(candidate, REPO_ROOT)

    def test_external_gate_mutation_reaches_dedicated_guard(self) -> None:
        candidate = copy.deepcopy(self.vector)
        candidate["required_external_artifacts"][0][
            "satisfied_by_this_artifact"
        ] = True
        with mock.patch.object(
            generator, "build_artifact", return_value=candidate
        ):
            with self.assertRaisesRegex(
                generator.AdapterFreezeError,
                r"required_external_artifacts\[0\] cannot be satisfied here",
            ):
                checker.validate_artifact(candidate, REPO_ROOT)

    def test_implementation_mutation_reaches_dedicated_guard(self) -> None:
        candidate = copy.deepcopy(self.vector)
        candidate["status"]["implementation_authorized"] = True
        with mock.patch.object(
            generator, "build_artifact", return_value=candidate
        ):
            with self.assertRaisesRegex(
                generator.AdapterFreezeError,
                r"status\.implementation_authorized must remain false",
            ):
                checker.validate_artifact(candidate, REPO_ROOT)

    def test_overlay_rejects_row_22_resolution(self) -> None:
        supplement = copy.deepcopy(self.supplement)
        supplement["matrix_overlay"]["resolutions"][0]["row_id"] = 22
        with self.assertRaisesRegex(
            generator.AdapterFreezeError,
            "matrix_overlay does not match generated matrix",
        ):
            checker.validate_operation_matrix(self.matrix, supplement)

    def test_checker_rejects_noncanonical_json_and_duplicate_keys(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            compact_path = Path(temporary) / "compact.json"
            compact_path.write_text(
                json.dumps(self.vector, sort_keys=True),
                encoding="utf-8",
                newline="\n",
            )
            with self.assertRaisesRegex(
                generator.AdapterFreezeError,
                "not the canonical",
            ):
                checker.check_artifact(compact_path, REPO_ROOT)

            duplicate_path = Path(temporary) / "duplicate.json"
            duplicate_path.write_text(
                '{"schema_version":"a","schema_version":"b"}\n',
                encoding="utf-8",
                newline="\n",
            )
            with self.assertRaisesRegex(
                generator.AdapterFreezeError,
                "duplicate JSON key",
            ):
                checker.load_json_strict(duplicate_path)

    def test_generator_refuses_packet_source_drift(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            temporary_root = Path(temporary)
            for _, relative_path, _ in generator.SOURCE_FILES:
                target = temporary_root / relative_path
                target.parent.mkdir(parents=True, exist_ok=True)
                shutil.copyfile(REPO_ROOT / relative_path, target)

            revenue_packet = temporary_root / generator.SOURCE_FILES[0][1]
            revenue_packet.write_bytes(revenue_packet.read_bytes() + b"\n")
            with self.assertRaisesRegex(
                generator.AdapterFreezeError,
                "revenue-resolver-validation-adapter-interface-packet.md mismatch",
            ):
                generator.build_artifact(temporary_root)

    def test_every_unresolved_gate_remains_explicitly_external(self) -> None:
        external = self.vector["required_external_artifacts"]
        self.assertEqual(len(external), 8)
        self.assertTrue(
            all(item["status"] == "required_external" for item in external)
        )
        self.assertTrue(
            all(item["satisfied_by_this_artifact"] is False for item in external)
        )
        all_blockers = {
            blocker
            for item in external
            for blocker in item["blocking_decisions"]
        }
        self.assertTrue(
            {
                "R11",
                "R12",
                "R13",
                "AR-07",
                "AR-14",
                "AR-15",
                "AR-20",
                "AR-24",
                "AR-31",
                "AR-32",
                "AR-33",
            }.issubset(all_blockers)
        )


if __name__ == "__main__":
    unittest.main()

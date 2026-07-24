#!/usr/bin/env python3
"""Negative and positive tests for the independent manifest-vector oracle."""

from __future__ import annotations

import copy
import re
import unittest
from pathlib import Path

import check_system_manifest_payload_vector_reference as reference


ROOT = Path(__file__).resolve().parents[1]
VECTOR = ROOT / "release-artifacts/system-manifest-payload-vector.json"
PROFILE = ROOT / "release-artifacts/genesis-deployment-profile.json"


class SystemManifestPayloadVectorReferenceTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.vector, _ = reference.load_json_strict(VECTOR)
        _, cls.profile_raw = reference.load_json_strict(PROFILE)

    def audit_copy(self, mutator) -> None:
        candidate = copy.deepcopy(self.vector)
        mutator(candidate)
        reference.audit_vector(candidate, self.profile_raw)

    def test_committed_vector_matches_independent_fixed_goldens(self) -> None:
        reference.audit_vector(copy.deepcopy(self.vector), self.profile_raw)

    def test_oracle_has_no_generator_or_primary_checker_import(self) -> None:
        source = Path(reference.__file__).read_text(encoding="utf-8")
        forbidden = re.compile(
            r"^\s*(?:from|import)\s+(?:generate_system_manifest_payload_vector"
            r"|check_system_manifest_payload_vector)(?:\s|\.|$)",
            re.MULTILINE,
        )
        self.assertIsNone(forbidden.search(source))

    def test_payload_mutation_cannot_self_confirm(self) -> None:
        def mutate(candidate) -> None:
            candidate["payload"]["core"] = "0x" + "11" * 20

        with self.assertRaisesRegex(reference.ReferenceVectorError, "canonical payload Keccak"):
            self.audit_copy(mutate)

    def test_recorded_canonical_bytes_mutation_is_rejected(self) -> None:
        def mutate(candidate) -> None:
            candidate["canonical_payload"]["utf8_hex"] = "0x00"

        with self.assertRaisesRegex(reference.ReferenceVectorError, "recorded canonical bytes"):
            self.audit_copy(mutate)

    def test_deployment_identity_mutation_is_rejected(self) -> None:
        def mutate(candidate) -> None:
            candidate["fixture_derivation"]["deployment_identity"]["hash"] = "0x" + "22" * 32

        with self.assertRaisesRegex(
            reference.ReferenceVectorError, "recorded deployment identity hash"
        ):
            self.audit_copy(mutate)

    def test_profile_source_metadata_mutations_are_rejected(self) -> None:
        for field, replacement, expected_error in (
            ("profile_schema_version", "6529stream.genesis-deployment-profile.v1", "profile source schema"),
            ("normative_anchor", "docs/unreviewed.md#DRIFT", "profile source normative anchor"),
        ):
            with self.subTest(field=field):
                candidate = copy.deepcopy(self.vector)
                candidate["source"][field] = replacement
                with self.assertRaisesRegex(
                    reference.ReferenceVectorError, expected_error
                ):
                    reference.audit_vector(candidate, self.profile_raw)

    def test_complete_state_export_abi_mutations_are_rejected(self) -> None:
        mutations = (
            (
                "return types",
                lambda surface: surface["functions"][0]["returns"].pop(),
            ),
            (
                "event topic",
                lambda surface: surface["events"][0].__setitem__(
                    "topic0", "0x" + "55" * 32
                ),
            ),
            (
                "anonymous event",
                lambda surface: surface["events"][0].__setitem__("anonymous", True),
            ),
            (
                "numeric boolean masquerade",
                lambda surface: surface["events"][0].__setitem__("anonymous", 0),
            ),
            (
                "indexed mask",
                lambda surface: surface["events"][0]["indexed"].reverse(),
            ),
            (
                "surface digest",
                lambda surface: surface.__setitem__(
                    "surface_sha256", "sha256:" + "00" * 32
                ),
            ),
        )
        for label, mutate in mutations:
            with self.subTest(label=label):
                candidate = copy.deepcopy(self.vector)
                mutate(
                    candidate["fixture_derivation"][
                        "state_export_publisher_surface"
                    ]
                )
                with self.assertRaisesRegex(
                    reference.ReferenceVectorError,
                    "complete state-export ABI surface",
                ):
                    reference.audit_vector(candidate, self.profile_raw)

    def test_complete_governed_parameter_authority_abi_mutations_are_rejected(self) -> None:
        mutations = (
            (
                "marker return",
                lambda surface: surface["functions"][0]["returns"].clear(),
            ),
            (
                "context returns",
                lambda surface: surface["functions"][1]["returns"].pop(),
            ),
            (
                "context selector",
                lambda surface: surface["functions"][1].__setitem__(
                    "selector", "0x00000000"
                ),
            ),
            (
                "interface ID",
                lambda surface: surface.__setitem__("interface_id", "0x00000000"),
            ),
            (
                "surface digest",
                lambda surface: surface.__setitem__(
                    "surface_sha256", "sha256:" + "00" * 32
                ),
            ),
        )
        for label, mutate in mutations:
            with self.subTest(label=label):
                candidate = copy.deepcopy(self.vector)
                mutate(
                    candidate["fixture_derivation"][
                        "governed_parameter_authority_surface"
                    ]
                )
                with self.assertRaisesRegex(
                    reference.ReferenceVectorError,
                    "complete governed-parameter authority ABI surface",
                ):
                    reference.audit_vector(candidate, self.profile_raw)

    def test_governed_parameter_authority_binding_mutation_is_rejected(self) -> None:
        candidate = copy.deepcopy(self.vector)
        candidate["fixture_derivation"][
            "governed_parameter_authority_binding"
        ] = "UNREVIEWED_LAYER"
        with self.assertRaisesRegex(
            reference.ReferenceVectorError,
            "governed-parameter authority binding",
        ):
            reference.audit_vector(candidate, self.profile_raw)

    def test_synthetic_governance_interface_id_is_rejected(self) -> None:
        candidate = copy.deepcopy(self.vector)
        governance_address = candidate["semantic_round_trip"][
            "contract_address_by_key"
        ]["GOVERNANCE_LAYER"]
        publisher_pointer_type = reference._keccak_hex(b"STATE_EXPORT_PUBLISHER")
        publisher_pointer = next(
            row
            for row in candidate["payload"]["pointers"]
            if row["pointerType"] == publisher_pointer_type
        )
        governance_record = next(
            row
            for row in candidate["payload"]["registryEntries"]
            if row["module"] == governance_address
        )
        publisher_pointer["interfaceId"] = "0xa5971448"
        governance_record["interfaceId"] = "0xa5971448"
        with self.assertRaisesRegex(
            reference.ReferenceVectorError,
            "publisher pointer interface ID",
        ):
            reference.audit_vector(candidate, self.profile_raw)

    def test_synthetic_finality_adapter_interface_id_is_rejected(self) -> None:
        candidate = copy.deepcopy(self.vector)
        adapter_address = candidate["semantic_round_trip"][
            "contract_address_by_key"
        ]["STREAM_CORE_FINALITY_ADAPTER"]
        adapter_record = next(
            row
            for row in candidate["payload"]["registryEntries"]
            if row["module"] == adapter_address
        )
        adapter_record["interfaceId"] = "0xc7c3f294"
        with self.assertRaisesRegex(
            reference.ReferenceVectorError,
            "finality adapter registry interface ID",
        ):
            reference.audit_vector(candidate, self.profile_raw)

    def test_profile_byte_mutation_is_rejected_by_fixed_hash(self) -> None:
        with self.assertRaisesRegex(reference.ReferenceVectorError, "fixed profile SHA-256"):
            reference.audit_vector(copy.deepcopy(self.vector), self.profile_raw + b" ")

    def test_chunk_segment_mutation_is_rejected(self) -> None:
        def mutate(candidate) -> None:
            segment = candidate["chunks"][0]["segment_hex"]
            candidate["chunks"][0]["segment_hex"] = segment[:-2] + (
                "00" if segment[-2:] != "00" else "01"
            )

        with self.assertRaisesRegex(reference.ReferenceVectorError, "chunk 0 segment bytes"):
            self.audit_copy(mutate)

    def test_chunk_leaf_mutation_is_rejected(self) -> None:
        def mutate(candidate) -> None:
            candidate["chunks"][2]["leaf_hash"] = "0x" + "33" * 32

        with self.assertRaisesRegex(reference.ReferenceVectorError, "chunk 2 recorded leaf hash"):
            self.audit_copy(mutate)

    def test_commitment_mutation_is_rejected(self) -> None:
        def mutate(candidate) -> None:
            candidate["commitments"]["payload_root_hash"] = "0x" + "44" * 32

        with self.assertRaisesRegex(reference.ReferenceVectorError, "recorded payload-root hash"):
            self.audit_copy(mutate)

    def test_descriptor_byte_mutation_is_rejected(self) -> None:
        def mutate(candidate) -> None:
            encoded = candidate["root_descriptor"]["encoded_hex"]
            candidate["root_descriptor"]["encoded_hex"] = encoded[:-2] + (
                "00" if encoded[-2:] != "00" else "01"
            )

        with self.assertRaisesRegex(reference.ReferenceVectorError, "descriptor encoded bytes"):
            self.audit_copy(mutate)

    def test_descriptor_offset_mutation_is_rejected(self) -> None:
        def mutate(candidate) -> None:
            candidate["root_descriptor"]["dynamic_offset"] = 256

        with self.assertRaisesRegex(reference.ReferenceVectorError, "descriptor offset"):
            self.audit_copy(mutate)


if __name__ == "__main__":
    unittest.main()

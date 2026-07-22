#!/usr/bin/env python3
"""Focused regression tests for the system-manifest payload ABI-lock vector."""

from __future__ import annotations

import copy
import json
import tempfile
import unittest
from pathlib import Path

import check_system_manifest_payload_vector as checker
import generate_system_manifest_payload_vector as generator


SCRIPT_DIR = Path(__file__).resolve().parent
REPO_ROOT = SCRIPT_DIR.parent
PROFILE_PATH = REPO_ROOT / generator.DEFAULT_PROFILE
VECTOR_PATH = REPO_ROOT / generator.DEFAULT_OUTPUT


class SystemManifestPayloadVectorTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.profile, cls.profile_raw = generator.load_json_strict(PROFILE_PATH)
        cls.vector, cls.vector_raw = generator.load_json_strict(VECTOR_PATH)

    def test_committed_vector_is_exact_deterministic_target_fixture(self) -> None:
        validated = checker.validate_committed_vector(
            self.vector,
            self.vector_raw,
            self.profile,
            self.profile_raw,
        )
        self.assertEqual(validated["evidence_class"], "target_abi_lock_fixture")
        self.assertFalse(validated["production_candidate"])
        self.assertFalse(validated["readiness_evidence"])
        self.assertEqual(
            validated["source"]["profile_entry_count"],
            generator.EXPECTED_PROFILE_ENTRIES,
        )
        self.assertEqual(
            len(validated["payload"]["contracts"]),
            generator.EXPECTED_PROFILE_ENTRIES,
        )
        self.assertEqual(
            len(validated["payload"]["registryEntries"]),
            generator.EXPECTED_PROFILE_ENTRIES,
        )
        self.assertEqual(len(validated["payload"]["pointers"]), 11)
        self.assertEqual(len(validated["payload"]["gasParameterProbes"]), 40)
        self.assertGreater(len(validated["chunks"]), 1)

    def test_governance_binding_proves_state_export_publisher_surface(self) -> None:
        governance = next(
            entry
            for entry in self.profile["entries"]
            if entry["key"] == "GOVERNANCE_LAYER"
        )
        self.assertIn(
            generator.STATE_EXPORT_PUBLISHER_INTERFACE,
            governance["required_interfaces"],
        )
        self.assertTrue(
            set(generator.STATE_EXPORT_PUBLISHER_MARKERS).issubset(
                governance["required_markers"]
            )
        )
        self.assertEqual(
            self.vector["fixture_derivation"]["state_export_publisher_binding"],
            "GOVERNANCE_LAYER",
        )
        self.assertEqual(
            self.vector["fixture_derivation"]["state_export_publisher_surface"],
            generator.state_export_publisher_surface(),
        )
        surface = self.vector["fixture_derivation"]["state_export_publisher_surface"]
        self.assertEqual(surface["interface_id"], "0x77faad4f")
        self.assertEqual(
            surface["functions"][0]["returns"],
            ["uint256", "bytes32", "bytes32", "bytes32", "string"],
        )
        self.assertEqual(
            [event["indexed"] for event in surface["events"]],
            [
                [False, True, True, True, False, False],
                [False, True, True, True, False],
                [False, True, True, True, False],
            ],
        )
        self.assertTrue(all(event["anonymous"] is False for event in surface["events"]))
        self.assertEqual(
            surface["surface_sha256"],
            generator.STATE_EXPORT_PUBLISHER_ABI_SHA256,
        )

        governance_address = self.vector["semantic_round_trip"][
            "contract_address_by_key"
        ]["GOVERNANCE_LAYER"]
        publisher_pointer_type = generator.hex_keccak(b"STATE_EXPORT_PUBLISHER")
        publisher_pointer = next(
            pointer
            for pointer in self.vector["payload"]["pointers"]
            if pointer["pointerType"] == publisher_pointer_type
        )
        governance_registry_record = next(
            record
            for record in self.vector["payload"]["registryEntries"]
            if record["module"] == governance_address
        )
        self.assertEqual(publisher_pointer["target"], governance_address)
        self.assertEqual(publisher_pointer["interfaceId"], "0x77faad4f")
        self.assertEqual(governance_registry_record["interfaceId"], "0x77faad4f")

        for field, expected_error in (
            ("required_interfaces", "state-export publisher interface"),
            ("required_markers", "state-export publisher interface"),
        ):
            with self.subTest(field=field):
                mutated = copy.deepcopy(self.profile)
                mutated_governance = next(
                    entry
                    for entry in mutated["entries"]
                    if entry["key"] == "GOVERNANCE_LAYER"
                )
                mutated_governance[field].pop()
                with self.assertRaisesRegex(
                    generator.ManifestVectorError,
                    expected_error,
                ):
                    generator._require_profile(mutated)

    def test_checker_rejects_full_publisher_abi_and_synthetic_interface_id_drift(self) -> None:
        surface_mutations = (
            (
                "return types",
                lambda surface: surface["functions"][0]["returns"].pop(),
            ),
            (
                "indexed mask",
                lambda surface: surface["events"][0]["indexed"].reverse(),
            ),
            (
                "anonymous event",
                lambda surface: surface["events"][0].__setitem__("anonymous", True),
            ),
            (
                "integer boolean masquerade",
                lambda surface: surface["events"][0].__setitem__("anonymous", 0),
            ),
            (
                "digest",
                lambda surface: surface.__setitem__(
                    "surface_sha256", "sha256:" + "00" * 32
                ),
            ),
        )
        for label, mutate in surface_mutations:
            with self.subTest(label=label):
                candidate = copy.deepcopy(self.vector)
                mutate(
                    candidate["fixture_derivation"][
                        "state_export_publisher_surface"
                    ]
                )
                with self.assertRaisesRegex(
                    generator.ManifestVectorError,
                    "publisher ABI surface",
                ):
                    checker.validate_vector_mechanics(candidate, self.profile)

        candidate = copy.deepcopy(self.vector)
        governance_address = candidate["semantic_round_trip"][
            "contract_address_by_key"
        ]["GOVERNANCE_LAYER"]
        publisher_pointer_type = generator.hex_keccak(b"STATE_EXPORT_PUBLISHER")
        publisher_pointer = next(
            pointer
            for pointer in candidate["payload"]["pointers"]
            if pointer["pointerType"] == publisher_pointer_type
        )
        governance_registry_record = next(
            record
            for record in candidate["payload"]["registryEntries"]
            if record["module"] == governance_address
        )
        publisher_pointer["interfaceId"] = "0xa5971448"
        governance_registry_record["interfaceId"] = "0xa5971448"
        with self.assertRaisesRegex(
            generator.ManifestVectorError,
            "exact IStreamStateExportPublisher interface ID",
        ):
            checker.validate_vector_mechanics(candidate, self.profile)

    def test_finality_adapter_uses_canonical_interface_id(self) -> None:
        candidate = copy.deepcopy(self.vector)
        adapter_address = candidate["semantic_round_trip"][
            "contract_address_by_key"
        ]["STREAM_CORE_FINALITY_ADAPTER"]
        adapter_record = next(
            record
            for record in candidate["payload"]["registryEntries"]
            if record["module"] == adapter_address
        )
        self.assertEqual(
            adapter_record["interfaceId"],
            generator.STREAM_CORE_FINALITY_ADAPTER_INTERFACE_ID,
        )

        adapter_record["interfaceId"] = "0xc7c3f294"
        with self.assertRaisesRegex(
            generator.ManifestVectorError,
            "exact IStreamCoreFinalityAdapter interface ID",
        ):
            checker.validate_vector_mechanics(candidate, self.profile)

    def test_normative_domain_preimages_and_root_magic_recompute(self) -> None:
        expected = {
            generator.PAYLOAD_SCHEMA_ID: b"STREAM_SYSTEM_MANIFEST_PAYLOAD_V1",
            generator.CANONICALIZATION_ID: b"RFC8785_JCS",
            generator.PAYLOAD_LEAF_DOMAIN: b"6529STREAM_SYSTEM_MANIFEST_PAYLOAD_LEAF_V1",
            generator.PAYLOAD_LIST_DOMAIN: b"6529STREAM_SYSTEM_MANIFEST_PAYLOAD_LIST_V1",
            generator.PAYLOAD_ROOT_DOMAIN: b"6529STREAM_SYSTEM_MANIFEST_PAYLOAD_ROOT_V1",
            generator.DEPLOYMENT_IDENTITY_DOMAIN: b"6529STREAM_DEPLOYMENT_IDENTITY_V1",
            generator.GGP_PROBE_BINDING_DOMAIN: b"6529STREAM_GGP_PROBE_BINDING_V1",
        }
        for digest, preimage in expected.items():
            self.assertEqual(generator.hex_keccak(preimage), digest)
        self.assertEqual(
            "0x" + generator.keccak256(b"STREAM_SYSTEM_MANIFEST_ROOT")[:4].hex(),
            generator.ROOT_DESCRIPTOR_MAGIC,
        )
        self.assertEqual(
            int("c04c14e3", 16) ^ int("cfc07fec", 16),
            int("0f8c6b0f", 16),
        )
        self.assertEqual(
            int("c04c14e3", 16) ^ int("76896171", 16),
            int("b6c57592", 16),
        )

    def test_deployment_identity_is_one_global_profile_bound_digest(self) -> None:
        profile_sha256 = self.vector["source"]["genesis_deployment_profile_sha256"]
        expected = generator.derive_target_deployment_identity_hash(profile_sha256)
        derivation = self.vector["fixture_derivation"]["deployment_identity"]
        self.assertEqual(
            derivation["identity_view_hash"],
            generator.derive_target_identity_view_hash(profile_sha256),
        )
        self.assertEqual(derivation["hash"], expected)
        self.assertEqual(
            self.vector["semantic_round_trip"]["deployment_manifest_hash"],
            expected,
        )

        payload = self.vector["payload"]
        occurrences = [
            *(item["deploymentManifestHash"] for item in payload["contracts"]),
            *(item["deploymentManifestHash"] for item in payload["pointers"]),
            *(item["deploymentManifestHash"] for item in payload["registryEntries"]),
            *(
                item["probeDeploymentManifestHash"]
                for item in payload["gasParameterProbes"]
            ),
            *(item["deploymentManifestHash"] for item in payload["criticalFallbacks"]),
        ]
        self.assertTrue(occurrences)
        self.assertEqual(set(occurrences), {expected})

    def test_checker_rejects_any_non_global_deployment_identity_occurrence(self) -> None:
        mutations = (
            ("contract entry", "contracts", 1, "deploymentManifestHash"),
            ("pointer", "pointers", 0, "deploymentManifestHash"),
            ("registry entry", "registryEntries", 0, "deploymentManifestHash"),
            (
                "probe binding",
                "gasParameterProbes",
                0,
                "probeDeploymentManifestHash",
            ),
            ("critical fallback", "criticalFallbacks", 0, "deploymentManifestHash"),
        )
        replacement = "0x" + "ff" * 32
        for label, array_name, index, field_name in mutations:
            with self.subTest(label=label):
                mutated = copy.deepcopy(self.vector)
                mutated["payload"][array_name][index][field_name] = replacement
                with self.assertRaisesRegex(
                    generator.ManifestVectorError,
                    "one release-wide deployment identity hash",
                ):
                    checker.validate_vector_mechanics(mutated, self.profile)

    def test_jcs_uses_utf16_key_order_and_exact_string_escaping(self) -> None:
        value = {
            "\ue000": "last",
            "😀": "supplementary-before-private-use",
            "€": "euro",
            "z": "quote=\" slash=/ backslash=\\ line=\n control=\u0001",
            "1": True,
            "\r": False,
        }
        self.assertEqual(
            generator.jcs_text(value),
            '{"\\r":false,"1":true,"z":"quote=\\\" slash=/ backslash=\\\\ line=\\n control=\\u0001","€":"euro","😀":"supplementary-before-private-use","\ue000":"last"}',
        )

    def test_jcs_rejects_non_schema_values_and_non_nfc_text(self) -> None:
        invalid_values = (
            None,
            1.25,
            -1,
            1 << 53,
            "e\u0301",
            "\ud800",
        )
        for value in invalid_values:
            with self.subTest(value=repr(value)):
                with self.assertRaises(generator.ManifestVectorError):
                    generator.jcs_bytes({"value": value})

    def test_chunk_split_and_root_descriptor_are_exact_and_bounded(self) -> None:
        chunks = self.vector["chunks"]
        self.assertGreater(len(chunks), 1)
        for chunk in chunks[:-1]:
            self.assertEqual(chunk["payload_length"], generator.CHUNK_PAYLOAD_BYTES)
        self.assertGreaterEqual(chunks[-1]["payload_length"], 1)
        self.assertLessEqual(chunks[-1]["payload_length"], generator.CHUNK_PAYLOAD_BYTES)
        descriptor = bytes.fromhex(self.vector["root_descriptor"]["encoded_hex"][2:])
        self.assertEqual(len(descriptor), 256 + 96 * len(chunks))
        self.assertLessEqual(len(descriptor), generator.MAX_MANIFEST_ROOT_DESCRIPTOR_BYTES)
        self.assertEqual(int.from_bytes(descriptor[6 * 32 : 7 * 32], "big"), 224)
        decoded = generator.decode_root_descriptor(descriptor)
        self.assertEqual(decoded["chunk_count"], len(chunks))
        self.assertEqual(
            generator.encode_root_descriptor(decoded["chunks"], decoded["total_bytes"]),
            descriptor,
        )

    def test_chunk_boundaries_cover_one_maximum_and_repeated_pointer(self) -> None:
        with self.assertRaisesRegex(generator.ManifestVectorError, "outside"):
            generator.split_payload(b"")
        with self.assertRaisesRegex(generator.ManifestVectorError, "outside"):
            generator.encode_root_descriptor([], 0)

        single_segment = generator.split_payload(b"x")
        self.assertEqual(single_segment, [b"x"])
        single_chunks = [
            {
                "pointer": "0x" + "11" * 20,
                "payload_length": 1,
                "payload_hash": generator.hex_keccak(b"x"),
            }
        ]
        single_descriptor = generator.encode_root_descriptor(single_chunks, 1)
        self.assertEqual(len(single_descriptor), 352)
        self.assertEqual(
            generator.decode_root_descriptor(single_descriptor)["chunks"],
            single_chunks,
        )

        maximum_payload = b"x" * generator.MAX_MANIFEST_PAYLOAD_BYTES
        maximum_segments = generator.split_payload(maximum_payload)
        self.assertEqual(len(maximum_segments), generator.MAX_MANIFEST_CHUNKS)
        self.assertTrue(
            all(
                len(segment) == generator.CHUNK_PAYLOAD_BYTES
                for segment in maximum_segments
            )
        )
        repeated_pointer = "0x" + "22" * 20
        repeated_hash = generator.hex_keccak(maximum_segments[0])
        maximum_chunks = [
            {
                "pointer": repeated_pointer,
                "payload_length": generator.CHUNK_PAYLOAD_BYTES,
                "payload_hash": repeated_hash,
            }
            for _ in maximum_segments
        ]
        maximum_descriptor = generator.encode_root_descriptor(
            maximum_chunks,
            generator.MAX_MANIFEST_PAYLOAD_BYTES,
        )
        self.assertEqual(
            len(maximum_descriptor),
            generator.MAX_MANIFEST_ROOT_DESCRIPTOR_BYTES,
        )
        decoded = generator.decode_root_descriptor(maximum_descriptor)
        self.assertEqual(decoded["chunk_count"], generator.MAX_MANIFEST_CHUNKS)
        self.assertEqual(decoded["total_bytes"], generator.MAX_MANIFEST_PAYLOAD_BYTES)
        self.assertEqual(decoded["chunks"], maximum_chunks)

    def test_root_descriptor_rejects_offset_padding_and_trailing_malleability(self) -> None:
        descriptor = bytearray.fromhex(self.vector["root_descriptor"]["encoded_hex"][2:])

        wrong_offset = bytearray(descriptor)
        wrong_offset[6 * 32 : 7 * 32] = (256).to_bytes(32, "big")
        with self.assertRaisesRegex(generator.ManifestVectorError, "offset"):
            generator.decode_root_descriptor(bytes(wrong_offset))

        wrong_padding = bytearray(descriptor)
        wrong_padding[4] = 1
        with self.assertRaisesRegex(generator.ManifestVectorError, "padding"):
            generator.decode_root_descriptor(bytes(wrong_padding))

        with self.assertRaisesRegex(generator.ManifestVectorError, "trailing"):
            generator.decode_root_descriptor(bytes(descriptor) + b"\x00" * 32)

    def test_caps_fail_closed(self) -> None:
        with self.assertRaisesRegex(generator.ManifestVectorError, "outside"):
            generator.split_payload(b"x" * (generator.MAX_MANIFEST_PAYLOAD_BYTES + 1))
        minimal_chunk = {
            "pointer": "0x" + "11" * 20,
            "payload_length": 1,
            "payload_hash": generator.hex_keccak(b"x"),
        }
        with self.assertRaisesRegex(generator.ManifestVectorError, "outside"):
            generator.encode_root_descriptor(
                [minimal_chunk] * (generator.MAX_MANIFEST_CHUNKS + 1),
                generator.MAX_MANIFEST_CHUNKS + 1,
            )

    def test_one_and_thirty_two_chunk_boundaries_and_repeated_pointer_round_trip(self) -> None:
        for total_bytes, expected_count, expected_descriptor_bytes in (
            (1, 1, 352),
            (generator.MAX_MANIFEST_PAYLOAD_BYTES, 32, 3_328),
        ):
            with self.subTest(total_bytes=total_bytes):
                segments = generator.split_payload(b"x" * total_bytes)
                self.assertEqual(len(segments), expected_count)
                chunks = generator._chunk_records(segments)
                descriptor_chunks = [
                    {
                        "pointer": chunk["pointer"],
                        "payload_length": chunk["payload_length"],
                        "payload_hash": chunk["payload_hash"],
                    }
                    for chunk in chunks
                ]
                descriptor = generator.encode_root_descriptor(
                    descriptor_chunks, total_bytes
                )
                self.assertEqual(len(descriptor), expected_descriptor_bytes)
                self.assertEqual(
                    generator.decode_root_descriptor(descriptor)["chunks"],
                    descriptor_chunks,
                )

        repeated_segment = b"x" * generator.CHUNK_PAYLOAD_BYTES
        repeated_chunk = {
            "pointer": "0x" + "11" * 20,
            "payload_length": len(repeated_segment),
            "payload_hash": generator.hex_keccak(repeated_segment),
        }
        repeated_descriptor = generator.encode_root_descriptor(
            [repeated_chunk, repeated_chunk], 2 * len(repeated_segment)
        )
        self.assertEqual(
            generator.decode_root_descriptor(repeated_descriptor)["chunks"],
            [repeated_chunk, repeated_chunk],
        )

    def test_checker_rejects_production_or_readiness_relabeling(self) -> None:
        for field in ("production_candidate", "readiness_evidence"):
            mutated = copy.deepcopy(self.vector)
            mutated[field] = True
            with self.subTest(field=field):
                with self.assertRaisesRegex(generator.ManifestVectorError, "cannot"):
                    checker.validate_vector_mechanics(mutated, self.profile)

    def test_checker_rejects_payload_semantic_and_schema_drift(self) -> None:
        changed_address = copy.deepcopy(self.vector)
        changed_address["payload"]["aggregate"]["metadataRouter"] = "0x" + "ab" * 20
        with self.assertRaisesRegex(generator.ManifestVectorError, "METADATA_ROUTER"):
            checker.validate_vector_mechanics(changed_address, self.profile)

        unknown_member = copy.deepcopy(self.vector)
        unknown_member["payload"]["governanceRegistryRoots"] = {}
        with self.assertRaisesRegex(generator.ManifestVectorError, "extra"):
            checker.validate_vector_mechanics(unknown_member, self.profile)

        timestamp_member = copy.deepcopy(self.vector)
        timestamp_member["payload"]["registryEntries"][0]["registeredAt"] = "1"
        with self.assertRaisesRegex(generator.ManifestVectorError, "extra"):
            checker.validate_vector_mechanics(timestamp_member, self.profile)

    def test_checker_rejects_canonical_bytes_and_chunk_boundary_drift(self) -> None:
        changed_bytes = copy.deepcopy(self.vector)
        canonical_hex = changed_bytes["canonical_payload"]["utf8_hex"]
        changed_bytes["canonical_payload"]["utf8_hex"] = (
            canonical_hex[:-2] + ("00" if canonical_hex[-2:] != "00" else "01")
        )
        with self.assertRaises(generator.ManifestVectorError):
            checker.validate_vector_mechanics(changed_bytes, self.profile)

        changed_boundary = copy.deepcopy(self.vector)
        changed_boundary["chunks"][0]["payload_length"] -= 1
        with self.assertRaisesRegex(generator.ManifestVectorError, "length"):
            checker.validate_vector_mechanics(changed_boundary, self.profile)

    def test_profile_drift_invalidates_the_committed_vector(self) -> None:
        changed_profile = copy.deepcopy(self.profile)
        changed_profile["entries"][0]["requirement"] += " (drift)"
        changed_raw = (
            json.dumps(changed_profile, indent=2, ensure_ascii=False) + "\n"
        ).encode("utf-8")
        with self.assertRaisesRegex(generator.ManifestVectorError, "drift|does not match"):
            checker.validate_committed_vector(
                self.vector,
                None,
                changed_profile,
                changed_raw,
            )

    def test_noncanonical_vector_file_formatting_is_rejected(self) -> None:
        with self.assertRaisesRegex(generator.ManifestVectorError, "formatting"):
            checker.validate_committed_vector(
                self.vector,
                b" " + self.vector_raw,
                self.profile,
                self.profile_raw,
            )

    def test_generator_output_is_byte_identical(self) -> None:
        expected = generator.render_vector(
            generator.build_vector(self.profile, self.profile_raw)
        ).encode("utf-8")
        self.assertEqual(expected, self.vector_raw)
        with tempfile.TemporaryDirectory() as temporary:
            output = Path(temporary) / "vector.json"
            self.assertEqual(
                generator.main(
                    [
                        "--profile",
                        str(PROFILE_PATH),
                        "--output",
                        str(output),
                    ]
                ),
                0,
            )
            self.assertEqual(output.read_bytes(), self.vector_raw)


if __name__ == "__main__":
    unittest.main()

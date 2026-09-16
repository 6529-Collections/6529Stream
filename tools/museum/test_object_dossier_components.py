"""Supplied-component admission proves local byte agreement, not conformance."""
from copy import deepcopy
from hashlib import sha256
import json
import unittest
from unittest.mock import patch

from .canonical import MuseumError, dumps, keccak256, subject_id
from .object_dossier_components import (EVIDENCE_STATUS, MODE, REQUIREMENT_CODES, SCHEMA_BYTES,
    SCHEMA_PATH, SOURCE_FIELDS, admit, generate, validate_source_state)


CORE = "0x" + "11" * 20
BLOCK = "0x" + "22" * 32
HEAD = "0x" + "33" * 32


def source_state():
    return {"chainId": "31337", "core": CORE, "collectionId": "1", "tokenId": "7", "collectionSerial": "1",
        "subjectId": subject_id("token", "31337", CORE, "1", token_id="7"), "blockNumber": "900",
        "blockHash": BLOCK, "canonicalCitation": "eip155:31337/erc721:" + CORE + "/7@chain:" + HEAD}


def component(identifier, path, content, requirement=None):
    return {"id": identifier, "path": path, "requirement": requirement or REQUIREMENT_CODES[0],
        "profile": "EXTERNAL_COMPONENT_V1", "bytes": str(len(content)),
        "sha256": "0x" + sha256(content).hexdigest(), "keccak256": keccak256(content)}


class ComponentAdmissionTests(unittest.TestCase):
    def setUp(self):
        self.source = source_state()
        self.content = b'{"claimedSemanticStatus":"pass"}'
        self.files = {"evidence/item.json": self.content}
        self.value = {"mode": MODE, "version": "1", "disclosure": "public", "sourceState": deepcopy(self.source),
            "components": [component("component:one", "evidence/item.json", self.content)]}

    def admit(self, value=None, files=None, source=None):
        raw = dumps(self.value if value is None else value)
        return admit(raw, keccak256(raw), self.files if files is None else files, self.source if source is None else source)

    def test_opaque_assertions_stay_supplied_unverified(self):
        envelope, commitments = self.admit()
        self.assertEqual(envelope, self.value)
        self.assertEqual(commitments, {REQUIREMENT_CODES[0]: (keccak256(self.content),)})
        self.assertEqual(EVIDENCE_STATUS, "supplied_unverified")
        self.assertNotIn("status", envelope)
        self.assertNotIn("conformance", envelope)

    def test_identical_bytes_in_distinct_occurrences_and_roles_are_preserved(self):
        second = REQUIREMENT_CODES[1]
        rows = [component("a:first", "first.bin", self.content),
                component("b:again", "again.bin", self.content),
                component("c:other-role", "other.bin", self.content, second)]
        value = self.value | {"components": rows}
        envelope, commitments = self.admit(value, {row["path"]: self.content for row in rows})
        self.assertEqual(envelope["components"], rows)
        self.assertEqual(len(envelope["components"]), 3)
        self.assertEqual(commitments, {REQUIREMENT_CODES[0]: (keccak256(self.content),), second: (keccak256(self.content),)})

    def test_mapping_sorts_unique_hashes_without_sorting_occurrences_by_hash(self):
        rows = [component("a:first", "one.bin", b"one"), component("b:second", "two.bin", b"two")]
        envelope, commitments = self.admit(self.value | {"components": rows}, {"one.bin": b"one", "two.bin": b"two"})
        self.assertEqual(envelope["components"], rows)
        self.assertEqual(commitments[REQUIREMENT_CODES[0]], tuple(sorted((keccak256(b"one"), keccak256(b"two")))))

    def test_empty_optional_envelope_contributes_nothing(self):
        envelope, commitments = self.admit(self.value | {"components": []}, {})
        self.assertEqual(envelope["components"], [])
        self.assertEqual(commitments, {})

    def test_public_disclosure_declaration_is_required_and_exact(self):
        missing = deepcopy(self.value)
        missing.pop("disclosure")
        for value in (missing, *(self.value | {"disclosure": disclosure}
                for disclosure in ("restricted", "private", "PUBLIC", "", None, True, False))):
            with self.subTest(disclosure=value.get("disclosure", "missing")):
                with self.assertRaisesRegex(MuseumError, "closed schema"):
                    self.admit(value)

    def test_external_hash_is_required_and_canonical(self):
        raw = dumps(self.value)
        for pin in (None, True, "0x" + "00" * 32, "0x" + "44" * 32, keccak256(raw).upper()):
            with self.subTest(pin=pin), self.assertRaises(MuseumError):
                admit(raw, pin, self.files, self.source)

    def test_noncanonical_or_duplicate_key_json_is_rejected_even_with_matching_pin(self):
        for raw in (json.dumps(self.value, indent=2).encode(),
                    dumps(self.value).replace(b'"version":"1"', b'"version":"1","version":"1"')):
            with self.subTest(raw=raw[:40]), self.assertRaises(MuseumError):
                admit(raw, keccak256(raw), self.files, self.source)

    def test_hash_and_size_mismatches_fail(self):
        for key, replacement in (("bytes", "1"), ("sha256", "0x" + "44" * 32),
                                 ("keccak256", "0x" + "55" * 32), ("sha256", "0x" + "00" * 32)):
            value = deepcopy(self.value); value["components"][0][key] = replacement
            with self.subTest(key=key), self.assertRaises(MuseumError): self.admit(value)
        with self.assertRaises(MuseumError): self.admit(files={"evidence/item.json": b"rewritten"})

    def test_exact_reference_state_includes_source_block_and_serial(self):
        for key, replacement in (("blockNumber", "901"), ("blockHash", "0x" + "44" * 32),
                                 ("collectionSerial", "2"), ("collectionId", "2")):
            value = deepcopy(self.value); value["sourceState"][key] = replacement
            with self.subTest(key=key), self.assertRaises(MuseumError): self.admit(value)
        value = deepcopy(self.value)
        value["sourceState"]["canonicalCitation"] = value["sourceState"]["canonicalCitation"].replace(HEAD, BLOCK)
        with self.assertRaises(MuseumError): self.admit(value)

    def test_foreign_original_token_or_subject_is_rejected(self):
        foreign = deepcopy(self.source)
        foreign["tokenId"] = "8"
        foreign["subjectId"] = subject_id("token", "31337", CORE, "1", token_id="8")
        foreign["canonicalCitation"] = foreign["canonicalCitation"].replace("/7@", "/8@")
        with self.assertRaises(MuseumError): self.admit(self.value | {"sourceState": foreign})
        for subject in ("0x" + "00" * 32, subject_id("collection", "31337", CORE, "1")):
            value = deepcopy(self.value); value["sourceState"]["subjectId"] = subject
            with self.subTest(subject=subject), self.assertRaises(MuseumError):
                self.admit(value, source=value["sourceState"])

    def test_protocol_numbers_are_strings_uint256_and_nonzero_identities(self):
        for key, replacement in (("chainId", 31337), ("tokenId", True), ("collectionId", "01"),
                                 ("tokenId", str(2**256)), ("collectionSerial", "0"), ("chainId", "0"),
                                 ("blockNumber", "-1"), ("blockNumber", str(2**256)),
                                 ("core", "0x" + "00" * 20), ("blockHash", "0x" + "00" * 32)):
            source = self.source | {key: replacement}
            with self.subTest(key=key, value=replacement), self.assertRaises(MuseumError):
                self.admit(self.value | {"sourceState": source}, source=source)

    def test_qualified_original_citation_is_required(self):
        for citation in (self.source["canonicalCitation"].split("@")[0],
                         self.source["canonicalCitation"].replace("@chain:", "@block:"),
                         self.source["canonicalCitation"].replace("/7@", "/8@"),
                         self.source["canonicalCitation"].replace(HEAD, "0x" + "00" * 32)):
            source = self.source | {"canonicalCitation": citation}
            with self.subTest(citation=citation), self.assertRaises(MuseumError):
                self.admit(self.value | {"sourceState": source}, source=source)

    def test_unknown_requirements_null_boolean_and_extra_claim_fields_fail(self):
        for key, replacement in (("requirement", "UNKNOWN_REQUIREMENT"), ("profile", None),
                                 ("bytes", True), ("sha256", False), ("keccak256", None)):
            value = deepcopy(self.value); value["components"][0][key] = replacement
            with self.subTest(key=key), self.assertRaises(MuseumError): self.admit(value)
        for field in ("status", "complete", "absence", "conformance"):
            for target in ("envelope", "row", "source"):
                value = deepcopy(self.value)
                selected = value if target == "envelope" else value["components"][0] if target == "row" else value["sourceState"]
                selected[field] = True
                with self.subTest(field=field, target=target), self.assertRaises(MuseumError): self.admit(value)

    def test_ids_must_be_bounded_stable_sorted_and_unique(self):
        for identifiers in (("same", "same"), ("z", "a"), (" a", "b"), ("a\n", "b"), ("a" * 257, "b")):
            rows = [component(identifiers[0], "one.bin", b"one"), component(identifiers[1], "two.bin", b"two")]
            with self.subTest(ids=identifiers), self.assertRaises(MuseumError):
                self.admit(self.value | {"components": rows}, {"one.bin": b"one", "two.bin": b"two"})

    def test_versioned_profile_names_are_required(self):
        for profile in ("", "unversioned", "COMPONENT_V0", "COMPONENT_V01", " COMPONENT_V1", "COMPONENT_V1\n"):
            value = deepcopy(self.value); value["components"][0]["profile"] = profile
            with self.subTest(profile=profile), self.assertRaises(MuseumError): self.admit(value)

    def test_paths_are_portable_and_exact_unique_file_set(self):
        for path in ("../escape", "/absolute", "C:/absolute", "back\\slash", "double//slash", "./dot", "nul.txt", "dir/CON", "trailing.", "bad%name", "bad?name"):
            value = deepcopy(self.value); value["components"][0]["path"] = path
            with self.subTest(path=path), self.assertRaises(MuseumError): self.admit(value, {path: self.content})
        for names in (("same.bin", "same.bin"), ("Same.bin", "same.bin"), ("file", "file/child"), ("Dir/a", "dir/b")):
            rows = [component("a", names[0], b"one"), component("b", names[1], b"two")]
            with self.subTest(paths=names), self.assertRaises(MuseumError):
                self.admit(self.value | {"components": rows}, {names[0]: b"one", names[1]: b"two"})
        with self.assertRaises(MuseumError): self.admit(files={})
        with self.assertRaises(MuseumError): self.admit(files=self.files | {"extra.bin": b"extra"})
        with self.assertRaises(MuseumError): self.admit(files={"evidence/item.json": bytearray(self.content)})

    def test_aggregate_and_manifest_bounds(self):
        raw = dumps(self.value)
        with patch("tools.museum.object_dossier_components.MAX_BYTES", len(raw) + len(self.content)-1):
            with self.assertRaisesRegex(MuseumError, "aggregate byte bound"): self.admit()
        with patch("tools.museum.object_dossier_components.MAX_MANIFEST", len(raw)-1):
            with self.assertRaisesRegex(MuseumError, "envelope byte bound"): self.admit()
        with patch("tools.museum.object_dossier_components.MAX_FILES", 0):
            with self.assertRaisesRegex(MuseumError, "bounded exact dictionary"): self.admit()

    def test_source_identity_matches_original_token_scope_without_capture_import_at_admission(self):
        # Test-only comparison. The implementation imports only canonical
        # identity primitives, never the capture/statement-generation module.
        from .token_media_inputs import token_scope
        for token in ("1", "7", str(2**256 - 1)):
            scope = token_scope("31337", CORE, "1", token)
            source = self.source | {"tokenId": token, "subjectId": scope.subject_id,
                "canonicalCitation": f"eip155:31337/erc721:{CORE}/{token}@chain:{HEAD}"}
            self.assertEqual(validate_source_state(source)["subjectId"], scope.subject_id)
        self.assertEqual(set(self.source), set(SOURCE_FIELDS))

    def test_checked_in_schema_is_generated_exactly(self):
        generate(check=True)
        self.assertEqual(SCHEMA_PATH.read_bytes(), SCHEMA_BYTES)


if __name__ == "__main__":
    unittest.main()

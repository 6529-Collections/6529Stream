"""Canonical name coverage, immutable declarations and exact chunk transport."""
from pathlib import Path
import unittest
from unittest.mock import patch

import rfc8785

from .canonical import MuseumError, dumps, keccak256, loads, schema_id
from .genesis_catalog import (BASE, ENTRIES, JCS, NAMES, RAW, ROOT, build,
                             normative_names, support_documents, validate_example)


class GenesisCatalog(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        with patch("socket.socket", side_effect=AssertionError("offline catalog")):
            cls.outputs = build(require_complete=True)
        cls.catalog = loads(cls.outputs[BASE + "catalog.json"], maximum=1048576)
        cls.plan = loads(cls.outputs[BASE + "admission-plan.json"], maximum=2097152)

    def test_29_ordered_names_are_exact_normative_table(self):
        self.assertEqual(NAMES, normative_names())
        self.assertEqual(len(NAMES), 29)
        self.assertEqual([r["name"] for r in self.catalog["entries"]], list(NAMES))
        self.assertTrue(self.catalog["sourceSetComplete"])
        self.assertEqual(self.catalog["missing"], [])

    def test_all_exact_files_schemas_interpreters_and_examples_are_committed(self):
        for row in self.catalog["entries"]:
            self.assertEqual(row["schemaId"], schema_id(row["name"]))
            self.assertTrue(row["examples"])
            for commitment in [row["definition"], row["interpreterSource"], *row["examples"]]:
                raw = (ROOT / commitment["path"]).read_bytes()
                self.assertEqual(commitment["keccak256"], keccak256(raw))
                self.assertEqual(commitment["byteLength"], str(len(raw)))

    def test_exact_chunk_order_lengths_hashes_and_reassembly(self):
        sizes = []
        for row in self.plan["documents"]:
            raw = (ROOT / row["sourcePath"]).read_bytes()
            reconstructed = []
            for i, chunk in enumerate(row["chunks"]):
                offset, length = int(chunk["offset"]), int(chunk["byteLength"])
                self.assertEqual(offset, i * 8192)
                self.assertEqual(chunk["index"], str(i))
                part = raw[offset:offset+length]; reconstructed.append(part)
                self.assertEqual(keccak256(part), chunk["keccak256"])
                if i < len(row["chunks"]) - 1: self.assertEqual(length, 8192)
                self.assertGreater(length, 0); self.assertLessEqual(length, 8192)
            self.assertEqual(b"".join(reconstructed), raw)
            self.assertEqual(row["specification"]["contentHash"], keccak256(raw))
            self.assertEqual(row["chunkHashes"], [r["keccak256"] for r in row["chunks"]])
            sizes.append(len(raw))
        self.assertGreater(max(sizes), 8192)

    def test_bootstrap_precedes_dependencies_and_no_same_id_collision(self):
        self.assertEqual([r["specification"]["name"] for r in self.plan["documents"][:2]], ["RAW_BYTES", "RFC8785_JCS"])
        seen = set()
        for row in self.plan["documents"]:
            self.assertNotIn(row["documentId"], seen)
            self.assertTrue(set(row["dependsOn"]) <= seen)
            seen.add(row["documentId"])
            self.assertEqual(row["specification"]["supersedesId"], "0x" + "00" * 32)
        declarations = {r["specification"]["name"]: r["specification"]["canonicalizationId"] for r in self.plan["documents"]}
        self.assertEqual(declarations["STREAM_IDENTITY_NOTARIZATION_V1"], RAW)
        self.assertEqual(declarations["STREAM_ARTIST_INTERVIEW_V1"], RAW)
        self.assertEqual(declarations["STREAM_LOAN_V1"], JCS)
        self.assertEqual(declarations["STREAM_CONDITION_REPORT_V1"], JCS)

    def test_no_observed_admission_or_acceptance_inferred_from_source_presence(self):
        for doc in (self.catalog, self.plan):
            self.assertFalse(any(doc["claims"].values()))
        self.assertEqual(self.plan["recipe"]["observedAdmissions"], [])
        for row in self.catalog["entries"]:
            self.assertEqual(row["registrationEvidence"]["status"], "not_observed")
            for example in row["examples"]:
                self.assertFalse(example["chainAuthority"])
                self.assertFalse(example["institutionalAcceptance"])

    def test_missing_canonical_schema_cannot_be_replaced_by_related_profile(self):
        original = Path.is_file
        missing = ROOT / "schemas/records/STREAM_IIIF_P3_MIN_V1.json"
        with patch.object(Path, "is_file", lambda p: False if p == missing else original(p)):
            with self.assertRaisesRegex(MuseumError, "incomplete canonical genesis"):
                build(require_complete=True)
            partial = loads(build()[BASE + "catalog.json"], maximum=1048576)
        row = next(r for r in partial["entries"] if r["name"] == "STREAM_IIIF_P3_MIN_V1")
        self.assertEqual(row["definitionStatus"], "missing")
        self.assertTrue(row["relatedDefinitionsNotSubstitutes"])
        self.assertFalse(partial["sourceSetComplete"])

    def test_same_title_cannot_hide_conflicting_embedded_schema_identity(self):
        entry = ENTRIES[0]; target = ROOT / entry.path
        original = Path.read_bytes
        value = loads(target.read_bytes(), maximum=524288)
        value["$id"] = "urn:6529stream:schema:DIFFERENT_MEANING"
        mutant = dumps(value)
        with patch.object(Path, "read_bytes", lambda p: mutant if p == target else original(p)):
            with self.assertRaisesRegex(MuseumError, "conflicting embedded schema identity"):
                build(require_complete=True)

    def test_native_companion_original_bytes_cannot_be_silently_redeclared(self):
        target = ROOT / "schemas/records/STREAM_RIGHTS_JSON_PROFILE_V1.json"
        original = Path.read_bytes
        mutant = target.read_bytes() + b"\n"
        with patch.object(Path, "read_bytes", lambda p: mutant if p == target else original(p)):
            with self.assertRaisesRegex(MuseumError, "support definition differs"):
                support_documents()

    def test_iiif_fractional_duration_does_not_use_record_integer_only_loader(self):
        from tools.metadata.genesis_iiif_profile import SCHEMA_BYTES, example
        entry = next(e for e in ENTRIES if e.name == "STREAM_IIIF_P3_MIN_V1")
        value = example(); value["items"][0]["duration"] = 1.25
        value["items"][0]["items"][0]["items"][0]["body"].update(type="Video", format="video/mp4", duration=1.25)
        self.assertEqual(validate_example(entry, loads(SCHEMA_BYTES), rfc8785.dumps(value)), value)

    def test_generated_artifacts_exact(self):
        for name, raw in self.outputs.items():
            self.assertEqual((ROOT / name).read_bytes(), raw)


if __name__ == "__main__":
    unittest.main()

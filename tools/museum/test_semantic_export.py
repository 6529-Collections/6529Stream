"""Archive manifest regressions using retained actual local Safe source inputs."""
from copy import copy, deepcopy
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

from .canonical import MuseumError, dumps, keccak256, loads, schema_id
from .package import write_package
from .package_v2 import _assemble, verify_package
from .recorded_projection import replay_source_bytes
from .semantic_export import (MANIFEST_PATH, MAX_PAYLOAD, NAME, POLICY_BYTES, POLICY_HASH,
    SCHEMA_BYTES, build_export, identity_evidence, source_scope, verify_export)
from .test_typed_authority_capture import FIXTURE, MANIFEST_HASH, ROOT
from .typed_authority_fixture import read, rebuild
from .typed_authority_profile import NAMES, SCHEMAS


class SemanticExportTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.temp = tempfile.TemporaryDirectory()
        cls.directory = Path(cls.temp.name)
        cls.inputs, _ = read(FIXTURE, MANIFEST_HASH)
        with patch("socket.socket", side_effect=AssertionError("export used network")):
            original = rebuild(cls.inputs)
            cls.source_directory = cls.directory / "source"
            write_package(original, cls.source_directory)
            cls.source_hash = original.manifest_hash
            cls.package = build_export(cls.source_directory, cls.source_hash, disclosure="public")
            cls.destination = cls.directory / "export"
            write_package(cls.package, cls.destination)
        cls.files = dict(cls.package.files)
        cls.manifest = loads(cls.files[MANIFEST_PATH], canonical=True)

    @classmethod
    def tearDownClass(cls): cls.temp.cleanup()

    def test_actual_originals_rebuild_offline_and_dispatch(self):
        with patch("socket.socket", side_effect=AssertionError("verification used network")):
            result = verify_package(self.destination, self.package.manifest_hash)
        self.assertEqual(result, self.package)
        for name, raw in self.inputs.items():
            if "input/source/inputs/" + name in self.files:
                self.assertEqual(raw, self.files["input/source/inputs/" + name])

    def test_compact_successor_does_not_mutate_v2_or_overflow_host(self):
        old = loads(SCHEMAS[NAMES[2]])
        new = loads(SCHEMA_BYTES)
        self.assertIn("sourceAuthoritySet", old["properties"])
        self.assertIn("resources", old["properties"])
        self.assertNotIn("authoritySelection", old["properties"])
        self.assertEqual(new["x-stream-profile"]["supersedesSchemaId"], schema_id(NAMES[2]))
        self.assertEqual(new["x-stream-schema-id"], schema_id(NAME))
        self.assertLessEqual(len(self.files[MANIFEST_PATH]), MAX_PAYLOAD)
        selection = loads(self.files[self.manifest["authoritySelection"]["path"]], maximum=524288)
        self.assertEqual(len(selection["basePolicy"]["sourceAuthoritySet"]), 25)
        self.assertEqual(selection["basePolicy"], loads(self.inputs["selection.json"], maximum=524288))
        self.assertEqual(selection["authorityPolicy"], loads(self.inputs["authority-selection.json"]))
        self.assertEqual(keccak256(dumps(selection)), self.manifest["selectionPolicyHash"])

    def test_scope_cites_exact_collection_head_without_inventing_token(self):
        scope = self.manifest["sourceState"]
        anchor = loads(self.inputs["anchor.json"])
        self.assertEqual(scope["blockHash"], anchor["blockHash"])
        self.assertEqual(scope["blockNumber"], anchor["blockNumber"])
        self.assertEqual(scope["core"], anchor["core"])
        self.assertEqual(scope["collectionId"], "1")
        self.assertIsNone(scope["tokenId"])
        self.assertEqual(scope["canonicalCitation"], "")
        self.assertEqual(scope["anchorSubject"]["kind"], "collection")
        self.assertEqual(scope["finalityQualifier"], "unfinalized_trusted_rpc_block")
        head, = scope["recordHeads"]
        self.assertEqual(head["recordHash"], "0x67063a94c9f24269ac80cd152e12ca265e3d7cdc444618eb819468079e7e99a7")
        self.assertEqual(scope["disclosurePolicyHash"], keccak256(self.files["semantic/disclosure.json"]))

    def test_all_entity_classes_and_original_assertions_are_retained(self):
        index = loads(self.files[self.manifest["components"]["entityIndex"]["path"]])
        self.assertEqual([r["id"] for r in index], sorted(r["id"] for r in index))
        self.assertEqual({r["kind"] for r in index}, {"linked_art", "stream_extension", "external"})
        self.assertEqual(len(index), 7)
        resources = loads(self.files[self.manifest["resourceIndex"]["path"]])
        self.assertEqual(len(resources), 5)
        assertion_sidecar = loads(self.files["semantic/assertions.json"], maximum=67108864)
        self.assertEqual(len(assertion_sidecar["base"]["publicSources"]), 15)
        for row in index:
            if row["kind"] == "linked_art":
                self.assertEqual(loads(self.files[row["path"]])["id"], row["id"])
            elif row["kind"] == "stream_extension":
                self.assertEqual(assertion_sidecar["base"]["extensionEntities"][0]["id"], row["id"])
            else: self.assertIsNone(row["path"])
        identity = loads(self.files["semantic/provenance.json"], maximum=67108864)["authorityIdentity"]
        self.assertEqual(identity[0]["declarations"][0]["declaration"]["source"]["recordHash"], "0xaf7a54943182d02adde0e2822bfa4e65e451cd97acdd8096d3b5c4d4dc581a53")

    def test_compatible_declaration_lineage_keeps_all_emitted_evidence(self):
        first = {"entityDeclaration": {"source": "ancestor"}, "declarationLineage": ["ancestor"]}
        later = {"entityDeclaration": {"source": "continuation"}, "declarationLineage": ["continuation", "ancestor"]}
        provenance = [{"entity": "urn:test:type", "sources": [first, later]},
            {"entity": "urn:test:other", "sources": [{"entityDeclaration": {"source": "foreign"}}]}]
        evidence = identity_evidence("urn:test:type", provenance)
        self.assertEqual(len(evidence["declarations"]), 2)
        self.assertEqual({row["declaration"]["source"] for row in evidence["declarations"]}, {"ancestor", "continuation"})

    def test_manifest_children_are_exact_non_circular_and_claims_remain_limited(self):
        refs = [*self.manifest["components"].values(), self.manifest["authoritySelection"],
            self.manifest["resourceIndex"], self.manifest["exportPolicy"]]
        for row in refs:
            self.assertNotEqual(row["path"], MANIFEST_PATH)
            raw = self.files[row["path"]]
            self.assertEqual(row["contentHash"]["digest"], keccak256(raw))
            self.assertEqual(row["byteLength"], str(len(raw)))
        self.assertIsNone(self.manifest["previousExport"])
        self.assertEqual(self.manifest["conformance"], {"streamProfile": "not_evaluated", "linkedArtModel": "pass", "linkedArtApi": "not_claimed"})
        self.assertEqual(self.manifest["completeness"], "incomplete")
        snapshots = loads(self.files["semantic/authoritySnapshots.json"], maximum=67108864)
        self.assertFalse(snapshots["publisherAuthenticated"])
        self.assertTrue(any(b"not bytes served or authenticated by Getty" in self.files[r["path"]] for r in snapshots["documents"]))
        self.assertEqual(keccak256(POLICY_BYTES), POLICY_HASH)

    def test_rehashed_manifest_tampering_fails_semantic_reconstruction(self):
        files = dict(self.files)
        altered = deepcopy(self.manifest); altered["sourceState"]["blockNumber"] = "999999"
        files[MANIFEST_PATH] = dumps(altered)
        metadata = loads(self.package.manifest, maximum=2097152); del metadata["files"]
        metadata["semanticManifestHash"] = keccak256(files[MANIFEST_PATH])
        forged = _assemble(self.directory, files, metadata)
        destination = self.directory / "forged"; write_package(forged, destination)
        with self.assertRaisesRegex(MuseumError, "reconstruction differs"):
            verify_export(destination, forged.manifest_hash)

    def test_restricted_or_wrong_external_pin_rejected_before_export(self):
        with self.assertRaisesRegex(MuseumError, "public export classification"):
            build_export(self.source_directory, self.source_hash, disclosure="restricted")
        with self.assertRaisesRegex(MuseumError, "external hash mismatch"):
            build_export(self.source_directory, "0x" + "99" * 32, disclosure="public")

    def test_mixed_scope_is_rejected_before_projection_outputs(self):
        pins = loads(self.inputs["pins.json"])
        source = replay_source_bytes(ROOT, self.inputs,
            **{name + "_hash": pins[name + "_hash"] for name in ("source", "publication", "interpretation", "profile")})
        altered = copy(source)
        capture = loads(source.capture_bytes, maximum=67108864)
        capture["records"][0]["subject"][1] = "2"
        altered.capture_bytes = dumps(capture)
        with self.assertRaisesRegex(MuseumError, "mixed export subjects"):
            source_scope(altered)


if __name__ == "__main__": unittest.main()

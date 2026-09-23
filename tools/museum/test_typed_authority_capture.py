"""Actual retained local Safe records; authority snapshot remains explicitly synthetic."""
import hashlib
from pathlib import Path
import unittest
from unittest.mock import patch

from .authority import _reconcile
from .authority_admission_v2 import candidates, bind_declarations
from .authority_v2 import PROFILE_HASH, _body
from .canonical import MuseumError, dumps, keccak256, loads, schema_id
from .recorded_projection import replay_source_bytes
from .typed_authority_fixture import read, rebuild
from .typed_authority_profile import NAMES, TypedAuthorityProfile

ROOT = Path(__file__).resolve().parents[2] / "schemas/museum"
FIXTURE = ROOT / "typed-account-profile/local-fixture"
MANIFEST_HASH = "0x2fe792608f9c37fe9615d9a54a555c4af9dc8fe30c65b60d98f3200fc22bf343"
AUTHORITY_HASH = "0x4ac6c959e4e98c3f9fb90691022049ec534edc247125a1b89daa59caf015c383"


class ActualTypedAuthorityCapture(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.inputs, cls.manifest = read(FIXTURE, MANIFEST_HASH)
        pins = loads(cls.inputs["pins.json"], canonical=True)
        with patch("socket.socket", side_effect=AssertionError("retained replay used a network")):
            cls.source = replay_source_bytes(ROOT, cls.inputs,
                **{name + "_hash": pins[name + "_hash"] for name in ("source", "publication", "interpretation", "profile")})
            cls.package = rebuild(cls.inputs)

    def test_actual_original_and_later_self_review_reconstruct_golden_package(self):
        self.assertEqual(self.package.manifest_hash, AUTHORITY_HASH)
        files = dict(self.package.files); report = loads(files["authority/report.json"])
        self.assertEqual(report["results"][0]["status"], "resolved")
        self.assertFalse(any(report["claims"].values()))
        row, = loads(files["authority/sidecar.json"], maximum=524288)
        self.assertEqual(row["assertion"]["origin"], "automated_mapping")
        self.assertEqual(row["source"]["recordHash"], "0x722011eb8894460595a7bd9c4a794bddd1285005257088360c8bde9b98eef6cf")
        self.assertEqual(row["source"]["schemaId"], schema_id(NAMES[1]))
        self.assertEqual(row["selectionBasis"], "account_confirmed_SELF_review")
        review, = row["reviewEvidence"]
        self.assertTrue(review["selfReview"])
        self.assertEqual(review["reviewRecord"]["recordHash"], "0x67063a94c9f24269ac80cd152e12ca265e3d7cdc444618eb819468079e7e99a7")
        self.assertLess(self.source.positions[row["source"]["recordHash"]], self.source.positions[review["reviewRecord"]["recordHash"]])
        declaration = row["entityDeclaration"]
        self.assertEqual(declaration["value"]["kind"], "type")
        self.assertEqual(declaration["source"]["recordHash"], "0xaf7a54943182d02adde0e2822bfa4e65e451cd97acdd8096d3b5c4d4dc581a53")
        self.assertLess(self.source.positions[declaration["source"]["recordHash"]], self.source.positions[row["source"]["recordHash"]])
        resource = loads(files[loads(files["authority/index.json"])["resources"][0]["path"]])
        self.assertEqual(resource["type"], "Type")
        self.assertEqual(resource["equivalent"][0]["id"], "http://vocab.getty.edu/aat/300033618")

    def test_actual_record_does_not_turn_synthetic_snapshot_into_publisher_evidence(self):
        self.assertEqual(self.manifest["snapshotMode"], "synthetic_fixture")
        self.assertFalse(self.manifest["authorityPublisherAuthenticated"])
        descriptor = loads(self.inputs["authority-snapshot.descriptor.json"])
        self.assertIn("not bytes served or authenticated by Getty", descriptor["attribution"])
        original = self.inputs["authority-publisher-response.json"]
        metadata = loads(self.inputs["authority-publisher-response-evidence.json"])
        self.assertEqual(hashlib.sha256(original).hexdigest(), metadata["sha256"])
        self.assertIn("not used as the reconciled snapshot", metadata["representation"])
        self.assertNotEqual(original, self.inputs["authority-snapshot.rdf.json"])

    def test_registered_closure_contains_new_schemas_and_exact_predecessors(self):
        self.assertIs(type(self.source.profile), TypedAuthorityProfile)
        self.assertEqual(len(self.source.records), 15)
        interpretation = loads(self.source.interpretation_bytes, maximum=16777216)
        retained = {row["documentId"]: row for row in interpretation["documents"]}
        from .chain_abi import decode
        from .independent_wire import DOCUMENT
        for name, (_, raw) in self.source.profile.documents.items():
            self.assertEqual(retained[schema_id(name)]["originalHex"], "0x" + raw.hex())
            if name in self.source.profile.document_predecessors:
                view, = decode((DOCUMENT,), bytes.fromhex(retained[schema_id(name)]["rawViewHex"][2:]))
                self.assertEqual(view[3][4], self.source.profile.document_predecessors[name])

    def test_omitting_actual_review_withholds_the_same_original_mapping(self):
        policy = loads(self.inputs["authority-selection.json"]); policy["reviewerAuthoritySet"] = []
        selection = dumps(policy)
        rows, _ = candidates(self.source, selection, keccak256(selection))
        bind_declarations(self.source, self.inputs["plan.json"], rows)
        self.assertFalse(rows[0]["eligible"])
        path = _body(rows[0]["assertion"])["alignment"]["snapshotRef"]["path"]
        descriptor, raw = self.inputs["authority-snapshot.descriptor.json"], self.inputs["authority-snapshot.rdf.json"]
        request = self.inputs["authority-requests.json"]
        result = _reconcile(request, rows, {path: (descriptor, raw, keccak256(descriptor))}, request_hash=keccak256(request),
            profile_hash=PROFILE_HASH, mode="recorded_account_authority_reconciliation", model=self.source.profile.linked_art)
        self.assertEqual(loads(result["authority/report.json"])["results"][0]["status"], "unresolved")
        self.assertEqual(loads(result["authority/index.json"])["resources"], [])

    def test_retained_archive_requires_the_external_manifest_pin(self):
        with self.assertRaisesRegex(MuseumError, "manifest pin differs"):
            read(FIXTURE, "0x" + "99" * 32)


if __name__ == "__main__": unittest.main()

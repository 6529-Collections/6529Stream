"""Actual captured-token partial assembly and closed admission boundaries."""
from copy import deepcopy
from pathlib import Path
import unittest
from unittest.mock import patch

from .bagit import read_tree
from .canonical import MuseumError, dumps, keccak256, loads
from . import object_dossier as dossier

FIXTURE = Path(__file__).resolve().parents[2] / "schemas/museum/dossier/token-local-fixture"
FIXTURE_HASH = "0x62ad190d7baa57290c72d22a98fb2249bc043b632597fc4454e77178af883425"


class AssemblyBoundaryTests(unittest.TestCase):
    def test_partial_schema_cannot_assert_full_conformance(self):
        schema = loads(dossier.schema_bytes(), canonical=True)
        for key in ("fullObjectDossierConformance", "completeCanonicalData", "completeLaneHistory",
                    "authoritativeRenderInventory", "completeOwnershipHistory", "profileRegistered"):
            self.assertIs(schema["properties"]["claims"]["properties"][key]["const"], False)

    def test_wrong_external_manifest_pin_rejects_before_native_replay(self):
        with patch.object(dossier, "_replay", side_effect=AssertionError("unexpected replay")):
            with self.assertRaisesRegex(MuseumError, "external manifest pin"):
                dossier.verify({"manifest.json": b"{}"}, "0x" + "ab" * 32)

    def test_links_unsafe_paths_and_nonbytes_are_rejected(self):
        for files in ({"../outside": b"x"}, {"C:/outside": b"x"},
                      {"a": b"x", "A": b"x"}, {"a": "x"}):
            with self.subTest(files=tuple(files)):
                with self.assertRaises(MuseumError): dossier._bounded(files)

    def test_tool_snapshot_is_inert_exact_bounded_utf8(self):
        snapshot = {"tool/" + name + ".txt": b"raise RuntimeError('never execute')\n"
                    for name in dossier.SOURCE_NAMES}
        retained = dossier._tool_snapshot(snapshot)
        self.assertEqual({key: value for key, value in retained.items() if key.endswith(".txt")}, snapshot)
        index = loads(retained["tool/source-index.json"], canonical=True)
        self.assertFalse(index["completeRuntimeArchive"])
        for mutation in ({}, snapshot | {"tool/extra.txt": b"x"},
                         snapshot | {next(iter(snapshot)): b"bad\r\n"}):
            with self.assertRaises(MuseumError): dossier._tool_snapshot(mutation)


class ActualPartialAssemblyTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.retained = read_tree(FIXTURE)
        with patch("socket.socket", side_effect=AssertionError("assembly used network")):
            cls.result = dossier.assemble(cls.retained, FIXTURE_HASH)
        cls.files = dict(cls.result.files)
        cls.manifest = loads(cls.result.manifest, maximum=2097152, canonical=True)

    def test_exact_source_and_old_scoped_artifacts_preserved(self):
        state = self.manifest["sourceState"]
        self.assertEqual(state["tokenId"], "1")
        self.assertEqual(state["collectionSerial"], "1")
        self.assertEqual(state["blockNumber"], "1311")
        self.assertEqual(state["blockHash"], "0xeb97545385853d7aa947b8f440360be7b0c277e50f64113945bc377d33aa2818")
        self.assertEqual(state["subjectId"], "0x2f4ce6f76fb30d506d480e39202ed6fbf92f5721a6c98fa85af9b9b38a6d5331")
        self.assertEqual(self.manifest["source"]["scopedBagManifestHash"],
                         "0xa5b26d213c405e04fb75d65d8bc457fd5bb1644c152025bf1cffd84a9ce36153")
        for name, raw in self.retained.items():
            self.assertEqual(self.files["source/retained/" + name], raw)

    def test_selected_png_and_mint_never_fill_complete_inventory(self):
        self.assertFalse(self.result.report["complete"])
        self.assertEqual(len(self.result.report["partialEvidence"]), 3)
        self.assertEqual(self.manifest["claims"], dossier.CLAIMS)
        self.assertFalse(self.manifest["claims"]["authoritativeRenderInventory"])
        self.assertFalse(self.manifest["claims"]["completeOwnershipHistory"])
        self.assertFalse(self.manifest["claims"]["fullObjectDossierConformance"])

    def test_original_tool_snapshot_and_full_source_replay_verify_offline(self):
        original = dossier._tool_snapshot
        def retained_only(snapshot=None):
            self.assertIsNotNone(snapshot, "verifier regenerated current source")
            return original(snapshot)
        with patch("socket.socket", side_effect=AssertionError("verification used network")), \
                patch.object(dossier, "_tool_snapshot", side_effect=retained_only):
            verified = dossier.verify(self.files, self.result.manifest_hash)
        self.assertEqual(verified.manifest_hash, self.result.manifest_hash)
        self.assertEqual(verified.files, self.result.files)

    def test_missing_extra_or_changed_payload_rejected_before_replay(self):
        changes = [dict(self.files), dict(self.files), dict(self.files)]
        changes[0].pop("source/retained/inputs.json.gz")
        changes[1]["extra.bin"] = b"x"
        changes[2]["inventory/report.json"] = b"{}"
        with patch.object(dossier, "_replay", side_effect=AssertionError("unexpected replay")):
            for files in changes:
                with self.subTest(files=len(files)):
                    with self.assertRaisesRegex(MuseumError, "file commitments"):
                        dossier.verify(files, self.result.manifest_hash)

    def test_rehashed_full_pass_claim_is_rejected(self):
        value = deepcopy(self.manifest)
        value["claims"]["fullObjectDossierConformance"] = True
        raw = dumps(value); files = self.files | {"manifest.json": raw}
        with patch.object(dossier, "_replay", side_effect=AssertionError("unexpected replay")):
            with self.assertRaises(MuseumError): dossier.verify(files, keccak256(raw))

    def test_rehashed_source_identity_must_match_original_capture(self):
        value = deepcopy(self.manifest); value["sourceState"]["blockNumber"] = "1312"
        raw = dumps(value); files = self.files | {"manifest.json": raw}
        # The trusted replay result cannot be changed by a rewritten outer manifest.
        with patch.object(dossier, "assemble", return_value=self.result):
            with self.assertRaisesRegex(MuseumError, "source reconstruction"):
                dossier.verify(files, keccak256(raw))


if __name__ == "__main__": unittest.main()

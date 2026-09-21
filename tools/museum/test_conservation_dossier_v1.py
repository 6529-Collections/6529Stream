"""Dossier regressions over complete synthetic native conservation replays.

No source validator is mocked and no native execution or interview delivery is
claimed. The fixture edits happen before original payload/receipt hashing.
"""
from contextlib import redirect_stderr, redirect_stdout
from copy import deepcopy
import io
from pathlib import Path
from tempfile import TemporaryDirectory
import unittest
from unittest.mock import patch

from . import public_conservation_capture as capture
from . import public_conservation_source as source
from .bagit import read_tree, write_tree
from .canonical import MuseumError, dumps, hex_bytes, keccak256, loads
from .test_public_conservation_source import PublicConservationFixture


MAX_JSON = 64 * 1024 * 1024


class DossierFixture(PublicConservationFixture):
    """Preserve intentionally duplicated, ordered declarations in real records."""

    def _add_original(self, value, kind, scope, origin, block, **kwargs):
        value = deepcopy(value)
        if kind == 2:
            value["participants"].insert(1, deepcopy(value["participants"][0]))
            value["languages"] = ["EN-latn-US", "fr", "EN-latn-US", "i-klingon", "x-exact"]
        return super()._add_original(value, kind, scope, origin, block, **kwargs)


def captured(fixture):
    reader = fixture.source()
    snapshot_bytes = reader.snapshot()
    transcript = reader.transcript()
    assembly = capture.replay(reader.anchor_bytes, keccak256(reader.anchor_bytes), source.PROFILE_HASH,
        transcript, keccak256(transcript), provenance="synthetic_fixture", disclosure="public")
    return assembly, loads(snapshot_bytes, maximum=MAX_JSON, canonical=True)


def fixtures():
    written = DossierFixture(empty=True)
    interview = written.append_interview(block=1)
    written.prepare_interview(interview, block=2)
    written.append_intent(block=3, interview=interview)
    written.update_heads()

    av = DossierFixture(empty=True)
    interview = av.append_interview(block=1, catalog=True)
    av.append_intent(origin=1, block=2, interview=interview)
    av.update_heads()

    history = DossierFixture()
    history.append_waiver(block=2)
    history.append_intent(block=3)
    history.append_intent(origin=1, block=3)
    history.append_intent("token", block=2)
    history.append_intent("token", origin=1, block=3)
    history.lock_artist(block=4)
    history.update_heads()

    stale = DossierFixture()
    stale.add(stale.suite[2][4], "attributionState(uint256)", ("uint256",), (1,),
        ("uint8", "uint64"), (4, 1))
    return {"written": written, "av": av, "history": history,
        "empty": DossierFixture(empty=True), "stale": stale}


def leaves(value, pointer=""):
    """Independent RFC6901 traversal, including empty containers."""
    if isinstance(value, dict) and value:
        return [(p, v) for key, item in value.items()
            for p, v in leaves(item, pointer + "/" + key.replace("~", "~0").replace("/", "~1"))]
    if isinstance(value, list) and value:
        return [(p, v) for index, item in enumerate(value) for p, v in leaves(item, pointer + "/" + str(index))]
    return [(pointer, value)]


def references(value, pointer=""):
    if isinstance(value, dict):
        here = [(pointer, value)] if set(value) == {"hash", "uri"} else []
        return here + [(p, v) for key, item in value.items()
            for p, v in references(item, pointer + "/" + key.replace("~", "~0").replace("/", "~1"))]
    if isinstance(value, list):
        return [(p, v) for index, item in enumerate(value)
            for p, v in references(item, pointer + "/" + str(index))]
    return []


class ConservationDossierTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        from . import conservation_dossier_v1 as dossier
        from . import conservation_dossier_projection_v1 as projection
        cls.dossier, cls.projection = dossier, projection
        cls.inputs = {key: captured(value) for key, value in fixtures().items()}
        cls.results = {key: dossier.build(dict(value.files), value.manifest_hash, disclosure="public")
            for key, (value, _) in cls.inputs.items()}

    @staticmethod
    def repin(files):
        manifest = loads(files["manifest.json"], maximum=MAX_JSON)
        manifest["files"] = [capture.base._ref(path, raw) for path, raw in sorted(files.items())
            if path != "manifest.json"]
        files["manifest.json"] = dumps(manifest)
        return keccak256(files["manifest.json"])

    def document(self, name, file="dossier"):
        return loads(dict(self.results[name].files)["conservation/" + file + ".json"], maximum=MAX_JSON)

    def test_every_original_field_and_exact_native_provenance_is_retained(self):
        for name, (_, snapshot) in self.inputs.items():
            dossier = self.document(name)
            self.assertEqual(dossier["preparations"], snapshot["preparations"])
            self.assertEqual(dossier["currentAssociation"], snapshot["currentAssociation"])
            self.assertEqual(dossier["source"]["sourceState"], snapshot["source"])
            self.assertEqual(len(dossier["records"]), len(snapshot["records"]))
            for index, (original, row) in enumerate(zip(snapshot["records"], dossier["records"])):
                with self.subTest(name=name, index=index):
                    self.assertEqual(row["semantic"], original["value"])
                    self.assertEqual(dumps(row["semantic"]), hex_bytes(original["payloadHex"]))
                    self.assertEqual(row["provenance"], {k: v for k, v in original.items() if k != "value"})
                    self.assertEqual(row["selector"], {
                        "chainId": snapshot["source"]["chainId"], "core": snapshot["source"]["core"],
                        "host": snapshot["source"]["host"], "collectionId": snapshot["source"]["collectionId"],
                        "recordHash": original["recordHash"], "recordType": original["record"][0],
                        "subjectId": original["record"][1], "schemaId": original["record"][4],
                        "canonicalizationId": original["record"][2][2], "originalURI": original["record"][3],
                        "recordIndex": original["receipt"][4],
                        "recordedAt": original["receipt"][3]})
            before = dumps(snapshot)
            self.projection.project(snapshot)
            self.assertEqual(dumps(snapshot), before)

    def test_semantic_leaf_ledger_covers_all_fields_nulls_and_empty_arrays(self):
        for name, (_, snapshot) in self.inputs.items():
            dossier, ledger = self.document(name), self.document(name, "semantic-leaves")
            expected = []
            roots = []
            for index, original in enumerate(snapshot["records"]):
                rows = leaves(original["value"], "/records/" + str(index) + "/semantic")
                expected.extend(("record", original["recordHash"], path, value) for path, value in rows)
                roots.append(("record", original["recordHash"], keccak256(hex_bytes(original["payloadHex"])), len(rows)))
            documents = {row["documentId"]: row for row in snapshot["documents"]}
            for index, row in enumerate(dossier["catalogDocuments"]):
                original = documents[row["documentId"]]
                raw = hex_bytes(original["payloadHex"])
                rows = leaves(loads(raw), "/catalogDocuments/" + str(index) + "/value")
                expected.extend(("catalog_document", row["documentId"], path, value) for path, value in rows)
                roots.append(("catalog_document", row["documentId"], keccak256(raw), len(rows)))
            self.assertEqual([(r["sourceKind"], r["sourceId"], r["jsonPointer"], r["value"]) for r in ledger["leaves"]], expected)
            self.assertEqual([(r["sourceKind"], r["sourceId"], r["semanticHash"], r["leafCount"]) for r in ledger["roots"]], roots)
            self.assertEqual(len({row[2] for row in expected}), len(expected))
            coverage = dossier["leafCoverage"]
            self.assertEqual(coverage["semanticLeafCount"], len(expected))
            self.assertTrue(coverage["complete"])
            self.assertEqual(coverage["semanticLeafLedgerHash"], keccak256(dumps(ledger)))
        self.assertTrue(any(r["valueType"] == "empty_array" and r["jsonPointer"].endswith("/captures")
            for r in self.document("written", "semantic-leaves")["leaves"]))
        self.assertTrue(any(r["valueType"] == "null" and r["jsonPointer"].endswith("/predecessor")
            for r in self.document("written", "semantic-leaves")["leaves"]))

    def test_exact_reference_occurrences_preserve_order_duplicates_and_digest_widths(self):
        for name, (_, snapshot) in self.inputs.items():
            dossier, inventory = self.document(name), self.document(name, "reference-occurrences")
            expected = []
            for index, original in enumerate(snapshot["records"]):
                for pointer, reference in references(original["value"], "/records/" + str(index) + "/semantic"):
                    expected.append(("record", original["recordHash"], pointer, reference))
            for index, catalog in enumerate(dossier["catalogDocuments"]):
                for pointer, reference in references(catalog["value"], "/catalogDocuments/" + str(index) + "/value"):
                    expected.append(("catalog_document", catalog["documentId"], pointer, reference))
            actual = [(row["sourceKind"], row["sourceRecord"]["recordHash"] if row["sourceKind"] == "record"
                else row["catalogSelector"]["documentId"], row["jsonPointer"], {"hash": row["hash"], "uri": row["uri"]})
                for row in inventory["occurrences"]]
            self.assertEqual(actual, expected)
            self.assertEqual([r["occurrence"] for r in inventory["occurrences"]], list(range(len(expected))))
            self.assertEqual(dossier["leafCoverage"]["referenceOccurrenceInventoryHash"], keccak256(dumps(inventory)))
        av = self.document("av", "reference-occurrences")["occurrences"]
        participant_refs = [r for r in av if r["relation"] == "participant_identity"]
        self.assertEqual(len(participant_refs), 4)
        self.assertEqual((participant_refs[0]["hash"], participant_refs[0]["uri"]),
            (participant_refs[1]["hash"], participant_refs[1]["uri"]))
        self.assertNotEqual(participant_refs[0]["jsonPointer"], participant_refs[1]["jsonPointer"])
        self.assertEqual([len(hex_bytes(r["hash"]["digest"])) for r in av if r["relation"] == "capture_content"], [128, 1])

    def test_written_and_audiovisual_interviews_keep_exact_declarations_catalogs_and_parent_join(self):
        for name in ("written", "av"):
            dossier = self.document(name)
            interview = next(r for r in dossier["records"] if r["family"] == "interview")
            parent = next(r for r in dossier["records"] if r["family"] == "intent")
            value = interview["semantic"]
            self.assertEqual(value["interviewDate"], "2024-02-29")
            self.assertEqual(value["languages"], ["EN-latn-US", "fr", "EN-latn-US", "i-klingon", "x-exact"])
            self.assertEqual(value["transcript"]["format"]["puid"], "fmt/111")
            self.assertEqual(dossier["parentInterviewRelationships"], [{
                "kind": "parent_interview", "parentRecordHash": parent["selector"]["recordHash"],
                "interviewRecordHash": interview["selector"]["recordHash"],
                "payloadReference": parent["semantic"]["interview"]["payload"],
                "locator": parent["semantic"]["interview"]["record"]}])
            if name == "written":
                self.assertEqual(value["instrument"]["kind"], "variable_media_questionnaire")
                self.assertNotIn("name", value["instrument"])
                self.assertEqual(value["captures"], [])
                self.assertEqual(dossier["preparations"][0]["status"], "prepared")
                self.assertFalse(dossier["preparations"][0]["adoptionUsedPreparationProven"])
            else:
                self.assertEqual(value["instrument"]["kind"], "named_derivative")
                self.assertIn("e\u0301", value["instrument"]["name"])
                self.assertEqual([r["kind"] for r in value["captures"]], ["audio", "video"])
                self.assertEqual(parent["semantic"]["artist"]["statementOrigin"], "estate_statement")
                self.assertEqual(interview["provenance"]["nativeEvidence"][8][5], "1")
                self.assertEqual(parent["provenance"]["nativeEvidence"][8][5], "3")
                occurrences = interview["catalogOccurrences"]
                self.assertEqual([r["occurrence"] for r in occurrences], [0, 1])
                self.assertEqual(occurrences[0]["documentHash"], occurrences[1]["documentHash"])
                self.assertNotEqual(occurrences[0]["jsonPointer"], occurrences[1]["jsonPointer"])
                self.assertEqual(len(dossier["catalogDocuments"]), 1)
                catalog = dossier["catalogDocuments"][0]
                self.assertEqual(len(catalog["value"]["entries"]), 2)
                self.assertEqual(catalog["value"]["entries"][0]["mapping"]["puid"], "fmt/111")
                self.assertEqual(dumps(catalog["value"]), hex_bytes(catalog["evidence"]["payloadHex"]))

    def test_four_lane_history_waivers_absence_locks_and_current_eligibility_are_distinct(self):
        for name, (_, snapshot) in self.inputs.items():
            dossier = self.document(name)
            self.assertEqual([r["scope"] for r in dossier["scopes"]], ["collection", "token"])
            for scope in dossier["scopes"]:
                original = snapshot["scopes"][scope["scope"]]
                self.assertEqual(scope["subjectId"], original["subjectId"])
                self.assertEqual(scope["lock"], original["lock"])
                self.assertEqual(scope["lockEvent"], original["lockEvent"])
                self.assertEqual([r["origin"] for r in scope["lineages"]], ["artist", "estate"])
                for lane in scope["lineages"]:
                    prior = original["origins"][lane["origin"]]
                    self.assertEqual(lane["status"], prior["status"])
                    self.assertEqual(lane["current"], prior["current"])
                    self.assertEqual(lane["currentEligibility"], prior["currentEligibility"])
                    self.assertEqual([r["selection"] for r in lane["revisions"]], prior["history"])
                    self.assertEqual([r["event"] for r in lane["revisions"]], prior["events"])
                    self.assertEqual([r["catalogPins"] for r in lane["revisions"]], prior["catalogs"])
                    self.assertEqual([r["interviewMode"] for r in lane["revisions"]],
                        ["waived" if r[3] == "1" else "present" for r in prior["history"]])
        history = self.document("history")["scopes"][0]
        self.assertTrue(history["lock"][0])
        self.assertEqual([r["recordFamily"] for r in history["lineages"][0]["revisions"]],
            ["intent", "intent_waiver", "intent"])
        self.assertEqual([r["revision"] for r in history["lineages"][0]["revisions"]], ["1", "2", "3"])
        for scope in self.document("empty")["scopes"]:
            for lane in scope["lineages"]:
                self.assertEqual(lane["status"], "absent_on_bound_selector")
                self.assertEqual(lane["revisions"], [])
        stale = self.document("stale")["scopes"][0]["lineages"][0]
        self.assertEqual(stale["status"], "selected")
        self.assertEqual(len(stale["revisions"]), 1)
        self.assertFalse(stale["currentEligibility"]["eligible"])
        self.assertIn("current_association_differs", stale["currentEligibility"]["reasons"])

    def test_original_capture_is_retained_byte_exact_and_replayed_offline(self):
        for name, (original, snapshot) in self.inputs.items():
            result = self.results[name]
            files = dict(result.files)
            with self.subTest(name=name):
                self.assertEqual({path[6:]: raw for path, raw in files.items() if path.startswith("input/")},
                    dict(original.files))
                self.assertEqual(loads(files["input/source/snapshot.json"], maximum=MAX_JSON), snapshot)
                for path, raw in self.projection.project(snapshot).items():
                    self.assertEqual(files[path], raw)
                with patch("socket.socket", side_effect=AssertionError("offline dossier attempted network")):
                    rebuilt = self.dossier.verify(files, result.manifest_hash)
                self.assertEqual(rebuilt.files, result.files)

    def test_rehashed_derivatives_profiles_and_reports_cannot_be_replaced(self):
        result = self.results["av"]
        files = dict(result.files)
        derived = [path for path in files if not path.startswith("input/") and path != "manifest.json"]
        self.assertTrue(set(self.projection.project(self.inputs["av"][1])) <= set(derived))
        self.assertGreater(len(derived), 4)
        for path in derived:
            changed = dict(files)
            changed[path] += b"\n"
            with self.subTest(path=path), self.assertRaises(MuseumError):
                self.dossier.verify(changed, self.repin(changed))

    def test_original_source_and_file_inventory_remain_required_after_rehash(self):
        result = self.results["written"]
        for path in ("input/source/anchor.json", "input/source/transcript.json", "input/source/snapshot.json",
                "input/conservation/original-records.json", "input/manifest.json"):
            files = dict(result.files)
            files[path] += b"\n"
            with self.subTest(path=path), self.assertRaises(MuseumError):
                self.dossier.verify(files, self.repin(files))
        for mutation in ("omit", "extra", "escape"):
            files = dict(result.files)
            if mutation == "omit": del files["conservation/reference-occurrences.json"]
            elif mutation == "extra": files["conservation/unsupplied-media.bin"] = b"not captured"
            else: files["../outside"] = b"unsafe path"
            with self.subTest(mutation=mutation), self.assertRaises(MuseumError):
                self.dossier.verify(files, self.repin(files))

    def test_exact_external_pin_and_public_disclosure_precede_derivation(self):
        original, _ = self.inputs["written"]
        with self.assertRaises(MuseumError):
            self.dossier.build(dict(original.files), "0x" + "ff" * 32, disclosure="public")
        for disclosure in (None, "private", "", "PUBLIC"):
            with self.subTest(disclosure=disclosure), self.assertRaises(MuseumError):
                self.dossier.build({}, original.manifest_hash, disclosure=disclosure)
        result = self.results["written"]
        with self.assertRaises(MuseumError):
            self.dossier.verify(dict(result.files), "0x" + "ff" * 32)

    def test_coherently_rehashed_capture_derivative_does_not_replace_native_replay(self):
        original, _ = self.inputs["av"]
        files = dict(original.files)
        snapshot = loads(files["source/snapshot.json"], maximum=MAX_JSON)
        interview = next(row for row in snapshot["records"] if "participants" in row["value"])
        interview["value"]["interviewDate"] = "2025-01-01"
        interview["payloadHex"] = "0x" + dumps(interview["value"]).hex()
        files["source/snapshot.json"] = dumps(snapshot)
        files["conservation/original-records.json"] = dumps(snapshot["records"])
        with self.assertRaises(MuseumError):
            self.dossier.build(files, self.repin(files), disclosure="public")
        for mutation in ("omit", "extra"):
            files = dict(original.files)
            transcript = loads(files["source/transcript.json"], maximum=MAX_JSON)
            if mutation == "omit": transcript["calls"].pop()
            else: transcript["calls"].append(deepcopy(transcript["calls"][0]))
            files["source/transcript.json"] = dumps(transcript)
            with self.subTest(mutation=mutation), self.assertRaises(MuseumError):
                self.dossier.build(files, self.repin(files), disclosure="public")

    def test_claims_and_provenance_do_not_upgrade_declarations(self):
        for name, result in self.results.items():
            original, snapshot = self.inputs[name]
            report = result.report
            self.assertEqual(report["recordCount"], str(len(snapshot["records"])))
            self.assertEqual(report["sourceManifestHash"], original.manifest_hash)
            self.assertEqual(report["sourceState"], snapshot["source"])
            self.assertEqual(report["identity"], snapshot["identity"])
            self.assertEqual(report["sourceClaims"], snapshot["claims"])
            self.assertEqual(report["sourceRemaining"], snapshot["remaining"])
            self.assertEqual(report["sourceProvenance"], "synthetic_fixture")
            self.assertTrue(report["claims"]["allOriginalPayloadFieldsAccounted"])
            for key in ("participantIdentityProven", "interviewPerformanceProven", "interviewConsentProven",
                    "referencedMediaRetrieved", "archiveDeliveryProven", "historicalSignaturesRevalidated",
                    "sourceProvenanceSelfAuthenticated", "completeCanonicalDossier", "completeCanonicalPacket",
                    "institutionalConformance", "profileRegistered"):
                self.assertIs(report["claims"][key], False, (name, key))
        self.assertEqual(self.results["history"].report["recordCounts"],
            {"intent": "5", "intent_waiver": "1", "interview": "0"})
        original, _ = self.inputs["written"]
        files = dict(original.files)
        admitted = capture.replay(files["source/anchor.json"], keccak256(files["source/anchor.json"]),
            source.PROFILE_HASH, files["source/transcript.json"], keccak256(files["source/transcript.json"]),
            provenance="trusted_rpc", disclosure="public")
        result = self.dossier.build(dict(admitted.files), admitted.manifest_hash, disclosure="public")
        self.assertEqual(result.report["sourceProvenance"], "trusted_rpc")
        self.assertFalse(result.report["claims"]["sourceProvenanceSelfAuthenticated"])
        self.assertEqual(self.dossier.verify(dict(result.files), result.manifest_hash).files, result.files)

    def test_coherently_rehashed_false_completeness_and_manifest_substitutions_reject(self):
        result = self.results["written"]
        for mutation in ("report", "claims", "provenance", "disclosure", "profile", "extra"):
            files = dict(result.files)
            manifest = loads(files["manifest.json"], maximum=MAX_JSON)
            if mutation == "report":
                report = loads(files["report.json"], maximum=MAX_JSON)
                report["claims"]["interviewPerformanceProven"] = True
                files["report.json"] = dumps(report)
            elif mutation == "claims": manifest["claims"]["completeCanonicalDossier"] = True
            elif mutation == "provenance": manifest["provenance"] = "trusted_rpc"
            elif mutation == "disclosure": manifest["disclosure"] = "restricted"
            elif mutation == "profile": manifest["projectionProfileHash"] = "0x" + "ab" * 32
            else: manifest["sourceAuthenticated"] = True
            files["manifest.json"] = dumps(manifest)
            with self.subTest(mutation=mutation), self.assertRaises(MuseumError):
                self.dossier.verify(files, self.repin(files))

    def test_cli_is_offline_read_only_on_verify_and_never_overwrites(self):
        original, _ = self.inputs["written"]
        with TemporaryDirectory() as directory, patch("socket.socket", side_effect=AssertionError("offline only")):
            root = Path(directory)
            input_path, output = root / "input", root / "dossier"
            write_tree(dict(original.files), input_path)
            args = ["build", str(input_path), str(output), "--manifest-hash", original.manifest_hash,
                "--disclosure", "public"]
            stdout = io.StringIO()
            with redirect_stdout(stdout): self.assertEqual(self.dossier.main(args), 0)
            message = loads(stdout.getvalue().encode(), maximum=MAX_JSON)
            self.assertEqual(message["manifestHash"], self.results["written"].manifest_hash)
            before, inputs_before = read_tree(output), read_tree(input_path)
            with redirect_stdout(io.StringIO()):
                self.assertEqual(self.dossier.main(["verify", str(output), "--manifest-hash", message["manifestHash"]]), 0)
            self.assertEqual(read_tree(output), before)
            with redirect_stderr(io.StringIO()): self.assertEqual(self.dossier.main(args), 1)
            self.assertEqual(read_tree(output), before)
            self.assertEqual(read_tree(input_path), inputs_before)
            rejected = root / "rejected"
            with redirect_stderr(io.StringIO()) as stderr:
                self.assertEqual(self.dossier.main(["build", str(root / "missing"), str(rejected),
                    "--manifest-hash", original.manifest_hash, "--disclosure", "restricted"]), 1)
            self.assertIn("public disclosure", stderr.getvalue())
            self.assertFalse(rejected.exists())
            stdout = io.StringIO()
            with redirect_stdout(stdout): self.assertEqual(self.dossier.main(["profiles"]), 0)
            profiles = loads(stdout.getvalue().encode(), maximum=MAX_JSON)
            self.assertEqual(profiles["profileHash"], self.dossier.PROFILE_HASH)
            self.assertEqual(profiles["projectionProfileHash"], self.projection.PROFILE_HASH)


if __name__ == "__main__":
    unittest.main()

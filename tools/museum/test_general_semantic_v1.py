"""Focused offline controls for General direct semantics and its dossier."""

from copy import deepcopy
from contextlib import redirect_stdout
import io
from pathlib import Path
from tempfile import TemporaryDirectory
import unittest
from unittest.mock import patch

from . import general_semantic_dossier_v1 as dossier
from .account_profile import account_iri
from .canonical import MuseumError, dumps, keccak256, loads
from .chain_rpc import MAX_TRANSCRIPT, ReplayTransport
from .general_attestation_source_v2 import GeneralAttestationSourceV2
from .general_semantic_fixture_v1 import build_case
from .general_semantic_profile_v1 import NAME as INTERPRETATION_NAME
from .general_semantic_source_v1 import GeneralSemanticSourceV1
from .metadata_catalog_source import MetadataCatalogSource
from .object_dossier import _ref


class GeneralSemanticV1Tests(unittest.TestCase):
    def _snapshot(self, **kwargs):
        fixture = build_case(**kwargs)
        source = fixture.source()
        with patch("socket.socket", side_effect=AssertionError("offline fixture used network")):
            raw = source.snapshot()
        return fixture, source, loads(raw, maximum=MAX_TRANSCRIPT, canonical=True)

    @staticmethod
    def _supported(snapshot):
        return next(row for row in snapshot["statements"] if row["status"] == "supported")

    def test_signed_institution_replays_both_sources_and_exact_definitions(self):
        fixture, source, snapshot = self._snapshot()
        row = self._supported(snapshot)
        self.assertEqual(row["value"], fixture.semantic_value)
        self.assertEqual(row["authority"]["verificationClass"], "SIGNER_VERIFIED")
        self.assertEqual(row["authority"]["authorityQualification"], "GENERAL_SIGNER_CLAIM")
        self.assertEqual(row["authority"]["originalProfileDefinitionHash"], "0x" + "00" * 32)
        self.assertTrue(snapshot["interpretationDocumentsChecked"])
        self.assertGreater(len(snapshot["documents"]), 3)

        metadata = MetadataCatalogSource(source.metadata.anchor_bytes,
            ReplayTransport(source.metadata.transcript(), keccak256(source.metadata.transcript())))
        general = GeneralAttestationSourceV2(source.general.anchor_bytes,
            ReplayTransport(source.general.transcript(), keccak256(source.general.transcript())))
        replay = GeneralSemanticSourceV1(metadata, general,
            ReplayTransport(source.transcript(), keccak256(source.transcript())), profile=fixture.profile)
        self.assertEqual(replay.snapshot(), source.snapshot())

    def test_signed_estate_uses_its_native_family_without_institution_promotion(self):
        fixture, _, snapshot = self._snapshot(authority="estate")
        row = self._supported(snapshot)
        self.assertEqual(row["original"]["value"][3], fixture.general_fixture.rows[fixture.row_index][1][3])
        self.assertEqual(row["authority"]["assertingAccount"],
            account_iri("31337", row["original"]["receipt"][0]))
        self.assertFalse(row["authority"]["namedInstitutionIdentityProven"])

    def test_curatorial_row_uses_recorder_and_not_unsigned_attester(self):
        _, _, snapshot = self._snapshot(authority="curatorial")
        row = self._supported(snapshot)
        authority = row["authority"]
        self.assertEqual(authority["verificationClass"], "OPERATOR_ASSERTED")
        self.assertEqual(authority["authorityQualification"], "CONFIGURED_OPERATOR_CLAIM")
        self.assertNotEqual(authority["authenticatedRecorder"], authority["assertedAttester"])
        self.assertEqual(authority["assertingAccount"], account_iri("31337", authority["authenticatedRecorder"]))
        self.assertTrue(authority["unsignedAttesterAndDIDNotUsedAsAuthority"])

    def test_equal_or_later_documentary_time_is_unorderable(self):
        for ordering in ("same_time", "late"):
            with self.subTest(ordering=ordering), self.assertRaisesRegex(
                    MuseumError, "strictly earlier timestamp"):
                build_case(authority="estate", evidence_order=ordering).source().snapshot()

    def test_asserting_account_cannot_impersonate_another_general_account(self):
        def mutate(value):
            value["assertions"][0]["assertingAgent"] = account_iri("31337",
                "0x0000000000000000000000000000000000000099")
        with self.assertRaisesRegex(MuseumError, "asserting account impersonation"):
            build_case(mutate=mutate).source().snapshot()

    def test_declaring_account_cannot_become_an_entity_or_use_other_account(self):
        def declare(value):
            value["entities"] = [{"id": "urn:fixture:declared-object", "kind": "physical_object",
                "names": [{"value": "Declared only", "language": "en", "kind": "preferred"}],
                "declaringAgent": value["assertions"][0]["assertingAgent"],
                "sourceRecords": deepcopy(value["sourceRecords"]), "predecessors": []}]

        fixture, _, snapshot = self._snapshot(mutate=declare)
        self.assertEqual(self._supported(snapshot)["value"]["entities"],
                         fixture.semantic_value["entities"])
        for change in ("account_entity", "other_declarer"):
            def mutate(value, change=change):
                declare(value)
                entity = value["entities"][0]
                if change == "account_entity":
                    entity["id"] = value["assertions"][0]["assertingAgent"]
                else:
                    entity["declaringAgent"] = account_iri("31337",
                        "0x0000000000000000000000000000000000000099")
            with self.subTest(change=change), self.assertRaisesRegex(
                    MuseumError, "general semantic declaring account impersonation"):
                build_case(mutate=mutate).source().snapshot()

    def test_documentary_hash_and_pointer_are_exact_prior_metadata_bytes(self):
        mutations = {
            "hash": lambda v: v["assertions"][0]["evidence"][0]["source"].__setitem__(
                "digest", "0x" + "99" * 32),
            "pointer": lambda v: v["assertions"][0]["evidence"][0].__setitem__(
                "selector", "/missing"),
            "selector": lambda v: v["sourceRecords"][0].__setitem__(
                "recordHash", "0x" + "88" * 32),
        }
        for name, mutate in mutations.items():
            with self.subTest(name=name), self.assertRaises(MuseumError):
                build_case(mutate=mutate).source().snapshot()

    def test_own_signed_and_page_evidence_are_not_upgraded(self):
        for field, replacement in (("basis", "own_signed_statement"),
                                   ("selectorType", "document_page")):
            def mutate(value, field=field, replacement=replacement):
                value["assertions"][0]["evidence"][0][field] = replacement
            with self.subTest(field=field), self.assertRaises(MuseumError):
                build_case(mutate=mutate).source().snapshot()

    def test_other_profile_is_retained_unsupported_without_registration_claim(self):
        def mutate(value):
            value["profileHash"] = "0x" + "77" * 32
        fixture, source, snapshot = self._snapshot(mutate=mutate)
        row = next(row for row in snapshot["statements"] if
                   row["source"]["recordHash"] == fixture.record_hash)
        self.assertEqual(row["status"], "unsupported")
        self.assertEqual(row["reasonCode"], "interpretation_profile_unsupported")
        self.assertEqual(row["original"]["payloadHex"], "0x" + fixture.payload.hex())
        self.assertFalse(snapshot["interpretationDocumentsChecked"])
        self.assertEqual(snapshot["documents"], [])
        selection, digest = fixture.selection(source, indices=[])
        built = dossier.build(source, selection, digest, disclosure="public")
        self.assertEqual(built.report["interpretationDocumentsStatus"], "not_required_no_supported_records")
        self.assertFalse(built.report["claims"]["registeredInterpretationDocumentsChecked"])

    def test_registered_definition_bytes_cannot_be_replaced_under_same_name(self):
        fixture = build_case()
        fixture.install_profile_document(INTERPRETATION_NAME,
            dumps({"name": INTERPRETATION_NAME, "replacement": True}))
        with self.assertRaisesRegex(MuseumError, "definition|interpretation"):
            fixture.source().snapshot()

    def test_direct_selection_builds_and_fully_reconstructs_one_resource(self):
        fixture = build_case(); source = fixture.source()
        selection, digest = fixture.selection(source)
        with patch("socket.socket", side_effect=AssertionError("dossier used network")):
            built = dossier.build(source, selection, digest, disclosure="public")
            checked = dossier.verify(dict(built.files), built.manifest_hash)
        self.assertEqual(built.report["selectedAssertionCount"], "1")
        self.assertEqual(built.report["resourceCount"], "1")
        self.assertEqual(checked.manifest_hash, built.manifest_hash)
        resource = loads(next(body for path, body in built.files
            if path.startswith("graph/resources/")), maximum=MAX_TRANSCRIPT)
        self.assertEqual(resource["type"], "LinguisticObject")
        self.assertEqual(loads(resource["content"].encode("utf-8")), fixture.semantic_value["assertions"][0])

    def test_disputed_or_withdrawn_direct_revision_is_retained_but_withheld(self):
        for status in ("disputed", "withdrawn"):
            fixture = build_case(review_status=status); source = fixture.source()
            raw, digest = fixture.selection(source)
            selected = dossier.select(loads(source.snapshot(), maximum=MAX_TRANSCRIPT), raw, digest)
            with self.subTest(status=status):
                self.assertEqual(selected["selected"], [])
                self.assertEqual(len(selected["withheld"]), 1)
                self.assertIn("selected_original_revision_disputed_or_withdrawn",
                    selected["withheld"][0]["reasons"])

    def test_non_direct_mapping_is_retained_without_review_authority_inference(self):
        fixture = build_case(origin="human_mapping"); source = fixture.source()
        raw, digest = fixture.selection(source)
        selected = dossier.select(loads(source.snapshot(), maximum=MAX_TRANSCRIPT), raw, digest)
        self.assertEqual(selected["selected"], [])
        self.assertEqual(selected["withheld"][0]["reasons"], ["mapping_review_not_supported"])

    def test_large_generic_payload_and_whole_document_evidence_cross_chunks(self):
        def mutate(value):
            assertion = value["assertions"][0]
            assertion["rationale"] = "retained declaration " + "x" * 10000
            assertion["evidence"][0]["selectorType"] = "whole_document"
            assertion["evidence"][0]["selector"] = ""
        fixture = build_case(mutate=mutate); source = fixture.source()
        snapshot = loads(source.snapshot(), maximum=MAX_TRANSCRIPT)
        row = self._supported(snapshot)
        self.assertGreater(len(bytes.fromhex(row["original"]["payloadHex"][2:])), 8192)
        self.assertGreater(int(row["original"]["payloadInfo"]["chunkCount"]), 1)
        raw, digest = fixture.selection(source)
        built = dossier.build(source, raw, digest, disclosure="public")
        self.assertEqual(built.report["selectedAssertionCount"], "1")

    def test_single_valued_conflict_has_no_recency_winner(self):
        def mutate(value):
            second = deepcopy(value["assertions"][0])
            second["id"] = "urn:fixture:assertion:conflict"
            second["object"]["literal"]["lexicalValue"] = "41.00"
            value["assertions"].append(second)
        fixture = build_case(mutate=mutate); source = fixture.source()
        relation = fixture.semantic_value["assertions"][0]["relation"]
        raw, digest = fixture.selection(source, single_valued=(relation,))
        selected = dossier.select(loads(source.snapshot(), maximum=MAX_TRANSCRIPT), raw, digest)
        self.assertEqual(selected["selected"], [])
        self.assertEqual(len(selected["withheld"]), 2)
        self.assertTrue(all("conflicting_selected_source_values" in row["reasons"]
                            for row in selected["withheld"]))

    def test_selection_snapshot_pin_and_duplicate_selectors_are_closed(self):
        fixture = build_case(); source = fixture.source(); selector = fixture.assertion_selectors(source)[0]
        base = {"profile": dossier.NAME, "sourceSnapshotHash": "0x" + "66" * 32,
            "sourceAuthoritySet": [selector], "singleValuedRelations": []}
        raw = dumps(base)
        with self.assertRaises(MuseumError):
            dossier.select(loads(source.snapshot(), maximum=MAX_TRANSCRIPT), raw, keccak256(raw))
        base["sourceSnapshotHash"] = keccak256(source.snapshot())
        base["sourceAuthoritySet"] = [selector, selector]
        raw = dumps(base)
        with self.assertRaisesRegex(MuseumError, "duplicate"):
            dossier.select(loads(source.snapshot(), maximum=MAX_TRANSCRIPT), raw, keccak256(raw))

    def test_public_disclosure_and_every_package_byte_are_mandatory(self):
        fixture = build_case(); source = fixture.source(); raw, digest = fixture.selection(source)
        with self.assertRaisesRegex(MuseumError, "public disclosure"):
            dossier.build(source, raw, digest, disclosure="restricted")
        built = dossier.build(source, raw, digest, disclosure="public")
        files = dict(built.files); files["graph/index.json"] += b" "
        with self.assertRaises(MuseumError):
            dossier.verify(files, built.manifest_hash)

    def test_coherently_rehashed_derived_report_tamper_fails_reconstruction(self):
        fixture = build_case(); source = fixture.source(); raw, digest = fixture.selection(source)
        built = dossier.build(source, raw, digest, disclosure="public")
        for change in ("report", "graph", "snapshot", "extra"):
            files = dict(built.files)
            if change == "report":
                value = loads(files["report.json"], maximum=MAX_TRANSCRIPT)
                value["selectedAssertionCount"] = "0"; files["report.json"] = dumps(value)
            elif change == "graph":
                files["graph/index.json"] = dumps({"resources": []})
            elif change == "snapshot":
                value = loads(files["semantics/snapshot.json"], maximum=MAX_TRANSCRIPT)
                value["qualification"] += " tampered"; files["semantics/snapshot.json"] = dumps(value)
            else:
                files["graph/extra.json"] = dumps({"coherentlyCommitted": True})
            manifest = loads(files["manifest.json"], maximum=MAX_TRANSCRIPT)
            manifest["files"] = [_ref(path, body) for path, body in sorted(files.items())
                                 if path != "manifest.json"]
            files["manifest.json"] = dumps(manifest)
            with self.subTest(change=change), self.assertRaisesRegex(
                    MuseumError, "reconstruction differs"):
                dossier.verify(files, keccak256(files["manifest.json"]))

    def test_unselected_conflicting_original_does_not_veto_selected_statement(self):
        def mutate(value):
            second = deepcopy(value["assertions"][0])
            second["id"] = "urn:fixture:assertion:unselected-conflict"
            second["object"]["literal"]["lexicalValue"] = "99.00"
            value["assertions"].append(second)
        fixture = build_case(mutate=mutate); source = fixture.source()
        relation = fixture.semantic_value["assertions"][0]["relation"]
        raw, digest = fixture.selection(source, indices=[0], single_valued=(relation,))
        selected = dossier.select(loads(source.snapshot(), maximum=MAX_TRANSCRIPT), raw, digest)
        self.assertEqual(len(selected["selected"]), 1)
        self.assertEqual(selected["withheld"], [])
        self.assertEqual(selected["unselectedCount"], "1")

    def test_cli_replay_verify_public_disclosure_and_no_overwrite(self):
        fixture = build_case(); source = fixture.source(); selection, selection_hash = fixture.selection(source)
        source.snapshot()
        inputs = {
            "metadata-anchor.json": source.metadata.anchor_bytes,
            "metadata-transcript.json": source.metadata.transcript(),
            "general-anchor.json": source.general.anchor_bytes,
            "general-transcript.json": source.general.transcript(),
            "semantic-transcript.json": source.transcript(),
            "selection.json": selection,
        }
        with TemporaryDirectory(prefix="general-semantic-cli-") as temporary:
            root = Path(temporary); capture = root / "capture"; capture.mkdir()
            for name, body in inputs.items():
                (capture / name).write_bytes(body)
            refs = {name.removesuffix(".json").replace("-", " ").title().replace(" ", ""): {
                "path": name, "hash": keccak256(body)} for name, body in inputs.items()}
            plan = {"profile": dossier.NAME, "provenance": "synthetic_fixture",
                "metadataAnchor": refs["MetadataAnchor"],
                "metadataTranscript": refs["MetadataTranscript"],
                "generalAnchor": refs["GeneralAnchor"],
                "generalTranscript": refs["GeneralTranscript"],
                "semanticTranscript": refs["SemanticTranscript"],
                "selection": refs["Selection"]}
            plan_raw = dumps(plan); plan_path = capture / "plan.json"; plan_path.write_bytes(plan_raw)
            with self.assertRaisesRegex(MuseumError, "public disclosure"):
                dossier.replay_plan(plan_path, keccak256(plan_raw), disclosure="restricted")
            output = root / "output"
            stdout = io.StringIO()
            with redirect_stdout(stdout):
                dossier.main(["replay", str(plan_path), str(output), "--plan-hash",
                    keccak256(plan_raw), "--disclosure", "public"])
            result = loads(stdout.getvalue().encode("utf-8"), maximum=MAX_TRANSCRIPT)
            stdout = io.StringIO()
            with redirect_stdout(stdout):
                dossier.main(["verify", str(output), "--manifest-hash", result["manifestHash"]])
            self.assertEqual(loads(stdout.getvalue().encode("utf-8"))["manifestHash"], result["manifestHash"])
            with redirect_stdout(io.StringIO()), self.assertRaises(SystemExit) as raised:
                dossier.main(["replay", str(plan_path), str(output), "--plan-hash",
                    keccak256(plan_raw), "--disclosure", "public"])
            self.assertEqual(raised.exception.code, 1)


if __name__ == "__main__":
    unittest.main()

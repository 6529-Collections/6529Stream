"""Focused source-backed tests for the conservation semantic graph."""

from copy import deepcopy
import unittest
from unittest.mock import patch

from .canonical import MuseumError, dumps, keccak256, loads
from . import conservation_dossier_projection_v1 as dossier_projection
from . import conservation_semantic_graph_v1 as graph
from .test_conservation_dossier_v1 import DossierFixture, captured, fixtures


MAX_JSON = 64 * 1024 * 1024


class DuplicateCaptureFixture(DossierFixture):
    def _add_original(self, value, kind, scope, origin, block, **kwargs):
        value = deepcopy(value)
        if kind == 2 and len(value.get("captures", ())) == 2:
            value["captures"][1]["payload"]["content"] = deepcopy(value["captures"][0]["payload"]["content"])
        return super()._add_original(value, kind, scope, origin, block, **kwargs)


def projected(fixture):
    _, snapshot = captured(fixture)
    return dossier_projection.project(snapshot)


class ConservationSemanticGraphTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        source = fixtures()
        cls.inputs = {name: projected(source[name]) for name in ("written", "av", "history", "empty", "stale")}
        with patch("socket.socket", side_effect=AssertionError("semantic graph attempted network")):
            cls.outputs = {name: graph.render(value) for name, value in cls.inputs.items()}

    @staticmethod
    def value(files, path):
        return loads(files[path], maximum=MAX_JSON, canonical=True)

    def resources(self, name):
        files = self.outputs[name]
        index = self.value(files, graph.INDEX_PATH)["resources"]
        return index, {row["id"]: self.value(files, row["path"]) for row in index}

    def test_profile_crosswalk_and_offline_linked_art_outputs_are_exact(self):
        files = self.outputs["av"]
        self.assertEqual(files[graph.PROFILE_PATH], graph.PROFILE_BYTES)
        self.assertEqual(files[graph.CROSSWALK_PATH], graph.CROSSWALK_BYTES)
        self.assertEqual(keccak256(graph.PROFILE_BYTES), graph.PROFILE_HASH)
        self.assertEqual(keccak256(graph.CROSSWALK_BYTES), graph.CROSSWALK_HASH)
        crosswalk = loads(graph.CROSSWALK_BYTES)
        required = {"rule", "sourceSchema", "sourceSchemaVersion", "sourceSelector", "sourceSubjectKind",
            "targetClass", "targetPropertyPath", "cardinality", "transformation", "authority",
            "controlledTerms", "uncertainty", "reverseCorrespondence", "positiveTest", "negativeTest"}
        self.assertTrue(crosswalk["rules"])
        self.assertTrue(all(set(row) == required for row in crosswalk["rules"]))
        methods = set(dir(type(self)))
        self.assertTrue(all(row["positiveTest"] in methods and row["negativeTest"] in methods
            for row in crosswalk["rules"]))
        self.assertEqual(crosswalk["completeness"], "complete_with_stream_extensions")
        self.assertEqual(len(crosswalk["sourceFamilyProfiles"]), 4)
        for row in self.value(files, graph.INDEX_PATH)["resources"]:
            self.assertIn(row["expandedPath"], files)
            self.assertEqual(self.value(files, row["path"])["id"], row["id"])
            self.assertEqual(self.value(files, row["expandedPath"])[0]["@id"], row["id"])

    def test_transcript_has_distinct_validated_carrier_and_linguistic_content(self):
        index, resources = self.resources("written")
        rows = [row for row in index if row["sourceOccurrence"]["jsonPointer"].endswith("/transcript/content")]
        self.assertEqual(len(rows), 2)
        by_type = {resources[row["id"]]["type"]: resources[row["id"]] for row in rows}
        self.assertEqual(set(by_type), {"DigitalObject", "LinguisticObject"})
        self.assertEqual(by_type["DigitalObject"]["digitally_carries"],
            [{"id": by_type["LinguisticObject"]["id"], "type": "LinguisticObject"}])
        self.assertNotIn("content", by_type["LinguisticObject"])
        self.assertTrue(all(row["status"] == "described_only" for row in rows))

    def test_statement_instrument_capture_payload_and_format_resources_are_distinct_and_described_only(self):
        index, resources = self.resources("av")
        relevant = [row for row in index if row["sourceOccurrence"]["relation"] in
            ("interview_instrument_document", "capture_content", "interview_payload")]
        self.assertEqual(sum(row["sourceOccurrence"]["relation"] == "capture_content" for row in relevant), 2)
        self.assertEqual(len({row["id"] for row in relevant}), len(relevant))
        self.assertTrue(all(resources[row["id"]]["type"] == "DigitalObject" for row in relevant))
        self.assertTrue(all(row["status"] == "described_only" for row in relevant))
        statements = [row for row in index if row["sourceOccurrence"]["relation"] == "display_statement"]
        formats = [row for row in index if row["sourceOccurrence"]["relation"] == "catalog_format_specification"]
        self.assertTrue(statements and formats)
        self.assertTrue(all(resources[row["id"]]["type"] == "LinguisticObject" for row in statements))
        self.assertTrue(all(resources[row["id"]]["type"] == "DigitalObject" for row in formats))
        self.assertTrue(all("digitally_carries" not in resources[row["id"]]
            for row in relevant + statements + formats))
        sidecar = self.value(self.outputs["av"], graph.SIDECAR_PATH)
        interview = sidecar["interviewDeclarations"][0]
        self.assertEqual([row["kind"] for row in interview["captures"]], ["audio", "video"])
        self.assertEqual(interview["instrument"]["kind"], "named_derivative")
        self.assertTrue(all(row["status"] == "described_only" for row in interview["captures"]))

    def test_equal_references_at_distinct_occurrences_never_merge_resource_identity(self):
        fixture = DuplicateCaptureFixture(empty=True)
        interview = fixture.append_interview(block=1, catalog=True)
        fixture.append_intent(block=2, interview=interview)
        fixture.update_heads()
        files = graph.render(projected(fixture))
        index = self.value(files, graph.INDEX_PATH)["resources"]
        rows = [row for row in index if row["sourceOccurrence"]["relation"] == "capture_content"]
        self.assertEqual(len(rows), 2)
        self.assertEqual(rows[0]["sourceOccurrence"]["hash"], rows[1]["sourceOccurrence"]["hash"])
        self.assertEqual(rows[0]["sourceOccurrence"]["uri"], rows[1]["sourceOccurrence"]["uri"])
        self.assertNotEqual(rows[0]["sourceOccurrence"]["jsonPointer"], rows[1]["sourceOccurrence"]["jsonPointer"])
        self.assertNotEqual(rows[0]["id"], rows[1]["id"])

    def test_participant_roles_order_duplicates_and_identity_references_remain_exact(self):
        files = self.outputs["av"]
        sidecar = self.value(files, graph.SIDECAR_PATH)
        rows = sidecar["participantRoleDeclarations"]
        self.assertEqual([row["role"] for row in rows], ["artist", "artist", "interviewer", "other"])
        self.assertEqual(rows[0]["identityReference"], rows[1]["identityReference"])
        self.assertNotEqual(rows[0]["sourceOccurrence"]["jsonPointer"], rows[1]["sourceOccurrence"]["jsonPointer"])
        self.assertTrue(all(row["disposition"] == "retained_stream_only"
            and not row["personOrGroupInferred"] and not row["participationProven"] for row in rows))
        index, resources = self.resources("av")
        self.assertFalse(any(row["sourceOccurrence"]["relation"] == "participant_identity" for row in index))
        self.assertFalse({"Person", "Group", "Activity", "VisualItem"} & {row["type"] for row in resources.values()})
        self.assertNotIn(b"carried_out_by", b"".join(files[row["path"]] for row in index) + files[graph.SIDECAR_PATH])

    def test_interview_is_attributed_declaration_not_activity_or_performance(self):
        sidecar = self.value(self.outputs["av"], graph.SIDECAR_PATH)
        row = sidecar["interviewDeclarations"][0]
        self.assertEqual(row["status"], "attributed_declaration_only")
        self.assertEqual(row["interviewDate"], "2024-02-29")
        self.assertEqual(row["languages"], ["EN-latn-US", "fr", "EN-latn-US", "i-klingon", "x-exact"])
        self.assertFalse(row["interviewPerformanceProven"])
        self.assertFalse(row["consentProven"])
        report = self.value(self.outputs["av"], graph.REPORT_PATH)
        for key in ("participantIdentityProven", "personOrGroupInferred", "interviewPerformanceProven",
                "consentProven", "mediaReceiptProven", "mediaFormatDetected", "archiveDeliveryProven"):
            self.assertIs(report["claims"][key], False)

    def test_exact_source_selectors_provenance_and_relationship_sidecars_are_retained(self):
        files = self.outputs["av"]
        dossier = loads(self.inputs["av"][dossier_projection.OUTPUTS[0]], maximum=MAX_JSON)
        selectors = {row["selector"]["recordHash"]: row["selector"] for row in dossier["records"]}
        index = self.value(files, graph.INDEX_PATH)["resources"]
        for row in index:
            source = row["sourceOccurrence"]
            if source["sourceKind"] == "record":
                self.assertEqual(source["selector"], selectors[source["selector"]["recordHash"]])
                self.assertTrue(source["jsonPointer"].startswith("/records/"))
            else:
                self.assertEqual(set(source["selector"]), {"documentId", "documentHash"})
                self.assertTrue(source["jsonPointer"].startswith("/catalogDocuments/"))
            self.assertEqual(source["dossierPath"], "conservation/dossier.json")
        provenance = self.value(files, graph.PROVENANCE_PATH)
        self.assertTrue(provenance)
        self.assertTrue(all(row["entity"] in {item["id"] for item in index}
            and row["rule"].startswith(graph.RULE) and row["sourceOccurrence"]["selector"] for row in provenance))
        sidecar = self.value(files, graph.SIDECAR_PATH)
        relation = sidecar["parentInterviewRelationships"][0]
        self.assertEqual(relation["parentSourceRecord"], selectors[relation["relationship"]["parentRecordHash"]])
        self.assertEqual(relation["interviewSourceRecord"], selectors[relation["relationship"]["interviewRecordHash"]])

    def test_complete_leaf_and_reference_coverage_matches_frozen_projection(self):
        for name, inputs in self.inputs.items():
            with self.subTest(name=name):
                dossier = loads(inputs[dossier_projection.OUTPUTS[0]], maximum=MAX_JSON)
                leaves = loads(inputs[dossier_projection.OUTPUTS[2]], maximum=MAX_JSON)
                references = loads(inputs[dossier_projection.OUTPUTS[1]], maximum=MAX_JSON)
                coverage = self.value(self.outputs[name], graph.COVERAGE_PATH)
                self.assertEqual(coverage["semanticLeaves"], [row | {"disposition": "retained_stream_only",
                    "reason": "retained exact in conservation dossier and typed sidecar"} for row in leaves["leaves"]])
                self.assertEqual(coverage["semanticLeafCount"], len(leaves["leaves"]))
                self.assertEqual(coverage["referenceOccurrenceCount"], len(references["occurrences"]))
                self.assertEqual(coverage["inputSemanticLeafLedgerHash"], dossier["leafCoverage"]["semanticLeafLedgerHash"])
                self.assertEqual(coverage["inputReferenceOccurrenceInventoryHash"],
                    dossier["leafCoverage"]["referenceOccurrenceInventoryHash"])
                self.assertTrue(coverage["allInputFieldsAccounted"])

    def test_parent_interview_and_lineages_keep_history_current_and_attribution_separate(self):
        sidecar = self.value(self.outputs["history"], graph.SIDECAR_PATH)
        collection = sidecar["scopes"][0]
        self.assertEqual([row["origin"] for row in collection["lineages"]], ["artist", "estate"])
        self.assertEqual([row["recordFamily"] for row in collection["lineages"][0]["revisions"]],
            ["intent", "intent_waiver", "intent"])
        self.assertEqual([row["revision"] for row in collection["lineages"][0]["revisions"]], ["1", "2", "3"])
        rows = sidecar["selectionLineages"]
        self.assertTrue(rows)
        self.assertTrue(all(row["parentSourceRecord"]["recordHash"] == row["selection"]["recordHash"] for row in rows))
        stale = self.value(self.outputs["stale"], graph.SIDECAR_PATH)["scopes"][0]["lineages"][0]
        self.assertFalse(stale["currentEligibility"]["eligible"])
        self.assertIn("current_association_differs", stale["currentEligibility"]["reasons"])

    def test_changed_missing_unknown_or_rehashed_input_derivatives_reject(self):
        original = self.inputs["av"]
        for mode in ("missing", "unknown", "profile", "references", "leaves", "parent"):
            files = dict(original)
            if mode == "missing": del files[dossier_projection.OUTPUTS[1]]
            elif mode == "unknown": files["conservation/other.json"] = b"{}"
            elif mode == "profile": files[dossier_projection.OUTPUTS[3]] += b"\n"
            else:
                if mode == "parent":
                    path = dossier_projection.OUTPUTS[0]
                    value = loads(files[path], maximum=MAX_JSON)
                    value["parentInterviewRelationships"][0]["parentRecordHash"] = "0x" + "00" * 32
                else:
                    path = dossier_projection.OUTPUTS[1 if mode == "references" else 2]
                    value = loads(files[path], maximum=MAX_JSON)
                    key = "occurrences" if mode == "references" else "leaves"
                    value[key] = value[key][1:]
                files[path] = dumps(value)
            with self.subTest(mode=mode), self.assertRaises(MuseumError):
                graph.render(files)

    def test_projection_is_deterministic_and_does_not_mutate_inputs(self):
        inputs = deepcopy(self.inputs["written"])
        before = dict(inputs)
        first = graph.render(inputs)
        second = graph.project(inputs)
        self.assertEqual(first, second)
        self.assertEqual(inputs, before)
        report = self.value(first, graph.REPORT_PATH)
        self.assertEqual(report["completeness"], "complete_with_stream_extensions")
        self.assertEqual(report["inputFiles"], [{"path": path, "hash": keccak256(raw), "bytes": str(len(raw))}
            for path, raw in sorted(inputs.items())])


if __name__ == "__main__":
    unittest.main()

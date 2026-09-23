"""Pure synthetic condition/conservation controls; no actual chain evidence."""
import copy
from pathlib import Path
import unittest

from .canonical import MuseumError, dumps, loads, schema_id, keccak256
from .citations import canonical_citation
from .condition import (NAME, SCHEMA_BYTES, TREATMENT_SCHEMA_BYTES, SCHEMAS, PROFILE_BYTES,
    CLAIMS, PROFILE_HASH, admit_payload, admit_document, compare_conditions, render,
    admit_owner, admit_independent, project_owner_conditions, project_independent_conditions)
from .exhibitions import fields
from .preservation_graph import validator

ROOT = Path(__file__).resolve().parents[2]
H = lambda n: "0x" + format(n, "064x")
A = lambda n: "0x" + format(n, "040x")


def reference(n=1):
    return {"uri": "urn:test:source:" + str(n),
        "hash": {"algorithm": "1", "digest": H(n), "canonicalizationId": schema_id("RAW_BYTES")}}


def record(n=1):
    return {"recordHash": H(n), **reference(n)}


def date(day="14"):
    instant = "2026-09-" + day + "T12:00:00Z"
    return {"expression": "September " + day + ", 2026", "precision": "exact", "calendar": "gregorian",
        "timezone": "UTC", "earliest": instant, "latest": instant}


def examiner():
    return {"entityId": "urn:test:examiner", "kind": "Person",
        "name": {"value": "Conservator e\u0301 / Exact", "language": "fr-CA"},
        "reference": reference(2), "institution": reference(3), "credentials": [reference(4)]}


def capture(n=1, capture_class="still"):
    return {"captureId": "urn:test:capture:" + str(n), "captureClass": capture_class, **reference(50+n),
        "format": {"formatId": H(70+n), "registryEntry": reference(70+n)},
        "displayHardwareInstallationNote": "Monitor 02; original  2 spaces, e\u0301."}


def condition():
    route = {"renderer": A(5), "routeHash": H(6)}
    return {"version": "1", "reportId": "urn:test:condition:outbound", "tokenId": "41",
        "examinationDate": date(), "examiner": examiner(),
        "workCitation": canonical_citation("1", A(1), "41", {"kind": "fin", "hash": H(10)}),
        "protocolState": {"blockNumber": "20", "blockHash": H(20), "stateRoot": H(21), "observation": reference(22)},
        "finality": {"verifyFinality": "pass", "finalityHash": H(10), "routeMatch": "match",
            "expectedRoute": route, "observedRoute": copy.deepcopy(route), "reason": None, "evidence": [reference(7)]},
        "fixity": {"status": "covered", "cycle": record(25), "latestCycleClaimed": True, "coverage": "complete", "reason": None,
            "payloads": [{"objectId": "urn:test:artifact:1", "reference": reference(26), "result": "pass"}]},
        "render": {"outcome": "pass", "method": reference(30), "reason": None, "evidence": [reference(31)],
            "acceptance": {"mode": "BYTE_EXACT", "referenceRender": record(32), "rendererClass": "STATIC",
                "softwareRasterization": True, "environment": reference(33)}},
        "recoveryLineage": {"status": "none", "statement": "No executed post-finality recovery reported.", "entries": []},
        "captures": [capture(), capture(2, "scripted_session")], "narrative": "Original e\u0301 condition.\nSecond line."}


def recovery(n=1):
    return {"recoveryId": "urn:test:recovery:" + str(n), "manifest": record(80+n), "executedAt": date(),
        "beforeContent": reference(90+n)["hash"], "afterContent": reference(91+n)["hash"], "ownerResponses": [record(100+n)]}


def curated(value):
    value["render"]["acceptance"] = {"mode": "CURATED_EQUIVALENCE", "referenceRender": record(32),
        "artistIntent": record(34), "attestation": record(35), "attestationLane": "INDEPENDENT_CONDITION",
        "evidenceClass": "SIGNER_VERIFIED", "evaluations": [{"propertyId": "urn:test:property:timing",
            "sourcePointer": "/significantProperties/0", "outcome": "equivalent", "note": "Exact timing retained.", "evidence": [reference(36)]}]}
    return value


def treatment():
    return {"version": "1", "treatmentId": "urn:test:treatment:1", "tokenId": "41",
        "workCitation": condition()["workCitation"], "kind": "treatment", "eventType": "NORMALIZATION",
        "status": "completed", "eventDate": date(), "agents": [{"agent": examiner(), "role": "conservator"}],
        "artifacts": [{"objectId": "urn:test:artifact:1", "role": "source", "reference": reference(40), "formatId": H(1)},
            {"objectId": "urn:test:artifact:2", "role": "outcome", "reference": reference(41), "formatId": H(2)}],
        "treatmentClass": "urn:test:treatment-class:normalization", "method": reference(42),
        "description": "Normalize a preserved derivative, retaining its source.", "outcome": "SUCCESS",
        "outcomeDetail": "Reported success.", "evidence": [reference(43)], "artistIntent": record(44),
        "authorization": record(45), "beforeCondition": record(46), "afterCondition": record(47), "migration": None}


def row(value=None, kind="condition"):
    return admit_payload(dumps(condition() if value is None else value), kind=kind)


from .test_loans import OwnerFixture


class ConditionOwnerFixture(OwnerFixture):
    """Synthetic original-wire responses; replay provenance does not make a deployment."""
    def __init__(self, **kwargs):
        self.condition_count = 0
        super().__init__(**kwargs)

    def append(self, family, schema, value, relayed=None):
        if family == "CONDITION_REPORT":
            from .test_valuations import ValuationFixture
            if self.condition_count == 0:
                ValuationFixture.register_schema(self, NAME, SCHEMA_BYTES)
            value = condition()
            value["workCitation"] = canonical_citation(self.a["chainId"], self.a["core"], "41", {"kind": "fin", "hash": H(10)})
            value["reportId"] += str(self.condition_count)
            self.condition_count += 1
        return super().append(family, schema, value, relayed)


class ConditionTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.model = validator(ROOT / "schemas/museum")

    def reject_change(self, base, callback, kind="condition"):
        value = copy.deepcopy(base)
        callback(value)
        with self.assertRaises(MuseumError):
            row(value, kind)

    def test_condition_projection_preserves_every_field(self):
        value = condition()
        admitted = row(value)
        self.assertEqual(admitted["value"], value)
        self.assertEqual(admitted["authority"], {"kind": "draft_unverified_submission", "authenticated": False})
        files = render([admitted], self.model)
        dossier = loads(files["condition/dossiers.json"], maximum=524288)[0]
        self.assertEqual(dossier["value"], value)
        coverage = loads(files["condition/coverage.json"], maximum=524288)
        self.assertEqual([(r["sourcePath"], r["value"]) for r in coverage], list(fields(admitted["value"])))
        self.assertEqual(dossier["value"]["captures"], value["captures"])
        self.assertIn("e\u0301", dossier["value"]["narrative"])
        self.assertEqual(loads(files["condition/report.json"])["claims"], CLAIMS)
        self.assertTrue(all(not value for value in CLAIMS.values()))
        self.assertEqual(loads(files["condition/report.json"])["linkedArtValidation"], "validated_emitted_resources")

    def test_opaque_original_schema_is_not_reinterpreted(self):
        opaque = dumps({"title": NAME, "type": "object"})
        submitted = dumps({"note": "Existing opaque fixture means only this."})
        admitted = admit_document(submitted, opaque)
        self.assertIsNone(admitted["value"])
        self.assertEqual(admitted["originalPayloadHex"], "0x" + submitted.hex())
        self.assertEqual(admitted["registeredSchemaHex"], "0x" + opaque.hex())
        self.assertEqual(loads(render([admitted])["condition/report.json"])["status"], "unsupported")
        with self.assertRaises(MuseumError):
            admit_payload(dumps(condition()), schema_bytes=opaque)

    def test_required_state_fields_and_closed_schema(self):
        base = condition()
        for field in ("examinationDate", "examiner", "workCitation", "protocolState", "finality", "fixity", "render", "recoveryLineage", "narrative"):
            with self.subTest(field=field):
                self.reject_change(base, lambda v, field=field: v.pop(field))
        self.reject_change(base, lambda v: v.update(authority={"authenticated": True}))
        self.reject_change(base, lambda v: v.update(narrative=""))
        with self.assertRaises(MuseumError):
            admit_payload(dumps(base) + b"\n")

    def test_citation_and_protocol_state_negative_controls(self):
        base = condition()
        for change in (
            lambda v: v.update(workCitation=v["workCitation"].split("@")[0]),
            lambda v: v.update(workCitation=v["workCitation"].replace("@fin:", "@block:")),
            lambda v: v.update(tokenId="42"),
            lambda v: v["protocolState"].update(blockNumber="020"),
            lambda v: v["protocolState"].update(stateRoot=H(0)),
            lambda v: v["finality"].update(finalityHash=H(11)),
            lambda v: v["finality"].update(evidence=[]),
            lambda v: v["finality"]["observedRoute"].update(routeHash=H(999)),
            lambda v: v["finality"].update(routeMatch="mismatch"),
            lambda v: v["finality"].update(verifyFinality="not_verified"),
        ):
            self.reject_change(base, change)

    def test_explicit_nonverification_is_retained(self):
        value = condition()
        value["finality"].update(verifyFinality="not_verified", finalityHash=None, routeMatch="not_verified",
            expectedRoute=None, observedRoute=None, reason="No actual state calls.", evidence=[])
        value["fixity"].update(status="not_checked", cycle=None, latestCycleClaimed=False, coverage="unknown",
            reason="No cycle selected.", payloads=[])
        value["render"].update(outcome="not_verified", method=None, reason="No execution environment.", evidence=[])
        self.assertEqual(row(value)["value"], value)
        self.reject_change(value, lambda v: v["render"].update(reason=None))

    def test_fixity_coverage_contradictions_reject(self):
        base = condition()
        for change in (
            lambda v: v["fixity"].update(cycle=None),
            lambda v: v["fixity"].update(latestCycleClaimed=False),
            lambda v: v["fixity"].update(coverage="partial"),
            lambda v: v["fixity"].update(payloads=[]),
            lambda v: v["fixity"]["payloads"][0].update(result="fail"),
            lambda v: v["fixity"]["payloads"].append(v["fixity"]["payloads"][0]),
        ):
            self.reject_change(base, change)

    def test_byte_exact_requires_static_software_rasterization(self):
        self.reject_change(condition(), lambda v: v["render"]["acceptance"].update(rendererClass="DYNAMIC"))
        self.reject_change(condition(), lambda v: v["render"]["acceptance"].update(softwareRasterization=False))

    def test_perceptual_threshold_is_exact_without_metric_truth(self):
        value = condition()
        value["render"]["acceptance"] = {"mode": "PERCEPTUAL_TOLERANCE", "referenceRender": record(32),
            "metricId": schema_id("STREAM_METRIC_SSIM_V1"), "metricDefinition": reference(38),
            "threshold": "0.990000", "comparison": "greater_than_or_equal", "observedValue": "0.990000000000000001"}
        self.assertEqual(row(value)["value"]["render"]["acceptance"]["threshold"], "0.990000")
        self.reject_change(value, lambda v: v["render"]["acceptance"].update(observedValue="0.989999999999999999"))
        self.reject_change(value, lambda v: v["render"]["acceptance"].update(threshold="9.9e-1"))
        self.reject_change(value, lambda v: v["render"]["acceptance"].update(metricId=H(0)))

    def test_curated_acceptance_remains_unproven(self):
        value = curated(condition())
        files = render([row(value)], self.model)
        report = loads(files["condition/report.json"])
        self.assertFalse(report["claims"]["renderAcceptanceProven"])
        self.assertFalse(report["claims"]["examinerIndependenceProven"])
        for change in (
            lambda v: v["examiner"].update(name=None),
            lambda v: v["examiner"].update(institution=None),
            lambda v: v["examiner"].update(credentials=[]),
            lambda v: v["render"]["acceptance"].update(attestation=None),
            lambda v: v["render"]["acceptance"].update(evidenceClass="OPERATOR_ASSERTED"),
            lambda v: v["render"]["acceptance"].update(evaluations=[]),
            lambda v: v["render"]["acceptance"]["evaluations"][0].update(outcome="different"),
            lambda v: v["render"]["acceptance"]["evaluations"][0].update(sourcePointer="significantProperties/0"),
        ):
            self.reject_change(value, change)

    def test_recovery_explicit_none_and_connected_order(self):
        base = condition()
        self.reject_change(base, lambda v: v["recoveryLineage"]["entries"].append(recovery()))
        base["recoveryLineage"] = {"status": "recorded", "statement": "Two asserted executions.", "entries": [recovery(), recovery(2)]}
        self.assertEqual(len(row(base)["value"]["recoveryLineage"]["entries"]), 2)
        self.reject_change(base, lambda v: v["recoveryLineage"]["entries"][1].update(beforeContent=reference(900)["hash"]))
        self.reject_change(base, lambda v: v["recoveryLineage"]["entries"][1].update(executedAt=date("15")))
        self.reject_change(base, lambda v: v["recoveryLineage"]["entries"][1].update(manifest=record(81)))

    def test_capture_vocab_hash_format_and_order(self):
        base = condition()
        base["captures"] = [capture(i+1, kind) for i, kind in enumerate(("scripted_session", "av_container", "frame_sequence", "still"))]
        self.assertEqual(row(base)["value"]["captures"], base["captures"])
        for change in (
            lambda v: v["captures"][0].update(captureClass="video"),
            lambda v: v["captures"][0]["format"].update(formatId=H(0)),
            lambda v: v["captures"][0]["hash"].update(digest=H(0)),
            lambda v: v["captures"].append(v["captures"][0]),
        ):
            self.reject_change(base, change)

    def test_comparison_retains_changed_state_and_recovery(self):
        first, second = condition(), condition()
        second.update(reportId="urn:test:condition:return", examinationDate=date("15"), narrative="Returned with new assertion.")
        second["protocolState"].update(blockNumber="30", blockHash=H(30))
        second["recoveryLineage"] = {"status": "recorded", "statement": "One executed recovery asserted.", "entries": [recovery()]}
        second["captures"] = [capture(3)]
        comparison = compare_conditions(row(first), row(second))
        self.assertEqual(comparison["recoveryContinuity"], "declared_extension")
        self.assertEqual(comparison["additionalRecoveryEntries"], [recovery()])
        self.assertIn("protocolState", [d["field"] for d in comparison["differences"]])
        self.assertTrue(all(not value for value in comparison["claims"].values()))
        self.assertEqual(comparison["captureCorrespondence"][-1]["status"], "new_return_capture")
        files = render([row(first), row(second)], self.model, comparisons=[comparison])
        self.assertEqual(loads(files["condition/comparisons.json"], maximum=524288), [comparison])

    def test_comparison_rejects_other_work_and_reverse_time(self):
        first, second = condition(), condition()
        second["workCitation"] = canonical_citation("2", A(1), "41", {"kind": "fin", "hash": H(10)})
        with self.assertRaises(MuseumError):
            compare_conditions(row(first), row(second))
        second = condition()
        second["examinationDate"] = date("13")
        with self.assertRaises(MuseumError):
            compare_conditions(row(first), row(second))

    def test_recovery_regression_and_capture_conflict_are_explicit(self):
        first, second = condition(), condition()
        first["recoveryLineage"] = {"status": "recorded", "statement": "One execution asserted.", "entries": [recovery()]}
        second["captures"][0]["hash"] = reference(900)["hash"]
        result = compare_conditions(row(first), row(second))
        self.assertEqual(result["recoveryContinuity"], "inconsistent_declared_lineage")
        self.assertEqual(result["captureCorrespondence"][0]["status"], "conflicting_capture_identity")
        self.assertFalse(result["claims"]["noDamageProven"])

    def test_identity_collision_rejected(self):
        self.reject_change(condition(), lambda v: v["examiner"].update(entityId=v["reportId"]))
        self.reject_change(condition(), lambda v: v["examiner"].update(entityId="eip155:1"))
        a, b = condition(), condition()
        b["reportId"] = "urn:test:condition:return"
        b["examiner"]["name"]["value"] = "Different declaration under reused identity"
        with self.assertRaises(MuseumError):
            render([row(a), row(b)])

    def test_external_authority_retained_without_examiner_promotion(self):
        original = row()
        original["source"] = {"recordHash": H(9), "owner": A(9), "recordIndex": "1"}
        original["authority"] = {"kind": "historical_owner", "account": A(9)}
        files = render([original])
        dossier = loads(files["condition/dossiers.json"], maximum=524288)[0]
        self.assertEqual(dossier["source"], original["source"])
        self.assertEqual(dossier["authority"], original["authority"])
        self.assertFalse(loads(files["condition/named-roles.json"])[0]["independenceProven"])
        self.assertFalse(loads(files["condition/report.json"])["claims"]["actualSourceAuthenticated"])

    def test_completed_treatment_and_migration(self):
        value = treatment()
        files = render([row(value, "treatment")], self.model)
        self.assertIn("Activity", [r["type"] for r in loads(files["condition/index.json"])["resources"]])
        self.assertTrue(loads(files["condition/report.json"])["dispositions"][0]["performedInterventionProjected"])
        value.update(kind="environment_migration", eventType="MIGRATION", migration={"sourceObjectId": "urn:test:artifact:1",
            "outcomeObjectId": "urn:test:artifact:2", "bootOutcome": "pass", "acceptanceOutcome": "pass", "evidence": [reference(48)]})
        self.assertEqual(row(value, "treatment")["value"], value)
        for change in (
            lambda v: v["migration"].update(sourceObjectId="urn:test:artifact:missing"),
            lambda v: v["migration"].update(outcomeObjectId="urn:test:artifact:1"),
            lambda v: v["migration"].update(bootOutcome="fail"),
            lambda v: v["migration"].update(acceptanceOutcome="not_checked"),
            lambda v: v["migration"].update(evidence=[]),
        ):
            self.reject_change(value, change, "treatment")

    def test_notes_and_plans_never_emit_interventions(self):
        for status in ("planned", "cancelled", "unknown"):
            value = treatment()
            value.update(status=status, outcome="NOT_PERFORMED")
            files = render([row(value, "treatment")], self.model)
            self.assertNotIn("Activity", [r["type"] for r in loads(files["condition/index.json"])["resources"]])
            self.assertFalse(loads(files["condition/report.json"])["dispositions"][0]["performedInterventionProjected"])
        value = treatment()
        value.update(kind="conservation_note", eventType="CONSERVATION_NOTE", treatmentClass=None)
        files = render([row(value, "treatment")], self.model)
        self.assertNotIn("Activity", [r["type"] for r in loads(files["condition/index.json"])["resources"]])
        self.assertIn("LinguisticObject", [r["type"] for r in loads(files["condition/index.json"])["resources"]])

    def test_treatment_contradictions_reject(self):
        for change in (
            lambda v: v.update(eventType="CONSERVATION_NOTE"),
            lambda v: v.update(outcome="NOT_PERFORMED"),
            lambda v: v.update(status="planned"),
            lambda v: v.update(method=None),
            lambda v: v.update(treatmentClass=None),
            lambda v: v.update(evidence=[]),
            lambda v: v["agents"].append(v["agents"][0]),
            lambda v: v["artifacts"].append(v["artifacts"][0]),
            lambda v: v.update(kind="conservation_note"),
        ):
            self.reject_change(treatment(), change, "treatment")

    def test_generated_candidates_are_exact(self):
        for name, raw in list(SCHEMAS.items()) + [("profile", PROFILE_BYTES)]:
            self.assertEqual((ROOT / "schemas/museum/condition" / (name + ".json")).read_bytes(), raw)
        self.assertNotEqual(SCHEMA_BYTES, TREATMENT_SCHEMA_BYTES)

    def test_original_owner_join_replays_and_ignores_mutable_cached_rows(self):
        fixture = ConditionOwnerFixture()
        source, _, _ = fixture.replay()
        pin = keccak256(source.snapshot())
        selected = fixture.lanes[(41, schema_id("CONDITION_REPORT"))]
        original = admit_owner(source, selected, source_hash=pin)
        self.assertEqual(len(original), 2)
        source.records[selected[0]]["authority"]["owner"] = A(999)
        source.records[selected[0]]["payloadHex"] = "0x00"
        source.documents[schema_id(NAME)] = (b"", b"{}", None)
        again = admit_owner(source, selected, source_hash=pin)
        self.assertEqual(again, original)
        files = project_owner_conditions(source, selected, source_hash=pin, profile_hash=PROFILE_HASH, model=self.model)
        report = loads(files["condition/report.json"])
        self.assertTrue(report["sourceReceiptEvidenceChecked"])
        self.assertFalse(report["claims"]["examinerIdentityProven"])
        self.assertEqual(original[0]["authority"]["mode"], "historical_owner_receipt")
        with self.assertRaises(MuseumError):
            admit_owner(source, selected, source_hash=H(999))
        with self.assertRaises(MuseumError):
            admit_owner(fixture.adapter(), selected, source_hash=pin)

    def test_owner_original_opaque_meaning_and_wrong_family(self):
        fixture = OwnerFixture()
        source, _, _ = fixture.replay()
        pin = keccak256(source.snapshot())
        selected = fixture.lanes[(41, schema_id("CONDITION_REPORT"))]
        rows = admit_owner(source, selected, source_hash=pin)
        self.assertTrue(all(r["value"] is None for r in rows))
        self.assertTrue(all(r["authority"]["mode"] == "historical_owner_receipt" for r in rows))
        with self.assertRaises(MuseumError):
            admit_owner(source, [fixture.loan_hash], source_hash=pin)

    def test_independent_actual_source_absence_and_frozen_identity_boundary(self):
        from .test_recorded_account import load_source
        from .review import _selector
        from dataclasses import replace
        source = load_source()
        pin = source.state.commitment
        self.assertEqual(admit_independent(source, [], source_hash=pin), [])
        report = loads(project_independent_conditions(source, [], source_hash=pin, profile_hash=PROFILE_HASH)["condition/report.json"])
        self.assertEqual(report["status"], "unsupported")
        self.assertEqual(report["reasonCode"], "no_selected_condition_or_treatment")
        # This actual captured source does not contain a typed condition family.
        original = source.state.records[0]
        with self.assertRaises(MuseumError):
            admit_independent(source, [_selector(original, "")], source_hash=pin)
        source.records = {"malicious": original}
        source.canonicalizations = {"malicious": "invalid"}
        source.positions = {"malicious": (0, 0, 0)}
        self.assertEqual(admit_independent(source, [], source_hash=pin), [])
        source._state = replace(source.state, records=())
        with self.assertRaises(MuseumError):
            admit_independent(source, [], source_hash=pin)


if __name__ == "__main__":
    unittest.main()

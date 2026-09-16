"""Typed synthetic event controls, original fixity composition, and actual-source offline negatives."""
import copy
from pathlib import Path
import tempfile
import contextlib
import io
import sys
import unittest
from unittest.mock import patch

from lxml import etree

from .canonical import MuseumError, dumps, keccak256, loads, schema_id
from .preservation_events import (AGENT_NAME, EVENT_NAME, REPORT_NAME, FAMILIES, SCHEMAS, MODE, PROFILE_BYTES,
    PROFILE_HASH, TYPE_LABELS, OUTCOME_LABELS, admit, render, project_recorded_preservation)
from .recorded_fixity import SCHEMAS as OLD_SCHEMAS, FAMILIES as OLD_FAMILIES, _admit as admit_fixity
from .recorded_semantic import JCS_ID
from .recorded_premis import PROFILE_HASH as FILE_HASH
from .source import RecordSelector, RetainedSourceRecord
from .review import _selector
from .test_recorded_fixity import SyntheticTypedSource, RecordedFixity, ACCOUNT, FILE, EVENT, AGENT, OBJECT, H, base_xml
from .premis import NS
from .package import write_package
from .package_recorded import build_recorded_package
from .package_v2 import verify_package
from .preservation_package import build_preservation_package
from .test_package import changed
from .test_package_recorded import inputs, pins

GENERAL = H("e3")


class GenericControl(SyntheticTypedSource):
    def add(self, name, body, index):
        schema = (OLD_SCHEMAS | SCHEMAS)[name]
        family = (OLD_FAMILIES | FAMILIES)[name]
        raw = dumps(body); digest = keccak256(dumps({"index": str(index), "name": name, "payload": keccak256(raw)}))
        selector = RecordSelector("0x" + "33" * 20, digest, H("44"), schema_id(name), keccak256(schema), family,
            ACCOUNT, "INDEPENDENT_ATTESTOR", str(index), H("55"))
        record = RetainedSourceRecord(selector, raw, keccak256(raw), schema,
            dumps({"mode": "synthetic_control", "recorder": ACCOUNT, "humanIdentityEstablished": False}), "public")
        self.records[digest], self.positions[digest], self.canonicalizations[digest] = record, (index, 0, 0), JCS_ID
        return record

    def __init__(self, kind="INGEST", outcome="SUCCESS", status="completed", *, multi=False, change=None):
        super().__init__()
        old = loads(self.event.payload)
        self.fixity_selector = self.selector
        objects = [{"objectId": OBJECT, "identifier": FILE, "role": schema_id("SOURCE_MASTER")}]
        agents = [{"agent": old["agent"], "document": old["agentDocument"]}]
        if multi:
            second = {"version": "1", "agentId": H("a2"), "name": "Reported institution", "type": "organization", "agentVersion": ""}
            record = self.add(AGENT_NAME, second, 4)
            agents.append({"agent": old["agent"] | {"agentId": H("a2"), "agentHash": record.payload_hash,
                "agentRole": schema_id("OBSERVER"), "account": "0x" + "00" * 20}, "document": _selector(record, "")})
            objects.append({"objectId": H("b2"), "identifier": "urn:local:second-file", "role": schema_id("DISPLAY_DERIVATIVE")})
        report = {"version": "1", "eventId": GENERAL, "eventType": schema_id(kind), "outcome": schema_id(outcome),
            "eventTime": "1700000000", "status": status, "objectIds": [v["objectId"] for v in objects],
            "agentIds": [v["agent"]["agentId"] for v in agents], "detail": "Synthetic unit control; not a performed historical capture.",
            "outcomeDetail": "Explicit recorded outcome detail.", "results": [{"purpose": "Retained source result",
                "uri": "ipfs://recorded-result", "contentHash": self.record(old["report"]).payload_hash, "record": old["report"]}]}
        if change: change(report)
        self.report = self.add(REPORT_NAME, report, 5)
        body = {"version": "1", "event": {"eventId": GENERAL, "eventType": report["eventType"], "outcome": report["outcome"],
            "eventURI": "ipfs://preservation-report", "eventHash": self.report.payload_hash,
            "eventTime": report["eventTime"], "schemaId": schema_id(REPORT_NAME)},
            "objects": objects, "agents": agents, "report": _selector(self.report, "")}
        self.generic = self.add(EVENT_NAME, body, 6)
        self.generic_selector = _selector(self.generic, "")

    def generic_rows(self): return admit(self, [self.generic_selector])


def two_files():
    root = etree.fromstring(base_xml())
    node = copy.deepcopy(root[0]); node.find("{" + NS + "}objectIdentifier/{" + NS + "}objectIdentifierValue").text = "urn:local:second-file"
    root.append(node)
    return etree.tostring(root, encoding="UTF-8", xml_declaration=True)


class PreservationEvents(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        # Reuse only the setup, never relabel its actual source as a synthetic positive.
        RecordedFixity.setUpClass()
        cls.schema, cls.source = RecordedFixity.schema, RecordedFixity.source
        cls.selection, cls.plan, cls.file_plan = RecordedFixity.selection, RecordedFixity.plan, RecordedFixity.file_plan

    def plan_for(self, **updates):
        return {"mode": MODE, "version": "1", "sourceStateHash": self.source.state.commitment,
            "profileHash": self.source.profile_hash, "premisPlanHash": keccak256(self.file_plan),
            "preservationProfileHash": PROFILE_HASH, "events": []} | updates

    def actual(self, **updates):
        raw = dumps(self.plan_for())
        args = dict(selection_hash=keccak256(self.selection), plan_hash=keccak256(self.plan),
            premis_plan_hash=keccak256(self.file_plan), premis_profile_hash=FILE_HASH, preservation_plan_hash=keccak256(raw),
            preservation_profile_hash=PROFILE_HASH, premis_schema=self.schema, observations={}) | updates
        return project_recorded_preservation(self.source, self.selection, self.plan, self.file_plan, raw, **args)

    def test_all_twelve_general_kinds_and_six_outcomes_match_adopted_labels(self):
        for kind, label in TYPE_LABELS.items():
            if kind == "FIXITY_CHECK": continue
            for outcome, expected in OUTCOME_LABELS.items():
                with self.subTest(kind=kind, outcome=outcome):
                    source = GenericControl(kind, outcome)
                    xml, issues, dispositions, correspondence, provenance = render(base_xml(), source.generic_rows(), [], {}, self.schema)
                    self.assertEqual(issues, [])
                    root = self.schema.validate(xml)
                    self.assertEqual(root.findtext("{" + NS + "}event/{" + NS + "}eventType"), label)
                    self.assertEqual(root.findtext("{" + NS + "}event/{" + NS + "}eventOutcomeInformation/{" + NS + "}eventOutcome"), expected)
                    self.assertEqual(dispositions[0]["disposition"], "premis_event")
                    self.assertEqual(correspondence[0]["eventTime"], "1700000000")
                    self.assertEqual(provenance[0]["sourceReport"], loads(source.report.payload))
                    if outcome in ("INCONCLUSIVE", "SUPERSEDED", "REDACTED"):
                        self.assertIn(b"<premis:eventOutcomeDetail>", xml)

    def test_multi_object_multi_agent_links_and_opaque_result_bytes_remain_separate(self):
        source = GenericControl("MIGRATION", multi=True)
        with patch("socket.socket", side_effect=AssertionError("network")):
            xml, issues, _, correspondence, provenance = render(two_files(), source.generic_rows(), [], {}, self.schema)
        self.assertFalse(issues)
        root = self.schema.validate(xml); event = root.find("{" + NS + "}event")
        self.assertEqual(len(event.findall("{" + NS + "}linkingAgentIdentifier")), 2)
        self.assertEqual(len(event.findall("{" + NS + "}linkingObjectIdentifier")), 2)
        self.assertEqual(len(root.findall("{" + NS + "}agent")), 2)
        self.assertEqual(correspondence[0]["objects"][1]["identifier"], "urn:local:second-file")
        self.assertEqual(provenance[0]["typedEvent"], loads(source.generic.payload))
        self.assertIn(b"historical execution and outcome not independently verified", xml)

    def test_noncompleted_states_never_become_performed_events(self):
        for status in ("planned", "cancelled", "unknown"):
            source = GenericControl(status=status, change=lambda r: r.update(eventTime="0", outcome=H("00"), results=[]))
            xml, issues, dispositions, correspondence, provenance = render(base_xml(), source.generic_rows(), [], {}, self.schema)
            self.assertFalse(issues)
            self.assertNotIn(b"<premis:event>", xml)
            self.assertEqual(dispositions[0]["disposition"], "retained_noncompleted_source")
            self.assertEqual(dispositions[0]["sourceStatus"], status)
            self.assertEqual(correspondence[0]["sourceStatus"], status)
            self.assertEqual(provenance[0]["sourceReport"]["eventTime"], "0")

    def test_original_fixity_is_composed_and_generic_fixity_cannot_bypass_observations(self):
        source = GenericControl("VALIDATION")
        fixes = admit_fixity(source, [source.fixity_selector])
        xml, issues, dispositions, _, _ = render(base_xml(), source.generic_rows(), fixes, {EVENT: b"abc"}, self.schema)
        self.assertFalse(issues)
        root = self.schema.validate(xml)
        self.assertEqual(len(root.findall("{" + NS + "}event")), 2)
        self.assertEqual(len(root.findall("{" + NS + "}agent")), 1)
        self.assertEqual(len(dispositions), 2)
        xml, issues, _, _, _ = render(base_xml(), source.generic_rows(), fixes, {}, self.schema)
        self.assertIsNone(xml)
        self.assertIn({"eventId": EVENT, "reasonCode": "observation_bytes_missing"}, issues)
        with self.assertRaisesRegex(MuseumError, "fixity needs"):
            GenericControl("FIXITY_CHECK").generic_rows()
        with self.assertRaisesRegex(MuseumError, "unselected observation"):
            render(base_xml(), source.generic_rows(), [], {EVENT: b"abc"}, self.schema)

    def test_missing_completed_evidence_local_detail_or_time_is_explicit_unsupported(self):
        for outcome, mutation, reason in (("SUCCESS", {"results": []}, "completed_report_result_evidence_missing"),
                ("INCONCLUSIVE", {"outcomeDetail": ""}, "local_outcome_detail_missing"),
                ("SUCCESS", {"eventTime": "0"}, "completed_timestamp_unavailable_for_xml")):
            source = GenericControl(outcome=outcome, change=lambda r: r.update(mutation))
            xml, issues, _, _, _ = render(base_xml(), source.generic_rows(), [], {}, self.schema)
            self.assertIsNone(xml)
            self.assertIn({"eventId": GENERAL, "reasonCode": reason}, issues)

    def test_report_agent_result_links_and_original_publication_order_are_mandatory(self):
        for which in ("report", "agent", "result"):
            source = GenericControl()
            body = loads(source.generic.payload)
            record = source.report if which == "report" else source.record(body["agents"][0]["document"] if which == "agent"
                else loads(source.report.payload)["results"][0]["record"])
            source.positions[record.selector.record_hash] = (99, 0, 0)
            with self.subTest(which=which), self.assertRaisesRegex(MuseumError, "prior publication"):
                source.generic_rows()
        source = GenericControl(); body = loads(source.generic.payload)
        body["event"]["eventHash"] = H("ff")
        revised = source.add(EVENT_NAME, body, 6)
        with self.assertRaisesRegex(MuseumError, "report reference"):
            admit(source, [_selector(revised, "")])
        source = GenericControl(change=lambda r: r["results"][0].update(contentHash=H("ff")))
        with self.assertRaisesRegex(MuseumError, "result whole payload"):
            source.generic_rows()

    def test_identity_collisions_duplicate_events_and_unknown_target_file_reject(self):
        source = GenericControl(); rows = source.generic_rows()
        with self.assertRaisesRegex(MuseumError, "duplicate event"):
            render(base_xml(), rows + rows, [], {}, self.schema)
        rows = source.generic_rows(); rows[0]["body"]["objects"][0]["identifier"] = "urn:wrong:file"
        xml, issues, dispositions, _, _ = render(base_xml(), rows, [], {}, self.schema)
        self.assertEqual(dispositions[0]["disposition"], "unsupported")
        self.assertIsNone(xml)
        self.assertIn({"eventId": GENERAL, "reasonCode": "selected_file_projection_unavailable"}, issues)
        rows = source.generic_rows(); rows[0]["body"]["objects"][0]["identifier"] = "urn:wrong:file"
        with self.assertRaisesRegex(MuseumError, "object ID collision"):
            render(base_xml(), rows, admit_fixity(source, [source.fixity_selector]), {EVENT: b"abc"}, self.schema)
        rows = source.generic_rows(); rows[0]["agents"][0][1]["name"] = "Hostile replacement"
        with self.assertRaisesRegex(MuseumError, "conflicting named-agent"):
            render(base_xml(), rows, admit_fixity(source, [source.fixity_selector]), {EVENT: b"abc"}, self.schema)

    def test_actual_retained_source_remains_precisely_unsupported_without_events(self):
        result = self.actual(); self.assertIsNone(result.xml)
        report = loads(result.report, maximum=67108864)
        self.assertIn({"reasonCode": "no_selected_preservation_events"}, report["issues"])
        self.assertEqual(report["issues"][0]["reasonCode"], "file_profile_unsupported")
        self.assertFalse(any(report["claims"].values()))
        self.assertEqual(report["sourceEvidence"]["sourceCaptureHash"], keccak256(self.source.capture_bytes))
        with self.assertRaisesRegex(MuseumError, "plan/profile"):
            self.actual(preservation_profile_hash=H("ff"))

    def test_versioned_package_retains_source_and_reconstructs_every_output_offline(self):
        original = build_recorded_package(inputs(), root=Path(__file__).resolve().parents[2] / "schemas/museum",
            disclosure="public", **pins(), premis_plan_bytes=self.file_plan, premis_plan_hash=keccak256(self.file_plan), premis_profile_hash=FILE_HASH)
        raw = dumps(self.plan_for())
        with tempfile.TemporaryDirectory() as temp:
            source = Path(temp) / "source"; write_package(original, source)
            result = build_preservation_package(source, original.manifest_hash, raw,
                plan_hash=keccak256(raw), profile_hash=PROFILE_HASH, observations={}, disclosure="public")
            self.assertEqual(dict(result.files)["source/manifest.json"], original.manifest)
            for name, content in original.files: self.assertEqual(dict(result.files)["source/" + name], content)
            target = Path(temp) / "export"; write_package(result, target)
            with patch("socket.socket", side_effect=AssertionError("network")):
                self.assertEqual(verify_package(target, result.manifest_hash), result)
            from .preservation_package import main
            plan_path = Path(temp) / "plan.json"; plan_path.write_bytes(raw)
            cli_target = Path(temp) / "cli"
            argv = ["preservation_package", "build", str(source), str(plan_path), str(cli_target),
                "--source-manifest-hash", original.manifest_hash, "--plan-hash", keccak256(raw),
                "--profile-hash", PROFILE_HASH, "--disclosure", "public"]
            output = io.StringIO()
            with patch.object(sys, "argv", argv), contextlib.redirect_stdout(output):
                self.assertEqual(main(), 0)
            self.assertEqual(output.getvalue().strip(), result.manifest_hash)
            with patch.object(sys, "argv", ["preservation_package", "verify", str(cli_target), "--manifest-hash", result.manifest_hash]), contextlib.redirect_stdout(io.StringIO()):
                self.assertEqual(main(), 0)
            bad = changed(result, "premis-preservation/provenance.json", b"[] ")
            altered = Path(temp) / "altered"; write_package(bad, altered)
            with self.assertRaisesRegex(MuseumError, "semantic reconstruction"):
                verify_package(altered, bad.manifest_hash)
            with self.assertRaisesRegex(MuseumError, "public classification"):
                build_preservation_package(source, original.manifest_hash, raw,
                    plan_hash=keccak256(raw), profile_hash=PROFILE_HASH, observations={}, disclosure="restricted")

    def test_new_profile_uses_original_families_and_retained_document_bytes(self):
        from .independent_wire import RECORD_TYPES
        root = Path(__file__).resolve().parents[2] / "schemas/museum/preservation-events"
        self.assertTrue(set(FAMILIES.values()).issubset(RECORD_TYPES))
        self.assertEqual((root / "profile.json").read_bytes(), PROFILE_BYTES)
        for name, raw in SCHEMAS.items(): self.assertEqual((root / (name + ".json")).read_bytes(), raw)


if __name__ == "__main__": unittest.main()
"""Pure typed controls and actual retained-source missing-evidence/offline replay cases.

Synthetic records exercise admission rules without being promoted to a captured
RecordedSemanticSource. No positive historical performed check is claimed here.
"""
import copy
from dataclasses import replace
from hashlib import sha256
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch

from .canonical import MuseumError, dumps, keccak256, loads, schema_id
from .fixity_package import build_fixity_package, verify_fixity_package
from .package import write_package
from .package_v2 import verify_package
from .premis import NS, PinnedPremis, PROFILE_BYTES as OLD_BYTES, PROFILE_HASH as OLD_HASH
from .recorded_fixity import (AGENT_NAME, EVENT_NAME, REPORT_NAME, FAILED, FIXITY_CHECK, MODE,
    PROFILE_BYTES, PROFILE_HASH, SCHEMAS, FAMILIES, SHA256, SUCCESS, _admit, _render, project_recorded_fixity)
from .recorded_premis import MODE as FILE_MODE, PROFILE_HASH as FILE_HASH
from .review import _selector
from .source import RecordSelector, RetainedSourceRecord
from .test_package import changed
from .test_package_recorded import inputs, pins
from .package_recorded import build_recorded_package
from .test_recorded_account import ROOT, FIXTURE, load_source

H = lambda byte: "0x" + byte * 32
ACCOUNT = "0x" + "11" * 20
FILE = "urn:local:semantic:file"
EVENT, OBJECT, AGENT = H("e1"), H("b1"), H("a1")
DIGEST = "0x" + sha256(b"abc").hexdigest()


def control_documents(*, failed=False):
    description = {"version": "1", "agentId": AGENT, "name": "Declared test tool", "type": "software", "agentVersion": "0.1"}
    observed = b"bad" if failed else b"abc"
    report = {"version": "1", "eventId": EVENT, "objectId": OBJECT, "agentId": AGENT, "checkedAt": "1700000000",
        "algorithm": SHA256, "expectedDigest": DIGEST, "observedDigest": "0x" + sha256(observed).hexdigest(),
        "expectedByteSize": "3", "observedByteSize": "3", "outcome": FAILED if failed else SUCCESS,
        "performed": True, "detail": "Explicit synthetic unit control, not historical execution evidence."}
    return description, report, observed


class SyntheticTypedSource:
    def __init__(self, *, failed=False, change=None):
        from .recorded_semantic import JCS_ID
        self.records, self.positions, self.canonicalizations = {}, {}, {}
        description, report, self.observed = control_documents(failed=failed)
        if change: change(description, report)
        agent = self.add(AGENT_NAME, description, 1)
        check_report = self.add(REPORT_NAME, report, 2)
        body = {"version": "1", "object": FILE,
            "event": {"eventId": EVENT, "eventType": FIXITY_CHECK, "outcome": report["outcome"],
                "eventURI": "ipfs://test-report", "eventHash": check_report.payload_hash,
                "eventTime": report["checkedAt"], "schemaId": schema_id(REPORT_NAME)},
            "agent": {"agentId": AGENT, "agentRole": schema_id("EXECUTING_SOFTWARE"), "account": "0x" + "22" * 20,
                "did": "did:example:test-tool", "uri": "ipfs://test-agent", "agentHash": agent.payload_hash},
            "check": {"objectId": OBJECT, "algorithm": report["algorithm"], "digest": report["observedDigest"],
                "byteSize": report["observedByteSize"], "checkedAt": report["checkedAt"], "outcome": report["outcome"],
                "agentId": AGENT, "reportURI": "ipfs://test-report", "reportHash": check_report.payload_hash},
            "report": _selector(check_report, ""), "agentDocument": _selector(agent, "")}
        self.event = self.add(EVENT_NAME, body, 3)
        self.selector = _selector(self.event, "")

    def add(self, name, body, index):
        from .recorded_semantic import JCS_ID
        raw = dumps(body)
        h = keccak256(dumps({"index": str(index), "name": name, "payload": keccak256(raw)}))
        selector = RecordSelector("0x" + "33" * 20, h, H("44"), schema_id(name), keccak256(SCHEMAS[name]),
            FAMILIES[name], ACCOUNT, "INDEPENDENT_ATTESTOR", str(index), H("55"))
        record = RetainedSourceRecord(selector, raw, keccak256(raw), SCHEMAS[name],
            dumps({"mode": "synthetic_control", "recorder": ACCOUNT, "humanIdentityEstablished": False}), "public")
        self.records[h], self.positions[h], self.canonicalizations[h] = record, (index, 0, 0), JCS_ID
        return record

    def record(self, selector):
        record = self.records.get(selector.get("recordHash"))
        if record is None or _selector(record, selector["pointer"]) != selector:
            raise MuseumError("synthetic control exact selector mismatch")
        return record

    def rows(self):
        return _admit(self, [self.selector])


def base_xml():
    return ("<?xml version='1.0' encoding='UTF-8'?>\n"
        '<premis:premis xmlns:premis="http://www.loc.gov/premis/v3" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" version="3.0">'
        '<premis:object xsi:type="premis:file"><premis:objectIdentifier><premis:objectIdentifierType>URI</premis:objectIdentifierType>'
        '<premis:objectIdentifierValue>' + FILE + '</premis:objectIdentifierValue></premis:objectIdentifier>'
        '<premis:objectCharacteristics><premis:fixity><premis:messageDigestAlgorithm>SHA-256</premis:messageDigestAlgorithm>'
        '<premis:messageDigest>' + DIGEST[2:] + '</premis:messageDigest></premis:fixity><premis:size>3</premis:size>'
        '<premis:format><premis:formatRegistry><premis:formatRegistryName>PRONOM</premis:formatRegistryName>'
        '<premis:formatRegistryKey>fmt/1</premis:formatRegistryKey></premis:formatRegistry></premis:format>'
        '</premis:objectCharacteristics></premis:object></premis:premis>').encode()


class RecordedFixity(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.schema = PinnedPremis(ROOT, OLD_BYTES, profile_hash=OLD_HASH)
        cls.source = load_source()
        cls.selection, cls.plan = ((FIXTURE / name).read_bytes() for name in ("selection.json", "plan.json"))
        cls.file_plan = dumps({"mode": FILE_MODE, "version": "1", "sourceStateHash": cls.source.state.commitment,
            "profileHash": cls.source.profile_hash, "linkedArtPlanHash": keccak256(cls.plan),
            "premisProfileHash": FILE_HASH, "objects": [FILE]})

    def plan_for(self, **updates):
        return {"mode": MODE, "version": "1", "sourceStateHash": self.source.state.commitment,
            "profileHash": self.source.profile_hash, "premisPlanHash": keccak256(self.file_plan),
            "fixityProfileHash": PROFILE_HASH, "events": []} | updates

    def actual(self, plan=None, source=None, **updates):
        raw = dumps(self.plan_for() if plan is None else plan)
        options = dict(selection_hash=keccak256(self.selection), plan_hash=keccak256(self.plan),
            premis_plan_hash=keccak256(self.file_plan), premis_profile_hash=FILE_HASH,
            fixity_plan_hash=keccak256(raw), fixity_profile_hash=PROFILE_HASH, premis_schema=self.schema,
            observations={}) | updates
        return project_recorded_fixity(self.source if source is None else source, self.selection, self.plan,
            self.file_plan, raw, **options)

    def test_synthetic_typed_success_has_exact_event_agent_object_and_time_joins(self):
        source = SyntheticTypedSource()
        before = base_xml()
        with patch("socket.socket", side_effect=AssertionError("network")):
            xml, issues, correspondence, provenance = _render(before, source.rows(), {EVENT: b"abc"}, self.schema)
        self.assertEqual(issues, [])
        root = self.schema.validate(xml)
        ns = {"p": NS}
        self.assertEqual(root.xpath("p:event/p:eventType/text()", namespaces=ns), ["fixity check"])
        self.assertEqual(root.xpath("p:event/p:eventDateTime/text()", namespaces=ns), ["2023-11-14T22:13:20Z"])
        self.assertEqual(root.xpath("p:event/p:eventOutcomeInformation/p:eventOutcome/text()", namespaces=ns), ["success"])
        self.assertEqual(root.xpath("p:event/p:linkingObjectIdentifier/p:linkingObjectIdentifierValue/text()", namespaces=ns), [FILE])
        self.assertEqual(root.xpath("p:agent/p:agentName/text()", namespaces=ns), ["Declared test tool"])
        self.assertIn("0x" + "22" * 20, root.xpath("p:agent/p:agentIdentifier/p:agentIdentifierValue/text()", namespaces=ns))
        self.assertNotIn(ACCOUNT, root.xpath("p:agent/p:agentIdentifier/p:agentIdentifierValue/text()", namespaces=ns))
        self.assertEqual(correspondence[0]["objectId"], OBJECT)
        self.assertEqual(provenance[0]["performedReport"], loads(source.rows()[0]["records"][1].payload))
        self.assertEqual(base_xml(), before)
        self.assertIn(b"historical execution are not independently established", xml)

    def test_failed_observation_retains_expected_file_digest_and_reports_failure(self):
        source = SyntheticTypedSource(failed=True)
        xml, issues, _, _ = _render(base_xml(), source.rows(), {EVENT: source.observed}, self.schema)
        self.assertFalse(issues)
        self.assertIn(b"<premis:eventOutcome>fail</premis:eventOutcome>", xml)
        self.assertIn(("<premis:messageDigest>" + DIGEST[2:] + "</premis:messageDigest>").encode(), xml)
        self.assertIn(sha256(b"bad").hexdigest().encode(), xml)

    def test_observation_report_expected_file_and_outcome_substitution_reject(self):
        source = SyntheticTypedSource()
        with self.assertRaisesRegex(MuseumError, "supplied observation differs"):
            _render(base_xml(), source.rows(), {EVENT: b"abd"}, self.schema)
        rows = source.rows(); rows[0]["report"]["expectedDigest"] = H("aa")
        with self.assertRaisesRegex(MuseumError, "selected file facts"):
            _render(base_xml(), rows, {EVENT: b"abc"}, self.schema)
        source = SyntheticTypedSource(change=lambda a, r: r.update(outcome=FAILED))
        with self.assertRaisesRegex(MuseumError, "outcome contradicts"):
            _render(base_xml(), source.rows(), {EVENT: b"abc"}, self.schema)

    def test_precise_missing_and_unsupported_facts_never_emit_xml(self):
        source = SyntheticTypedSource()
        xml, issues, _, _ = _render(base_xml(), source.rows(), {}, self.schema)
        self.assertIsNone(xml)
        self.assertEqual(issues, [{"eventId": EVENT, "reasonCode": "observation_bytes_missing"}])
        for field, value, reason in (("eventType", schema_id("MIGRATION"), "unsupported_event_type"),
                ("eventTime", str(1 << 63), "timestamp_outside_xml_profile")):
            rows = source.rows(); rows[0]["value"]["event"][field] = value
            xml, issues, _, _ = _render(base_xml(), rows, {EVENT: b"abc"}, self.schema)
            self.assertIsNone(xml)
            self.assertIn({"eventId": EVENT, "reasonCode": reason}, issues)
        with self.assertRaisesRegex(MuseumError, "unselected observation"):
            _render(base_xml(), source.rows(), {H("aa"): b"abc"}, self.schema)

    def test_typed_source_exact_schema_canonicalization_and_prior_publication(self):
        from .recorded_semantic import JCS_ID
        for mutation, message in (("schema", "schema/family"), ("canonicalization", "canonicalization"), ("future", "precede"),
                ("subject", "subject differs"), ("reporter", "reporter")):
            source = SyntheticTypedSource()
            event = loads(source.event.payload)
            report_hash = event["report"]["recordHash"]
            record = source.records[report_hash]
            if mutation == "schema": source.records[report_hash] = replace(record, selector=replace(record.selector, record_type=H("ff")))
            elif mutation == "canonicalization": source.canonicalizations[report_hash] = H("ff")
            elif mutation == "future": source.positions[report_hash] = (4, 0, 0)
            else:
                key = "subject_id" if mutation == "subject" else "recorder"
                value = H("ff") if mutation == "subject" else "0x" + "ff" * 20
                revised = replace(record, selector=replace(record.selector, **{key: value}))
                source.records[report_hash] = revised
                event["report"] = _selector(revised, "")
                source.event = source.add(EVENT_NAME, event, 3); source.selector = _selector(source.event, "")
            with self.subTest(mutation=mutation), self.assertRaises(MuseumError): source.rows()

    def test_hash_time_agent_and_whole_record_substitution_reject(self):
        for path, value in ((["event", "eventHash"], H("ff")), (["agent", "agentHash"], H("ff")),
                (["check", "checkedAt"], "1700000001"), (["agent", "agentId"], H("ff")),
                (["event", "eventURI"], "ipfs://other"), (["report", "pointer"], "/detail")):
            source = SyntheticTypedSource(); body = loads(source.event.payload)
            body[path[0]][path[1]] = value
            source.event = source.add(EVENT_NAME, body, 3); source.selector = _selector(source.event, "")
            with self.subTest(path=path), self.assertRaises(MuseumError): source.rows()
        source = SyntheticTypedSource()
        with self.assertRaisesRegex(MuseumError, "duplicate event"):
            _admit(source, [source.selector, source.selector])

    def test_repeated_checks_append_two_events_and_share_exact_agent(self):
        source = SyntheticTypedSource()
        second_id = H("e2")
        first = loads(source.event.payload)
        report = loads(source.record(first["report"]).payload)
        report.update(eventId=second_id, checkedAt="1700000001", observedDigest="0x" + sha256(b"bad").hexdigest(), outcome=FAILED)
        retained = source.add(REPORT_NAME, report, 4)
        second = copy.deepcopy(first)
        second["event"].update(eventId=second_id, eventTime=report["checkedAt"], eventHash=retained.payload_hash, outcome=FAILED)
        second["check"].update(checkedAt=report["checkedAt"], digest=report["observedDigest"], reportHash=retained.payload_hash, outcome=FAILED)
        second["report"] = _selector(retained, "")
        event = source.add(EVENT_NAME, second, 5)
        rows = _admit(source, [source.selector, _selector(event, "")])
        xml, issues, _, _ = _render(base_xml(), rows, {EVENT: b"abc", second_id: b"bad"}, self.schema)
        self.assertEqual(issues, [])
        root = self.schema.validate(xml)
        self.assertEqual(len(root.findall("{" + NS + "}event")), 2)
        self.assertEqual(len(root.findall("{" + NS + "}agent")), 1)
        rows[1]["description"]["name"] = "Conflicting claimed agent"
        with self.assertRaisesRegex(MuseumError, "conflicting selected agent"):
            _render(base_xml(), rows, {EVENT: b"abc", second_id: b"bad"}, self.schema)

    def test_existing_file_bytes_and_target_ids_are_not_collapsed(self):
        source = SyntheticTypedSource()
        self.schema.validate(base_xml())
        rows = source.rows()
        xml, issues, _, _ = _render(base_xml().replace(FILE.encode(), b"urn:other:file"), rows,
            {EVENT: b"abc"}, self.schema)
        self.assertIsNone(xml)
        self.assertIn({"eventId": EVENT, "reasonCode": "selected_file_projection_unavailable"}, issues)
        # A returned recorded agent address is not the reporting account and its
        # agentId remains separate even when the two addresses happen to match.
        rows = source.rows(); rows[0]["value"]["agent"]["account"] = ACCOUNT
        xml, issues, correspondence, _ = _render(base_xml(), rows, {EVENT: b"abc"}, self.schema)
        self.assertFalse(issues)
        self.assertNotEqual(correspondence[0]["agentIdentifier"], ACCOUNT)

    def test_xml_incompatible_agent_text_rejects_without_silent_normalization(self):
        source = SyntheticTypedSource(change=lambda a, r: a.update(name="tool\u0000name"))
        with self.assertRaisesRegex(MuseumError, "without changing source bytes"):
            _render(base_xml(), source.rows(), {EVENT: b"abc"}, self.schema)
        source = SyntheticTypedSource(change=lambda a, r: a.update(name="tool <&> e\u0301"))
        xml, issues, _, _ = _render(base_xml(), source.rows(), {EVENT: b"abc"}, self.schema)
        self.assertFalse(issues)
        self.assertEqual(self.schema.validate(xml).findtext("{" + NS + "}agent/{" + NS + "}agentName"), "tool <&> e\u0301")

    def test_typed_schema_rejects_unknown_fields_widths_and_unperformed_claim(self):
        for key, value in (("checkedAt", str(1 << 64)), ("observedByteSize", "03"), ("performed", False), ("extra", "invented")):
            with self.subTest(key=key), self.assertRaises(MuseumError):
                SyntheticTypedSource(change=lambda a, r: r.update({key: value})).rows()

    def test_actual_retained_capture_has_precise_missing_evidence_no_event_promotion(self):
        result = self.actual()
        self.assertIsNone(result.xml)
        report = loads(result.report, maximum=67108864)
        self.assertEqual(report["status"], "unsupported")
        self.assertIn({"reasonCode": "no_selected_performed_check_events"}, report["issues"])
        self.assertEqual(report["issues"][0]["reasonCode"], "file_profile_unsupported")
        self.assertFalse(any(report["claims"].values()))
        self.assertEqual(report["sourceEvidence"]["sourceCaptureHash"], keccak256(self.source.capture_bytes))
        with self.assertRaisesRegex(MuseumError, "verified recorded"):
            self.actual(source=SyntheticTypedSource())
        selected = _selector(self.source.state.records[0], "")
        with self.assertRaisesRegex(MuseumError, "schema/family"):
            self.actual(self.plan_for(events=[selected]))

    def test_actual_plan_scope_and_restricted_or_unselected_inputs_reject(self):
        for change in ({"version": "2"}, {"fixityProfileHash": OLD_HASH}, {"sourceStateHash": OLD_HASH},
                       {"premisPlanHash": OLD_HASH}, {"events": "all"}):
            with self.subTest(change=change), self.assertRaises(MuseumError): self.actual(self.plan_for(**change))
        with self.assertRaisesRegex(MuseumError, "hash mismatch"): self.actual(fixity_profile_hash=OLD_HASH)
        with self.assertRaisesRegex(MuseumError, "observation bound/type"): self.actual(observations={EVENT: "abc"})

    def test_offline_derivative_retains_original_bytes_and_reconstructs_without_network(self):
        original = build_recorded_package(inputs(), root=ROOT, disclosure="public", **pins(),
            premis_plan_bytes=self.file_plan, premis_plan_hash=keccak256(self.file_plan), premis_profile_hash=FILE_HASH)
        raw = dumps(self.plan_for())
        with tempfile.TemporaryDirectory() as temp:
            source = Path(temp) / "source"; write_package(original, source)
            result = build_fixity_package(source, original.manifest_hash, raw, plan_hash=keccak256(raw),
                profile_hash=PROFILE_HASH, observations={}, disclosure="public")
            files = dict(result.files)
            for name, payload in original.files: self.assertEqual(files["source/" + name], payload)
            self.assertEqual(files["source/manifest.json"], original.manifest)
            self.assertNotIn("premis-fixity/premis.xml", files)
            target = Path(temp) / "derivative"; write_package(result, target)
            with patch("socket.socket", side_effect=AssertionError("network")):
                self.assertEqual(verify_package(target, result.manifest_hash), result)
            tampered = changed(result, "premis-fixity/report.json", b"{}")
            other = Path(temp) / "tampered"; write_package(tampered, other)
            with self.assertRaisesRegex(MuseumError, "semantic reconstruction"):
                verify_fixity_package(other, tampered.manifest_hash)
            with self.assertRaises(MuseumError):
                build_fixity_package(target, result.manifest_hash, raw, plan_hash=keccak256(raw),
                    profile_hash=PROFILE_HASH, observations={}, disclosure="public")
            plan_path = Path(temp) / "fixity-plan.json"; plan_path.write_bytes(raw)
            cli = Path(temp) / "cli"
            command = [sys.executable, "-B", "-m", "tools.museum.fixity_package", "build", str(source),
                str(plan_path), str(cli), "--source-manifest-hash", original.manifest_hash, "--plan-hash", keccak256(raw),
                "--profile-hash", PROFILE_HASH, "--disclosure", "public"]
            run = subprocess.run(command, capture_output=True, text=True, timeout=60)
            self.assertEqual(run.returncode, 0, run.stderr)
            self.assertEqual((cli / "manifest.json").read_bytes(), result.manifest)
            self.assertEqual(run.stdout.strip(), result.manifest_hash)
            run = subprocess.run([sys.executable, "-B", "-m", "tools.museum.package_v2", "verify", str(cli),
                "--manifest-hash", result.manifest_hash], capture_output=True, text=True, timeout=60)
            self.assertEqual(run.returncode, 0, run.stderr)
            with self.assertRaisesRegex(MuseumError, "public classification"):
                build_fixity_package(source, original.manifest_hash, raw, plan_hash=keccak256(raw),
                    profile_hash=PROFILE_HASH, observations={}, disclosure="restricted")

    def test_profile_schema_bytes_retained_and_original_profile_unchanged(self):
        from .independent_wire import RECORD_TYPES
        self.assertTrue(set(FAMILIES.values()).issubset(RECORD_TYPES))
        folder = ROOT / "premis-fixity"
        self.assertEqual((folder / "profile.json").read_bytes(), PROFILE_BYTES)
        for name, raw in SCHEMAS.items(): self.assertEqual((folder / (name + ".json")).read_bytes(), raw)
        self.assertEqual((ROOT / "premis/profile.json").read_bytes(), OLD_BYTES)


if __name__ == "__main__": unittest.main()

"""Pure synthetic crosswalk controls plus actual-source unsupported package replay.

Positive controls are not recorded captures. The public package path always
replays a recorded preservation package before calling the pure renderer.
"""
import copy
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

from .canonical import MuseumError, dumps, keccak256, loads
from .premis import NS, PinnedPremis, PROFILE_BYTES as PREMIS_BYTES, PROFILE_HASH as PREMIS_HASH
from .preservation_events import render as premis_render
from .preservation_graph import render, validator, PROFILE_HASH, PROFILE_BYTES, CLAIMS
from .preservation_graph_package import build_graph_package, verify_graph_package
from .test_preservation_events import GenericControl, GENERAL, two_files
from .test_recorded_fixity import base_xml, EVENT
from .test_recorded_account import ROOT
from .package import write_package
from .package_v2 import verify_package


class PreservationGraph(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.model = validator(ROOT)
        cls.premis = PinnedPremis(ROOT, PREMIS_BYTES, profile_hash=PREMIS_HASH)

    def source(self, *, status="completed", kind="MIGRATION", agent_type="software", fixed=False, multi=False):
        control = GenericControl(kind, status=status, multi=multi)
        rows = control.generic_rows()
        # Typed serializer controls only: changing this local description is not
        # an admission or actual source-authority test.
        rows[0]["agents"][0][1]["type"] = agent_type
        if agent_type != "software": rows[0]["agents"][0][1]["agentVersion"] = ""
        if fixed:
            from .recorded_fixity import _admit
            fixes = _admit(control, [control.fixity_selector])
        else: fixes = []
        xml, issues, dispositions, _, provenance = premis_render(two_files() if multi else base_xml(), rows, fixes,
            {EVENT: b"abc"} if fixed else {}, self.premis)
        self.assertFalse(issues)
        report = dumps({"status": "supported", "xmlHash": keccak256(xml), "eventDispositions": dispositions})
        return xml, report, dumps(provenance)

    def resources(self, files):
        return [loads(raw) for name, raw in files.items() if name.startswith("graph/resources/")]

    def test_completed_activity_expands_with_exact_time_type_and_premis_document(self):
        xml, report, evidence = self.source()
        with patch("socket.socket", side_effect=AssertionError("no network")):
            files = render(xml, report, evidence, self.model)
        resources = self.resources(files)
        event = next(r for r in resources if r["type"] == "Activity")
        self.assertEqual(event["id"], "urn:6529stream:preservation:event:" + GENERAL)
        self.assertEqual(event["timespan"], {"type": "TimeSpan", "begin_of_the_begin": "2023-11-14T22:13:20Z", "end_of_the_end": "2023-11-14T22:13:20Z"})
        self.assertEqual(event["classified_as"][0]["_label"], "migration")
        document = next(r for r in resources if r["type"] == "DigitalObject")
        self.assertNotIn("subject_of", event)  # Structured XML is not forced into linguistic content.
        index = loads(files["graph/index.json"])
        self.assertEqual(index["premisReferences"][0]["premisDocument"], document["id"])
        self.assertEqual(index["premisReferences"][-1]["contentHash"], keccak256(xml))
        self.assertEqual(index["premisReferences"][-1]["path"], "source/premis-preservation/premis.xml")
        provenance = loads(files["graph/provenance.json"], maximum=67108864)
        self.assertTrue(all(p["sourceSelectors"] and p["premisPath"] and p["rule"] for p in provenance))
        expanded = next(loads(raw)[0] for path, raw in files.items() if path.startswith("graph/expanded/") and loads(raw)[0]["@id"] == event["id"])
        self.assertEqual(expanded["@type"], ["http://www.cidoc-crm.org/cidoc-crm/E7_Activity"])
        self.assertFalse(any(loads(files["graph/report.json"])["claims"].values()))

    def test_person_and_organization_names_remain_separate_from_software_and_roles(self):
        for source_type, target in (("person", "Person"), ("organization", "Group")):
            with self.subTest(source_type=source_type):
                files = render(*self.source(agent_type=source_type), self.model)
                agent = next(r for r in self.resources(files) if r["type"] == target)
                self.assertEqual(agent["identified_by"][0]["content"], "Declared test tool")
                self.assertTrue(loads(files["graph/sidecar.json"])["unmappedRelations"])
                self.assertNotIn(b"carried_out_by", b"".join(files.values()))
        files = render(*self.source(), self.model)
        self.assertEqual({r["type"] for r in self.resources(files)}, {"Activity", "DigitalObject", "Type"})
        sidecar = loads(files["graph/sidecar.json"])
        self.assertEqual(sidecar["streamOnlyAgents"][0]["type"], "software")
        self.assertNotIn(b"used_specific_object", b"".join(files.values()))

    def test_noncompleted_reports_never_create_activity_or_promote_their_agents(self):
        for status in ("planned", "cancelled", "unknown"):
            files = render(*self.source(status=status, agent_type="person"), self.model)
            self.assertEqual({r["type"] for r in self.resources(files)}, {"DigitalObject"})
            self.assertEqual(loads(files["graph/sidecar.json"])["eventDispositions"][0]["sourceStatus"], status)
            self.assertEqual(loads(files["graph/report.json"])["events"], "0")

    def test_fixity_and_multi_object_roles_keep_original_source_correspondence(self):
        files = render(*self.source(fixed=True, multi=True), self.model)
        self.assertEqual(sum(r["type"] == "Activity" for r in self.resources(files)), 2)
        sidecar = loads(files["graph/sidecar.json"])
        self.assertEqual(len(sidecar["sourceEvidence"]), 2)
        self.assertEqual(max(len(r["objects"]) for r in sidecar["unmappedRelations"]), 2)
        self.assertTrue(all(r["disposition"] == "retained_stream_only" for r in sidecar["unmappedRelations"]))

    def test_changed_missing_duplicate_and_noncompleted_event_correspondence_reject(self):
        xml, raw, evidence = self.source()
        with self.assertRaisesRegex(MuseumError, "hash differs"):
            render(xml + b" ", raw, evidence, self.model)
        report = loads(raw); report["eventDispositions"] = []
        with self.assertRaisesRegex(MuseumError, "correspondence differs"):
            render(xml, dumps(report), evidence, self.model)
        report = loads(raw); report["eventDispositions"][0]["sourceStatus"] = "planned"
        with self.assertRaisesRegex(MuseumError, "noncompleted"):
            render(xml, dumps(report), evidence, self.model)
        with self.assertRaisesRegex(MuseumError, "duplicate event evidence"):
            rows = loads(evidence); render(xml, raw, dumps(rows + rows), self.model)

    def test_profile_and_all_graph_references_are_retained_and_exact(self):
        self.assertEqual((ROOT / "preservation-graph/profile.json").read_bytes(), PROFILE_BYTES)
        self.assertEqual(keccak256(PROFILE_BYTES), PROFILE_HASH)
        files = render(*self.source(multi=True), self.model)
        index = loads(files["graph/index.json"])
        indexed = {r["id"] for r in index["resources"]} | {r["id"] for r in index["premisReferences"]}
        for resource in self.resources(files):
            for item in resource.get("classified_as", []): self.assertIn(item["id"], indexed)
        for relation in loads(files["graph/sidecar.json"])["unmappedRelations"]:
            for row in relation["objects"] + relation["agents"]: self.assertIn(row["id"], indexed)

    def test_source_unsupported_stays_exact_without_placeholder_graph(self):
        report = dumps({"status": "unsupported", "eventDispositions": []})
        files = render(None, report, dumps([]), self.model)
        self.assertEqual(loads(files["graph/report.json"])["reasonCode"], "source_premis_projection_unavailable")
        self.assertFalse(self.resources(files))

    def test_versioned_package_retains_actual_source_and_rebuilds_offline(self):
        from .test_preservation_events import PreservationEvents
        from .test_package_recorded import inputs, pins
        from .package_recorded import build_recorded_package
        from .preservation_package import build_preservation_package
        from .preservation_events import PROFILE_HASH as OLD_HASH
        from .recorded_premis import PROFILE_HASH as FILE_HASH
        from .test_package import changed
        PreservationEvents.setUpClass()
        original = build_recorded_package(inputs(), root=ROOT, disclosure="public", **pins(),
            premis_plan_bytes=PreservationEvents.file_plan, premis_plan_hash=keccak256(PreservationEvents.file_plan), premis_profile_hash=FILE_HASH)
        plan = dumps(PreservationEvents().plan_for())
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            write_package(original, root / "original")
            prior = build_preservation_package(root / "original", original.manifest_hash, plan,
                plan_hash=keccak256(plan), profile_hash=OLD_HASH, observations={}, disclosure="public")
            write_package(prior, root / "prior")
            result = build_graph_package(root / "prior", prior.manifest_hash, profile_hash=PROFILE_HASH, disclosure="public")
            self.assertEqual(dict(result.files)["source/manifest.json"], prior.manifest)
            for name, raw in prior.files: self.assertEqual(dict(result.files)["source/" + name], raw)
            write_package(result, root / "graph")
            with patch("socket.socket", side_effect=AssertionError("no network")):
                self.assertEqual(verify_package(root / "graph", result.manifest_hash), result)
            altered = changed(result, "graph/report.json", dumps({"claims": {"historicalPerformanceProven": True}}))
            write_package(altered, root / "altered")
            with self.assertRaisesRegex(MuseumError, "semantic reconstruction"):
                verify_graph_package(root / "altered", altered.manifest_hash)
            with self.assertRaisesRegex(MuseumError, "public classification"):
                build_graph_package(root / "prior", prior.manifest_hash, profile_hash=PROFILE_HASH, disclosure="restricted")
            with self.assertRaisesRegex(MuseumError, "profile hash"):
                build_graph_package(root / "prior", prior.manifest_hash, profile_hash="0x" + "00" * 32, disclosure="public")


if __name__ == "__main__": unittest.main()

"""Actual recorded missing-evidence checks; complete media controls are explicitly synthetic."""
import copy
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch

from .canonical import MuseumError, dumps, keccak256, loads
from .iiif import _project_selected_presentation, project_iiif_fixture, FIELDS
from .iiif_model import PinnedIIIF, PROFILE_BYTES as OLD_BYTES, PROFILE_HASH as OLD_HASH, SOURCE
from .iiif_numbers import target_loads
from .recorded_iiif import MODE, PROFILE_BYTES, PROFILE_HASH, _availability, project_recorded_iiif
from .premis import project_premis_fixture
from .semantic_selection import select_canonical_fixture
from .package import write_package
from .package_recorded import build_recorded_package
from .package_v2 import verify_package
from . import test_recorded_premis as premis_tests
PREMIS_EXAMPLES = premis_tests.EXAMPLES
from .test_recorded_account import ROOT, FIXTURE
from .test_package_recorded import inputs, pins
from .test_package import changed
from .test_iiif import source_data, source_document, arguments, updated

EXAMPLES = ROOT / "iiif-recorded"


class RecordedIIIF(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        premis_tests.RecordedPremis.setUpClass()
        cls.base = premis_tests.RecordedPremis()
        cls.schema = PinnedIIIF(ROOT, OLD_BYTES, profile_hash=OLD_HASH)
        cls.premis_plan = (PREMIS_EXAMPLES / "missing-file-plan.json").read_bytes()

    def plan_for(self, **updates):
        return {"mode": MODE, "version": "1", "sourceStateHash": self.base.source.state.commitment,
            "profileHash": self.base.source.profile_hash, "linkedArtPlanHash": keccak256(self.base.plan),
            "premisPlanHash": keccak256(self.premis_plan), "iiifProfileHash": PROFILE_HASH,
            "work": "urn:local:semantic:work", "manifestId": "https://example.org/iiif/recorded/manifest",
            "canvases": [{"file": "urn:local:semantic:file", "canvasId": "https://example.org/iiif/recorded/canvas",
                "pageId": "https://example.org/iiif/recorded/page", "annotationId": "https://example.org/iiif/recorded/annotation"}]} | updates

    def kwargs(self):
        from .recorded_premis import PROFILE_HASH as PH
        return dict(selection_hash=keccak256(self.base.selection), plan_hash=keccak256(self.base.plan),
            premis_plan_hash=keccak256(self.premis_plan), premis_profile_hash=PH, premis_schema=self.base.schema,
            iiif_profile_hash=PROFILE_HASH, iiif_schema=self.schema)

    def project(self, plan=None, **updates):
        raw = dumps(self.plan_for() if plan is None else plan)
        return project_recorded_iiif(self.base.source, self.base.selection, self.base.plan, self.premis_plan, raw,
            **(self.kwargs() | {"iiif_plan_hash": keccak256(raw)} | updates))

    def test_actual_recorded_capture_has_precise_unsupported_result_and_original_evidence(self):
        with patch("socket.socket", side_effect=AssertionError("network")):
            result = self.project()
        self.assertIsNone(result.projection)
        self.assertIsNone(result.premis.projection)
        report = loads(result.report)
        self.assertEqual(report["status"], "unsupported")
        self.assertEqual(report["reasonCode"], "incomplete_selected_presentation_evidence")
        self.assertEqual(report["issues"][0]["reasonCode"], "recorded_premis_unavailable")
        missing = [r for r in report["issues"] if r["reasonCode"] == "missing_selected_presentation_fact"]
        self.assertEqual(len(missing), 9)
        self.assertEqual({r["entity"] for r in missing}, {"urn:local:semantic:work", "urn:local:semantic:file"})
        self.assertEqual(report["sourceEvidence"]["environment"], "local_evm_fixture")
        self.assertEqual(self.base.source.capture_bytes, (FIXTURE / "source-capture.json").read_bytes())
        self.assertFalse(any(report["claims"].values()))

    def test_exact_mode_scope_and_profile_are_required(self):
        for update in ({"mode": "synthetic_iiif_projection"}, {"version": "2"},
            {"sourceStateHash": OLD_HASH}, {"profileHash": OLD_HASH}, {"linkedArtPlanHash": OLD_HASH},
            {"premisPlanHash": OLD_HASH}, {"iiifProfileHash": OLD_HASH}):
            with self.subTest(update=update), self.assertRaisesRegex(MuseumError, "scope mismatch"):
                self.project(self.plan_for(**update))
        with self.assertRaisesRegex(MuseumError, "hash mismatch"):
            self.project(iiif_profile_hash=OLD_HASH)
        with self.assertRaisesRegex(MuseumError, "hash mismatch"):
            self.project(iiif_plan_hash=OLD_HASH)
        with self.assertRaisesRegex(MuseumError, "verified recorded"):
            project_recorded_iiif(source_data()[0], self.base.selection, self.base.plan, self.premis_plan,
                dumps(self.plan_for()), **self.kwargs(), iiif_plan_hash=keccak256(dumps(self.plan_for())))

    def test_layout_cannot_change_file_selection_or_alias_source_and_structural_ids(self):
        canvas = self.plan_for()["canvases"][0]
        for update in ({"canvases": []}, {"canvases": [canvas,canvas]},
            {"canvases": [canvas | {"file": "urn:unknown"}]},
            {"manifestId": canvas["canvasId"]}, {"manifestId": "javascript:bad"}):
            with self.subTest(update=update), self.assertRaises(MuseumError):
                self.project(self.plan_for(**update))
        report = loads(self.project(self.plan_for(work="urn:local:semantic:text")).report)
        self.assertIn({"reasonCode": "selected_resource_missing", "entity": "urn:local:semantic:text",
                       "requiredType": "PropositionalObject"}, report["issues"])

    def synthetic(self, data=None):
        # Exercise shared logic with named synthetic controls, never a fabricated RecordedSemanticSource.
        data = source_data() if data is None else data
        args, kwargs = arguments(data, self.base.linked, self.base.schema, self.schema)
        pk = {k:v for k,v in kwargs.items() if k not in ("iiif_plan_hash", "iiif_profile")}
        premis = project_premis_fixture(*args[:4], **pk)
        selection = select_canonical_fixture(data[0], args[1], policy_hash=pk["selection_hash"], profile_hash=pk["profile_hash"])
        return data, args, kwargs, premis, selection

    def test_complete_synthetic_renderer_control_preserves_fields_and_selected_provenance(self):
        data,args,kwargs,premis,selected = self.synthetic()
        self.assertEqual(_availability(premis.linked_art, selected, data[1], loads(args[4])), [])
        old = project_iiif_fixture(*args, **kwargs)
        plan = loads(args[4]) | {"mode": MODE, "iiifProfileHash": PROFILE_HASH}
        raw = dumps(plan)
        new = _project_selected_presentation(data[0], premis, selected, args[1], args[3], raw,
            **(kwargs | {"iiif_plan_hash": keccak256(raw)}), mode=MODE,
            source_mode="synthetic_renderer_control", export_profile_hash=PROFILE_HASH)
        actual, expected = target_loads(new.manifest), target_loads(old.manifest)
        self.assertEqual(actual[SOURCE]["@value"]["mode"], "synthetic_renderer_control")
        actual[SOURCE] = expected[SOURCE]
        for a,b in zip(actual["items"], expected["items"]):
            ab = a["items"][0]["items"][0]["body"]
            bb = b["items"][0]["items"][0]["body"]
            self.assertEqual(ab[SOURCE]["@value"]["mode"], "synthetic_renderer_control")
            ab[SOURCE] = bb[SOURCE]
        self.assertEqual(actual, expected)
        self.assertEqual(new.provenance, old.provenance)
        self.assertEqual(new.premis.xml, old.premis.xml)
        self.assertEqual(loads(new.report)["iiifProfileHash"], PROFILE_HASH)

    def test_missing_dimensions_report_exact_selected_relation_and_no_iri_fallback(self):
        data,args,_,premis,selected = self.synthetic(updated(source_data(), "photo", "height", remove=True))
        issues = _availability(premis.linked_art, selected, data[1], loads(args[4]))
        self.assertEqual(issues, [{"reasonCode": "missing_selected_presentation_fact", "entity": "urn:fixture:photo",
                                  "field": "height", "relation": FIELDS["height"]}])

    def test_conflicts_apply_only_to_fields_that_this_role_consumes(self):
        doc = source_document(source_data())
        original = next(a for a in doc["assertions"] if a["subject"] == "urn:fixture:work" and a["relation"] == FIELDS["manifest-rights"])
        a,b = copy.deepcopy(original),copy.deepcopy(original)
        a.update(id="urn:fixture:unconsumed-rights-a",relation=FIELDS["rights"])
        b.update(id="urn:fixture:unconsumed-rights-b",relation=FIELDS["rights"])
        b["object"]["literal"]["lexicalValue"] = "http://rightsstatements.org/vocab/InC/1.0/"
        doc["assertions"] += [a,b]
        data,args,_,premis,selected = self.synthetic(source_data(doc["assertions"],doc["entities"]))
        self.assertTrue(selected.withheld)
        self.assertEqual(_availability(premis.linked_art,selected,data[1],loads(args[4])),[])
        conflict = copy.deepcopy(original);conflict["id"] += "-conflict"
        conflict["object"]["literal"]["lexicalValue"] = "http://rightsstatements.org/vocab/InC/1.0/"
        doc["assertions"].append(conflict)
        data,args,_,premis,selected = self.synthetic(source_data(doc["assertions"],doc["entities"]))
        with self.assertRaisesRegex(MuseumError,"conflicting selected facts"):
            _availability(premis.linked_art,selected,data[1],loads(args[4]))

    def package(self, **updates):
        from .recorded_premis import PROFILE_HASH as PH
        raw = dumps(self.plan_for())
        return build_recorded_package(inputs(), root=ROOT, disclosure="public", **pins(),
            **(dict(premis_plan_bytes=self.premis_plan, premis_plan_hash=keccak256(self.premis_plan), premis_profile_hash=PH,
                iiif_plan_bytes=raw, iiif_plan_hash=keccak256(raw), iiif_profile_hash=PROFILE_HASH) | updates))

    def test_offline_package_retains_capture_and_cannot_rehash_report_or_promote_manifest(self):
        package = self.package(); files = dict(package.files)
        self.assertNotIn("iiif/manifest.json", files)
        self.assertNotIn("premis/premis.xml", files)
        self.assertEqual(files["inputs/source-capture.json"], self.base.source.capture_bytes)
        self.assertEqual(files["definitions/recorded-iiif-profile.json"], PROFILE_BYTES)
        self.assertEqual(loads(package.manifest, maximum=2097152)["mode"], "recorded_account_iiif_resource_package")
        with tempfile.TemporaryDirectory() as temp:
            folder=Path(temp)/"package";write_package(package,folder)
            with patch("socket.socket", side_effect=AssertionError("network")):
                self.assertEqual(verify_package(folder,package.manifest_hash),package)
            altered=changed(package,"iiif/report.json",b"{}")
            folder=Path(temp)/"tampered";write_package(altered,folder)
            with self.assertRaisesRegex(MuseumError,"semantic reconstruction"):
                verify_package(folder,altered.manifest_hash)

    def test_package_opt_in_requires_both_pins_and_recorded_premis(self):
        for update in ({"iiif_plan_hash": None}, {"iiif_profile_hash": None}, {"premis_plan_bytes": None}):
            with self.subTest(update=update), self.assertRaises(MuseumError): self.package(**update)
        with self.assertRaisesRegex(MuseumError,"hash mismatch"): self.package(iiif_profile_hash=OLD_HASH)

    def test_retained_profiles_and_actual_cli(self):
        self.assertEqual((EXAMPLES/"profile.json").read_bytes(),PROFILE_BYTES)
        raw=(EXAMPLES/"missing-presentation-plan.json").read_bytes()
        self.assertEqual(raw,dumps(self.plan_for()))
        ip=loads((EXAMPLES/"pins.json").read_bytes());pp=loads((PREMIS_EXAMPLES/"pins.json").read_bytes())
        self.assertEqual(ip,{"iiif_plan":keccak256(raw),"iiif_profile":PROFILE_HASH})
        with tempfile.TemporaryDirectory() as temp:
            folder=Path(temp)/"package"
            command=[sys.executable,"-B","-m","tools.museum.package_v2","build-recorded",str(FIXTURE),str(folder),
                "--dependency-root",str(ROOT),"--disclosure","public","--premis-plan",str(PREMIS_EXAMPLES/"missing-file-plan.json"),
                "--iiif-plan",str(EXAMPLES/"missing-presentation-plan.json")]
            for key,value in (pins() | {k+"_hash":v for k,v in pp.items()} | {k+"_hash":v for k,v in ip.items()}).items():
                command += ["--"+key.replace("_","-"),value]
            result=subprocess.run(command,capture_output=True,text=True,timeout=60)
            self.assertEqual(result.returncode,0,result.stderr)
            self.assertEqual((folder/"iiif/report.json").read_bytes(),self.project().report)
            digest=keccak256((folder/"manifest.json").read_bytes())
            result=subprocess.run([sys.executable,"-B","-m","tools.museum.package_v2","verify",str(folder),
                "--manifest-hash",digest],capture_output=True,text=True,timeout=60)
            self.assertEqual(result.returncode,0,result.stderr)


if __name__ == "__main__": unittest.main()

"""Recorded admission with honest missing facts; positive rendering controls stay synthetic."""
import copy
from dataclasses import replace
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch

from .canonical import MuseumError, dumps, keccak256, loads
from .premis import FIELDS, PinnedPremis, PROFILE_BYTES as OLD_BYTES, PROFILE_HASH as OLD_HASH, project_premis_fixture
from .recorded_premis import MODE, PROFILE_BYTES, PROFILE_HASH, _availability, project_recorded_premis
from .projection import project_fixture
from .projection_v2 import ProjectionProfileV2, CROSSWALK_V2_BYTES, CROSSWALK_V2_HASH
from .semantic_selection import select_canonical_fixture
from .package import write_package
from .package_recorded import build_recorded_package
from .package_v2 import verify_package
from .test_package import changed
from .test_package_recorded import inputs, pins
from .test_recorded_account import ROOT, FIXTURE, load_source
from .test_premis import data_for, facts, arguments

EXAMPLES = ROOT / "premis-recorded"
FILE = "urn:local:semantic:file"


class RecordedPremis(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.source = load_source()
        cls.selection, cls.plan = ((FIXTURE / name).read_bytes() for name in ("selection.json", "plan.json"))
        cls.schema = PinnedPremis(ROOT, OLD_BYTES, profile_hash=OLD_HASH)
        cls.linked = ProjectionProfileV2(ROOT, CROSSWALK_V2_BYTES, crosswalk_hash=CROSSWALK_V2_HASH,
            validation_hash=keccak256((ROOT / "linked-art-v2/validation-policy.json").read_bytes()),
            vocabulary_hash=keccak256((ROOT / "standards/vocabulary-policy.json").read_bytes()))

    def plan_for(self, **updates):
        return {"mode": MODE, "version": "1", "sourceStateHash": self.source.state.commitment,
                "profileHash": self.source.profile_hash, "linkedArtPlanHash": keccak256(self.plan),
                "premisProfileHash": PROFILE_HASH, "objects": [FILE]} | updates

    def project(self, plan=None, **updates):
        raw = dumps(self.plan_for() if plan is None else plan)
        kwargs = dict(selection_hash=keccak256(self.selection), plan_hash=keccak256(self.plan),
            premis_plan_hash=keccak256(raw), premis_profile_hash=PROFILE_HASH, premis_schema=self.schema) | updates
        return project_recorded_premis(self.source, self.selection, self.plan, raw, **kwargs)

    def fixture_selection(self, claims=None):
        # These are explicitly synthetic authority controls, never evidence of an actual recorded positive export.
        data = data_for(claims)
        args, kwargs = arguments(data, self.linked, self.schema)
        projected = project_fixture(*args[:3], selection_hash=kwargs["selection_hash"], plan_hash=kwargs["plan_hash"],
                                   profile_hash=kwargs["profile_hash"], profile=self.linked)
        selected = select_canonical_fixture(data[0], args[1], policy_hash=kwargs["selection_hash"], profile_hash=kwargs["profile_hash"])
        return data, args, kwargs, projected, selected

    def test_actual_recorded_source_returns_precise_missing_file_facts_without_xml(self):
        result = self.project()
        self.assertIsNone(result.projection)
        report = loads(result.report)
        self.assertEqual(report["status"], "unsupported")
        missing = [row for row in report["issues"] if row["reasonCode"] == "missing_selected_file_fact"]
        self.assertEqual({row["relation"] for row in missing}, set(FIELDS.values()))
        self.assertEqual({row["entity"] for row in missing}, {FILE})
        self.assertFalse(any(row["reasonCode"] == "selected_digital_object_missing" for row in report["issues"]))
        self.assertEqual(report["sourceEvidence"]["environment"], "local_evm_fixture")
        self.assertEqual(report["sourceEvidence"]["sourceCaptureHash"], keccak256(self.source.capture_bytes))
        self.assertFalse(any(report["claims"].values()))
        self.assertEqual(self.source.capture_bytes, (FIXTURE / "source-capture.json").read_bytes())

    def test_unknown_entity_and_empty_explicit_selection_are_precisely_unsupported(self):
        report = loads(self.project(self.plan_for(objects=[])).report)
        self.assertIn({"reasonCode": "no_selected_files"}, report["issues"])
        report = loads(self.project(self.plan_for(objects=["urn:unknown:file"])).report)
        self.assertIn({"entity": "urn:unknown:file", "reasonCode": "selected_digital_object_missing"}, report["issues"])

    def test_version_scope_profile_plan_and_fixture_promotion_reject(self):
        for update in ({"mode": "synthetic_premis_file_projection"}, {"version": "2"},
                       {"sourceStateHash": "0x" + "11" * 32}, {"profileHash": OLD_HASH},
                       {"linkedArtPlanHash": OLD_HASH}, {"premisProfileHash": OLD_HASH}, {"objects": [FILE,FILE]}):
            with self.subTest(update=update), self.assertRaises(MuseumError):
                self.project(self.plan_for(**update))
        with self.assertRaisesRegex(MuseumError, "hash mismatch"):
            self.project(premis_plan_hash=OLD_HASH)
        with self.assertRaisesRegex(MuseumError, "hash mismatch"):
            self.project(premis_profile_hash=OLD_HASH)
        with self.assertRaisesRegex(MuseumError, "verified recorded"):
            project_recorded_premis(data_for()[0], self.selection, self.plan, dumps(self.plan_for()),
                selection_hash=keccak256(self.selection), plan_hash=keccak256(self.plan),
                premis_plan_hash=keccak256(dumps(self.plan_for())), premis_profile_hash=PROFILE_HASH, premis_schema=self.schema)

    def test_complete_selected_fact_controls_render_exact_original_synthetic_xml(self):
        data, args, kwargs, projected, selected = self.fixture_selection()
        self.assertEqual(_availability(projected, selected, ["urn:fixture:master"], data[1]), [])
        result = project_premis_fixture(*args, **kwargs)
        self.assertIn(b"<premis:size>3</premis:size>", result.xml)
        self.assertEqual(loads(result.report)["mode"], "synthetic_premis_file_projection")
        self.assertEqual(loads(result.report)["premisProfileHash"], OLD_HASH)
        self.assertEqual({row["issuer"] for row in loads(result.provenance) if "issuer" in row}, {"urn:fixture:artist"})
        incomplete_policy = data[1] | {"singleValuedRelations": []}
        self.assertEqual(len(_availability(projected, selected, ["urn:fixture:master"], incomplete_policy)), 4)

    def test_present_malformed_or_qualified_facts_reject_even_when_other_facts_absent(self):
        cases = [facts(category="representation")[:-1], facts(size=str(1 << 63))[:-1],
                 facts(digest="FF" * 32)[:-1], facts(puid="fmt/0")[1:]]
        qualified = facts()[:-1]; qualified[1]["object"]["literal"]["unit"] = "bytes"; cases.append(qualified)
        for claims in cases:
            with self.subTest(claims=claims):
                data, _, _, projected, selected = self.fixture_selection(claims)
                with self.assertRaises(MuseumError):
                    _availability(projected, selected, ["urn:fixture:master"], data[1])

    def test_conflicting_selected_facts_reject_before_missing_diagnostic(self):
        extra = copy.deepcopy(facts(size="4")[1]); extra["id"] += "-conflict"
        data, _, _, projected, selected = self.fixture_selection(facts()[:-1] + [extra])
        self.assertTrue(selected.withheld)
        with self.assertRaisesRegex(MuseumError, "conflicting selected facts"):
            _availability(projected, selected, ["urn:fixture:master"], data[1])

    def extended(self):
        raw = dumps(self.plan_for())
        return build_recorded_package(inputs(), root=ROOT, disclosure="public", **pins(), premis_plan_bytes=raw,
            premis_plan_hash=keccak256(raw), premis_profile_hash=PROFILE_HASH)

    def test_recorded_package_preserves_originals_and_replays_unsupported_report_offline(self):
        package = self.extended(); files = dict(package.files)
        self.assertNotIn("premis/premis.xml", files)
        self.assertIn("premis/report.json", files)
        self.assertEqual(files["definitions/recorded-premis-profile.json"], PROFILE_BYTES)
        self.assertEqual(files["inputs/source-capture.json"], self.source.capture_bytes)
        support = loads(files["reports/format-support.json"])["formats"][1]
        self.assertEqual(support["reasonCode"], "incomplete_selected_file_evidence")
        with tempfile.TemporaryDirectory() as temp:
            folder = Path(temp) / "package"; write_package(package, folder)
            with patch("socket.socket", side_effect=AssertionError("network")):
                self.assertEqual(verify_package(folder, package.manifest_hash), package)
            altered = changed(package, "premis/report.json", b"{}")
            other = Path(temp) / "tampered"; write_package(altered, other)
            with self.assertRaisesRegex(MuseumError, "semantic reconstruction"):
                verify_package(other, altered.manifest_hash)

    def test_recorded_package_cannot_change_export_profile_or_add_partial_pins(self):
        with self.assertRaisesRegex(MuseumError, "plan and both pins"):
            build_recorded_package(inputs(), root=ROOT, disclosure="public", **pins(), premis_plan_bytes=dumps(self.plan_for()))
        with self.assertRaisesRegex(MuseumError, "hash mismatch"):
            build_recorded_package(inputs(), root=ROOT, disclosure="public", **pins(), premis_plan_bytes=dumps(self.plan_for()),
                premis_plan_hash=keccak256(dumps(self.plan_for())), premis_profile_hash=OLD_HASH)

    def test_retained_profile_and_real_cli_opt_in(self):
        self.assertEqual((EXAMPLES / "profile.json").read_bytes(), PROFILE_BYTES)
        raw = (EXAMPLES / "missing-file-plan.json").read_bytes()
        self.assertEqual(raw, dumps(self.plan_for()))
        pp = loads((EXAMPLES / "pins.json").read_bytes())
        self.assertEqual(pp, {"premis_plan": keccak256(raw), "premis_profile": PROFILE_HASH})
        with tempfile.TemporaryDirectory() as temp:
            folder = Path(temp) / "package"
            command = [sys.executable, "-B", "-m", "tools.museum.package_v2", "build-recorded", str(FIXTURE), str(folder),
                "--dependency-root", str(ROOT), "--disclosure", "public", "--premis-plan", str(EXAMPLES / "missing-file-plan.json"),
                "--premis-plan-hash", pp["premis_plan"], "--premis-profile-hash", pp["premis_profile"]]
            for key,value in pins().items(): command += ["--" + key.replace("_","-"), value]
            result = subprocess.run(command, capture_output=True, text=True, timeout=60)
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertEqual((folder / "premis/report.json").read_bytes(), self.project().report)
            manifest_hash = keccak256((folder / "manifest.json").read_bytes())
            result = subprocess.run([sys.executable, "-B", "-m", "tools.museum.package_v2", "verify", str(folder),
                "--manifest-hash", manifest_hash], capture_output=True, text=True, timeout=60)
            self.assertEqual(result.returncode, 0, result.stderr)


if __name__ == "__main__":
    unittest.main()

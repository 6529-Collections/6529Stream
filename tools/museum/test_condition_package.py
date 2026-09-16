"""Replay packaging of synthetic owner controls and retained actual-source negatives."""
import copy
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

from .canonical import MuseumError, dumps, keccak256, loads, schema_id
from .condition import PROFILE_HASH
from .condition_package import build_condition_package, verify_condition_package
from .package import write_package
from .package_recorded import build_recorded_package
from .package_v2 import verify_package
from .review import _selector
from .test_condition import ConditionOwnerFixture, H
from .test_package import changed
from .test_package_recorded import inputs, pins
from .test_recorded_account import ROOT, load_source


class ConditionPackageTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.recorded = load_source()
        cls.original = build_recorded_package(inputs(), root=ROOT, disclosure="public", **pins())

    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory(); self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        write_package(self.original, self.root / "original")
        self.fixture = ConditionOwnerFixture(anchor=self.recorded.anchor)
        self.owner, self.owner_inputs, _ = self.fixture.replay()
        self.owner_pins = {"anchorHash": keccak256(self.owner_inputs["anchor.json"]),
            "transcriptHash": keccak256(self.owner_inputs["transcript.json"]), "sourceHash": keccak256(self.owner.snapshot())}
        self.plan = {"version": "1", "sourceKind": "owner_records", "sourceHash": self.owner_pins["sourceHash"],
            "records": self.fixture.lanes[(41, schema_id("CONDITION_REPORT"))]}

    def build(self, **changes):
        raw = dumps(self.plan)
        args = dict(plan_hash=keccak256(raw), profile_hash=PROFILE_HASH, disclosure="public",
            owner_inputs=self.owner_inputs, owner_pins=self.owner_pins)
        args.update(changes)
        return build_condition_package(self.root / "original", self.original.manifest_hash, raw, **args)

    def test_offline_rebuild_retains_every_source_and_narrow_claim(self):
        with patch("socket.socket", side_effect=AssertionError("offline condition package opened network")):
            result = self.build(); write_package(result, self.root / "export")
            self.assertEqual(verify_package(self.root / "export", result.manifest_hash), result)
        files = dict(result.files)
        self.assertEqual(files["source/manifest.json"], self.original.manifest)
        for name, raw in self.original.files: self.assertEqual(files["source/" + name], raw)
        for name, raw in self.owner_inputs.items(): self.assertEqual(files["owner-records/" + name], raw)
        report = loads(files["condition/report.json"], maximum=524288)
        self.assertTrue(report["sourceReceiptEvidenceChecked"])
        self.assertEqual([k for k, v in report["claims"].items() if v], ["actualSourceAuthenticated"])
        self.assertEqual(len(loads(files["condition/dossiers.json"], maximum=524288)), 2)

    def test_rehashed_output_cannot_upgrade_examination_claims(self):
        result = self.build(); files = dict(result.files)
        report = loads(files["condition/report.json"], maximum=524288)
        report["claims"]["historicalExaminationProven"] = True
        altered = changed(result, "condition/report.json", dumps(report))
        write_package(altered, self.root / "altered")
        with self.assertRaisesRegex(MuseumError, "semantic reconstruction"):
            verify_condition_package(self.root / "altered", altered.manifest_hash)

    def test_external_pins_public_classification_and_selection_are_required(self):
        for changes in ({"plan_hash": H(91)}, {"profile_hash": H(91)}, {"disclosure": "restricted"},
                        {"owner_pins": dict(self.owner_pins, sourceHash=H(91))},
                        {"owner_inputs": dict(self.owner_inputs, **{"deployment-evidence.json": b"changed"})}):
            with self.subTest(changes=tuple(changes)), self.assertRaises(MuseumError): self.build(**changes)
        self.plan["records"] = []
        with self.assertRaisesRegex(MuseumError, "selection bound"): self.build()

    def test_valid_but_different_original_anchor_cannot_be_joined(self):
        anchor = dict(self.recorded.anchor, chainId="1")
        fixture = ConditionOwnerFixture(anchor=anchor)
        owner, owner_inputs, _ = fixture.replay()
        owner_pins = {"anchorHash": keccak256(owner_inputs["anchor.json"]),
            "transcriptHash": keccak256(owner_inputs["transcript.json"]), "sourceHash": keccak256(owner.snapshot())}
        self.plan.update(sourceHash=owner_pins["sourceHash"], records=fixture.lanes[(41, schema_id("CONDITION_REPORT"))])
        with self.assertRaisesRegex(MuseumError, "same original chain/Core/block"):
            self.build(owner_inputs=owner_inputs, owner_pins=owner_pins)

    def test_actual_retained_unrelated_independent_family_is_rejected(self):
        self.plan.update(sourceKind="independent_records", sourceHash=self.recorded.state.commitment,
            records=[_selector(self.recorded.state.records[0], "")])
        with self.assertRaisesRegex(MuseumError, "cannot retain owner inputs"): self.build()
        with self.assertRaisesRegex(MuseumError, "condition/treatment family differs"):
            self.build(owner_inputs=None, owner_pins=None)


if __name__ == "__main__": unittest.main()

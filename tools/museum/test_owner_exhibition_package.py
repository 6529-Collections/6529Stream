"""Retained recorded base plus explicitly synthetic owner exhibition wire inputs."""
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch

from .bagit import build_bag, read_tree, write_tree
from .canonical import MuseumError, dumps, hex_bytes, keccak256, loads
from .owner_exhibition_package import build_owner_exhibition_package, verify_owner_exhibition_package
from .owner_exhibitions import PROFILE_HASH
from .package import write_package
from .package_recorded import build_recorded_package
from .package_v2 import verify_package
from .repository_exchange import export_bag, import_version
from .test_bagit import description
from .test_owner_exhibitions import OwnerExhibitionFixture
from .test_package import changed
from .test_package_recorded import inputs, pins
from .test_recorded_account import ROOT, load_source


class JoinedFixture(OwnerExhibitionFixture):
    """Synthetic owner responses reuse every shared retained base request exactly.

    Reusing the original Core bytes/header makes the same-block join consistent;
    it does not turn this synthetic owner host into an actual deployment.
    """
    def __init__(self, anchor, originals, **kwargs):
        super().__init__(anchor=anchor, **kwargs)
        self.shared = {}
        for name in ("transcript.json", "publication-transcript.json", "interpretation-transcript.json"):
            for row in loads(originals[name], maximum=67108864, canonical=True)["calls"]:
                key = dumps([row["method"], row["params"]])
                if key in self.shared:
                    assert self.shared[key] == row["result"]
                self.shared[key] = row["result"]
                if row["method"] == "eth_getCode" and row["params"][0] in self.codes:
                    self.codes[row["params"][0]] = hex_bytes(row["result"])
        self._update_pins()

    def _update_pins(self):
        self.a["codePins"] = [{"address": row["address"], "runtimeHash": keccak256(self.codes[row["address"]])}
            for row in self.a["codePins"]]
        self.pins = {row["address"]: row["runtimeHash"] for row in self.a["codePins"]}
        for field, getter in (("core", "coreCodeHash()"), ("schemas", "schemaRegistryCodeHash()"),
                ("store", "chunkStoreCodeHash()")):
            self.add(self.a["host"], getter, (), (), ("bytes32",), (self.pins[self.a[field]],))

    def request(self, method, params):
        key = dumps([method, params])
        if key in getattr(self, "shared", {}):
            return self.shared[key]
        return super().request(method, params)


class OwnerExhibitionPackageTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.original_inputs = inputs()
        cls.recorded = load_source()
        cls.original = build_recorded_package(cls.original_inputs, root=ROOT, disclosure="public", **pins())

    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        write_package(self.original, self.root / "base")
        self.set_owner(JoinedFixture(self.recorded.anchor, self.original_inputs))

    def set_owner(self, fixture):
        self.fixture = fixture
        source, self.owner_inputs, _ = fixture.replay()
        self.owner_pins = {"anchorHash": keccak256(self.owner_inputs["anchor.json"]),
            "transcriptHash": keccak256(self.owner_inputs["transcript.json"]),
            "sourceHash": keccak256(source.snapshot())}
        self.plan = {"version": "1", "sourceHash": self.owner_pins["sourceHash"], "records": fixture.selected}

    def build(self, **changes):
        raw = dumps(self.plan)
        kwargs = dict(plan_hash=keccak256(raw), profile_hash=PROFILE_HASH,
            owner_inputs=self.owner_inputs, owner_pins=self.owner_pins, disclosure="public")
        kwargs.update(changes)
        return build_owner_exhibition_package(self.root / "base", self.original.manifest_hash, raw, **kwargs)

    def test_original_bytes_full_replay_and_dispatch_remain_offline(self):
        with patch("socket.socket", side_effect=AssertionError("exhibition package used network")):
            result = self.build()
            path = self.root / "package"; write_package(result, path)
            self.assertEqual(verify_package(path, result.manifest_hash), result)
        files = dict(result.files)
        self.assertEqual(files["source/manifest.json"], self.original.manifest)
        for name, raw in self.original.files:
            self.assertEqual(files["source/" + name], raw)
        for name, raw in self.owner_inputs.items():
            self.assertEqual(files["owner-records/" + name], raw)
        report = loads(files["exhibitions/report.json"], maximum=524288)
        self.assertEqual(report["activities"], "1")
        self.assertFalse(any(report["claims"].values()))
        sidecar = loads(files["exhibitions/sidecar.json"], maximum=524288)
        self.assertEqual(sidecar[0]["authority"]["mode"], "historical_owner_receipt")
        self.assertNotEqual(sidecar[0]["authority"]["owner"], sidecar[0]["exhibition"]["institution"]["entityId"])

    def test_rehashed_semantic_tamper_is_rejected(self):
        result = self.build()
        report = loads(dict(result.files)["exhibitions/report.json"], maximum=524288)
        report["claims"]["historicalPerformanceProven"] = True
        altered = changed(result, "exhibitions/report.json", dumps(report))
        path = self.root / "altered"; write_package(altered, path)
        with self.assertRaisesRegex(MuseumError, "semantic reconstruction"):
            verify_owner_exhibition_package(path, altered.manifest_hash)

    def test_pins_disclosure_closed_plan_and_original_deployment_are_required(self):
        wrong = keccak256(b"wrong external pin")
        for changes in ({"plan_hash": wrong}, {"profile_hash": wrong}, {"disclosure": "restricted"},
                {"owner_pins": dict(self.owner_pins, sourceHash=wrong)},
                {"owner_pins": dict(self.owner_pins, anchorHash=wrong)},
                {"owner_pins": dict(self.owner_pins, transcriptHash=wrong)},
                {"owner_inputs": dict(self.owner_inputs, **{"deployment-evidence.json": b"changed"})}):
            with self.subTest(keys=tuple(changes)), self.assertRaises(MuseumError):
                self.build(**changes)
        self.plan["additional"] = "not permitted"
        with self.assertRaisesRegex(MuseumError, "closed plan"):
            self.build()
        with patch("tools.museum.owner_exhibition_package.verify_recorded_package",
                   side_effect=AssertionError("restricted export read its source")):
            with self.assertRaisesRegex(MuseumError, "public disclosure"):
                self.build(disclosure="restricted")

    def test_matching_block_labels_cannot_hide_different_runtime_pins(self):
        fixture = JoinedFixture(self.recorded.anchor, self.original_inputs)
        core = fixture.a["core"]
        fixture.codes[core] = b"\x60\x99\x00"
        fixture._update_pins()
        for key in list(fixture.shared):
            method, params = loads(key, maximum=524288)
            if method == "eth_getCode" and params[0] == core:
                fixture.shared[key] = "0x" + fixture.codes[core].hex()
        self.set_owner(fixture)  # Independently replays with coherently changed external pins.
        with self.assertRaisesRegex(MuseumError, "shared runtime pins differ"):
            self.build()

    def test_same_request_cannot_have_different_valid_header_results(self):
        fixture = JoinedFixture(self.recorded.anchor, self.original_inputs)
        for key in list(fixture.shared):
            method, _ = loads(key, maximum=524288)
            if method == "eth_getBlockByHash":
                fixture.shared[key] = dict(fixture.shared[key], extraData="0xabcd")
        self.set_owner(fixture)  # Required anchor scalars still pass its own source replay.
        with self.assertRaisesRegex(MuseumError, "cross-source RPC result differs"):
            self.build()

    def test_foreign_state_and_selected_resource_identity_collisions_are_rejected(self):
        anchor = dict(self.recorded.anchor, blockNumber=str(int(self.recorded.anchor["blockNumber"]) + 1))
        self.set_owner(OwnerExhibitionFixture(anchor=anchor))
        with self.assertRaisesRegex(MuseumError, "same original chain/Core/block"):
            self.build()
        original_ids = loads(dict(self.original.files)["linked-art/entity-index.json"], maximum=2097152)
        def collide(value):
            value["exhibitionId"] = original_ids[0]["id"]
        self.set_owner(JoinedFixture(self.recorded.anchor, self.original_inputs, edit=collide))
        with self.assertRaisesRegex(MuseumError, "identity reuse"):
            self.build()

    def test_package_bagit_ocfl_restore_is_exact_and_offline(self):
        with patch("socket.socket", side_effect=AssertionError("exhibition handoff used network")):
            package = self.build()
            payloads = {"semantic/" + name: raw for name, raw in package.files}
            payloads["semantic/manifest.json"] = package.manifest
            descriptor, payloads = description(payloads)
            # Outer bundle commitments remain explicit synthetic transport metadata.
            # They do not promote the owner's synthetic receipt to actual capture.
            descriptor["semanticPackages"] = [{"prefix": "semantic", "manifestHash": package.manifest_hash}]
            bag = build_bag(dumps(descriptor), payloads)
            bag_path = self.root / "bag"; write_tree(bag.files, bag_path)
            object_path = self.root / "object"
            inspected = export_bag(bag_path, bag.manifest_hash, object_path,
                created="2026-09-20T00:00:00Z", message="Synthetic owner exhibition round trip")
            restored = self.root / "restored"
            receipt = import_version(object_path, inspected.object.inventory_hash, "v1", bag.manifest_hash, restored)
        self.assertEqual(read_tree(restored), dict(bag.files))
        self.assertFalse(receipt["qualification"]["sourceAuthorityProven"])
        for name, raw in self.owner_inputs.items():
            self.assertEqual((restored / "data/semantic/owner-records" / name).read_bytes(), raw)

    def test_cli_build_verify_and_restricted_preflight(self):
        owner = self.root / "owner"; write_tree(self.owner_inputs, owner)
        (self.root / "pins.json").write_bytes(dumps(self.owner_pins))
        raw = dumps(self.plan); (self.root / "plan.json").write_bytes(raw)
        command = [sys.executable, "-m", "tools.museum.owner_exhibition_package"]
        output = self.root / "cli-package"
        built = subprocess.run([*command, "build", str(self.root / "base"), str(self.root / "plan.json"),
            str(owner), str(self.root / "pins.json"), str(output), "--source-manifest-hash", self.original.manifest_hash,
            "--plan-hash", keccak256(raw), "--profile-hash", PROFILE_HASH, "--disclosure", "public"],
            capture_output=True, text=True)
        self.assertEqual(built.returncode, 0, built.stderr)
        checked = subprocess.run([*command, "verify", str(output), "--manifest-hash", built.stdout.strip()],
            capture_output=True, text=True)
        self.assertEqual(checked.returncode, 0, checked.stderr)
        denied = subprocess.run([*command, "build", "absent-base", "absent-plan", "absent-owner", "absent-pins",
            str(self.root / "restricted"), "--source-manifest-hash", self.original.manifest_hash,
            "--plan-hash", keccak256(raw), "--profile-hash", PROFILE_HASH, "--disclosure", "restricted"],
            capture_output=True, text=True)
        self.assertEqual(denied.returncode, 2)
        self.assertIn("public disclosure", denied.stderr)
        self.assertFalse((self.root / "restricted").exists())


if __name__ == "__main__":
    unittest.main()

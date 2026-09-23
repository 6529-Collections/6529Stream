"""Four formats in one relocatable archive; original v1 packages stay separate."""
import copy
from dataclasses import replace
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch

from .canonical import MuseumError, dumps, hex_bytes, keccak256, loads
from .package import fixture_state_bytes, write_package
from .package_v2 import build_fixture_package, verify_fixture_package, FORMATS, INPUTS
from .test_lido import source_data, arguments, MEDIUM, DATE, CREATOR
from .test_package import changed

ROOT = Path(__file__).resolve().parents[2] / "schemas/museum"


def inputs():
    data = source_data()
    args, old = arguments(data, None, None, None, None)
    pins = {k: v for k, v in old.items() if k.endswith("_hash")}
    pins.update(validation_hash=keccak256((ROOT / "linked-art-v2/validation-policy.json").read_bytes()),
                vocabulary_hash=keccak256((ROOT / "standards/vocabulary-policy.json").read_bytes()))
    return args, pins


class MultiformatPackage(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.args, cls.pins = inputs()
        cls.package = build_fixture_package(*cls.args, root=ROOT, **cls.pins)

    def archive(self, package=None):
        temporary = tempfile.TemporaryDirectory()
        self.addCleanup(temporary.cleanup)
        folder = Path(temporary.name) / "archive"
        write_package(self.package if package is None else package, folder)
        return folder

    def test_four_formats_same_source_exact_coverage_and_identity_roles(self):
        files = dict(self.package.files)
        manifest = loads(self.package.manifest, maximum=2 * 1024 * 1024)
        self.assertEqual(manifest["formats"], FORMATS)
        self.assertEqual(manifest["sourceStateHash"], self.args[0].commitment)
        self.assertFalse(any(manifest["claims"].values()))
        self.assertIn("premis/premis.xml", files)
        self.assertIn("iiif/manifest.json", files)
        self.assertIn("lido/lido.xml", files)
        shared = loads(files["reports/shared-identity.json"], maximum=64 * 1024 * 1024)
        self.assertEqual(shared["lido"]["creatorId"], CREATOR)
        self.assertEqual(shared["lido"]["workId"], "urn:fixture:work")
        self.assertNotEqual(shared["lido"]["creatorId"], "urn:fixture:artist")
        self.assertEqual(files["inputs/source-state.json"], fixture_state_bytes(self.args[0]))
        wire = loads(files["inputs/source-state.json"], maximum=64 * 1024 * 1024)
        values = [claim.get("object", {}).get("literal", {}).get("lexicalValue")
                  for record in wire["records"]
                  for claim in loads(hex_bytes(record["payloadHex"]))["assertions"]]
        self.assertIn(MEDIUM, values)
        baseline = None
        for name in ("linked-art", "premis", "iiif", "lido"):
            report = loads(files[name + "/report.json"], maximum=64 * 1024 * 1024)
            self.assertEqual(report["sourceStateHash"], self.args[0].commitment)
            coverage = loads(files[name + "/coverage.json"], maximum=64 * 1024 * 1024)
            # Projection disposition can differ; the source-derived denominator and exact
            # bytes/presence must remain the same across all four formats.
            fields = [(r["recordHash"], [{k:v for k,v in f.items()
                        if k not in {"disposition", "rule", "reason"}} for f in r["fields"]]) for r in coverage]
            if baseline is None: baseline = fields
            self.assertEqual(fields, baseline)

    def test_complete_offline_rebuild_after_move(self):
        folder = self.archive()
        with patch("socket.socket", side_effect=AssertionError("offline only")):
            self.assertEqual(verify_fixture_package(folder, self.package.manifest_hash), self.package)
        # No dependency on the original schema directory during verification.
        self.assertTrue((folder / "dependencies/iiif/sound-context.json").is_file())
        self.assertTrue((folder / "dependencies/lido/dependency-index.json").is_file())
        self.assertTrue((folder / "dependencies/premis/dependency-index.json").is_file())

    def test_tamper_without_new_anchor_and_unlisted_file_reject(self):
        folder = self.archive()
        with self.assertRaisesRegex(MuseumError, "external hash"):
            verify_fixture_package(folder, "0x" + "00" * 32)
        path = folder / "lido/lido.xml"
        path.write_bytes(path.read_bytes() + b" ")
        with self.assertRaises(MuseumError):
            verify_fixture_package(folder, self.package.manifest_hash)
        folder = self.archive()
        (folder / "unlisted.txt").write_text("extra", encoding="utf-8")
        with self.assertRaisesRegex(MuseumError, "undeclared"):
            verify_fixture_package(folder, self.package.manifest_hash)

    def test_rehashed_format_correspondence_and_coverage_tamper_reject(self):
        files = dict(self.package.files)
        replacements = {
            "lido/lido.xml": files["lido/lido.xml"].replace(b"generative digital artwork", b"false artwork"),
            "reports/shared-identity.json": dumps({"sourceStateHash": self.args[0].commitment}),
            "premis/coverage.json": dumps([]),
        }
        for name, raw in replacements.items():
            with self.subTest(name=name):
                self.assertNotEqual(raw, files[name])
                modified = changed(self.package, name, raw)
                with self.assertRaisesRegex(MuseumError, "reconstruction differs"):
                    verify_fixture_package(self.archive(modified), modified.manifest_hash)

    def test_removed_required_output_cannot_redefine_package(self):
        manifest = loads(self.package.manifest, maximum=2 * 1024 * 1024)
        name = "premis/premis.xml"
        manifest["files"] = [r for r in manifest["files"] if r["path"] != name]
        modified = replace(self.package, files=tuple((n,b) for n,b in self.package.files if n != name),
                           manifest=dumps(manifest))
        with self.assertRaisesRegex(MuseumError, "reconstruction differs"):
            verify_fixture_package(self.archive(modified), modified.manifest_hash)

    def test_archived_dependency_tamper_rejected_even_with_child_rehash(self):
        files = dict(self.package.files)
        index = loads(files["dependencies/premis/dependency-index.json"])
        name = "dependencies/" + index["documents"][0]["chunks"][0]["path"]
        raw = files[name]
        modified = changed(self.package, name, bytes([raw[0] ^ 1]) + raw[1:])
        with self.assertRaises(MuseumError):
            verify_fixture_package(self.archive(modified), modified.manifest_hash)

    def test_false_recorded_restricted_or_conformance_claim_reject(self):
        for state in (replace(self.args[0], mode="recorded_state"),
                      replace(self.args[0], records=(replace(self.args[0].records[0], disclosure="restricted"),))):
            with self.assertRaises(MuseumError):
                build_fixture_package(state, *self.args[1:], root=ROOT, **self.pins)
        manifest = loads(self.package.manifest, maximum=2 * 1024 * 1024)
        manifest["claims"]["authenticatedChainState"] = True
        modified = replace(self.package, manifest=dumps(manifest))
        with self.assertRaisesRegex(MuseumError, "unsupported"):
            verify_fixture_package(self.archive(modified), modified.manifest_hash)

    def test_path_case_collision_traversal_and_wrong_profile_reject(self):
        for mutate in ("case", "traversal", "profile"):
            manifest = loads(self.package.manifest, maximum=2 * 1024 * 1024)
            if mutate == "case":
                row = copy.deepcopy(manifest["files"][0]); row["path"] = row["path"].upper()
                manifest["files"].append(row)
            elif mutate == "traversal":
                manifest["files"][0]["path"] = "../outside"
            else:
                manifest["pins"]["crosswalk"] = "0x" + "00" * 32
            modified = replace(self.package, manifest=dumps(manifest))
            with self.assertRaises(MuseumError):
                verify_fixture_package(self.archive(modified), modified.manifest_hash)

    def test_plan_drift_and_distinct_file_selection_reject(self):
        args = list(self.args)
        plan = loads(args[3]); plan["objects"] = plan["objects"][:-1]
        args[3] = dumps(plan)
        pins = self.pins | {"premis_plan_hash": keccak256(args[3])}
        with self.assertRaises(MuseumError):
            build_fixture_package(*args, root=ROOT, **pins)
        with self.assertRaises(MuseumError):
            build_fixture_package(*self.args, root=ROOT, **(self.pins | {"lido_plan_hash":"0x"+"00"*32}))

    def test_bounds_fail_before_archive_is_written(self):
        with patch("tools.museum.package_v2.MAX_FILES", 1):
            with self.assertRaisesRegex(MuseumError, "bounds"):
                build_fixture_package(*self.args, root=ROOT, **self.pins)

    def test_cli_build_and_verify_from_retained_fixture(self):
        fixture = ROOT / "multiformat/fixture"
        with tempfile.TemporaryDirectory() as temporary:
            destination = Path(temporary) / "package"
            pins = loads((fixture / "pins.json").read_bytes())
            cmd = [sys.executable, "-B", "-m", "tools.museum.package_v2", "build-fixture",
                   str(fixture / "source-state.json")]
            cmd.extend(str(fixture / (name.replace("_", "-") + ".json")) for name in INPUTS)
            cmd += [str(destination), "--dependency-root", str(ROOT)]
            for key, value in pins.items():
                cmd += ["--" + key.replace("_", "-"), value]
            result = subprocess.run(cmd, capture_output=True, text=True, encoding="utf-8", timeout=60)
            self.assertEqual(result.returncode, 0, result.stderr)
            result = subprocess.run([sys.executable, "-B", "-m", "tools.museum.package_v2", "verify",
                str(destination), "--manifest-hash", self.package.manifest_hash],
                capture_output=True, text=True, encoding="utf-8", timeout=60)
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertIn("resource_package v2", result.stdout)


if __name__ == "__main__":
    unittest.main()

"""Real retained account capture replay; never promote a synthetic source to recorded."""
import copy
from dataclasses import replace
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch

from .canonical import MuseumError, dumps, hex_bytes, keccak256, loads
from .package import write_package
from .package_recorded import build_recorded_package, build_recorded_directory, verify_recorded_package, INPUT_FILES
from .package_v2 import verify_package, verify_fixture_package
from .test_package import changed
from .test_recorded_account import ROOT, FIXTURE, SOURCE_HASH, PUBLICATION_HASH, INTERPRETATION_HASH, PROFILE_HASH


def inputs():
    return {name: (FIXTURE / name).read_bytes() for name in INPUT_FILES}


def pins():
    return dict(source_hash=SOURCE_HASH, publication_hash=PUBLICATION_HASH,
        interpretation_hash=INTERPRETATION_HASH, profile_hash=PROFILE_HASH,
        selection_hash=keccak256((FIXTURE / "selection.json").read_bytes()),
        plan_hash=keccak256((FIXTURE / "plan.json").read_bytes()))


class RecordedPackage(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.inputs, cls.pins = inputs(), pins()
        cls.package = build_recorded_package(cls.inputs, root=ROOT, disclosure="public", **cls.pins)

    def archive(self, package=None):
        temporary = tempfile.TemporaryDirectory()
        self.addCleanup(temporary.cleanup)
        folder = Path(temporary.name) / "archive"
        write_package(self.package if package is None else package, folder)
        return folder

    def test_actual_captured_bytes_and_original_projection_are_retained(self):
        files = dict(self.package.files)
        for name, raw in self.inputs.items():
            self.assertEqual(files["inputs/" + name], raw, name)
        outputs = ["sidecar", "coverage", "provenance", "report"]
        outputs += [prefix + str(index) for prefix in ("resource-", "expanded-") for index in range(4)]
        for name in outputs:
            self.assertEqual(files["linked-art/" + name + ".json"], (FIXTURE / (name + ".json")).read_bytes())
        capture = loads(files["inputs/source-capture.json"], maximum=67108864)
        self.assertEqual(len(capture["records"]), 18)
        self.assertTrue(all(hex_bytes(row["payloadHex"]) for row in capture["records"]))
        manifest = loads(self.package.manifest, maximum=2097152)
        self.assertEqual(manifest["environment"], "local_evm_fixture")
        self.assertEqual(manifest["mode"], "recorded_account_resource_package")
        self.assertFalse(any(manifest["claims"].values()))
        disclosure = loads(files["reports/disclosure.json"])
        self.assertEqual(disclosure["classification"], "public")
        self.assertEqual(len(disclosure["records"]), 18)
        self.assertEqual({row["disclosure"] for row in disclosure["records"]}, {"public"})
        evidence = loads(files["reports/source-evidence.json"])
        self.assertEqual(evidence["registeredProfileHash"], PROFILE_HASH)
        self.assertFalse(evidence["cryptographicStateProof"])
        self.assertFalse(evidence["publicDeploymentAcceptance"])
        self.assertNotIn("inputs/source-state.json", files)

    def test_explicit_unsupported_formats_without_invented_format_files(self):
        files = dict(self.package.files)
        support = loads(files["reports/format-support.json"])["formats"]
        self.assertEqual([row["status"] for row in support], ["supported", "unsupported", "unsupported", "unsupported"])
        self.assertTrue(all(row["reasonCode"] == "recorded_adapter_unavailable" for row in support[1:]))
        self.assertFalse(any(name.startswith(("premis/", "iiif/", "lido/", "dependencies/premis/",
                                             "dependencies/iiif/", "dependencies/lido/")) for name in files))

    def test_relocated_package_reconstructs_with_network_and_original_root_unavailable(self):
        folder = self.archive()
        moved = folder.parent / "relocated"
        shutil.move(str(folder), moved)
        read_bytes = Path.read_bytes

        def archived_only(path):
            if path.resolve().is_relative_to(ROOT.resolve()):
                raise AssertionError("verification read the original source/dependency root")
            return read_bytes(path)

        with patch("socket.socket", side_effect=AssertionError("package attempted network")), \
             patch.object(Path, "read_bytes", archived_only), \
             patch("tools.museum.recorded_projection.replay_source", side_effect=AssertionError("mutable input replay")):
            verified = verify_package(moved, self.package.manifest_hash)
        self.assertEqual(verified, self.package)

    def test_restricted_classification_refuses_before_input_access_or_output(self):
        with patch("tools.museum.package_recorded.replay_source_bytes", side_effect=AssertionError("restricted replay")):
            with self.assertRaisesRegex(MuseumError, "restricted"):
                build_recorded_package({}, root=ROOT, disclosure="restricted", **self.pins)
            with self.assertRaisesRegex(MuseumError, "restricted"):
                build_recorded_directory(ROOT / "nonexistent", root=ROOT, disclosure="restricted", **self.pins)
        package = replace(self.package, manifest=dumps(loads(self.package.manifest, maximum=2097152) | {"disclosure": "restricted"}))
        with self.assertRaisesRegex(MuseumError, "restricted"):
            verify_recorded_package(self.archive(package), package.manifest_hash)

    def test_transcript_pins_and_rehashed_wrong_call_do_not_authenticate(self):
        wrong = self.pins | {"source_hash": "0x" + "11" * 32}
        with self.assertRaisesRegex(MuseumError, "external commitment"):
            build_recorded_package(self.inputs, root=ROOT, disclosure="public", **wrong)
        rows = loads(self.inputs["transcript.json"], maximum=67108864)
        rows["calls"][0]["result"] = "0x1"
        raw = dumps(rows)
        altered = self.inputs | {"transcript.json": raw}
        with self.assertRaises(MuseumError):
            build_recorded_package(altered, root=ROOT, disclosure="public", **(self.pins | {"source_hash": keccak256(raw)}))

    def test_rehashed_original_capture_and_deployment_substitution_reject(self):
        for name, expected in (("source-capture.json", "captured bytes"),
                               ("publications.json", "captured bytes"),
                               ("interpretation.json", "captured bytes"),
                               ("deployment-evidence.json", "deployment evidence")):
            with self.subTest(name=name):
                package = changed(self.package, "inputs/" + name, self.inputs[name] + b" ")
                with self.assertRaisesRegex(MuseumError, expected):
                    verify_package(self.archive(package), package.manifest_hash)

    def test_rehashed_projection_support_and_disclosure_changes_reject(self):
        for name in ("linked-art/resource-0.json", "reports/format-support.json", "reports/disclosure.json",
                     "reports/source-evidence.json"):
            with self.subTest(name=name):
                package = changed(self.package, name, b"{}")
                with self.assertRaisesRegex(MuseumError, "semantic reconstruction"):
                    verify_package(self.archive(package), package.manifest_hash)

    def test_manifest_cannot_promote_environment_claims_or_format_support(self):
        manifest = loads(self.package.manifest, maximum=2097152)
        promoted = copy.deepcopy(manifest["formats"])
        promoted[1]["status"] = "supported"
        for update in ({"environment": "public_chain"}, {"formats": promoted},
                       {"claims": manifest["claims"] | {"registered": True}}):
            with self.subTest(update=update):
                package = replace(self.package, manifest=dumps(manifest | update))
                with self.assertRaises(MuseumError):
                    verify_package(self.archive(package), package.manifest_hash)
        with self.assertRaisesRegex(MuseumError, "unsupported multiformat"):
            verify_fixture_package(self.archive(), self.package.manifest_hash)

    def test_registered_definition_and_dependency_changes_reject_after_rehash(self):
        files = dict(self.package.files)
        definition = next(name for name in files if name.startswith("definitions/"))
        package = changed(self.package, definition, b"{}")
        with self.assertRaisesRegex(MuseumError, "semantic reconstruction"):
            verify_package(self.archive(package), package.manifest_hash)
        dependency = next(name for name in files if name.startswith("dependencies/") and "/chunks/" in name)
        raw = files[dependency]
        package = changed(self.package, dependency, raw[:-1] + bytes([raw[-1] ^ 1]))
        with self.assertRaises(MuseumError):
            verify_package(self.archive(package), package.manifest_hash)

    def test_missing_inputs_undeclared_files_and_external_manifest_pin_reject(self):
        with self.assertRaisesRegex(MuseumError, "exact input set"):
            build_recorded_package({"source-state.json": b'{"mode":"synthetic_fixture"}'}, root=ROOT,
                                   disclosure="public", **self.pins)
        folder = self.archive()
        with self.assertRaisesRegex(MuseumError, "external hash"):
            verify_package(folder, "0x" + "11" * 32)
        (folder / "unlisted.json").write_bytes(b"{}")
        with self.assertRaisesRegex(MuseumError, "undeclared"):
            verify_package(folder, self.package.manifest_hash)

    def test_real_cli_build_verify_and_restricted_no_output(self):
        fixture_pins = loads((ROOT / "multiformat/recorded/pins.json").read_bytes())
        self.assertEqual(fixture_pins, {k.removesuffix("_hash"): v for k,v in self.pins.items()})
        with tempfile.TemporaryDirectory() as temporary:
            output = Path(temporary) / "package"
            command = [sys.executable, "-B", "-m", "tools.museum.package_v2", "build-recorded",
                       str(FIXTURE), str(output), "--dependency-root", str(ROOT), "--disclosure", "public"]
            for name, value in self.pins.items():
                command += ["--" + name.replace("_", "-"), value]
            result = subprocess.run(command, capture_output=True, text=True, timeout=60)
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertEqual((output / "manifest.json").read_bytes(), self.package.manifest)
            result = subprocess.run([sys.executable, "-B", "-m", "tools.museum.package_v2", "verify",
                str(output), "--manifest-hash", self.package.manifest_hash], capture_output=True, text=True, timeout=60)
            self.assertEqual(result.returncode, 0, result.stderr)
            restricted = Path(temporary) / "restricted"
            command[command.index(str(output))] = str(restricted)
            command[command.index("public")] = "restricted"
            result = subprocess.run(command, capture_output=True, text=True, timeout=60)
            self.assertNotEqual(result.returncode, 0)
            self.assertIn("restricted", result.stderr)
            self.assertFalse(restricted.exists())


if __name__ == "__main__":
    unittest.main()

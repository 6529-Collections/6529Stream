"""Exact archived inputs/dependencies and semantic recomputation, all offline."""

import copy
from dataclasses import replace
from hashlib import sha256
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch

from .canonical import MuseumError, dumps, keccak256, loads
from .package import (ResourcePackage, build_fixture_package, fixture_state_bytes, fixture_state_from_bytes,
                      verify_fixture_package, write_package)
from .test_projection import ROOT, fixture


def build(data):
    state, policy, plan = data
    return build_fixture_package(state, dumps(policy), dumps(plan), root=ROOT, profile_hash=plan["profileHash"],
        selection_hash=keccak256(dumps(policy)), plan_hash=keccak256(dumps(plan)),
        validation_hash=keccak256((ROOT / "linked-art/validation-policy.json").read_bytes()),
        vocabulary_hash=keccak256((ROOT / "standards/vocabulary-policy.json").read_bytes()))


def changed(package, name, content):
    files = dict(package.files)
    files[name] = content
    manifest = loads(package.manifest, maximum=2 * 1024 * 1024)
    for row in manifest["files"]:
        if row["path"] == name:
            row.update(bytes=str(len(content)), sha256="0x" + sha256(content).hexdigest(), keccak256=keccak256(content))
    return ResourcePackage(tuple(sorted(files.items())), dumps(manifest))


class OfflineResourcePackage(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.data = fixture()
        cls.package = build(cls.data)

    def test_fixture_wire_roundtrip_and_false_identity_or_recorded_state_reject(self):
        raw = fixture_state_bytes(self.data[0])
        self.assertEqual(fixture_state_from_bytes(raw), self.data[0])
        value = loads(raw, maximum=64 * 1024 * 1024)
        value["records"][0]["selector"]["record_index"] = "2"
        with self.assertRaises(MuseumError):
            fixture_state_from_bytes(dumps(value))
        with self.assertRaises(MuseumError):
            fixture_state_bytes(replace(self.data[0], mode="recorded_state"))
        with self.assertRaises(MuseumError):
            fixture_state_bytes(replace(self.data[0], records=(replace(self.data[0].records[0], disclosure="restricted"),)))

    def test_all_children_are_bound_and_manifest_does_not_hash_itself(self):
        manifest = loads(self.package.manifest, maximum=2 * 1024 * 1024)
        self.assertEqual(len(manifest["files"]), len(self.package.files))
        self.assertNotIn("manifest.json", {row["path"] for row in manifest["files"]})
        self.assertNotIn(self.package.manifest_hash.encode(), self.package.manifest)
        self.assertFalse(any(manifest["claims"].values()))
        for row, (name, raw) in zip(manifest["files"], self.package.files):
            self.assertEqual(row["path"], name)
            self.assertEqual(row["bytes"], str(len(raw)))
            self.assertEqual(row["sha256"], "0x" + sha256(raw).hexdigest())
            self.assertEqual(row["keccak256"], keccak256(raw))
        index = loads(dict(self.package.files)["projection/entity-index.json"])
        self.assertEqual(len(index), 5)
        self.assertEqual(len({row["id"] for row in index}), 5)
        self.assertEqual(sum(row["kind"] == "stream_extension" for row in index), 1)

    def test_original_chunks_reconstruct_offline_and_projection_reproduces_in_new_location(self):
        with tempfile.TemporaryDirectory() as temporary, patch("socket.socket", side_effect=AssertionError("no network")):
            folder = Path(temporary) / "archive"
            write_package(self.package, folder)
            result = verify_fixture_package(folder, self.package.manifest_hash)
            self.assertEqual(result, self.package)
            files = dict(result.files)
            index = loads(files["dependencies/standards/vocabulary-index.json"], maximum=65536)
            crm = next(row for row in index["documents"] if row["byteLength"] == "434213")
            parts = [files["dependencies/standards/" + c["path"]] for c in crm["chunks"]]
            self.assertEqual(len(parts), 54)
            self.assertEqual(len(b"".join(parts)), 434213)
            self.assertEqual(sha256(b"".join(parts)).hexdigest(), "ff214757a58164438fc78becfbb11bc1223f9a3a03db0a381cb94303f170e69a")
            self.assertEqual(b"".join(parts).count(b"\r\n"), 5130)  # original source line endings survive

    def test_external_manifest_anchor_and_child_tampering_reject(self):
        with tempfile.TemporaryDirectory() as temporary:
            folder = Path(temporary) / "archive"
            write_package(self.package, folder)
            with self.assertRaises(MuseumError):
                verify_fixture_package(folder, "0x" + "00" * 32)
            path = folder / "projection/report.json"
            original = path.read_bytes()
            path.write_bytes(original + b" ")
            with self.assertRaises(MuseumError):
                verify_fixture_package(folder, self.package.manifest_hash)
            path.write_bytes(original)
            self.assertEqual(verify_fixture_package(folder, self.package.manifest_hash), self.package)

    def test_rehashed_resource_forgery_fails_semantic_reconstruction(self):
        name, raw = next((n, r) for n, r in self.package.files if n.startswith("entities/"))
        entity = loads(raw)
        entity["_label"] = "Unauthored replacement"
        forged = changed(self.package, name, dumps(entity))
        with tempfile.TemporaryDirectory() as temporary:
            folder = Path(temporary) / "forged"
            write_package(forged, folder)
            with self.assertRaisesRegex(MuseumError, "semantic reconstruction differs"):
                verify_fixture_package(folder, forged.manifest_hash)

    def test_rehashed_context_chunk_forgery_still_fails_original_dependency_pin(self):
        name, raw = next((n, r) for n, r in self.package.files if n.startswith("dependencies/") and n.endswith(".bin"))
        forged = changed(self.package, name, bytes([raw[0] ^ 1]) + raw[1:])
        with tempfile.TemporaryDirectory() as temporary:
            folder = Path(temporary) / "forged"
            write_package(forged, folder)
            with self.assertRaises(MuseumError):
                verify_fixture_package(folder, forged.manifest_hash)

    def test_missing_extra_and_traversal_files_reject(self):
        with tempfile.TemporaryDirectory() as temporary:
            folder = Path(temporary) / "archive"
            write_package(self.package, folder)
            extra = folder / "unlisted.json"
            extra.write_bytes(b"{}")
            with self.assertRaisesRegex(MuseumError, "undeclared or missing"):
                verify_fixture_package(folder, self.package.manifest_hash)
            extra.unlink()
            name, raw = self.package.files[0]
            (folder / name).unlink()
            with self.assertRaises((MuseumError, FileNotFoundError)):
                verify_fixture_package(folder, self.package.manifest_hash)
            (folder / name).write_bytes(raw)
        for bad in ("../outside", "CON.txt", "a/NUL", "C:/absolute"):
            with tempfile.TemporaryDirectory() as temporary:
                manifest = loads(self.package.manifest, maximum=2 * 1024 * 1024)
                manifest["files"][0]["path"] = bad
                malformed = dumps(manifest)
                folder = Path(temporary) / "archive"
                write_package(self.package, folder)
                (folder / "manifest.json").write_bytes(malformed)
                with self.subTest(path=bad), self.assertRaises(MuseumError):
                    verify_fixture_package(folder, keccak256(malformed))

    def test_existing_output_is_not_overwritten_and_cli_requires_external_hash(self):
        with tempfile.TemporaryDirectory() as temporary:
            folder = Path(temporary) / "archive"
            write_package(self.package, folder)
            with self.assertRaises(FileExistsError):
                write_package(self.package, folder)
            result = subprocess.run([sys.executable, "-m", "tools.museum.package", "verify", str(folder),
                "--manifest-hash", self.package.manifest_hash], cwd=Path(__file__).resolve().parents[2],
                stdout=subprocess.PIPE, stderr=subprocess.PIPE)
            self.assertEqual(result.returncode, 0, result.stderr.decode())
            self.assertIn(self.package.manifest_hash.encode(), result.stdout)
            missing = subprocess.run([sys.executable, "-m", "tools.museum.package", "verify", str(folder)],
                cwd=Path(__file__).resolve().parents[2], stdout=subprocess.PIPE, stderr=subprocess.PIPE)
            self.assertNotEqual(missing.returncode, 0)

    def test_documented_example_is_exact_and_cli_build_matches_the_same_package(self):
        example = ROOT / "projection/package-example"
        self.assertEqual((example / "source-state.json").read_bytes(), fixture_state_bytes(self.data[0]))
        self.assertEqual((example / "selection-policy.json").read_bytes(), dumps(self.data[1]))
        self.assertEqual((example / "projection-plan.json").read_bytes(), dumps(self.data[2]))
        with tempfile.TemporaryDirectory() as temporary:
            target = Path(temporary) / "built-by-cli"
            command = [sys.executable, "-m", "tools.museum.package", "build-fixture",
                str(example / "source-state.json"), str(example / "selection-policy.json"),
                str(example / "projection-plan.json"), str(target), "--dependency-root", str(ROOT),
                "--profile-hash", self.data[2]["profileHash"],
                "--selection-hash", keccak256(dumps(self.data[1])), "--plan-hash", keccak256(dumps(self.data[2])),
                "--validation-hash", keccak256((ROOT / "linked-art/validation-policy.json").read_bytes()),
                "--vocabulary-hash", keccak256((ROOT / "standards/vocabulary-policy.json").read_bytes())]
            result = subprocess.run(command, cwd=Path(__file__).resolve().parents[2],
                                    stdout=subprocess.PIPE, stderr=subprocess.PIPE)
            self.assertEqual(result.returncode, 0, result.stderr.decode())
            self.assertEqual((target / "manifest.json").read_bytes(), self.package.manifest)
            self.assertIn(self.package.manifest_hash.encode(), result.stdout)

    def test_duplicate_case_paths_and_size_claims_reject_before_reconstruction(self):
        for mode in ("case", "size", "self"):
            manifest = loads(self.package.manifest, maximum=2 * 1024 * 1024)
            if mode == "case":
                duplicate = copy.deepcopy(manifest["files"][0])
                duplicate["path"] = duplicate["path"].upper()
                manifest["files"].insert(1, duplicate)
            elif mode == "size":
                manifest["files"][0]["bytes"] = str(96 * 1024 * 1024 + 1)
            else:
                manifest["files"][0]["path"] = "manifest.json"
            raw = dumps(manifest)
            with tempfile.TemporaryDirectory() as temporary:
                folder = Path(temporary) / "bad"
                write_package(self.package, folder)
                (folder / "manifest.json").write_bytes(raw)
                with self.subTest(mode=mode), self.assertRaises(MuseumError):
                    verify_fixture_package(folder, keccak256(raw))


if __name__ == "__main__":
    unittest.main()

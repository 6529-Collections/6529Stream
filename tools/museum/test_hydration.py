from copy import deepcopy
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch

from .canonical import MuseumError, dumps, keccak256, loads
from .bagit import build_bag, verify_bag, verify_bag_files, read_tree, write_tree
from .hydration import PROFILE_BYTES, PROFILE_HASH, SOURCE_PREFIX, SOURCE_SUFFIX, hydrate_bag
from .ocfl import build_version, verify_object_files
from .test_bagit import description, remote_description


class HydrationTests(unittest.TestCase):
    def setUp(self):
        self.description, self.embedded = remote_description()
        self.original = build_bag(dumps(self.description), self.embedded)
        self.supplied = {"remote/master.bin": b"declared remote preservation master"}

    def hydrate(self):
        return hydrate_bag(self.original, self.supplied)

    def test_exact_local_fulfillment_preserves_original_tags_and_has_no_active_fetch(self):
        with patch("socket.socket", side_effect=AssertionError("network use")):
            bag = self.hydrate()
            self.assertEqual(verify_bag_files(bag.files, bag.manifest_hash), bag)
        files = dict(bag.files)
        self.assertNotIn("fetch.txt", files)
        self.assertEqual(files["data/remote/master.bin"], self.supplied["remote/master.bin"])
        self.assertIn(b"Stream-Self-Containment: self_contained\n", files["bag-info.txt"])
        for name, raw in self.original.files:
            saved = name if name.startswith("data/") else SOURCE_PREFIX + name + SOURCE_SUFFIX
            self.assertEqual(files[saved], raw)
        m = loads(bag.manifest)
        self.assertEqual(m["input"], self.description)
        self.assertEqual(m["sourceBagManifestHash"], self.original.manifest_hash)
        self.assertFalse(m["hydration"]["archivalAvailabilityEstablished"])
        self.assertFalse(any(m["qualification"].values()))
        self.assertEqual(files["stream-hydration-profile.json"], PROFILE_BYTES)
        self.assertEqual(m["profileHash"], PROFILE_HASH)
        self.assertNotIn(b"  tagmanifest-sha256.txt\n", files["tagmanifest-sha256.txt"])
        self.assertIn(b"tagmanifest-sha256.txt.original", files["tagmanifest-sha256.txt"])

    def test_missing_extra_wrong_length_and_same_length_wrong_bytes_fail(self):
        variants = ({}, self.supplied | {"extra": b"x"}, {"remote/master.bin": b"x"},
                    {"remote/master.bin": b"!" * len(self.supplied["remote/master.bin"])})
        for supplied in variants:
            with self.subTest(supplied=supplied), self.assertRaises(MuseumError):
                hydrate_bag(self.original, supplied)

    def test_each_original_digest_remains_independently_required(self):
        for field in ("sha256", "keccak256"):
            d = deepcopy(self.description)
            row = next(r for r in d["payloads"] if r["delivery"]["kind"] == "fetch")
            # Arweave tx IDs are not raw content digests, so a wrong declared SHA can reach hydration.
            row["delivery"]["uri"] = "ar://" + "A" * 43
            row[field] = keccak256(b"wrong commitment")
            original = build_bag(dumps(d), self.embedded)
            with self.assertRaises(MuseumError): hydrate_bag(original, self.supplied)

    def test_all_tag_payload_and_original_provenance_tampering_refused(self):
        bag = self.hydrate()
        for name in dict(bag.files):
            files = dict(bag.files); files[name] += b"!"
            with self.subTest(name=name), self.assertRaises(MuseumError):
                verify_bag_files(files, bag.manifest_hash)
        files = dict(bag.files); files["fetch.txt"] = b"unexpected active fetch"
        with self.assertRaises(MuseumError): verify_bag_files(files, bag.manifest_hash)

    def test_external_source_binding_and_nonrecursive_profile(self):
        bag = self.hydrate()
        with self.assertRaises(MuseumError): verify_bag_files(bag.files, keccak256(b"wrong"))
        with self.assertRaises(MuseumError): hydrate_bag(bag, self.supplied)
        d, files = description()
        with self.assertRaises(MuseumError): hydrate_bag(build_bag(dumps(d), files), {})
        files = dict(bag.files); m = loads(bag.manifest); m["sourceBagManifestHash"] = keccak256(b"wrong")
        raw = dumps(m); files["stream-manifest.json"] = raw
        with self.assertRaises(MuseumError): verify_bag_files(files, keccak256(raw))

    def test_rehashed_authority_or_input_changes_still_fail(self):
        bag = self.hydrate()
        for field in ("source", "authority", "retrieval"):
            m = loads(bag.manifest)
            if field == "source": m["input"]["sourceMode"] = "externally_admitted_records"
            elif field == "authority": m["qualification"]["sourceAuthorityVerified"] = True
            else: m["hydration"]["networkRetrievalPerformed"] = True
            raw = dumps(m); files = dict(bag.files); files["stream-manifest.json"] = raw
            with self.subTest(field=field), self.assertRaises(MuseumError):
                verify_bag_files(files, keccak256(raw))

    def test_complete_hydrated_bag_enters_ocfl_without_source_promotion(self):
        bag = self.hydrate()
        obj = build_version(bag, created="2026-09-15T00:00:00Z", message="Local synthetic hydration")
        self.assertEqual(verify_object_files(obj.files, obj.inventory_hash), obj)
        m = loads(bag.manifest)
        self.assertEqual(m["input"]["sourceMode"], "synthetic_fixture")
        self.assertEqual(m["input"]["recordChainHeads"], self.description["recordChainHeads"])

    def test_cli_exact_source_is_untouched_and_output_is_not_overwritten(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp); old = root / "original"; provided = root / "provided"; output = root / "hydrated"
            write_tree(self.original.files, old); write_tree(self.supplied, provided)
            saved = read_tree(old)
            args = [sys.executable, "-m", "tools.museum.hydration", str(old), str(provided), str(output),
                    "--source-manifest-hash", self.original.manifest_hash]
            run = subprocess.run(args, capture_output=True, text=True)
            self.assertEqual(run.returncode, 0, run.stderr)
            bag = self.hydrate(); self.assertEqual(verify_bag(output, bag.manifest_hash), bag)
            self.assertEqual(read_tree(old), saved)
            self.assertNotEqual(subprocess.run(args, capture_output=True).returncode, 0)
            self.assertEqual(verify_bag(output, bag.manifest_hash), bag)

    def test_profile_document_and_original_worked_bag_remain_exact(self):
        root = Path(__file__).resolve().parents[2]
        self.assertEqual((root / "schemas/museum/bagit/hydration-profile.json").read_bytes(), PROFILE_BYTES)
        pins = loads((root / "schemas/museum/bagit/worked-pins.json").read_bytes())
        original = verify_bag(root / "schemas/museum/bagit/worked-bag", pins["bagManifestHash"])
        self.assertEqual(loads(original.manifest)["mode"], "stream_bagit_package")

    def test_actual_recorded_package_stays_literal_in_synthetic_transport_fixture(self):
        from .package_recorded import build_recorded_package
        from .test_package_recorded import inputs, pins, ROOT
        recorded = build_recorded_package(inputs(), root=ROOT, disclosure="public", **pins())
        nested = {"semantic/" + name: raw for name, raw in recorded.files}
        nested["semantic/manifest.json"] = recorded.manifest
        d, files = description(nested | self.embedded)
        d["payloads"].append(deepcopy(next(r for r in self.description["payloads"] if r["delivery"]["kind"] == "fetch")))
        d["payloads"].sort(key=lambda r: r["path"])
        d["semanticPackages"] = [{"prefix": "semantic", "manifestHash": recorded.manifest_hash}]
        bag = hydrate_bag(build_bag(dumps(d), files), self.supplied)
        with tempfile.TemporaryDirectory() as tmp:
            output = Path(tmp) / "bag"; write_tree(bag.files, output)
            with patch("socket.socket", side_effect=AssertionError("network use")):
                self.assertEqual(verify_bag(output, bag.manifest_hash), bag)
            for name, raw in recorded.files:
                self.assertEqual((output / "data/semantic" / name).read_bytes(), raw)
        self.assertEqual(loads(bag.manifest, maximum=2097152)["input"]["sourceMode"], "synthetic_fixture")
        nested_manifest = loads(dict(bag.files)["data/semantic/manifest.json"], maximum=2097152)
        self.assertEqual(nested_manifest["mode"], "recorded_account_resource_package")
        self.assertEqual(nested_manifest["environment"], "local_evm_fixture")
        self.assertFalse(any(nested_manifest["claims"].values()))

    def test_shared_directory_spelling_rejected_before_any_write(self):
        for names in (("A/x", "a/y"), ("root/One/x", "root/one/y")):
            d, files = description({n: b"x" for n in names})
            with self.assertRaisesRegex(MuseumError, "casing"):
                build_bag(dumps(d), files)
        d, files = description({"A/x": b"x", "A/y": b"y"})
        bag = build_bag(dumps(d), files)
        with tempfile.TemporaryDirectory() as tmp:
            output = Path(tmp) / "consistent"; write_tree(bag.files, output)
            self.assertEqual(verify_bag(output, bag.manifest_hash), bag)


if __name__ == "__main__":
    unittest.main()

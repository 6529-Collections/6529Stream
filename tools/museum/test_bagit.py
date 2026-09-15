import base64
from copy import deepcopy
from hashlib import sha256
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

from .canonical import MuseumError, dumps, keccak256, loads
from .bagit import PROFILE_BYTES, PROFILE_HASH, ZERO, build_bag, read_tree, verify_bag, verify_bag_files, write_tree
from .ocfl import build_version, verify_object_files


def description(payloads=None, predecessor=ZERO):
    files = {"bundle.json": dumps({"mode": "synthetic_fixture", "work": "example"}),
             "schema.json": dumps({"type": "object"}), "render/script.js": b"draw(1);"}
    if payloads:
        files.update(payloads)
    d = {"mode": "stream_bagit_input", "version": "1", "bundleKind": "OBJECT_DOSSIER_V1",
         "sourceMode": "synthetic_fixture", "disclosure": "public",
         "citation": "eip155:1/erc721:0x" + "11" * 20 + "/42@chain:0x" + "22" * 32,
         "baggingDate": "2026-09-15", "bundleManifest": {"path": "bundle.json", "hash": keccak256(files["bundle.json"])},
         "schema": {"path": "schema.json", "id": keccak256(b"EXPLICIT_SYNTHETIC_BUNDLE"), "hash": keccak256(files["schema.json"])},
         "recordChainHeads": [{"scope": "synthetic:collection", "head": "0x" + "22" * 32}],
         "tool": {"name": "tools.museum.bagit worked example", "version": "1", "sourceHash": keccak256(b"explicit fixture tool reference")},
         "predecessor": predecessor, "payloads": [], "semanticPackages": []}
    for name, raw in sorted(files.items()):
        d["payloads"].append({"path": name, "bytes": str(len(raw)), "sha256": "0x" + sha256(raw).hexdigest(),
            "keccak256": keccak256(raw), "renderCritical": name.startswith("render/"), "delivery": {"kind": "embedded"}})
    return d, files


def remote_description():
    d, files = description({"archive/onchain.json": b"onchain evidence fixture", "archive/external.json": b"external evidence fixture"})
    raw = b"declared remote preservation master"
    cid = "b" + base64.b32encode(bytes([1, 0x55, 0x12, 0x20]) + sha256(raw).digest()).decode().lower().rstrip("=")
    d["payloads"].append({"path": "remote/master.bin", "bytes": str(len(raw)), "sha256": "0x" + sha256(raw).hexdigest(),
        "keccak256": keccak256(raw), "renderCritical": False, "delivery": {"kind": "fetch", "uri": "ipfs://" + cid,
        "archiveEvidence": [{"family": family, "path": path, "hash": keccak256(files[path])} for family, path in
            (("onchain", "archive/onchain.json"), ("permanent_external", "archive/external.json"))]}})
    d["payloads"].sort(key=lambda r: r["path"])
    return d, files


class BagItTests(unittest.TestCase):
    def setUp(self):
        self.d, self.payloads = description()
        self.bag = build_bag(dumps(self.d), self.payloads)

    def test_exact_manifest_tags_original_bytes_and_determinism(self):
        files = dict(self.bag.files)
        self.assertEqual(build_bag(dumps(self.d), self.payloads), self.bag)
        self.assertEqual(verify_bag_files(files, self.bag.manifest_hash), self.bag)
        self.assertEqual(files["data/render/script.js"], self.payloads["render/script.js"])
        self.assertEqual(files["bagit.txt"], b"BagIt-Version: 1.0\nTag-File-Character-Encoding: UTF-8\n")
        self.assertEqual(files["stream-bagit-profile.json"], PROFILE_BYTES)
        self.assertIn(b"Stream-Self-Containment: self_contained\n", files["bag-info.txt"])
        for name, raw in self.payloads.items():
            self.assertIn((sha256(raw).hexdigest() + "  data/" + name + "\n").encode(), files["manifest-sha256.txt"])
            self.assertIn((keccak256(raw)[2:] + "  data/" + name + "\n").encode(), files["manifest-keccak256.txt"])
        self.assertNotIn(b"tagmanifest", files["tagmanifest-sha256.txt"])
        self.assertFalse(any(loads(self.bag.manifest)["qualification"].values()))

    def test_every_payload_and_tag_tamper_is_rejected(self):
        for name in dict(self.bag.files):
            with self.subTest(name=name):
                files = dict(self.bag.files); files[name] += b"!"
                with self.assertRaises(MuseumError):
                    verify_bag_files(files, self.bag.manifest_hash)

    def test_missing_extra_noncanonical_and_wrong_external_commitment(self):
        for variant in (dict(self.bag.files) | {"extra": b"x"}, {k: v for k, v in self.bag.files if k != "data/schema.json"}):
            with self.assertRaises(MuseumError):
                verify_bag_files(variant, self.bag.manifest_hash)
        with self.assertRaises(MuseumError):
            verify_bag_files(self.bag.files, keccak256(b"wrong"))
        with self.assertRaises(MuseumError):
            build_bag(dumps(self.d) + b"\n", self.payloads)

    def test_fetch_is_incomplete_committed_and_never_render_critical(self):
        d, files = remote_description(); bag = build_bag(dumps(d), files)
        self.assertEqual(loads(bag.manifest)["selfContainment"], "fetch_dependent")
        self.assertIn("fetch.txt", dict(bag.files))
        self.assertEqual(verify_bag_files(bag.files, bag.manifest_hash), bag)
        with self.assertRaises(MuseumError):
            build_version(bag, created="2026-09-15T00:00:00Z", message="cannot ingest incomplete")
        next(r for r in d["payloads"] if r["delivery"]["kind"] == "fetch")["renderCritical"] = True
        with self.assertRaisesRegex(MuseumError, "render-critical"):
            build_bag(dumps(d), files)

    def test_fetch_rejects_uncommitted_archives_wrong_cid_and_mutable_uri(self):
        for fault in ("family", "bytes", "uri", "digest"):
            with self.subTest(fault=fault):
                d, files = remote_description(); row = next(r for r in d["payloads"] if r["delivery"]["kind"] == "fetch")
                if fault == "family": row["delivery"]["archiveEvidence"][1]["family"] = "onchain"
                if fault == "bytes": row["delivery"]["archiveEvidence"][1]["hash"] = keccak256(b"wrong")
                if fault == "uri": row["delivery"]["uri"] = "https://example.org/master"
                if fault == "digest": row["sha256"] = keccak256(b"wrong")
                with self.assertRaises(MuseumError): build_bag(dumps(d), files)

    def test_qualified_citation_and_no_restricted_or_invented_flags(self):
        for field, value in (("citation", "eip155:1/erc721:0x" + "11" * 20 + "/42@0x" + "22" * 32),
                             ("disclosure", "restricted"), ("sourceMode", "verified"), ("baggingDate", "2026-02-30")):
            d = deepcopy(self.d); d[field] = value
            with self.assertRaises(MuseumError): build_bag(dumps(d), self.payloads)
        d = deepcopy(self.d); d["sourceAuthorityVerified"] = True
        with self.assertRaises(MuseumError): build_bag(dumps(d), self.payloads)

    def test_paths_collisions_and_bounds(self):
        for path in ("../outside", "CON", "a%0a.txt", "a\\b", "a:b", "x. ", "/absolute", "x\nmalicious", "x?name"):
            with self.subTest(path=path):
                d = deepcopy(self.d); d["payloads"][0]["path"] = path
                with self.assertRaises(MuseumError): build_bag(dumps(d), self.payloads)
        for names in (("A", "a"), ("a", "a/file")):
            d, files = description({n: b"x" for n in names})
            with self.assertRaises(MuseumError): build_bag(dumps(d), files)
        d = deepcopy(self.d); d["payloads"][0]["bytes"] = str(100 * 1024 * 1024)
        with self.assertRaises(MuseumError): build_bag(dumps(d), self.payloads)

    def test_write_no_overwrite_and_cli_entry(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp); payload = root / "payload"; write_tree(self.payloads, payload)
            desc = root / "input.json"; desc.write_bytes(dumps(self.d)); output = root / "bag"
            run = subprocess.run([sys.executable, "-m", "tools.museum.bagit", "build", str(desc), str(payload), str(output),
                "--description-hash", keccak256(desc.read_bytes())], capture_output=True, text=True)
            self.assertEqual(run.returncode, 0, run.stderr)
            self.assertEqual(verify_bag(output, self.bag.manifest_hash), self.bag)
            with self.assertRaises(FileExistsError): write_tree(self.bag.files, output)
            self.assertEqual(read_tree(output), dict(self.bag.files))

    def test_nested_semantic_package_replays_original_bytes_and_source_mode(self):
        from .test_package_v2 import inputs, ROOT
        from .package_v2 import build_fixture_package
        args, pins = inputs()
        original = build_fixture_package(*args, root=ROOT, **pins)
        nested = {"semantic/" + name: raw for name, raw in original.files}
        nested["semantic/manifest.json"] = original.manifest
        d, files = description(nested)
        d["semanticPackages"] = [{"prefix": "semantic", "manifestHash": original.manifest_hash}]
        bag = build_bag(dumps(d), files)
        with tempfile.TemporaryDirectory() as tmp:
            output = Path(tmp) / "bag"; write_tree(bag.files, output)
            self.assertEqual(verify_bag(output, bag.manifest_hash), bag)
            self.assertEqual((output / "data/semantic/manifest.json").read_bytes(), original.manifest)
            d["sourceMode"] = "externally_admitted_records"
            false_bag = build_bag(dumps(d), files)
            wrong = Path(tmp) / "wrong"; write_tree(false_bag.files, wrong)
            with self.assertRaisesRegex(MuseumError, "synthetic"):
                verify_bag(wrong, false_bag.manifest_hash)

    def test_worked_fixture_and_empty_directory_inventory(self):
        fixture = Path(__file__).resolve().parents[2] / "schemas/museum/bagit"
        pins = loads((fixture / "worked-pins.json").read_bytes(), canonical=True)
        raw = (fixture / "worked-input.json").read_bytes()
        self.assertEqual(keccak256(raw), pins["inputHash"])
        self.assertEqual((fixture / "profile.json").read_bytes(), PROFILE_BYTES)
        self.assertEqual(pins["profileHash"], PROFILE_HASH)
        rebuilt = build_bag(raw, read_tree(fixture / "worked-payload"))
        self.assertEqual(verify_bag(fixture / "worked-bag", pins["bagManifestHash"]), rebuilt)
        with tempfile.TemporaryDirectory() as tmp:
            output = Path(tmp) / "bag"; write_tree(rebuilt.files, output)
            (output / "extra-empty").mkdir()
            with self.assertRaisesRegex(MuseumError, "empty"):
                read_tree(output)

    def test_public_state_export_without_optional_token_data_stays_self_contained(self):
        d, files = description(); d["bundleKind"] = "STATE_EXPORT"
        bag = build_bag(dumps(d), files)
        self.assertEqual(loads(bag.manifest)["selfContainment"], "self_contained")
        self.assertNotIn("fetch.txt", dict(bag.files))


class OcflTests(unittest.TestCase):
    def setUp(self):
        d, files = description(); self.bag = build_bag(dumps(d), files)
        self.first = build_version(self.bag, created="2026-09-15T00:00:00Z", message="fixture initial")

    def second(self, **overrides):
        d, files = description({"render/script.js": b"draw(2);"}, self.bag.manifest_hash)
        d.update(overrides)
        bag = build_bag(dumps(d), files)
        return build_version(bag, created="2026-09-15T01:00:00Z", message="fixture successor",
                             previous=self.first, previous_inventory_hash=self.first.inventory_hash)

    def test_two_versions_preserve_prior_bytes_deduplicate_and_restore_bags(self):
        second = self.second(); files = dict(second.files)
        for name, raw in self.first.files:
            if name.startswith("v1/"):
                self.assertEqual(files[name], raw)
        inventory = loads(second.inventory)
        self.assertEqual(inventory["head"], "v2")
        self.assertEqual(inventory["id"], loads(self.bag.manifest)["input"]["citation"].split("@")[0])
        digest = sha256(b"draw(1);").hexdigest()
        self.assertEqual(inventory["manifest"][digest], ["v1/content/" + digest])
        self.assertEqual(verify_object_files(second.files, second.inventory_hash), second)

    def test_wrong_predecessor_identity_family_or_time_is_rejected(self):
        for changes in ({"predecessor": keccak256(b"wrong")}, {"bundleKind": "STATE_EXPORT"},
                        {"citation": "eip155:1/erc721:0x" + "11" * 20 + "/43@chain:0x" + "22" * 32}):
            with self.assertRaises(MuseumError): self.second(**changes)
        d, files = description(predecessor=self.bag.manifest_hash)
        for created in ("2026-09-15T00:00:00Z", "2026-09-15T24:00:00Z", "2026-09-15"):
            with self.assertRaises(MuseumError):
                build_version(build_bag(dumps(d), files), created=created, message="bad",
                              previous=self.first, previous_inventory_hash=self.first.inventory_hash)

    def test_external_inventory_commitment_and_content_tampering(self):
        with self.assertRaises(MuseumError): verify_object_files(self.first.files, keccak256(b"wrong"))
        for name in dict(self.first.files):
            with self.subTest(name=name):
                files = dict(self.first.files); files[name] += b"!"
                with self.assertRaises(MuseumError): verify_object_files(files, self.first.inventory_hash)

    def test_rehashed_historical_rewrite_and_orphan_file_refused(self):
        second = self.second(); files = dict(second.files)
        old = loads(files["v1/inventory.json"]); old["versions"]["v1"]["message"] = "rewritten"
        raw = dumps(old); files["v1/inventory.json"] = raw
        files["v1/inventory.json.sha256"] = (sha256(raw).hexdigest() + "  inventory.json\n").encode()
        with self.assertRaises(MuseumError): verify_object_files(files, second.inventory_hash)
        files = dict(second.files); files["v2/content/orphan"] = b"undeclared"
        with self.assertRaises(MuseumError): verify_object_files(files, second.inventory_hash)

    def test_new_object_tree_never_mutates_previous_and_cli_verifies(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp) / "object"; write_tree(self.first.files, root)
            run = subprocess.run([sys.executable, "-m", "tools.museum.ocfl", "verify", str(root), "--inventory-hash", self.first.inventory_hash], capture_output=True, text=True)
            self.assertEqual(run.returncode, 0, run.stderr)
            before = read_tree(root); self.second()
            self.assertEqual(read_tree(root), before)


if __name__ == "__main__":
    unittest.main()

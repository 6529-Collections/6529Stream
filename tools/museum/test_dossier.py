"""Actual retained collection source to complete dossier and offline OCFL replay."""
from copy import deepcopy
from hashlib import sha256
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch

from .archive_fixture import read, rebuild
from .bagit import MAX_MANIFEST, read_tree, verify_bag, verify_bag_files, write_tree
from .canonical import MuseumError, dumps, keccak256, loads, subject_id
from .current_media_inputs import image_bytes
from .dossier import (CLAIMS, MANIFEST, SCHEMA_BYTES, _assemble, _source_index,
    _validate_source_snapshot, build_dossier, inspect_export, verify_dossier, verify_ocfl)
from .dossier_bagit import build_bag, external_identifier, identity
from .ocfl import build_version, verify_object_files
from .package import write_package

ROOT = Path(__file__).resolve().parents[2]
FIXTURE = ROOT / "schemas/museum/archival-export/local-fixture"
PIN = "0x92d26a64ba30e5b5827a323668e29a2f76264b286b8068615334b48781c2e518"


class DossierTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.temp = tempfile.TemporaryDirectory(); cls.root = Path(cls.temp.name)
        with patch("socket.socket", side_effect=AssertionError("dossier used network")):
            cls.originals, _ = read(FIXTURE, PIN)
            cls.export, cls.publication = rebuild(cls.originals)
            cls.source = cls.root / "export"; write_package(cls.export, cls.source)
            raw = image_bytes(); cls.supply = {sha256(raw).hexdigest() + ".bin": raw}
            cls.bag = build_dossier(cls.source, cls.export.manifest_hash, cls.supply, bagging_date="2026-09-16",
                archive_raw=cls.originals["archive-publication.json"],
                archive_hash=keccak256(cls.originals["archive-publication.json"]))
        cls.bag_path = cls.root / "bag"; write_tree(cls.bag.files, cls.bag_path)
        cls.files = dict(cls.bag.files)
        cls.description = loads(cls.bag.manifest, maximum=MAX_MANIFEST)["input"]

    @classmethod
    def tearDownClass(cls): cls.temp.cleanup()

    def test_actual_source_originals_media_and_archive_remain_separate(self):
        for name, raw in self.export.files:
            self.assertEqual(self.files["data/semantic/" + name], raw)
        self.assertEqual(self.files["data/semantic/manifest.json"], self.export.manifest)
        self.assertEqual(self.files["data/publication/evidence.json"], self.originals["archive-publication.json"])
        self.assertEqual(self.files["data/media/" + next(iter(self.supply))], image_bytes())
        manifest = loads(self.files["data/" + MANIFEST], canonical=True)
        self.assertEqual(manifest["claims"], CLAIMS)
        self.assertIsNone(manifest["scope"]["tokenId"])
        self.assertEqual(manifest["scope"]["canonicalCitation"], "")
        self.assertFalse(manifest["claims"]["fullObjectDossierConformance"])
        self.assertFalse(manifest["claims"]["publisherAuthenticated"])
        self.assertEqual(self.description["bundleKind"], "MUSEUM_SEMANTIC_EVIDENCE_DOSSIER_V1")
        self.assertNotIn("fetch.txt", self.files)
        media = loads(self.files["data/dossier/media-index.json"], maximum=MAX_MANIFEST)
        self.assertEqual(len(media), 1)
        self.assertEqual(media[0]["byteLength"], "70")
        self.assertTrue(media[0]["renderCritical"])
        self.assertIn(media[0]["path"], {row["path"] for row in self.description["payloads"] if row["renderCritical"]})

    def test_full_offline_replay_and_generic_bag_dispatch(self):
        with patch("socket.socket", side_effect=AssertionError("verification used network")):
            self.assertEqual(verify_bag(self.bag_path, self.bag.manifest_hash), self.bag)

    def test_missing_required_media_is_explicit_and_blocks_build(self):
        # Source replay is covered end-to-end above; avoid repeating it for each packaging fault.
        with patch("tools.museum.dossier.verify_export", return_value=self.export):
            report = inspect_export(self.source, self.export.manifest_hash)
            self.assertEqual(report["missingMedia"], list(self.supply))
            self.assertFalse(report["readyToPackage"])
            complete = inspect_export(self.source, self.export.manifest_hash, self.supply)
            self.assertTrue(complete["readyToPackage"])
            with self.assertRaisesRegex(MuseumError, "missing"):
                build_dossier(self.source, self.export.manifest_hash, {}, bagging_date="2026-09-16")
            with self.assertRaises(MuseumError):
                inspect_export(self.source, self.export.manifest_hash, {"unrequested.bin": b"x"})

    def test_archive_pin_pair_and_wrong_source_evidence_are_rejected(self):
        for raw, pin in ((self.originals["archive-publication.json"], None),
                         (None, keccak256(b"wrong")), (self.originals["archive-publication.json"], keccak256(b"wrong"))):
            with self.assertRaises(MuseumError):
                _assemble(self.export, self.supply, bagging_date="2026-09-16", archive_raw=raw, archive_hash=pin)

    def test_scope_identity_is_exact_and_token_identity_is_never_invented(self):
        scope = deepcopy(self.description["scope"])
        expected = "urn:6529stream:subject:" + scope["anchorSubject"]["subjectId"]
        self.assertEqual(identity(scope, external_identifier(scope)), expected)
        scope["tokenId"] = "71"
        with self.assertRaises(MuseumError): identity(scope, external_identifier(scope))
        # Identity syntax only: this does not manufacture a token source capture.
        scope["anchorSubject"] = {"kind": "token", "subjectId": subject_id("token", scope["chainId"], scope["core"], scope["collectionId"], token_id="71")}
        scope["canonicalCitation"] = "eip155:" + scope["chainId"] + "/erc721:" + scope["core"] + "/71@chain:" + scope["recordHeads"][0]["recordChainHash"]
        self.assertEqual(identity(scope, external_identifier(scope)), scope["canonicalCitation"].split("@")[0])
        scope["anchorSubject"]["subjectId"] = self.description["scope"]["anchorSubject"]["subjectId"]
        with self.assertRaises(MuseumError): identity(scope, external_identifier(scope))

    def test_rehashed_media_index_does_not_pass_semantic_reconstruction(self):
        payloads = {name[5:]: raw for name, raw in self.bag.files if name.startswith("data/")}
        media = loads(payloads["dossier/media-index.json"], maximum=MAX_MANIFEST)
        media[0]["renderCritical"] = False
        payloads["dossier/media-index.json"] = dumps(media)
        d = deepcopy(self.description)
        for row in d["payloads"]:
            raw = payloads[row["path"]]
            row.update(bytes=str(len(raw)), sha256="0x" + sha256(raw).hexdigest(), keccak256=keccak256(raw))
        forged = build_bag(dumps(d), payloads)
        self.assertEqual(verify_bag_files(forged.files, forged.manifest_hash), forged)
        output = self.root / "forged-media"; write_tree(forged.files, output)
        with self.assertRaisesRegex(MuseumError, "reconstruction differs"):
            verify_dossier(output, forged.manifest_hash)

    def test_ocfl_byte_transport_and_offline_dossier_replay(self):
        first = build_version(self.bag, created="2026-09-16T00:00:00Z", message="Actual collection dossier")
        self.assertEqual(loads(first.inventory, maximum=MAX_MANIFEST)["id"], self.description["externalIdentifier"].split("@")[0])
        output = self.root / "ocfl"; write_tree(first.files, output)
        # A successor is a new immutable transport version, without a source-finality claim.
        snapshot = {name[5:]: raw for name, raw in self.bag.files if name.startswith("data/tool/")}
        snapshot["tool/dossier.py.txt"] += b"\n# Later compatible implementation revision.\n"
        snapshot["tool/source-index.json"] = _source_index({name: raw for name, raw in snapshot.items() if name.endswith(".txt")})
        second_bag = _assemble(self.export, self.supply, bagging_date="2026-09-17", predecessor=self.bag.manifest_hash,
            tool_snapshot=snapshot)
        second = build_version(second_bag, created="2026-09-17T00:00:00Z", message="Same bounded selection, no publication attachment",
            previous=first, previous_inventory_hash=first.inventory_hash)
        self.assertEqual(verify_object_files(second.files, second.inventory_hash), second)
        for name, raw in first.files:
            if name.startswith("v1/"): self.assertEqual(dict(second.files)[name], raw)
        self.assertEqual(read_tree(output), dict(first.files))
        second_output = self.root / "ocfl-v2"; write_tree(second.files, second_output)
        with patch("socket.socket", side_effect=AssertionError("OCFL verification used network")):
            self.assertEqual(verify_ocfl(second_output, second.inventory_hash), second)

    def test_source_snapshot_index_is_closed_inert_and_committed(self):
        original = {name[5:]: raw for name, raw in self.bag.files if name.startswith("data/tool/")}
        self.assertEqual(_validate_source_snapshot(original)[1], self.description["tool"]["sourceHash"])
        for mutate in (lambda f: f.update({"tool/extra.txt": b"x"}),
                       lambda f: f.update({"tool/dossier.py.txt": b"altered"}),
                       lambda f: f.update({"tool/dossier.py.txt": b"x\r\n"})):
            files = dict(original); mutate(files)
            with self.assertRaises(MuseumError): _validate_source_snapshot(files)

    def test_definitions_and_cli_options(self):
        self.assertEqual((ROOT / "schemas/museum/dossier" / "STREAM_MUSEUM_SEMANTIC_EVIDENCE_DOSSIER_V1.json").read_bytes(), SCHEMA_BYTES)
        run = subprocess.run([sys.executable, "-m", "tools.museum.dossier", "build", "--help"], capture_output=True, text=True)
        self.assertEqual(run.returncode, 0, run.stderr)
        self.assertIn("--media-directory", run.stdout)
        self.assertIn("--archive-evidence-hash", run.stdout)


if __name__ == "__main__": unittest.main()

"""Synthetic supplementary dossier controls; no actual-chain acceptance claim."""
import copy
import io
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

from .canonical import MuseumError, dumps, keccak256, loads as read_json
from . import owner_notice_dossier as dossier
from .owner_notice_evidence import OwnerNoticeEvidenceSource, PROFILE_BYTES as NOTICE_PROFILE_BYTES
from .owner_notice_semantics import OwnerNoticeSemanticSource, PROFILE_BYTES
from .test_owner_notice_semantics import Fixture, Transport
from .test_owner_notice_evidence import Fixture as EvidenceFixture


def loads(raw):
    return read_json(raw, maximum=dossier.MAX_BYTES)


def rehash(files):
    """A malicious packager can rehash files but cannot skip semantic rebuild."""
    manifest = loads(files["manifest.json"])
    manifest["files"] = [{"path": path, "bytes": str(len(raw)), "hash": keccak256(raw)}
        for path, raw in sorted(files.items()) if path != "manifest.json"]
    files["manifest.json"] = dumps(manifest)
    return keccak256(files["manifest.json"])


class OwnerNoticeDossierTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.fixture = Fixture()
        cls.source = cls.fixture.semantic()
        cls.files = dossier.build_files(cls.source)

    def test_exact_originals_and_all_supported_leaves_are_retained(self):
        files = self.files
        self.assertEqual(files["sources/owner/snapshot.json"], self.source.catalogue.snapshot())
        self.assertEqual(files["sources/owner/transcript.json"], self.source.catalogue.transcript())
        self.assertEqual(files["semantics/profile.json"], PROFILE_BYTES)
        value = loads(files["dossier.json"])
        self.assertEqual(len(value["ownerStatements"]), 6)
        self.assertEqual(value["noticeActionEvidence"], {"status": "not_captured", "original": None})
        self.assertEqual(value["currentDesignation"]["status"], "not_captured")
        index = loads(files["graph/index.json"])
        self.assertEqual(len(index["resources"]), 5)
        provenance = loads(files["graph/provenance.json"])
        coverage = loads(files["graph/source-coverage.json"])
        supported = {row["source"]["recordHash"]: row for row in value["ownerStatements"] if row["status"] == "supported"}
        for resource in index["resources"]:
            node = loads(files[resource["path"]])
            original = supported[resource["source"]["recordHash"]]
            self.assertEqual(node["type"], "LinguisticObject")
            self.assertEqual(node["content"].encode(), bytes.fromhex(original["payloadHex"][2:]))
            self.assertEqual({row["path"]: row["value"] for row in provenance if row["entity"] == node["id"]},
                dict(dossier.leaves(node)))
            self.assertEqual({row["sourcePath"]: row["value"] for row in coverage if row["source"] == original["source"]},
                dict(dossier.leaves(original["value"])))
        self.assertTrue(any(row["sourcePath"] == "/evidenceReferences" and row["value"] == [] for row in coverage))
        self.assertFalse(value["claims"]["institutionalAssentProven"])

    def test_closed_offline_replay_needs_no_network(self):
        with patch("socket.socket", side_effect=AssertionError("network forbidden")):
            report = dossier.verify_files(self.files, keccak256(self.files["manifest.json"]))
        self.assertEqual(report["supportedStatementCount"], "5")
        self.assertEqual(report["unsupportedStatementCount"], "1")
        self.assertEqual(report["mode"], "synthetic_fixture")
        self.assertFalse(report["claims"]["actualChainAcceptance"])

    def test_external_pin_inventory_missing_and_extra_bytes_reject(self):
        with self.assertRaisesRegex(MuseumError, "external manifest"):
            dossier.verify_files(self.files, "0x" + "11" * 32)
        for change in ("extra", "removed", "changed", "duplicate"):
            files = dict(self.files)
            if change == "extra": files["unlisted.json"] = b"{}"
            elif change == "removed": del files["semantics/profile.json"]
            elif change == "changed": files["semantics/profile.json"] += b" "
            else:
                manifest = loads(files["manifest.json"])
                manifest["files"][1] = manifest["files"][0]
                files["manifest.json"] = dumps(manifest)
            with self.subTest(change=change), self.assertRaises(MuseumError):
                dossier.verify_files(files, keccak256(files["manifest.json"]))

    def test_rehashed_projection_profiles_and_claims_still_need_exact_rebuild(self):
        paths = [next(path for path in self.files if path.startswith("graph/resources/")),
            "graph/source-coverage.json", "graph/provenance.json", "report.json", "dossier.json", "semantics/profile.json"]
        for path in paths:
            files = dict(self.files)
            value = loads(files[path])
            if isinstance(value, list): value = value[1:]
            elif path.startswith("graph/resources/"): value["content"] = "invented institutional assent"
            elif path == "semantics/profile.json": value["claims"]["institutionalAssentProven"] = True
            else: value["claims"]["recipientReceiptProven"] = True
            files[path] = dumps(value)
            with self.subTest(path=path), self.assertRaisesRegex(MuseumError, "reconstruct exactly"):
                dossier.verify_files(files, rehash(files))

    def test_rehashed_semantic_and_original_snapshot_tampering_reject(self):
        for path in ("semantics/snapshot.json", "sources/owner/snapshot.json"):
            files = dict(self.files); value = loads(files[path])
            value["claims"] = {"institutionalAssentProven": True}
            files[path] = dumps(value)
            with self.subTest(path=path), self.assertRaisesRegex(MuseumError, "replay differs"):
                dossier.verify_files(files, rehash(files))

    def test_rehashed_required_component_omission_and_false_flags_reject(self):
        for change in ("semantic_omission", "ownership_flag", "extra_independent", "notice_flag"):
            files = dict(self.files); manifest = loads(files["manifest.json"])
            if change == "semantic_omission": del files["semantics/transcript.json"]
            elif change == "ownership_flag": manifest["components"]["ownership"] = True
            elif change == "extra_independent": manifest["components"]["independentCount"] = "1"
            else: manifest["components"]["notices"] = True
            files["manifest.json"] = dumps(manifest)
            with self.subTest(change=change), self.assertRaisesRegex(MuseumError, "component source files missing"):
                dossier.verify_files(files, rehash(files))

    def test_ownership_and_independent_voice_rebuild_as_separate_sources(self):
        fixture = Fixture()
        independent = fixture.independent()
        source = OwnerNoticeSemanticSource(fixture.catalogue(), Transport(fixture.responses),
            ownership=fixture.ownership(), independents=[independent])
        files = dossier.build_files(source)
        with patch("socket.socket", side_effect=AssertionError("network forbidden")):
            report = dossier.verify_files(files, keccak256(files["manifest.json"]))
        self.assertEqual(report["independentStatementCount"], "1")
        value = loads(files["dossier.json"])
        self.assertEqual(value["currentDesignation"]["recordHash"], fixture.hashes["aCurrent"])
        self.assertFalse(value["independentStatements"][0]["authority"]["ownerStandingAtPublication"])
        self.assertEqual(len(value["ownerStatements"]), 6)
        self.assertIn("sources/independent-0/anchor.json", files)
        self.assertEqual(len(loads(files["graph/index.json"])["resources"]), 6)

    def test_burn_preserves_original_statements_without_current_notice_target(self):
        fixture = Fixture(burned=True)
        files = dossier.build_files(fixture.semantic(ownership=fixture.ownership()))
        dossier.verify_files(files, keccak256(files["manifest.json"]))
        value = loads(files["dossier.json"])
        self.assertEqual(value["currentDesignation"]["status"], "burned_no_current_owner")
        self.assertEqual(len(value["ownerStatements"]), 6)

    def test_native_evidence_package_preserves_uninterpreted_originals_and_replays_execution(self):
        # Native evidence fixture uses deliberately unsupported schema commitments.
        # It proves exact native wire replay, never semantic or actual-chain acceptance.
        fixture = EvidenceFixture(executed=True)
        catalogue = fixture.source()
        semantic = OwnerNoticeSemanticSource(catalogue, Transport(fixture.responses))
        notices = OwnerNoticeEvidenceSource(catalogue, Transport(fixture.responses), provenance=catalogue.provenance)
        files = dossier.build_files(semantic, notices=notices)
        self.assertEqual(files["notices/profile.json"], NOTICE_PROFILE_BYTES)
        value = loads(files["dossier.json"])
        self.assertTrue(all(row["status"] == "unsupported" for row in value["ownerStatements"]))
        self.assertEqual(value["noticeActionEvidence"]["original"]["actions"][0]["execution"]["state"], "executed_native_receipt")
        with patch("socket.socket", side_effect=AssertionError("network forbidden")):
            report = dossier.verify_files(files, keccak256(files["manifest.json"]))
        self.assertEqual(report["noticeActionEvidence"], "captured")
        self.assertEqual(report["supportedStatementCount"], "0")
        tampered = dict(files)
        value = loads(tampered["notices/snapshot.json"])
        value["claims"]["institutionalAssentProven"] = True
        tampered["notices/snapshot.json"] = dumps(value)
        with self.assertRaisesRegex(MuseumError, "action replay differs"):
            dossier.verify_files(tampered, rehash(tampered))

    def test_evidence_from_another_catalogue_cannot_be_joined(self):
        fixture = EvidenceFixture()
        semantic = OwnerNoticeSemanticSource(fixture.source(), Transport(fixture.responses))
        with self.assertRaisesRegex(MuseumError, "same original owner catalogue"):
            dossier.build_files(semantic, notices=fixture.evidence_source())

    def test_write_and_verify_cli_are_offline_and_refuse_overwrite(self):
        with tempfile.TemporaryDirectory() as directory:
            destination = Path(directory) / "dossier"
            result = dossier.write(self.source, destination)
            self.assertEqual(result["manifestHash"], keccak256(self.files["manifest.json"]))
            with patch("socket.socket", side_effect=AssertionError("network forbidden")), \
                    patch("sys.argv", ["owner_notice_dossier", "verify", str(destination), "--manifest-hash", result["manifestHash"]]), \
                    patch("sys.stdout", new_callable=io.StringIO) as output:
                dossier.main()
            self.assertEqual(loads(output.getvalue().encode())["supportedStatementCount"], "5")
            with self.assertRaises((MuseumError, FileExistsError)):
                dossier.write(self.source, destination)

    def test_capture_input_replays_all_external_source_commitments_first(self):
        with tempfile.TemporaryDirectory() as directory:
            row = {"provenance": "synthetic_fixture"}
            for name in ("anchor", "snapshot", "transcript"):
                raw = self.files["sources/owner/" + name + ".json"]
                path = Path(directory) / (name + ".json"); path.write_bytes(raw)
                row[name + "Path"], row[name + "Hash"] = str(path), keccak256(raw)
            with patch("socket.socket", side_effect=AssertionError("network forbidden")):
                source = dossier._input_source(row, dossier.OwnerCatalogSource)
            self.assertEqual(source.snapshot(), self.source.catalogue.snapshot())
            for name in ("anchor", "snapshot", "transcript"):
                changed = copy.deepcopy(row); changed[name + "Hash"] = "0x" + "12" * 32
                with self.subTest(name=name), self.assertRaisesRegex(MuseumError, "external source pin"):
                    dossier._input_source(changed, dossier.OwnerCatalogSource)


if __name__ == "__main__":
    unittest.main()

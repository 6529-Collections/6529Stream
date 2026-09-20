"""Real synthetic twelve-source replay into V7, preserving all title-V5 originals."""
import copy
from contextlib import redirect_stdout
import io
from pathlib import Path
from tempfile import TemporaryDirectory
import unittest
from unittest.mock import patch

from ..metadata import acquisition_packet_v5 as v5
from ..metadata import acquisition_packet_v7 as v7
from . import acquisition_finality_v7 as assembly
from .bagit import read_tree, write_tree
from .canonical import MuseumError, dumps, keccak256, loads
from .scoped_static_finality_fixture import ScopedStaticFinalityFixture
from .test_public_scoped_finality_capture import repin


class FinalityV7AssemblyTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.fixture = ScopedStaticFinalityFixture()
        cls.inputs = cls.fixture.scoped_inputs()
        cls.result = cls.compose(cls.inputs)

    @staticmethod
    def compose(inputs):
        return assembly.compose(*sum(([row.files, row.manifest_hash] for row in inputs), []), disclosure="public")

    def packet(self): return v7.validate(dict(self.result.files)[assembly.PACKET_PATH])

    def test_v7_preserves_all_original_fields_files_and_capture_bytes(self):
        files = dict(self.result.files)
        for path, raw in self.inputs[0].files:
            self.assertEqual(files[assembly.ORIGINAL_MANIFEST if path == "manifest.json" else path], raw)
        for path, raw in self.inputs[1].files:
            self.assertEqual(files[assembly.FINALITY_PREFIX + path], raw)
        old = v5.validate(files[assembly.previous.PACKET_PATH]); new = self.packet()
        self.assertEqual(set(old), set(new))
        self.assertEqual(new["schema"], v7.PACKET)
        self.assertEqual(new["version"], 7)
        for key in old.keys() - {"schema", "version", "finality", "contentRootProof", "citation"}:
            self.assertEqual(new[key], old[key], key)
        self.assertEqual(keccak256(files[assembly.previous.PACKET_PATH]), self.result.report["originalPacketHash"])
        self.assertEqual(keccak256(files[assembly.PACKET_PATH]), self.result.report["packetHash"])

    def test_scoped_native_proof_and_original_fin_citation_remain_paired(self):
        packet = self.packet()
        self.assertEqual(packet["finality"]["kind"], "native_scoped_static_finality")
        self.assertEqual(packet["contentRootProof"]["kind"], "native_scoped_token_content_proof")
        fragment = packet["finality"]["fragment"]
        self.assertEqual(packet["citation"]["qualifier"], {"kind": "fin", "hash": fragment["bundle"]["finality"]["record"][2]})
        self.assertEqual(fragment["historicalCoreFacts"]["status"], "hash_only")
        self.assertIsNone(fragment["historicalCoreFacts"]["preimage"])
        self.assertFalse(fragment["claims"]["completeAuthority"])
        self.assertEqual(packet["contentRootProof"]["scope"], fragment["bundle"]["scope"])

    def test_twelve_reconciled_sources_include_original_transaction_rows(self):
        report, files = self.result.report, dict(self.result.files)
        joined = report["sourceReconciliation"]
        self.assertEqual(len(joined["inputs"]), 12)
        owner = assembly.previous.ACCESSION_PREFIX + "sources/owner/anchor.json"
        self.assertNotIn("collectionId", loads(files[owner]))
        self.assertEqual(joined["inputs"][assembly.FINALITY_PREFIX + "source/"]["anchorHash"],
            keccak256(files[assembly.FINALITY_PREFIX + "source/anchor.json"]))
        self.assertEqual(joined["counts"]["originalTransactionRows"], "2")
        self.assertEqual(joined["counts"]["distinctOriginalTransactions"], "2")
        self.assertFalse(joined["counts"]["transactionSignaturesVerified"])

    def test_release_season_and_burned_token_export_real_replayed_membership(self):
        for kind, count, burned in ((1, 1, True), (2, 3, False), (3, 30, False)):
            with self.subTest(scope=kind, burned=burned):
                fixture = ScopedStaticFinalityFixture(scope_type=kind, count=count, burned=burned)
                result = self.compose(fixture.scoped_inputs())
                packet = v7.validate(dict(result.files)[assembly.PACKET_PATH])
                self.assertEqual(packet["contentRootProof"]["scope"][0], str(kind))
                self.assertEqual(packet["contentRootProof"]["leafCount"], str(count))
                self.assertEqual(packet["sourceState"]["burned"], burned)
                self.assertEqual(packet["ownershipProvenance"]["currentOwner"] == v7.ZERO_ADDRESS, burned)

    def test_independently_replayed_capture_conflicting_header_or_unrelated_receipt_rejects(self):
        for mode in ("header", "unrelated_log"):
            fixture = copy.deepcopy(self.fixture)
            if mode == "header":
                # A different provider field at the same canonical hash passes
                # this capture alone but cannot replace the earlier originals.
                fixture.blocks[fixture.scoped_anchor["blockHash"]]["extraData"] = "0x1234"
            else:
                own = {(r["log"]["transactionHash"], r["log"]["logIndex"]) for r in fixture.scoped_events}
                selected = {r["log"]["transactionHash"] for r in fixture.scoped_events}
                log = next(log for tx, receipt in fixture.receipts.items() if tx in selected
                    for log in receipt["logs"] if (tx, log["logIndex"]) not in own)
                log["data"] = "0x1234"
            with self.subTest(mode=mode):
                captured = fixture.scoped_capture()
                # Establish independent exact replay before exercising the
                # cross-source contradiction, with no mocked verification.
                self.assertEqual(assembly.finality.verify(captured.files, captured.manifest_hash).files, captured.files)
                with self.assertRaisesRegex(MuseumError, "RPC outcome|header .*differs|receipt .*differs"):
                    assembly.compose(self.inputs[0].files, self.inputs[0].manifest_hash,
                        captured.files, captured.manifest_hash, disclosure="public")

    def test_nineteen_items_keep_partial_source_coverage_and_refuse_complete_packet(self):
        report = self.result.report
        self.assertEqual([row["item"] for row in report["items"]], [str(i) for i in range(1, 20)])
        self.assertEqual(report["items"][2]["sourceCoverage"], "partial")
        self.assertIn("3", report["unresolvedSourceItems"])
        self.assertEqual(report["items"][8]["sourceCoverage"], "derived_within_source_profile")
        self.assertEqual(report["sourceProvenance"], "synthetic_fixture")
        for key in ("sourceCoverageComplete", "sourceConsensusVerified", "actualChainAcceptance", "completeAuthority", "completeCanonicalPacket"):
            self.assertFalse(report["claims"][key])
        with self.assertRaisesRegex(MuseumError, "unresolved items"):
            assembly.complete_packet(self.result.files, self.result.manifest_hash)

    def test_offline_replay_export_and_common_dispatch(self):
        from .package_v2 import verify_package
        with patch("socket.socket", side_effect=AssertionError("offline only")):
            self.assertEqual(assembly.verify(self.result.files, self.result.manifest_hash).files, self.result.files)
            self.assertEqual(assembly.export_packet(self.result.files, self.result.manifest_hash), dict(self.result.files)[assembly.PACKET_PATH])
            with TemporaryDirectory() as temporary:
                path = Path(temporary) / "assembly"; write_tree(dict(self.result.files), path)
                self.assertEqual(verify_package(path, self.result.manifest_hash).files, self.result.files)

    def test_rehashed_derivatives_cannot_override_original_reconstruction(self):
        for path in (assembly.PACKET_PATH, "finality/assembly.json", "extra.json"):
            with self.subTest(path=path):
                files = dict(self.result.files)
                value = {} if path not in files else loads(files[path], maximum=assembly.MAX_BYTES)
                value["completeAuthority"] = True; files[path] = dumps(value)
                files, digest = repin(files)
                with self.assertRaisesRegex(MuseumError, "reconstruction differs"): assembly.verify(files, digest)

    def test_manifest_claims_mode_extra_key_and_external_pin_reject(self):
        wrong = keccak256(b"wrong")
        with self.assertRaisesRegex(MuseumError, "external manifest pin"): assembly.verify(self.result.files, wrong)
        for key, value in (("mode", "acquisition_finality_v6_assembly"), ("callerOverride", True), ("claims", {})):
            files = dict(self.result.files); manifest = loads(files["manifest.json"], maximum=1048576)
            manifest[key] = value; files["manifest.json"] = dumps(manifest)
            with self.subTest(key=key), self.assertRaisesRegex(MuseumError, "closed manifest"):
                assembly.verify(files, keccak256(files["manifest.json"]))
        with self.assertRaisesRegex(MuseumError, "manifest pin"):
            assembly.compose(self.inputs[0].files, wrong, self.inputs[1].files, self.inputs[1].manifest_hash, disclosure="public")

    def test_schema_rejects_scoped_pair_citation_and_unrelated_group_contradictions(self):
        original = self.packet()
        for mode in ("proof_kind", "proof_hash", "citation", "entropy", "rights"):
            packet = copy.deepcopy(original)
            if mode == "proof_kind": packet["contentRootProof"]["kind"] = "native_token_content_proof"
            elif mode == "proof_hash": packet["contentRootProof"]["root"] = keccak256(b"wrong root")
            elif mode == "citation":
                packet["citation"]["qualifier"]["hash"] = keccak256(b"wrong finality")
                packet["citation"]["qualified"] = packet["citation"]["work"] + "@fin:" + packet["citation"]["qualifier"]["hash"]
            elif mode == "entropy": packet["entropy"]["leafHash"] = keccak256(b"wrong entropy")
            else: packet["rights"]["completeness"] = "absent"
            with self.subTest(mode=mode), self.assertRaises(MuseumError): v7.validate(dumps(packet))

    def test_disclosure_precedes_input_directory_reads(self):
        class Unreadable:
            def __iter__(self): raise AssertionError("read before disclosure")
        wrong = keccak256(b"wrong")
        with self.assertRaisesRegex(MuseumError, "public disclosure"):
            assembly.compose(Unreadable(), wrong, Unreadable(), wrong, disclosure="restricted")
        with patch.object(assembly, "read_tree", side_effect=AssertionError("read before disclosure")):
            with self.assertRaisesRegex(MuseumError, "public disclosure"):
                assembly.main(["assemble", "--packet", "missing", "--packet-hash", wrong,
                    "--finality", "missing", "--finality-hash", wrong, "--disclosure", "private", "--output", "new"])

    def test_cli_assemble_verify_export_and_no_overwrite(self):
        with TemporaryDirectory() as temporary, patch("socket.socket", side_effect=AssertionError("offline only")):
            root = Path(temporary); paths = (root / "title", root / "finality")
            for path, item in zip(paths, self.inputs): write_tree(dict(item.files), path)
            output = root / "v7"
            args = ["assemble", "--packet", str(paths[0]), "--packet-hash", self.inputs[0].manifest_hash,
                "--finality", str(paths[1]), "--finality-hash", self.inputs[1].manifest_hash,
                "--disclosure", "public", "--output", str(output)]
            with redirect_stdout(io.StringIO()):
                assembly.main(args)
                assembly.main(["verify", str(output), "--manifest-hash", self.result.manifest_hash])
            self.assertEqual(read_tree(output), dict(self.result.files))
            stdout = io.StringIO()
            with redirect_stdout(stdout): assembly.main(["export-packet", str(output), "--manifest-hash", self.result.manifest_hash])
            self.assertEqual(stdout.getvalue().encode("utf-8"), dict(self.result.files)[assembly.PACKET_PATH])
            with self.assertRaises((MuseumError, FileExistsError)): assembly.main(args)
            self.assertEqual(read_tree(output), dict(self.result.files))


if __name__ == "__main__": unittest.main()

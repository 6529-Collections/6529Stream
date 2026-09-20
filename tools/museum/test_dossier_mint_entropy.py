"""Offline package joins; wrapper stubs are explicit, reader vectors are synthetic."""
from contextlib import ExitStack
from copy import deepcopy
from pathlib import Path
from tempfile import TemporaryDirectory
import unittest
from unittest.mock import patch

from . import dossier_mint_entropy as package
from .bagit import write_tree
from .canonical import MuseumError, dumps, keccak256, loads
from .chain_abi import encode
from . import test_dossier_gather as fixtures


class MintEntropyPackageTests(unittest.TestCase):
    def setUp(self):
        self.base = fixtures.GatherWrapperTests(); self.base.setUp()
        self.tools = {"tool/" + p + ".txt": b"raise RuntimeError('must stay inert')\n" for p in package.TOOL_NAMES}
        self.mint = {"mint": {"identity": {"tokenId": "71", "collectionId": "1", "collectionSerial": "1",
            "lifecycle": "2", "burned": False, "coordinatorAtMint": "0x" + "11" * 20},
            "mintCommitment": keccak256(b"mint"), "tokenData": {"keccak256": keccak256(b"token data")}},
            "sourceBlockViews": {"coreFacts": self.base.ref["coreFacts"]}}

    def context(self):
        stack = ExitStack()
        stack.enter_context(self.base.context())
        stack.enter_context(patch.object(package, "_originals", return_value=self.base.originals))
        stack.enter_context(patch("tools.museum.token_mint_evidence.extract",
            return_value=({"mint/original-token-data.bin": b"token data"}, self.mint)))
        return stack

    def build(self):
        original = self.base.build()
        return package.compose(dict(original.files), original.manifest_hash, disclosure="public", tool_snapshot=self.tools)

    def test_absent_capture_preserves_unknowns_original_package_and_inert_sources(self):
        with self.context():
            original = self.base.build()
            result = self.build(); rebuilt = package.verify(dict(result.files), result.manifest_hash)
        self.assertEqual(result.files, rebuilt.files)
        files = dict(result.files)
        self.assertEqual({p[len("examination/"):]: b for p, b in files.items() if p.startswith("examination/")}, dict(original.files))
        self.assertEqual(result.report["entropy"]["status"], "unresolved")
        self.assertIsNone(result.report["entropy"]["terminalEligible"])
        self.assertIsNone(result.report["entropy"]["provenance"])
        self.assertIn("4", result.report["unresolvedItems"])
        self.assertFalse(result.report["canonicalPacketReady"])
        self.assertNotIn("entropy/packet-fragment.json", files)
        self.assertEqual(len(result.report["items"]), 19)
        self.assertIn("examination/citation/choices.json", result.report["items"][0]["evidence"])
        self.assertEqual(files["mint/original-token-data.bin"], b"token data")

    def test_disclosure_precedes_all_api_and_cli_reads(self):
        with patch.object(package.gather, "verify", side_effect=AssertionError("must not read")):
            with self.assertRaisesRegex(MuseumError, "public disclosure"):
                package.compose({}, "", disclosure="restricted")
        args = ["dossier_mint_entropy", "build", "--examination", "missing", "--examination-hash", keccak256(b"pin"),
            "--output", "missing", "--disclosure", "restricted"]
        with patch("sys.argv", args), patch.object(package, "read_tree", side_effect=AssertionError("must not read")):
            with self.assertRaisesRegex(MuseumError, "public disclosure"):
                package.main()

    def test_capture_triplet_pins_and_provenance_are_closed(self):
        files = {n: b"{}" for n in package.INPUTS}
        pins = {n + "Hash": keccak256(b"{}") for n in ("anchor", "transcript", "snapshot")}
        pins["provenance"] = "synthetic_fixture"
        package._inputs(files, pins)
        for changed_files, changed_pins in ((files | {"extra.json": b"{}"}, pins),
                (files, pins | {"complete": True}), (files, pins | {"provenance": "native"}),
                (files | {"snapshot.json": b"changed"}, pins)):
            with self.subTest(changed_pins=changed_pins), self.assertRaises(MuseumError):
                package._inputs(changed_files, changed_pins)
        with self.assertRaisesRegex(MuseumError, "supplied together"):
            package.compose({}, "", disclosure="public", entropy_files=files)

    def test_rehashed_completion_and_leaf_insertion_cannot_bypass_source_replay(self):
        with self.context():
            result = self.build()
            for alter in ("completion", "entropy"):
                files = dict(result.files)
                report = loads(files["packet/fields.json"], maximum=package.MAX_BYTES)
                if alter == "completion": report["canonicalPacketReady"] = True
                else: report["entropy"]["terminalEligible"] = True
                files["packet/fields.json"] = dumps(report)
                manifest = loads(result.manifest, maximum=package.MAX_MANIFEST)
                manifest["files"] = [package.base._ref(p, b) for p, b in sorted(files.items()) if p != "manifest.json"]
                raw = dumps(manifest); files["manifest.json"] = raw
                with self.subTest(alter=alter), self.assertRaisesRegex(MuseumError, "source reconstruction"):
                    package.verify(files, keccak256(raw))

    def test_external_pin_and_declared_inventory_reject_before_replay(self):
        with self.context(): result = self.build()
        with patch.object(package.gather, "verify", side_effect=AssertionError("reject first")):
            with self.assertRaisesRegex(MuseumError, "external manifest"):
                package.verify(dict(result.files), keccak256(b"wrong"))
            with self.assertRaisesRegex(MuseumError, "file commitments"):
                package.verify(dict(result.files) | {"unlisted.txt": b"data"}, result.manifest_hash)
            manifest = loads(result.manifest, maximum=package.MAX_MANIFEST)
            manifest["claims"]["sourceConsensusVerified"] = True
            raw = dumps(manifest)
            with self.assertRaisesRegex(MuseumError, "closed manifest"):
                package.verify(dict(result.files) | {"manifest.json": raw}, keccak256(raw))

    def test_full_packet_remains_unavailable_and_closed_dispatch_replays(self):
        from .package_v2 import verify_package
        with self.context(), TemporaryDirectory(prefix="mint-examination-test-") as temporary:
            result = self.build()
            with self.assertRaisesRegex(MuseumError, "unresolved items: 3, 4, 5"):
                package.complete_packet(dict(result.files), result.manifest_hash)
            directory = Path(temporary) / "package"
            write_tree(dict(result.files), directory)
            self.assertEqual(verify_package(directory, result.manifest_hash).files, result.files)

    def test_mint_joins_require_exact_original_events_data_and_coordinator(self):
        log = {key: "original-" + key for key in package.LOG_FIELDS}
        mint = deepcopy(self.mint)
        mint["mint"]["logs"] = {key: deepcopy(log) for key in ("registered", "entropyRegistered", "transfer")}
        result = {"identity": mint["mint"]["identity"] | {"tokenDataHash": mint["mint"]["tokenData"]["keccak256"]},
            "mint": {"mintCommitment": mint["mint"]["mintCommitment"], "logs": deepcopy(mint["mint"]["logs"]),
                "tokenTransfers": [{"topics": ["unused", "unused", "0x" + "00" * 12 + self.base.ref["coreFacts"]["owner"][2:]]}]}}
        package._join_mint(result, mint)
        changes = [lambda x: x["identity"].update(collectionSerial="999"),
            lambda x: x["identity"].update(coordinatorAtMint="0x" + "22" * 20),
            lambda x: x["identity"].update(tokenDataHash=keccak256(b"changed")),
            lambda x: x["mint"].update(mintCommitment=keccak256(b"changed")),
            lambda x: x["mint"]["logs"]["entropyRegistered"].update(transactionHash=keccak256(b"other transaction")),
            lambda x: x["mint"]["tokenTransfers"][-1]["topics"].__setitem__(2, "0x" + "00" * 12 + "99" * 20)]
        for change in changes:
            changed = deepcopy(result); change(changed)
            with self.subTest(change=change), self.assertRaises(MuseumError): package._join_mint(changed, mint)


class MintEntropyReplayTests(unittest.TestCase):
    """Real bounded reader replays joined to explicitly synthetic original inputs."""

    def case(self, status=5):
        from .test_mint_entropy_source import MintEntropyFixture, A, H
        from .test_object_dossier_native import reference
        f = MintEntropyFixture(status=status)
        # A non-entropy receipt log stands in for the retained sale settlement.
        # It must survive the cross-source comparison just like the native logs.
        f.log(1, A(40), [H(900)], ("bytes32",), (H(901),))
        evidence = {"artifacts": {"StreamEntropyCoordinator": {"address": A(20), "runtimeHash": keccak256(f.code[A(20)])}},
            "tokenSourceBlockViews": {}, "tokenMint": {"transactionHash": H(301), "receipt": deepcopy(f.receipts[H(301)])}}
        originals = {"deployment-evidence.json": dumps(evidence), "transcript.json": dumps({"calls": []})}
        f.a["deploymentEvidenceHash"] = keccak256(originals["deployment-evidence.json"])
        ref = reference(f.a, serial="2")
        # The real retained fixture also lacks a source-block coordinator code pin.
        ref["sourceAnchor"]["runtimePins"] = [p for p in f.a["codePins"] if p["address"] == A(10)]
        ref["coreFacts"]["owner"] = A(1)
        snapshot = f.result()
        mint = {"mint": {"identity": {k: v for k, v in snapshot["identity"].items() if k != "tokenDataHash"},
            "mintCommitment": snapshot["mint"]["mintCommitment"], "logs": snapshot["mint"]["logs"],
            "tokenData": {"keccak256": snapshot["identity"]["tokenDataHash"]}},
            "sourceBlockViews": {"coreFacts": ref["coreFacts"]}}
        examination = {"inputs/sources.json": dumps({"sources": []})}
        return f, examination, originals, ref, mint

    def capture(self, f):
        source = f.source()
        files = {"anchor.json": source.anchor_bytes, "snapshot.json": source.snapshot(), "transcript.json": source.transcript()}
        pins = {name + "Hash": keccak256(files[name + ".json"]) for name in ("anchor", "snapshot", "transcript")}
        return files, pins | {"provenance": "synthetic_fixture"}

    def replay(self, case, files=None, pins=None):
        f, examination, originals, ref, mint = case
        if files is None: files, pins = self.capture(f)
        with patch("socket.socket", side_effect=AssertionError("offline entropy source replay")):
            return package._entropy(examination, originals, ref, mint, files, pins)

    def test_all_supported_statuses_emit_exact_fragment_without_finality_promotion(self):
        from tools.metadata import genesis_dossier_profile as schema
        for status in (3, 4, 5, 6, 7):
            case = self.case(status)
            result = self.replay(case)
            fragment = result["entropy"]
            defs = schema.definitions()
            self.assertTrue(schema.Draft202012Validator({"$defs": defs, **schema.ref("entropy")}).is_valid(fragment))
            self.assertEqual(fragment["leaf"]["status"], str(status))
            self.assertEqual(fragment["leafHash"], schema._entropy_hash(fragment["leaf"]))
            self.assertEqual(result["terminalEligible"], status == 5)
            self.assertEqual(result["mode"], "synthetic_fixture")
            self.assertFalse(result["claims"]["actualChainAcceptance"])
            items = [{"item": str(i), "evidence": [], "status": "unresolved", "remaining": "missing"} for i in range(1, 20)]
            report = package._report({"items": items, "sourceState": case[3]["sourceState"], "sourceAnchor": case[3]["sourceAnchor"]},
                keccak256(b"synthetic examination"), case[4], result)
            self.assertEqual(report["items"][3]["status"], "derived_within_source_profile")
            self.assertNotIn("4", report["unresolvedItems"])
            self.assertFalse(report["canonicalPacketReady"])

    def test_coherent_reader_cannot_replace_original_owner_or_original_full_mint_receipt(self):
        from .test_mint_entropy_source import A, H, TRANSFER
        case = self.case(); f = case[0]
        f.log(6, A(10), [TRANSFER, H(1), H(2), H(71)])
        f.core("ownerOf(uint256)", ("address",), (A(2),))
        files, pins = self.capture(f)  # independently valid native source
        with self.assertRaisesRegex(MuseumError, "source-block owner"):
            self.replay(case, files, pins)
        case = self.case(); f = case[0]
        f.receipts[H(301)]["logs"][-1]["data"] = "0x" + encode(("bytes32",), (H(902),)).hex()
        files, pins = self.capture(f)  # unchanged three mint logs, changed sale log
        with self.assertRaisesRegex(MuseumError, "RPC"):
            self.replay(case, files, pins)

    def test_runtime_rpc_and_provenance_conflicts_survive_coherent_repinning(self):
        from .test_mint_entropy_source import A
        case = self.case(); files, pins = self.capture(case[0])
        transcript = loads(files["transcript.json"], maximum=package.MAX_TRANSCRIPT)
        call = next(deepcopy(r) for r in transcript["calls"] if r["method"] == "eth_call")
        call["result"] = "0x" + "00" * 32
        case[2]["transcript.json"] = dumps({"calls": [call]})
        with self.assertRaisesRegex(MuseumError, "RPC"):
            self.replay(case, files, pins)
        case = self.case(); f = case[0]
        f.code[A(20)] = b"\x60\x99"
        f.a["codePins"][1]["runtimeHash"] = keccak256(f.code[A(20)])
        with self.assertRaisesRegex(MuseumError, "deployment/runtime"):
            self.replay(case)
        case = self.case(); files, pins = self.capture(case[0])
        with self.assertRaisesRegex(MuseumError, "source replay"):
            self.replay(case, files, pins | {"provenance": "trusted_rpc"})

    def test_optional_real_reader_fragment_is_written_and_rebuilt_by_composer(self):
        # Containing fixture/extractor boundaries are stubbed here; the source
        # reader, pin checks, receipt/owner joins and composition are concrete.
        case = self.case(); f, _, originals, ref, mint = case
        captures, pins = self.capture(f)
        original_files = case[1] | {"manifest.json": dumps({"retainedManifestHash": keccak256(b"stub fixture")})}
        report = {"sourceState": ref["sourceState"], "sourceAnchor": ref["sourceAnchor"],
            "items": [{"item": str(i), "name": "Requirement", "evidence": [], "status": "unresolved", "remaining": "missing"}
                for i in range(1, 20)]}
        prior = package.base.Assembly(tuple(sorted(original_files.items())), original_files["manifest.json"], report)
        tools = {"tool/" + p + ".txt": b"raise RuntimeError('inert')\n" for p in package.TOOL_NAMES}
        with patch.object(package.gather, "verify", return_value=prior), \
                patch.object(package, "_originals", return_value=originals), \
                patch.object(package.native, "reference_from_originals", return_value=ref), \
                patch("tools.museum.token_mint_evidence.extract", return_value=({}, mint)), \
                patch("socket.socket", side_effect=AssertionError("offline composition")):
            result = package.compose(original_files, prior.manifest_hash, disclosure="public",
                entropy_files=captures, entropy_pins=pins, tool_snapshot=tools)
            self.assertEqual(package.verify(dict(result.files), result.manifest_hash).files, result.files)
        files = dict(result.files)
        fragment = loads(files["entropy/packet-fragment.json"])
        self.assertEqual(fragment["leafHash"], keccak256(files["entropy/leaf-preimage.bin"]))
        self.assertEqual(len(files["entropy/leaf-preimage.bin"]), 288)
        self.assertEqual(result.report["entropy"]["provenance"], "synthetic_fixture")
        self.assertEqual(result.report["entropy"]["observedStatusLabel"], "FINALIZED")
        self.assertFalse(result.report["canonicalPacketReady"])
        self.assertNotIn("4", result.report["unresolvedItems"])


if __name__ == "__main__":
    unittest.main()

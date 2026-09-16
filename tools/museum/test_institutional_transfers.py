"""Synthetic original receipt controls; no deployed title/transfer capture claim."""
import copy
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

from .canonical import MuseumError, dumps, keccak256, loads
from .chain_abi import encode
from .chain_rpc import ReplayTransport
from .institutional import PROFILE_HASH as INSTITUTIONAL_PROFILE_HASH
from .institutional_package import build_institutional_package
from .institutional_transfers import PROFILE, PROFILE_HASH, EVENT, TitleTransferCapture
from .institutional_transfer_package import build_transfer_package, verify_transfer_package
from .package import write_package
from .package_recorded import build_recorded_package
from .test_institutional import InstitutionalFixture
from .test_package import changed
from .test_package_recorded import inputs, pins
from .test_preservation_resources import A, H
from .test_recorded_account import ROOT, load_source


class TransferFixture:
    def __init__(self, anchor=None):
        self.owner = InstitutionalFixture(anchor=anchor, families=["ACCESSION", "DEACCESSION"],
            edit=lambda _, v: v["titleBinding"]["transfer"].update(blockNumber=str(int((anchor or {"blockNumber": "20"})["blockNumber"]) - 1)))
        self.source, self.inputs, _ = self.owner.replay()
        self.source_hash = keccak256(self.source.snapshot())
        a = self.source.a; number = int(a["blockNumber"]); stamp = int(a["timestamp"])
        self.hints = dumps({"profile": PROFILE, "ownerSourceHash": self.source_hash, "records": self.owner.selected})
        self.receipt = {"status": "0x1", "transactionHash": H(19), "blockHash": H(20), "blockNumber": hex(number-1),
            "transactionIndex": "0x0", "logs": []}
        self.receipt["logs"] = [{**{k: self.receipt[k] for k in ("transactionHash", "blockHash", "blockNumber", "transactionIndex")},
            "address": a["core"], "logIndex": "0x3", "removed": False, "data": "0x",
            "topics": [EVENT, "0x" + encode(("address",), (A(8),)).hex(), "0x" + encode(("address",), (A(9),)).hex(),
                "0x" + encode(("uint256",), (41,)).hex()]}]
        self.blocks = {a["blockHash"]: {"hash": a["blockHash"], "number": hex(number), "timestamp": hex(stamp),
            "stateRoot": a["stateRoot"], "parentHash": H(20), "transactions": []},
            H(20): {"hash": H(20), "number": hex(number-1), "timestamp": hex(stamp-2), "stateRoot": H(22), "parentHash": H(18), "transactions": [H(19)]}}

    def request(self, method, params):
        if method == "eth_chainId": return hex(int(self.source.a["chainId"]))
        if method == "eth_getTransactionReceipt": return copy.deepcopy(self.receipt)
        if method == "eth_getBlockByHash": return copy.deepcopy(self.blocks[params[0]])
        raise AssertionError(method)

    def capture(self):
        return TitleTransferCapture(self.source, self.hints, self,
            hints_hash=keccak256(self.hints), source_hash=self.source_hash)


class InstitutionalTransfers(unittest.TestCase):
    def test_exact_receipts_replay_and_preserve_distinct_title_custody_limits(self):
        f = TransferFixture(); capture = f.capture(); raw = capture.capture(); report = loads(raw)
        self.assertEqual(report["mode"], "synthetic_fixture")
        self.assertEqual(len(report["correspondences"]), 2)
        self.assertTrue(report["claims"]["selectedOriginalTokenTransfersChecked"])
        self.assertFalse(report["claims"]["legalTitleProven"])
        self.assertFalse(report["claims"]["physicalCustodyTransferred"])
        transcript = capture.reader.transcript()
        with patch("socket.socket", side_effect=AssertionError("offline")):
            replay = TitleTransferCapture(f.source, f.hints, ReplayTransport(transcript, keccak256(transcript)),
                hints_hash=keccak256(f.hints), source_hash=f.source_hash, provenance="trusted_rpc")
            result = loads(replay.capture())
        self.assertEqual(result["correspondences"], report["correspondences"])
        self.assertEqual(capture.capture(), raw)

    def test_erc20_shaped_log_wrong_core_token_parties_and_log_index_reject(self):
        changes = [lambda r: r["logs"][0].update(address=A(99)), lambda r: r["logs"][0].update(data="0x00"),
            lambda r: r["logs"][0].update(topics=r["logs"][0]["topics"][:3]),
            lambda r: r["logs"][0]["topics"].__setitem__(3, "0x" + encode(("uint256",), (42,)).hex()),
            lambda r: r["logs"][0]["topics"].__setitem__(1, "0x" + encode(("address",), (A(77),)).hex()),
            lambda r: r["logs"][0].update(logIndex="0x4")]
        for mutate in changes:
            f = TransferFixture(); mutate(f.receipt)
            with self.subTest(mutate=mutate), self.assertRaisesRegex(MuseumError, "exact original ERC721"):
                f.capture().capture()

    def test_reverted_removed_duplicate_and_mismatched_receipt_coordinates_reject(self):
        changes = [lambda r: r.update(status="0x0"), lambda r: r["logs"][0].update(removed=True),
            lambda r: r["logs"].append(copy.deepcopy(r["logs"][0])), lambda r: r["logs"][0].update(transactionHash=H(88)),
            lambda r: r.update(transactionHash=H(88)), lambda r: r.update(transactionIndex="0x1"),
            lambda r: r.update(blockHash=H(88)), lambda r: r.update(blockNumber="0x12")]
        for mutate in changes:
            f = TransferFixture(); mutate(f.receipt)
            with self.subTest(mutate=mutate), self.assertRaises(MuseumError): f.capture().capture()

    def test_parent_link_timestamp_publication_and_transaction_inclusion_reject(self):
        changes = [lambda f: f.blocks[H(20)].update(hash=H(88)),
            lambda f: f.blocks[H(20)].update(number="0x12"), lambda f: f.blocks[H(20)].update(transactions=[H(88)]),
            lambda f: f.blocks[H(20)].update(timestamp=hex(int(f.source.a["timestamp"]))),
            lambda f: f.blocks[f.source.a["blockHash"]].update(stateRoot=H(88))]
        for mutate in changes:
            f = TransferFixture(); mutate(f)
            with self.subTest(mutate=mutate), self.assertRaises(MuseumError): f.capture().capture()

    def test_plan_source_and_transport_provenance_pins_reject(self):
        f = TransferFixture()
        with self.assertRaises(MuseumError): TitleTransferCapture(f.source, f.hints, f, hints_hash=H(99), source_hash=f.source_hash)
        with self.assertRaises(MuseumError): TitleTransferCapture(f.source, f.hints, f, hints_hash=keccak256(f.hints), source_hash=H(99))
        with self.assertRaises(MuseumError): TitleTransferCapture(f.source, f.hints, f, hints_hash=keccak256(f.hints), source_hash=f.source_hash, provenance="trusted_rpc")
        hints = loads(f.hints); hints["records"].append(hints["records"][0]); raw = dumps(hints)
        with self.assertRaises(MuseumError): TitleTransferCapture(f.source, raw, f, hints_hash=keccak256(raw), source_hash=f.source_hash)
        original = f.capture().capture()
        f.source.records[f.owner.selected[0]]["payloadHex"] = "0x00"
        self.assertEqual(f.capture().capture(), original)

    def test_equal_timestamps_never_prove_publication_transaction_order(self):
        f = TransferFixture()
        f.blocks[H(20)]["timestamp"] = hex(int(f.source.a["timestamp"]) - 1)
        report = loads(f.capture().capture())
        self.assertEqual(report["correspondences"][0]["sourceRecordedAt"], report["correspondences"][0]["eventTimestamp"])
        self.assertFalse(report["claims"]["transferPrecedesSourcePublicationProven"])

    def test_receipt_span_is_bounded_before_ancestor_reads(self):
        anchor = {"chainId": "31337", "core": A(2), "blockNumber": "300", "blockHash": H(21), "timestamp": "1790000000", "stateRoot": H(22)}
        owner = InstitutionalFixture(anchor=anchor, families=["ACCESSION"], edit=lambda _, v: v["titleBinding"]["transfer"].update(blockNumber="1"))
        source, _, _ = owner.replay(); digest = keccak256(source.snapshot())
        hints = dumps({"profile": PROFILE, "ownerSourceHash": digest, "records": owner.selected})
        class Ancient:
            def request(self, method, params):
                if method == "eth_chainId": return "0x7a69"
                if method == "eth_getTransactionReceipt": return {"status": "0x1", "transactionHash": H(19), "blockHash": H(1), "blockNumber": "0x1", "transactionIndex": "0x0", "logs": []}
                raise AssertionError("must not start unbounded ancestor reads")
        with self.assertRaisesRegex(MuseumError, "ancestor span"):
            TitleTransferCapture(source, hints, Ancient(), hints_hash=keccak256(hints), source_hash=digest).capture()

    def test_complete_derivative_rebuild_rejects_rehashed_report_tampering(self):
        f = TransferFixture(anchor=load_source().anchor); capture = f.capture(); capture.capture(); transcript = capture.reader.transcript()
        original = build_recorded_package(inputs(), root=ROOT, disclosure="public", **pins())
        owner_pins = {"anchorHash": keccak256(f.inputs["anchor.json"]), "transcriptHash": keccak256(f.inputs["transcript.json"]), "sourceHash": f.source_hash}
        plan = dumps({"version": "1", "ownerSourceHash": f.source_hash, "records": f.owner.selected})
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp); write_package(original, root / "original")
            institutional = build_institutional_package(root / "original", original.manifest_hash, plan, plan_hash=keccak256(plan),
                profile_hash=INSTITUTIONAL_PROFILE_HASH, owner_inputs=f.inputs, owner_pins=owner_pins, disclosure="public")
            write_package(institutional, root / "institutional")
            with patch("socket.socket", side_effect=AssertionError("offline")):
                result = build_transfer_package(root / "institutional", institutional.manifest_hash, f.hints, transcript,
                    hints_hash=keccak256(f.hints), transcript_hash=keccak256(transcript), profile_hash=PROFILE_HASH)
                write_package(result, root / "export")
                self.assertEqual(verify_transfer_package(root / "export", result.manifest_hash), result)
            self.assertEqual(dict(result.files)["source/manifest.json"], institutional.manifest)
            altered = changed(result, "transfers/report.json", dumps({"legalTitleProven": True})); write_package(altered, root / "altered")
            with self.assertRaisesRegex(MuseumError, "semantic reconstruction"): verify_transfer_package(root / "altered", altered.manifest_hash)


if __name__ == "__main__": unittest.main()

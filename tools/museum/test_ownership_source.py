"""Synthetic source controls; these vectors are not executed EVM acceptance."""
import copy
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

from .canonical import MuseumError, dumps, keccak256, loads
from .chain_abi import calldata, encode
from .chain_history import scan_history
from .chain_rpc import RecordingReader, ReplayTransport
from .independent_wire import ZERO_ADDRESS
from .ownership_source import OwnershipSource, PROFILE, TRANSFER, definitions, write_capture, _bounded_read


def H(n):
    return "0x" + f"{n:064x}"


def A(n):
    return "0x" + f"{n:040x}"


class OwnershipFixture:
    def __init__(self, *, burned=False):
        self.code = b"\x60\x00\x60\x01"
        self.a = {"profile": PROFILE, "chainId": "31337", "blockHash": H(103), "blockNumber": "3",
            "timestamp": "1003", "stateRoot": H(203), "environment": "local_evm_fixture",
            "deploymentEvidenceHash": H(500), "core": A(10), "coreRuntimeHash": keccak256(self.code),
            "tokenId": "71", "collectionId": "6"}
        self.blocks = {H(100 + n): {"hash": H(100 + n), "number": hex(n), "timestamp": hex(1000 + n),
            "stateRoot": H(200 + n), "parentHash": H(99 + n) if n else H(0),
            "transactions": [H(300 + n)] if n else []} for n in range(4)}
        self.receipts = {}
        for n, sender, recipient in ((1, ZERO_ADDRESS, A(1)), (2, A(1), A(2)),
                                     (3, A(2), ZERO_ADDRESS if burned else A(2))):
            receipt = {"transactionHash": H(300 + n), "blockHash": H(100 + n), "blockNumber": hex(n),
                       "transactionIndex": "0x0", "status": "0x1", "logs": []}
            receipt["logs"] = [{**{k: v for k, v in receipt.items() if k not in ("logs", "status")},
                "address": A(10), "data": "0x", "logIndex": "0x0", "removed": False,
                "topics": [TRANSFER, "0x" + encode(("address",), (sender,)).hex(),
                           "0x" + encode(("address",), (recipient,)).hex(), H(71)]}]
            self.receipts[H(300 + n)] = receipt
        self.calls = {
            calldata("supportsInterface(bytes4)", ("bytes4",), ("0x80ac58cd",)):
                encode(("bool",), (True,)),
            calldata("tokenCollectionIdentity(uint256)", ("uint256",), (71,)):
                encode(("bool", "uint256", "uint256", "bool"), (True, 6, 2, burned)),
            calldata("tokenLifecycle(uint256)", ("uint256",), (71,)):
                encode(("uint8",), (3 if burned else 2,)),
            calldata("ownerOf(uint256)", ("uint256",), (71,)):
                encode(("address",), (A(2),))}
        self.requested = []

    def request(self, method, params):
        self.requested.append((method, params))
        if method == "eth_chainId": return "0x7a69"
        if method == "eth_getBlockByHash": return copy.deepcopy(self.blocks[params[0]])
        if method == "eth_getTransactionReceipt": return copy.deepcopy(self.receipts[params[0]])
        if method in ("eth_call", "eth_getCode"):
            assert params[1] == {"blockHash": self.a["blockHash"], "requireCanonical": True}
            if method == "eth_getCode": return "0x" + self.code.hex()
            assert params[0]["to"] == self.a["core"]
            return "0x" + self.calls[params[0]["data"]].hex()
        raise AssertionError(method)

    def source(self):
        return OwnershipSource(dumps(self.a), self)


class OwnershipHistoryTests(unittest.TestCase):
    def test_complete_mint_transfer_self_transfer_replay_with_socket_disabled(self):
        fixture = OwnershipFixture(); source = fixture.source(); raw = source.snapshot(); report = loads(raw)
        self.assertEqual(report["identity"]["owner"], A(2))
        self.assertEqual([r["kind"] for r in report["transitions"]], ["mint", "transfer", "transfer"])
        self.assertEqual(report["historyCoverage"], {"startBlock": "0", "endBlock": "3", "blockCount": "4", "transactionCount": "3"})
        self.assertEqual([params[0] for method, params in fixture.requested if method == "eth_getTransactionReceipt"], [H(301), H(302), H(303)])
        self.assertEqual(report["tokenTransferJsonlHash"], keccak256(report["tokenTransferJsonl"].encode()))
        self.assertTrue(report["claims"]["fullTokenTransferHistory"])
        self.assertFalse(report["claims"]["actualChainAcceptance"])
        self.assertFalse(report["claims"]["legalTitleProven"])
        transcript = source.transcript()
        with patch("socket.socket", side_effect=AssertionError("offline")):
            replay = OwnershipSource(source.anchor_bytes, ReplayTransport(transcript, keccak256(transcript)))
            self.assertEqual(replay.snapshot(), raw)
        self.assertEqual(source.snapshot(), raw)

    def test_burn_keeps_identity_and_never_calls_reverting_owner_of(self):
        fixture = OwnershipFixture(burned=True)
        del fixture.calls[calldata("ownerOf(uint256)", ("uint256",), (71,))]
        report = loads(fixture.source().snapshot())
        self.assertEqual(report["identity"], {"tokenId": "71", "collectionId": "6", "collectionSerial": "2", "lifecycle": "3", "owner": ZERO_ADDRESS})
        self.assertEqual(report["transitions"][-1]["kind"], "burn")

    def test_missing_mint_disconnected_and_reminted_histories_reject(self):
        for height, topic, value in ((1, 1, A(8)), (2, 1, A(8)), (2, 1, ZERO_ADDRESS), (2, 2, ZERO_ADDRESS)):
            fixture = OwnershipFixture()
            fixture.receipts[H(300 + height)]["logs"][0]["topics"][topic] = "0x" + encode(("address",), (value,)).hex()
            with self.subTest(height=height, topic=topic, value=value), self.assertRaises(MuseumError):
                fixture.source().snapshot()

    def test_state_mismatch_and_prepared_or_unknown_mints_reject(self):
        changes = [("tokenLifecycle(uint256)", ("uint8",), (0,)),
                   ("tokenLifecycle(uint256)", ("uint8",), (1,)),
                   ("tokenLifecycle(uint256)", ("uint8",), (3,)),
                   ("ownerOf(uint256)", ("address",), (A(8),)),
                   ("tokenCollectionIdentity(uint256)", ("bool", "uint256", "uint256", "bool"), (True, 7, 2, False)),
                   ("tokenCollectionIdentity(uint256)", ("bool", "uint256", "uint256", "bool"), (False, 0, 0, False))]
        for signature, types, values in changes:
            fixture = OwnershipFixture(); fixture.calls[calldata(signature, ("uint256",), (71,))] = encode(types, values)
            with self.subTest(signature=signature, values=values), self.assertRaises(MuseumError): fixture.source().snapshot()

    def test_malformed_core_transfer_and_abi_address_padding_reject(self):
        changes = [lambda log: log.update(data="0x00"), lambda log: log["topics"].pop(),
                   lambda log: log["topics"].__setitem__(1, "0x01" + "00" * 31)]
        for change in changes:
            fixture = OwnershipFixture(); change(fixture.receipts[H(302)]["logs"][0])
            with self.subTest(change=change), self.assertRaises(MuseumError): fixture.source().snapshot()

    def test_other_core_or_token_does_not_supply_missing_mint(self):
        for key, value in (("address", A(99)), ("topics", [TRANSFER, H(0), H(1), H(72)])):
            fixture = OwnershipFixture(); fixture.receipts[H(301)]["logs"][0][key] = value
            with self.subTest(key=key), self.assertRaisesRegex(MuseumError, "begin with one mint"): fixture.source().snapshot()

    def test_runtime_interface_and_provenance_fail_closed(self):
        fixture = OwnershipFixture(); fixture.code += b"x"
        with self.assertRaisesRegex(MuseumError, "runtime differs"): fixture.source().snapshot()
        fixture = OwnershipFixture(); fixture.calls[calldata("supportsInterface(bytes4)", ("bytes4",), ("0x80ac58cd",))] = encode(("bool",), (False,))
        with self.assertRaisesRegex(MuseumError, "ERC721"): fixture.source().snapshot()
        with self.assertRaisesRegex(MuseumError, "provenance"): OwnershipSource(dumps(fixture.a), fixture, provenance="trusted_rpc")

    def test_output_guard_input_bound_and_committed_profile(self):
        fixture = OwnershipFixture()
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary); output = root / "capture"
            pins = write_capture(fixture.source(), output)
            self.assertEqual(pins["snapshotHash"], keccak256((output / "snapshot.json").read_bytes()))
            with self.assertRaises(FileExistsError): write_capture(fixture.source(), output)
            with self.assertRaisesRegex(MuseumError, "input file bound"): _bounded_read(output / "transcript.json", 8)
        definitions(Path(__file__).resolve().parents[2] / "schemas/museum/object-dossier", check=True)


class CompleteReceiptWalkTests(unittest.TestCase):
    def walk(self, fixture, **kwargs):
        return scan_history(RecordingReader(fixture, fixture.a["blockHash"]), fixture.a, **kwargs)

    def test_missing_ancestry_bad_genesis_duplicate_transaction_and_time_reject(self):
        changes = [lambda f: f.blocks[H(101)].update(hash=H(999)),
                   lambda f: f.blocks[H(100)].update(parentHash=H(999)),
                   lambda f: f.blocks[H(102)].update(transactions=[H(301)]),
                   lambda f: f.blocks[H(102)].update(timestamp="0xffff"),
                   lambda f: f.blocks[H(103)].update(stateRoot=H(999))]
        for change in changes:
            fixture = OwnershipFixture(); change(fixture)
            with self.subTest(change=change), self.assertRaises(MuseumError): self.walk(fixture)

    def test_missing_receipt_bad_coordinates_and_reverted_logs_reject(self):
        changes = [lambda f: f.receipts.__setitem__(H(302), None),
                   lambda f: f.receipts[H(302)].update(transactionIndex="0x1"),
                   lambda f: f.receipts[H(302)].update(blockHash=H(999)),
                   lambda f: f.receipts[H(302)].update(status="0x0"),
                   lambda f: f.receipts[H(302)]["logs"][0].update(transactionHash=H(999)),
                   lambda f: f.receipts[H(302)]["logs"][0].update(removed=True),
                   lambda f: f.receipts[H(302)]["logs"][0].update(logIndex="0x1")]
        for change in changes:
            fixture = OwnershipFixture(); change(fixture)
            with self.subTest(change=change), self.assertRaises(MuseumError): self.walk(fixture)

    def test_every_receipt_including_failed_and_empty_receipts_is_visited(self):
        fixture = OwnershipFixture()
        for n, status in ((2, "0x0"), (3, "0x1")):
            fixture.receipts[H(300+n)].update(logs=[], status=status)
        result = self.walk(fixture)
        self.assertEqual(result["transactionCount"], "3")
        self.assertEqual(len(result["logs"]), 1)

    def test_cross_transaction_log_order_is_contiguous(self):
        fixture = OwnershipFixture()
        fixture.blocks[H(103)]["transactions"].append(H(304))
        second = copy.deepcopy(fixture.receipts[H(303)])
        second.update(transactionHash=H(304), transactionIndex="0x1")
        second["logs"][0].update(transactionHash=H(304), transactionIndex="0x1", logIndex="0x1")
        fixture.receipts[H(304)] = second
        self.assertEqual(len(self.walk(fixture)["logs"]), 4)
        second["logs"][0]["logIndex"] = "0x0"
        with self.assertRaisesRegex(MuseumError, "log index"): self.walk(fixture)

    def test_no_truncation_when_bound_exceeded_and_failed_source_cannot_resume(self):
        fixture = OwnershipFixture()
        with self.assertRaisesRegex(MuseumError, "block bound"): self.walk(fixture, maximum_blocks=3)
        self.assertEqual(fixture.requested, [])
        source = fixture.source(); fixture.receipts[H(301)] = None
        with self.assertRaises(MuseumError): source.snapshot()
        with self.assertRaisesRegex(MuseumError, "cannot resume"): source.snapshot()

    def test_transcript_extra_rows_and_wrong_pin_reject(self):
        fixture = OwnershipFixture(); source = fixture.source(); source.snapshot()
        rows = loads(source.transcript(), maximum=67108864); rows["calls"].append(rows["calls"][0]); raw = dumps(rows)
        with self.assertRaisesRegex(MuseumError, "unconsumed"):
            OwnershipSource(source.anchor_bytes, ReplayTransport(raw, keccak256(raw))).snapshot()
        with self.assertRaisesRegex(MuseumError, "commitment"): ReplayTransport(raw, H(999))


if __name__ == "__main__":
    unittest.main()

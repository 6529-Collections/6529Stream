"""Synthetic full-history OwnerRecords controls; no actual-chain acceptance."""
from copy import deepcopy
from hashlib import sha256
from pathlib import Path
import re
import tempfile
import unittest
from unittest.mock import patch

from .canonical import MuseumError, dumps, hex_bytes, keccak256, loads, record_chain, schema_id, subject_id
from .chain_abi import calldata, encode
from .chain_rpc import ReplayTransport
from . import owner_catalog_source as catalog


def H(label):
    return keccak256(str(label).encode())


def A(number):
    return "0x" + number.to_bytes(20, "big").hex()


class Transport:
    def __init__(self, responses):
        self.responses = responses

    def request(self, method, params):
        key = dumps([method, params])
        if key not in self.responses:
            raise MuseumError("unexpected synthetic owner catalogue request")
        return deepcopy(self.responses[key])


def record_pair(*, algorithm=1, payload=b"payload", owner=A(8), relayed=None, token=71, index=0,
                record_type=None, previous=catalog.ZERO):
    digest = (hex_bytes(keccak256(payload)) if algorithm == 1 else sha256(payload).digest()
        if algorithm == 2 else b"opaque" if algorithm in (4, 5) else b"x" * 32)
    record = (record_type or schema_id("ACCESSION"), subject_id("token", "31337", A(2), "0", token_id=str(token)),
        H("schema"), (algorithm, digest, schema_id("RAW_BYTES")), "ipfs://original", payload, 99)
    receipt = [token, owner, 102, index, catalog.ZERO, relayed is not None, catalog.ZERO,
        17 if relayed else 0, 200 if relayed else 0, H("schema-definition"), H("canon-definition"),
        schema_id(relayed or "DIRECT"), catalog.ZERO]
    if relayed:
        body = catalog.signed_words(record, receipt)
        domain = catalog.domain(31337, A(1))
        signature = b"s" * 64 if relayed == "EIP712" else b""
        words = tuple("0x" + body[i:i + 32].hex() for i in range(0, len(body), 32))
        bundle = encode(("bytes32", ("bytes32",) * 14, "bytes"), (domain, words, signature))
        receipt[6] = keccak256(b"\x19\x01" + hex_bytes(domain) + hex_bytes(keccak256(body)))
    else:
        bundle = encode(("bytes32", "address", "bytes32"), (schema_id("DIRECT"), owner, keccak256(payload)))
    receipt[12] = keccak256(bundle)
    digest = catalog.native_hash(31337, A(1), A(2), record, receipt)
    receipt[4] = record_chain("31337", A(1), str(token), record[0], previous, digest, str(index))
    return digest, record, tuple(receipt), bundle


class Fixture:
    def __init__(self, *, empty=False):
        self.responses = {}
        self.custom = H("CUSTOM_OWNER_HISTORY")
        runtimes = {A(i): b"\x60" + bytes([i]) for i in range(1, 5)}
        self.blocks = {n: {"hash": H("block" + str(n)), "number": hex(n), "parentHash":
            H("block" + str(n - 1)) if n else catalog.ZERO, "timestamp": hex(100 + n),
            "stateRoot": H("state" + str(n)), "transactions": []} for n in range(3)}
        self.anchor = {"profile": catalog.PROFILE, "chainId": "31337", "blockHash": self.blocks[2]["hash"],
            "blockNumber": "2", "timestamp": "102", "stateRoot": self.blocks[2]["stateRoot"],
            "environment": "local_evm_fixture", "deploymentEvidenceHash": H("deployment"),
            "host": A(1), "core": A(2), "schemas": A(3), "store": A(4), "tokenId": "71",
            "codePins": [{"address": a, "runtimeHash": keccak256(raw)} for a, raw in runtimes.items()]}
        self.receipts = {}
        self.admission = self.log(1, A(1), [catalog.ADMISSION_EVENT, self.custom, H("action")],
            encode(("uint16",), (1,)))
        self.rows = []
        if not empty:
            first = record_pair()
            second = record_pair(algorithm=2, payload=b"", owner=A(9), index=1, previous=first[2][4])
            third = record_pair(algorithm=4, payload=b"opaque", relayed="ERC1271", index=2, previous=second[2][4])
            fourth = record_pair(algorithm=2, payload=b"\x00\xff", owner=A(9), relayed="EIP712", record_type=self.custom)
            self.rows = [first, second, third, fourth]
        self.put("eth_chainId", [], "0x7a69")
        block_ref = {"blockHash": self.anchor["blockHash"], "requireCanonical": True}
        for address, raw in runtimes.items():
            self.put("eth_getCode", [address, block_ref], "0x" + raw.hex())
        for key, getter in (("core", "core"), ("schemas", "schemaRegistry"), ("store", "chunkStore")):
            address = self.anchor[key]
            self.call(getter + "()", ("address",), (address,))
            self.call(getter + "CodeHash()", ("bytes32",), (keccak256(runtimes[address]),))
        self.call("chunkStore()", ("address",), (A(4),), target=A(3))
        self.call("streamModuleType()", ("bytes32",), (schema_id("OWNER_RECORDS"),))
        self.call("streamModuleVersion()", ("bytes32",), (schema_id("6529stream.owner-records.v1"),))
        self.call("deriveOwnerSubject(uint256)", ("bytes32",),
            (subject_id("token", "31337", A(2), "0", token_id="71"),), ("uint256",), (71,))
        for row_index, (digest, record, receipt, bundle) in enumerate(self.rows):
            pointer = A(30 + row_index)
            self.call("ownerRecord(bytes32)", (catalog.OWNER_RECORD, catalog.RECEIPT), (record, receipt), ("bytes32",), (digest,))
            self.call("ownerRecordSignatureBundle(bytes32)", ("address", "bytes"), (pointer, bundle), ("bytes32",), (digest,))
            self.put("eth_getCode", [pointer, block_ref], "0x00" + bundle.hex())
            self.call("recordHashAt(uint256,bytes32,uint256)", ("bytes32",), (digest,),
                ("uint256", "bytes32", "uint256"), (71, record[0], receipt[3]))
            if receipt[5]:
                self.call("isOwnerRecordNonceUsed(address,uint256)", ("bool",), (True,), ("address", "uint256"),
                    (receipt[1], receipt[7]))
            self.log(2, A(1), [catalog.RECORD_EVENT, "0x" + encode(("uint256",), (71,)).hex(), record[0],
                "0x" + encode(("address",), (receipt[1],)).hex()],
                encode((catalog.OWNER_RECORD, "bytes32", "bytes32", "bool", "uint16"),
                    (record, digest, receipt[4], receipt[5], 1)))
        for record_type in (*catalog.FIXED, self.custom):
            lane = [row for row in self.rows if row[1][0] == record_type]
            self.call("isOwnerRecordType(bytes32)", ("bool",), (True,), ("bytes32",), (record_type,))
            self.call("recordChainHash(uint256,bytes32)", ("bytes32", "uint64"),
                (lane[-1][2][4] if lane else catalog.ZERO, len(lane)), ("uint256", "bytes32"), (71, record_type))
            latest = {row[2][1]: row[0] for row in lane}
            for owner, digest in latest.items():
                self.call("latestOwnerRecordHashFor(uint256,bytes32,address)", ("bytes32",), (digest,),
                    ("uint256", "bytes32", "address"), (71, record_type, owner))
        for block in self.blocks.values():
            self.put("eth_getBlockByHash", [block["hash"], False], block)

    def put(self, method, params, result):
        self.responses[dumps([method, params])] = result

    def call(self, signature, outputs, result, kinds=(), values=(), target=A(1)):
        self.put("eth_call", [{"to": target, "data": calldata(signature, kinds, values), "gas": "0x1312d00"},
            {"blockHash": self.anchor["blockHash"], "requireCanonical": True}], "0x" + encode(outputs, result).hex())

    def log(self, block, address, topics, data):
        tx = H("tx" + str(block))
        if tx not in self.receipts:
            self.blocks[block]["transactions"].append(tx)
            self.receipts[tx] = {"transactionHash": tx, "blockHash": self.blocks[block]["hash"],
                "blockNumber": hex(block), "transactionIndex": "0x0", "status": "0x1", "logs": []}
            self.put("eth_getTransactionReceipt", [tx], self.receipts[tx])
        receipt = self.receipts[tx]
        log = {key: receipt[key] for key in ("transactionHash", "blockHash", "blockNumber", "transactionIndex")}
        log.update(address=address, topics=topics, data="0x" + data.hex(), logIndex=hex(len(receipt["logs"])), removed=False)
        receipt["logs"].append(log)
        return log

    def source(self, **kwargs):
        return catalog.OwnerCatalogSource(dumps(self.anchor), Transport(self.responses), **kwargs)


class NativeWireTests(unittest.TestCase):
    def verify(self, row):
        digest, record, receipt, bundle = row
        return catalog.verify_native_wire(31337, A(1), A(2), 102, digest, 71, record, receipt, bundle)

    def test_all_native_algorithms_and_empty_payloads_remain_present(self):
        for algorithm in range(1, 7):
            for payload in (b"", b"payload"):
                with self.subTest(algorithm=algorithm, payload=payload):
                    state = self.verify(record_pair(algorithm=algorithm, payload=payload))
                    if not payload:
                        self.assertEqual(state, "external_or_empty_commitment")
                    elif algorithm in (1, 2):
                        self.assertTrue(state.endswith("_verified"))
                    else:
                        self.assertEqual(state, "opaque_algorithm_commitment")

    def test_keccak_sha256_mismatch_and_native_digest_lengths_rejected(self):
        for algorithm, digest in ((1, b"x" * 32), (2, b"x" * 32), (3, b"x"), (4, b""), (5, b"x" * 129), (6, b"x"), (7, b"x" * 32)):
            row = list(record_pair()); record = list(row[1]); record[3] = (algorithm, digest, schema_id("RAW_BYTES")); row[1] = tuple(record)
            with self.subTest(algorithm=algorithm), self.assertRaises(MuseumError):
                self.verify(row)

    def test_direct_and_relayed_historical_preimages(self):
        for scheme in (None, "EIP712", "ERC1271"):
            with self.subTest(scheme=scheme):
                self.verify(record_pair(relayed=scheme))
        row = list(record_pair(relayed="ERC1271")); receipt = list(row[2]); receipt[6] = H("wrong-domain")
        row[2] = tuple(receipt)
        with self.assertRaisesRegex(MuseumError, "signed preimage"):
            self.verify(row)

    def test_foreign_token_and_invalid_native_uri_rejected(self):
        with self.assertRaisesRegex(MuseumError, "identity"):
            self.verify(record_pair(token=72))
        for uri in ("https://", "https:///path", "https://x/a b", "javascript:alert(1)", "ipfs://", "ar://"):
            row = list(record_pair()); record = list(row[1]); record[4] = uri; row[1] = tuple(record)
            with self.subTest(uri=uri), self.assertRaisesRegex(MuseumError, "URI"):
                self.verify(row)


class CatalogueTests(unittest.TestCase):
    def test_full_catalogue_all_lanes_and_historical_author_latest(self):
        f = Fixture(); source = f.source()
        with patch("socket.socket", side_effect=AssertionError("synthetic reader used network")):
            raw = source.snapshot()
        value = loads(raw, maximum=1048576, canonical=True)
        self.assertEqual(value["mode"], "synthetic_fixture")
        self.assertEqual(len(value["catalogue"]), 11)
        self.assertEqual(len(value["lanes"]), 11)
        self.assertEqual(len(value["records"]), 4)
        self.assertEqual(sum(row["state"] == "authenticated_empty" for row in value["lanes"]), 9)
        lane = next(row for row in value["lanes"] if row["recordType"] == schema_id("ACCESSION"))
        self.assertEqual(lane["latestByAuthor"], [{"owner": A(8), "recordHash": f.rows[2][0]}, {"owner": A(9), "recordHash": f.rows[1][0]}])
        self.assertEqual({row["payloadCorrespondence"] for row in value["records"]},
            {"embedded_keccak256_verified", "external_or_empty_commitment", "opaque_algorithm_commitment", "embedded_sha256_verified"})
        self.assertFalse(value["claims"]["actualChainAcceptance"])
        self.assertFalse(value["claims"]["legalTitleProven"])
        self.assertEqual(source.snapshot(), raw)
        transcript = source.transcript()
        replay = catalog.OwnerCatalogSource(dumps(f.anchor), ReplayTransport(transcript, keccak256(transcript)))
        self.assertEqual(replay.snapshot(), raw)

    def test_fully_empty_token_still_has_fixed_and_admitted_types(self):
        value = loads(Fixture(empty=True).source().snapshot(), maximum=1048576, canonical=True)
        self.assertEqual(value["records"], [])
        self.assertEqual(len(value["lanes"]), 11)
        self.assertTrue(all(row["state"] == "authenticated_empty" and row["count"] == "0" and row["head"] == catalog.ZERO for row in value["lanes"]))

    def test_extra_type_admission_is_irreversible_unique_and_precedes_publication(self):
        for change in ("missing", "duplicate", "fixed", "version", "action", "later"):
            f = Fixture()
            if change == "missing": f.receipts[H("tx1")]["logs"].clear()
            elif change == "duplicate": f.log(1, A(1), f.admission["topics"], encode(("uint16",), (1,)))
            elif change == "fixed": f.admission["topics"][1] = schema_id("ACCESSION")
            elif change == "version": f.admission["data"] = "0x" + encode(("uint16",), (2,)).hex()
            elif change == "action": f.admission["topics"][2] = catalog.ZERO
            else:
                f.receipts[H("tx1")]["logs"].clear()
                f.log(2, A(1), f.admission["topics"], encode(("uint16",), (1,)))
            with self.subTest(change=change), self.assertRaises(MuseumError):
                f.source().snapshot()

    def test_all_type_state_and_lane_heads_are_checked(self):
        for change in ("known", "empty-head", "count", "latest", "index", "nonce", "signature-code"):
            f = Fixture(); family = schema_id("ACCESSION")
            if change == "known": f.call("isOwnerRecordType(bytes32)", ("bool",), (False,), ("bytes32",), (schema_id("LOAN"),))
            elif change == "empty-head": f.call("recordChainHash(uint256,bytes32)", ("bytes32", "uint64"), (H("nonempty"), 0), ("uint256", "bytes32"), (71, schema_id("LOAN")))
            elif change == "count": f.call("recordChainHash(uint256,bytes32)", ("bytes32", "uint64"), (f.rows[1][2][4], 2), ("uint256", "bytes32"), (71, family))
            elif change == "latest": f.call("latestOwnerRecordHashFor(uint256,bytes32,address)", ("bytes32",), (f.rows[0][0],), ("uint256", "bytes32", "address"), (71, family, A(8)))
            elif change == "index": f.call("recordHashAt(uint256,bytes32,uint256)", ("bytes32",), (f.rows[1][0],), ("uint256", "bytes32", "uint256"), (71, family, 0))
            elif change == "nonce": f.call("isOwnerRecordNonceUsed(address,uint256)", ("bool",), (False,), ("address", "uint256"), (A(8), 17))
            else: f.put("eth_getCode", [A(30), {"blockHash": f.anchor["blockHash"], "requireCanonical": True}], "0x00")
            with self.subTest(change=change), self.assertRaises(MuseumError):
                f.source().snapshot()

    def test_missing_publication_wrong_timestamp_and_foreign_emitter_rejected(self):
        for change in ("missing", "timestamp", "emitter", "event-owner", "record"):
            f = Fixture(); logs = f.receipts[H("tx2")]["logs"]
            if change == "missing": logs.pop()
            elif change == "timestamp": f.blocks[2]["timestamp"] = "0x67"; f.anchor["timestamp"] = "103"
            elif change == "emitter": logs[0]["address"] = A(90)
            elif change == "event-owner": logs[0]["topics"][3] = "0x" + encode(("address",), (A(90),)).hex()
            else:
                digest, record, receipt, _ = f.rows[0]; record = list(record); record[5] = b"edited"
                f.call("ownerRecord(bytes32)", (catalog.OWNER_RECORD, catalog.RECEIPT), (tuple(record), receipt), ("bytes32",), (digest,))
            source = f.source()
            with self.subTest(change=change), self.assertRaises(MuseumError):
                source.snapshot()
            with self.assertRaisesRegex(MuseumError, "cannot resume"):
                source.snapshot()

    def test_full_history_cannot_skip_an_ancestor_transaction_or_genesis(self):
        for change in ("missing-receipt", "parent", "genesis", "bound"):
            f = Fixture()
            if change == "missing-receipt": f.responses.pop(dumps(["eth_getTransactionReceipt", [H("tx1")]]))
            elif change == "parent": f.blocks[1]["parentHash"] = H("foreign-parent")
            elif change == "genesis": f.blocks[0]["parentHash"] = H("not-genesis")
            else: f.anchor["blockNumber"] = "4096"
            with self.subTest(change=change), self.assertRaises(MuseumError):
                f.source().snapshot()

    def test_provenance_default_does_not_become_actual_acceptance(self):
        f = Fixture()
        with self.assertRaisesRegex(MuseumError, "provenance"):
            f.source(provenance="trusted_rpc")
        source = f.source(); source.snapshot(); raw = source.transcript()
        replay = catalog.OwnerCatalogSource(dumps(f.anchor), ReplayTransport(raw, keccak256(raw)), provenance="trusted_rpc")
        value = loads(replay.snapshot(), maximum=1048576, canonical=True)
        self.assertEqual(value["mode"], "caller_admitted_rpc_owner_catalogue")
        self.assertTrue(value["provenanceDeclaredByCaller"])
        self.assertFalse(value["claims"]["actualChainAcceptance"])

    def test_profile_generator_check(self):
        with tempfile.TemporaryDirectory() as temporary:
            self.assertEqual(catalog.definitions(temporary), catalog.PROFILE_HASH)
            self.assertEqual(catalog.definitions(temporary, check=True), catalog.PROFILE_HASH)
            (Path(temporary) / "owner-catalog-profile.json").write_bytes(b"{}")
            with self.assertRaises(MuseumError): catalog.definitions(temporary, check=True)

    def test_offline_cli_pins_preserved_bytes_and_refuses_output_reuse(self):
        f = Fixture(); source = f.source(); snapshot = source.snapshot(); transcript = source.transcript()
        anchor = dumps(f.anchor)
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            (root / "anchor.json").write_bytes(anchor)
            (root / "transcript.json").write_bytes(transcript)
            argv = ["owner-catalog", "replay", "--anchor", str(root / "anchor.json"), "--anchor-hash", keccak256(anchor),
                "--transcript", str(root / "transcript.json"), "--transcript-hash", keccak256(transcript),
                "--output", str(root / "result")]
            with patch("sys.argv", argv), patch("builtins.print"), \
                    patch("socket.socket", side_effect=AssertionError("offline CLI contacted network")):
                catalog.main()
                with self.assertRaises(FileExistsError): catalog.main()
            self.assertEqual((root / "result/snapshot.json").read_bytes(), snapshot)
            self.assertEqual((root / "result/anchor.json").read_bytes(), anchor)
            self.assertEqual((root / "result/transcript.json").read_bytes(), transcript)
            pins = loads((root / "result/pins.json").read_bytes(), canonical=True)
            self.assertEqual(pins["provenance"], "synthetic_fixture")
            self.assertFalse(pins["actualChainAcceptance"])
            self.assertEqual(pins["snapshotHash"], keccak256(snapshot))
            argv[argv.index("--anchor-hash") + 1] = catalog.ZERO
            with patch("sys.argv", argv), self.assertRaisesRegex(MuseumError, "anchor commitment"):
                catalog.main()

    def test_bounded_input_and_output_parent_guards(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary); path = root / "large.bin"; path.write_bytes(b"abc")
            with self.assertRaisesRegex(MuseumError, "input file bound"):
                catalog._bounded_read(path, 2)
            source = Fixture().source()
            with patch("pathlib.Path.is_symlink", return_value=True), self.assertRaisesRegex(MuseumError, "parent links"):
                catalog.write_capture(source, root / "result")
            self.assertFalse((root / "result").exists())


class SourceParityTests(unittest.TestCase):
    def test_fixed_catalogue_and_owner_abi_are_native(self):
        root = Path(__file__).resolve().parents[2] / "smart-contracts"
        book = (root / "domains/records/StreamOwnerRecordBook.sol").read_text(encoding="utf-8")
        types = re.search(r"function isKnownType\(.*?return (.*?);", book, re.S)[1]
        self.assertEqual(tuple(re.findall(r'keccak256\("([A-Z_]+)"\)', types)), catalog.FIXED_TYPES)
        source = (root / "interfaces/stream/metadata/IStreamOwnerRecords.sol").read_text(encoding="utf-8")
        for name, expected in (("OwnerRecord", catalog.OWNER_RECORD), ("Receipt", catalog.RECEIPT)):
            body = re.search(r"struct " + name + r"\s*\{(.*?)\}", source, re.S)[1]
            fields = [row.strip().split()[0] for row in body.split(";") if row.strip()]
            actual = tuple(catalog.HASH_REF if field == "IStreamPreservationRecords.HashRef" else field for field in fields)
            self.assertEqual(actual, expected)


if __name__ == "__main__":
    unittest.main()

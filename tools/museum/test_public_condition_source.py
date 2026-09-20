"""Synthetic canonical condition-source history; never actual-chain evidence."""
from copy import deepcopy
import unittest
from unittest.mock import patch

from .account_profile import JCS_BYTES
from .canonical import MuseumError, dumps, hex_bytes, keccak256, loads, record_chain, schema_id, subject_id
from .chain_abi import Array, calldata, decode, encode
from .citations import canonical_citation
from .condition import NAME, SCHEMA_BYTES
from .independent_wire import (DOCUMENT, DOCUMENT_SPEC, RAW_BYTES, RAW_DEFINITION, RECORD,
    RECEIPT as INDEPENDENT_RECEIPT, SUBJECT, TYPE_HASH, ZERO, domain as independent_domain,
    generic_hash)
from .owner_catalog_source import OWNER_RECORD, RECEIPT as OWNER_RECEIPT, native_hash
from .public_history_rpc import PublicReplayTransport
from . import public_condition_source as source
from .test_condition import condition
from .test_owner_catalog_source import A, H


CHAIN, TOKEN, COLLECTION = 31337, 71, 7
JCS = schema_id("RFC8785_JCS")
OPAQUE = schema_id("STREAM_CONDITION_OPAQUE_FIXTURE_V1")


class PublicConditionFixture:
    """A complete synthetic Core/catalog/two-owner/independent source graph."""

    def __init__(self, *, empty=False, unsupported_newest=False, malformed_newest=False,
            independent_unsupported_newest=False, shared_action=False, same_tx_owner=False):
        self.empty, self.same_tx_owner = empty, same_tx_owner
        self.responses, self.codes, self.receipts, self.requested = {}, {}, {}, []
        self.blocks = {number: {"hash": H("condition-block-" + str(number)), "number": hex(number),
            "parentHash": H("condition-block-" + str(number - 1)) if number else ZERO,
            "timestamp": hex(1000 + number), "stateRoot": H("condition-state-" + str(number)),
            "transactions": []} for number in range(9)}
        self.core, self.catalog, self.executor = A(1), A(2), A(3)
        self.schemas, self.store = A(4), A(5)
        self.owner1, self.owner2, self.independent = A(10), A(11), A(12)
        for address in (self.core, self.catalog, self.executor, self.schemas, self.store,
                self.owner1, self.owner2, self.independent):
            self.codes[address] = b"\x60" + hex_bytes(address, 20)[-1:] + b"\x00"
        self.documents = {}
        self._register("RAW_BYTES", 1, RAW_DEFINITION, RAW_BYTES)
        self._register("RFC8785_JCS", 1, JCS_BYTES, RAW_BYTES)
        self._register(NAME, 0, SCHEMA_BYTES, JCS)
        self._register("STREAM_CONDITION_OPAQUE_FIXTURE_V1", 0,
            b'{"title":"Synthetic opaque condition fixture","type":"object"}', JCS)

        self.owner_rows = {self.owner1: [], self.owner2: []}
        self.independent_rows = []
        self.actions = {}
        self._base_calls()
        self._catalogue()
        if not empty:
            first = self._condition_payload("owner-one-before-admission", captures=True)
            self._owner_record(self.owner1, first, A(20), 2, 0)
            continued = self._condition_payload("owner-one-continued", captures=True)
            self._owner_record(self.owner1, continued, A(21), 6, 0)
            selected = self._condition_payload("owner-two-selected", captures=False)
            self._owner_record(self.owner2, selected, A(22), 6, 1)
            foreign = self._condition_payload("foreign-token", captures=True, token=72)
            self._independent_record(foreign, A(30), (1, COLLECTION, 72, ZERO), 7, 0)
            matching = self._condition_payload("independent-selected", captures=True)
            self._independent_record(matching, A(31), (1, COLLECTION, TOKEN, ZERO), 7, 1)
            if unsupported_newest:
                self._owner_record(self.owner2, dumps({"fixture": "unsupported newest original"}),
                    A(23), 8, 0, schema=OPAQUE)
            if malformed_newest:
                self._owner_record(self.owner2, b'{"version":"1","broken":', A(23), 8, 0)
            if independent_unsupported_newest:
                self._independent_record(dumps({"fixture": "unsupported independent newest"}), A(32),
                    (1, COLLECTION, TOKEN, ZERO), 8, 1, schema=OPAQUE)
        self._lane_calls()
        if shared_action:
            self._share_admission_action_same_receipt()
        self._finalize_anchor()

    @staticmethod
    def topic(kind, value):
        return "0x" + encode((kind,), (value,)).hex()

    def _call(self, target, signature, outputs, result, kinds=(), values=()):
        self.responses[(target, calldata(signature, kinds, values))] = "0x" + encode(outputs, result).hex()

    def _pointer(self, raw):
        digest = keccak256(raw)
        for address, code in self.codes.items():
            if code == b"\x00" + raw:
                return address
        address = A(1000 + len(self.codes))
        self.codes[address] = b"\x00" + raw
        self._call(self.store, "chunk(bytes32)", ("address", "uint32"),
            (address, len(raw)), ("bytes32",), (digest,))
        return address

    def _register(self, name, kind, raw, canonical):
        parts = [raw[offset:offset + 8192] for offset in range(0, len(raw), 8192)]
        hashes = tuple(keccak256(part) for part in parts)
        for part in parts:
            self._pointer(part)
        spec = (name, kind, keccak256(raw), canonical, ZERO, "", len(raw))
        view = (True, 0, keccak256(encode((DOCUMENT_SPEC, Array("bytes32")), (spec, hashes))), spec, hashes)
        self.documents[schema_id(name)] = (raw, view)
        self._call(self.schemas, "document(bytes32)", (DOCUMENT,), (view,), ("bytes32",), (schema_id(name),))

    def _condition_payload(self, label, *, captures, token=TOKEN):
        value = condition()
        value["reportId"] = "urn:test:public-condition:" + label
        value["tokenId"] = str(token)
        finality_hash = H("condition-finality-" + label)
        value["workCitation"] = canonical_citation(str(CHAIN), self.core, str(token),
            {"kind": "fin", "hash": finality_hash})
        value["finality"]["finalityHash"] = finality_hash
        value["captures"] = value["captures"] if captures else []
        return dumps(value)

    def _transaction(self, block, tag, logs):
        header = self.blocks[block]
        tx_hash = H("condition-tx-" + tag)
        tx_index = len(header["transactions"])
        header["transactions"].append(tx_hash)
        prior_logs = sum(len(self.receipts[tx]["logs"]) for tx in header["transactions"][:-1])
        receipt = {"transactionHash": tx_hash, "blockHash": header["hash"], "blockNumber": hex(block),
            "transactionIndex": hex(tx_index), "status": "0x1", "logs": []}
        for offset, (address, topics, data) in enumerate(logs):
            receipt["logs"].append({"transactionHash": tx_hash, "blockHash": header["hash"],
                "blockNumber": hex(block), "transactionIndex": hex(tx_index), "logIndex": hex(prior_logs + offset),
                "address": address, "topics": topics, "data": "0x" + data.hex(), "removed": False})
        self.receipts[tx_hash] = receipt
        return receipt

    def _action(self, label, block, native_address, native_topics, native_data):
        action_id = H("condition-action-" + label)
        stamp = 1000 + block
        stored = (3, 1, A(50), 0, "0x12345678", H(label + "-calldata"), H(label + "-scope"),
            H(label + "-old"), H(label + "-new"), stamp - 1, stamp + 10, A(51), self.executor,
            A(52), A(53), H(label + "-policy"), label, H(label + "-result"))
        self.actions[action_id] = stored
        executed_topics = [source.EXECUTED_EVENT, action_id, self.topic("uint8", 1), self.topic("address", stored[2])]
        executed_data = encode(source.EXECUTED_DATA, (1, *stored[3:9], stored[12], stored[17]))
        receipt = self._transaction(block, label,
            [(native_address, native_topics, native_data), (self.executor, executed_topics, executed_data)])
        self._call(self.executor, "governanceAction(bytes32)", (source.ACTION,), (stored,), ("bytes32",), (action_id,))
        return action_id, receipt["logs"][0]

    def _base_calls(self):
        self.responses[(None, "eth_chainId")] = hex(CHAIN)
        for expected, value in (("0x02d968bb", True), ("0x01ffc9a7", True), ("0xffffffff", False)):
            self._call(self.core, "supportsInterface(bytes4)", ("bool",), (value,), ("bytes4",), (expected,))
        for expected, value in (("0xa621c1b7", True), ("0x01ffc9a7", True), ("0xffffffff", False)):
            self._call(self.catalog, "supportsInterface(bytes4)", ("bool",), (value,), ("bytes4",), (expected,))
        self._call(self.core, "conditionSources()", ("address", "bytes32"),
            (self.catalog, keccak256(self.codes[self.catalog])))
        self._call(self.core, "tokenCollectionIdentity(uint256)", ("bool", "uint256", "uint256", "bool"),
            (True, COLLECTION, 1, False), ("uint256",), (TOKEN,))
        for getter, kind, value in (("core", "address", self.core),
                ("coreCodeHash", "bytes32", keccak256(self.codes[self.core])),
                ("governanceAuthority", "address", self.executor),
                ("executorCodeHash", "bytes32", keccak256(self.codes[self.executor])),
                ("deploymentChainId", "uint256", CHAIN)):
            self._call(self.catalog, getter + "()", (kind,), (value,))
        self._call(self.schemas, "chunkStore()", ("address",), (self.store,))
        for host, owner in ((self.owner1, True), (self.owner2, True), (self.independent, False)):
            expected_interface = "0x34ee6097" if owner else "0x771b2917"
            for expected, value in ((expected_interface, True), ("0x01ffc9a7", True), ("0xffffffff", False)):
                self._call(host, "supportsInterface(bytes4)", ("bool",), (value,), ("bytes4",), (expected,))
            for getter, address in (("core", self.core), ("schemaRegistry", self.schemas), ("chunkStore", self.store)):
                self._call(host, getter + "()", ("address",), (address,))
                self._call(host, getter + "CodeHash()", ("bytes32",), (keccak256(self.codes[address]),))
            self._call(host, "streamModuleType()", ("bytes32",),
                (schema_id("OWNER_RECORDS" if owner else "COLLECTION_ATTESTATIONS"),))
            self._call(host, "streamModuleVersion()", ("bytes32",),
                (schema_id("6529stream.owner-records.v1" if owner else
                    "6529stream.collection-attestations.independent.v1"),))
            self._call(host, "isOwnerRecordType(bytes32)" if owner else "isIndependentRecordType(bytes32)",
                ("bool",), (True,), ("bytes32",), (source.OWNER_TYPE if owner else source.INDEPENDENT_TYPE,))
            if owner:
                self._call(host, "deriveOwnerSubject(uint256)", ("bytes32",),
                    (subject_id("token", str(CHAIN), self.core, "0", token_id=str(TOKEN)),),
                    ("uint256",), (TOKEN,))

    def _catalogue(self):
        bind_action = H("condition-action-binding")
        bind_topics = [source.BOUND_EVENT, self.topic("address", self.catalog), bind_action]
        # _action derives this same identifier from the label.
        actual, self.binding_log = self._action("binding", 1, self.core, bind_topics,
            encode(("uint16", "bytes32"), (1, keccak256(self.codes[self.catalog]))))
        assert actual == bind_action
        rows = []
        previous = source.empty_head({"chainId": str(CHAIN), "core": self.core, "conditionSources": self.catalog})
        for source_id, (host, lane, predecessor, block) in enumerate(((self.owner1, 0, 0, 3),
                (self.owner2, 0, 1, 4), (self.independent, 1, 0, 5)), 1):
            action = H("condition-action-source-" + str(source_id))
            row = (host, keccak256(self.codes[host]), lane, predecessor, 1000 + block, action)
            next_value = source.next_head(previous, source_id, row)
            topics = [source.ADDED_EVENT, self.topic("uint64", source_id), self.topic("address", host), self.topic("uint8", lane)]
            data = encode(("bytes32", "uint64", "bytes32", "bytes32", "bytes32", "uint16"),
                (row[1], predecessor, previous, next_value, action, 1))
            actual, log = self._action("source-" + str(source_id), block, self.catalog, topics, data)
            assert actual == action
            rows.append((row, previous, next_value, log)); previous = next_value
        self.catalog_rows, self.catalog_head = rows, previous
        self._call(self.catalog, "sourceSetHead()", ("uint64", "bytes32"), (len(rows), previous))
        self._call(self.catalog, "sourceCount()", ("uint64",), (len(rows),))
        self._call(self.catalog, "sourceSetHashAt(uint64)", ("bytes32",),
            (source.empty_head({"chainId": str(CHAIN), "core": self.core, "conditionSources": self.catalog}),),
            ("uint64",), (0,))
        for index, (row, _prior, head, _log) in enumerate(rows, 1):
            self._call(self.catalog, "sourceAt(uint64)", (source.SOURCE,), (row,), ("uint64",), (index,))
            self._call(self.catalog, "sourceId(address,uint8)", ("uint64",), (index,),
                ("address", "uint8"), (row[0], row[2]))
            self._call(self.catalog, "sourceSetHashAt(uint64)", ("bytes32",), (head,), ("uint64",), (index,))
        self._call(self.catalog, "requireSourceSet(uint64,bytes32)", (), (),
            ("uint64", "bytes32"), (len(rows), previous))

    def _owner_record(self, host, payload, author, block, tx_order, *, schema=None):
        schema = schema or schema_id(NAME)
        rows = self.owner_rows[host]; index = len(rows)
        sid = subject_id("token", str(CHAIN), self.core, "0", token_id=str(TOKEN))
        content = (1, hex_bytes(keccak256(payload)), JCS)
        record = (source.OWNER_TYPE, sid, schema, content, "ipfs://synthetic-condition", payload, 900)
        receipt = [TOKEN, author, 1000 + block, index, ZERO, False, ZERO, 0, 0,
            keccak256(self.documents[schema][0]), keccak256(JCS_BYTES), schema_id("DIRECT"), ZERO]
        bundle = encode(("bytes32", "address", "bytes32"), (schema_id("DIRECT"), author, keccak256(payload)))
        receipt[12] = keccak256(bundle)
        digest = native_hash(CHAIN, host, self.core, record, receipt)
        receipt[4] = record_chain(str(CHAIN), host, str(TOKEN), source.OWNER_TYPE,
            rows[-1][2][4] if rows else ZERO, digest, str(index))
        receipt = tuple(receipt); rows.append((digest, record, receipt, bundle, block, tx_order))
        pointer = self._pointer(bundle)
        self._call(host, "ownerRecord(bytes32)", (OWNER_RECORD, OWNER_RECEIPT), (record, receipt), ("bytes32",), (digest,))
        self._call(host, "ownerRecordSignatureBundle(bytes32)", ("address", "bytes"), (pointer, bundle), ("bytes32",), (digest,))
        self._call(host, "recordHashAt(uint256,bytes32,uint256)", ("bytes32",), (digest,),
            ("uint256", "bytes32", "uint256"), (TOKEN, source.OWNER_TYPE, index))
        topics = [source.OWNER_EVENT, self.topic("uint256", TOKEN), source.OWNER_TYPE, self.topic("address", author)]
        data = encode((OWNER_RECORD, "bytes32", "bytes32", "bool", "uint16"),
            (record, digest, receipt[4], False, 1))
        self._pending_publication(block, tx_order, host, topics, data, "owner-" + host[-2:] + "-" + str(index))
        return digest

    def _independent_record(self, payload, attestor, subject, block, tx_order, *, schema=None):
        schema = schema or schema_id(NAME); index = len(self.independent_rows)
        sid = subject_id(("collection", "token", "media")[subject[0]], str(CHAIN), self.core,
            str(subject[1]), token_id=str(subject[2]), object_id=subject[3])
        content = (1, hex_bytes(keccak256(payload)), JCS)
        effective, nonce, deadline = 900, 500 + index, 2000
        words = encode(("bytes32", "address", "uint256", "bytes32", "bytes32", "bytes32", "uint16",
            "bytes32", "bytes32", "bytes32", "bytes32", "uint64", "uint256", "uint64"),
            (TYPE_HASH, attestor, COLLECTION, sid, source.INDEPENDENT_TYPE, schema, 1,
             keccak256(content[1]), JCS, keccak256(b""), keccak256(payload), effective, nonce, deadline))
        domain = independent_domain(CHAIN, self.independent)
        saved_words = tuple("0x" + words[i:i + 32].hex() for i in range(0, len(words), 32))
        bundle = encode(("bytes32", ("bytes32",) * 14, "bytes"), (domain, saved_words, b""))
        record = (source.INDEPENDENT_TYPE, sid, content, "", schema, schema_id("DIRECT"),
            (1, hex_bytes(keccak256(bundle)), RAW_BYTES), effective)
        authorization = keccak256(b"\x19\x01" + hex_bytes(domain) + hex_bytes(keccak256(words)))
        digest = generic_hash(CHAIN, self.independent, self.core, COLLECTION, attestor, record)
        chain = record_chain(str(CHAIN), self.independent, str(COLLECTION), source.INDEPENDENT_TYPE,
            self.independent_rows[-1][2][5] if self.independent_rows else ZERO, digest, str(index))
        receipt = (COLLECTION, attestor, 5, 1000 + block, index, chain, authorization, nonce, deadline,
            keccak256(self.documents[schema][0]), keccak256(JCS_BYTES))
        self.independent_rows.append((digest, record, receipt, subject, payload, bundle, block, tx_order))
        for getter, raw in (("recordPayload(bytes32)", payload), ("recordSignatureBundle(bytes32)", bundle)):
            self._call(self.independent, getter, ("address", "bytes"), (self._pointer(raw), raw), ("bytes32",), (digest,))
        self._call(self.independent, "collectionRecord(bytes32)", (RECORD, INDEPENDENT_RECEIPT),
            (record, receipt), ("bytes32",), (digest,))
        self._call(self.independent, "recordSubject(bytes32)", (SUBJECT,), (subject,), ("bytes32",), (digest,))
        self._call(self.independent, "isIndependentAttestorNonceUsed(address,uint256)", ("bool",), (True,),
            ("address", "uint256"), (attestor, nonce))
        topics = [source.INDEPENDENT_EVENT, self.topic("uint256", COLLECTION), source.INDEPENDENT_TYPE, sid]
        data = encode((RECORD, "bytes32", "bytes32", "address", "bytes32", "uint16"),
            (record, digest, chain, attestor, self.topic("uint256", 5), 1))
        self._pending_publication(block, tx_order, self.independent, topics, data, "independent-" + str(index))
        return digest

    def _pending_publication(self, block, tx_order, host, topics, data, tag):
        pending = getattr(self, "pending", {})
        pending.setdefault(block, []).append((tx_order, host, topics, data, tag))
        self.pending = pending

    def _lane_calls(self):
        for block, rows in sorted(getattr(self, "pending", {}).items()):
            rows = sorted(rows)
            if (self.same_tx_owner and block == 6) or all(
                    host == self.independent for _order, host, _topics, _data, _tag in rows):
                self._transaction(block, "independent-batch-" + str(block),
                    [(host, topics, data) for _order, host, topics, data, _tag in rows])
            else:
                for _order, host, topics, data, tag in rows:
                    self._transaction(block, tag, [(host, topics, data)])
        for host, rows in self.owner_rows.items():
            head = rows[-1][2][4] if rows else ZERO
            self._call(host, "recordChainHash(uint256,bytes32)", ("bytes32", "uint64"),
                (head, len(rows)), ("uint256", "bytes32"), (TOKEN, source.OWNER_TYPE))
            latest = {}
            for digest, _record, receipt, _bundle, *_ in rows:
                latest[receipt[1]] = digest
            for author, digest in latest.items():
                self._call(host, "latestOwnerRecordHashFor(uint256,bytes32,address)", ("bytes32",), (digest,),
                    ("uint256", "bytes32", "address"), (TOKEN, source.OWNER_TYPE, author))
        rows = self.independent_rows
        head = rows[-1][2][5] if rows else ZERO
        self._call(self.independent, "recordChainHash(uint256,bytes32)", ("bytes32", "uint64"),
            (head, len(rows)), ("uint256", "bytes32"), (COLLECTION, source.INDEPENDENT_TYPE))
        latest = {}
        for index, (digest, record, receipt, _subject, *_rest) in enumerate(rows):
            self._call(self.independent, "recordHashAt(uint256,bytes32,uint256)", ("bytes32",), (digest,),
                ("uint256", "bytes32", "uint256"), (COLLECTION, source.INDEPENDENT_TYPE, index))
            latest[(record[1], receipt[1])] = digest
        for (sid, author), digest in latest.items():
            self._call(self.independent, "latestCollectionRecordHashFor(uint256,bytes32,bytes32,address)",
                ("bytes32",), (digest,), ("uint256", "bytes32", "bytes32", "address"),
                (COLLECTION, source.INDEPENDENT_TYPE, sid, author))

    def _share_admission_action_same_receipt(self):
        """Coherent synthetic governance batch with two native admissions and one execution."""
        first_row, second_row = self.catalog_rows[0][0], self.catalog_rows[1][0]
        shared = first_row[5]
        changed = (*second_row[:4], 1003, shared)
        self._call(self.catalog, "sourceAt(uint64)", (source.SOURCE,), (changed,), ("uint64",), (2,))
        first_log, second_log = self.catalog_rows[0][3], self.catalog_rows[1][3]
        decoded = list(decode(("bytes32", "uint64", "bytes32", "bytes32", "bytes32", "uint16"),
            hex_bytes(second_log["data"])))
        decoded[4] = shared
        second_log["data"] = "0x" + encode(("bytes32", "uint64", "bytes32", "bytes32", "bytes32", "uint16"), decoded).hex()
        first_receipt = self.receipts[first_log["transactionHash"]]
        second_receipt = self.receipts.pop(second_log["transactionHash"])
        self.blocks[4]["transactions"].remove(second_receipt["transactionHash"])
        native = deepcopy(second_log)
        for key, value in (("transactionHash", first_receipt["transactionHash"]),
                ("blockHash", first_receipt["blockHash"]), ("blockNumber", first_receipt["blockNumber"]),
                ("transactionIndex", first_receipt["transactionIndex"]), ("logIndex", "0x1")):
            native[key] = value
        execution = first_receipt["logs"][1]
        execution["logIndex"] = "0x2"
        first_receipt["logs"] = [first_receipt["logs"][0], native, execution]

    def _finalize_anchor(self):
        self.a = {"profile": source.PROFILE, "chainId": str(CHAIN), "blockHash": self.blocks[8]["hash"],
            "blockNumber": "8", "timestamp": "1008", "stateRoot": self.blocks[8]["stateRoot"],
            "environment": "local_evm_fixture", "deploymentEvidenceHash": H("condition-deployment"),
            "core": self.core, "conditionSources": self.catalog, "executor": self.executor,
            "tokenId": str(TOKEN), "collectionId": str(COLLECTION),
            "codePins": [{"address": address, "runtimeHash": keccak256(raw)}
                for address, raw in sorted(self.codes.items())]}
        self.anchor = self.a

    @staticmethod
    def _matches(log, query):
        if log["address"] != query["address"] or len(log["topics"]) < len(query["topics"]): return False
        if not int(query["fromBlock"], 16) <= int(log["blockNumber"], 16) <= int(query["toBlock"], 16): return False
        return all(term is None or log["topics"][index] in (term if type(term) is list else [term])
            for index, term in enumerate(query["topics"]))

    def request(self, method, params):
        self.requested.append((method, deepcopy(params)))
        if method == "eth_chainId": return hex(CHAIN)
        if method == "eth_getCode": return "0x" + self.codes[params[0]].hex()
        if method == "eth_call":
            key = (params[0]["to"], params[0]["data"])
            if key not in self.responses: raise MuseumError("unexpected synthetic condition call")
            return deepcopy(self.responses[key])
        if method == "eth_getLogs":
            query, = params
            return [deepcopy(log) for receipt in self.receipts.values() for log in receipt["logs"] if self._matches(log, query)]
        if method == "eth_getTransactionReceipt": return deepcopy(self.receipts[params[0]])
        if method == "eth_getBlockByHash":
            return deepcopy(next(block for block in self.blocks.values() if block["hash"] == params[0]))
        if method == "eth_getBlockByNumber": return deepcopy(self.blocks[int(params[0], 16)])
        raise MuseumError("unexpected synthetic condition RPC method")

    def source(self, **kwargs): return source.PublicConditionSource(dumps(self.a), self, **kwargs)
    def result(self): return loads(self.source().snapshot(), maximum=source.MAX_OUTPUT)


class PublicConditionSourceTests(unittest.TestCase):
    def test_complete_catalogue_replacements_mixed_subjects_and_zero_capture_selection(self):
        fixture = PublicConditionFixture(); adapter = fixture.source()
        with patch("socket.socket", side_effect=AssertionError("synthetic fixture is offline")):
            result = loads(adapter.snapshot(), maximum=source.MAX_OUTPUT)
        self.assertEqual([row["lane"] for row in result["catalogue"]["sources"]],
            ["OWNER", "OWNER", "INDEPENDENT"])
        self.assertEqual(result["catalogue"]["sources"][1]["replacesSourceId"], "1")
        self.assertEqual([row["count"] for row in result["lanes"]], ["2", "1", "2"])
        self.assertEqual(sum(row["matchesToken"] for row in result["records"]), 4)
        owner_one = [row for row in result["records"] if row["host"] == fixture.owner1]
        self.assertLess(int(owner_one[0]["publication"]["blockNumber"]),
            int(result["catalogue"]["sources"][0]["admission"]["publication"]["blockNumber"]))
        self.assertGreater(int(owner_one[1]["publication"]["blockNumber"]),
            int(result["catalogue"]["sources"][1]["admission"]["publication"]["blockNumber"]))
        owner = result["selections"]["owner"]
        self.assertEqual(owner["status"], "present")
        self.assertEqual(owner["selected"]["host"], fixture.owner2)
        self.assertEqual(owner["interpretation"]["value"]["captures"], [])
        self.assertEqual(result["selections"]["independent"]["status"], "present")
        owner_positions = [row["publication"] for row in result["records"] if row["lane"] == "OWNER"]
        self.assertEqual((owner_positions[1]["blockNumber"], owner_positions[2]["blockNumber"]), ("6", "6"))
        self.assertNotEqual(owner_positions[1]["transactionIndex"], owner_positions[2]["transactionIndex"])
        independent_positions = [row["publication"] for row in result["records"] if row["lane"] == "INDEPENDENT"]
        self.assertEqual({row["transactionHash"] for row in independent_positions},
            {independent_positions[0]["transactionHash"]})
        self.assertEqual([row["logIndex"] for row in independent_positions], ["0", "1"])
        self.assertFalse(result["claims"]["actualChainAcceptance"])

    def test_empty_complete_denominator_is_scoped_none_recorded(self):
        result = PublicConditionFixture(empty=True).result()
        self.assertEqual(result["records"], [])
        self.assertTrue(all(row["count"] == "0" and row["head"] == ZERO for row in result["lanes"]))
        self.assertEqual(result["selections"], {"owner": {"status": "none_recorded", "selected": None, "interpretation": None},
            "independent": {"status": "none_recorded", "selected": None, "interpretation": None}})

    def test_unsupported_or_malformed_newest_is_selected_without_fallback(self):
        for option, reason in (({"unsupported_newest": True}, None), ({"malformed_newest": True}, "original_condition_payload_invalid")):
            fixture = PublicConditionFixture(**option); result = fixture.result(); selected = result["selections"]["owner"]
            self.assertEqual(selected["status"], "selected_unresolved")
            self.assertEqual(selected["selected"]["recordHash"], fixture.owner_rows[fixture.owner2][-1][0])
            self.assertIsNone(selected["interpretation"]["value"])
            if reason is not None: self.assertEqual(selected["interpretation"]["reasonCode"], reason)
            self.assertTrue(any(row["recordHash"] != selected["selected"]["recordHash"] for row in result["records"]
                if row["lane"] == "OWNER"))
        fixture = PublicConditionFixture(independent_unsupported_newest=True); result = fixture.result()
        selected = result["selections"]["independent"]
        self.assertEqual(selected["status"], "selected_unresolved")
        self.assertEqual(selected["selected"]["recordHash"], fixture.independent_rows[-1][0])
        self.assertIsNone(selected["interpretation"]["value"])

    def test_latest_across_owner_hosts_uses_same_transaction_log_order(self):
        fixture = PublicConditionFixture(same_tx_owner=True); result = fixture.result()
        rows = [row for row in result["records"] if row["lane"] == "OWNER"
            and row["publication"]["blockNumber"] == "6"]
        self.assertEqual(len(rows), 2)
        self.assertEqual({row["publication"]["transactionHash"] for row in rows},
            {rows[0]["publication"]["transactionHash"]})
        self.assertEqual([row["publication"]["logIndex"] for row in rows], ["0", "1"])
        self.assertEqual(result["selections"]["owner"]["selected"]["recordHash"], rows[1]["recordHash"])

    def test_catalogue_suffix_source_head_and_runtime_tamper_reject(self):
        for mode in ("suffix", "source", "head", "runtime"):
            fixture = PublicConditionFixture()
            if mode == "suffix":
                fixture._call(fixture.catalog, "sourceCount()", ("uint64",), (2,))
            elif mode == "source":
                row = list(fixture.catalog_rows[1][0]); row[0] = A(99)
                fixture._call(fixture.catalog, "sourceAt(uint64)", (source.SOURCE,), (tuple(row),), ("uint64",), (2,))
            elif mode == "head":
                fixture._call(fixture.catalog, "sourceSetHashAt(uint64)", ("bytes32",), (H("wrong-head"),), ("uint64",), (2,))
            else: fixture.codes[fixture.owner1] = b"changed"
            with self.subTest(mode=mode), self.assertRaises(MuseumError): fixture.source().snapshot()

    def test_original_receipt_lane_and_position_tamper_reject(self):
        for mode in ("receipt", "event", "lane-head", "position"):
            fixture = PublicConditionFixture()
            digest, record, receipt, bundle, *_ = fixture.owner_rows[fixture.owner1][0]
            if mode == "receipt":
                changed = list(receipt); changed[2] += 1
                fixture._call(fixture.owner1, "ownerRecord(bytes32)", (OWNER_RECORD, OWNER_RECEIPT),
                    (record, tuple(changed)), ("bytes32",), (digest,))
            elif mode == "event":
                target = next(log for receipt_ in fixture.receipts.values() for log in receipt_["logs"]
                    if log["address"] == fixture.owner1 and log["topics"][0] == source.OWNER_EVENT)
                target["topics"][3] = fixture.topic("address", A(99))
            elif mode == "lane-head":
                fixture._call(fixture.owner1, "recordChainHash(uint256,bytes32)", ("bytes32", "uint64"),
                    (H("wrong-lane"), 2), ("uint256", "bytes32"), (TOKEN, source.OWNER_TYPE))
            else:
                logs = [log for receipt_ in fixture.receipts.values() for log in receipt_["logs"]
                    if log["address"] in (fixture.owner1, fixture.owner2) and log["blockNumber"] == "0x6"]
                logs[1]["logIndex"] = logs[0]["logIndex"]
            with self.subTest(mode=mode), self.assertRaises(MuseumError): fixture.source().snapshot()

    def test_document_payload_subject_and_signature_bytes_are_authenticated(self):
        for mode in ("document", "payload", "subject", "bundle"):
            fixture = PublicConditionFixture()
            digest, record, receipt, subject, payload, bundle, *_ = fixture.independent_rows[-1]
            if mode == "document":
                raw, view = fixture.documents[schema_id(NAME)]; changed = list(view); changed[2] = H("wrong-declaration")
                fixture._call(fixture.schemas, "document(bytes32)", (DOCUMENT,), (tuple(changed),),
                    ("bytes32",), (schema_id(NAME),))
            elif mode == "payload":
                fixture._call(fixture.independent, "recordPayload(bytes32)", ("address", "bytes"),
                    (fixture._pointer(payload), payload + b"x"), ("bytes32",), (digest,))
            elif mode == "subject":
                fixture._call(fixture.independent, "recordSubject(bytes32)", (SUBJECT,),
                    ((1, COLLECTION, 72, ZERO),), ("bytes32",), (digest,))
            else:
                fixture._call(fixture.independent, "recordSignatureBundle(bytes32)", ("address", "bytes"),
                    (fixture._pointer(bundle), bundle + b"x"), ("bytes32",), (digest,))
            with self.subTest(mode=mode), self.assertRaises(MuseumError): fixture.source().snapshot()

    def test_governance_binding_admission_and_replacement_receipts_required(self):
        for mode in ("binding", "admission", "execution", "action", "replacement"):
            fixture = PublicConditionFixture()
            if mode == "binding": fixture.binding_log["topics"][2] = H("unknown-binding-action")
            elif mode == "admission": fixture.catalog_rows[1][3]["topics"][1] = fixture.topic("uint64", 1)
            elif mode == "execution":
                receipt = fixture.receipts[fixture.catalog_rows[0][3]["transactionHash"]]
                receipt["logs"].pop()
            elif mode == "action":
                action_id = fixture.catalog_rows[0][0][5]; stored = list(fixture.actions[action_id]); stored[0] = 2
                fixture._call(fixture.executor, "governanceAction(bytes32)", (source.ACTION,), (tuple(stored),),
                    ("bytes32",), (action_id,))
            else:
                row = list(fixture.catalog_rows[1][0]); row[3] = 3
                fixture._call(fixture.catalog, "sourceAt(uint64)", (source.SOURCE,), (tuple(row),), ("uint64",), (2,))
            with self.subTest(mode=mode), self.assertRaises(MuseumError): fixture.source().snapshot()

    def test_shared_batch_action_is_valid_but_same_action_across_transactions_rejects(self):
        shared = PublicConditionFixture(shared_action=True).result()
        actions = [row["actionId"] for row in shared["catalogue"]["sources"]]
        self.assertEqual(actions[0], actions[1])
        self.assertEqual(shared["catalogue"]["sources"][0]["admission"]["governance"],
            shared["catalogue"]["sources"][1]["admission"]["governance"])

        fixture = PublicConditionFixture()
        first, second = fixture.catalog_rows[0], fixture.catalog_rows[1]
        shared_action = first[0][5]
        changed = (*second[0][:5], shared_action)
        fixture._call(fixture.catalog, "sourceAt(uint64)", (source.SOURCE,), (changed,), ("uint64",), (2,))
        data = list(decode(("bytes32", "uint64", "bytes32", "bytes32", "bytes32", "uint16"),
            hex_bytes(second[3]["data"])))
        data[4] = shared_action
        second[3]["data"] = "0x" + encode(("bytes32", "uint64", "bytes32", "bytes32", "bytes32", "uint16"), data).hex()
        first_execution = fixture.receipts[first[3]["transactionHash"]]["logs"][1]
        second_execution = fixture.receipts[second[3]["transactionHash"]]["logs"][1]
        second_execution.update(address=first_execution["address"], topics=deepcopy(first_execution["topics"]),
            data=first_execution["data"])
        with self.assertRaisesRegex(MuseumError, "reused across transactions"):
            fixture.source().snapshot()

    def test_replay_is_exact_offline_and_rejects_suffix(self):
        fixture = PublicConditionFixture(unsupported_newest=True); original = fixture.source(); expected = original.snapshot()
        transcript = original.transcript()
        with patch("socket.socket", side_effect=AssertionError("offline replay only")):
            replay = source.PublicConditionSource(original.anchor_bytes,
                PublicReplayTransport(transcript, keccak256(transcript)))
            self.assertEqual(replay.snapshot(), expected)
        changed = loads(transcript, maximum=64 * 1024 * 1024)
        changed["calls"].append(deepcopy(changed["calls"][-1])); raw = dumps(changed)
        with self.assertRaisesRegex(MuseumError, "unconsumed"):
            source.PublicConditionSource(original.anchor_bytes,
                PublicReplayTransport(raw, keccak256(raw))).snapshot()

    def test_anchor_is_closed_and_trusted_mode_requires_real_transport_type(self):
        fixture = PublicConditionFixture(); fixture.a["conditionHosts"] = []
        with self.assertRaisesRegex(MuseumError, "anchor shape"): fixture.source()
        fixture = PublicConditionFixture()
        with self.assertRaisesRegex(MuseumError, "provenance"):
            fixture.source(provenance="trusted_rpc")


if __name__ == "__main__": unittest.main()

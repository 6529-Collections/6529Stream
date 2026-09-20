"""Synthetic conservation-floor ledger history; never actual-chain evidence."""
from copy import deepcopy
import unittest
from unittest.mock import patch

from .canonical import MuseumError, dumps, hex_bytes, keccak256, loads, schema_id
from .chain_abi import calldata, decode, encode
from .independent_wire import ZERO, ZERO_ADDRESS
from .public_history_rpc import PublicReplayTransport, PublicRpcTransport
from . import public_conservation_floor_source as source
from .test_owner_catalog_source import A, H


CHAIN, COLLECTION, FOREIGN = 31337, 7, 8
LITE = schema_id("MUSEUM_GRADE_LITE")
PREPARED_EVENT = schema_id(
    "ConservationPrimarySalePrepared(bytes32,address,bytes32,bytes32,bytes32,uint16)"
)


def _zero(kind):
    if isinstance(kind, tuple): return tuple(_zero(item) for item in kind)
    if kind == "address": return ZERO_ADDRESS
    if kind.startswith("bytes"): return ZERO if kind == "bytes32" else "0x" + "00" * int(kind[5:])
    if kind == "bool": return False
    return 0


class PublicConservationFloorFixture:
    """Complete synthetic ledger catalogue and original paid receipt histories."""

    MODES = {"paid_inline", "empty", "waived", "optional_preparation", "reused_release"}

    def __init__(self, *, mode="paid_inline", invalid_custody=False,
            invalid_source_timestamp=False):
        if mode not in self.MODES:
            raise ValueError("unsupported synthetic conservation floor mode")
        self.mode, self.invalid_custody = mode, invalid_custody
        self.core, self.floor, self.executor = A(1), A(2), A(3)
        self.metadata1, self.provider1 = A(10), A(11)
        self.metadata2, self.provider2 = A(12), A(13)
        self.recorder1, self.recorder2, self.foreign_recorder = A(20), A(21), A(22)
        self.sale1, self.sale2 = A(30), A(31)
        self.payment1, self.payment2, self.foreign_sale, self.foreign_payment = A(32), A(33), A(34), A(35)
        self.responses, self.receipts, self.requested = {}, {}, []
        self.codes = {address: b"\x60" + hex_bytes(address, 20)[-1:] + b"\x00" for address in (
            self.core, self.floor, self.executor, self.metadata1, self.provider1,
            self.metadata2, self.provider2, self.recorder1, self.recorder2,
            self.foreign_recorder, self.sale1, self.sale2, self.payment1, self.payment2,
            self.foreign_sale, self.foreign_payment)}
        self.blocks = {number: {"hash": H("floor-block-" + str(number)), "number": hex(number),
            "parentHash": H("floor-block-" + str(number - 1)) if number else ZERO,
            "timestamp": hex(3000 + number), "stateRoot": H("floor-state-" + str(number)),
            "transactions": []} for number in range(11)}
        if invalid_source_timestamp:
            self.blocks[2]["timestamp"] = "0x0"
        self.actions, self.sources = {}, []
        self.first_rows, self.release_rows, self.settlement_rows = [], [], []
        self._bindings()
        self._catalogue()
        if mode != "empty":
            if mode == "waived":
                self._paid("waived", COLLECTION, 4, self.recorder1, self.sale1, self.payment1,
                    source_id=0, tier=source.WAIVED, release_number=None)
            else:
                self._paid("first", COLLECTION, 4, self.recorder1, self.sale1, self.payment1,
                    source_id=1, release_number=1, preparation=mode == "optional_preparation",
                    invalid_custody=invalid_custody)
                self._paid("second", COLLECTION, 7, self.recorder2, self.sale2, self.payment2,
                    source_id=2, release_number=None if mode == "reused_release" else 2,
                    include_first=False,
                    reused_release=self.release_rows[0] if mode == "reused_release" else None)
                self._paid("foreign", FOREIGN, 8, self.foreign_recorder, self.foreign_sale,
                    self.foreign_payment,
                    source_id=0, tier=source.WAIVED, release_number=None)
        self._calls()
        self.a = {"profile": source.PROFILE, "chainId": str(CHAIN),
            "blockHash": self.blocks[10]["hash"], "blockNumber": "10", "timestamp": "3010",
            "stateRoot": self.blocks[10]["stateRoot"], "environment": "local_evm_fixture",
            "deploymentEvidenceHash": H("floor-deployment"), "core": self.core,
            "conservationFloor": self.floor, "executor": self.executor,
            "collectionId": str(COLLECTION), "codePins": [
                {"address": address, "runtimeHash": keccak256(code)}
                for address, code in sorted(self.codes.items())]}
        self.anchor = self.a

    @staticmethod
    def topic(kind, value):
        return "0x" + encode((kind,), (value,)).hex()

    def _call(self, target, signature, outputs, result, kinds=(), values=()):
        self.responses[(target, calldata(signature, kinds, values))] = "0x" + encode(outputs, result).hex()

    def _transaction(self, block, tag, logs):
        header = self.blocks[block]
        tx = H("floor-tx-" + tag)
        tx_index = len(header["transactions"])
        header["transactions"].append(tx)
        base = sum(len(self.receipts[item]["logs"]) for item in header["transactions"][:-1])
        receipt = {"transactionHash": tx, "blockHash": header["hash"], "blockNumber": hex(block),
            "transactionIndex": hex(tx_index), "status": "0x1", "logs": []}
        for offset, (address, topics, data) in enumerate(logs):
            receipt["logs"].append({"transactionHash": tx, "blockHash": header["hash"],
                "blockNumber": hex(block), "transactionIndex": hex(tx_index),
                "logIndex": hex(base + offset), "address": address, "topics": topics,
                "data": "0x" + data.hex(), "removed": False})
        self.receipts[tx] = receipt
        return receipt

    def _action(self, label, block, native_address, native_topics, native_data):
        action_id = H("floor-action-" + label)
        stamp = 3000 + block
        stored = (3, 1, A(50), 0, "0x12345678", H(label + "-calldata"), H(label + "-scope"),
            H(label + "-old"), H(label + "-new"), stamp - 1, stamp + 10, A(51), self.executor,
            A(52), A(53), H(label + "-policy"), label, H(label + "-result"))
        self.actions[action_id] = stored
        executed_topics = [source.EXECUTED_EVENT, action_id, self.topic("uint8", 1),
            self.topic("address", stored[2])]
        executed_data = encode(source.EXECUTED_DATA, (1, *stored[3:9], stored[12], stored[17]))
        receipt = self._transaction(block, label,
            [(native_address, native_topics, native_data),
             (self.executor, executed_topics, executed_data)])
        self._call(self.executor, "governanceAction(bytes32)", (source.ACTION,), (stored,),
            ("bytes32",), (action_id,))
        return action_id, receipt["logs"][0]

    def _bindings(self):
        action = H("floor-action-binding")
        topics = [source.BOUND_EVENT, self.topic("address", self.floor), action]
        actual, self.binding_log = self._action("binding", 1, self.core, topics,
            encode(("uint16", "bytes32"), (1, keccak256(self.codes[self.floor]))))
        assert actual == action

    def _catalogue(self):
        previous = source.empty_head({"chainId": str(CHAIN), "core": self.core,
            "conservationFloor": self.floor})
        self.empty_source_head = previous
        for source_id, (metadata, provider, block) in enumerate(((self.metadata1, self.provider1, 2),
                (self.metadata2, self.provider2, 5)), 1):
            action = H("floor-action-source-" + str(source_id))
            admitted_at = int(self.blocks[block]["timestamp"], 16)
            row = (metadata, keccak256(self.codes[metadata]), provider, keccak256(self.codes[provider]),
                H("floor-source-configuration-" + str(source_id)), source_id - 1, admitted_at, action)
            head = source.next_head(previous, source_id, row)
            topics = [source.ADDED_EVENT, self.topic("uint64", source_id),
                self.topic("address", metadata), self.topic("address", provider)]
            data = encode(("bytes32", source.SOURCE, "uint16"), (head, row, 1))
            actual, log = self._action("source-" + str(source_id), block, self.floor, topics, data)
            assert actual == action
            self.sources.append((row, previous, head, log))
            previous = head
        self.source_head = previous

    def _first_row(self, cid, recorder, key, block, source_id, tier):
        head = self.source_head if source_id == 2 else self.sources[0][2]
        if source_id == 0:
            head = self.sources[0][2] if block < 5 else self.source_head
        if tier == source.WAIVED:
            facts = (ZERO,) * 7 + (False,)
        else:
            facts = (ZERO, ZERO, ZERO, ZERO, ZERO, H("floor-rights-" + str(cid)), ZERO, True)
        row = (ZERO, cid, tier, recorder, key, 3000 + block, source_id, head, facts)
        row = (source.receipt_hash(self._hash_anchor(), source.FIRST_DOMAIN, source.FIRST, row), *row[1:])
        return row

    def _release_row(self, cid, recorder, key, block, source_id, number):
        context = (H(f"floor-scope-{cid}-{number}"), H(f"floor-membership-{cid}-{number}"),
            H(f"floor-media-{cid}-{number}"), ZERO, H(f"floor-context-{cid}-{number}"), False)
        semantic_key = source.release_key(self._hash_anchor(), cid, context)
        facts = (context[4], H(f"floor-media-evidence-{cid}-{number}"), ZERO)
        row = (ZERO, semantic_key, cid, LITE, recorder, key, 3000 + block, source_id,
            self.sources[source_id - 1][2], context, facts)
        row = (source.receipt_hash(self._hash_anchor(), source.RELEASE_DOMAIN, source.RELEASE, row), *row[1:])
        return row

    def _hash_anchor(self):
        return {"chainId": str(CHAIN), "core": self.core, "conservationFloor": self.floor}

    def _settlement_key(self, recorder, sale_adapter, execution_id):
        return keccak256(encode(("bytes32", "uint256", "address", "address", "bytes32"),
            (source.KEY_DOMAIN, CHAIN, recorder, sale_adapter, execution_id)))

    def _paid(self, label, cid, block, recorder, sale_adapter, payment_adapter, *, source_id,
            tier=LITE, release_number, include_first=True, preparation=False, invalid_custody=False,
            reused_release=None):
        execution_id = H("floor-execution-" + label)
        key = self._settlement_key(recorder, sale_adapter, execution_id)
        profile = H("floor-profile-" + label)
        wallet, asset, payer = A(60), A(61), A(62)
        amount = 1000 + block
        operation_root = ZERO if invalid_custody else H("floor-operation-root-" + label)
        operation_id = ZERO if invalid_custody else H("floor-operation-id-" + label)
        expected_policy = H("floor-expected-policy-" + label)
        current_policy = ZERO if invalid_custody else H("floor-current-policy-" + label)
        bound_policy = ZERO if invalid_custody else H("floor-bound-policy-" + label)
        assignment = H("floor-assignment-" + label)
        template = H("floor-template-" + label)
        settlement_id = H("floor-settlement-id-" + label)
        sale = (settlement_id, source.PRIMARY, 1, cid, 0 if invalid_custody else 100 + block,
            block, payer, A(63), A(64),
            amount, expected_policy)
        result = (H("floor-candidate-" + label), key, profile, wallet, asset, amount,
            self.executor, execution_id, False, operation_root, current_policy, bound_policy)
        first = None
        if include_first:
            first = self._first_row(cid, recorder, key, block, source_id, tier)
            self.first_rows.append(first)
        release = None
        if release_number is not None:
            release = self._release_row(cid, recorder, key, block, source_id, release_number)
            self.release_rows.append(release)
        first_hash = first[0] if first is not None else self.first_rows[0][0]
        release_hash = release[0] if release is not None else reused_release[0] if reused_release else ZERO
        settlement = (ZERO, recorder, keccak256(self.codes[recorder]), key,
            H("floor-candidate-payload-" + label), result[0], keccak256(encode(source.RESULT, result)),
            cid, sale[4], tier, first_hash, release_hash, 3000 + block)
        settlement = (source.receipt_hash(self._hash_anchor(), source.SETTLEMENT_DOMAIN,
            source.SETTLEMENT, settlement), *settlement[1:])
        self.settlement_rows.append(settlement)
        logs = []
        if preparation:
            logs.append((self.floor, [PREPARED_EVENT, key, self.topic("address", recorder), result[0]],
                encode(("bytes32", "bytes32", "uint16"),
                    (H("floor-preparation-" + label), keccak256(encode(source.RESULT, result)), 1))))
        if first is not None:
            logs.append((self.floor, [source.FIRST_EVENT, self.topic("uint256", cid), first[0]],
                encode((source.FIRST, "uint16"), (first, 1))))
        if release is not None:
            logs.append((self.floor, [source.RELEASE_EVENT, release[1], release[0]],
                encode((source.RELEASE, "uint16"), (release, 1))))
        logs.append((self.floor, [source.SETTLEMENT_EVENT, key, settlement[0]],
            encode((source.SETTLEMENT, "uint16"), (settlement, 1))))
        sale_hash = keccak256(encode(source.SALE, sale))
        logs.extend([
            (recorder, [source.SETTLED_EVENT, key, source.PRIMARY, profile],
                encode(source.SETTLED_DATA, (1, wallet, asset, payer, amount, sale_hash, False, 2))),
            (recorder, [source.CONTEXT_EVENT, key, source.PRIMARY, profile],
                encode(source.CONTEXT_DATA, (1, sale_adapter, settlement_id, 1, cid, sale[4],
                    operation_root, operation_id, sale[5], sale[7], sale[8], template))),
            (recorder, [source.POLICY_EVENT, key, source.PRIMARY, profile],
                encode(source.POLICY_DATA, (1, expected_policy, sale[10], assignment, template))),
            (recorder, [source.EXECUTION_EVENT, key, self.topic("address", sale_adapter), execution_id],
                encode(source.EXECUTION_DATA, (1, self.executor, payment_adapter, result[0],
                    current_policy, bound_policy)))])
        receipt = self._transaction(block, "paid-" + label, logs)
        self._call(self.floor, "settlementReceipt(bytes32)", (source.SETTLEMENT,), (settlement,),
            ("bytes32",), (key,))
        if first is not None:
            self._call(self.floor, "firstSale(uint256)", (source.FIRST,), (first,),
                ("uint256",), (cid,))
        if release is not None:
            self._call(self.floor, "releaseFloorReceipt(bytes32)", (source.RELEASE,), (release,),
                ("bytes32",), (release[1],))
        self._call(recorder, "settlementConsumed(bytes32)", ("bool",), (True,),
            ("bytes32",), (key,))
        self._call(recorder, "settlementResult(bytes32)", source.RESULT, result,
            ("bytes32",), (key,))
        return receipt

    def _calls(self):
        for host, interface in ((self.core, source.CORE_INTERFACE), (self.floor, source.FLOOR_INTERFACE)):
            for expected, value in ((interface, True), ("0x01ffc9a7", True), ("0xffffffff", False)):
                self._call(host, "supportsInterface(bytes4)", ("bool",), (value,),
                    ("bytes4",), (expected,))
        self._call(self.core, "conservationFloor()", ("address", "bytes32"),
            (self.floor, keccak256(self.codes[self.floor])))
        for getter, kind, value in (("core", "address", self.core),
                ("coreCodeHash", "bytes32", keccak256(self.codes[self.core])),
                ("governanceAuthority", "address", self.executor),
                ("executorCodeHash", "bytes32", keccak256(self.codes[self.executor])),
                ("deploymentChainId", "uint256", CHAIN)):
            self._call(self.floor, getter + "()", (kind,), (value,))
        self._call(self.core, "collectionExists(uint256)", ("bool",), (True,),
            ("uint256",), (COLLECTION,))
        if not self.first_rows:
            self._call(self.floor, "firstSale(uint256)", (source.FIRST,), (_zero(source.FIRST),),
                ("uint256",), (COLLECTION,))
        self._call(self.floor, "sourceSetHead()", ("uint64", "bytes32"),
            (len(self.sources), self.source_head))
        self._call(self.floor, "sourceCount()", ("uint64",), (len(self.sources),))
        self._call(self.floor, "sourceSetHashAt(uint64)", ("bytes32",), (self.empty_source_head,),
            ("uint64",), (0,))
        for index, (row, _previous, head, _log) in enumerate(self.sources, 1):
            self._call(self.floor, "sourceAt(uint64)", (source.SOURCE,), (row,), ("uint64",), (index,))
            self._call(self.floor, "sourceSetHashAt(uint64)", ("bytes32",), (head,),
                ("uint64",), (index,))

    @staticmethod
    def _matches(log, query):
        if log["address"] != query["address"] or len(log["topics"]) < len(query["topics"]):
            return False
        if not int(query["fromBlock"], 16) <= int(log["blockNumber"], 16) <= int(query["toBlock"], 16):
            return False
        return all(term is None or log["topics"][index] in (term if type(term) is list else [term])
            for index, term in enumerate(query["topics"]))

    def request(self, method, params):
        self.requested.append((method, deepcopy(params)))
        if method == "eth_chainId": return hex(CHAIN)
        if method == "eth_getCode": return "0x" + self.codes[params[0]].hex()
        if method == "eth_call":
            key = (params[0]["to"], params[0]["data"])
            if key not in self.responses: raise MuseumError("unexpected synthetic conservation floor call")
            return deepcopy(self.responses[key])
        if method == "eth_getLogs":
            query, = params
            return [deepcopy(log) for receipt in self.receipts.values() for log in receipt["logs"]
                if self._matches(log, query)]
        if method == "eth_getTransactionReceipt": return deepcopy(self.receipts[params[0]])
        if method == "eth_getBlockByHash":
            return deepcopy(next(block for block in self.blocks.values() if block["hash"] == params[0]))
        if method == "eth_getBlockByNumber": return deepcopy(self.blocks[int(params[0], 16)])
        raise MuseumError("unexpected synthetic conservation floor RPC")

    def source(self, **kwargs):
        return source.PublicConservationFloorSource(dumps(self.a), self, **kwargs)

    def result(self):
        return loads(self.source().snapshot(), maximum=source.MAX_OUTPUT)


class PublicConservationFloorSourceTests(unittest.TestCase):
    def test_paid_inline_retains_replacement_sources_two_releases_and_original_sales(self):
        result = PublicConservationFloorFixture().result()
        self.assertEqual(result["floor"]["status"], "present")
        self.assertEqual(result["catalogue"]["count"], "2")
        self.assertEqual(len(result["floor"]["releases"]), 2)
        self.assertEqual(len(result["floor"]["settlements"]), 2)
        self.assertEqual([row["sourceId"] for row in result["floor"]["releases"]], ["1", "2"])
        self.assertEqual([row["recorder"] for row in result["floor"]["settlements"]],
            [A(20), A(21)])
        self.assertEqual(result["historyCoverage"]["ledgerReceiptEventCount"], "7")
        self.assertEqual(result["historyCoverage"]["targetReceiptEventCount"], "5")
        self.assertTrue(any(row["receipt"][7] == str(FOREIGN)
            for row in result["historyCoverage"]["ledgerReceiptEvents"]
            if row["kind"] == "settlement"))
        self.assertFalse(result["claims"]["candidatePreimageRecovered"])

    def test_empty_and_waived_are_explicit(self):
        empty = PublicConservationFloorFixture(mode="empty").result()
        self.assertEqual(empty["floor"]["status"], "none_recorded")
        waived = PublicConservationFloorFixture(mode="waived").result()
        self.assertEqual(waived["floor"]["firstSale"]["effectiveTier"], "CONSERVATION_WAIVED")
        self.assertEqual(waived["floor"]["releases"], [])

    def test_optional_preparation_does_not_change_paid_receipts(self):
        direct = PublicConservationFloorFixture().result()["floor"]
        prepared_fixture = PublicConservationFloorFixture(mode="optional_preparation")
        prepared = prepared_fixture.result()["floor"]
        self.assertEqual(prepared["firstSale"]["receipt"], direct["firstSale"]["receipt"])
        self.assertEqual([row["receipt"] for row in prepared["releases"]],
            [row["receipt"] for row in direct["releases"]])
        self.assertEqual([row["receipt"] for row in prepared["settlements"]],
            [row["receipt"] for row in direct["settlements"]])
        self.assertTrue(any(log["topics"][0] == PREPARED_EVENT for receipt in prepared_fixture.receipts.values()
            for log in receipt["logs"]))

    def test_reused_release_retains_original_receipt_without_duplicate_publication(self):
        result = PublicConservationFloorFixture(mode="reused_release").result()["floor"]
        self.assertEqual(len(result["releases"]), 1)
        self.assertEqual(len(result["settlements"]), 2)
        self.assertEqual({row["releaseReceiptHash"] for row in result["settlements"]},
            {result["releases"][0]["receiptHash"]})
        self.assertEqual(result["releases"][0]["sourceId"], "1")

    def test_duplicate_release_publication_is_rejected(self):
        fixture = PublicConservationFloorFixture(mode="reused_release")
        original = next(log for receipt in fixture.receipts.values() for log in receipt["logs"]
            if log["topics"][0] == source.RELEASE_EVENT)
        fixture._transaction(9, "duplicate-release", [(fixture.floor, original["topics"],
            hex_bytes(original["data"]))])
        with self.assertRaisesRegex(MuseumError, "duplicate"):
            fixture.source().snapshot()

    def test_catalogue_heads_governance_runtime_and_binding_are_exact(self):
        for mode in ("head", "admission", "action", "runtime", "binding"):
            fixture = PublicConservationFloorFixture()
            if mode == "head":
                fixture._call(fixture.floor, "sourceSetHashAt(uint64)", ("bytes32",),
                    (H("wrong-source-head"),), ("uint64",), (2,))
            elif mode == "admission":
                fixture.sources[-1][3]["topics"][0] = H("missing-source-admission")
            elif mode == "action":
                action = fixture.sources[-1][0][7]
                row = list(fixture.actions[action]); row[0] = 2
                fixture._call(fixture.executor, "governanceAction(bytes32)", (source.ACTION,),
                    (tuple(row),), ("bytes32",), (action,))
            elif mode == "runtime": fixture.codes[fixture.provider2] = b"changed-provider-runtime"
            else:
                fixture._call(fixture.core, "conservationFloor()", ("address", "bytes32"),
                    (fixture.floor, H("wrong-floor-runtime")))
            with self.subTest(mode=mode), self.assertRaises(MuseumError): fixture.source().snapshot()

    def test_ledger_denominator_and_original_receipt_hash_getter_and_events_fail_closed(self):
        for mode in ("foreign-hash", "getter", "stored-result", "missing-event", "event-order", "failed-receipt"):
            fixture = PublicConservationFloorFixture()
            if mode == "foreign-hash":
                target = next(log for receipt in fixture.receipts.values() for log in receipt["logs"]
                    if log["topics"][0] == source.SETTLEMENT_EVENT and
                    decode((source.SETTLEMENT, "uint16"), hex_bytes(log["data"]))[0][7] == FOREIGN)
                row, version = decode((source.SETTLEMENT, "uint16"), hex_bytes(target["data"]))
                changed = (*row[:4], H("changed-foreign-candidate-payload"), *row[5:])
                target["data"] = "0x" + encode((source.SETTLEMENT, "uint16"), (changed, version)).hex()
            else:
                target = next(row for row in fixture.settlement_rows if row[7] == COLLECTION)
                receipt = next(value for value in fixture.receipts.values()
                    if any(log["topics"][0] == source.SETTLEMENT_EVENT and log["topics"][1] == target[3]
                        for log in value["logs"]))
                if mode == "getter":
                    fixture._call(fixture.floor, "settlementReceipt(bytes32)", (source.SETTLEMENT,),
                        (_zero(source.SETTLEMENT),), ("bytes32",), (target[3],))
                elif mode == "stored-result":
                    result = list(decode(source.RESULT,
                        hex_bytes(fixture.responses[(target[1], calldata("settlementResult(bytes32)",
                            ("bytes32",), (target[3],)))])))
                    result[5] += 1
                    fixture._call(target[1], "settlementResult(bytes32)", source.RESULT, tuple(result),
                        ("bytes32",), (target[3],))
                elif mode == "missing-event":
                    receipt["logs"] = [log for log in receipt["logs"] if log["topics"][0] != source.POLICY_EVENT]
                elif mode == "event-order":
                    settled = next(log for log in receipt["logs"] if log["topics"][0] == source.SETTLED_EVENT)
                    context = next(log for log in receipt["logs"] if log["topics"][0] == source.CONTEXT_EVENT)
                    context["logIndex"] = settled["logIndex"]
                else: receipt["status"] = "0x0"
            with self.subTest(mode=mode), self.assertRaises(MuseumError): fixture.source().snapshot()

    def test_first_release_settlement_positions_and_custody_branch_are_native_exact(self):
        fixture = PublicConservationFloorFixture()
        receipt = next(value for value in fixture.receipts.values()
            if any(log["topics"][0] == source.FIRST_EVENT and
                log["topics"][1] == fixture.topic("uint256", COLLECTION) for log in value["logs"]))
        first = next(log for log in receipt["logs"] if log["topics"][0] == source.FIRST_EVENT)
        release = next(log for log in receipt["logs"] if log["topics"][0] == source.RELEASE_EVENT)
        first["logIndex"], release["logIndex"] = release["logIndex"], first["logIndex"]
        with self.assertRaisesRegex(MuseumError, "order"):
            fixture.source().snapshot()
        with self.assertRaisesRegex(MuseumError, "operation projection"):
            PublicConservationFloorFixture(invalid_custody=True).source().snapshot()

    def test_zero_source_admission_timestamp_rejects_before_interpretation(self):
        with self.assertRaisesRegex(MuseumError, "source member"):
            PublicConservationFloorFixture(invalid_source_timestamp=True).source().snapshot()

    def test_no_current_metadata_provider_sale_adapter_or_registry_reads(self):
        fixture = PublicConservationFloorFixture(); fixture.source().snapshot()
        forbidden = {fixture.metadata1, fixture.provider1, fixture.metadata2, fixture.provider2,
            fixture.sale1, fixture.sale2, fixture.payment1, fixture.payment2,
            fixture.foreign_sale, fixture.foreign_payment}
        self.assertFalse(any(method == "eth_call" and params[0]["to"] in forbidden
            for method, params in fixture.requested))
        self.assertFalse(any(method == "eth_getLogs" and params[0]["address"] in forbidden
            for method, params in fixture.requested))

    def test_only_core_ledger_executor_and_target_recorders_need_runtime_pins(self):
        fixture = PublicConservationFloorFixture()
        retained = {fixture.core, fixture.floor, fixture.executor, fixture.recorder1, fixture.recorder2}
        removed = set(fixture.codes) - retained
        self.assertIn(fixture.foreign_recorder, removed)
        fixture.a["codePins"] = [row for row in fixture.a["codePins"] if row["address"] in retained]
        result = fixture.result()
        self.assertEqual(result["floor"]["status"], "present")
        self.assertEqual(result["historyCoverage"]["ledgerReceiptEventCount"], "7")
        self.assertFalse(any(method == "eth_getCode" and params[0] in removed
            for method, params in fixture.requested))
        self.assertFalse(any(method == "eth_call" and params[0]["to"] in removed
            for method, params in fixture.requested))

    def test_explicit_source_receipt_and_pin_bounds_fail_without_truncation(self):
        cases = (("MAX_SOURCES", 1, "source bound/count"),
            ("MAX_RECEIPTS", 6, "ledger event bound"))
        for name, value, message in cases:
            fixture = PublicConservationFloorFixture()
            with self.subTest(name=name), patch.object(source, name, value), \
                    self.assertRaisesRegex(MuseumError, message):
                fixture.source().snapshot()
        fixture = PublicConservationFloorFixture()
        with patch.object(source, "MAX_PINS", len(fixture.a["codePins"]) - 1), \
                self.assertRaisesRegex(MuseumError, "pin bound"):
            fixture.source()

    def test_zero_paid_recorded_at_rejects_before_any_followup_read(self):
        fixture = PublicConservationFloorFixture(); adapter = fixture.source()
        adapter._history = {"blockTimestamps": {"4": "0"}}
        first_log = next(log for receipt in fixture.receipts.values() for log in receipt["logs"]
            if log["topics"][0] == source.FIRST_EVENT and log["topics"][1] == fixture.topic("uint256", COLLECTION))
        release_log = next(log for receipt in fixture.receipts.values() for log in receipt["logs"]
            if log["topics"][0] == source.RELEASE_EVENT and log["transactionHash"] == first_log["transactionHash"])
        settlement_log = next(log for receipt in fixture.receipts.values() for log in receipt["logs"]
            if log["topics"][0] == source.SETTLEMENT_EVENT and log["transactionHash"] == first_log["transactionHash"])
        first = fixture.first_rows[0]; release = fixture.release_rows[0]; settlement = fixture.settlement_rows[0]
        before = list(fixture.requested)
        controls = ((adapter._first, (*first[:5], 0, *first[6:]), first_log, "first sale"),
            (adapter._release, (*release[:6], 0, *release[7:]), release_log, "release"),
            (adapter._settlement, (*settlement[:12], 0), settlement_log, "settlement"))
        for method, row, log, message in controls:
            with self.subTest(method=method.__name__), self.assertRaisesRegex(MuseumError, message):
                if method.__name__ == "_settlement": method(row, log)
                else: method(row, log, {})
            self.assertEqual(fixture.requested, before)

    def test_closed_anchor_and_failed_capture_cannot_resume(self):
        fixture = PublicConservationFloorFixture(); fixture.a["tokenId"] = "1"
        with self.assertRaisesRegex(MuseumError, "anchor shape"): fixture.source()
        fixture = PublicConservationFloorFixture(); adapter = fixture.source()
        fixture.codes[fixture.floor] = b"changed"
        with self.assertRaises(MuseumError): adapter.snapshot()
        with self.assertRaisesRegex(MuseumError, "cannot resume"): adapter.snapshot()

    def test_exact_offline_replay_and_provenance(self):
        fixture = PublicConservationFloorFixture(); original = fixture.source()
        raw, transcript = original.snapshot(), original.transcript()
        with patch("socket.socket", side_effect=AssertionError("offline only")):
            replay = source.PublicConservationFloorSource(original.anchor_bytes,
                PublicReplayTransport(transcript, keccak256(transcript)))
            self.assertEqual(replay.snapshot(), raw)
        with self.assertRaisesRegex(MuseumError, "provenance"):
            fixture.source(provenance="trusted_rpc")
        transport = PublicRpcTransport("https://example.invalid")
        with patch.object(PublicRpcTransport, "request", side_effect=fixture.request), \
                patch("socket.socket", side_effect=AssertionError("synthetic only")):
            trusted = source.PublicConservationFloorSource(dumps(fixture.a), transport,
                provenance="trusted_rpc")
            self.assertEqual(loads(trusted.snapshot(), maximum=source.MAX_OUTPUT)["mode"],
                "caller_admitted_rpc_conservation_floor")


if __name__ == "__main__": unittest.main()

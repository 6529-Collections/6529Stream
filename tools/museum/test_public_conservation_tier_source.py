"""Synthetic Core conservation-tier history; never actual-chain evidence."""
from copy import deepcopy
import unittest
from unittest.mock import patch

from .canonical import MuseumError, dumps, keccak256, loads, schema_id
from .chain_abi import calldata, encode
from .independent_wire import ZERO, ZERO_ADDRESS
from .mint_entropy_source import REGISTERED, REVERTED, TRANSFER
from .public_history_rpc import PublicReplayTransport, PublicRpcTransport
from . import public_conservation_tier_source as source
from .test_owner_catalog_source import A, H


CHAIN, COLLECTION = 31337, 7


class PublicConservationTierFixture:
    """Exact synthetic event/state joins for the public tier reader."""

    MODES = {"full_history", "never_minted", "declared", "default", "prepared_reverted",
        "aborted_then_completed"}

    def __init__(self, *, mode="full_history", tier="MUSEUM_GRADE", burned=None):
        if mode not in self.MODES or tier not in ("MUSEUM_GRADE", "MUSEUM_GRADE_LITE", "CONSERVATION_WAIVED"):
            raise ValueError("unsupported synthetic conservation tier mode")
        self.mode, self.tier_name = mode, tier
        self.core, self.facade = A(1), A(20)
        self.core_code = b"\x60\x01\x60\x00"
        self.responses, self.receipts, self.requested = {}, {}, []
        self.blocks = {number: {"hash": H("tier-block-" + str(number)), "number": hex(number),
            "parentHash": H("tier-block-" + str(number - 1)) if number else ZERO,
            "timestamp": hex(2000 + number), "stateRoot": H("tier-state-" + str(number)),
            "transactions": []} for number in range(9)}
        self.allocations, self.completed = [], []
        self.declared = ZERO
        if mode in ("full_history", "declared"):
            self.declared = schema_id(tier)
            self._declaration(1)
        if mode == "full_history":
            self._register(101, 1, 2, completed=True)
            self._register(102, 2, 3); self._revert(102, 4)
            self._register(103, 3, 5)
        elif mode == "default":
            self._register(101, 1, 2, completed=True)
        elif mode == "prepared_reverted":
            self._register(101, 1, 2); self._revert(101, 3)
            self._register(102, 2, 4)
        elif mode == "aborted_then_completed":
            self._register(101, 1, 2); self._revert(101, 3)
            self._register(102, 2, 4, completed=True)
        self.minted = len(self.completed)
        self.next_serial = len(self.allocations) + 1
        if burned is None: burned = mode == "full_history"
        self.burned = burned
        self._calls()
        self.a = {"profile": source.PROFILE, "chainId": str(CHAIN), "blockHash": self.blocks[8]["hash"],
            "blockNumber": "8", "timestamp": "2008", "stateRoot": self.blocks[8]["stateRoot"],
            "environment": "local_evm_fixture", "deploymentEvidenceHash": H("tier-deployment"),
            "core": self.core, "coreRuntimeHash": keccak256(self.core_code), "collectionId": str(COLLECTION)}
        self.anchor = self.a

    @staticmethod
    def topic(kind, value): return "0x" + encode((kind,), (value,)).hex()

    def _call(self, signature, outputs, result, kinds=(), values=()):
        self.responses[(self.core, calldata(signature, kinds, values))] = "0x" + encode(outputs, result).hex()

    def _transaction(self, block, tag, logs):
        header = self.blocks[block]; tx = H("tier-tx-" + tag); tx_index = len(header["transactions"])
        header["transactions"].append(tx)
        base = sum(len(self.receipts[item]["logs"]) for item in header["transactions"][:-1])
        receipt = {"transactionHash": tx, "blockHash": header["hash"], "blockNumber": hex(block),
            "transactionIndex": hex(tx_index), "status": "0x1", "logs": []}
        for offset, (address, topics, data) in enumerate(logs):
            receipt["logs"].append({"transactionHash": tx, "blockHash": header["hash"],
                "blockNumber": hex(block), "transactionIndex": hex(tx_index), "logIndex": hex(base + offset),
                "address": address, "topics": topics, "data": "0x" + data.hex(), "removed": False})
        self.receipts[tx] = receipt
        return receipt

    def _declaration(self, block):
        collection = self.topic("uint256", COLLECTION); tier = schema_id(self.tier_name)
        core = (self.core, [source.CORE_TIER_EVENT, collection, tier, self.topic("address", self.facade)],
            encode(("uint16",), (1,)))
        facade = (self.facade, [source.FACADE_TIER_EVENT, collection, tier], encode(("uint16",), (1,)))
        self.declaration_receipt = self._transaction(block, "declaration", [core, facade])

    def _register(self, token, serial, block, *, completed=False):
        topics = [REGISTERED, self.topic("uint256", token), self.topic("uint256", COLLECTION)]
        logs = [(self.core, topics, encode(("uint16", "uint256"), (1, serial)))]
        if completed:
            logs.append((self.core, [TRANSFER, ZERO, self.topic("address", A(30 + serial)),
                self.topic("uint256", token)], b""))
            self.completed.append(token)
        self._transaction(block, "register-" + str(token), logs)
        self.allocations.append({"token": token, "serial": serial, "reverted": False})

    def _revert(self, token, block):
        row = next(value for value in self.allocations if value["token"] == token)
        row["reverted"] = True
        self._transaction(block, "revert-" + str(token), [(self.core,
            [REVERTED, self.topic("uint256", token), self.topic("uint256", COLLECTION)],
            encode(("uint16",), (1,)))])

    def _calls(self):
        for interface, value in (("0xc10ccea9", True), ("0x80ac58cd", True),
                ("0x01ffc9a7", True), ("0xffffffff", False)):
            self._call("supportsInterface(bytes4)", ("bool",), (value,), ("bytes4",), (interface,))
        self._call("collectionExists(uint256)", ("bool",), (True,), ("uint256",), (COLLECTION,))
        self._call("declaredConservationTier(uint256)", ("bytes32",), (self.declared,),
            ("uint256",), (COLLECTION,))
        self._call("collectionMintedEver(uint256)", ("uint256",), (self.minted,),
            ("uint256",), (COLLECTION,))
        self._call("collectionNextSerial(uint256)", ("uint256",), (self.next_serial,),
            ("uint256",), (COLLECTION,))
        for row in self.allocations:
            token, serial = row["token"], row["serial"]
            if row["reverted"]:
                identity, lifecycle = (False, 0, 0, False), 0
            elif token in self.completed:
                is_burned = self.burned and token == self.completed[0]
                identity, lifecycle = (True, COLLECTION, serial, is_burned), 3 if is_burned else 2
            else:
                identity, lifecycle = (True, COLLECTION, serial, False), 1
            self._call("tokenCollectionIdentity(uint256)", ("bool", "uint256", "uint256", "bool"),
                identity, ("uint256",), (token,))
            self._call("tokenLifecycle(uint256)", ("uint8",), (lifecycle,), ("uint256",), (token,))

    @staticmethod
    def _matches(log, query):
        if log["address"] != query["address"] or len(log["topics"]) < len(query["topics"]): return False
        if not int(query["fromBlock"], 16) <= int(log["blockNumber"], 16) <= int(query["toBlock"], 16): return False
        return all(term is None or log["topics"][index] in (term if type(term) is list else [term])
            for index, term in enumerate(query["topics"]))

    def request(self, method, params):
        self.requested.append((method, deepcopy(params)))
        if method == "eth_chainId": return hex(CHAIN)
        if method == "eth_getCode": return "0x" + self.core_code.hex()
        if method == "eth_call":
            key = (params[0]["to"], params[0]["data"])
            if key not in self.responses: raise MuseumError("unexpected synthetic conservation tier call")
            return deepcopy(self.responses[key])
        if method == "eth_getLogs":
            query, = params
            return [deepcopy(log) for receipt in self.receipts.values() for log in receipt["logs"]
                if self._matches(log, query)]
        if method == "eth_getTransactionReceipt": return deepcopy(self.receipts[params[0]])
        if method == "eth_getBlockByHash":
            return deepcopy(next(block for block in self.blocks.values() if block["hash"] == params[0]))
        if method == "eth_getBlockByNumber": return deepcopy(self.blocks[int(params[0], 16)])
        raise MuseumError("unexpected synthetic conservation tier RPC")

    def source(self, **kwargs): return source.PublicConservationTierSource(dumps(self.a), self, **kwargs)
    def result(self): return loads(self.source().snapshot(), maximum=source.MAX_OUTPUT)


class PublicConservationTierSourceTests(unittest.TestCase):
    def test_full_history_retains_declared_tier_allocations_completed_mint_and_burn(self):
        fixture = PublicConservationTierFixture(); adapter = fixture.source(); result = loads(adapter.snapshot(), maximum=source.MAX_OUTPUT)
        self.assertEqual(result["tier"]["declaredTier"], "MUSEUM_GRADE")
        self.assertEqual(result["tier"]["effectiveTier"], "MUSEUM_GRADE")
        self.assertEqual(result["tier"]["tierBasis"], "declared")
        self.assertEqual([row["status"] for row in result["allocations"]],
            ["burned", "aborted", "prepared_incomplete"])
        self.assertEqual([row["tokenId"] for row in result["completedMints"]], ["101"])
        self.assertEqual(result["tier"]["firstCompletedMint"], result["completedMints"][0])
        self.assertEqual(result["tier"]["declaration"]["metadataHost"], fixture.facade)
        self.assertFalse(result["claims"]["historicalFacadeGrantsReexecuted"])
        self.assertFalse(any(call[0] == "eth_call" and call[1][0]["to"] == fixture.facade for call in fixture.requested))

    def test_never_minted_zero_is_not_effective_but_sale_rule_is_lite(self):
        result = PublicConservationTierFixture(mode="never_minted").result(); tier = result["tier"]
        self.assertEqual(tier["rawDeclaredTier"], ZERO)
        self.assertIsNone(tier["declaredTier"]); self.assertIsNone(tier["effectiveTier"])
        self.assertEqual(tier["tierBasis"], "not_yet_effective")
        self.assertEqual((tier["prospectiveSaleTier"], tier["prospectiveSaleTierBasis"]),
            ("MUSEUM_GRADE_LITE", "undeclared_lite_floor_rule"))
        self.assertEqual(result["allocations"], []); self.assertEqual(result["completedMints"], [])
        self.assertEqual(result["historyCoverage"]["mintScanStatus"], "not_queried_no_allocations")

    def test_all_explicit_tiers_apply_before_mint_without_defaulting(self):
        for label in ("MUSEUM_GRADE", "MUSEUM_GRADE_LITE", "CONSERVATION_WAIVED"):
            with self.subTest(label=label):
                result = PublicConservationTierFixture(mode="declared", tier=label).result(); tier = result["tier"]
                self.assertEqual((tier["declaredTier"], tier["effectiveTier"], tier["prospectiveSaleTier"]),
                    (label, label, label))
                self.assertEqual(tier["completedMintCount"], "0")
                self.assertIsNotNone(tier["declaration"])

    def test_undeclared_first_completion_defaults_lite_and_burn_does_not_undo(self):
        for burned in (False, True):
            result = PublicConservationTierFixture(mode="default", burned=burned).result(); tier = result["tier"]
            self.assertEqual((tier["rawDeclaredTier"], tier["declaredTier"]), (ZERO, None))
            self.assertEqual((tier["tierBasis"], tier["effectiveTier"]), ("default", "MUSEUM_GRADE_LITE"))
            self.assertEqual(result["allocations"][0]["status"], "burned" if burned else "minted")
            self.assertEqual(tier["completedMintCount"], "1")

    def test_reverted_and_prepared_allocations_do_not_activate_default(self):
        result = PublicConservationTierFixture(mode="prepared_reverted").result(); tier = result["tier"]
        self.assertEqual([row["status"] for row in result["allocations"]], ["aborted", "prepared_incomplete"])
        self.assertEqual(result["completedMints"], [])
        self.assertEqual((tier["tierBasis"], tier["effectiveTier"], tier["completedMintCount"]),
            ("not_yet_effective", None, "0"))

    def test_aborted_serial_then_completed_serial_is_sequential_and_defaults_lite(self):
        result = PublicConservationTierFixture(mode="aborted_then_completed").result()
        self.assertEqual([row["status"] for row in result["allocations"]], ["aborted", "minted"])
        self.assertEqual([row["tokenId"] for row in result["completedMints"]], ["102"])
        self.assertEqual((result["tier"]["tierBasis"], result["tier"]["effectiveTier"]),
            ("default", "MUSEUM_GRADE_LITE"))

    def test_overlapping_next_allocation_and_reordered_completion_reject(self):
        first = PublicConservationTierFixture(mode="prepared_reverted")
        registration = next((tx, receipt) for tx, receipt in first.receipts.items()
            if any(log["topics"][0] == REGISTERED and log["topics"][1] == first.topic("uint256", 102)
                for log in receipt["logs"]))
        tx, receipt = registration
        first.blocks[4]["transactions"].remove(tx); first.blocks[2]["transactions"].append(tx)
        receipt.update(blockHash=first.blocks[2]["hash"], blockNumber="0x2", transactionIndex="0x1")
        for log in receipt["logs"]:
            log.update(blockHash=receipt["blockHash"], blockNumber="0x2", transactionIndex="0x1", logIndex="0x1")
        with self.assertRaisesRegex(MuseumError, "overlapping allocation"):
            first.source().snapshot()

        second = PublicConservationTierFixture()
        registered = next(receipt for receipt in second.receipts.values()
            if any(log["topics"][0] == REGISTERED and log["topics"][1] == second.topic("uint256", 101)
                for log in receipt["logs"]))
        transfer = registered["logs"].pop()
        second._transaction(4, "late-first-completion", [(transfer["address"], transfer["topics"], b"")])
        with self.assertRaisesRegex(MuseumError, "overlapping allocation"):
            second.source().snapshot()

    def test_missing_allocation_suffix_mint_or_revert_history_rejects_state(self):
        for mode in ("allocation", "mint", "revert", "count"):
            fixture = PublicConservationTierFixture()
            if mode == "allocation":
                target = next(log for receipt in fixture.receipts.values() for log in receipt["logs"]
                    if log["topics"][0] == REGISTERED and log["topics"][1] == fixture.topic("uint256", 103))
            elif mode == "mint":
                target = next(log for receipt in fixture.receipts.values() for log in receipt["logs"] if log["topics"][0] == TRANSFER)
            elif mode == "revert":
                target = next(log for receipt in fixture.receipts.values() for log in receipt["logs"] if log["topics"][0] == REVERTED)
            else:
                fixture._call("collectionNextSerial(uint256)", ("uint256",), (5,), ("uint256",), (COLLECTION,)); target = None
            if target is not None: target["topics"][0] = H("omitted-tier-history")
            with self.subTest(mode=mode), self.assertRaises(MuseumError): fixture.source().snapshot()

    def test_duplicate_out_of_order_and_reused_allocations_reject(self):
        for mode in ("duplicate", "serial", "token", "post-mint-declaration"):
            fixture = PublicConservationTierFixture()
            if mode == "duplicate":
                original = next(log for receipt in fixture.receipts.values() for log in receipt["logs"] if log["topics"][0] == REGISTERED)
                fixture._transaction(7, "duplicate-allocation", [(fixture.core, original["topics"],
                    bytes.fromhex(original["data"][2:]))])
            elif mode == "serial":
                target = next(log for receipt in fixture.receipts.values() for log in receipt["logs"]
                    if log["topics"][0] == REGISTERED and log["topics"][1] == fixture.topic("uint256", 102))
                target["data"] = "0x" + encode(("uint16", "uint256"), (1, 3)).hex()
            elif mode == "token":
                target = next(log for receipt in fixture.receipts.values() for log in receipt["logs"]
                    if log["topics"][0] == REGISTERED and log["topics"][1] == fixture.topic("uint256", 102))
                target["topics"][1] = fixture.topic("uint256", 101)
            else:
                receipt = fixture.declaration_receipt; block = fixture.blocks[7]
                old = receipt["transactionHash"]; block["transactions"] = [old]
                receipt.update(blockHash=block["hash"], blockNumber="0x7", transactionIndex="0x0")
                for index, log in enumerate(receipt["logs"]):
                    log.update(blockHash=block["hash"], blockNumber="0x7", transactionIndex="0x0", logIndex=hex(index))
                fixture.blocks[1]["transactions"].clear()
            with self.subTest(mode=mode), self.assertRaises(MuseumError): fixture.source().snapshot()

    def test_declaration_counterpart_state_and_original_host_are_exact(self):
        for mode in ("duplicate", "missing-facade", "facade-order", "state", "unknown"):
            fixture = PublicConservationTierFixture(mode="declared")
            if mode == "duplicate":
                log = fixture.declaration_receipt["logs"][0]
                fixture._transaction(2, "duplicate-tier", [(fixture.core, log["topics"], bytes.fromhex(log["data"][2:]))])
            elif mode == "missing-facade": fixture.declaration_receipt["logs"].pop()
            elif mode == "facade-order": fixture.declaration_receipt["logs"].reverse()
            elif mode == "state":
                fixture._call("declaredConservationTier(uint256)", ("bytes32",), (ZERO,), ("uint256",), (COLLECTION,))
            else:
                fixture._call("declaredConservationTier(uint256)", ("bytes32",), (H("unknown-tier"),), ("uint256",), (COLLECTION,))
            with self.subTest(mode=mode), self.assertRaises(MuseumError): fixture.source().snapshot()

    def test_identity_lifecycle_runtime_interface_and_collection_checks(self):
        for mode in ("identity", "lifecycle", "runtime", "interface", "collection", "bound"):
            fixture = PublicConservationTierFixture(mode="prepared_reverted")
            if mode == "identity":
                fixture._call("tokenCollectionIdentity(uint256)", ("bool", "uint256", "uint256", "bool"),
                    (True, COLLECTION, 1, False), ("uint256",), (101,))
            elif mode == "lifecycle": fixture._call("tokenLifecycle(uint256)", ("uint8",), (2,), ("uint256",), (102,))
            elif mode == "runtime": fixture.core_code = b"changed"
            elif mode == "interface": fixture._call("supportsInterface(bytes4)", ("bool",), (False,), ("bytes4",), ("0xc10ccea9",))
            elif mode == "collection": fixture._call("collectionExists(uint256)", ("bool",), (False,), ("uint256",), (COLLECTION,))
            else: fixture._call("collectionNextSerial(uint256)", ("uint256",), (258,), ("uint256",), (COLLECTION,))
            with self.subTest(mode=mode), self.assertRaises(MuseumError): fixture.source().snapshot()

    def test_exact_offline_replay_closed_anchor_and_provenance(self):
        fixture = PublicConservationTierFixture(); original = fixture.source(); raw = original.snapshot(); transcript = original.transcript()
        with patch("socket.socket", side_effect=AssertionError("offline replay only")):
            replay = source.PublicConservationTierSource(original.anchor_bytes,
                PublicReplayTransport(transcript, keccak256(transcript)))
            self.assertEqual(replay.snapshot(), raw)
        packet = loads(transcript, maximum=64 * 1024 * 1024); packet["calls"].append(deepcopy(packet["calls"][-1])); altered = dumps(packet)
        with self.assertRaisesRegex(MuseumError, "unconsumed"):
            source.PublicConservationTierSource(original.anchor_bytes,
                PublicReplayTransport(altered, keccak256(altered))).snapshot()
        fixture = PublicConservationTierFixture(); fixture.a["metadata"] = fixture.facade
        with self.assertRaisesRegex(MuseumError, "anchor shape"): fixture.source()
        fixture = PublicConservationTierFixture()
        with self.assertRaisesRegex(MuseumError, "provenance"): fixture.source(provenance="trusted_rpc")
        transport = PublicRpcTransport("https://example.invalid")
        with patch.object(PublicRpcTransport, "request", side_effect=fixture.request), \
                patch("socket.socket", side_effect=AssertionError("no network")):
            trusted = source.PublicConservationTierSource(dumps(fixture.a), transport, provenance="trusted_rpc")
            trusted_raw = trusted.snapshot()
        self.assertEqual(loads(trusted_raw, maximum=source.MAX_OUTPUT)["mode"], "caller_admitted_rpc_conservation_tier")
        self.assertEqual(source.PublicConservationTierSource(trusted.anchor_bytes,
            PublicReplayTransport(trusted.transcript(), keccak256(trusted.transcript())),
            provenance="trusted_rpc").snapshot(), trusted_raw)


if __name__ == "__main__": unittest.main()

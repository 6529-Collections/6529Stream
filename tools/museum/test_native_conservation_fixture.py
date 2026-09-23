"""One coherent synthetic chain for the three native conservation readers.

The fixture is not actual-chain evidence.  Every reader observes the same Core,
block header, receipt set, runtime bytes and response map; the three closed
anchors differ only where their frozen source profiles require different keys.
"""
from copy import deepcopy
import unittest
from unittest.mock import patch

from .canonical import MuseumError, dumps, keccak256, loads, schema_id
from .chain_abi import encode
from .independent_wire import ZERO, ZERO_ADDRESS
from .mint_entropy_source import REGISTERED, REVERTED, TRANSFER
from .public_history_rpc import PublicReplayTransport
from . import public_conservation_source as selection_source
from . import public_conservation_tier_source as tier_source
from . import public_conservation_floor_source as floor_source
from . import public_conservation_capture as selection_capture
from . import public_conservation_tier_capture as tier_capture
from . import public_conservation_floor_capture as floor_capture
from .test_public_conservation_source import PublicConservationFixture, A, H


CHAIN, COLLECTION, TOKEN = 31337, 1, 41
K = lambda label: keccak256(label.encode("utf-8"))


def _zero(kind):
    if isinstance(kind, tuple): return tuple(_zero(item) for item in kind)
    if kind == "address": return ZERO_ADDRESS
    if kind.startswith("bytes"): return ZERO if kind == "bytes32" else "0x" + "00" * int(kind[5:])
    if kind == "bool": return False
    return 0


class NativeConservationFixture(PublicConservationFixture):
    """Selected Artist intent, completed-mint default, and empty floor at one block."""

    def __init__(self, *, paid=False, late_declaration=False):
        if late_declaration and not paid:
            raise ValueError("late declaration requires the synthetic paid history")
        super().__init__()
        self.paid, self.late_declaration = paid, late_declaration
        self.core = A(2)
        self.floor, self.floor_executor = A(80), A(81)
        self.codes[self.floor] = b"\x60\x50\x00"
        self.codes[self.floor_executor] = b"\x60\x51\x00"
        self.pins[self.floor] = keccak256(self.codes[self.floor])
        self.pins[self.floor_executor] = keccak256(self.codes[self.floor_executor])
        self._tier_history(late_declaration)
        self._floor_history(paid)
        if late_declaration:
            self._late_declaration()

        common = {key: self.a[key] for key in ("chainId", "blockHash", "blockNumber", "timestamp",
            "stateRoot", "environment", "deploymentEvidenceHash", "core", "collectionId")}
        self.selection_anchor = deepcopy(self.a)
        self.tier_anchor = {"profile": tier_source.PROFILE, **common,
            "coreRuntimeHash": self.pins[self.core]}
        self.floor_anchor = {"profile": floor_source.PROFILE, **common,
            "conservationFloor": self.floor, "executor": self.floor_executor,
            "codePins": [{"address": address, "runtimeHash": self.pins[address]}
                for address in (self.core, self.floor, self.floor_executor) +
                ((self.floor_recorder,) if paid else ())]}

    @staticmethod
    def topic(kind, value):
        return "0x" + encode((kind,), (value,)).hex()

    def _tier_history(self, declared):
        for interface, value in (("0xc10ccea9", True), ("0x80ac58cd", True),
                ("0x01ffc9a7", True), ("0xffffffff", False)):
            self.add(self.core, "supportsInterface(bytes4)", ("bytes4",), (interface,), ("bool",), (value,))
        self.add(self.core, "collectionExists(uint256)", ("uint256",), (COLLECTION,), ("bool",), (True,))
        self.add(self.core, "declaredConservationTier(uint256)", ("uint256",), (COLLECTION,),
            ("bytes32",), (floor_source.FULL if declared else ZERO,))
        self.add(self.core, "collectionMintedEver(uint256)", ("uint256",), (COLLECTION,),
            ("uint256",), (1,))
        self.add(self.core, "collectionNextSerial(uint256)", ("uint256",), (COLLECTION,),
            ("uint256",), (4,))
        for token in (39, 40):
            self.add(self.core, "tokenCollectionIdentity(uint256)", ("uint256",), (token,),
                ("bool", "uint256", "uint256", "bool"), (False, 0, 0, False))
            self.add(self.core, "tokenLifecycle(uint256)", ("uint256",), (token,), ("uint8",), (0,))

        def registered(token, serial, block):
            self.event(block, self.core,
                [REGISTERED, self.topic("uint256", token), self.topic("uint256", COLLECTION)],
                ("uint16", "uint256"), (1, serial))

        def reverted(token, block):
            self.event(block, self.core,
                [REVERTED, self.topic("uint256", token), self.topic("uint256", COLLECTION)],
                ("uint16",), (1,))

        registered(39, 1, 0); reverted(39, 0)
        registered(40, 2, 1); reverted(40, 1)
        registered(TOKEN, 3, 2)
        self.event(4, self.core, [TRANSFER, ZERO, self.topic("address", A(90)),
            self.topic("uint256", TOKEN)], (), ())

    def _action(self, label, block, address, topics, kinds, values):
        stamp = int(self.blocks[H(200 + block)]["timestamp"], 16)
        action_id = K("native-conservation-" + label + "-action")
        stored = (3, 1, A(82), 0, "0x12345678", K(label + "-calldata"), K(label + "-scope"),
            K(label + "-old"), K(label + "-new"), stamp - 1, stamp + 1, A(83),
            self.floor_executor, A(84), A(85), K(label + "-policy"),
            "synthetic unified " + label, K(label + "-result"))
        self.add(self.floor_executor, "governanceAction(bytes32)", ("bytes32",), (action_id,),
            (floor_source.ACTION,), (stored,))
        self.event(block, address, topics(action_id), kinds, values(action_id))
        self.event(block, self.floor_executor,
            [floor_source.EXECUTED_EVENT, action_id, self.topic("uint8", 1),
                self.topic("address", stored[2])], floor_source.EXECUTED_DATA,
            (1, *stored[3:9], stored[12], stored[17]))
        return action_id

    def _floor_history(self, paid):
        for host, interface in ((self.core, floor_source.CORE_INTERFACE),
                (self.floor, floor_source.FLOOR_INTERFACE)):
            for expected, value in ((interface, True), ("0x01ffc9a7", True), ("0xffffffff", False)):
                self.add(host, "supportsInterface(bytes4)", ("bytes4",), (expected,), ("bool",), (value,))
        self.add(self.core, "conservationFloor()", (), (), ("address", "bytes32"),
            (self.floor, self.pins[self.floor]))
        for signature, kind, value in (("core()", "address", self.core),
                ("coreCodeHash()", "bytes32", self.pins[self.core]),
                ("governanceAuthority()", "address", self.floor_executor),
                ("executorCodeHash()", "bytes32", self.pins[self.floor_executor]),
                ("deploymentChainId()", "uint256", CHAIN)):
            self.add(self.floor, signature, (), (), (kind,), (value,))

        hash_anchor = {"chainId": str(CHAIN), "core": self.core, "conservationFloor": self.floor}
        empty = floor_source.empty_head(hash_anchor); head = empty; rows = []
        if paid:
            self.floor_provider = A(86); self.floor_recorder, self.floor_sale, self.floor_payment = A(87), A(88), A(89)
            self.floor_provider_qualification = "synthetic_generic_mock_not_native_provider"
            for address, code in ((self.floor_provider, b"synthetic generic floor provider"),
                    (self.floor_recorder, b"synthetic original settlement recorder"),
                    (self.floor_sale, b"synthetic sale adapter"),
                    (self.floor_payment, b"synthetic payment adapter")):
                self.codes[address] = code; self.pins[address] = keccak256(code)
            stamp = int(self.blocks[H(202)]["timestamp"], 16)
            row = (self.a["host"], self.pins[self.a["host"]], self.floor_provider,
                self.pins[self.floor_provider],
                K("synthetic floor source configuration"), 0, stamp,
                K("native-conservation-floor-source-action"))
            head = floor_source.next_head(empty, 1, row); rows.append(row)
        self.add(self.floor, "sourceSetHead()", (), (), ("uint64", "bytes32"), (len(rows), head))
        self.add(self.floor, "sourceCount()", (), (), ("uint64",), (len(rows),))
        self.add(self.floor, "sourceSetHashAt(uint64)", ("uint64",), (0,), ("bytes32",), (empty,))
        if rows:
            self.add(self.floor, "sourceAt(uint64)", ("uint64",), (1,), (floor_source.SOURCE,), (rows[0],))
            self.add(self.floor, "sourceSetHashAt(uint64)", ("uint64",), (1,), ("bytes32",), (head,))

        self._action("floor-binding", 0, self.core,
            lambda action: [floor_source.BOUND_EVENT, self.topic("address", self.floor), action],
            ("uint16", "bytes32"), lambda _action: (1, self.pins[self.floor]))
        if not rows:
            self.add(self.floor, "firstSale(uint256)", ("uint256",), (COLLECTION,),
                (floor_source.FIRST,), (_zero(floor_source.FIRST),))
            return
        row = rows[0]
        self._action("floor-source", 2, self.floor,
            lambda _action: [floor_source.ADDED_EVENT, self.topic("uint64", 1),
                self.topic("address", row[0]), self.topic("address", row[2])],
            ("bytes32", floor_source.SOURCE, "uint16"), lambda _action: (head, row, 1))
        self._paid_floor(head)

    def _paid_floor(self, source_head):
        block = 3; stamp = int(self.blocks[H(203)]["timestamp"], 16)
        recorder, sale_adapter, payment_adapter = self.floor_recorder, self.floor_sale, self.floor_payment
        execution_id = K("synthetic floor execution")
        key = keccak256(encode(("bytes32", "uint256", "address", "address", "bytes32"),
            (floor_source.KEY_DOMAIN, CHAIN, recorder, sale_adapter, execution_id)))
        profile, wallet, asset, payer = K("floor profile"), A(92), A(93), A(94)
        amount = 1003
        operation_root, operation_id = K("floor operation root"), K("floor operation id")
        expected_policy, current_policy, bound_policy = (K("floor expected policy"),
            K("floor current policy"), K("floor bound policy"))
        assignment, template, settlement_id = K("floor assignment"), K("floor template"), K("floor settlement id")
        sale = (settlement_id, floor_source.PRIMARY, 1, COLLECTION, 0, 1, payer, A(95), A(96),
            amount, expected_policy)
        result = (K("floor candidate commitment"), key, profile, wallet, asset, amount,
            self.floor_executor, execution_id, False, operation_root, current_policy, bound_policy)
        scope = (0, COLLECTION, 0, ZERO); subject = self.subject("collection")
        selection = self.selections[("collection", 0)][-1]
        interview = keccak256(encode(("bytes32", "uint256", ("address",) * 5,
            ("uint8", "uint256", "uint256", "bytes32"), "bytes32", selection_source.SELECTION,
            "bytes32", "bytes32"), (schema_id("6529STREAM_FINALITY_WAIVED_INTERVIEW_V1"), CHAIN,
            (self.core, self.a["host"], self.a["schemas"], self.a["store"], self.a["conservationSelector"]),
            scope, subject, selection, schema_id("STREAM_ARTIST_INTERVIEW_V1"),
            "0x1533a5140b53a7b0bc3f76524cb01d44c62391c8db570cbdff11fbc9dea6e9cf")))
        self.floor_interview_commitment = interview
        facts = (self.artist_id, self.identity_hash, self.originals[0]["recordHash"], ZERO,
            interview, K("synthetic rights commitment"),
            K("synthetic personhood commitment"), False)
        lite = next(value for value, label in tier_source.TIERS.items() if label == "MUSEUM_GRADE_LITE")
        first = (ZERO, COLLECTION, lite, recorder, key, stamp, 1, source_head, facts)
        hash_anchor = {"chainId": str(CHAIN), "core": self.core, "conservationFloor": self.floor}
        first = (floor_source.receipt_hash(hash_anchor, floor_source.FIRST_DOMAIN,
            floor_source.FIRST, first), *first[1:])
        context = (K("floor release scope"), K("floor release membership"), K("floor media inventory"),
            ZERO, K("floor source context"), False)
        release_key = floor_source.release_key(hash_anchor, COLLECTION, context)
        release = (ZERO, release_key, COLLECTION, lite, recorder, key, stamp, 1, source_head,
            context, (context[4], K("floor media evidence"), ZERO))
        release = (floor_source.receipt_hash(hash_anchor, floor_source.RELEASE_DOMAIN,
            floor_source.RELEASE, release), *release[1:])
        settlement = (ZERO, recorder, self.pins[recorder], key, K("floor candidate payload"),
            result[0], keccak256(encode(floor_source.RESULT, result)), COLLECTION, 0, lite,
            first[0], release[0], stamp)
        settlement = (floor_source.receipt_hash(hash_anchor, floor_source.SETTLEMENT_DOMAIN,
            floor_source.SETTLEMENT, settlement), *settlement[1:])
        self.add(self.floor, "firstSale(uint256)", ("uint256",), (COLLECTION,),
            (floor_source.FIRST,), (first,))
        self.add(self.floor, "releaseFloorReceipt(bytes32)", ("bytes32",), (release_key,),
            (floor_source.RELEASE,), (release,))
        self.add(self.floor, "settlementReceipt(bytes32)", ("bytes32",), (key,),
            (floor_source.SETTLEMENT,), (settlement,))
        self.add(recorder, "settlementConsumed(bytes32)", ("bytes32",), (key,), ("bool",), (True,))
        self.add(recorder, "settlementResult(bytes32)", ("bytes32",), (key,), floor_source.RESULT, result)
        self.event(block, self.floor, [floor_source.FIRST_EVENT, self.topic("uint256", COLLECTION), first[0]],
            (floor_source.FIRST, "uint16"), (first, 1))
        self.event(block, self.floor, [floor_source.RELEASE_EVENT, release_key, release[0]],
            (floor_source.RELEASE, "uint16"), (release, 1))
        self.event(block, self.floor, [floor_source.SETTLEMENT_EVENT, key, settlement[0]],
            (floor_source.SETTLEMENT, "uint16"), (settlement, 1))
        sale_hash = keccak256(encode(floor_source.SALE, sale))
        self.event(block, recorder, [floor_source.SETTLED_EVENT, key, floor_source.PRIMARY, profile],
            floor_source.SETTLED_DATA, (1, wallet, asset, payer, amount, sale_hash, False, 2))
        self.event(block, recorder, [floor_source.CONTEXT_EVENT, key, floor_source.PRIMARY, profile],
            floor_source.CONTEXT_DATA, (1, sale_adapter, settlement_id, 1, COLLECTION, 0,
                operation_root, operation_id, 1, sale[7], sale[8], template))
        self.event(block, recorder, [floor_source.POLICY_EVENT, key, floor_source.PRIMARY, profile],
            floor_source.POLICY_DATA, (1, expected_policy, sale[10], assignment, template))
        self.event(block, recorder, [floor_source.EXECUTION_EVENT, key,
                self.topic("address", sale_adapter), execution_id],
            floor_source.EXECUTION_DATA, (1, self.floor_executor, payment_adapter, result[0],
                current_policy, bound_policy))

    def _late_declaration(self):
        facade = A(91)
        self.event(3, self.core, [tier_source.CORE_TIER_EVENT, self.topic("uint256", COLLECTION),
            floor_source.FULL, self.topic("address", facade)], ("uint16",), (1,))
        self.event(3, facade, [tier_source.FACADE_TIER_EVENT,
            self.topic("uint256", COLLECTION), floor_source.FULL], ("uint16",), (1,))

    def selection_source(self):
        return selection_source.PublicConservationSource(dumps(self.selection_anchor), self)

    def tier_source(self):
        return tier_source.PublicConservationTierSource(dumps(self.tier_anchor), self)

    def floor_source(self):
        return floor_source.PublicConservationFloorSource(dumps(self.floor_anchor), self)

    def sources(self):
        return {"selection": self.selection_source(), "tier": self.tier_source(),
            "floor": self.floor_source()}

    def captures(self):
        modules = {"selection": (selection_capture, selection_source.PROFILE_HASH),
            "tier": (tier_capture, tier_source.PROFILE_HASH),
            "floor": (floor_capture, floor_source.PROFILE_HASH)}
        captured = {}
        for name, adapter in self.sources().items():
            adapter.snapshot(); transcript = adapter.transcript()
            module, profile_hash = modules[name]
            result = module.replay(adapter.anchor_bytes, keccak256(adapter.anchor_bytes), profile_hash,
                transcript, keccak256(transcript), provenance="synthetic_fixture", disclosure="public")
            verified = module.verify(dict(result.files), result.manifest_hash)
            captured[name] = {"files": dict(verified.files), "manifestHash": verified.manifest_hash,
                "report": verified.report}
        return captured


class NativeConservationFixtureTests(unittest.TestCase):
    def test_three_sources_share_one_exact_chain_core_and_anchor_header(self):
        fixture = NativeConservationFixture()
        anchors = (fixture.selection_anchor, fixture.tier_anchor, fixture.floor_anchor)
        for key in ("chainId", "core", "collectionId", "blockHash", "blockNumber", "timestamp",
                "stateRoot", "environment", "deploymentEvidenceHash"):
            self.assertEqual({anchor[key] for anchor in anchors}, {fixture.selection_anchor[key]})
        header = fixture.blocks[fixture.selection_anchor["blockHash"]]
        self.assertEqual((str(int(header["number"], 16)), str(int(header["timestamp"], 16)),
            header["stateRoot"]), (fixture.selection_anchor["blockNumber"],
            fixture.selection_anchor["timestamp"], fixture.selection_anchor["stateRoot"]))
        self.assertEqual(fixture.selection_anchor["tokenId"], str(TOKEN))

    def test_selected_artist_intent_completed_token_default_and_empty_floor_are_independent(self):
        fixture = NativeConservationFixture(); adapters = fixture.sources()
        selection = loads(adapters["selection"].snapshot(), maximum=selection_source.MAX_OUTPUT)
        tier = loads(adapters["tier"].snapshot(), maximum=tier_source.MAX_OUTPUT)
        floor = loads(adapters["floor"].snapshot(), maximum=floor_source.MAX_OUTPUT)
        lane = selection["scopes"]["collection"]["origins"]["artist"]
        self.assertEqual((lane["status"], len(lane["history"])), ("selected", 1))
        self.assertEqual([row["status"] for row in tier["allocations"]],
            ["aborted", "aborted", "minted"])
        self.assertEqual((tier["tier"]["tierBasis"], tier["tier"]["effectiveTier"]),
            ("default", "MUSEUM_GRADE_LITE"))
        self.assertEqual(tier["completedMints"][0]["tokenId"], str(TOKEN))
        self.assertEqual(floor["floor"], {"status": "none_recorded", "firstSale": None,
            "releases": [], "settlements": []})
        self.assertFalse(floor["claims"]["paymentExecutionReproved"])

    def test_each_source_replays_offline_from_its_own_transcript(self):
        fixture = NativeConservationFixture()
        constructors = {"selection": selection_source.PublicConservationSource,
            "tier": tier_source.PublicConservationTierSource,
            "floor": floor_source.PublicConservationFloorSource}
        for name, adapter in fixture.sources().items():
            raw = adapter.snapshot(); transcript = adapter.transcript()
            with self.subTest(name=name), patch("socket.socket", side_effect=AssertionError("offline only")):
                replay = constructors[name](adapter.anchor_bytes,
                    PublicReplayTransport(transcript, keccak256(transcript)))
                self.assertEqual(replay.snapshot(), raw)

    def test_all_three_capture_wrappers_verify_exact_manifests(self):
        captured = NativeConservationFixture().captures()
        self.assertEqual(set(captured), {"selection", "tier", "floor"})
        for name, value in captured.items():
            with self.subTest(name=name):
                self.assertEqual(keccak256(value["files"]["manifest.json"]), value["manifestHash"])
                self.assertEqual(value["report"]["provenance"], "synthetic_fixture")
                self.assertFalse(value["report"]["canonicalPacketCompatible"])

    def test_shared_receipts_have_one_global_position_and_common_calls_cannot_diverge(self):
        fixture = NativeConservationFixture()
        for receipt in fixture.receipts.values():
            self.assertEqual([int(log["logIndex"], 16) for log in receipt["logs"]],
                list(range(len(receipt["logs"]))))
            self.assertTrue(all(log["transactionHash"] == receipt["transactionHash"] and
                log["blockHash"] == receipt["blockHash"] for log in receipt["logs"]))
        fixture.add(fixture.core, "collectionExists(uint256)", ("uint256",), (COLLECTION,),
            ("bool",), (False,))
        for constructor, anchor in ((tier_source.PublicConservationTierSource, fixture.tier_anchor),
                (floor_source.PublicConservationFloorSource, fixture.floor_anchor)):
            with self.subTest(constructor=constructor.__name__), self.assertRaises(MuseumError):
                constructor(dumps(anchor), fixture).snapshot()

    def test_paid_lite_floor_joins_the_selected_artist_record_before_token_completion(self):
        fixture = NativeConservationFixture(paid=True); adapters = fixture.sources()
        selection = loads(adapters["selection"].snapshot(), maximum=selection_source.MAX_OUTPUT)
        tier = loads(adapters["tier"].snapshot(), maximum=tier_source.MAX_OUTPUT)
        floor = loads(adapters["floor"].snapshot(), maximum=floor_source.MAX_OUTPUT)
        first = floor["floor"]["firstSale"]; settlement = floor["floor"]["settlements"][0]
        facts = first["receipt"][8]
        self.assertEqual((facts[0], facts[1], facts[2], facts[4]),
            (fixture.artist_id, fixture.identity_hash, fixture.originals[0]["recordHash"],
                fixture.floor_interview_commitment))
        self.assertEqual(selection["records"][0]["recordHash"], facts[2])
        self.assertEqual((first["effectiveTier"], first["sourceId"], settlement["tokenId"]),
            ("MUSEUM_GRADE_LITE", "1", "0"))
        self.assertEqual((tier["tier"]["tierBasis"], tier["tier"]["effectiveTier"],
            tier["completedMints"][0]["tokenId"]), ("default", "MUSEUM_GRADE_LITE", str(TOKEN)))
        sale_position = tuple(int(first["publication"][key]) for key in
            ("blockNumber", "transactionIndex", "logIndex"))
        mint_position = tuple(int(tier["completedMints"][0]["publication"][key]) for key in
            ("blockNumber", "transactionIndex", "logIndex"))
        self.assertLess(sale_position, mint_position)
        self.assertEqual(floor["catalogue"]["sources"][0]["metadata"], fixture.a["host"])
        self.assertFalse(floor["claims"]["documentaryFactsIndependentlyVerified"])
        self.assertFalse(floor["claims"]["personhoodProven"])
        self.assertEqual(fixture.floor_provider_qualification,
            "synthetic_generic_mock_not_native_provider")
        self.assertFalse(any(method == "eth_call" and params[0]["to"] == fixture.floor_provider
            for method, params in fixture.requested))

    def test_late_full_declaration_does_not_rewrite_earlier_lite_floor(self):
        fixture = NativeConservationFixture(paid=True, late_declaration=True)
        tier = loads(fixture.tier_source().snapshot(), maximum=tier_source.MAX_OUTPUT)
        floor = loads(fixture.floor_source().snapshot(), maximum=floor_source.MAX_OUTPUT)
        self.assertEqual((tier["tier"]["declaredTier"], tier["tier"]["effectiveTier"]),
            ("MUSEUM_GRADE", "MUSEUM_GRADE"))
        self.assertEqual(floor["floor"]["firstSale"]["effectiveTier"], "MUSEUM_GRADE_LITE")
        sale = floor["floor"]["firstSale"]["publication"]
        declaration = tier["tier"]["declaration"]["publication"]
        self.assertEqual((sale["blockNumber"], sale["transactionIndex"]),
            (declaration["blockNumber"], declaration["transactionIndex"]))
        self.assertLess(int(sale["logIndex"]), int(declaration["logIndex"]))
        self.assertLess(int(declaration["blockNumber"]),
            int(tier["completedMints"][0]["publication"]["blockNumber"]))

    def test_paid_late_declaration_capture_manifests_all_reconstruct(self):
        captured = NativeConservationFixture(paid=True, late_declaration=True).captures()
        for name, value in captured.items():
            with self.subTest(name=name):
                self.assertEqual(keccak256(value["files"]["manifest.json"]), value["manifestHash"])
                self.assertFalse(value["report"]["completeCanonicalPacket"])


if __name__ == "__main__": unittest.main()

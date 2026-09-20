"""Immutable native conservation-floor receipts over bounded public RPC history.

Preparation is optional and is never payment evidence. Candidate preimages are
not exposed by this native interface; their commitments are retained as such.
"""
from .canonical import MuseumError, dumps, hex_bytes, keccak256, loads, schema_id, uint
from .chain_abi import calldata, decode, encode
from .independent_wire import ZERO, ZERO_ADDRESS, json_values, require
from .owner_catalog_source import _position, _location
from .public_chain_history import scan_public_history, PROFILE_HASH as HISTORY_PROFILE_HASH
from .public_condition_source import ACTION, EXECUTED_DATA, EXECUTED_EVENT
from .public_conservation_tier_source import TIERS
from .public_history_rpc import PublicRecordingReader, PublicReplayTransport, PublicRpcTransport, quantity

PROFILE = "STREAM_MUSEUM_PUBLIC_CONSERVATION_FLOOR_SOURCE_V1"
SOURCE_REVISION = "7d9040dc700575027067b0cc4d822d06b7dff5f2"
CORE_REVISION = "ff372f80b830b45a6afb30583780414f3abcc4cc"
MAX_ANCHOR, MAX_ABI, MAX_OUTPUT = 524288, 32768, 16777216
MAX_SOURCES, MAX_RECEIPTS, MAX_PINS = 64, 512, 256
CORE_INTERFACE, FLOOR_INTERFACE = "0x5243bb3a", "0xaf0adf33"
SOURCE = ("address", "bytes32", "address", "bytes32", "bytes32", "uint64", "uint64", "bytes32")
COLLECTION_FACTS = ("bytes32",) * 7 + ("bool",)
RELEASE_CONTEXT = ("bytes32",) * 5 + ("bool",)
RELEASE_FACTS = ("bytes32",) * 3
FIRST = ("bytes32", "uint256", "bytes32", "address", "bytes32", "uint64", "uint64", "bytes32", COLLECTION_FACTS)
RELEASE = ("bytes32", "bytes32", "uint256", "bytes32", "address", "bytes32", "uint64", "uint64", "bytes32", RELEASE_CONTEXT, RELEASE_FACTS)
SETTLEMENT = ("bytes32", "address", "bytes32", "bytes32", "bytes32", "bytes32", "bytes32", "uint256", "uint256", "bytes32", "bytes32", "bytes32", "uint64")
RESULT = ("bytes32", "bytes32", "bytes32", "address", "address", "uint256", "address", "bytes32", "bool", "bytes32", "bytes32", "bytes32")
SALE = ("bytes32", "bytes32", "uint8", "uint256", "uint256", "uint256", "address", "address", "address", "uint256", "bytes32")
SETTLED_DATA = ("uint16", "address", "address", "address", "uint256", "bytes32", "bool", "uint8")
CONTEXT_DATA = ("uint16", "address", "bytes32", "uint8", "uint256", "uint256", "bytes32", "bytes32", "uint256", "address", "address", "bytes32")
POLICY_DATA = ("uint16", "bytes32", "bytes32", "bytes32", "bytes32")
EXECUTION_DATA = ("uint16", "address", "address", "bytes32", "bytes32", "bytes32")


def _signature(kind):
    return kind if isinstance(kind, str) else "(" + ",".join(_signature(k) for k in kind) + ")"


DOMAIN = schema_id("6529STREAM_CONSERVATION_FLOOR_SOURCES_V1")
FIRST_DOMAIN = schema_id("6529STREAM_CONSERVATION_FIRST_SALE_V1")
RELEASE_DOMAIN = schema_id("6529STREAM_CONSERVATION_RELEASE_RECEIPT_V1")
SETTLEMENT_DOMAIN = schema_id("6529STREAM_CONSERVATION_SETTLEMENT_RECEIPT_V1")
RELEASE_KEY_DOMAIN = schema_id("6529STREAM_CONSERVATION_RELEASE_V1")
KEY_DOMAIN = schema_id("6529STREAM_PRIMARY_SETTLEMENT_KEY_V2")
PRIMARY = schema_id("PRIMARY_SALE")
WAIVED, FULL = schema_id("CONSERVATION_WAIVED"), schema_id("MUSEUM_GRADE")
BOUND_EVENT = schema_id("ConservationFloorBound(uint16,address,bytes32,bytes32)")
ADDED_EVENT = schema_id("ConservationFloorSourceAdded(uint64,address,address,bytes32," + _signature(SOURCE) + ",uint16)")
FIRST_EVENT = schema_id("ConservationFirstSaleRecorded(uint256,bytes32," + _signature(FIRST) + ",uint16)")
RELEASE_EVENT = schema_id("ConservationReleaseFloorRecorded(bytes32,bytes32," + _signature(RELEASE) + ",uint16)")
SETTLEMENT_EVENT = schema_id("ConservationSettlementRecorded(bytes32,bytes32," + _signature(SETTLEMENT) + ",uint16)")
SETTLED_EVENT = schema_id("PrimaryRevenueSettled(bytes32,bytes32,bytes32,uint16,address,address,address,uint256,bytes32,bool,uint8)")
CONTEXT_EVENT = schema_id("PrimaryRevenueSettlementContext(bytes32,bytes32,bytes32,uint16,address,bytes32,uint8,uint256,uint256,bytes32,bytes32,uint256,address,address,bytes32)")
POLICY_EVENT = schema_id("PrimaryRevenueSettlementPolicy(bytes32,bytes32,bytes32,uint16,bytes32,bytes32,bytes32,bytes32)")
EXECUTION_EVENT = schema_id("PrimaryRevenueExecutionBound(bytes32,address,bytes32,uint16,address,address,bytes32,bytes32,bytes32)")
QUALIFICATION = ("Complete bounded ledger event discovery and source admission history at one pinned block. "
    "Immutable first-sale, release and settlement getters agree with original successful receipts, exact hash recipes "
    "and the original recorder's consumed result and settlement events. Earlier preparation is optional and never "
    "payment evidence. Historical facts are not replaced with today's Metadata, provider or registry eligibility. "
    "Full candidate bytes are not exposed; candidate payload and native candidate commitments remain commitments. "
    "Provider log completeness and canonical mappings remain trusted. Native acceptance does not independently "
    "prove underlying documentary facts, personhood, all paid route coverage, payment execution or protocol runtime "
    "acceptance. No consensus proof, actual-chain acceptance or complete acquisition packet is established.")
CLAIMS = {"completeLedgerEventDiscovery": True, "completeSourceAdmissionHistory": True,
    "immutableReceiptHashesChecked": True, "originalConsumedResultJoined": True,
    "originalSettlementEventsJoined": True, "optionalPreparationSupported": True,
    "historicalReplacementPreserved": True, "providerLogCompletenessTrusted": True,
    "canonicalMappingTrusted": True, "candidatePreimageRecovered": False,
    "historicalProviderEligibilityReexecuted": False, "documentaryFactsIndependentlyVerified": False,
    "personhoodProven": False, "allPaidRoutesCovered": False, "paymentExecutionReproved": False,
    "nativeRuntimeAcceptance": False, "actualChainAcceptance": False, "consensusProof": False,
    "completeAcquisitionPacket": False}
PROFILE_BYTES = dumps({"name": PROFILE, "version": "1", "sourceReviewCommit": SOURCE_REVISION,
    "coreSourceReviewCommit": CORE_REVISION, "historyProfileHash": HISTORY_PROFILE_HASH,
    "bounds": {"sources": str(MAX_SOURCES), "ledgerReceiptEvents": str(MAX_RECEIPTS), "codePins": str(MAX_PINS)},
    "denominator": "Permanent Core binding and complete source IDs/heads/admissions; ledger-wide first/release/settlement event discovery before collection filtering. No caller-selected receipt list.",
    "hashing": "Exact frozen static structs with receiptHash zero in each domain-separated preimage; full saved facts retained.",
    "originalSale": "Pinned original recorder, consumed key, exact 384-byte result hash, four original same-transaction events; no candidate preimage recovery or current-registry reauthorization.",
    "preparation": "No preparation event/getter is required; the original paid receipt is identical across earlier optional preparation and inline persistence.",
    "governance": "Original native acceptance plus stored executed class1 action and successful receipt; no full per-call batch witness or historical root-scope rederivation.",
    "claims": CLAIMS, "qualification": QUALIFICATION})
PROFILE_HASH = keccak256(PROFILE_BYTES)


def _topic(kind, value): return "0x" + encode((kind,), (value,)).hex()


def empty_head(a):
    return keccak256(encode(("bytes32", "uint256", "address", "address"),
        (DOMAIN, uint(a["chainId"]), a["core"], a["conservationFloor"])))


def next_head(previous, source_id, row):
    return keccak256(encode(("bytes32", "bytes32", "uint64", *SOURCE[:6]),
        (DOMAIN, previous, source_id, *row[:6])))


def receipt_hash(a, domain, kind, row):
    return keccak256(encode(("bytes32", "uint256", "address", "address", kind),
        (domain, uint(a["chainId"]), a["core"], a["conservationFloor"], (ZERO, *row[1:]))))


def release_key(a, collection_id, context):
    return keccak256(encode(("bytes32", "uint256", "address", "uint256", "bytes32", "bytes32", "bytes32", "bytes32", "bool"),
        (RELEASE_KEY_DOMAIN, uint(a["chainId"]), a["core"], collection_id, *context[:4], context[5])))


class PublicConservationFloorSource:
    def __init__(self, anchor_bytes, transport, *, provenance="synthetic_fixture"):
        require(provenance in ("synthetic_fixture", "trusted_rpc") and
            (provenance != "trusted_rpc" or type(transport) in (PublicRpcTransport, PublicReplayTransport)), "conservation floor provenance")
        a = loads(anchor_bytes, maximum=MAX_ANCHOR, canonical=True)
        require(type(a) is dict and set(a) == {"profile", "chainId", "blockHash", "blockNumber", "timestamp",
            "stateRoot", "environment", "deploymentEvidenceHash", "core", "conservationFloor", "executor", "collectionId", "codePins"}
            and a["profile"] == PROFILE and a["environment"] in ("local_evm_fixture", "public_chain"), "conservation floor anchor shape/profile")
        require(uint(a["chainId"]) > 0 and uint(a["collectionId"]) > 0, "conservation floor nonzero identity")
        uint(a["blockNumber"]); uint(a["timestamp"], 64)
        for key in ("blockHash", "stateRoot", "deploymentEvidenceHash"):
            require(any(hex_bytes(a[key], 32)), "conservation floor empty commitment")
        for key in ("core", "conservationFloor", "executor"):
            require(any(hex_bytes(a[key], 20)), "conservation floor empty address")
        require(len({a[k] for k in ("core", "conservationFloor", "executor")}) == 3, "conservation floor distinct hosts")
        require(type(a["codePins"]) is list and 3 <= len(a["codePins"]) <= MAX_PINS, "conservation floor pin bound")
        pins = {}
        for p in a["codePins"]:
            require(type(p) is dict and set(p) == {"address", "runtimeHash"}, "conservation floor pin shape")
            require(any(hex_bytes(p["address"], 20)) and any(hex_bytes(p["runtimeHash"], 32))
                and p["address"] not in pins, "conservation floor duplicate/empty pin")
            pins[p["address"]] = p["runtimeHash"]
        require(all(a[k] in pins for k in ("core", "conservationFloor", "executor")), "conservation floor missing dependency pin")
        self.a, self.pins, self.anchor_bytes, self.provenance = a, pins, anchor_bytes, provenance
        self.reader = PublicRecordingReader(transport, a["blockHash"])
        self._started, self._snapshot = False, None

    def transcript(self): return self.reader.transcript()

    def _read(self, target, signature, outputs=(), kinds=(), values=()):
        return decode(outputs, hex_bytes(self.reader.call(target, calldata(signature, kinds, values))), maximum=MAX_ABI)

    def _interface(self, host, interface):
        for expected, value in ((interface, True), ("0x01ffc9a7", True), ("0xffffffff", False)):
            require(self._read(host, "supportsInterface(bytes4)", ("bool",), ("bytes4",), (expected,)) == (value,), "conservation floor interface differs")

    def snapshot(self):
        if self._snapshot is not None: return self._snapshot
        require(not self._started, "failed conservation floor capture cannot resume")
        self._started = True
        try: self._snapshot = self._capture()
        except MuseumError: raise
        except (KeyError, TypeError, IndexError, ValueError, OverflowError) as exc:
            raise MuseumError("malformed conservation floor evidence") from exc
        return self._snapshot

    def _bindings(self):
        a = self.a; host = a["conservationFloor"]
        require(quantity(self.reader.request("eth_chainId", [])) == uint(a["chainId"]), "conservation floor chain differs")
        for address, digest in sorted(self.pins.items()):
            code = hex_bytes(self.reader.code(address))
            require(0 < len(code) <= 24576 and keccak256(code) == digest, "conservation floor runtime pin differs")
        self._interface(a["core"], CORE_INTERFACE); self._interface(host, FLOOR_INTERFACE)
        require(self._read(a["core"], "conservationFloor()", ("address", "bytes32")) == (host, self.pins[host]),
            "conservation floor permanent Core binding unavailable/differs")
        for getter, kind, expected in (("core", "address", a["core"]), ("coreCodeHash", "bytes32", self.pins[a["core"]]),
                ("governanceAuthority", "address", a["executor"]), ("executorCodeHash", "bytes32", self.pins[a["executor"]]),
                ("deploymentChainId", "uint256", uint(a["chainId"]))):
            require(self._read(host, getter + "()", (kind,)) == (expected,), "conservation floor dependency differs")
        require(self._read(a["core"], "collectionExists(uint256)", ("bool",), ("uint256",), (uint(a["collectionId"]),)) == (True,),
            "conservation floor collection unavailable")

    def _catalogue(self):
        host = self.a["conservationFloor"]
        count, head = self._read(host, "sourceSetHead()", ("uint64", "bytes32"))
        require(count <= MAX_SOURCES and self._read(host, "sourceCount()", ("uint64",)) == (count,), "conservation floor source bound/count")
        previous, sources = empty_head(self.a), []
        require(self._read(host, "sourceSetHashAt(uint64)", ("bytes32",), ("uint64",), (0,)) == (previous,), "conservation floor empty head differs")
        for source_id in range(1, count + 1):
            row, = self._read(host, "sourceAt(uint64)", (SOURCE,), ("uint64",), (source_id,))
            require(row[0] != ZERO_ADDRESS and row[2] != ZERO_ADDRESS and all(row[k] != ZERO for k in (1, 3, 4, 7))
                and row[5] == source_id - 1 and 0 < row[6] <= uint(self.a["timestamp"]), "conservation floor source member differs")
            require(not sources or (row[0], row[2]) != (sources[-1]["metadata"], sources[-1]["provider"]), "conservation floor duplicate adjacent source")
            digest = next_head(previous, source_id, row)
            require(self._read(host, "sourceSetHashAt(uint64)", ("bytes32",), ("uint64",), (source_id,)) == (digest,), "conservation floor source head differs")
            sources.append({"sourceId": str(source_id), "metadata": row[0], "metadataCodeHash": row[1],
                "provider": row[2], "providerCodeHash": row[3], "configurationHash": row[4],
                "predecessor": str(row[5]), "admittedAt": str(row[6]), "actionId": row[7],
                "previousHead": previous, "head": digest, "source": json_values(row)})
            previous = digest
        require(previous == head, "conservation floor final source head differs")
        return {"count": str(count), "head": head, "emptyHead": empty_head(self.a), "sources": sources}

    def _admissions(self, catalogue, history):
        a = self.a
        bindings = [log for log in history["logs"] if log["address"] == a["core"] and log["topics"][0] == BOUND_EVENT]
        require(len(bindings) == 1, "conservation floor exact permanent binding event required")
        bound = bindings[0]
        require(len(bound["topics"]) == 3 and bound["topics"][1] == _topic("address", a["conservationFloor"])
            and bound["topics"][2] != ZERO and decode(("uint16", "bytes32"), hex_bytes(bound["data"])) == (1, self.pins[a["conservationFloor"]]),
            "conservation floor original binding differs")
        additions = [log for log in history["logs"] if log["address"] == a["conservationFloor"] and log["topics"][0] == ADDED_EVENT]
        require(len(additions) == len(catalogue["sources"]), "conservation floor admission count differs")
        actions, action_transactions = {}, {}
        def action(log, action_id):
            require(action_id not in action_transactions or action_transactions[action_id] == log["transactionHash"],
                "conservation floor governance action reused across transactions")
            action_transactions[action_id] = log["transactionHash"]
            if action_id in actions:
                require(tuple(uint(actions[action_id]["execution"][k]) for k in ("blockNumber", "transactionIndex", "logIndex")) > _position(log),
                    "conservation floor shared governance order differs")
                return actions[action_id]
            receipt = self.reader.request("eth_getTransactionReceipt", [log["transactionHash"]])
            events = [r for r in receipt["logs"] if r["address"] == a["executor"] and r["topics"] and
                r["topics"][0] == EXECUTED_EVENT and len(r["topics"]) > 1 and r["topics"][1] == action_id]
            require(len(events) == 1, "conservation floor governance execution receipt required")
            event = events[0]
            require(len(event["topics"]) == 4 and event["topics"][2] == _topic("uint8", 1) and _position(event) > _position(log),
                "conservation floor governance class/order differs")
            stored, = self._read(a["executor"], "governanceAction(bytes32)", (ACTION,), ("bytes32",), (action_id,))
            require(stored[:2] == (3, 1) and stored[11] != ZERO_ADDRESS and stored[12] != ZERO_ADDRESS
                and stored[9] <= uint(history["blockTimestamps"][str(quantity(log["blockNumber"]))]) <= stored[10], "conservation floor original governance action differs")
            require(event["topics"][3] == _topic("address", stored[2]) and decode(EXECUTED_DATA, hex_bytes(event["data"])) ==
                (1, *stored[3:9], stored[12], stored[17]), "conservation floor governance event/state differs")
            actions[action_id] = {"actionId": action_id, "action": json_values(stored), "execution": _location(event)}
            return actions[action_id]
        binding = {"ledger": a["conservationFloor"], "runtimeHash": self.pins[a["conservationFloor"]],
            "publication": _location(bound), "governance": action(bound, bound["topics"][2])}
        previous = _position(bound)
        for source, log in zip(catalogue["sources"], additions):
            row = tuple(source["source"])
            row = (*row[:5], uint(row[5]), uint(row[6]), row[7])
            require(len(log["topics"]) == 4 and log["topics"][1:] == [_topic("uint64", uint(source["sourceId"])),
                _topic("address", source["metadata"]), _topic("address", source["provider"])] and
                decode(("bytes32", SOURCE, "uint16"), hex_bytes(log["data"])) == (source["head"], row, 1)
                and source["admittedAt"] == history["blockTimestamps"][str(quantity(log["blockNumber"]))]
                and _position(log) > previous, "conservation floor retained admission differs")
            previous = _position(log)
            source["admission"] = {"publication": _location(log), "governance": action(log, source["actionId"])}
        return binding

    def _discovery(self, history, binding):
        """Keep the ledger-wide denominator, including other collections, before selection."""
        specs = {FIRST_EVENT: ("first_sale", FIRST, FIRST_DOMAIN, 1, 1),
            RELEASE_EVENT: ("release", RELEASE, RELEASE_DOMAIN, 2, 1),
            SETTLEMENT_EVENT: ("settlement", SETTLEMENT, SETTLEMENT_DOMAIN, 7, 3)}
        found, seen = [], set()
        bound_position = tuple(uint(binding["publication"][k]) for k in ("blockNumber", "transactionIndex", "logIndex"))
        for log in history["logs"]:
            if log["address"] != self.a["conservationFloor"] or log["topics"][0] not in specs: continue
            require(len(found) < MAX_RECEIPTS, "conservation floor ledger event bound")
            name, kind, domain, cid_index, key_index = specs[log["topics"][0]]
            row, version = decode((kind, "uint16"), hex_bytes(log["data"]))
            key = row[key_index]
            topic_key = _topic("uint256", key) if name == "first_sale" else key
            require(version == 1 and len(log["topics"]) == 3 and log["topics"][1:] == [topic_key, row[0]]
                and row[0] != ZERO and row[cid_index] > 0 and receipt_hash(self.a, domain, kind, row) == row[0]
                and (name, key) not in seen and _position(log) > bound_position, "conservation floor receipt event/hash/duplicate differs")
            seen.add((name, key)); found.append((name, row, log))
        return found

    def _evidence_source(self, source_id, head, log, catalogue, *, waived=False):
        prior = [s for s in catalogue["sources"] if tuple(uint(s["admission"]["publication"][k]) for k in
            ("blockNumber", "transactionIndex", "logIndex")) < _position(log)]
        latest_id = len(prior); latest_head = prior[-1]["head"] if prior else catalogue["emptyHead"]
        require(source_id == (0 if waived else latest_id) and (waived or latest_id > 0) and head == latest_head,
            "conservation floor historical source admission differs")

    def _first(self, row, log, catalogue):
        require(row[2] in TIERS and row[3] != ZERO_ADDRESS and row[4] != ZERO and row[5] > 0
            and row[5] == uint(self._history["blockTimestamps"][str(quantity(log["blockNumber"]))]), "conservation floor first sale identity/time differs")
        waived = row[2] == WAIVED; facts = row[8]
        self._evidence_source(row[6], row[7], log, catalogue, waived=waived)
        if waived:
            require(facts == (ZERO,) * 7 + (False,), "conservation floor waived facts differ")
        elif facts[7]:
            require(facts[:5] == (ZERO,) * 5 and facts[5] != ZERO and facts[6] == ZERO, "conservation floor platform facts differ")
        else:
            require(all(facts[k] != ZERO for k in (0, 1, 4, 5, 6)) and (facts[2] == ZERO) != (facts[3] == ZERO),
                "conservation floor collection facts differ")
        return {"receiptHash": row[0], "collectionId": str(row[1]), "effectiveTier": TIERS[row[2]],
            "recorder": row[3], "settlementKey": row[4], "recordedAt": str(row[5]), "sourceId": str(row[6]),
            "sourceSetHash": row[7], "receipt": json_values(row), "publication": _location(log)}

    def _release(self, row, log, catalogue):
        context, facts = row[9:11]
        require(row[3] in TIERS and row[3] != WAIVED and row[4] != ZERO_ADDRESS and row[5] != ZERO and row[6] > 0
            and row[6] == uint(self._history["blockTimestamps"][str(quantity(log["blockNumber"]))]), "conservation floor release identity/time differs")
        require(all(context[k] != ZERO for k in (0, 1, 2, 4)) and context[5] == (context[3] != ZERO)
            and release_key(self.a, row[2], context) == row[1] and facts[0] == context[4] and facts[1] != ZERO
            and (row[3] != FULL or not context[5] or facts[2] != ZERO) and (context[5] or facts[2] == ZERO),
            "conservation floor release facts/key differ")
        self._evidence_source(row[7], row[8], log, catalogue)
        return {"receiptHash": row[0], "releaseKey": row[1], "collectionId": str(row[2]), "effectiveTier": TIERS[row[3]],
            "recorder": row[4], "settlementKey": row[5], "recordedAt": str(row[6]), "sourceId": str(row[7]),
            "sourceSetHash": row[8], "receipt": json_values(row), "publication": _location(log)}

    def _settlement(self, row, log):
        recorder, key = row[1], row[3]
        require(recorder in self.pins and row[2] == self.pins[recorder] and all(row[k] != ZERO for k in (3, 4, 5, 6, 10))
            and row[9] in TIERS and row[12] > 0 and row[12] == uint(self._history["blockTimestamps"][str(quantity(log["blockNumber"]))]),
            "conservation floor settlement identity/time differs")
        require(self._read(recorder, "settlementConsumed(bytes32)", ("bool",), ("bytes32",), (key,)) == (True,),
            "conservation floor original settlement not consumed")
        result, = self._read(recorder, "settlementResult(bytes32)", (RESULT,), ("bytes32",), (key,))
        require(keccak256(encode((RESULT,), (result,))) == row[6] and result[:2] == (row[5], key)
            and result[2] != ZERO and result[3] != ZERO_ADDRESS and result[5] > 0 and result[6] != ZERO_ADDRESS
            and result[7] != ZERO, "conservation floor original stored result differs")
        receipt = self.reader.request("eth_getTransactionReceipt", [log["transactionHash"]])
        events, publications, previous = [], [], _position(log)
        for topic, kind in ((SETTLED_EVENT, SETTLED_DATA), (CONTEXT_EVENT, CONTEXT_DATA),
                (POLICY_EVENT, POLICY_DATA), (EXECUTION_EVENT, EXECUTION_DATA)):
            matches = [r for r in receipt["logs"] if r["address"] == recorder and len(r["topics"]) > 1
                and r["topics"][0] == topic and r["topics"][1] == key]
            require(len(matches) == 1, "conservation floor original settlement event missing/duplicate")
            event = matches[0]; data = decode(kind, hex_bytes(event["data"]))
            require(len(event["topics"]) == 4 and data[0] == 1 and _position(event) == (*previous[:2], previous[2] + 1),
                "conservation floor original settlement event version/order")
            if topic != EXECUTION_EVENT:
                require(event["topics"][2:] == [PRIMARY, result[2]], "conservation floor original settlement event class/profile differs")
            events.append((event, data)); previous = _position(event)
            publications.append({"topics": event["topics"], "data": json_values(data), "publication": _location(event)})
        (_, settled), (_, context), (_, policy), (execution_event, execution) = events
        sale_adapter, = decode(("address",), hex_bytes(execution_event["topics"][2]))
        expected_key = keccak256(encode(("bytes32", "uint256", "address", "address", "bytes32"),
            (KEY_DOMAIN, uint(self.a["chainId"]), recorder, sale_adapter, result[7])))
        require(key == expected_key and execution_event["topics"][3] == result[7]
            and sale_adapter == context[1] and sale_adapter != ZERO_ADDRESS and context[2] != ZERO
            and context[4:6] == row[7:9] and context[6] == result[9] and context[8] > 0
            and context[10] != ZERO_ADDRESS and context[11] == policy[4]
            and settled[1:3] == result[3:5] and settled[3] != ZERO_ADDRESS and settled[4] == result[5]
            and settled[6] == (policy[1] != policy[2]) and settled[7] == (1 if policy[4] == ZERO else 2)
            and policy[1] != ZERO and policy[2] != ZERO
            and execution[1] == result[6] and execution[3:] == (result[0], result[10], result[11]),
            "conservation floor original settlement event/result join differs")
        sale = (context[2], PRIMARY, context[3], context[4], context[5], context[8], settled[3],
            context[9], context[10], settled[4], policy[2])
        require(keccak256(encode((SALE,), (sale,))) == settled[5], "conservation floor original sale context hash differs")
        operation_fields = (context[7], result[10], result[11])
        require((result[9] == ZERO and row[8] > 0 and operation_fields == (ZERO, ZERO, ZERO)) or
            (result[9] != ZERO and all(value != ZERO for value in operation_fields)),
            "conservation floor original sale operation projection differs")
        return {"receiptHash": row[0], "recorder": recorder, "recorderCodeHash": row[2], "settlementKey": key,
            "candidatePayloadHash": row[4], "candidateCommitment": row[5], "resultHash": row[6],
            "collectionId": str(row[7]), "tokenId": str(row[8]), "effectiveTier": TIERS[row[9]],
            "firstSaleReceiptHash": row[10], "releaseReceiptHash": row[11], "recordedAt": str(row[12]),
            "receipt": json_values(row), "publication": _location(log),
            "originalSettlement": {"consumed": True, "result": json_values(result), "sale": json_values(sale),
                "events": publications, "candidatePreimageAvailable": False}}

    @staticmethod
    def _created_by(evidence, settlement):
        ep, sp = evidence["publication"], settlement["publication"]
        require(evidence["settlementKey"] == settlement["settlementKey"] and evidence["recorder"] == settlement["recorder"]
            and ep["transactionHash"] == sp["transactionHash"] and uint(ep["logIndex"]) < uint(sp["logIndex"])
            and evidence["recordedAt"] == settlement["recordedAt"] and evidence["effectiveTier"] == settlement["effectiveTier"],
            "conservation floor receipt creating settlement differs")

    def _floor(self, discovered, catalogue):
        a = self.a; cid = uint(a["collectionId"]); host = a["conservationFloor"]
        target = [(name, row, log) for name, row, log in discovered if row[{"first_sale": 1, "release": 2, "settlement": 7}[name]] == cid]
        stored_first, = self._read(host, "firstSale(uint256)", (FIRST,), ("uint256",), (cid,))
        first_rows = [(row, log) for name, row, log in target if name == "first_sale"]
        if not first_rows:
            require(not target and encode((FIRST,), (stored_first,)) == bytes(512), "conservation floor absent first sale differs")
            return {"status": "none_recorded", "firstSale": None, "releases": [], "settlements": []}
        require(len(first_rows) == 1 and stored_first == first_rows[0][0], "conservation floor first sale event/getter differs")
        first = self._first(*first_rows[0], catalogue)
        releases, settlements = [], []
        for name, row, log in target:
            if name == "release":
                require(self._read(host, "releaseFloorReceipt(bytes32)", (RELEASE,), ("bytes32",), (row[1],)) == (row,),
                    "conservation floor release event/getter differs")
                releases.append(self._release(row, log, catalogue))
            elif name == "settlement":
                require(self._read(host, "settlementReceipt(bytes32)", (SETTLEMENT,), ("bytes32",), (row[3],)) == (row,),
                    "conservation floor settlement event/getter differs")
                settlements.append(self._settlement(row, log))
        require(settlements, "conservation floor first sale has no paid settlement")
        self._created_by(first, settlements[0])
        by_key = {s["settlementKey"]: s for s in settlements}
        by_hash = {r["receiptHash"]: r for r in releases}
        for release in releases:
            require(release["settlementKey"] in by_key, "conservation floor release creating settlement absent")
            creator = by_key[release["settlementKey"]]
            self._created_by(release, creator)
            require(creator["releaseReceiptHash"] == release["receiptHash"] and
                uint(release["publication"]["logIndex"]) + 1 == uint(creator["publication"]["logIndex"]),
                "conservation floor release creating hash/order differs")
        first_release = next((r for r in releases if r["settlementKey"] == first["settlementKey"]), None)
        first_next = first_release if first_release is not None else settlements[0]
        require(uint(first["publication"]["logIndex"]) + 1 == uint(first_next["publication"]["logIndex"]),
            "conservation floor first sale release/settlement order differs")
        for settlement in settlements:
            require(settlement["firstSaleReceiptHash"] == first["receiptHash"] and settlement["effectiveTier"] == first["effectiveTier"],
                "conservation floor settlement first sale/tier differs")
            release_hash = settlement["releaseReceiptHash"]
            if settlement["effectiveTier"] == TIERS[WAIVED]:
                require(release_hash == ZERO and not releases, "conservation floor waived release differs")
            else:
                require(release_hash in by_hash, "conservation floor settlement release missing")
                release = by_hash[release_hash]
                require(release["effectiveTier"] == settlement["effectiveTier"] and
                    tuple(uint(release["publication"][k]) for k in ("blockNumber", "transactionIndex", "logIndex")) <
                    tuple(uint(settlement["publication"][k]) for k in ("blockNumber", "transactionIndex", "logIndex")),
                    "conservation floor settlement release order/tier differs")
        return {"status": "present", "firstSale": first, "releases": releases, "settlements": settlements}

    def _capture(self):
        a = self.a; host = a["conservationFloor"]
        self._bindings(); catalogue = self._catalogue()
        filters = [{"address": a["core"], "topics": [BOUND_EVENT]},
            {"address": host, "topics": [[ADDED_EVENT, FIRST_EVENT, RELEASE_EVENT, SETTLEMENT_EVENT]]}]
        history = scan_public_history(self.reader, a, filters=filters); self._history = history
        binding = self._admissions(catalogue, history)
        discovered = self._discovery(history, binding)
        floor = self._floor(discovered, catalogue)
        require(self._read(host, "sourceSetHead()", ("uint64", "bytes32")) == (uint(catalogue["count"]), catalogue["head"])
            and self._read(host, "sourceCount()", ("uint64",)) == (uint(catalogue["count"]),)
            and self._read(a["core"], "conservationFloor()", ("address", "bytes32")) == (host, self.pins[host]),
            "conservation floor final binding/catalog changed")
        source_header = next(row["result"] for row in self.reader.rows if row["method"] == "eth_getBlockByHash" and row["params"] == [a["blockHash"], False])
        require(self.reader.request("eth_getBlockByHash", [a["blockHash"], False]) == source_header and
            self.reader.request("eth_getBlockByNumber", [hex(uint(a["blockNumber"])), False]) == source_header, "conservation floor final anchor changed")
        if type(self.reader.transport) is PublicReplayTransport: self.reader.transport.finish()
        coverage = {"scan": history["coverage"], "ledgerReceiptEventCount": str(len(discovered)),
            "targetReceiptEventCount": str((1 if floor["firstSale"] else 0) + len(floor["releases"]) + len(floor["settlements"])),
            "ledgerReceiptEvents": [{"kind": name, "receipt": json_values(row), "publication": _location(log)} for name, row, log in discovered],
            "providerLogCompletenessTrusted": True, "canonicalMappingTrusted": True,
            "independentSettlementCountAvailable": False, "supplementalCoverage": False}
        result = dumps({"profile": PROFILE, "profileHash": PROFILE_HASH, "version": "1", "sourceReviewCommit": SOURCE_REVISION,
            "coreSourceReviewCommit": CORE_REVISION, "mode": "caller_admitted_rpc_conservation_floor" if self.provenance == "trusted_rpc" else "synthetic_fixture",
            "anchorHash": keccak256(self.anchor_bytes), "transcriptHash": keccak256(self.transcript()),
            "sourceState": {k: a[k] for k in ("chainId", "core", "conservationFloor", "collectionId", "blockHash", "blockNumber", "timestamp", "environment")},
            "binding": binding, "catalogue": catalogue, "floor": floor, "historyCoverage": coverage, "claims": CLAIMS, "qualification": QUALIFICATION})
        require(len(result) <= MAX_OUTPUT, "conservation floor snapshot bound")
        return result

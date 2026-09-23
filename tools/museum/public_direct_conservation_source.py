"""Typed original DIRECT sale-floor evidence; universal captures remain frozen."""
from . import public_conservation_floor_source as f
from .canonical import MuseumError, dumps, hex_bytes, keccak256, loads, schema_id, uint
from .chain_abi import decode, encode
from .independent_wire import ZERO, ZERO_ADDRESS, json_values, require
from .owner_catalog_source import _position, _location
from .public_chain_history import scan_public_history, PROFILE_HASH as HISTORY_PROFILE_HASH
from .public_history_rpc import PublicRecordingReader, PublicReplayTransport, PublicRpcTransport, quantity

PROFILE = "STREAM_MUSEUM_PUBLIC_DIRECT_CONSERVATION_SOURCE_V1"
SOURCE_REVISION = CORE_REVISION = "8bb6dfe2957542f641b0d558e1cfd48e1b39ae98"
MAX_ANCHOR, MAX_ABI, MAX_OUTPUT = f.MAX_ANCHOR, f.MAX_ABI, f.MAX_OUTPUT
MAX_SOURCES, MAX_RECEIPTS, MAX_PINS = f.MAX_SOURCES, f.MAX_RECEIPTS, f.MAX_PINS
BINDINGS = ("address", "bytes32", "address", "bytes32", "uint256", "bytes32")
SALE = ("bytes32", "uint256", "uint256", "bytes32", "bytes32", "bytes32", "bytes32", "bytes32",
    "address", "uint64", "bool", "address", "uint64", "address", "address", "uint256")
DIRECT = ("bytes32", "address", "bytes32", "bytes32", "bytes32", "bytes32", BINDINGS, SALE,
    "bytes32", "bytes32", "bytes32", "uint64")
KEY_DOMAIN = schema_id("6529STREAM_DIRECT_PRIMARY_SALE_KEY_V1")
ORIGINAL_DOMAIN = schema_id("6529STREAM_DIRECT_PRIMARY_SALE_RECEIPT_V1")
DIRECT_DOMAIN = schema_id("6529STREAM_CONSERVATION_DIRECT_RECEIPT_V1")
NATIVE, ERC20, AUCTION = (schema_id("6529STREAM_DIRECT_" + name + "_V1")
    for name in ("NATIVE_FIXED_PRICE", "ERC20_FIXED_PRICE", "ENGLISH_AUCTION"))
PRODUCTS = {NATIVE: "native_fixed_price", ERC20: "erc20_fixed_price", AUCTION: "english_auction"}
DIRECT_EVENT = schema_id("ConservationDirectPrimarySaleRecorded(bytes32,bytes32," + f._signature(DIRECT) + ",uint16)")
ORIGINAL_EVENT = schema_id("DirectPrimarySaleRecorded(bytes32,bytes32,uint256," + f._signature(SALE) + ",uint16)")


def _interface_id(*signatures):
    result = 0
    for signature in signatures: result ^= int(schema_id(signature)[2:10], 16)
    return "0x" + result.to_bytes(4, "big").hex()


DIRECT_FLOOR_INTERFACE = _interface_id("recordDirectPrimarySale(bytes32)", "directPrimarySaleFloorReceipt(bytes32)")
DIRECT_SALE_INTERFACE = _interface_id("directPrimaryBindings()", "directPrimarySaleReceipt(bytes32)", "directPrimarySaleReceiptHash(bytes32)")
QUALIFICATION = ("Bounded original DIRECT conservation receipts at one pinned block, with complete known-family "
    "ledger discovery before collection selection. This profile admits only DIRECT target histories; target universal "
    "or mixed histories fail closed, while foreign typed rows remain in the discovery denominator. Exact original "
    "adapter bindings, paid receipt, receipt hash and successful event are retained separately from universal "
    "settlement/candidate/result concepts. Original manager used authorization/root and completed Core identity "
    "are read at the source block; no token-to-operation getter exists and the admitted adapter's original mint "
    "validation remains trusted. Auction creation time is distinct from its later paid publication. Saved source "
    "and release facts survive replacement; current provider and registry eligibility are not reexecuted. "
    "Original adapter/manager runtime and local state must remain readable with their saved pins for this "
    "strict original-join capture; missing originals prevent capture without erasing immutable ledger history. "
    "ERC20 receipts save an asset address, not an asset runtime hash; its historical contract admission remains "
    "the floor's assertion and no present-day asset code is required. "
    "An empty target is no observed recorded paid DIRECT outcome, not proof about free, unpaid, cancelled, "
    "refunded or no-bid operations. DIRECT does not supply the universal supplemental bridge. "
    "Provider log completeness, canonical mappings and external runtime/provenance admission remain trusted. "
    "Receipt replay does not reprove payment execution, signatures, personhood, underlying documentary facts, "
    "all paid routes, native runtime acceptance, consensus or a complete acquisition packet.")
CLAIMS = {"completeKnownFamilyLedgerDiscovery": True, "completeSourceAdmissionHistory": True,
    "typedDirectReceiptsRetained": True, "immutableReceiptHashesChecked": True,
    "originalAdapterReceiptJoined": True, "originalAdapterPaidEventJoined": True,
    "originalManagerUsedStateJoined": True, "completedCoreIdentityJoined": True,
    "universalProjectionSynthesized": False, "targetMixedFamiliesSupported": False,
    "historicalReplacementPreserved": True, "historicalRegistryEligibilityReexecuted": False,
    "historicalProviderEligibilityReexecuted": False, "tokenOperationGetterAvailable": False,
    "originalMintReturnValidationTrusted": True, "providerLogCompletenessTrusted": True,
    "originalDependenciesAvailableRequired": True, "supplementalCoverage": False,
    "historicalAssetContractAdmissionTrusted": True, "currentAssetCodeRequired": False,
    "canonicalMappingTrusted": True, "allPaidRoutesCovered": False,
    "documentaryFactsIndependentlyVerified": False, "personhoodProven": False,
    "paymentExecutionReproved": False, "signaturesReverified": False,
    "nativeRuntimeAcceptance": False, "actualChainAcceptance": False,
    "consensusProof": False, "completeAcquisitionPacket": False}
PROFILE_BYTES = dumps({"name": PROFILE, "version": "1", "sourceReviewCommit": SOURCE_REVISION,
    "coreSourceReviewCommit": CORE_REVISION, "historyProfileHash": HISTORY_PROFILE_HASH,
    "commonFloorHelpersProfileHash": f.PROFILE_HASH,
    "bounds": {"sources": str(MAX_SOURCES), "ledgerReceiptEvents": str(MAX_RECEIPTS), "codePins": str(MAX_PINS)},
    "interfaces": {"directFloor": DIRECT_FLOOR_INTERFACE, "originalDirectSale": DIRECT_SALE_INTERFACE},
    "denominator": "Permanent Core binding, exact original source admissions and ledger-wide first/release/universal/DIRECT events before collection selection; no operator-selected receipt list.",
    "supportedTarget": "DIRECT-only or no recorded target sale; any target universal or mixed family is rejected, never silently omitted.",
    "originalSale": "Full six-word bindings and sixteen-word local paid receipt, exact domain-separated keys/hashes, typed floor getter and zero universal getter, matching original four-topic event immediately after the floor event.",
    "temporal": "Native/ERC20 fixed-price creation equals paid floor time; English auction creation may precede paid floor time. Burned completed token identities are retained; no current owner is required.",
    "authority": "Exact original code-pinned adapter/manager, monotonic used authorization/root, successful receipt and permanent ledger acceptance. No current registry/provider reauthorization, historical signatures or payment reexecution.",
    "commonEvidence": "Unchanged native FirstSale/Release/Source hash recipes and original governance receipt joins reuse frozen floor helpers; old source/capture bytes and profile meanings are unchanged.",
    "claims": CLAIMS, "qualification": QUALIFICATION})
PROFILE_HASH = keccak256(PROFILE_BYTES)


def direct_key(bindings, adapter, authorization_id):
    return keccak256(encode(("bytes32", "uint256", "address", "address", "bytes32", "bytes32"),
        (KEY_DOMAIN, bindings[4], bindings[0], adapter, bindings[5], authorization_id)))


def original_hash(bindings, adapter, authorization_id, sale):
    return keccak256(encode(("bytes32", "uint256", "address", "address", "bytes32", "bytes32", SALE),
        (ORIGINAL_DOMAIN, bindings[4], bindings[0], adapter, bindings[5], authorization_id, sale)))


class PublicDirectConservationSource(f.PublicConservationFloorSource):
    """Reuse only unchanged native shared evidence helpers, never a universal projection."""
    def __init__(self, anchor_bytes, transport, *, provenance="synthetic_fixture"):
        require(provenance in ("synthetic_fixture", "trusted_rpc") and
            (provenance != "trusted_rpc" or type(transport) in (PublicRpcTransport, PublicReplayTransport)), "DIRECT conservation provenance")
        a = loads(anchor_bytes, maximum=MAX_ANCHOR, canonical=True)
        require(type(a) is dict and set(a) == {"profile", "chainId", "blockHash", "blockNumber", "timestamp",
            "stateRoot", "environment", "deploymentEvidenceHash", "core", "conservationFloor", "executor", "collectionId", "codePins"}
            and a["profile"] == PROFILE and a["environment"] in ("local_evm_fixture", "public_chain"), "DIRECT conservation anchor shape/profile")
        require(uint(a["chainId"]) > 0 and uint(a["collectionId"]) > 0, "DIRECT conservation nonzero identity")
        uint(a["blockNumber"]); uint(a["timestamp"], 64)
        for key in ("blockHash", "stateRoot", "deploymentEvidenceHash"):
            require(any(hex_bytes(a[key], 32)), "DIRECT conservation empty commitment")
        for key in ("core", "conservationFloor", "executor"):
            require(any(hex_bytes(a[key], 20)), "DIRECT conservation empty address")
        require(len({a[k] for k in ("core", "conservationFloor", "executor")}) == 3, "DIRECT conservation distinct hosts")
        require(type(a["codePins"]) is list and 3 <= len(a["codePins"]) <= MAX_PINS, "DIRECT conservation pin bound")
        pins = {}
        for p in a["codePins"]:
            require(type(p) is dict and set(p) == {"address", "runtimeHash"}, "DIRECT conservation pin shape")
            require(any(hex_bytes(p["address"], 20)) and any(hex_bytes(p["runtimeHash"], 32))
                and p["address"] not in pins, "DIRECT conservation duplicate/empty pin")
            pins[p["address"]] = p["runtimeHash"]
        require(all(a[k] in pins for k in ("core", "conservationFloor", "executor")), "DIRECT conservation missing dependency pin")
        self.a, self.pins, self.anchor_bytes, self.provenance = a, pins, anchor_bytes, provenance
        self.reader = PublicRecordingReader(transport, a["blockHash"])
        self._started, self._snapshot = False, None

    def _discovery(self, history, binding):
        found = super()._discovery(history, binding)
        bound = tuple(uint(binding["publication"][k]) for k in ("blockNumber", "transactionIndex", "logIndex"))
        keys = {row[3] for name, row, _ in found if name == "settlement"}
        for log in history["logs"]:
            if log["address"] != self.a["conservationFloor"] or log["topics"][0] != DIRECT_EVENT: continue
            require(len(found) < MAX_RECEIPTS, "DIRECT conservation ledger event bound")
            row, version = decode((DIRECT, "uint16"), hex_bytes(log["data"]), maximum=MAX_ABI)
            require(version == 1 and len(log["topics"]) == 3 and log["topics"][1:] == [row[3], row[0]]
                and row[0] != ZERO and row[3] != ZERO and row[7][1] > 0
                and f.receipt_hash(self.a, DIRECT_DOMAIN, DIRECT, row) == row[0]
                and row[3] not in keys and _position(log) > bound, "DIRECT conservation receipt event/hash/key differs")
            keys.add(row[3]); found.append(("direct", row, log))
        return sorted(found, key=lambda value: _position(value[2]))

    def _direct(self, row, log):
        a = self.a; adapter, bindings, sale = row[1], row[6], row[7]
        manager, product = bindings[2], bindings[5]
        stamp = uint(self._history["blockTimestamps"][str(quantity(log["blockNumber"]))])
        require(adapter in self.pins and row[2] == self.pins[adapter] and manager in self.pins
            and bindings == (a["core"], self.pins[a["core"]], manager, self.pins[manager], uint(a["chainId"]), product)
            and product in PRODUCTS and row[4] != ZERO and row[8] in f.TIERS and row[9] != ZERO
            and 0 < row[11] == stamp, "DIRECT conservation original bindings/identity/time differs")
        require(all(sale[k] != ZERO for k in (0, 3, 4, 5, 6, 7)) and sale[1] > 0 and sale[2] > 0
            and all(sale[k] != ZERO_ADDRESS for k in (8, 11, 13)) and 0 < sale[9] <= row[11]
            and sale[12] > 0 and sale[15] > 0
            and (sale[14] != ZERO_ADDRESS if product == ERC20 else sale[14] == ZERO_ADDRESS)
            and (product == AUCTION or sale[9] == row[11]), "DIRECT conservation original paid fields differ")
        require(row[3] == direct_key(bindings, adapter, row[4])
            and row[5] == original_hash(bindings, adapter, row[4], sale), "DIRECT conservation original key/hash differs")
        self._interface(adapter, DIRECT_SALE_INTERFACE)
        require(self._read(adapter, "directPrimaryBindings()", (BINDINGS,)) == (bindings,)
            and self._read(adapter, "directPrimarySaleReceipt(bytes32)", (SALE,), ("bytes32",), (row[4],)) == (sale,)
            and self._read(adapter, "directPrimarySaleReceiptHash(bytes32)", ("bytes32",), ("bytes32",), (row[4],)) == (row[5],),
            "DIRECT conservation original adapter getter differs")
        require(self._read(manager, "core()", ("address",)) == (a["core"],)
            and self._read(manager, "isOperationRootUsed(bytes32)", ("bool",), ("bytes32",), (sale[3],)) == (True,)
            and self._read(manager, "isAuthorizationUsed(bytes32)", ("bool",), ("bytes32",), (row[4],)) == (True,),
            "DIRECT conservation original manager used state differs")
        identity = self._read(a["core"], "tokenCollectionIdentity(uint256)", ("bool", "uint256", "uint256", "bool"), ("uint256",), (sale[2],))
        lifecycle, = self._read(a["core"], "tokenLifecycle(uint256)", ("uint8",), ("uint256",), (sale[2],))
        require(identity[0] and identity[1] == sale[1] and identity[2] > 0 and lifecycle in (2, 3)
            and identity[3] == (lifecycle == 3), "DIRECT conservation completed token identity differs")
        receipt = self.reader.request("eth_getTransactionReceipt", [log["transactionHash"]])
        events = [event for event in receipt["logs"] if event["address"] == adapter and len(event["topics"]) > 1
            and event["topics"][0] == ORIGINAL_EVENT and event["topics"][1] == row[4]]
        require(len(events) == 1, "DIRECT conservation original paid event missing/duplicate")
        event = events[0]
        require(event["topics"] == [ORIGINAL_EVENT, row[4], row[5], f._topic("uint256", sale[2])]
            and decode((SALE, "uint16"), hex_bytes(event["data"]), maximum=MAX_ABI) == (sale, 1)
            and _position(event) == (*_position(log)[:2], _position(log)[2] + 1),
            "DIRECT conservation original paid event version/order/receipt differs")
        return {"receiptHash": row[0], "adapter": adapter, "adapterCodeHash": row[2], "directKey": row[3],
            "authorizationId": row[4], "originalReceiptHash": row[5], "productKind": product, "product": PRODUCTS[product],
            "collectionId": str(sale[1]), "tokenId": str(sale[2]), "effectiveTier": f.TIERS[row[8]],
            "firstSaleReceiptHash": row[9], "releaseReceiptHash": row[10], "recordedAt": str(row[11]),
            "receipt": json_values(row), "publication": _location(log),
            "originalSale": {"bindings": json_values(bindings), "receipt": json_values(sale), "receiptHash": row[5],
                "publication": _location(event), "event": {"topics": event["topics"], "data": json_values((sale, 1))},
                "managerState": {"core": a["core"], "authorizationUsed": True, "operationRootUsed": True},
                "tokenIdentity": {"exists": True, "collectionId": str(identity[1]), "collectionSerial": str(identity[2]),
                    "burned": identity[3], "lifecycle": str(lifecycle)}, "universalGetterEmpty": True}}

    @staticmethod
    def _created_by_direct(evidence, direct):
        ep, dp = evidence["publication"], direct["publication"]
        require(evidence["settlementKey"] == direct["directKey"] and evidence["recorder"] == direct["adapter"]
            and ep["transactionHash"] == dp["transactionHash"] and uint(ep["logIndex"]) < uint(dp["logIndex"])
            and evidence["recordedAt"] == direct["recordedAt"] and evidence["effectiveTier"] == direct["effectiveTier"],
            "DIRECT conservation shared receipt creating sale differs")

    def _floor(self, discovered, catalogue):
        a = self.a; cid = uint(a["collectionId"]); host = a["conservationFloor"]
        target = [(name, row, log) for name, row, log in discovered
            if (row[7][1] if name == "direct" else row[{"first_sale": 1, "release": 2, "settlement": 7}[name]]) == cid]
        require(not any(name == "settlement" for name, _, _ in target), "DIRECT conservation unsupported target universal/mixed history")
        stored_first, = self._read(host, "firstSale(uint256)", (f.FIRST,), ("uint256",), (cid,))
        first_rows = [(row, log) for name, row, log in target if name == "first_sale"]
        if not first_rows:
            require(not target and encode((f.FIRST,), (stored_first,)) == bytes(512), "DIRECT conservation absent first sale differs")
            return {"status": "none_recorded", "firstSale": None, "releases": [], "directSales": []}
        require(len(first_rows) == 1 and stored_first == first_rows[0][0], "DIRECT conservation first sale event/getter differs")
        first = self._first(*first_rows[0], catalogue)
        releases, sales = [], []
        for name, row, log in target:
            if name == "release":
                require(self._read(host, "releaseFloorReceipt(bytes32)", (f.RELEASE,), ("bytes32",), (row[1],)) == (row,),
                    "DIRECT conservation release event/getter differs")
                releases.append(self._release(row, log, catalogue))
            elif name == "direct":
                require(self._read(host, "directPrimarySaleFloorReceipt(bytes32)", (DIRECT,), ("bytes32",), (row[3],)) == (row,),
                    "DIRECT conservation typed floor event/getter differs")
                universal, = self._read(host, "settlementReceipt(bytes32)", (f.SETTLEMENT,), ("bytes32",), (row[3],))
                require(encode((f.SETTLEMENT,), (universal,)) == bytes(416), "DIRECT conservation universal getter is not empty")
                sales.append(self._direct(row, log))
        require(sales, "DIRECT conservation first sale has no original paid DIRECT receipt")
        self._created_by_direct(first, sales[0])
        by_key = {sale["directKey"]: sale for sale in sales}; by_hash = {r["receiptHash"]: r for r in releases}
        for release in releases:
            require(release["settlementKey"] in by_key, "DIRECT conservation release creating sale missing")
            creator = by_key[release["settlementKey"]]; self._created_by_direct(release, creator)
            require(creator["releaseReceiptHash"] == release["receiptHash"]
                and uint(release["publication"]["logIndex"]) + 1 == uint(creator["publication"]["logIndex"]),
                "DIRECT conservation release creation hash/order differs")
        first_release = next((r for r in releases if r["settlementKey"] == first["settlementKey"]), None)
        require(uint(first["publication"]["logIndex"]) + 1 == uint((first_release or sales[0])["publication"]["logIndex"]),
            "DIRECT conservation first receipt order differs")
        for sale in sales:
            require(sale["firstSaleReceiptHash"] == first["receiptHash"] and sale["effectiveTier"] == first["effectiveTier"],
                "DIRECT conservation first-sale link/tier differs")
            digest = sale["releaseReceiptHash"]
            if sale["effectiveTier"] == f.TIERS[f.WAIVED]:
                require(digest == ZERO and not releases, "DIRECT conservation waived release differs")
            else:
                require(digest in by_hash, "DIRECT conservation historical release missing")
                release = by_hash[digest]
                require(release["effectiveTier"] == sale["effectiveTier"] and tuple(uint(release["publication"][k]) for k in
                    ("blockNumber", "transactionIndex", "logIndex")) < tuple(uint(sale["publication"][k]) for k in
                    ("blockNumber", "transactionIndex", "logIndex")), "DIRECT conservation release history order/tier differs")
        return {"status": "present", "firstSale": first, "releases": releases, "directSales": sales}

    def _capture(self):
        a = self.a; host = a["conservationFloor"]
        self._bindings(); self._interface(host, DIRECT_FLOOR_INTERFACE); catalogue = self._catalogue()
        filters = [{"address": a["core"], "topics": [f.BOUND_EVENT]},
            {"address": host, "topics": [[f.ADDED_EVENT, f.FIRST_EVENT, f.RELEASE_EVENT, f.SETTLEMENT_EVENT, DIRECT_EVENT]]}]
        history = scan_public_history(self.reader, a, filters=filters); self._history = history
        binding = self._admissions(catalogue, history); discovered = self._discovery(history, binding)
        floor = self._floor(discovered, catalogue)
        require(self._read(host, "sourceSetHead()", ("uint64", "bytes32")) == (uint(catalogue["count"]), catalogue["head"])
            and self._read(host, "sourceCount()", ("uint64",)) == (uint(catalogue["count"]),)
            and self._read(a["core"], "conservationFloor()", ("address", "bytes32")) == (host, self.pins[host]),
            "DIRECT conservation final binding/catalog changed")
        source_header = next(row["result"] for row in self.reader.rows if row["method"] == "eth_getBlockByHash" and row["params"] == [a["blockHash"], False])
        require(self.reader.request("eth_getBlockByHash", [a["blockHash"], False]) == source_header and
            self.reader.request("eth_getBlockByNumber", [hex(uint(a["blockNumber"])), False]) == source_header, "DIRECT conservation final anchor changed")
        if type(self.reader.transport) is PublicReplayTransport: self.reader.transport.finish()
        coverage = {"scan": history["coverage"], "ledgerReceiptEventCount": str(len(discovered)),
            "targetReceiptEventCount": str((1 if floor["firstSale"] else 0) + len(floor["releases"]) + len(floor["directSales"])),
            "ledgerReceiptEvents": [{"kind": name, "receipt": json_values(row), "publication": _location(log)} for name, row, log in discovered],
            "providerLogCompletenessTrusted": True, "canonicalMappingTrusted": True,
            "independentSaleCountAvailable": False, "targetMixedFamiliesSupported": False, "supplementalCoverage": False}
        result = dumps({"profile": PROFILE, "profileHash": PROFILE_HASH, "version": "1", "sourceReviewCommit": SOURCE_REVISION,
            "coreSourceReviewCommit": CORE_REVISION, "mode": "caller_admitted_rpc_direct_conservation" if self.provenance == "trusted_rpc" else "synthetic_fixture",
            "anchorHash": keccak256(self.anchor_bytes), "transcriptHash": keccak256(self.transcript()),
            "sourceState": {k: a[k] for k in ("chainId", "core", "conservationFloor", "collectionId", "blockHash", "blockNumber", "timestamp", "environment")},
            "binding": binding, "catalogue": catalogue, "floor": floor, "historyCoverage": coverage, "claims": CLAIMS, "qualification": QUALIFICATION})
        require(len(result) <= MAX_OUTPUT, "DIRECT conservation snapshot bound")
        return result

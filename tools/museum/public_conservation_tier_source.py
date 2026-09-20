"""Durable Core conservation declarations and completed-mint default provenance."""
from .canonical import MuseumError, dumps, hex_bytes, keccak256, loads, schema_id, uint
from .chain_abi import calldata, decode, encode
from .independent_wire import ZERO, ZERO_ADDRESS, json_values, require
from .mint_entropy_source import REGISTERED, REVERTED, TRANSFER
from .owner_catalog_source import _position, _location
from .public_chain_history import scan_public_history, PROFILE_HASH as HISTORY_PROFILE_HASH
from .public_mint_entropy_source import PublicMintEntropySource
from .public_history_rpc import PublicRecordingReader, PublicReplayTransport, PublicRpcTransport, quantity

PROFILE = "STREAM_MUSEUM_PUBLIC_CONSERVATION_TIER_SOURCE_V1"
SOURCE_REVISION = "f7a05e0734b95f1e2ff1a038b73511c0d94b6f81"
CORE_REVISION = "ff372f80b830b45a6afb30583780414f3abcc4cc"
MAX_ANCHOR, MAX_ALLOCATIONS, MAX_OUTPUT = 65536, 256, 4194304
CORE_TIER_EVENT = schema_id("ConservationTierRecorded(uint16,uint256,bytes32,address)")
FACADE_TIER_EVENT = schema_id("CollectionConservationTierDeclared(uint256,bytes32,uint16)")
TIERS = {schema_id(name): name for name in ("MUSEUM_GRADE", "MUSEUM_GRADE_LITE", "CONSERVATION_WAIVED")}
QUALIFICATION = ("The permanent Core declaration and complete collection allocation denominator are reconciled with "
    "successful original mint Transfer receipts and collectionMintedEver. Current Metadata replacement or absence "
    "does not change historical declarations. A raw zero declaration has no public effective tier before completed "
    "minting; afterward its default is LITE. The prospective LITE sale rule is reported separately and does not "
    "prove floor enforcement. Provider log completeness and canonical mappings remain trusted. Native Core "
    "acceptance is retained without reexecuting historical facade grants, entropy, callbacks or governance. "
    "No consensus, actual-chain acceptance, sale-floor receipt or complete acquisition packet is established.")
CLAIMS = {"durableCoreDeclarationChecked": True, "completeCollectionAllocationHistory": True,
    "completedMintCountReconciled": True, "firstCompletedMintReceiptRetained": True,
    "replacementIndependentDefault": True, "rawZeroDistinctFromProspectiveFloor": True,
    "providerLogCompletenessTrusted": True, "canonicalMappingTrusted": True,
    "historicalFacadeGrantsReexecuted": False, "entropyExecutionReproved": False,
    "saleFloorEnforcementProven": False, "saleFloorReceiptJoined": False,
    "actualChainAcceptance": False, "consensusProof": False, "completeAcquisitionPacket": False}
PROFILE_BYTES = dumps({"name": PROFILE, "version": "1", "sourceReviewCommit": SOURCE_REVISION,
    "coreSourceReviewCommit": CORE_REVISION, "historyProfileHash": HISTORY_PROFILE_HASH,
    "bounds": {"collectionAllocations": str(MAX_ALLOCATIONS), "anchorBytes": str(MAX_ANCHOR), "snapshotBytes": str(MAX_OUTPUT)},
    "denominator": "Core collectionNextSerial starts1; retain every serial through nextSerial-1, including aborted and pending identities. Token IDs are never reused; each nonfinal allocation completes or aborts before the next registration.",
    "history": "Core declaration and collection allocation/revert filters, then zero-from Transfer filters for every discovered token. Complete successful receipts and cross-stage canonical observations agree.",
    "declaration": "Core raw getter and at most one original Core event, with its original facade counterpart in the same successful receipt; no current-facade absence inference.",
    "default": "Only successful completed mint Transfer count matching collectionMintedEver enables undeclared LITE; allocation/preparation/abort do not, and burns do not undo it.",
    "prospectiveFloor": "Undeclared uses LITE prospectively at first sale independently of the public pre-completion effective-tier getter; a rule derivation, not an enforcement claim.",
    "claims": CLAIMS, "qualification": QUALIFICATION})
PROFILE_HASH = keccak256(PROFILE_BYTES)


def _topic(kind, value): return "0x" + encode((kind,), (value,)).hex()


class PublicConservationTierSource:
    def __init__(self, anchor_bytes, transport, *, provenance="synthetic_fixture"):
        require(provenance in ("synthetic_fixture", "trusted_rpc") and
            (provenance != "trusted_rpc" or type(transport) in (PublicRpcTransport, PublicReplayTransport)),
            "conservation tier provenance")
        a = loads(anchor_bytes, maximum=MAX_ANCHOR, canonical=True)
        require(type(a) is dict and set(a) == {"profile", "chainId", "blockHash", "blockNumber", "timestamp",
            "stateRoot", "environment", "deploymentEvidenceHash", "core", "coreRuntimeHash", "collectionId"}
            and a["profile"] == PROFILE and a["environment"] in ("local_evm_fixture", "public_chain"),
            "conservation tier anchor shape/profile")
        require(uint(a["chainId"]) > 0 and uint(a["collectionId"]) > 0, "conservation tier nonzero identity")
        uint(a["blockNumber"]); uint(a["timestamp"], 64)
        for key in ("blockHash", "stateRoot", "deploymentEvidenceHash", "coreRuntimeHash"):
            require(any(hex_bytes(a[key], 32)), "conservation tier empty commitment")
        require(any(hex_bytes(a["core"], 20)), "conservation tier Core address")
        self.a, self.anchor_bytes, self.provenance = a, anchor_bytes, provenance
        self.reader = PublicRecordingReader(transport, a["blockHash"])
        self._started, self._snapshot = False, None

    def transcript(self): return self.reader.transcript()

    def _read(self, signature, outputs, kinds=(), values=()):
        return decode(outputs, hex_bytes(self.reader.call(self.a["core"], calldata(signature, kinds, values))), maximum=4096)

    def snapshot(self):
        if self._snapshot is not None: return self._snapshot
        require(not self._started, "failed conservation tier capture cannot resume")
        self._started = True
        try: self._snapshot = self._capture()
        except MuseumError: raise
        except (KeyError, TypeError, IndexError, ValueError, OverflowError) as exc:
            raise MuseumError("malformed conservation tier evidence") from exc
        return self._snapshot

    def _state(self):
        cid = uint(self.a["collectionId"])
        require(self._read("collectionExists(uint256)", ("bool",), ("uint256",), (cid,)) == (True,),
            "conservation tier collection unavailable")
        declared, = self._read("declaredConservationTier(uint256)", ("bytes32",), ("uint256",), (cid,))
        minted, = self._read("collectionMintedEver(uint256)", ("uint256",), ("uint256",), (cid,))
        serial, = self._read("collectionNextSerial(uint256)", ("uint256",), ("uint256",), (cid,))
        require(declared == ZERO or declared in TIERS, "conservation tier unknown native declaration")
        require(1 <= serial <= MAX_ALLOCATIONS + 1 and minted < serial, "conservation tier complete allocation bound/state")
        return declared, minted, serial

    def _allocations(self, history, next_serial):
        allocations = {}; cid = uint(self.a["collectionId"])
        for log in history["logs"]:
            if log["topics"][0] not in (REGISTERED, REVERTED): continue
            require(log["address"] == self.a["core"] and len(log["topics"]) == 3
                and log["topics"][2] == _topic("uint256", cid), "conservation tier allocation scope differs")
            token, = decode(("uint256",), hex_bytes(log["topics"][1]))
            require(token > 0, "conservation tier allocated zero token")
            if log["topics"][0] == REGISTERED:
                version, serial = decode(("uint16", "uint256"), hex_bytes(log["data"]))
                require(version == 1 and token not in allocations and serial == len(allocations) + 1
                    and (not allocations or token > max(allocations)), "conservation tier allocation denominator/order differs")
                require(len(allocations) < MAX_ALLOCATIONS, "conservation tier allocation bound")
                allocations[token] = {"tokenId": str(token), "collectionSerial": str(serial), "registered": log, "reverted": None}
            else:
                require(decode(("uint16",), hex_bytes(log["data"])) == (1,) and token in allocations
                    and allocations[token]["reverted"] is None, "conservation tier orphan/duplicate abort")
                allocations[token]["reverted"] = log
        require(len(allocations) == next_serial - 1, "conservation tier missing allocation suffix")
        return allocations

    def _mint_history(self, history, allocations, minted_ever):
        a = self.a; mints = {}
        for log in history["logs"]:
            if log["topics"][0] != TRANSFER: continue
            require(log["address"] == a["core"] and len(log["topics"]) == 4 and log["data"] == "0x"
                and log["topics"][1] == ZERO, "conservation tier completed mint Transfer shape")
            recipient, = decode(("address",), hex_bytes(log["topics"][2]))
            token, = decode(("uint256",), hex_bytes(log["topics"][3]))
            require(token in allocations and token not in mints and recipient != ZERO_ADDRESS
                and allocations[token]["reverted"] is None and _position(log) > _position(allocations[token]["registered"]),
                "conservation tier missing allocation/duplicate/aborted mint")
            mints[token] = {"tokenId": str(token), "collectionSerial": allocations[token]["collectionSerial"],
                "recipient": recipient, "publication": _location(log), "blockTimestamp": history["blockTimestamps"][str(quantity(log["blockNumber"]))], "transfer": log}
        require(len(mints) == minted_ever, "conservation tier completed mint count differs")
        ordered = list(allocations.items())
        for (token, allocation), (_, following) in zip(ordered, ordered[1:]):
            terminal = allocation["reverted"] or (mints[token]["transfer"] if token in mints else None)
            require(terminal is not None and _position(terminal) < _position(following["registered"]),
                "conservation tier overlapping allocation/completion history")
        pending = 0
        for token, allocation in allocations.items():
            identity = self._read("tokenCollectionIdentity(uint256)", ("bool", "uint256", "uint256", "bool"), ("uint256",), (token,))
            lifecycle, = self._read("tokenLifecycle(uint256)", ("uint8",), ("uint256",), (token,))
            if allocation["reverted"] is not None:
                require(identity == (False, 0, 0, False) and lifecycle == 0, "conservation tier aborted identity differs")
                status = "aborted"
            else:
                require(identity[:3] == (True, uint(a["collectionId"]), uint(allocation["collectionSerial"]))
                    and identity[3] == (lifecycle == 3), "conservation tier retained identity differs")
                if token in mints:
                    require(lifecycle in (2, 3), "conservation tier completed mint lifecycle differs")
                    status = "burned" if lifecycle == 3 else "minted"
                else:
                    require(lifecycle == 1, "conservation tier missing completed mint receipt")
                    pending += 1; status = "prepared_incomplete"
            allocation.update(status=status, identity=json_values(identity), lifecycle=str(lifecycle))
        require(pending <= 1, "conservation tier multiple pending Core mints")
        return sorted(mints.values(), key=lambda row: tuple(uint(row["publication"][k]) for k in ("blockNumber", "transactionIndex", "logIndex")))

    def _declaration(self, history, declared, completed):
        a = self.a
        events = [log for log in history["logs"] if log["topics"][0] == CORE_TIER_EVENT]
        require(len(events) == (0 if declared == ZERO else 1), "conservation tier declaration state/history differs")
        if not events: return None
        log = events[0]
        require(log["address"] == a["core"] and len(log["topics"]) == 4
            and log["topics"][1:3] == [_topic("uint256", uint(a["collectionId"])), declared]
            and decode(("uint16",), hex_bytes(log["data"])) == (1,), "conservation tier original Core declaration differs")
        metadata, = decode(("address",), hex_bytes(log["topics"][3]))
        require(metadata != ZERO_ADDRESS, "conservation tier zero original facade")
        receipt = self.reader.request("eth_getTransactionReceipt", [log["transactionHash"]])
        candidates = [row for row in receipt["logs"] if row["address"] == metadata and row["topics"]
            and row["topics"][0] == FACADE_TIER_EVENT and len(row["topics"]) > 1 and row["topics"][1] == log["topics"][1]]
        require(len(candidates) == 1, "conservation tier exact original facade counterpart required")
        facade = candidates[0]
        require(facade["topics"] == [FACADE_TIER_EVENT, log["topics"][1], declared]
            and decode(("uint16",), hex_bytes(facade["data"])) == (1,) and _position(facade) > _position(log),
            "conservation tier original facade event/order differs")
        if completed:
            require(_position(facade) < _position(completed[0]["transfer"]), "conservation tier declaration after completed mint")
        return {"tier": TIERS[declared], "tierHash": declared, "metadataHost": metadata,
            "blockTimestamp": history["blockTimestamps"][str(quantity(log["blockNumber"]))],
            "publication": _location(log), "coreEvent": log, "facadeEvent": facade,
            "authority": "historical_native_Core_acceptance", "historicalFacadeGrantsReexecuted": False}

    def _capture(self):
        a = self.a; core = a["core"]
        require(quantity(self.reader.request("eth_chainId", [])) == uint(a["chainId"]), "conservation tier chain differs")
        code = hex_bytes(self.reader.code(core))
        require(0 < len(code) <= 24576 and keccak256(code) == a["coreRuntimeHash"], "conservation tier Core runtime differs")
        for interface, expected in (("0xc10ccea9", True), ("0x80ac58cd", True), ("0x01ffc9a7", True), ("0xffffffff", False)):
            require(self._read("supportsInterface(bytes4)", ("bool",), ("bytes4",), (interface,)) == (expected,), "conservation tier Core interface differs")
        declared, minted, next_serial = self._state()
        cid_topic = _topic("uint256", uint(a["collectionId"]))
        primary_filters = [{"address": core, "topics": [CORE_TIER_EVENT, cid_topic]},
            {"address": core, "topics": [[REGISTERED, REVERTED], None, cid_topic]}]
        primary = scan_public_history(self.reader, a, filters=primary_filters)
        allocations = self._allocations(primary, next_serial)
        tokens = list(allocations)
        mint_filters = [{"address": core, "topics": [TRANSFER, ZERO, None,
            [_topic("uint256", token) for token in tokens[start:start + 64]]]} for start in range(0, len(tokens), 64)]
        mint_history = scan_public_history(self.reader, a, filters=mint_filters) if mint_filters else None
        # This helper only reconciles already validated public-history stages;
        # it does not construct or admit an unrelated mint/entropy source.
        history = PublicMintEntropySource._joined_history(self,
            [primary] + ([mint_history] if mint_history else []), primary_filters + mint_filters)
        completed = self._mint_history(history, allocations, minted)
        declaration = self._declaration(history, declared, completed)
        require(self._state() == (declared, minted, next_serial), "conservation tier final Core state changed")
        source_header = next(row["result"] for row in self.reader.rows if row["method"] == "eth_getBlockByHash" and row["params"] == [a["blockHash"], False])
        require(self.reader.request("eth_getBlockByHash", [a["blockHash"], False]) == source_header
            and self.reader.request("eth_getBlockByNumber", [hex(uint(a["blockNumber"])), False]) == source_header, "conservation tier final anchor changed")
        if type(self.reader.transport) is PublicReplayTransport: self.reader.transport.finish()
        tier = {"rawDeclaredTier": declared, "declaredTier": TIERS.get(declared),
            "tierBasis": "declared" if declared != ZERO else "default" if minted else "not_yet_effective",
            "effectiveTier": TIERS[declared] if declared != ZERO else "MUSEUM_GRADE_LITE" if minted else None,
            "prospectiveSaleTier": TIERS.get(declared, "MUSEUM_GRADE_LITE"),
            "prospectiveSaleTierBasis": "declared" if declared != ZERO else "undeclared_lite_floor_rule",
            "declaration": declaration, "firstCompletedMint": completed[0] if completed else None,
            "completedMintCount": str(minted), "nextCollectionSerial": str(next_serial)}
        coverage = {"primary": primary["coverage"], "mints": mint_history["coverage"] if mint_history else None,
            "mintScanStatus": "queried" if mint_filters else "not_queried_no_allocations", "unionCounts": history["counts"],
            "providerLogCompletenessTrusted": True, "canonicalMappingTrusted": True}
        result = dumps({"profile": PROFILE, "profileHash": PROFILE_HASH, "version": "1", "sourceReviewCommit": SOURCE_REVISION,
            "coreSourceReviewCommit": CORE_REVISION, "mode": "caller_admitted_rpc_conservation_tier" if self.provenance == "trusted_rpc" else "synthetic_fixture",
            "anchorHash": keccak256(self.anchor_bytes), "transcriptHash": keccak256(self.transcript()),
            "sourceState": {key: a[key] for key in ("chainId", "core", "coreRuntimeHash", "collectionId", "blockHash", "blockNumber", "timestamp", "environment")},
            "tier": tier, "allocations": list(allocations.values()), "completedMints": completed,
            "historyCoverage": coverage, "claims": CLAIMS, "qualification": QUALIFICATION})
        require(len(result) <= MAX_OUTPUT, "conservation tier snapshot bound")
        return result

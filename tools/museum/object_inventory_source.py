"""Finite native render-inventory reconstruction from externally pinned RPC inputs.

This reader authenticates correspondence to an admitted producer, not its Solidity
implementation or the availability of the objects it describes. Synthetic transports
exercise the identical ABI, receipt and chain checks without acquiring native provenance.
No URL, object payload or registry definition is fetched by this adapter.
"""
import re

from .canonical import MuseumError, dumps, hex_bytes, keccak256, loads, schema_id, subject_id, uint
from .chain_abi import Array, calldata, decode, encode
from .chain_rpc import MAX_TRANSCRIPT, RecordingReader, ReplayTransport, RpcTransport, quantity
from .independent_wire import ZERO, json_values, require

PROFILE = "STREAM_MUSEUM_NATIVE_RENDER_INVENTORY_SOURCE_V1"
MAX_SEGMENTS, MAX_ITEMS, MAX_SEGMENT_ITEMS = 4096, 16384, 1024
MAX_RECEIPTS, MAX_ANCESTRY, MAX_LOGS = 4096, 4096, 4096
MAX_ABI, MAX_RUNTIME, MAX_ANCHOR = 524288, 131072, 524288

# Closed source layouts, including every nested original context field. Fixed
# arrays are represented by static tuples: their Solidity ABI has no length word.
LAYOUTS = {
    "Item": "uint8 kind;bytes32 role;address source;bytes32 sourceRecord;uint256 sourceIndex;uint16 algorithm;bytes32 canonicalizationId;bytes digest;string uri;uint64 byteSize;bytes32 schemaId;bytes32 formatId;bytes32 catalogId;bytes32 catalogHash;bytes32 objectHash;bytes32 originalCoverageHash;bytes32 provenanceHash",
    "Segment": "bytes32 key;uint64 itemCount;bytes32 firstLink;bytes32 sourceWitnessHash",
    "Plan": "uint256 collectionId;bytes32 subject;bytes32 artistId;bytes32 sourceContextHash;uint64 tokenCount;uint64 nextToken;uint64 segmentCount;uint64 itemCount;bytes32 segmentChainHash;uint16 completedStages;bytes32 renderCriticalEvidenceHash",
    "OriginalInputs": "bytes32 rootRecordHash;bytes32 snapshotRecordHash;bytes32 referenceRenderRecordHash;bytes32 intentRecordHash;bytes32 intentWaiverRecordHash;bytes32 interviewEvidenceHash;bytes32 rightsStatementRecordHash;bytes32 workDescriptionRecordHash",
    "Evidence": "bytes32 planId;uint256 collectionId;bytes32 scopeSubject;bytes32 artistId;OriginalInputs originals;bytes32 sourceContextHash;bytes32 tokenInventoryHash;uint64 tokenCount;uint64 segmentCount;uint64 itemCount;bytes32 segmentChainHash;bytes32 renderCriticalEvidenceHash",
    "Dependencies": "address[12] targets;bytes32[12] codeHashes;address[5] artistTargets;bytes32[5] artistCodeHashes;address artistContentOwner;bytes32 artistContentOwnerCodeHash;uint256 chainId;uint256 readGas;uint256 sourceGas;uint256 selectionGas;uint256 snapshotGas;uint256 referenceGas",
    "SnapshotReceipt": "bytes32 recordHash;uint256 collectionId;bytes32 snapshotId;bytes32 predecessor;uint64 revision;bytes32 recordChainHash;bytes32 manifestHash;uint32 manifestBytes;bytes32 sourceHash;bytes32 inventoryPlan;address publisher;uint8 authorizationClass;uint64 grantRevision;uint8 displayAuthorizationClass;uint64 displayGrantRevision;uint64 effectiveAt;uint64 recordedAt;bytes32 reasonHash;bytes32 schemaDefinitionHash;bytes32 profileDefinitionHash;bytes32 canonicalizationDefinitionHash",
    "ReferenceReceipt": "bytes32 recordHash;bytes32 recordChainHash;uint256 collectionId;bytes32 referenceId;bytes32 predecessor;uint64 revision;bytes32 payloadHash;uint32 payloadBytes;bytes32 sourcesHash;bytes32 snapshotRecordHash;uint64 snapshotRevision;address recorder;uint8 authorizationClass;uint64 grantRevision;uint64 effectiveAt;uint64 recordedAt;bytes32 reasonHash;bytes32 schemaHash;bytes32 profileHash;bytes32 canonicalizationHash",
    "Descriptions": "bytes32 scopeSubject;bytes32 workDescriptionRecordHash;bytes32 rightsStatementRecordHash;bytes32 workPayloadHash;bytes32 rightsPayloadHash;bytes32 workSelectionHash;bytes32 rightsSelectionHash;uint64 workRevision;uint64 rightsRevision",
    "PublicationEvidence": "bytes32 attestationRecordHash;bytes32 artistId;bytes32 bindingHash;uint64 bindingGeneration;address signer;uint8 authorityClass;uint32 requiredCapability;uint64 signedAt;bytes32 publicationHash",
    "RecordEvidence": "bytes32 recordHash;uint8 kind;bytes32 payloadHash;address recorder;uint64 recordedAt;uint64 recordIndex;bytes32 recordChainHash;bytes32 receiptHash;PublicationEvidence publication;bytes32 publicationEvidenceHash",
    "Association": "bytes32 artistId;bytes32 bindingHash;uint64 generation;bytes32 identityRecordHash",
    "Selection": "RecordEvidence record;Association association;uint8 origin;uint8 interviewStatus;RecordEvidence interview;bytes32 interviewArchiveReferenceHash;uint8 interviewPayloadCorrespondence;bytes32 predecessor;address submitter;uint64 revision;uint64 selectedAt;bytes32 catalogsHash;bytes32 selectionHash",
    "Context": "uint256 collectionId;bytes32 subject;bytes32 artistId;SnapshotReceipt snapshot;ReferenceReceipt referenceRender;Descriptions descriptions;Selection conservation;bytes32 interviewEvidenceHash;bytes32 nativeHash;bytes32 rootRecordHash;bytes32 tokenInventoryHash;bytes32 checkpointHash;uint64 tokenCount",
}
FIELDS = {name: tuple(tuple(field.split()) for field in layout.split(";")) for name, layout in LAYOUTS.items()}


def abi_type(name):
    array = re.fullmatch(r"(.+)\[([0-9]+)\]", name)
    if array:
        return (abi_type(array[1]),) * int(array[2])
    if name in FIELDS:
        return tuple(abi_type(kind) for kind, _ in FIELDS[name])
    return name


def struct_object(name, values):
    return {field: struct_object(kind, value) if kind in FIELDS else json_values(value)
        for (kind, field), value in zip(FIELDS[name], values)}


ITEM, SEGMENT, EVIDENCE = (abi_type(name) for name in ("Item", "Segment", "Evidence"))
CONTEXT, DEPENDENCIES, PLAN = (abi_type(name) for name in ("Context", "Dependencies", "Plan"))
ITEM_DOMAIN = schema_id("6529STREAM_PRESERVATION_ITEM_V1")
LINK_DOMAIN = schema_id("6529STREAM_PRESERVATION_ITEM_LINK_V1")
SEGMENT_DOMAIN = schema_id("6529STREAM_PRESERVATION_SEGMENT_V1")
PLAN_DOMAIN = schema_id("6529STREAM_RENDER_CRITICAL_INVENTORY_PLAN_V1")
KEY_DOMAIN = schema_id("6529STREAM_RENDER_CRITICAL_SEGMENT_V1")
EVIDENCE_DOMAIN = schema_id("6529STREAM_RENDER_CRITICAL_EVIDENCE_V1")
FIXED_DEFINITIONS = (
    "STREAM_WORK_DESCRIPTION_V1", "STREAM_WORK_DESCRIPTION_JSON_PROFILE_V1",
    "STREAM_WORK_FORMAT_CATALOG_V1", "STREAM_WORK_FORMAT_CATALOG_JSON_PROFILE_V1",
    "STREAM_RIGHTS_V1", "STREAM_RIGHTS_JSON_PROFILE_V1",
    "STREAM_ARTIST_INTENT_V1", "STREAM_ARTIST_INTENT_JSON_PROFILE_V1",
    "STREAM_ARTIST_INTENT_WAIVER_V1", "STREAM_ARTIST_INTENT_WAIVER_JSON_PROFILE_V1",
    "STREAM_ARTIST_INTERVIEW_V1", "STREAM_ARTIST_INTERVIEW_JSON_PROFILE_V1",
    "STREAM_CONSERVATION_FORMAT_CATALOG_V1", "STREAM_CONSERVATION_FORMAT_CATALOG_JSON_PROFILE_V1",
    "STREAM_NATIVE_ONCHAIN_SNAPSHOT_V1", "STREAM_NATIVE_ONCHAIN_SNAPSHOT_JSON_PROFILE_V1",
    "STREAM_RENDERER_CLASS_DECLARATION_V1", "STREAM_RENDERER_CLASS_DECLARATION_JSON_PROFILE_V1",
    "STREAM_NATIVE_REFERENCE_RENDER_V1", "STREAM_NATIVE_REFERENCE_RENDER_JSON_PROFILE_V1",
    "STREAM_REFERENCE_NATIVE_ENVIRONMENT_V1", "STREAM_REFERENCE_PNG_OBJECT_V1",
    "STREAM_REFERENCE_RUNTIME_ZIP_OBJECT_V1", "STREAM_REFERENCE_NATIVE_FORMATS_V1",
    "RFC8785_JCS", "RAW_BYTES", "STREAM_TOKEN_CONTENT_LEAF_MANIFEST_V1",
    "STREAM_ABI_TOKEN_CONTENT_LEAF_MANIFEST_V1", "STREAM_TOKEN_CONTENT_ROOT_RECORD_V1",
    "STREAM_ABI_TOKEN_CONTENT_ROOT_RECORD_V1",
)


def abi_signature(kind):
    return "(" + ",".join(map(abi_signature, kind)) + ")" if isinstance(kind, tuple) else kind


EVENT = schema_id("InventorySegmentRecorded(bytes32,uint64," + abi_signature(SEGMENT) + "," + abi_signature(ITEM) + "[])")
CLAIMS = {"completeProducerInventoryReconstructed": True, "currentProducerReadChecked": True,
    "itemByteAvailabilityVerified": False, "itemByteCorrespondenceVerified": False,
    "archivalCoverageVerified": False, "aggregateFinalityVerified": False,
    "fullObjectDossierConformance": False, "consensusProof": False,
    "actualChainAcceptance": False, "remoteObjectFetch": False}
QUALIFICATION = ("Complete role-qualified inventory correspondence for the externally admitted finite native collection producer only. "
    "The producer's anchored requireCurrent call owns original source eligibility. This adapter reconstructs every retained segment and item; "
    "it does not independently reproduce source publication authority, registry definitions, arbitrary execution dependency closure, "
    "object bytes, archival coverage, aggregate finality or consensus. Replay origin and any trusted-RPC classification are "
    "explicit external caller admissions; transcript bytes cannot authenticate their own origin. Synthetic evidence is never actual-chain acceptance.")
PROFILE_BYTES = dumps({"name": PROFILE, "version": "1", "status": "prospective_unregistered_read_profile",
    "bounds": {"segments": str(MAX_SEGMENTS), "items": str(MAX_ITEMS), "itemsPerSegment": str(MAX_SEGMENT_ITEMS),
        "receiptHints": str(MAX_RECEIPTS), "ancestorSpan": str(MAX_ANCESTRY), "receiptLogs": str(MAX_LOGS),
        "abiBytes": str(MAX_ABI)}, "layouts": LAYOUTS, "fixedDefinitionNames": FIXED_DEFINITIONS,
    "profile": "Native COLLECTION inventory: seven initial stages, 30 fixed definitions plus renderer catalog, all retained token stages.",
    "claims": CLAIMS, "qualification": QUALIFICATION})
PROFILE_HASH = keccak256(PROFILE_BYTES)


def _hash(kinds, values):
    return keccak256(encode(kinds, values))


def item_hash(item):
    require(0 <= item[0] < 12 and item[1] != ZERO and len(item[7]) <= 128
        and len(item[8].encode("utf-8")) <= 16384, "inventory item profile bound")
    return _hash(("bytes32", ITEM), (ITEM_DOMAIN, item))


def segment_key(plan_id, index):
    return _hash(("bytes32", "bytes32", "uint64"), (KEY_DOMAIN, plan_id, index))


def reconstruct_segment(key, witness, items):
    require(key != ZERO and witness != ZERO and len(items) <= MAX_SEGMENT_ITEMS,
        "inventory segment key/witness/count")
    next_ = ZERO
    for index in reversed(range(len(items))):
        next_ = _hash(("bytes32", "bytes32", "uint64", "uint64", "bytes32", "bytes32"),
            (LINK_DOMAIN, key, len(items), index, item_hash(items[index]), next_))
    return key, len(items), next_, witness


def append_segment(previous, index, segment):
    require(segment[0] != ZERO and segment[3] != ZERO and (segment[1] == 0) == (segment[2] == ZERO),
        "inventory segment empty/link shape")
    return _hash(("bytes32", "bytes32", "uint64", SEGMENT), (SEGMENT_DOMAIN, previous, index, segment))


def _anchor(raw):
    a = loads(raw, maximum=MAX_ANCHOR, canonical=True)
    require(isinstance(a, dict) and set(a) == {"profile", "chainId", "blockHash", "blockNumber", "timestamp",
        "stateRoot", "collectionId", "producer", "dependencyHash", "codePins", "segmentTransactions"}
        and a["profile"] == PROFILE, "inventory anchor shape/profile")
    for key in ("chainId", "blockNumber", "timestamp", "collectionId"):
        uint(a[key])
    require(uint(a["chainId"]) > 0 and uint(a["collectionId"]) > 0 and uint(a["timestamp"]) < 1 << 64,
        "inventory anchor identity/time")
    for key in ("blockHash", "stateRoot", "dependencyHash"):
        require(any(hex_bytes(a[key], 32)), "inventory anchor zero commitment")
    require(any(hex_bytes(a["producer"], 20)), "inventory producer address")
    require(isinstance(a["codePins"], list) and 1 <= len(a["codePins"]) <= 19, "inventory code pin bound")
    pins = {}
    for row in a["codePins"]:
        require(isinstance(row, dict) and set(row) == {"address", "runtimeHash"}, "inventory code pin shape")
        require(any(hex_bytes(row["address"], 20)) and any(hex_bytes(row["runtimeHash"], 32))
            and row["address"] not in pins, "inventory code pin identity")
        pins[row["address"]] = row["runtimeHash"]
    require(a["producer"] in pins, "inventory producer runtime pin missing")
    hints = a["segmentTransactions"]
    require(isinstance(hints, list) and 0 < len(hints) <= MAX_RECEIPTS, "inventory transaction hint bound")
    for tx in hints:
        require(any(hex_bytes(tx, 32)), "inventory transaction hash")
    require(hints == sorted(set(hints)), "inventory transaction hints canonical/unique")
    return a, pins


class NativeInventorySource:
    """Externally anchor code/dependency identity before admission; snapshot is not a proof of consensus."""

    def __init__(self, anchor_raw, transport, *, provenance="synthetic_fixture"):
        require(provenance in ("synthetic_fixture", "trusted_rpc"), "inventory provenance")
        require(provenance != "trusted_rpc" or type(transport) in (RpcTransport, ReplayTransport),
            "synthetic transport cannot acquire native provenance")
        self.anchor_bytes = anchor_raw
        self.a, self.pins = _anchor(anchor_raw)
        self.provenance = provenance
        self.reader = RecordingReader(transport, self.a["blockHash"])
        self._started, self._snapshot = False, None

    def transcript(self):
        return self.reader.transcript()

    def _call(self, signature, output, kinds=(), values=()):
        raw = hex_bytes(self.reader.call(self.a["producer"], calldata(signature, kinds, values)))
        return decode((output,), raw, maximum=MAX_ABI)[0]

    def snapshot(self):
        if self._snapshot is not None:
            return self._snapshot
        require(not self._started, "failed inventory capture cannot resume")
        self._started = True
        try:
            self._snapshot = self._capture()
        except MuseumError:
            raise
        except (KeyError, TypeError, IndexError, ValueError, OverflowError) as exc:
            raise MuseumError("malformed native inventory evidence") from exc
        return self._snapshot

    def _capture(self):
        a = self.a; chain, cid = uint(a["chainId"]), uint(a["collectionId"])
        require(quantity(self.reader.request("eth_chainId", [])) == chain, "inventory chain differs")
        # Code is checked before invoking the externally admitted producer.
        for address, digest in sorted(self.pins.items()):
            raw = hex_bytes(self.reader.code(address))
            require(0 < len(raw) <= MAX_RUNTIME and keccak256(raw) == digest, "inventory runtime pin differs")
        current = self._call("requireCurrent(uint256)", EVIDENCE, ("uint256",), (cid,))
        plan_id = current[0]
        require(plan_id != ZERO and current[-1] != ZERO, "inventory current evidence missing")
        historical = self._call("inventoryEvidence(bytes32)", EVIDENCE, ("bytes32",), (plan_id,))
        require(historical == current, "inventory historical/current evidence differs")
        d = self._call("dependencies()", DEPENDENCIES)
        dependency_hash = self._call("dependencyHash()", "bytes32")
        require(dependency_hash == a["dependencyHash"] == _hash((DEPENDENCIES,), (d,)), "inventory dependency hash differs")
        require(d[6] == chain and d[7] >= 50000 and all(v >= d[7] for v in d[8:]),
            "inventory dependency chain/gas shape")
        expected_pins = {a["producer"]: self.pins[a["producer"]]}
        for address, digest in (*zip(d[0], d[1]), *zip(d[2], d[3]), (d[4], d[5])):
            require(any(hex_bytes(address, 20)) and digest != ZERO
                and (address not in expected_pins or expected_pins[address] == digest), "inventory conflicting dependency pin")
            expected_pins[address] = digest
        require(expected_pins == self.pins, "inventory exact dependency code pins differ")
        c = self._call("sourceContext(bytes32)", CONTEXT, ("bytes32",), (plan_id,))
        p = self._call("plan(bytes32)", PLAN, ("bytes32",), (plan_id,))
        context_hash = _hash((CONTEXT,), (c,))
        require(plan_id == _hash(("bytes32", "uint256", "address", "bytes32", CONTEXT),
            (PLAN_DOMAIN, chain, a["producer"], dependency_hash, c)), "inventory plan identity differs")
        self._context(current, c, p, cid, context_hash, d[0][0])
        without_hash = current[:-1] + (ZERO,)
        require(current[-1] == _hash(("bytes32", "uint256", "address", "bytes32", EVIDENCE),
            (EVIDENCE_DOMAIN, chain, a["producer"], dependency_hash, without_hash)), "inventory evidence hash differs")
        count = current[8]
        segments = [self._call("inventorySegment(bytes32,uint64)", SEGMENT,
            ("bytes32", "uint64"), (plan_id, index)) for index in range(count)]
        events, anchor_block = self._events(plan_id, count)
        rows, aggregate, total, tokens = [], ZERO, 0, []
        for index, segment in enumerate(segments):
            event, items, location = events[index]
            require(segment[0] == segment_key(plan_id, index) and event == segment,
                "inventory event/storage segment differs")
            require(reconstruct_segment(segment[0], segment[3], items) == segment,
                "inventory complete item chain differs")
            token = self._stage_items(index, segment, items, c, d, context_hash)
            if token is not None:
                require(token not in tokens, "inventory duplicate token occurrence")
                tokens.append(token)
            aggregate = append_segment(aggregate, index, segment); total += len(items)
            require(total <= MAX_ITEMS, "inventory aggregate item bound")
            rows.append({"index": str(index), "segment": struct_object("Segment", segment),
                "items": [struct_object("Item", item) for item in items],
                "itemHashes": [item_hash(item) for item in items], "publication": location})
        require(total == current[9] and aggregate == current[10], "inventory aggregate count/chain differs")
        require(self._call("requireCurrent(uint256)", EVIDENCE, ("uint256",), (cid,)) == current,
            "inventory current source changed during capture")
        require(self.reader.request("eth_getBlockByHash", [a["blockHash"], False]) == anchor_block,
            "inventory source anchor changed during capture")
        if type(self.reader.transport) is ReplayTransport:
            self.reader.transport.finish()
        return dumps({"profile": PROFILE, "profileHash": PROFILE_HASH, "version": "1",
            "mode": "caller_admitted_rpc_inventory" if self.provenance == "trusted_rpc" else "synthetic_fixture",
            "provenanceDeclaredByCaller": True,
            "anchorHash": keccak256(self.anchor_bytes), "transcriptHash": keccak256(self.transcript()),
            "scope": {key: a[key] for key in ("chainId", "blockHash", "blockNumber", "timestamp", "stateRoot", "collectionId", "producer")},
            "core": d[0][0], "dependencies": struct_object("Dependencies", d), "dependencyHash": dependency_hash,
            "context": struct_object("Context", c), "plan": struct_object("Plan", p),
            "evidence": struct_object("Evidence", current), "segments": rows,
            "tokens": [{"tokenId": str(token), "collectionInventoryIndex": str(i), "segmentIndex": str(38 + i)}
                for i, token in enumerate(tokens)],
            "claims": CLAIMS, "qualification": QUALIFICATION})

    def _stage_items(self, index, segment, items, c, d, context_hash):
        # These are the producer's original stage witnesses, not guessed byte locators.
        witnesses = (context_hash, c[4][6], c[5][5], c[5][6], c[6][12], c[7], c[9])
        if index < 7:
            require(segment[3] == witnesses[index], "inventory original stage witness differs")
        elif index < 38:
            require(len(items) == 1 and items[0][0] == 3 and items[0][2] == d[0][2]
                and items[0][1] == schema_id("REGISTERED_INTERPRETATION_DOCUMENT")
                and items[0][3] == items[0][12] != ZERO
                and segment[3] == _hash(("bytes32", ITEM), (items[0][3], items[0])),
                "inventory definition stage differs")
            if index < 37:
                require(items[0][3] == schema_id(FIXED_DEFINITIONS[index - 7]), "inventory fixed definition order differs")
        else:
            require(segment[3] == _hash(("bytes32", "uint64"), (c[11], index - 38))
                and len(items) == 4, "inventory token stage witness/count differs")
            token = items[0][4]
            require(token > 0, "inventory token identity missing")
            for ordinal, role in enumerate(("TOKEN_DATA", "TOKEN_METADATA_JSON", "TOKEN_IMAGE", "TOKEN_ANIMATION_HTML")):
                item = items[ordinal]
                allowed = (0, 9) if ordinal == 0 else (0, 7) if ordinal == 2 else (0,)
                require(item[0] in allowed and item[1] == schema_id(role)
                    and item[2] == d[0][0 if ordinal == 0 else 4]
                    and item[3] == c[11] and item[4] == token, "inventory token role/source differs")
            return token
        return None

    def _context(self, e, c, p, cid, context_hash, core):
        subject = subject_id("collection", self.a["chainId"], core, str(cid))
        conservation, descriptions, snapshot, reference = c[6], c[5], c[3], c[4]
        record, association = conservation[0], conservation[1]
        require(record[1] in (0, 1) and conservation[2] == 0 and conservation[3] in (0, 1)
            and conservation[6] in (0, 1, 2), "inventory conservation profile differs")
        originals = (c[9], snapshot[0], reference[0], record[0] if record[1] == 0 else ZERO,
            record[0] if record[1] == 1 else ZERO, c[7], descriptions[2], descriptions[1])
        require(all(value != ZERO for i, value in enumerate(originals) if i not in (3, 4))
            and record[0] != ZERO, "inventory eight original inputs missing")
        require(c[0] == e[1] == p[0] == cid and c[1] == e[2] == p[1] == subject
            and c[2] == e[3] == p[2] == association[0] != ZERO
            and descriptions[0] == subject and snapshot[1] == reference[2] == cid
            and reference[9] == snapshot[0] and reference[10] == snapshot[4],
            "inventory original scope/association differs")
        require(e[4] == originals and e[5] == p[3] == context_hash
            and e[6] == c[10] != ZERO and c[11] != ZERO and c[8] != ZERO,
            "inventory original/context/token commitments differ")
        require(0 < c[12] == e[7] == p[4] == p[5] <= MAX_SEGMENTS - 38
            and e[8] == p[6] == 38 + c[12] and e[8] <= MAX_SEGMENTS
            and 0 < e[9] == p[7] <= MAX_ITEMS and e[10] == p[8] != ZERO
            and p[9] == 8 and p[10] == e[11], "inventory completed plan/counts differ")

    def _events(self, plan_id, count):
        a = self.a; receipts = {}
        for tx in a["segmentTransactions"]:
            r = self.reader.request("eth_getTransactionReceipt", [tx])
            require(isinstance(r, dict) and r.get("transactionHash") == tx and r.get("status") == "0x1",
                "inventory successful segment receipt required")
            require(any(hex_bytes(r["blockHash"], 32)), "inventory receipt block missing")
            quantity(r["blockNumber"]); quantity(r["transactionIndex"])
            require(isinstance(r.get("logs"), list) and len(r["logs"]) <= MAX_LOGS, "inventory receipt log bound")
            receipts[tx] = r
        oldest = min(quantity(r["blockNumber"]) for r in receipts.values()); tip = uint(a["blockNumber"])
        require(0 <= tip - oldest <= MAX_ANCESTRY, "inventory receipt ancestry bound")
        blocks, expected = {}, a["blockHash"]
        for number in range(tip, oldest - 1, -1):
            block = self.reader.request("eth_getBlockByHash", [expected, False])
            require(isinstance(block, dict) and block.get("hash") == expected and quantity(block["number"]) == number,
                "inventory anchor ancestry differs")
            stamp = quantity(block["timestamp"])
            if number == tip:
                require(block.get("stateRoot") == a["stateRoot"] and stamp == uint(a["timestamp"]), "inventory block anchor differs")
            else:
                require(stamp <= quantity(blocks[number + 1]["timestamp"]), "inventory ancestry time differs")
            hex_bytes(block["parentHash"], 32)
            txs = block.get("transactions")
            require(isinstance(txs, list) and len(txs) <= 8192, "inventory block transaction bound")
            for tx in txs:
                require(any(hex_bytes(tx, 32)), "inventory block transaction identity")
            require(len(txs) == len(set(txs)), "inventory duplicate block transaction")
            blocks[number] = block; expected = block["parentHash"]
        events, positions, log_ranges = {}, set(), []
        for tx, receipt in receipts.items():
            number, position = quantity(receipt["blockNumber"]), quantity(receipt["transactionIndex"])
            require(number in blocks, "inventory receipt postdates anchor")
            block = blocks[number]
            require(receipt["blockHash"] == block["hash"] and position < len(block["transactions"])
                and block["transactions"][position] == tx, "inventory receipt transaction membership differs")
            used, last = False, -1
            for log in receipt["logs"]:
                require(isinstance(log, dict) and log.get("removed") is False, "inventory removed/malformed event")
                index = quantity(log["logIndex"])
                require(index > last and (number, index) not in positions, "inventory duplicate/unordered log")
                require(all(log.get(key) == receipt[key] for key in ("transactionHash", "transactionIndex", "blockHash", "blockNumber")),
                    "inventory event receipt coordinates differ")
                last = index; positions.add((number, index))
                topics = log.get("topics")
                require(isinstance(topics, list) and len(topics) <= 4, "inventory event topics")
                if log.get("address") != a["producer"] or not topics or topics[0] != EVENT:
                    continue
                require(len(topics) == 3, "inventory segment event signature shape")
                if topics[1] != plan_id:
                    continue
                segment_index, = decode(("uint64",), hex_bytes(topics[2], 32))
                require(segment_index < count and segment_index not in events, "inventory missing/duplicate segment index")
                segment, items = decode((SEGMENT, Array(ITEM, MAX_SEGMENT_ITEMS)), hex_bytes(log["data"]), maximum=MAX_ABI)
                location = {"transactionHash": tx, "blockHash": block["hash"], "blockNumber": str(number),
                    "transactionIndex": str(position), "logIndex": str(index)}
                events[segment_index] = (segment, items, location); used = True
            require(used, "inventory unused transaction hint")
            log_ranges.append((number, position, quantity(receipt["logs"][0]["logIndex"]), last))
        log_ranges.sort()
        for before, after in zip(log_ranges, log_ranges[1:]):
            require(before[0] != after[0] or (before[1] < after[1] and before[3] < after[2]),
                "inventory cross-transaction log order differs")
        require(set(events) == set(range(count)), "inventory incomplete segment event inventory")
        order = [(uint(events[i][2]["blockNumber"]), uint(events[i][2]["transactionIndex"]),
            uint(events[i][2]["logIndex"])) for i in range(count)]
        require(order == sorted(order) and len(order) == len(set(order)), "inventory segment publication order differs")
        return events, blocks[tip]


def definitions(directory, *, check=False):
    """Write/check the prospective interpretation profile; this does not register it."""
    from pathlib import Path
    path = Path(directory) / "native-inventory-profile.json"
    if check:
        require(path.is_file() and path.read_bytes() == PROFILE_BYTES, "native inventory profile differs")
    else:
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes(PROFILE_BYTES)
    return PROFILE_HASH


def _bounded_read(path, maximum):
    with path.open("rb") as stream:
        raw = stream.read(maximum + 1)
    require(len(raw) <= maximum, "native inventory input file bound")
    return raw


def replay(anchor_path, anchor_hash, transcript_path, transcript_hash, output, *, provenance="synthetic_fixture"):
    """Replay externally pinned inputs into a new directory; no network client is created."""
    from pathlib import Path
    from .bagit import MAX_BYTES, write_tree
    anchor_raw = _bounded_read(Path(anchor_path), MAX_ANCHOR)
    transcript_raw = _bounded_read(Path(transcript_path), MAX_TRANSCRIPT)
    require(keccak256(anchor_raw) == anchor_hash, "native inventory external anchor pin differs")
    source = NativeInventorySource(anchor_raw, ReplayTransport(transcript_raw, transcript_hash), provenance=provenance)
    snapshot = source.snapshot()
    require(source.transcript() == transcript_raw, "native inventory replay transcript differs")
    pins = {"profileHash": PROFILE_HASH, "anchorHash": anchor_hash, "transcriptHash": transcript_hash,
        "snapshotHash": keccak256(snapshot), "provenance": provenance, "actualChainAcceptance": False}
    files = {"anchor.json": anchor_raw, "transcript.json": transcript_raw,
        "snapshot.json": snapshot, "pins.json": dumps(pins)}
    require(sum(map(len, files.values())) <= MAX_BYTES, "native inventory replay output aggregate bound")
    write_tree(files, output)
    return pins


def main():
    import argparse
    from pathlib import Path
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest="command", required=True)
    definition = sub.add_parser("definitions"); definition.add_argument("--output", required=True, type=Path)
    definition.add_argument("--check", action="store_true")
    capture = sub.add_parser("replay", help="offline replay; provenance is external caller admission, never inferred")
    for name in ("anchor", "transcript"):
        capture.add_argument("--" + name, required=True, type=Path)
        capture.add_argument("--" + name + "-hash", required=True)
    capture.add_argument("--provenance", choices=("synthetic_fixture", "trusted_rpc"), default="synthetic_fixture")
    capture.add_argument("--output", required=True, type=Path)
    args = parser.parse_args()
    if args.command == "definitions":
        print(definitions(args.output, check=args.check))
    else:
        print(dumps(replay(args.anchor, args.anchor_hash, args.transcript, args.transcript_hash,
            args.output, provenance=args.provenance)).decode("utf-8"))


if __name__ == "__main__":
    main()

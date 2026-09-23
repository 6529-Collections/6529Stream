"""Canonical retained condition-source denominator and receipt-ordered selection.

Provider completeness and canonical mappings remain explicit trust assumptions.
The selected original is retained even when its condition meaning is unsupported.
"""
from jsonschema.exceptions import ValidationError

from .account_profile import JCS_BYTES
from .canonical import MuseumError, dumps, hex_bytes, keccak256, loads, record_chain, schema_id, subject_id, uint
from .chain_abi import calldata, decode, encode
from .condition import NAME, SCHEMA_BYTES, admit_document, _source_subject
from .independent_source import IndependentSourceAdapter
from .independent_wire import (RECORD, RECEIPT as INDEPENDENT_RECEIPT, SUBJECT, RAW_BYTES,
    ZERO, ZERO_ADDRESS, json_values, require, verify_record)
from .owner_catalog_source import (OWNER_RECORD, RECEIPT as OWNER_RECEIPT,
    RECORD_EVENT as OWNER_EVENT, verify_native_wire, _position, _location)
from .public_chain_history import scan_public_history, PROFILE_HASH as HISTORY_PROFILE_HASH
from .public_history_rpc import PublicRecordingReader, PublicReplayTransport, PublicRpcTransport, quantity

PROFILE = "STREAM_MUSEUM_PUBLIC_CONDITION_SOURCE_V1"
SOURCE_REVISION = "f7a05e0734b95f1e2ff1a038b73511c0d94b6f81"
CORE_REVISION = "758572df4e7f3969f549dd58aef0c369202e2b27"
MAX_ANCHOR, MAX_ABI, MAX_OUTPUT = 524288, 32768, 33554432
MAX_SOURCES, MAX_RECORDS, MAX_PINS = 24, 4096, 256
SOURCE = ("address", "bytes32", "uint8", "uint64", "uint64", "bytes32")
ACTION = ("uint8", "uint8", "address", "uint256", "bytes4", "bytes32", "bytes32", "bytes32",
    "bytes32", "uint64", "uint64", "address", "address", "address", "address", "bytes32", "string", "bytes32")
EXECUTED_DATA = ("uint16", "uint256", "bytes4", "bytes32", "bytes32", "bytes32", "bytes32", "address", "bytes32")
DOMAIN = schema_id("6529STREAM_CONDITION_SOURCE_SET_V1")
ADDED_EVENT = schema_id("ConditionSourceAdded(uint64,address,uint8,bytes32,uint64,bytes32,bytes32,bytes32,uint16)")
BOUND_EVENT = schema_id("ConditionSourcesBound(uint16,address,bytes32,bytes32)")
EXECUTED_EVENT = schema_id("GovernanceActionExecuted(uint16,bytes32,uint8,address,uint256,bytes4,bytes32,bytes32,bytes32,bytes32,address,bytes32)")
INDEPENDENT_EVENT = schema_id("IndependentPreservationRecordRecorded(uint256,bytes32,bytes32,(bytes32,bytes32,(uint16,bytes,bytes32),string,bytes32,bytes32,(uint16,bytes,bytes32),uint64),bytes32,bytes32,address,bytes32,uint16)")
OWNER_TYPE, INDEPENDENT_TYPE = schema_id("CONDITION_REPORT"), schema_id("INDEPENDENT_CONDITION")
QUALIFICATION = ("Complete canonical catalog and retained owner-token/independent-collection lanes at one pinned block, "
    "within explicit read bounds. Latest uses successful original receipt block/transaction/log order. "
    "Uninterpretable newest originals remain selected and unresolved. None-recorded covers only this bound catalog. "
    "RPC completeness and canonical mappings are trusted; no consensus proof, actual-chain acceptance, current ownership, "
    "examiner independence, examination protocol joins or complete acquisition packet is established.")
CLAIMS = {"canonicalSourceSetComplete": True, "retainedReplacementHistory": True,
    "completeRelevantLanes": True, "receiptOrderedLatest": True, "unsupportedNewestRetained": True,
    "canonicalScopedAbsence": True, "providerLogCompletenessTrusted": True,
    "actualChainAcceptance": False, "consensusProof": False, "currentOwnerProven": False,
    "examinerIndependenceProven": False, "examinationProtocolJoinsProven": False,
    "completeAcquisitionPacket": False}
PROFILE_BYTES = dumps({"name": PROFILE, "version": "1", "sourceReviewCommit": SOURCE_REVISION,
    "coreSourceReviewCommit": CORE_REVISION, "historyProfileHash": HISTORY_PROFILE_HASH,
    "bounds": {"sources": str(MAX_SOURCES), "records": str(MAX_RECORDS), "codePins": str(MAX_PINS)},
    "denominator": "Permanent Core binding; every catalog ID and replacement predecessor, including all preadmission records.",
    "selection": "Greatest authenticated (blockNumber,transactionIndex,logIndex) per owner/independent lane across all matching originals.",
    "interpretation": "Only selected original exact schema/canonicalization; unsupported, empty or invalid payload retains selected-unresolved, never older fallback.",
    "governance": "Original native acceptance plus exact stored executed action and successful receipt event; no full per-call batch witness or historical root-scope rederivation is claimed.",
    "claims": CLAIMS, "qualification": QUALIFICATION})
PROFILE_HASH = keccak256(PROFILE_BYTES)


def empty_head(a):
    return keccak256(encode(("bytes32", "uint256", "address", "address"),
        (DOMAIN, uint(a["chainId"]), a["core"], a["conditionSources"])))


def next_head(previous, source_id, row):
    return keccak256(encode(("bytes32", "bytes32", "uint64", "address", "bytes32", "uint8", "uint64"),
        (DOMAIN, previous, source_id, row[0], row[1], row[2], row[3])))


def _topic(kind, value):
    return "0x" + encode((kind,), (value,)).hex()


class _Documents(IndependentSourceAdapter):
    """Reuse immutable original document/chunk checks with one shared recorder."""
    def __init__(self, reader, schemas, store):
        self.a, self.reader = {"schemas": schemas, "store": store}, reader
        self.documents, self.chunks, self.document_stack, self.document_bytes = {}, {}, set(), 0


class PublicConditionSource:
    def __init__(self, anchor_bytes, transport, *, provenance="synthetic_fixture"):
        require(provenance in ("synthetic_fixture", "trusted_rpc") and
            (provenance != "trusted_rpc" or type(transport) in (PublicRpcTransport, PublicReplayTransport)),
            "condition source provenance")
        a = loads(anchor_bytes, maximum=MAX_ANCHOR, canonical=True)
        require(type(a) is dict and set(a) == {"profile", "chainId", "blockHash", "blockNumber", "timestamp",
            "stateRoot", "environment", "deploymentEvidenceHash", "core", "conditionSources", "executor",
            "tokenId", "collectionId", "codePins"} and a["profile"] == PROFILE
            and a["environment"] in ("local_evm_fixture", "public_chain"), "condition anchor shape/profile")
        for key in ("chainId", "tokenId", "collectionId"):
            require(uint(a[key]) > 0, "condition anchor nonzero identity")
        uint(a["blockNumber"]); uint(a["timestamp"], 64)
        for key in ("blockHash", "stateRoot", "deploymentEvidenceHash"):
            require(any(hex_bytes(a[key], 32)), "condition anchor commitment")
        for key in ("core", "conditionSources", "executor"):
            require(any(hex_bytes(a[key], 20)), "condition anchor address")
        require(len({a[k] for k in ("core", "conditionSources", "executor")}) == 3, "condition anchor distinct hosts")
        require(type(a["codePins"]) is list and 3 <= len(a["codePins"]) <= MAX_PINS, "condition pin bound")
        pins = {}
        for p in a["codePins"]:
            require(type(p) is dict and set(p) == {"address", "runtimeHash"}, "condition pin shape")
            require(any(hex_bytes(p["address"], 20)) and any(hex_bytes(p["runtimeHash"], 32))
                and p["address"] not in pins, "condition duplicate/empty pin")
            pins[p["address"]] = p["runtimeHash"]
        require(all(a[k] in pins for k in ("core", "conditionSources", "executor")), "condition missing dependency pin")
        self.a, self.pins, self.anchor_bytes, self.provenance = a, pins, anchor_bytes, provenance
        self.reader = PublicRecordingReader(transport, a["blockHash"])
        self._started, self._snapshot, self._documents = False, None, {}

    def transcript(self): return self.reader.transcript()

    def _read(self, target, signature, outputs=(), kinds=(), values=()):
        return decode(outputs, hex_bytes(self.reader.call(target, calldata(signature, kinds, values))), maximum=MAX_ABI)

    def _interface(self, host, interface):
        for expected, value in ((interface, True), ("0x01ffc9a7", True), ("0xffffffff", False)):
            require(self._read(host, "supportsInterface(bytes4)", ("bool",), ("bytes4",), (expected,)) == (value,),
                "condition source interface differs")

    def snapshot(self):
        if self._snapshot is not None: return self._snapshot
        require(not self._started, "failed condition source cannot resume")
        self._started = True
        try: self._snapshot = self._capture()
        except MuseumError: raise
        except (KeyError, TypeError, IndexError, ValueError, OverflowError, ValidationError) as exc:
            raise MuseumError("malformed condition source evidence") from exc
        return self._snapshot

    def _bindings(self):
        a = self.a; catalog = a["conditionSources"]
        require(quantity(self.reader.request("eth_chainId", [])) == uint(a["chainId"]), "condition chain differs")
        for address, digest in sorted(self.pins.items()):
            code = hex_bytes(self.reader.code(address))
            require(0 < len(code) <= 24576 and keccak256(code) == digest, "condition runtime pin differs")
        self._interface(a["core"], "0x02d968bb"); self._interface(catalog, "0xa621c1b7")
        require(self._read(a["core"], "conditionSources()", ("address", "bytes32")) == (catalog, self.pins[catalog]),
            "condition permanent Core binding unavailable/differs")
        for getter, kind, expected in (("core", "address", a["core"]), ("coreCodeHash", "bytes32", self.pins[a["core"]]),
            ("governanceAuthority", "address", a["executor"]), ("executorCodeHash", "bytes32", self.pins[a["executor"]]),
            ("deploymentChainId", "uint256", uint(a["chainId"]))):
            require(self._read(catalog, getter + "()", (kind,)) == (expected,), "condition catalog dependency differs")
        identity = self._read(a["core"], "tokenCollectionIdentity(uint256)", ("bool", "uint256", "uint256", "bool"),
            ("uint256",), (uint(a["tokenId"]),))
        require(identity[0] and identity[1] == uint(a["collectionId"]) and identity[2] > 0,
            "condition token collection identity differs")
        return identity

    def _catalogue(self):
        host = self.a["conditionSources"]
        count, head = self._read(host, "sourceSetHead()", ("uint64", "bytes32"))
        require(count <= MAX_SOURCES and self._read(host, "sourceCount()", ("uint64",)) == (count,), "condition complete source bound/count")
        previous, sources, pairs = empty_head(self.a), [], set()
        require(self._read(host, "sourceSetHashAt(uint64)", ("bytes32",), ("uint64",), (0,)) == (previous,), "condition empty source head differs")
        for source_id in range(1, count + 1):
            row, = self._read(host, "sourceAt(uint64)", (SOURCE,), ("uint64",), (source_id,))
            address, code_hash, lane, predecessor, admitted, action = row
            require(address in self.pins and code_hash == self.pins[address] and lane in (0, 1)
                and (address, lane) not in pairs and 0 <= predecessor < source_id and 0 < admitted <= uint(self.a["timestamp"])
                and action != ZERO, "condition source member differs")
            require(predecessor == 0 or sources[predecessor - 1]["lane"] == ("OWNER", "INDEPENDENT")[lane],
                "condition replacement lane differs")
            pairs.add((address, lane))
            next_value = next_head(previous, source_id, row)
            require(self._read(host, "sourceId(address,uint8)", ("uint64",), ("address", "uint8"), (address, lane)) == (source_id,)
                and self._read(host, "sourceSetHashAt(uint64)", ("bytes32",), ("uint64",), (source_id,)) == (next_value,),
                "condition source identity/head differs")
            sources.append({"sourceId": str(source_id), "host": address, "runtimeHash": code_hash,
                "lane": ("OWNER", "INDEPENDENT")[lane], "replacesSourceId": str(predecessor), "admittedAt": str(admitted),
                "actionId": action, "previousHead": previous, "head": next_value})
            previous = next_value
        require(previous == head, "condition source catalog final head differs")
        self._read(host, "requireSourceSet(uint64,bytes32)", (), ("uint64", "bytes32"), (count, head))
        return {"count": str(count), "head": head, "sources": sources}

    def _host(self, source):
        host, owner = source["host"], source["lane"] == "OWNER"
        # Concrete original module versions are part of this read profile.
        self._interface(host, "0x34ee6097" if owner else "0x771b2917")
        deps = {}
        for getter in ("core", "schemaRegistry", "chunkStore"):
            address, = self._read(host, getter + "()", ("address",))
            require(address in self.pins and self._read(host, getter + "CodeHash()", ("bytes32",)) == (self.pins[address],),
                "condition record dependency pin differs")
            deps[getter] = address
        require(deps["core"] == self.a["core"] and self._read(deps["schemaRegistry"], "chunkStore()", ("address",)) == (deps["chunkStore"],),
            "condition original host graph differs")
        expected = ("OWNER_RECORDS", "6529stream.owner-records.v1") if owner else ("COLLECTION_ATTESTATIONS", "6529stream.collection-attestations.independent.v1")
        for getter, value in zip(("streamModuleType", "streamModuleVersion"), expected):
            require(self._read(host, getter + "()", ("bytes32",)) == (schema_id(value),), "condition original module version differs")
        require(self._read(host, "isOwnerRecordType(bytes32)" if owner else "isIndependentRecordType(bytes32)",
            ("bool",), ("bytes32",), (OWNER_TYPE if owner else INDEPENDENT_TYPE,)) == (True,), "condition native family unavailable")
        if owner:
            expected_subject = subject_id("token", self.a["chainId"], self.a["core"], "0", token_id=self.a["tokenId"])
            require(self._read(host, "deriveOwnerSubject(uint256)", ("bytes32",), ("uint256",),
                (uint(self.a["tokenId"]),)) == (expected_subject,), "condition owner subject differs")
        key = (deps["schemaRegistry"], deps["chunkStore"])
        if key not in self._documents: self._documents[key] = _Documents(self.reader, *key)
        return deps, self._documents[key]

    def _lane(self, source, history, records):
        a = self.a; host = source["host"]; owner = source["lane"] == "OWNER"
        deps, documents = self._host(source)
        scope, family = uint(a["tokenId"] if owner else a["collectionId"]), OWNER_TYPE if owner else INDEPENDENT_TYPE
        head, count = self._read(host, "recordChainHash(uint256,bytes32)", ("bytes32", "uint64"), ("uint256", "bytes32"), (scope, family))
        require(count <= MAX_RECORDS - len(records), "condition complete lane record bound")
        events = {}
        for log in history["logs"]:
            if log["address"] != host or log["topics"][0] != (OWNER_EVENT if owner else INDEPENDENT_EVENT): continue
            require(len(log["topics"]) == 4 and log["topics"][1:3] == [_topic("uint256", scope), family], "condition publication topics differ")
            event = decode((OWNER_RECORD, "bytes32", "bytes32", "bool", "uint16") if owner else
                (RECORD, "bytes32", "bytes32", "address", "bytes32", "uint16"), hex_bytes(log["data"]), maximum=MAX_ABI)
            require(event[-1] == 1 and event[1] not in events, "condition publication duplicate/version")
            events[event[1]] = (event, log)
        previous, hashes, positions, latest, nonces = ZERO, [], [], {}, set()
        for index in range(count):
            digest, = self._read(host, "recordHashAt(uint256,bytes32,uint256)", ("bytes32",),
                ("uint256", "bytes32", "uint256"), (scope, family, index))
            require(digest != ZERO and digest in events and digest not in hashes, "condition missing/duplicate original")
            event, log = events[digest]
            if owner:
                record, receipt = self._read(host, "ownerRecord(bytes32)", (OWNER_RECORD, OWNER_RECEIPT), ("bytes32",), (digest,))
                pointer, bundle = self._read(host, "ownerRecordSignatureBundle(bytes32)", ("address", "bytes"), ("bytes32",), (digest,))
                verify_native_wire(uint(a["chainId"]), host, a["core"], uint(a["timestamp"]), digest, scope, record, receipt, bundle)
                require(pointer != ZERO_ADDRESS and hex_bytes(self.reader.code(pointer)) == b"\x00" + bundle, "condition owner signature storage differs")
                require(record[0] == family and receipt[3] == index and record_chain(a["chainId"], host, str(scope), family, previous, digest, str(index)) == receipt[4], "condition owner lane chain differs")
                require(event[:4] == (record, digest, receipt[4], receipt[5])
                    and log["topics"][3] == _topic("address", receipt[1]), "condition owner publication differs")
                payload, schema, canonical, schema_hash, canonical_hash = record[5], record[2], record[3][2], receipt[9], receipt[10]
                recorded, chain_hash, subject, matches = receipt[2], receipt[4], None, True
                if receipt[5]:
                    nonce = (receipt[1], receipt[7]); require(nonce not in nonces, "condition owner repeated nonce")
                    nonces.add(nonce)
                    require(self._read(host, "isOwnerRecordNonceUsed(address,uint256)", ("bool",), ("address", "uint256"), nonce) == (True,), "condition owner consumed nonce missing")
                author_key = (receipt[1],)
            else:
                raw = hex_bytes(self.reader.call(host, calldata("collectionRecord(bytes32)", ("bytes32",), (digest,))))
                subject_raw = hex_bytes(self.reader.call(host, calldata("recordSubject(bytes32)", ("bytes32",), (digest,))))
                payloads = []
                for getter in ("recordPayload(bytes32)", "recordSignatureBundle(bytes32)"):
                    pointer, value = self._read(host, getter, ("address", "bytes"), ("bytes32",), (digest,))
                    require(0 < len(value) <= 8192 and documents._chunk(keccak256(value), pointer) == value, "condition independent stored bytes differ")
                    payloads.append(value)
                payload, bundle = payloads
                record, receipt, subject = verify_record(uint(a["chainId"]), host, a["core"], uint(a["timestamp"]),
                    (scope, family), index, previous, digest, raw, subject_raw, payload, bundle)
                require(event[:5] == (record, digest, receipt[5], receipt[1], _topic("uint256", 5))
                    and log["topics"][3] == record[1], "condition independent publication differs")
                nonce = (receipt[1], receipt[7]); require(nonce not in nonces, "condition independent repeated nonce")
                nonces.add(nonce)
                require(self._read(host, "isIndependentAttestorNonceUsed(address,uint256)", ("bool",), ("address", "uint256"), nonce) == (True,), "condition independent consumed nonce missing")
                schema, canonical, schema_hash, canonical_hash = record[4], record[2][2], receipt[9], receipt[10]
                recorded, chain_hash = receipt[3], receipt[5]
                matches = subject == (1, uint(a["collectionId"]), uint(a["tokenId"]), ZERO)
                author_key = (record[1], receipt[1])
            require(recorded == uint(history["blockTimestamps"][str(quantity(log["blockNumber"]))]), "condition original publication timestamp differs")
            documents._document(schema, 0, schema_hash); documents._document(canonical, 1, canonical_hash)
            saved = {"sourceId": source["sourceId"], "host": host, "lane": source["lane"], "recordHash": digest,
                "record": json_values(record), "receipt": json_values(receipt), "subject": json_values(subject),
                "payloadHex": "0x" + payload.hex(), "signatureBundleHex": "0x" + bundle.hex(),
                "schemaRegistry": deps["schemaRegistry"], "chunkStore": deps["chunkStore"], "matchesToken": matches,
                "publication": _location(log), "authority": {"mode": "historical_native_owner_receipt" if owner else "historical_native_independent_receipt",
                    "account": receipt[1], "currentSignatureRevalidation": False}}
            records.append(saved); hashes.append(digest); positions.append(_position(log)); latest[author_key] = digest
            previous = chain_hash
        require(set(hashes) == set(events) and previous == head and positions == sorted(set(positions)), "condition complete lane events/head/order differ")
        for key, digest in sorted(latest.items()):
            signature = "latestOwnerRecordHashFor(uint256,bytes32,address)" if owner else "latestCollectionRecordHashFor(uint256,bytes32,bytes32,address)"
            kinds = ("uint256", "bytes32", "address") if owner else ("uint256", "bytes32", "bytes32", "address")
            require(self._read(host, signature, ("bytes32",), kinds, (scope, family, *key)) == (digest,), "condition per-author latest differs")
        require(self._read(host, "recordChainHash(uint256,bytes32)", ("bytes32", "uint64"), ("uint256", "bytes32"), (scope, family)) == (head, count), "condition final lane changed")
        return {"sourceId": source["sourceId"], "host": host, "lane": source["lane"], "scopeKey": str(scope),
            "recordType": family, "count": str(count), "head": head, "records": hashes}

    def _selection(self, lane, records):
        matches = [r for r in records if r["lane"] == lane and r["matchesToken"]]
        if not matches: return {"status": "none_recorded", "selected": None, "interpretation": None}
        saved = max(matches, key=lambda r: tuple(uint(r["publication"][k]) for k in ("blockNumber", "transactionIndex", "logIndex")))
        owner = lane == "OWNER"; record, receipt = saved["record"], saved["receipt"]
        schema, canonical = (record[2], record[3][2]) if owner else (record[4], record[2][2])
        documents = self._documents[(saved["schemaRegistry"], saved["chunkStore"])].documents
        registered, payload = documents[schema][1], hex_bytes(saved["payloadHex"])
        interpretation = {"value": None, "reasonCode": "original_payload_empty", "payloadHash": keccak256(payload)}
        if payload:
            if registered != SCHEMA_BYTES:
                interpretation = admit_document(payload, registered)
            elif owner and record[3][0] not in ("1", "2"):
                interpretation["reasonCode"] = "original_content_algorithm_unsupported"
            elif schema != schema_id(NAME) or canonical != schema_id("RFC8785_JCS") or documents[schema][2][3][3] != canonical or documents[canonical][1] != JCS_BYTES or documents[canonical][2][3][3] != RAW_BYTES:
                interpretation["reasonCode"] = "original_canonicalization_unsupported"
            else:
                try:
                    interpretation = admit_document(payload, registered)
                    _source_subject(interpretation, self.a, record[1], self.a["tokenId"])
                except (MuseumError, ValueError, TypeError, KeyError, ValidationError):
                    interpretation = {"value": None, "reasonCode": "original_condition_payload_invalid", "payloadHash": keccak256(payload)}
        selected = {key: saved[key] for key in ("sourceId", "host", "recordHash", "lane", "publication")}
        selected.update(schemaId=schema, schemaHash=receipt[9], canonicalizationId=canonical,
            canonicalizationHash=receipt[10], subjectId=record[1])
        return {"status": "present" if interpretation["value"] is not None else "selected_unresolved",
            "selected": selected, "interpretation": interpretation}

    def _capture(self):
        a = self.a; identity = self._bindings(); catalogue = self._catalogue()
        filters = [{"address": a["core"], "topics": [BOUND_EVENT]},
            {"address": a["conditionSources"], "topics": [ADDED_EVENT]}]
        for source in catalogue["sources"]:
            owner = source["lane"] == "OWNER"
            filters.append({"address": source["host"], "topics": [OWNER_EVENT if owner else INDEPENDENT_EVENT,
                _topic("uint256", uint(a["tokenId"] if owner else a["collectionId"])), OWNER_TYPE if owner else INDEPENDENT_TYPE]})
        history = scan_public_history(self.reader, a, filters=filters)
        binding = self._admissions(catalogue, history)
        records = []; lanes = [self._lane(source, history, records) for source in catalogue["sources"]]
        positions = [(r["publication"]["blockHash"], r["publication"]["logIndex"]) for r in records]
        require(len(set(positions)) == len(positions), "condition conflicting original receipt position")
        selections = {"owner": self._selection("OWNER", records), "independent": self._selection("INDEPENDENT", records)}
        count, head = uint(catalogue["count"]), catalogue["head"]
        require(self._read(a["conditionSources"], "sourceSetHead()", ("uint64", "bytes32")) == (count, head)
            and self._read(a["conditionSources"], "sourceCount()", ("uint64",)) == (count,), "condition final catalog changed")
        self._read(a["conditionSources"], "requireSourceSet(uint64,bytes32)", (), ("uint64", "bytes32"), (count, head))
        require(self._read(a["core"], "conditionSources()", ("address", "bytes32")) == (a["conditionSources"], self.pins[a["conditionSources"]]), "condition final Core binding changed")
        source_header = next(row["result"] for row in self.reader.rows if row["method"] == "eth_getBlockByHash" and row["params"] == [a["blockHash"], False])
        require(self.reader.request("eth_getBlockByHash", [a["blockHash"], False]) == source_header and
            self.reader.request("eth_getBlockByNumber", [hex(uint(a["blockNumber"])), False]) == source_header, "condition final anchor changed")
        if type(self.reader.transport) is PublicReplayTransport: self.reader.transport.finish()
        documents = [{"schemaRegistry": key[0], "chunkStore": key[1], "documentId": digest,
            "view": json_values(view), "payloadHex": "0x" + raw.hex()}
            for key, helper in sorted(self._documents.items()) for digest, (_, raw, view) in sorted(helper.documents.items())]
        result = dumps({"profile": PROFILE, "profileHash": PROFILE_HASH, "version": "1", "sourceReviewCommit": SOURCE_REVISION,
            "coreSourceReviewCommit": CORE_REVISION, "mode": "caller_admitted_rpc_condition_source" if self.provenance == "trusted_rpc" else "synthetic_fixture",
            "anchorHash": keccak256(self.anchor_bytes), "transcriptHash": keccak256(self.transcript()),
            "sourceState": {k: a[k] for k in ("chainId", "core", "tokenId", "collectionId", "blockHash", "blockNumber", "timestamp", "environment")},
            "identity": json_values(identity), "binding": binding, "catalogue": catalogue, "lanes": lanes, "records": records,
            "documents": documents, "selections": selections, "historyCoverage": history["coverage"], "claims": CLAIMS, "qualification": QUALIFICATION})
        require(len(result) <= MAX_OUTPUT, "condition snapshot bound")
        return result

    def _admissions(self, catalogue, history):
        """Join permanent binding/membership to original successful governance receipts."""
        a = self.a
        bindings = [log for log in history["logs"] if log["address"] == a["core"] and log["topics"][0] == BOUND_EVENT]
        require(len(bindings) == 1, "condition exact permanent binding event required")
        bound = bindings[0]
        require(len(bound["topics"]) == 3 and bound["topics"][1] == _topic("address", a["conditionSources"])
            and bound["topics"][2] != ZERO and decode(("uint16", "bytes32"), hex_bytes(bound["data"])) == (1, self.pins[a["conditionSources"]]),
            "condition original Core binding event differs")
        additions = [log for log in history["logs"] if log["address"] == a["conditionSources"] and log["topics"][0] == ADDED_EVENT]
        require(len(additions) == len(catalogue["sources"]), "condition complete admission event count differs")
        by_id = {}
        for log in additions:
            require(len(log["topics"]) == 4, "condition admission topic shape")
            source_id, = decode(("uint64",), hex_bytes(log["topics"][1]))
            require(source_id not in by_id, "condition duplicate admission")
            by_id[source_id] = log
        action_evidence, action_transactions = {}, {}
        def action(log, action_id):
            require(action_id not in action_transactions or action_transactions[action_id] == log["transactionHash"],
                "condition governance action reused across transactions")
            action_transactions[action_id] = log["transactionHash"]
            key = (action_id, log["transactionHash"])
            if key in action_evidence:
                require(tuple(uint(action_evidence[key]["execution"][k]) for k in ("blockNumber", "transactionIndex", "logIndex")) > _position(log),
                    "condition shared governance execution order differs")
                return action_evidence[key]
            receipt = self.reader.request("eth_getTransactionReceipt", [log["transactionHash"]])
            events = [r for r in receipt["logs"] if r["address"] == a["executor"] and r["topics"] and r["topics"][0] == EXECUTED_EVENT and len(r["topics"]) > 1 and r["topics"][1] == action_id]
            require(len(events) == 1, "condition original governance execution receipt required")
            event = events[0]; require(len(event["topics"]) == 4 and event["topics"][2] == _topic("uint8", 1)
                and _position(event) > _position(log), "condition governance execution class/order differs")
            stored, = self._read(a["executor"], "governanceAction(bytes32)", (ACTION,), ("bytes32",), (action_id,))
            require(stored[0:2] == (3, 1) and stored[11] != ZERO_ADDRESS and stored[12] != ZERO_ADDRESS
                and stored[9] <= uint(history["blockTimestamps"][str(quantity(log["blockNumber"]))]) <= stored[10], "condition original governance action differs")
            require(event["topics"][3] == _topic("address", stored[2]) and decode(EXECUTED_DATA, hex_bytes(event["data"])) ==
                (1, *stored[3:9], stored[12], stored[17]), "condition governance event/state differs")
            result = {"actionId": action_id, "action": json_values(stored), "execution": _location(event)}
            action_evidence[key] = result
            return result
        binding = {"catalog": a["conditionSources"], "runtimeHash": self.pins[a["conditionSources"]],
            "publication": _location(bound), "governance": action(bound, bound["topics"][2])}
        positions = []
        for source in catalogue["sources"]:
            source_id = uint(source["sourceId"]); require(source_id in by_id, "condition missing admission source")
            log = by_id[source_id]; lane = 0 if source["lane"] == "OWNER" else 1
            require(log["topics"][2:] == [_topic("address", source["host"]), _topic("uint8", lane)]
                and decode(("bytes32", "uint64", "bytes32", "bytes32", "bytes32", "uint16"), hex_bytes(log["data"])) ==
                    (source["runtimeHash"], uint(source["replacesSourceId"]), source["previousHead"], source["head"], source["actionId"], 1)
                and source["admittedAt"] == history["blockTimestamps"][str(quantity(log["blockNumber"]))], "condition retained admission differs")
            positions.append(_position(log))
            source["admission"] = {"publication": _location(log), "governance": action(log, source["actionId"])}
        require(positions == sorted(set(positions)), "condition source admission order differs")
        return binding

"""Original native TOKEN notice, response and executed-companion evidence.

This finite read profile depends on an explicitly admitted OwnerCatalogSource and
its runtime pins. RPC transcripts are replayable observations, not consensus
proofs. Publication references remain publisher claims; no recipient receipt,
institutional assent, or complete governance-call witness is inferred.
"""
from .canonical import MuseumError, dumps, hex_bytes, keccak256, loads, schema_id, uint
from .chain_abi import calldata, decode, encode
from .chain_history import scan_history
from .chain_rpc import MAX_TRANSCRIPT, RecordingReader, ReplayTransport, RpcTransport, quantity
from .independent_wire import ZERO, ZERO_ADDRESS, json_values, require
from .owner_catalog_source import OwnerCatalogSource, MAX_RECORDS, _location, _position

PROFILE = "STREAM_MUSEUM_OWNER_NOTICE_EVIDENCE_V1"
SOURCE_REVISION = "de5289825b47d4eb943677e9e541cb127dcdadd5"
MAX_ACTIONS, MAX_DELIVERIES, MAX_CLAIM, MAX_CLAIM_TOTAL = 256, 1024, 8192, 16777216
MAX_SNAPSHOT, MAX_ABI = 67108864, 32768
SCOPE = ("uint8", "uint256", "uint256", "bytes32")
BINDING = ("address", "bytes32", "bytes32", "bytes32", "bytes32", "bytes32", "bytes32", "bytes32", "uint64", "bytes32")
NOTICE = (BINDING, SCOPE, "address", "address", "bytes32", "bytes32", "bytes32", "uint64", "uint64",
    "uint64", "uint64", "bytes32", "uint64", "uint64", "uint64", "uint32", "uint32")
RESPONSE = ("uint256", "address", "bytes32", "bytes32", "uint64", "uint64", "uint8", "bool", "bool", "bool")
REFERENCE = ("uint16", "bytes32", "bytes", "string")
CONTACT = ("uint8", "string", "uint256", "address")
DELIVERY = (CONTACT, REFERENCE)
FACTS = ("uint8", "uint8", "bytes32", "uint64", "uint64")
COMPONENT = ("bytes32", "address", "bytes4", "bytes32", "bytes32", "bytes32", "bytes32")
MANIFEST = ("string", "bytes32", "bytes32", "bytes32", "bytes32")
EXECUTION_EVIDENCE = ("uint8", "bytes32", "address", "bytes32", "uint8", "uint64", "bytes32", "uint64", "uint64", "uint32", "uint32")
REQUEST = (SCOPE, "bytes32", "bytes32", "bytes32", COMPONENT, MANIFEST, "bytes32", "string")
RECOVERY = ("bool", "bytes32", SCOPE, "bytes32", "bytes32", "uint64", "bytes32", "bytes32", "bool",
    COMPONENT, MANIFEST, EXECUTION_EVIDENCE, "bytes32", "string", "uint64")
OPENED = schema_id("OwnerRecoveryNoticeOpened(bytes32,uint256,address,address,bytes32,bytes32,uint64,uint64,bytes32,uint16)")
RECORDED = schema_id("OwnerRecoveryResponseRecorded(bytes32,address,bytes32,uint256,bool,bool,uint16)")
PROCESSED = schema_id("OwnerRecoveryResponseProcessed(bytes32,address,bytes32,bytes32,uint64,uint32,uint32,bytes32,uint16)")
EXECUTED = schema_id("ScopedFinalityRecoveryExecuted(uint16,uint8,uint256,bytes32,uint256,bytes32,bytes32,bytes32,bool,bytes32,string)")
LINEAGE = schema_id("FinalityRecoveryLineageRecorded(uint16,bytes32,bytes32,bytes32,uint64,bytes32,bytes32)")
EVIDENCE = schema_id("FinalityRecoveryEvidenceSnapshotted(uint16,bytes32,uint8,bytes32,address,bytes32,uint8,uint64,bytes32,uint64,uint64,uint32,uint32)")
RESPONSE_TYPE, STEWARD_TYPE = schema_id("RECOVERY_RESPONSE"), schema_id("STEWARD_DESIGNATION")
STATUSES = ("NONE", "SCHEDULED", "CANCELLED", "EXECUTED", "EXPIRED", "VETOED")
CLAIMS = {"nativeNoticeAndResponseCorrespondenceChecked": True, "originalClaimBytesRetained": True,
    "completeMatchingResponseQueuesChecked": True, "executionRequiresCompanionReceipt": True,
    "completeOrderedGovernanceWitnessCaptured": False, "actionIdRecomputed": False,
    "schemaInterpretationVerified": False, "offchainDeliveryProven": False,
    "recipientReceiptProven": False, "institutionalAssentProven": False, "currentRecoveryEligibilityProven": False,
    "legalTitleProven": False, "actualChainAcceptance": False, "consensusProof": False,
    "fullObjectDossierConformance": False}
QUALIFICATION = ("Complete matching native notice and response history for one admitted token/host, within explicit refusal bounds. "
    "Opening and execution receipts preserve original authority; current owner/permissions are not reinterpreted. "
    "Publication and delivery references are publisher-attributed claims only. Governance status alone proves no recovery execution. "
    "The complete ordered GovernanceCall witness is not captured or recomputed. RPC provenance is caller-declared, not authenticated by replay.")
PROFILE_BYTES = dumps({"name": PROFILE, "version": "1", "status": "prospective_unregistered_read_profile",
    "sourceRevision": SOURCE_REVISION, "bounds": {"actions": str(MAX_ACTIONS), "responses": str(MAX_RECORDS),
        "deliveriesPerNotice": str(MAX_DELIVERIES), "claimBytes": str(MAX_CLAIM), "aggregateClaimBytes": str(MAX_CLAIM_TOTAL),
        "snapshotBytes": str(MAX_SNAPSHOT), "transcriptBytes": str(MAX_TRANSCRIPT), "historyBlocks": "4096"},
    "claims": CLAIMS, "qualification": QUALIFICATION})
PROFILE_HASH = keccak256(PROFILE_BYTES)


def _hash(kinds, values):
    return keccak256(encode(kinds, values))


def opening_hash(chain, host, core, action, notice, opening_tail):
    original_owner = (notice[3], notice[4], notice[5], notice[9])
    return _hash(("bytes32", "uint256", "address", "address", "bytes32", BINDING, SCOPE, "address",
        ("address", "bytes32", "bytes32", "uint64"), "bytes32", "uint64", "uint64", "uint64"),
        (schema_id("6529STREAM_OWNER_RECOVERY_NOTICE_V1"), chain, host, core, action, notice[0], notice[1],
         notice[2], original_owner, notice[6], notice[7], notice[8], opening_tail))


def update_hash(previous, action, digest, predecessor, response, processed, acknowledgements, objections):
    return _hash(("bytes32", "bytes32", "bytes32", "bytes32", "bytes32", "address", "uint8",
        "uint64", "uint64", "uint32", "uint32"), (schema_id("6529STREAM_OWNER_RECOVERY_RESPONSE_V1"),
        previous, action, digest, predecessor, response[1], response[6], processed, processed + 1, acknowledgements, objections))


def _publication_position(row):
    return tuple(uint(row["publication"][key]) for key in ("blockNumber", "transactionIndex", "logIndex"))


def _payload(row):
    # Parse only original bytes, without normalization or substituting caller interpretations.
    return loads(hex_bytes(row["record"][5]), maximum=8192)


def _consistent_reads(*transcripts):
    observed = {}
    for raw in transcripts:
        for row in loads(raw, maximum=MAX_TRANSCRIPT, canonical=True)["calls"]:
            request = dumps([row["method"], row["params"]])
            result = keccak256(dumps(row["result"]))
            require(request not in observed or observed[request] == result,
                "notice joined transcripts contradict the same source read")
            observed[request] = result


def _reference(reference):
    algorithm, canon, digest, uri = reference
    require(1 <= algorithm <= 6 and canon != ZERO and
        (0 < len(digest) <= 128 if algorithm in (4, 5) else len(digest) == 32)
        and 0 < len(uri.encode("utf-8")) <= 2048, "notice original reference shape")


def _contact_json(contact):
    kind, uri, chain, account = contact
    require(kind <= 2, "notice contact enum")
    if kind == 2:
        require(uri == "" and chain > 0 and account != ZERO_ADDRESS, "notice EIP155 endpoint")
        return {"kind": "eip155", "chainId": str(chain), "account": account}
    require(chain == 0 and account == ZERO_ADDRESS and 0 < len(uri.encode("utf-8")) <= 2048,
        "notice inactive endpoint fields")
    return {"kind": "https" if kind == 0 else "mailto", "uri": uri}


class OwnerNoticeEvidenceSource:
    """Read/replay notice evidence joined to one concrete complete owner catalogue."""

    def __init__(self, owner_catalog, transport, *, provenance="synthetic_fixture"):
        require(type(owner_catalog) is OwnerCatalogSource, "notice requires concrete owner catalogue")
        require(provenance == owner_catalog.provenance and provenance in ("synthetic_fixture", "trusted_rpc")
            and (provenance != "trusted_rpc" or type(transport) in (RpcTransport, ReplayTransport)),
            "notice provenance differs from owner catalogue")
        self.owner_catalog, self.provenance = owner_catalog, provenance
        self.anchor_bytes = owner_catalog.anchor_bytes
        self.a, self.pins = owner_catalog.a, owner_catalog.pins
        self.reader = RecordingReader(transport, self.a["blockHash"])
        self._started, self._snapshot, self._claim_bytes = False, None, 0

    def transcript(self):
        return self.reader.transcript()

    def _read(self, target, signature, outputs, kinds=(), values=()):
        raw = hex_bytes(self.reader.call(target, calldata(signature, kinds, values)))
        return decode(outputs, raw, maximum=MAX_ABI)

    def _pin(self, address, expected=None):
        require(address in self.pins and (expected is None or self.pins[address] == expected),
            "notice missing/differing explicit dependency pin")
        code = hex_bytes(self.reader.code(address))
        require(0 < len(code) <= 24576 and keccak256(code) == self.pins[address], "notice runtime pin differs")

    def snapshot(self):
        if self._snapshot is not None:
            return self._snapshot
        require(not self._started, "failed notice capture cannot resume")
        self._started = True
        try:
            self._snapshot = self._capture()
        except MuseumError:
            raise
        except (KeyError, TypeError, ValueError, IndexError, OverflowError) as exc:
            raise MuseumError("malformed native notice evidence") from exc
        return self._snapshot

    def _events(self, history, originals):
        opened, responses, processed = {}, {}, {}
        for log in history["logs"]:
            topics = log["topics"]
            if log["address"] != self.a["host"] or not topics:
                continue
            if topics[0] == OPENED:
                require(len(topics) == 4, "notice opening topics")
                token, = decode(("uint256",), hex_bytes(topics[2]))
                if token != uint(self.a["tokenId"]):
                    continue
                owner, = decode(("address",), hex_bytes(topics[3]))
                values = decode(("address", "bytes32", "bytes32", "uint64", "uint64", "bytes32", "uint16"), hex_bytes(log["data"]))
                require(topics[1] != ZERO and topics[1] not in opened and values[-1] == 1 and owner != ZERO_ADDRESS,
                    "notice duplicate/invalid opening")
                opened[topics[1]] = (owner, values, log)
            elif topics[0] == RECORDED:
                require(len(topics) == 4, "notice response topics")
                token, queued, late, version = decode(("uint256", "bool", "bool", "uint16"), hex_bytes(log["data"]))
                if token != uint(self.a["tokenId"]):
                    continue
                action, digest = topics[1], topics[3]
                author, = decode(("address",), hex_bytes(topics[2]))
                require(digest in originals and digest not in responses and version == 1,
                    "notice typed response lacks unique original")
                row = originals[digest]; body = _payload(row)
                require(row["record"][0] == RESPONSE_TYPE and row["receipt"][1] == author
                    and row["publication"]["transactionHash"] == log["transactionHash"]
                    and _publication_position(row) < _position(log), "notice typed response publication differs")
                require(type(body) is dict and set(body) == {"evidenceReferences", "grounds", "profileHash", "recoveryId",
                    "recoveryManifestHash", "response", "subjectId", "version"} and type(body["version"]) is int
                    and body["version"] == 1 and body["subjectId"] == row["record"][1] and body["recoveryId"] == action
                    and body["response"] in ("acknowledged", "objected") and any(hex_bytes(action, 32))
                    and any(hex_bytes(body["recoveryManifestHash"], 32)) and any(hex_bytes(body["profileHash"], 32)),
                    "notice typed original response linkage differs")
                response, = self._read(self.a["host"], "recoveryResponse(bytes32)", (RESPONSE,), ("bytes32",), (digest,))
                require(response[:7] == (token, author, action, body["recoveryManifestHash"], uint(row["receipt"][2]),
                    uint(row["receipt"][3]), 0 if body["response"] == "acknowledged" else 1),
                    "notice response getter differs from original")
                responses[digest] = (response, queued, late, log)
            elif topics[0] == PROCESSED:
                require(len(topics) == 4, "notice processed topics")
                processed.setdefault(topics[1], []).append(log)
        require(len(set(opened) | {r[0][2] for r in responses.values()}) <= MAX_ACTIONS, "notice action bound")
        for action, logs in processed.items():
            for log in logs:
                digest = log["topics"][3]
                if digest in responses:
                    require(responses[digest][0][2] == action and action in opened,
                        "notice processed event action differs")
        return opened, responses, processed

    def _claims(self, action, notice, originals, opening_log):
        expected = [{"kind": "eip155", "chainId": self.a["chainId"], "account": notice[3]}]
        if notice[4] == ZERO:
            require(notice[5] == ZERO, "notice empty designation commitment")
        else:
            require(notice[4] in originals, "notice original designation missing")
            row = originals[notice[4]]; body = _payload(row)
            require(row["record"][0] == STEWARD_TYPE and row["receipt"][1] == notice[3]
                and _publication_position(row) < _position(opening_log)
                and keccak256(hex_bytes(row["record"][5])) == notice[5]
                and body["subjectId"] == row["record"][1] and type(body["contactEndpoints"]) is list,
                "notice original designation linkage differs")
            expected.extend(body["contactEndpoints"])
        require(1 <= notice[10] <= MAX_DELIVERIES and notice[10] == len(expected), "notice complete endpoint count")
        claims, rolling = [], None
        for index in range(notice[10] + 1):
            pointer, raw = self._read(self.a["host"], "recoveryNoticeClaim(bytes32,uint256)", ("address", "bytes"),
                ("bytes32", "uint256"), (action, index))
            self._claim_bytes += len(raw)
            require(pointer != ZERO_ADDRESS and 0 < len(raw) <= MAX_CLAIM and self._claim_bytes <= MAX_CLAIM_TOTAL,
                "notice immutable claim bound")
            code = hex_bytes(self.reader.code(pointer))
            require(code == b"\x00" + raw, "notice immutable claim carrier differs")
            if index == 0:
                decoded = decode((REFERENCE, REFERENCE), raw, maximum=MAX_CLAIM)
                for reference in decoded:
                    _reference(reference)
                rolling = keccak256(raw)
            else:
                decoded, = decode((DELIVERY,), raw, maximum=MAX_CLAIM)
                require(_contact_json(decoded[0]) == expected[index - 1], "notice original ordered endpoint differs")
                _reference(decoded[1])
                rolling = _hash(("bytes32", "uint256", "bytes32"), (rolling, index - 1, keccak256(raw)))
            claims.append({"index": str(index), "pointer": pointer, "originalBytes": "0x" + raw.hex(),
                "contentHash": keccak256(raw), "runtimeHash": keccak256(code), "wire": json_values(decoded),
                "attribution": "publisher_publication_claim" if index == 0 else "publisher_delivery_claim"})
        require(rolling == notice[6], "notice publication rolling hash differs")
        return claims

    def _notice(self, action, opening, responses, processing, originals, history, executor):
        notice, = self._read(self.a["host"], "recoveryNotice(bytes32)", (NOTICE,), ("bytes32",), (action,))
        binding, scope = notice[:2]; owner, opened, opening_log = opening
        require(scope[0] == 1 and scope[1] > 0 and scope[2] == uint(self.a["tokenId"]) and scope[3] == ZERO,
            "notice TOKEN scope differs")
        identity = self._read(self.a["core"], "tokenCollectionIdentity(uint256)",
            ("bool", "uint256", "uint256", "bool"), ("uint256",), (scope[2],))
        # A subsequent burn does not invalidate the original notice publication.
        require(identity[0] and identity[1] == scope[1] and identity[2] > 0,
            "notice immutable token collection differs")
        require(binding[0] != ZERO_ADDRESS and all(binding[i] != ZERO for i in (1, 2, 3, 4, 5, 6, 7, 9))
            and binding[2] == _hash(("bytes32", "uint256", "address", SCOPE),
                (schema_id("6529STREAM_FINALITY_RECOVERY_SCOPE_V1"), uint(self.a["chainId"]), binding[0], scope)),
            "notice original binding differs")
        require(notice[3] == owner and notice[2] != ZERO_ADDRESS and opened[:5] == (notice[2], notice[4], notice[6], notice[7], notice[8])
            and notice[7] == uint(history["blockTimestamps"][str(quantity(opening_log["blockNumber"]))])
            and 0 < notice[7] and notice[8] == notice[7] + 72 * 3600 and notice[8] <= binding[8],
            "notice original opening snapshot differs")
        claims = self._claims(action, notice, originals, opening_log)
        queue = sorted((digest for digest, row in responses.items() if row[0][2:4] == (action, binding[6])),
            key=lambda digest: responses[digest][0][5])
        opening_tail = sum(_position(responses[d][3]) < _position(opening_log) for d in queue)
        barrier = sum(_publication_position(row) < _position(opening_log) for row in originals.values()
            if row["record"][0] == RESPONSE_TYPE)
        require(notice[9] == barrier and notice[13] == len(queue) and notice[14] <= len(queue)
            and notice[12] == notice[14] + 1, "notice complete queue/barrier/cursor differs")
        evidence = opening_hash(uint(self.a["chainId"]), self.a["host"], self.a["core"], action, notice, opening_tail)
        require(opened[5] == evidence, "notice opening evidence hash differs")
        latest, counts, revisions = {}, [0, 0], [(evidence, 1, notice[8], 0, 0, opening_log)]
        require(len(processing) == notice[14], "notice processed event count differs")
        for index, digest in enumerate(queue):
            response, was_queued, was_late, response_log = responses[digest]
            require(self._read(self.a["host"], "recoveryResponseAt(bytes32,uint256)", ("bytes32",),
                ("bytes32", "uint256"), (action, index)) == (digest,), "notice complete queue occurrence differs")
            before_opening = _position(response_log) < _position(opening_log)
            require(was_queued == (not before_opening) and was_late == (not before_opening and response[4] >= notice[8])
                and response[7:] == (True, index < notice[14], response[4] >= notice[8]),
                "notice response temporal/processing labels differ")
            if index >= notice[14]:
                continue
            log = processing[index]; predecessor = latest.get(response[1], ZERO)
            require(log["topics"][3] == digest and decode(("address",), hex_bytes(log["topics"][2])) == (response[1],)
                and _position(log) > max(_position(response_log), _position(opening_log)), "notice processing order differs")
            if predecessor != ZERO:
                counts[responses[predecessor][0][6]] -= 1
            counts[response[6]] += 1
            evidence = update_hash(evidence, action, digest, predecessor, response, index + 1, *counts)
            require(decode(("bytes32", "uint64", "uint32", "uint32", "bytes32", "uint16"), hex_bytes(log["data"]))
                == (predecessor, index + 2, *counts, evidence, 1), "notice processed evidence event differs")
            latest[response[1]] = digest
            revisions.append((evidence, index + 2, notice[8], *counts, log))
        require((evidence, *counts) == (notice[11], notice[15], notice[16]), "notice final evidence/counts differ")
        for author in sorted({responses[d][0][1] for d in queue}):
            require(self._read(self.a["host"], "latestCountedRecoveryResponse(bytes32,address)", ("bytes32",),
                ("bytes32", "address"), (action, author)) == (latest.get(author, ZERO),), "notice latest counted response differs")
        facts, = self._read(executor, "governanceActionFacts(bytes32)", (FACTS,), ("bytes32",), (action,))
        require(facts[0] < len(STATUSES) and facts[1:3] == (2, binding[7]) and facts[4] == binding[8]
            and facts[3] <= facts[4], "notice saved governance action facts differ")
        execution = self._execution(action, notice, facts, revisions, queue, responses, history, executor)
        return {"actionId": action, "state": "opened", "wire": json_values(notice),
            "originalAbiBytes": "0x" + encode((NOTICE,), (notice,)).hex(), "openingEvent": opening_log,
            "binding": json_values(binding), "scope": json_values(scope), "claims": claims,
            "queue": queue, "processed": str(notice[14]), "pending": queue[notice[14]:],
            "latestCountedByAuthor": [{"author": key, "recordHash": value} for key, value in sorted(latest.items())],
            "revisions": [{"evidenceHash": row[0], "revision": str(row[1]), "noticeEndsAt": str(row[2]),
                "acknowledgements": str(row[3]), "objections": str(row[4]), "event": row[5]} for row in revisions],
            "governanceAction": {"status": STATUSES[facts[0]], "wire": json_values(facts)},
            "completeOrderedActionWitness": "not_captured", "execution": execution}

    def _execution(self, action, notice, facts, revisions, queue, responses, history, executor):
        binding, scope = notice[:2]; target = binding[0]
        self._pin(target, binding[1])
        for getter, value in (("core", self.a["core"]), ("governanceAuthority", executor), ("ownerEvidence", self.a["host"])):
            require(self._read(target, getter + "()", ("address",)) == (value,), "notice companion reciprocal binding differs")
        record, = self._read(target, "finalityRecoveryRecord(bytes32)", (RECOVERY,), ("bytes32",), (action,))
        matched = {kind: [] for kind in (EXECUTED, LINEAGE, EVIDENCE)}
        for log in history["logs"]:
            topics = log["topics"]
            if log["address"] == target and topics and topics[0] in matched:
                offset = 3 if topics[0] == EXECUTED else 1
                require(len(topics) == (2 if topics[0] == EVIDENCE else 4), "notice execution event topics")
                if topics[offset] == action:
                    matched[topics[0]].append(log)
        base = {"target": target, "targetCodeHash": binding[1], "wire": json_values(record),
            "originalAbiBytes": "0x" + encode((RECOVERY,), (record,)).hex()}
        if not record[0]:
            require(not any(matched.values()) and record == _empty(RECOVERY), "notice unexecuted companion record/events differ")
            return {**base, "state": "observed_not_executed"}
        require(all(len(rows) == 1 for rows in matched.values()), "notice execution receipt set incomplete/duplicate")
        event, lineage, evidence_event = (matched[k][0] for k in (EXECUTED, LINEAGE, EVIDENCE))
        require(facts[0] == 3 and record[1] == action and record[2] == scope and record[3] == binding[9]
            and record[5] > 0 and record[8] is True and record[10][2] == binding[6]
            and record[11][0] in (1, 2) and notice[8] <= record[14] <= binding[8]
            and record[14] == uint(history["blockTimestamps"][str(quantity(event["blockNumber"]))]),
            "notice executed companion identity/time differs")
        require(lineage["transactionHash"] == evidence_event["transactionHash"] == event["transactionHash"]
            and _position(lineage) < _position(evidence_event) < _position(event), "notice execution receipt order differs")
        request = (record[2], record[3], record[4], record[6], record[9], record[10], record[12], record[13])
        scope_key = _hash(SCOPE, scope)
        require(_hash((REQUEST,), (request,)) == binding[5]
            and _hash(("bytes32", "bytes32", "bytes32", "bytes32", "uint64", "bytes32"),
                (schema_id("6529STREAM_FINALITY_RECOVERY_OLD_STATE_V1"), scope_key, record[3], record[4], record[5] - 1, record[6])) == binding[3]
            and _hash(("bytes32", "uint256", "address", "uint64", REQUEST),
                (schema_id("6529STREAM_FINALITY_RECOVERY_NEW_STATE_V1"), uint(self.a["chainId"]), target, record[5], request)) == binding[4],
            "notice executed original request/transition commitments differ")
        route = keccak256(encode(("bytes32", "uint256", "address", "bytes32", "bytes32", "bytes32", "uint64"),
            (schema_id("6529STREAM_SCOPED_FINALITY_RECOVERY_V1"), uint(self.a["chainId"]), target, action, record[3], record[4], record[5]))
            + encode((SCOPE, COMPONENT, "bytes32", EXECUTION_EVIDENCE, "bytes32"), (scope, record[9], binding[6], record[11], record[12])))
        require(route == record[7] and record[10][1] == keccak256(record[10][0].encode("utf-8")), "notice executed route/manifest URI hash differs")
        require(decode(("uint8",), hex_bytes(event["topics"][1])) == (1,)
            and decode(("uint256",), hex_bytes(event["topics"][2])) == (scope[1],)
            and decode(("uint16", "uint256", "bytes32", "bytes32", "bytes32", "bool", "bytes32", "string"), hex_bytes(event["data"]))
                == (1, scope[2], scope[3], binding[6], record[7], True, record[12], record[13]), "notice executed event differs")
        require(lineage["topics"][2:] == [record[4], record[3]] and decode(("uint16", "uint64", "bytes32", "bytes32"), hex_bytes(lineage["data"]))
            == (1, record[5], record[6], record[7]), "notice executed lineage event differs")
        require(decode(("uint16", EXECUTION_EVIDENCE), hex_bytes(evidence_event["data"])) == (1, record[11]),
            "notice executed evidence event differs")
        before = [row for row in revisions if _position(row[5]) < _position(lineage)]
        require(before and tuple(record[11][6:]) == before[-1][:5] and len(before) == len(revisions)
            and sum(_position(responses[d][3]) < _position(lineage) for d in queue) == before[-1][1] - 1,
            "notice execution consumed evidence/pending tail differs")
        return {**base, "state": "executed_native_receipt", "requestReconstructedFromExecutedRecord": json_values(request),
            "events": [lineage, evidence_event, event], "consumedOwnerEvidenceRevision": str(record[11][7])}

    def _capture(self):
        owner_raw = self.owner_catalog.snapshot()
        owner = loads(owner_raw, maximum=MAX_SNAPSHOT, canonical=True)
        originals = {row["recordHash"]: row for row in owner["records"] if row["record"][0] in (RESPONSE_TYPE, STEWARD_TYPE)}
        for address in sorted(self.pins):
            self._pin(address)
        history = scan_history(self.reader, self.a)
        opened, responses, processed = self._events(history, originals)
        executor = None
        if opened:
            executor, = self._read(self.a["host"], "governanceAuthority()", ("address",))
            digest, = self._read(self.a["host"], "executorCodeHash()", ("bytes32",))
            self._pin(executor, digest)
        actions = []
        for action in sorted(set(opened) | {r[0][2] for r in responses.values()}):
            if action in opened:
                actions.append(self._notice(action, opened[action], responses, processed.get(action, []), originals, history, executor))
            else:
                require(not any(log["topics"][3] in responses for log in processed.get(action, [])),
                    "notice processing without matching token opening")
                actions.append({"actionId": action, "state": "no_token_notice_in_complete_history",
                    "completeOrderedActionWitness": "not_captured", "execution": {"state": "not_captured", "reason": "no_saved_target_binding"}})
        for digest, (response, queued, late, log) in responses.items():
            matching = response[2] in opened and any(a["actionId"] == response[2] and a.get("binding", [None] * 7)[6] == response[3] for a in actions)
            if not matching:
                require(response[7:] == (False, False, False) and not queued and not late, "notice unmatched response labels differ")
        end = self.reader.request("eth_getBlockByHash", [self.a["blockHash"], False])
        require(type(end) is dict and end.get("hash") == self.a["blockHash"] and end.get("stateRoot") == self.a["stateRoot"]
            and quantity(end.get("number")) == uint(self.a["blockNumber"])
            and quantity(end.get("timestamp")) == uint(self.a["timestamp"]), "notice final source anchor differs")
        _consistent_reads(self.owner_catalog.transcript(), self.transcript())
        if type(self.reader.transport) is ReplayTransport:
            self.reader.transport.finish()
        result = dumps({"profile": PROFILE, "profileHash": PROFILE_HASH, "version": "1", "sourceRevision": SOURCE_REVISION,
            "mode": "caller_admitted_rpc_owner_notice_evidence" if self.provenance == "trusted_rpc" else "synthetic_fixture",
            "provenanceDeclaredByCaller": True, "anchorHash": keccak256(self.anchor_bytes), "ownerCatalogueHash": keccak256(owner_raw),
            "ownerCatalogueTranscriptHash": keccak256(self.owner_catalog.transcript()), "transcriptHash": keccak256(self.transcript()),
            "sourceState": owner["sourceState"], "host": self.a["host"], "subjectId": owner["subjectId"],
            "originals": [originals[key] for key in sorted(originals)], "actions": actions,
            "responses": [{"recordHash": key, "wire": json_values(value[0]), "recordedEvent": value[3],
                "queuedAtPublication": value[1], "lateAtPublication": value[2]} for key, value in sorted(responses.items())],
            "unlinkedOriginalResponseHashes": sorted(set(originals) - set(responses) -
                {key for key, row in originals.items() if row["record"][0] == STEWARD_TYPE}),
            "history": {key: history[key] for key in ("blockCount", "transactionCount", "startBlock", "endBlock")},
            "claims": CLAIMS, "qualification": QUALIFICATION})
        require(len(result) <= MAX_SNAPSHOT, "notice snapshot byte bound")
        return result


def _empty(kind):
    if isinstance(kind, tuple):
        return tuple(_empty(k) for k in kind)
    if kind == "bool":
        return False
    if kind == "address":
        return ZERO_ADDRESS
    if kind == "string":
        return ""
    if kind == "bytes":
        return b""
    if kind.startswith("bytes"):
        return "0x" + "00" * int(kind[5:])
    return 0

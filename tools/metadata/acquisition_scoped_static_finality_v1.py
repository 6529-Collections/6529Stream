"""Original scoped STATIC finality as a closed supplied-data fragment.

This version-local definition preserves TOKEN, RELEASE or SEASON evidence.  It
does not alter collection-finality V1/V6 or claim that supplied RPC observations
authenticate chain execution.
"""
import argparse
import copy
from pathlib import Path

from jsonschema import Draft202012Validator
from jsonschema.exceptions import ValidationError

from tools.museum import native_scoped_finality_wire as wire
from tools.museum import scoped_static_content_wire as content_wire
from tools.museum import scoped_static_snapshot_wire as snapshot_wire
from tools.museum import scoped_static_types as types
from tools.museum.canonical import MuseumError, dumps, hex_bytes, keccak256, loads, subject_id, uint
from tools.museum.chain_abi import Array
from tools.museum.public_chain_history import _log
from tools.museum.independent_wire import RECORD as METADATA_RECORD
from tools.museum.independent_wire import ZERO, ZERO_ADDRESS, require
from . import acquisition_native_finality_v1 as native
from . import acquisition_governance_transactions_v1 as governance
from .acquisition_packet_v5 import _typed

ROOT = Path(__file__).resolve().parents[2]
NAME = "STREAM_ACQUISITION_SCOPED_STATIC_FINALITY_V1"
SOURCE_PROFILE = "STREAM_MUSEUM_PUBLIC_SCOPED_STATIC_FINALITY_SOURCE_V1"
SOURCE_REVISION = wire.SOURCE_REVISION
MAX_BYTES, MAX_EVENTS, MAX_ORIGINAL_BYTES = 64 * 1024 * 1024, 8192, 1024 * 1024
SOURCE_REF_FIELDS = native.SOURCE_REF_FIELDS
COMMON = native.COMMON
CLAIMS = {
    "completeAuthority": False,
    "sourceAuthenticated": False,
    "historicalCoreFactsPreimageRecovered": False,
    "historicalRendererExecutionReenacted": False,
    "historicalGovernanceAuthorizationReexecuted": False,
    "transactionHashesRecomputed": False,
    "actualChainAcceptance": False,
}
QUALIFICATION = (
    "Prospective unregistered supplied-data scoped STATIC finality evidence. Exact TOKEN, RELEASE or SEASON "
    "membership, STATIC selection, output-hash manifest, scoped content-root history, original snapshot, "
    "finality receipt, native events and available original governance transactions are retained and joined. "
    "Current source-block token identity is separate from immutable historical membership; a later burn does not "
    "rewrite the finalized member set. Output rows preserve hashes and source commitments, not rendered bytes. "
    "Historical Core facts remain hash-only. RPC observations, original transaction JSON and successful receipts "
    "do not prove signed envelopes, runtime admission, consensus, historical roles, renderer execution, EVM "
    "execution, current archive availability, complete authority or acquisition acceptance. COLLECTION, VIEW, "
    "HYBRID, policy V2 and non-STATIC profiles remain unsupported."
)
RULES = [
    "Numeric version1 is additive. Frozen collection finality, governance, V5 and V6 definitions are unchanged.",
    "The scope is exactly TOKEN, RELEASE or SEASON. RELEASE and SEASON use the complete sealed ordered membership; TOKEN uses exactly its one native token identity.",
    "The selected scoped content root is retained historically. Source-block scopeHead may be a later root; the event join proves the selected root was the latest same-scope root strictly before finalization.",
    "Complete output rows have token IDs in exact membership and selection order. Hash-only rows do not imply retention of JSON, image, HTML, animation or token-data bytes.",
    "The original coordinator policy inventory is the distinct coordinator sequence by first occurrence, including exact original code hashes and first token indices. Recurrence after another coordinator is valid.",
    "Original schedule and execution transaction/header/receipt bytes are retained when available. Canonical direct Executor inputs reconstruct the ordered calls and action-ID preimage; missing or indirect inputs remain partial.",
    "Historical facts and identities are never reconstructed from current role, source, renderer or requireCurrent getters.",
]


def closed(properties):
    return {"type": "object", "properties": properties, "required": list(properties), "additionalProperties": False}


def ref(name): return {"$ref": "#/$defs/" + name}
def nullable(shape): return {"oneOf": [{"type": "null"}, shape]}
def array(shape, maximum, minimum=0): return {"type": "array", "items": shape, "minItems": minimum, "maxItems": maximum}
def blob(maximum): return {"type": "string", "pattern": "^0x(?:[0-9a-f]{2})*(?![\\s\\S])", "maxLength": 2 + 2 * maximum}


def abi(kind):
    if isinstance(kind, Array): return array(abi(kind.item), kind.maximum)
    if isinstance(kind, tuple):
        return {"type": "array", "prefixItems": [abi(item) for item in kind], "items": False,
            "minItems": len(kind), "maxItems": len(kind)}
    if kind == "bool": return {"type": "boolean"}
    if kind == "bytes": return blob(snapshot_wire.MAX_PAYLOAD)
    if kind == "string": return {"type": "string", "maxLength": wire.MAX_CALLDATA,
        "x-stream-max-utf8-bytes": wire.MAX_CALLDATA}
    if kind.startswith("uint"):
        return {"type": "string", "pattern": "^(0|[1-9][0-9]*)(?![\\s\\S])", "maxLength": 78,
            "x-stream-uint-bits": int(kind[4:])}
    length = 20 if kind == "address" else int(kind[5:])
    return {"type": "string", "pattern": "^0x[0-9a-f]{" + str(length * 2) + "}(?![\\s\\S])"}


def _transaction_definitions(d):
    h, a, u = abi("bytes32"), abi("address"), abi("uint256")
    d["normalized"] = closed({"to": nullable(a), "from": a, "value": u,
        "input": blob(governance.wire.MAX_TRANSACTION_BYTES)})
    d["transaction"] = closed({"status": {"enum": ["available", "not_returned"]},
        "transactionBytes": nullable(blob(MAX_ORIGINAL_BYTES)), "receiptBytes": blob(MAX_ORIGINAL_BYTES),
        "normalized": nullable(ref("normalized"))})
    d["call"] = closed({key: a if key == "target" else u if key == "value" else abi("bytes4") if key == "selector" else h
        for key in governance.wire.CALL_FIELDS})
    d["finalityCall"] = closed({"index": u, **copy.deepcopy(d["call"]["properties"])})
    flags = ("fullGovernanceCallMetadataReconstructed", "actionIdPreimageReconstructed",
        "originalSchedulingTransactionDecoded", "originalExecutionTransactionDecoded",
        "bothOriginalTransactionInputsDecoded")
    false_flags = ("transactionHashesRecomputed", "transactionSenderSignatureVerified",
        "historicalRoleAuthorizationReexecuted", "historicalPolicyReexecuted",
        "historicalEvmExecutionReexecuted", "completeAuthority", "actualChainAcceptance")
    d["governanceClaims"] = closed({**{key: {"type": "boolean"} for key in flags},
        **{key: {"const": False} for key in false_flags}})
    reasons = [side + suffix for side in ("schedule", "execution") for suffix in
        ("_transaction_unavailable", "_outer_recipient_not_executor", "_outer_selector_unsupported",
         "_unsupported_noncanonical_input")]
    reasons.append("single_execution_first_call_transitions_unavailable")
    d["governance"] = closed({"status": {"enum": ["reconstructed", "partial"]},
        "reasons": array({"enum": reasons}, 3), "scheduleKind": {"enum": [None, "schedule_batch", "schedule_action"]},
        "executionKind": {"enum": [None, "execute_batch", "execute_action"]}, "originalNonce": u,
        "calls": nullable(array(ref("call"), governance.wire.MAX_CALLS, 1)),
        "callDatas": nullable(array(blob(governance.wire.MAX_CALL_BYTES), governance.wire.MAX_CALLS, 1)),
        "callsHash": nullable(h), "callsHashPreimage": nullable(blob(16384)),
        "aggregateTransitions": nullable(closed({key: h for key in ("scopeHash", "oldValueHash", "newValueHash")})),
        "actionId": h, "actionIdPreimage": nullable(blob(416)), "callDataKey": nullable(h),
        "claims": ref("governanceClaims"), "finalityCall": nullable(ref("finalityCall"))})


def definitions():
    h, a = abi("bytes32"), abi("address")
    d = {"sourceRef": closed({**{key: h for key in SOURCE_REF_FIELDS[:-1]},
        "provenance": {"enum": ["synthetic_fixture", "trusted_rpc"]}})}
    d["sourceState"] = closed({key: a if key == "core" else h if key in ("blockHash", "stateRoot", "deploymentEvidenceHash")
        else {"enum": ["local_evm_fixture", "public_chain"]} if key == "environment"
        else abi("uint64" if key in ("blockNumber", "timestamp") else "uint256") for key in COMMON})
    d["graph"] = closed({key: closed({"address": a, "runtimeHash": h}) for key in wire.GRAPH_KEYS})
    d["identity"] = closed({"tokenId": abi("uint256"), "collectionId": abi("uint256"),
        "collectionSerial": abi("uint256"), "lifecycle": {"enum": ["2", "3"]}, "burned": {"type": "boolean"}})
    d["finality"] = closed({"record": abi(wire.SCOPED_RECORD), "components": array(abi(wire.COMPONENT), 32, 1),
        "manifestRef": abi(wire.MANIFEST_REF), "manifestBytes": blob(wire.MAX_MANIFEST),
        "executionWitness": abi(wire.EXECUTION_WITNESS), "archiveWitness": abi(wire.ARCHIVE_WITNESS), "inputsHash": h})
    d["rootRow"] = closed({"recordHash": h, "record": abi(types.ROOT_RECORD), "aggregate": abi(types.ROOT_AGGREGATE)})
    d["roots"] = closed({"selectedRootHash": h, "scopeHead": h, "collectionAggregate": abi(types.ROOT_AGGREGATE),
        "history": array(ref("rootRow"), types.MAX_HISTORY, 1)})
    d["chunk"] = closed({"pointer": a, "codeHash": h, "runtime": blob(types.CHUNK_BYTES + 1)})
    d["checkpoint"] = closed({"id": h, "salt": h, "plan": abi(types.CONTENT_PLAN),
        "outputs": array(abi(types.OUTPUT), types.MAX_OUTPUTS, 1)})
    d["outputManifest"] = closed({"recordHash": h, "planHash": h, "record": abi(types.OUTPUT_MANIFEST),
        "plan": abi(types.OUTPUT_PLAN), "artifactHash": h, "artifact": abi(types.ARTIFACT),
        "coverage": abi(types.COVERAGE), "chunks": array(ref("chunk"), types.MAX_PARTS, 1)})
    d["content"] = closed({"roots": ref("roots"), "checkpoint": ref("checkpoint"), "manifest": ref("outputManifest")})
    d["snapshotRow"] = closed({"publication": abi(types.SNAPSHOT_PUBLICATION),
        "receipt": abi(types.SNAPSHOT_RECEIPT), "payload": blob(snapshot_wire.MAX_PAYLOAD)})
    d["snapshot"] = closed({"dependencies": abi(types.SNAPSHOT_DEPS),
        "history": array(ref("snapshotRow"), types.MAX_HISTORY, 1), "head": h, "lock": abi(types.SNAPSHOT_LOCK)})
    d["selection"] = closed({"id": h, "plan": abi(types.SELECTION_PLAN),
        "rows": array(abi(types.SELECTION_ROW), types.MAX_OUTPUTS, 1)})
    d["membership"] = closed({"publication": nullable(abi(types.MEMBERSHIP_PUBLICATION)),
        "progress": nullable(abi(types.MEMBERSHIP_PROGRESS)), "metadataRecord": nullable(abi(METADATA_RECORD)),
        "manifestBytes": nullable(blob(2336)), "parts": array(ref("chunk"), types.MAX_PARTS),
        "tokens": array(abi("uint256"), types.MAX_MEMBERS, 1),
        "identities": array(abi(("bool", "uint256", "uint256", "bool")), types.MAX_MEMBERS, 1),
        "lifecycles": array(abi("uint8"), types.MAX_MEMBERS, 1),
        "inventoryTokens": array(abi("uint256"), types.MAX_MEMBERS),
        "progressHistory": array(abi(("uint256", "uint256")), types.MAX_MEMBERS), "facts": abi(types.MEMBERSHIP_FACTS)})
    d["execution"] = closed({"action": abi(wire.base.GOVERNANCE_ACTION), "callDataPointer": a,
        "callDatas": array(blob(wire.MAX_CALLDATA), 64, 1), "runtime": blob(24576)})
    d["bundle"] = closed({"scope": abi(wire.SCOPE), "finality": ref("finality"), "content": ref("content"),
        "snapshot": ref("snapshot"), "selection": ref("selection"), "membership": ref("membership"),
        "execution": ref("execution")})
    q = {"type": "string", "pattern": "^0x(?:0|[1-9a-f][0-9a-f]*)(?![\\s\\S])", "maxLength": 66}
    d["log"] = closed({"address": a, "blockHash": h, "blockNumber": q, "data": blob(65536), "logIndex": q,
        "topics": array(h, 4, 1), "transactionHash": h, "transactionIndex": q})
    d["event"] = closed({"log": ref("log"), "timestamp": abi("uint64")})
    d["definition"] = closed({"documentId": h, "payloadHex": blob(snapshot_wire.MAX_PAYLOAD)})
    d["historicalCoreFacts"] = closed({"status": {"const": "hash_only"}, "hash": h, "preimage": {"type": "null"}})
    _transaction_definitions(d)
    d["claims"] = closed({key: {"const": value} for key, value in CLAIMS.items()})
    d["fragment"] = closed({"schema": {"const": NAME}, "version": {"const": 1}, "sourceRef": ref("sourceRef"),
        "sourceState": ref("sourceState"), "graph": ref("graph"), "identity": ref("identity"),
        "bundle": ref("bundle"), "events": array(ref("event"), MAX_EVENTS, 1),
        "definitions": array(ref("definition"), 9, 9), "headers": array(blob(MAX_ORIGINAL_BYTES), 2, 1),
        "transactions": closed({key: ref("transaction") for key in ("schedule", "execution")}),
        "reconstruction": ref("governance"), "historicalCoreFacts": ref("historicalCoreFacts"),
        "claims": ref("claims"), "qualification": {"const": QUALIFICATION}})
    d["tokenProof"] = closed({"kind": {"const": "native_scoped_token_content_proof"}, "subjectId": h,
        "scope": abi(wire.SCOPE), "rootRecordHash": h, "manifestHash": h, "root": h,
        "leafCount": abi("uint64"), "leafIndex": abi("uint64"), "leaf": abi(wire.base.LEAF),
        "leafHash": h, "proof": array(h, 16)})
    return d


def schema_document_bytes():
    return dumps({"$schema": "https://json-schema.org/draft/2020-12/schema", "$id": "urn:6529stream:schema:" + NAME,
        "title": NAME, "description": QUALIFICATION, **ref("fragment"), "$defs": definitions(),
        "x-stream-source-profile": SOURCE_PROFILE, "x-stream-source-review": SOURCE_REVISION,
        "x-stream-constraints": RULES})


SCHEMA_BYTES = schema_document_bytes()
SCHEMA_HASH = keccak256(SCHEMA_BYTES)


def token_proof(value):
    source, bundle = value["sourceState"], value["bundle"]
    content = content_wire.validate(bundle["content"], source, value["graph"],
        wire.validate_finality(bundle["finality"], source, value["graph"], bundle["scope"])["statement"])
    proof = content["targetProof"]
    return {"kind": "native_scoped_token_content_proof",
        "subjectId": subject_id("token", source["chainId"], source["core"], source["collectionId"],
            token_id=source["tokenId"]), "scope": copy.deepcopy(bundle["scope"]),
        "rootRecordHash": proof["rootRecordHash"], "manifestHash": proof["manifestHash"],
        "root": proof["root"], "leafCount": proof["leafCount"], "leafIndex": proof["leafIndex"],
        "leaf": copy.deepcopy(proof["leaf"]), "leafHash": proof["leafHash"], "proof": list(proof["proof"])}


def native_record_keys(value):
    bundle, graph = value["bundle"], value["graph"]
    # Snapshot and membership rows are genuine original typed/Metadata records
    # and can independently appear in the preserved catalogue.  Only the
    # Registry finality record and Router root are non-generic native records
    # that cannot be relabeled as legacy packet authority.
    return {(graph["finality"]["address"], bundle["finality"]["record"][2])} | {
        (graph["router"]["address"], row["recordHash"]) for row in bundle["content"]["roots"]["history"]}


def event_observations(value):
    for row in value["events"]:
        log = row["log"]
        publication = {key: str(governance.quantity(log[key])) if key in ("blockNumber", "transactionIndex", "logIndex")
            else log[key] for key in ("blockHash", "blockNumber", "transactionHash", "transactionIndex", "logIndex")}
        yield publication, row["timestamp"], ("native_scoped_finality_event", log["address"],
            tuple(log["topics"]), log["data"])


def runtime_observations(value):
    for pin in value["graph"].values(): yield pin["address"], pin["runtimeHash"]
    for row in value["bundle"]["content"]["manifest"]["chunks"]: yield row["pointer"], row["codeHash"]
    for row in value["bundle"]["membership"]["parts"]: yield row["pointer"], row["codeHash"]
    execution = value["bundle"]["execution"]
    yield execution["callDataPointer"], keccak256(hex_bytes(execution["runtime"]))


def _definitions(value):
    expected = {row["id"]: row["bytes"] for row in wire.definitions()}
    actual = {row["documentId"]: hex_bytes(row["payloadHex"]) for row in value["definitions"]}
    require(len(actual) == len(value["definitions"]) and actual == expected,
        "scoped STATIC definition bytes differ")


def _original(raw, label):
    require(type(raw) is str and len(raw) <= 2 + 2 * MAX_ORIGINAL_BYTES,
        "scoped STATIC " + label + " byte bound")
    value = loads(hex_bytes(raw), maximum=MAX_ORIGINAL_BYTES, canonical=True)
    require(type(value) is dict, "scoped STATIC original " + label + " object")
    return value


def _normalized_transactions(value):
    """Validate retained raw transaction observations and return wire inputs.

    Full receipt/header/event closure is additionally enforced by the parent
    event join.  This function refuses to synthesize a missing transaction.
    """
    source = value["sourceState"]
    headers, numbers, placements = {}, {}, {}
    for raw in value["headers"]:
        header = _original(raw, "header")
        require(all(key in header for key in ("hash", "number", "timestamp", "parentHash", "stateRoot", "transactions")),
            "scoped STATIC original header fields missing")
        digest, number, stamp = header["hash"], governance.quantity(header["number"]), governance.quantity(header["timestamp"])
        require(any(hex_bytes(digest, 32)) and any(hex_bytes(header["stateRoot"], 32))
            and number <= uint(source["blockNumber"], 64) and stamp <= uint(source["timestamp"], 64),
            "scoped STATIC original header identity")
        require(bool(any(hex_bytes(header["parentHash"], 32))) == (number != 0),
            "scoped STATIC header parent shape")
        require(digest not in headers and number not in numbers, "scoped STATIC duplicate header identity")
        require(not numbers or number > max(numbers), "scoped STATIC header order")
        if number == uint(source["blockNumber"], 64):
            require(digest == source["blockHash"] and header["stateRoot"] == source["stateRoot"]
                and stamp == uint(source["timestamp"], 64), "scoped STATIC source header differs")
        transactions = header["transactions"]
        require(type(transactions) is list and len(transactions) <= governance.MAX_TRANSACTIONS_PER_BLOCK
            and len(set(transactions)) == len(transactions), "scoped STATIC header transaction bound/duplicates")
        for index, transaction_hash in enumerate(transactions):
            require(any(hex_bytes(transaction_hash, 32)) and transaction_hash not in placements,
                "scoped STATIC transaction placement differs")
            placements[transaction_hash] = (digest, number, index)
        headers[digest], numbers[number] = header, digest
    previous = None
    for number, digest in numbers.items():
        header = headers[digest]
        if previous is not None:
            old_number, old = previous
            require(governance.quantity(old["timestamp"]) <= governance.quantity(header["timestamp"]),
                "scoped STATIC header time regresses")
            if number == old_number + 1:
                require(header["parentHash"] == old["hash"], "scoped STATIC adjacent header parent differs")
        previous = number, header
    normalized, used, originals = {}, set(), {}
    expected_topics = {side: wire.EVENTS[name] for side, name in
        (("schedule", "governanceScheduled"), ("execution", "governanceExecuted"))}
    for side in ("schedule", "execution"):
        observation = value["transactions"][side]
        matches = [row for row in value["events"] if row["log"]["address"] == value["graph"]["executor"]["address"]
            and row["log"]["topics"][0] == expected_topics[side]]
        require(len(matches) == 1, "scoped STATIC original governance event")
        receipt = _original(observation["receiptBytes"], "receipt")
        transaction_hash, digest, number, index = governance._identity(receipt, receipt=True)
        expected_row, expected = matches[0], matches[0]["log"]
        require(receipt.get("status") == "0x1" and transaction_hash == expected["transactionHash"]
            and digest == expected["blockHash"] and number == governance.quantity(expected["blockNumber"])
            and index == governance.quantity(expected["transactionIndex"])
            and placements.get(transaction_hash) == (digest, number, index),
            "scoped STATIC original governance receipt/header differs")
        require(str(governance.quantity(headers[digest]["timestamp"])) == expected_row["timestamp"],
            "scoped STATIC governance event/header timestamp differs")
        used.add(digest)
        require(transaction_hash not in originals or originals[transaction_hash] == observation,
            "scoped STATIC repeated original transaction differs")
        originals[transaction_hash] = observation
        logs = receipt.get("logs")
        require(type(logs) is list and 0 < len(logs) <= governance.MAX_LOGS_PER_RECEIPT,
            "scoped STATIC complete receipt log bound")
        retained, last = {}, -1
        for raw_log in logs:
            log = _log(raw_log); log_index = governance.quantity(log["logIndex"])
            require(log_index > last and all(log[key] == receipt[key]
                for key in ("blockHash", "blockNumber", "transactionHash", "transactionIndex")),
                "scoped STATIC original receipt log coordinates/order differ")
            retained[log_index] = log; last = log_index
        for row in value["events"]:
            log = row["log"]
            if log["transactionHash"] == transaction_hash:
                require(retained.get(governance.quantity(log["logIndex"])) == log,
                    "scoped STATIC event missing/different in original receipt")
        if observation["status"] == "not_returned":
            require(observation["transactionBytes"] is None and observation["normalized"] is None,
                "scoped STATIC unavailable transaction carries fabricated input")
            normalized[side] = None
            continue
        transaction = _original(observation["transactionBytes"], "transaction")
        require(observation["normalized"] is not None and governance._identity(transaction) ==
            (transaction_hash, digest, number, index), "scoped STATIC original transaction identity differs")
        require(all(transaction[key] == receipt[key] for key in ("from", "to") if key in receipt),
            "scoped STATIC original transaction/receipt differs")
        if "chainId" in transaction:
            require(governance.quantity(transaction["chainId"]) == uint(source["chainId"]),
                "scoped STATIC original transaction chain differs")
        require("value" in transaction and "input" in transaction
            and len(hex_bytes(transaction["input"])) <= governance.wire.MAX_TRANSACTION_BYTES,
            "scoped STATIC original transaction fields missing")
        row = {"to": transaction["to"], "from": transaction["from"],
            "value": str(governance.quantity(transaction["value"])), "input": transaction["input"]}
        require(row == observation["normalized"], "scoped STATIC transaction normalization differs")
        normalized[side] = row
    require(used == set(headers), "scoped STATIC unrelated header supplied")
    return normalized


def validate(raw):
    """Validate exact supplied fields; capture replay and origin remain external."""
    try:
        value = loads(raw, maximum=MAX_BYTES, canonical=True)
        schema = loads(SCHEMA_BYTES, maximum=MAX_BYTES)
        Draft202012Validator(schema).validate(value); _typed(value, ref("fragment"), schema["$defs"])
        refs, source = value["sourceRef"], value["sourceState"]
        require(all(any(hex_bytes(refs[key], 32)) for key in SOURCE_REF_FIELDS[:-1]),
            "scoped STATIC source pin differs")
        require(all(uint(source[key]) > 0 for key in ("chainId", "collectionId", "tokenId"))
            and source["core"] != ZERO_ADDRESS
            and all(source[key] != ZERO for key in ("blockHash", "stateRoot", "deploymentEvidenceHash")),
            "scoped STATIC source identity")
        identity = value["identity"]
        require(identity["tokenId"] == source["tokenId"] and identity["collectionId"] == source["collectionId"]
            and uint(identity["collectionSerial"]) > 0 and (identity["lifecycle"] == "3") == identity["burned"],
            "scoped STATIC current token identity differs")
        membership = value["bundle"]["membership"]
        indices = [index for index, token in enumerate(membership["tokens"]) if token == source["tokenId"]]
        require(len(indices) == 1, "scoped STATIC target membership identity absent/duplicate")
        index = indices[0]; original_identity = membership["identities"][index]
        require(original_identity == [True, source["collectionId"], identity["collectionSerial"], identity["burned"]]
            and membership["lifecycles"][index] == identity["lifecycle"],
            "scoped STATIC current/member token identity differs")
        require(value["graph"]["core"]["address"] == source["core"], "scoped STATIC Core graph differs")
        bundle_report = wire.validate_bundle(value["bundle"], source, value["graph"])
        require(value["historicalCoreFacts"] == bundle_report["historicalCoreFacts"],
            "scoped STATIC historical Core hash differs")
        _definitions(value)
        wire.validate_event_join(value["bundle"], source, value["graph"], value["events"])
        normalized = _normalized_transactions(value)
        governance_report = wire.validate_governance(value["bundle"], source, value["graph"], normalized,
            value["events"])
        require(value["reconstruction"] == governance_report, "scoped STATIC reconstruction differs")
        proof = token_proof(value)
        wire.base.verify_proof(proof["leafHash"], uint(proof["leafIndex"]), uint(proof["leafCount"]),
            proof["proof"], proof["root"])
        runtimes = {}
        for address, digest in runtime_observations(value):
            require(address != ZERO_ADDRESS and digest != ZERO
                and runtimes.setdefault(address, digest) == digest,
                "scoped STATIC supplied runtime commitments differ")
        return value
    except MuseumError:
        raise
    except (ValidationError, ValueError, TypeError, KeyError, IndexError, OverflowError, RecursionError) as exc:
        raise MuseumError("invalid supplied scoped STATIC finality fragment") from exc


def _source_profile_hash():
    from tools.museum import public_scoped_finality_source as source
    require(source.PROFILE == SOURCE_PROFILE and source.SOURCE_REVISION == SOURCE_REVISION,
        "scoped STATIC source implementation differs")
    return source.PROFILE_HASH


def semanticProjection(snapshot, source_ref):
    """Project a verified source snapshot without authenticating it by itself."""
    try:
        require(type(source_ref) is dict and set(source_ref) == set(SOURCE_REF_FIELDS)
            and snapshot["profile"] == SOURCE_PROFILE and snapshot["profileHash"] == _source_profile_hash()
            and snapshot["sourceReviewCommit"] == SOURCE_REVISION and snapshot["version"] == "1",
            "scoped STATIC snapshot profile differs")
        require(source_ref == {"sourceProfileHash": snapshot["profileHash"], "anchorHash": snapshot["anchorHash"],
            "transcriptHash": snapshot["transcriptHash"], "snapshotHash": keccak256(dumps(snapshot)),
            "provenance": snapshot["provenance"]}, "scoped STATIC snapshot source reference differs")
        anchor = snapshot["source"]
        value = {"schema": NAME, "version": 1, "sourceRef": copy.deepcopy(source_ref),
            "sourceState": {key: anchor[key] for key in COMMON}, "claims": dict(CLAIMS),
            "qualification": QUALIFICATION}
        for key in ("graph", "identity", "bundle", "events", "definitions", "headers", "transactions",
                    "reconstruction", "historicalCoreFacts"):
            value[key] = copy.deepcopy(snapshot[key])
        return validate(dumps(value))
    except MuseumError:
        raise
    except (ValueError, TypeError, KeyError, IndexError, OverflowError, RecursionError) as exc:
        raise MuseumError("invalid scoped STATIC snapshot projection") from exc


def documents(): return {NAME: SCHEMA_BYTES}
def outputs(): return {"schemas/records/" + name + ".json": raw for name, raw in documents().items()}


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__); parser.add_argument("--check", action="store_true")
    args = parser.parse_args(argv)
    for path, raw in outputs().items():
        destination = ROOT / path
        if args.check:
            require(destination.is_file() and destination.read_bytes() == raw,
                "generated scoped STATIC finality bytes differ")
        else:
            destination.write_bytes(raw)
    print("Scoped STATIC finality supplied-data definition matches; source authentication remains separate.")


if __name__ == "__main__": main()

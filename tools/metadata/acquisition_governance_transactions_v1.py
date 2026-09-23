"""Additive supplied original governance transaction and action-preimage evidence."""
import argparse
import copy
from pathlib import Path

from jsonschema import Draft202012Validator
from jsonschema.exceptions import ValidationError

from . import acquisition_native_finality_v1 as native
from . import acquisition_packet_v4 as v4
from .acquisition_packet_v5 import _embed, _typed
from tools.museum import governance_transaction_wire as wire
from tools.museum.canonical import MuseumError, dumps, hex_bytes, keccak256, loads, uint
from tools.museum.chain_history import LOG_FIELDS, MAX_LOGS_PER_RECEIPT, MAX_TRANSACTIONS_PER_BLOCK
from tools.museum.chain_rpc import quantity
from tools.museum.independent_wire import ZERO_ADDRESS, require
from tools.museum.public_chain_history import _log, _matches

ROOT = Path(__file__).resolve().parents[2]
NAME = "STREAM_ACQUISITION_GOVERNANCE_TRANSACTIONS_V1"
SOURCE_PROFILE = "STREAM_MUSEUM_PUBLIC_GOVERNANCE_TRANSACTION_SOURCE_V1"
SOURCE_REVISION = native.SOURCE_REVISION
MAX_BYTES, MAX_ORIGINAL_BYTES = 32 * 1024 * 1024, 1024 * 1024
CHAIN_BOUND_BY = "source_anchor_and_block"
QUALIFICATION = ("Prospective unregistered supplied-data governance transaction evidence. The whole frozen "
    "native finality fragment remains unchanged. Original transaction input and receipt/header JSON bytes are "
    "retained observations, not signed transaction envelopes. Direct canonical Executor inputs can reconstruct "
    "ordered GovernanceCall metadata, batch transitions and the action-ID preimage. Missing transaction results "
    "and unsupported outer calls remain partial. Canonical ABI input and finite call/byte bounds are reader "
    "availability restrictions, not assertions that other calldata cannot execute natively. Transaction hashes, "
    "sender signatures, historical roles/policies/EVM execution, state/receipt tries and consensus are not "
    "verified. Complete preimages do not establish complete authority, current liveness or acquisition acceptance.")
RULES = [
    "Numeric version1 is additive. Frozen native-finality and packet V5/V6 bytes and claims are not changed or upgraded in place.",
    "Exactly original scheduling and execution receipt bytes are retained. A not_returned transaction means unavailable observed input, not proved pruning or an empty transaction. Duplicate transaction/header identities must preserve identical original bytes.",
    "The one or two original receipt headers are unique and ordered by height. Receipt/transaction identities, header transaction slots, complete retained receipt logs and all matching frozen native events agree. Only adjacent retained header parent links are checked; omitted ancestry is not inferred.",
    "The source anchor and block observations bind chain context. A present transaction chainId must equal that chain; an absent legacy field is not fabricated. Raw RPC JSON bytes and transaction input are not a signed transaction envelope or a cryptographically recomputed transaction hash.",
    "Supported direct schedule/execute inputs decode with exact canonical ABI and no trailing bytes. The availability limits are64 calls,131072 input bytes,32768 governed-call bytes and the frozen24576-byte carrier bound. Indirect Safe/forwarder or unknown outer selectors stay partial without invented inner calls.",
    "Original scheduling nonce comes from GovernanceActionScheduled, never transaction.nonce. Ordered calls determine callsHash, all three aggregate transition hashes and the original chain/Executor action-ID preimage. Stored target/selector index the first call and stored value is the complete batch sum.",
    "Reconstruction is complete only when both direct supported transaction inputs decode and agree. One available batch may independently recover call/action preimages while overall status remains partial. A lone single-execution input cannot recover missing per-call transition hashes from aggregate hashes.",
    "Historical sender roles, authorization, policy catalogs, bootstrap-delay exceptions and EVM execution are not reexecuted using current reads. The execution sender is retained as the original caller, not treated as an authorization proof.",
]


def ref(name): return {"$ref": "#/$defs/" + name}
def nullable(shape): return {"oneOf": [{"type": "null"}, shape]}
def closed(fields): return native.closed(fields)


def definitions():
    d = _embed(native, "native__")
    h, a, u = native.abi("bytes32"), native.abi("address"), native.abi("uint256")
    d["normalized"] = closed({"to": nullable(a), "from": a, "value": u, "input": native.blob(wire.MAX_TRANSACTION_BYTES)})
    d["transaction"] = closed({"status": {"enum": ["available", "not_returned"]},
        "transactionBytes": nullable(native.blob(MAX_ORIGINAL_BYTES)), "receiptBytes": native.blob(MAX_ORIGINAL_BYTES),
        "normalized": nullable(ref("normalized"))})
    d["call"] = closed({key: a if key == "target" else u if key == "value" else native.abi("bytes4") if key == "selector" else h
        for key in wire.CALL_FIELDS})
    d["finalityCall"] = closed({"index": u, **copy.deepcopy(d["call"]["properties"])})
    flags = ("fullGovernanceCallMetadataReconstructed", "actionIdPreimageReconstructed", "originalSchedulingTransactionDecoded",
        "originalExecutionTransactionDecoded", "bothOriginalTransactionInputsDecoded")
    false_flags = ("transactionHashesRecomputed", "transactionSenderSignatureVerified", "historicalRoleAuthorizationReexecuted",
        "historicalPolicyReexecuted", "historicalEvmExecutionReexecuted", "completeAuthority", "actualChainAcceptance")
    d["claims"] = closed({**{key: {"type": "boolean"} for key in flags}, **{key: {"const": False} for key in false_flags}})
    reasons = [side + suffix for side in ("schedule", "execution") for suffix in
        ("_transaction_unavailable", "_outer_recipient_not_executor", "_outer_selector_unsupported", "_unsupported_noncanonical_input")]
    reasons.append("single_execution_first_call_transitions_unavailable")
    d["reconstruction"] = closed({"status": {"enum": ["reconstructed", "partial"]},
        "reasons": native.array({"enum": reasons}, 3),
        "scheduleKind": {"enum": [None, "schedule_batch", "schedule_action"]},
        "executionKind": {"enum": [None, "execute_batch", "execute_action"]},
        "originalNonce": u, "calls": nullable(native.array(ref("call"), wire.MAX_CALLS, 1)),
        "callDatas": nullable(native.array(native.blob(wire.MAX_CALL_BYTES), wire.MAX_CALLS, 1)),
        "callsHash": nullable(h), "callsHashPreimage": nullable(native.blob(16384)),
        "aggregateTransitions": nullable(closed({key: h for key in ("scopeHash", "oldValueHash", "newValueHash")})),
        "actionId": h, "actionIdPreimage": nullable(native.blob(416)), "callDataKey": nullable(h),
        "claims": ref("claims"), "finalityCall": nullable(ref("finalityCall"))})
    d["fragment"] = closed({"schema": {"const": NAME}, "version": {"const": 1},
        "sourceRef": ref("native__sourceRef"), "sourceState": ref("native__sourceState"),
        "nativeFinality": ref("native__fragment"), "headers": native.array(native.blob(MAX_ORIGINAL_BYTES), 2, 1),
        "transactions": closed({key: ref("transaction") for key in ("schedule", "execution")}),
        "chainBoundBy": {"const": CHAIN_BOUND_BY}, "reconstruction": ref("reconstruction"),
        "qualification": {"const": QUALIFICATION}})
    return d


def schema_document_bytes():
    return dumps({"$schema": "https://json-schema.org/draft/2020-12/schema", "$id": "urn:6529stream:schema:" + NAME,
        "title": NAME, "description": QUALIFICATION, **ref("fragment"), "$defs": definitions(),
        "x-stream-native-finality": {"name": native.NAME, "hash": native.SCHEMA_HASH},
        "x-stream-source-review": SOURCE_REVISION, "x-stream-constraints": RULES})


SCHEMA_BYTES = schema_document_bytes()
SCHEMA_HASH = keccak256(SCHEMA_BYTES)


def _original(raw, label):
    require(type(raw) is str and len(raw) <= 2 + MAX_ORIGINAL_BYTES * 2, "governance " + label + " byte bound")
    value = loads(hex_bytes(raw), maximum=MAX_ORIGINAL_BYTES, canonical=True)
    require(type(value) is dict, "governance original " + label + " object")
    return value


def _identity(row, *, receipt=False):
    hash_key = "transactionHash" if receipt else "hash"
    required = (hash_key, "blockHash", "blockNumber", "transactionIndex") + (() if receipt else ("from", "to"))
    require(all(key in row for key in required),
        "governance original transaction/receipt fields missing")
    for key in (hash_key, "blockHash"): require(any(hex_bytes(row[key], 32)), "governance original zero transaction/block hash")
    if "from" in row: require(any(hex_bytes(row["from"], 20)), "governance original zero sender")
    if "to" in row: require(row["to"] is None or bool(any(hex_bytes(row["to"], 20))), "governance original recipient")
    return row[hash_key], row["blockHash"], quantity(row["blockNumber"]), quantity(row["transactionIndex"])


def _observations(value):
    s, fragment = value["sourceState"], value["nativeFinality"]
    observed = v4._Observations({"blockNumber": s["blockNumber"], "blockHash": s["blockHash"], "examinedAt": s["timestamp"]}, s["timestamp"])
    for publication, stamp, identity in native.event_observations(fragment): observed.add(publication, stamp, identity)
    filters, original_logs = {}, {}
    topics = native.wire.EVENTS
    short = {topics[name]: 2 for name in ("checkpointLeaf", "finalized", "coverageCompleted", "governanceScheduled", "governanceExecuted")}
    short[topics["root"]] = 3
    for row in fragment["events"]:
        log = row["log"]; terms = log["topics"][:short.get(log["topics"][0], len(log["topics"]))]
        filt = {"address": log["address"], "topics": terms}; filters[dumps(filt)] = filt
        original_logs[(log["blockHash"], log["transactionHash"], log["logIndex"])] = log
    headers, numbers, placements = {}, {}, {}
    for raw in value["headers"]:
        header = _original(raw, "header")
        require(all(key in header for key in ("hash", "number", "timestamp", "parentHash", "stateRoot", "transactions")),
            "governance original header fields missing")
        digest, number, stamp = header["hash"], quantity(header["number"]), quantity(header["timestamp"])
        require(any(hex_bytes(digest, 32)) and any(hex_bytes(header["stateRoot"], 32)), "governance header commitment")
        require(bool(any(hex_bytes(header["parentHash"], 32))) == (number != 0), "governance header parent shape")
        require(number < 1 << 64 and number <= uint(s["blockNumber"], 64) and stamp < 1 << 64 and stamp <= uint(s["timestamp"], 64),
            "governance header beyond source")
        require(digest not in headers and number not in numbers, "governance duplicate header identity")
        require(not numbers or number > max(numbers), "governance header order")
        if number == uint(s["blockNumber"], 64):
            require(digest == s["blockHash"] and header["stateRoot"] == s["stateRoot"] and stamp == uint(s["timestamp"], 64),
                "governance source header differs")
        require(observed.numbers.get(number, digest) == digest and observed.hashes.get(digest, number) == number
            and observed.times.get(number, stamp) == stamp, "governance frozen header observation differs")
        txs = header["transactions"]
        require(type(txs) is list and len(txs) <= MAX_TRANSACTIONS_PER_BLOCK and len(set(txs)) == len(txs), "governance header transaction bound/duplicates")
        for index, tx in enumerate(txs):
            require(any(hex_bytes(tx, 32)) and tx not in placements, "governance header transaction placement differs")
            placements[tx] = (digest, number, index)
        headers[digest], numbers[number] = header, digest
    previous = None
    for number, digest in numbers.items():
        h = headers[digest]
        if previous:
            n, parent = previous
            require(quantity(parent["timestamp"]) <= quantity(h["timestamp"]), "governance header time regresses")
            if number == n + 1: require(h["parentHash"] == parent["hash"], "governance adjacent header parent differs")
        previous = number, h
    used_headers, originals, normalized = set(), {}, {}
    for side, event_name in (("schedule", "governanceScheduled"), ("execution", "governanceExecuted")):
        observation = value["transactions"][side]
        expected = next(row["log"] for row in fragment["events"] if row["log"]["topics"][0] == native.wire.EVENTS[event_name])
        receipt = _original(observation["receiptBytes"], "receipt")
        tx, digest, number, index = _identity(receipt, receipt=True)
        require(receipt.get("status") == "0x1" and tx == expected["transactionHash"]
            and digest == expected["blockHash"] and number == quantity(expected["blockNumber"])
            and index == quantity(expected["transactionIndex"]), "governance original event receipt differs")
        require(digest in headers and placements.get(tx) == (digest, number, index), "governance receipt/header transaction slot differs")
        used_headers.add(digest)
        require(tx not in originals or originals[tx] == observation, "governance repeated original transaction differs")
        originals[tx] = observation
        rows = receipt.get("logs")
        require(type(rows) is list and 0 < len(rows) <= MAX_LOGS_PER_RECEIPT, "governance complete receipt log bound")
        retained, last = {}, -1
        for row in rows:
            log = _log(row); j = quantity(log["logIndex"])
            require(j > last and all(log[key] == receipt[key] for key in ("blockHash", "blockNumber", "transactionHash", "transactionIndex")),
                "governance original receipt log coordinates/order differ")
            last = j; retained[j] = log
            if any(_matches(log, filt) for filt in filters.values()):
                require(original_logs.get((log["blockHash"], log["transactionHash"], log["logIndex"])) == log,
                    "governance retained receipt discloses omitted native event")
            publication = {key: str(quantity(log[key])) if key in ("blockNumber", "transactionIndex", "logIndex") else log[key]
                for key in ("blockHash", "blockNumber", "transactionHash", "transactionIndex", "logIndex")}
            identity = ("native_finality_event", log["address"], tuple(log["topics"]), log["data"])
            observed.add(publication, str(quantity(headers[digest]["timestamp"])), identity)
        for row in fragment["events"]:
            log = row["log"]
            if log["transactionHash"] == tx:
                require(retained.get(quantity(log["logIndex"])) == log, "governance frozen event missing/different in original receipt")
        if observation["status"] == "not_returned":
            require(observation["transactionBytes"] is None and observation["normalized"] is None,
                "governance unavailable transaction carries fabricated input")
            normalized[side] = None
            continue
        require(observation["transactionBytes"] is not None and observation["normalized"] is not None,
            "governance available transaction input missing")
        transaction = _original(observation["transactionBytes"], "transaction")
        require(_identity(transaction) == (tx, digest, number, index)
            and all(transaction[key] == receipt[key] for key in ("from", "to") if key in receipt), "governance original transaction/receipt differs")
        if "chainId" in transaction:
            require(quantity(transaction["chainId"]) == uint(s["chainId"]), "governance original transaction chain differs")
        require("value" in transaction and "input" in transaction, "governance original transaction input/value missing")
        require(len(hex_bytes(transaction["input"])) <= wire.MAX_TRANSACTION_BYTES, "governance original transaction input bound")
        norm = {"to": transaction["to"], "from": transaction["from"], "value": str(quantity(transaction["value"])), "input": transaction["input"]}
        require(norm == observation["normalized"], "governance original normalization differs")
        normalized[side] = norm
    require(used_headers == set(headers), "governance unrelated header supplied")
    observed.finish()
    return normalized


def validate(raw):
    """Return the recomputed report; this validates supplied observations, not their origin."""
    try:
        value = loads(raw, maximum=MAX_BYTES, canonical=True)
        schema = loads(SCHEMA_BYTES, maximum=MAX_BYTES)
        Draft202012Validator(schema).validate(value); _typed(value, ref("fragment"), schema["$defs"])
        require(all(any(hex_bytes(value["sourceRef"][key], 32)) for key in native.SOURCE_REF_FIELDS[:-1]), "governance zero source reference")
        fragment = native.validate(dumps(value["nativeFinality"]))
        require(value["sourceState"] == fragment["sourceState"], "governance source/native finality state differs")
        require(value["sourceRef"]["provenance"] == fragment["sourceRef"]["provenance"], "governance source provenance differs")
        normalized = _observations(value)
        report = wire.verify(fragment["bundle"], value["sourceState"], fragment["graph"], normalized, fragment["events"])
        require(report == value["reconstruction"], "governance derived reconstruction differs")
        return report
    except MuseumError: raise
    except (ValidationError, ValueError, TypeError, KeyError, IndexError, OverflowError, RecursionError) as exc:
        raise MuseumError("invalid supplied governance transaction evidence") from exc


def _project(snapshot, source_ref):
    from tools.museum import public_governance_transaction_source as source
    require(source.PROFILE == SOURCE_PROFILE and source.SOURCE_REVISION == SOURCE_REVISION,
        "governance source implementation differs")
    require(type(source_ref) is dict and set(source_ref) == set(native.SOURCE_REF_FIELDS)
        and snapshot["profile"] == SOURCE_PROFILE and snapshot["profileHash"] == source.PROFILE_HASH
        and snapshot["version"] == "1" and snapshot["sourceReviewCommit"] == SOURCE_REVISION,
        "governance snapshot profile differs")
    require(source_ref == {"sourceProfileHash": source.PROFILE_HASH, "anchorHash": snapshot["anchorHash"],
        "transcriptHash": snapshot["transcriptHash"], "snapshotHash": keccak256(dumps(snapshot)), "provenance": snapshot["provenance"]},
        "governance snapshot source reference differs")
    value = {"schema": NAME, "version": 1, "sourceRef": copy.deepcopy(source_ref),
        "chainBoundBy": CHAIN_BOUND_BY, "qualification": QUALIFICATION}
    for key in ("sourceState", "nativeFinality", "headers", "transactions", "reconstruction"):
        value[key] = copy.deepcopy(snapshot[key])
    validate(dumps(value))
    return value


def semanticProjection(snapshot, source_ref):
    """Derive a new fragment without altering the embedded frozen finality object."""
    try:
        return _project(snapshot, source_ref)
    except MuseumError: raise
    except (ValueError, TypeError, KeyError, IndexError, OverflowError, RecursionError) as exc:
        raise MuseumError("invalid governance transaction snapshot projection") from exc


def documents(): return {NAME: SCHEMA_BYTES}
def outputs(): return {"schemas/records/" + name + ".json": raw for name, raw in documents().items()}


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__); parser.add_argument("--check", action="store_true")
    args = parser.parse_args(argv)
    for path, raw in outputs().items():
        destination = ROOT / path
        if args.check: require(destination.is_file() and destination.read_bytes() == raw, "generated governance transaction definition differs")
        else: destination.write_bytes(raw)
    print("Governance transaction supplied-data definition matches; historical authority remains unproved.")


if __name__ == "__main__": main()

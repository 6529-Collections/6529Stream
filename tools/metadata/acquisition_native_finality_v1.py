"""Original native collection finality: closed supplied-data ABI and commitment joins."""
import argparse
import copy
from pathlib import Path

from jsonschema import Draft202012Validator
from jsonschema.exceptions import ValidationError

from tools.museum import native_finality_wire as wire
from tools.museum.canonical import MuseumError, dumps, hex_bytes, keccak256, loads, subject_id, uint
from tools.museum.chain_abi import Array
from tools.museum.chain_rpc import quantity
from tools.museum.independent_wire import ZERO, ZERO_ADDRESS, require
from . import acquisition_packet_v4 as v4

ROOT = Path(__file__).resolve().parents[2]
NAME = "STREAM_ACQUISITION_NATIVE_FINALITY_V1"
SOURCE_PROFILE = "STREAM_MUSEUM_PUBLIC_COLLECTION_FINALITY_SOURCE_V1"
SOURCE_REVISION = "e031ce6f5f7a79f8c098d4ad0242ee02ce1b0116"
MAX_BYTES, MAX_EVENTS = 16 * 1024 * 1024, 8192
SOURCE_REF_FIELDS = ("sourceProfileHash", "anchorHash", "transcriptHash", "snapshotHash", "provenance")
COMMON = ("chainId", "core", "collectionId", "tokenId", "blockHash", "blockNumber", "timestamp", "stateRoot", "environment", "deploymentEvidenceHash")
GRAPH_KEYS = ("core", "artist", "router", "finality", "provider", "metadata", "schemas", "leafManifest", "checkpoint", "artifacts", "inventory", "store", "executor", "roles")
CLAIMS = {"completeAuthority": False, "batchCallMetadataVerified": False,
    "executionTransactionInputCaptured": False, "sourceAuthenticated": False,
    "historicalCoreFactsPreimageRecovered": False}
QUALIFICATION = ("Prospective unregistered native finality supplied-data fragment. The original collection "
    "finality receipt, typed manifest and components, Executor witness, root publication and complete "
    "inline-ONCHAIN leaf manifest remain native evidence. Historical Core facts retain only their original "
    "hash; their fields are not invented from current state. Root publisher authority, Artist consent and "
    "Executor/proposer authority are separate. Supplied hashes, ABI encodings, event coordinates and "
    "Merkle membership are checked without source replay, signature verification, historical execution, "
    "current archive/readiness revalidation, runtime admission, consensus or acquisition acceptance. "
    "A stored batch's first-call fields do not establish every call's metadata. No generic record authority "
    "or absence proof is synthesized. Other finality scopes and content profiles remain unsupported.")
RULES = [
    "Numeric version1 identifies this standalone fragment; sourceRef retains closed nonzero source-profile and original anchor/transcript/snapshot pins with explicit provenance, excluding a circular capture-manifest pin. Only the projector checks the named source implementation; generic validation cannot authenticate these pins.",
    "The supported native profile is artist-bound COLLECTION and inline ONCHAIN. Canonical ABI re-encoding, original domains and exact schema definition bytes are checked by the pinned native wire helper.",
    "Finality, input-manifest, root, checkpoint, verified leaf manifest and preserved artifact hashes join original evidence. Current Core facts never replace historical coreFactsHash.",
    "Root and Finality publication authority retain their different native tuples. No numeric legacy authorityClass, generic record signer or historical governance batch preimage is invented.",
    "The complete ordered leaf manifest is bounded by320+192*N<=524288 and N<=2729. Odd tree nodes are promoted without sorting or duplication; target proof direction derives only from index and count.",
    "The required original event subset has unique positions and corresponds to its native tuples. Checkpoint completion precedes leaf-manifest verification, the selected final root precedes finality, and original root/finality timestamps equal their publication observations. Scheduled calldata publication precedes scheduling; the five finality emissions are adjacent in the original execution transaction. This subset does not claim all progress events or all receipts. Conflicting event positions and source-time observations fail.",
    "Source references and runtime commitments are supplied observations, not self-authenticating evidence. Capture replay and external runtime/provenance admission belong to the caller.",
]


def closed(properties):
    return {"type": "object", "properties": properties, "required": list(properties), "additionalProperties": False}


def ref(name): return {"$ref": "#/$defs/" + name}
def array(shape, maximum, minimum=0): return {"type": "array", "items": shape, "minItems": minimum, "maxItems": maximum}
def blob(maximum): return {"type": "string", "pattern": "^0x(?:[0-9a-f]{2})*(?![\\s\\S])", "maxLength": 2 + 2 * maximum}


def abi(kind):
    if isinstance(kind, Array): return array(abi(kind.item), kind.maximum)
    if isinstance(kind, tuple):
        return {"type": "array", "prefixItems": [abi(k) for k in kind], "items": False,
            "minItems": len(kind), "maxItems": len(kind)}
    if kind == "bool": return {"type": "boolean"}
    if kind == "bytes": return blob(wire.MAX_CALLDATA)
    if kind == "string": return {"type": "string", "maxLength": wire.MAX_CALLDATA,
        "x-stream-max-utf8-bytes": wire.MAX_CALLDATA}
    if kind.startswith("uint"):
        return {"type": "string", "pattern": "^(0|[1-9][0-9]*)(?![\\s\\S])", "maxLength": 78,
            "x-stream-uint-bits": int(kind[4:])}
    length = 20 if kind == "address" else int(kind[5:])
    return {"type": "string", "pattern": "^0x[0-9a-f]{" + str(length * 2) + "}(?![\\s\\S])"}


def definitions():
    h, a = abi("bytes32"), abi("address")
    d = {"sourceRef": closed({**{key: h for key in SOURCE_REF_FIELDS[:-1]},
        "provenance": {"enum": ["synthetic_fixture", "trusted_rpc"]}})}
    d["sourceState"] = closed({key: a if key == "core" else h if key in ("blockHash", "stateRoot", "deploymentEvidenceHash")
        else {"enum": ["local_evm_fixture", "public_chain"]} if key == "environment"
        else abi("uint64" if key in ("blockNumber", "timestamp") else "uint256") for key in COMMON})
    d["graph"] = closed({key: closed({"address": a, "runtimeHash": h}) for key in GRAPH_KEYS})
    d["identity"] = closed({"tokenId": abi("uint256"), "collectionId": abi("uint256"), "collectionSerial": abi("uint256"),
        "lifecycle": {"enum": ["2", "3"]}, "burned": {"type": "boolean"}})
    d["finality"] = closed({"record": abi(wire.FINALITY_RECORD), "components": array(abi(wire.COMPONENT), 32, 1),
        "manifestRef": abi(wire.MANIFEST_REF), "manifestBytes": blob(wire.MAX_MANIFEST),
        "executionWitness": abi(wire.EXECUTION_WITNESS), "archiveWitness": abi(wire.ARCHIVE_WITNESS), "inputsHash": h})
    d["content"] = closed({"selectedRootHash": h, "rootHead": h,
        "rootHistory": array(closed({"recordHash": h, "record": abi(wire.ROOT_RECORD)}), wire.MAX_ROOT_HISTORY, 1),
        "manifest": closed({"recordHash": h, "planHash": h, "record": abi(wire.LEAF_MANIFEST), "plan": abi(wire.LEAF_PLAN)}),
        "checkpoint": closed({"planHash": h, "profile": {"const": wire.INLINE_PROFILE}, "plan": abi(wire.CHECKPOINT),
            "leaves": array(abi(wire.LEAF), wire.MAX_LEAVES, 1)}),
        "artifact": closed({"artifactHash": h, "artifact": abi(wire.ARTIFACT), "coverage": abi(wire.COVERAGE),
            "chunks": array(closed({"pointer": a, "codeHash": h, "runtime": blob(wire.CHUNK_BYTES + 1)}), wire.MAX_CHUNKS, 1)})})
    d["execution"] = closed({"action": abi(wire.GOVERNANCE_ACTION), "callDataPointer": a,
        "callDatas": array(blob(wire.MAX_CALLDATA), 64, 1), "runtime": blob(24576)})
    d["bundle"] = closed({"finality": ref("finality"), "content": ref("content"), "execution": ref("execution")})
    q = {"type": "string", "pattern": "^0x(?:0|[1-9a-f][0-9a-f]*)(?![\\s\\S])", "maxLength": 66}
    d["log"] = closed({"address": a, "blockHash": h, "blockNumber": q, "data": blob(65536), "logIndex": q,
        "topics": array(h, 4, 1), "transactionHash": h, "transactionIndex": q})
    d["event"] = closed({"log": ref("log"), "timestamp": abi("uint64")})
    d["definition"] = closed({"documentId": h, "payloadHex": blob(8192)})
    d["historicalCoreFacts"] = closed({"status": {"const": "hash_only"}, "hash": h, "preimage": {"type": "null"}})
    d["fragment"] = closed({"schema": {"const": NAME}, "version": {"const": 1}, "sourceRef": ref("sourceRef"),
        "sourceState": ref("sourceState"), "graph": ref("graph"), "identity": ref("identity"), "bundle": ref("bundle"),
        "events": array(ref("event"), MAX_EVENTS, 1), "definitions": array(ref("definition"), 6, 6),
        "historicalCoreFacts": ref("historicalCoreFacts"), "claims": {"const": CLAIMS}, "qualification": {"const": QUALIFICATION}})
    d["tokenProof"] = closed({"kind": {"const": "native_token_content_proof"}, "subjectId": h, "scope": abi(wire.SCOPE),
        "rootRecordHash": h, "manifestHash": h, "root": h, "leafCount": abi("uint64"), "leafIndex": abi("uint64"),
        "leaf": abi(wire.LEAF), "leafHash": h, "proof": array(h, 12)})
    return d


def schema_document_bytes():
    return dumps({"$schema": "https://json-schema.org/draft/2020-12/schema", "$id": "urn:6529stream:schema:" + NAME,
        "title": NAME, "description": QUALIFICATION, **ref("fragment"), "$defs": definitions(),
        "x-stream-source-profile": SOURCE_PROFILE, "x-stream-source-review": SOURCE_REVISION, "x-stream-constraints": RULES})


SCHEMA_BYTES = schema_document_bytes()
SCHEMA_HASH = keccak256(SCHEMA_BYTES)


def token_proof(value):
    s, content = value["sourceState"], value["bundle"]["content"]
    leaves = wire.from_json(Array(wire.LEAF, wire.MAX_LEAVES), content["checkpoint"]["leaves"])
    matches = [i for i, leaf in enumerate(leaves) if leaf[0] == uint(s["tokenId"])]
    require(len(matches) == 1, "native finality target leaf missing/duplicate")
    i = matches[0]; leaf = leaves[i]; manifest = content["manifest"]["record"]
    return {"kind": "native_token_content_proof", "subjectId": subject_id("token", s["chainId"], s["core"], s["collectionId"], token_id=s["tokenId"]),
        "scope": ["0", s["collectionId"], "0", ZERO], "rootRecordHash": content["selectedRootHash"], "manifestHash": manifest[5],
        "root": manifest[4], "leafCount": str(len(leaves)), "leafIndex": str(i), "leaf": copy.deepcopy(content["checkpoint"]["leaves"][i]),
        "leafHash": wire.leaf_hash(uint(s["chainId"]), s["core"], leaf),
        "proof": list(wire.proof_for(uint(s["chainId"]), s["core"], leaves, i))}


def native_record_keys(value):
    return {(value["graph"]["finality"]["address"], value["bundle"]["finality"]["record"][1])} | {
        (value["graph"]["router"]["address"], row["recordHash"]) for row in value["bundle"]["content"]["rootHistory"]}


def event_observations(value):
    for row in value["events"]:
        log = row["log"]
        publication = {key: str(quantity(log[key])) if key in ("blockNumber", "transactionIndex", "logIndex") else log[key]
            for key in ("blockHash", "blockNumber", "transactionHash", "transactionIndex", "logIndex")}
        yield publication, row["timestamp"], ("native_finality_event", log["address"], tuple(log["topics"]), log["data"])


def runtime_observations(value):
    for pin in value["graph"].values(): yield pin["address"], pin["runtimeHash"]
    for row in value["bundle"]["content"]["artifact"]["chunks"]: yield row["pointer"], row["codeHash"]
    execution = value["bundle"]["execution"]
    yield execution["callDataPointer"], keccak256(hex_bytes(execution["runtime"]))


def _source_profile_hash():
    from tools.museum import public_finality_source as source
    require(source.PROFILE == SOURCE_PROFILE and source.SOURCE_REVISION == SOURCE_REVISION, "native finality source implementation differs")
    return source.PROFILE_HASH


def validate(raw):
    """Validate supplied native fields. Source/capture authentication remains external."""
    try:
        value = loads(raw, maximum=MAX_BYTES, canonical=True)
        schema = loads(SCHEMA_BYTES, maximum=MAX_BYTES)
        Draft202012Validator(schema).validate(value)
        # V5's typed walker handles fixed ABI arrays and width annotations.
        from .acquisition_packet_v5 import _typed
        _typed(value, ref("fragment"), schema["$defs"])
        s, refs = value["sourceState"], value["sourceRef"]
        require(all(any(hex_bytes(refs[key], 32)) for key in SOURCE_REF_FIELDS[:-1]), "native finality source pin differs")
        require(all(uint(s[key]) > 0 for key in ("chainId", "collectionId", "tokenId"))
            and s["core"] != ZERO_ADDRESS and all(s[k] != ZERO for k in ("blockHash", "stateRoot", "deploymentEvidenceHash")), "native finality source identity")
        i = value["identity"]
        require(i["tokenId"] == s["tokenId"] and i["collectionId"] == s["collectionId"] and uint(i["collectionSerial"]) > 0
            and (i["lifecycle"] == "3") == i["burned"], "native finality current token identity differs")
        require(value["graph"]["core"]["address"] == s["core"], "native finality Core graph differs")
        result = wire.validate_bundle(value["bundle"], s, value["graph"])
        require(value["historicalCoreFacts"] == result["historicalCoreFacts"], "native finality historical Core hash differs")
        _definitions(value)
        _events(value)
        _observations(value)
        proof = token_proof(value)
        wire.verify_proof(proof["leafHash"], uint(proof["leafIndex"]), uint(proof["leafCount"]), proof["proof"], proof["root"])
        return value
    except MuseumError: raise
    except (ValidationError, ValueError, TypeError, KeyError, IndexError, OverflowError, RecursionError) as exc:
        raise MuseumError("invalid supplied native finality fragment") from exc


def _definitions(value):
    expected = {row["id"]: row["bytes"] for row in wire.definitions()}
    actual = {row["documentId"]: hex_bytes(row["payloadHex"]) for row in value["definitions"]}
    require(len(actual) == len(value["definitions"]) and actual == expected, "native finality definition bytes differ")


def _events(value):
    wire.validate_event_join(value["bundle"], value["sourceState"], value["graph"], value["events"])


def _observations(value):
    s = value["sourceState"]
    observed_state = {"blockNumber": s["blockNumber"], "blockHash": s["blockHash"], "examinedAt": s["timestamp"]}
    obs = v4._Observations(observed_state, s["timestamp"])
    previous = None
    for row, stamp, identity in event_observations(value):
        order = tuple(uint(row[k]) for k in ("blockNumber", "transactionIndex", "logIndex"))
        require(previous is None or order > previous, "native finality events must be strictly ordered")
        previous = order
        obs.add(row, stamp, identity)
    obs.finish()
    codes = {}
    for address, digest in runtime_observations(value):
        require(address != ZERO_ADDRESS and digest != ZERO and codes.setdefault(address, digest) == digest,
            "native finality supplied runtime commitments differ")


def semanticProjection(snapshot, source_ref):
    """Project the exact supplied source snapshot; this operation does not replay it."""
    try:
        require(type(source_ref) is dict and set(source_ref) == set(SOURCE_REF_FIELDS)
            and snapshot["profile"] == SOURCE_PROFILE and snapshot["profileHash"] == _source_profile_hash()
            and snapshot["sourceReviewCommit"] == SOURCE_REVISION and snapshot["version"] == "1", "native finality snapshot profile differs")
        anchor = snapshot["source"]
        require(source_ref["sourceProfileHash"] == snapshot["profileHash"]
            and source_ref["anchorHash"] == snapshot["anchorHash"]
            and source_ref["transcriptHash"] == snapshot["transcriptHash"]
            and source_ref["snapshotHash"] == keccak256(dumps(snapshot)), "native finality snapshot reference differs")
        require(source_ref["provenance"] == snapshot["provenance"], "native finality source provenance differs")
        value = {"schema": NAME, "version": 1, "sourceRef": copy.deepcopy(source_ref),
            "sourceState": {key: anchor[key] for key in COMMON}, "claims": dict(CLAIMS), "qualification": QUALIFICATION}
        for key in ("graph", "identity", "bundle", "events", "definitions", "historicalCoreFacts"):
            value[key] = copy.deepcopy(snapshot[key])
        return validate(dumps(value))
    except MuseumError: raise
    except (ValueError, TypeError, KeyError, IndexError, OverflowError, RecursionError) as exc:
        raise MuseumError("invalid native finality snapshot projection") from exc


def documents(): return {NAME: SCHEMA_BYTES}
def outputs(): return {"schemas/records/" + name + ".json": raw for name, raw in documents().items()}


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__); parser.add_argument("--check", action="store_true")
    args = parser.parse_args(argv)
    for path, raw in outputs().items():
        destination = ROOT / path
        if args.check: require(destination.is_file() and destination.read_bytes() == raw, "generated native finality bytes differ")
        else: destination.write_bytes(raw)
    print("Native finality supplied-data definition matches; source authentication remains separate.")


if __name__ == "__main__": main()

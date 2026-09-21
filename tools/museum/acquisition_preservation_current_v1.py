"""Current preservation evidence for acquisition packet fields 8 and 11.

The generic native preservation host stores hash references and exact records;
it does not store typed fixity-cycle or drill payload bytes. This consumer
projects only authenticated empty histories and independently replayed current
VIEW Archive correspondence. Non-empty generic histories remain retained and
semantically unresolved.
"""
from dataclasses import dataclass

from . import canonical_composition_observations_v1 as composition
from . import native_view_preservation_wire_v1 as preservation
from . import public_chain_history as public_history
from . import public_history_rpc as rpc
from . import view_preservation_retrieval_v1 as retrieval
from . import view_preservation_retrieval_wire_v1 as retrieval_wire
from .canonical import MuseumError, dumps, hex_bytes, keccak256, schema_id, uint
from .chain_abi import calldata, decode, encode
from .independent_wire import ZERO, ZERO_ADDRESS, json_values, require


NAME = "STREAM_MUSEUM_ACQUISITION_PRESERVATION_CURRENT_V1"
SOURCE_REVISION = "ec832e8674965a30c571d55cc39efdbd0db9e727"
SOURCE_BLOBS = {
    "smart-contracts/domains/preservation/StreamPreservationRecords.sol":
        "dc1c96e433db6c6a943bd8533615d1c1d2e186f2677ce564a18c59211577a648",
    "smart-contracts/interfaces/stream/preservation/IStreamPreservationRecords.sol":
        "699e2dd62061702633d00a5e70afde86b00da36b76f5259aad384ebe82b92ef6",
    "smart-contracts/domains/metadata/StreamMetadataRenderer.sol":
        "c6f1bb1c688c1ebca80eef1d36ac74e58e7737d31ea485d9ae4d7bd6235d6b3a",
}
MAX_HISTORY = 4096
JCS = schema_id("RFC8785_JCS")
FIXITY_CYCLE = schema_id("FIXITY_CYCLE_COMPLETED")
SCRIPT_DRILL = schema_id("PRESERVATION_DRILL")
HASH_REF = ("uint16", "bytes", "bytes32")
RECORD = ("bytes32", "bytes32", HASH_REF, "string", "bytes32", "bytes32", HASH_REF, "uint64")
SUMMARY = ("uint256", "bytes32", "bytes32", "bytes32", "uint16", "bytes32", "bytes32",
    "string", "bytes32", "bytes32", "bytes32", "uint16", "bytes32", "bytes32",
    "uint64", "address", "uint64", "uint8")
EVENT = schema_id("CollectionRecordRecorded(uint256,bytes32,bytes32,(bytes32,bytes32,(uint16,bytes,bytes32),string,bytes32,bytes32,(uint16,bytes,bytes32),uint64),bytes32,address,uint8)")
MODULE_FAMILY = schema_id("6529stream.module.preservation-records")
MODULE_VERSION = schema_id("6529stream.module.preservation-records.v2")
MODULE_SCHEMA = schema_id("6529stream.preservation-records.schema.v2")

CLAIMS = {"currentArchiveCorrespondenceReplayed": False,
    "completeRecordTypeHistoriesReplayed": True, "emptyHistoryAuthenticated": True,
    "latestFixityCycleSemanticsProven": False, "preservationDrillSemanticsProven": False,
    "networkRetrievalPerformed": False, "nativeExecutionProven": False,
    "historicalSignatureAuthorizationProven": False, "archiveConsensusProven": False}
QUALIFICATION = (
    "Current Archive correspondence is inherited only from complete replay of the exact VIEW "
    "retrieval consumer. Complete block-zero-through-anchor log queries and matching native "
    "record, summary and latest getters authenticate each generic preservation-record history "
    "for the supplied exact module. No current native registry selects that module as the global "
    "fixity-cycle or drill authority, so even an empty supplied-host history is not projected as "
    "global none-recorded or never-drilled. "
    "The frozen source registers no FIXITY_CYCLE_COMPLETED or preservation-drill payload schema "
    "and this host stores no payload preimage for those generic records. Non-empty histories "
    "remain retained and unresolved; fixities and reference renders are never relabeled. Provider "
    "observations do not authenticate RPC provenance, signatures, delivery or consensus.")
PROFILE_BYTES = dumps({"name": NAME, "version": "1", "sourceRevision": SOURCE_REVISION,
    "sourceBlobs": SOURCE_BLOBS,
    "retrievalProfileHash": retrieval.PROFILE_HASH,
    "nativeRecordHost": "StreamPreservationRecords exact event/record/summary/latest evidence",
    "recordTypes": {"fixityCycle": FIXITY_CYCLE, "scriptDrill": SCRIPT_DRILL},
    "bounds": {"recordsPerType": str(MAX_HISTORY)}, "claims": CLAIMS,
    "qualification": QUALIFICATION})
PROFILE_HASH = keccak256(PROFILE_BYTES)
OUTPUT_PREFIX = "preservation-current/"
PROFILE_PATH = OUTPUT_PREFIX + "profile.json"
PRESERVATION_PATH = OUTPUT_PREFIX + "preservation.json"
DRILL_PATH = OUTPUT_PREFIX + "script-drill.json"
REPORT_PATH = OUTPUT_PREFIX + "report.json"


@dataclass(frozen=True)
class PreservationCurrentResult:
    files: dict[str, bytes]
    report: dict
    observations: list[dict]


def _closed(value, keys, label):
    require(type(value) is dict and set(value) == set(keys), "current preservation " + label + " shape")


def _hash_ref(value):
    require(type(value) is list and len(value) == 3, "current preservation HashRef shape")
    algorithm, digest = uint(value[0], 16), hex_bytes(value[1])
    require(1 <= algorithm <= 6 and 0 < len(digest) <= 128
        and ((algorithm in (1, 2, 3, 6) and len(digest) == 32)
             or algorithm in (4, 5))
        and any(hex_bytes(value[2], 32)), "current preservation HashRef")
    return algorithm, digest, value[2]


def _record(value):
    require(type(value) is list and len(value) == 8, "current preservation record shape")
    content = _hash_ref(value[2])
    if value[5] == ZERO:
        require(uint(value[6][0], 16) == 0 and value[6][1] == "0x" and value[6][2] == ZERO,
            "current preservation absent signature")
        signature = (0, b"", ZERO)
    else:
        signature = _hash_ref(value[6])
    raw_uri = value[3].encode("utf-8") if type(value[3]) is str else b""
    safe_uri = (not raw_uri or (all(byte > 32 and byte != 127 for byte in raw_uri) and
        ((raw_uri.startswith(b"https://") and len(raw_uri) > 8 and raw_uri[8] not in b"/?#")
         or (raw_uri.startswith(b"ipfs://") and len(raw_uri) > 7)
         or (raw_uri.startswith(b"ar://") and len(raw_uri) > 5))))
    require(any(hex_bytes(value[0], 32)) and any(hex_bytes(value[1], 32))
        and any(hex_bytes(value[4], 32)) and uint(value[7], 64) > 0
        and type(value[3]) is str and len(raw_uri) <= 2048 and safe_uri,
        "current preservation record identity")
    return (value[0], value[1], content, value[3], value[4], value[5], signature, uint(value[7], 64))


def _summary(value):
    require(type(value) is list and len(value) == 18, "current preservation summary shape")
    return (uint(value[0]), value[1], value[2], value[3], uint(value[4], 16), value[5], value[6],
        value[7], value[8], value[9], value[10], uint(value[11], 16), value[12], value[13],
        uint(value[14], 64), value[15], uint(value[16], 64), uint(value[17], 8))


def _record_hash(chain, host, core, recorder, collection, record):
    content = keccak256(encode(("uint16", "bytes32", "bytes32"),
        (record[2][0], keccak256(record[2][1]), record[2][2])))
    signature = keccak256(encode(("uint16", "bytes32", "bytes32"),
        (record[6][0], keccak256(record[6][1]), record[6][2])))
    return keccak256(encode(("bytes32", "uint256", "address", "address", "address", "uint256",
        "bytes32", "bytes32", "bytes32", "bytes32", "bytes32", "bytes32", "bytes32", "uint64"),
        (schema_id("6529stream.preservation-record.v2"), chain, host, core, recorder, collection,
         record[0], record[1], content, keccak256(record[3].encode("utf-8")), record[4], record[5],
         signature, record[7])))


def _rpc_call(reader, context, target, signature, inputs=(), values=(), outputs=()):
    result = reader.request("eth_call", [{"to": target, "data": calldata(signature, inputs, values),
        "gas": "0x1000000"},
        {"blockHash": context["blockHash"], "requireCanonical": True}])
    return decode(outputs, hex_bytes(result), maximum=1048576)


def _source(evidence, context):
    _closed(evidence, ("host", "runtimeHash", "anchorHash", "transcriptHash", "transcript",
        "provenance"), "record source")
    require(any(hex_bytes(evidence["host"], 20)) and any(hex_bytes(evidence["runtimeHash"], 32))
        and evidence["anchorHash"] == keccak256(dumps(context))
        and evidence["transcriptHash"] == keccak256(dumps(evidence["transcript"]))
        and evidence["provenance"] in composition.PROVENANCE,
        "current preservation record source identity")
    transport = rpc.PublicReplayTransport(dumps(evidence["transcript"]), evidence["transcriptHash"])
    reader = rpc.PublicRecordingReader(transport, context["blockHash"])
    filters = [{"address": evidence["host"], "topics": [EVENT,
        "0x" + uint(context["collectionId"]).to_bytes(32, "big").hex(), record_type]}
        for record_type in (FIXITY_CYCLE, SCRIPT_DRILL)]
    history = public_history.scan_public_history(reader, context, filters=filters)
    code = hex_bytes(reader.request("eth_getCode", [evidence["host"],
        {"blockHash": context["blockHash"], "requireCanonical": True}]))
    require(code and keccak256(code) == evidence["runtimeHash"],
        "current preservation record host runtime")
    core, = _rpc_call(reader, context, evidence["host"], "streamCore()", outputs=("address",))
    registry, = _rpc_call(reader, context, evidence["host"], "recordFamilyRegistry()", outputs=("address",))
    marker, = _rpc_call(reader, context, evidence["host"], "isStreamPreservationRecords()", outputs=("bool",))
    family, = _rpc_call(reader, context, evidence["host"], "streamModuleFamily()", outputs=("bytes32",))
    version, = _rpc_call(reader, context, evidence["host"], "streamModuleVersion()", outputs=("bytes32",))
    schema_hash, = _rpc_call(reader, context, evidence["host"], "streamModuleSchemaHash()", outputs=("bytes32",))
    require(core == context["core"] and registry != ZERO_ADDRESS and marker is True
        and (family, version, schema_hash) == (MODULE_FAMILY, MODULE_VERSION, MODULE_SCHEMA),
        "current preservation exact module identity")
    rows = {FIXITY_CYCLE: [], SCRIPT_DRILL: []}; latest = {}; seen = set()
    require(len(history["logs"]) <= MAX_HISTORY * 2, "current preservation history bound")
    for log in history["logs"]:
        record_type, subject = log["topics"][2], log["topics"][3]
        require(record_type in rows, "current preservation foreign record type")
        native_record, record_hash, recorder, authorization = decode(
            (RECORD, "bytes32", "address", "uint8"), hex_bytes(log["data"]), maximum=1048576)
        record = _record(json_values(native_record))
        require(record_hash not in seen and record[0] == record_type and record[1] == subject
            and recorder != ZERO_ADDRESS,
            "current preservation record event")
        seen.add(record_hash)
        saved_record, = _rpc_call(reader, context, evidence["host"], "collectionRecord(bytes32)",
            ("bytes32",), (record_hash,), (RECORD,))
        summary, = _rpc_call(reader, context, evidence["host"], "collectionRecordSummary(bytes32)",
            ("bytes32",), (record_hash,), (SUMMARY,))
        saved_record = _record(json_values(saved_record)); summary = _summary(json_values(summary))
        recorded_at = uint(history["blockTimestamps"][str(int(log["blockNumber"], 16))], 64)
        require(saved_record == record and record_hash == _record_hash(uint(context["chainId"]),
            evidence["host"], context["core"], recorder, uint(context["collectionId"]), record)
            and summary == (uint(context["collectionId"]), record[0], record[1], record_hash,
                record[2][0], keccak256(record[2][1]), record[2][2], record[3],
                keccak256(record[3].encode("utf-8")), record[4], record[5], record[6][0],
                keccak256(record[6][1]), record[6][2], record[7], recorder, recorded_at, authorization),
            "current preservation native record/summary")
        rows[record_type].append({"recordHash": record_hash, "record": json_values(record),
            "summary": json_values(summary), "publication": {**log, "timestamp": str(recorded_at)}})
        latest[(record_type, record[1], recorder)] = record_hash
    for (record_type, subject, recorder), expected in sorted(latest.items()):
        actual, = _rpc_call(reader, context, evidence["host"],
            "latestCollectionRecordHashFor(uint256,bytes32,bytes32,address)",
            ("uint256", "bytes32", "bytes32", "address"),
            (uint(context["collectionId"]), record_type, subject, recorder), ("bytes32",))
        require(actual == expected, "current preservation latest recorder record")
    transport.finish()
    observation = {"kind": "rpc", "name": "acquisition-preservation-current-records",
        "anchor": dict(context), "transcript": evidence["transcript"],
        "runtimePins": {evidence["host"]: evidence["runtimeHash"]},
        "provenance": evidence["provenance"]}
    composition.reconcile(context, [observation])
    return ({name: {"status": "authenticated_empty" if not rows[record_type]
            else "retained_unmapped", "recordType": record_type, "host": evidence["host"],
            "count": str(len(rows[record_type])), "records": rows[record_type],
            "schemaMappingAvailable": False, "hostSelectionProven": False}
        for name, record_type in (("fixityCycle", FIXITY_CYCLE), ("scriptDrill", SCRIPT_DRILL))},
        observation)


def _retrieval_observation(envelope, checked):
    pins, calls, events = {}, {}, []
    def pin(address, digest):
        if type(address) is str and type(digest) is str:
            try:
                if any(hex_bytes(address, 20)) and any(hex_bytes(digest, 32)):
                    require(pins.setdefault(address, digest) == digest,
                        "current preservation retrieval runtime conflict")
            except (ValueError, TypeError): return
    for row in envelope["graph"].values(): pin(row["address"], row["runtimeHash"])
    witness = envelope["retrieval"]["witness"]
    pin(witness["address"], witness["runtimeHash"])

    class _Pins:
        def pin(self, address, digest):
            pin(address, digest)

    # Reuse the exact already-enforced retrieval source closure.  These are
    # source-block runtime observations, not arbitrary historical hash fields.
    native_graph = {key: envelope["graph"][key] for key in preservation.GRAPH_KEYS}
    source_bundle = envelope["sourceProof"]["bundle"]
    source_checked = preservation.validate_bundle(source_bundle, envelope["context"], native_graph)
    retrieval_wire._source_pins(source_bundle, source_checked, _Pins())
    retrieval_wire._reference_source_pins(
        envelope["inventory"]["value"]["reference"], envelope["context"], native_graph, _Pins())

    def walk(value, key=None):
        if type(value) is dict:
            if set(value) == {"target", "calldata", "result"}: calls.setdefault(dumps(value), value)
            if key == "runtimes":
                for address, raw in value.items(): pin(address, keccak256(hex_bytes(raw)))
            if set(value) == {"verifier", "runtimeHash", "record"}:
                pin(value["verifier"], value["runtimeHash"])
            if set(value) == {"host", "runtimeHash", "coverage", "receipts", "fixities",
                    "checkpoint", "envelope"}:
                pin(value["host"], value["runtimeHash"])
            if set(value) == {"pointer", "runtime", "archive"}:
                pin(value["pointer"], keccak256(hex_bytes(value["runtime"])))
            direct = {"address", "blockHash", "blockNumber", "transactionHash",
                "transactionIndex", "logIndex", "topics", "data", "timestamp", "removed"}
            if set(value) == direct:
                events.append({"log": {k: value[k] for k in ("address", "blockHash", "blockNumber",
                    "transactionHash", "transactionIndex", "logIndex", "topics", "data", "removed")},
                    "timestamp": value["timestamp"]})
            elif set(value) == {"log", "timestamp"}: events.append(value)
            for child_key, child in value.items(): walk(child, child_key)
        elif type(value) is list:
            for child in value: walk(child, key)
    walk(envelope)
    return {"kind": "native", "name": "acquisition-preservation-current-retrieval",
        "context": dict(envelope["context"]), "calls": list(calls.values()),
        "events": events, "runtimePins": pins,
        "provenance": checked["sourceProvenance"]}


def _token_in_retrieval(envelope, token_id):
    from . import view_preservation_output_types_v1 as output_types
    found = [row for row in envelope["inventory"]["value"]["members"] if decode(
        (output_types.OUTPUT,), hex_bytes(row["outputReturn"]), maximum=4096)[0][1] == token_id]
    require(len(found) == 1, "current preservation target token retrieval occurrence")


def consume(packet, evidence, *, context, graph):
    try: return _consume(packet, evidence, context, graph)
    except MuseumError: raise
    except (KeyError, IndexError, TypeError, ValueError, OverflowError) as exc:
        raise MuseumError("malformed current preservation evidence") from exc


def _consume(packet, evidence, context, graph):
    _closed(evidence, ("sourceRevision", "retrievalEnvelope", "recordSource"), "input")
    require(evidence["sourceRevision"] == SOURCE_REVISION and type(packet) is dict
        and type(context) is dict and set(context) == set(composition.STATE_KEYS) and type(graph) is dict,
        "current preservation source revision/context")
    packet_state = packet["sourceState"]
    for key in ("chainId", "core", "collectionId", "tokenId", "blockHash", "blockNumber"):
        require(context[key] == packet_state.get(key), "current preservation packet source " + key)
    require(uint(packet_state["examinedAt"], 64) >= uint(context["timestamp"], 64),
        "current preservation packet examination precedes source")
    require(packet["workClass"] in ("script", "non_script")
        and packet["metadataMode"] in ("ONCHAIN", "HYBRID", "OFFCHAIN_HASH_BOUND", "SERVICE_BACKED"),
        "current preservation packet mode")
    histories, record_observation = _source(evidence["recordSource"], context)
    fixity, drill = histories["fixityCycle"], histories["scriptDrill"]
    envelope = evidence["retrievalEnvelope"]; current = None; retrieval_observation = None
    if envelope is not None:
        checked = retrieval.verify(dumps(envelope))
        require(envelope["context"] == context
            and (not graph or all(envelope["graph"].get(key) == value for key, value in graph.items())),
            "current preservation retrieval source state/graph")
        _token_in_retrieval(envelope, uint(context["tokenId"]))
        current = {"profileHash": checked["profileHash"], "inputHash": checked["inputHash"],
            "sourceProofHash": checked["sourceProofHash"], "inventoryInputHash": checked["inventoryInputHash"],
            "retainedGetterCount": checked["retainedGetterCount"],
            "retainedGetterHash": checked["retainedGetterHash"], "media": checked["media"]}
        retrieval_observation = _retrieval_observation(envelope, checked)
    mode = packet["metadataMode"]
    declared_coverage = ("service_backed_mutable" if mode == "SERVICE_BACKED" else
        "onchain_bound" if mode in ("ONCHAIN", "HYBRID") else None)
    coverage = "covered" if current is not None else None
    preservation_patch = {"coverage": coverage} if coverage is not None else None
    drill_patch = None
    preservation = {"coverageStatus": coverage or "unresolved", "currentArchive": current,
        "fixityCycleHistory": fixity, "packetPatch": preservation_patch,
        "suppliedModeApplicability": {"metadataMode": mode, "interpretation": declared_coverage,
            "authenticatedByCurrentNativeSource": False},
        "qualification": "Archive fixities do not become a completed fixity-cycle record."}
    script = {"history": drill, "packetPatch": drill_patch,
        "suppliedWorkApplicability": {"workClass": packet["workClass"],
            "interpretation": "not_applicable" if packet["workClass"] == "non_script" else "applicable",
            "authenticatedByCurrentNativeSource": False},
        "qualification": "Reference renders and current output correspondence do not become a preservation drill."}
    observations = ([retrieval_observation] if retrieval_observation is not None else []) + [record_observation]
    claims = dict(CLAIMS); claims["currentArchiveCorrespondenceReplayed"] = current is not None
    claims["emptyHistoryAuthenticated"] = any(row["status"] == "authenticated_empty" for row in (fixity, drill))
    report = {"profileHash": PROFILE_HASH, "sourceRevision": SOURCE_REVISION,
        "sourceState": dict(context), "preservationHash": keccak256(dumps(preservation)),
        "scriptDrillHash": keccak256(dumps(script)), "observationsHash": keccak256(dumps(observations)),
        "claims": claims, "qualification": QUALIFICATION}
    files = {PROFILE_PATH: PROFILE_BYTES, PRESERVATION_PATH: dumps(preservation),
        DRILL_PATH: dumps(script), REPORT_PATH: dumps(report)}
    return PreservationCurrentResult(files, report, observations)


def _reference(label, value):
    raw = dumps(value)
    return {"hash": {"algorithm": 1, "digest": keccak256(raw), "canonicalizationId": JCS},
        "uri": "urn:6529stream:acquisition-preservation-current:" + label}

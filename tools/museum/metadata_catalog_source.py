"""Complete one-collection MetadataV1 catalogue from its native indexed state.

Preserve every original subject and receipt without substituting current writer
permissions or host selection. The native subject map has no inverse getter:
non-collection subjects retain their hashes without invented token identifiers.
"""
import argparse
import os
from pathlib import Path

from .canonical import MuseumError, dumps, hex_bytes, keccak256, loads, record_chain, schema_id, subject_id, uint
from .chain_abi import encode
from .chain_rpc import MAX_TRANSCRIPT, RecordingReader, ReplayTransport, RpcTransport, quantity
from .independent_source import IndependentSourceAdapter
from .independent_wire import RECORD, ZERO, ZERO_ADDRESS, generic_hash, json_values, require

PROFILE = "STREAM_MUSEUM_METADATA_CATALOG_SOURCE_V1"
MAX_TYPES, MAX_RECORDS, MAX_ANCHOR = 256, 4096, 524288
POLICY = ("bytes32", "uint16", "bool")
RECEIPT = ("uint256", "address", "uint8", "uint64", "uint64", "bytes32", "bytes32", "bytes32", "bytes32")
FAMILY_CLASSES = {"ARTIST": (1,), "CURATOR": (3, 8), "INSTITUTION": (4,), "RIGHTS": (7, 8),
    "ARCHIVE": (6, 8), "FIXITY": (4, 6, 8), "C2PA": (4, 6, 8), "IIIF": (6, 7, 8),
    "MEDIA_RELATIONSHIP": (6, 7), "IDENTITY_DISPLAY": (7, 8), "AGENT": (7, 8)}
FAMILIES = {schema_id("6529STREAM_RECORD_FAMILY_" + name + "_V1"): classes
    for name, classes in FAMILY_CLASSES.items()}
ARTIST = schema_id("6529STREAM_RECORD_FAMILY_ARTIST_V1")
CURATOR = schema_id("6529STREAM_RECORD_FAMILY_CURATOR_V1")
WORK = schema_id("WORK_DESCRIPTION")
ARTIST_SCHEMAS = {
    schema_id("ARTIST_INTENT"): (schema_id("STREAM_ARTIST_INTENT_V1"),),
    schema_id("ARTIST_INTENT_WAIVER"): (schema_id("STREAM_ARTIST_INTENT_WAIVER_V1"),),
    schema_id("ARTIST_STATEMENT"): (schema_id("STREAM_ARTIST_INTERVIEW_V1"), schema_id("STREAM_ARTIST_STATEMENT_V1")),
    schema_id("ARTIST_SEMANTIC_ASSERTION"): (schema_id("STREAM_SEMANTIC_ASSERTION_V1"),),
    WORK: (schema_id("STREAM_WORK_DESCRIPTION_V1"),),
}
QUALIFICATION = ("Complete native MetadataV1 type enumeration, policy rows, histories, heads, per-subject/per-recorder latest records "
    "and referenced payload-pointer catalogue for one nonzero collection at the pinned source block. Native historical receipts supply "
    "original authority; current grants, artist signatures and host selection are not re-evaluated. Registered definition hashes are "
    "retained without interpreting their bytes. Unknown token subject preimages are not invented. RPC provenance is caller-declared. "
    "No state or consensus proof, current host selection, legal rights, semantic payload acceptance or full dossier conformance.")
CLAIMS = {"nativeTypeCatalogueComplete": True, "collectionRecordLanesComplete": True,
    "authenticatedEmptyLanes": True, "payloadPointerCatalogueComplete": True, "payloadBytesChecked": True,
    "historicalReceiptCorrespondenceChecked": True, "currentHostSelectionProven": False,
    "currentWriterPermissionsChecked": False, "tokenSubjectPreimagesResolved": False,
    "semanticPayloadValidation": False, "schemaInterpretationVerified": False,
    "actualChainAcceptance": False, "consensusProof": False, "legalRightsProven": False,
    "fullObjectDossierConformance": False, "networkObjectFetch": False}
PROFILE_BYTES = dumps({"name": PROFILE, "version": "1", "status": "prospective_unregistered_read_profile",
    "scope": "one nonzero native collection; scope zero is not a valid MetadataV1 record scope",
    "enumeration": "recordTypeCount/At, recordPolicy, every recordChainHash/recordHashAt, payloadPointerCount/At",
    "pointerIdentity": "one native deduplicated (family,contentHash) entry; repeated records remain distinct",
    "bounds": {"types": str(MAX_TYPES), "records": str(MAX_RECORDS), "payloadBytes": "8192"},
    "claims": CLAIMS, "qualification": QUALIFICATION})
PROFILE_HASH = keccak256(PROFILE_BYTES)


def validate_policy(record_type, policy):
    encode((POLICY,), (policy,))
    family, mask, admitted = policy
    require(record_type != ZERO and admitted and family in FAMILIES and mask != 0,
        "metadata catalogue invalid admitted policy")
    allowed = sum(1 << value for value in FAMILIES[family])
    if record_type == WORK:
        require(family == CURATOR, "metadata WORK family differs")
        allowed |= 1 << 1
    require(mask & ~allowed == 0, "metadata catalogue native policy mask differs")


def verify_record(chain, host, core, collection, timestamp, expected_hash, record_type, policy, index, previous,
                  record, receipt, payload):
    """Exact native MetadataV1 record/receipt checks, without current authorization."""
    encode((RECORD, RECEIPT), (record, receipt))
    rt, subject, content, uri, schema, scheme, signature, effective = record
    family, mask, _ = policy
    require(rt == record_type and subject != ZERO and schema != ZERO and content[2] != ZERO
        and receipt[0] == collection and collection > 0 and receipt[1] != ZERO_ADDRESS
        and receipt[2] in (1, 3, 4, 6, 7, 8) and mask & (1 << receipt[2]) != 0
        and receipt[3] <= timestamp and receipt[4] == index and receipt[6] != ZERO and receipt[7] != ZERO
        and scheme == ZERO and signature == (0, b"", ZERO) and effective > 0,
        "metadata catalogue original record/receipt differs")
    require(type(payload) is bytes and 0 < len(payload) <= 8192 and content[0] == 1 and len(content[1]) == 32
        and content[1] == hex_bytes(keccak256(payload)), "metadata catalogue full payload differs")
    raw_uri = uri.encode("utf-8")
    require(len(raw_uri) <= 2048 and (not raw_uri or (all(b > 32 and b != 127 for b in raw_uri)
        and ((raw_uri.startswith(b"https://") and len(raw_uri) > 8 and raw_uri[8] not in b"/?#")
            or (raw_uri.startswith(b"ipfs://") and len(raw_uri) > 7)
            or (raw_uri.startswith(b"ar://") and len(raw_uri) > 5)))), "metadata catalogue native URI differs")
    if rt == WORK:
        require(schema == schema_id("STREAM_WORK_DESCRIPTION_V1"), "metadata WORK schema differs")
    if receipt[2] == 1:
        require(receipt[8] != ZERO and (family == ARTIST or (family == CURATOR and rt == WORK))
            and schema in ARTIST_SCHEMAS.get(rt, ()), "metadata historical artist receipt differs")
    else:
        require(receipt[8] == ZERO and family != ARTIST, "metadata direct receipt has artist authorization")
    require(generic_hash(chain, host, core, collection, receipt[1], record) == expected_hash,
        "metadata catalogue original hash differs")
    require(record_chain(str(chain), host, str(collection), rt, previous, expected_hash, str(index)) == receipt[5],
        "metadata catalogue original chain differs")


def _anchor(raw):
    a = loads(raw, maximum=MAX_ANCHOR, canonical=True)
    require(type(a) is dict and set(a) == {"profile", "chainId", "blockHash", "blockNumber", "timestamp", "stateRoot",
        "environment", "deploymentEvidenceHash", "host", "core", "schemas", "store", "artistRegistry", "codePins", "collectionId"}
        and a["profile"] == PROFILE and a["environment"] in ("local_evm_fixture", "public_chain"), "metadata catalogue anchor shape")
    for key in ("chainId", "blockNumber", "collectionId"):
        uint(a[key])
    uint(a["timestamp"], 64)
    require(uint(a["chainId"]) > 0 and uint(a["collectionId"]) > 0, "metadata catalogue requires nonzero collection scope")
    for key in ("blockHash", "stateRoot", "deploymentEvidenceHash"):
        require(any(hex_bytes(a[key], 32)), "metadata catalogue empty commitment")
    for key in ("host", "core", "schemas", "store", "artistRegistry"):
        require(any(hex_bytes(a[key], 20)), "metadata catalogue dependency address")
    require(type(a["codePins"]) is list and 5 <= len(a["codePins"]) <= 64, "metadata catalogue pin bound")
    pins = {}
    for row in a["codePins"]:
        require(type(row) is dict and set(row) == {"address", "runtimeHash"}, "metadata catalogue pin shape")
        require(any(hex_bytes(row["address"], 20)) and any(hex_bytes(row["runtimeHash"], 32))
            and row["address"] not in pins, "metadata catalogue duplicate/empty pin")
        pins[row["address"]] = row["runtimeHash"]
    require(all(a[key] in pins for key in ("host", "core", "schemas", "store", "artistRegistry")), "metadata catalogue missing pin")
    return a, pins


class MetadataCatalogSource:
    _read = IndependentSourceAdapter._read
    _block = IndependentSourceAdapter._block
    _chunk = IndependentSourceAdapter._chunk

    def __init__(self, anchor_raw, transport, *, provenance="synthetic_fixture"):
        require(provenance in ("synthetic_fixture", "trusted_rpc")
            and (provenance != "trusted_rpc" or type(transport) in (RpcTransport, ReplayTransport)), "metadata catalogue provenance")
        self.a, self.pins = _anchor(anchor_raw)
        self.anchor_bytes, self.provenance = anchor_raw, provenance
        self.reader = RecordingReader(transport, self.a["blockHash"])
        self.chunks = {}
        self._started, self._snapshot = False, None

    def transcript(self):
        return self.reader.transcript()

    def snapshot(self):
        if self._snapshot is not None:
            return self._snapshot
        require(not self._started, "failed metadata catalogue capture cannot resume")
        self._started = True
        try:
            self._snapshot = self._capture()
        except MuseumError:
            raise
        except (KeyError, TypeError, IndexError, ValueError, OverflowError) as exc:
            raise MuseumError("malformed metadata catalogue evidence") from exc
        return self._snapshot

    def _bindings(self):
        a = self.a
        require(quantity(self.reader.request("eth_chainId", [])) == uint(a["chainId"]), "metadata catalogue chain differs")
        self._block()
        original = self.reader.rows[-1]["result"]
        for address, digest in sorted(self.pins.items()):
            code = hex_bytes(self.reader.code(address))
            require(0 < len(code) <= 24576 and keccak256(code) == digest, "metadata catalogue runtime differs")
        for key, getter in (("core", "core"), ("schemas", "schemaRegistry"), ("store", "chunkStore"), ("artistRegistry", "artistRegistry")):
            _, value = self._read(a["host"], getter + "()", outputs=("address",))
            require(value == (a[key],), "metadata catalogue host dependency differs")
            _, value = self._read(a["host"], getter + "CodeHash()", outputs=("bytes32",))
            require(value == (self.pins[a[key]],), "metadata catalogue constructor pin differs")
        _, value = self._read(a["schemas"], "chunkStore()", outputs=("address",))
        require(value == (a["store"],), "metadata catalogue schema store differs")
        for getter, expected in (("streamModuleType()", schema_id("COLLECTION_METADATA")),
                                 ("streamModuleVersion()", schema_id("6529stream.collection-metadata.full-bytes.v1"))):
            _, value = self._read(a["host"], getter, outputs=("bytes32",))
            require(value == (expected,), "metadata catalogue native module differs")
        _, exists = self._read(a["core"], "collectionExists(uint256)", ("uint256",), (uint(a["collectionId"]),), ("bool",))
        require(exists == (True,), "metadata catalogue original collection missing")
        return original

    def _capture(self):
        a = self.a; cid, chain = uint(a["collectionId"]), uint(a["chainId"])
        block = self._bindings()
        _, (type_count,) = self._read(a["host"], "recordTypeCount()", outputs=("uint256",))
        require(type_count <= MAX_TYPES, "metadata catalogue type bound")
        catalogue, policies = [], {}
        for index in range(type_count):
            _, (rt,) = self._read(a["host"], "recordTypeAt(uint256)", ("uint256",), (index,), ("bytes32",))
            require(rt != ZERO and rt not in policies, "metadata catalogue duplicate type")
            _, (policy,) = self._read(a["host"], "recordPolicy(bytes32)", ("bytes32",), (rt,), (POLICY,))
            validate_policy(rt, policy)
            policies[rt] = policy
            catalogue.append({"index": str(index), "recordType": rt, "family": policy[0],
                "authorizationMask": str(policy[1]), "admitted": True})
        records, lanes, seen, expected_pointers, authorizations = [], [], set(), {}, set()
        collection_subject = subject_id("collection", a["chainId"], a["core"], a["collectionId"])
        for rt, policy in policies.items():
            _, (head, count) = self._read(a["host"], "recordChainHash(uint256,bytes32)",
                ("uint256", "bytes32"), (cid, rt), ("bytes32", "uint64"))
            require(count <= MAX_RECORDS - len(records), "metadata catalogue record bound")
            previous, latest, hashes, last_time = ZERO, {}, [], 0
            for index in range(count):
                _, (digest,) = self._read(a["host"], "recordHashAt(uint256,bytes32,uint256)",
                    ("uint256", "bytes32", "uint256"), (cid, rt, index), ("bytes32",))
                require(digest != ZERO and digest not in seen, "metadata catalogue duplicate/missing record")
                _, (record, receipt) = self._read(a["host"], "collectionRecord(bytes32)", ("bytes32",), (digest,), (RECORD, RECEIPT))
                _, (fixed_receipt,) = self._read(a["host"], "collectionRecordReceipt(bytes32)", ("bytes32",), (digest,), (RECEIPT,))
                require(fixed_receipt == receipt, "metadata catalogue fixed receipt differs")
                _, (pointer, payload) = self._read(a["host"], "recordPayload(bytes32)", ("bytes32",), (digest,), ("address", "bytes"))
                verify_record(chain, a["host"], a["core"], cid, uint(a["timestamp"]), digest, rt, policy,
                    index, previous, record, receipt, payload)
                require(receipt[3] >= last_time, "metadata catalogue lane publication time differs")
                content_hash = keccak256(payload)
                require(self._chunk(content_hash, pointer) == payload, "metadata catalogue payload pointer bytes differ")
                key = (policy[0], content_hash)
                require(key not in expected_pointers or expected_pointers[key] == pointer, "metadata catalogue repeated pointer differs")
                expected_pointers[key] = pointer
                if receipt[8] != ZERO:
                    require(receipt[8] not in authorizations, "metadata catalogue reused artist authorization")
                    authorizations.add(receipt[8])
                    _, (consumed,) = self._read(a["host"], "consumedArtistAuthorization(bytes32)", ("bytes32",), (receipt[8],), ("bool",))
                    require(consumed, "metadata catalogue artist authorization not consumed")
                seen.add(digest); hashes.append(digest); latest[(record[1], receipt[1])] = digest
                records.append({"recordHash": digest, "record": json_values(record), "receipt": json_values(receipt),
                    "subjectId": record[1], "subjectKind": "collection" if record[1] == collection_subject else "host_admitted_token_subject",
                    "payloadHex": "0x" + payload.hex(), "payloadPointer": pointer,
                    "authority": {"mode": "historical_native_metadata_receipt", "authorizationClass": str(receipt[2]),
                        "recorder": receipt[1], "artistAuthorization": receipt[8], "currentPermissionsRevalidated": False}})
                previous, last_time = receipt[5], receipt[3]
            require(previous == head, "metadata catalogue complete lane head differs")
            latest_rows = []
            for (subject, recorder), expected in sorted(latest.items()):
                _, (actual,) = self._read(a["host"], "latestCollectionRecordHashFor(uint256,bytes32,bytes32,address)",
                    ("uint256", "bytes32", "bytes32", "address"), (cid, rt, subject, recorder), ("bytes32",))
                require(actual == expected, "metadata catalogue per-subject recorder latest differs")
                latest_rows.append({"subjectId": subject, "recorder": recorder, "recordHash": expected})
            lanes.append({"recordType": rt, "count": str(count), "chainHash": head, "records": hashes,
                "status": "authenticated_empty" if count == 0 else "complete_history", "latest": latest_rows})
        _, (pointer_count,) = self._read(a["host"], "payloadPointerCount(uint256)", ("uint256",), (cid,), ("uint256",))
        require(pointer_count <= MAX_RECORDS, "metadata catalogue pointer bound")
        pointers, observed = [], {}
        for index in range(pointer_count):
            _, (pointer, family, digest) = self._read(a["host"], "payloadPointerAt(uint256,uint256)",
                ("uint256", "uint256"), (cid, index), ("address", "bytes32", "bytes32"))
            key = (family, digest)
            require(key not in observed and key in expected_pointers and expected_pointers[key] == pointer,
                "metadata catalogue unreferenced/duplicate payload pointer")
            require(self._chunk(digest, pointer) is not None, "metadata catalogue payload unavailable")
            observed[key] = pointer
            pointers.append({"index": str(index), "pointer": pointer, "family": family, "contentHash": digest})
        require(observed == expected_pointers, "metadata catalogue payload pointer inventory incomplete")
        self._block()
        require(self.reader.rows[-1]["result"] == block, "metadata catalogue source anchor changed")
        if type(self.reader.transport) is ReplayTransport:
            self.reader.transport.finish()
        return dumps({"profile": PROFILE, "profileHash": PROFILE_HASH, "version": "1",
            "mode": "caller_admitted_rpc_metadata_catalogue" if self.provenance == "trusted_rpc" else "synthetic_fixture",
            "provenanceDeclaredByCaller": True, "anchorHash": keccak256(self.anchor_bytes),
            "transcriptHash": keccak256(self.transcript()), "host": a["host"],
            "sourceState": {key: a[key] for key in ("chainId", "core", "collectionId", "blockHash", "blockNumber")},
            "catalog": catalogue, "lanes": lanes, "records": records, "payloadPointers": pointers,
            "claims": CLAIMS, "qualification": QUALIFICATION})


def _bounded_read(path, maximum):
    with Path(path).open("rb") as stream:
        raw = stream.read(maximum + 1)
    require(len(raw) <= maximum, "metadata catalogue input file bound")
    return raw


def definitions(directory, *, check=False):
    target = Path(directory) / "metadata-catalog-profile.json"
    if check:
        require(_bounded_read(target, MAX_ANCHOR) == PROFILE_BYTES, "metadata catalogue profile differs")
    else:
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_bytes(PROFILE_BYTES)
    return PROFILE_HASH


def write_capture(source, output):
    from .bagit import MAX_BYTES, write_tree
    snapshot = source.snapshot(); transcript = source.transcript()
    pins = {"profileHash": PROFILE_HASH, "anchorHash": keccak256(source.anchor_bytes), "snapshotHash": keccak256(snapshot),
        "transcriptHash": keccak256(transcript), "provenance": source.provenance, "actualChainAcceptance": False}
    files = {"anchor.json": source.anchor_bytes, "transcript.json": transcript, "snapshot.json": snapshot,
        "pins.json": dumps(pins), "profile.json": PROFILE_BYTES}
    require(sum(map(len, files.values())) <= MAX_BYTES, "metadata catalogue output byte bound")
    write_tree(files, output)
    return pins


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    commands = parser.add_subparsers(dest="command", required=True)
    definition = commands.add_parser("definitions")
    definition.add_argument("--output", type=Path, required=True); definition.add_argument("--check", action="store_true")
    for name in ("capture", "replay"):
        command = commands.add_parser(name)
        command.add_argument("--anchor", type=Path, required=True); command.add_argument("--anchor-hash", required=True)
        command.add_argument("--output", type=Path, required=True)
        if name == "capture": command.add_argument("--rpc-env", required=True)
        else:
            command.add_argument("--transcript", type=Path, required=True); command.add_argument("--transcript-hash", required=True)
            command.add_argument("--provenance", choices=("synthetic_fixture", "trusted_rpc"), default="synthetic_fixture")
    args = parser.parse_args()
    if args.command == "definitions":
        print(definitions(args.output, check=args.check)); return
    anchor = _bounded_read(args.anchor, MAX_ANCHOR)
    require(keccak256(anchor) == args.anchor_hash, "metadata catalogue external anchor commitment differs")
    if args.command == "capture":
        endpoint = os.environ.get(args.rpc_env)
        require(bool(endpoint), "metadata catalogue RPC environment variable missing")
        transport = RpcTransport(endpoint)
    else: transport = ReplayTransport(_bounded_read(args.transcript, MAX_TRANSCRIPT), args.transcript_hash)
    source = MetadataCatalogSource(anchor, transport, provenance="trusted_rpc" if args.command == "capture" else args.provenance)
    print(dumps(write_capture(source, args.output)).decode("utf-8"))


if __name__ == "__main__":
    try: main()
    except (MuseumError, OSError) as exc: raise SystemExit(str(exc)) from None

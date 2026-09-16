"""Complete one-scope catalogue capture for StreamCollectionAttestations.

The eight record types are fixed by this reader and confirmed against the
externally pinned host runtime. Empty lanes are retained as authenticated
head/count reads. This is read-only trusted-RPC consistency evidence, never a
state proof, consensus proof, or endorsement of record semantics.
"""
import argparse
import os
from pathlib import Path

from .canonical import dumps, hex_bytes, keccak256, loads, uint
from .chain_abi import calldata, decode
from .chain_rpc import MAX_TRANSCRIPT, RecordingReader, ReplayTransport, RpcTransport, quantity
from .independent_source import (IndependentSourceAdapter, MAX_RECORDS,
    PROFILE as DECLARED_LANE_PROFILE, _anchor as _declared_anchor)
from .independent_wire import (DOCUMENT, RECORD_TYPES, ZERO, ZERO_ADDRESS,
    json_values, require, verify_record)


PROFILE = "STREAM_MUSEUM_INDEPENDENT_CATALOG_SOURCE_V1"
CATALOG_NAMES = (
    "INDEPENDENT_FIXITY",
    "INDEPENDENT_PRESERVATION_EVENT",
    "INDEPENDENT_EXHIBITION",
    "INDEPENDENT_CONDITION",
    "INDEPENDENT_CONSERVATION_TREATMENT",
    "INDEPENDENT_ENVIRONMENT_MIGRATION",
    "INDEPENDENT_EXPORT_MIRROR",
    "INDEPENDENT_SEMANTIC_ASSERTION",
)
CATALOG = tuple(zip(CATALOG_NAMES, RECORD_TYPES))
PAYLOAD_FAMILY = keccak256(b"6529STREAM_RECORD_FAMILY_INDEPENDENT_V1")
SIGNATURE_FAMILY = keccak256(b"STREAM_INDEPENDENT_SIGNATURE_BUNDLE_V1")
PROFILE_BYTES = dumps({
    "name": PROFILE,
    "version": "1",
    "catalog": [{"name": name, "recordType": record_type} for name, record_type in CATALOG],
    "scope": "one exact collection scope, including deployment-wide scope zero, at one pinned block",
    "history": "all eight heads, counts and ordered records; zero/zero is authenticated empty",
    "pointers": "complete payloadPointerAt inventory equals unique (family,content-hash) pairs referenced by records",
    "evidence": "trusted RPC and runtime pins are replay consistency evidence, not a cryptographic state or consensus proof",
})
PROFILE_HASH = keccak256(PROFILE_BYTES)
MAX_ANCHOR = 524288


def _anchor(raw):
    value = loads(raw, maximum=524288, canonical=True)
    fields = {"profile", "chainId", "blockHash", "blockNumber", "timestamp", "stateRoot",
        "environment", "deploymentEvidenceHash", "host", "core", "schemas", "store",
        "codePins", "scopeKey"}
    require(isinstance(value, dict) and set(value) == fields and value["profile"] == PROFILE,
        "catalog anchor shape/profile")
    scope = uint(value["scopeKey"])
    # Reuse the existing closed anchor, runtime-pin and numeric validation after
    # deriving all lanes locally. The compatibility value is never retained.
    compatibility = {key: item for key, item in value.items() if key != "scopeKey"}
    compatibility["profile"] = DECLARED_LANE_PROFILE
    compatibility["lanes"] = [{"scopeKey": str(scope), "recordType": record_type}
        for _, record_type in CATALOG]
    _, pins, lanes = _declared_anchor(dumps(compatibility))
    require(lanes == [(scope, record_type) for _, record_type in CATALOG],
        "derived catalogue lanes differ")
    return value, pins, scope


class IndependentCatalogSource(IndependentSourceAdapter):
    """Capture the complete fixed independent-attestation catalogue for a scope."""

    def __init__(self, anchor_bytes, transport, *, provenance="synthetic_fixture"):
        value, pins, scope = _anchor(anchor_bytes)
        require(provenance in ("synthetic_fixture", "trusted_rpc"), "source provenance")
        require(provenance != "trusted_rpc" or type(transport) in (RpcTransport, ReplayTransport),
            "synthetic transport cannot authenticate source")
        self.anchor_bytes = anchor_bytes
        self.a, self.pins, self.scope = value, pins, scope
        self.lanes = [(scope, record_type) for _, record_type in CATALOG]
        self.reader = RecordingReader(transport, value["blockHash"])
        self.provenance = provenance
        self.documents = {}
        self.document_stack = set()
        self.document_bytes = 0
        self.chunks = {}
        self._started = False
        self._snapshot = None

    def snapshot(self):
        if self._snapshot is not None:
            return self._snapshot
        require(not self._started, "failed capture cannot reuse partial reader state")
        self._started = True
        a, r = self.a, self.reader
        require(quantity(r.request("eth_chainId", [])) == uint(a["chainId"]), "chain id mismatch")
        self._block()
        for address, expected in self.pins.items():
            code = hex_bytes(r.code(address))
            require(0 < len(code) <= 24576 and keccak256(code) == expected,
                "runtime identity mismatch")
        for field, getter in (("core", "core()"), ("schemas", "schemaRegistry()"),
                              ("store", "chunkStore()")):
            _, (actual,) = self._read(a["host"], getter, outputs=("address",))
            require(actual == a[field], "host dependency address mismatch")
        _, (store,) = self._read(a["schemas"], "chunkStore()", outputs=("address",))
        require(store == a["store"], "schema chunk store mismatch")
        for field, getter in (("core", "coreCodeHash()"), ("schemas", "schemaRegistryCodeHash()"),
                              ("store", "chunkStoreCodeHash()")):
            _, (saved,) = self._read(a["host"], getter, outputs=("bytes32",))
            require(saved == self.pins[a[field]], "host constructor code pin mismatch")
        _, (supported,) = self._read(a["host"], "supportsInterface(bytes4)", ("bytes4",),
                                      ("0x771b2917",), ("bool",))
        require(supported, "unsupported dedicated independent host")
        for getter, expected in (("streamModuleType()", keccak256(b"COLLECTION_ATTESTATIONS")),
                                 ("streamModuleVersion()",
                                  keccak256(b"6529stream.collection-attestations.independent.v1"))):
            _, (actual,) = self._read(a["host"], getter, outputs=("bytes32",))
            require(actual == expected, "independent host module identity differs")
        _, (module_interface,) = self._read(a["host"], "streamModuleInterfaceId()", outputs=("bytes4",))
        require(module_interface == "0x771b2917", "independent host module interface differs")

        catalog = []
        for name, record_type in CATALOG:
            _, (accepted,) = self._read(a["host"], "isIndependentRecordType(bytes32)",
                ("bytes32",), (record_type,), ("bool",))
            require(accepted, "fixed independent catalogue type unsupported")
            catalog.append({"name": name, "recordType": record_type})
        _, (zero_accepted,) = self._read(a["host"], "isIndependentRecordType(bytes32)",
            ("bytes32",), (ZERO,), ("bool",))
        require(not zero_accepted, "independent type predicate accepts zero")

        records, lane_results, all_hashes = [], [], set()
        expected_pointers = {}
        for (name, record_type), (scope, lane_type) in zip(CATALOG, self.lanes):
            require(record_type == lane_type, "catalogue lane order differs")
            _, (head, count) = self._read(a["host"], "recordChainHash(uint256,bytes32)",
                ("uint256", "bytes32"), (scope, record_type), ("bytes32", "uint64"))
            require(len(records) + count <= MAX_RECORDS, "record inventory bound")
            previous, latest = ZERO, {}
            for index in range(count):
                _, (record_hash,) = self._read(a["host"], "recordHashAt(uint256,bytes32,uint256)",
                    ("uint256", "bytes32", "uint256"), (scope, record_type, index), ("bytes32",))
                require(record_hash != ZERO and record_hash not in all_hashes,
                    "duplicate/missing lane record")
                all_hashes.add(record_hash)
                record_raw = hex_bytes(r.call(a["host"], calldata(
                    "collectionRecord(bytes32)", ("bytes32",), (record_hash,))))
                subject_raw = hex_bytes(r.call(a["host"], calldata(
                    "recordSubject(bytes32)", ("bytes32",), (record_hash,))))
                payloads, pointers = [], []
                for getter, family in (("recordPayload(bytes32)", PAYLOAD_FAMILY),
                                       ("recordSignatureBundle(bytes32)", SIGNATURE_FAMILY)):
                    _, (pointer, payload) = self._read(a["host"], getter, ("bytes32",),
                        (record_hash,), ("address", "bytes"))
                    require(0 < len(payload) <= 8192, "record/bundle payload bound")
                    digest = keccak256(payload)
                    require(self._chunk(digest, pointer) == payload, "record pointer bytes mismatch")
                    key = (family, digest)
                    require(key not in expected_pointers or expected_pointers[key] == pointer,
                        "deduplicated payload pointer differs")
                    expected_pointers[key] = pointer
                    payloads.append(payload)
                    pointers.append(pointer)
                record, receipt, subject = verify_record(uint(a["chainId"]), a["host"], a["core"],
                    uint(a["timestamp"]), (scope, record_type), index, previous, record_hash,
                    record_raw, subject_raw, *payloads)
                self._document(record[4], 0, receipt[9])
                self._document(record[2][2], 1, receipt[10])
                _, (used,) = self._read(a["host"], "isIndependentAttestorNonceUsed(address,uint256)",
                    ("address", "uint256"), (receipt[1], receipt[7]), ("bool",))
                require(used, "accepted record nonce not consumed")
                records.append({"recordHash": record_hash, "record": json_values(record),
                    "receipt": json_values(receipt), "subject": json_values(subject),
                    "payloadHex": "0x" + payloads[0].hex(),
                    "signatureBundleHex": "0x" + payloads[1].hex(), "pointers": pointers,
                    "authority": {"class": "5", "attestor": receipt[1],
                        "basis": "historical_host_receipt", "currentSignatureRevalidation": False},
                    "subjectMembership": "declared_media_reference" if subject[0] == 2
                        else "host_admitted_at_write"})
                previous = receipt[5]
                latest[(record[1], receipt[1])] = record_hash
            require(previous == head, "lane final chain/count mismatch")
            for (subject_id, attestor), expected in latest.items():
                _, (actual,) = self._read(a["host"],
                    "latestCollectionRecordHashFor(uint256,bytes32,bytes32,address)",
                    ("uint256", "bytes32", "bytes32", "address"),
                    (scope, record_type, subject_id, attestor), ("bytes32",))
                require(actual == expected, "attestor scoped latest mismatch")
            status = "authenticated_empty" if count == 0 else "complete_history"
            lane_results.append({"name": name, "scopeKey": str(scope), "recordType": record_type,
                "count": str(count), "chainHash": head, "status": status})

        _, (pointer_count,) = self._read(a["host"], "payloadPointerCount(uint256)",
            ("uint256",), (self.scope,), ("uint256",))
        require(pointer_count <= MAX_RECORDS * 2, "payload pointer inventory bound")
        pointer_rows, observed = [], {}
        for index in range(pointer_count):
            _, (pointer, family, digest) = self._read(a["host"],
                "payloadPointerAt(uint256,uint256)", ("uint256", "uint256"),
                (self.scope, index), ("address", "bytes32", "bytes32"))
            key = (family, digest)
            require(pointer != ZERO_ADDRESS and family in (PAYLOAD_FAMILY, SIGNATURE_FAMILY)
                and digest != ZERO and key not in observed, "payload pointer row differs")
            require(key in expected_pointers and expected_pointers[key] == pointer,
                "payload pointer is unreferenced or differs")
            require(self._chunk(digest, pointer) is not None, "payload pointer bytes unavailable")
            observed[key] = pointer
            pointer_rows.append({"index": str(index), "pointer": pointer, "family": family,
                "contentHash": digest})
        require(observed == expected_pointers, "payload pointer inventory incomplete")

        self._block()
        if isinstance(r.transport, ReplayTransport):
            r.transport.finish()
        self._snapshot = dumps({"profile": PROFILE, "profileHash": PROFILE_HASH,
            "mode": "recorded_state" if self.provenance == "trusted_rpc" else "synthetic_fixture",
            "evidence": self.provenance, "environment": a["environment"],
            "anchorHash": keccak256(self.anchor_bytes), "transcriptHash": keccak256(r.transcript()),
            "sourceState": {"chainId": a["chainId"], "core": a["core"],
                "scopeKey": str(self.scope), "blockHash": a["blockHash"],
                "blockNumber": a["blockNumber"]},
            "scopeKey": str(self.scope), "catalog": catalog, "lanes": lane_results,
            "records": records, "payloadPointers": pointer_rows,
            "documents": [{"documentId": key, "view": json_values(document),
                "payloadHex": "0x" + payload.hex()}
                for key, (_, payload, document) in self.documents.items()],
            "claims": {"fixedCatalogueComplete": True, "independentScopeInventoryComplete": True,
                "authenticatedEmptyLanes": True, "wholeHostInventory": False,
                "actualChainAcceptance": False, "fullObjectDossierConformance": False,
                "cryptographicStateProof": False, "consensusFinality": False,
                "publicDeploymentAcceptance": False, "semanticPayloadValidation": False,
                "institutionalAcceptance": False}})
        return self._snapshot

    def transcript(self):
        require(self._snapshot is not None, "catalogue snapshot required before transcript")
        return self.reader.transcript()


def definitions(directory, *, check=False):
    """Write/check the prospective catalogue profile; this does not register it."""
    path = Path(directory) / "independent-catalog-profile.json"
    if check:
        require(path.is_file() and path.read_bytes() == PROFILE_BYTES,
            "independent catalogue profile differs")
    else:
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes(PROFILE_BYTES)
    return PROFILE_HASH


def _bounded_read(path, maximum):
    with Path(path).open("rb") as stream:
        raw = stream.read(maximum + 1)
    require(len(raw) <= maximum, "catalogue source input file bound")
    return raw


def replay(anchor_path, anchor_hash, transcript_path, transcript_hash, output,
           *, provenance="synthetic_fixture"):
    """Replay externally pinned inputs without creating a network client."""
    from .bagit import write_tree
    anchor = _bounded_read(anchor_path, MAX_ANCHOR)
    transcript = _bounded_read(transcript_path, MAX_TRANSCRIPT)
    require(keccak256(anchor) == anchor_hash, "catalogue source external anchor pin differs")
    adapter = IndependentCatalogSource(anchor, ReplayTransport(transcript, transcript_hash),
        provenance=provenance)
    snapshot = adapter.snapshot()
    require(adapter.transcript() == transcript, "catalogue source replay transcript differs")
    pins = {"profileHash": PROFILE_HASH, "anchorHash": anchor_hash,
        "transcriptHash": transcript_hash, "snapshotHash": keccak256(snapshot),
        "provenance": provenance, "actualChainAcceptance": False}
    write_tree({"anchor.json": anchor, "transcript.json": transcript,
        "snapshot.json": snapshot, "pins.json": dumps(pins)}, output)
    return pins


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest="command", required=True)
    definition = sub.add_parser("definitions")
    definition.add_argument("--output", type=Path, required=True)
    definition.add_argument("--check", action="store_true")
    command = sub.add_parser("replay", help="offline replay; provenance is caller admission")
    for name in ("anchor", "transcript"):
        command.add_argument("--" + name, type=Path, required=True)
        command.add_argument("--" + name + "-hash", required=True)
    command.add_argument("--provenance", choices=("synthetic_fixture", "trusted_rpc"),
        default="synthetic_fixture")
    command.add_argument("--output", type=Path, required=True)
    command = sub.add_parser("capture", help="read a caller-admitted RPC at the pinned anchor")
    command.add_argument("--anchor", type=Path, required=True)
    command.add_argument("--anchor-hash", required=True)
    command.add_argument("--rpc-env", required=True)
    command.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    if args.command == "definitions":
        result = definitions(args.output, check=args.check)
    elif args.command == "replay":
        result = replay(args.anchor, args.anchor_hash, args.transcript, args.transcript_hash,
            args.output, provenance=args.provenance)
    else:
        from .bagit import write_tree
        anchor = _bounded_read(args.anchor, MAX_ANCHOR)
        require(keccak256(anchor) == args.anchor_hash, "catalogue source external anchor pin differs")
        require(args.rpc_env in os.environ, "RPC endpoint variable unavailable")
        adapter = IndependentCatalogSource(anchor, RpcTransport(os.environ[args.rpc_env]),
            provenance="trusted_rpc")
        snapshot = adapter.snapshot(); transcript = adapter.transcript()
        result = {"profileHash": PROFILE_HASH, "anchorHash": args.anchor_hash,
            "transcriptHash": keccak256(transcript), "snapshotHash": keccak256(snapshot),
            "provenance": "trusted_rpc", "actualChainAcceptance": False}
        write_tree({"anchor.json": anchor, "transcript.json": transcript,
            "snapshot.json": snapshot, "pins.json": dumps(result)}, args.output)
    print(result if type(result) is str else dumps(result).decode())


if __name__ == "__main__": main()

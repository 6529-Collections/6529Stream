"""Current-registry dossier host roster at one externally pinned Core state.

The current Core module registry gives a complete append-only roster for that
registry instance. It does not enumerate other genesis registries or every
permissionless OwnerRecords/CollectionAttestations deployment, so this reader
never promotes the roster to a global writer denominator.
"""
import argparse
import os
from pathlib import Path

from .canonical import dumps, hex_bytes, keccak256, loads, schema_id, uint
from .chain_abi import calldata, decode, encode
from .chain_rpc import MAX_TRANSCRIPT, RecordingReader, ReplayTransport, RpcTransport, quantity
from .independent_wire import RECORD_TYPES, ZERO, ZERO_ADDRESS, json_values, require


PROFILE = "STREAM_MUSEUM_DOSSIER_REGISTERED_HOST_ROSTER_V1"
MAX_ANCHOR = 524288
MAX_MODULES = 4096
MAX_RECORD_TYPES = 1024
MAX_RUNTIME = 24576
POINTER = ("address", "bytes32", "bool", "bytes32", "bytes4", "address", "uint8",
    "bytes32", "bytes32", "uint64")
MODULE_RECORD = ("uint8", "bytes32", "bytes32", "bytes4", "uint32", "bytes32",
    "bytes32", "bytes32", "string", "uint64", "uint64", "uint64")
POLICY = ("bytes32", "uint16", "bool")
MODULE_REGISTRY = schema_id("MODULE_REGISTRY")
COLLECTION_METADATA = schema_id("COLLECTION_METADATA")
OWNER_RECORDS = schema_id("OWNER_RECORDS")
COLLECTION_ATTESTATIONS = schema_id("COLLECTION_ATTESTATIONS")
VERSIONS = {
    OWNER_RECORDS: ("owner", schema_id("6529stream.owner-records.v1")),
    COLLECTION_ATTESTATIONS: ("independent",
        schema_id("6529stream.collection-attestations.independent.v1")),
    COLLECTION_METADATA: ("metadata",
        schema_id("6529stream.collection-metadata.full-bytes.v1")),
}
STATUS = {1: "ACTIVE", 2: "DEPRECATED", 3: "INCIDENT_REVOKED"}
PROFILE_BYTES = dumps({"name": PROFILE, "version": "1",
    "denominator": "Every module ever registered in the Core current MODULE_REGISTRY instance, plus Core current COLLECTION_METADATA pointer target.",
    "limits": {"modules": str(MAX_MODULES), "metadataRecordTypes": str(MAX_RECORD_TYPES)},
    "knownHosts": [{"kind": kind, "moduleType": module_type, "moduleVersion": version}
        for module_type, (kind, version) in VERSIONS.items()],
    "scopes": {"owner": "exact tokenId", "independent": "deployment scope 0 and exact collectionId",
        "metadata": "exact collectionId"},
    "qualification": "Complete current-registry roster, not a global deployed-host inventory. Alternate registry histories and unregistered compatible writers remain unresolved."})
PROFILE_HASH = keccak256(PROFILE_BYTES)


def _anchor(raw):
    value = loads(raw, maximum=MAX_ANCHOR, canonical=True)
    fields = {"profile", "chainId", "blockHash", "blockNumber", "timestamp", "stateRoot",
        "environment", "deploymentEvidenceHash", "core", "coreRuntimeHash", "tokenId",
        "collectionId"}
    require(isinstance(value, dict) and set(value) == fields and value["profile"] == PROFILE,
        "dossier host anchor shape/profile")
    for key in ("chainId", "blockNumber", "timestamp", "tokenId", "collectionId"):
        uint(value[key])
    require(uint(value["chainId"]) > 0 and uint(value["tokenId"]) > 0
        and uint(value["collectionId"]) > 0 and uint(value["timestamp"]) < 1 << 64,
        "dossier host anchor identity/time")
    for key in ("blockHash", "stateRoot", "deploymentEvidenceHash", "coreRuntimeHash"):
        require(any(hex_bytes(value[key], 32)), "dossier host anchor zero commitment")
    require(any(hex_bytes(value["core"], 20))
        and value["environment"] in ("local_evm_fixture", "public_chain"),
        "dossier host anchor Core/environment")
    return value


def _module_row(address, index, record, runtime_matches):
    return {"index": str(index), "host": address, "status": STATUS[record[0]],
        "moduleType": record[1], "moduleVersion": record[2], "interfaceId": record[3],
        "moduleGasLimit": str(record[4]), "runtimeHash": record[5],
        "runtimeMatches": runtime_matches, "deploymentManifestHash": record[6],
        "moduleManifestHash": record[7], "moduleManifestURI": record[8],
        "registeredAt": str(record[9]), "statusUpdatedAt": str(record[10]),
        "revision": str(record[11])}


class DossierHostsSource:
    """Read a complete current-registry roster and qualified known host scopes."""

    def __init__(self, anchor_bytes, transport, *, provenance="synthetic_fixture"):
        require(provenance in ("synthetic_fixture", "trusted_rpc"), "dossier host provenance")
        require(provenance != "trusted_rpc" or type(transport) in (RpcTransport, ReplayTransport),
            "synthetic transport cannot acquire dossier host provenance")
        self.anchor_bytes = anchor_bytes
        self.a = _anchor(anchor_bytes)
        self.provenance = provenance
        self.reader = RecordingReader(transport, self.a["blockHash"])
        self._started = False
        self._snapshot = None

    def _read(self, target, signature, inputs=(), values=(), outputs=(), maximum=524288):
        raw = hex_bytes(self.reader.call(target, calldata(signature, inputs, values)))
        require(len(raw) <= maximum, "dossier host ABI response bound")
        return decode(outputs, raw, maximum=maximum)

    def _block(self):
        a = self.a
        block = self.reader.request("eth_getBlockByHash", [a["blockHash"], False])
        require(isinstance(block, dict) and block.get("hash") == a["blockHash"]
            and block.get("stateRoot") == a["stateRoot"]
            and quantity(block.get("number")) == uint(a["blockNumber"])
            and quantity(block.get("timestamp")) == uint(a["timestamp"]),
            "dossier host block anchor differs")

    def _pointer(self, pointer_type):
        pointer, = self._read(self.a["core"], "getSatellitePointer(bytes32)", ("bytes32",),
            (pointer_type,), (POINTER,))
        require(pointer[0] != ZERO_ADDRESS and pointer[1] != ZERO and pointer[3] == pointer_type
            and pointer[4] != "0x00000000" and pointer[5] != ZERO_ADDRESS
            and pointer[6] in STATUS and pointer[7] != ZERO and pointer[8] != ZERO
            and pointer[9] > 0, "dossier host Core pointer differs")
        code = hex_bytes(self.reader.code(pointer[0]))
        require(0 < len(code) <= MAX_RUNTIME and keccak256(code) == pointer[1],
            "dossier host selected pointer runtime differs")
        return pointer

    def _known_host(self, module, source, index, record, runtime_matches, scopes):
        module_type, module_version = record[1], record[2]
        kind, supported_version = VERSIONS[module_type]
        base = {"host": module, "kind": kind, "source": source,
            "registeredIndex": None if index is None else str(index), "status": STATUS[record[0]],
            "moduleType": module_type, "moduleVersion": module_version, "interfaceId": record[3],
            "runtimeHash": record[5], "runtimeMatches": runtime_matches, "supported": False,
            "deploymentManifestHash": record[6], "moduleManifestHash": record[7],
            "core": None, "scopes": scopes, "resolution": "unsupported_registered_version",
            "catalog": {"mode": "unresolved", "scopeHeads": [],
                "unresolved": ["unsupported_registered_version"]}}
        if not runtime_matches:
            base["resolution"] = "runtime_changed_or_missing"
            base["catalog"]["unresolved"] = ["runtime_changed_or_missing"]
            return base
        if module_version != supported_version:
            return base
        actual_type, actual_version, actual_interface = (
            self._read(module, "streamModuleType()", outputs=("bytes32",))[0],
            self._read(module, "streamModuleVersion()", outputs=("bytes32",))[0],
            self._read(module, "streamModuleInterfaceId()", outputs=("bytes4",))[0])
        require((actual_type, actual_version, actual_interface) ==
            (module_type, module_version, record[3]), "dossier registered host identity differs")
        supported, = self._read(module, "supportsInterface(bytes4)", ("bytes4",),
            (record[3],), ("bool",))
        require(supported, "dossier registered host interface differs")
        core, = self._read(module, "core()", outputs=("address",))
        base["core"] = core
        if core != self.a["core"]:
            base["resolution"] = "foreign_core"
            base["catalog"]["unresolved"] = ["foreign_core_excluded_from_scope_reads"]
            return base
        base["supported"] = True
        if kind == "owner":
            base["resolution"] = "owner_record_type_catalog_unavailable"
            base["catalog"] = {"mode": "unresolved_no_native_type_enumeration", "scopeHeads": [],
                "unresolved": ["owner_record_type_catalog_unavailable"]}
            return base
        heads = []
        if kind == "independent":
            for record_type in RECORD_TYPES:
                accepted, = self._read(module, "isIndependentRecordType(bytes32)", ("bytes32",),
                    (record_type,), ("bool",))
                require(accepted, "dossier independent fixed type differs")
            for scope in scopes:
                for record_type in RECORD_TYPES:
                    head, count = self._read(module, "recordChainHash(uint256,bytes32)",
                        ("uint256", "bytes32"), (uint(scope), record_type), ("bytes32", "uint64"))
                    require((count == 0) == (head == ZERO), "dossier independent head/count differs")
                    heads.append({"scopeKey": scope, "recordType": record_type,
                        "chainHash": head, "count": str(count)})
            base["catalog"] = {"mode": "fixed_native_v1", "scopeHeads": heads, "unresolved": []}
        else:
            count, = self._read(module, "recordTypeCount()", outputs=("uint256",))
            require(count <= MAX_RECORD_TYPES, "dossier metadata type catalogue bound")
            seen = set()
            for position in range(count):
                record_type, = self._read(module, "recordTypeAt(uint256)", ("uint256",),
                    (position,), ("bytes32",))
                require(record_type != ZERO and record_type not in seen,
                    "dossier metadata type catalogue differs")
                seen.add(record_type)
                policy, = self._read(module, "recordPolicy(bytes32)", ("bytes32",),
                    (record_type,), (POLICY,))
                require(policy[0] != ZERO and policy[1] > 0 and policy[2],
                    "dossier metadata admitted policy differs")
                head, lane_count = self._read(module, "recordChainHash(uint256,bytes32)",
                    ("uint256", "bytes32"), (uint(scopes[0]), record_type), ("bytes32", "uint64"))
                require((lane_count == 0) == (head == ZERO), "dossier metadata head/count differs")
                heads.append({"scopeKey": scopes[0], "recordType": record_type,
                    "family": policy[0], "authorizationMask": str(policy[1]),
                    "chainHash": head, "count": str(lane_count)})
            base["catalog"] = {"mode": "native_enumerated_v1", "scopeHeads": heads,
                "unresolved": []}
        base["resolution"] = "verified_within_current_registry"
        return base

    def snapshot(self):
        if self._snapshot is not None:
            return self._snapshot
        require(not self._started, "failed dossier host capture cannot resume")
        self._started = True
        a, r = self.a, self.reader
        require(quantity(r.request("eth_chainId", [])) == uint(a["chainId"]),
            "dossier host chain differs")
        self._block()
        core_code = hex_bytes(r.code(a["core"]))
        require(0 < len(core_code) <= MAX_RUNTIME and keccak256(core_code) == a["coreRuntimeHash"],
            "dossier host Core runtime differs")
        exists, collection, serial, burned = self._read(a["core"],
            "tokenCollectionIdentity(uint256)", ("uint256",), (uint(a["tokenId"]),),
            ("bool", "uint256", "uint256", "bool"))
        require(exists and collection == uint(a["collectionId"]) and serial > 0,
            "dossier host token/collection identity differs")

        registry_pointer = self._pointer(MODULE_REGISTRY)
        registry = registry_pointer[0]
        supported, = self._read(registry, "supportsInterface(bytes4)", ("bytes4",),
            (registry_pointer[4],), ("bool",))
        require(supported, "dossier current registry interface differs")
        module_count, = self._read(registry, "moduleCount()", outputs=("uint256",))
        chain_hash, record_count = self._read(registry, "registrationChainHash()",
            outputs=("bytes32", "uint64"))
        require(module_count == record_count and module_count <= MAX_MODULES
            and ((module_count == 0) == (chain_hash == ZERO)),
            "dossier current registry count/chain differs")
        modules, relevant, addresses, reconstructed = [], [], set(), ZERO
        for index in range(module_count):
            module, = self._read(registry, "moduleAt(uint256)", ("uint256",),
                (index,), ("address",))
            require(module != ZERO_ADDRESS and module not in addresses,
                "dossier current registry module index differs")
            addresses.add(module)
            record, = self._read(registry, "moduleRecord(address)", ("address",),
                (module,), (MODULE_RECORD,), maximum=8192)
            require(record[0] in STATUS and record[1] != ZERO and record[2] != ZERO
                and record[3] != "0x00000000" and record[5] != ZERO and record[6] != ZERO
                and record[7] != ZERO and len(record[8].encode("utf-8")) <= 2048
                and 0 < record[9] <= record[10] <= uint(a["timestamp"]) and record[11] > 0,
                "dossier current registry module record differs")
            runtime = hex_bytes(r.code(module))
            runtime_matches = 0 < len(runtime) <= MAX_RUNTIME and keccak256(runtime) == record[5]
            row = _module_row(module, index, record, runtime_matches)
            modules.append(row)
            item_hash = keccak256(encode(("bytes32", "address", "bytes32", "bytes4", "bytes32",
                "bytes32", "bytes32", "bytes32"), (schema_id("6529STREAM_MODULE_REGISTRATION_RECORD_V1"),
                module, record[1], record[3], record[2], record[5], record[6], record[7])))
            reconstructed = keccak256(encode(("bytes32", "uint256", "address", "uint256",
                "bytes32", "bytes32", "bytes32", "uint64"),
                (schema_id("6529STREAM_RECORD_CHAIN_V1"), uint(a["chainId"]), registry, 0,
                 schema_id("MODULE_REGISTRATION"), reconstructed, item_hash, index)))
            if record[1] in VERSIONS:
                kind = VERSIONS[record[1]][0]
                scopes = ([a["tokenId"]] if kind == "owner" else
                    ["0", a["collectionId"]] if kind == "independent" else [a["collectionId"]])
                relevant.append(self._known_host(module, "registry", index, record,
                    runtime_matches, scopes))
        require(reconstructed == chain_hash, "dossier current registry chain reconstruction differs")

        metadata_pointer = self._pointer(COLLECTION_METADATA)
        selected = metadata_pointer[0]
        selected_supports, = self._read(selected, "supportsInterface(bytes4)", ("bytes4",),
            (metadata_pointer[4],), ("bool",))
        selected_core, = self._read(selected, "core()", outputs=("address",))
        require(selected_supports and selected_core == a["core"],
            "dossier selected metadata binding differs")
        selected_rows = [row for row in relevant if row["host"] == selected and row["kind"] == "metadata"]
        if metadata_pointer[5] == registry:
            require(len(selected_rows) == 1,
                "dossier selected metadata missing from named current registry")
        if selected_rows:
            require(len(selected_rows) == 1, "duplicate selected metadata host")
            require((selected_rows[0]["moduleType"], selected_rows[0]["interfaceId"],
                selected_rows[0]["runtimeHash"]) ==
                (metadata_pointer[3], metadata_pointer[4], metadata_pointer[1]),
                "dossier selected registered metadata record differs")
            if metadata_pointer[5] == registry:
                require((selected_rows[0]["deploymentManifestHash"],
                    selected_rows[0]["moduleManifestHash"]) ==
                    (metadata_pointer[8], metadata_pointer[7]),
                    "dossier selected metadata immutable manifests differ")
            selected_rows[0]["source"] = "registry_and_selected_metadata"
            selected_row = selected_rows[0]
        else:
            synthetic_record = (metadata_pointer[6], metadata_pointer[3], ZERO,
                metadata_pointer[4], 0, metadata_pointer[1], metadata_pointer[8],
                metadata_pointer[7], "pointer:cached", 1, 1, 1)
            selected_row = self._known_host(selected, "selected_metadata", None,
                synthetic_record, True, [a["collectionId"]])
            selected_row["resolution"] = "selected_metadata_version_unresolved"
            selected_row["catalog"]["unresolved"] = ["selected_metadata_version_unresolved"]
            relevant.append(selected_row)
        selected_row["core"] = selected_core

        self._block()
        if type(r.transport) is ReplayTransport:
            r.transport.finish()
        unresolved = ["host_inventory_not_exhaustive", "alternate_registry_history_incomplete",
            "unregistered_compatible_writers_not_excluded"]
        if any(row["kind"] == "owner" for row in relevant):
            unresolved.append("owner_record_type_catalog_unavailable")
        if selected not in addresses:
            unresolved.append("selected_metadata_not_in_current_registry")
        for row in relevant:
            if row["resolution"] not in ("verified_within_current_registry",):
                unresolved.append("host:" + row["host"] + ":" + row["resolution"])
        source_state = {"chainId": a["chainId"], "core": a["core"], "tokenId": a["tokenId"],
            "collectionId": a["collectionId"], "collectionSerial": str(serial), "burned": burned,
            "blockHash": a["blockHash"], "blockNumber": a["blockNumber"]}
        self._snapshot = dumps({"profile": PROFILE, "profileHash": PROFILE_HASH, "version": "1",
            "mode": "recorded_state" if self.provenance == "trusted_rpc" else "synthetic_fixture",
            "anchorHash": keccak256(self.anchor_bytes), "transcriptHash": keccak256(r.transcript()),
            "sourceState": source_state,
            "registry": {"pointer": json_values(registry_pointer), "host": registry,
                "moduleCount": str(module_count), "registrationChainHash": chain_hash,
                "recordCount": str(record_count), "modules": modules},
            "selectedMetadata": {"pointer": json_values(metadata_pointer), "host": selected},
            "hosts": relevant, "unresolved": unresolved,
            "claims": {"currentRegistryEnumerationComplete": True,
                "currentSelectedMetadataBound": True, "hostInventoryExhaustive": False,
                "alternateRegistryHistoryComplete": False,
                "unregisteredCompatibleWritersExcluded": False, "laneHistoriesComplete": False,
                "actualChainAcceptance": False, "cryptographicStateProof": False,
                "fullObjectDossierConformance": False}})
        return self._snapshot

    def transcript(self):
        require(self._snapshot is not None, "dossier host snapshot required before transcript")
        return self.reader.transcript()


def definitions(directory, *, check=False):
    path = Path(directory) / "dossier-hosts-profile.json"
    if check:
        require(path.is_file() and path.read_bytes() == PROFILE_BYTES,
            "dossier hosts profile differs")
    else:
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes(PROFILE_BYTES)
    return PROFILE_HASH


def _bounded_read(path, maximum):
    with Path(path).open("rb") as stream:
        raw = stream.read(maximum + 1)
    require(len(raw) <= maximum, "dossier host input file bound")
    return raw


def replay(anchor_path, anchor_hash, transcript_path, transcript_hash, output,
           *, provenance="synthetic_fixture"):
    from .bagit import write_tree
    anchor = _bounded_read(anchor_path, MAX_ANCHOR)
    transcript = _bounded_read(transcript_path, MAX_TRANSCRIPT)
    require(keccak256(anchor) == anchor_hash, "dossier host external anchor pin differs")
    source = DossierHostsSource(anchor, ReplayTransport(transcript, transcript_hash), provenance=provenance)
    snapshot = source.snapshot()
    require(source.transcript() == transcript, "dossier host replay transcript differs")
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
    command = sub.add_parser("replay")
    for name in ("anchor", "transcript"):
        command.add_argument("--" + name, type=Path, required=True)
        command.add_argument("--" + name + "-hash", required=True)
    command.add_argument("--provenance", choices=("synthetic_fixture", "trusted_rpc"),
        default="synthetic_fixture")
    command.add_argument("--output", type=Path, required=True)
    command = sub.add_parser("capture")
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
        require(keccak256(anchor) == args.anchor_hash, "dossier host external anchor pin differs")
        require(args.rpc_env in os.environ, "RPC endpoint variable unavailable")
        source = DossierHostsSource(anchor, RpcTransport(os.environ[args.rpc_env]), provenance="trusted_rpc")
        snapshot = source.snapshot(); transcript = source.transcript()
        result = {"profileHash": PROFILE_HASH, "anchorHash": args.anchor_hash,
            "transcriptHash": keccak256(transcript), "snapshotHash": keccak256(snapshot),
            "provenance": "trusted_rpc", "actualChainAcceptance": False}
        write_tree({"anchor.json": anchor, "transcript.json": transcript,
            "snapshot.json": snapshot, "pins.json": dumps(result)}, args.output)
    print(result if type(result) is str else dumps(result).decode())


if __name__ == "__main__": main()

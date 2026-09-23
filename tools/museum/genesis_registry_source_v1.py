"""Bounded replay of the frozen genesis document plan at one selected Registry.

The reader proves the finite 51-name plan against exact EIP-1898 getter results.
It does not enumerate the Registry globally, prove consensus, reconstruct
registration governance, or reinterpret a conflicting same-name document.
"""
from . import genesis_registry_plan_v1 as plan_module
from .canonical import MuseumError, dumps, hex_bytes, keccak256, loads, schema_id, uint
from .chain_abi import Array, calldata, decode, encode
from .chain_rpc import quantity
from .dossier_hosts_source import MODULE_RECORD, POINTER
from .independent_wire import (DOCUMENT, DOCUMENT_SPEC, RAW_BYTES, ZERO, ZERO_ADDRESS,
    json_values, require, verify_document)
from .publication import KINDS
from .public_history_rpc import (MAX_RESPONSE, PublicRecordingReader, PublicReplayTransport,
    PublicRpcTransport)


PROFILE = "STREAM_MUSEUM_GENESIS_REGISTRY_SOURCE_V1"
SOURCE_REVISION = "767733060c482cb7e3150f2e21adea6fe0e00536"
SOURCE_PATHS = (
    "smart-contracts/core/StreamCore.sol",
    "smart-contracts/interfaces/stream/core/IStreamCorePointers.sol",
    "smart-contracts/domains/modules/StreamModuleRegistry.sol",
    "smart-contracts/interfaces/stream/modules/IStreamModuleRegistry.sol",
    "smart-contracts/domains/metadata/StreamCollectionMetadataV1.sol",
    "smart-contracts/domains/metadata/StreamSchemaRegistry.sol",
    "smart-contracts/domains/metadata/StreamSchemaDocumentStore.sol",
    "smart-contracts/interfaces/stream/metadata/IStreamSchemaRegistry.sol",
    "smart-contracts/interfaces/stream/metadata/IStreamSchemaDocumentFacts.sol",
)
SOURCE_BLOBS = {
    "smart-contracts/core/StreamCore.sol": "56e71599e76f29bcf1f9f685e8d93fd6381873226463a37c959c48c34a612185",
    "smart-contracts/interfaces/stream/core/IStreamCorePointers.sol": "d3971717024317891effbb623d6ee4351427d7ba7e6ceed0f79630b5565d3a55",
    "smart-contracts/domains/modules/StreamModuleRegistry.sol": "1cb14bcba74f8e88723141724e0d067dc42a44568e68900b90dea2581e5c7fe9",
    "smart-contracts/interfaces/stream/modules/IStreamModuleRegistry.sol": "1b5a2c48c8beff2a9ee031a3ab9407bd92ebb6b7826928b534844731d1b9fca7",
    "smart-contracts/domains/metadata/StreamCollectionMetadataV1.sol": "7ccfc45622b37ef2a35f7a3c7107cb75cf8a2548c046159aba39f1714429db0e",
    "smart-contracts/domains/metadata/StreamSchemaRegistry.sol": "6e5c9df53ce608e6bdf3ccf026d285464ff093ed9a57fbe26889ffe9e56bf6fc",
    "smart-contracts/domains/metadata/StreamSchemaDocumentStore.sol": "a162258ace7233828bc96a1e0bfb7eed2f8365f7e81b416bb3ce5a035285b5ad",
    "smart-contracts/interfaces/stream/metadata/IStreamSchemaRegistry.sol": "e05fbd4c3321524333d208ecf5a9221f2dccb9a7f1dc1f2e770699e035f2eb5c",
    "smart-contracts/interfaces/stream/metadata/IStreamSchemaDocumentFacts.sol": "004e47eb9941f74513225e1b38c13990a1a30ebedb9237dc8328c49f728be5cb",
}
COMMON = ("chainId", "core", "blockHash", "blockNumber", "timestamp", "stateRoot",
    "environment", "deploymentEvidenceHash")
MAX_ANCHOR = 65536
MAX_ABI = 640 * 1024
MAX_OUTPUT = 16 * 1024 * 1024
MAX_RUNTIME = 24576
MAX_DOCUMENTS = 64
MAX_CHUNKS = 64
# A dynamic-bytes return is offset + length + padded payload. The public-history
# transcript stores it as a JSON hex string, so the native 524288-byte maximum
# cannot fit one MAX_RESPONSE row. Chunk getters remain complete at that edge.
MAX_AGGREGATE_DOCUMENT_BYTES = ((MAX_RESPONSE - 4) // 2 - 64) // 32 * 32
DOCUMENT_FACTS = ("bool", "uint8", "uint8", "bytes32", "bytes32", "bytes32",
    "uint32", "uint256", "bytes32")
COLLECTION_METADATA = schema_id("COLLECTION_METADATA")
STATUS = ("ACTIVE", "DEPRECATED", "ARCHIVED")

CLAIMS = {
    "currentCoreSelectedMetadataBound": True,
    "currentSelectedSchemaRegistryBound": True,
    "completeNamedPlanGetterDenominator": True,
    "presentDocumentBytesAndChunksReconstructed": True,
    "sameNameConflictsPreserved": True,
    "globalRegistryInventoryComplete": False,
    "registrationEventHistoryComplete": False,
    "governanceAuthorizationProven": False,
    "providerCompletenessProven": False,
    "sourceConsensusVerified": False,
    "actualChainAcceptance": False,
    "allNativeUriByteStringsDecodable": False,
}
QUALIFICATION = (
    "The current Core COLLECTION_METADATA pointer, its ACTIVE ModuleRegistry record and the "
    "Metadata host's immutable SchemaRegistry/Store bindings select one Registry at the retained "
    "source block. Every one of the frozen plan's 51 names is read exactly. Present rows retain "
    "their native status, declaration, whole bytes, ordered chunk occurrences, Store pointers and "
    "STOP carrier runtimes; exact absent rows and same-name conflicts remain distinct. The "
    "aggregate documentBytes getter is additionally checked whenever its canonical JSON-RPC "
    "result fits the frozen transport; native-maximum rows are reconstructed from every ordered "
    "chunk instead. The strict shared ABI reader accepts UTF-8 Solidity strings, so a native "
    "document whose URI contains invalid UTF-8 bytes is outside this reader's availability. "
    "Current ACTIVE eligibility is reported separately, so later retirement does not rewrite an "
    "original immutable document. This is named-plan coverage, not a global Registry enumeration, "
    "registration-history proof, governance authorization, RPC completeness, consensus or actual-chain proof."
)
PROFILE_BYTES = dumps({"name": PROFILE, "version": "1", "sourceRevision": SOURCE_REVISION,
    "sourceBlobs": SOURCE_BLOBS, "planProfileHash": plan_module.PROFILE_HASH,
    "counts": {"canonicalSchemas": "29", "supportDocuments": "22", "documents": "51"},
    "limits": {"anchorBytes": str(MAX_ANCHOR), "abiBytes": str(MAX_ABI),
        "snapshotBytes": str(MAX_OUTPUT), "documents": str(MAX_DOCUMENTS),
        "chunksPerDocument": str(MAX_CHUNKS),
        "aggregateDocumentGetterPayloadBytes": str(MAX_AGGREGATE_DOCUMENT_BYTES)},
    "claims": CLAIMS, "qualification": QUALIFICATION})
PROFILE_HASH = keccak256(PROFILE_BYTES)


def _zero(kind):
    if isinstance(kind, Array): return ()
    if isinstance(kind, tuple): return tuple(_zero(item) for item in kind)
    if kind == "bool": return False
    if kind == "address": return ZERO_ADDRESS
    if kind.startswith("bytes"): return "0x" + "00" * int(kind[5:])
    if kind == "string": return ""
    return 0


ZERO_DOCUMENT = _zero(DOCUMENT)
ZERO_FACTS = _zero(DOCUMENT_FACTS)


def _pin_rows(value):
    require(type(value) is list and 6 <= len(value) <= 64, "genesis Registry code pin bound")
    result = {}
    for row in value:
        require(type(row) is dict and set(row) == {"address", "runtimeHash"}
            and row["address"] not in result and any(hex_bytes(row["address"], 20))
            and any(hex_bytes(row["runtimeHash"], 32)), "genesis Registry invalid/duplicate code pin")
        result[row["address"]] = row["runtimeHash"]
    return result


class GenesisRegistrySource:
    def __init__(self, anchor_bytes, transport, *, plan_files, plan_hash,
                 provenance="synthetic_fixture"):
        require(provenance in ("synthetic_fixture", "trusted_rpc")
            and (provenance != "trusted_rpc"
                or type(transport) in (PublicRpcTransport, PublicReplayTransport)),
            "genesis Registry provenance")
        anchor = loads(anchor_bytes, maximum=MAX_ANCHOR, canonical=True)
        keys = set(COMMON) | {"profile", "coreRuntimeHash", "codePins", "runtimeAdmission"}
        require(type(anchor) is dict and set(anchor) == keys and anchor["profile"] == PROFILE,
            "genesis Registry anchor shape/profile")
        require(uint(anchor["chainId"]) > 0 and uint(anchor["blockNumber"]) >= 0
            and 0 < uint(anchor["timestamp"]) < 1 << 64
            and anchor["environment"] in ("local_evm_fixture", "public_chain")
            and any(hex_bytes(anchor["core"], 20)), "genesis Registry source identity")
        for key in ("blockHash", "stateRoot", "deploymentEvidenceHash", "coreRuntimeHash"):
            require(any(hex_bytes(anchor[key], 32)), "genesis Registry zero source commitment")
        admission = anchor["runtimeAdmission"]
        require(type(admission) is dict and set(admission) == {"sourceCommit", "kind", "artifactHash"}
            and admission["sourceCommit"] == SOURCE_REVISION
            and admission["kind"] == ("synthetic_fixture" if provenance == "synthetic_fixture"
                else "externally_admitted_runtime")
            and any(hex_bytes(admission["artifactHash"], 32)),
            "genesis Registry runtime admission differs")
        self.pins = _pin_rows(anchor["codePins"])
        require(anchor["core"] in self.pins and self.pins[anchor["core"]] == anchor["coreRuntimeHash"],
            "genesis Registry Core pin differs")
        self.plan = plan_module.admit(dict(plan_files), plan_hash)
        require(len(self.plan.documents) == 51 and len(self.plan.canonical_names) == 29,
            "genesis Registry plan denominator")
        self.a, self.anchor_bytes, self.provenance = anchor, anchor_bytes, provenance
        self.reader = PublicRecordingReader(transport, anchor["blockHash"])
        self._started, self._snapshot = False, None
        self.runtime_pins, self.chunks = {}, {}

    def _read(self, target, signature, outputs, inputs=(), values=(), maximum=MAX_ABI):
        raw = hex_bytes(self.reader.call(target, calldata(signature, inputs, values)))
        require(len(raw) <= maximum, "genesis Registry ABI response bound")
        return decode(outputs, raw, maximum=maximum)

    def _one(self, target, signature, output, inputs=(), values=(), maximum=MAX_ABI):
        return self._read(target, signature, (output,), inputs, values, maximum)[0]

    def _code(self, address, expected=None, maximum=MAX_RUNTIME):
        code = hex_bytes(self.reader.code(address))
        require(0 < len(code) <= maximum and (expected is None or keccak256(code) == expected),
            "genesis Registry runtime differs")
        digest = keccak256(code)
        require(address not in self.runtime_pins or self.runtime_pins[address] == digest,
            "genesis Registry conflicting runtime observation")
        self.runtime_pins[address] = digest
        return code

    def _pin(self, address):
        require(address in self.pins, "genesis Registry discovered dependency has no external pin")
        return self._code(address, self.pins[address])

    def _source(self):
        a = self.a
        require(quantity(self.reader.request("eth_chainId", [])) == uint(a["chainId"]),
            "genesis Registry chain differs")
        by_hash = self.reader.request("eth_getBlockByHash", [a["blockHash"], False])
        by_number = self.reader.request("eth_getBlockByNumber", [hex(uint(a["blockNumber"])), False])
        require(dumps(by_hash) == dumps(by_number),
            "genesis Registry block hash/number observations differ")
        for block in (by_hash, by_number):
            require(type(block) is dict and block.get("hash") == a["blockHash"]
                and block.get("stateRoot") == a["stateRoot"]
                and quantity(block.get("number")) == uint(a["blockNumber"])
                and quantity(block.get("timestamp")) == uint(a["timestamp"]),
                "genesis Registry block anchor differs")

    def _pointer(self, kind):
        row = self._one(self.a["core"], "getSatellitePointer(bytes32)", POINTER,
            ("bytes32",), (kind,))
        require(row[0] != ZERO_ADDRESS and row[1] != ZERO and row[3] == kind
            and row[4] != "0x00000000" and row[5] != ZERO_ADDRESS and row[6] == 1
            and row[7] != ZERO and row[8] != ZERO and row[9] > 0,
            "genesis Registry Core pointer differs")
        self._pin(row[0])
        require(row[1] == self.pins[row[0]],
            "genesis Registry Core pointer runtime pin differs")
        return row

    def _graph(self):
        a = self.a
        self._pin(a["core"])
        metadata = self._pointer(COLLECTION_METADATA)
        module_registry, host = metadata[5], metadata[0]
        self._pin(module_registry)
        record = self._one(module_registry, "moduleRecord(address)", MODULE_RECORD,
            ("address",), (host,))
        require(record[0] == 1 and record[1] == COLLECTION_METADATA and record[3] == metadata[4]
            and record[5] == metadata[1] and record[6] == metadata[8]
            and record[7] == metadata[7] and record[11] > 0
            and self._one(module_registry,
                "isModuleEligible(address,bytes32,bytes4)", "bool",
                ("address", "bytes32", "bytes4"), (host, COLLECTION_METADATA, metadata[4])),
            "genesis Registry selected Metadata is not currently ACTIVE")
        core = self._one(host, "core()", "address")
        core_hash = self._one(host, "coreCodeHash()", "bytes32")
        schemas = self._one(host, "schemaRegistry()", "address")
        schemas_hash = self._one(host, "schemaRegistryCodeHash()", "bytes32")
        store = self._one(host, "chunkStore()", "address")
        store_hash = self._one(host, "chunkStoreCodeHash()", "bytes32")
        require(core == a["core"] and core_hash == self.pins[a["core"]]
            and schemas != ZERO_ADDRESS and store != ZERO_ADDRESS,
            "genesis Registry Metadata immutable graph differs")
        self._pin(schemas); self._pin(store)
        require(schemas_hash == self.pins[schemas] and store_hash == self.pins[store]
            and self._one(schemas, "chunkStore()", "address") == store,
            "genesis Registry Registry/Store binding differs")
        governance = self._one(schemas, "governanceAuthority()", "address")
        governance_hash = self._one(schemas, "governanceAuthorityCodeHash()", "bytes32")
        metadata_governance = self._one(host, "governanceAuthority()", "address")
        metadata_governance_hash = self._one(host, "executorCodeHash()", "bytes32")
        self._pin(governance)
        require(governance == metadata_governance
            and governance_hash == metadata_governance_hash == self.pins[governance]
            and self._one(schemas, "MAX_DOCUMENT_CHUNKS()", "uint256") == 64
            and self._one(schemas, "CHUNK_BYTES()", "uint256") == 8192
            and self._one(schemas, "MAX_DOCUMENT_BYTES()", "uint256") == 524288
            and self._one(schemas, "RAW_BYTES()", "bytes32") == RAW_BYTES
            and self._one(store, "MAX_CHUNK_BYTES()", "uint256") == 8192,
            "genesis Registry native limits/authority differ")
        base = {a["core"], host, module_registry, schemas, store, governance}
        require(len(base) == 6 and set(self.pins) == base,
            "genesis Registry anchor runtime pin denominator")
        return {"collectionMetadataPointer": json_values(metadata),
            "metadataModuleRecord": json_values(record), "metadataHost": host,
            "metadataAdmissionRegistry": module_registry, "schemaRegistry": schemas,
            "chunkStore": store, "governanceAuthority": governance,
            "governanceAuthorityRuntimeHash": governance_hash}

    def _chunk(self, store, digest):
        if digest in self.chunks: return self.chunks[digest]
        pointer, length = self._read(store, "chunk(bytes32)", ("address", "uint32"),
            ("bytes32",), (digest,))
        raw = self._one(store, "readChunk(bytes32)", "bytes", ("bytes32",), (digest,))
        runtime = self._code(pointer, maximum=8193)
        require(pointer != ZERO_ADDRESS and 0 < length <= 8192 and len(raw) == length
            and keccak256(raw) == digest and runtime == b"\0" + raw,
            "genesis Registry Store chunk differs")
        row = {"chunkHash": digest, "pointer": pointer, "byteLength": str(length),
            "runtimeHash": keccak256(runtime), "runtime": "0x" + runtime.hex(),
            "payloadHex": "0x" + raw.hex()}
        self.chunks[digest] = row
        return row

    def _document(self, index, expected, schemas, store):
        identifier = schema_id(expected.name)
        document = self._one(schemas, "document(bytes32)", DOCUMENT,
            ("bytes32",), (identifier,))
        facts = self._one(schemas, "documentFacts(bytes32)", DOCUMENT_FACTS,
            ("bytes32",), (identifier,))
        base = {"index": str(index), "documentId": identifier, "name": expected.name,
            "expected": expected.metadata(), "document": json_values(document),
            "facts": json_values(facts)}
        if not document[0]:
            require(document == ZERO_DOCUMENT and facts == ZERO_FACTS,
                "genesis Registry partial absent document")
            return {**base, "outcome": "absent", "matchesPlan": False,
                "currentStatus": None, "currentEligible": False,
                "payloadHex": None, "chunks": []}
        require(document[1] in (0, 1, 2) and document[3][1] in tuple(KINDS.values())
            and 0 < document[3][6] <= 524288
            and 0 < len(document[4]) <= MAX_CHUNKS,
            "genesis Registry document status/kind/size/chunk bound")
        require(facts == (True, document[3][1], document[1], document[3][2],
            document[3][3], document[3][4], document[3][6], len(document[4]), document[2]),
            "genesis Registry document/facts differ")
        require(identifier != RAW_BYTES or document[1] == 0,
            "genesis Registry RAW_BYTES status is not permanently ACTIVE")
        chunks, assembled = [], []
        for chunk_index, digest in enumerate(document[4]):
            require(self._one(schemas, "documentChunkHashAt(bytes32,uint256)", "bytes32",
                ("bytes32", "uint256"), (identifier, chunk_index)) == digest,
                "genesis Registry ordered chunk getter differs")
            row = self._chunk(store, digest)
            raw = hex_bytes(row["payloadHex"])
            require(chunk_index + 1 == len(document[4]) or len(raw) == 8192,
                "genesis Registry nonfinal chunk width")
            assembled.append(raw); chunks.append({"index": str(chunk_index), **row})
        payload = b"".join(assembled)
        verified = verify_document(identifier, encode((DOCUMENT,), (document,)), payload)
        require(verified == document, "genesis Registry document verification differs")
        aggregate = "omitted_transport_bound"
        if len(payload) <= MAX_AGGREGATE_DOCUMENT_BYTES:
            require(self._one(schemas, "documentBytes(bytes32)", "bytes",
                ("bytes32",), (identifier,), maximum=MAX_ABI) == payload,
                "genesis Registry aggregate document bytes differ")
            aggregate = "queried_exact"
        spec = (expected.name, KINDS[expected.kind], keccak256(expected.content),
            expected.canonicalization_id, expected.supersedes_id, expected.uri,
            len(expected.content))
        hashes = tuple(keccak256(raw) for raw in expected.chunks)
        matches = document[3] == spec and document[4] == hashes and payload == expected.content
        status = STATUS[document[1]]
        return {**base, "outcome": status.lower() if matches else "conflict",
            "matchesPlan": matches, "currentStatus": status,
            "currentEligible": False, "aggregateGetter": aggregate,
            "payloadHex": "0x" + payload.hex(), "chunks": chunks}

    def _documents(self, graph):
        schemas, store = graph["schemaRegistry"], graph["chunkStore"]
        rows, size = [], 0
        for index, expected in enumerate(self.plan.documents):
            row = self._document(index, expected, schemas, store)
            size += len(dumps(row))
            require(size <= MAX_OUTPUT, "genesis Registry document rows byte bound")
            rows.append(row)
        by_id = {row["documentId"]: row for row in rows}
        for row in rows:
            if row["outcome"] == "absent": continue
            kind = uint(row["document"][3][1])
            canonical_id = row["document"][3][3]
            predecessor_id = row["document"][3][4]
            canonical = by_id.get(canonical_id)
            if canonical is not None:
                require(canonical["outcome"] != "absent"
                    and uint(canonical["document"][3][1]) == KINDS["CANONICALIZATION"],
                    "genesis Registry named canonicalizer is absent or wrong kind")
            predecessor = by_id.get(predecessor_id) if predecessor_id != ZERO else None
            if predecessor_id != ZERO and predecessor is not None:
                require(predecessor["outcome"] != "absent"
                    and uint(predecessor["document"][3][1]) == kind,
                    "genesis Registry named predecessor is absent or wrong kind")
            row["canonicalizationStatus"] = None if canonical is None else canonical["currentStatus"]
            row["currentEligible"] = (row["matchesPlan"]
                and row["currentStatus"] == "ACTIVE" and canonical is not None
                and canonical["matchesPlan"] and canonical["currentStatus"] == "ACTIVE")
        # Registration checks dependencies before inserting a new ID, so the
        # immutable named rows form a DAG. RAW_BYTES is the one native bootstrap
        # whose canonicalization edge intentionally points to itself.
        edges = {}
        for row in rows:
            if row["outcome"] == "absent": continue
            document_id, spec = row["documentId"], row["document"][3]
            dependencies = []
            if spec[3] in by_id and not (document_id == RAW_BYTES and spec[3] == RAW_BYTES):
                dependencies.append(spec[3])
            if spec[4] != ZERO and spec[4] in by_id:
                dependencies.append(spec[4])
            require(document_id not in dependencies,
                "genesis Registry named document dependency self-cycle")
            edges[document_id] = tuple(dependencies)
        visiting, visited = set(), set()
        def visit(document_id):
            require(document_id not in visiting,
                "genesis Registry named document dependency cycle")
            if document_id in visited: return
            visiting.add(document_id)
            for dependency in edges.get(document_id, ()): visit(dependency)
            visiting.remove(document_id); visited.add(document_id)
        for document_id in edges: visit(document_id)
        canonical_names = set(self.plan.canonical_names)
        counts = {name: sum(row["outcome"] == name for row in rows)
            for name in ("absent", "active", "deprecated", "archived", "conflict")}
        coverage = {"documentCount": str(len(rows)), "canonicalSchemaCount": "29",
            "supportDocumentCount": "22", "outcomes": {key: str(value) for key, value in counts.items()},
            "canonicalSchemasExact": str(sum(row["name"] in canonical_names and row["matchesPlan"] for row in rows)),
            "allPlanDocumentsPresentAndExact": all(row["matchesPlan"] for row in rows),
            "allPlanDocumentsCurrentlyEligible": all(row["currentEligible"] for row in rows)}
        return rows, coverage

    def _capture(self):
        self._source()
        graph = self._graph()
        documents, coverage = self._documents(graph)
        # Re-read the exact same canonical source headers after every native getter.
        self._source()
        if type(self.reader.transport) is PublicReplayTransport:
            self.reader.transport.finish()
        runtime_pins = [{"address": address, "runtimeHash": digest}
            for address, digest in sorted(self.runtime_pins.items())]
        graph["runtimePins"] = runtime_pins
        raw = dumps({"profile": PROFILE, "profileHash": PROFILE_HASH, "version": "1",
            "sourceReviewCommit": SOURCE_REVISION, "source": self.a,
            "sourceState": {key: self.a[key] for key in COMMON},
            "provenance": self.provenance, "anchorHash": keccak256(self.anchor_bytes),
            "transcriptHash": keccak256(self.reader.transcript()), "graph": graph,
            "plan": {"profileHash": plan_module.PROFILE_HASH,
                "manifestHash": self.plan.manifest_hash, "canonicalNameCount": "29",
                "supportDocumentCount": "22", "documentCount": "51"},
            "documents": documents, "coverage": coverage,
            "claims": CLAIMS, "qualification": QUALIFICATION})
        require(len(raw) <= MAX_OUTPUT, "genesis Registry snapshot byte bound")
        return raw

    def snapshot(self):
        if self._snapshot is not None: return self._snapshot
        require(not self._started, "failed genesis Registry capture cannot resume")
        self._started = True
        try:
            self._snapshot = self._capture()
        except MuseumError:
            raise
        except (KeyError, TypeError, IndexError, ValueError, OverflowError) as exc:
            raise MuseumError("malformed genesis Registry evidence") from exc
        return self._snapshot

    def transcript(self):
        require(self._snapshot is not None,
            "genesis Registry snapshot required before transcript")
        return self.reader.transcript()

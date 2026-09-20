"""Original collection ONCHAIN finality and token content proof from pinned public reads.

Historical commitments are retained separately from current readiness. No live
role, render or archival liveness check can replace the original preimages.
"""
from . import native_finality_wire as wire
from . import conservation_capture_join as observations
from .canonical import MuseumError, dumps, hex_bytes, keccak256, loads, schema_id, subject_id, uint
from .chain_abi import Array, calldata, decode, encode
from .independent_wire import RAW_BYTES, ZERO, ZERO_ADDRESS, json_values, require
from .current_rights_source import DOCUMENT_FACTS
from .public_chain_history import scan_public_history, PROFILE_HASH as HISTORY_PROFILE_HASH
from .public_history_rpc import PublicRecordingReader, PublicReplayTransport, PublicRpcTransport

PROFILE = "STREAM_MUSEUM_PUBLIC_COLLECTION_FINALITY_SOURCE_V1"
SOURCE_REVISION = "e031ce6f5f7a79f8c098d4ad0242ee02ce1b0116"
COMMON = observations.COMMON
MAX_ANCHOR, MAX_OUTPUT, MAX_ROOTS, MAX_CHUNKS = 65536, 32 * 1024 * 1024, wire.MAX_ROOT_HISTORY, 64
ADDRESSES = ("core", "host", "router", "originalFinality", "contentProvider", "coreAdapter",
    "leafManifest", "checkpoint", "inventory", "artifactCoverage", "schemas", "store",
    "artistRegistry", "executor", "roles")
CLAIMS = {"originalNativeFinalityRetained": True, "originalManifestPreimageChecked": True,
    "fullCapturedCollectionRootLineage": True, "originalLeafManifestReconstructed": True,
    "nativeTokenProofChecked": True, "historicalCoreFactsPreimageRecovered": False,
    "completeGovernanceCallMetadataReconstructed": False, "actionIdPreimageReconstructed": False,
    "originalProposerRoleReexecuted": False, "originalArtistConsentReexecuted": False,
    "currentArchiveLivenessRequired": False, "originalRenderedBytesReexecuted": False,
    "allFinalityScopesCaptured": False, "institutionIdentityProven": False,
    "providerLogCompletenessTrusted": True, "sourceConsensusVerified": False,
    "actualChainAcceptance": False, "completeAcquisitionPacket": False}
CLAIMS.update(batchCallMetadataVerified=False, executionTransactionInputCaptured=False, completeAuthority=False)
QUALIFICATION = (
    "Pinned original collection inline ONCHAIN finality evidence. Exact original typed manifest, "
    "stored components, root publication, complete preserved leaf bytes and ordered token proof "
    "are reconstructed. Historical Core facts remain a hash with unknown field preimage. "
    "Original Executor/proposer/role and Artist publication witnesses are retained without "
    "reexecuting their historical authority. Scheduled bytes do not supply arbitrary batch "
    "call metadata or an action-ID preimage; first-call aggregate fields never substitute for "
    "the finality call. Current state cannot rewrite original commitments. Other scopes and "
    "STATIC, policy-V2, VIEW or chunked profiles are outside this supported proof profile. "
    "Provider completeness, canonical mapping, original execution and consensus remain trust boundaries.")
GRAPH_MAP = {key: key for key in wire.GRAPH_KEYS} | {"artist": "artistRegistry", "finality": "originalFinality",
    "provider": "contentProvider", "metadata": "host", "artifacts": "artifactCoverage"}
# Exact immutable/native joins; current roles and current readiness are deliberately absent.
ADDRESS_BINDINGS = (
    ("originalFinality", "coreReads", "core"), ("originalFinality", "coreFinalityAdapter", "coreAdapter"),
    ("originalFinality", "metadataReads", "host"), ("originalFinality", "scopeEvidenceProvider", "contentProvider"),
    ("originalFinality", "sanctionReads", "artistRegistry"), ("originalFinality", "artifactCoverage", "artifactCoverage"),
    ("originalFinality", "finalityRoleRegistry", "roles"), ("originalFinality", "governanceAuthority", "executor"),
    ("coreAdapter", "core", "core"), ("coreAdapter", "collectionMetadata", "host"),
    ("coreAdapter", "evidenceProvider", "contentProvider"),
    ("contentProvider", "metadataHost", "host"), ("contentProvider", "contentLeafManifest", "leafManifest"),
    ("contentProvider", "schemaRegistry", "schemas"), ("router", "core", "core"),
    ("host", "core", "core"), ("host", "schemaRegistry", "schemas"), ("host", "chunkStore", "store"),
    ("leafManifest", "core", "core"), ("leafManifest", "contentCheckpoint", "checkpoint"),
    ("leafManifest", "artifactCoverage", "artifactCoverage"), ("checkpoint", "core", "core"),
    ("checkpoint", "metadataRouter", "router"), ("checkpoint", "tokenInventory", "inventory"),
    ("inventory", "core", "core"), ("artifactCoverage", "core", "core"),
    ("artifactCoverage", "schemaRegistry", "schemas"), ("artifactCoverage", "chunkStore", "store"),
    ("artifactCoverage", "finalityRegistry", "originalFinality"), ("schemas", "chunkStore", "store"),
    ("executor", "roleRegistry", "roles"), ("roles", "owner", "executor"))
HASH_BINDINGS = (
    ("originalFinality", "scopeEvidenceProviderCodeHash", "contentProvider"),
    ("contentProvider", "metadataHostCodeHash", "host"), ("contentProvider", "schemaRegistryCodeHash", "schemas"),
    ("contentProvider", "contentLeafManifestCodeHash", "leafManifest"),
    ("leafManifest", "checkpointCodeHash", "checkpoint"), ("leafManifest", "coverageCodeHash", "artifactCoverage"),
    ("checkpoint", "coreCodeHash", "core"), ("checkpoint", "routerCodeHash", "router"),
    ("checkpoint", "inventoryCodeHash", "inventory"))
PROFILE_BYTES = dumps({"name": PROFILE, "version": "1", "sourceReviewCommit": SOURCE_REVISION,
    "historyProfileHash": HISTORY_PROFILE_HASH, "supportedProfile": "collection_inline_ONCHAIN_V1",
    "bounds": {"anchorBytes": str(MAX_ANCHOR), "outputBytes": str(MAX_OUTPUT), "roots": str(MAX_ROOTS),
        "leaves": str(wire.MAX_LEAVES), "chunks": str(MAX_CHUNKS)},
    "definitions": [{key: row[key] for key in ("name", "id", "kind", "hash")} for row in wire.definitions()],
    "rules": ["Original router finality anchor and immutable reciprocal graph runtime pins; no current finality pointer substitution.",
        "Read original stored collection receipt, all components and staged ABI manifest; retain exact schema Store bytes.",
        "Select Statement.inputs.rootRecordHash, retain complete observed collection root lineage and corresponding publication events.",
        "Reconstruct original complete inline checkpoint, leaf manifest and preserved artifact bytes; ordered odd-promoting native proof.",
        "Match stored execution/archive witnesses and scheduled ABI bytes to exact canonical archived finalizer calldata.",
        "All original event bytes and chronology correspond to successful receipts and canonical provider headers.",
        "Coverage completion receipt retained; per-chunk archival proof and full GovernanceCall batch metadata are not reconstructed."],
    "claims": CLAIMS, "qualification": QUALIFICATION})
PROFILE_HASH = keccak256(PROFILE_BYTES)


def _topic(kind, value): return "0x" + encode((kind,), (value,)).hex()
def _hex(raw): return "0x" + raw.hex()


class PublicFinalitySource:
    def __init__(self, anchor_bytes, transport, *, provenance="synthetic_fixture"):
        require(provenance in ("synthetic_fixture", "trusted_rpc") and
            (provenance != "trusted_rpc" or type(transport) in (PublicRpcTransport, PublicReplayTransport)),
            "finality source provenance")
        a = loads(anchor_bytes, maximum=MAX_ANCHOR, canonical=True)
        require(type(a) is dict and set(a) == set(COMMON) | set(ADDRESSES) |
            {"profile", "tokenId", "codePins", "runtimeAdmission"} and a["profile"] == PROFILE,
            "finality source anchor shape/profile")
        require(all(uint(a[key]) > 0 for key in ("chainId", "collectionId", "tokenId"))
            and a["environment"] in ("local_evm_fixture", "public_chain"), "finality source identity")
        uint(a["blockNumber"]); uint(a["timestamp"], 64)
        for key in ("blockHash", "stateRoot", "deploymentEvidenceHash"):
            require(any(hex_bytes(a[key], 32)), "finality source anchor commitment")
        admission = a["runtimeAdmission"]
        require(type(admission) is dict and set(admission) == {"sourceCommit", "kind", "artifactHash"}
            and admission["sourceCommit"] == SOURCE_REVISION and any(hex_bytes(admission["artifactHash"], 32))
            and admission["kind"] == ("synthetic_fixture" if provenance == "synthetic_fixture" else "externally_admitted_runtime"),
            "finality source runtime admission")
        require(type(a["codePins"]) is list and len(ADDRESSES) <= len(a["codePins"]) <= 256,
            "finality source code pin bound")
        pins = {}
        for row in a["codePins"]:
            require(type(row) is dict and set(row) == {"address", "runtimeHash"}
                and any(hex_bytes(row["address"], 20)) and any(hex_bytes(row["runtimeHash"], 32))
                and row["address"] not in pins, "finality source code pin")
            pins[row["address"]] = row["runtimeHash"]
        require(len({a[key] for key in ADDRESSES}) == len(ADDRESSES)
            and all(a[key] in pins for key in ADDRESSES), "finality source required graph pins")
        self.a, self.anchor_bytes, self.pins, self.provenance = a, anchor_bytes, pins, provenance
        self.reader = PublicRecordingReader(transport, a["blockHash"])
        self._reads, self._histories = {}, []
        self.documents, self.chunks = {}, {}
        self._started, self._snapshot = False, None

    def _read(self, target, signature, outputs, inputs=(), values=(), *, maximum=65536):
        data = calldata(signature, inputs, values)
        raw = hex_bytes(self.reader.call(target, data))
        require(len(raw) <= maximum, "finality source return bound")
        key = (target, data)
        require(key not in self._reads or self._reads[key] == raw, "finality source repeated read differs")
        self._reads[key] = raw
        return decode(outputs, raw, maximum=maximum)

    def _one(self, target, signature, output, inputs=(), values=(), *, maximum=65536):
        return self._read(target, signature, (output,), inputs, values, maximum=maximum)[0]

    def _history(self, address, topics):
        history = scan_public_history(self.reader, self.a, filters=[{"address": address, "topics": topics}])
        self._histories.append(history)
        return history

    def _carrier(self, pointer, digest, maximum):
        require(pointer != ZERO_ADDRESS and digest != ZERO, "finality source carrier commitment")
        code = hex_bytes(self.reader.code(pointer))
        require(1 < len(code) <= maximum + 1 and code[0] == 0 and keccak256(code) == digest,
            "finality source immutable carrier differs")
        return code[1:]

    def _state(self):
        a = self.a
        identity = self._read(a["core"], "tokenCollectionIdentity(uint256)",
            ("bool", "uint256", "uint256", "bool"), ("uint256",), (uint(a["tokenId"]),))
        lifecycle = self._one(a["core"], "tokenLifecycle(uint256)", "uint8", ("uint256",), (uint(a["tokenId"]),))
        require(identity[0] and identity[1] == uint(a["collectionId"]) and identity[2] > 0
            and lifecycle in (2, 3) and identity[3] == (lifecycle == 3), "finality source token identity")
        self.identity = {"tokenId": a["tokenId"], "collectionId": a["collectionId"], "collectionSerial": str(identity[2]),
            "lifecycle": str(lifecycle), "burned": identity[3]}
        return {key: a[key] for key in ("chainId", "core", "collectionId", "tokenId", "blockNumber", "blockHash")} | {
            "collectionSerial": str(identity[2]), "examinedAt": a["timestamp"], "burned": lifecycle == 3,
            "subjectId": subject_id("token", a["chainId"], a["core"], a["collectionId"], token_id=a["tokenId"]),
            "collectionSubjectId": subject_id("collection", a["chainId"], a["core"], a["collectionId"])}

    def _bindings(self):
        a = self.a
        for target, digest in self.pins.items():
            code = hex_bytes(self.reader.code(target))
            require(0 < len(code) <= 24576 and keccak256(code) == digest, "finality source runtime pin differs")
        for source, getter, target in ADDRESS_BINDINGS:
            require(self._one(a[source], getter + "()", "address") == a[target], "finality source reciprocal binding differs")
        for source, getter, target in HASH_BINDINGS:
            require(self._one(a[source], getter + "()", "bytes32") == self.pins[a[target]], "finality source immutable runtime pin differs")
        for source, getter, target, kind in wire.BINDINGS:
            expected = a[GRAPH_MAP[target]] if kind == "address" else self.pins[a[GRAPH_MAP[target]]]
            require(self._one(a[GRAPH_MAP[source]], getter, "address" if kind == "address" else "bytes32") == expected,
                "finality source native graph binding differs")
        for key in ("leafManifest", "checkpoint", "contentProvider"):
            require(self._one(a[key], "deploymentChainId()", "uint256") == uint(a["chainId"]), "finality source deployment chain differs")
        original = (a["originalFinality"], self.pins[a["originalFinality"]])
        serving = self._read(a["router"], "servingOriginalFinalityAnchor()", ("address", "bytes32"))
        saved = self._read(a["router"], "originalFinalityAnchor(uint256)", ("address", "bytes32"),
            ("uint256",), (uint(a["collectionId"]),))
        require(serving == original and saved in ((ZERO_ADDRESS, ZERO), original), "finality source original router anchor differs")
        for key, interface in (("coreAdapter", "0xebf35615"), ("router", wire.INTERFACES["root"]), ("leafManifest", wire.INTERFACES["leafManifest"]),
                ("checkpoint", wire.INTERFACES["checkpoint"]), ("inventory", wire.INTERFACES["inventory"])):
            for item in ("0x01ffc9a7", interface):
                require(self._one(a[key], "supportsInterface(bytes4)", "bool", ("bytes4",), (item,)), "finality source interface missing")
            require(not self._one(a[key], "supportsInterface(bytes4)", "bool", ("bytes4",), ("0xffffffff",)), "finality source invalid interface")
        return {key: {"address": a[GRAPH_MAP[key]], "runtimeHash": self.pins[a[GRAPH_MAP[key]]]} for key in wire.GRAPH_KEYS}

    def _chunk(self, digest):
        if digest not in self.chunks:
            pointer, length = self._read(self.a["store"], "chunk(bytes32)", ("address", "uint32"), ("bytes32",), (digest,))
            code = hex_bytes(self.reader.code(pointer))
            require(pointer != ZERO_ADDRESS and 0 < length <= 8192 and len(code) == length + 1
                and code[0] == 0 and keccak256(code[1:]) == digest, "finality source Store chunk differs")
            self.chunks[digest] = {"pointer": pointer, "runtime": _hex(code)}
        return hex_bytes(self.chunks[digest]["runtime"])[1:]

    def _definitions(self):
        for definition in wire.definitions():
            key, expected = definition["id"], definition["bytes"]
            facts = self._one(self.a["schemas"], "documentFacts(bytes32)", DOCUMENT_FACTS, ("bytes32",), (key,))
            require(facts[0] and facts[1] == definition["kind"] and facts[2] in (0, 1, 2)
                and facts[3:7] == (definition["hash"], RAW_BYTES, ZERO, len(expected))
                and facts[7] == 1 and facts[8] != ZERO, "finality source original definition facts differ")
            digest = self._one(self.a["schemas"], "documentChunkHashAt(bytes32,uint256)", "bytes32",
                ("bytes32", "uint256"), (key, 0))
            require(self._chunk(digest) == expected, "finality source native definition bytes differ")
            self.documents[key] = {"documentId": key, "facts": json_values(facts), "chunkHashes": [digest], "payloadHex": _hex(expected)}

    def _finality(self):
        a, cid = self.a, uint(self.a["collectionId"])
        host = a["originalFinality"]
        record = self._one(host, "collectionFinalityRecord(uint256)", wire.FINALITY_RECORD, ("uint256",), (cid,))
        require(record[0] and record[1] != ZERO, "finality source collection is not finalized")
        count = self._one(host, "finalityComponentCount(uint256)", "uint256", ("uint256",), (cid,))
        require(count == 10, "finality source unsupported native component count")
        components = self._one(host, "finalityComponents(uint256,uint256,uint256)", Array(wire.COMPONENT, 32),
            ("uint256", "uint256", "uint256"), (cid, 0, count))
        require(len(components) == count and self._one(host, "finalityManifestStored(bytes32)", "bool", ("bytes32",), (record[2],)),
            "finality source original manifest/components unavailable")
        raw = self._one(host, "finalityManifestBytes(bytes32)", "bytes", ("bytes32",), (record[2],), maximum=wire.MAX_MANIFEST + 64)
        require(0 < len(raw) <= wire.MAX_MANIFEST and self._chunk(record[2]) == raw,
            "finality source original registry/Store manifest bytes differ")
        statement = decode(wire.INPUT_ENVELOPE, raw, maximum=wire.MAX_MANIFEST)[6]
        witness = self._one(host, "finalityExecutionWitness(bytes32)", wire.EXECUTION_WITNESS, ("bytes32",), (record[1],))
        archive = self._one(host, "finalitySanctionArchiveWitness(bytes32)", wire.ARCHIVE_WITNESS, ("bytes32",), (record[1],))
        return {"record": json_values(record), "components": json_values(components), "manifestBytes": _hex(raw),
            "manifestRef": json_values((record[4], record[3], record[2], wire.INPUT_SCHEMA, wire.INPUT_CANON)),
            "executionWitness": json_values(witness), "archiveWitness": json_values(archive),
            "inputsHash": wire.inputs_hash(uint(a["chainId"]), a["core"], a["host"], statement[0], statement[7])}

    def _content(self, finality):
        a, cid, chain = self.a, uint(self.a["collectionId"]), uint(self.a["chainId"])
        statement = decode(wire.INPUT_ENVELOPE, hex_bytes(finality["manifestBytes"]), maximum=wire.MAX_MANIFEST)[6]
        selected_hash = statement[7][0]
        head = self._one(a["router"], "collectionContentRootHead(uint256)", "bytes32", ("uint256",), (cid,))
        history, seen, digest = [], set(), head
        while digest != ZERO:
            require(digest not in seen and len(seen) < MAX_ROOTS, "finality source root history cycle/bound")
            seen.add(digest)
            record = self._one(a["router"], "contentRootRecord(bytes32)", wire.ROOT_RECORD, ("bytes32",), (digest,))
            require(record[0][0] == cid, "finality source foreign root lineage")
            history.append({"recordHash": digest, "record": json_values(record)})
            digest = record[0][1]
        require(selected_hash in seen, "finality source original root absent from collection lineage")
        history.reverse()
        selected = wire.from_json(wire.ROOT_RECORD, next(row["record"] for row in history if row["recordHash"] == selected_hash))
        manifest_hash = selected[0][2]
        manifest = self._one(a["leafManifest"], "manifestRecord(bytes32)", wire.LEAF_MANIFEST, ("bytes32",), (manifest_hash,))
        plan_hash = wire.manifest_plan_hash(chain, a["leafManifest"], a["core"], a["checkpoint"], a["artifactCoverage"], manifest)
        plan = self._one(a["leafManifest"], "manifestPlan(bytes32)", wire.LEAF_PLAN, ("bytes32",), (plan_hash,))
        checkpoint = self._one(a["checkpoint"], "checkpoint(bytes32)", wire.CHECKPOINT, ("bytes32",), (manifest[0],))
        profile = self._one(a["checkpoint"], "checkpointProfile(bytes32)", "bytes32", ("bytes32",), (manifest[0],))
        require(profile == wire.INLINE_PROFILE and 0 < checkpoint[1] <= wire.MAX_LEAVES and checkpoint[2] == checkpoint[1],
            "finality source unsupported checkpoint profile/size/completion")
        leaves = [self._one(a["checkpoint"], "checkpointLeaf(bytes32,uint256)", wire.LEAF,
            ("bytes32", "uint256"), (manifest[0], index)) for index in range(checkpoint[1])]
        artifact = self._one(a["artifactCoverage"], "artifact(bytes32)", wire.ARTIFACT, ("bytes32",), (manifest[1],))
        coverage = self._one(a["artifactCoverage"], "coverage(bytes32)", wire.COVERAGE, ("bytes32",), (manifest[2],))
        require(0 < len(artifact[6]) <= MAX_CHUNKS and len(artifact[6]) == len(artifact[7]), "finality source artifact count bound")
        chunks = []
        for index in range(len(artifact[6])):
            pointer, code_hash = self._read(a["artifactCoverage"], "artifactChunk(bytes32,uint32)",
                ("address", "bytes32"), ("bytes32", "uint32"), (manifest[1], index))
            payload = self._carrier(pointer, code_hash, 8192)
            require(payload == self._chunk(artifact[6][index]), "finality source artifact/Store original chunk differs")
            chunks.append({"pointer": pointer, "codeHash": code_hash, "runtime": _hex(b"\0" + payload)})
        return {"selectedRootHash": selected_hash, "rootHead": head, "rootHistory": history,
            "manifest": {"recordHash": manifest_hash, "planHash": plan_hash, "record": json_values(manifest), "plan": json_values(plan)},
            "checkpoint": {"planHash": manifest[0], "profile": profile, "plan": json_values(checkpoint), "leaves": json_values(leaves)},
            "artifact": {"artifactHash": manifest[1], "artifact": json_values(artifact), "coverage": json_values(coverage), "chunks": chunks}}

    def _execution(self, finality):
        a, action_id = self.a, finality["executionWitness"][0]
        action = self._one(a["executor"], "governanceAction(bytes32)", wire.GOVERNANCE_ACTION, ("bytes32",), (action_id,))
        pointer = self._one(a["executor"], "scheduledCallDataPointer(bytes32)", "address", ("bytes32",), (action_id,))
        calls = self._one(a["executor"], "scheduledCallData(bytes32)", Array("bytes", 64), ("bytes32",), (action_id,), maximum=65536)
        key = keccak256(b"".join(hex_bytes(keccak256(raw)) for raw in calls))
        require(pointer != ZERO_ADDRESS and self._one(a["executor"], "publishedCallData(bytes32)", "address", ("bytes32",), (key,)) == pointer,
            "finality source scheduled/publication pointer differs")
        runtime = hex_bytes(self.reader.code(pointer))
        require(0 < len(runtime) <= 24576, "finality source scheduled runtime bound")
        return {"action": json_values(action), "callDataPointer": pointer, "callDatas": [_hex(raw) for raw in calls], "runtime": _hex(runtime)}

    def _events(self, bundle, source, graph):
        """Fixed original identities drive filters; event coordinates are never caller supplied."""
        expected = wire.expected_events(bundle, source, graph)
        filters = {}
        for row in expected:
            topics = list(row["topics"])
            if row["kind"] == "root_published": topics = topics[:3]
            elif row["kind"] == "leaf_verified": topics = topics[:2]
            elif row["kind"] == "finality_finalized": topics = topics[:2]
            while topics and topics[-1] is None: topics.pop()
            key = dumps({"address": row["address"], "topics": topics})
            filters[key] = (row["address"], topics)
        action_id = bundle["finality"]["executionWitness"][0]
        executor = graph["executor"]["address"]
        for name in ("governanceScheduled", "governanceExecuted"):
            topics = [wire.EVENTS[name], action_id]
            filters[dumps({"address": executor, "topics": topics})] = (executor, topics)
        publication = schema_id("GovernanceCallDataPublished(uint16,bytes32,address,address)")
        call_key = keccak256(b"".join(hex_bytes(keccak256(hex_bytes(raw))) for raw in bundle["execution"]["callDatas"]))
        topics = [publication, call_key]
        filters[dumps({"address": executor, "topics": topics})] = (executor, topics)
        events, stamps = {}, {}
        for target, topics in filters.values():
            history = self._history(target, topics)
            for block, stamp in history["blockTimestamps"].items():
                require(block not in stamps or stamps[block] == stamp, "finality source event header time differs")
                stamps[block] = stamp
            for log in history["logs"]:
                key = (log["blockHash"], log["transactionHash"], log["logIndex"])
                require(key not in events or events[key] == log, "finality source conflicting event")
                events[key] = log
        from .chain_rpc import quantity
        ordered = sorted(events.values(), key=lambda row: tuple(quantity(row[key]) for key in ("blockNumber", "transactionIndex", "logIndex")))
        return [{"log": row, "timestamp": stamps[str(quantity(row["blockNumber"]))]} for row in ordered]

    def _capture(self):
        graph, state = self._bindings(), self._state()
        self._definitions()
        finality = self._finality()
        bundle = {"finality": finality, "content": self._content(finality), "execution": self._execution(finality)}
        source = {key: self.a[key] for key in (*COMMON, "tokenId")}
        derived = wire.validate_bundle(bundle, source, graph)
        events = self._events(bundle, source, graph)
        reconciliation = observations._observations(source, {"finality": self.reader.rows}, self.pins)
        if type(self.reader.transport) is PublicReplayTransport: self.reader.transport.finish()
        result = {"profile": PROFILE, "profileHash": PROFILE_HASH, "version": "1", "sourceReviewCommit": SOURCE_REVISION,
            "provenance": self.provenance, "source": source, "sourceState": state, "identity": self.identity,
            "anchorHash": keccak256(self.anchor_bytes), "transcriptHash": keccak256(self.reader.transcript()),
            "graph": graph, "bundle": bundle, "events": events, "historicalCoreFacts": derived["historicalCoreFacts"],
            "definitions": [{"documentId": row["id"], "payloadHex": _hex(row["bytes"])} for row in wire.definitions()],
            "documentEvidence": list(self.documents.values()), "storeChunks": self.chunks,
            "historyCoverage": [row["coverage"] for row in self._histories], "observationReconciliation": reconciliation,
            "claims": CLAIMS, "qualification": QUALIFICATION}
        raw = dumps(result)
        require(len(raw) <= MAX_OUTPUT, "finality source snapshot bound")
        from ..metadata import acquisition_native_finality_v1 as definition
        definition.semanticProjection(result, {"sourceProfileHash": PROFILE_HASH, "anchorHash": result["anchorHash"],
            "transcriptHash": result["transcriptHash"], "snapshotHash": keccak256(raw), "provenance": self.provenance})
        return raw

    def snapshot(self):
        if self._snapshot is not None: return self._snapshot
        require(not self._started, "failed finality source capture cannot resume")
        self._started = True
        try: self._snapshot = self._capture()
        except MuseumError: raise
        except (KeyError, TypeError, ValueError, IndexError, OverflowError) as exc:
            raise MuseumError("malformed original finality source evidence") from exc
        return self._snapshot

    def transcript(self):
        require(self._snapshot is not None, "finality source snapshot required")
        return self.reader.transcript()

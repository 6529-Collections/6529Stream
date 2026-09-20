"""Pinned original TOKEN/RELEASE/SEASON STATIC finality observations and replay."""
from . import native_scoped_finality_wire as wire
from . import native_finality_wire as neutral
from . import scoped_static_types as t
from . import conservation_capture_join as observations
from . import public_scoped_finality_rpc as rpc
from . import scoped_finality_observations
from .canonical import MuseumError, dumps, hex_bytes, keccak256, loads, uint
from .chain_abi import Array, decode, encode
from .chain_rpc import quantity
from .current_rights_source import DOCUMENT_FACTS
from .independent_wire import RAW_BYTES, ZERO, ZERO_ADDRESS, json_values, require
from .public_finality_source import PublicFinalitySource as _NeutralReads
from .public_chain_history import PROFILE_HASH as HISTORY_PROFILE_HASH
from .scoped_static_source_reads import ScopedStaticSourceReads
from .scoped_static_content_source_reads import ContentReadsMixin

PROFILE = "STREAM_MUSEUM_PUBLIC_SCOPED_STATIC_FINALITY_SOURCE_V1"
SOURCE_REVISION = wire.SOURCE_REVISION
COMMON = observations.COMMON
ADDRESSES = wire.GRAPH_KEYS
INVENTORY_DEPENDENCIES = (("address",)*12, ("bytes32",)*12, ("address",)*5, ("bytes32",)*5,
    "address", "bytes32", "uint256", "uint256", "uint256", "uint256", "uint256", "uint256")
MAX_ANCHOR, MAX_OUTPUT = 65536, 32 * 1024 * 1024
CLAIMS = {"originalNativeFinalityRetained": True, "originalManifestPreimageChecked": True,
    "completeMembershipAndOutputRowsChecked": True, "nativeTokenProofChecked": True,
    "historicalCoreFactsPreimageRecovered": False, "originalRenderedBytesReexecuted": False,
    "originalProposerRoleReexecuted": False, "originalArtistConsentReexecuted": False,
    "currentArchiveLivenessRequired": False, "allFinalityScopesCaptured": False,
    "providerLogCompletenessTrusted": True, "sourceConsensusVerified": False,
    "actualChainAcceptance": False, "completeAcquisitionPacket": False}
QUALIFICATION = ("Original artist-bound TOKEN/RELEASE/SEASON STATIC evidence in ONCHAIN metadata mode. "
    "The exact scoped input manifest, snapshot source, complete membership and ordered original output hash rows "
    "join original root publications and the token proof. Current token lifecycle is a separate observation. "
    "Original schedule/execution transaction inputs reconstruct supported direct Executor metadata when available; "
    "missing or unsupported inputs remain partial. Historical Core facts and renderer source facts remain hash-only. "
    "Complete rendered bytes, signatures, original roles, historical execution, runtime admission and consensus "
    "are not reconstructed. Policy V2, VIEW, COLLECTION and factory profiles need distinct evidence profiles.")
ADDRESS_BINDINGS = tuple((s, getter, dest) for s, getter, dest, kind in neutral.BINDINGS
    if s in ("finality", "executor", "roles", "metadata", "schemas", "artifacts") and kind == "address") + (
    ("finality", "coreFinalityAdapter()", "coreAdapter"),
    ("coreAdapter", "core()", "core"), ("coreAdapter", "collectionMetadata()", "metadata"),
    ("coreAdapter", "evidenceProvider()", "provider"), ("discovery", "scopeEvidenceProvider()", "provider"),
    ("router", "core()", "core"), ("metadata", "chunkStore()", "store"),
    ("scopeMembership", "core()", "core"), ("scopeMembership", "metadataHost()", "metadata"),
    ("scopeMembership", "tokenInventory()", "tokenInventory"), ("scopeMembership", "schemaRegistry()", "schemas"),
    ("scopeMembership", "chunkStore()", "store"), ("tokenInventory", "core()", "core"),
    ("staticSelection", "core()", "core"), ("staticSelection", "metadataRouter()", "router"),
    ("staticSelection", "scopeMembership()", "scopeMembership"), ("staticSelection", "metadataHost()", "metadata"),
    ("staticContent", "core()", "core"), ("staticContent", "metadataRouter()", "router"),
    ("staticContent", "selectionCheckpoint()", "staticSelection"),
    ("outputManifest", "core()", "core"), ("outputManifest", "contentCheckpoint()", "staticContent"),
    ("outputManifest", "artifactCoverage()", "artifacts"),
    ("outputManifest", "schemaRegistry()", "schemas"),
    ("coordinatorInventory", "core()", "core"), ("coordinatorInventory", "scopeMembershipHost()", "scopeMembership"),
    ("entropyFactory", "coordinatorInventory()", "coordinatorInventory"),
    ("renderCriticalInventory", "core()", "core"), ("renderCriticalInventory", "metadataHost()", "metadata"),
    ("renderCriticalInventory", "metadataRouter()", "router"), ("renderCriticalInventory", "snapshots()", "scopedSnapshot"),
    ("renderCriticalInventory", "referencePublisher()", "scopedReference"),
    ("renderCriticalInventory", "artifactCoverage()", "artifacts"),
    ("renderCriticalInventory", "externalCoverage()", "externalCoverage"),
    ("bundleCoverage", "core()", "core"), ("bundleCoverage", "metadataHost()", "metadata"),
    ("bundleCoverage", "renderCriticalInventory()", "renderCriticalInventory"),
    ("bundleCoverage", "artifactCoverage()", "artifacts"), ("bundleCoverage", "externalCoverage()", "externalCoverage"))
HASH_BINDINGS = (
    ("metadata", "coreCodeHash()", "core"), ("metadata", "schemaRegistryCodeHash()", "schemas"),
    ("metadata", "chunkStoreCodeHash()", "store"), ("tokenInventory", "coreCodeHash()", "core"),
    ("staticSelection", "coreCodeHash()", "core"), ("staticSelection", "routerCodeHash()", "router"),
    ("staticSelection", "membershipCodeHash()", "scopeMembership"), ("staticSelection", "metadataCodeHash()", "metadata"),
    ("staticContent", "coreCodeHash()", "core"), ("staticContent", "routerCodeHash()", "router"),
    ("staticContent", "selectionCodeHash()", "staticSelection"),
    ("outputManifest", "checkpointCodeHash()", "staticContent"), ("outputManifest", "coverageCodeHash()", "artifacts"),
    ("outputManifest", "schemaCodeHash()", "schemas"),
    ("coordinatorInventory", "coreCodeHash()", "core"), ("coordinatorInventory", "scopeMembershipCodeHash()", "scopeMembership"))
CHAIN_BINDINGS = ("scopeMembership", "tokenInventory", "staticSelection", "staticContent", "outputManifest", "coordinatorInventory")
PROFILE_BYTES = dumps({"name": PROFILE, "version": "1", "status": "prospective_unregistered_source_profile",
    "sourceReviewCommit": SOURCE_REVISION, "rpcProfileHash": rpc.PROFILE_HASH,
    "historyProfileHash": HISTORY_PROFILE_HASH, "supportedProfile": "original_scoped_STATIC_ONCHAIN_V1",
    "graphRoles": list(ADDRESSES), "scopeTypes": ["1", "2", "3"],
    "bounds": {"anchorBytes": str(MAX_ANCHOR), "snapshotBytes": str(MAX_OUTPUT),
        "outputs": str(t.MAX_OUTPUTS), "history": str(t.MAX_HISTORY)},
    "definitions": [{k: row[k] for k in ("name", "id", "kind", "hash")} for row in wire.definitions()],
    "rules": ["Read original Registry receipt/components/staging bytes; Store bytes must match exactly.",
        "All collection scoped root events are retained to reconstruct aggregate transitions, including foreign scopes.",
        "Read historical snapshot payloads, complete immutable original membership and ordered STATIC selection/output checkpoints.",
        "Do not replace original evidence with requireCurrent or current source producer output.",
        "The selected root must be the last same-scope root strictly before finality; later publications are separate observations.",
        "Original successful receipts and canonical provider headers join exact event chronology and both original transaction observations."],
    "claims": CLAIMS, "qualification": QUALIFICATION})
PROFILE_HASH = keccak256(PROFILE_BYTES)


class PublicScopedFinalitySource(ScopedStaticSourceReads, ContentReadsMixin):
    _read, _one, _history = _NeutralReads._read, _NeutralReads._one, _NeutralReads._history
    _carrier, _chunk, _state = _NeutralReads._carrier, _NeutralReads._chunk, _NeutralReads._state
    _execution = _NeutralReads._execution

    def __init__(self, anchor_bytes, transport, *, provenance="synthetic_fixture"):
        require(provenance in ("synthetic_fixture", "trusted_rpc") and (provenance != "trusted_rpc"
            or type(transport) in (rpc.PublicScopedRpcTransport, rpc.PublicScopedReplayTransport)), "scoped source provenance")
        a = loads(anchor_bytes, maximum=MAX_ANCHOR, canonical=True)
        require(type(a) is dict and set(a) == set(COMMON) | set(ADDRESSES) |
            {"profile", "tokenId", "scope", "codePins", "runtimeAdmission"} and a["profile"] == PROFILE,
            "scoped source anchor shape/profile")
        require(all(uint(a[k]) > 0 for k in ("chainId", "collectionId", "tokenId"))
            and a["environment"] in ("local_evm_fixture", "public_chain"), "scoped source identity")
        uint(a["blockNumber"], 64); uint(a["timestamp"], 64)
        for key in ("blockHash", "stateRoot", "deploymentEvidenceHash"):
            require(any(hex_bytes(a[key], 32)), "scoped source anchor commitment")
        admission = a["runtimeAdmission"]
        require(type(admission) is dict and set(admission) == {"sourceCommit", "kind", "artifactHash"}
            and admission["sourceCommit"] == SOURCE_REVISION and any(hex_bytes(admission["artifactHash"], 32))
            and admission["kind"] == ("synthetic_fixture" if provenance == "synthetic_fixture" else "externally_admitted_runtime"),
            "scoped source runtime admission")
        require(type(a["codePins"]) is list and 0 < len(a["codePins"]) <= 256, "scoped source pin bound")
        pins = {}
        for row in a["codePins"]:
            require(type(row) is dict and set(row) == {"address", "runtimeHash"}
                and any(hex_bytes(row["address"], 20)) and any(hex_bytes(row["runtimeHash"], 32))
                and row["address"] not in pins, "scoped source code pin")
            pins[row["address"]] = row["runtimeHash"]
        require(all(a[key] in pins for key in ADDRESSES), "scoped source graph pins")
        self.a, self.anchor_bytes, self.pins, self.provenance = a, anchor_bytes, pins, provenance
        self.scope = wire.scope_value(a["scope"])
        require(self.scope[1] == uint(a["collectionId"]) and (self.scope[0] != 1 or self.scope[2] == uint(a["tokenId"])),
            "scoped source target/scope")
        self.graph = {key: {"address": a[key], "runtimeHash": pins[a[key]]} for key in ADDRESSES}
        self.reader = rpc.PublicScopedRecordingReader(transport, a["blockHash"])
        self._reads, self._histories, self.documents, self.chunks = {}, [], {}, {}
        self._started, self._snapshot = False, None

    def _bindings(self):
        a = self.a
        for target, digest in self.pins.items():
            code = hex_bytes(self.reader.code(target))
            require(0 < len(code) <= 24576 and keccak256(code) == digest, "scoped source runtime differs")
        for source, getter, target in ADDRESS_BINDINGS:
            require(self._one(a[source], getter, "address") == a[target], "scoped source reciprocal binding differs")
        for source, getter, target in HASH_BINDINGS:
            require(self._one(a[source], getter, "bytes32") == self.pins[a[target]], "scoped source saved runtime differs")
        for source in CHAIN_BINDINGS:
            require(self._one(a[source], "deploymentChainId()", "uint256") == uint(a["chainId"]), "scoped source deployment chain differs")
        require(self._one(a["finality"], "scopeEvidenceProviderCodeHash()", "bytes32") == self.pins[a["provider"]],
            "scoped source original provider runtime differs")
        c = self._one(a["provider"], "scopedConfiguration()", wire.PROVIDER_CONFIG)
        require(c[0] == tuple(a[k] for k in wire.PROVIDER_TARGETS)
            and c[1] == tuple(self.pins[a[k]] for k in wire.PROVIDER_TARGETS) and c[2] == uint(a["chainId"])
            and c[3] >= 50000 and c[3] <= c[5] <= 2**32-1 and c[4] > c[5] + c[5]//63 + 100000 and c[6] != ZERO,
            "scoped source immutable provider configuration")
        require(self._one(a["renderCriticalInventory"], "dependencyHash()", "bytes32") == c[6], "scoped source inventory dependency")
        d = self._one(a["renderCriticalInventory"], "dependencies()", INVENTORY_DEPENDENCIES)
        indices = (0, 1, 4, 5, 2, 8, 9, 15, 16, 17, 20, 21)
        require(keccak256(encode((INVENTORY_DEPENDENCIES,), (d,))) == c[6]
            and d[0] == tuple(c[0][i] for i in indices) and d[1] == tuple(c[1][i] for i in indices)
            and d[2][0] == a["artist"] and d[3][0] == self.pins[a["artist"]] and d[6] == c[2],
            "scoped source original inventory dependency structure")
        original = (a["finality"], self.pins[a["finality"]])
        require(self._read(a["router"], "servingOriginalFinalityAnchor()", ("address", "bytes32")) == original
            and self._read(a["router"], "originalFinalityAnchor(uint256)", ("address", "bytes32"),
                ("uint256",), (uint(a["collectionId"]),)) in ((ZERO_ADDRESS, ZERO), original),
            "scoped source original Router anchor differs")
        self.provider_configuration = json_values(c)
        self.inventory_dependencies = json_values(d)

    def _definitions(self):
        for definition in wire.definitions():
            key, expected = definition["id"], definition["bytes"]
            facts = self._one(self.a["schemas"], "documentFacts(bytes32)", DOCUMENT_FACTS, ("bytes32",), (key,))
            require(facts[0] and facts[1] == definition["kind"] and facts[2] in (0, 1, 2)
                and facts[3:7] == (definition["hash"], RAW_BYTES, ZERO, len(expected))
                and facts[7] == 1 and facts[8] != ZERO, "scoped source native definition facts")
            digest = self._one(self.a["schemas"], "documentChunkHashAt(bytes32,uint256)", "bytes32", ("bytes32", "uint256"), (key, 0))
            require(self._chunk(digest) == expected, "scoped source native definition bytes")
            self.documents[key] = {"documentId": key, "facts": json_values(facts), "chunkHashes": [digest], "payloadHex": "0x" + expected.hex()}

    def _finality(self):
        host, scope = self.a["finality"], self.scope
        suffix = "((uint8,uint256,uint256,bytes32))"
        record = self._one(host, "artworkScopeFinalityRecord" + suffix, wire.SCOPED_RECORD, (wire.SCOPE,), (scope,))
        require(record[0] and record[2] != ZERO, "scoped source scope not finalized")
        count = self._one(host, "finalityComponentCountForScope" + suffix, "uint256", (wire.SCOPE,), (scope,))
        require(count == 10, "scoped source component count")
        components = self._one(host, "finalityComponentsForScope((uint8,uint256,uint256,bytes32),uint256,uint256)",
            Array(wire.COMPONENT, 32), (wire.SCOPE, "uint256", "uint256"), (scope, 0, count))
        require(len(components) == count and self._one(host, "finalityManifestStored(bytes32)", "bool", ("bytes32",), (record[3],)),
            "scoped source staged manifest/components")
        raw = self._one(host, "finalityManifestBytes(bytes32)", "bytes", ("bytes32",), (record[3],), maximum=wire.MAX_MANIFEST + 64)
        require(0 < len(raw) <= wire.MAX_MANIFEST and self._chunk(record[3]) == raw, "scoped source Registry/Store manifest differs")
        statement = decode(wire.INPUT_ENVELOPE, raw, maximum=wire.MAX_MANIFEST)[6]
        witness = self._one(host, "finalityExecutionWitness(bytes32)", wire.EXECUTION_WITNESS, ("bytes32",), (record[2],))
        archive = self._one(host, "finalitySanctionArchiveWitness(bytes32)", wire.ARCHIVE_WITNESS, ("bytes32",), (record[2],))
        return {"record": json_values(record), "components": json_values(components), "manifestBytes": "0x" + raw.hex(),
            "manifestRef": json_values((record[6], record[4], record[3], wire.INPUT_SCHEMA, wire.INPUT_CANON)),
            "executionWitness": json_values(witness), "archiveWitness": json_values(archive),
            "inputsHash": neutral.inputs_hash(uint(self.a["chainId"]), self.a["core"], self.a["metadata"], scope, statement[7])}

    def _events(self, bundle, source):
        from . import scoped_static_content_wire as content
        filters = {}
        for descriptor in wire.expected_events(bundle, source, self.graph):
            topics = list(descriptor["topics"])
            if descriptor["kind"] == "root_published": topics = topics[:2]
            elif descriptor["kind"] in ("content_appended", "selection_appended"): topics = topics[:2]
            while topics and topics[-1] is None: topics.pop()
            filters[dumps([descriptor["address"], topics])] = descriptor["address"], topics
        action_id = bundle["finality"]["executionWitness"][0]
        for name in ("governanceScheduled", "governanceExecuted"):
            topics = [wire.EVENTS[name], action_id]
            filters[dumps([self.a["executor"], topics])] = self.a["executor"], topics
        execution = wire.validate_execution(bundle["execution"], source, self.graph,
            wire.validate_finality(bundle["finality"], source, self.graph, bundle["scope"]))
        topics = [wire.EVENTS["governanceCalldataPublished"], execution["callDataKey"]]
        filters[dumps([self.a["executor"], topics])] = self.a["executor"], topics
        topics = [content.EVENTS["manifestAdvanced"], bundle["content"]["manifest"]["planHash"]]
        filters[dumps([self.a["outputManifest"], topics])] = self.a["outputManifest"], topics
        selected_histories = [self._history(target, topics) for target, topics in filters.values()]
        events, stamps = {}, {}
        for history in selected_histories:
            for block, stamp in history["blockTimestamps"].items():
                require(block not in stamps or stamps[block] == stamp, "scoped source header time differs")
                stamps[block] = stamp
            for log in history["logs"]:
                key = log["blockHash"], log["transactionHash"], log["logIndex"]
                require(key not in events or events[key] == log, "scoped source conflicting event")
                events[key] = log
        ordered = sorted(events.values(), key=lambda log: tuple(quantity(log[k]) for k in ("blockNumber", "transactionIndex", "logIndex")))
        return [{"log": log, "timestamp": stamps[str(quantity(log["blockNumber"]))]} for log in ordered]

    def _transactions(self, events, source):
        from .public_governance_transaction_source import transaction_observation
        transactions, headers = {}, {}
        for role, name in (("schedule", "governanceScheduled"), ("execution", "governanceExecuted")):
            matched = [r["log"] for r in events if r["log"]["address"] == self.a["executor"] and r["log"]["topics"][0] == wire.EVENTS[name]]
            require(len(matched) == 1, "scoped source original transaction event")
            log = matched[0]
            def original(method, params):
                values = [r["result"] for r in self.reader.rows if r["method"] == method and r["params"] == params]
                require(values and all(r == values[0] for r in values), "scoped source original receipt/header")
                return values[0]
            receipt = original("eth_getTransactionReceipt", [log["transactionHash"]])
            headers[log["blockHash"]] = original("eth_getBlockByHash", [log["blockHash"], False])
            value = self.reader.request("eth_getTransactionByHash", [log["transactionHash"]])
            transactions[role] = transaction_observation(value, receipt, log, source)
        return transactions, ["0x" + dumps(row).hex() for row in sorted(headers.values(), key=lambda row: quantity(row["number"]))]

    def _capture(self):
        self._bindings(); state = self._state(); self._definitions()
        source = {key: self.a[key] for key in (*COMMON, "tokenId")}
        finality = self._finality(); statement = wire.validate_finality(finality, source, self.graph, self.scope)["statement"]
        content = self._content(statement)
        from . import scoped_static_content_wire as content_wire
        content_result = content_wire.validate(content, source, self.graph, statement)
        bundle = {"scope": json_values(self.scope), "finality": finality, "content": content,
            **self._snapshot_membership(statement, content_result), "execution": self._execution(finality)}
        derived = wire.validate_bundle(bundle, source, self.graph)
        events = self._events(bundle, source); wire.validate_event_join(bundle, source, self.graph, events)
        transactions, headers = self._transactions(events, source)
        reconstruction = wire.validate_governance(bundle, source, self.graph, {k: v["normalized"] for k, v in transactions.items()}, events)
        reconciliation = scoped_finality_observations.reconcile(source, {"scopedFinality": self.reader.rows}, self.pins)
        if type(self.reader.transport) is rpc.PublicScopedReplayTransport: self.reader.transport.finish()
        result = {"profile": PROFILE, "profileHash": PROFILE_HASH, "version": "1", "sourceReviewCommit": SOURCE_REVISION,
            "provenance": self.provenance, "source": source, "sourceState": state, "identity": self.identity,
            "anchorHash": keccak256(self.anchor_bytes), "transcriptHash": keccak256(self.reader.transcript()),
            "graph": self.graph, "providerConfiguration": self.provider_configuration,
            "inventoryDependencies": self.inventory_dependencies, "bundle": bundle, "events": events,
            "historicalCoreFacts": derived["historicalCoreFacts"], "headers": headers, "transactions": transactions, "reconstruction": reconstruction,
            "definitions": [{"documentId": row["id"], "payloadHex": "0x" + row["bytes"].hex()} for row in wire.definitions()],
            "documentEvidence": list(self.documents.values()), "storeChunks": self.chunks,
            "historyCoverage": [r["coverage"] for r in self._histories], "observationReconciliation": reconciliation,
            "claims": CLAIMS, "qualification": QUALIFICATION}
        raw = dumps(result); require(len(raw) <= MAX_OUTPUT, "scoped source snapshot bound")
        from ..metadata import acquisition_scoped_static_finality_v1 as definition
        definition.semanticProjection(result, {"sourceProfileHash": PROFILE_HASH, "anchorHash": result["anchorHash"],
            "transcriptHash": result["transcriptHash"], "snapshotHash": keccak256(raw), "provenance": self.provenance})
        return raw

    snapshot, transcript = _NeutralReads.snapshot, _NeutralReads.transcript

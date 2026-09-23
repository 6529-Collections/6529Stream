"""Pinned COLLECTION policy V2 history; current admission is never substituted."""
from . import native_policy_finality_wire_v2 as wire
from . import native_finality_wire as neutral
from . import public_scoped_finality_rpc as rpc
from . import scoped_finality_observations
from . import policy_content_wire_v2 as content_wire
from . import policy_preservation_wire_v2 as preservation_wire
from .canonical import dumps, hex_bytes, keccak256, loads, uint
from .chain_abi import Array, decode
from .chain_rpc import quantity
from .current_rights_source import DOCUMENT_FACTS
from .independent_wire import RAW_BYTES, ZERO, ZERO_ADDRESS, json_values, require
from .public_finality_source import PublicFinalitySource as NeutralReads
from .public_scoped_finality_source import PublicScopedFinalitySource as TransactionReads
from .public_chain_history import PROFILE_HASH as HISTORY_PROFILE_HASH
from .conservation_capture_join import COMMON
from .policy_membership_v2 import PolicyMembershipReads
from .policy_content_source_reads_v2 import PolicyContentReads
from .policy_preservation_source_reads_v2 import PolicyPreservationSourceReads
from .policy_static_components_v2 import PolicyStaticReads

PROFILE = "STREAM_MUSEUM_PUBLIC_COLLECTION_POLICY_FINALITY_SOURCE_V2"
SOURCE_REVISION = wire.SOURCE_REVISION
MAX_ANCHOR, MAX_OUTPUT = 65536, 64 * 1024 * 1024
ADDRESSES = wire.GRAPH_KEYS
CLAIMS = {"originalPolicyFinalityRetained": True, "originalManifestPreimageChecked": True,
    "completeOriginalMembershipAndOutputRowsChecked": True, "sixStaticComponentPreimagesChecked": True,
    "historicalCoreFactsPreimageRecovered": False, "historicalMetadataComponentPreimageRecovered": False,
    "historicalTerminalAdmissionPreimageRecovered": False, "originalRenderedBytesReexecuted": False,
    "originalAuthorityReexecuted": False, "currentArchiveLivenessRequired": False,
    "providerLogCompletenessTrusted": True, "sourceConsensusVerified": False, "actualChainAcceptance": False,
    "completeAcquisitionPacket": False}
QUALIFICATION = ("Original COLLECTION policy V2 evidence with the original 22-role configuration and separate V2 output binding. "
    "The original inventory prefix, ordered output/readiness rows, full policy rows, canonical snapshot/reference payloads, "
    "STATIC source preimages and six component hashes join original root and finality history. Current burns are separate "
    "observations. Core facts, metadata-component facts and terminal-admission preimages remain hash-only. Retained HTML "
    "samples do not reconstruct all served JSON or browser execution. RPC observations do not authenticate consensus, "
    "runtime provenance, signatures, original authority or full EVM execution. Scoped factory and VIEW profiles are separate.")
PROFILE_BYTES = dumps({"name": PROFILE, "version": "2", "status": "prospective_unregistered_source_profile",
    "sourceReviewCommit": SOURCE_REVISION, "rpcProfileHash": rpc.PROFILE_HASH, "historyProfileHash": HISTORY_PROFILE_HASH,
    "supportedProfile": "original_COLLECTION_POLICY_V2", "graphRoles": list(ADDRESSES), "scopeTypes": ["0"],
    "bounds": {"anchorBytes": str(MAX_ANCHOR), "snapshotBytes": str(MAX_OUTPUT), "outputs": "818",
        "rootHistory": "256", "uniqueStaticSourceBytes": str(8 * 1024 * 1024)},
    "rules": ["V1 provider roles six and seven retain their original meaning; V2 output sources come from separate fixed bindings.",
        "The selected original root, snapshot, reference, source-set policies and finality statement are joined by exact native profiles.",
        "Current heads and token lifecycle are separately observed; no current eligibility getter replaces historical evidence.",
        "The exact complete original statement is retained in both Registry staging and the original Store.",
        "Canonical provider logs, successful receipts and original transaction inputs are retained with explicit external trust limits."],
    "claims": CLAIMS, "qualification": QUALIFICATION})
PROFILE_HASH = keccak256(PROFILE_BYTES)

ADDRESS_BINDINGS = tuple((s if s != "inventory" else "tokenInventory", getter, d if d != "inventory" else "tokenInventory")
    for s, getter, d, kind in neutral.BINDINGS if kind == "address") + (
    ("finality", "coreFinalityAdapter()", "coreAdapter"), ("coreAdapter", "core()", "core"),
    ("coreAdapter", "collectionMetadata()", "metadata"), ("coreAdapter", "evidenceProvider()", "provider"),
    ("discovery", "scopeEvidenceProvider()", "provider"), ("router", "core()", "core"),
    ("scopeMembership", "core()", "core"), ("scopeMembership", "metadataHost()", "metadata"),
    ("scopeMembership", "tokenInventory()", "tokenInventory"), ("metadata", "chunkStore()", "store"),
    ("staticSelection", "core()", "core"), ("staticSelection", "metadataRouter()", "router"),
    ("staticSelection", "scopeMembership()", "scopeMembership"), ("staticSelection", "metadataHost()", "metadata"),
    ("policyContent", "core()", "core"), ("policyContent", "metadataRouter()", "router"),
    ("policyContent", "selectionCheckpoint()", "staticSelection"), ("policyContent", "entropySourceSet()", "entropySourceSet"),
    ("policyContent", "terminalReadiness()", "terminalReadiness"),
    ("outputManifest", "core()", "core"), ("outputManifest", "contentCheckpoint()", "policyContent"),
    ("outputManifest", "artifactCoverage()", "artifacts"), ("outputManifest", "schemaRegistry()", "schemas"),
    ("provider", "policyOutputManifestV2()", "outputManifest"),
    ("provider", "policySnapshotPublicationV2()", "policySnapshot"), ("provider", "policyReferencePublicationV2()", "policyReference"),
    ("coordinatorInventory", "core()", "core"), ("coordinatorInventory", "scopeMembershipHost()", "scopeMembership"),
    ("entropyFactory", "coordinatorInventory()", "coordinatorInventory"),
    ("renderCriticalInventory", "core()", "core"), ("renderCriticalInventory", "metadataHost()", "metadata"),
    ("renderCriticalInventory", "metadataRouter()", "router"), ("renderCriticalInventory", "snapshots()", "policySnapshot"),
    ("renderCriticalInventory", "referencePublisher()", "policyReference"),
    ("renderCriticalInventory", "artifactCoverage()", "artifacts"), ("renderCriticalInventory", "externalCoverage()", "externalCoverage"),
    ("bundleCoverage", "core()", "core"), ("bundleCoverage", "metadataHost()", "metadata"),
    ("bundleCoverage", "renderCriticalInventory()", "renderCriticalInventory"),
    ("bundleCoverage", "artifactCoverage()", "artifacts"), ("bundleCoverage", "externalCoverage()", "externalCoverage"))
HASH_BINDINGS = tuple((s if s != "inventory" else "tokenInventory", getter, d if d != "inventory" else "tokenInventory")
    for s, getter, d, kind in neutral.BINDINGS if kind == "runtimeHash") + (
    ("policyContent", "coreCodeHash()", "core"), ("policyContent", "routerCodeHash()", "router"),
    ("policyContent", "selectionCodeHash()", "staticSelection"),
    ("policyContent", "entropySourceSetCodeHash()", "entropySourceSet"), ("policyContent", "terminalReadinessCodeHash()", "terminalReadiness"),
    ("provider", "policyOutputManifestV2CodeHash()", "outputManifest"),
    ("provider", "policySnapshotPublicationV2CodeHash()", "policySnapshot"),
    ("provider", "policyReferencePublicationV2CodeHash()", "policyReference"),
    ("outputManifest", "checkpointCodeHash()", "policyContent"), ("outputManifest", "coverageCodeHash()", "artifacts"),
    ("outputManifest", "schemaCodeHash()", "schemas"), ("staticSelection", "coreCodeHash()", "core"),
    ("staticSelection", "routerCodeHash()", "router"), ("staticSelection", "membershipCodeHash()", "scopeMembership"),
    ("staticSelection", "metadataCodeHash()", "metadata"))


class PublicPolicyFinalitySource(PolicyContentReads, PolicyPreservationSourceReads, PolicyStaticReads, PolicyMembershipReads):
    _read, _one, _history = NeutralReads._read, NeutralReads._one, NeutralReads._history
    _carrier, _chunk, _state, _execution = NeutralReads._carrier, NeutralReads._chunk, NeutralReads._state, NeutralReads._execution
    _transactions = TransactionReads._transactions
    snapshot, transcript = NeutralReads.snapshot, NeutralReads.transcript

    def __init__(self, anchor_bytes, transport, *, provenance="synthetic_fixture"):
        require(provenance in ("synthetic_fixture", "trusted_rpc") and (provenance != "trusted_rpc"
            or type(transport) in (rpc.PublicScopedRpcTransport, rpc.PublicScopedReplayTransport)), "policy source provenance")
        a = loads(anchor_bytes, maximum=MAX_ANCHOR, canonical=True)
        require(type(a) is dict and set(a) == set(COMMON) | set(ADDRESSES) |
            {"profile", "tokenId", "codePins", "runtimeAdmission"} and a["profile"] == PROFILE, "policy source anchor shape/profile")
        require(all(uint(a[k]) > 0 for k in ("chainId", "collectionId", "tokenId"))
            and a["environment"] in ("local_evm_fixture", "public_chain"), "policy source identity")
        uint(a["blockNumber"], 64); uint(a["timestamp"], 64)
        for k in ("blockHash", "stateRoot", "deploymentEvidenceHash"): require(any(hex_bytes(a[k], 32)), "policy source anchor commitment")
        admission = a["runtimeAdmission"]
        require(type(admission) is dict and set(admission) == {"sourceCommit", "kind", "artifactHash"}
            and admission["sourceCommit"] == SOURCE_REVISION and any(hex_bytes(admission["artifactHash"], 32))
            and admission["kind"] == ("synthetic_fixture" if provenance == "synthetic_fixture" else "externally_admitted_runtime"),
            "policy source runtime admission")
        require(type(a["codePins"]) is list and 0 < len(a["codePins"]) <= 256, "policy source pin bound")
        pins = {}
        for row in a["codePins"]:
            require(type(row) is dict and set(row) == {"address", "runtimeHash"} and any(hex_bytes(row["address"], 20))
                and any(hex_bytes(row["runtimeHash"], 32)) and row["address"] not in pins, "policy source code pin")
            pins[row["address"]] = row["runtimeHash"]
        require(all(a[k] in pins for k in ADDRESSES), "policy source graph pins")
        self.a, self.anchor_bytes, self.pins, self.provenance = a, anchor_bytes, pins, provenance
        self.graph = {k: {"address": a[k], "runtimeHash": pins[a[k]]} for k in ADDRESSES}
        self.reader = rpc.PublicScopedRecordingReader(transport, a["blockHash"])
        self._reads, self._histories, self.documents, self.chunks = {}, [], {}, {}
        self._started, self._snapshot = False, None

    def _bindings(self):
        a = self.a
        for address, digest in self.pins.items():
            code = hex_bytes(self.reader.code(address))
            require(0 < len(code) <= 24576 and keccak256(code) == digest, "policy pinned runtime differs")
        for source, getter, target in ADDRESS_BINDINGS:
            require(self._one(a[source], getter, "address") == a[target], "policy immutable address binding")
        for source, getter, target in HASH_BINDINGS:
            require(self._one(a[source], getter, "bytes32") == self.pins[a[target]], "policy immutable runtime binding")
        for key in ("scopeMembership", "tokenInventory", "staticSelection", "policyContent", "outputManifest", "coordinatorInventory"):
            require(self._one(a[key], "deploymentChainId()", "uint256") == uint(a["chainId"]), "policy immutable deployment chain")
        config = {key: json_values(self._one(a["provider"], getter, wire.PROVIDER_CONFIG)) for key, getter in
            (("originalConfiguration", "configuration()"), ("scopedConfiguration", "scopedConfiguration()"), ("policyConfiguration", "policyConfiguration()"))}
        config["inventoryDependencies"] = json_values(self._one(a["renderCriticalInventory"], "dependencies()", wire.INVENTORY_DEPENDENCIES))
        config["profiles"] = [json_values(self._one(a["provider"], "finalitySourceProfile(uint8)", wire.PROFILE, ("uint8",), (i,))) for i in range(3)]
        config["configurationHash"] = self._one(a["provider"], "finalitySourceConfigurationHash()", "bytes32")
        wire.validate_provider(config, a, self.graph)
        require(self._one(a["renderCriticalInventory"], "dependencyHash()", "bytes32") == config["policyConfiguration"][6], "policy inventory dependency hash")
        d = self._one(a["discovery"], "configuration()", wire.DISCOVERY_CONFIG)
        adapters = []
        for i, family in enumerate(wire.ADAPTER_FAMILIES):
            address = d[11][i] if i < 6 else d[6]
            require(address in self.pins, "policy original adapter lacks external runtime pin")
            row = {"family": self._one(address, "componentType()", "bytes32"), "address": address, "runtimeHash": self.pins[address]}
            for key in ("core", "host", "evidenceProvider", "metadataHost"):
                row[key] = self._one(address, key+"()", "address")
                row[key+"CodeHash"] = self._one(address, key+"CodeHash()", "bytes32")
            adapters.append(row)
        self.provider_evidence = {"configuration": config, "discoveryConfiguration": json_values(d),
            "discoverySourceConfigurationHash": self._one(a["discovery"], "sourceConfigurationHash()", "bytes32"), "adapters": adapters,
            "moduleIdentities": {k: [self._one(a["provider"], k+"ModuleVersion()", "bytes32"),
                self._one(a["provider"], k+"ModuleManifestHash()", "bytes32")] for k in ("router", "metadata")}}
        original = (a["finality"], self.pins[a["finality"]])
        require(self._read(a["router"], "servingOriginalFinalityAnchor()", ("address", "bytes32")) == original
            and self._read(a["router"], "originalFinalityAnchor(uint256)", ("address", "bytes32"),
                ("uint256",), (uint(a["collectionId"]),)) in ((ZERO_ADDRESS, ZERO), original), "policy original Router anchor")

    def _definitions(self):
        for definition in wire.definitions():
            key, expected = definition["id"], definition["bytes"]
            f = self._one(self.a["schemas"], "documentFacts(bytes32)", DOCUMENT_FACTS, ("bytes32",), (key,))
            require(f[0] and f[1] == definition["kind"] and f[2] in (0, 1, 2)
                and f[3:7] == (definition["hash"], RAW_BYTES, ZERO, len(expected)) and 0 < f[7] <= 64 and f[8] != ZERO,
                "policy retained native definition facts")
            hashes, parts = [], []
            for i in range(f[7]):
                digest = self._one(self.a["schemas"], "documentChunkHashAt(bytes32,uint256)", "bytes32", ("bytes32", "uint256"), (key, i))
                hashes.append(digest); parts.append(self._chunk(digest))
            require(b"".join(parts) == expected, "policy complete native definition bytes")
            self.documents[key] = {"documentId": key, "facts": json_values(f), "chunkHashes": hashes, "payloadHex": "0x"+expected.hex()}

    def _finality(self):
        host, cid = self.a["finality"], uint(self.a["collectionId"])
        r = self._one(host, "collectionFinalityRecord(uint256)", neutral.FINALITY_RECORD, ("uint256",), (cid,))
        require(r[0] and r[1] != ZERO, "policy collection not finalized")
        count = self._one(host, "finalityComponentCount(uint256)", "uint256", ("uint256",), (cid,))
        require(count == 10, "policy finality component count")
        components = self._one(host, "finalityComponents(uint256,uint256,uint256)", Array(wire.COMPONENT, 32),
            ("uint256", "uint256", "uint256"), (cid, 0, count))
        require(len(components) == count and self._one(host, "finalityManifestStored(bytes32)", "bool", ("bytes32",), (r[2],)),
            "policy retained Registry components/staging")
        raw = self._one(host, "finalityManifestBytes(bytes32)", "bytes", ("bytes32",), (r[2],), maximum=wire.MAX_MANIFEST+64)
        require(0 < len(raw) <= wire.MAX_MANIFEST and self._chunk(r[2]) == raw, "policy exact Registry/Store bytes")
        s = decode(wire.INPUT_ENVELOPE, raw, maximum=wire.MAX_MANIFEST)[6]
        witness = self._one(host, "finalityExecutionWitness(bytes32)", neutral.EXECUTION_WITNESS, ("bytes32",), (r[1],))
        archive = self._one(host, "finalitySanctionArchiveWitness(bytes32)", neutral.ARCHIVE_WITNESS, ("bytes32",), (r[1],))
        return {"record": json_values(r), "components": json_values(components), "manifestBytes": "0x"+raw.hex(),
            "manifestRef": json_values((r[4], r[3], r[2], wire.INPUT_SCHEMA, wire.INPUT_CANON)),
            "executionWitness": json_values(witness), "archiveWitness": json_values(archive),
            "inputsHash": neutral.inputs_hash(uint(self.a["chainId"]), self.a["core"], self.a["metadata"], s[0], s[7])}

    def _events(self, bundle, source):
        filters = {}
        for descriptor in wire.expected_events(bundle, source, self.graph):
            topics = list(descriptor["topics"])
            if descriptor["kind"] in ("root_published", "content_appended", "selection_appended"): topics = topics[:2]
            while topics and topics[-1] is None: topics.pop()
            filters[dumps([descriptor["address"], topics])] = descriptor["address"], topics
        for name in ("governanceScheduled", "governanceExecuted"):
            topics = [wire.EVENTS[name], bundle["finality"]["executionWitness"][0]]
            filters[dumps([self.a["executor"], topics])] = self.a["executor"], topics
        f = wire.validate_finality(bundle["finality"], source, self.graph)
        execution = wire.validate_execution(bundle["execution"], source, self.graph, f)
        for host, topics in ((self.a["executor"], [wire.EVENTS["governanceCalldataPublished"], execution["callDataKey"]]),
                (self.a["outputManifest"], [content_wire.EVENTS["manifestAdvanced"], bundle["content"]["manifest"]["planHash"]])):
            filters[dumps([host, topics])] = host, topics
        histories = [self._history(target, topics) for target, topics in filters.values()]
        events, stamps = {}, {}
        for history in histories:
            for block, stamp in history["blockTimestamps"].items():
                require(block not in stamps or stamps[block] == stamp, "policy original block time conflict"); stamps[block] = stamp
            for log in history["logs"]:
                key = log["blockHash"], log["transactionHash"], log["logIndex"]
                require(key not in events or events[key] == log, "policy original log conflict"); events[key] = log
        ordered = sorted(events.values(), key=lambda log: tuple(quantity(log[k]) for k in ("blockNumber", "transactionIndex", "logIndex")))
        return [{"log": log, "timestamp": stamps[str(quantity(log["blockNumber"]))]} for log in ordered]

    def _capture(self):
        self._bindings(); state = self._state(); self._definitions()
        source = {k: self.a[k] for k in (*COMMON, "tokenId")}
        finality = self._finality(); f = wire.validate_finality(finality, source, self.graph); statement = f["statement"]
        wire.validate_routes(self.provider_evidence, source, self.graph, f)
        content = self._content(statement); content_result = content_wire.validate(content, source, self.graph, statement)
        preservation = self._preservation(statement, content_result)
        preserved = preservation_wire.validate(preservation, source, self.graph, statement, content_result)
        membership = self._membership(preserved["snapshot"]["membership"], content_result["tokenIds"])
        static = self._static_components(preserved["snapshot"], content_result, statement)
        bundle = {"provider": self.provider_evidence, "finality": finality, "content": content, **preservation,
            "membership": membership, "staticComponents": static, "execution": self._execution(finality)}
        derived = wire.validate_bundle(bundle, source, self.graph)
        events = self._events(bundle, source); wire.validate_event_join(bundle, source, self.graph, events)
        transactions, headers = self._transactions(events, source)
        reconstruction = wire.validate_governance(bundle, source, self.graph, {k:v["normalized"] for k,v in transactions.items()}, events)
        reconciliation = scoped_finality_observations.reconcile(source, {"policyFinality": self.reader.rows}, self.pins)
        if type(self.reader.transport) is rpc.PublicScopedReplayTransport: self.reader.transport.finish()
        result = {"profile": PROFILE, "profileHash": PROFILE_HASH, "version": "2", "sourceReviewCommit": SOURCE_REVISION,
            "provenance": self.provenance, "source": source, "sourceState": state, "identity": self.identity,
            "anchorHash": keccak256(self.anchor_bytes), "transcriptHash": keccak256(self.reader.transcript()), "graph": self.graph,
            "bundle": bundle, "events": events, "historicalCoreFacts": derived["historicalCoreFacts"],
            "headers": headers, "transactions": transactions, "reconstruction": reconstruction,
            "definitions": [{"documentId":r["id"],"payloadHex":"0x"+r["bytes"].hex()} for r in wire.definitions()],
            "documentEvidence": list(self.documents.values()), "storeChunks": self.chunks,
            "historyCoverage": [r["coverage"] for r in self._histories], "observationReconciliation": reconciliation,
            "claims": CLAIMS, "qualification": QUALIFICATION}
        raw = dumps(result); require(len(raw) <= MAX_OUTPUT, "policy source snapshot bound")
        return raw

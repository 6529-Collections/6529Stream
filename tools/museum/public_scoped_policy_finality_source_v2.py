"""Pinned scoped factory policy V2 history; current admission is never substituted."""
from . import native_scoped_policy_finality_wire_v2 as wire
from . import native_finality_wire as neutral
from . import public_scoped_finality_rpc as rpc
from . import scoped_finality_observations
from . import scoped_policy_content_wire_v2 as content_wire
from . import scoped_policy_preservation_wire_v2 as preservation_wire
from .canonical import dumps, hex_bytes, keccak256, loads, uint
from .chain_abi import Array, decode
from .chain_rpc import quantity
from .current_rights_source import DOCUMENT_FACTS
from .independent_wire import RAW_BYTES, ZERO, ZERO_ADDRESS, json_values, require
from .public_finality_source import PublicFinalitySource as NeutralReads
from .public_scoped_finality_source import PublicScopedFinalitySource as TransactionReads
from .public_chain_history import PROFILE_HASH as HISTORY_PROFILE_HASH
from .conservation_capture_join import COMMON
from .scoped_policy_membership_v2 import ScopedPolicyMembershipReads
from .scoped_policy_content_source_reads_v2 import ScopedPolicyContentReads
from .scoped_policy_preservation_source_reads_v2 import ScopedPolicyPreservationSourceReads
from .scoped_policy_static_components_v2 import ScopedPolicyStaticReads

PROFILE = "STREAM_MUSEUM_PUBLIC_SCOPED_POLICY_FINALITY_SOURCE_V2"
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
QUALIFICATION = ("Original scoped factory policy V2 evidence with the original 22-role catalogue and factory-derived scoped V2 configuration. "
    "The original authoritative scoped membership, ordered output/readiness rows, full policy rows, canonical snapshot/reference payloads, "
    "STATIC source preimages and six component hashes join original root and finality history. Current burns are separate "
    "observations. Core facts, metadata-component facts and terminal-admission preimages remain hash-only. Retained HTML "
    "samples do not reconstruct all served JSON or browser execution. RPC observations do not authenticate consensus, "
    "runtime provenance, signatures, original authority or full EVM execution. CurrentAuthority/Deferred factories and VIEW use separate profiles.")
PROFILE_BYTES = dumps({"name": PROFILE, "version": "2", "status": "prospective_unregistered_source_profile",
    "sourceReviewCommit": SOURCE_REVISION, "rpcProfileHash": rpc.PROFILE_HASH, "historyProfileHash": HISTORY_PROFILE_HASH,
    "supportedProfile": "original_TOKEN_RELEASE_SEASON_FACTORY_POLICY_V2", "graphRoles": list(ADDRESSES), "scopeTypes": ["1", "2", "3"],
    "bounds": {"anchorBytes": str(MAX_ANCHOR), "snapshotBytes": str(MAX_OUTPUT), "outputs": "818",
        "rootHistory": "256", "uniqueStaticSourceBytes": str(8 * 1024 * 1024)},
    "rules": ["V1 provider roles six and seven retain their original meaning; V2 output sources come from separate fixed bindings.",
        "The selected original root, snapshot, reference, source-set policies and finality statement are joined by exact native profiles.",
        "Current heads and token lifecycle are separately observed; no current eligibility getter replaces historical evidence.",
        "The exact complete original statement is retained in both Registry staging and the original Store.",
        "Canonical provider logs, successful receipts and original transaction inputs are retained with explicit external trust limits."],
    "claims": CLAIMS, "qualification": QUALIFICATION})
PROFILE_HASH = keccak256(PROFILE_BYTES)

from .public_policy_finality_source_v2 import ADDRESS_BINDINGS as COLLECTION_ADDRESSES, HASH_BINDINGS as COLLECTION_HASHES
from .scoped_policy_factory_v2 import ScopedPolicyFactoryReads


def _shared_binding(row):
    source, getter, target = row
    return source not in ("leafManifest", "checkpoint") and target not in ("leafManifest", "checkpoint") and not (
        source == "provider" and getter.startswith(("policyOutput", "policySnapshot", "policyReference")))


ADDRESS_BINDINGS = tuple((s.replace("entropyFactory", "sourceFactory"), getter, d)
    for s, getter, d in COLLECTION_ADDRESSES if _shared_binding((s,getter,d)))
HASH_BINDINGS = tuple((s.replace("entropyFactory", "sourceFactory"), getter, d)
    for s, getter, d in COLLECTION_HASHES if _shared_binding((s,getter,d)))


class PublicScopedPolicyFinalitySource(ScopedPolicyContentReads, ScopedPolicyPreservationSourceReads, ScopedPolicyStaticReads, ScopedPolicyMembershipReads, ScopedPolicyFactoryReads):
    _read, _one, _history = NeutralReads._read, NeutralReads._one, NeutralReads._history
    _carrier, _chunk, _state, _execution = NeutralReads._carrier, NeutralReads._chunk, NeutralReads._state, NeutralReads._execution
    _transactions = TransactionReads._transactions
    snapshot, transcript = NeutralReads.snapshot, NeutralReads.transcript

    def __init__(self, anchor_bytes, transport, *, provenance="synthetic_fixture"):
        require(provenance in ("synthetic_fixture", "trusted_rpc") and (provenance != "trusted_rpc"
            or type(transport) in (rpc.PublicScopedRpcTransport, rpc.PublicScopedReplayTransport)), "policy source provenance")
        a = loads(anchor_bytes, maximum=MAX_ANCHOR, canonical=True)
        require(type(a) is dict and set(a) == set(COMMON) | set(ADDRESSES) |
            {"profile", "tokenId", "scope", "codePins", "runtimeAdmission"} and a["profile"] == PROFILE, "policy source anchor shape/profile")
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
        self.scope = wire.scope_value(a["scope"])
        require(self.scope[1] == uint(a["collectionId"]) and (self.scope[0] != 1 or self.scope[2] == uint(a["tokenId"])), "scoped policy source target/scope")
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
        config["sourceConfigurationHash"] = self._one(a["provider"], "finalitySourceConfigurationHash()", "bytes32")
        config["factoryBinding"] = json_values(self._one(a["provider"], "scopedPolicyPublicationBinding()", wire.FACTORY_BINDING))
        config["collectionPolicyOutput"] = {"address": self._one(a["provider"], "policyOutputManifestV2()", "address"),
            "runtimeHash": self._one(a["provider"], "policyOutputManifestV2CodeHash()", "bytes32")}
        # Saved constructor catalogue pins remain distinct from selected scoped children.
        for name in ("originalConfiguration", "scopedConfiguration", "policyConfiguration"):
            for target, digest in zip(config[name][0], config[name][1]):
                require(self.pins.get(target) == digest, "scoped policy original catalogue runtime pin")
        output = config["collectionPolicyOutput"]
        require(self.pins.get(output["address"]) == output["runtimeHash"], "scoped policy inherited output runtime pin")
        for getter, index in (("policySnapshotPublicationV2", 8), ("policyReferencePublicationV2", 9)):
            require(self._one(a["provider"], getter+"()", "address") == config["policyConfiguration"][0][index]
                and self._one(a["provider"], getter+"CodeHash()", "bytes32") == config["policyConfiguration"][1][index],
                "scoped policy inherited publication binding")
        require(self._one(a["provider"], "contentLeafManifest()", "address") == config["originalConfiguration"][0][6]
            and self._one(a["provider"], "contentLeafManifestCodeHash()", "bytes32") == config["originalConfiguration"][1][6],
            "scoped policy original role six binding")
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
        for address in (*d[:9], *d[11], a["sourceFactory"]):
            require(address in self.pins and self._one(a["discovery"], "dependencyCodeHash(address)", "bytes32", ("address",), (address,)) == self.pins[address],
                "scoped policy discovery dependency pin")
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
        filters = {}
        for descriptor in wire.expected_events(bundle, source, self.graph):
            topics = list(descriptor["topics"])
            if descriptor["kind"] in ("root_published", "content_appended", "selection_appended"): topics = topics[:2]
            while topics and topics[-1] is None: topics.pop()
            filters[dumps([descriptor["address"], topics])] = descriptor["address"], topics
        for name in ("governanceScheduled", "governanceExecuted"):
            topics = [wire.EVENTS[name], bundle["finality"]["executionWitness"][0]]
            filters[dumps([self.a["executor"], topics])] = self.a["executor"], topics
        f = wire.validate_finality(bundle["finality"], source, self.graph, self.scope)
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
        finality = self._finality(); f = wire.validate_finality(finality, source, self.graph, self.scope); statement = f["statement"]
        content = self._content(statement); content_result = content_wire.validate(content, source, self.graph, statement)
        preservation = self._preservation(statement, content_result)
        preserved = preservation_wire.validate(preservation, source, self.graph, statement, content_result)
        factory = self._scoped_policy_factory("publicationFactory", self.scope, preserved["source"][9][0])
        config = self.provider_evidence["configuration"]
        config["selectedConfiguration"] = json_values(wire.selected_configuration(config["originalConfiguration"], factory["recipe"], factory["graph"]))
        require(self._one(self.a["renderCriticalInventory"], "dependencyHash()", "bytes32") == config["selectedConfiguration"][6], "scoped policy factory inventory hash")
        wire.validate_routes(self.provider_evidence, source, self.graph, f, factory)
        membership = self._membership(self.scope, preserved["snapshot"]["membership"], content_result["tokenIds"])
        static = self._static_components(preserved["snapshot"], content_result, statement)
        bundle = {"scope": json_values(self.scope), "factory": factory, "provider": self.provider_evidence, "finality": finality, "content": content, **preservation,
            "membership": membership, "staticComponents": static, "execution": self._execution(finality)}
        derived = wire.validate_bundle(bundle, source, self.graph)
        events = self._events(bundle, source); wire.validate_event_join(bundle, source, self.graph, events)
        transactions, headers = self._transactions(events, source)
        reconstruction = wire.validate_governance(bundle, source, self.graph, {k:v["normalized"] for k,v in transactions.items()}, events)
        reconciliation = scoped_finality_observations.reconcile(source, {"scopedPolicyFinality": self.reader.rows}, self.pins)
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

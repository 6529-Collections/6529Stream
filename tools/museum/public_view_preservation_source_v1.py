"""Pinned original VIEW preservation snapshot, full-output tree and typed Router root."""
from . import native_view_preservation_wire_v1 as wire
from . import public_history_rpc as rpc
from . import conservation_capture_join as observations
from . import view_preservation_adoption_wire_v1 as adoption_wire
from . import view_policy_membership_v2 as membership_wire
from .canonical import MuseumError, dumps, hex_bytes, keccak256, loads, uint
from .chain_rpc import quantity
from .conservation_capture_join import COMMON
from .current_rights_source import DOCUMENT_FACTS
from .independent_wire import RAW_BYTES, ZERO, json_values, require
from .public_chain_history import PROFILE_HASH as HISTORY_PROFILE_HASH
from .public_finality_source import PublicFinalitySource as NeutralReads
from .view_preservation_adoption_source_reads_v1 import ViewPreservationAdoptionReads
from .view_policy_membership_v2 import ViewPolicyMembershipReads
from .view_preservation_output_source_reads_v1 import ViewPreservationOutputReads
from .view_preservation_snapshot_source_reads_v1 import ViewPreservationSnapshotReads
from .view_preservation_root_wire_v1 import ViewPreservationRootReads
from . import view_preservation_snapshot_wire_v1 as snapshot_wire

PROFILE = "STREAM_MUSEUM_PUBLIC_VIEW_PRESERVATION_SOURCE_V1"
SOURCE_REVISION = wire.SOURCE_REVISION
MAX_ANCHOR, MAX_OUTPUT = 65536, 64 * 1024 * 1024
ADDRESSES = wire.GRAPH_KEYS
CLAIMS = {"originalAdoptionBytesRetained": True, "completeSealedMembershipChecked": True,
    "originalSourcePolicyRowsChecked": True, "completeCheckpointRowsChecked": True, "contentMerkleTreeChecked": True,
    "originalSnapshotSourceRetained": True, "typedRouterContentRootChecked": True,
    "coveredOutputPartBytesChecked": True, "originalAuthorityReexecuted": False,
    "originalRenderedBytesRecovered": False, "rendererReexecuted": False,
    "currentEligibilityVerified": False, "currentArchiveLivenessVerified": False,
    "providerLogCompletenessTrusted": True, "sourceConsensusVerified": False,
    "nativeViewFinalityEstablished": False, "actualChainAcceptance": False,
    "completeAcquisitionPacket": False}
QUALIFICATION = (
    "Original non-sanction VIEW preservation source from immutable snapshot payloads, exact tagged "
    "Router adoption history, distinct producer admission, complete sealed membership/policies, all "
    "checkpoint rows, covered parts/index and typed CONTENT_ROOT. The saved snapshot supplies the "
    "original checkpoint source; current getters and rerendering cannot replace it. Full-output content "
    "Merkle leaves remain distinct from the ordered outputRoot and old live VIEW output profile. "
    "Original rendered JSON/HTML, media, browser behavior, historical authority/signatures, deployment "
    "provenance, consensus, current archive liveness and acquisition acceptance are not proved. "
    "Reference/inventory, selected provider and full finality integration remain separate native work.")
PROFILE_BYTES = dumps({"name": PROFILE, "version": "1",
    "status": "prospective_unregistered_source_profile", "sourceReviewCommit": SOURCE_REVISION,
    "rpcProfileHash": rpc.PROFILE_HASH, "historyProfileHash": HISTORY_PROFILE_HASH,
    "supportedProfile": "original_VIEW_PRESERVATION_V1_SNAPSHOT_AND_CONTENT_ROOT",
    "graphRoles": list(ADDRESSES), "scopeTypes": ["4"],
    "nativeDefinitions": [{"id": row["id"], "kind": str(row["kind"]), "hash": row["hash"]}
        for row in wire.definitions()],
    "consumerDefinitions": [{"id": adoption_wire.PROFILE, "hash": adoption_wire.PROFILE_HASH}],
    "bounds": {"anchorBytes": str(MAX_ANCHOR), "snapshotBytes": str(MAX_OUTPUT),
        "formatOutputRows": "16384", "partRows": "64", "outputParts": "256", "snapshotPolicies": "630",
        "note": "Transcript and package aggregate bounds also apply; format limits are not universal capture or native gas acceptance."},
    "rules": ["Externally pinned snapshot/root and checkpoint/manifest select immutable original evidence.",
        "The complete saved snapshot payload supplies the checkpoint source; no currentSource substitute is allowed.",
        "Complete shared adoption and CONTENT_ROOT history preserves exact profile tags and separate scope heads.",
        "Every original native row, part and ordered index joins both outputRoot and distinct full-output contentRoot.",
        "Historical getter code matches retained runtime pins; provider completeness and external runtime admission remain explicit.",
        "Only native definitions are read from Schema Registry; local consumer profiles are retained separately.",
        "No rendering, current eligibility, signature execution or native finality result is manufactured."],
    "claims": CLAIMS, "qualification": QUALIFICATION})
PROFILE_HASH = keccak256(PROFILE_BYTES)


class PublicViewPreservationSource(ViewPreservationAdoptionReads, ViewPolicyMembershipReads, ViewPreservationOutputReads,
        ViewPreservationSnapshotReads, ViewPreservationRootReads):
    _read, _one, _history = NeutralReads._read, NeutralReads._one, NeutralReads._history
    _carrier, _chunk, _state = NeutralReads._carrier, NeutralReads._chunk, NeutralReads._state

    def __init__(self, anchor_bytes, transport, *, provenance="synthetic_fixture"):
        require(provenance in ("synthetic_fixture", "trusted_rpc") and (provenance != "trusted_rpc"
            or type(transport) in (rpc.PublicRpcTransport, rpc.PublicReplayTransport)), "VIEW preservation source provenance")
        a = loads(anchor_bytes, maximum=MAX_ANCHOR, canonical=True)
        require(type(a) is dict and set(a) == set(COMMON) | set(ADDRESSES) |
            {"profile", "tokenId", "scope", "checkpointId", "manifestRecordHash", "snapshotRecordHash", "rootRecordHash", "codePins", "runtimeAdmission"}
            and a["profile"] == PROFILE, "VIEW preservation anchor shape/profile")
        require(all(uint(a[key]) > 0 for key in ("chainId", "collectionId", "tokenId"))
            and a["environment"] in ("local_evm_fixture", "public_chain"), "VIEW preservation source identity")
        uint(a["blockNumber"], 64)
        uint(a["timestamp"], 64)
        for key in ("blockHash", "stateRoot", "deploymentEvidenceHash", "checkpointId", "manifestRecordHash", "snapshotRecordHash", "rootRecordHash"):
            require(any(hex_bytes(a[key], 32)), "VIEW preservation anchor commitment")
        admission = a["runtimeAdmission"]
        require(type(admission) is dict and set(admission) == {"sourceCommit", "kind", "artifactHash"}
            and admission["sourceCommit"] == SOURCE_REVISION and any(hex_bytes(admission["artifactHash"], 32))
            and admission["kind"] == ("synthetic_fixture" if provenance == "synthetic_fixture" else "externally_admitted_runtime"),
            "VIEW preservation external runtime admission")
        require(type(a["codePins"]) is list and 0 < len(a["codePins"]) <= 256, "VIEW preservation code pin bound")
        pins = {}
        for row in a["codePins"]:
            require(type(row) is dict and set(row) == {"address", "runtimeHash"}
                and any(hex_bytes(row["address"], 20)) and any(hex_bytes(row["runtimeHash"], 32))
                and row["address"] not in pins, "VIEW preservation code pin")
            pins[row["address"]] = row["runtimeHash"]
        require(all(a[key] in pins for key in ADDRESSES), "VIEW preservation graph pin missing")
        self.a, self.anchor_bytes, self.pins, self.provenance = a, anchor_bytes, pins, provenance
        self.scope = wire.scope_value(a["scope"])
        require(self.scope[1] == uint(a["collectionId"]), "VIEW preservation scope collection differs")
        self.graph = {key: {"address": a[key], "runtimeHash": pins[a[key]]} for key in ADDRESSES}
        wire.context_graph(a, self.graph)
        self.reader = rpc.PublicRecordingReader(transport, a["blockHash"])
        self._reads, self._histories, self.documents, self.chunks = {}, [], {}, {}
        self._started, self._snapshot = False, None

    def _bindings(self):
        for address, digest in self.pins.items():
            code = hex_bytes(self.reader.code(address))
            require(0 < len(code) <= 24576 and keccak256(code) == digest, "VIEW preservation pinned runtime differs")
        for role, getter, target in (("schemas", "chunkStore()", "store"),
                ("coverage", "core()", "core"), ("coverage", "schemaRegistry()", "schemas")):
            require(self._one(self.a[role], getter, "address") == self.a[target],
                "VIEW preservation immutable schema/coverage binding")

    def _definitions(self):
        for definition in wire.definitions():
            key, expected = definition["id"], definition["bytes"]
            facts = self._one(self.a["schemas"], "documentFacts(bytes32)", DOCUMENT_FACTS, ("bytes32",), (key,))
            require(facts[0] and facts[1] == definition["kind"] and facts[2] in (0, 1, 2)
                and facts[3:7] == (definition["hash"], RAW_BYTES, ZERO, len(expected))
                and 0 < facts[7] <= 64 and facts[8] != ZERO, "VIEW preservation retained definition facts")
            hashes, parts = [], []
            for index in range(facts[7]):
                digest = self._one(self.a["schemas"], "documentChunkHashAt(bytes32,uint256)", "bytes32",
                    ("bytes32", "uint256"), (key, index))
                hashes.append(digest)
                parts.append(self._chunk(digest))
            require(b"".join(parts) == expected, "VIEW preservation native definition bytes differ")
            self.documents[key] = {"documentId": key, "facts": json_values(facts),
                "chunkHashes": hashes, "payloadHex": "0x" + expected.hex()}

    def _events(self, bundle, context):
        filters = {}
        for item in wire.expected_events(bundle, context, self.graph):
            topics = list(item.get("historyTopics", item["topics"]))
            while topics and topics[-1] is None: topics.pop()
            filters[dumps([item["address"], topics])] = item["address"], topics
        histories = [self._history(target, topics) for target, topics in filters.values()]
        events, stamps = {}, {}
        for history in histories:
            for block, stamp in history["blockTimestamps"].items():
                require(block not in stamps or stamps[block] == stamp, "VIEW preservation original block time conflict")
                stamps[block] = stamp
            for log in history["logs"]:
                key = log["blockHash"], log["transactionHash"], log["logIndex"]
                require(key not in events or events[key] == log, "VIEW preservation original log conflict")
                events[key] = log
        ordered = sorted(events.values(), key=lambda row: tuple(quantity(row[key])
            for key in ("blockNumber", "transactionIndex", "logIndex")))
        # The public history scanner rejects removed logs before normalizing its
        # retained fields. Restore that checked fact for the joined event format.
        return [{"log": {**row, "removed": False},
            "timestamp": stamps[str(quantity(row["blockNumber"]))]} for row in ordered]

    def _capture(self):
        self._bindings()
        state = self._state()
        self._definitions()
        context = {key: self.a[key] for key in (*COMMON, "tokenId")}
        snapshot = self._view_preservation_snapshot(self.a["snapshotRecordHash"], self.scope)
        retained = snapshot_wire.validate(snapshot, context, self.graph)
        original_source = retained["source"][3]
        header = self._view_preservation_header()
        checkpoint = header["checkpoint"]["plan"]
        require(wire.scope_value(checkpoint[0]) == self.scope,
            "VIEW preservation pinned checkpoint scope differs")
        adoption = self._preservation_adoption(checkpoint[1], self.scope)
        adopted = adoption_wire.validate(adoption, context, self.graph)
        membership = self._view_membership(adopted["policyBinding"])
        members = membership_wire.validate(membership, context, self.graph, adopted["policyBinding"])
        combined = {**adopted, "tokenIds": members["tokenIds"], "policies": members["policies"]}
        output = self._view_preservation_outputs(header, combined, original_source)
        root = self._view_preservation_root(self.a["rootRecordHash"], self.scope)
        bundle = {"scope": json_values(self.scope), "adoption": adoption, "membership": membership,
            "output": output, "snapshot": snapshot, "root": root}
        wire.validate_bundle(bundle, context, self.graph)
        target = wire.target_proof(bundle, context, self.graph)
        require(target["row"][2] == self.identity["collectionSerial"],
            "VIEW preservation target permanent serial differs")
        events = self._events(bundle, context)
        event_result = wire.validate_event_join(bundle, context, self.graph, events)
        reconciliation = observations._observations(context, {"view-preservation": self.reader.rows}, self.pins)
        if type(self.reader.transport) is rpc.PublicReplayTransport:
            self.reader.transport.finish()
        result = {"profile": PROFILE, "version": "1", "profileHash": PROFILE_HASH,
            "sourceReviewCommit": SOURCE_REVISION, "provenance": self.provenance,
            "anchorHash": keccak256(self.anchor_bytes), "transcriptHash": keccak256(self.reader.transcript()),
            "sourceState": state, "sourceContext": context, "identity": self.identity,
            "graph": self.graph, "bundle": bundle, "targetProof": target,
            "events": events, "eventReconciliation": event_result,
            "definitions": [{"documentId": row["id"], "payloadHex": "0x" + row["bytes"].hex()}
                for row in wire.definitions()], "documentEvidence": list(self.documents.values()),
            "storeChunks": self.chunks, "historyCoverage": [row["coverage"] for row in self._histories],
            "observationReconciliation": reconciliation, "claims": CLAIMS, "qualification": QUALIFICATION}
        raw = dumps(result)
        require(len(raw) <= MAX_OUTPUT, "VIEW preservation snapshot bound")
        return raw

    def snapshot(self):
        if self._snapshot is not None: return self._snapshot
        require(not self._started, "failed VIEW preservation capture cannot resume")
        self._started = True
        try: self._snapshot = self._capture()
        except MuseumError: raise
        except (KeyError, TypeError, ValueError, IndexError, OverflowError) as exc:
            raise MuseumError("malformed original VIEW preservation evidence") from exc
        return self._snapshot

    def transcript(self):
        require(self._snapshot is not None, "VIEW preservation snapshot required")
        return self.reader.transcript()

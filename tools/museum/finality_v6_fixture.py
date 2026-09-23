"""Synthetic twelve-source finality fixture; no chain or authority claim.

The first eleven inputs come unchanged from :class:`TitleV5Fixture`.  This
subclass adds the missing native finality/checkpoint products and their exact
public-read state to the same headers, receipts and RPC response map before any
capture is made.
"""
from . import native_finality_wire as wire
from . import public_finality_source as source
from .canonical import dumps, keccak256, loads, schema_id
from .chain_abi import Array, decode, encode
from .current_rights_source import DOCUMENT_FACTS
from .independent_wire import RAW_BYTES, ZERO, ZERO_ADDRESS
from .test_current_rights_source import A, H
from .title_v5_fixture import TitleV5Fixture, TOKEN, COLLECTION


class FinalityV6Fixture(TitleV5Fixture):
    """One coherent synthetic map for title V5 plus collection finality."""

    def __init__(self, *, leaf_count=3, target_index=2, burned=False):
        if not 1 <= leaf_count <= wire.MAX_LEAVES or not 0 <= target_index < leaf_count:
            raise ValueError("invalid synthetic finality leaf selection")
        super().__init__(burned=burned)
        self.finality_leaf_count, self.finality_target_index = leaf_count, target_index
        self.finality_addresses = {
            "core": self.core,
            "host": self.a["host"],
            "router": self.configuration[0][7],
            "originalFinality": A(6),
            "contentProvider": A(7),
            "coreAdapter": A(35000),
            "leafManifest": A(35001),
            "checkpoint": A(35002),
            "inventory": A(35003),
            "artifactCoverage": A(35004),
            "schemas": A(3),
            "store": A(4),
            "artistRegistry": self.registry,
            "executor": self.floor_executor,
            "roles": A(35005),
        }
        for name in ("coreAdapter", "leafManifest", "checkpoint", "inventory",
                "artifactCoverage", "roles"):
            address = self.finality_addresses[name]
            if address in self.codes:
                raise AssertionError("synthetic finality address collision")
            self.codes[address] = ("synthetic e031 native finality " + name).encode("ascii")
            self.pins[address] = keccak256(self.codes[address])
        self._finality_bindings()
        self._finality_definitions()
        self._install_finality()

    def _finality_bindings(self):
        a = self.finality_addresses
        for owner, getter, target in source.ADDRESS_BINDINGS:
            self.add(a[owner], getter + "()", (), (), ("address",), (a[target],))
        for owner, getter, target in source.HASH_BINDINGS:
            self.add(a[owner], getter + "()", (), (), ("bytes32",), (self.pins[a[target]],))
        for owner, getter, target, kind in wire.BINDINGS:
            result = a[source.GRAPH_MAP[target]] if kind == "address" else self.pins[a[source.GRAPH_MAP[target]]]
            self.add(a[source.GRAPH_MAP[owner]], getter, (), (),
                ("address" if kind == "address" else "bytes32",), (result,))
        for key in ("leafManifest", "checkpoint", "contentProvider"):
            self.add(a[key], "deploymentChainId()", (), (), ("uint256",), (int(self.a["chainId"]),))
        for key, interface in (("coreAdapter", "0xebf35615"), ("router", wire.INTERFACES["root"]),
                ("leafManifest", wire.INTERFACES["leafManifest"]),
                ("checkpoint", wire.INTERFACES["checkpoint"]),
                ("inventory", wire.INTERFACES["inventory"])):
            self.add(a[key], "supportsInterface(bytes4)", ("bytes4",), ("0x01ffc9a7",), ("bool",), (True,))
            self.add(a[key], "supportsInterface(bytes4)", ("bytes4",), (interface,), ("bool",), (True,))
            self.add(a[key], "supportsInterface(bytes4)", ("bytes4",), ("0xffffffff",), ("bool",), (False,))

        self.add(a["router"], "servingOriginalFinalityAnchor()", (), (), ("address", "bytes32"),
            (a["originalFinality"], self.pins[a["originalFinality"]]))
        self.add(a["router"], "originalFinalityAnchor(uint256)", ("uint256",), (COLLECTION,),
            ("address", "bytes32"), (a["originalFinality"], self.pins[a["originalFinality"]]))

    def _finality_definitions(self):
        schemas = self.finality_addresses["schemas"]
        for definition in wire.definitions():
            raw = definition["bytes"]
            digest = self.chunk(raw)
            facts = (True, definition["kind"], 0, definition["hash"], RAW_BYTES,
                ZERO, len(raw), 1, keccak256(("finality-definition-" + definition["name"]).encode()))
            self.add(schemas, "documentFacts(bytes32)", ("bytes32",), (definition["id"],),
                (DOCUMENT_FACTS,), (facts,))
            self.add(schemas, "documentChunkHashAt(bytes32,uint256)", ("bytes32", "uint256"),
                (definition["id"], 0), ("bytes32",), (digest,))

    def _raw_event(self, block, address, topics, data):
        receipt = self.receipts[H(400 + block)]
        topics = [keccak256(b"synthetic finality unknown indexed topic") if topic is None else topic
            for topic in topics]
        log = {key: receipt[key] for key in ("transactionHash", "blockHash", "blockNumber", "transactionIndex")}
        log.update(address=address, topics=list(topics), data=data,
            logIndex=hex(len(receipt["logs"])), removed=False)
        receipt["logs"].append(log)
        return log

    def _install_finality(self):
        """Install one exact supplied bundle and every public getter/event it needs."""
        from .test_native_finality_wire import supplied
        a = self.finality_addresses
        context = {key: self.a[key] for key in ("chainId", "core", "collectionId", "blockHash",
            "blockNumber", "timestamp", "stateRoot", "environment", "deploymentEvidenceHash")}
        context["tokenId"] = str(TOKEN)
        graph = {key: {"address": a[source.GRAPH_MAP[key]],
            "runtimeHash": self.pins[a[source.GRAPH_MAP[key]]]} for key in wire.GRAPH_KEYS}
        bundle, _, _ = supplied(context, graph, count=self.finality_leaf_count,
            token_index=self.finality_target_index, artist_id=self.artist_id,
            root_timestamp=1780000002, finality_timestamp=1780000003)
        self.finality_bundle = bundle

        finality, content, execution = (bundle[key] for key in ("finality", "content", "execution"))
        record = wire.from_json(wire.FINALITY_RECORD, finality["record"])
        components = wire.from_json(Array(wire.COMPONENT, 32), finality["components"])
        witness = wire.from_json(wire.EXECUTION_WITNESS, finality["executionWitness"])
        archive = wire.from_json(wire.ARCHIVE_WITNESS, finality["archiveWitness"])
        raw_manifest = bytes.fromhex(finality["manifestBytes"][2:])
        self.chunk(raw_manifest)
        host = a["originalFinality"]
        self.add(host, "collectionFinalityRecord(uint256)", ("uint256",), (COLLECTION,),
            (wire.FINALITY_RECORD,), (record,))
        self.add(host, "finalityComponentCount(uint256)", ("uint256",), (COLLECTION,), ("uint256",), (len(components),))
        self.add(host, "finalityComponents(uint256,uint256,uint256)", ("uint256", "uint256", "uint256"),
            (COLLECTION, 0, len(components)), (Array(wire.COMPONENT, 32),), (components,))
        self.add(host, "finalityManifestStored(bytes32)", ("bytes32",), (record[2],), ("bool",), (True,))
        self.add(host, "finalityManifestBytes(bytes32)", ("bytes32",), (record[2],), ("bytes",), (raw_manifest,))
        self.add(host, "finalityExecutionWitness(bytes32)", ("bytes32",), (record[1],),
            (wire.EXECUTION_WITNESS,), (witness,))
        self.add(host, "finalitySanctionArchiveWitness(bytes32)", ("bytes32",), (record[1],),
            (wire.ARCHIVE_WITNESS,), (archive,))

        self.add(a["router"], "collectionContentRootHead(uint256)", ("uint256",), (COLLECTION,),
            ("bytes32",), (content["rootHead"],))
        for row in content["rootHistory"]:
            value = wire.from_json(wire.ROOT_RECORD, row["record"])
            self.add(a["router"], "contentRootRecord(bytes32)", ("bytes32",), (row["recordHash"],),
                (wire.ROOT_RECORD,), (value,))
        manifest = content["manifest"]
        manifest_record = wire.from_json(wire.LEAF_MANIFEST, manifest["record"])
        manifest_plan = wire.from_json(wire.LEAF_PLAN, manifest["plan"])
        self.add(a["leafManifest"], "manifestRecord(bytes32)", ("bytes32",), (manifest["recordHash"],),
            (wire.LEAF_MANIFEST,), (manifest_record,))
        self.add(a["leafManifest"], "manifestPlan(bytes32)", ("bytes32",), (manifest["planHash"],),
            (wire.LEAF_PLAN,), (manifest_plan,))
        checkpoint = content["checkpoint"]
        checkpoint_plan = wire.from_json(wire.CHECKPOINT, checkpoint["plan"])
        self.add(a["checkpoint"], "checkpoint(bytes32)", ("bytes32",), (checkpoint["planHash"],),
            (wire.CHECKPOINT,), (checkpoint_plan,))
        self.add(a["checkpoint"], "checkpointProfile(bytes32)", ("bytes32",), (checkpoint["planHash"],),
            ("bytes32",), (checkpoint["profile"],))
        for index, item in enumerate(checkpoint["leaves"]):
            leaf = wire.from_json(wire.LEAF, item)
            self.add(a["checkpoint"], "checkpointLeaf(bytes32,uint256)", ("bytes32", "uint256"),
                (checkpoint["planHash"], index), (wire.LEAF,), (leaf,))
        artifact = content["artifact"]
        artifact_value = wire.from_json(wire.ARTIFACT, artifact["artifact"])
        coverage = wire.from_json(wire.COVERAGE, artifact["coverage"])
        self.add(a["artifactCoverage"], "artifact(bytes32)", ("bytes32",), (artifact["artifactHash"],),
            (wire.ARTIFACT,), (artifact_value,))
        self.add(a["artifactCoverage"], "coverage(bytes32)", ("bytes32",), (manifest_record[2],),
            (wire.COVERAGE,), (coverage,))
        for index, item in enumerate(artifact["chunks"]):
            runtime = bytes.fromhex(item["runtime"][2:])
            self.codes[item["pointer"]] = runtime
            self.add(a["artifactCoverage"], "artifactChunk(bytes32,uint32)", ("bytes32", "uint32"),
                (artifact["artifactHash"], index), ("address", "bytes32"), (item["pointer"], item["codeHash"]))
            self.chunk(runtime[1:])

        action = wire.from_json(wire.GOVERNANCE_ACTION, execution["action"])
        calls = tuple(bytes.fromhex(value[2:]) for value in execution["callDatas"])
        runtime = bytes.fromhex(execution["runtime"][2:])
        self.codes[execution["callDataPointer"]] = runtime
        self.add(a["executor"], "governanceAction(bytes32)", ("bytes32",), (witness[0],),
            (wire.GOVERNANCE_ACTION,), (action,))
        self.add(a["executor"], "scheduledCallDataPointer(bytes32)", ("bytes32",), (witness[0],),
            ("address",), (execution["callDataPointer"],))
        self.add(a["executor"], "scheduledCallData(bytes32)", ("bytes32",), (witness[0],),
            (Array("bytes", 64),), (calls,))
        call_key = keccak256(b"".join(bytes.fromhex(keccak256(value)[2:]) for value in calls))
        self.add(a["executor"], "publishedCallData(bytes32)", ("bytes32",), (call_key,),
            ("address",), (execution["callDataPointer"],))

        expected = wire.expected_events(bundle, context, graph)
        order = {kind: index for index, kind in enumerate(("artifact_recorded", "coverage_completed",
            "checkpoint_started", "leaf_verified", "checkpoint_completed", "manifest_started", "manifest_verified"))}
        early = sorted((row for row in expected if row["kind"] in order),
            key=lambda row: order[row["kind"]])
        first_leaf_event = None
        for row in early:
            observed = self._raw_event(3, row["address"], row["topics"], row["data"])
            if row["kind"] == "leaf_verified" and first_leaf_event is None:
                first_leaf_event = observed
        for row in expected:
            if row["kind"] in order: continue
            block = 3 if row["kind"] == "root_published" else 4
            self._raw_event(block, row["address"], row["topics"], row["data"])
        nonce = 1
        topics = (wire.EVENTS["governanceScheduled"], witness[0], self.topic("uint8", action[1]),
            self.topic("address", action[2]))
        scheduled_values = (1, *action[3:11], nonce, action[11], action[15], action[16], action[17])
        publication_data = encode(("uint16", "address", "address"),
            (1, execution["callDataPointer"], A(35006)))
        self._raw_event(3, a["executor"], (wire.EVENTS["governanceCalldataPublished"], call_key),
            "0x" + publication_data.hex())
        self._raw_event(3, a["executor"], topics,
            "0x" + encode(wire.GOVERNANCE_SCHEDULED_DATA, scheduled_values).hex())
        executed_values = (1, *action[3:9], action[12], action[17])
        self._raw_event(4, a["executor"],
            (wire.EVENTS["governanceExecuted"], witness[0], self.topic("uint8", action[1]), self.topic("address", action[2])),
            "0x" + encode(wire.GOVERNANCE_EXECUTED_DATA, executed_values).hex())
        mint = self.transfer_rows[0]
        assert first_leaf_event is not None
        assert (int(mint["blockNumber"], 16), int(mint["logIndex"], 16)) < (
            int(first_leaf_event["blockNumber"], 16), int(first_leaf_event["logIndex"], 16))

        common = {key: self.a[key] for key in ("chainId", "blockHash", "blockNumber", "timestamp",
            "stateRoot", "environment", "deploymentEvidenceHash", "core", "collectionId")}
        self.finality_anchor = {**common, "profile": source.PROFILE, "tokenId": str(TOKEN), **a,
            "runtimeAdmission": {"sourceCommit": source.SOURCE_REVISION, "kind": "synthetic_fixture",
                "artifactHash": keccak256(b"synthetic e031 finality source artifact")},
            "codePins": [{"address": address, "runtimeHash": self.pins[address]}
                for address in dict.fromkeys(a.values())]}

    def finality_source(self):
        return source.PublicFinalitySource(dumps(self.finality_anchor), self)

    def finality_result(self):
        return loads(self.finality_source().snapshot(), maximum=source.MAX_OUTPUT)

    def finality_capture(self):
        from . import public_finality_capture as capture
        adapter = self.finality_source()
        return capture._assemble(adapter, keccak256(adapter.anchor_bytes), source.PROFILE_HASH)

    def preservation_inputs(self):
        """Build the unchanged V5 stack with the V6-required script/ONCHAIN mode."""
        from ..metadata.genesis_dossier_profile import examples
        from ..metadata.test_acquisition_packet_v5 import supplied
        from . import acquisition_attribution_v5 as attribution
        from . import acquisition_direct_conservation as direct_assembly
        from . import acquisition_packet_v5 as packet_v5
        from . import public_attribution_capture as attribution_capture
        from . import public_prospective_reference_capture as prospective_capture
        from . import public_prospective_reference_source as prospective

        components = self.packages()
        direct_packet = direct_assembly.compose(*sum(([value.files, value.manifest_hash]
            for value in components), []), disclosure="public")
        packet = supplied(direct_packet)
        script = examples()["script-packet.json"]
        packet.update(workClass="script", metadataMode="ONCHAIN")
        packet["dossierBag"] = script["dossierBag"]
        packet["preservation"] = script["preservation"]
        packet["scriptDrill"] = script["scriptDrill"]
        snapshot = loads(self.source().snapshot(), maximum=32 * 1024 * 1024)
        packet["attribution"]["binding"]["record"]["recordHash"] = snapshot["current"]["binding"][3]
        raw = dumps(packet)
        packet_assembly = packet_v5.compose(direct_packet.files, direct_packet.manifest_hash,
            raw, keccak256(raw), disclosure="public")
        adapter = self.source(); adapter.snapshot(); transcript = adapter.transcript()
        attr = attribution_capture.replay(adapter.anchor_bytes, keccak256(adapter.anchor_bytes),
            attribution_capture._source().PROFILE_HASH, transcript, keccak256(transcript),
            provenance="synthetic_fixture", disclosure="public")
        old = attribution.compose(packet_assembly.files, packet_assembly.manifest_hash,
            attr.files, attr.manifest_hash, disclosure="public")
        adapter = self.prospective_source_adapter(); adapter.snapshot(); transcript = adapter.transcript()
        reference = prospective_capture.replay(adapter.anchor_bytes, keccak256(adapter.anchor_bytes),
            prospective.PROFILE_HASH, transcript, keccak256(transcript), provenance="synthetic_fixture", disclosure="public")
        return old, self.media_capture(), reference

    def finality_inputs(self):
        title, accession = self.title_inputs()
        # Rebuild the title-V5 package through its public composer so callers
        # receive the exact verified Assembly rather than only parsed reports.
        from . import acquisition_title_v5 as title_v5
        original = title_v5.compose(title.files, title.manifest_hash, accession.files,
            accession.manifest_hash, disclosure="public")
        return original, self.finality_capture()

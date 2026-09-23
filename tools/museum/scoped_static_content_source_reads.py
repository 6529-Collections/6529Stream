"""Original scoped STATIC content reads for the additive public source.

The host owns anchor, provenance, reciprocal runtime admission, public-history
reconciliation and final event chronology. This mixin performs no currentness
or rendering calls and never substitutes a collection leaf-manifest codec.
"""
from . import scoped_static_content_wire as wire
from . import scoped_static_types as t
from .canonical import hex_bytes, keccak256, uint
from .chain_abi import decode, encode
from .chain_rpc import quantity
from .independent_wire import ZERO, json_values, require
from .native_finality_wire import from_json, _topic

SCOPE_ABI = "(uint8,uint256,uint256,bytes32)"
MAX_SNAPSHOT = 524288


class ContentReadsMixin:
    def _content(self, statement):
        statement = from_json(t.STATEMENT, statement)
        a, g = self.a, self.graph
        address = lambda key: g[key]["address"]
        chain, cid = uint(a["chainId"]), uint(a["collectionId"])
        scope = wire.valid_scope(statement[0], cid)
        require(scope == from_json(t.SCOPE, self.scope), "scoped source content scope differs")
        aggregate = self._one(address("router"), "scopedContentRootAggregate(uint256)", t.ROOT_AGGREGATE,
            ("uint256",), (cid,))
        require(0 < aggregate[0] <= t.MAX_HISTORY, "scoped source collection root history bound")
        head = self._one(address("router"), "scopedContentRootHead(" + SCOPE_ABI + ")", "bytes32", (t.SCOPE,), (scope,))
        history = self._history(address("router"), [wire.EVENTS["root"], _topic("uint256", cid)])
        logs = sorted(history["logs"], key=lambda row: tuple(quantity(row[key])
            for key in ("blockNumber", "transactionIndex", "logIndex")))
        require(len(logs) == aggregate[0], "scoped source root event/aggregate denominator")
        roots, selected, seen = [], None, set()
        for log in logs:
            require(log["address"] == address("router") and len(log["topics"]) == 4
                and log["topics"][:2] == [wire.EVENTS["root"], _topic("uint256", cid)], "scoped source root event topics")
            version, record, state = decode(("uint16", t.ROOT_RECORD, t.ROOT_AGGREGATE), hex_bytes(log["data"]), maximum=8192)
            digest = log["topics"][3]
            require(version == 1 and digest != ZERO and digest not in seen
                and record[0][0][1] == cid and log["topics"][2] == wire.scope_subject(chain, address("core"), record[0][0]),
                "scoped source root event identity")
            stored = self._one(address("router"), "scopedContentRootRecord(bytes32)", t.ROOT_RECORD,
                ("bytes32",), (digest,), maximum=8192)
            require(stored == record, "scoped source original root getter/event differs")
            require(record[17] == uint(history["blockTimestamps"][str(quantity(log["blockNumber"]))]),
                "scoped source root timestamp differs")
            seen.add(digest)
            roots.append({"recordHash": digest, "record": json_values(record), "aggregate": json_values(state)})
            if digest == statement[7][0]: selected = record
        require(selected is not None and selected[0][0] == scope, "scoped source original root not in collection history")

        # The root retains a snapshot receipt identity, not a manifest-record key.
        # Decode its original payload to discover the exact manifest record and
        # original checkpoint. The independent snapshot verifier checks all its
        # other fields, retained history and membership/selection relationships.
        require(selected[1:3] == (address("scopedSnapshot"), g["scopedSnapshot"]["runtimeHash"]),
            "scoped source original snapshot host differs")
        publication, receipt = self._read(address("scopedSnapshot"), "snapshotRecord(bytes32)",
            (t.SNAPSHOT_PUBLICATION, t.SNAPSHOT_RECEIPT), ("bytes32",), (selected[0][2],), maximum=8192)
        require(receipt[0] == selected[0][2] and 0 < receipt[6] <= MAX_SNAPSHOT, "scoped source snapshot payload bound")
        payload = self._one(address("scopedSnapshot"), "snapshotPayload(bytes32)", "bytes",
            ("bytes32",), (selected[0][2],), maximum=MAX_SNAPSHOT + 64)
        require(len(payload) == receipt[6] and keccak256(payload) == receipt[5] == selected[3],
            "scoped source original snapshot bytes differ")
        envelope = decode(t.SNAPSHOT_ENVELOPE, payload, maximum=MAX_SNAPSHOT)
        manifest_key, original_manifest = publication[4], envelope[-1][5]
        manifest = self._one(address("outputManifest"), "manifestRecord(bytes32)", t.OUTPUT_MANIFEST,
            ("bytes32",), (manifest_key,))
        require(manifest_key != ZERO and manifest == original_manifest, "scoped source original output manifest differs")
        plan_hash = wire.manifest_plan_hash(chain, address("outputManifest"), address("core"),
            address("staticContent"), address("artifacts"), manifest)
        plan = self._one(address("outputManifest"), "manifestPlan(bytes32)", t.OUTPUT_PLAN, ("bytes32",), (plan_hash,))
        checkpoint = self._one(address("staticContent"), "checkpoint(bytes32)", t.CONTENT_PLAN, ("bytes32",), (manifest[0],))
        require(checkpoint[2] == scope and 0 < checkpoint[3] <= t.MAX_OUTPUTS
            and checkpoint[4] == checkpoint[3], "scoped source complete content bound")
        outputs = [self._one(address("staticContent"), "outputAt(bytes32,uint256)", t.OUTPUT,
            ("bytes32", "uint256"), (manifest[0], i)) for i in range(checkpoint[3])]
        starts = self._history(address("staticContent"), [wire.EVENTS["contentStarted"], manifest[0]])
        require(len(starts["logs"]) == 1, "scoped source content start denominator")
        start = starts["logs"][0]
        version, salt, initial = decode(("uint16", "bytes32", t.CONTENT_PLAN), hex_bytes(start["data"]), maximum=1024)
        require(start["address"] == address("staticContent") and start["topics"] == [wire.EVENTS["contentStarted"], manifest[0]]
            and version == 1 and initial == (*checkpoint[:4], 0, ZERO, ZERO, ZERO), "scoped source original checkpoint start")
        artifact = self._one(address("artifacts"), "artifact(bytes32)", t.ARTIFACT, ("bytes32",), (manifest[2],))
        coverage = self._one(address("artifacts"), "coverage(bytes32)", t.COVERAGE, ("bytes32",), (manifest[3],))
        require(0 < len(artifact[6]) <= t.MAX_PARTS and len(artifact[6]) == len(artifact[7]), "scoped source artifact parts bound")
        chunks = []
        for index, digest in enumerate(artifact[6]):
            pointer, code_hash = self._read(address("artifacts"), "artifactChunk(bytes32,uint32)",
                ("address", "bytes32"), ("bytes32", "uint32"), (manifest[2], index))
            raw = self._carrier(pointer, code_hash, t.CHUNK_BYTES)
            require(raw == self._chunk(digest), "scoped source artifact/Store original part differs")
            chunks.append({"pointer": pointer, "codeHash": code_hash, "runtime": "0x" + (b"\0" + raw).hex()})
        content = {"roots": {"selectedRootHash": statement[7][0], "scopeHead": head,
            "collectionAggregate": json_values(aggregate), "history": roots},
            "checkpoint": {"id": manifest[0], "salt": salt, "plan": json_values(checkpoint), "outputs": json_values(outputs)},
            "manifest": {"recordHash": manifest_key, "planHash": plan_hash, "record": json_values(manifest),
                "plan": json_values(plan), "artifactHash": manifest[2], "artifact": json_values(artifact),
                "coverage": json_values(coverage), "chunks": chunks}}
        wire.validate(content, a, g, statement)
        return content

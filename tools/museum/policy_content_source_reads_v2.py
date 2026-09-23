"""Fixed original COLLECTION V2 content reads; host owns source authentication.

Complete root event history is joined to the canonical head/predecessor chain.
Only historical getters are used, never requireCurrent* or renderer calls.
"""
from . import policy_content_types_v2 as t
from . import policy_content_wire_v2 as wire
from .canonical import hex_bytes, subject_id, uint
from .chain_abi import decode
from .chain_rpc import quantity
from .independent_wire import ZERO, json_values, require
from .native_finality_wire import from_json, _topic


class PolicyContentReads:
    def _content(self, statement):
        s = from_json(t.STATEMENT, statement); a, g = self.a, self.graph
        address = lambda key: g[key]["address"]
        chain, cid = uint(a["chainId"]), uint(a["collectionId"])
        require(s[0] == (0, cid, 0, ZERO), "policy source COLLECTION content only")
        head = self._one(address("router"), "collectionContentRootHead(uint256)", "bytes32", ("uint256",), (cid,))
        require(head != ZERO, "policy source empty collection root head")
        history = self._history(address("router"), [[wire.EVENTS["root"], wire.EVENTS["binding"]], _topic("uint256", cid)])
        logs = sorted(history["logs"], key=lambda row: tuple(quantity(row[key]) for key in ("blockNumber", "transactionIndex", "logIndex")))
        require(0 < len(logs) <= t.MAX_HISTORY * 2, "policy source root event bound")
        roots, bindings, selected = [], {}, None
        for log in logs:
            topics = log["topics"]
            require(log["address"] == address("router") and len(topics) in (3, 4)
                and topics[1] == _topic("uint256", cid), "policy source root event address/topics")
            if topics[0] == wire.EVENTS["binding"]:
                version, b = decode(("uint16", t.ROOT_BINDING), hex_bytes(log["data"]), maximum=4096)
                require(len(topics) == 3 and version == 2 and topics[2] not in bindings, "policy source binding event identity")
                bindings[topics[2]] = (b, log)
                continue
            require(topics[0] == wire.EVENTS["root"] and len(topics) == 4 and topics[2] == subject_id("collection", str(chain),
                address("core"), str(cid)), "policy source root subject")
            version, r = decode(("uint16", t.ROOT_RECORD), hex_bytes(log["data"]), maximum=8192)
            digest = topics[3]
            require(version in (1, 2) and digest != ZERO and r[0][0] == cid, "policy source root event identity")
            stored = self._one(address("router"), "contentRootRecord(bytes32)", t.ROOT_RECORD, ("bytes32",), (digest,), maximum=8192)
            binding = self._one(address("router"), "policyContentRootBinding(bytes32)", t.ROOT_BINDING, ("bytes32",), (digest,))
            require(stored == r and ((version == 1 and binding[0] == ZERO) or (version == 2 and binding[0] == t.PROFILE)),
                "policy source original root/event/binding differs")
            require(r[13] == uint(history["blockTimestamps"][str(quantity(log["blockNumber"]))]), "policy source root timestamp")
            roots.append({"recordHash": digest, "record": json_values(r), "binding": json_values(binding)})
            if digest == s[7][0]: selected = (r, binding)
        require(0 < len(roots) <= t.MAX_HISTORY and selected is not None, "policy source selected original root absent")
        require(set(bindings) == {r["recordHash"] for r in roots if r["binding"][0] == t.PROFILE}, "policy source binding event denominator")
        root_logs = {l["topics"][3]: l for l in logs if l["topics"][0] == wire.EVENTS["root"]}
        for row in roots:
            if row["binding"][0] != t.PROFILE: continue
            binding, event = bindings[row["recordHash"]]; previous = root_logs[row["recordHash"]]
            require(json_values(binding) == row["binding"] and event["transactionHash"] == previous["transactionHash"]
                and event["blockHash"] == previous["blockHash"] and quantity(event["logIndex"]) == quantity(previous["logIndex"]) + 1,
                "policy source binding/root original adjacency")
        root, binding = selected
        require(binding[0] == t.PROFILE and binding[1:5] == (address("outputManifest"), g["outputManifest"]["runtimeHash"],
            address("policyContent"), g["policyContent"]["runtimeHash"]), "policy source selected original V2 hosts")
        manifest_key = root[0][2]
        m = self._one(address("outputManifest"), "manifestRecord(bytes32)", t.OUTPUT_MANIFEST, ("bytes32",), (manifest_key,))
        ph = wire.manifest_plan_hash(chain, g, m)
        mp = self._one(address("outputManifest"), "manifestPlan(bytes32)", t.OUTPUT_PLAN, ("bytes32",), (ph,))
        p = self._one(address("policyContent"), "checkpoint(bytes32)", t.CONTENT_PLAN, ("bytes32",), (m[0],))
        require(p[4] == s[0] and 0 < p[5] <= t.MAX_OUTPUTS and p[6] == p[5], "policy source complete checkpoint bound")
        outputs = [self._one(address("policyContent"), "outputAt(bytes32,uint256)", t.OUTPUT,
            ("bytes32", "uint256"), (m[0], i)) for i in range(p[5])]
        selection = self._one(address("staticSelection"), "checkpoint(bytes32)", t.SELECTION_PLAN, ("bytes32",), (p[0],))
        require(selection[0] == s[0] and selection[3] == selection[4] == p[5], "policy source complete selection bound")
        rows = [self._one(address("staticSelection"), "selectionAt(bytes32,uint256)", t.SELECTION_ROW,
            ("bytes32", "uint256"), (p[0], i)) for i in range(p[5])]
        starts = self._history(address("policyContent"), [wire.EVENTS["contentStarted"], m[0]])
        require(len(starts["logs"]) == 1, "policy source content start denominator")
        log = starts["logs"][0]
        version, salt, initial = decode(("uint16", "bytes32", t.CONTENT_PLAN), hex_bytes(log["data"]), maximum=1024)
        require(log["address"] == address("policyContent") and log["topics"] == [wire.EVENTS["contentStarted"], m[0]]
            and version == 2 and initial == (*p[:6], 0, ZERO, ZERO, ZERO), "policy source original checkpoint start")
        artifact = self._one(address("artifacts"), "artifact(bytes32)", t.ARTIFACT, ("bytes32",), (m[5],))
        coverage = self._one(address("artifacts"), "coverage(bytes32)", t.COVERAGE, ("bytes32",), (m[6],))
        require(0 < len(artifact[6]) <= t.MAX_PARTS and len(artifact[6]) == len(artifact[7]), "policy source artifact part bound")
        chunks = []
        for index, digest in enumerate(artifact[6]):
            pointer, pin = self._read(address("artifacts"), "artifactChunk(bytes32,uint32)", ("address", "bytes32"),
                ("bytes32", "uint32"), (m[5], index))
            raw = self._carrier(pointer, pin, t.CHUNK_BYTES)
            require(raw == self._chunk(digest), "policy source artifact/Store part differs")
            chunks.append({"pointer": pointer, "codeHash": pin, "runtime": "0x" + (b"\0" + raw).hex()})
        content = {"roots": {"selectedRootHash": s[7][0], "rootHead": head, "history": roots},
            "checkpoint": {"id": m[0], "salt": salt, "plan": json_values(p), "outputs": json_values(outputs),
                "selectionPlan": json_values(selection), "selectionRows": json_values(rows)},
            "manifest": {"recordHash": manifest_key, "planHash": ph, "record": json_values(m), "plan": json_values(mp),
                "artifactHash": m[5], "artifact": json_values(artifact), "coverage": json_values(coverage), "chunks": chunks}}
        wire.validate(content, a, g, s)
        return content

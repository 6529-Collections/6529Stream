"""Historical original Router VIEW adoption reads for the e0b4 profile.

The mixin scans both overloads of the shared collection adoption namespace and
reads immutable saved records and carriers. It does not call any current
eligibility, current selection, rendering, or finality method.
"""
from . import view_policy_adoption_types_v2 as t
from . import view_policy_adoption_wire_v2 as wire
from .canonical import hex_bytes, keccak256, uint
from .chain_abi import decode, encode
from .chain_rpc import quantity
from .independent_wire import ZERO, json_values, require
from .native_finality_wire import _topic

EVENT_V1 = keccak256(("ViewAdopted(uint16,uint256,bytes32,bytes32," + wire.RECORD_EVENT_ABI + ")").encode())
EVENT_V2 = keccak256(("ViewAdopted(uint16,bytes32,uint256,bytes32,bytes32," + wire.RECORD_EVENT_ABI + ")").encode())


class ViewPolicyAdoptionReads:
    """Requires ``a``, ``graph``, ``reader``, ``_one``, ``_read`` and ``_history``."""

    def _runtime_carrier(self, pointer, body, label):
        runtime = hex_bytes(self.reader.code(pointer))
        require(pointer != wire.ZERO_ADDRESS and runtime == b"\0" + body,
            "VIEW " + label + " runtime differs")
        return {"pointer": pointer, "codeHash": keccak256(runtime),
            "runtime": "0x" + runtime.hex()}

    def _pinned_runtime(self, address, expected, label):
        cache = getattr(self, "_view_adoption_runtime_cache", None)
        if cache is None:
            cache = self._view_adoption_runtime_cache = {}
        if address in cache:
            require(cache[address] == expected, "VIEW " + label + " runtime conflict")
            return
        raw = hex_bytes(self.reader.code(address))
        require(0 < len(raw) <= 24576 and keccak256(raw) == expected,
            "VIEW " + label + " runtime differs")
        cache[address] = expected

    def _declaration(self, record, profile, policy):
        graph = self.graph; source = record[1]; host = source[0][16][0]; key = record[0][2]
        self._pinned_runtime(host, source[0][16][1], "historical declaration host")
        manifest, receipt, original = self._read(host, "viewRecord(bytes32)",
            (t.VIEW_MANIFEST, t.VIEW_RECEIPT, t.COLLECTION_RECORD), ("bytes32",), (key,), maximum=16384)
        manifest_pointer, manifest_raw = self._read(host, "manifestPayload(bytes32)",
            ("address", "bytes"), ("bytes32",), (key,), maximum=16384)
        view_pointer, payload = self._read(host, "viewPayload(bytes32)",
            ("address", "bytes"), ("bytes32",), (key,), maximum=t.MAX_PAYLOAD + 128)
        count = self._one(host, "viewChunkCount(bytes32)", "uint256", ("bytes32",), (key,))
        require(0 < count <= t.MAX_CHUNKS and view_pointer == source[10][0],
            "VIEW original payload chunk count/pointer")
        chunks = []
        for index in range(count):
            digest, body = self._read(host, "viewChunk(bytes32,uint256)", ("bytes32", "bytes"),
                ("bytes32", "uint256"), (key, index), maximum=8320)
            require(digest == source[11][index], "VIEW original payload chunk hash")
            chunks.append(self._runtime_carrier(source[10][index], body, "payload chunk"))
        renderer = source[2][3]
        self._pinned_runtime(renderer, source[2][4], "historical renderer")
        targets, pins = self._read(renderer, "sourceBindings()", (("address",) * 4,
            ("bytes32",) * 4))
        if profile == t.V2_PROFILE:
            encoding, encoding_hash = self._read(renderer, "encodingBinding()",
                ("address", "bytes32"))
            saved_policy = self._one(renderer, "policyViewBinding()", t.POLICY_BINDING)
            require(saved_policy == policy, "VIEW original policy binding getter differs")
        else:
            encoding = encoding_hash = None
        renderer_manifest = self._one(renderer, "rendererManifest()", t.RENDERER_MANIFEST,
            maximum=4576)
        return {"manifest": json_values(manifest), "receipt": json_values(receipt),
            "record": json_values(original), "manifestPayload": "0x" + manifest_raw.hex(),
            "manifestCarrier": self._runtime_carrier(manifest_pointer, manifest_raw,
                "manifest carrier"), "viewPayload": "0x" + payload.hex(),
            "payloadChunks": chunks, "renderer": {"sourceTargets": json_values(targets),
                "sourcePins": json_values(pins), "encoding": encoding,
                "encodingRuntimeHash": encoding_hash, "manifest": json_values(renderer_manifest)}}

    def _adoption(self, selected_record_hash, scope):
        a, graph = self.a, self.graph
        chain, cid = uint(a["chainId"]), uint(a["collectionId"])
        scope = wire._scope(scope)
        require(scope[1] == cid and selected_record_hash != ZERO,
            "VIEW selected adoption identity")
        router = graph["router"]["address"]
        head = self._one(router, "viewAdoptionHead((uint8,uint256,uint256,bytes32))",
            "bytes32", (t.SCOPE,), (scope,))
        aggregate = self._one(router, "viewAdoptionAggregate(uint256)", t.AGGREGATE,
            ("uint256",), (cid,))
        history = self._history(router, [[EVENT_V1, EVENT_V2], _topic("uint256", cid)])
        logs = sorted(history["logs"], key=lambda row: tuple(quantity(row[key])
            for key in ("blockNumber", "transactionIndex", "logIndex")))
        require(0 < len(logs) <= t.MAX_HISTORY, "VIEW adoption event bound")
        rows = []
        for log in logs:
            require(log["address"] == router and len(log["topics"]) == 4
                and log["topics"][1] == _topic("uint256", cid),
                "VIEW adoption event address/topics")
            if log["topics"][0] == EVENT_V1:
                version, record = decode(("uint16", t.RECORD), hex_bytes(log["data"]), maximum=16384)
                profile = ZERO
            else:
                require(log["topics"][0] == EVENT_V2, "VIEW adoption event topic")
                version, profile, record = decode(("uint16", "bytes32", t.RECORD),
                    hex_bytes(log["data"]), maximum=16384)
            record_hash = log["topics"][3]
            require(version == (1 if profile == ZERO else 2) and profile in (ZERO, t.V2_PROFILE)
                and log["topics"][2] == wire.scope_subject(chain, graph["core"]["address"], record[0][0])
                and record_hash == record[3], "VIEW adoption event record/profile")
            getter_profile = self._one(router, "viewAdoptionProfile(bytes32)", "bytes32",
                ("bytes32",), (record_hash,))
            encoded = self._one(router, "viewAdoptionEncoded(bytes32)", "bytes",
                ("bytes32",), (record_hash,), maximum=8320)
            pointer, content_hash, size = self._read(router,
                "viewAdoptionCarrier(bytes32)", ("address", "bytes32", "uint32"),
                ("bytes32",), (record_hash,))
            # Preserve exact runtime without trusting the getter's pointer/hash/size assertion.
            carrier = self._runtime_carrier(pointer, encoded, "adoption record carrier")
            require(getter_profile == profile and content_hash == keccak256(encoded)
                and size == len(encoded) and encoded == encode((t.RECORD,), (record,)),
                "VIEW adoption getter/carrier differs")
            policy = None if profile == ZERO else self._one(record[1][2][3],
                "policyViewBinding()", t.POLICY_BINDING)
            declaration = self._declaration(record, profile, policy)
            block = str(quantity(log["blockNumber"])); timestamp = uint(history["blockTimestamps"][block], 64)
            event = (version, profile, cid, log["topics"][2], record_hash, record,
                quantity(log["blockNumber"]), log["blockHash"], log["transactionHash"],
                quantity(log["transactionIndex"]), quantity(log["logIndex"]), timestamp)
            rows.append({"profile": profile, "record": json_values(record),
                "encoded": "0x" + encoded.hex(), "carrier": carrier,
                "event": json_values(event), "declaration": declaration,
                "policyBinding": None if policy is None else json_values(policy)})
        serving = graph["serving"]["address"]
        serving_binding = self._one(serving, "binding()", wire.SERVING_BINDING)
        worker, worker_hash = self._read(serving, "workerBinding()", ("address", "bytes32"))
        configuration_hash = self._one(serving, "configurationHash()", "bytes32")
        value = {"version": "1", "chainId": str(chain), "router": router,
            "routerRuntimeHash": graph["router"]["runtimeHash"], "scope": json_values(scope),
            "selectedRecordHash": selected_record_hash, "head": head,
            "aggregate": json_values(aggregate), "history": rows,
            "serving": {"binding": json_values(serving_binding), "worker": worker,
                "workerRuntimeHash": worker_hash, "configurationHash": configuration_hash}}
        wire.validate(value, a, graph)
        return value

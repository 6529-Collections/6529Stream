"""Immutable original VIEW adoption and preservation Registry reads.

The mixin deliberately avoids current VIEW selection, ``requirePreservation``,
renderer output, and preservation-attribution output calls.  It retains the
complete tagged Router history and the original stored Registry admission.
"""
from . import view_policy_adoption_types_v2 as a_types
from . import view_policy_adoption_wire_v2 as a_wire
from . import view_preservation_adoption_types_v1 as t
from . import view_preservation_adoption_wire_v1 as wire
from .canonical import hex_bytes, keccak256, uint
from .chain_abi import decode, encode
from .chain_rpc import quantity
from .independent_wire import ZERO, json_values, require
from .native_finality_wire import _topic
from .view_policy_adoption_source_reads_v2 import ViewPolicyAdoptionReads, EVENT_V1, EVENT_V2


class ViewPreservationAdoptionReads(ViewPolicyAdoptionReads):
    """Requires ``a``, ``graph``, ``reader``, ``_one``, ``_read`` and ``_history``."""

    def _preservation_adoption(self, selected_record_hash, scope):
        a, graph = self.a, self.graph
        chain, cid = uint(a["chainId"]), uint(a["collectionId"])
        scope = a_wire._scope(scope)
        require(scope[1] == cid and selected_record_hash != ZERO,
            "VIEW preservation selected adoption identity")
        router = graph["router"]["address"]
        head = self._one(router, "viewAdoptionHead((uint8,uint256,uint256,bytes32))",
            "bytes32", (a_types.SCOPE,), (scope,))
        aggregate = self._one(router, "viewAdoptionAggregate(uint256)", a_types.AGGREGATE,
            ("uint256",), (cid,))
        history = self._history(router, [[EVENT_V1, EVENT_V2], _topic("uint256", cid)])
        logs = sorted(history["logs"], key=lambda row: tuple(quantity(row[key])
            for key in ("blockNumber", "transactionIndex", "logIndex")))
        require(0 < len(logs) <= a_types.MAX_HISTORY, "VIEW preservation adoption event bound")
        rows = []
        for log in logs:
            require(log["address"] == router and len(log["topics"]) == 4
                and log["topics"][1] == _topic("uint256", cid),
                "VIEW preservation adoption event address/topics")
            if log["topics"][0] == EVENT_V1:
                version, record = decode(("uint16", a_types.RECORD), hex_bytes(log["data"]),
                    maximum=16384)
                profile = ZERO
            else:
                require(log["topics"][0] == EVENT_V2, "VIEW preservation adoption event topic")
                version, profile, record = decode(("uint16", "bytes32", a_types.RECORD),
                    hex_bytes(log["data"]), maximum=16384)
            record_hash = log["topics"][3]
            require(version == (1 if profile == ZERO else 2)
                and profile in (ZERO, a_types.V2_PROFILE)
                and log["topics"][2] == a_wire.scope_subject(
                    chain, graph["core"]["address"], record[0][0])
                and record_hash == record[3], "VIEW preservation adoption event record/profile")
            getter_profile = self._one(router, "viewAdoptionProfile(bytes32)", "bytes32",
                ("bytes32",), (record_hash,))
            encoded = self._one(router, "viewAdoptionEncoded(bytes32)", "bytes",
                ("bytes32",), (record_hash,), maximum=8320)
            pointer, content_hash, size = self._read(router, "viewAdoptionCarrier(bytes32)",
                ("address", "bytes32", "uint32"), ("bytes32",), (record_hash,))
            carrier = self._runtime_carrier(pointer, encoded, "adoption record carrier")
            require(getter_profile == profile and content_hash == keccak256(encoded)
                and size == len(encoded) and encoded == encode((a_types.RECORD,), (record,)),
                "VIEW preservation adoption getter/carrier differs")
            policy = None if profile == ZERO else self._one(record[1][2][3],
                "policyViewBinding()", a_types.POLICY_BINDING)
            declaration = self._declaration(record, profile, policy)
            block = str(quantity(log["blockNumber"]))
            stamp = uint(history["blockTimestamps"][block], 64)
            event = (version, profile, cid, log["topics"][2], record_hash, record,
                quantity(log["blockNumber"]), log["blockHash"], log["transactionHash"],
                quantity(log["transactionIndex"]), quantity(log["logIndex"]), stamp)
            rows.append({"profile": profile, "record": json_values(record),
                "encoded": "0x" + encoded.hex(), "carrier": carrier,
                "event": json_values(event), "declaration": declaration,
                "policyBinding": None if policy is None else json_values(policy)})

        producer = graph["preservationRenderer"]["address"]
        attribution = graph["preservationAttribution"]["address"]
        self._pinned_runtime(producer, graph["preservationRenderer"]["runtimeHash"],
            "preservation producer")
        self._pinned_runtime(attribution, graph["preservationAttribution"]["runtimeHash"],
            "preservation attribution")
        configuration = self._one(producer, "configuration()", t.CONFIGURATION)
        configuration_hash = self._one(producer, "configurationHash()", "bytes32")
        worker, worker_hash = self._read(producer, "workerBinding()", ("address", "bytes32"))
        encoding, encoding_hash = self._read(producer, "encodingBinding()", ("address", "bytes32"))
        binding = self._one(producer, "preservationViewBinding(bytes32)", t.BINDING,
            ("bytes32",), (selected_record_hash,))
        profile = self._one(producer, "preservationProfile()", "bytes32")
        require(profile == t.OUTPUT_PROFILE, "VIEW preservation producer profile differs")
        attribution_row = {"core": self._one(attribution, "core()", "address"),
            "router": self._one(attribution, "router()", "address"),
            "profile": self._one(attribution, "preservationAttributionProfile()", "bytes32"),
            "liveAttribution": self._one(attribution, "liveAttribution()", "address"),
            "liveAttributionRuntimeHash": self._one(attribution,
                "liveAttributionCodeHash()", "bytes32")}
        registry_address = rows[[row["record"][3] for row in rows].index(selected_record_hash)][
            "record"][1][2][0]
        registry_hash = rows[[row["record"][3] for row in rows].index(selected_record_hash)][
            "record"][1][2][1]
        self._pinned_runtime(registry_address, registry_hash, "preservation Registry")
        selected = a_wire._v(a_types.RECORD,
            rows[[row["record"][3] for row in rows].index(selected_record_hash)]["record"])
        version_key = selected[1][2][2]
        key = wire.preservation_key(version_key, producer)
        version = self._one(registry_address, "version(bytes32)", t.VERSION,
            ("bytes32",), (version_key,))
        original_reads = self._one(registry_address, "reads(bytes32)", t.READS,
            ("bytes32",), (version_key,), maximum=16448)
        record = self._one(registry_address, "preservationRecord(bytes32)",
            t.PRESERVATION_RECORD, ("bytes32",), (key,), maximum=2048)
        reads = self._one(registry_address, "preservationReads(bytes32)", t.READS,
            ("bytes32",), (key,), maximum=16448)
        count = self._one(registry_address, "targetCount()", "uint256")
        require(0 < count <= t.MAX_TARGETS, "VIEW preservation Registry target bound")
        targets = [self._one(registry_address, "targetAt(uint256)", t.TARGET,
            ("uint256",), (index,)) for index in range(count)]
        for item in reads:
            require(item[0] < len(targets), "VIEW preservation Registry target index")
            target = targets[item[0]]
            self._pinned_runtime(target[0], target[1], "Registry declared target")
        registry = {"deploymentChainId": str(self._one(registry_address,
            "deploymentChainId()", "uint256")),
            "schemaRegistry": self._one(registry_address, "schemaRegistry()", "address"),
            "schemaRegistryCodeHash": self._one(registry_address,
                "schemaRegistryCodeHash()", "bytes32"),
            "targetSetHash": self._one(registry_address, "targetSetHash()", "bytes32"),
            "version": json_values(version), "originalReads": json_values(original_reads),
            "record": json_values(record), "reads": json_values(reads),
            "targets": json_values(targets)}
        producer_binding = record[0][1]
        admission = (registry_address, registry_hash, version_key, *record[1:5])
        value = {"version": "1", "chainId": str(chain), "router": router,
            "routerRuntimeHash": graph["router"]["runtimeHash"], "scope": json_values(scope),
            "selectedRecordHash": selected_record_hash, "head": head,
            "aggregate": json_values(aggregate), "history": rows,
            "preservation": {"configuration": json_values(configuration),
                "configurationHash": configuration_hash, "worker": worker,
                "workerRuntimeHash": worker_hash, "encoding": encoding,
                "encodingRuntimeHash": encoding_hash, "binding": json_values(binding),
                "producerBinding": json_values(producer_binding),
                "admission": json_values(admission), "attribution": attribution_row,
                "registry": registry}}
        wire.validate(value, a, graph)
        return value

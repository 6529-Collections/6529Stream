"""One synthetic RPC map for original VIEW preservation snapshot and content-root evidence.

These response maps exercise the public source and exact replay. They do not
execute a renderer, prove native deployment or authenticate historical authority.
"""
from copy import deepcopy

from .canonical import dumps, hex_bytes, keccak256, loads, schema_id
from .chain_abi import calldata, encode
from .independent_wire import RAW_BYTES, ZERO
from .test_public_chain_history import PublicHistoryFixture
from .test_current_rights_source import A


class ViewPreservationFixtureV1(PublicHistoryFixture):
    """Immutable originals and later observations share complete headers/receipts."""

    def __init__(self, *, count=3, mode="disabled", burned=False, later_burn=False, later_adoption=False):
        from . import native_view_preservation_wire_v1 as wire
        from . import public_view_preservation_source_v1 as source
        from . import view_policy_membership_v2 as membership
        from . import view_preservation_adoption_wire_v1 as adoption
        from .test_view_policy_membership_v2 import supplied as members, install_membership_reads
        from .test_view_preservation_adoption_wire_v1 import (
            supplied as adopted, install_preservation_adoption_reads)
        from .test_view_preservation_output_wire_v1 import supplied as output, install_output_reads
        from .test_view_preservation_snapshot_wire_v1 import supplied as snapshot, install_snapshot_reads
        from .test_view_preservation_root_wire_v1 import supplied as root, install_root_reads
        super().__init__(end=40)
        self.anchor.update(chainId="31337", timestamp="140")
        self.codes, self.pins, self.responses = {}, {}, {}
        self.graph = {}
        for index, role in enumerate(wire.GRAPH_KEYS):
            address = A(73000 + index)
            runtime = ("synthetic VIEW " + role).encode()
            self.codes[address] = runtime
            self.pins[address] = keccak256(runtime)
            self.graph[role] = {"address": address, "runtimeHash": self.pins[address]}
        self.context = {**self.anchor, "environment": "local_evm_fixture",
            "deploymentEvidenceHash": schema_id("synthetic e8a VIEW preservation deployment artifact"),
            "core": self.graph["core"]["address"], "collectionId": "1", "tokenId": "41"}
        self.member_value, _, _, self.binding = members(count, modes=(mode,),
            context=self.context, graph=self.graph, recorded_at=101)
        if burned or later_burn:
            self.member_value["membership"]["identities"][0][3] = True
            self.member_value["membership"]["lifecycles"][0] = "3"
        self.adoption_value, _, _ = adopted(context=self.context, graph=self.graph,
            policy_binding=self.binding, adopted_at=103, later_head=later_adoption, later_adopted_at=110)
        adoption_result = adoption.validate(self.adoption_value, self.context, self.graph)
        member_result = membership.validate(self.member_value, self.context, self.graph, self.binding)
        combined = {**adoption_result, "tokenIds": member_result["tokenIds"], "policies": member_result["policies"]}
        self.output_value, _, _, _ = output(count, mode=mode, burned=burned,
            context=self.context, graph=self.graph, adoption=combined,
            serving_configuration_hash=adoption_result["preservation"]["configurationHash"], coverage_timestamp=106)
        self.snapshot_value, _, _ = snapshot(context=self.context, graph=self.graph,
            adoption=combined, membership=member_result, output_value=self.output_value,
            recorded_at=107, locked=True)
        self.root_value, _, _, _, _ = root(context=self.context, graph=self.graph,
            snapshot_value=self.snapshot_value, output_value=self.output_value, published_at=109)
        self.bundle = {"scope": deepcopy(self.binding[7]), "adoption": self.adoption_value,
            "membership": self.member_value, "output": self.output_value,
            "snapshot": self.snapshot_value, "root": self.root_value}
        wire.validate_bundle(self.bundle, self.context, self.graph)
        install_membership_reads(self, self.member_value, self.context, self.graph, self.binding)
        install_preservation_adoption_reads(self, self.adoption_value, self.context, self.graph)
        install_output_reads(self, self.output_value, self.context, self.graph)
        install_snapshot_reads(self, self.snapshot_value, self.context, self.graph)
        install_root_reads(self, self.root_value, self.context, self.graph)
        self._definitions(wire.definitions())
        self._events()
        for role, getter, target in (("schemas", "chunkStore()", "store"),
                ("coverage", "core()", "core"), ("coverage", "schemaRegistry()", "schemas")):
            self.add(self.graph[role]["address"], getter, (), (), ("address",), (self.graph[target]["address"],))
        self.view_anchor = {**self.context, **{key: row["address"] for key, row in self.graph.items()},
            "profile": source.PROFILE, "scope": deepcopy(self.bundle["scope"]),
            "checkpointId": self.output_value["checkpoint"]["id"],
            "manifestRecordHash": self.output_value["manifest"]["recordHash"],
            "snapshotRecordHash": self.snapshot_value["selectedRecordHash"],
            "rootRecordHash": self.root_value["selectedRecordHash"],
            "codePins": [{"address": address, "runtimeHash": self.pins[address]}
                for address in sorted({row["address"] for row in self.graph.values()})],
            "runtimeAdmission": {"sourceCommit": wire.SOURCE_REVISION, "kind": "synthetic_fixture",
                "artifactHash": self.context["deploymentEvidenceHash"]}}

    def header(self, number):
        header = super().header(number)
        header["timestamp"] = hex(100 + number)
        return header

    def add(self, target, signature, inputs, arguments, outputs, values):
        key = target, calldata(signature, inputs, arguments)
        raw = "0x" + encode(outputs, values).hex()
        if key in self.responses and self.responses[key] != raw:
            raise AssertionError("contradictory synthetic VIEW read: " + signature)
        self.responses[key] = raw

    def _chunk(self, raw):
        digest = keccak256(raw)
        runtime = b"\0" + raw
        pointer = "0x" + keccak256(runtime)[-40:]
        if pointer in self.codes and self.codes[pointer] != runtime:
            raise AssertionError("synthetic VIEW Store pointer collision")
        self.codes[pointer] = runtime
        self.pins[pointer] = keccak256(runtime)
        self.add(self.graph["store"]["address"], "chunk(bytes32)", ("bytes32",), (digest,),
            ("address", "uint32"), (pointer, len(raw)))
        return digest

    def _definitions(self, definitions):
        from .current_rights_source import DOCUMENT_FACTS
        for row in definitions:
            raw = row["bytes"]
            hashes = [self._chunk(raw[index:index+8192]) for index in range(0, len(raw), 8192)]
            facts = (True, row["kind"], 1, row["hash"], RAW_BYTES, ZERO, len(raw),
                len(hashes), schema_id("synthetic VIEW definition sequence"))
            self.add(self.graph["schemas"]["address"], "documentFacts(bytes32)",
                ("bytes32",), (row["id"],), (DOCUMENT_FACTS,), (facts,))
            for index, digest in enumerate(hashes):
                self.add(self.graph["schemas"]["address"], "documentChunkHashAt(bytes32,uint256)",
                    ("bytes32", "uint256"), (row["id"], index), ("bytes32",), (digest,))

    def _events(self):
        """Original publication steps are placed before their actual consumers."""
        from . import native_view_preservation_wire_v1 as wire
        descriptors = list(wire.expected_events(self.bundle, self.context, self.graph))
        self.event_descriptors = descriptors
        self.view_events = []
        priorities = {kind: index for index, kind in enumerate((
            "membership_recorded", "membership_admitted", "membership_progressed", "membership_sealed",
            "source_set_prepared", "view_adopted", "view_checkpoint_started", "view_checkpoint_appended",
            "view_checkpoint_sealed", "view_coverage_completed", "view_part_prepared", "view_manifest_started",
            "view_manifest_advanced", "view_manifest_verified", "preservation_registered",
            "view_snapshot_published", "view_snapshot_locked", "view_root_published", "view_root_binding_published"))}
        adoptions = {row["record"][3]: row for row in self.adoption_value["history"]}
        snapshots = {row["receipt"][0]: row for row in self.snapshot_value["history"]}
        roots = {row["recordHash"]: row for row in self.root_value["history"]}
        priorities["view_root_binding_published"] = priorities["view_root_published"]
        def block(descriptor):
            kind = descriptor["kind"]
            if kind.startswith("membership_"): return 1
            if kind == "source_set_prepared": return 2
            if kind == "view_adopted": return int(adoptions[descriptor["topics"][3]]["record"][10]) - 100
            if kind.startswith("view_checkpoint_"): return 5
            if kind == "preservation_registered": return 4
            if kind == "view_snapshot_published": return int(snapshots[descriptor["topics"][3]]["receipt"][13]) - 100
            if kind == "view_snapshot_locked": return int(self.snapshot_value["lock"][3]) - 100
            if kind in ("view_root_published", "view_root_binding_published"):
                return int(roots[descriptor["topics"][3]]["record"][17]) - 100
            return 6
        ordered = sorted(enumerate(descriptors), key=lambda item: (block(item[1]), priorities[item[1]["kind"]], item[0]))
        for _, descriptor in ordered:
            number = block(descriptor)
            topics = [topic if topic is not None else schema_id("synthetic VIEW coverage plan " + descriptor["topics"][1])
                for topic in descriptor["topics"]]
            log = PublicHistoryFixture.add(self, number, address=descriptor["address"], topics=topics,
                same_transaction=bool(self.header(number)["transactions"]))
            log["data"] = descriptor["data"]
            stamp = str(100 + number)
            self.view_events.append({"log": log, "timestamp": stamp})
            if descriptor["kind"] == "view_adopted":
                row = adoptions[descriptor["topics"][3]]
                row["event"][6:] = [str(number), log["blockHash"], log["transactionHash"],
                    str(int(log["transactionIndex"], 16)), str(int(log["logIndex"], 16)), stamp]
        wire.validate_bundle(self.bundle, self.context, self.graph)
        wire.validate_event_join(self.bundle, self.context, self.graph, self.view_events)

    def request(self, method, params):
        if method == "eth_call":
            self.calls.append((method, deepcopy(params)))
            if params[1] != {"blockHash": self.anchor["blockHash"], "requireCanonical": True}:
                raise AssertionError("synthetic VIEW call block differs")
            return self.responses[(params[0]["to"], params[0]["data"])]
        if method == "eth_getCode":
            self.calls.append((method, deepcopy(params)))
            if params[1] != {"blockHash": self.anchor["blockHash"], "requireCanonical": True}:
                raise AssertionError("synthetic VIEW code block differs")
            return "0x" + self.codes[params[0]].hex()
        return super().request(method, params)

    def source(self):
        from .public_view_preservation_source_v1 import PublicViewPreservationSource
        return PublicViewPreservationSource(dumps(self.view_anchor), self)

    def result(self):
        from .public_view_preservation_source_v1 import MAX_OUTPUT
        return loads(self.source().snapshot(), maximum=MAX_OUTPUT)

    def capture(self):
        from . import public_view_preservation_capture_v1 as capture
        from .public_view_preservation_source_v1 import PROFILE_HASH
        source = self.source()
        return capture._assemble(source, keccak256(source.anchor_bytes), PROFILE_HASH)

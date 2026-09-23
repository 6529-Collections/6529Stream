"""Coherent synthetic scoped policy V2 graph and publication evidence.

The fixture is deliberately explicit synthetic evidence.  It constructs the
new graph before any inherited package is requested and never substitutes the
factory's current-eligibility reads for its stored original graph.
"""
from copy import deepcopy

from . import native_finality_wire as neutral
from . import native_scoped_policy_finality_wire_v2 as wire
from . import scoped_policy_content_wire_v2 as content_wire
from . import scoped_policy_factory_v2 as factory_wire
from . import scoped_policy_preservation_wire_v2 as preservation_wire
from .canonical import dumps, hex_bytes, keccak256, loads, schema_id
from .chain_abi import Array, calldata, decode, encode
from .independent_wire import ZERO, ZERO_ADDRESS, json_values
from .scoped_policy_preservation_types_v2 import POLICY_DEPS, SNAPSHOT_RECEIPT, REFERENCE_RECEIPT
from .scoped_static_types import SELECTION_PLAN
from .test_current_rights_source import A, H
from .test_scoped_policy_content_wire_v2 import (
    supplied as content_supplied, rebuild as rebuild_content, reseal_roots)
from .test_scoped_policy_factory_v2 import supplied as factory_supplied
from .test_scoped_policy_preservation_wire_v2 import (
    supplied as preservation_supplied, seal_snapshot, seal_reference)
from .test_scoped_static_snapshot_wire import supplied as membership_supplied
from .title_v5_fixture import TitleV5Fixture, TOKEN


class ScopedPolicyFinalityFixtureV2(TitleV5Fixture):
    """TOKEN, RELEASE or SEASON scoped-policy V2 fixture on one RPC map."""

    def __init__(self, *, scope_type=1, count=None, burned=False):
        if scope_type not in (1, 2, 3):
            raise ValueError("unsupported scoped policy fixture scope")
        count = (1 if scope_type == 1 else 3) if count is None else count
        if not 1 <= count <= wire.MAX_OUTPUTS or (scope_type == 1 and count != 1):
            raise ValueError("scoped policy fixture member count")
        super().__init__(burned=burned)
        addresses = {key: A(68000 + index) for index, key in enumerate(wire.GRAPH_KEYS)}
        addresses.update(core=self.core, metadata=self.a["host"], router=self.configuration[0][7],
            artist=self.registry, finality=A(6), provider=A(7), schemas=A(3), store=A(4),
            executor=self.floor_executor)
        for key, address in addresses.items():
            if address not in self.codes:
                self.codes[address] = ("synthetic e0b4 scoped policy " + key).encode("ascii")
                self.pins[address] = keccak256(self.codes[address])
        self.scoped_policy_addresses = addresses
        self.scoped_policy_graph = {key: {"address": address, "runtimeHash": self.pins[address]}
            for key, address in addresses.items()}
        self.scoped_policy_context = {key: self.a[key] for key in ("chainId", "core",
            "collectionId", "blockHash", "blockNumber", "timestamp", "stateRoot",
            "environment", "deploymentEvidenceHash")} | {"tokenId": str(TOKEN)}
        self.policy_addresses = self.scoped_policy_addresses
        self.policy_graph = self.scoped_policy_graph
        self.policy_context = self.scoped_policy_context
        self._build_pure(scope_type, count)
        self._install_source_map()

    def _build_pure(self, scope_type, count):
        x, g = self.scoped_policy_context, self.scoped_policy_graph
        stamp = int(self.blocks[H(203)]["timestamp"], 16)
        artist = (True, self.registry, self.pins[self.registry], self.artist_id, 1,
            schema_id("synthetic scoped policy binding"), A(93),
            schema_id("synthetic scoped policy identity"),
            schema_id("synthetic scoped policy acceptance"), 100, 110,
            schema_id("synthetic scoped policy Artist snapshot"))
        membership_graph = {**g, "staticContent": g["policyContent"],
            "scopedSnapshot": g["policySnapshot"]}
        membership_bundle, _, _, _ = membership_supplied(scope_type, count,
            context=x, graph=membership_graph, artist=artist,
            recorded_at=stamp, locked_at=stamp)
        membership = membership_bundle["membership"]
        for index, identity in enumerate(membership["identities"]):
            identity[2] = str(3 + index)
        membership["identities"][0][3] = self.title_burned
        membership["lifecycles"][0] = "3" if self.title_burned else "2"
        if membership["publication"] is not None:
            membership["publication"][7][3] = str(stamp)
        self.scoped_policy_membership = membership
        preservation, _, _, _, _ = preservation_supplied(count, mode="disabled",
            scope_type=scope_type, context=x, graph=g, artist=artist,
            membership=membership)
        preservation["snapshot"]["publication"][8] = str(stamp)
        preservation["snapshot"]["receipt"][13] = str(stamp)
        preservation["snapshot"]["lock"][3] = str(stamp)
        preservation["reference"]["publication"][1][10] = str(stamp)
        preservation["reference"]["receipt"][1][14:16] = [str(stamp), str(stamp)]
        preservation["reference"]["lock"][3] = str(stamp)
        source = preservation["snapshot"]["source"]
        facts, entropy = source[1], source[9]
        self.scoped_policy_preservation = preservation
        self.scoped_policy_factory = self._factory_value(source[0], None, artist)
        from .scoped_policy_finality_fixture_provider_v2 import provider_evidence
        provider = provider_evidence(x, g, self.scoped_policy_factory, fixture=self)
        from .policy_finality_fixture_v2 import _static_originals
        adapters = [{key: row[key] for key in ("family", "address", "runtimeHash")}
            for row in provider["adapters"][:6]]
        static_plan, static_rows, originals = _static_originals(x, g, artist, count,
            adapters, entropy[5][0][0], entropy[5][0][1])
        static_plan = (source[0], facts[5], *static_plan[2:])
        selection_id = preservation_wire.selection_id(
            neutral.from_json(SELECTION_PLAN, static_plan), x, g)
        content, _, _, statement = content_supplied(count, scope_type=scope_type,
            scope_id=source[0][3], context=x, graph=g, artist_id=self.artist_id,
            root_timestamp=stamp, selection_id=selection_id,
            selection_plan=static_plan, selection_rows=static_rows)
        # Join the complete scoped selection to the exact original membership
        # and immutable entropy policy commitments retained by the snapshot.
        content["checkpoint"]["selectionPlan"][1] = facts[5]
        selected_plan = neutral.from_json(SELECTION_PLAN, content["checkpoint"]["selectionPlan"])
        content["checkpoint"]["plan"][0] = preservation_wire.selection_id(selected_plan, x, g)
        content["checkpoint"]["factoryDependencies"] = deepcopy(
            preservation["snapshot"]["entropyDependencies"])
        content["checkpoint"]["plan"][2:4] = entropy[1:3]
        policy = entropy[5][0]
        native = policy[14]
        readiness = [policy[0], policy[1], policy[8], "1", str(native[3]),
            str(native[4]), str(native[5]), True, False, ZERO]
        for selected, output in zip(content["checkpoint"]["selectionRows"],
                                    content["checkpoint"]["outputs"]):
            selected[6][3], selected[7][3] = policy[0], policy[1]
            output[4] = deepcopy(readiness)
            output[5] = schema_id("synthetic scoped terminal admission " + str(output[0][0]))
        captures = preservation["reference"]["publication"][1][7]
        samples = preservation["reference"]["source"][7]
        for capture, sample in zip(captures, samples):
            ordinal = int(sample[0]); output = content["checkpoint"]["outputs"][ordinal]
            output[0][0] = capture[0]; output[0][1] = capture[2]
            output[0][3] = capture[3]; output[0][5] = sample[1][4]
            output[3] = capture[3]
        rebuild_content(content, x, g, statement)
        result = content_wire.validate(content, x, g, statement)
        for capture, sample in zip(captures, samples):
            ordinal = int(sample[0])
            sample[2] = deepcopy(result["selectionRows"][ordinal])
            sample[3] = deepcopy(result["outputs"][ordinal][4])
            sample[4] = result["outputs"][ordinal][5]
            capture[1] = sample[1][1] = str(3 + ordinal)
        source[3:6] = [result["selectionPlan"], result["contentPlan"], result["outputManifest"]]
        preservation["snapshot"]["publication"][4:6] = [result["manifestRecordHash"], entropy[0]]
        seal_snapshot(preservation["snapshot"], x, g)
        receipt = neutral.from_json(SNAPSHOT_RECEIPT, preservation["snapshot"]["receipt"])
        root = content["roots"]["history"][0]["record"]
        root[0][2:4] = [receipt[0], str(receipt[3])]
        root[3:5] = [receipt[5], receipt[7]]
        root[8:11] = [artist[3], str(artist[4]), artist[5]]
        statement[5] = receipt[5]
        statement[7][1] = receipt[0]
        reseal_roots(content, x, g, statement)
        result = content_wire.validate(content, x, g, statement)
        preservation["reference"]["source"][3:6] = [result["selectedRootHash"],
            result["selectedRoot"], result["selectedBinding"]]
        seal_reference(preservation["reference"], preservation["snapshot"], x, g)
        # Revalidate after the complete content substitution.  This is the
        # source of the immutable snapshot/reference facts later read by RPC.
        preserved = preservation_wire.validate(preservation, x, g, None, result)
        self.scoped_policy_content = content
        self.scoped_policy_preservation = preservation
        self.scoped_policy_statement = statement
        self.scoped_policy_content_result = result
        self.scoped_policy_preservation_result = preserved
        self.scoped_policy_provider = provider
        self._complete_bundle(artist, adapters, originals)

    def _factory_value(self, scope, content, artist):
        """Rebind the independent exact factory vector to this fixture graph."""
        value = factory_supplied()
        r = neutral.from_json(factory_wire.RECIPE, value["recipe"])
        d = list(r[0]); targets, hashes = list(d[0]), list(d[1])
        provider_map = ((0, "core"), (1, "metadata"), (2, "schemas"), (3, "store"),
            (4, "router"), (7, "work"), (8, "rights"), (9, "conservation"),
            (10, "artifacts"), (11, "externalCoverage"))
        for index, role in provider_map:
            targets[index], hashes[index] = (self.scoped_policy_graph[role][key]
                for key in ("address", "runtimeHash"))
        d[0], d[1] = tuple(targets), tuple(hashes)
        artists = [ZERO_ADDRESS] * 5; artist_hashes = [ZERO] * 5
        artists[0], artist_hashes[0] = self.registry, self.pins[self.registry]
        # The original factory recipe requires a complete five-role Artist
        # suite. Synthetic retained roles remain distinct and runtime pinned.
        for index in range(1, 5):
            role = A(68900 + index)
            self.codes[role] = ("synthetic scoped Artist role " + str(index)).encode("ascii")
            self.pins[role] = keccak256(self.codes[role])
            artists[index], artist_hashes[index] = role, self.pins[role]
        owner = A(68910); owner_code = b"synthetic scoped Artist content owner"
        self.codes[owner] = owner_code; self.pins[owner] = keccak256(owner_code)
        d[2], d[3], d[4], d[5] = tuple(artists), tuple(artist_hashes), owner, self.pins[owner]
        fixed = (self.scoped_policy_graph["scopeMembership"]["address"],
            self.scoped_policy_graph["staticSelection"]["address"],
            self.scoped_policy_graph["sourceFactory"]["address"],
            self.scoped_policy_graph["executor"]["address"])
        fixed_hashes = tuple(self.scoped_policy_graph[k]["runtimeHash"] for k in
            ("scopeMembership", "staticSelection", "sourceFactory", "executor"))
        recipe = (tuple(d), fixed, fixed_hashes, *r[3:])
        dependencies = neutral.from_json(POLICY_DEPS,
            self.scoped_policy_preservation["snapshot"]["entropyDependencies"])
        factory = self.scoped_policy_graph["publicationFactory"]["address"]
        graph = [scope, self.scoped_policy_preservation["snapshot"]["source"][9][0],
            self.scoped_policy_graph["entropySourceSet"]["address"],
            self.scoped_policy_graph["entropySourceSet"]["runtimeHash"], ZERO,
            tuple(self.scoped_policy_graph[k]["address"] for k in factory_wire.CHILDREN),
            tuple(self.scoped_policy_graph[k]["runtimeHash"] for k in factory_wire.CHILDREN), 7]
        recipe_digest = factory_wire.recipe_hash(self.scoped_policy_context["chainId"], recipe)
        dependencies_digest = factory_wire.dependencies_hash(dependencies)
        graph[4] = factory_wire.graph_id(self.scoped_policy_context["chainId"], factory,
            recipe_digest, dependencies_digest, graph)
        events = [{"graphId": graph[4], "inventoryPlan": graph[1], "childIndex": str(index),
            "child": graph[5][index], "codeHash": graph[6][index]} for index in range(7)]
        value = {"profile": factory_wire.PROFILE, "chainId": self.scoped_policy_context["chainId"],
            "factory": factory, "factoryRuntimeHash": self.scoped_policy_graph["publicationFactory"]["runtimeHash"],
            "recipe": json_values(recipe), "recipeHash": recipe_digest,
            "sourceFactoryDependencies": json_values(dependencies),
            "sourceFactoryDependenciesHash": dependencies_digest, "graph": json_values(graph),
            "preparationEvents": events, "childDependencies": factory_wire.child_dependencies(recipe, graph)}
        factory_wire.validate(value, self.scoped_policy_context, self.scoped_policy_graph, scope)
        return value

    def _complete_bundle(self, artist, adapters, originals):
        """Join STATIC originals and form the exact scoped finality statement."""
        from . import scoped_policy_static_components_v2 as static_wire
        from .policy_finality_fixture_v2 import _component_expectations

        x, g = self.policy_context, self.policy_graph
        result, preserved = self.scoped_policy_content_result, self.scoped_policy_preservation_result
        snap = neutral.from_json(SNAPSHOT_RECEIPT,
            self.scoped_policy_preservation["snapshot"]["receipt"])
        ref = neutral.from_json(REFERENCE_RECEIPT,
            self.scoped_policy_preservation["reference"]["receipt"])
        plan = result["selectionPlan"]
        authenticated = (plan[0], snap[15], result["contentPlan"][0], plan[1],
            plan[5], plan[3], artist[11])
        modules = self.scoped_policy_provider["moduleIdentities"]
        metadata = self.scoped_policy_provider["adapters"][6]
        entropy = preserved["componentCommitments"]["entropy"]
        reference = preserved["componentCommitments"]["reference"]
        other = (
            (schema_id("ENTROPY_COORDINATOR"), g["entropySourceSet"]["address"],
                wire.COMPONENT_INTERFACE, g["entropySourceSet"]["runtimeHash"],
                entropy["moduleVersion"], entropy["manifestHash"], entropy["dataHash"]),
            (schema_id("REFERENCE_RENDER"), g["policyReference"]["address"],
                wire.COMPONENT_INTERFACE, g["policyReference"]["runtimeHash"],
                reference["moduleVersion"], reference["manifestHash"], reference["dataHash"]),
            (metadata["family"], metadata["address"], wire.COMPONENT_INTERFACE,
                metadata["runtimeHash"], modules["metadata"][0], modules["metadata"][1],
                schema_id("synthetic scoped collection metadata data")))
        components, probe = _component_expectations(x, g, json_values(authenticated),
            plan, result["selectionRows"], originals, json_values(artist), adapters,
            modules["router"][0], modules["router"][1], other)
        components = tuple((*row[:2], wire.COMPONENT_INTERFACE, *row[3:])
            for row in components)
        probe.update(authenticated=json_values(authenticated), plan=result["selectionPlan"],
            rows=result["selectionRows"], originals=originals,
            artistPresentation=json_values(artist), componentExpectations=json_values(components))
        static_wire.validate(probe)
        statement = list(self.scoped_policy_statement)
        statement[5:7] = [snap[5], ref[1][6]]
        statement[7][0:3] = [result["selectedRootHash"], snap[0], ref[1][0]]
        statement[7][3] = ZERO
        statement[8] = json_values(components)
        self.scoped_policy_statement = statement
        self.policy_statement = statement
        self.policy_bundle = {"scope": deepcopy(statement[0]),
            "factory": deepcopy(self.scoped_policy_factory),
            "provider": deepcopy(self.scoped_policy_provider),
            "content": deepcopy(self.scoped_policy_content),
            "snapshot": deepcopy(self.scoped_policy_preservation["snapshot"]),
            "reference": deepcopy(self.scoped_policy_preservation["reference"]),
            "membership": deepcopy(self.scoped_policy_membership),
            "staticComponents": probe}

        from .scoped_policy_finality_fixture_reads_v2 import seal_execution
        self.policy_transactions = {}
        seal_execution(self, self.policy_bundle, x, g, statement)
        wire.validate_bundle(self.policy_bundle, x, g)
        self.policy_bundle = loads(dumps(self.policy_bundle), maximum=64 * 1024 * 1024)

    def pure_bundle(self):
        return {"content": deepcopy(self.scoped_policy_content),
            "snapshot": deepcopy(self.scoped_policy_preservation["snapshot"]),
            "reference": deepcopy(self.scoped_policy_preservation["reference"]),
            "factory": deepcopy(self.scoped_policy_factory),
            "statement": deepcopy(self.scoped_policy_statement)}

    @staticmethod
    def _source_module():
        from . import public_scoped_policy_finality_source_v2 as source
        return source

    def _store_chunk(self, raw):
        digest = self.chunk(raw)
        pointer, length = decode(("address", "uint32"), hex_bytes(
            self.responses[(self.policy_addresses["store"],
                calldata("chunk(bytes32)", ("bytes32",), (digest,)))]))
        assert length == len(raw)
        return pointer

    def _relocate_carriers(self):
        member = self.policy_bundle["membership"]
        for row in (*member["parts"], *self.policy_bundle["content"]["manifest"]["chunks"]):
            row["pointer"] = self._store_chunk(hex_bytes(row["runtime"])[1:])
        if member["publication"] is not None:
            member["publication"][4] = self._store_chunk(hex_bytes(member["manifestBytes"]))

    def _install_definitions(self):
        from .current_rights_source import DOCUMENT_FACTS
        for definition in wire.definitions():
            raw = definition["bytes"]
            parts = [raw[index:index + 8192] for index in range(0, len(raw), 8192)]
            digests = [self.chunk(part) for part in parts]
            facts = (True, definition["kind"], 0, definition["hash"],
                schema_id("RAW_BYTES"), ZERO, len(raw), len(parts),
                schema_id("synthetic scoped policy definition " + definition["name"]))
            self.add(self.policy_addresses["schemas"], "documentFacts(bytes32)",
                ("bytes32",), (definition["id"],), (DOCUMENT_FACTS,), (facts,))
            for index, digest in enumerate(digests):
                self.add(self.policy_addresses["schemas"],
                    "documentChunkHashAt(bytes32,uint256)", ("bytes32", "uint256"),
                    (definition["id"], index), ("bytes32",), (digest,))

    def _install_factory_reads(self):
        value, a = self.policy_bundle["factory"], self.policy_addresses
        recipe = neutral.from_json(factory_wire.RECIPE, value["recipe"])
        graph = neutral.from_json(factory_wire.GRAPH, value["graph"])
        def put(target, signature, outputs, values, inputs=(), arguments=()):
            self.add(target, signature, inputs, arguments, outputs, values)
        host = value["factory"]
        put(host, "scopedPolicyPublicationFactoryProfile()", ("bytes32",), (factory_wire.PROFILE,))
        put(host, "recipe()", (factory_wire.RECIPE,), (recipe,))
        put(host, "graphForPlan(bytes32)", (factory_wire.GRAPH,), (graph,),
            ("bytes32",), (graph[1],))
        for signature, output, result in (("recipeHash()", "bytes32", value["recipeHash"]),
                ("sourceFactoryDependenciesHash()", "bytes32", value["sourceFactoryDependenciesHash"]),
                ("core()", "address", recipe[0][0][0]),
                ("metadataHost()", "address", recipe[0][0][1]),
                ("entropySourceFactory()", "address", a["sourceFactory"])):
            put(host, signature, (output,), (result,))
        dependencies = neutral.from_json(POLICY_DEPS, value["sourceFactoryDependencies"])
        put(a["sourceFactory"], "scopedPolicyFactoryProfile()", ("bytes32",),
            (factory_wire.SOURCE_FACTORY_PROFILE,))
        put(a["sourceFactory"], "dependencies()", (POLICY_DEPS,), (dependencies,))
        source_set = graph[2]
        for signature, output, result in (("factory()", "address", a["sourceFactory"]),
                ("core()", "address", recipe[0][0][0]),
                ("inventoryPlan()", "bytes32", graph[1]),
                ("SOURCE_SET_PROFILE()", "bytes32",
                    schema_id("6529STREAM_ENTROPY_POLICY_SOURCE_SET_V2"))):
            put(source_set, signature, (output,), (result,))
        snapshot = neutral.from_json(SNAPSHOT_RECEIPT,
            self.policy_bundle["snapshot"]["receipt"])
        reference = neutral.from_json(REFERENCE_RECEIPT,
            self.policy_bundle["reference"]["receipt"])
        put(graph[5][3], "dependencies()", (factory_wire.SNAPSHOT_DEPS,),
            (neutral.from_json(factory_wire.SNAPSHOT_DEPS,
                self.policy_bundle["snapshot"]["dependencies"]),))
        put(graph[5][4], "dependencies()", (factory_wire.REFERENCE_DEPS,),
            (neutral.from_json(factory_wire.REFERENCE_DEPS,
                self.policy_bundle["reference"]["dependencies"]),))
        put(graph[5][5], "dependencyHash()", ("bytes32",),
            (keccak256(encode((factory_wire.collection.INVENTORY_DEPENDENCIES,),
                (factory_wire.inventory_dependencies(recipe, graph),))),))
        put(graph[5][6], "dependencyHash()", ("bytes32",),
            (keccak256(encode((factory_wire.BUNDLE_DEPS,),
                (factory_wire.bundle_dependencies(recipe, graph),))),))
        direct = {
            graph[5][0]: (("core()", "address", recipe[0][0][0]),
                ("coreCodeHash()", "bytes32", recipe[0][1][0]),
                ("metadataRouter()", "address", recipe[0][0][4]),
                ("metadataRouterCodeHash()", "bytes32", recipe[0][1][4]),
                ("entropySourceSet()", "address", graph[2]),
                ("entropySourceSetCodeHash()", "bytes32", graph[3]),
                ("deploymentChainId()", "uint256", int(self.a["chainId"])),
                ("readGas()", "uint32", recipe[3]), ("sourceGas()", "uint32", recipe[4])),
            graph[5][1]: (("core()", "address", recipe[0][0][0]),
                ("coreCodeHash()", "bytes32", recipe[0][1][0]),
                ("metadataRouter()", "address", recipe[0][0][4]),
                ("routerCodeHash()", "bytes32", recipe[0][1][4]),
                ("selectionCheckpoint()", "address", recipe[1][1]),
                ("selectionCodeHash()", "bytes32", recipe[2][1]),
                ("entropySourceSet()", "address", graph[2]),
                ("entropySourceSetCodeHash()", "bytes32", graph[3]),
                ("terminalReadiness()", "address", graph[5][0]),
                ("terminalReadinessCodeHash()", "bytes32", graph[6][0]),
                ("sourceFactory()", "address", recipe[1][2]),
                ("sourceFactoryCodeHash()", "bytes32", recipe[2][2]),
                ("factoryDependenciesHash()", "bytes32", value["sourceFactoryDependenciesHash"]),
                ("deploymentChainId()", "uint256", int(self.a["chainId"]))),
            graph[5][2]: (("core()", "address", recipe[0][0][0]),
                ("contentCheckpoint()", "address", graph[5][1]),
                ("checkpointCodeHash()", "bytes32", graph[6][1]),
                ("artifactCoverage()", "address", recipe[0][0][10]),
                ("coverageCodeHash()", "bytes32", recipe[0][1][10]),
                ("schemaRegistry()", "address", recipe[0][0][2]),
                ("schemaCodeHash()", "bytes32", recipe[0][1][2]),
                ("deploymentChainId()", "uint256", int(self.a["chainId"]))) }
        for target, rows in direct.items():
            for signature, output, result in rows:
                put(target, signature, (output,), (result,))

    def _install_content_reads(self):
        from . import scoped_policy_content_types_v2 as kinds
        b, a = self.policy_bundle, self.policy_addresses
        c, m, checkpoint = b["content"], b["content"]["manifest"], b["content"]["checkpoint"]
        scope = neutral.from_json(wire.SCOPE, b["scope"])
        def put(role, signature, outputs, values, inputs=(), arguments=()):
            self.add(a[role], signature, inputs, arguments, outputs, values)
        put("router", "scopedContentRootHead((uint8,uint256,uint256,bytes32))",
            ("bytes32",), (c["roots"]["scopeHead"],), (wire.SCOPE,), (scope,))
        put("router", "scopedContentRootAggregate(uint256)", (kinds.ROOT_AGGREGATE,),
            (neutral.from_json(kinds.ROOT_AGGREGATE, c["roots"]["collectionAggregate"]),),
            ("uint256",), (int(self.a["collectionId"]),))
        for row in c["roots"]["history"]:
            for signature, kind, value in (("scopedContentRootRecord(bytes32)", kinds.ROOT_RECORD, row["record"]),
                    ("scopedPolicyContentRootBinding(bytes32)", kinds.ROOT_BINDING, row["binding"])):
                put("router", signature, (kind,), (neutral.from_json(kind, value),),
                    ("bytes32",), (row["recordHash"],))
        for role, signature, kind, value, key in (
                ("outputManifest", "manifestRecord(bytes32)", kinds.OUTPUT_MANIFEST, m["record"], m["recordHash"]),
                ("outputManifest", "manifestPlan(bytes32)", kinds.OUTPUT_PLAN, m["plan"], m["planHash"]),
                ("policyContent", "checkpoint(bytes32)", kinds.CONTENT_PLAN, checkpoint["plan"], checkpoint["id"]),
                ("staticSelection", "checkpoint(bytes32)", kinds.SELECTION_PLAN, checkpoint["selectionPlan"], checkpoint["plan"][0]),
                ("artifacts", "artifact(bytes32)", kinds.ARTIFACT, m["artifact"], m["artifactHash"]),
                ("artifacts", "coverage(bytes32)", kinds.COVERAGE, m["coverage"], m["record"][6])):
            put(role, signature, (kind,), (neutral.from_json(kind, value),), ("bytes32",), (key,))
        for index, row in enumerate(checkpoint["outputs"]):
            put("policyContent", "outputAt(bytes32,uint256)", (kinds.OUTPUT,),
                (neutral.from_json(kinds.OUTPUT, row),), ("bytes32", "uint256"),
                (checkpoint["id"], index))
        for index, row in enumerate(checkpoint["selectionRows"]):
            put("staticSelection", "selectionAt(bytes32,uint256)", (kinds.SELECTION_ROW,),
                (neutral.from_json(kinds.SELECTION_ROW, row),), ("bytes32", "uint256"),
                (checkpoint["plan"][0], index))
        for index, row in enumerate(m["chunks"]):
            put("artifacts", "artifactChunk(bytes32,uint32)", ("address", "bytes32"),
                (row["pointer"], row["codeHash"]), ("bytes32", "uint32"),
                (m["artifactHash"], index))

    def _install_preservation_reads(self):
        from . import scoped_policy_preservation_types_v2 as kinds
        b, a = self.policy_bundle, self.policy_addresses
        suffix = "((uint8,uint256,uint256,bytes32))"
        for family, role, pub_kind, receipt_kind, deps_kind in (
                ("snapshot", "policySnapshot", kinds.SNAPSHOT_PUBLICATION,
                    kinds.SNAPSHOT_RECEIPT, kinds.SNAPSHOT_DEPS),
                ("reference", "policyReference", kinds.REFERENCE_PUBLICATION,
                    kinds.REFERENCE_RECEIPT, kinds.REFERENCE_DEPS)):
            group, host = b[family], a[role]
            publication = neutral.from_json(pub_kind, group["publication"])
            receipt = neutral.from_json(receipt_kind, group["receipt"])
            scope = publication[0]
            key = receipt[0] if family == "snapshot" else receipt[1][0]
            self.add(host, "dependencies()", (), (), (deps_kind,),
                (neutral.from_json(deps_kind, group["dependencies"]),))
            self.add(host, family + "Count" + suffix, (wire.SCOPE,), (scope,),
                ("uint256",), (len(group["history"]),))
            for index, entry in enumerate(group["history"]):
                ep = neutral.from_json(pub_kind, entry["publication"])
                er = neutral.from_json(receipt_kind, entry["receipt"])
                entry_key = er[0] if family == "snapshot" else er[1][0]
                self.add(host, family + "At((uint8,uint256,uint256,bytes32),uint256)",
                    (wire.SCOPE, "uint256"), (scope, index), ("bytes32",), (entry_key,))
                self.add(host, family + "Record(bytes32)", ("bytes32",), (entry_key,),
                    (pub_kind, receipt_kind), (ep, er))
            raw = hex_bytes(group["payload"])
            self.add(host, family + "Payload(bytes32)", ("bytes32",), (key,),
                ("bytes",), (raw,))
            for offset in range(0, len(raw), 8192): self.chunk(raw[offset:offset + 8192])
            self.add(host, "current" + family.title() + suffix, (wire.SCOPE,), (scope,),
                (receipt_kind,), (receipt,))
            self.add(host, family + "Lock" + suffix, (wire.SCOPE,), (scope,),
                (kinds.SNAPSHOT_LOCK,), (neutral.from_json(kinds.SNAPSHOT_LOCK, group["lock"]),))
            if family == "reference":
                self.add(host, "referenceSource(bytes32)", ("bytes32",), (key,),
                    (kinds.REFERENCE_SOURCE,),
                    (neutral.from_json(kinds.REFERENCE_SOURCE, group["source"]),))
        source = neutral.from_json(kinds.SNAPSHOT_SOURCE, b["snapshot"]["source"])
        entropy = source[9]; host, factory = a["entropySourceSet"], a["sourceFactory"]
        for signature, output, value in (("factory()", "address", factory),
                ("core()", "address", a["core"]),
                ("coreCodeHash()", "bytes32", self.policy_graph["core"]["runtimeHash"]),
                ("SOURCE_SET_PROFILE()", "bytes32", preservation_wire.SOURCE_SET_PROFILE),
                ("sourceScope()", wire.SCOPE, source[0]),
                ("scopeMembershipFacts()", kinds.MEMBERSHIP_FACTS, source[1]),
                ("inventoryPlan()", "bytes32", entropy[0]),
                ("originalInventoryHash()", "bytes32", entropy[1]),
                ("originalPolicyChainHash()", "bytes32", entropy[2]),
                ("sourceCount()", "uint256", entropy[3]),
                ("tokenInventory()", "address", a["tokenInventory"]),
                ("tokenInventoryCodeHash()", "bytes32", self.policy_graph["tokenInventory"]["runtimeHash"])):
            self.add(host, signature, (), (), (output,), (value,))
        for index, row in enumerate(entropy[5]):
            self.add(host, "sourcePolicyAt(uint256)", ("uint256",), (index,),
                (kinds.POLICY_ROW,), (row,))
        deps = neutral.from_json(kinds.POLICY_DEPS, b["snapshot"]["entropyDependencies"])
        for signature, role in (("core()", "core"), ("metadataHost()", "metadata"),
                ("scopeMembershipHost()", "scopeMembership"),
                ("coordinatorInventory()", "coordinatorInventory")):
            self.add(factory, signature, (), (), ("address",), (a[role],))
        self.add(factory, "sourceSetForPlan(bytes32)", ("bytes32",), (entropy[0],),
            ("address", "bytes32"), (host, self.policy_graph["entropySourceSet"]["runtimeHash"]))
        commitments = preservation_wire.source_set_commitments(source, deps, self.policy_graph)
        self.add(host, "sourceSetManifestHash()", (), (), ("bytes32",), (commitments["manifestHash"],))
        self.add(host, "sourceSetDataHash()", (), (), ("bytes32",), (commitments["dataHash"],))
        self.add(a["policyContent"], "sourceFactory()", (), (), ("address",), (factory,))
        self.add(a["policyContent"], "sourceFactoryCodeHash()", (), (), ("bytes32",), (source[7],))
        self.add(a["policyContent"], "factoryDependenciesHash()", (), (), ("bytes32",), (source[8],))
        reference = neutral.from_json(kinds.REFERENCE_SOURCE, b["reference"]["source"])
        for item in b["reference"]["objects"]:
            self.add(a["externalCoverage"], "objectIdentity(bytes32)", ("bytes32",),
                (item["objectHash"],), (kinds.EXTERNAL_OBJECT,),
                (neutral.from_json(kinds.EXTERNAL_OBJECT, item["identity"]),))
        for coverage in (reference[6], *(sample[1][9] for sample in reference[7])):
            self.add(a["externalCoverage"], "coverage(bytes32)", ("bytes32",),
                (coverage[0],), (kinds.EXTERNAL_COVERAGE,), (coverage,))

    def _install_source_map(self):
        from .scoped_policy_finality_fixture_provider_v2 import install_provider_reads
        from .scoped_policy_finality_fixture_reads_v2 import (
            install_events, install_finality_reads)
        from .scoped_policy_finality_fixture_membership_static_v2 import (
            install_membership_static_reads)

        self._relocate_carriers()
        install_provider_reads(self, self.policy_bundle["provider"],
            self.policy_context, self.policy_graph)
        self._install_factory_reads()
        self._install_content_reads()
        self._install_preservation_reads()
        install_membership_static_reads(self, self.policy_bundle,
            self.policy_context, self.policy_graph)
        self._install_definitions()
        install_finality_reads(self, self.policy_bundle, self.policy_context, self.policy_graph)
        install_events(self, self.policy_bundle, self.policy_context, self.policy_graph)
        source = self._source_module()
        addresses = {key: row["address"] for key, row in self.policy_graph.items()}
        common = {key: self.a[key] for key in ("chainId", "blockHash", "blockNumber",
            "timestamp", "stateRoot", "environment", "deploymentEvidenceHash", "core",
            "collectionId")}
        pinned = [address for address in dict.fromkeys(self.codes) if address in self.pins]
        self.policy_anchor = {**common, **addresses, "profile": source.PROFILE,
            "tokenId": str(TOKEN), "scope": deepcopy(self.policy_bundle["scope"]),
            "codePins": [{"address": address, "runtimeHash": self.pins[address]}
                for address in pinned],
            "runtimeAdmission": {"sourceCommit": wire.SOURCE_REVISION,
                "kind": "synthetic_fixture",
                "artifactHash": schema_id("synthetic e0b4 scoped policy runtime artifact")}}

    def request(self, method, params):
        if method == "eth_getTransactionByHash":
            self.requested.append((method, params))
            return deepcopy(self.policy_transactions.get(params[0]))
        return super().request(method, params)

    def policy_source(self):
        source = self._source_module()
        return source.PublicScopedPolicyFinalitySource(dumps(self.policy_anchor), self)

    def policy_result(self):
        source = self._source_module()
        return loads(self.policy_source().snapshot(), maximum=source.MAX_OUTPUT)

    def policy_capture(self):
        from . import public_scoped_policy_finality_capture_v2 as capture
        adapter = self.policy_source()
        return capture._assemble(adapter, keccak256(adapter.anchor_bytes),
            self._source_module().PROFILE_HASH)

    def policy_inputs(self):
        from . import acquisition_title_v5 as title
        prior, accession = self.title_inputs()
        packet = title.compose(prior.files, prior.manifest_hash, accession.files,
            accession.manifest_hash, disclosure="public")
        return packet, self.policy_capture()

    def preservation_inputs(self):
        from .policy_finality_fixture_v2 import PolicyFinalityFixtureV2
        return PolicyFinalityFixtureV2.preservation_inputs(self)

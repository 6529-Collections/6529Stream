"""Coherent synthetic COLLECTION policy V2 evidence over one RPC map.

The fixture installs the policy history before any inherited title capture is
constructed.  It is explicit synthetic evidence: no EVM execution, consensus,
runtime provenance or current policy eligibility is claimed.
"""
from copy import deepcopy

from . import native_finality_wire as neutral
from . import native_policy_finality_wire_v2 as wire
from . import policy_content_wire_v2 as content_wire
from . import policy_preservation_wire_v2 as preservation_wire
from . import policy_static_components_v2 as static_wire
from . import policy_membership_v2 as membership_wire
from .canonical import dumps, hex_bytes, keccak256, loads, schema_id
from .chain_abi import Array, calldata, decode, encode
from .independent_wire import RAW_BYTES, ZERO, ZERO_ADDRESS, json_values
from .scoped_static_types import SELECTION_PLAN, SELECTION_ROW
from .policy_preservation_types_v2 import SNAPSHOT_RECEIPT, REFERENCE_RECEIPT
from .test_current_rights_source import A, H
from .test_native_policy_finality_wire_v2 import provider_fixture, seal as seal_finality
from .test_policy_content_wire_v2 import supplied as content_supplied, rebuild as rebuild_content
from .test_policy_preservation_wire_v2 import supplied as preservation_supplied, seal_snapshot, seal_reference
from .title_v5_fixture import TitleV5Fixture, TOKEN, COLLECTION


def _static_originals(context, graph, artist, count, adapters, coordinator, coordinator_pin):
    """Build one immutable ConfigRecord reused by all selected token rows."""
    chain = int(context["chainId"]); scope = (0, int(context["collectionId"]), 0, ZERO)
    selected = (A(61001), schema_id("synthetic registry runtime"), schema_id("synthetic registry version"),
        A(61002), schema_id("synthetic renderer runtime"), schema_id("6529STREAM_RENDERER_V1"),
        schema_id("6529STREAM_STATIC_RENDERER_V1"), schema_id("synthetic render context"),
        schema_id("synthetic render schema"), schema_id("synthetic reads"), schema_id("synthetic registration"))
    config = (1, selected[3], "ipfs://synthetic-policy/", "ipfs://synthetic-pending", 0, True)
    raw = (chain, True, "Synthetic policy collection", "Synthetic retained source",
        "ipfs://synthetic-image", "ipfs://synthetic-animation", "return tokenId;",
        (A(61003), schema_id("synthetic script code"), schema_id("synthetic script manifest")),
        (A(61004), schema_id("synthetic media code"), schema_id("synthetic media manifest")))
    snap = static_wire._source_snapshot_hash(raw)
    seed = (ZERO, schema_id("synthetic config predecessor"), int(context["collectionId"]), 0, 1, 1, 1,
        snap, selected, config)
    record_hash = static_wire._record_hash(graph["core"]["address"], graph["router"]["address"], seed)
    record = (record_hash, *seed[1:])
    sources = (graph["core"]["address"], graph["router"]["address"], graph["metadata"]["address"],
        coordinator, ZERO_ADDRESS, ZERO_ADDRESS)
    pins = (graph["core"]["runtimeHash"], graph["router"]["runtimeHash"], graph["metadata"]["runtimeHash"],
        coordinator_pin, ZERO, ZERO)
    rows = []
    for index in range(count):
        rows.append((TOKEN + index, record_hash, keccak256(encode((static_wire.CONFIG_RECORD,), (record,))),
            snap, keccak256(encode((static_wire.RAW_SOURCE,), (raw,))), selected, sources, pins))
    plan = (scope, schema_id("synthetic membership"), schema_id("synthetic collection state"), count, count, ZERO)
    originals = [{"configRecordHash": record_hash, "configRecord": json_values(record),
        "rawSource": json_values(raw), "selectedConfig": json_values(config)}]
    return plan, json_values(rows), originals


def _component_expectations(context, graph, authenticated, plan, rows, originals, artist, adapters,
                            module_version, module_manifest, other):
    """Reproduce the six static hashes, retaining the three other families."""
    probe = {"context": {"chainId": context["chainId"], "core": graph["core"]["address"],
        "metadata": graph["metadata"]["address"], "router": graph["router"]["address"],
        "routerCodeHash": graph["router"]["runtimeHash"], "selection": graph["staticSelection"]["address"],
        "selectionCodeHash": graph["staticSelection"]["runtimeHash"], "routerModuleVersion": module_version,
        "routerModuleManifestHash": module_manifest, "adapters": adapters},
        "authenticated": authenticated, "plan": plan, "rows": rows, "originals": originals,
        "artistPresentation": artist, "componentExpectations": []}
    # The pure validator computes hashes while checking expectations, so build
    # them with the same independently specified native preimages.
    chain = int(context["chainId"]); typed_rows = tuple(neutral.from_json(SELECTION_ROW, row) for row in rows)
    typed_originals = {item["configRecordHash"]: (neutral.from_json(static_wire.CONFIG_RECORD, item["configRecord"]),
        neutral.from_json(static_wire.RAW_SOURCE, item["rawSource"])) for item in originals}
    auth = neutral.from_json(static_wire.AUTHENTICATED_SELECTION, authenticated)
    values = []
    by_family = {row["family"]: row for row in adapters}
    for family in static_wire.FAMILIES:
        identity = keccak256(encode(("bytes32", "bytes32", "uint256", "address", "address", "address",
            "address", "bytes32", static_wire.AUTHENTICATED_SELECTION),
            (static_wire.DOMAIN, family, chain, graph["core"]["address"], graph["metadata"]["address"],
             graph["router"]["address"], graph["staticSelection"]["address"],
             graph["staticSelection"]["runtimeHash"], auth)))
        folded = ZERO
        for index, row in enumerate(typed_rows):
            record, raw = typed_originals[row[1]]
            item = keccak256(encode(("bytes32", "bytes32", "bytes32", "uint256", "uint256", "bytes32",
                "bytes32", "bytes32", "bytes32", "bytes32"), (static_wire.ROW_DOMAIN, identity, family,
                index, row[0], row[1], row[2], row[3], row[4], static_wire._field_hash(family, row, record, raw))))
            folded = keccak256(encode(("bytes32", "bytes32", "bytes32", "bytes32", "uint256", "uint256", "bytes32"),
                (static_wire.FOLD_DOMAIN, identity, family, folded, index, row[0], item)))
        if family == static_wire.METADATA_ROUTER:
            folded = keccak256(encode(("bytes32", "bytes32", "bytes32", "bytes32", static_wire.ARTIST_PRESENTATION),
                (static_wire.FOLD_DOMAIN, identity, family, folded,
                 neutral.from_json(static_wire.ARTIST_PRESENTATION, artist))))
        digest = keccak256(encode(("bytes32", "bytes32", "bytes32", "uint64", "bytes32"),
            (static_wire.DOMAIN, identity, family, auth[5], folded)))
        adapter = by_family[family]
        values.append((family, adapter["address"], wire.COMPONENT_INTERFACE, adapter["runtimeHash"],
            module_version, module_manifest, digest))
    merged = {row[0]: row for row in other}
    merged.update({row[0]: row for row in values})
    return tuple(merged[k] for k in neutral.INDEPENDENT_FAMILIES), probe


class PolicyFinalityFixtureV2(TitleV5Fixture):
    """One-token COLLECTION policy V2 fixture sharing the eleven title sources."""

    def __init__(self, *, count=1, burned=False, mode="disabled"):
        if not 1 <= count <= wire.MAX_OUTPUTS: raise ValueError("synthetic policy output count")
        if mode != "disabled": raise ValueError("synthetic policy fixture supports disabled policy only")
        super().__init__(burned=burned)
        self.policy_transactions = {}
        addresses = {key: A(60000 + i) for i, key in enumerate(wire.GRAPH_KEYS)}
        addresses.update(core=self.core, metadata=self.a["host"], router=self.configuration[0][7], artist=self.registry,
            finality=A(6), provider=A(7), schemas=A(3), store=A(4), executor=self.floor_executor)
        for key, address in addresses.items():
            if address not in self.codes:
                self.codes[address] = ("synthetic 896 policy " + key).encode("ascii")
                self.pins[address] = keccak256(self.codes[address])
        self.policy_addresses = addresses
        self.policy_graph = {key: {"address": address, "runtimeHash": self.pins[address]}
            for key, address in addresses.items()}
        self.policy_context = {key: self.a[key] for key in ("chainId", "core", "collectionId", "blockHash",
            "blockNumber", "timestamp", "stateRoot", "environment", "deploymentEvidenceHash")} | {"tokenId": str(TOKEN)}
        self._build_pure(count, mode)
        self._install_policy_bindings()
        self._install_policy_definitions()
        self._install_policy_getters()
        self._install_policy_events()
        common = {key: self.a[key] for key in ("chainId", "blockHash", "blockNumber", "timestamp", "stateRoot",
            "environment", "deploymentEvidenceHash", "core", "collectionId")}
        pins = list(dict.fromkeys([*addresses.values(), *(row["address"] for row in self.policy_adapters),
            *[address for address in self.codes if address not in self.pins or address in self.codes]]))
        self.policy_anchor = {**common, **addresses, "profile": self._source_module().PROFILE, "tokenId": str(TOKEN),
            "codePins": [{"address": address, "runtimeHash": self.pins[address]} for address in pins if address in self.pins],
            "runtimeAdmission": {"sourceCommit": wire.SOURCE_REVISION, "kind": "synthetic_fixture",
                "artifactHash": schema_id("synthetic 896 policy runtime artifact")}}

    def _build_pure(self, count, mode):
        x, g = self.policy_context, self.policy_graph
        stamp = int(x["timestamp"])
        artist = (True, self.registry, self.pins[self.registry], self.artist_id, 1,
            schema_id("synthetic policy binding"), A(93), schema_id("synthetic policy identity"),
            schema_id("synthetic policy acceptance"), 100, 110,
            schema_id("synthetic policy Artist snapshot"))
        preservation, _, _, preserved_statement, _ = preservation_supplied(
            count, mode=mode, context=x, graph=g, artist=artist)
        adapters = [{"family": family, "address": A(62000 + i), "runtimeHash": schema_id("synthetic adapter " + str(i))}
            for i, family in enumerate(static_wire.FAMILIES)]
        for row in adapters:
            self.codes[row["address"]] = ("synthetic static adapter " + row["family"]).encode("ascii")
            self.pins[row["address"]] = keccak256(self.codes[row["address"]])
            row["runtimeHash"] = self.pins[row["address"]]
        initial_entropy = neutral.from_json(preservation_wire.POLICY_EVIDENCE,
            preservation["snapshot"]["source"][8])
        plan, rows, originals = _static_originals(x, g, artist, count, adapters,
            initial_entropy[5][0][0], initial_entropy[5][0][1])
        tokens = [str(TOKEN + i) for i in range(count)]
        prefix = neutral._hash("6529STREAM_TOKEN_INVENTORY_V1", ("uint256", "address", "address", "uint256"),
            (int(x["chainId"]), g["tokenInventory"]["address"], g["core"]["address"], int(x["collectionId"])))
        identities = []
        for i, token in enumerate(tokens):
            serial = 3 + i
            prefix = neutral._hash("6529STREAM_TOKEN_INVENTORY_APPEND_V1", ("bytes32", "uint256", "uint256"),
                (prefix, serial, int(token)))
            identities.append((True, int(x["collectionId"]), serial, self.title_burned if i == 0 else False))
        facts = list(preservation["snapshot"]["source"][1]); facts[3] = facts[6] = count; facts[7] = prefix
        facts[5] = preservation_wire.membership_hash(tuple(facts), (0, int(x["collectionId"]), 0, ZERO), x, g)
        preservation["snapshot"]["source"][1] = json_values(tuple(facts))
        policy_dependencies = neutral.from_json(preservation_wire.POLICY_DEPS,
            preservation["snapshot"]["entropyDependencies"])
        entropy = list(neutral.from_json(preservation_wire.POLICY_EVIDENCE,
            preservation["snapshot"]["source"][8]))
        entropy[0] = preservation_wire.policy_plan((0, int(x["collectionId"]), 0, ZERO), tuple(facts),
            policy_dependencies, x)
        entropy[2] = preservation_wire.policy_chain(tuple(entropy), (0, int(x["collectionId"]), 0, ZERO),
            policy_dependencies, x)
        preservation["snapshot"]["source"][8] = json_values(tuple(entropy))
        plan = (*plan[:1], facts[5], *plan[2:])
        selection_id = preservation_wire.selection_id(neutral.from_json(SELECTION_PLAN, plan), x, g)
        event_stamp = int(self.blocks[H(203)]["timestamp"], 16)
        content, _, _, content_statement = content_supplied(count, context=x, graph=g, artist_id=self.artist_id,
            root_timestamp=event_stamp, selection_id=selection_id, selection_plan=plan, selection_rows=rows)
        content["roots"]["history"][0]["record"][4:7] = [artist[3], str(artist[4]), artist[5]]
        # Preserve the exact source-set inventory and policy commitments in the
        # output checkpoint rather than the content helper's placeholder pair.
        entropy = preservation["snapshot"]["source"][8]
        content["checkpoint"]["plan"][2:4] = entropy[1:3]
        content_statement[9][3:6] = list(entropy[0:3])
        policy = entropy[5][0]; native_policy = policy[14]
        readiness = [policy[0], policy[1], policy[8], "1", str(native_policy[3]), str(native_policy[4]),
            str(native_policy[5]), True, False, ZERO]
        for output in content["checkpoint"]["outputs"]:
            output[4] = deepcopy(readiness)
            output[5] = schema_id("synthetic terminal admission " + str(output[0][0]))
        captures = preservation["reference"]["publication"][1][7]
        samples = preservation["reference"]["source"][6]
        for capture, sample in zip(captures, samples):
            ordinal = int(sample[0]); output = content["checkpoint"]["outputs"][ordinal]
            output[0][0] = capture[0]; output[0][1] = capture[2]; output[0][3] = capture[3]
            output[0][5] = sample[1][4]; output[3] = capture[3]
        rebuild_content(content, x, g, content_statement)
        cr = content_wire.validate(content, x, g, content_statement)
        source = preservation["snapshot"]["source"]
        source[3:8] = [cr["selectionPlan"], cr["contentPlan"], cr["outputManifest"],
            cr["selectedRoot"], cr["selectedBinding"]]
        for capture, sample in zip(preservation["reference"]["publication"][1][7],
                                   preservation["reference"]["source"][6]):
            ordinal = int(sample[0]); sample[2] = deepcopy(cr["selectionRows"][ordinal])
            sample[3] = deepcopy(cr["outputs"][ordinal][4])
            sample[4] = cr["outputs"][ordinal][5]
            capture[1] = sample[1][1] = str(3 + ordinal)
        preservation["snapshot"]["publication"][9] = str(event_stamp)
        preservation["snapshot"]["receipt"][13] = str(event_stamp)
        preservation["snapshot"]["lock"][3] = str(event_stamp)
        preservation["reference"]["publication"][1][10] = str(event_stamp)
        preservation["reference"]["receipt"][1][14:16] = [str(event_stamp), str(event_stamp)]
        preservation["reference"]["lock"][3] = str(event_stamp)
        preservation["snapshot"]["publication"][4:7] = [cr["manifestRecordHash"], content["roots"]["selectedRootHash"], entropy[0]]
        seal_snapshot(preservation["snapshot"], x, g)
        seal_reference(preservation["reference"], preservation["snapshot"], x, g)
        snap = neutral.from_json(SNAPSHOT_RECEIPT, preservation["snapshot"]["receipt"])
        ref = neutral.from_json(REFERENCE_RECEIPT, preservation["reference"]["receipt"])
        preserved = preservation_wire.validate(preservation, x, g, None, cr)
        static_plan = cr["selectionPlan"]
        authenticated = (static_plan[0], snap[15], cr["contentPlan"][0], static_plan[1], static_plan[5],
            static_plan[3], artist[11])
        module_version, module_manifest = schema_id("synthetic router module V2"), schema_id("synthetic router manifest")
        metadata_module_version = schema_id("synthetic metadata module V2")
        metadata_module_manifest = schema_id("synthetic metadata manifest")
        metadata_family = schema_id("COLLECTION_METADATA")
        metadata_adapter = {"family": metadata_family, "address": A(62006),
            "runtimeHash": schema_id("synthetic metadata adapter")}
        self.codes[metadata_adapter["address"]] = b"synthetic collection metadata adapter"
        self.pins[metadata_adapter["address"]] = keccak256(self.codes[metadata_adapter["address"]])
        metadata_adapter["runtimeHash"] = self.pins[metadata_adapter["address"]]
        entropy_commitment = preserved["componentCommitments"]["entropy"]
        reference_commitment = preserved["componentCommitments"]["reference"]
        other = (
            (schema_id("ENTROPY_COORDINATOR"), g["entropySourceSet"]["address"], wire.COMPONENT_INTERFACE,
             g["entropySourceSet"]["runtimeHash"], entropy_commitment["moduleVersion"],
             entropy_commitment["manifestHash"], entropy_commitment["dataHash"]),
            (schema_id("REFERENCE_RENDER"), g["policyReference"]["address"], wire.COMPONENT_INTERFACE,
             g["policyReference"]["runtimeHash"], reference_commitment["moduleVersion"],
             reference_commitment["manifestHash"], reference_commitment["dataHash"]),
            (metadata_family, metadata_adapter["address"], wire.COMPONENT_INTERFACE,
             metadata_adapter["runtimeHash"], metadata_module_version, metadata_module_manifest,
             schema_id("synthetic collection metadata data")))
        components, static_probe = _component_expectations(x, g, json_values(authenticated), static_plan, rows,
            originals, json_values(artist), adapters, module_version, module_manifest,
            other)
        inputs = list(content_statement[7]); inputs[0:3] = [content["roots"]["selectedRootHash"], snap[0], ref[1][0]]
        inputs[3] = ZERO
        statement = (static_plan[0], preserved_statement[1], content_statement[2], count,
            content_statement[4], snap[5], ref[1][6], tuple(inputs), components,
            (g["entropySourceSet"]["address"], g["entropySourceSet"]["runtimeHash"], wire.ENTROPY_PROFILE,
             entropy[0], entropy[1], entropy[2], entropy[3], wire.SNAPSHOT_PROFILE, wire.REFERENCE_PROFILE), 1, 1)
        statement = neutral.from_json(wire.STATEMENT, json_values(statement))
        self.policy_statement = json_values(statement)
        finality = seal_finality(statement, x, g)
        static_probe.update(authenticated=json_values(authenticated), plan=json_values(static_plan), rows=rows,
            originals=originals, artistPresentation=json_values(artist), componentExpectations=json_values(components))
        static_wire.validate(static_probe)
        membership = {"facts": json_values(tuple(facts)), "inventoryState": [str(count), prefix], "tokens": tokens,
            "identities": json_values(identities), "lifecycles": ["3" if row[3] else "2" for row in identities],
            "serialTokens": tokens}
        membership_wire.validate(membership, x, g, tuple(facts), tokens)
        configuration = provider_fixture(x, g)
        original = neutral.from_json(wire.PROVIDER_CONFIG, configuration["originalConfiguration"])
        discovery = (g["core"]["address"], g["metadata"]["address"], g["router"]["address"],
            g["provider"]["address"], g["scopeMembership"]["address"], original[0][10],
            metadata_adapter["address"], original[0][9], g["artist"]["address"], g["finality"]["address"],
            g["finality"]["runtimeHash"], tuple(row["address"] for row in adapters), 100000, 200000, 300000)
        all_adapters = [*adapters, metadata_adapter]
        adapter_evidence = []
        for i, row in enumerate(all_adapters):
            host = "router" if i < 6 else "metadata"
            adapter_evidence.append({"family": row["family"], "address": row["address"],
                "runtimeHash": row["runtimeHash"], "core": g["core"]["address"],
                "coreCodeHash": g["core"]["runtimeHash"], "host": g[host]["address"],
                "hostCodeHash": g[host]["runtimeHash"], "evidenceProvider": g["provider"]["address"],
                "evidenceProviderCodeHash": g["provider"]["runtimeHash"], "metadataHost": g["metadata"]["address"],
                "metadataHostCodeHash": g["metadata"]["runtimeHash"]})
        module_identities = {"router": (module_version, module_manifest),
            "metadata": (metadata_module_version, metadata_module_manifest)}
        provider = {"configuration": configuration, "discoveryConfiguration": json_values(discovery),
            "discoverySourceConfigurationHash": configuration["configurationHash"], "adapters": adapter_evidence,
            "moduleIdentities": {key: json_values(value) for key, value in module_identities.items()}}
        self.policy_bundle = {"provider": provider, **finality, **preservation,
            "content": content, "membership": membership, "staticComponents": static_probe}
        self.policy_adapters = all_adapters
        self.policy_module_identities = module_identities
        self._finality_execution()

    def _finality_execution(self):
        from .test_governance_transaction_wire import _hashes, _inputs, _events
        b, x, g = self.policy_bundle, self.policy_context, self.policy_graph
        a = self.policy_addresses; chain = int(x["chainId"])
        statement = neutral.from_json(wire.STATEMENT, wire.validate_finality(b["finality"], x, g)["statement"])
        proof = tuple(schema_id("synthetic policy archive " + str(i)) for i in range(3))
        archive = (neutral.archive_evidence_hash(chain, a["core"], a["finality"], a["artifacts"], proof), proof)
        sanction = (neutral.SANCTION, a["artist"], wire.COMPONENT_INTERFACE, self.pins[a["artist"]],
            schema_id("synthetic policy sanction version"), schema_id("synthetic policy sanction manifest"), proof[0])
        components = tuple(sorted((*statement[8], sanction)))
        raw = encode(wire.INPUT_ENVELOPE,
            (wire.INPUT_SCHEMA, wire.INPUT_CANON, chain, a["core"], a["metadata"], a["finality"], statement))
        uri = "ipfs://synthetic-original-policy-finality"
        manifest = (uri, keccak256(uri.encode()), keccak256(raw), wire.INPUT_SCHEMA, wire.INPUT_CANON)
        digest = neutral.components_hash(components)
        record_hash = neutral.finality_hash(chain, a["core"], int(x["collectionId"]), statement[1], digest, manifest)
        stamp = int(self.blocks[H(204)]["timestamp"], 16)
        record = (True, record_hash, manifest[2], manifest[1], uri, digest, a["finality"], stamp)
        witness = [schema_id("pending synthetic policy action"), A(63001), schema_id("synthetic policy reason"),
            schema_id("synthetic policy role witness"), 1]
        ec = neutral.execution_context(chain, a["finality"], a["core"], a["metadata"], statement,
            record_hash, digest, archive[0])
        raw_call = hex_bytes(calldata(neutral.FINALIZE_SIGNATURE, neutral.FINALIZE_TYPES,
            (int(x["collectionId"]), components, record_hash, manifest, proof)))
        calls = ((a["finality"], 0, "0x" + raw_call[:4].hex(), keccak256(raw_call), ec["scopeHash"],
            ec["oldValueHash"], ec["newValueHash"]),)
        action = [3, 2, a["finality"], 0, calls[0][2], ZERO, ZERO, ZERO, ZERO,
            int(self.blocks[H(203)]["timestamp"], 16), stamp + 100, witness[1], A(63002), ZERO_ADDRESS,
            ZERO_ADDRESS, witness[2], "synthetic original policy reason", schema_id("synthetic policy action manifest")]
        calls_hash, folds, action_id = _hashes(calls, chain, a["executor"], action, 17)
        action[5:9] = [calls_hash, *folds]; witness[0] = action_id
        runtime = b"\0" + encode((Array("bytes", 64),), ((raw_call,),))
        pointer = A(63003); self.codes[pointer] = runtime; self.pins[pointer] = keccak256(runtime)
        b["finality"] = json_values({"record": record, "components": components, "manifestRef": manifest,
            "manifestBytes": "0x" + raw.hex(), "executionWitness": witness, "archiveWitness": archive,
            "inputsHash": ec["inputsHash"]})
        b["execution"] = json_values({"action": action, "callDataPointer": pointer,
            "callDatas": ("0x" + raw_call.hex(),), "runtime": "0x" + runtime.hex()})
        self.policy_normalized_transactions = _inputs(calls, (raw_call,), action, action_id, a["executor"],
            "schedule_batch", "execute_batch")
        self.policy_governance_events = _events(action, action_id, a["executor"], 17)
        wire.validate_bundle(b, x, g)

    @staticmethod
    def _source_module():
        from . import public_policy_finality_source_v2 as source
        return source

    def _install_policy_bindings(self):
        source, a, g = self._source_module(), self.policy_addresses, self.policy_graph
        for owner, getter, target in source.ADDRESS_BINDINGS:
            self.add(a[owner], getter, (), (), ("address",), (a[target],))
        for owner, getter, target in source.HASH_BINDINGS:
            self.add(a[owner], getter, (), (), ("bytes32",), (g[target]["runtimeHash"],))
        for key in ("scopeMembership", "tokenInventory", "staticSelection", "policyContent", "outputManifest", "coordinatorInventory"):
            self.add(a[key], "deploymentChainId()", (), (), ("uint256",), (int(self.a["chainId"]),))
        evidence = self.policy_bundle["provider"]; config = evidence["configuration"]
        for getter, key in (("configuration()", "originalConfiguration"), ("scopedConfiguration()", "scopedConfiguration"),
                            ("policyConfiguration()", "policyConfiguration")):
            self.add(a["provider"], getter, (), (), (wire.PROVIDER_CONFIG,),
                (neutral.from_json(wire.PROVIDER_CONFIG, config[key]),))
        self.add(a["renderCriticalInventory"], "dependencies()", (), (), (wire.INVENTORY_DEPENDENCIES,),
            (neutral.from_json(wire.INVENTORY_DEPENDENCIES, config["inventoryDependencies"]),))
        self.add(a["renderCriticalInventory"], "dependencyHash()", (), (), ("bytes32",),
            (neutral.from_json(wire.PROVIDER_CONFIG, config["policyConfiguration"])[6],))
        for i, row in enumerate(config["profiles"]):
            self.add(a["provider"], "finalitySourceProfile(uint8)", ("uint8",), (i,), (wire.PROFILE,),
                (neutral.from_json(wire.PROFILE, row),))
        self.add(a["provider"], "finalitySourceConfigurationHash()", (), (), ("bytes32",), (config["configurationHash"],))
        self.add(a["discovery"], "configuration()", (), (), (wire.DISCOVERY_CONFIG,),
            (neutral.from_json(wire.DISCOVERY_CONFIG, evidence["discoveryConfiguration"]),))
        self.add(a["discovery"], "sourceConfigurationHash()", (), (), ("bytes32",),
            (evidence["discoverySourceConfigurationHash"],))
        for row in evidence["adapters"]:
            host = row["address"]
            self.add(host, "componentType()", (), (), ("bytes32",), (row["family"],))
            for key in ("core", "host", "evidenceProvider", "metadataHost"):
                self.add(host, key + "()", (), (), ("address",), (row[key],))
                self.add(host, key + "CodeHash()", (), (), ("bytes32",), (row[key + "CodeHash"],))
        for key, values in evidence["moduleIdentities"].items():
            self.add(a["provider"], key + "ModuleVersion()", (), (), ("bytes32",), (values[0],))
            self.add(a["provider"], key + "ModuleManifestHash()", (), (), ("bytes32",), (values[1],))
        original = (a["finality"], g["finality"]["runtimeHash"])
        self.add(a["router"], "servingOriginalFinalityAnchor()", (), (), ("address", "bytes32"), original)
        self.add(a["router"], "originalFinalityAnchor(uint256)", ("uint256",), (COLLECTION,),
            ("address", "bytes32"), original)

    def _install_policy_definitions(self):
        from .current_rights_source import DOCUMENT_FACTS
        for definition in wire.definitions():
            raw = definition["bytes"]
            parts = [raw[i:i + 8192] for i in range(0, len(raw), 8192)]
            digests = [self.chunk(part) for part in parts]
            facts = (True, definition["kind"], 0, definition["hash"], RAW_BYTES, ZERO, len(raw), len(parts),
                schema_id("synthetic policy definition " + definition["name"]))
            self.add(A(3), "documentFacts(bytes32)", ("bytes32",), (definition["id"],), (DOCUMENT_FACTS,), (facts,))
            for index, digest in enumerate(digests):
                self.add(A(3), "documentChunkHashAt(bytes32,uint256)", ("bytes32", "uint256"),
                    (definition["id"], index), ("bytes32",), (digest,))

    def _install_policy_getters(self):
        from . import policy_content_types_v2 as ct
        from . import policy_preservation_types_v2 as pt
        b, a, g = self.policy_bundle, self.policy_addresses, self.policy_graph
        def put(role, signature, outputs, values, inputs=(), arguments=()):
            self.add(a[role], signature, inputs, arguments, outputs, values)
        f = b["finality"]; record = neutral.from_json(neutral.FINALITY_RECORD, f["record"])
        put("finality", "collectionFinalityRecord(uint256)", (neutral.FINALITY_RECORD,), (record,), ("uint256",), (COLLECTION,))
        put("finality", "finalityComponentCount(uint256)", ("uint256",), (10,), ("uint256",), (COLLECTION,))
        put("finality", "finalityComponents(uint256,uint256,uint256)", (Array(wire.COMPONENT, 32),),
            (neutral.from_json(Array(wire.COMPONENT, 32), f["components"]),), ("uint256", "uint256", "uint256"),
            (COLLECTION, 0, 10))
        put("finality", "finalityManifestStored(bytes32)", ("bool",), (True,), ("bytes32",), (record[2],))
        raw_manifest = hex_bytes(f["manifestBytes"]); self.chunk(raw_manifest)
        put("finality", "finalityManifestBytes(bytes32)", ("bytes",), (raw_manifest,), ("bytes32",), (record[2],))
        put("finality", "finalityExecutionWitness(bytes32)", (neutral.EXECUTION_WITNESS,),
            (neutral.from_json(neutral.EXECUTION_WITNESS, f["executionWitness"]),), ("bytes32",), (record[1],))
        put("finality", "finalitySanctionArchiveWitness(bytes32)", (neutral.ARCHIVE_WITNESS,),
            (neutral.from_json(neutral.ARCHIVE_WITNESS, f["archiveWitness"]),), ("bytes32",), (record[1],))
        c = b["content"]; m = c["manifest"]; cp = c["checkpoint"]
        put("router", "collectionContentRootHead(uint256)", ("bytes32",), (c["roots"]["rootHead"],), ("uint256",), (COLLECTION,))
        for row in c["roots"]["history"]:
            put("router", "contentRootRecord(bytes32)", (ct.ROOT_RECORD,),
                (neutral.from_json(ct.ROOT_RECORD, row["record"]),), ("bytes32",), (row["recordHash"],))
            put("router", "policyContentRootBinding(bytes32)", (ct.ROOT_BINDING,),
                (neutral.from_json(ct.ROOT_BINDING, row["binding"]),), ("bytes32",), (row["recordHash"],))
        for role, signature, kind, value, key in (
            ("outputManifest", "manifestRecord(bytes32)", ct.OUTPUT_MANIFEST, m["record"], m["recordHash"]),
            ("outputManifest", "manifestPlan(bytes32)", ct.OUTPUT_PLAN, m["plan"], m["planHash"]),
            ("policyContent", "checkpoint(bytes32)", ct.CONTENT_PLAN, cp["plan"], cp["id"]),
            ("staticSelection", "checkpoint(bytes32)", SELECTION_PLAN, cp["selectionPlan"], cp["plan"][0]),
            ("artifacts", "artifact(bytes32)", ct.ARTIFACT, m["artifact"], m["artifactHash"]),
            ("artifacts", "coverage(bytes32)", ct.COVERAGE, m["coverage"], m["record"][6])):
            put(role, signature, (kind,), (neutral.from_json(kind, value),), ("bytes32",), (key,))
        for i, value in enumerate(cp["outputs"]):
            put("policyContent", "outputAt(bytes32,uint256)", (ct.OUTPUT,), (neutral.from_json(ct.OUTPUT, value),),
                ("bytes32", "uint256"), (cp["id"], i))
        for i, value in enumerate(cp["selectionRows"]):
            put("staticSelection", "selectionAt(bytes32,uint256)", (SELECTION_ROW,),
                (neutral.from_json(SELECTION_ROW, value),), ("bytes32", "uint256"), (cp["plan"][0], i))
        for i, value in enumerate(m["chunks"]):
            body = hex_bytes(value["runtime"])[1:]; pointer = self._store_policy_chunk(body)
            value["pointer"] = pointer
            put("artifacts", "artifactChunk(bytes32,uint32)", ("address", "bytes32"),
                (pointer, value["codeHash"]), ("bytes32", "uint32"), (m["artifactHash"], i))
        self._install_preservation_getters(pt)
        source = neutral.from_json(pt.SNAPSHOT_SOURCE, b["snapshot"]["source"])
        e = source[8]; host, factory = a["entropySourceSet"], a["entropyFactory"]
        for signature, kind, value in (("factory()", "address", factory), ("core()", "address", a["core"]),
            ("coreCodeHash()", "bytes32", g["core"]["runtimeHash"]), ("SOURCE_SET_PROFILE()", "bytes32", preservation_wire.SOURCE_SET_PROFILE),
            ("sourceScope()", neutral.SCOPE, source[0]), ("scopeMembershipFacts()", pt.MEMBERSHIP_FACTS, source[1]),
            ("inventoryPlan()", "bytes32", e[0]), ("originalInventoryHash()", "bytes32", e[1]),
            ("originalPolicyChainHash()", "bytes32", e[2]), ("sourceCount()", "uint256", e[3]),
            ("tokenInventory()", "address", a["tokenInventory"]), ("tokenInventoryCodeHash()", "bytes32", g["tokenInventory"]["runtimeHash"])):
            put("entropySourceSet", signature, (kind,), (value,))
        for i, row in enumerate(e[5]):
            put("entropySourceSet", "sourcePolicyAt(uint256)", (pt.POLICY_ROW,), (row,), ("uint256",), (i,))
        pd = neutral.from_json(pt.POLICY_DEPS, b["snapshot"]["entropyDependencies"])
        put("entropyFactory", "policyFactoryProfile()", ("bytes32",), (schema_id("6529STREAM_ENTROPY_POLICY_SOURCE_FACTORY_V2"),))
        put("entropyFactory", "dependencies()", (pt.POLICY_DEPS,), (pd,))
        for signature, role in (("core()", "core"), ("metadataHost()", "metadata"),
                                ("scopeMembershipHost()", "scopeMembership"), ("coordinatorInventory()", "coordinatorInventory")):
            put("entropyFactory", signature, ("address",), (a[role],))
        put("entropyFactory", "sourceSetForPlan(bytes32)", ("address", "bytes32"),
            (host, g["entropySourceSet"]["runtimeHash"]), ("bytes32",), (e[0],))
        pin = g["tokenInventory"]["runtimeHash"]
        put("entropySourceSet", "sourceSetManifestHash()", ("bytes32",),
            (keccak256(encode(("bytes32", pt.POLICY_DEPS, "address", "bytes32"),
             (preservation_wire.SOURCE_SET_PROFILE, pd, a["tokenInventory"], pin))),))
        put("entropySourceSet", "sourceSetDataHash()", ("bytes32",),
            (keccak256(encode(("bytes32", neutral.SCOPE, "bytes32", "bytes32", "bytes32", pt.MEMBERSHIP_FACTS, "address", "bytes32"),
             (preservation_wire.SOURCE_SET_PROFILE, source[0], e[0], e[1], e[2], source[1], a["tokenInventory"], pin))),))
        static = b["staticComponents"]
        for item in static["originals"]:
            put("router", "metadataConfigRecord(bytes32)", (static_wire.CONFIG_RECORD,),
                (neutral.from_json(static_wire.CONFIG_RECORD, item["configRecord"]),), ("bytes32",), (item["configRecordHash"],))
            put("router", "staticRenderSourceForConfig(uint256,bytes32)", (static_wire.RAW_SOURCE, static_wire.METADATA_CONFIG),
                (neutral.from_json(static_wire.RAW_SOURCE, item["rawSource"]), neutral.from_json(static_wire.METADATA_CONFIG, item["selectedConfig"])),
                ("uint256", "bytes32"), (COLLECTION, item["configRecordHash"]))
        for key, value in self.policy_module_identities.items():
            put("provider", key + "ModuleVersion()", ("bytes32",), (value[0],))
            put("provider", key + "ModuleManifestHash()", ("bytes32",), (value[1],))
        membership = b["membership"]
        put("tokenInventory", "collectionInventoryState(uint256)", ("uint256", "bytes32"),
            (int(membership["inventoryState"][0]), membership["inventoryState"][1]), ("uint256",), (COLLECTION,))
        for i, token in enumerate(membership["tokens"]):
            put("tokenInventory", "collectionTokenAt(uint256,uint256)", ("uint256",), (int(token),),
                ("uint256", "uint256"), (COLLECTION, i))
            identity = neutral.from_json(membership_wire.IDENTITY, membership["identities"][i])
            self.add(a["core"], "tokenCollectionIdentity(uint256)", ("uint256",), (int(token),),
                (membership_wire.IDENTITY,), (identity,))
            self.add(a["core"], "tokenLifecycle(uint256)", ("uint256",), (int(token),),
                ("uint8",), (int(membership["lifecycles"][i]),))
            put("tokenInventory", "collectionTokenBySerial(uint256,uint256)", ("uint256",), (int(token),),
                ("uint256", "uint256"), (COLLECTION, identity[2]))
        action_id = f["executionWitness"][0]; execution = b["execution"]
        put("executor", "governanceAction(bytes32)", (neutral.GOVERNANCE_ACTION,),
            (neutral.from_json(neutral.GOVERNANCE_ACTION, execution["action"]),), ("bytes32",), (action_id,))
        calls = tuple(hex_bytes(v) for v in execution["callDatas"])
        key = keccak256(b"".join(hex_bytes(keccak256(v)) for v in calls))
        put("executor", "scheduledCallDataPointer(bytes32)", ("address",), (execution["callDataPointer"],), ("bytes32",), (action_id,))
        put("executor", "scheduledCallData(bytes32)", (Array("bytes", 64),), (calls,), ("bytes32",), (action_id,))
        put("executor", "publishedCallData(bytes32)", ("address",), (execution["callDataPointer"],), ("bytes32",), (key,))

    def _store_policy_chunk(self, raw):
        digest = self.chunk(raw); pointer, length = decode(("address", "uint32"),
            hex_bytes(self.responses[(A(4), calldata("chunk(bytes32)", ("bytes32",), (digest,)))]))
        assert length == len(raw)
        return pointer

    def _install_preservation_getters(self, pt):
        b, a = self.policy_bundle, self.policy_addresses
        for family, role, pub_type, rec_type, deps_type in (("snapshot", "policySnapshot", pt.SNAPSHOT_PUBLICATION,
                pt.SNAPSHOT_RECEIPT, pt.SNAPSHOT_DEPS), ("reference", "policyReference", pt.REFERENCE_PUBLICATION,
                pt.REFERENCE_RECEIPT, pt.REFERENCE_DEPS)):
            group = b[family]; host = a[role]
            p = neutral.from_json(pub_type, group["publication"]); r = neutral.from_json(rec_type, group["receipt"])
            d = neutral.from_json(deps_type, group["dependencies"]); scope = p[0]
            key = r[0] if family == "snapshot" else r[1][0]
            self.add(host, "dependencies()", (), (), (deps_type,), (d,))
            suffix = "((uint8,uint256,uint256,bytes32))"
            self.add(host, family + "Count" + suffix, (neutral.SCOPE,), (scope,), ("uint256",), (len(group["history"]),))
            for i, entry in enumerate(group["history"]):
                er = neutral.from_json(rec_type, entry["receipt"]); ek = er[0] if family == "snapshot" else er[1][0]
                ep = neutral.from_json(pub_type, entry["publication"])
                self.add(host, family + "At((uint8,uint256,uint256,bytes32),uint256)", (neutral.SCOPE, "uint256"),
                    (scope, i), ("bytes32",), (ek,))
                self.add(host, family + "Record(bytes32)", ("bytes32",), (ek,), (pub_type, rec_type), (ep, er))
            raw = hex_bytes(group["payload"]); parts = [raw[i:i+8192] for i in range(0, len(raw), 8192)]
            self.add(host, family + "Payload(bytes32)", ("bytes32",), (key,), ("bytes",), (raw,))
            current = "current" + family.title() + suffix
            self.add(host, current, (neutral.SCOPE,), (scope,), (rec_type,), (r,))
            self.add(host, family + "Lock" + suffix, (neutral.SCOPE,), (scope,), (pt.SNAPSHOT_LOCK,),
                (neutral.from_json(pt.SNAPSHOT_LOCK, group["lock"]),))
            self.add(host, family + "ChunkCount(bytes32)", ("bytes32",), (key,), ("uint256",), (len(parts),))
            for i, part in enumerate(parts):
                digest = self.chunk(part); pointer = self._store_policy_chunk(part)
                self.add(host, family + "ChunkAt(bytes32,uint256)", ("bytes32", "uint256"), (key, i),
                    ("address", "bytes32", "uint32"), (pointer, digest, len(part)))
            if family == "reference":
                self.add(host, "referenceSource(bytes32)", ("bytes32",), (key,), (pt.REFERENCE_SOURCE,),
                    (neutral.from_json(pt.REFERENCE_SOURCE, group["source"]),))
        ref = neutral.from_json(pt.REFERENCE_SOURCE, b["reference"]["source"])
        for item in b["reference"]["objects"]:
            self.add(a["externalCoverage"], "objectIdentity(bytes32)", ("bytes32",), (item["objectHash"],),
                (pt.EXTERNAL_OBJECT,), (neutral.from_json(pt.EXTERNAL_OBJECT, item["identity"]),))
        for coverage in (ref[5], *(sample[1][9] for sample in ref[6])):
            self.add(a["externalCoverage"], "coverage(bytes32)", ("bytes32",), (coverage[0],),
                (pt.EXTERNAL_COVERAGE,), (coverage,))

    def _install_policy_events(self):
        from . import policy_content_wire_v2 as content
        from .chain_history import LOG_FIELDS
        b, x, g = self.policy_bundle, self.policy_context, self.policy_graph
        descriptors = list(wire.expected_events(b, x, g)); observed = []
        order = ("inventory_indexed", "selection_started", "selection_appended", "selection_completed",
            "content_started", "content_appended", "content_completed", "artifact_recorded", "coverage_completed",
            "manifest_started")
        for kind in order:
            for row in descriptors:
                if row["kind"] == kind: observed.append(self._policy_raw_event(3, row))
        count = len(b["membership"]["tokens"])
        for start in range(0, count, 16):
            row = {"address": g["outputManifest"]["address"],
                "topics": [content.EVENTS["manifestAdvanced"], b["content"]["manifest"]["planHash"]],
                "data": "0x" + encode(("uint16", "uint64", "uint64"),
                    (2, start, min(start + 16, count))).hex()}
            observed.append(self._policy_raw_event(3, row))
        for kind in ("manifest_verified", "root_published", "root_binding_published",
                "policy_snapshot_published", "policy_snapshot_locked", "policy_reference_published",
                "policy_reference_locked"):
            for row in descriptors:
                if row["kind"] == kind: observed.append(self._policy_raw_event(3, row))
        execution = wire.validate_execution(b["execution"], x, g,
            wire.validate_finality(b["finality"], x, g))
        publication = {"address": g["executor"]["address"],
            "topics": [wire.EVENTS["governanceCalldataPublished"], execution["callDataKey"]],
            "data": "0x" + encode(neutral.GOVERNANCE_CALLDATA_DATA,
                (1, b["execution"]["callDataPointer"], A(63004))).hex()}
        observed.append(self._policy_raw_event(3, publication))
        schedule = self._policy_transaction(3, "schedule")
        observed.append(self._policy_raw_event(3, self.policy_governance_events[0], schedule))
        execution_tx = self._policy_transaction(4, "execution")
        for row in descriptors:
            if row["kind"] in ("finalized", "manifestPointer", "terminalExecuted", "executionWitness", "archiveWitness"):
                observed.append(self._policy_raw_event(4, row, execution_tx))
        observed.append(self._policy_raw_event(4, self.policy_governance_events[1], execution_tx))
        self.policy_events = [{"log": {key: log[key] for key in LOG_FIELDS},
            "timestamp": str(int(self.blocks[log["blockHash"]]["timestamp"], 16))} for log in observed]
        wire.validate_event_join(b, x, g, self.policy_events)
        wire.validate_governance(b, x, g, self.policy_normalized_transactions, self.policy_events)

    def _policy_raw_event(self, block, row, transaction=None):
        tx = transaction or H(400 + block); receipt = self.receipts[tx]
        header = self.blocks[receipt["blockHash"]]
        offset = sum(len(self.receipts[value]["logs"])
            for value in header["transactions"][:int(receipt["transactionIndex"], 16)])
        log = {key: receipt[key] for key in ("transactionHash", "blockHash", "blockNumber", "transactionIndex")}
        topics = [schema_id("synthetic policy wildcard") if value is None else
            ("0x" + value.hex()) if isinstance(value, bytes) else value for value in row["topics"]]
        log.update(address=row["address"], topics=topics, data=row["data"],
            logIndex=hex(offset + len(receipt["logs"])), removed=False)
        receipt["logs"].append(log)
        return log

    def _policy_transaction(self, block, side):
        header = self.blocks[H(200 + block)]
        tx = schema_id("synthetic policy " + side + " transaction")
        normalized = self.policy_normalized_transactions[side]
        receipt = {"transactionHash": tx, "blockHash": header["hash"], "blockNumber": header["number"],
            "transactionIndex": hex(len(header["transactions"])), "status": "0x1", "logs": [],
            "from": normalized["from"], "to": normalized["to"]}
        header["transactions"].append(tx); self.receipts[tx] = receipt
        self.policy_transactions[tx] = {key: receipt[key]
            for key in ("blockHash", "blockNumber", "transactionIndex", "from", "to")}
        self.policy_transactions[tx].update(hash=tx, input=normalized["input"],
            value=hex(int(normalized["value"])), chainId=hex(int(self.a["chainId"])))
        return tx

    def request(self, method, params):
        if method == "eth_getTransactionByHash":
            self.requested.append((method, params))
            return deepcopy(self.policy_transactions.get(params[0]))
        return super().request(method, params)

    def policy_source(self):
        source = self._source_module()
        return source.PublicPolicyFinalitySource(dumps(self.policy_anchor), self)

    def policy_result(self):
        source = self._source_module()
        return loads(self.policy_source().snapshot(), maximum=source.MAX_OUTPUT)

    def policy_capture(self):
        from . import public_policy_finality_capture_v2 as capture
        adapter = self.policy_source()
        return capture._assemble(adapter, keccak256(adapter.anchor_bytes), self._source_module().PROFILE_HASH)

    def policy_inputs(self):
        from . import acquisition_title_v5 as title
        prior, accession = self.title_inputs()
        return title.compose(prior.files, prior.manifest_hash, accession.files, accession.manifest_hash,
            disclosure="public"), self.policy_capture()

    def preservation_inputs(self):
        """Build V5 as script/ONCHAIN with the same original disabled policy."""
        from ..metadata.genesis_dossier_profile import examples, _entropy_hash
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
        readiness = self.policy_bundle["content"]["checkpoint"]["outputs"][0][4]
        leaf = packet["entropy"]["leaf"]
        leaf.update(coordinatorAtMint=readiness[0], status=readiness[3], seed=readiness[9])
        packet["entropy"]["leafHash"] = _entropy_hash(leaf)
        packet["entropy"]["events"] = []
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
            prospective.PROFILE_HASH, transcript, keccak256(transcript), provenance="synthetic_fixture",
            disclosure="public")
        return old, self.media_capture(), reference

"""Exact delayed governance and pointer joins for the local token capture."""
from .canonical import dumps, hex_bytes, keccak256, schema_id
from .current_museum_capture import h
from .independent_wire import ZERO, ZERO_ADDRESS, require

TOKEN_GOVERNANCE_PRODUCTS = (
    "StreamCore", "StreamGovernanceExecutor", "StreamRoleRegistry", "StreamModuleRegistry",
    "StreamSystemManifest", "StreamSchemaRegistry", "StreamDeploymentPlan",
    "StreamGovernanceBootstrap", "StreamGovernanceActionPolicy", "StreamCoreExternalReads",
    "IStreamArtistMintConsent", "IStreamMetadataRouter", "IStreamCollectionMetadataV1",
    "IStreamArtworkFinalityRegistry",
)


class TokenGovernanceMixin:
    def call(self, name, function, values=()):
        result = super().call(name, function, values)
        if name == "StreamDeploymentPlan" and function == "buildFoundation":
            definition = next(row for row in self.products[name]["abi"] if row.get("name") == function)
            components = definition["outputs"][0]["components"]
            index = next(i for i, row in enumerate(components) if row["name"] == "actionPolicies")
            self.token_action_policies = list(result[0][index])
        return result

    def admit_schema(self):
        super().admit_schema()
        selector = self.function("StreamSchemaRegistry", "registerDocument")[0]
        row = (1, self.schemas, "0x" + self.products["StreamSchemaRegistry"]["methodIdentifiers"][selector],
            keccak256(hex_bytes(self.rpc("eth_getCode", [self.schemas, "latest"]))),
            h(("bytes32", "address"), (self.deployment, self.schemas)), 1, 0, 0, ZERO)
        self.token_action_policies.append(row)

    def admit_token_batch(self, action_class, calls, datas):
        additions, = self.call("StreamDeploymentPlan", "catalogAdditions",
            ([(action_class, calls, datas)], [], self.token_action_policies, self.deployment))
        if not additions: return
        candidate, catalog, count, revision = self.call("StreamGovernanceExecutor", "governanceActionPolicyState")
        require(count == len(self.token_action_policies), "unexpected action catalog mutation")
        self.deploy("StreamGovernanceActionPolicy")
        next_, scope, old, new = self.call("StreamGovernanceActionPolicy", "extensionTransition",
            (self.addresses["StreamGovernanceExecutor"], candidate, catalog, count, revision, additions))
        data = self.data("StreamGovernanceExecutor", "extendGovernanceActionPolicy", (revision, catalog, next_, additions))
        pointer, digest = self.manifest_payload(dumps({"purpose": "new local token capture exact selector admission"}))
        tail, tail_data = self.publication(pointer, digest)
        self.govern(3, [self.operation(self.addresses["StreamGovernanceExecutor"], data, (scope, old, new)), tail],
            [hex_bytes(data), tail_data])
        self.token_action_policies.extend(additions)
        require(self.call("StreamGovernanceExecutor", "governanceActionPolicyState")[1:] == (next_, count + len(additions), revision + 1),
            "actual action catalog extension differs")

    def govern_configuration(self, name, function, values, transition=None, *, action_class=1):
        target = self.addresses[name]; data = self.data(name, function, values)
        if transition is None:
            transition = (h(("address", "bytes"), (target, hex_bytes(data))), ZERO, keccak256(hex_bytes(data)))
        operation = self.operation(target, data, transition)
        self.admit_token_batch(action_class, [operation], [hex_bytes(data)])
        return self.govern(action_class, [operation], [hex_bytes(data)])

    def publication(self, pointer, digest, *, collection_metadata=None, modules=None):
        name = "StreamSystemManifest"; current = self.call(name, "streamSystemManifest")
        old_pointer, = self.call(name, "streamSystemManifestPointer")
        target = self.addresses[name]
        # Use the exact domain bytes already exercised by the foundation helper.
        scope = h(("bytes32", "uint256", "address"),
            ("0xf73b4d7b4d260fce0823707f836fdf29a1767a2a2a9cfbce14ec8c5e49e47841", 31337, target))
        old_modules = h(("address",) * 11, current[2:13]); discovery = h(("bytes32",) * 7, current[13:20])
        next_modules = list(current[2:13]) if modules is None else list(modules)
        if collection_metadata is not None: next_modules[2] = collection_metadata
        def state(hash_, uri, carrier, revision, module_hash):
            return h(("bytes32", "bytes32", "bytes32", "bytes32", "address", "bytes32", "bytes32", "uint64"),
                ("0x3764ccb415d0aac07f1bddb8d4841ad6d4c2f9b2fe7ce7d221c586bc056aaf60", scope,
                 hash_, keccak256(uri.encode()), carrier, module_hash, discovery, revision))
        uri = "urn:stream:local-token:actual-selection"
        data = self.data(name, "publishStreamSystemManifest", (pointer, (digest, uri, *current[13:20])))
        return self.operation(target, data, (scope,
            state(current[0], current[1], old_pointer, current[20], old_modules),
            state(digest, uri, pointer, current[20] + 1, h(("address",) * 11, next_modules)))), hex_bytes(data)

    def token_interface_id(self, name):
        artifact = self.products[name]
        node = next(node for node in artifact["ast"]["nodes"] if node.get("nodeType") == "ContractDefinition" and node["name"] == name)
        result = 0
        for row in node["nodes"]:
            if row.get("nodeType") == "FunctionDefinition" and row.get("kind") == "function":
                require("functionSelector" in row, "pinned interface function selector absent")
                result ^= int(row["functionSelector"], 16)
        require(result != 0, "empty module interface")
        return "0x" + result.to_bytes(4, "big").hex()

    def _register_token_module(self, name, kind, interface_name):
        registry, target = self.addresses["StreamModuleRegistry"], self.addresses[name]
        interface = self.token_interface_id(interface_name)
        require(self.read(target, "supportsInterface(bytes4)", ("bytes4",), (interface,), ("bool",)) == (True,),
            "module does not support pinned interface: " + name)
        module_type = schema_id(kind); version = schema_id("local token graph module v1")
        uri = "urn:stream:local-token:module"; module_hash = schema_id("local token graph " + name)
        # Products with a native module identity retain their exact constructor commitments.
        if any(row.get("name") == "streamModuleType" for row in self.products[name]["abi"]):
            require(self.call(name, "streamModuleType") == (module_type,), "native module type differs")
            version, = self.call(name, "streamModuleVersion")
            actual_interface, = self.call(name, "streamModuleInterfaceId")
            require(actual_interface == interface, "native module interface differs")
            uri, module_hash = self.call(name, "streamModuleManifest")
        runtime = keccak256(hex_bytes(self.rpc("eth_getCode", [target, "latest"])))
        item = (target, module_type, version, interface, 2000000, runtime, self.deployment, module_hash, uri)
        chain, count = self.call("StreamModuleRegistry", "registrationChainHash")
        record_hash = h(("bytes32", "address", "bytes32", "bytes4", "bytes32", "bytes32", "bytes32", "bytes32"),
            (schema_id("6529STREAM_MODULE_REGISTRATION_RECORD_V1"), target, module_type, interface, version, runtime, self.deployment, module_hash))
        next_chain = h(("bytes32", "uint256", "address", "uint256", "bytes32", "bytes32", "bytes32", "uint64"),
            (schema_id("6529STREAM_RECORD_CHAIN_V1"), 31337, registry, 0, schema_id("MODULE_REGISTRATION"), chain, record_hash, count))
        fields = ("uint8", "bytes32", "bytes32", "bytes4", "uint32", "bytes32", "bytes32", "bytes32", "bytes32", "uint64")
        empty = h(fields, (0, ZERO, ZERO, "0x00000000", 0, ZERO, ZERO, ZERO, keccak256(b""), 0))
        facts = h(fields, (1, module_type, version, interface, 2000000, runtime, self.deployment, module_hash, keccak256(uri.encode()), 1))
        scope = h(("bytes32", "uint256", "address", "address"), (schema_id("6529STREAM_MODULE_REGISTRATION_SCOPE_V1"), 31337, registry, target))
        fields = ("bytes32", "bytes32", "bool", "bytes32", "uint256", "bytes32", "uint64", "address")
        old = h(fields, (schema_id("6529STREAM_MODULE_REGISTRATION_STATE_V1"), scope, False, empty, count, chain, count, ZERO_ADDRESS))
        new = h(fields, (schema_id("6529STREAM_MODULE_REGISTRATION_STATE_V1"), scope, True, facts, count + 1, next_chain, count + 1, target))
        self.govern_configuration("StreamModuleRegistry", "registerModule", (item,), (scope, old, new))
        return item

    def select_token_modules(self, rows):
        positions = {"ROYALTY_RESOLVER": 0, "METADATA_ROUTER": 1, "COLLECTION_METADATA": 2,
            "ENTROPY_COORDINATOR": 3, "MINT_MANAGER": 4, "MINT_LEDGER": 5, "ARTIST_REGISTRY": 6,
            "ARTWORK_FINALITY_REGISTRY": 8, "STATE_EXPORT_PUBLISHER": 10}
        modules = list(self.call("StreamSystemManifest", "streamSystemManifest")[2:13])
        calls, datas, expected = [], [], []
        core, registry = self.addresses["StreamCore"], self.addresses["StreamModuleRegistry"]
        for row in rows:
            name, kind, interface_name, *pointer_name = row
            pointer_type = (pointer_name[0] if pointer_name and pointer_name[0] is not None else kind)
            item = self._register_token_module(name, kind, interface_name)
            type_hash = schema_id(pointer_type); previous = self.call("StreamCore", "getSatellitePointer", (type_hash,))
            candidate = (item[0], item[5], False, item[1], item[3], registry, 1, item[7], self.deployment, previous[-1] + 1)
            scope = h(("bytes32", "uint256", "address", "bytes32"),
                ("0xf4a381d3d4c51db07c19830799ea01c544326118ea1db1fb59d54af5f637bdbb", 31337, core, type_hash))
            old, = self.call("StreamCoreExternalReads", "pointerStateHash", (scope, previous, previous[-1]))
            new, = self.call("StreamCoreExternalReads", "pointerStateHash", (scope, candidate, candidate[-1]))
            data = self.data("StreamCore", "updateSatellitePointer", (type_hash, item[0]))
            calls.append(self.operation(core, data, (scope, old, new))); datas.append(hex_bytes(data))
            require(pointer_type in positions, "unsupported token capture manifest pointer")
            modules[positions[pointer_type]] = item[0]; expected.append((type_hash, candidate))
        pointer, digest = self.manifest_payload(dumps({"purpose": "new local token graph actual module selection", "modules": modules}))
        tail, tail_data = self.publication(pointer, digest, modules=modules)
        calls.append(tail); datas.append(tail_data)
        self.admit_token_batch(3, calls, datas)
        self.govern(3, calls, datas)
        for type_hash, value in expected:
            require(self.call("StreamCore", "getSatellitePointer", (type_hash,)) == value, "actual token module selection differs")

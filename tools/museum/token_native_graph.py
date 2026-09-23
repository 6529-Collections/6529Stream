"""Bounded original Artist/finality graph for an isolated token media capture.

This is an RPC port of the pinned current-stack constructor recipe. It creates
native products and one-use CREATE slots; it never changes code/storage, selects
Core authorities, installs policy overrides, or claims the new graph accepted.
The caller supplies the actual governance foundation and performs its real
pointer/manifest selection between the two public methods.
"""
import hashlib
import json
from pathlib import Path

from .canonical import hex_bytes, keccak256, schema_id
from .chain_abi import decode, encode
from .current_native_fixture import abi_kind, patch_links
from .current_rights_capture import create_address
from .independent_wire import ZERO, require


TOKEN_GRAPH_PRODUCTS = tuple("""
StreamMintLedger StreamMintManager StreamAssetPolicyRegistry StreamSplitFactory
StreamArtistRegistryValidatorBase StreamArweaveCheckpointVerifier StreamArchivalCoverage
StreamDeploymentSlot StreamArtistExtensionFactory StreamArtistOnboardingRegistry
StreamArtistRegistryWriterExtension StreamArtistRegistryReadExtension StreamArtistRegistryFinalityReadExtension
StreamArtistArchiveV2 StreamArtistBindingLifecycle StreamArtistCollaboratorLifecycle
StreamArtistIdentityAuthority StreamArtistIdentityWriterExtension StreamArtistIdentityEstateExtension
StreamArtistIdentityRecoveryExtension StreamArtistAcceptanceLifecycle StreamArtistAttributionLifecycle
StreamArtistPayoutLifecycle StreamArtistConsentFinalityLifecycle StreamMetadataRouter
StreamRevenueResolver StreamRoyaltyResolver StreamCollectionMetadataV1 StreamSchemaDocumentStore
StreamCollectionTokenInventory StreamFinalityScopeMembership StreamFinalityCoordinatorInventory
StreamFinalityEntropySourceFactory StreamOnchainContentCheckpoint StreamFinalityArtifactCoverage
StreamContentLeafManifest StreamArweaveObjectCheckpointVerifier StreamExternalArtifactCoverage
StreamCollectionSnapshots StreamReferenceRenderPublication StreamReferenceRendererCatalog
StreamFinalityNativeEvidenceProvider StreamCoreFinalityAdapter StreamFinalityServingHostAdapter
StreamFinalityCurrentDiscovery StreamArtworkFinalityRegistry StreamArtistOnboardingCoordinator
StreamArtistOnboardingReads StreamWorkRecordSelection StreamRightsRecordSelection
StreamConservationRecordSelection StreamRenderCriticalInventory StreamBundleArchiveCoverage
""".split())
TOKEN_GRAPH_DECLARATIONS = (
    "StreamModuleBase", "StreamGasParameterHost", "StreamArtistOwner", "StreamFinalityRouterEvidenceProvider",
)
LATE_PRODUCTS = (
    "StreamFinalityNativeEvidenceProvider", "StreamCoreFinalityAdapter", "StreamFinalityCurrentDiscovery",
    "StreamArtworkFinalityRegistry", "StreamWorkRecordSelection", "StreamRightsRecordSelection",
    "StreamConservationRecordSelection", "StreamRenderCriticalInventory", "StreamBundleArchiveCoverage",
)
COORDINATOR = "StreamArtistOnboardingCoordinator"
METADATA = "StreamCollectionMetadataV1"
FACADE = "StreamArtistOnboardingRegistry"
FINALITY = "StreamArtworkFinalityRegistry"
PROVIDER = "StreamFinalityNativeEvidenceProvider"
FINALITY_URI = "https://engineering.example.invalid/6529stream/current/finality"
FINALITY_HASH = schema_id("current-stack native finality module v1")
RENDERER_CATALOG_ID = schema_id("STREAM_CURRENT_REFERENCE_RENDERER_CLASS_V1")


def _word(value):
    if type(value) is int:
        require(0 <= value < 2**256, "graph immutable integer bound")
        return value.to_bytes(32, "big")
    raw = hex_bytes(value)
    require(len(raw) in (20, 32), "graph immutable word width")
    return raw.rjust(32, b"\0")


def _immutable_ids(artifact, declaration, variable):
    contracts = [n for n in artifact["ast"]["nodes"]
                 if n.get("nodeType") == "ContractDefinition" and n.get("name") == declaration]
    require(len(contracts) == 1, "graph immutable declaration missing: " + declaration)
    rows = [n for n in contracts[0]["nodes"] if n.get("nodeType") == "VariableDeclaration"
            and n.get("name") == variable and n.get("mutability") == "immutable"]
    require(len(rows) == 1, "graph immutable variable missing: " + declaration + "." + variable)
    return str(rows[0]["id"])


def predicted_runtime(products, name, linked_runtime, values, *, declaration_ids=None):
    """Patch every compiler-declared immutable exactly once from pinned AST IDs."""
    positions = products[name]["deployedBytecode"].get("immutableReferences", {})
    assigned = {}
    for (declaration, variable), value in values.items():
        require(declaration in products, "graph immutable declaration artifact absent")
        identifier = (declaration_ids or {}).get((declaration, variable))
        if identifier is None:
            identifier = _immutable_ids(products[declaration], declaration, variable)
        require(identifier not in assigned, "duplicate graph immutable assignment")
        assigned[identifier] = _word(value)
    require(set(assigned) == set(positions), "graph immutable assignment inventory differs: " + name)
    raw = bytearray(linked_runtime)
    used = set()
    for identifier, rows in positions.items():
        require(rows, "empty graph immutable positions")
        for row in rows:
            start, length = row["start"], row["length"]
            require(type(start) is int and length == 32 and 0 <= start <= len(raw)-length,
                    "graph immutable offset invalid")
            span = set(range(start, start+length))
            require(not used & span, "graph immutable patches overlap")
            used |= span
            raw[start:start+length] = assigned[identifier]
    require(0 < len(raw) <= 24576, "predicted graph runtime size")
    return bytes(raw)


class TokenNativeGraphMixin:
    """Requires CurrentRightsFixture's native RPC, linking and factory helpers."""

    def _load_token_graph_projection(self):
        """Join compilation-local AST IDs by exact pinned bytecode and offset groups.

        Foundry's incremental native exports can retain identical executable
        templates with different compilation-local inherited AST identifiers.
        The accepted graph projection retains declarations from its complete
        compiler input. It supplies metadata only, never replacement bytecode.
        """
        pin = self.manifest.get("graphImmutableProjection")
        require(isinstance(pin, dict) and set(pin) == {"directory", "manifestSha256"},
                "token graph immutable projection pin missing")
        directory = Path(pin["directory"])
        raw = (directory / "manifest.json").read_bytes()
        require(len(raw) <= 1048576 and hashlib.sha256(raw).hexdigest() == pin["manifestSha256"],
                "token graph projection manifest hash differs")
        manifest = json.loads(raw)
        require(manifest["artifactInputKind"] == "current-native-export", "graph projection source kind differs")
        # Only these two native hosts need inherited IDs from the retained
        # graph compilation. Every other product uses its own pinned native
        # AST; a different projection template is never silently substituted.
        names = {"StreamModuleBase", "StreamGasParameterHost", "StreamArtistOwner", FACADE, "StreamArtistIdentityAuthority"}
        projected = {}
        declarations = {}
        projected_contexts = {}
        require("mode" not in manifest or manifest["mode"] == "explicit-native-owners",
                "unsupported graph projection owner mode")
        explicit_owners = manifest.get("mode") == "explicit-native-owners"
        for name in sorted(names):
            row = manifest["products"][name]
            if explicit_owners:
                owner = row["owner"]
                context = manifest["contexts"][owner]
                coordinate = row["source"] + ":" + name
                require(manifest["owners"][coordinate] == owner
                        and context["artifactInputKind"] == "current-native-export",
                        "graph projection product owner differs: " + name)
                original = context["products"][name]
                require(all(row[key] == original[key] for key in
                            ("source", "projectionBytes", "projectionSha256")),
                        "graph projection owner row differs: " + name)
                require(self.manifest["products"][name]["sha256"] == original["currentNativeExportSha256"],
                        "graph native export owner differs: " + name)
                compilation = context["compilerInputSha256"]
            else:
                compilation = manifest["compilerInputSha256"]
                owner = compilation
            projected_contexts[name] = owner
            raw = (directory / (name + ".json")).read_bytes()
            require(len(raw) == row["projectionBytes"] <= 1048576
                    and hashlib.sha256(raw).hexdigest() == row["projectionSha256"], "graph projection file differs: " + name)
            value = json.loads(raw)
            require(value["contractName"] == name and value["source"] == self.manifest["products"][name]["source"]
                    and row["source"] == value["source"] and value["compilationHash"] == compilation,
                    "graph projection compilation identity differs")
            if explicit_owners:
                require(value["currentNativeExportSha256"] == original["currentNativeExportSha256"]
                        and value["deployedBytecode"].get("immutableReferences", {})
                            == self.products[name]["deployedBytecode"].get("immutableReferences", {}),
                        "graph same-owner immutable references differ: " + name)
            for field in ("bytecode", "deployedBytecode"):
                native = self.products[name][field]
                require(value[field]["object"] == native["object"]
                        and value[field]["linkReferences"] == native["linkReferences"],
                        "graph projection executable template differs: " + name)
            for identifier, declaration in value["immutableDeclarations"].items():
                require(str(declaration["id"]) == identifier and declaration["contractName"] == name
                        and declaration["source"] == value["source"] and declaration["compilationHash"] == value["compilationHash"]
                        and declaration["nodeType"] == "VariableDeclaration" and declaration["mutability"] == "immutable",
                        "graph projected immutable declaration differs")
                key = (owner, (name, declaration["variable"]))
                require(key not in declarations, "duplicate projected immutable declaration")
                declarations[key] = identifier
            projected[name] = value
        self.token_declaration_ids = {}
        for name, projection in projected.items():
            native = self.products[name]["deployedBytecode"].get("immutableReferences", {})
            def offsets(rows):
                return tuple(sorted((row["start"], row["length"]) for row in rows))
            native_offsets = {offsets(rows): identifier for identifier, rows in native.items()}
            require(len(native_offsets) == len(native), "graph native immutable groups overlap")
            projected_offsets = {offsets(rows): identifier for identifier, rows in projection["deployedBytecode"].get("immutableReferences", {}).items()}
            require(len(projected_offsets) == len(projection["deployedBytecode"].get("immutableReferences", {}))
                    and set(projected_offsets) == set(native_offsets), "graph projected immutable offset groups differ: " + name)
            translated = {identifier: native_offsets[positions] for positions, identifier in projected_offsets.items()}
            self.token_declaration_ids[name] = {key: translated[identifier]
                for (owner, key), identifier in declarations.items()
                if owner == projected_contexts[name] and identifier in translated}
            if explicit_owners:
                resolved = self.token_declaration_ids[name]
                require(len(resolved) == len(native) and set(resolved.values()) == set(native),
                        "graph same-owner declaration closure differs: " + name)
        self.token_projection_sha256 = pin["manifestSha256"]

    def _graph_address(self, name):
        return self.token_reserved.get(name, self.addresses.get(name))

    def _graph_codehash(self, name):
        address = self._graph_address(name)
        require(address is not None, "unbound graph dependency: " + name)
        raw = hex_bytes(self.rpc("eth_getCode", [address, "latest"]))
        prediction = self.token_predicted.get(name)
        if prediction is not None:
            require(not raw or raw == prediction, "graph predicted runtime changed: " + name)
            return keccak256(prediction)
        require(0 < len(raw) <= 24576, "graph dependency runtime absent/oversized: " + name)
        return keccak256(raw)

    def _graph_targets(self, names):
        return tuple(self._graph_address(n) for n in names), tuple(self._graph_codehash(n) for n in names)

    def _graph_call_at(self, product, address, function, values=()):
        _, _, outputs = self.function(product, function)
        raw = self.rpc("eth_call", [{"to": address, "data": self.data(product, function, values)}, "latest"])
        return decode(outputs, hex_bytes(raw), maximum=1048576)

    def _graph_linked(self, name, field):
        def resolve(source, library):
            require(self.manifest["products"].get(library, {}).get("source") == source,
                    "graph library source mismatch")
            require(library in self.addresses, "graph linked library not deployed: " + library)
            return self.addresses[library]
        row = self.products[name][field]
        return patch_links(row["object"], row["linkReferences"], resolve)

    def _graph_initcode(self, name, values):
        creation, links = self._graph_linked(name, "bytecode")
        rows = [r for r in self.products[name]["abi"] if r["type"] == "constructor"]
        require(len(rows) <= 1, "duplicate graph constructor")
        kinds = tuple(abi_kind(c) for c in rows[0].get("inputs", [])) if rows else ()
        arguments = encode(kinds, values)
        require(len(creation + arguments) <= 49152, "graph initcode exceeds native bound")
        return creation + arguments, arguments, links

    def _graph_record(self, name, address, *, instance=None, expected=None, extra=None):
        key = instance or name
        require(key not in self.addresses and key not in self.artifact_rows, "graph instance reused: " + key)
        actual = hex_bytes(self.rpc("eth_getCode", [address, "latest"]))
        template, links = self._graph_linked(name, "deployedBytecode")
        require(0 < len(actual) == len(template) <= 24576, "graph runtime size differs: " + key)
        patches, values = set(), {}
        for identifier, rows in self.products[name]["deployedBytecode"].get("immutableReferences", {}).items():
            observed = set()
            for row in rows:
                start, length = row["start"], row["length"]
                require(type(start) is int and length == 32 and 0 <= start <= len(actual)-length,
                        "graph runtime immutable offset")
                span = set(range(start, start+length))
                require(not span & patches, "graph runtime immutable overlap")
                patches |= span
                observed.add(actual[start:start+length])
            require(len(observed) == 1, "graph runtime immutable occurrences differ")
            values[identifier] = "0x" + next(iter(observed)).hex()
        require(all(a == b or i in patches for i, (a, b) in enumerate(zip(actual, template))),
                "graph runtime differs outside compiler immutables: " + key)
        if expected is not None:
            require(actual == expected, "complete predicted graph runtime differs: " + key)
        self.addresses[key] = address
        self.artifact_rows[key] = self.manifest["products"][name] | {
            "productName": name, "instanceName": key, "address": address,
            "runtimeHash": keccak256(actual), "runtimeBytes": str(len(actual)),
            "runtimeLinks": links, "immutableValues": values,
        } | (extra or {})
        return address

    def deploy_graph_product(self, name, values=(), *, instance=None):
        """A distinct native CREATE; repeated artifacts need explicit instance names."""
        key = instance or name
        require(key not in self.addresses, "graph instance already deployed: " + key)
        initcode, arguments, links = self._graph_initcode(name, values)
        receipt = self.send("0x" + initcode.hex())
        return self._graph_record(name, receipt["contractAddress"], instance=key, extra={
            "constructorArgumentsHex": "0x" + arguments.hex(), "links": links,
            "creationHash": keccak256(initcode), "deploymentTransactionHash": receipt["transactionHash"],
        })

    def _graph_predict(self, name, own=None, inherited=None):
        values = {(name, key): value for key, value in (own or {}).items()} | (inherited or {})
        runtime, _ = self._graph_linked(name, "deployedBytecode")
        result = predicted_runtime(self.products, name, runtime, values,
            declaration_ids=getattr(self, "token_declaration_ids", {}).get(name))
        self.token_predicted[name] = result
        return result

    def _graph_slot(self, product):
        require(product not in self.token_slots and product not in self.addresses, "graph reservation reused")
        key = "StreamDeploymentSlot:" + product
        slot = self.deploy_graph_product("StreamDeploymentSlot", (self.account,), instance=key)
        expected = create_address(slot, 1)
        require(self._graph_call_at("StreamDeploymentSlot", slot, "product") == (expected,)
                and self._graph_call_at("StreamDeploymentSlot", slot, "operator") == (self.account,)
                and self._graph_call_at("StreamDeploymentSlot", slot, "consumed") == (False,)
                and int(self.rpc("eth_getTransactionCount", [slot, "latest"]), 16) == 1
                and self.rpc("eth_getCode", [expected, "latest"]) == "0x", "original fresh CREATE slot differs")
        require(expected not in self.token_reserved.values(), "duplicate graph reserved address")
        self.token_slots[product] = slot
        self.token_reserved[product] = expected
        return expected

    def _graph_fill_slot(self, name, values):
        slot, expected = self.token_slots[name], self.token_reserved[name]
        require(name in self.token_predicted, "graph slot needs complete predicted runtime")
        runtime = self.token_predicted[name]
        require(self._graph_call_at("StreamDeploymentSlot", slot, "operator") == (self.account,)
                and self._graph_call_at("StreamDeploymentSlot", slot, "product") == (expected,)
                and self._graph_call_at("StreamDeploymentSlot", slot, "consumed") == (False,)
                and int(self.rpc("eth_getTransactionCount", [slot, "latest"]), 16) == 1
                and self.rpc("eth_getCode", [expected, "latest"]) == "0x", "original unconsumed graph slot changed")
        initcode, arguments, links = self._graph_initcode(name, values)
        receipt = self.send(self.data("StreamDeploymentSlot", "deploy", (initcode, keccak256(runtime))), slot)
        require(self._graph_call_at("StreamDeploymentSlot", slot, "consumed") == (True,)
                and int(self.rpc("eth_getTransactionCount", [slot, "latest"]), 16) == 2,
                "graph slot did not perform one original CREATE")
        return self._graph_record(name, expected, expected=runtime, extra={
            "constructorArgumentsHex": "0x" + arguments.hex(), "links": links,
            "creationHash": keccak256(initcode), "createSlot": slot,
            "deploymentTransactionHash": receipt["transactionHash"],
        })

    def _graph_extension(self, name, kind, pins, *, identity=False):
        factory = "StreamArtistExtensionFactory"
        method = "deployIdentity" if identity else "deployRegistry"
        arguments = (kind, pins) if identity else (kind, *pins)
        child, = self.call(factory, method, arguments)
        receipt = self.transact(factory, method, arguments)
        binding_method = "identityBinding" if identity else "registryBinding"
        binding, = self.call(factory, binding_method, arguments)
        # Independently bind the original factory receipt to its exact constructor pins.
        kinds = ("bytes32", "uint256", "uint8", ("address",)*6) if identity else (
            "bytes32", "uint256", "uint8", "address", "address")
        values = (schema_id("6529STREAM_ARTIST_EXTENSION_BIRTH_V1"), self.token_chain_id, kind, pins) if identity else (
            schema_id("6529STREAM_ARTIST_EXTENSION_BIRTH_V1"), self.token_chain_id, kind, *pins)
        require(binding == keccak256(encode(kinds, values)), "graph extension binding preimage differs")
        runtime = keccak256(hex_bytes(self.rpc("eth_getCode", [child, "latest"])))
        require(self.call(factory, "birth", (child,)) == ((kind, pins[0], self.token_chain_id, binding, runtime),),
                "actual graph factory birth differs")
        return self._graph_record(name, child, extra={"factory": self.addresses[factory],
            "factoryBindingHash": binding, "deploymentTransactionHash": receipt["transactionHash"]})

    def build_token_artist_graph(self):
        require(not hasattr(self, "token_suite"), "token graph phase one already started")
        self.token_slots, self.token_reserved, self.token_predicted = {}, {}, {}
        self.token_chain_id = int(self.rpc("eth_chainId", []), 16)
        require(self.token_chain_id == 31337, "token graph is isolated local evidence only")
        require(set(TOKEN_GRAPH_PRODUCTS + TOKEN_GRAPH_DECLARATIONS) <= self.products.keys(), "token graph pinned product closure incomplete")
        self._load_token_graph_projection()
        self.deploy_library_closure(TOKEN_GRAPH_PRODUCTS)
        core, executor, roles, modules = (self.addresses[n] for n in (
            "StreamCore", "StreamGovernanceExecutor", "StreamRoleRegistry", "StreamModuleRegistry"))
        deploy = self.deploy_graph_product
        ledger = deploy("StreamMintLedger")
        manager = deploy("StreamMintManager", (core, ledger, modules))
        self.transact("StreamMintLedger", "setLedgerWriter", (manager, True))
        asset = deploy("StreamAssetPolicyRegistry", (executor,))
        splits = deploy("StreamSplitFactory", (asset, executor, (
            ("ERC_1271_GAS_LIMIT", 400000, 350000, 2), ("ASSET_POLICY_GAS_LIMIT", 30000, 15000, 2),
            ("WALLET_DEPOSIT_GAS_LIMIT", 200000, 25000, 2))))
        validator = deploy("StreamArtistRegistryValidatorBase")
        observers = tuple(sorted((
            (self.safe(1751), schema_id("explicit local token observer organization one")),
            (self.safe(1752), schema_id("explicit local token observer organization two")),
        )))
        signature = ("ARCHIVAL_ERC1271_VERIFY_GAS", 400000, 90000, 2)
        checkpoint = deploy("StreamArweaveCheckpointVerifier", (executor, observers, 2, signature))
        coverage = deploy("StreamArchivalCoverage", (core, executor, roles, checkpoint, signature,
            ("ARCHIVAL_DEPENDENCY_READ_GAS", 150000, 50000, 2)))
        coordinator = self._graph_slot(COORDINATOR)
        factory = deploy("StreamArtistExtensionFactory")
        facade = self._graph_slot(FACADE)
        children = tuple(self._graph_extension(name, i+4, (facade, coordinator)) for i, name in enumerate((
            "StreamArtistRegistryWriterExtension", "StreamArtistRegistryReadExtension", "StreamArtistRegistryFinalityReadExtension")))
        coverage_binding, = self.call("StreamArtistEstateCoverage", "admit", (core, manager, executor, coverage))
        self._graph_predict(FACADE, {
            "core": core, "mintManager": manager, "operationCoordinator": coordinator,
            "registryWriterExtension": children[0], "registryReadExtension": children[1],
            "registryFinalityReadExtension": children[2], "archivalCoverage": coverage,
            "archivalCoverageCodeHash": self._graph_codehash("StreamArchivalCoverage"),
            "archivalCoverageConfigurationHash": coverage_binding,
        }, {("StreamGasParameterHost", "governanceAuthority"): executor,
            ("StreamModuleBase", "_schemaHash"): schema_id("6529stream.artist-onboarding.v1"),
            ("StreamModuleBase", "_supersedes"): ZERO,
            ("StreamModuleBase", "_deploymentManifestHash"): self.deployment,
            ("StreamModuleBase", "_manifestHash"): schema_id("fixture artist module")})
        self._graph_fill_slot(FACADE, (core, manager, coordinator, executor, coverage, self.deployment,
            "urn:6529stream:fixture:artist", schema_id("fixture artist module"), factory, children))
        archive = deploy("StreamArtistArchiveV2", (facade, coordinator))
        owner_args = (facade, coordinator, archive, core, manager)
        owner_names = ("StreamArtistBindingLifecycle", "StreamArtistCollaboratorLifecycle", "StreamArtistIdentityAuthority",
            "StreamArtistAcceptanceLifecycle", "StreamArtistAttributionLifecycle", "StreamArtistPayoutLifecycle", "StreamArtistConsentFinalityLifecycle")
        owners = []
        for name in owner_names:
            if name != "StreamArtistIdentityAuthority":
                owners.append(deploy(name, owner_args)); continue
            identity = self._graph_slot(name)
            pins = (identity, *owner_args)
            children = tuple(self._graph_extension(child, i+1, pins, identity=True) for i, child in enumerate((
                "StreamArtistIdentityWriterExtension", "StreamArtistIdentityEstateExtension", "StreamArtistIdentityRecoveryExtension")))
            authority, = self.call("StreamArtistTimingState", "canonicalAuthority", (core, manager))
            require(authority == executor, "original identity canonical authority differs")
            self._graph_predict(name, {"artistWindowAuthority": authority, "identityWriterExtension": children[0],
                "identityEstateExtension": children[1], "identityRecoveryExtension": children[2]},
                {("StreamArtistOwner", key): value for key, value in {
                    "artistRegistry": facade, "operationCoordinator": coordinator, "archiveV2": archive,
                    "core": core, "mintManager": manager, "deploymentChainId": self.token_chain_id,
                    "domainId": schema_id("domain:identity_authority")}.items()})
            owners.append(self._graph_fill_slot(name, (*owner_args, factory, children)))
        router = deploy("StreamMetadataRouter", (core, executor, self.deployment,
            "https://engineering.example.invalid/6529stream/fixture/router", schema_id("fixture metadata module"), facade))
        primary = deploy("StreamRevenueResolver", (core, splits, executor, facade,
            ("ARTIST_BENEFICIARY_READ_GAS", 200000, 50000, 2)))
        royalties = deploy("StreamRoyaltyResolver", (core, splits, executor, facade))
        self.token_suite = (facade, archive, tuple(owners), core, manager, roles, router, primary, royalties,
            schema_id("PRIMARY_SALE"), validator)
        require(self.addresses["StreamSchemaRegistry"] == self.schemas, "original schema host differs")
        if "StreamSchemaDocumentStore" not in self.addresses:
            self._graph_record("StreamSchemaDocumentStore", self.store)
        require(self.call("StreamSchemaRegistry", "chunkStore") == (self.store,), "original schema store differs")
        deploy(METADATA, ((core, executor, self.schemas, facade, self.deployment,
            "https://engineering.example.invalid/6529stream/current/metadata", schema_id("current-stack collection metadata module v1"),
            ("METADATA_DEPENDENCY_READ_GAS", 400000, 50000, 1), ("METADATA_ARTIST_READ_GAS", 12000000, 50000, 1)),))
        self._build_token_graph_prerequisites(observers)
        return self.token_suite

    def _build_token_graph_prerequisites(self, observers):
        for name in LATE_PRODUCTS: self._graph_slot(name)
        deploy, addr = self.deploy_graph_product, self._graph_address
        core, executor = addr("StreamCore"), addr("StreamGovernanceExecutor")
        tokens = deploy("StreamCollectionTokenInventory", (core, executor, ("TOKEN_INVENTORY_CORE_READ_GAS", 150000, 50000, 1)))
        membership = deploy("StreamFinalityScopeMembership", (core, addr(METADATA), tokens, executor,
            ("SCOPE_MEMBERSHIP_READ_GAS", 500000, 50000, 1)))
        deploy("StreamFinalityCoordinatorInventory", (core, membership, 150000, 2000000))
        targets, hashes = self._graph_targets(("StreamCore", METADATA, "StreamFinalityScopeMembership", "StreamFinalityCoordinatorInventory"))
        deploy("StreamFinalityEntropySourceFactory", ((targets, hashes, self.token_chain_id, 150000, 3000000),))
        checkpoint = deploy("StreamOnchainContentCheckpoint", (core, addr("StreamMetadataRouter"), tokens, executor,
            ("CONTENT_CHECKPOINT_READ_GAS", 500000, 50000, 1), ("CONTENT_CHECKPOINT_RENDER_GAS", 3000000, 50000, 1)))
        artifact = deploy("StreamFinalityArtifactCoverage", (core, addr("StreamArchivalCoverage"), self.schemas, self.store,
            addr(FINALITY), executor, ("FINALITY_ARTIFACT_DEPENDENCY_READ_GAS", 500000, 300000, 2)))
        deploy("StreamContentLeafManifest", (core, checkpoint, artifact, executor, ("CONTENT_LEAF_MANIFEST_READ_GAS", 1000000, 50000, 2)))
        verifier = deploy("StreamArweaveObjectCheckpointVerifier", (executor, observers, 2, ("ARCHIVAL_ERC1271_VERIFY_GAS", 400000, 90000, 2)))
        deploy("StreamExternalArtifactCoverage", (core, executor, addr("StreamRoleRegistry"), verifier,
            ("EXTERNAL_ARCHIVE_READ_GAS", 500000, 150000, 2), ("EXTERNAL_ARCHIVE_SIGNATURE_GAS", 400000, 90000, 2)))

    def _require_token_graph_selections(self):
        for key, name, frozen in (
            ("MODULE_REGISTRY", "StreamModuleRegistry", False),
            ("SYSTEM_MANIFEST", "StreamSystemManifest", True),
            ("COLLECTION_METADATA", METADATA, False),
            ("METADATA_ROUTER", "StreamMetadataRouter", False),
            ("ARTIST_REGISTRY", FACADE, False),
        ):
            pointer = self.call("StreamCore", "getSatellitePointer", (schema_id(key),))
            require(pointer[0] == self.addresses[name] and pointer[1] == self._graph_codehash(name)
                    and pointer[6] == 1 and (not frozen or pointer[2]),
                    "actual governance graph selection differs: " + key)

    def token_graph_renderer_catalog(self):
        result, = self.call("StreamMetadataRouter", "collectionServingFacts", (1,))
        abi = next(row for row in self.products["StreamMetadataRouter"]["abi"]
                   if row.get("type") == "function" and row.get("name") == "collectionServingFacts")
        facts = dict(zip((r["name"] for r in abi["outputs"][0]["components"]), result))
        renderer, runtime_hash = facts["renderer"], facts["rendererCodeHash"]
        require(runtime_hash == keccak256(hex_bytes(self.rpc("eth_getCode", [renderer, "latest"])))
                and self.rpc("eth_getCode", [renderer, "latest"]) != "0x", "original linked renderer differs")
        presentation, context, dependencies = self.call("StreamMetadataRouter", "renderingProfile")
        uri, manifest = self.call("StreamMetadataRouter", "streamModuleManifest")
        version, = self.call("StreamMetadataRouter", "streamModuleVersion")
        require(uri, "original router module URI absent")
        raw, = self.call("StreamReferenceRendererCatalog", "declarationJSON", ((renderer, runtime_hash,
            version, manifest, presentation, context, dependencies, schema_id("STATIC")),))
        require(raw, "actual renderer catalog empty")
        self.token_renderer_catalog = raw
        return raw

    def _build_token_graph_source_hosts(self, catalog):
        targets, hashes = self._graph_targets(("StreamCore", METADATA, "StreamSchemaRegistry", "StreamSchemaDocumentStore",
            "StreamMetadataRouter", "StreamContentLeafManifest", "StreamOnchainContentCheckpoint",
            "StreamFinalityScopeMembership", "StreamFinalityCoordinatorInventory"))
        configs = (("SNAPSHOT_READ_GAS", 500000, 50000, 1), ("SNAPSHOT_SOURCE_GAS", 2000000, 50000, 1),
            ("SNAPSHOT_EVIDENCE_GAS", 2000000, 50000, 1), ("SNAPSHOT_INVENTORY_GAS", 3000000, 50000, 1))
        executor = self.addresses["StreamGovernanceExecutor"]
        self.deploy_graph_product("StreamCollectionSnapshots", ((targets, hashes, self.token_chain_id,
            500000, 2000000, 2000000, 3000000), executor, configs))
        targets, hashes = self._graph_targets(("StreamCore", METADATA, "StreamSchemaRegistry", "StreamSchemaDocumentStore",
            "StreamMetadataRouter", "StreamCollectionSnapshots", "StreamExternalArtifactCoverage"))
        dependencies = (targets, hashes, self.token_chain_id, RENDERER_CATALOG_ID, keccak256(catalog), len(catalog),
            500000, 4000000, 6000000, 2000000)
        configs = (("REFERENCE_READ_GAS", 500000, 50000, 1), ("REFERENCE_SOURCE_GAS", 4000000, 50000, 1),
            ("REFERENCE_SNAPSHOT_GAS", 6000000, 50000, 1), ("REFERENCE_ARCHIVE_GAS", 2000000, 50000, 1))
        self.deploy_graph_product("StreamReferenceRenderPublication", (dependencies, executor, configs))

    def _predict_token_graph_late(self):
        addr, code = self._graph_address, self._graph_codehash
        version, = self.call("StreamMetadataRouter", "streamModuleVersion")
        _, router_manifest = self.call("StreamMetadataRouter", "streamModuleManifest")
        metadata_version, = self.call(METADATA, "streamModuleVersion")
        _, metadata_manifest = self.call(METADATA, "streamModuleManifest")
        self._graph_predict(PROVIDER, {"metadataModuleVersion": metadata_version, "metadataModuleManifestHash": metadata_manifest},
            {("StreamFinalityRouterEvidenceProvider", key): value for key, value in {
                "core": addr("StreamCore"), "coreCodeHash": code("StreamCore"), "metadataHost": addr(METADATA),
                "metadataHostCodeHash": code(METADATA), "metadataRouter": addr("StreamMetadataRouter"),
                "metadataRouterCodeHash": code("StreamMetadataRouter"), "scopeMembershipHost": addr("StreamFinalityScopeMembership"),
                "scopeMembershipHostCodeHash": code("StreamFinalityScopeMembership"), "deploymentChainId": self.token_chain_id,
                "readGas": 500000, "sourceGas": 4000000, "routerModuleVersion": version,
                "routerModuleManifestHash": router_manifest}.items()})
        self._graph_predict("StreamCoreFinalityAdapter", {"core": addr("StreamCore"), "collectionMetadata": addr(METADATA),
            "evidenceProvider": addr(PROVIDER), "_coreCodeHash": code("StreamCore"), "_metadataCodeHash": code(METADATA),
            "_providerCodeHash": code(PROVIDER)})
        self._graph_predict("StreamFinalityCurrentDiscovery", {"core": addr("StreamCore"), "metadataHost": addr(METADATA),
            "scopeEvidenceProvider": addr(PROVIDER), "deploymentChainId": self.token_chain_id})
        self._graph_predict(FINALITY, {
            "coreReads": addr("StreamCore"), "coreFinalityAdapter": addr("StreamCoreFinalityAdapter"),
            "metadataReads": addr(METADATA), "scopeEvidenceProvider": addr(PROVIDER),
            "artifactCoverage": addr("StreamFinalityArtifactCoverage"), "_artifactCodeHash": code("StreamFinalityArtifactCoverage"),
            "sanctionReads": addr(FACADE), "finalityRoleRegistry": addr("StreamRoleRegistry"),
            "_executorCodeHash": code("StreamGovernanceExecutor"), "_rolesCodeHash": code("StreamRoleRegistry"),
            "_coreCodeHash": code("StreamCore"), "_metadataCodeHash": code(METADATA), "_providerCodeHash": code(PROVIDER),
            "_adapterCodeHash": code("StreamCoreFinalityAdapter"), "_discoveryCodeHash": code("StreamFinalityCurrentDiscovery"),
            "finalityDiscovery": addr("StreamFinalityCurrentDiscovery"),
        }, {("StreamGasParameterHost", "governanceAuthority"): addr("StreamGovernanceExecutor"),
            ("StreamModuleBase", "_schemaHash"): schema_id("6529stream.canonical-artwork-finality.schema.v1"),
            ("StreamModuleBase", "_supersedes"): ZERO,
            ("StreamModuleBase", "_deploymentManifestHash"): self.deployment,
            ("StreamModuleBase", "_manifestHash"): FINALITY_HASH})
        self.token_coordinator_configuration = self._token_coordinator_configuration_hash()
        self._graph_predict(COORDINATOR, {"deploymentChainId": self.token_chain_id,
            "configurationHash": self.token_coordinator_configuration,
            "reads": create_address(addr(COORDINATOR), 1), "finalityRegistry": addr(FINALITY),
            "finalityRegistryCodeHash": code(FINALITY), "finalityEvidenceProvider": addr(PROVIDER),
            "finalityEvidenceProviderCodeHash": code(PROVIDER)})
        for name in ("StreamWorkRecordSelection", "StreamRightsRecordSelection", "StreamConservationRecordSelection"):
            self._graph_predict(name, {"core": addr("StreamCore"), "metadata": addr(METADATA),
                "schemaRegistry": self.schemas, "chunkStore": self.store, "deploymentChainId": self.token_chain_id,
                "coreCodeHash": code("StreamCore"), "metadataCodeHash": code(METADATA),
                "schemaRegistryCodeHash": code("StreamSchemaRegistry"), "chunkStoreCodeHash": code("StreamSchemaDocumentStore")})
        self._graph_predict("StreamRenderCriticalInventory")
        self._graph_predict("StreamBundleArchiveCoverage")

    def _token_coordinator_configuration_hash(self):
        suite = self.token_suite
        targets = (*suite[2], suite[0], suite[1], *suite[3:9], suite[10])
        require(len(targets) == len(set(targets)) == 16, "actual suite must have sixteen distinct products")
        hashes = tuple(keccak256(hex_bytes(self.rpc("eth_getCode", [target, "latest"]))) for target in targets)
        ctor = next(row for row in self.products[COORDINATOR]["abi"] if row["type"] == "constructor")
        suite_kind = abi_kind(ctor["inputs"][0])
        operations = (*range(1, 8), *range(12, 19), *range(20, 41), 51, 52, 54, 58, 65534)
        profiles = tuple(schema_id("6529STREAM_ARTIST_" + suffix + "_PROFILE_V1") for suffix in (
            "RECOVERY_PREPARATION", "RECOVERY_GUARDIAN_HISTORY", "RECOVERY_FIRST_ROTATION", "RECOVERY_HISTORICAL_ROTATION",
            "GUARDIAN_VESTING", "GUARDIAN_SUPERSESSION", "GUARDIAN_HEAD_SELECTION", "GUARDIAN_ROOT_APPEAL",
            "FIRST_ESTATE_RECOVERY", "ESTATE_SUCCESSOR_GUARDIAN_RECOVERY"))
        kinds = ("bytes32", "uint256", "address", suite_kind, ("bytes32",)*16, "address", "bytes32", "address", "bytes32")
        values = (schema_id("6529STREAM_ARTIST_ONBOARDING_CONFIGURATION_V1"), self.token_chain_id,
            self._graph_address(COORDINATOR), suite, hashes, self._graph_address(FINALITY), self._graph_codehash(FINALITY),
            self._graph_address(PROVIDER), self._graph_codehash(PROVIDER))
        return keccak256(encode(kinds + ("uint16",)*len(operations) + ("bytes32",)*len(profiles), values + operations + profiles))

    def _token_inventory_dependencies(self):
        targets, hashes = self._graph_targets(("StreamCore", METADATA, "StreamSchemaRegistry", "StreamSchemaDocumentStore",
            "StreamMetadataRouter", "StreamCollectionSnapshots", "StreamReferenceRenderPublication", "StreamWorkRecordSelection",
            "StreamRightsRecordSelection", "StreamConservationRecordSelection", "StreamFinalityArtifactCoverage", "StreamExternalArtifactCoverage"))
        artists, artist_hashes = self._graph_targets((FACADE, COORDINATOR, "StreamArtistIdentityAuthority",
            "StreamArtistAttributionLifecycle", "StreamArtistArchiveV2"))
        return (targets, hashes, artists, artist_hashes, self._graph_address("StreamArtistConsentFinalityLifecycle"),
            self._graph_codehash("StreamArtistConsentFinalityLifecycle"), self.token_chain_id,
            500000, 4000000, 4000000, 6000000, 12000000)

    def _token_provider_configuration(self):
        targets, hashes = self._graph_targets(("StreamCore", METADATA, "StreamMetadataRouter", "StreamFinalityScopeMembership",
            "StreamSchemaRegistry", "StreamSchemaDocumentStore", "StreamContentLeafManifest", "StreamOnchainContentCheckpoint",
            "StreamCollectionSnapshots", "StreamReferenceRenderPublication", "StreamFinalityEntropySourceFactory", FACADE,
            FINALITY, "StreamFinalityCurrentDiscovery", "StreamCoreFinalityAdapter", "StreamWorkRecordSelection",
            "StreamRightsRecordSelection", "StreamConservationRecordSelection", "StreamRenderCriticalInventory", "StreamBundleArchiveCoverage",
            "StreamFinalityArtifactCoverage", "StreamExternalArtifactCoverage"))
        ctor = next(row for row in self.products["StreamRenderCriticalInventory"]["abi"] if row["type"] == "constructor")
        kind = abi_kind(ctor["inputs"][0])
        dependency_hash = keccak256(encode((kind,), (self._token_inventory_dependencies(),)))
        return targets, hashes, self.token_chain_id, 500000, 16000000, 4000000, dependency_hash

    def complete_token_artist_graph(self):
        require(hasattr(self, "token_suite") and COORDINATOR not in self.addresses, "token graph phase two state differs")
        self._require_token_graph_selections()
        catalog = self.token_graph_renderer_catalog()
        self._build_token_graph_source_hosts(catalog)
        self._predict_token_graph_late()
        addr, fill, deploy = self._graph_address, self._graph_fill_slot, self.deploy_graph_product
        configuration = self._token_provider_configuration()
        fill(PROVIDER, (configuration,))
        fill("StreamCoreFinalityAdapter", (addr("StreamCore"), addr(METADATA), addr(PROVIDER)))
        families = ("METADATA_ROUTER", "RENDERER", "RENDER_CONTEXT", "MEDIA_MANIFEST", "SCRIPT_SOURCE", "DEPENDENCY_SOURCE")
        adapters = tuple(deploy("StreamFinalityServingHostAdapter", (addr("StreamCore"), addr("StreamMetadataRouter"),
            addr(PROVIDER), schema_id(family)), instance="StreamFinalityServingHostAdapter:" + family) for family in families)
        metadata_adapter = deploy("StreamFinalityServingHostAdapter", (addr("StreamCore"), addr(METADATA), addr(PROVIDER),
            schema_id("COLLECTION_METADATA")), instance="StreamFinalityServingHostAdapter:COLLECTION_METADATA")
        discovery = (addr("StreamCore"), addr(METADATA), addr("StreamMetadataRouter"), addr(PROVIDER),
            addr("StreamFinalityScopeMembership"), addr("StreamFinalityEntropySourceFactory"), metadata_adapter,
            addr("StreamReferenceRenderPublication"), addr(FACADE), addr(FINALITY), self._graph_codehash(FINALITY),
            adapters, 500000, 12000000, 8000000)
        fill("StreamFinalityCurrentDiscovery", (discovery,))
        deployment = (addr("StreamFinalityArtifactCoverage"), self.deployment, FINALITY_URI, FINALITY_HASH)
        fill(FINALITY, (addr("StreamCore"), addr(METADATA), addr("StreamCoreFinalityAdapter"), addr(FACADE),
            addr("StreamGovernanceExecutor"), addr("StreamFinalityCurrentDiscovery"),
            ("FINALITY_COMPONENT_READ_GAS", 30000000, 50000, 2), deployment))
        fill(COORDINATOR, (self.token_suite, addr(FINALITY)))
        reader = create_address(addr(COORDINATOR), 1)
        require(int(self.rpc("eth_getTransactionCount", [addr(COORDINATOR), "latest"]), 16) == 2
                and self.call(COORDINATOR, "reads") == (reader,), "one original Coordinator reader CREATE differs")
        runtime = self._graph_predict("StreamArtistOnboardingReads", {"_chainId": self.token_chain_id})
        self._graph_record("StreamArtistOnboardingReads", reader, expected=runtime, extra={"createdBy": addr(COORDINATOR)})
        require(self.call(COORDINATOR, "configurationHash") == (self.token_coordinator_configuration,), "original Coordinator configuration differs")
        self._require_token_graph_selections()
        for name in ("StreamWorkRecordSelection", "StreamRightsRecordSelection", "StreamConservationRecordSelection"):
            fill(name, (addr("StreamCore"), addr(METADATA), self.schemas))
        fill("StreamRenderCriticalInventory", (self._token_inventory_dependencies(),))
        targets, hashes = self._graph_targets(("StreamCore", METADATA, "StreamRenderCriticalInventory",
            "StreamFinalityArtifactCoverage", "StreamExternalArtifactCoverage", "StreamArtistArchiveV2"))
        fill("StreamBundleArchiveCoverage", ((targets, hashes, self.token_chain_id, 500000, 2000000),))
        require(self.call("StreamRenderCriticalInventory", "dependencyHash") == (configuration[-1],), "actual inventory configuration differs")
        # Tuple equality is checked through ABI bytes, preserving fixed/dynamic array distinctions.
        _, _, outputs = self.function(PROVIDER, "nativeConfiguration")
        require(encode(outputs, self.call(PROVIDER, "nativeConfiguration")) == encode(outputs, (configuration,)),
                "original complete provider constructor configuration differs")
        for address, expected_hash in zip(configuration[0], configuration[1]):
            runtime = hex_bytes(self.rpc("eth_getCode", [address, "latest"]))
            require(0 < len(runtime) <= 24576 and keccak256(runtime) == expected_hash,
                    "actual provider dependency runtime absent/changed")
        self.token_graph_evidence = {
            "mode": "local_native_token_artist_graph_v1", "chainId": str(self.token_chain_id),
            "governanceSelectionsVerified": True, "coordinatorConstructed": True,
            "coordinatorConfigurationHash": self.token_coordinator_configuration,
            "rendererCatalogHash": keccak256(catalog), "rendererCatalogBytes": str(len(catalog)),
            "providerDependencyCount": str(len(configuration[0])), "providerDependenciesVerified": True,
            "immutableProjectionManifestSha256": self.token_projection_sha256,
            "reservedProducts": dict(self.token_reserved), "createSlots": dict(self.token_slots),
            "qualification": "New isolated local composition of explicitly pinned native products. Original constructors, complete runtime predictions, real pointer selections and all provider dependencies are checked. No prior acceptance, public deployment, finality, museum qualification or token mint is inferred.",
        }
        return self.token_graph_evidence

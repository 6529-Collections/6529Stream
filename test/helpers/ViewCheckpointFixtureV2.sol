// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "../unit/metadata/StreamViewPolicyRendererV2.t.sol";

/// @dev Actual original Store/State/Renderer, typed source graph; not a governed adoption ceremony.
contract CheckpointViewRecordProbe is PolicyViewRecordProbe {
    constructor(address c, Store s) PolicyViewRecordProbe(c, s) { }

    function viewAdoptionHead(StreamFinalityScope calldata scope) external view returns (bytes32) {
        return Original.state().heads[Original.subject(core, scope)];
    }

    function tokenJSONForView(uint256, bytes32) external view returns (string memory) {
        bytes memory raw = Transport.serve(
            core, address(LegacyRouting).codehash, address(PolicyRouting).codehash, msg.data
        );
        assembly ("memory-safe") { return(add(raw, 32), mload(raw)) }
    }
}

abstract contract ViewCheckpointFixtureV2 is CharacterizationTestBase {
    PolicyViewWire internal core;
    PolicyViewWire internal factory;
    PolicyViewWire internal sourceSet;
    PolicyViewWire internal coordinator;
    PolicyViewWire internal attribution;
    PolicyViewRecordProbe internal records;
    PolicyViewTokenProbe internal probe;
    Store internal store;
    StreamFinalityScope internal scope;
    StreamScopeMembershipFacts internal membership;
    Rule internal rule;
    bytes32 internal constant PLAN = keccak256("typed complete inventory plan");
    bytes32 internal constant VIEW_ID =
        keccak256("declared view identity distinct from membership");
    bytes32 internal constant VIEW_RECORD = keccak256("typed declared view receipt");

    function setUp() public {
        vm.warp(2000000000);
        core = new PolicyViewWire();
        factory = new PolicyViewWire();
        sourceSet = new PolicyViewWire();
        coordinator = new PolicyViewWire();
        attribution = new PolicyViewWire();
        store = new Store();
        records = new CheckpointViewRecordProbe(address(core), store);
        probe = new PolicyViewTokenProbe();
        scope = StreamFinalityScope(
            StreamFinalityScopeType.VIEW, 1, 0, keccak256("sealed membership identity")
        );
        membership.scopeSubject = keccak256(
            abi.encode(
                keccak256("6529STREAM_SUBJECT_SCOPE_V1"),
                block.chainid,
                address(core),
                uint256(1),
                uint8(4),
                scope.scopeId
            )
        );
        membership.scopeManifestHash = keccak256("scope manifest");
        membership.sourceRecordHash = keccak256("membership record");
        membership.membershipHash = keccak256("whole membership");
        membership.tokenListHash = keccak256(abi.encode(uint256(11)));
        membership.tokenCount = 1;
        _answer(
            factory,
            "supportsInterface(bytes4)",
            abi.encode(type(Factory).interfaceId),
            abi.encode(true)
        );
        _answer(
            factory,
            "scopedPolicyFactoryProfile()",
            "",
            abi.encode(keccak256("6529STREAM_SCOPED_ENTROPY_POLICY_SOURCE_FACTORY_V2"))
        );
        _answer(factory, "core()", "", abi.encode(address(core)));
        _answer(
            factory,
            "sourceSetForPlan(bytes32)",
            abi.encode(PLAN),
            abi.encode(address(sourceSet), address(sourceSet).codehash)
        );
        _answer(
            factory,
            "currentInventoryPlan((uint8,uint256,uint256,bytes32))",
            abi.encode(scope),
            abi.encode(PLAN)
        );
        _answer(
            sourceSet,
            "supportsInterface(bytes4)",
            abi.encode(type(Set).interfaceId),
            abi.encode(true)
        );
        _answer(
            sourceSet,
            "SOURCE_SET_PROFILE()",
            "",
            abi.encode(keccak256("6529STREAM_ENTROPY_POLICY_SOURCE_SET_V2"))
        );
        _answer(sourceSet, "factory()", "", abi.encode(address(factory)));
        _answer(sourceSet, "core()", "", abi.encode(address(core)));
        _answer(sourceSet, "sourceScope()", "", abi.encode(scope));
        _answer(sourceSet, "inventoryPlan()", "", abi.encode(PLAN));
        _answer(
            sourceSet, "originalInventoryHash()", "", abi.encode(keccak256("complete inventory"))
        );
        _answer(
            sourceSet,
            "originalPolicyChainHash()",
            "",
            abi.encode(keccak256("complete policy roster"))
        );
        _answer(sourceSet, "requireCurrentSelection()", "", "");
        _answer(sourceSet, "scopeMembershipFacts()", "", abi.encode(membership));
        _answer(sourceSet, "sourceCount()", "", abi.encode(uint256(1)));
        _identity(2, false, 7);
        _answer(
            core,
            "coordinatorAtMint(uint256)",
            abi.encode(uint256(11)),
            abi.encode(address(coordinator))
        );
        _answer(core, "collectionFreezeStatus(uint256)", abi.encode(uint256(1)), abi.encode(false));
        _answer(core, "collectionSupplyMode(uint256)", abi.encode(uint256(1)), abi.encode(uint8(0)));
        _answer(core, "collectionStatus(uint256)", abi.encode(uint256(1)), abi.encode(uint8(0)));
        _answer(core, "tokenData(uint256)", abi.encode(uint256(11)), abi.encode(hex"00f1ff00"));
        _answer(
            core,
            "scopeCoversToken((uint8,uint256,uint256,bytes32),uint256)",
            abi.encode(scope, uint256(11)),
            abi.encode(true)
        );
        _answer(coordinator, "core()", "", abi.encode(address(core)));
        _answer(
            coordinator,
            "supportsInterface(bytes4)",
            abi.encode(E.STATIC_CAPABILITY),
            abi.encode(true)
        );
        _answer(attribution, "core()", "", abi.encode(address(core)));
        _answer(attribution, "router()", "", abi.encode(address(records)));
        _answer(
            attribution,
            "attribution(uint256,uint256)",
            abi.encode(uint256(1), uint256(11)),
            abi.encode(bytes('{"state":"typed_live"}'))
        );
        rule.coordinator = address(coordinator);
        rule.indexedCodeHash = address(coordinator).codehash;
        rule.moduleVersion = keccak256("version");
        rule.moduleManifestHash = keccak256("manifest");
        rule.moduleSchemaHash = keccak256("schema");
        rule.deploymentManifestHash = keccak256("deployment");
        rule.policyHash = keccak256("full H");
        rule.componentDataHash = keccak256("component");
        rule.frozen = true;
        _policy(0, 1, true);
        _facts(1, 0, 0);
    }

    function _answer(
        PolicyViewWire target,
        string memory signature,
        bytes memory args,
        bytes memory response
    ) internal {
        target.answer(bytes.concat(bytes4(keccak256(bytes(signature))), args), response);
    }

    function _identity(uint8 lifecycle, bool burned, uint256 serial) internal {
        _answer(
            core,
            "tokenCollectionIdentity(uint256)",
            abi.encode(uint256(11)),
            abi.encode(true, uint256(1), serial, burned)
        );
        _answer(core, "tokenLifecycle(uint256)", abi.encode(uint256(11)), abi.encode(lifecycle));
    }

    function _policy(uint8 mode, uint8 requirement, bool explicit_) internal {
        rule.explicitPolicy = explicit_;
        E.Policy memory h;
        if (explicit_) {
            h = E.Policy(
                true,
                true,
                true,
                mode,
                1,
                requirement,
                3,
                4,
                rule.policyHash,
                keccak256(abi.encode(E.FAMILY, rule.policyHash, true)),
                keccak256("action"),
                keccak256("Artist consent")
            );
            rule.provider = address(0);
            rule.epoch = 0;
            rule.salt = 0;
        } else {
            rule.provider = address(0x991);
            rule.epoch = 2;
            rule.salt = keccak256("legacy salt");
        }
        rule.collectionPolicy = h;
        _answer(sourceSet, "sourcePolicyAt(uint256)", abi.encode(uint256(0)), abi.encode(rule));
    }

    function _facts(uint8 status, bytes32 seed, bytes32 request) internal {
        _answer(
            coordinator,
            "staticTerminalEntropyFacts(uint256)",
            abi.encode(uint256(11)),
            abi.encode(uint256(1), rule.collectionPolicy, status, seed, request)
        );
        _answer(
            coordinator,
            "staticTokenRenderFacts(uint256)",
            abi.encode(uint256(11)),
            abi.encode(status, seed, address(0x992))
        );
    }

    function _renderer() internal returns (Renderer renderer, bytes32 key) {
        R.RendererManifest memory m = R.RendererManifest(
            Format.ID,
            Format.VERSION,
            T.CONTEXT,
            keccak256("STATIC"),
            Format.schemaHash(),
            "",
            "",
            keccak256("typed manifest"),
            262144,
            262144,
            false
        );
        renderer = new Renderer(
            [address(core), address(records), address(sourceSet), address(attribution)],
            address(factory),
            scope,
            2000000,
            address(0),
            G.GasParameterConfig("METADATA_DEPENDENCY_READ_GAS", 1000000, 50000, 2),
            G.GasParameterConfig("STATIC_ATTRIBUTION_GAS", 1000000, 50000, 2),
            m
        );
        V.Record memory r;
        r.input.scope = scope;
        r.input.viewId = VIEW_ID;
        r.input.viewRecordHash = VIEW_RECORD;
        r.input.expectedPrevious = records.head(scope);
        r.source = records.payload(
            abi.encode(
                V.Payload(
                    T.CONTEXT,
                    "policy view",
                    "full source",
                    "",
                    bytes("window.done=stream.entropy.terminal;")
                )
            )
        );
        r.source.route.core = address(core);
        r.source.route.coreCodeHash = address(core).codehash;
        r.source.route.router = address(records);
        r.source.route.routerCodeHash = address(records).codehash;
        r.source.route.finality = address(core);
        r.source.route.finalityCodeHash = address(core).codehash;
        r.source.route.metadata = address(core);
        r.source.route.metadataCodeHash = address(core).codehash;
        r.source.route.artist = address(core);
        r.source.route.artistCodeHash = address(core).codehash;
        r.source.route.provider = address(core);
        r.source.route.providerCodeHash = address(core).codehash;
        r.source.route.binding.views = address(core);
        r.source.route.binding.viewsCodeHash = address(core).codehash;
        r.source.route.binding.readGas = 1000000;
        r.source.route.binding.sourceGas = 2000000;
        r.source.route.store = address(store);
        r.source.route.storeCodeHash = address(store).codehash;
        r.source.route.binding.membership = address(core);
        r.source.route.binding.membershipCodeHash = address(core).codehash;
        r.source.membership = membership;
        r.source.renderer.renderer = address(renderer);
        r.source.renderer.rendererCodeHash = address(renderer).codehash;
        r.source.renderer.contextVersion = T.CONTEXT;
        r.source.renderer.registry = address(core);
        r.source.renderer.registryCodeHash = address(core).codehash;
        r.source.renderer.versionKey =
            keccak256(abi.encode("typed retained Registry version", address(renderer)));
        _answer(
            core,
            "requireRetained(bytes32)",
            abi.encode(r.source.renderer.versionKey),
            abi.encode(address(renderer), address(renderer).codehash)
        );
        _pointer("METADATA_ROUTER", address(records));
        _pointer("COLLECTION_METADATA", address(core));
        _pointer("ARTIST_REGISTRY", address(core));
        _pointer("ARTWORK_FINALITY_REGISTRY", address(core));
        _answer(core, "scopeEvidenceProvider()", "", abi.encode(address(core)));
        _answer(core, "scopeEvidenceProviderCodeHash()", "", abi.encode(address(core).codehash));
        _answer(core, "viewSourceBinding()", "", abi.encode(r.source.route.binding));
        _answer(
            core,
            "selectedViewRecord(uint256,bytes32)",
            abi.encode(uint256(1), VIEW_ID),
            abi.encode(VIEW_RECORD, false)
        );
        r.sourceHash = keccak256(
            abi.encode(
                keccak256("6529STREAM_POLICY_VIEW_ADOPTION_SOURCE_V2"),
                T.PROFILE,
                block.chainid,
                address(records),
                r.input.scope,
                r.input.viewId,
                r.input.viewRecordHash,
                r.source,
                renderer.policyViewBinding()
            )
        );
        r.input.expectedSourceHash = r.sourceHash;
        r.actor = address(this);
        r.authorizationClass = 7;
        r.grantRevision = 1;
        key = records.write(r, keccak256("typed op17 consent"), true);
    }

    function _request(bytes32 key, bytes32 seed, bool burned)
        internal
        view
        returns (R.RenderRequest memory)
    {
        return R.RenderRequest(
            address(core),
            11,
            1,
            7,
            seed,
            burned ? R.TokenRenderState.BURNED : R.TokenRenderState.ACTIVE,
            R.MetadataMode.ONCHAIN,
            0,
            0,
            VIEW_ID,
            VIEW_RECORD,
            key
        );
    }

    function _contains(string memory text, string memory part) internal pure returns (bool) {
        bytes memory a = bytes(text);
        bytes memory b = bytes(part);
        if (b.length > a.length) return false;
        for (uint256 i; i <= a.length - b.length; ++i) {
            bool yes = true;
            for (uint256 j; j < b.length; ++j) {
                if (a[i + j] != b[j]) {
                    yes = false;
                    break;
                }
            }
            if (yes) return true;
        }
        return false;
    }

    function _fails(Renderer r, R.RenderRequest memory q) internal view {
        (bool ok,) = address(r).staticcall(abi.encodeCall(r.renderPolicyView, (q, uint8(3))));
        require(!ok, "source mismatch must refuse");
    }

    function _pointer(string memory role, address target) internal {
        _answer(
            core,
            "getSatellitePointer(bytes32)",
            abi.encode(keccak256(bytes(role))),
            abi.encode(
                target,
                target.codehash,
                bytes32(0),
                bytes32(0),
                uint64(0),
                uint64(0),
                uint8(1),
                bytes32(0),
                bytes32(0),
                uint64(1)
            )
        );
    }
}

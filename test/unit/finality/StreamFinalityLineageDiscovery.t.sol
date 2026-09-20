// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "./StreamFinalityCurrentDiscovery.t.sol";
import "../../../smart-contracts/domains/finality/StreamFinalityLineageCurrentDiscovery.sol";
import "../../../smart-contracts/domains/finality/StreamFinalityLineageProfileDiscovery.sol";
import {
    StreamArtistCurrentAuthorityTypes as CA
} from "../../../smart-contracts/interfaces/stream/artist/StreamArtistCurrentAuthorityTypes.sol";

abstract contract LineageDiscoveryFixture is CharacterizationTestBase, OfficialSafeFixture {
    StreamFinalityDiscoveryTypes.Configuration internal c;
    StreamFinalityLineageCurrentDiscovery internal discovery;
    DiscoveryReadTable internal moduleRegistry;
    DiscoveryReadTable internal entropy;
    StreamFinalityScope internal scope;

    CA.Route internal authority;

    function _new() internal returns (address) {
        return address(new DiscoveryReadTable());
    }

    function _put(address target, bytes memory input, bytes memory result) internal {
        DiscoveryReadTable(target).put(input, result);
    }

    function _address(address target, string memory sig, address result) internal {
        _put(target, abi.encodeWithSignature(sig), abi.encode(result));
    }

    function _support(address target, bytes4 id) internal {
        _put(target, abi.encodeCall(IERC165.supportsInterface, (id)), abi.encode(true));
        _put(
            target,
            abi.encodeCall(IERC165.supportsInterface, (type(IERC165).interfaceId)),
            abi.encode(true)
        );
        _put(
            target,
            abi.encodeCall(IERC165.supportsInterface, (bytes4(0xffffffff))),
            abi.encode(false)
        );
    }

    function _family(uint256 i) internal pure returns (bytes32) {
        if (i == 0) return keccak256("METADATA_ROUTER");
        if (i == 1) return keccak256("RENDERER");
        if (i == 2) return keccak256("RENDER_CONTEXT");
        if (i == 3) return keccak256("MEDIA_MANIFEST");
        if (i == 4) return keccak256("SCRIPT_SOURCE");
        if (i == 5) return keccak256("DEPENDENCY_SOURCE");
        return keccak256("COLLECTION_METADATA");
    }

    function _facts(bytes32 family, bool frozen) internal {
        _put(
            c.provider,
            abi.encodeCall(IStreamFinalityComponentFacts.finalityComponentFacts, (family, scope)),
            abi.encode(
                StreamFinalityHostComponentFacts(
                    frozen,
                    keccak256("version"),
                    keccak256("manifest"),
                    keccak256(abi.encode("original source", family, scope))
                )
            )
        );
    }

    function _selected(address host, bytes32 kind, bytes4 id) internal {
        _support(host, id);
        _put(host, abi.encodeCall(IStreamModule.streamModuleType, ()), abi.encode(kind));
        _put(host, abi.encodeCall(IStreamModule.streamModuleInterfaceId, ()), abi.encode(id));
        StreamMetadataRecoveryRoutes.Pointer memory ptr = StreamMetadataRecoveryRoutes.Pointer(
            host,
            host.codehash,
            false,
            kind,
            id,
            address(moduleRegistry),
            1,
            keccak256("module"),
            keccak256("deployment"),
            1
        );
        _put(
            c.core, abi.encodeCall(IStreamCorePointers.getSatellitePointer, (kind)), abi.encode(ptr)
        );
        _put(
            address(moduleRegistry),
            abi.encodeCall(IStreamModuleRegistry.isModuleEligible, (host, kind, id)),
            abi.encode(true)
        );
    }

    function _state(address target, bytes32 kind, bool frozen)
        internal
        view
        returns (StreamFinalityComponentState memory)
    {
        return StreamFinalityComponentState(
            frozen,
            kind,
            target,
            type(IStreamArtworkFinalityComponent).interfaceId,
            target.codehash,
            keccak256("version"),
            keccak256("manifest"),
            keccak256(abi.encode("original source", kind, scope))
        );
    }

    function _record(address target, bytes32 kind, bool frozen) internal {
        _put(
            target,
            abi.encodeCall(IStreamArtworkFinalityComponent.finalityState, (1)),
            abi.encode(_state(target, kind, frozen))
        );
    }

    function _expectation(StreamFinalityComponentState memory s)
        internal
        pure
        returns (StreamFinalityComponentExpectation memory)
    {
        return StreamFinalityComponentExpectation(
            s.componentType,
            s.component,
            s.interfaceId,
            s.codeHash,
            s.moduleVersion,
            s.manifestHash,
            s.dataHash
        );
    }

    function _sign() internal {
        _put(
            authority.registry,
            abi.encodeCall(IStreamFinalitySanctionReads.collectionSanctionComponentType, (1)),
            abi.encode(keccak256("ARTIST_SANCTION"))
        );
        _record(authority.registry, keccak256("ARTIST_SANCTION"), true);
    }

    function setUp() public virtual {
        scope = StreamFinalityScope(StreamFinalityScopeType.COLLECTION, 1, 0, 0);
        c.core = _new();
        c.metadata = _new();
        c.router = _new();
        c.provider = _new();
        c.membership = _new();
        c.entropyFactory = _new();
        c.referenceRender = _new();
        c.artist = _new();
        c.finalityRegistry = _new();
        c.finalityRegistryCodeHash = c.finalityRegistry.codehash;
        c.readGas = 100000;
        c.componentGas = 1000000;
        c.entropyGas = 2000000;
        moduleRegistry = new DiscoveryReadTable();
        entropy = new DiscoveryReadTable();
        _address(c.provider, "core()", c.core);
        _address(c.provider, "metadataHost()", c.metadata);
        _address(c.provider, "metadataRouter()", c.router);
        _address(c.provider, "scopeMembershipHost()", c.membership);
        _address(c.metadata, "core()", c.core);
        _address(c.router, "core()", c.core);
        _address(c.membership, "core()", c.core);
        _address(c.membership, "metadataHost()", c.metadata);
        _address(c.entropyFactory, "core()", c.core);
        _address(c.entropyFactory, "metadataHost()", c.metadata);
        _address(c.entropyFactory, "scopeMembershipHost()", c.membership);
        _address(c.referenceRender, "core()", c.core);
        _address(c.referenceRender, "metadataHost()", c.metadata);
        _support(c.provider, type(IStreamFinalityServingEvidenceProvider).interfaceId);
        _support(c.router, type(IStreamMetadataRouter).interfaceId);
        _support(c.metadata, type(IStreamCollectionMetadataV1).interfaceId);
        for (uint256 i; i < 7; ++i) {
            bytes32 family = _family(i);
            address host = i == 6 ? c.metadata : c.router;
            _put(
                c.provider,
                abi.encodeCall(IStreamFinalityServingEvidenceProvider.componentHost, (family)),
                abi.encode(host)
            );
            _facts(family, true);
            StreamFinalityServingHostAdapter adapter =
                new StreamFinalityServingHostAdapter(c.core, host, c.provider, family);
            if (i == 6) c.metadataAdapter = address(adapter);
            else c.routerAdapters[i] = address(adapter);
        }
        _selected(c.router, keccak256("METADATA_ROUTER"), type(IStreamMetadataRouter).interfaceId);
        _selected(
            c.metadata,
            keccak256("COLLECTION_METADATA"),
            type(IStreamCollectionMetadataV1).interfaceId
        );
        _selected(
            c.artist, keccak256("ARTIST_REGISTRY"), type(IStreamArtistMintConsent).interfaceId
        );
        StreamMetadataRecoveryRoutes.Pointer memory registry = StreamMetadataRecoveryRoutes.Pointer(
            address(moduleRegistry),
            address(moduleRegistry).codehash,
            false,
            keccak256("MODULE_REGISTRY"),
            bytes4(0x01020304),
            address(moduleRegistry),
            1,
            keccak256("module"),
            keccak256("deployment"),
            1
        );
        _put(
            c.core,
            abi.encodeCall(IStreamCorePointers.getSatellitePointer, (keccak256("MODULE_REGISTRY"))),
            abi.encode(registry)
        );
        StreamScopeMembershipFacts memory f;
        f.scopeSubject = StreamMetadataSubjects.scopeSubject(block.chainid, c.core, scope);
        f.membershipHash = keccak256("members");
        f.tokenCount = 2;
        _put(
            c.membership,
            abi.encodeCall(IStreamFinalityScopeMembership.requireScopeMembership, (scope)),
            abi.encode(f)
        );
        IStreamMetadataServingFacts.ServingFacts memory serving;
        serving.presentationProfile = keccak256("6529STREAM_ROUTER_STABLE_PRESENTATION_V1");
        serving.mode = keccak256("ONCHAIN");
        serving.scriptBytes = 8;
        _put(
            c.router,
            abi.encodeCall(IStreamMetadataServingFacts.collectionServingFacts, (1)),
            abi.encode(serving)
        );
        _put(
            c.entropyFactory,
            abi.encodeCall(IStreamFinalityEntropySourceFactory.requireCurrentComponent, (scope)),
            abi.encode(
                _expectation(_state(address(entropy), keccak256("ENTROPY_COORDINATOR"), true))
            )
        );
        _record(c.referenceRender, keccak256("REFERENCE_RENDER"), true);
        _put(
            c.provider,
            abi.encodeCall(
                IStreamFinalityRouterEvidenceBinding.requireCurrentRouterCandidate,
                (1, c.finalityRegistry)
            ),
            bytes("")
        );
        address snapshots = _new();
        _address(c.referenceRender, "metadataRouter()", c.router);
        _address(c.referenceRender, "snapshots()", snapshots);
        _address(c.provider, "referenceRenderHost()", c.referenceRender);
        _address(c.provider, "snapshotHost()", snapshots);
        _address(c.provider, "entropySourceFactory()", c.entropyFactory);
        _support(c.provider, type(IStreamFinalityRouterEvidenceBinding).interfaceId);
        _support(c.provider, type(IStreamFinalityDiscoverySources).interfaceId);
        _support(c.entropyFactory, type(IStreamFinalityEntropySourceFactory).interfaceId);
        _support(c.entropyFactory, type(IStreamFinalityCurrentEntropyRoute).interfaceId);
        _put(
            c.entropyFactory,
            abi.encodeCall(IStreamFinalityCurrentEntropyRoute.requireCurrentRoute, (scope)),
            abi.encode(
                StreamFinalityCurrentComponentRoute(
                    keccak256("ENTROPY_COORDINATOR"),
                    address(entropy),
                    type(IStreamArtworkFinalityComponent).interfaceId,
                    address(entropy).codehash
                )
            )
        );
        _record(address(entropy), keccak256("ENTROPY_COORDINATOR"), true);
        _support(c.referenceRender, type(IStreamArtworkFinalityComponent).interfaceId);
        _support(c.referenceRender, type(IStreamArtworkScopedFinalityComponent).interfaceId);
        _support(c.artist, type(IStreamArtworkFinalityComponent).interfaceId);
        _support(c.artist, type(IStreamArtworkScopedFinalityComponent).interfaceId);
        _support(address(entropy), type(IStreamArtworkFinalityComponent).interfaceId);
        discovery = new StreamFinalityLineageCurrentDiscovery(c);
        _address(c.finalityRegistry, "scopeEvidenceProvider()", c.provider);
        _address(c.finalityRegistry, "finalityDiscovery()", address(discovery));
        _address(c.finalityRegistry, "coreReads()", c.core);
        _address(c.finalityRegistry, "metadataReads()", c.metadata);
        _address(c.finalityRegistry, "sanctionReads()", c.artist);
        _support(c.finalityRegistry, type(IStreamFinalityCurrentAuthority).interfaceId);
        _put(
            c.finalityRegistry,
            abi.encodeCall(IStreamFinalityCurrentAuthority.currentAuthorityProfile, ()),
            abi.encode(CA.PROFILE)
        );
        _successor(_new());
    }

    function _successor(address registry_) internal {
        _support(registry_, type(IStreamArtworkFinalityComponent).interfaceId);
        _support(registry_, type(IStreamArtworkScopedFinalityComponent).interfaceId);
        _selected(
            registry_, keccak256("ARTIST_REGISTRY"), type(IStreamArtistMintConsent).interfaceId
        );
        authority = CA.Route(
            c.finalityRegistry,
            c.finalityRegistryCodeHash,
            c.provider,
            c.provider.codehash,
            registry_,
            registry_.codehash,
            _new(),
            bytes32(0),
            keccak256(abi.encode("selection", registry_)),
            keccak256("locked A presentation")
        );
        authority.coordinatorCodeHash = authority.coordinator.codehash;
        _routeValue(authority);
    }

    function _routeValue(CA.Route memory value) internal {
        _put(
            c.finalityRegistry,
            abi.encodeCall(
                IStreamFinalityCurrentAuthority.currentArtistAuthority, (scope.collectionId)
            ),
            abi.encode(value)
        );
    }
}

/// @dev Real discovery and serving adapters with explicit Resolver/Finality/source boundaries.
/// This does not claim execution of the full Artist migration or Finality graph.
contract StreamFinalityLineageDiscoveryTest is LineageDiscoveryFixture {
    function testUnpredictedSuccessorsKeepOriginalAnchorAndNineIndependentRoutes() public {
        require(authority.registry != c.artist && discovery.configuration().artist == c.artist);
        require(discovery.dependencyCodeHash(authority.registry) == 0);
        (uint256 count, bytes32 beforeHash) = discovery.nonSanctionDiscoveryFacts(scope);
        require(count == 9 && beforeHash != 0);
        _sign();
        _assertSanctionRoute();
        _successor(_new());
        _sign();
        _assertSanctionRoute();
        (, bytes32 afterHash) = discovery.nonSanctionDiscoveryFacts(scope);
        require(beforeHash == afterHash && discovery.configuration().artist == c.artist);
    }

    function _assertSanctionRoute() private view {
        StreamFinalityCurrentComponentRoute[] memory routes =
            discovery.requireCurrentRoutes(scope, true);
        uint256 found;
        for (uint256 i; i < routes.length; ++i) {
            if (routes[i].componentType == keccak256("ARTIST_SANCTION")) {
                ++found;
                require(
                    routes[i].component == authority.registry
                        && routes[i].codeHash == authority.registryCodeHash
                );
                StreamFinalityComponentExpectation memory component =
                    discovery.finalityComponentAt(1, i);
                require(component.component == authority.registry);
            }
        }
        require(found == 1 && discovery.finalityDiscoveryHash(1) != 0);
    }

    function testWrongProviderRuntimeAndEmptyLineageRejectEvenWithoutSanction() public {
        CA.Route memory wrong = authority;
        wrong.provider = c.artist;
        _routeValue(wrong);
        vm.expectRevert();
        discovery.nonSanctionDiscoveryFacts(scope);
        wrong = authority;
        wrong.registryCodeHash = keccak256("wrong runtime");
        _routeValue(wrong);
        vm.expectRevert();
        discovery.requireCurrentRoutes(scope, false);
        wrong = authority;
        wrong.selectionHash = 0;
        _routeValue(wrong);
        vm.expectRevert();
        discovery.finalityComponentCount(1);
        wrong = authority;
        wrong.presentationHash = 0;
        _routeValue(wrong);
        vm.expectRevert();
        discovery.nonSanctionDiscoveryFacts(scope);
        _routeValue(authority);
        require(discovery.finalityComponentCount(1) == 10);
    }

    function testMalformedAndWrongProfileAuthorityFailClosed() public {
        _put(
            c.finalityRegistry,
            abi.encodeCall(IStreamFinalityCurrentAuthority.currentArtistAuthority, (uint256(1))),
            abi.encode(authority.registry)
        );
        vm.expectRevert();
        discovery.nonSanctionDiscoveryFacts(scope);
        _routeValue(authority);
        _put(
            c.finalityRegistry,
            abi.encodeCall(IStreamFinalityCurrentAuthority.currentAuthorityProfile, ()),
            abi.encode(bytes32(0))
        );
        vm.expectRevert();
        discovery.requireCurrentRoutes(scope, false);
    }

    function testCoreSelectionAndHistoricalSanctionAnchorRemainIndependentRequiredJoins() public {
        _selected(
            c.artist, keccak256("ARTIST_REGISTRY"), type(IStreamArtistMintConsent).interfaceId
        );
        vm.expectRevert();
        discovery.nonSanctionDiscoveryFacts(scope);
        _selected(
            authority.registry,
            keccak256("ARTIST_REGISTRY"),
            type(IStreamArtistMintConsent).interfaceId
        );
        _address(c.finalityRegistry, "sanctionReads()", authority.registry);
        vm.expectRevert();
        discovery.nonSanctionDiscoveryFacts(scope);
        _address(c.finalityRegistry, "sanctionReads()", c.artist);
        require(discovery.requireCurrentRoutes(scope, false).length == 9);
    }

    function testOldDiscoveryRemainsStrictAfterCutover() public {
        StreamFinalityCurrentDiscovery legacy = new StreamFinalityCurrentDiscovery(c);
        _address(c.finalityRegistry, "finalityDiscovery()", address(legacy));
        vm.expectRevert();
        legacy.nonSanctionDiscoveryFacts(scope);
        _address(c.finalityRegistry, "finalityDiscovery()", address(discovery));
        require(discovery.requireCurrentRoutes(scope, false).length == 9);
    }

    function testOriginalSignatureDoesNotSatisfyCurrentSuccessorComponent() public {
        _record(c.artist, keccak256("ARTIST_SANCTION"), true);
        require(discovery.requireCurrentRoutes(scope, false).length == 9);
        vm.expectRevert();
        discovery.finalityDiscoveryHash(1);
        _sign();
        require(discovery.finalityDiscoveryHash(1) != 0);
        bytes memory runtime = authority.coordinator.code;
        vm.etch(authority.coordinator, hex"00");
        vm.expectRevert();
        discovery.requireCurrentRoutes(scope, false);
        vm.etch(authority.coordinator, runtime);
        require(discovery.finalityDiscoveryHash(1) != 0);
    }
}

/// @dev Same current-authority handshake through the profile-aware Discovery sibling;
/// the three source catalogues are explicit typed boundaries, not actual policy publication.
contract StreamFinalityLineageProfileDiscoveryTest is LineageDiscoveryFixture {
    StreamFinalityLineageProfileDiscovery private profiled;
    Profiles.Profile private selected;

    function setUp() public override {
        super.setUp();
        bytes32 configurationHash = keccak256("fixed source catalogue boundary");
        address snapshots = IStreamFinalityDiscoverySources(c.provider).snapshotHost();
        _address(snapshots, "core()", c.core);
        _address(snapshots, "metadataHost()", c.metadata);
        _support(c.provider, type(Profiles).interfaceId);
        _put(
            c.provider,
            abi.encodeCall(Profiles.finalitySourceConfigurationHash, ()),
            abi.encode(configurationHash)
        );
        for (uint8 i; i < 3; ++i) {
            Profiles.Profile memory p = Profiles.Profile(
                ProfileReads.profileHash(i),
                c.referenceRender,
                c.referenceRender.codehash,
                snapshots,
                snapshots.codehash,
                c.entropyFactory,
                c.entropyFactory.codehash,
                keccak256(abi.encode("source", i))
            );
            _put(c.provider, abi.encodeCall(Profiles.finalitySourceProfile, (i)), abi.encode(p));
            if (i == 0) selected = p;
        }
        _source();
        profiled = new StreamFinalityLineageProfileDiscovery(c, configurationHash);
        _address(c.finalityRegistry, "finalityDiscovery()", address(profiled));
    }

    function _source() private {
        _put(
            c.provider,
            abi.encodeCall(Profiles.finalitySourcesForScope, (scope)),
            abi.encode(Profiles.Sources(scope, selected))
        );
    }

    function testProfileDiscoverySelectsCurrentSanctionWithoutChangingSourceCatalogue() public {
        _sign();
        _assertCurrent();
        bytes32 fixedSources = profiled.sourceConfigurationHash();
        _successor(_new());
        _sign();
        _assertCurrent();
        require(
            profiled.sourceConfigurationHash() == fixedSources
                && profiled.configuration().artist == c.artist
        );
    }

    function _assertCurrent() private view {
        StreamFinalityCurrentComponentRoute[] memory routes =
            profiled.requireCurrentRoutes(scope, true);
        uint256 found;
        for (uint256 i; i < routes.length; ++i) {
            if (routes[i].componentType == keccak256("ARTIST_SANCTION")) {
                ++found;
                require(routes[i].component == authority.registry);
                require(profiled.finalityComponentAt(1, i).component == authority.registry);
            }
        }
        require(found == 1 && profiled.finalityDiscoveryHash(1) != 0);
    }

    function testValidAuthorityDoesNotPermitSourceTupleOrScopeSubstitution() public {
        selected.configurationHash = keccak256("substituted source configuration");
        _source();
        vm.expectRevert();
        profiled.nonSanctionDiscoveryFacts(scope);
        selected.configurationHash = keccak256(abi.encode("source", uint8(0)));
        StreamFinalityScope memory wrong = scope;
        wrong.collectionId += 1;
        _put(
            c.provider,
            abi.encodeCall(Profiles.finalitySourcesForScope, (scope)),
            abi.encode(Profiles.Sources(wrong, selected))
        );
        vm.expectRevert();
        profiled.requireCurrentRoutes(scope, false);
        _source();
        (uint256 count, bytes32 hash) = profiled.nonSanctionDiscoveryFacts(scope);
        require(count == 9 && hash != 0);
    }
}

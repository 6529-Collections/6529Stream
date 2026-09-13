// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "../../regression/legacy/helpers/CharacterizationTestBase.sol";
import "../../helpers/OfficialSafeFixture.sol";
import "../../../smart-contracts/domains/finality/StreamFinalityCurrentDiscovery.sol";
import "../../../smart-contracts/domains/finality/StreamFinalityServingHostAdapter.sol";
import "../../../smart-contracts/interfaces/stream/core/IStreamCorePointers.sol";

/// @dev Explicit deterministic dependency-response boundary. Actual native/Core composition has
/// its own cohort; these tests challenge discovery and actual provider-backed adapters only.
contract DiscoveryReadTable {
    mapping(bytes32 => bytes) private _values;
    mapping(bytes32 => bool) private _set;

    function put(bytes calldata callData, bytes calldata result) external {
        bytes32 key = keccak256(callData);
        _values[key] = result;
        _set[key] = true;
    }

    function remove(bytes calldata callData) external {
        delete _set[keccak256(callData)];
    }

    fallback() external {
        bytes32 key = keccak256(msg.data);
        require(_set[key], "unconfigured typed boundary");
        bytes memory result = _values[key];
        assembly ("memory-safe") { return(add(result, 32), mload(result)) }
    }
}

contract StreamFinalityCurrentDiscoveryTest is CharacterizationTestBase, OfficialSafeFixture {
    StreamFinalityDiscoveryTypes.Configuration private c;
    StreamFinalityCurrentDiscovery private discovery;
    DiscoveryReadTable private moduleRegistry;
    DiscoveryReadTable private entropy;
    StreamFinalityScope private scope;

    function _new() private returns (address) {
        return address(new DiscoveryReadTable());
    }

    function _put(address target, bytes memory input, bytes memory result) private {
        DiscoveryReadTable(target).put(input, result);
    }

    function _address(address target, string memory sig, address result) private {
        _put(target, abi.encodeWithSignature(sig), abi.encode(result));
    }

    function _support(address target, bytes4 id) private {
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

    function _family(uint256 i) private pure returns (bytes32) {
        if (i == 0) return keccak256("METADATA_ROUTER");
        if (i == 1) return keccak256("RENDERER");
        if (i == 2) return keccak256("RENDER_CONTEXT");
        if (i == 3) return keccak256("MEDIA_MANIFEST");
        if (i == 4) return keccak256("SCRIPT_SOURCE");
        if (i == 5) return keccak256("DEPENDENCY_SOURCE");
        return keccak256("COLLECTION_METADATA");
    }

    function _facts(bytes32 family, bool frozen) private {
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

    function _selected(address host, bytes32 kind, bytes4 id) private {
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
        private
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

    function _record(address target, bytes32 kind, bool frozen) private {
        _put(
            target,
            abi.encodeCall(IStreamArtworkFinalityComponent.finalityState, (1)),
            abi.encode(_state(target, kind, frozen))
        );
    }

    function _expectation(StreamFinalityComponentState memory s)
        private
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

    function _sign() private {
        _put(
            c.artist,
            abi.encodeCall(IStreamFinalitySanctionReads.collectionSanctionComponentType, (1)),
            abi.encode(keccak256("ARTIST_SANCTION"))
        );
        _record(c.artist, keccak256("ARTIST_SANCTION"), true);
    }

    function setUp() public {
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
        _support(c.referenceRender, type(IStreamArtworkFinalityComponent).interfaceId);
        _support(c.referenceRender, type(IStreamArtworkScopedFinalityComponent).interfaceId);
        _support(c.artist, type(IStreamArtworkFinalityComponent).interfaceId);
        _support(c.artist, type(IStreamArtworkScopedFinalityComponent).interfaceId);
        _support(address(entropy), type(IStreamArtworkFinalityComponent).interfaceId);
        discovery = new StreamFinalityCurrentDiscovery(c);
        _address(c.finalityRegistry, "scopeEvidenceProvider()", c.provider);
        _address(c.finalityRegistry, "finalityDiscovery()", address(discovery));
        _address(c.finalityRegistry, "coreReads()", c.core);
        _address(c.finalityRegistry, "metadataReads()", c.metadata);
        _address(c.finalityRegistry, "sanctionReads()", c.artist);
    }

    function testNonSanctionProjectionWorksBeforeArtistSignsAndDoesNotChangeAfterward() public {
        (uint256 count, bytes32 beforeHash) = discovery.nonSanctionDiscoveryFacts(scope);
        require(count == 9 && beforeHash != 0);
        vm.expectRevert();
        discovery.finalityDiscoveryHash(1);
        _sign();
        require(discovery.finalityComponentCount(1) == 10);
        (, bytes32 afterHash) = discovery.nonSanctionDiscoveryFacts(scope);
        require(beforeHash == afterHash);
    }

    function testExactCanonicalOrderingAndIndependentArrayHash() public {
        _sign();
        StreamFinalityComponentExpectation[] memory entries =
            new StreamFinalityComponentExpectation[](10);
        for (uint256 i; i < 10; ++i) {
            entries[i] = discovery.finalityComponentAt(1, i);
            if (i > 0) require(entries[i - 1].componentType < entries[i].componentType);
            require(
                entries[i].dataHash
                    == keccak256(abi.encode("original source", entries[i].componentType, scope))
            );
        }
        require(
            discovery.finalityDiscoveryHash(1)
                == keccak256(abi.encode(keccak256("6529STREAM_FINALITY_COMPONENTS_V1"), entries))
        );
        require(
            discovery.finalityDiscoveryHashForScope(scope) == discovery.finalityDiscoveryHash(1)
        );
        require(discovery.finalityComponentCountForScope(scope) == 10);
    }

    function testEveryRouterAndMetadataLockMustActuallyBeFrozen() public {
        for (uint256 i; i < 7; ++i) {
            _facts(_family(i), false);
            vm.expectRevert();
            discovery.nonSanctionDiscoveryFacts(scope);
            _facts(_family(i), true);
        }
        require(discovery.nonSanctionComponentAt(scope, 0).dataHash != 0);
    }

    function testMissingReferenceAndIncompleteEntropyCannotBeOmitted() public {
        _record(c.referenceRender, keccak256("REFERENCE_RENDER"), false);
        vm.expectRevert();
        discovery.nonSanctionDiscoveryFacts(scope);
        _record(c.referenceRender, keccak256("REFERENCE_RENDER"), true);
        DiscoveryReadTable(c.entropyFactory)
            .remove(
                abi.encodeCall(IStreamFinalityEntropySourceFactory.requireCurrentComponent, (scope))
            );
        vm.expectRevert();
        discovery.nonSanctionDiscoveryFacts(scope);
    }

    function testCounterfeitEntropyFamilyInterfaceAndRuntimeReject() public {
        StreamFinalityComponentExpectation memory e =
            _expectation(_state(address(entropy), keccak256("ENTROPY_COORDINATOR"), true));
        e.componentType = keccak256("RENDERER");
        _entropy(e);
        vm.expectRevert();
        discovery.nonSanctionDiscoveryFacts(scope);
        e.componentType = keccak256("ENTROPY_COORDINATOR");
        e.interfaceId = bytes4(0x12345678);
        _entropy(e);
        vm.expectRevert();
        discovery.nonSanctionDiscoveryFacts(scope);
        e.interfaceId = type(IStreamArtworkFinalityComponent).interfaceId;
        e.codeHash = keccak256("false");
        _entropy(e);
        vm.expectRevert();
        discovery.nonSanctionDiscoveryFacts(scope);
    }

    function _entropy(StreamFinalityComponentExpectation memory e) private {
        _put(
            c.entropyFactory,
            abi.encodeCall(IStreamFinalityEntropySourceFactory.requireCurrentComponent, (scope)),
            abi.encode(e)
        );
    }

    function testCurrentRegistryAndSelectionCannotSilentlyDrift() public {
        _address(c.finalityRegistry, "finalityDiscovery()", address(0xbeef));
        vm.expectRevert();
        discovery.nonSanctionDiscoveryFacts(scope);
        _address(c.finalityRegistry, "finalityDiscovery()", address(discovery));
        _put(
            address(moduleRegistry),
            abi.encodeCall(
                IStreamModuleRegistry.isModuleEligible,
                (c.artist, keccak256("ARTIST_REGISTRY"), type(IStreamArtistMintConsent).interfaceId)
            ),
            abi.encode(false)
        );
        vm.expectRevert();
        discovery.nonSanctionDiscoveryFacts(scope);
    }

    function testRuntimeLossFailsAndExactRestoreRecovers() public {
        bytes memory prior = c.routerAdapters[3].code;
        vm.etch(c.routerAdapters[3], hex"00");
        vm.expectRevert();
        discovery.nonSanctionDiscoveryFacts(scope);
        vm.etch(c.routerAdapters[3], prior);
        (uint256 count,) = discovery.nonSanctionDiscoveryFacts(scope);
        require(count == 9);
    }

    function testConstructorRejectsMisroutedFixedAdapterAndPreservesLateRegistryOrder() public {
        c.routerAdapters[1] = c.routerAdapters[0];
        vm.expectRevert();
        new StreamFinalityCurrentDiscovery(c);
        c = discovery.configuration();
        bytes memory prior = c.finalityRegistry.code;
        vm.etch(c.finalityRegistry, hex"");
        StreamFinalityCurrentDiscovery early = new StreamFinalityCurrentDiscovery(c);
        require(early.scopeEvidenceProvider() == c.provider);
        vm.expectRevert();
        early.nonSanctionDiscoveryFacts(scope);
        vm.etch(c.finalityRegistry, prior);
    }

    function testUnknownScopeAndOffchainDoNotInheritNativeArtistReadiness() public {
        StreamFinalityScope memory absent = scope;
        absent.tokenId = 17;
        vm.expectRevert();
        discovery.nonSanctionDiscoveryFacts(absent);
        IStreamMetadataServingFacts.ServingFacts memory serving;
        serving.presentationProfile = keccak256("6529STREAM_ROUTER_STABLE_PRESENTATION_V1");
        serving.mode = keccak256("OFFCHAIN");
        _put(
            c.router,
            abi.encodeCall(IStreamMetadataServingFacts.collectionServingFacts, (1)),
            abi.encode(serving)
        );
        vm.expectRevert();
        discovery.nonSanctionDiscoveryFacts(scope);
    }

    function testSafeCanReadIndependentAndCompletedDiscovery() public {
        uint256[] memory keys = new uint256[](2);
        keys[0] = 88771;
        keys[1] = 88772;
        OfficialSafe safe =
            createOfficialSafe(deploySafeComponents("1.4.1"), safeOwnerAddresses(keys), 2, 88773);
        require(
            executeSafe(
                safe,
                keys,
                address(discovery),
                0,
                abi.encodeCall(discovery.nonSanctionDiscoveryFacts, (scope)),
                0
            )
        );
        _sign();
        require(
            executeSafe(
                safe,
                keys,
                address(discovery),
                0,
                abi.encodeCall(discovery.finalityDiscoveryHash, (1)),
                0
            )
        );
        require(
            executeSafe(
                safe,
                keys,
                address(discovery),
                0,
                abi.encodeCall(discovery.finalityComponentAtForScope, (scope, 0)),
                0
            )
        );
    }

    function testOutOfRangeAndMalformedComponentReturnReject() public {
        vm.expectRevert();
        discovery.nonSanctionComponentAt(scope, 9);
        _put(
            c.referenceRender,
            abi.encodeCall(IStreamArtworkFinalityComponent.finalityState, (1)),
            new bytes(257)
        );
        vm.expectRevert();
        discovery.nonSanctionDiscoveryFacts(scope);
    }

    function testFuzzComponentSourceDriftChangesIndependentHash(bytes32 source) public {
        (uint256 n, bytes32 beforeHash) = discovery.nonSanctionDiscoveryFacts(scope);
        require(n == 9);
        bytes32 original =
            keccak256(abi.encode("original source", keccak256("SCRIPT_SOURCE"), scope));
        if (source == 0 || source == original) return;
        _put(
            c.provider,
            abi.encodeCall(
                IStreamFinalityComponentFacts.finalityComponentFacts,
                (keccak256("SCRIPT_SOURCE"), scope)
            ),
            abi.encode(
                StreamFinalityHostComponentFacts(
                    true, keccak256("version"), keccak256("manifest"), source
                )
            )
        );
        (, bytes32 afterHash) = discovery.nonSanctionDiscoveryFacts(scope);
        require(beforeHash != afterHash);
    }

    function testInterfaceAdmissionRejectsAbsentFalseNoncanonicalAndInvalidIdentifier() public {
        bytes memory callData = abi.encodeCall(
            IERC165.supportsInterface, (type(IStreamArtworkFinalityComponent).interfaceId)
        );
        DiscoveryReadTable(c.referenceRender).remove(callData);
        vm.expectRevert();
        new StreamFinalityCurrentDiscovery(c);
        _put(c.referenceRender, callData, abi.encode(false));
        vm.expectRevert();
        new StreamFinalityCurrentDiscovery(c);
        _put(c.referenceRender, callData, abi.encode(uint256(2)));
        vm.expectRevert();
        new StreamFinalityCurrentDiscovery(c);
        _put(c.referenceRender, callData, abi.encode(true));
        _put(
            c.referenceRender,
            abi.encodeCall(IERC165.supportsInterface, (bytes4(0xffffffff))),
            abi.encode(true)
        );
        vm.expectRevert();
        new StreamFinalityCurrentDiscovery(c);
    }

    function testReferenceAndSnapshotCannotDifferFromTheInputProvider() public {
        _address(c.provider, "referenceRenderHost()", c.artist);
        vm.expectRevert();
        new StreamFinalityCurrentDiscovery(c);
        _address(c.provider, "referenceRenderHost()", c.referenceRender);
        _address(c.referenceRender, "snapshots()", c.metadata);
        vm.expectRevert();
        new StreamFinalityCurrentDiscovery(c);
    }

    function testCountIsStructuralAndSingleSlotReadDoesNotRevalidateAllOtherRecords() public {
        _record(c.referenceRender, keccak256("REFERENCE_RENDER"), false);
        require(discovery.finalityComponentCount(1) == 10);
        // Locate one independent Router slot by its known permanent family ordering.
        uint256 index;
        bytes32 script = keccak256("SCRIPT_SOURCE");
        for (uint256 i; i < 7; ++i) {
            if (_family(i) < script) ++index;
        }
        if (keccak256("ENTROPY_COORDINATOR") < script) ++index;
        if (keccak256("REFERENCE_RENDER") < script) ++index;
        require(discovery.nonSanctionComponentAt(scope, index).componentType == script);
        vm.expectRevert();
        discovery.nonSanctionDiscoveryFacts(scope);
    }
}

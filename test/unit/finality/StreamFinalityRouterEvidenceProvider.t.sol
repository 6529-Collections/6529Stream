// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../../../smart-contracts/domains/finality/StreamFinalityRouterEvidenceProvider.sol";
import "../../../smart-contracts/interfaces/stream/finality/IStreamFinalityEvidenceProvider.sol";
import "../../../smart-contracts/domains/finality/StreamFinalityServingHostAdapter.sol";
import {
    StreamMetadataRouter
} from "../../../smart-contracts/domains/metadata/StreamMetadataRouter.sol";
import {
    StreamMetadataTokenRenderer
} from "../../../smart-contracts/domains/metadata/StreamMetadataTokenRenderer.sol";
import "../../../smart-contracts/interfaces/stream/artist/IStreamArtistAttribution.sol";
import "../../../smart-contracts/interfaces/stream/artist/IStreamArtistAttributionState.sol";
import "../../../smart-contracts/interfaces/stream/artist/IStreamArtistContentRatification.sol";
import "../../regression/legacy/helpers/CharacterizationTestBase.sol";
import "../../helpers/OfficialSafeFixture.sol";

contract RouterEvidenceCoreBoundary {
    mapping(bytes32 => StreamMetadataRecoveryRoutes.Pointer) private pointers;
    bool public frozen;

    function set(bytes32 kind, StreamMetadataRecoveryRoutes.Pointer calldata p) external {
        pointers[kind] = p;
    }

    function getSatellitePointer(bytes32 kind)
        external
        view
        returns (StreamMetadataRecoveryRoutes.Pointer memory)
    {
        return pointers[kind];
    }

    function supportsInterface(bytes4 id) external pure returns (bool) {
        return id == 0x80ac58cd;
    }

    function collectionExists(uint256 id) external pure returns (bool) {
        return id == 1;
    }

    function collectionFreezeStatus(uint256) external view returns (bool) {
        return frozen;
    }

    function collectionMintedEver(uint256) external pure returns (uint256) {
        return 0;
    }

    function setFrozen(bool value) external {
        frozen = value;
    }
}

contract RouterEvidenceMetadataBoundary {
    address public immutable core;

    constructor(address c) {
        core = c;
    }

    function supportsInterface(bytes4 id) external pure returns (bool) {
        return
            id == type(IERC165).interfaceId || id == type(IStreamCollectionMetadataV1).interfaceId;
    }

    function streamModuleType() external pure returns (bytes32) {
        return keccak256("COLLECTION_METADATA");
    }

    function streamModuleInterfaceId() external pure returns (bytes4) {
        return type(IStreamCollectionMetadataV1).interfaceId;
    }
}

contract RouterEvidenceMembershipBoundary {
    address public immutable core;
    address public immutable metadataHost;
    uint8 public fault;

    constructor(address c, address m) {
        core = c;
        metadataHost = m;
    }

    function setFault(uint8 value) external {
        fault = value;
    }

    function requireScopeMembership(StreamFinalityScope calldata scope)
        external
        view
        returns (StreamScopeMembershipFacts memory f)
    {
        require(fault != 1, "unknown membership");
        if (fault == 2) assembly ("memory-safe") { return(0, 255) }
        f.scopeSubject = fault == 3
            ? bytes32(0)
            : StreamMetadataSubjects.scopeSubject(block.chainid, core, scope);
        f.membershipHash = keccak256(abi.encode(scope));
        f.tokenCount = 1;
    }
}

contract RouterEvidenceRegistryBoundary {
    bool public eligible = true;

    function setEligible(bool value) external {
        eligible = value;
    }

    function isModuleEligible(address, bytes32, bytes4) external view returns (bool) {
        return eligible;
    }
}

contract RouterEvidenceFinalityBoundary {
    address public immutable coreReads;
    address public sanctionReads;
    address public scopeEvidenceProvider;
    address public metadataReads;
    bytes32 public scopeEvidenceProviderCodeHash;

    constructor(address c) {
        coreReads = c;
    }

    function bind(address artist, address provider, address metadata) external {
        sanctionReads = artist;
        scopeEvidenceProvider = provider;
        scopeEvidenceProviderCodeHash = provider.codehash;
        metadataReads = metadata;
    }

    function supportsInterface(bytes4 id) external pure returns (bool) {
        return
            id == type(IERC165).interfaceId
                || id == type(IStreamArtworkFinalityRegistry).interfaceId;
    }

    function streamModuleType() external pure returns (bytes32) {
        return keccak256("ARTWORK_FINALITY_REGISTRY");
    }

    function streamModuleInterfaceId() external pure returns (bytes4) {
        return type(IStreamArtworkFinalityRegistry).interfaceId;
    }
}

contract RouterEvidenceArtistBoundary {
    address public immutable core;
    address public immutable finalityRegistry;
    bytes32 public immutable finalityRegistryCodeHash;

    constructor(address c, address f) {
        core = c;
        finalityRegistry = f;
        finalityRegistryCodeHash = f.codehash;
    }

    function supportsInterface(bytes4 id) external pure returns (bool) {
        return id == type(IERC165).interfaceId || id == type(IStreamArtistAttribution).interfaceId
            || id == type(IStreamArtistContentRatification).interfaceId
            || id == type(IStreamArtistAttributionState).interfaceId;
    }

    function collectionArtistState(uint256)
        external
        pure
        returns (uint8, uint64, bytes32, uint8, bytes32)
    {
        return (2, 4, keccak256("artist"), 1, keccak256("binding"));
    }

    function attribution(uint256)
        external
        pure
        returns (IStreamCollectionArtistRegistry.Attribution memory)
    {
        return IStreamCollectionArtistRegistry.Attribution(
            address(0xA11CE),
            address(0xA11CE),
            keccak256("identity"),
            keccak256("binding"),
            keccak256("acceptance"),
            4,
            0
        );
    }

    function firstReleaseRatification(uint256) external pure returns (bool, bytes32, bytes32) {
        return (false, 0, 0);
    }
}

/// @notice Actual Router/provider/linked library/Safe; custody, metadata, membership and graph authority are explicit fixtures.
contract StreamFinalityRouterEvidenceProviderTest is CharacterizationTestBase, OfficialSafeFixture {
    event log_named_uint(string label, uint256 used);
    RouterEvidenceCoreBoundary private core;
    RouterEvidenceMetadataBoundary private metadata;
    RouterEvidenceMembershipBoundary private membership;
    RouterEvidenceArtistBoundary private artist;
    RouterEvidenceFinalityBoundary private original;
    RouterEvidenceRegistryBoundary private registry;
    StreamMetadataRouter private router;
    StreamFinalityRouterEvidenceProvider private provider;
    bytes32 private constant ROUTER = keccak256("METADATA_ROUTER");
    bytes32 private constant SCRIPT = keccak256("SCRIPT_SOURCE");
    bytes32 private constant MEDIA = keccak256("MEDIA_MANIFEST");
    bytes32 private constant RENDERER = keccak256("RENDERER");
    bytes32 private constant CONTEXT = keccak256("RENDER_CONTEXT");
    bytes32 private constant DEPENDENCIES = keccak256("DEPENDENCY_SOURCE");

    function setUp() public {
        vm.warp(1000);
        core = new RouterEvidenceCoreBoundary();
        metadata = new RouterEvidenceMetadataBoundary(address(core));
        membership = new RouterEvidenceMembershipBoundary(address(core), address(metadata));
        original = new RouterEvidenceFinalityBoundary(address(core));
        artist = new RouterEvidenceArtistBoundary(address(core), address(original));
        registry = new RouterEvidenceRegistryBoundary();
        router = _router("urn:actual-router");
        provider = _provider(router);
        original.bind(address(artist), address(provider), address(metadata));
        _install();
        router.setCollectionMetadata(
            1, "Name", "Description", "ipfs://image", "https://example.test/"
        );
        router.setCollectionScript(1, "return 1;");
    }

    function _router(string memory uri) private returns (StreamMetadataRouter) {
        return new StreamMetadataRouter(
            address(core),
            address(this),
            keccak256("deployment"),
            uri,
            keccak256("actual manifest"),
            IStreamArtistAttribution(address(artist))
        );
    }

    function _provider(StreamMetadataRouter r)
        private
        returns (StreamFinalityRouterEvidenceProvider)
    {
        return new StreamFinalityRouterEvidenceProvider(
            address(core), address(metadata), address(r), address(membership), 500000, 2000000
        );
    }

    function _scope() private pure returns (StreamFinalityScope memory) {
        return StreamFinalityScope(StreamFinalityScopeType.COLLECTION, 1, 0, 0);
    }

    function _facts(bytes32 family) private view returns (StreamFinalityHostComponentFacts memory) {
        return provider.finalityComponentFacts(family, _scope());
    }

    function _set(bytes32 kind, address target, bytes4 id) private {
        core.set(
            kind,
            StreamMetadataRecoveryRoutes.Pointer(
                target,
                target.codehash,
                false,
                kind,
                id,
                address(registry),
                1,
                keccak256("manifest"),
                keccak256("deployment"),
                1
            )
        );
    }

    function _install() private {
        _set(keccak256("MODULE_REGISTRY"), address(registry), bytes4(0));
        _set(
            keccak256("ARTIST_REGISTRY"),
            address(artist),
            type(IStreamArtistAttribution).interfaceId
        );
        _set(
            keccak256("ARTWORK_FINALITY_REGISTRY"),
            address(original),
            type(IStreamArtworkFinalityRegistry).interfaceId
        );
        _set(
            keccak256("COLLECTION_METADATA"),
            address(metadata),
            type(IStreamCollectionMetadataV1).interfaceId
        );
        _set(ROUTER, address(router), type(IStreamMetadataRouter).interfaceId);
    }

    function testConcreteProviderPinsActualHostsAndAdvertisesOnlyImplementedInterfaces() public {
        require(
            provider.core() == address(core) && provider.metadataHost() == address(metadata),
            "actual graph"
        );
        require(
            provider.scopeMembershipHost() == address(membership)
                && provider.scopeMembershipHostCodeHash() == address(membership).codehash,
            "fixed membership"
        );
        require(
            provider.routerModuleVersion() == router.streamModuleVersion()
                && provider.routerModuleManifestHash() == keccak256("actual manifest"),
            "actual module metadata"
        );
        require(
            provider.supportsInterface(type(IStreamFinalityServingEvidenceProvider).interfaceId),
            "serving"
        );
        require(
            !provider.supportsInterface(type(IStreamFinalityEvidenceProvider).interfaceId)
                && !provider.supportsInterface(0xffffffff),
            "no full provider claim"
        );
        vm.expectRevert();
        provider.componentHost(keccak256("ENTROPY_COORDINATOR"));
    }

    function testConstructorDoesNotRequireSelectedPointersOrLiveFinalityFacade() public {
        core.set(
            ROUTER,
            StreamMetadataRecoveryRoutes.Pointer(address(0), 0, false, 0, 0, address(0), 0, 0, 0, 0)
        );
        vm.etch(address(original), hex"");
        StreamFinalityRouterEvidenceProvider fresh = _provider(router);
        require(fresh.metadataRouter() == address(router), "construct before Coordinator/Registry");
    }

    function testExactScriptCommitmentHasIndependentManualPreimage() public view {
        bytes32 payload = keccak256(abi.encode(keccak256("return 1;"), uint32(9)));
        bytes32 expected = keccak256(
            abi.encode(
                keccak256("6529STREAM_ROUTER_COMPONENT_EVIDENCE_V1"),
                block.chainid,
                address(core),
                address(router),
                SCRIPT,
                _scope(),
                payload
            )
        );
        StreamFinalityHostComponentFacts memory f = _facts(SCRIPT);
        require(f.dataHash == expected && !f.frozen, "actual stored script and explicit lock");
    }

    function testScriptChangeOnlyChangesScriptFamilyWhenModeUnchanged() public {
        bytes32[6] memory kinds = [ROUTER, SCRIPT, MEDIA, RENDERER, CONTEXT, DEPENDENCIES];
        bytes32[6] memory beforeHashes;
        for (uint256 i; i < 6; ++i) {
            beforeHashes[i] = _facts(kinds[i]).dataHash;
        }
        router.setCollectionScript(1, "return 2;");
        for (uint256 i; i < 6; ++i) {
            require((_facts(kinds[i]).dataHash != beforeHashes[i]) == (i == 1), "family separation");
        }
    }

    function testMediaChangePreservesDisplayScriptRendererAndProfileFamilies() public {
        bytes32[6] memory kinds = [ROUTER, SCRIPT, MEDIA, RENDERER, CONTEXT, DEPENDENCIES];
        bytes32[6] memory beforeHashes;
        for (uint256 i; i < 6; ++i) {
            beforeHashes[i] = _facts(kinds[i]).dataHash;
        }
        router.setCollectionMetadata(
            1, "Name", "Description", "ipfs://different", "https://example.test/"
        );
        for (uint256 i; i < 6; ++i) {
            require((_facts(kinds[i]).dataHash != beforeHashes[i]) == (i == 2), "family separation");
        }
    }

    function testRendererCodeLossDoesNotInvalidateOtherFamilies() public {
        bytes32[6] memory kinds = [ROUTER, SCRIPT, MEDIA, RENDERER, CONTEXT, DEPENDENCIES];
        bytes32[6] memory beforeHashes;
        for (uint256 i; i < 6; ++i) {
            beforeHashes[i] = _facts(kinds[i]).dataHash;
        }
        vm.etch(address(StreamMetadataTokenRenderer), hex"");
        for (uint256 i; i < 6; ++i) {
            require(
                (_facts(kinds[i]).dataHash != beforeHashes[i]) == (i == 3), "renderer-only loss"
            );
        }
        require(!_facts(RENDERER).frozen, "unavailable renderer not ready");
    }

    function testCoreFreezeDoesNotInventContentLocksAndDisplayLocksAreActual() public {
        core.setFrozen(true);
        require(
            !_facts(ROUTER).frozen && !_facts(SCRIPT).frozen && !_facts(MEDIA).frozen,
            "Core is not metadata authority"
        );
        router.lockArtistIdentity(1);
        router.lockDisplayMetadata(1);
        require(
            _facts(ROUTER).frozen && !_facts(SCRIPT).frozen && !_facts(MEDIA).frozen,
            "independent explicit locks"
        );
        require(
            _facts(CONTEXT).frozen && _facts(DEPENDENCIES).frozen && _facts(RENDERER).frozen,
            "actual immutable profiles"
        );
    }

    function testScopeShapeUnknownMembershipAndMalformedResultsReject() public {
        StreamFinalityScope memory s = _scope();
        s.tokenId = 1;
        vm.expectRevert();
        provider.finalityComponentFacts(SCRIPT, s);
        for (uint8 i = 1; i <= 3; ++i) {
            membership.setFault(i);
            vm.expectRevert();
            provider.finalityComponentFacts(SCRIPT, _scope());
        }
        membership.setFault(0);
        require(_facts(SCRIPT).dataHash != 0, "exact retry");
    }

    function testEveryFixedRuntimePinRejectsAndRestores() public {
        address[4] memory targets =
            [address(core), address(metadata), address(router), address(membership)];
        for (uint256 i; i < 4; ++i) {
            bytes memory code = targets[i].code;
            vm.etch(targets[i], hex"00");
            vm.expectRevert();
            provider.finalityComponentFacts(SCRIPT, _scope());
            vm.etch(targets[i], code);
            require(_facts(SCRIPT).dataHash != 0, "restored pin");
        }
    }

    function testCandidateRequiresLockedExactOriginalAnchorAndReciprocalProvider() public {
        vm.expectRevert();
        provider.requireCurrentRouterCandidate(1, address(original));
        router.lockArtistIdentity(1);
        provider.requireCurrentRouterCandidate(1, address(original));
        original.bind(address(artist), address(router), address(metadata));
        vm.expectRevert();
        provider.requireCurrentRouterCandidate(1, address(original));
        original.bind(address(artist), address(provider), address(metadata));
        provider.requireCurrentRouterCandidate(1, address(original));
    }

    function testCandidateCannotAdoptAnotherEligibleRegistryOverOldSavedAnchor() public {
        router.lockArtistIdentity(1);
        RouterEvidenceFinalityBoundary replacement =
            new RouterEvidenceFinalityBoundary(address(core));
        replacement.bind(address(artist), address(provider), address(metadata));
        _set(
            keccak256("ARTWORK_FINALITY_REGISTRY"),
            address(replacement),
            type(IStreamArtworkFinalityRegistry).interfaceId
        );
        vm.expectRevert();
        provider.requireCurrentRouterCandidate(1, address(replacement));
        require(_facts(ROUTER).dataHash != 0, "historical facts do not follow current registry");
    }

    function testCurrentRegistryEligibilityIsLiveWhileHistoricalFactsRemainReadable() public {
        router.lockArtistIdentity(1);
        bytes32 beforeHash = _facts(ROUTER).dataHash;
        registry.setEligible(false);
        vm.expectRevert();
        provider.requireCurrentRouterCandidate(1, address(original));
        require(
            _facts(ROUTER).dataHash == beforeHash, "current status does not rewrite original bytes"
        );
        registry.setEligible(true);
        provider.requireCurrentRouterCandidate(1, address(original));
    }

    function testCandidateJoinsSavedArtistAndOriginalRegistrySanctionSource() public {
        router.lockArtistIdentity(1);
        original.bind(address(router), address(provider), address(metadata));
        vm.expectRevert();
        provider.requireCurrentRouterCandidate(1, address(original));
        original.bind(address(artist), address(provider), address(metadata));
        provider.requireCurrentRouterCandidate(1, address(original));
    }

    function testActualFixedServingAdaptersConsumeAllSixFamilies() public {
        router.lockArtistIdentity(1);
        router.lockDisplayMetadata(1);
        bytes32[6] memory kinds = [ROUTER, SCRIPT, MEDIA, RENDERER, CONTEXT, DEPENDENCIES];
        for (uint256 i; i < 6; ++i) {
            StreamFinalityServingHostAdapter adapter = new StreamFinalityServingHostAdapter(
                address(core), address(router), address(provider), kinds[i]
            );
            adapter.requireCurrentSelection();
            StreamFinalityComponentState memory state = adapter.finalityState(1);
            StreamFinalityHostComponentFacts memory actual = _facts(kinds[i]);
            require(
                state.component == address(adapter) && state.componentType == kinds[i]
                    && state.codeHash == address(adapter).codehash
                    && state.dataHash == actual.dataHash && state.frozen == actual.frozen
                    && state.manifestHash == actual.manifestHash
                    && state.moduleVersion == actual.moduleVersion,
                "actual provider/adapter composition"
            );
        }
    }

    function testInsufficientParentGasRejectsAndExactReadRetries() public view {
        (bool ok,) = address(provider).staticcall{ gas: 100000 }(
            abi.encodeCall(provider.finalityComponentFacts, (SCRIPT, _scope()))
        );
        require(!ok && _facts(SCRIPT).dataHash != 0, "insufficient gas never becomes readiness");
    }

    function testMaximumColdSourceAndLongModuleURIUseActualBytes() public {
        StreamMetadataRouter large = _router(_text(4096, 117));
        StreamFinalityRouterEvidenceProvider actual = _provider(large);
        large.setCollectionMetadata(1, _text(256, 78), _text(2048, 68), _url(2048), _url(2048));
        large.setCollectionScript(1, _text(8192, 115));
        safeVm.cool(address(large));
        safeVm.cool(address(core));
        safeVm.cool(address(metadata));
        safeVm.cool(address(membership));
        uint256 beforeGas = gasleft();
        StreamFinalityHostComponentFacts memory f = actual.finalityComponentFacts(ROUTER, _scope());
        uint256 consumed = beforeGas - gasleft();
        require(
            f.dataHash != 0 && f.manifestHash == keccak256("actual manifest"), "full maximum source"
        );
        emit log_named_uint("router_provider_max_source_gas", consumed);
    }

    function testFuzzScopeIdentityCannotAliasAValidComponent(uint256 tokenId) public view {
        if (tokenId == 0) tokenId = 1;
        StreamFinalityScope memory token =
            StreamFinalityScope(StreamFinalityScopeType.TOKEN, 1, tokenId, 0);
        require(
            provider.finalityComponentFacts(SCRIPT, token).dataHash != _facts(SCRIPT).dataHash,
            "scope domain separation"
        );
    }

    function testThresholdSafeCanCallEverySupportedProviderSelector() public {
        router.lockArtistIdentity(1);
        uint256[] memory keys = new uint256[](2);
        keys[0] = 654321;
        keys[1] = 765432;
        OfficialSafe account =
            createOfficialSafe(deploySafeComponents("1.4.1"), safeOwnerAddresses(keys), 2, 187);
        bytes[] memory calls = new bytes[](19);
        calls[0] = abi.encodeCall(provider.core, ());
        calls[1] = abi.encodeCall(provider.coreCodeHash, ());
        calls[2] = abi.encodeCall(provider.metadataHost, ());
        calls[3] = abi.encodeCall(provider.metadataHostCodeHash, ());
        calls[4] = abi.encodeCall(provider.metadataRouter, ());
        calls[5] = abi.encodeCall(provider.metadataRouterCodeHash, ());
        calls[6] = abi.encodeCall(provider.scopeMembershipHost, ());
        calls[7] = abi.encodeCall(provider.scopeMembershipHostCodeHash, ());
        calls[8] = abi.encodeCall(provider.deploymentChainId, ());
        calls[9] = abi.encodeCall(provider.readGas, ());
        calls[10] = abi.encodeCall(provider.sourceGas, ());
        calls[11] = abi.encodeCall(provider.routerModuleVersion, ());
        calls[12] = abi.encodeCall(provider.routerModuleManifestHash, ());
        calls[13] = abi.encodeCall(
            provider.supportsInterface, (type(IStreamFinalityServingEvidenceProvider).interfaceId)
        );
        calls[14] = abi.encodeCall(provider.componentHost, (SCRIPT));
        calls[15] = abi.encodeCall(provider.finalityComponentFacts, (SCRIPT, _scope()));
        calls[16] = abi.encodeCall(provider.requireCurrentRouterCandidate, (1, address(original)));
        calls[17] = abi.encodeCall(provider.finalityComponentFacts, (ROUTER, _scope()));
        calls[18] = abi.encodeCall(provider.finalityComponentFacts, (CONTEXT, _scope()));
        for (uint256 i; i < calls.length; ++i) {
            require(
                executeSafe(account, keys, address(provider), 0, calls[i], 0), "Safe provider call"
            );
        }
        require(account.nonce() == calls.length, "all threshold transactions executed");
    }

    function _text(uint256 size, uint8 value) private pure returns (string memory) {
        bytes memory raw = new bytes(size);
        for (uint256 i; i < size; ++i) {
            raw[i] = bytes1(value);
        }
        return string(raw);
    }

    function _url(uint256 size) private pure returns (string memory) {
        return string.concat("https://example.test/", _text(size - 21, 97));
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../../smart-contracts/StreamArtworkFinalityPreview.sol";
import "../../smart-contracts/StreamArtworkFinalityRegistry.sol";
import "../../smart-contracts/StreamArtworkFinalityTypes.sol";
import "./Assertions.sol";
import "./CharacterizationTestBase.sol";
import "./FinalityMocks.sol";

/// @notice Shared harness for the artwork finality registry tests: deploys the registry and
///         its consumer-seam mocks and builds spec-conformant happy-path fixtures per scope.
abstract contract FinalityTestBase is CharacterizationTestBase {
    using Assertions for bool;
    using Assertions for bytes32;
    using Assertions for uint256;
    using Assertions for address;

    MockFinalityAuthority internal authority;
    MockFinalityCore internal coreMock;
    MockFinalityMetadata internal metadataMock;
    MockFinalitySanction internal sanctionMock;
    MockFinalityComponent internal metadataComponent;
    MockFinalityComponent internal rendererComponent;
    MockFinalityComponent internal sanctionComponent;
    StreamArtworkFinalityRegistry internal registry;
    StreamArtworkFinalityPreview internal previewer;

    address internal finalityAdmin = address(0xF14A11);
    address internal guardian = address(0x60A2D1);
    address internal outsider = address(0x00751D);

    uint256 internal constant COLLECTION_ID = 7;
    uint64 internal constant MINTED_SUPPLY = 10;
    uint64 internal constant BURNED_SUPPLY = 2;

    struct Fixture {
        StreamFinalityScope scope;
        StreamFinalityComponentExpectation[] components;
        StreamFinalityManifestRef manifest;
        bytes32 coreFactsHash;
        bytes32 componentsHash;
        bytes32 nonSanctionComponentsHash;
        bytes32 sanctionSubjectHash;
        bytes32 sanctionRecordHash;
        bytes32 expectedFinalityRecordHash;
        bytes32 scopeKey;
    }

    function setUp() public virtual {
        authority = new MockFinalityAuthority();
        coreMock = new MockFinalityCore();
        metadataMock = new MockFinalityMetadata();
        sanctionMock = new MockFinalitySanction();
        metadataComponent = new MockFinalityComponent();
        rendererComponent = new MockFinalityComponent();
        sanctionComponent = new MockFinalityComponent();
        registry = new StreamArtworkFinalityRegistry(
            address(coreMock),
            address(metadataMock),
            address(sanctionMock),
            address(authority),
            address(0)
        );
        previewer = new StreamArtworkFinalityPreview(registry);
        authority.setRole(
            StreamFinalityDomains.ROLE_COLLECTION_FINALITY_ADMIN, finalityAdmin, true
        );
        authority.setDefaultGuardian(guardian);
        vm.warp(1_750_000_000);
    }

    // ------------------------------------------------------------------
    // Scope builders
    // ------------------------------------------------------------------

    function _collectionScope(uint256 collectionId)
        internal
        pure
        returns (StreamFinalityScope memory)
    {
        return StreamFinalityScope({
            scopeType: StreamFinalityScopeType.COLLECTION,
            collectionId: collectionId,
            tokenId: 0,
            scopeId: bytes32(0)
        });
    }

    function _tokenScope(uint256 collectionId, uint256 tokenId)
        internal
        pure
        returns (StreamFinalityScope memory)
    {
        return StreamFinalityScope({
            scopeType: StreamFinalityScopeType.TOKEN,
            collectionId: collectionId,
            tokenId: tokenId,
            scopeId: bytes32(0)
        });
    }

    function _idScope(StreamFinalityScopeType scopeType, uint256 collectionId, bytes32 scopeId)
        internal
        pure
        returns (StreamFinalityScope memory)
    {
        return StreamFinalityScope({
            scopeType: scopeType,
            collectionId: collectionId,
            tokenId: 0,
            scopeId: scopeId
        });
    }

    function _scopeKeyOf(StreamFinalityScope memory scope) internal pure returns (bytes32) {
        return keccak256(
            abi.encode(uint8(scope.scopeType), scope.collectionId, scope.tokenId, scope.scopeId)
        );
    }

    // ------------------------------------------------------------------
    // Fact builders
    // ------------------------------------------------------------------

    function _emptyConfigHash(uint256 collectionId) internal view returns (bytes32) {
        return keccak256(
            abi.encode(
                StreamFinalityDomains.STREAM_CORE_COLLECTION_CONFIG_EMPTY_V1,
                block.chainid,
                address(coreMock),
                collectionId
            )
        );
    }

    function _closedCollectionFacts(uint256 collectionId)
        internal
        view
        returns (StreamCoreCollectionFinalityFacts memory)
    {
        return StreamCoreCollectionFinalityFacts({
            exists: true,
            hasMaxSupply: true,
            status: StreamFinalityDomains.CORE_COLLECTION_STATUS_CLOSED,
            supplyMode: 0,
            createdAt: uint64(block.timestamp) - 1000,
            maxSupply: MINTED_SUPPLY,
            mintedSupply: MINTED_SUPPLY,
            burnedSupply: BURNED_SUPPLY,
            nextCollectionSerial: MINTED_SUPPLY + 1,
            collectionConfigHash: _emptyConfigHash(collectionId)
        });
    }

    function _scopedFactsFor(StreamFinalityScope memory scope)
        internal
        view
        returns (StreamScopedCoreFinalityFacts memory facts)
    {
        facts.scopeExists = true;
        facts.scopeType = uint8(scope.scopeType);
        facts.collectionId = scope.collectionId;
        facts.tokenId = scope.tokenId;
        facts.scopeId = scope.scopeId;
        facts.collectionStatus = 0;
        facts.collectionSupplyMode = 2;
        facts.collectionConfigHash = _emptyConfigHash(scope.collectionId);
        if (scope.scopeType == StreamFinalityScopeType.TOKEN) {
            facts.tokenMappingExists = true;
            facts.collectionSerial = 3;
            facts.tokenLifecycle = StreamFinalityDomains.TOKEN_LIFECYCLE_MINTED;
        } else {
            facts.scopeManifestHash = keccak256(abi.encodePacked("scope-manifest", scope.scopeId));
        }
    }

    // ------------------------------------------------------------------
    // Component builders
    // ------------------------------------------------------------------

    function _expectationFor(
        MockFinalityComponent component,
        bytes32 componentType,
        bytes32 dataHash
    ) internal view returns (StreamFinalityComponentExpectation memory) {
        return StreamFinalityComponentExpectation({
            componentType: componentType,
            component: address(component),
            interfaceId: bytes4(0x517EA000),
            codeHash: address(component).codehash,
            moduleVersion: bytes32(uint256(1)),
            manifestHash: keccak256(abi.encodePacked("module-manifest", componentType)),
            dataHash: dataHash
        });
    }

    function _stateFor(StreamFinalityComponentExpectation memory expectation)
        internal
        pure
        returns (StreamFinalityComponentState memory)
    {
        return StreamFinalityComponentState({
            frozen: true,
            componentType: expectation.componentType,
            component: expectation.component,
            interfaceId: expectation.interfaceId,
            codeHash: expectation.codeHash,
            moduleVersion: expectation.moduleVersion,
            manifestHash: expectation.manifestHash,
            dataHash: expectation.dataHash
        });
    }

    function _installComponentState(
        StreamFinalityScope memory scope,
        StreamFinalityComponentExpectation memory expectation
    ) internal {
        MockFinalityComponent component = MockFinalityComponent(expectation.component);
        if (scope.scopeType == StreamFinalityScopeType.COLLECTION) {
            component.setCollectionState(scope.collectionId, _stateFor(expectation));
        } else {
            component.setScopedState(scope, _stateFor(expectation));
        }
    }

    function _sortComponents(StreamFinalityComponentExpectation[] memory components)
        internal
        pure
        returns (StreamFinalityComponentExpectation[] memory)
    {
        uint256 count = components.length;
        for (uint256 i = 1; i < count; i++) {
            StreamFinalityComponentExpectation memory key = components[i];
            uint256 j = i;
            while (j > 0 && !_ascending(components[j - 1], key)) {
                components[j] = components[j - 1];
                j--;
            }
            components[j] = key;
        }
        return components;
    }

    function _ascending(
        StreamFinalityComponentExpectation memory previous,
        StreamFinalityComponentExpectation memory next
    ) internal pure returns (bool) {
        if (previous.componentType != next.componentType) {
            return previous.componentType < next.componentType;
        }
        if (previous.component != next.component) {
            return previous.component < next.component;
        }
        if (previous.interfaceId != next.interfaceId) {
            return previous.interfaceId < next.interfaceId;
        }
        if (previous.codeHash != next.codeHash) {
            return previous.codeHash < next.codeHash;
        }
        if (previous.moduleVersion != next.moduleVersion) {
            return previous.moduleVersion < next.moduleVersion;
        }
        if (previous.manifestHash != next.manifestHash) {
            return previous.manifestHash < next.manifestHash;
        }
        return previous.dataHash < next.dataHash;
    }

    // ------------------------------------------------------------------
    // Manifest builder
    // ------------------------------------------------------------------

    function _stagedManifest(string memory uri, bytes memory manifestBytes)
        internal
        returns (StreamFinalityManifestRef memory manifest)
    {
        manifest.uri = uri;
        manifest.uriHash = keccak256(bytes(uri));
        manifest.contentHash = registry.stageFinalityManifest(manifestBytes);
        manifest.schemaId = keccak256("6529STREAM_TEST_MANIFEST_SCHEMA_V1");
        manifest.canonicalizationHash = keccak256("RFC8785_JCS");
    }

    // ------------------------------------------------------------------
    // Full fixtures
    // ------------------------------------------------------------------

    /// @notice Builds a fully-passing fixture for any scope: Core facts, content root,
    ///         manifest bytes, live component states, verified artist sanction, and the
    ///         computed expected finality record hash.
    function _buildFixture(StreamFinalityScope memory scope, bool artistBound)
        internal
        returns (Fixture memory fixture)
    {
        fixture.scope = scope;
        fixture.scopeKey = _scopeKeyOf(scope);

        if (scope.scopeType == StreamFinalityScopeType.COLLECTION) {
            coreMock.setCollectionFacts(scope.collectionId, _closedCollectionFacts(scope.collectionId));
            coreMock.setBurnsBlocked(scope.collectionId, true, uint64(block.number));
            fixture.coreFactsHash = registry.computeCollectionCoreFactsHash(scope.collectionId);
        } else {
            coreMock.setScopedFacts(scope, _scopedFactsFor(scope));
            fixture.coreFactsHash = registry.computeScopedCoreFactsHash(scope);
        }

        uint64 leafCount = scope.scopeType == StreamFinalityScopeType.COLLECTION
            ? MINTED_SUPPLY
            : scope.scopeType == StreamFinalityScopeType.TOKEN ? 1 : 4;
        metadataMock.setContentRoot(
            scope.collectionId,
            registry.contentRootScopeSubject(scope),
            keccak256(abi.encodePacked("content-root", fixture.scopeKey)),
            leafCount,
            keccak256("6529STREAM_TEST_CONTENT_ROOT_SCHEMA_V1")
        );

        fixture.manifest = _stagedManifest(
            "ar://finality-manifest",
            abi.encodePacked("canonical finality manifest bytes for ", fixture.scopeKey)
        );

        bytes32 sanctionType = artistBound
            ? StreamFinalityDomains.COMPONENT_ARTIST_SANCTION
            : StreamFinalityDomains.COMPONENT_PLATFORM_WORKS_DECLARATION;
        sanctionMock.setRequiredComponentType(scope.collectionId, sanctionType);

        // Non-sanction components first: their hash feeds the sanction subject hash.
        StreamFinalityComponentExpectation[] memory nonSanction =
            new StreamFinalityComponentExpectation[](2);
        nonSanction[0] = _expectationFor(
            metadataComponent,
            StreamFinalityDomains.COMPONENT_COLLECTION_METADATA,
            keccak256(abi.encodePacked("metadata-datahash", fixture.scopeKey))
        );
        nonSanction[1] = _expectationFor(
            rendererComponent,
            StreamFinalityDomains.COMPONENT_RENDERER,
            keccak256(abi.encodePacked("renderer-datahash", fixture.scopeKey))
        );

        fixture.sanctionRecordHash =
            keccak256(abi.encodePacked("sanction-record", fixture.scopeKey));
        StreamFinalityComponentExpectation memory sanctionEntry =
            _expectationFor(sanctionComponent, sanctionType, fixture.sanctionRecordHash);

        StreamFinalityComponentExpectation[] memory all =
            new StreamFinalityComponentExpectation[](3);
        all[0] = nonSanction[0];
        all[1] = nonSanction[1];
        all[2] = sanctionEntry;
        fixture.components = _sortComponents(all);

        for (uint256 i = 0; i < fixture.components.length; i++) {
            _installComponentState(scope, fixture.components[i]);
        }

        fixture.componentsHash = registry.computeComponentsHash(fixture.components);
        fixture.nonSanctionComponentsHash =
            registry.computeNonSanctionComponentsHash(fixture.components);
        fixture.sanctionSubjectHash = registry.computeSanctionSubjectHash(
            scope, fixture.coreFactsHash, fixture.nonSanctionComponentsHash, fixture.manifest
        );
        if (artistBound) {
            sanctionMock.setSanctionResponse(
                uint8(scope.scopeType),
                scope.collectionId,
                scope.tokenId,
                scope.scopeId,
                fixture.sanctionSubjectHash,
                true,
                fixture.sanctionRecordHash
            );
        }

        fixture.expectedFinalityRecordHash = registry.computeFinalityRecordHash(
            scope, fixture.coreFactsHash, fixture.componentsHash, fixture.manifest
        );
    }

    /// @notice Schedules the terminal freeze for a fixture and warps into the open window.
    function _scheduleAndOpen(Fixture memory fixture) internal {
        uint64 notBefore = uint64(block.timestamp) + registry.TERMINAL_FREEZE_VETO_FLOOR();
        uint64 expiresAfter = notBefore + registry.TERMINAL_FREEZE_EXECUTION_WINDOW_FLOOR();
        vm.prank(finalityAdmin);
        registry.scheduleArtworkTerminalFreeze(
            fixture.scope, fixture.expectedFinalityRecordHash, notBefore, expiresAfter
        );
        vm.warp(notBefore);
    }

    /// @notice Runs the full staged path and executes finality for the fixture.
    function _executeFixture(Fixture memory fixture) internal {
        _scheduleAndOpen(fixture);
        vm.prank(finalityAdmin);
        if (fixture.scope.scopeType == StreamFinalityScopeType.COLLECTION) {
            registry.finalizeCollectionArtwork(
                fixture.scope.collectionId,
                fixture.components,
                fixture.expectedFinalityRecordHash,
                fixture.manifest
            );
        } else {
            registry.finalizeArtworkScope(
                fixture.scope,
                fixture.components,
                fixture.expectedFinalityRecordHash,
                fixture.manifest
            );
        }
    }

    function _finalizeFixtureCall(Fixture memory fixture) internal {
        vm.prank(finalityAdmin);
        if (fixture.scope.scopeType == StreamFinalityScopeType.COLLECTION) {
            registry.finalizeCollectionArtwork(
                fixture.scope.collectionId,
                fixture.components,
                fixture.expectedFinalityRecordHash,
                fixture.manifest
            );
        } else {
            registry.finalizeArtworkScope(
                fixture.scope,
                fixture.components,
                fixture.expectedFinalityRecordHash,
                fixture.manifest
            );
        }
    }

    /// @notice Rebinds the staged hash and sanction response after fixture mutation.
    function _recomputeFixtureHashes(Fixture memory fixture, bool artistBound) internal {
        fixture.componentsHash = registry.computeComponentsHash(fixture.components);
        fixture.nonSanctionComponentsHash =
            registry.computeNonSanctionComponentsHash(fixture.components);
        fixture.sanctionSubjectHash = registry.computeSanctionSubjectHash(
            fixture.scope,
            fixture.coreFactsHash,
            fixture.nonSanctionComponentsHash,
            fixture.manifest
        );
        if (artistBound) {
            sanctionMock.setSanctionResponse(
                uint8(fixture.scope.scopeType),
                fixture.scope.collectionId,
                fixture.scope.tokenId,
                fixture.scope.scopeId,
                fixture.sanctionSubjectHash,
                true,
                fixture.sanctionRecordHash
            );
        }
        fixture.expectedFinalityRecordHash = registry.computeFinalityRecordHash(
            fixture.scope, fixture.coreFactsHash, fixture.componentsHash, fixture.manifest
        );
    }
}

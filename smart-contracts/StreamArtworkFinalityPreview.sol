// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./IStreamArtworkFinalityComponents.sol";
import "./IStreamFinalityCoreReads.sol";
import "./IStreamFinalityMetadataReads.sol";
import "./IStreamFinalitySanctionReads.sol";
import "./StreamArtworkFinalityRegistry.sol";
import "./StreamArtworkFinalityTypes.sol";

/// @notice The finality registry's preview surface: previewFinality per [LTA-FINALITY]
///         exposes every comparison finalization performs — plus the computed sanction
///         subject hash the artist signs ([AA-SANCTION] requirement 2) — before any
///         state-changing finality transaction is sent.
/// @dev View-only periphery bound to one registry. Every pinned preimage is recomputed
///      through the registry's compute* views, never re-derived here, so preview and
///      execution cannot drift on a hash; gate semantics are covered by tests that assert
///      preview flags against execution outcomes.
contract StreamArtworkFinalityPreview {
    error FinalityPreviewZeroAddress();

    StreamArtworkFinalityRegistry public immutable registry;
    IStreamFinalityCoreReads public immutable coreReads;
    IStreamFinalityMetadataReads public immutable metadataReads;
    IStreamFinalitySanctionReads public immutable sanctionReads;
    address public immutable finalityDiscovery;

    constructor(StreamArtworkFinalityRegistry registry_) {
        if (address(registry_) == address(0)) {
            revert FinalityPreviewZeroAddress();
        }
        registry = registry_;
        coreReads = registry_.coreReads();
        metadataReads = registry_.metadataReads();
        sanctionReads = registry_.sanctionReads();
        finalityDiscovery = registry_.finalityDiscovery();
    }

    function previewCollectionFinality(
        uint256 collectionId,
        StreamFinalityComponentExpectation[] calldata components,
        StreamFinalityManifestRef calldata manifest
    ) external view returns (StreamFinalityPreview memory) {
        return _preview(
            StreamFinalityScope({
                scopeType: StreamFinalityScopeType.COLLECTION,
                collectionId: collectionId,
                tokenId: 0,
                scopeId: bytes32(0)
            }),
            components,
            manifest
        );
    }

    function previewArtworkScopeFinality(
        StreamFinalityScope calldata scope,
        StreamFinalityComponentExpectation[] calldata components,
        StreamFinalityManifestRef calldata manifest
    ) external view returns (StreamFinalityPreview memory) {
        return _preview(scope, components, manifest);
    }

    // ------------------------------------------------------------------
    // Internal composition
    // ------------------------------------------------------------------

    function _preview(
        StreamFinalityScope memory scope,
        StreamFinalityComponentExpectation[] calldata components,
        StreamFinalityManifestRef calldata manifest
    ) private view returns (StreamFinalityPreview memory p) {
        if (!_isCanonicalScopeShape(scope)) {
            return p;
        }
        p.notAlreadyFinalized = !registry.artworkScopeFinalityRecord(scope).finalized;
        p.componentsWellFormed = _componentListWellFormed(components);
        p.computedComponentsHash = registry.computeComponentsHash(components);
        p.computedNonSanctionComponentsHash = registry.computeNonSanctionComponentsHash(components);
        p.manifestSatisfied = _manifestSatisfied(manifest);

        (p.coreGatesSatisfied, p.computedCoreFactsHash, p.contentRootSatisfied) =
            _coreAndContentRoot(scope);
        p.facadeBindingSatisfied = _facadeBindingSatisfied(scope.collectionId);
        (p.sanctionSatisfied, p.computedSanctionSubjectHash) = _sanction(
            scope,
            components,
            p.computedCoreFactsHash,
            p.computedNonSanctionComponentsHash,
            manifest
        );
        p.componentsMatchLive = _componentsMatchLive(scope, components);
        p.discoveryMatches = _discoveryMatches(scope, components.length, p.computedComponentsHash);

        p.computedFinalityRecordHash = registry.computeFinalityRecordHash(
            scope, p.computedCoreFactsHash, p.computedComponentsHash, manifest
        );
        p.stagedFreezeReady = _stagedFreezeReady(scope, p.computedFinalityRecordHash);

        p.wouldExecute = p.notAlreadyFinalized && p.stagedFreezeReady && p.coreGatesSatisfied
            && p.contentRootSatisfied && p.manifestSatisfied && p.componentsWellFormed
            && p.componentsMatchLive && p.sanctionSatisfied && p.facadeBindingSatisfied
            && p.discoveryMatches;
    }

    function _stagedFreezeReady(StreamFinalityScope memory scope, bytes32 computedRecordHash)
        private
        view
        returns (bool)
    {
        StreamTerminalFreezeAction memory action = registry.artworkTerminalFreezeAction(scope);
        return action.status == StreamTerminalFreezeStatus.SCHEDULED
            && block.timestamp >= action.notBefore && block.timestamp <= action.expiresAfter
            && action.expectedFinalityRecordHash == computedRecordHash;
    }

    function _manifestSatisfied(StreamFinalityManifestRef calldata manifest)
        private
        view
        returns (bool)
    {
        return manifest.uriHash == keccak256(bytes(manifest.uri))
            && manifest.contentHash != bytes32(0) && manifest.schemaId != bytes32(0)
            && manifest.canonicalizationHash != bytes32(0)
            && registry.finalityManifestStored(manifest.contentHash);
    }

    function _coreAndContentRoot(StreamFinalityScope memory scope)
        private
        view
        returns (bool coreGatesSatisfied, bytes32 factsHash, bool contentRootSatisfied)
    {
        uint64 expectedLeafCount;
        bool exactLeafCount;
        if (scope.scopeType == StreamFinalityScopeType.COLLECTION) {
            StreamCoreCollectionFinalityFacts memory facts =
                coreReads.coreCollectionFinalityFacts(scope.collectionId);
            factsHash = registry.computeCollectionCoreFactsHash(scope.collectionId);
            coreGatesSatisfied = facts.exists
                && facts.status == StreamFinalityDomains.CORE_COLLECTION_STATUS_CLOSED
                && coreReads.collectionBurnsBlocked(scope.collectionId);
            expectedLeafCount = facts.mintedSupply;
            exactLeafCount = true;
        } else {
            StreamScopedCoreFinalityFacts memory scopedFacts =
                coreReads.scopedCoreFinalityFacts(scope);
            factsHash = registry.computeScopedCoreFactsHash(scope);
            coreGatesSatisfied = scopedFacts.scopeExists
                && scopedFacts.scopeType == uint8(scope.scopeType)
                && scopedFacts.collectionId == scope.collectionId
                && scopedFacts.tokenId == scope.tokenId && scopedFacts.scopeId == scope.scopeId;
            if (scope.scopeType == StreamFinalityScopeType.TOKEN) {
                coreGatesSatisfied = coreGatesSatisfied && scopedFacts.tokenMappingExists
                    && (scopedFacts.tokenLifecycle == StreamFinalityDomains.TOKEN_LIFECYCLE_MINTED
                        || scopedFacts.tokenLifecycle
                            == StreamFinalityDomains.TOKEN_LIFECYCLE_BURNED);
                expectedLeafCount = 1;
                exactLeafCount = true;
            }
        }
        contentRootSatisfied = _contentRootSatisfied(scope, expectedLeafCount, exactLeafCount);
    }

    function _contentRootSatisfied(
        StreamFinalityScope memory scope,
        uint64 expectedLeafCount,
        bool exactLeafCount
    ) private view returns (bool) {
        (bytes32 contentRoot, uint64 leafCount,) = metadataReads.tokenContentRoot(
            scope.collectionId, registry.contentRootScopeSubject(scope)
        );
        if (contentRoot == bytes32(0)) {
            return false;
        }
        return exactLeafCount ? leafCount == expectedLeafCount : leafCount != 0;
    }

    function _facadeBindingSatisfied(uint256 collectionId) private view returns (bool) {
        if (
            coreReads.collectionIdentityMode(collectionId)
                != StreamFinalityDomains.IDENTITY_MODE_EXTERNAL_FACADE
        ) {
            return true;
        }
        (bool recorded, address facadeAddress,) =
            metadataReads.facadeIdentityBindingRecord(collectionId);
        address controller = coreReads.collectionTransferController(collectionId);
        return recorded && facadeAddress != address(0) && facadeAddress == controller;
    }

    function _sanction(
        StreamFinalityScope memory scope,
        StreamFinalityComponentExpectation[] calldata components,
        bytes32 coreFactsHash,
        bytes32 nonSanctionComponentsHash,
        StreamFinalityManifestRef calldata manifest
    ) private view returns (bool satisfied, bytes32 sanctionSubjectHash) {
        sanctionSubjectHash = registry.computeSanctionSubjectHash(
            scope, coreFactsHash, nonSanctionComponentsHash, manifest
        );
        (uint256 index, uint256 occurrences) = _locateSanctionSlot(components);
        if (occurrences != 1) {
            return (false, sanctionSubjectHash);
        }
        bytes32 requiredType = sanctionReads.collectionSanctionComponentType(scope.collectionId);
        if (components[index].componentType != requiredType) {
            return (false, sanctionSubjectHash);
        }
        if (requiredType != StreamFinalityDomains.COMPONENT_ARTIST_SANCTION) {
            return (true, sanctionSubjectHash);
        }
        (bool valid, bytes32 sanctionRecordHash) = _sanctionVerification(scope, sanctionSubjectHash);
        return (valid && sanctionRecordHash == components[index].dataHash, sanctionSubjectHash);
    }

    function _sanctionVerification(StreamFinalityScope memory scope, bytes32 sanctionSubjectHash)
        private
        view
        returns (bool valid, bytes32 sanctionRecordHash)
    {
        (valid, sanctionRecordHash,,) = sanctionReads.verifySanctionForSubject(
            uint8(scope.scopeType),
            scope.collectionId,
            scope.tokenId,
            scope.scopeId,
            sanctionSubjectHash
        );
    }

    function _locateSanctionSlot(StreamFinalityComponentExpectation[] calldata components)
        private
        pure
        returns (uint256 index, uint256 occurrences)
    {
        uint256 count = components.length;
        for (uint256 i = 0; i < count; i++) {
            bytes32 componentType = components[i].componentType;
            if (
                componentType == StreamFinalityDomains.COMPONENT_ARTIST_SANCTION
                    || componentType == StreamFinalityDomains.COMPONENT_PLATFORM_WORKS_DECLARATION
            ) {
                index = i;
                occurrences++;
            }
        }
    }

    function _componentListWellFormed(StreamFinalityComponentExpectation[] calldata components)
        private
        view
        returns (bool)
    {
        uint256 count = components.length;
        if (count == 0 || count > registry.MAX_FINALITY_COMPONENTS()) {
            return false;
        }
        for (uint256 i = 1; i < count; i++) {
            if (!_strictlyAscending(components[i - 1], components[i])) {
                return false;
            }
        }
        return true;
    }

    function _strictlyAscending(
        StreamFinalityComponentExpectation calldata previous,
        StreamFinalityComponentExpectation calldata next
    ) private pure returns (bool) {
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
        if (previous.dataHash != next.dataHash) {
            return previous.dataHash < next.dataHash;
        }
        return false;
    }

    function _componentsMatchLive(
        StreamFinalityScope memory scope,
        StreamFinalityComponentExpectation[] calldata components
    ) private view returns (bool) {
        bytes memory componentCallData = _componentCallData(scope);
        uint256 count = components.length;
        for (uint256 i = 0; i < count; i++) {
            if (!_componentMatches(components[i], componentCallData)) {
                return false;
            }
        }
        return true;
    }

    function _componentMatches(
        StreamFinalityComponentExpectation memory expectation,
        bytes memory componentCallData
    ) private view returns (bool) {
        address component = expectation.component;
        if (component.code.length == 0 || component.codehash != expectation.codeHash) {
            return false;
        }
        (bool success, bytes memory returndata) = component.staticcall(componentCallData);
        if (!success || returndata.length != 256) {
            return false;
        }
        (bool ok, StreamFinalityComponentState memory state) = _decodeComponentState(returndata);
        if (!ok) {
            return false;
        }
        return state.frozen && state.componentType == expectation.componentType
            && state.component == expectation.component
            && state.interfaceId == expectation.interfaceId
            && state.codeHash == expectation.codeHash
            && state.moduleVersion == expectation.moduleVersion
            && state.manifestHash == expectation.manifestHash
            && state.dataHash == expectation.dataHash;
    }

    function _decodeComponentState(bytes memory returndata)
        private
        pure
        returns (bool ok, StreamFinalityComponentState memory state)
    {
        uint256 rawFrozen;
        bytes32 componentType;
        uint256 rawComponent;
        uint256 rawInterfaceId;
        bytes32 codeHash;
        bytes32 moduleVersion;
        bytes32 manifestHash;
        bytes32 dataHash;
        assembly {
            rawFrozen := mload(add(returndata, 0x20))
            componentType := mload(add(returndata, 0x40))
            rawComponent := mload(add(returndata, 0x60))
            rawInterfaceId := mload(add(returndata, 0x80))
            codeHash := mload(add(returndata, 0xa0))
            moduleVersion := mload(add(returndata, 0xc0))
            manifestHash := mload(add(returndata, 0xe0))
            dataHash := mload(add(returndata, 0x100))
        }
        if (rawFrozen > 1 || rawComponent > type(uint160).max) {
            return (false, state);
        }
        if (rawInterfaceId & ((uint256(1) << 224) - 1) != 0) {
            return (false, state);
        }
        state = StreamFinalityComponentState({
            frozen: rawFrozen == 1,
            componentType: componentType,
            component: address(uint160(rawComponent)),
            interfaceId: bytes4(bytes32(rawInterfaceId)),
            codeHash: codeHash,
            moduleVersion: moduleVersion,
            manifestHash: manifestHash,
            dataHash: dataHash
        });
        return (true, state);
    }

    function _componentCallData(StreamFinalityScope memory scope)
        private
        pure
        returns (bytes memory)
    {
        if (scope.scopeType == StreamFinalityScopeType.COLLECTION) {
            return abi.encodeWithSelector(
                IStreamArtworkFinalityComponent.finalityState.selector, scope.collectionId
            );
        }
        return abi.encodeWithSelector(
            IStreamArtworkScopedFinalityComponent.finalityStateForScope.selector, scope
        );
    }

    function _discoveryMatches(
        StreamFinalityScope memory scope,
        uint256 submittedCount,
        bytes32 submittedHash
    ) private view returns (bool) {
        address discovery = finalityDiscovery;
        if (discovery == address(0)) {
            return true;
        }
        if (scope.scopeType == StreamFinalityScopeType.COLLECTION) {
            return IStreamArtworkFinalityDiscovery(discovery)
                        .finalityComponentCount(scope.collectionId) == submittedCount
                && IStreamArtworkFinalityDiscovery(discovery)
                        .finalityDiscoveryHash(scope.collectionId) == submittedHash;
        }
        return IStreamArtworkScopedFinalityDiscovery(discovery)
                    .finalityComponentCountForScope(scope) == submittedCount
            && IStreamArtworkScopedFinalityDiscovery(discovery).finalityDiscoveryHashForScope(scope)
                == submittedHash;
    }

    function _isCanonicalScopeShape(StreamFinalityScope memory scope) private pure returns (bool) {
        if (scope.collectionId == 0) {
            return false;
        }
        if (scope.scopeType == StreamFinalityScopeType.COLLECTION) {
            return scope.tokenId == 0 && scope.scopeId == bytes32(0);
        }
        if (scope.scopeType == StreamFinalityScopeType.TOKEN) {
            return scope.tokenId != 0 && scope.scopeId == bytes32(0);
        }
        return scope.tokenId == 0 && scope.scopeId != bytes32(0);
    }
}

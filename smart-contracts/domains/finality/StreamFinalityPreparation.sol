// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../../interfaces/stream/finality/IStreamArtworkFinalityComponents.sol";
import "../../interfaces/stream/finality/IStreamArtworkFinalityRegistry.sol";
import "../../vendor/openzeppelin/IERC165.sol";
import "../../interfaces/stream/finality/IStreamCoreFinalityAdapter.sol";
import "../../interfaces/stream/finality/IStreamCoreFinalitySource.sol";
import "../../interfaces/stream/finality/IStreamCanonicalArtworkFinality.sol";
import "../../interfaces/stream/finality/IStreamFinalityScopeEvidence.sol";
import "../../interfaces/stream/finality/IStreamArtistSanctionPreparation.sol";
import "../../interfaces/stream/finality/IStreamNonSanctionFinalityDiscovery.sol";
import "../../interfaces/stream/finality/IStreamFinalityEvidenceProvider.sol";
import "../../interfaces/stream/finality/IStreamFinalityEvidenceDiscoveryBinding.sol";
import "../../interfaces/stream/finality/IStreamCoreFinalityEvidenceBinding.sol";
import "../../interfaces/stream/core/IStreamCorePointers.sol";
import "./StreamFinalityHashes.sol";
import "../../interfaces/stream/finality/IStreamFinalityMetadataReads.sol";
import "../../interfaces/stream/finality/IStreamFinalitySanctionReads.sol";
import "../../interfaces/stream/finality/StreamArtworkFinalityTypes.sol";

/// @notice Stateless candidate evidence validation using the registry's exact immutable dependencies.
/// @dev Compiler linkage preserves registry identity. The host checks its actual record/manifest state.
library StreamFinalityPreparation {
    uint256 private constant FINALITY_STRICT_PARENT_GAS_RESERVE = 100_000;

    struct Dependencies {
        IStreamCoreFinalitySource coreReads;
        IStreamCoreFinalityAdapter coreFinalityAdapter;
        IStreamFinalityMetadataReads metadataReads;
        address metadataHost;
        IStreamFinalitySanctionReads sanctionReads;
        address finalityDiscovery;
        bytes32 _coreCodeHash;
        bytes32 _metadataCodeHash;
        bytes32 _providerCodeHash;
        bytes32 _adapterCodeHash;
        bytes32 _discoveryCodeHash;
        uint256 readGas;
    }

    struct Prepared {
        bytes32 scopeKey;
        bytes32 coreFactsHash;
        bytes32 componentsHash;
        bytes32 finalityRecordHash;
        uint256 expectedLeafCount;
        bool exactLeafCount;
    }
    error FinalityAdapterReturnShapeInvalid(bytes4 selector, uint256 byteLength);
    error FinalityAdapterSemanticProbeInvalid(bytes4 selector);
    error FinalityCollectionBurnsNotBlocked(uint256 collectionId);
    error FinalityCollectionNotClosed(uint256 collectionId, uint8 status);
    error FinalityCollectionNotFrozen(uint256 collectionId);
    error FinalityCollectionStatusInvalid(uint256 collectionId, uint8 status);
    error FinalityCollectionSupplyModeInvalid(uint256 collectionId, uint8 supplyMode);
    error FinalityCollectionUnknown(uint256 collectionId);
    error FinalityComponentCodeHashMismatch(uint256 index);
    error FinalityComponentMismatch(uint256 index);
    error FinalityComponentUnreadable(uint256 index);
    error FinalityContentRootLeafCountMismatch(uint256 expectedLeafCount, uint256 actualLeafCount);
    error FinalityContentRootMissing(bytes32 scopeSubject);
    error FinalityCurrentBindingInvalid(address target);
    error FinalityDiscoveryComponentMismatch(uint256 index);
    error FinalityDiscoveryComponentUnreadable(uint256 index);
    error FinalityDiscoveryCountMismatch(uint256 discoveredCount, uint256 submittedCount);
    error FinalityDiscoveryFactsUnreadable();
    error FinalityDiscoveryHashMismatch(bytes32 discoveredHash, bytes32 submittedHash);
    error FinalityExpectedRecordHashMismatch(bytes32 expected, bytes32 computed);
    error FinalityMetadataModeInvalid(uint8 metadataMode);
    error FinalityMissingRequiredComponent(bytes32 componentType);
    error FinalitySanctionComponentDuplicated();
    error FinalitySanctionComponentMissing();
    error FinalitySanctionComponentWrongType(bytes32 requiredType, bytes32 suppliedType);
    error FinalitySanctionInvalid(bytes32 sanctionSubjectHash);
    error FinalitySanctionRecordHashMismatch(bytes32 componentDataHash, bytes32 sanctionRecordHash);
    error FinalityScopeInputsInvalid();
    error FinalityScopeUnknown();
    error FinalityScopedFactsMismatch();
    error FinalitySnapshotManifestMissing(uint256 collectionId, uint8 metadataMode);
    error FinalityTokenNotInScope();

    function prepareSanction(
        Dependencies memory deps,
        StreamFinalityScope memory scope,
        StreamFinalityComponentExpectation[] calldata components,
        StreamFinalityManifestRef calldata manifest
    ) public view returns (StreamArtistSanctionPreparation memory prepared) {
        _requireCurrentBindings(deps);
        bytes32 requiredType = abi.decode(
            _requiredRead(
                deps,
                address(deps.sanctionReads),
                abi.encodeCall(
                    IStreamFinalitySanctionReads.collectionSanctionComponentType,
                    (scope.collectionId)
                ),
                32
            ),
            (bytes32)
        );
        if (requiredType != StreamFinalityDomains.COMPONENT_ARTIST_SANCTION) {
            revert FinalitySanctionComponentWrongType(
                StreamFinalityDomains.COMPONENT_ARTIST_SANCTION, requiredType
            );
        }
        for (uint256 i; i < components.length; ++i) {
            bytes32 kind = components[i].componentType;
            if (
                kind == StreamFinalityDomains.COMPONENT_ARTIST_SANCTION
                    || kind == StreamFinalityDomains.COMPONENT_PLATFORM_WORKS_DECLARATION
            ) revert FinalitySanctionComponentWrongType(bytes32(0), kind);
        }
        uint8 metadataMode = abi.decode(
            _requiredRead(
                deps,
                address(deps.metadataReads),
                abi.encodeCall(
                    IStreamFinalityMetadataReads.collectionMetadataMode, (scope.collectionId)
                ),
                32
            ),
            (uint8)
        );
        if (metadataMode > StreamFinalityDomains.METADATA_MODE_HYBRID) {
            revert FinalityMetadataModeInvalid(metadataMode);
        }
        _requireSnapshotManifestForScriptWorks(deps, scope.collectionId, metadataMode);
        uint256 leafCount;
        bool exactLeafCount;
        (prepared.coreFactsHash, leafCount, exactLeafCount) = _verifyCoreGatesAndFacts(deps, scope);
        _verifyContentRoot(deps, scope, leafCount, exactLeafCount);
        _requireMandatoryComponents(deps, components, metadataMode);
        _verifyComponentsLiveStrict(deps, components, _componentCallData(deps, scope));
        prepared.nonSanctionComponentsHash = _componentsHash(deps, components);
        _verifyNonSanctionDiscovery(deps, scope, components, prepared.nonSanctionComponentsHash);
        prepared.scopeInputsHash = _scopeInputsHash(deps, scope, manifest, metadataMode);
        prepared.sanctionSubjectHash = _sanctionSubjectHash(
            deps, scope, prepared.coreFactsHash, prepared.nonSanctionComponentsHash, manifest
        );
    }

    function _verifyNonSanctionDiscovery(
        Dependencies memory deps,
        StreamFinalityScope memory scope,
        StreamFinalityComponentExpectation[] calldata components,
        bytes32 submittedHash
    ) private view {
        (uint256 count, bytes32 hash) = abi.decode(
            _requiredRead(
                deps,
                deps.finalityDiscovery,
                abi.encodeCall(
                    IStreamNonSanctionFinalityDiscovery.nonSanctionDiscoveryFacts, (scope)
                ),
                64
            ),
            (uint256, bytes32)
        );
        if (count != components.length) {
            revert FinalityDiscoveryCountMismatch(count, components.length);
        }
        if (hash != submittedHash) revert FinalityDiscoveryHashMismatch(hash, submittedHash);
        for (uint256 i; i < count; ++i) {
            StreamFinalityComponentExpectation memory discovered = abi.decode(
                _requiredRead(
                    deps,
                    deps.finalityDiscovery,
                    abi.encodeCall(
                        IStreamNonSanctionFinalityDiscovery.nonSanctionComponentAt, (scope, i)
                    ),
                    224
                ),
                (StreamFinalityComponentExpectation)
            );
            if (!_sameExpectation(deps, discovered, components[i])) {
                revert FinalityDiscoveryComponentMismatch(i);
            }
        }
    }

    function prepare(
        Dependencies memory deps,
        StreamFinalityScope memory scope,
        StreamFinalityComponentExpectation[] calldata components,
        bytes32 expectedFinalityRecordHash,
        StreamFinalityManifestRef calldata manifest
    ) public view returns (Prepared memory ctx, StreamFinalityExecutionContext memory execution) {
        ctx.scopeKey = _scopeKey(deps, scope);
        _requireCurrentBindings(deps);
        uint8 metadataMode = abi.decode(
            _requiredRead(
                deps,
                address(deps.metadataReads),
                abi.encodeCall(
                    IStreamFinalityMetadataReads.collectionMetadataMode, (scope.collectionId)
                ),
                32
            ),
            (uint8)
        );
        if (metadataMode > StreamFinalityDomains.METADATA_MODE_HYBRID) {
            revert FinalityMetadataModeInvalid(metadataMode);
        }
        _requireSnapshotManifestForScriptWorks(deps, scope.collectionId, metadataMode);
        (ctx.coreFactsHash, ctx.expectedLeafCount, ctx.exactLeafCount) =
            _verifyCoreGatesAndFacts(deps, scope);
        _verifyContentRoot(deps, scope, ctx.expectedLeafCount, ctx.exactLeafCount);
        ctx.componentsHash = _componentsHash(deps, components);
        _requireMandatoryComponents(deps, components, metadataMode);
        _verifySanctionComponent(deps, scope, components, ctx.coreFactsHash, manifest);
        _verifyComponentsLiveStrict(deps, components, _componentCallData(deps, scope));
        _verifyDiscovery(deps, scope, components, ctx.componentsHash);
        execution.inputsHash = _scopeInputsHash(deps, scope, manifest, metadataMode);
        ctx.finalityRecordHash =
            _finalityRecordHash(deps, scope, ctx.coreFactsHash, ctx.componentsHash, manifest);
        if (ctx.finalityRecordHash != expectedFinalityRecordHash) {
            revert FinalityExpectedRecordHashMismatch(
                expectedFinalityRecordHash, ctx.finalityRecordHash
            );
        }
        execution.scopeHash = keccak256(
            abi.encode(
                keccak256("6529STREAM_FINALITY_EXECUTION_SCOPE_V1"),
                block.chainid,
                address(this),
                scope
            )
        );
        execution.coreFactsHash = ctx.coreFactsHash;
        execution.componentsHash = ctx.componentsHash;
        execution.finalityRecordHash = ctx.finalityRecordHash;
        execution.oldValueHash = keccak256(
            abi.encode(
                keccak256("6529STREAM_FINALITY_EXECUTION_OLD_V1"),
                execution.scopeHash,
                false,
                ctx.coreFactsHash,
                ctx.componentsHash,
                execution.inputsHash
            )
        );
        execution.newValueHash = keccak256(
            abi.encode(
                keccak256("6529STREAM_FINALITY_EXECUTION_NEW_V1"),
                execution.scopeHash,
                true,
                ctx.finalityRecordHash
            )
        );
    }

    function _scopeInputsHash(
        Dependencies memory deps,
        StreamFinalityScope memory scope,
        StreamFinalityManifestRef calldata manifest,
        uint8 metadataMode
    ) private view returns (bytes32) {
        bytes memory raw = _requiredRead(
            deps,
            address(deps.metadataReads),
            abi.encodeCall(
                IStreamFinalityScopeEvidence.requireFinalityScopeInputs,
                (scope, manifest.contentHash)
            ),
            384
        );
        (StreamFinalityScopeInputs memory inputs, bytes32 schema, bytes32 canonicalization) =
            abi.decode(raw, (StreamFinalityScopeInputs, bytes32, bytes32));
        bool artistBound = abi.decode(
            _requiredRead(
                deps,
                address(deps.sanctionReads),
                abi.encodeCall(
                    IStreamFinalitySanctionReads.collectionSanctionComponentType,
                    (scope.collectionId)
                ),
                32
            ),
            (bytes32)
        ) == StreamFinalityDomains.COMPONENT_ARTIST_SANCTION;
        if (
            schema != manifest.schemaId || canonicalization != manifest.canonicalizationHash
                || inputs.rootRecordHash == bytes32(0)
                || (metadataMode != StreamFinalityDomains.METADATA_MODE_OFFCHAIN
                    && (inputs.referenceRenderRecordHash == bytes32(0)
                        || inputs.snapshotRecordHash == bytes32(0)))
                || inputs.interviewEvidenceHash == bytes32(0)
                || inputs.rightsStatementRecordHash == bytes32(0)
                || inputs.workDescriptionRecordHash == bytes32(0)
                || inputs.renderCriticalEvidenceHash == bytes32(0)
                || inputs.bundleCoverageHash == bytes32(0)
                || (artistBound
                    && ((inputs.intentRecordHash == bytes32(0))
                            == (inputs.intentWaiverRecordHash == bytes32(0))))
                || (!artistBound
                    && (inputs.intentRecordHash != bytes32(0)
                        || inputs.intentWaiverRecordHash != bytes32(0)))
        ) {
            revert FinalityScopeInputsInvalid();
        }
        return keccak256(
            abi.encode(
                keccak256("6529STREAM_FINALITY_SCOPE_INPUTS_V1"),
                block.chainid,
                address(deps.coreReads),
                deps.metadataHost,
                scope,
                inputs
            )
        );
    }

    function _requireCurrentBindings(Dependencies memory deps) private view {
        address core_ = address(deps.coreReads);
        if (core_.code.length == 0 || core_.codehash != deps._coreCodeHash) {
            revert FinalityCurrentBindingInvalid(core_);
        }
        if (
            deps.metadataHost.codehash != deps._metadataCodeHash
                || address(deps.metadataReads).codehash != deps._providerCodeHash
                || address(deps.coreFinalityAdapter).codehash != deps._adapterCodeHash
                || deps.finalityDiscovery.codehash != deps._discoveryCodeHash
        ) {
            revert FinalityCurrentBindingInvalid(address(deps.metadataReads));
        }
        if (
            _selected(deps, keccak256("ARTWORK_FINALITY_REGISTRY")) != address(this)
                || _selected(deps, keccak256("COLLECTION_METADATA")) != deps.metadataHost
                || _selected(deps, keccak256("ARTIST_REGISTRY")) != address(deps.sanctionReads)
        ) {
            revert FinalityCurrentBindingInvalid(address(this));
        }
        if (
            _readExactAddress(deps, deps.metadataHost, IStreamFinalityScopeEvidence.core.selector)
                    != core_
                || _readExactAddress(
                        deps,
                        address(deps.metadataReads),
                        IStreamFinalityScopeEvidence.core.selector
                    ) != core_
                || _readExactAddress(
                        deps,
                        address(deps.metadataReads),
                        IStreamFinalityEvidenceProvider.metadataHost.selector
                    ) != deps.metadataHost
                || _readExactAddress(
                        deps,
                        deps.finalityDiscovery,
                        IStreamFinalityEvidenceDiscoveryBinding.scopeEvidenceProvider.selector
                    ) != address(deps.metadataReads)
                || _readExactAddress(
                        deps,
                        address(deps.sanctionReads),
                        IStreamFinalityScopeEvidence.core.selector
                    ) != core_
                || _readExactAddress(
                        deps, address(deps.sanctionReads), bytes4(keccak256("finalityRegistry()"))
                    ) != address(this)
                || abi.decode(
                        _requiredRead(
                            deps,
                            address(deps.sanctionReads),
                            abi.encodeWithSelector(bytes4(keccak256("finalityRegistryCodeHash()"))),
                            32
                        ),
                        (bytes32)
                    ) != address(this).codehash
        ) {
            revert FinalityCurrentBindingInvalid(address(deps.sanctionReads));
        }
        if (
            _readExactAddress(
                        deps,
                        address(deps.coreFinalityAdapter),
                        IStreamCoreFinalityAdapter.core.selector
                    ) != core_
                || _readExactAddress(
                        deps,
                        address(deps.coreFinalityAdapter),
                        IStreamCoreFinalityAdapter.collectionMetadata.selector
                    ) != deps.metadataHost
                || _readExactAddress(
                        deps,
                        address(deps.coreFinalityAdapter),
                        IStreamCoreFinalityEvidenceBinding.evidenceProvider.selector
                    ) != address(deps.metadataReads)
        ) revert FinalityCurrentBindingInvalid(address(deps.coreFinalityAdapter));
    }

    function _selected(Dependencies memory deps, bytes32 kind)
        private
        view
        returns (address target)
    {
        bytes memory raw = _requiredRead(
            deps,
            address(deps.coreReads),
            abi.encodeCall(IStreamCorePointers.getSatellitePointer, (kind)),
            320
        );
        uint256 word = _adapterResultWord(deps, raw, 0);
        if (word >> 160 != 0) revert FinalityCurrentBindingInvalid(address(deps.coreReads));
        target = address(uint160(word));
        if (target.code.length == 0 || target.codehash != bytes32(_adapterResultWord(deps, raw, 1)))
        {
            revert FinalityCurrentBindingInvalid(target);
        }
    }

    function _requiredRead(
        Dependencies memory deps,
        address target,
        bytes memory data,
        uint256 size
    ) private view returns (bytes memory result) {
        (bool success,, bytes memory raw) = _readExactStatic(deps, target, data, size);
        if (!success) revert FinalityCurrentBindingInvalid(target);
        return raw;
    }

    function _readExactAddress(Dependencies memory deps, address adapter, bytes4 selector)
        private
        view
        returns (address value)
    {
        (bool success, uint256 actualLength, bytes memory result) =
            _readExactStatic(deps, adapter, abi.encodeWithSelector(selector), 32);
        if (!success) {
            revert FinalityAdapterReturnShapeInvalid(selector, actualLength);
        }
        uint256 rawAddress = _adapterResultWord(deps, result, 0);
        if (rawAddress > type(uint160).max) {
            revert FinalityAdapterSemanticProbeInvalid(selector);
        }
        value = address(uint160(rawAddress));
    }

    function _readExactStatic(
        Dependencies memory deps,
        address target,
        bytes memory callData,
        uint256 expectedLength
    ) private view returns (bool readable, uint256 actualLength, bytes memory result) {
        result = new bytes(expectedLength);
        uint256 availableGas = gasleft();
        uint256 forwardedGas = deps.readGas;
        if (
            forwardedGas > type(uint256).max / 64
                || availableGas
                    <= forwardedGas + (forwardedGas + 62) / 63 + FINALITY_STRICT_PARENT_GAS_RESERVE
        ) {
            return (false, 0, result);
        }
        assembly ("memory-safe") {
            readable := staticcall(
                forwardedGas,
                target,
                add(callData, 0x20),
                mload(callData),
                add(result, 0x20),
                expectedLength
            )
            actualLength := returndatasize()
            if iszero(eq(actualLength, expectedLength)) { readable := 0 }
        }
    }

    function _adapterResultWord(Dependencies memory deps, bytes memory result, uint256 index)
        private
        pure
        returns (uint256 word)
    {
        assembly ("memory-safe") {
            word := mload(add(add(result, 0x20), mul(index, 0x20)))
        }
    }

    function _verifyCoreGatesAndFacts(Dependencies memory deps, StreamFinalityScope memory scope)
        private
        view
        returns (bytes32 factsHash, uint256 expectedLeafCount, bool exactLeafCount)
    {
        if (scope.scopeType == StreamFinalityScopeType.COLLECTION) {
            StreamCoreCollectionFinalityFacts memory facts = abi.decode(
                _requiredRead(
                    deps,
                    address(deps.coreFinalityAdapter),
                    abi.encodeCall(
                        IStreamCoreFinalityAdapter.coreCollectionFinalityFacts, (scope.collectionId)
                    ),
                    288
                ),
                (StreamCoreCollectionFinalityFacts)
            );
            _requireCoreCollectionDomains(deps, scope.collectionId, facts.status, facts.supplyMode);
            if (!facts.exists) {
                revert FinalityCollectionUnknown(scope.collectionId);
            }
            if (facts.status != StreamFinalityDomains.CORE_COLLECTION_STATUS_CLOSED) {
                revert FinalityCollectionNotClosed(scope.collectionId, facts.status);
            }
            if (!abi.decode(
                    _requiredRead(
                        deps,
                        address(deps.coreReads),
                        abi.encodeCall(
                            IStreamCoreFinalitySource.collectionBurnsBlocked, (scope.collectionId)
                        ),
                        32
                    ),
                    (bool)
                )) {
                revert FinalityCollectionBurnsNotBlocked(scope.collectionId);
            }
            if (!abi.decode(
                    _requiredRead(
                        deps,
                        address(deps.coreReads),
                        abi.encodeCall(
                            IStreamCoreFinalitySource.collectionFreezeStatus, (scope.collectionId)
                        ),
                        32
                    ),
                    (bool)
                )) {
                revert FinalityCollectionNotFrozen(scope.collectionId);
            }
            return
                (
                    _coreCollectionFactsHash(deps, scope.collectionId, facts),
                    facts.mintedSupply,
                    true
                );
        }
        StreamScopedCoreFinalityFacts memory scopedFacts = abi.decode(
            _requiredRead(
                deps,
                address(deps.coreFinalityAdapter),
                abi.encodeCall(
                    IStreamCoreFinalityAdapter.scopedCoreFinalityFacts, (_adapterScope(deps, scope))
                ),
                416
            ),
            (StreamScopedCoreFinalityFacts)
        );
        _requireCoreCollectionDomains(
            deps, scope.collectionId, scopedFacts.collectionStatus, scopedFacts.collectionSupplyMode
        );
        if (!scopedFacts.scopeExists) {
            revert FinalityScopeUnknown();
        }
        if (
            scopedFacts.scopeType != uint8(scope.scopeType)
                || scopedFacts.collectionId != scope.collectionId
                || scopedFacts.tokenId != scope.tokenId || scopedFacts.scopeId != scope.scopeId
        ) {
            revert FinalityScopedFactsMismatch();
        }
        if (scope.scopeType == StreamFinalityScopeType.TOKEN) {
            if (
                !scopedFacts.tokenMappingExists
                    || (scopedFacts.tokenLifecycle != StreamFinalityDomains.TOKEN_LIFECYCLE_MINTED
                        && scopedFacts.tokenLifecycle
                            != StreamFinalityDomains.TOKEN_LIFECYCLE_BURNED)
            ) {
                revert FinalityTokenNotInScope();
            }
            return (_scopedCoreFactsHash(deps, scope, scopedFacts), 1, true);
        }
        return (_scopedCoreFactsHash(deps, scope, scopedFacts), 0, false);
    }

    function _requireCoreCollectionDomains(
        Dependencies memory deps,
        uint256 collectionId,
        uint8 collectionStatus,
        uint8 collectionSupplyMode
    ) private pure {
        if (collectionStatus > StreamFinalityDomains.CORE_COLLECTION_STATUS_CLOSED) {
            revert FinalityCollectionStatusInvalid(collectionId, collectionStatus);
        }
        if (collectionSupplyMode > StreamFinalityDomains.CORE_COLLECTION_SUPPLY_MODE_UNCAPPED_OPEN)
        {
            revert FinalityCollectionSupplyModeInvalid(collectionId, collectionSupplyMode);
        }
    }

    function _verifyContentRoot(
        Dependencies memory deps,
        StreamFinalityScope memory scope,
        uint256 expectedLeafCount,
        bool exactLeafCount
    ) private view {
        bytes32 scopeSubject = _contentRootSubject(deps, scope);
        (bytes32 contentRoot, uint64 leafCount,) = abi.decode(
            _requiredRead(
                deps,
                address(deps.metadataReads),
                abi.encodeCall(
                    IStreamFinalityMetadataReads.tokenContentRoot,
                    (scope.collectionId, scopeSubject)
                ),
                96
            ),
            (bytes32, uint64, bytes32)
        );
        if (contentRoot == bytes32(0)) {
            revert FinalityContentRootMissing(scopeSubject);
        }
        if (exactLeafCount) {
            if (uint256(leafCount) != expectedLeafCount) {
                revert FinalityContentRootLeafCountMismatch(expectedLeafCount, uint256(leafCount));
            }
        } else if (leafCount == 0) {
            revert FinalityContentRootLeafCountMismatch(1, leafCount);
        }
    }

    function _requireMandatoryComponents(
        Dependencies memory deps,
        StreamFinalityComponentExpectation[] calldata components,
        uint8 metadataMode
    ) private pure {
        bytes32 missing = StreamFinalityComponentSet.firstMissingMandatory(components, metadataMode);
        if (missing != bytes32(0)) {
            revert FinalityMissingRequiredComponent(missing);
        }
        // The exactly-one artist-sanction/platform-works floor is enforced by
        // _verifySanctionComponent.
    }

    function _requireSnapshotManifestForScriptWorks(
        Dependencies memory deps,
        uint256 collectionId,
        uint8 metadataMode
    ) private view {
        if (
            metadataMode != StreamFinalityDomains.METADATA_MODE_ONCHAIN
                && metadataMode != StreamFinalityDomains.METADATA_MODE_HYBRID
        ) {
            return;
        }
        if (
            abi.decode(
                    _requiredRead(
                        deps,
                        address(deps.metadataReads),
                        abi.encodeCall(
                            IStreamFinalityMetadataReads.latestCollectionSnapshotHash,
                            (collectionId)
                        ),
                        32
                    ),
                    (bytes32)
                ) == bytes32(0)
        ) {
            revert FinalitySnapshotManifestMissing(collectionId, metadataMode);
        }
    }

    function _verifySanctionComponent(
        Dependencies memory deps,
        StreamFinalityScope memory scope,
        StreamFinalityComponentExpectation[] calldata components,
        bytes32 coreFactsHash,
        StreamFinalityManifestRef calldata manifest
    ) private view {
        uint256 index;
        {
            uint256 occurrences;
            (index, occurrences) = StreamFinalityComponentSet.locateSanctionSlot(components);
            if (occurrences == 0) revert FinalitySanctionComponentMissing();
            if (occurrences > 1) revert FinalitySanctionComponentDuplicated();
            bytes32 requiredType = abi.decode(
                _requiredRead(
                    deps,
                    address(deps.sanctionReads),
                    abi.encodeCall(
                        IStreamFinalitySanctionReads.collectionSanctionComponentType,
                        (scope.collectionId)
                    ),
                    32
                ),
                (bytes32)
            );
            bytes32 suppliedType = components[index].componentType;
            if (suppliedType != requiredType) {
                revert FinalitySanctionComponentWrongType(requiredType, suppliedType);
            }
            if (requiredType != StreamFinalityDomains.COMPONENT_ARTIST_SANCTION) return;
        }
        bytes32 nonSanctionHash = _nonSanctionComponentsHash(deps, components);
        bytes32 subjectHash =
            _sanctionSubjectHash(deps, scope, coreFactsHash, nonSanctionHash, manifest);
        _requireVerifiedSanction(deps, scope, subjectHash, components[index].dataHash);
    }

    function _requireVerifiedSanction(
        Dependencies memory deps,
        StreamFinalityScope memory scope,
        bytes32 sanctionSubjectHash,
        bytes32 componentDataHash
    ) private view {
        (bool valid, bytes32 sanctionRecordHash) =
            _sanctionVerification(deps, scope, sanctionSubjectHash);
        if (!valid) {
            revert FinalitySanctionInvalid(sanctionSubjectHash);
        }
        if (sanctionRecordHash != componentDataHash) {
            revert FinalitySanctionRecordHashMismatch(componentDataHash, sanctionRecordHash);
        }
    }

    function _sanctionVerification(
        Dependencies memory deps,
        StreamFinalityScope memory scope,
        bytes32 sanctionSubjectHash
    ) private view returns (bool valid, bytes32 sanctionRecordHash) {
        (valid, sanctionRecordHash,,) = abi.decode(
            _requiredRead(
                deps,
                address(deps.sanctionReads),
                abi.encodeCall(
                    IStreamFinalitySanctionReads.verifySanctionForSubject,
                    (
                        uint8(scope.scopeType),
                        scope.collectionId,
                        scope.tokenId,
                        scope.scopeId,
                        sanctionSubjectHash
                    )
                ),
                128
            ),
            (bool, bytes32, address, uint8)
        );
    }

    function _verifyComponentsLiveStrict(
        Dependencies memory deps,
        StreamFinalityComponentExpectation[] calldata components,
        bytes memory componentCallData
    ) private view {
        (uint8 failCode, uint256 failIndex) = StreamFinalityComponentSet.verifyComponentsStrict(
            components, componentCallData, deps.readGas
        );
        if (failCode == StreamFinalityComponentSet.STRICT_OK) {
            return;
        }
        if (failCode == StreamFinalityComponentSet.STRICT_CODEHASH_MISMATCH) {
            revert FinalityComponentCodeHashMismatch(failIndex);
        }
        if (failCode == StreamFinalityComponentSet.STRICT_STATE_MISMATCH) {
            revert FinalityComponentMismatch(failIndex);
        }
        revert FinalityComponentUnreadable(failIndex);
    }

    function _verifyDiscovery(
        Dependencies memory deps,
        StreamFinalityScope memory scope,
        StreamFinalityComponentExpectation[] calldata components,
        bytes32 submittedHash
    ) private view {
        uint256 submittedCount = components.length;
        address discovery = deps.finalityDiscovery;
        (bool factsReadable, uint256 discoveredCount, bytes32 discoveredHash) =
            _discoveryFacts(deps, discovery, scope);
        if (!factsReadable) {
            revert FinalityDiscoveryFactsUnreadable();
        }
        if (discoveredCount != submittedCount) {
            revert FinalityDiscoveryCountMismatch(discoveredCount, submittedCount);
        }
        if (discoveredHash != submittedHash) {
            revert FinalityDiscoveryHashMismatch(discoveredHash, submittedHash);
        }
        for (uint256 i = 0; i < submittedCount; i++) {
            (bool componentReadable, StreamFinalityComponentExpectation memory discovered) =
                _discoveryComponent(deps, discovery, scope, i);
            if (!componentReadable) {
                revert FinalityDiscoveryComponentUnreadable(i);
            }
            if (!_sameExpectation(deps, discovered, components[i])) {
                revert FinalityDiscoveryComponentMismatch(i);
            }
        }
    }

    function _discoveryComponent(
        Dependencies memory deps,
        address discovery,
        StreamFinalityScope memory scope,
        uint256 index
    ) private view returns (bool readable, StreamFinalityComponentExpectation memory component) {
        bytes memory callData;
        if (scope.scopeType == StreamFinalityScopeType.COLLECTION) {
            callData = abi.encodeWithSelector(
                IStreamArtworkFinalityDiscovery.finalityComponentAt.selector,
                scope.collectionId,
                index
            );
        } else {
            callData = abi.encodeWithSelector(
                IStreamArtworkScopedFinalityDiscovery.finalityComponentAtForScope.selector,
                scope,
                index
            );
        }
        return _readDiscoveryComponent(deps, discovery, callData, deps.readGas);
    }

    function _sameExpectation(
        Dependencies memory deps,
        StreamFinalityComponentExpectation memory discovered,
        StreamFinalityComponentExpectation calldata submitted
    ) private pure returns (bool) {
        return discovered.componentType == submitted.componentType
            && discovered.component == submitted.component
            && discovered.interfaceId == submitted.interfaceId
            && discovered.codeHash == submitted.codeHash
            && discovered.moduleVersion == submitted.moduleVersion
            && discovered.manifestHash == submitted.manifestHash
            && discovered.dataHash == submitted.dataHash;
    }

    function _discoveryFacts(
        Dependencies memory deps,
        address discovery,
        StreamFinalityScope memory scope
    ) private view returns (bool readable, uint256 discoveredCount, bytes32 discoveredHash) {
        bytes memory countCallData;
        bytes memory hashCallData;
        if (scope.scopeType == StreamFinalityScopeType.COLLECTION) {
            countCallData = abi.encodeWithSelector(
                IStreamArtworkFinalityDiscovery.finalityComponentCount.selector, scope.collectionId
            );
            hashCallData = abi.encodeWithSelector(
                IStreamArtworkFinalityDiscovery.finalityDiscoveryHash.selector, scope.collectionId
            );
        } else {
            countCallData = abi.encodeWithSelector(
                IStreamArtworkScopedFinalityDiscovery.finalityComponentCountForScope.selector, scope
            );
            hashCallData = abi.encodeWithSelector(
                IStreamArtworkScopedFinalityDiscovery.finalityDiscoveryHashForScope.selector, scope
            );
        }
        (bool countReadable, bytes32 rawCount) =
            _readDiscoveryWord(deps, discovery, countCallData, deps.readGas);
        if (!countReadable) {
            return (false, 0, bytes32(0));
        }
        (bool hashReadable, bytes32 rawHash) =
            _readDiscoveryWord(deps, discovery, hashCallData, deps.readGas);
        return (hashReadable, uint256(rawCount), rawHash);
    }

    function _readDiscoveryWord(
        Dependencies memory deps,
        address discovery,
        bytes memory callData,
        uint256 gasCap
    ) private view returns (bool readable, bytes32 value) {
        return StreamFinalityComponentSet.observeDiscoveryWord(discovery, callData, gasCap);
    }

    function _readDiscoveryComponent(
        Dependencies memory deps,
        address discovery,
        bytes memory callData,
        uint256 gasCap
    ) private view returns (bool readable, StreamFinalityComponentExpectation memory component) {
        return StreamFinalityComponentSet.observeDiscoveryComponent(discovery, callData, gasCap);
    }

    function _componentCallData(Dependencies memory deps, StreamFinalityScope memory scope)
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

    function _componentsHash(
        Dependencies memory deps,
        StreamFinalityComponentExpectation[] calldata components
    ) private pure returns (bytes32) {
        return keccak256(
            abi.encode(StreamFinalityDomains.STREAM_FINALITY_COMPONENTS_V1, components)
        );
    }

    function _componentsHashMemory(
        Dependencies memory deps,
        StreamFinalityComponentExpectation[] memory components
    ) private pure returns (bytes32) {
        return keccak256(
            abi.encode(StreamFinalityDomains.STREAM_FINALITY_COMPONENTS_V1, components)
        );
    }

    function _nonSanctionComponentsHash(
        Dependencies memory deps,
        StreamFinalityComponentExpectation[] calldata components
    ) private pure returns (bytes32) {
        uint256 count = components.length;
        uint256 kept = 0;
        for (uint256 i = 0; i < count; i++) {
            if (components[i].componentType != StreamFinalityDomains.COMPONENT_ARTIST_SANCTION) {
                kept++;
            }
        }
        StreamFinalityComponentExpectation[] memory filtered =
            new StreamFinalityComponentExpectation[](kept);
        uint256 cursor = 0;
        for (uint256 i = 0; i < count; i++) {
            if (components[i].componentType != StreamFinalityDomains.COMPONENT_ARTIST_SANCTION) {
                filtered[cursor] = components[i];
                cursor++;
            }
        }
        return _componentsHashMemory(deps, filtered);
    }

    function _adapterScope(Dependencies memory deps, StreamFinalityScope memory scope)
        private
        pure
        returns (StreamCoreFinalityScopeQuery memory)
    {
        return StreamCoreFinalityScopeQuery({
            scopeType: uint8(scope.scopeType),
            collectionId: scope.collectionId,
            tokenId: scope.tokenId,
            scopeId: scope.scopeId
        });
    }

    function _contentRootSubject(Dependencies memory deps, StreamFinalityScope memory scope)
        private
        view
        returns (bytes32)
    {
        return StreamFinalityHashes.contentRootSubject(address(deps.coreReads), scope);
    }

    function _coreCollectionFactsHash(
        Dependencies memory deps,
        uint256 collectionId,
        StreamCoreCollectionFinalityFacts memory facts
    ) private view returns (bytes32) {
        return StreamFinalityHashes.coreCollectionFactsHash(
            address(deps.coreReads), collectionId, facts
        );
    }

    function _scopedCoreFactsHash(
        Dependencies memory deps,
        StreamFinalityScope memory scope,
        StreamScopedCoreFinalityFacts memory facts
    ) private view returns (bytes32) {
        return StreamFinalityHashes.scopedCoreFactsHash(address(deps.coreReads), scope, facts);
    }

    function _finalityRecordHash(
        Dependencies memory deps,
        StreamFinalityScope memory scope,
        bytes32 coreFactsHash,
        bytes32 componentsHash,
        StreamFinalityManifestRef calldata manifest
    ) private view returns (bytes32) {
        return StreamFinalityHashes.finalityRecordHash(
            address(deps.coreReads), scope, coreFactsHash, componentsHash, manifest
        );
    }

    function _sanctionSubjectHash(
        Dependencies memory deps,
        StreamFinalityScope memory scope,
        bytes32 coreFactsHash,
        bytes32 nonSanctionComponentsHash,
        StreamFinalityManifestRef calldata manifest
    ) private view returns (bytes32) {
        return StreamFinalityHashes.sanctionSubjectHash(
            address(deps.coreReads), scope, coreFactsHash, nonSanctionComponentsHash, manifest
        );
    }

    function _scopeKey(Dependencies memory deps, StreamFinalityScope memory scope)
        private
        pure
        returns (bytes32)
    {
        return keccak256(
            abi.encode(uint8(scope.scopeType), scope.collectionId, scope.tokenId, scope.scopeId)
        );
    }
}

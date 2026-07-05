// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./IStreamArtworkFinalityComponents.sol";
import "./IStreamArtworkFinalityRegistry.sol";
import "./IStreamFinalityCoreReads.sol";
import "./IStreamFinalityGovernanceAuthority.sol";
import "./IStreamFinalityMetadataReads.sol";
import "./IStreamFinalitySanctionReads.sol";
import "./StreamArtworkFinalityTypes.sol";

/// @notice Five-scope artwork finality registry with the single governed terminal-freeze path.
/// @dev Implements [LTA-FINALITY] collection and scoped finality (all five scopes ship at
///      genesis per ADR 0009 decision 6), the [LTA-FREEZE] rule 4 TERMINAL_FREEZE staging with
///      a 72-hour veto floor and an independent guardian ([GOV-WINDOWS]), the
///      [CMC-FINALITY-INPUTS] execution gates this registry owns (content root, sanction,
///      burn block, facade identity binding), and the never-revert diagnostic reads. Consumer
///      surfaces built in parallel worktrees (Core facts, metadata satellite, artist registry,
///      governed admin registry) are bound through the narrow IStreamFinality* seams.
contract StreamArtworkFinalityRegistry is
    IStreamArtworkFinalityRegistry,
    IStreamArtworkScopedFrozenRouteRegistry
{
    error FinalityZeroAddress();

    /// @notice Event schema version carried by every registry event.
    uint16 public constant FINALITY_EVENT_SCHEMA_VERSION = 1;

    /// @notice Component-count cap ([LTA-FINALITY] planning value, pinned at release).
    uint256 public constant MAX_FINALITY_COMPONENTS = 32;

    /// @notice Calldata cap for finality entries and staged manifest bytes (planning value).
    uint256 public constant MAX_FINALITY_CALLDATA_BYTES = 32_768;

    /// @notice Terminal-freeze veto window floor ([GOV-WINDOWS] rule 2; ADR 0011 decision R10).
    uint64 public constant TERMINAL_FREEZE_VETO_FLOOR = 72 hours;

    /// @notice Open-to-execute window floor for delayed classes ([GOV-WINDOWS] rule 1).
    uint64 public constant TERMINAL_FREEZE_EXECUTION_WINDOW_FLOOR = 7 days;

    /// @notice Per-component gas cap for the never-revert diagnostics; genesis planning value
    ///         of the FINALITY_COMPONENT_READ_GAS governed gas parameter ([LTA-GGP] seam —
    ///         the GGP host framework binds the pinned key below when it lands).
    uint256 public constant FINALITY_COMPONENT_READ_GAS = 30_000;

    /// @notice Pinned GGP key for the diagnostic read budget.
    bytes32 public constant GGP_FINALITY_COMPONENT_READ_GAS_KEY =
        StreamFinalityDomains.GGP_FINALITY_COMPONENT_READ_GAS;

    IStreamFinalityCoreReads public immutable coreReads;
    IStreamFinalityMetadataReads public immutable metadataReads;
    IStreamFinalitySanctionReads public immutable sanctionReads;
    IStreamFinalityGovernanceAuthority public immutable governanceAuthority;

    /// @notice Optional discovery module (the metadata router); zero until the router wave
    ///         lands, at which point deployment binds it and the discovery gate activates.
    address public immutable finalityDiscovery;

    mapping(uint256 => StreamCollectionFinalityRecord) private _collectionRecords;
    mapping(uint256 => StreamFinalityComponentExpectation[]) private _collectionComponents;
    mapping(bytes32 => StreamScopedFinalityRecord) private _scopedRecords;
    mapping(bytes32 => StreamFinalityComponentExpectation[]) private _scopedComponents;
    mapping(bytes32 => StreamTerminalFreezeAction) private _terminalFreezes;
    mapping(bytes32 => bytes) private _manifestBytes;

    /// @dev Bundles per-execution values so deep call frames stay under stack limits.
    struct FinalityExecution {
        bytes32 scopeKey;
        bytes32 coreFactsHash;
        bytes32 componentsHash;
        bytes32 finalityRecordHash;
        uint64 expectedLeafCount;
        bool exactLeafCount;
    }

    /// @dev Bundles range-diagnostic values so deep call frames stay under stack limits.
    struct RangeObservation {
        bool matches;
        bytes32 expectedRangeHash;
        bytes32 observedRangeHash;
        uint256 nextStart;
    }

    constructor(
        address coreReads_,
        address metadataReads_,
        address sanctionReads_,
        address governanceAuthority_,
        address finalityDiscovery_
    ) {
        if (
            coreReads_ == address(0) || metadataReads_ == address(0) || sanctionReads_ == address(0)
                || governanceAuthority_ == address(0)
        ) {
            revert FinalityZeroAddress();
        }
        coreReads = IStreamFinalityCoreReads(coreReads_);
        metadataReads = IStreamFinalityMetadataReads(metadataReads_);
        sanctionReads = IStreamFinalitySanctionReads(sanctionReads_);
        governanceAuthority = IStreamFinalityGovernanceAuthority(governanceAuthority_);
        finalityDiscovery = finalityDiscovery_;
    }

    /// @notice Returns true for deployment validation.
    function isStreamArtworkFinalityRegistry() external pure returns (bool) {
        return true;
    }

    /// @notice The bound Core address used in every pinned hash preimage.
    function core() public view returns (address) {
        return address(coreReads);
    }

    // ------------------------------------------------------------------
    // Terminal-freeze staging (single governed freeze path)
    // ------------------------------------------------------------------

    /// @notice Stages the irreversible artwork finality for `scope` under the TERMINAL_FREEZE
    ///         class: delay plus an independent veto guardian ([LTA-FREEZE] rule 4).
    function scheduleArtworkTerminalFreeze(
        StreamFinalityScope calldata scope,
        bytes32 expectedFinalityRecordHash,
        uint64 notBefore,
        uint64 expiresAfter
    ) external override {
        _requireFinalityAdmin(msg.sender);
        StreamFinalityScope memory scopeMem = scope;
        _requireCanonicalScopeShape(scopeMem);
        if (expectedFinalityRecordHash == bytes32(0)) {
            revert FinalityExpectedRecordHashZero();
        }
        bytes32 scopeKey = _scopeKey(scopeMem);
        if (_scopeFinalized(scopeMem)) {
            revert FinalityAlreadyFinalized(scopeKey);
        }

        StreamTerminalFreezeAction storage action = _terminalFreezes[scopeKey];
        if (action.status == StreamTerminalFreezeStatus.SCHEDULED) {
            if (block.timestamp > action.expiresAfter) {
                _expireAction(scopeKey, action);
            } else {
                revert FinalityFreezeAlreadyScheduled(scopeKey);
            }
        }

        uint64 earliestNotBefore = uint64(block.timestamp) + TERMINAL_FREEZE_VETO_FLOOR;
        if (notBefore < earliestNotBefore) {
            revert FinalityFreezeDelayTooShort(notBefore, earliestNotBefore);
        }
        uint64 earliestExpiry = notBefore + TERMINAL_FREEZE_EXECUTION_WINDOW_FLOOR;
        if (expiresAfter < earliestExpiry) {
            revert FinalityFreezeWindowTooShort(expiresAfter, earliestExpiry);
        }

        (address guardian,) = governanceAuthority.terminalFreezeVetoGuardian(scopeKey);
        if (guardian == address(0)) {
            revert FinalityFreezeGuardianUnset(scopeKey);
        }

        action.status = StreamTerminalFreezeStatus.SCHEDULED;
        action.scope = scopeMem;
        action.expectedFinalityRecordHash = expectedFinalityRecordHash;
        action.scheduledAt = uint64(block.timestamp);
        action.notBefore = notBefore;
        action.expiresAfter = expiresAfter;
        action.scheduler = msg.sender;
        action.vetoGuardianAtScheduling = guardian;

        emit ArtworkTerminalFreezeScheduled(
            FINALITY_EVENT_SCHEMA_VERSION,
            uint8(scopeMem.scopeType),
            scopeMem.collectionId,
            scopeKey,
            scopeMem.tokenId,
            scopeMem.scopeId,
            expectedFinalityRecordHash,
            notBefore,
            expiresAfter,
            guardian,
            msg.sender
        );
    }

    /// @notice Guardian veto, valid while the action is scheduled and before `notBefore`.
    /// @dev The guardian is re-resolved through the authority at veto time — a role reference,
    ///      never the frozen address captured at scheduling (ADR 0004 execution rules).
    function vetoArtworkTerminalFreeze(StreamFinalityScope calldata scope, bytes32 reasonHash)
        external
        override
    {
        bytes32 scopeKey = _scopeKey(scope);
        StreamTerminalFreezeAction storage action = _terminalFreezes[scopeKey];
        if (action.status != StreamTerminalFreezeStatus.SCHEDULED) {
            revert FinalityFreezeNotScheduled(scopeKey);
        }
        if (block.timestamp >= action.notBefore) {
            revert FinalityFreezeVetoWindowClosed(action.notBefore);
        }
        (address guardian,) = governanceAuthority.terminalFreezeVetoGuardian(scopeKey);
        if (guardian == address(0) || msg.sender != guardian) {
            revert FinalityCallerNotVetoGuardian(msg.sender, guardian);
        }
        action.status = StreamTerminalFreezeStatus.VETOED;
        emit ArtworkTerminalFreezeVetoed(
            FINALITY_EVENT_SCHEMA_VERSION,
            scopeKey,
            action.expectedFinalityRecordHash,
            reasonHash,
            msg.sender
        );
    }

    /// @notice Cancels a scheduled terminal freeze before execution ([LTA-GOV] rule 3).
    function cancelArtworkTerminalFreeze(StreamFinalityScope calldata scope, bytes32 reasonHash)
        external
        override
    {
        _requireFinalityAdmin(msg.sender);
        bytes32 scopeKey = _scopeKey(scope);
        StreamTerminalFreezeAction storage action = _terminalFreezes[scopeKey];
        if (
            action.status != StreamTerminalFreezeStatus.SCHEDULED
                || block.timestamp > action.expiresAfter
        ) {
            revert FinalityFreezeNotScheduled(scopeKey);
        }
        action.status = StreamTerminalFreezeStatus.CANCELLED;
        emit ArtworkTerminalFreezeCancelled(
            FINALITY_EVENT_SCHEMA_VERSION,
            scopeKey,
            action.expectedFinalityRecordHash,
            reasonHash,
            msg.sender
        );
    }

    /// @notice Anyone may materialize the virtual expiry of an overdue scheduled freeze.
    function materializeExpiredArtworkTerminalFreeze(StreamFinalityScope calldata scope)
        external
        override
    {
        bytes32 scopeKey = _scopeKey(scope);
        StreamTerminalFreezeAction storage action = _terminalFreezes[scopeKey];
        if (action.status != StreamTerminalFreezeStatus.SCHEDULED) {
            revert FinalityFreezeNotScheduled(scopeKey);
        }
        if (block.timestamp <= action.expiresAfter) {
            revert FinalityFreezeNotExpired(scopeKey);
        }
        _expireAction(scopeKey, action);
    }

    /// @notice Stored staged action; a virtually expired action reports SCHEDULED until
    ///         materialized, matching the [GOV-WINDOWS] virtual-expiry model.
    function artworkTerminalFreezeAction(StreamFinalityScope calldata scope)
        external
        view
        override
        returns (StreamTerminalFreezeAction memory)
    {
        return _terminalFreezes[_scopeKey(scope)];
    }

    /// @inheritdoc IStreamArtworkFinalityRegistry
    function artworkFreezeMode(StreamFinalityScope calldata scope)
        external
        view
        override
        returns (StreamArtworkFreezeMode)
    {
        StreamFinalityScope memory scopeMem = scope;
        if (scopeMem.scopeType == StreamFinalityScopeType.COLLECTION) {
            if (
                _collectionRecords[scopeMem.collectionId].finalized
                    && _isCanonicalScopeShape(scopeMem)
            ) {
                return StreamArtworkFreezeMode.INHERITED;
            }
            return StreamArtworkFreezeMode.NONE;
        }
        if (_scopedRecords[_scopeKey(scopeMem)].finalized) {
            return StreamArtworkFreezeMode.EXACT;
        }
        if (_collectionRecords[scopeMem.collectionId].finalized) {
            return StreamArtworkFreezeMode.INHERITED;
        }
        return StreamArtworkFreezeMode.NONE;
    }

    // ------------------------------------------------------------------
    // Manifest byte staging ([LTA-FINALITY] requirement 14)
    // ------------------------------------------------------------------

    /// @notice Stages canonical manifest bytes in registry storage, content-addressed by their
    ///         keccak256 hash; idempotent for already-staged content.
    function stageFinalityManifest(bytes calldata manifestBytes)
        external
        override
        returns (bytes32 contentHash)
    {
        uint256 byteLength = manifestBytes.length;
        if (byteLength == 0 || byteLength > MAX_FINALITY_CALLDATA_BYTES) {
            revert FinalityManifestBytesInvalid();
        }
        contentHash = keccak256(manifestBytes);
        if (_manifestBytes[contentHash].length == 0) {
            _manifestBytes[contentHash] = manifestBytes;
            emit FinalityManifestStaged(
                FINALITY_EVENT_SCHEMA_VERSION, contentHash, byteLength, msg.sender
            );
        }
    }

    /// @inheritdoc IStreamArtworkFinalityRegistry
    function finalityManifestStored(bytes32 contentHash) external view override returns (bool) {
        return _manifestBytes[contentHash].length != 0;
    }

    /// @inheritdoc IStreamArtworkFinalityRegistry
    function finalityManifestBytes(bytes32 contentHash)
        external
        view
        override
        returns (bytes memory)
    {
        return _manifestBytes[contentHash];
    }

    // ------------------------------------------------------------------
    // Finality execution
    // ------------------------------------------------------------------

    /// @inheritdoc IStreamArtworkFinalityRegistry
    function finalizeCollectionArtwork(
        uint256 collectionId,
        StreamFinalityComponentExpectation[] calldata components,
        bytes32 expectedFinalityRecordHash,
        StreamFinalityManifestRef calldata manifest
    ) external override {
        _finalize(_collectionScope(collectionId), components, expectedFinalityRecordHash, manifest);
    }

    /// @inheritdoc IStreamArtworkFinalityRegistry
    function finalizeArtworkScope(
        StreamFinalityScope calldata scope,
        StreamFinalityComponentExpectation[] calldata components,
        bytes32 expectedFinalityRecordHash,
        StreamFinalityManifestRef calldata manifest
    ) external override {
        if (scope.scopeType == StreamFinalityScopeType.COLLECTION) {
            revert FinalityScopeUsesCollectionEntry();
        }
        _finalize(scope, components, expectedFinalityRecordHash, manifest);
    }

    function _finalize(
        StreamFinalityScope memory scope,
        StreamFinalityComponentExpectation[] calldata components,
        bytes32 expectedFinalityRecordHash,
        StreamFinalityManifestRef calldata manifest
    ) private {
        if (msg.data.length > MAX_FINALITY_CALLDATA_BYTES) {
            revert FinalityCalldataTooLarge(msg.data.length, MAX_FINALITY_CALLDATA_BYTES);
        }
        _requireFinalityAdmin(msg.sender);
        _requireCanonicalScopeShape(scope);

        FinalityExecution memory ctx;
        ctx.scopeKey = _scopeKey(scope);
        if (_scopeFinalized(scope)) {
            revert FinalityAlreadyFinalized(ctx.scopeKey);
        }

        StreamTerminalFreezeAction storage action = _terminalFreezes[ctx.scopeKey];
        _requireExecutableFreeze(action, ctx.scopeKey, expectedFinalityRecordHash);

        _requireComponentListWellFormed(components);
        _requireManifestValid(manifest);

        (ctx.coreFactsHash, ctx.expectedLeafCount, ctx.exactLeafCount) =
            _verifyCoreGatesAndFacts(scope);
        _verifyContentRoot(scope, ctx.expectedLeafCount, ctx.exactLeafCount);
        _verifyFacadeBinding(scope.collectionId);

        ctx.componentsHash = _componentsHash(components);
        _verifySanctionComponent(scope, components, ctx.coreFactsHash, manifest);
        _verifyComponentsLiveStrict(components, _componentCallData(scope));
        _verifyDiscovery(scope, components.length, ctx.componentsHash);

        ctx.finalityRecordHash =
            _finalityRecordHash(scope, ctx.coreFactsHash, ctx.componentsHash, manifest);
        if (ctx.finalityRecordHash != expectedFinalityRecordHash) {
            revert FinalityExpectedRecordHashMismatch(
                expectedFinalityRecordHash, ctx.finalityRecordHash
            );
        }

        action.status = StreamTerminalFreezeStatus.EXECUTED;
        _storeRecordAndEmit(scope, ctx, components, manifest);
    }

    // ------------------------------------------------------------------
    // Pinned-preimage computation views (preview and signing-tool seam)
    // ------------------------------------------------------------------

    /// @inheritdoc IStreamArtworkFinalityRegistry
    function computeComponentsHash(StreamFinalityComponentExpectation[] calldata components)
        external
        pure
        override
        returns (bytes32)
    {
        return _componentsHash(components);
    }

    /// @inheritdoc IStreamArtworkFinalityRegistry
    function computeNonSanctionComponentsHash(StreamFinalityComponentExpectation[] calldata components)
        external
        pure
        override
        returns (bytes32)
    {
        return _nonSanctionComponentsHash(components);
    }

    /// @inheritdoc IStreamArtworkFinalityRegistry
    function computeCollectionCoreFactsHash(uint256 collectionId)
        external
        view
        override
        returns (bytes32)
    {
        return _coreCollectionFactsHash(
            collectionId, coreReads.coreCollectionFinalityFacts(collectionId)
        );
    }

    /// @inheritdoc IStreamArtworkFinalityRegistry
    function computeScopedCoreFactsHash(StreamFinalityScope calldata scope)
        external
        view
        override
        returns (bytes32)
    {
        return _scopedCoreFactsHash(scope, coreReads.scopedCoreFinalityFacts(scope));
    }

    /// @inheritdoc IStreamArtworkFinalityRegistry
    function computeFinalityRecordHash(
        StreamFinalityScope calldata scope,
        bytes32 coreFactsHash,
        bytes32 componentsHash,
        StreamFinalityManifestRef calldata manifest
    ) external view override returns (bytes32) {
        return _finalityRecordHash(scope, coreFactsHash, componentsHash, manifest);
    }

    /// @inheritdoc IStreamArtworkFinalityRegistry
    function computeSanctionSubjectHash(
        StreamFinalityScope calldata scope,
        bytes32 coreFactsHash,
        bytes32 nonSanctionComponentsHash,
        StreamFinalityManifestRef calldata manifest
    ) external view override returns (bytes32) {
        return _sanctionSubjectHash(scope, coreFactsHash, nonSanctionComponentsHash, manifest);
    }

    /// @inheritdoc IStreamArtworkFinalityRegistry
    function contentRootScopeSubject(StreamFinalityScope calldata scope)
        external
        view
        override
        returns (bytes32)
    {
        return _contentRootSubject(scope);
    }

    // ------------------------------------------------------------------
    // Required reads and diagnostics
    // ------------------------------------------------------------------

    /// @inheritdoc IStreamArtworkFinalityRegistry
    function collectionFinalityRecord(uint256 collectionId)
        external
        view
        override
        returns (StreamCollectionFinalityRecord memory)
    {
        return _collectionRecords[collectionId];
    }

    /// @inheritdoc IStreamArtworkFinalityRegistry
    function finalityComponentCount(uint256 collectionId) external view override returns (uint256) {
        return _collectionComponents[collectionId].length;
    }

    /// @inheritdoc IStreamArtworkFinalityRegistry
    function finalityComponents(uint256 collectionId, uint256 start, uint256 limit)
        external
        view
        override
        returns (StreamFinalityComponentExpectation[] memory)
    {
        return _sliceComponents(_collectionComponents[collectionId], start, limit);
    }

    /// @inheritdoc IStreamArtworkFinalityRegistry
    function finalityStillMatches(uint256 collectionId) external view override returns (bool) {
        (bool matches,,) = _verifyScopeDiagnostic(_collectionScope(collectionId));
        return matches;
    }

    /// @inheritdoc IStreamArtworkFinalityRegistry
    function verifyFinality(uint256 collectionId)
        external
        view
        override
        returns (bool currentRouteMatches, bytes32 finalityRecordHash, bytes32 componentsHash)
    {
        return _verifyScopeDiagnostic(_collectionScope(collectionId));
    }

    /// @inheritdoc IStreamArtworkFinalityRegistry
    function verifyFinalityRange(uint256 collectionId, uint256 start, uint256 limit)
        external
        view
        override
        returns (
            bool rangeMatches,
            bytes32 finalityRecordHash,
            bytes32 expectedRangeHash,
            bytes32 observedRangeHash,
            uint256 nextStart
        )
    {
        return _verifyScopeRange(_collectionScope(collectionId), start, limit);
    }

    /// @inheritdoc IStreamArtworkFinalityRegistry
    function artworkScopeFinalityRecord(StreamFinalityScope calldata scope)
        external
        view
        override
        returns (StreamScopedFinalityRecord memory out)
    {
        StreamFinalityScope memory scopeMem = scope;
        if (
            scopeMem.scopeType == StreamFinalityScopeType.COLLECTION
                && _isCanonicalScopeShape(scopeMem)
        ) {
            StreamCollectionFinalityRecord storage record =
                _collectionRecords[scopeMem.collectionId];
            if (!record.finalized) {
                return out;
            }
            out.finalized = true;
            out.scope = scopeMem;
            out.finalityRecordHash = record.finalityRecordHash;
            out.manifestContentHash = record.manifestContentHash;
            out.manifestURIHash = record.manifestURIHash;
            out.componentsHash = record.componentsHash;
            out.finalityManifestURI = record.finalityManifestURI;
            out.manifestPointer = record.manifestPointer;
            out.finalizedAt = record.finalizedAt;
            return out;
        }
        return _scopedRecords[_scopeKey(scopeMem)];
    }

    /// @inheritdoc IStreamArtworkFinalityRegistry
    function verifyArtworkScopeFinality(StreamFinalityScope calldata scope)
        external
        view
        override
        returns (bool currentRouteMatches, bytes32 finalityRecordHash, bytes32 componentsHash)
    {
        return _verifyScopeDiagnostic(scope);
    }

    /// @inheritdoc IStreamArtworkFinalityRegistry
    function verifyArtworkScopeFinalityRange(
        StreamFinalityScope calldata scope,
        uint256 start,
        uint256 limit
    )
        external
        view
        override
        returns (
            bool rangeMatches,
            bytes32 finalityRecordHash,
            bytes32 expectedRangeHash,
            bytes32 observedRangeHash,
            uint256 nextStart
        )
    {
        return _verifyScopeRange(scope, start, limit);
    }

    /// @inheritdoc IStreamArtworkFinalityRegistry
    function finalityComponentCountForScope(StreamFinalityScope calldata scope)
        external
        view
        override
        returns (uint256)
    {
        (,,, StreamFinalityComponentExpectation[] storage stored) = _storedRecordFor(scope);
        return stored.length;
    }

    /// @inheritdoc IStreamArtworkFinalityRegistry
    function finalityComponentsForScope(
        StreamFinalityScope calldata scope,
        uint256 start,
        uint256 limit
    ) external view override returns (StreamFinalityComponentExpectation[] memory) {
        (,,, StreamFinalityComponentExpectation[] storage stored) = _storedRecordFor(scope);
        return _sliceComponents(stored, start, limit);
    }

    /// @inheritdoc IStreamArtworkScopedFrozenRouteRegistry
    function frozenRouteForScope(bytes32 routeType, StreamFinalityScope calldata scope)
        external
        view
        override
        returns (bool pinned, address module, bytes32 routeHash, bytes32 finalityRecordHash)
    {
        (bool finalized, bytes32 recHash,, StreamFinalityComponentExpectation[] storage stored) =
            _storedRecordFor(scope);
        if (!finalized) {
            return (false, address(0), bytes32(0), bytes32(0));
        }
        uint256 count = stored.length;
        for (uint256 i = 0; i < count; i++) {
            if (stored[i].componentType == routeType) {
                StreamFinalityComponentExpectation memory expectation = stored[i];
                return (true, expectation.component, keccak256(abi.encode(expectation)), recHash);
            }
        }
        return (false, address(0), bytes32(0), recHash);
    }

    // ------------------------------------------------------------------
    // Internal: freeze machinery
    // ------------------------------------------------------------------

    function _expireAction(bytes32 scopeKey, StreamTerminalFreezeAction storage action) private {
        action.status = StreamTerminalFreezeStatus.EXPIRED;
        emit ArtworkTerminalFreezeExpired(
            FINALITY_EVENT_SCHEMA_VERSION, scopeKey, action.expectedFinalityRecordHash
        );
    }

    function _requireExecutableFreeze(
        StreamTerminalFreezeAction storage action,
        bytes32 scopeKey,
        bytes32 expectedFinalityRecordHash
    ) private view {
        if (action.status != StreamTerminalFreezeStatus.SCHEDULED) {
            revert FinalityFreezeNotScheduled(scopeKey);
        }
        if (block.timestamp < action.notBefore || block.timestamp > action.expiresAfter) {
            revert FinalityFreezeNotOpen(action.notBefore, action.expiresAfter);
        }
        if (action.expectedFinalityRecordHash != expectedFinalityRecordHash) {
            revert FinalityStagedHashMismatch(
                action.expectedFinalityRecordHash, expectedFinalityRecordHash
            );
        }
    }

    function _requireFinalityAdmin(address account) private view {
        if (!governanceAuthority.hasStreamRole(
                StreamFinalityDomains.ROLE_COLLECTION_FINALITY_ADMIN, account
            )) {
            revert FinalityCallerNotFinalityAdmin(account);
        }
    }

    // ------------------------------------------------------------------
    // Internal: scope helpers
    // ------------------------------------------------------------------

    function _collectionScope(uint256 collectionId)
        private
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

    function _scopeKey(StreamFinalityScope memory scope) private pure returns (bytes32) {
        return keccak256(
            abi.encode(uint8(scope.scopeType), scope.collectionId, scope.tokenId, scope.scopeId)
        );
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

    function _requireCanonicalScopeShape(StreamFinalityScope memory scope) private pure {
        if (!_isCanonicalScopeShape(scope)) {
            revert FinalityScopeShapeInvalid();
        }
    }

    function _scopeFinalized(StreamFinalityScope memory scope) private view returns (bool) {
        if (scope.scopeType == StreamFinalityScopeType.COLLECTION) {
            return _collectionRecords[scope.collectionId].finalized;
        }
        return _scopedRecords[_scopeKey(scope)].finalized;
    }

    function _storedRecordFor(StreamFinalityScope memory scope)
        private
        view
        returns (
            bool finalized,
            bytes32 recHash,
            bytes32 compHash,
            StreamFinalityComponentExpectation[] storage stored
        )
    {
        if (scope.scopeType == StreamFinalityScopeType.COLLECTION && _isCanonicalScopeShape(scope))
        {
            StreamCollectionFinalityRecord storage record = _collectionRecords[scope.collectionId];
            return (
                record.finalized,
                record.finalityRecordHash,
                record.componentsHash,
                _collectionComponents[scope.collectionId]
            );
        }
        bytes32 scopeKey = _scopeKey(scope);
        StreamScopedFinalityRecord storage srecord = _scopedRecords[scopeKey];
        return (
            srecord.finalized,
            srecord.finalityRecordHash,
            srecord.componentsHash,
            _scopedComponents[scopeKey]
        );
    }

    // ------------------------------------------------------------------
    // Internal: execution gates (strict, typed reverts)
    // ------------------------------------------------------------------

    function _requireComponentListWellFormed(StreamFinalityComponentExpectation[] calldata components)
        private
        pure
    {
        uint256 count = components.length;
        if (count == 0 || count > MAX_FINALITY_COMPONENTS) {
            revert FinalityComponentCountInvalid(count, MAX_FINALITY_COMPONENTS);
        }
        for (uint256 i = 1; i < count; i++) {
            if (!_strictlyAscending(components[i - 1], components[i])) {
                revert FinalityComponentsUnsorted(i);
            }
        }
    }

    /// @dev Full-identity-tuple ordering per [LTA-FINALITY]: sorted ascending by
    ///      (componentType, component, interfaceId, codeHash, moduleVersion, manifestHash,
    ///      dataHash) with no duplicates; equal tuples are duplicates and fail.
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

    function _requireManifestValid(StreamFinalityManifestRef calldata manifest) private view {
        bytes32 recomputedURIHash = keccak256(bytes(manifest.uri));
        if (manifest.uriHash != recomputedURIHash) {
            revert FinalityManifestURIHashMismatch(recomputedURIHash, manifest.uriHash);
        }
        if (
            manifest.contentHash == bytes32(0) || manifest.schemaId == bytes32(0)
                || manifest.canonicalizationHash == bytes32(0)
        ) {
            revert FinalityManifestFieldZero();
        }
        if (_manifestBytes[manifest.contentHash].length == 0) {
            revert FinalityManifestBytesMissing(manifest.contentHash);
        }
    }

    /// @dev Collection scope: existence, CLOSED status, and the one-way burn block
    ///      ([LTA-FINALITY] requirement 7, [CMC-BURN] rule 7). Scoped: scope existence and
    ///      the TOKEN minted-or-burned rule (scope rules 2-3).
    function _verifyCoreGatesAndFacts(StreamFinalityScope memory scope)
        private
        view
        returns (bytes32 factsHash, uint64 expectedLeafCount, bool exactLeafCount)
    {
        if (scope.scopeType == StreamFinalityScopeType.COLLECTION) {
            StreamCoreCollectionFinalityFacts memory facts =
                coreReads.coreCollectionFinalityFacts(scope.collectionId);
            if (!facts.exists) {
                revert FinalityCollectionUnknown(scope.collectionId);
            }
            if (facts.status != StreamFinalityDomains.CORE_COLLECTION_STATUS_CLOSED) {
                revert FinalityCollectionNotClosed(scope.collectionId, facts.status);
            }
            if (!coreReads.collectionBurnsBlocked(scope.collectionId)) {
                revert FinalityCollectionBurnsNotBlocked(scope.collectionId);
            }
            return (_coreCollectionFactsHash(scope.collectionId, facts), facts.mintedSupply, true);
        }
        StreamScopedCoreFinalityFacts memory scopedFacts = coreReads.scopedCoreFinalityFacts(scope);
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
            return (_scopedCoreFactsHash(scope, scopedFacts), 1, true);
        }
        return (_scopedCoreFactsHash(scope, scopedFacts), 0, false);
    }

    /// @dev [CMC-FINALITY-INPUTS] rule 4 / [CMC-CONTENT-ROOT] rule 4: the recorded token
    ///      content root and leaf count verify at execution. Collection scope binds the exact
    ///      minted-ever count (burned tokens retain archival content, [CMC-BURN] rule 4);
    ///      TOKEN scope binds exactly one leaf; RELEASE/SEASON/VIEW bind a nonzero-leaf root
    ///      whose exact token set is pinned by the metadata scope manifest.
    function _verifyContentRoot(
        StreamFinalityScope memory scope,
        uint64 expectedLeafCount,
        bool exactLeafCount
    ) private view {
        bytes32 scopeSubject = _contentRootSubject(scope);
        (bytes32 contentRoot, uint64 leafCount,) =
            metadataReads.tokenContentRoot(scope.collectionId, scopeSubject);
        if (contentRoot == bytes32(0)) {
            revert FinalityContentRootMissing(scopeSubject);
        }
        if (exactLeafCount) {
            if (leafCount != expectedLeafCount) {
                revert FinalityContentRootLeafCountMismatch(expectedLeafCount, leafCount);
            }
        } else if (leafCount == 0) {
            revert FinalityContentRootLeafCountMismatch(1, leafCount);
        }
    }

    /// @dev [LTA-FINALITY] requirement 16 / [CMC-FINALITY-INPUTS] rule 14: EXTERNAL_FACADE
    ///      collections require the recorded facade identity binding whose facade address
    ///      equals the Core-registered transfer controller; CORE_NATIVE collections carry no
    ///      binding component by construction and skip this gate.
    function _verifyFacadeBinding(uint256 collectionId) private view {
        if (
            coreReads.collectionIdentityMode(collectionId)
                != StreamFinalityDomains.IDENTITY_MODE_EXTERNAL_FACADE
        ) {
            return;
        }
        (bool recorded, address facadeAddress,) =
            metadataReads.facadeIdentityBindingRecord(collectionId);
        if (!recorded) {
            revert FinalityFacadeBindingMissing(collectionId);
        }
        address controller = coreReads.collectionTransferController(collectionId);
        if (facadeAddress == address(0) || facadeAddress != controller) {
            revert FinalityFacadeBindingControllerMismatch(facadeAddress, controller);
        }
    }

    /// @dev [LTA-FINALITY] requirement 9 / [AA-SANCTION] requirement 3: exactly one of
    ///      ARTIST_SANCTION and PLATFORM_WORKS_DECLARATION, matching the artist registry's
    ///      required type; artist-bound scopes verify the sanction over the subject hash and
    ///      bind `sanctionRecordHash` as the component dataHash.
    function _verifySanctionComponent(
        StreamFinalityScope memory scope,
        StreamFinalityComponentExpectation[] calldata components,
        bytes32 coreFactsHash,
        StreamFinalityManifestRef calldata manifest
    ) private view {
        (uint256 index, uint256 occurrences) = _locateSanctionSlot(components);
        if (occurrences == 0) {
            revert FinalitySanctionComponentMissing();
        }
        if (occurrences > 1) {
            revert FinalitySanctionComponentDuplicated();
        }
        bytes32 requiredType = sanctionReads.collectionSanctionComponentType(scope.collectionId);
        bytes32 suppliedType = components[index].componentType;
        if (suppliedType != requiredType) {
            revert FinalitySanctionComponentWrongType(requiredType, suppliedType);
        }
        if (requiredType != StreamFinalityDomains.COMPONENT_ARTIST_SANCTION) {
            return;
        }
        _requireVerifiedSanction(
            scope,
            _sanctionSubjectHash(
                scope, coreFactsHash, _nonSanctionComponentsHash(components), manifest
            ),
            components[index].dataHash
        );
    }

    function _requireVerifiedSanction(
        StreamFinalityScope memory scope,
        bytes32 sanctionSubjectHash,
        bytes32 componentDataHash
    ) private view {
        (bool valid, bytes32 sanctionRecordHash) = _sanctionVerification(scope, sanctionSubjectHash);
        if (!valid) {
            revert FinalitySanctionInvalid(sanctionSubjectHash);
        }
        if (sanctionRecordHash != componentDataHash) {
            revert FinalitySanctionRecordHashMismatch(componentDataHash, sanctionRecordHash);
        }
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

    function _verifyComponentsLiveStrict(
        StreamFinalityComponentExpectation[] calldata components,
        bytes memory componentCallData
    ) private view {
        uint256 count = components.length;
        for (uint256 i = 0; i < count; i++) {
            address component = components[i].component;
            if (component.code.length == 0) {
                revert FinalityComponentUnreadable(i);
            }
            if (component.codehash != components[i].codeHash) {
                revert FinalityComponentCodeHashMismatch(i);
            }
            (bool readable, StreamFinalityComponentState memory state) =
                _observeComponent(component, componentCallData, 0);
            if (!readable) {
                revert FinalityComponentUnreadable(i);
            }
            if (!_stateMatchesExpectation(state, components[i])) {
                revert FinalityComponentMismatch(i);
            }
        }
    }

    function _verifyDiscovery(
        StreamFinalityScope memory scope,
        uint256 submittedCount,
        bytes32 submittedHash
    ) private view {
        address discovery = finalityDiscovery;
        if (discovery == address(0)) {
            return;
        }
        (uint256 discoveredCount, bytes32 discoveredHash) = _discoveryFacts(discovery, scope);
        if (discoveredCount != submittedCount) {
            revert FinalityDiscoveryCountMismatch(discoveredCount, submittedCount);
        }
        if (discoveredHash != submittedHash) {
            revert FinalityDiscoveryHashMismatch(discoveredHash, submittedHash);
        }
    }

    function _discoveryFacts(address discovery, StreamFinalityScope memory scope)
        private
        view
        returns (uint256 discoveredCount, bytes32 discoveredHash)
    {
        if (scope.scopeType == StreamFinalityScopeType.COLLECTION) {
            discoveredCount = IStreamArtworkFinalityDiscovery(discovery)
                .finalityComponentCount(scope.collectionId);
            discoveredHash = IStreamArtworkFinalityDiscovery(discovery)
                .finalityDiscoveryHash(scope.collectionId);
        } else {
            discoveredCount = IStreamArtworkScopedFinalityDiscovery(discovery)
                .finalityComponentCountForScope(scope);
            discoveredHash = IStreamArtworkScopedFinalityDiscovery(discovery)
                .finalityDiscoveryHashForScope(scope);
        }
    }

    // ------------------------------------------------------------------
    // Internal: component observation shared by execution and diagnostics
    // ------------------------------------------------------------------

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

    function _componentStillMatches(
        StreamFinalityComponentExpectation memory expectation,
        bytes memory componentCallData,
        uint256 gasCap
    ) private view returns (bool) {
        address component = expectation.component;
        if (component.code.length == 0 || component.codehash != expectation.codeHash) {
            return false;
        }
        (bool readable, StreamFinalityComponentState memory state) =
            _observeComponent(component, componentCallData, gasCap);
        if (!readable) {
            return false;
        }
        return _stateMatchesExpectation(state, expectation);
    }

    /// @dev Bounded staticcall with a fixed-size returndata copy; never reverts on component
    ///      misbehavior ([LTA-FINALITY] diagnostic-read semantics).
    function _observeComponent(address component, bytes memory componentCallData, uint256 gasCap)
        private
        view
        returns (bool readable, StreamFinalityComponentState memory state)
    {
        bool success;
        bytes memory returndata;
        if (gasCap == 0) {
            (success, returndata) = component.staticcall(componentCallData);
        } else {
            (success, returndata) = component.staticcall{ gas: gasCap }(componentCallData);
        }
        if (!success || returndata.length != 256) {
            return (false, state);
        }
        return _decodeComponentState(returndata);
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

    function _stateMatchesExpectation(
        StreamFinalityComponentState memory state,
        StreamFinalityComponentExpectation memory expectation
    ) private pure returns (bool) {
        return state.frozen && state.componentType == expectation.componentType
            && state.component == expectation.component
            && state.interfaceId == expectation.interfaceId
            && state.codeHash == expectation.codeHash
            && state.moduleVersion == expectation.moduleVersion
            && state.manifestHash == expectation.manifestHash
            && state.dataHash == expectation.dataHash;
    }

    // ------------------------------------------------------------------
    // Internal: pinned hash preimages
    // ------------------------------------------------------------------

    function _componentsHash(StreamFinalityComponentExpectation[] calldata components)
        private
        pure
        returns (bytes32)
    {
        return keccak256(
            abi.encode(StreamFinalityDomains.STREAM_FINALITY_COMPONENTS_V1, components)
        );
    }

    function _componentsHashMemory(StreamFinalityComponentExpectation[] memory components)
        private
        pure
        returns (bytes32)
    {
        return keccak256(
            abi.encode(StreamFinalityDomains.STREAM_FINALITY_COMPONENTS_V1, components)
        );
    }

    /// @dev componentsHash over the submitted list with every ARTIST_SANCTION entry excluded
    ///      ([AA-SANCTION]): same domain, same sort order.
    function _nonSanctionComponentsHash(StreamFinalityComponentExpectation[] calldata components)
        private
        pure
        returns (bytes32)
    {
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
        return _componentsHashMemory(filtered);
    }

    /// @dev Splitting a wide static-arg `abi.encode` into `bytes.concat` halves is
    ///      byte-identical because every argument is a static type occupying exactly one
    ///      32-byte head word; the golden tests recompute each preimage in one encode and
    ///      assert equality. The split keeps legacy codegen under its stack limit.
    function _coreCollectionFactsHash(
        uint256 collectionId,
        StreamCoreCollectionFinalityFacts memory facts
    ) private view returns (bytes32) {
        return keccak256(
            bytes.concat(
                abi.encode(
                    StreamFinalityDomains.STREAM_CORE_COLLECTION_FACTS_V1,
                    block.chainid,
                    address(coreReads),
                    collectionId,
                    facts.exists,
                    facts.hasMaxSupply,
                    facts.status
                ),
                abi.encode(
                    facts.supplyMode,
                    facts.createdAt,
                    facts.maxSupply,
                    facts.mintedSupply,
                    facts.burnedSupply,
                    facts.nextCollectionSerial,
                    facts.collectionConfigHash
                )
            )
        );
    }

    function _scopedCoreFactsHash(
        StreamFinalityScope memory scope,
        StreamScopedCoreFinalityFacts memory facts
    ) private view returns (bytes32) {
        return keccak256(
            bytes.concat(
                abi.encode(
                    StreamFinalityDomains.STREAM_SCOPED_CORE_FINALITY_FACTS_V1,
                    block.chainid,
                    address(coreReads),
                    uint8(scope.scopeType),
                    scope.collectionId,
                    scope.tokenId,
                    scope.scopeId,
                    facts.scopeExists
                ),
                abi.encode(
                    facts.tokenMappingExists,
                    facts.collectionSerial,
                    facts.tokenLifecycle,
                    facts.burned,
                    facts.collectionStatus,
                    facts.collectionSupplyMode,
                    facts.collectionConfigHash,
                    facts.scopeManifestHash
                )
            )
        );
    }

    function _finalityRecordHash(
        StreamFinalityScope memory scope,
        bytes32 coreFactsHash,
        bytes32 componentsHash,
        StreamFinalityManifestRef calldata manifest
    ) private view returns (bytes32) {
        if (scope.scopeType == StreamFinalityScopeType.COLLECTION) {
            return keccak256(
                bytes.concat(
                    abi.encode(
                        StreamFinalityDomains.STREAM_FINALITY_V1,
                        block.chainid,
                        address(coreReads),
                        scope.collectionId,
                        coreFactsHash
                    ),
                    abi.encode(
                        componentsHash,
                        manifest.uriHash,
                        manifest.contentHash,
                        manifest.schemaId,
                        manifest.canonicalizationHash
                    )
                )
            );
        }
        return keccak256(
            bytes.concat(
                abi.encode(
                    StreamFinalityDomains.STREAM_SCOPED_FINALITY_V1,
                    block.chainid,
                    address(coreReads),
                    uint8(scope.scopeType),
                    scope.collectionId,
                    scope.tokenId,
                    scope.scopeId
                ),
                abi.encode(
                    coreFactsHash,
                    componentsHash,
                    manifest.uriHash,
                    manifest.contentHash,
                    manifest.schemaId,
                    manifest.canonicalizationHash
                )
            )
        );
    }

    /// @dev Sanction subject preimage ([AA-SANCTION]/[AA-DOMAINS]): the finality record
    ///      preimage without the sanction component itself.
    function _sanctionSubjectHash(
        StreamFinalityScope memory scope,
        bytes32 coreFactsHash,
        bytes32 nonSanctionComponentsHash,
        StreamFinalityManifestRef calldata manifest
    ) private view returns (bytes32) {
        return keccak256(
            bytes.concat(
                abi.encode(
                    StreamFinalityDomains.SANCTION_SUBJECT_DOMAIN,
                    block.chainid,
                    address(coreReads),
                    address(this),
                    uint8(scope.scopeType),
                    scope.collectionId,
                    scope.tokenId
                ),
                abi.encode(
                    scope.scopeId,
                    coreFactsHash,
                    nonSanctionComponentsHash,
                    manifest.uriHash,
                    manifest.contentHash,
                    manifest.schemaId,
                    manifest.canonicalizationHash
                )
            )
        );
    }

    /// @dev [CMC-SUBJECT-ID] derivations: collection subject for COLLECTION scope, token
    ///      subject for TOKEN scope, scope subject for RELEASE/SEASON/VIEW.
    function _contentRootSubject(StreamFinalityScope memory scope) private view returns (bytes32) {
        if (scope.scopeType == StreamFinalityScopeType.COLLECTION) {
            return keccak256(
                abi.encode(
                    StreamFinalityDomains.STREAM_SUBJECT_COLLECTION_V1,
                    block.chainid,
                    address(coreReads),
                    scope.collectionId
                )
            );
        }
        if (scope.scopeType == StreamFinalityScopeType.TOKEN) {
            return keccak256(
                abi.encode(
                    StreamFinalityDomains.STREAM_SUBJECT_TOKEN_V1,
                    block.chainid,
                    address(coreReads),
                    scope.tokenId
                )
            );
        }
        return keccak256(
            abi.encode(
                StreamFinalityDomains.STREAM_SUBJECT_SCOPE_V1,
                block.chainid,
                address(coreReads),
                scope.collectionId,
                uint8(scope.scopeType),
                scope.scopeId
            )
        );
    }

    // ------------------------------------------------------------------
    // Internal: storage effects and diagnostics
    // ------------------------------------------------------------------

    function _storeRecordAndEmit(
        StreamFinalityScope memory scope,
        FinalityExecution memory ctx,
        StreamFinalityComponentExpectation[] calldata components,
        StreamFinalityManifestRef calldata manifest
    ) private {
        uint256 count = components.length;
        if (scope.scopeType == StreamFinalityScopeType.COLLECTION) {
            StreamCollectionFinalityRecord storage record = _collectionRecords[scope.collectionId];
            record.finalized = true;
            record.finalityRecordHash = ctx.finalityRecordHash;
            record.manifestContentHash = manifest.contentHash;
            record.manifestURIHash = manifest.uriHash;
            record.finalityManifestURI = manifest.uri;
            record.componentsHash = ctx.componentsHash;
            record.manifestPointer = address(this);
            record.finalizedAt = uint64(block.timestamp);
            StreamFinalityComponentExpectation[] storage stored =
                _collectionComponents[scope.collectionId];
            for (uint256 i = 0; i < count; i++) {
                stored.push(components[i]);
            }
            emit CollectionArtworkFinalized(
                FINALITY_EVENT_SCHEMA_VERSION,
                scope.collectionId,
                ctx.finalityRecordHash,
                msg.sender,
                ctx.componentsHash,
                manifest.contentHash,
                manifest.uri
            );
        } else {
            StreamScopedFinalityRecord storage record = _scopedRecords[ctx.scopeKey];
            record.finalized = true;
            record.scope = scope;
            record.finalityRecordHash = ctx.finalityRecordHash;
            record.manifestContentHash = manifest.contentHash;
            record.manifestURIHash = manifest.uriHash;
            record.componentsHash = ctx.componentsHash;
            record.finalityManifestURI = manifest.uri;
            record.manifestPointer = address(this);
            record.finalizedAt = uint64(block.timestamp);
            StreamFinalityComponentExpectation[] storage stored = _scopedComponents[ctx.scopeKey];
            for (uint256 i = 0; i < count; i++) {
                stored.push(components[i]);
            }
            emit ArtworkScopeFinalized(
                FINALITY_EVENT_SCHEMA_VERSION,
                uint8(scope.scopeType),
                scope.collectionId,
                ctx.finalityRecordHash,
                scope.tokenId,
                scope.scopeId,
                ctx.componentsHash,
                manifest.contentHash,
                manifest.uri
            );
        }
        emit FinalityManifestPointerRecorded(
            FINALITY_EVENT_SCHEMA_VERSION,
            ctx.finalityRecordHash,
            address(this),
            manifest.contentHash
        );
        emit ArtworkTerminalFreezeExecuted(
            FINALITY_EVENT_SCHEMA_VERSION, ctx.scopeKey, ctx.finalityRecordHash, msg.sender
        );
    }

    function _sliceComponents(
        StreamFinalityComponentExpectation[] storage stored,
        uint256 start,
        uint256 limit
    ) private view returns (StreamFinalityComponentExpectation[] memory out) {
        uint256 count = stored.length;
        if (start >= count || limit == 0) {
            return new StreamFinalityComponentExpectation[](0);
        }
        uint256 end = limit >= count - start ? count : start + limit;
        out = new StreamFinalityComponentExpectation[](end - start);
        for (uint256 i = start; i < end; i++) {
            out[i - start] = stored[i];
        }
    }

    function _verifyScopeDiagnostic(StreamFinalityScope memory scope)
        private
        view
        returns (bool currentRouteMatches, bytes32 finalityRecordHash, bytes32 componentsHash)
    {
        (
            bool finalized,
            bytes32 recHash,
            bytes32 compHash,
            StreamFinalityComponentExpectation[] storage stored
        ) = _storedRecordFor(scope);
        if (!finalized) {
            return (false, bytes32(0), bytes32(0));
        }
        bytes memory componentCallData = _componentCallData(scope);
        bool matches = true;
        uint256 count = stored.length;
        for (uint256 i = 0; i < count && matches; i++) {
            matches =
                _componentStillMatches(stored[i], componentCallData, FINALITY_COMPONENT_READ_GAS);
        }
        return (matches, recHash, compHash);
    }

    function _verifyScopeRange(StreamFinalityScope memory scope, uint256 start, uint256 limit)
        private
        view
        returns (
            bool rangeMatches,
            bytes32 finalityRecordHash,
            bytes32 expectedRangeHash,
            bytes32 observedRangeHash,
            uint256 nextStart
        )
    {
        (bool finalized, bytes32 recHash,, StreamFinalityComponentExpectation[] storage stored) =
            _storedRecordFor(scope);
        if (!finalized) {
            return (false, bytes32(0), bytes32(0), bytes32(0), 0);
        }
        RangeObservation memory result =
            _observeRange(stored, _componentCallData(scope), start, limit);
        return (
            result.matches,
            recHash,
            result.expectedRangeHash,
            result.observedRangeHash,
            result.nextStart
        );
    }

    function _observeRange(
        StreamFinalityComponentExpectation[] storage stored,
        bytes memory componentCallData,
        uint256 start,
        uint256 limit
    ) private view returns (RangeObservation memory result) {
        uint256 count = stored.length;
        uint256 from = start > count ? count : start;
        uint256 end = limit >= count - from ? count : from + limit;
        result.nextStart = end;
        result.matches = true;
        StreamFinalityComponentExpectation[] memory expected =
            new StreamFinalityComponentExpectation[](end - from);
        StreamFinalityComponentExpectation[] memory observed =
            new StreamFinalityComponentExpectation[](end - from);
        for (uint256 i = 0; i < expected.length; i++) {
            expected[i] = stored[from + i];
            (bool readable, StreamFinalityComponentState memory state) = _observeComponent(
                expected[i].component, componentCallData, FINALITY_COMPONENT_READ_GAS
            );
            if (readable) {
                observed[i] = StreamFinalityComponentExpectation({
                    componentType: state.componentType,
                    component: state.component,
                    interfaceId: state.interfaceId,
                    codeHash: state.codeHash,
                    moduleVersion: state.moduleVersion,
                    manifestHash: state.manifestHash,
                    dataHash: state.dataHash
                });
            }
            if (!_observationMatches(expected[i], readable, state)) {
                result.matches = false;
            }
        }
        result.expectedRangeHash = _componentsHashMemory(expected);
        result.observedRangeHash = _componentsHashMemory(observed);
    }

    function _observationMatches(
        StreamFinalityComponentExpectation memory expectation,
        bool readable,
        StreamFinalityComponentState memory state
    ) private view returns (bool) {
        if (!readable) {
            return false;
        }
        address component = expectation.component;
        if (component.code.length == 0 || component.codehash != expectation.codeHash) {
            return false;
        }
        return _stateMatchesExpectation(state, expectation);
    }
}

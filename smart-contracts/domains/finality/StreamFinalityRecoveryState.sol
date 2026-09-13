// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./StreamFinalityRecoveryIntentState.sol";
import "../../interfaces/stream/finality/IStreamFinalityRecoveryEvents.sol";
import "../../interfaces/stream/finality/IStreamFinalityRecoveryCore.sol";
import {
    StreamFinalityRecoveryRecord,
    StreamFinalityRecoveryRefreshPlan
} from "../../interfaces/stream/finality/StreamFinalityRecoveryTypes.sol";

/// @notice Owner-supplied executed recovery facts and bounded, atomic refresh state.
/// @dev The fixed companion must authenticate Executor context, original scope/route/evidence,
///      current module selection and the actual Core high-water mark before append. No public
///      library call establishes those facts. All maps belong to the delegatecalling owner.
library StreamFinalityRecoveryState {
    event FinalityRecoveryExecuted(
        uint16 schemaVersion,
        uint256 indexed collectionId,
        bytes32 indexed recoveryId,
        bytes32 recoveryManifestContentHash,
        bytes32 recoveryRouteHash,
        bool artworkBytesChanged,
        bytes32 reasonHash,
        string reasonURI
    );
    event ScopedFinalityRecoveryExecuted(
        uint16 schemaVersion,
        uint8 indexed scopeType,
        uint256 indexed collectionId,
        bytes32 indexed recoveryId,
        uint256 tokenId,
        bytes32 scopeId,
        bytes32 recoveryManifestContentHash,
        bytes32 recoveryRouteHash,
        bool artworkBytesChanged,
        bytes32 reasonHash,
        string reasonURI
    );
    event FinalityRecoveryRefreshPlanCreated(
        uint16 schemaVersion,
        uint256 indexed collectionId,
        bytes32 indexed recoveryId,
        bytes32 indexed manifestContentHash,
        uint256 lastAllocatedTokenIdAtExecution,
        uint256 rangeStart,
        uint256 rangeEnd,
        bool complete
    );
    event FinalityRecoveryRefreshProgress(
        uint16 schemaVersion,
        uint256 indexed collectionId,
        bytes32 indexed recoveryId,
        bytes32 indexed manifestContentHash,
        uint256 fromTokenId,
        uint256 toTokenId,
        uint256 processedThrough,
        uint256 chunksEmitted,
        bool complete
    );
    event FinalityRecoveryRefreshPlanSuperseded(
        uint16 schemaVersion,
        uint256 indexed collectionId,
        bytes32 indexed recoveryId,
        bytes32 indexed supersededByRecoveryId,
        bytes32 manifestContentHash,
        uint256 processedThrough,
        uint256 rangeEnd
    );
    event ScopedFinalityRecoveryRefreshPlanCreated(
        uint16 schemaVersion,
        uint8 indexed scopeType,
        uint256 indexed collectionId,
        bytes32 indexed recoveryId,
        uint256 tokenId,
        bytes32 scopeId,
        bytes32 manifestContentHash,
        uint256 lastAllocatedTokenIdAtExecution,
        uint256 rangeStart,
        uint256 rangeEnd,
        bool complete
    );
    event ScopedFinalityRecoveryRefreshProgress(
        uint16 schemaVersion,
        uint8 indexed scopeType,
        uint256 indexed collectionId,
        bytes32 indexed recoveryId,
        uint256 tokenId,
        bytes32 scopeId,
        bytes32 manifestContentHash,
        uint256 fromTokenId,
        uint256 toTokenId,
        uint256 processedThrough,
        uint256 chunksEmitted,
        bool complete
    );
    event ScopedFinalityRecoveryRefreshPlanSuperseded(
        uint16 schemaVersion,
        uint8 indexed scopeType,
        uint256 indexed collectionId,
        bytes32 indexed recoveryId,
        uint256 tokenId,
        bytes32 scopeId,
        bytes32 supersededByRecoveryId,
        bytes32 manifestContentHash,
        uint256 processedThrough,
        uint256 rangeEnd
    );
    event FinalityRecoveryLineageRecorded(
        uint16 schemaVersion,
        bytes32 indexed recoveryId,
        bytes32 indexed predecessorRecoveryId,
        bytes32 indexed originalFinalityRecordHash,
        uint64 generation,
        bytes32 oldRouteHash,
        bytes32 recoveryRouteHash
    );
    event FinalityRecoveryEvidenceSnapshotted(
        uint16 schemaVersion,
        bytes32 indexed recoveryId,
        uint8 artistEvidenceKind,
        bytes32 artistEvidenceHash,
        address artistSigner,
        bytes32 artistId,
        uint8 artistAuthorityClass,
        uint64 artistNoticeEndsAt,
        bytes32 ownerEvidenceHash,
        uint64 ownerEvidenceRevision,
        uint64 ownerNoticeEndsAt,
        uint32 ownerAcknowledgementCount,
        uint32 ownerObjectionCount
    );

    error FinalityRecoveryActionConsumed(bytes32 recoveryId);
    error FinalityRecoveryExecutionContextMissing();
    error FinalityRecoveryGenerationOverflow(bytes32 scopeKey);
    error FinalityRecoveryPredecessorMismatch(bytes32 expected, bytes32 actual);
    error FinalityRecoveryOriginalRecordMismatch(bytes32 expected, bytes32 actual);
    error FinalityRecoveryOldRouteMismatch(bytes32 expected, bytes32 actual);
    error FinalityRecoveryRefreshPlanComplete(bytes32 recoveryId);
    error FinalityRecoveryRefreshPlanInactive(bytes32 recoveryId, bytes32 activeRecoveryId);
    error FinalityRecoveryRefreshPlanMismatch(bytes32 recoveryId);
    error FinalityRecoveryRefreshPlanMissing(bytes32 recoveryId);
    error FinalityRecoveryRefreshReentrancy();
    error IncompleteFinalityRecoveryRefreshPlans(uint256 count);
    error FinalityRecoveryTimestampOverflow(uint256 timestamp);
    error FinalityRecoveryCoreChanged(address core);

    struct Head {
        bytes32 recoveryId;
        bytes32 originalFinalityRecordHash;
        uint64 generation;
        StreamFinalityScope originalScope;
    }

    struct State {
        mapping(bytes32 => StreamFinalityRecoveryRecord) records;
        mapping(bytes32 => Head) heads;
        mapping(bytes32 => mapping(bytes32 => bytes32)) routeOverrides;
        mapping(bytes32 => StreamFinalityRecoveryRefreshPlan) plans;
        uint256 incompleteCount;
        bool refreshing;
    }

    struct Admission {
        bytes32 recoveryId;
        StreamFinalityScope originalScope;
        bytes32 selectedOldRouteHash;
        uint256 lastAllocatedTokenId;
    }

    function append(
        State storage self,
        StreamFinalityRecoveryRequest memory request,
        StreamFinalityRecoveryEvidenceSnapshot memory evidence,
        Admission memory admission
    ) public returns (bytes32 routeHash) {
        if (self.refreshing) revert FinalityRecoveryRefreshReentrancy();
        if (admission.recoveryId == 0) revert FinalityRecoveryExecutionContextMissing();
        if (self.records[admission.recoveryId].executed) {
            revert FinalityRecoveryActionConsumed(admission.recoveryId);
        }
        StreamFinalityRecoveryIntentState.shape(request.scope);
        StreamFinalityRecoveryIntentState.shape(admission.originalScope);
        bytes32 key = StreamFinalityRecoveryHashes.scopeKey(request.scope);
        Head storage head = self.heads[key];
        if (request.expectedPredecessorRecoveryId != head.recoveryId) {
            revert FinalityRecoveryPredecessorMismatch(
                request.expectedPredecessorRecoveryId, head.recoveryId
            );
        }
        if (
            request.expectedOriginalFinalityRecordHash == 0
                || admission.originalScope.collectionId != request.scope.collectionId
                || (admission.originalScope.scopeType != StreamFinalityScopeType.COLLECTION
                    && keccak256(abi.encode(admission.originalScope))
                        != keccak256(abi.encode(request.scope)))
                || (head.recoveryId != 0
                    && (head.originalFinalityRecordHash
                            != request.expectedOriginalFinalityRecordHash
                        || keccak256(abi.encode(head.originalScope))
                            != keccak256(abi.encode(admission.originalScope))))
        ) {
            revert FinalityRecoveryOriginalRecordMismatch(
                request.expectedOriginalFinalityRecordHash, head.originalFinalityRecordHash
            );
        }
        if (
            request.expectedOldRouteHash != admission.selectedOldRouteHash
                || admission.selectedOldRouteHash == 0
        ) {
            revert FinalityRecoveryOldRouteMismatch(
                request.expectedOldRouteHash, admission.selectedOldRouteHash
            );
        }
        if (head.generation == type(uint64).max) revert FinalityRecoveryGenerationOverflow(key);
        if (block.timestamp > type(uint64).max) {
            revert FinalityRecoveryTimestampOverflow(block.timestamp);
        }
        uint64 generation = head.generation + 1;
        StreamFinalityRecoveryHashes.Execution memory execution =
            StreamFinalityRecoveryHashes.Execution(
                admission.recoveryId,
                request.expectedOriginalFinalityRecordHash,
                head.recoveryId,
                generation
            );
        routeHash = StreamFinalityRecoveryHashes.recoveredRouteHash(
            StreamFinalityRecoveryHashes.Environment(block.chainid, address(this)),
            execution,
            request,
            evidence
        );
        _supersede(self, request.scope, head.recoveryId, admission.recoveryId);
        StreamFinalityRecoveryRecord storage record = self.records[admission.recoveryId];
        record.executed = true;
        record.recoveryId = admission.recoveryId;
        record.scope = request.scope;
        record.originalFinalityRecordHash = request.expectedOriginalFinalityRecordHash;
        record.predecessorRecoveryId = head.recoveryId;
        record.generation = generation;
        record.oldRouteHash = request.expectedOldRouteHash;
        record.recoveryRouteHash = routeHash;
        record.artworkBytesChanged = true;
        record.replacementRoute = request.replacementRoute;
        record.recoveryManifest = request.recoveryManifest;
        record.evidence = evidence;
        record.reasonHash = request.reasonHash;
        record.reasonURI = request.reasonURI;
        record.executedAt = uint64(block.timestamp);
        self.heads[key] = Head(
            admission.recoveryId,
            request.expectedOriginalFinalityRecordHash,
            generation,
            admission.originalScope
        );
        self.routeOverrides[key][request.replacementRoute.componentType] = admission.recoveryId;
        _emitExecution(record);
        _createPlan(self, record, admission.lastAllocatedTokenId);
    }

    /// @notice Emits exactly one range through Core; callback failure reverts cursor/count/events.
    /// @dev Caller must first validate that this owner remains the current selected companion.
    function continuePlan(
        State storage self,
        StreamFinalityScope memory scope,
        bytes32 recoveryId,
        address core,
        bytes32 coreCodeHash
    ) public {
        if (self.refreshing) revert FinalityRecoveryRefreshReentrancy();
        if (core.code.length == 0 || core.codehash != coreCodeHash) {
            revert FinalityRecoveryCoreChanged(core);
        }
        StreamFinalityRecoveryRefreshPlan storage plan = self.plans[recoveryId];
        if (!plan.exists) revert FinalityRecoveryRefreshPlanMissing(recoveryId);
        if (plan.complete) revert FinalityRecoveryRefreshPlanComplete(recoveryId);
        bytes32 active = self.heads[StreamFinalityRecoveryHashes.scopeKey(scope)].recoveryId;
        if (plan.superseded || active != recoveryId) {
            revert FinalityRecoveryRefreshPlanInactive(recoveryId, active);
        }
        StreamFinalityRecoveryRecord storage record = self.records[recoveryId];
        if (
            !record.executed || keccak256(abi.encode(record.scope)) != keccak256(abi.encode(scope))
                || plan.manifestContentHash != record.recoveryManifest.contentHash
        ) revert FinalityRecoveryRefreshPlanMismatch(recoveryId);
        uint256 from = plan.processedThrough == 0 ? plan.rangeStart : plan.processedThrough + 1;
        uint256 to = plan.rangeEnd - from > 4999 ? from + 4999 : plan.rangeEnd;
        self.refreshing = true;
        plan.processedThrough = to;
        ++plan.chunksEmitted;
        if (to == plan.rangeEnd) {
            plan.complete = true;
            --self.incompleteCount;
        }
        IStreamFinalityRecoveryCore(core)
            .emitBatchMetadataUpdate(from, to, plan.manifestContentHash);
        _emitProgress(record, plan, from, to);
        self.refreshing = false;
    }

    function assertComplete(State storage self) public view {
        if (self.incompleteCount != 0) {
            revert IncompleteFinalityRecoveryRefreshPlans(self.incompleteCount);
        }
    }

    function _createPlan(
        State storage self,
        StreamFinalityRecoveryRecord storage record,
        uint256 highWater
    ) private {
        StreamFinalityRecoveryRefreshPlan storage plan = self.plans[record.recoveryId];
        plan.exists = true;
        plan.manifestContentHash = record.recoveryManifest.contentHash;
        plan.lastAllocatedTokenIdAtExecution = highWater;
        if (record.scope.scopeType == StreamFinalityScopeType.TOKEN) {
            if (record.scope.tokenId > highWater) {
                revert FinalityRecoveryRefreshPlanMismatch(record.recoveryId);
            }
            plan.rangeStart = record.scope.tokenId;
            plan.rangeEnd = record.scope.tokenId;
        } else if (highWater != 0) {
            plan.rangeStart = 1;
            plan.rangeEnd = highWater;
        }
        plan.complete = plan.rangeEnd == 0;
        if (!plan.complete) ++self.incompleteCount;
        if (record.scope.scopeType == StreamFinalityScopeType.COLLECTION) {
            emit FinalityRecoveryRefreshPlanCreated(
                1,
                record.scope.collectionId,
                record.recoveryId,
                plan.manifestContentHash,
                highWater,
                plan.rangeStart,
                plan.rangeEnd,
                plan.complete
            );
        } else {
            emit ScopedFinalityRecoveryRefreshPlanCreated(
                1,
                uint8(record.scope.scopeType),
                record.scope.collectionId,
                record.recoveryId,
                record.scope.tokenId,
                record.scope.scopeId,
                plan.manifestContentHash,
                highWater,
                plan.rangeStart,
                plan.rangeEnd,
                plan.complete
            );
        }
    }

    function _supersede(
        State storage self,
        StreamFinalityScope memory scope,
        bytes32 oldId,
        bytes32 newId
    ) private {
        StreamFinalityRecoveryRefreshPlan storage plan = self.plans[oldId];
        if (!plan.exists || plan.complete || plan.superseded) return;
        plan.superseded = true;
        plan.supersededByRecoveryId = newId;
        --self.incompleteCount;
        if (scope.scopeType == StreamFinalityScopeType.COLLECTION) {
            emit FinalityRecoveryRefreshPlanSuperseded(
                1,
                scope.collectionId,
                oldId,
                newId,
                plan.manifestContentHash,
                plan.processedThrough,
                plan.rangeEnd
            );
        } else {
            emit ScopedFinalityRecoveryRefreshPlanSuperseded(
                1,
                uint8(scope.scopeType),
                scope.collectionId,
                oldId,
                scope.tokenId,
                scope.scopeId,
                newId,
                plan.manifestContentHash,
                plan.processedThrough,
                plan.rangeEnd
            );
        }
    }

    function _emitProgress(
        StreamFinalityRecoveryRecord storage record,
        StreamFinalityRecoveryRefreshPlan storage plan,
        uint256 from,
        uint256 to
    ) private {
        if (record.scope.scopeType == StreamFinalityScopeType.COLLECTION) {
            emit FinalityRecoveryRefreshProgress(
                1,
                record.scope.collectionId,
                record.recoveryId,
                plan.manifestContentHash,
                from,
                to,
                plan.processedThrough,
                plan.chunksEmitted,
                plan.complete
            );
        } else {
            emit ScopedFinalityRecoveryRefreshProgress(
                1,
                uint8(record.scope.scopeType),
                record.scope.collectionId,
                record.recoveryId,
                record.scope.tokenId,
                record.scope.scopeId,
                plan.manifestContentHash,
                from,
                to,
                plan.processedThrough,
                plan.chunksEmitted,
                plan.complete
            );
        }
    }

    function _emitExecution(StreamFinalityRecoveryRecord storage r) private {
        emit FinalityRecoveryLineageRecorded(
            1,
            r.recoveryId,
            r.predecessorRecoveryId,
            r.originalFinalityRecordHash,
            r.generation,
            r.oldRouteHash,
            r.recoveryRouteHash
        );
        StreamFinalityRecoveryEvidenceSnapshot memory e = r.evidence;
        emit FinalityRecoveryEvidenceSnapshotted(
            1,
            r.recoveryId,
            uint8(e.artistEvidenceKind),
            e.artistEvidenceHash,
            e.artistSigner,
            e.artistId,
            e.artistAuthorityClass,
            e.artistNoticeEndsAt,
            e.ownerEvidenceHash,
            e.ownerEvidenceRevision,
            e.ownerNoticeEndsAt,
            e.ownerAcknowledgementCount,
            e.ownerObjectionCount
        );
        if (r.scope.scopeType == StreamFinalityScopeType.COLLECTION) {
            emit FinalityRecoveryExecuted(
                1,
                r.scope.collectionId,
                r.recoveryId,
                r.recoveryManifest.contentHash,
                r.recoveryRouteHash,
                true,
                r.reasonHash,
                r.reasonURI
            );
        } else {
            emit ScopedFinalityRecoveryExecuted(
                1,
                uint8(r.scope.scopeType),
                r.scope.collectionId,
                r.recoveryId,
                r.scope.tokenId,
                r.scope.scopeId,
                r.recoveryManifest.contentHash,
                r.recoveryRouteHash,
                true,
                r.reasonHash,
                r.reasonURI
            );
        }
    }
}

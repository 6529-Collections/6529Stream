// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamRenderCriticalSourceTypes as S
} from "../../interfaces/stream/preservation/StreamRenderCriticalSourceTypes.sol";
import {
    StreamScopedRenderCriticalTypes as Scoped
} from "../../interfaces/stream/preservation/StreamScopedRenderCriticalTypes.sol";
import {
    StreamPreservationInventoryTypes as T
} from "../../interfaces/stream/preservation/StreamPreservationInventoryTypes.sol";
import {
    StreamScopedRenderCriticalSourceReads as Sources
} from "./StreamScopedRenderCriticalSourceReads.sol";
import {
    StreamPreservationInventoryChains as Chains
} from "./StreamPreservationInventoryChains.sol";

/// @dev One compiler-owned scoped host layout; no caller-selected storage root.
library StreamScopedRenderCriticalState {
    struct DocumentPin {
        bytes32 id;
        bytes32 factsHash;
    }

    struct State {
        S.Dependencies dependencies;
        bytes32 dependencyHash;
        mapping(bytes32 => Scoped.Context) contexts;
        mapping(bytes32 => Scoped.Plan) plans;
        mapping(bytes32 => mapping(uint64 => T.Segment)) segments;
        mapping(bytes32 => uint64) definitionCursor;
        mapping(bytes32 => DocumentPin[]) documents;
        mapping(bytes32 => Scoped.Evidence) completed;
        mapping(bytes32 => Scoped.TokenProgress) tokenProgress;
        mapping(bytes32 => DocumentPin[]) selectedDocuments;
        mapping(bytes32 => mapping(bytes32 => bytes32)) selectedDocumentFacts;
    }
    event ScopedInventorySegmentRecorded(
        uint16 schemaVersion,
        bytes32 indexed id,
        uint64 indexed index,
        T.Segment segment,
        T.Item[] items
    );

    function idFor(bytes32 dependencyHash, Scoped.Context memory c)
        internal
        view
        returns (bytes32)
    {
        return keccak256(
            abi.encode(
                keccak256("6529STREAM_SCOPED_RENDER_CRITICAL_PLAN_V1"),
                block.chainid,
                address(this),
                dependencyHash,
                c
            )
        );
    }

    function stage(State storage s, bytes32 id, uint16 expected) internal view {
        T.Plan storage p = s.plans[id].progress;
        if (
            p.collectionId == 0 || p.completedStages != expected
                || p.renderCriticalEvidenceHash != 0
        ) {
            revert T.InventoryIncomplete();
        }
        requireCurrent(s, id);
    }

    function requireCurrent(State storage s, bytes32 id) internal view {
        Scoped.Context memory current = Sources.current(s.dependencies, s.plans[id].scope);
        if (idFor(s.dependencyHash, current) != id) revert T.InventorySourceChanged();
    }

    function append(State storage s, bytes32 id, T.Item[] memory rows, bytes32 witness) internal {
        T.Plan storage p = s.plans[id].progress;
        uint64 index = p.segmentCount;
        bytes32 key = keccak256(
            abi.encode(keccak256("6529STREAM_SCOPED_RENDER_CRITICAL_SEGMENT_V1"), id, index)
        );
        T.Segment memory segment = Chains.segmentInMemory(key, witness, rows);
        s.segments[id][index] = segment;
        p.segmentChainHash = Chains.append(p.segmentChainHash, index, segment);
        p.segmentCount = index + 1;
        p.itemCount += segment.itemCount;
        emit ScopedInventorySegmentRecorded(1, id, index, segment, rows);
    }

    /// @dev Only the two generic record coordinates consumed by OriginalReads. Scoped
    /// snapshot/reference receipts are deliberately never cast to COLLECTION receipts.
    function originalRecordContext(Scoped.Context memory c)
        internal
        pure
        returns (S.Context memory old)
    {
        old.collectionId = c.scope.collectionId;
        old.subject = c.subject;
    }
}

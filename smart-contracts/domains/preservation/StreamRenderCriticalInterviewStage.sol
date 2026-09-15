// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    StreamRenderCriticalSourceTypes as S
} from "../../interfaces/stream/preservation/StreamRenderCriticalSourceTypes.sol";
import {
    StreamPreservationInventoryTypes as T
} from "../../interfaces/stream/preservation/StreamPreservationInventoryTypes.sol";
import { StreamPreservationInventoryIO as IO } from "./StreamPreservationInventoryIO.sol";
import { StreamPreservationInventoryItems as Items } from "./StreamPreservationInventoryItems.sol";
import {
    StreamPreservationInventoryChains as Chains
} from "./StreamPreservationInventoryChains.sol";
import {
    StreamPreservationTypedReferences as References
} from "./StreamPreservationTypedReferences.sol";
import {
    StreamPreservationDocumentReads as Documents
} from "./StreamPreservationDocumentReads.sol";
import {
    StreamPreservationOriginalReads as Originals
} from "./StreamPreservationOriginalReads.sol";
import {
    StreamPreservationArtistBundleReads as ArtistBundles
} from "./StreamPreservationArtistBundleReads.sol";
import { StreamRenderCriticalSourceReads as Sources } from "./StreamRenderCriticalSourceReads.sol";
import { StreamReferenceInventoryReads as Reference } from "./StreamReferenceInventoryReads.sol";
import "../../interfaces/stream/preservation/IStreamRenderCriticalInventory.sol";
import "../../interfaces/stream/metadata/IStreamWorkRecordSelection.sol";
import "../../interfaces/stream/metadata/StreamRightsRecordTypes.sol";
import "../../interfaces/stream/metadata/IStreamConservationRecordSelection.sol";
import "../../interfaces/stream/finality/IStreamOnchainContentCheckpoint.sol";
import "../../interfaces/stream/preservation/IStreamReferenceRenderPublication.sol";

import {
    StreamRenderCriticalInventoryState as State
} from "./StreamRenderCriticalInventoryState.sol";

/// @notice Typed stages using the actual host storage reference.
library StreamRenderCriticalInterviewStage {
    event InventorySegmentRecorded(
        bytes32 indexed planId, uint64 indexed index, T.Segment segment, T.Item[] items
    );

    function appendInterview(State.State storage state, bytes calldata input) public {
        (
            bytes32 id,
            StreamConservationRecordTypes.Interview memory witness,
            address originalActor
        ) = abi.decode(input[4:], (bytes32, StreamConservationRecordTypes.Interview, address));
        _stage(state, id, 5);
        S.Context memory c = state.contexts[id];
        if (c.conservation.interviewStatus != StreamConservationRecordTypes.InterviewStatus.PRESENT)
        {
            revert T.InvalidInventoryItem();
        }
        T.Item[] memory refs = References.interview(
            state.dependencies.targets[1],
            c.conservation.interview.recordHash,
            c.conservation.interview.payloadHash,
            witness
        );
        Documents.authenticateCatalogs(state.dependencies, refs);
        T.Item[] memory originals = Originals.items(
            state.dependencies,
            c,
            c.conservation.interview.recordHash,
            c.conservation.interview.payloadHash
        );
        originals = _with(
            originals,
            ArtistBundles.item(
                state.dependencies,
                c.conservation.interview.publication,
                c.conservation.interview.recordHash,
                originalActor
            )
        );
        _append(state, id, _join(originals, refs), c.interviewEvidenceHash);
        state.plans[id].completedStages = 6;
    }

    function _stage(State.State storage state, bytes32 id, uint16 stage) private view {
        T.Plan storage p = state.plans[id];
        if (p.collectionId == 0 || p.completedStages != stage || p.renderCriticalEvidenceHash != 0) revert T.InventoryIncomplete();
        Sources.bindings(state.dependencies);
    }

    function _append(
        State.State storage state,
        bytes32 id,
        T.Item[] memory rows,
        bytes32 witnessHash
    ) private {
        T.Plan storage p = state.plans[id];
        uint64 index = p.segmentCount;
        bytes32 key =
            keccak256(abi.encode(keccak256("6529STREAM_RENDER_CRITICAL_SEGMENT_V1"), id, index));
        T.Segment memory segment = Chains.segment(key, witnessHash, rows);
        state.segments[id][index] = segment;
        p.segmentChainHash = Chains.append(p.segmentChainHash, index, segment);
        p.segmentCount = index + 1;
        p.itemCount += segment.itemCount;
        emit InventorySegmentRecorded(id, index, segment, rows);
    }

    function _with(T.Item[] memory a, T.Item memory item)
        private
        pure
        returns (T.Item[] memory result)
    {
        result = new T.Item[](a.length + 1);
        for (uint256 i; i < a.length; ++i) {
            result[i] = a[i];
        }
        result[a.length] = item;
    }

    function _join(T.Item[] memory a, T.Item[] memory b)
        private
        pure
        returns (T.Item[] memory result)
    {
        result = new T.Item[](a.length + b.length);
        for (uint256 i; i < a.length; ++i) {
            result[i] = a[i];
        }
        for (uint256 i; i < b.length; ++i) {
            result[a.length + i] = b[i];
        }
    }

    function appendInterviewWaiver(State.State storage state, bytes32 id) public {
        _stage(state, id, 5);
        S.Context memory c = state.contexts[id];
        if (
            c.conservation.interviewStatus != StreamConservationRecordTypes.InterviewStatus.WAIVED
                || c.conservation.interview.recordHash != 0
        ) revert T.InvalidInventoryItem();
        T.Item[] memory rows = new T.Item[](1);
        rows[0] = Items.absent(
            keccak256("INTERVIEW_ORIGINAL_EXPLICITLY_WAIVED"),
            state.dependencies.targets[1],
            c.conservation.record.recordHash,
            0
        );
        rows[0].provenanceHash = c.interviewEvidenceHash;
        _append(state, id, rows, c.interviewEvidenceHash);
        state.plans[id].completedStages = 6;
    }
}

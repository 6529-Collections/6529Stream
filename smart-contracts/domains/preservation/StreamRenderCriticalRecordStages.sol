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
library StreamRenderCriticalRecordStages {
    event InventorySegmentRecorded(
        bytes32 indexed planId, uint64 indexed index, T.Segment segment, T.Item[] items
    );

    function appendIntent(State.State storage state, bytes calldata input) public {
        (bytes32 id, StreamConservationRecordTypes.Intent memory witness, address originalActor) =
            abi.decode(input[4:], (bytes32, StreamConservationRecordTypes.Intent, address));
        _stage(state, id, 4);
        S.Context memory c = state.contexts[id];
        if (c.conservation.record.kind != IStreamConservationRecordSelection.RecordKind.INTENT) {
            revert T.InvalidInventoryItem();
        }
        _parent(
            state,
            id,
            References.intent(
                state.dependencies.targets[1],
                c.conservation.record.recordHash,
                c.conservation.record.payloadHash,
                witness
            ),
            originalActor
        );
    }

    function appendIntentWaiver(State.State storage state, bytes calldata input) public {
        (
            bytes32 id,
            StreamConservationRecordTypes.IntentWaiver memory witness,
            address originalActor
        ) = abi.decode(input[4:], (bytes32, StreamConservationRecordTypes.IntentWaiver, address));
        _stage(state, id, 4);
        S.Context memory c = state.contexts[id];
        if (
            c.conservation.record.kind
                != IStreamConservationRecordSelection.RecordKind.INTENT_WAIVER
        ) revert T.InvalidInventoryItem();
        _parent(
            state,
            id,
            References.waiver(
                state.dependencies.targets[1],
                c.conservation.record.recordHash,
                c.conservation.record.payloadHash,
                witness
            ),
            originalActor
        );
    }

    function _parent(State.State storage state, bytes32 id, T.Item[] memory refs, address actor)
        private
    {
        S.Context memory c = state.contexts[id];
        T.Item[] memory originals = Originals.items(
            state.dependencies,
            c,
            c.conservation.record.recordHash,
            c.conservation.record.payloadHash
        );
        originals = _with(
            originals,
            ArtistBundles.item(
                state.dependencies,
                c.conservation.record.publication,
                c.conservation.record.recordHash,
                actor
            )
        );
        _append(state, id, _join(originals, refs), c.conservation.selectionHash);
        state.plans[id].completedStages = 5;
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
}

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

/// @notice Complete fixed definition admission and current facts checks.
library StreamRenderCriticalDefinitionStages {
    event InventorySegmentRecorded(
        bytes32 indexed planId, uint64 indexed index, T.Segment segment, T.Item[] items
    );

    function appendDefinition(State.State storage state, bytes32 id) public {
        _stage(state, id, 7);
        uint64 index = state.definitionCursor[id];
        bytes32 documentId;
        bytes32 expectedHash;
        if (index < Documents.FIXED_COUNT) {
            documentId = Documents.fixedId(index);
            expectedHash = Documents.fixedHash(index);
        } else {
            if (index != Documents.FIXED_COUNT) revert T.InvalidInventoryItem();
            bytes memory raw = IO.fixedRead(
                state.dependencies.targets[6],
                abi.encodeCall(IStreamReferenceRenderPublication.dependencies, ()),
                704,
                state.dependencies.readGas
            );
            StreamReferenceRenderTypes.Dependencies memory rd =
                abi.decode(raw, (StreamReferenceRenderTypes.Dependencies));
            IO.canonical(state.dependencies.targets[6], raw, abi.encode(rd));
            documentId = rd.rendererCatalogId;
            expectedHash = rd.rendererCatalogHash;
        }
        T.Item[] memory rows = new T.Item[](1);
        rows[0] = Documents.item(state.dependencies, documentId, expectedHash);
        state.documents[id].push(State.DocumentPin(documentId, rows[0].provenanceHash));
        _append(state, id, rows, keccak256(abi.encode(documentId, rows[0])));
        state.definitionCursor[id] = index + 1;
        if (index == Documents.FIXED_COUNT) state.plans[id].completedStages = 8;
    }

    function requireDefinitions(State.State storage state, bytes32 id, bool full) public view {
        if (state.documents[id].length != Documents.FIXED_COUNT + 1) {
            revert T.InventoryIncomplete();
        }
        for (uint256 i; i < state.documents[id].length; ++i) {
            State.DocumentPin storage p = state.documents[id][i];
            bytes32 actual = full
                ? Documents.item(state.dependencies, p.id, 0).provenanceHash
                : Documents.currentFactsHash(state.dependencies, p.id);
            if (actual != p.factsHash) revert T.InventorySourceChanged();
        }
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
}

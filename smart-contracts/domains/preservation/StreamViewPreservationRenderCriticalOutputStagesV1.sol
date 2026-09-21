// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamViewPreservationRenderCriticalStateV1 as State
} from "./StreamViewPreservationRenderCriticalStateV1.sol";
import {
    StreamViewPreservationRenderCriticalTypesV1 as View
} from "../../interfaces/stream/preservation/StreamViewPreservationRenderCriticalTypesV1.sol";
import {
    StreamPreservationInventoryTypes as T
} from "../../interfaces/stream/preservation/StreamPreservationInventoryTypes.sol";
import {
    StreamViewPreservationRenderCriticalArtworkReadsV1 as Artwork
} from "./StreamViewPreservationRenderCriticalArtworkReadsV1.sol";
import {
    StreamViewPreservationRenderCriticalRendererReadsV1 as Renderer
} from "./StreamViewPreservationRenderCriticalRendererReadsV1.sol";
import {
    StreamViewPreservationRenderCriticalAdmissionReadsV1 as Admission
} from "./StreamViewPreservationRenderCriticalAdmissionReadsV1.sol";
import {
    StreamViewPreservationRenderCriticalTokenReadsV1 as Tokens
} from "./StreamViewPreservationRenderCriticalTokenReadsV1.sol";

/// @notice Mandatory shared VIEW closure followed by every complete ordered token output.
library StreamViewPreservationRenderCriticalOutputStagesV1 {
    function appendArtwork(State.State storage s, bytes32 id) public {
        State.stage(s, id, 8);
        T.Item[] memory rows = Artwork.items(s.dependencies, s.contexts[id]);
        State.append(s, id, rows, _witness(s, id, 8, 0, uint64(rows.length)));
        s.plans[id].progress.completedStages = 9;
    }

    function appendRenderer(State.State storage s, bytes32 id) public {
        State.stage(s, id, 9);
        View.TokenProgress storage p = s.tokenProgress[id];
        (T.Item memory row, uint64 count) = Renderer.item(s.dependencies, s.contexts[id], p.row);
        _row(s, id, row, count, 9);
    }

    function appendAdmission(State.State storage s, bytes32 id) public {
        State.stage(s, id, 10);
        View.TokenProgress storage p = s.tokenProgress[id];
        (T.Item memory row, uint64 count) = Admission.item(s.dependencies, s.contexts[id], p.row);
        _row(s, id, row, count, 10);
    }

    function appendToken(State.State storage s, bytes32 id) public {
        State.stage(s, id, 11);
        T.Plan storage p = s.plans[id].progress;
        uint64 index = p.nextToken;
        if (index >= p.tokenCount) revert T.InventoryIncomplete();
        T.Item[] memory rows = Tokens.items(s.dependencies, s.contexts[id], index);
        State.append(s, id, rows, _witness(s, id, 11, index, uint64(rows.length)));
        p.nextToken = index + 1;
    }

    function _row(State.State storage s, bytes32 id, T.Item memory item, uint64 count, uint16 stage)
        private
    {
        View.TokenProgress storage p = s.tokenProgress[id];
        if (count == 0 || p.row >= count || (p.row != 0 && p.count != count)) {
            revert T.InventorySourceChanged();
        }
        if (item.kind == T.Kind.REGISTERED_DOCUMENT) {
            if (item.catalogId == 0 || item.provenanceHash == 0) revert T.InventorySourceChanged();
            bytes32 prior = s.selectedDocumentFacts[id][item.catalogId];
            if (prior == 0) {
                s.selectedDocumentFacts[id][item.catalogId] = item.provenanceHash;
                s.selectedDocuments[id].push(State.DocumentPin(item.catalogId, item.provenanceHash));
            } else if (prior != item.provenanceHash) {
                revert T.InventorySourceChanged();
            }
        }
        T.Item[] memory rows = new T.Item[](1);
        rows[0] = item;
        State.append(s, id, rows, _witness(s, id, stage, p.row, count));
        p.count = count;
        p.row += 1;
        if (p.row == count) {
            p.row = 0;
            p.count = 0;
            s.plans[id].progress.completedStages = stage + 1;
        }
    }

    function _witness(State.State storage s, bytes32 id, uint16 stage, uint64 index, uint64 count)
        private
        view
        returns (bytes32)
    {
        return keccak256(
            abi.encode(
                keccak256("6529STREAM_VIEW_PRESERVATION_OUTPUT_INVENTORY_SOURCE_V1"),
                s.contexts[id].adoptionRecord,
                s.contexts[id].checkpointHash,
                s.contexts[id].sourceContextHash,
                stage,
                index,
                count
            )
        );
    }
}

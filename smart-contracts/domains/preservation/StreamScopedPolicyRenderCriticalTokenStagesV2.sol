// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamScopedPolicyRenderCriticalStateV2 as State
} from "./StreamScopedPolicyRenderCriticalStateV2.sol";
import {
    StreamScopedPolicyRenderCriticalTypesV2 as Scoped
} from "../../interfaces/stream/preservation/StreamScopedPolicyRenderCriticalTypesV2.sol";
import {
    StreamPreservationInventoryTypes as T
} from "../../interfaces/stream/preservation/StreamPreservationInventoryTypes.sol";
import {
    IStreamScopedPolicyContentCheckpointV2 as Content
} from "../../interfaces/stream/finality/IStreamScopedPolicyContentCheckpointV2.sol";
import {
    StreamScopedPolicyRenderCriticalTokenReadsV2 as Tokens
} from "./StreamScopedPolicyRenderCriticalTokenReadsV2.sol";
import {
    StreamScopedPolicyRenderCriticalScriptReadsV2 as Scripts
} from "./StreamScopedPolicyRenderCriticalScriptReadsV2.sol";
import {
    StreamScopedPolicyRenderCriticalRendererReadsV2 as Renderers
} from "./StreamScopedPolicyRenderCriticalRendererReadsV2.sol";
import {
    StreamScopedPolicyRenderCriticalCitationReadsV2 as Citations
} from "./StreamScopedPolicyRenderCriticalCitationReadsV2.sol";

/// @notice Fixed ordered per-token closure; no caller chooses the next ordinal or expected total.
library StreamScopedPolicyRenderCriticalTokenStagesV2 {
    function appendOutput(State.State storage s, bytes32 id, Content.Payload memory payload)
        public
    {
        uint64 ordinal = _stage(s, id, 0);
        T.Item[] memory rows = Tokens.tokenItems(s.dependencies, s.contexts[id], ordinal, payload);
        State.append(s, id, rows, _witness(s, id, ordinal, 0, 0, uint64(rows.length)));
        s.tokenProgress[id].phase = 1;
    }

    function appendScript(State.State storage s, bytes32 id, bool libraryOnly) public {
        uint8 phase = libraryOnly ? 2 : 1;
        uint64 ordinal = _stage(s, id, phase);
        T.Item[] memory rows = Scripts.items(s.dependencies, s.contexts[id], ordinal, libraryOnly);
        State.append(s, id, rows, _witness(s, id, ordinal, phase, 0, uint64(rows.length)));
        s.tokenProgress[id].phase = phase + 1;
    }

    function appendRenderer(State.State storage s, bytes32 id) public {
        uint64 ordinal = _stage(s, id, 3);
        Scoped.TokenProgress storage p = s.tokenProgress[id];
        (T.Item memory row, uint64 count) =
            Renderers.item(s.dependencies, s.contexts[id], ordinal, p.row);
        _row(s, id, ordinal, row, count);
    }

    function appendCitation(State.State storage s, bytes32 id) public {
        uint64 ordinal = _stage(s, id, 4);
        Scoped.TokenProgress storage p = s.tokenProgress[id];
        (T.Item memory row, uint64 count) =
            Citations.item(s.dependencies, s.contexts[id], ordinal, p.row);
        _row(s, id, ordinal, row, count);
    }

    function _stage(State.State storage s, bytes32 id, uint8 phase)
        private
        view
        returns (uint64 ordinal)
    {
        State.stage(s, id, 8);
        ordinal = s.plans[id].progress.nextToken;
        if (ordinal >= s.plans[id].progress.tokenCount || s.tokenProgress[id].phase != phase) {
            revert T.InventoryIncomplete();
        }
    }

    function _row(
        State.State storage s,
        bytes32 id,
        uint64 ordinal,
        T.Item memory item,
        uint64 count
    ) private {
        Scoped.TokenProgress storage p = s.tokenProgress[id];
        if (count == 0 || p.row >= count || (p.row != 0 && p.count != count)) {
            revert T.InventorySourceChanged();
        }
        T.Item[] memory rows = new T.Item[](1);
        rows[0] = item;
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
        State.append(s, id, rows, _witness(s, id, ordinal, p.phase, p.row, count));
        p.count = count;
        p.row += 1;
        if (p.row == count) {
            p.row = 0;
            p.count = 0;
            if (p.phase == 4) {
                p.phase = 0;
                s.plans[id].progress.nextToken = ordinal + 1;
            } else {
                p.phase += 1;
            }
        }
    }

    function _witness(
        State.State storage s,
        bytes32 id,
        uint64 ordinal,
        uint8 phase,
        uint64 row,
        uint64 count
    ) private view returns (bytes32) {
        return keccak256(
            abi.encode(
                keccak256("6529STREAM_SCOPED_POLICY_TOKEN_INVENTORY_SOURCE_V2"),
                s.contexts[id].checkpointHash,
                s.contexts[id].selectionHash,
                ordinal,
                phase,
                row,
                count
            )
        );
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamPreservationPolicyRenderCriticalStateV1 as State
} from "./StreamPreservationPolicyRenderCriticalStateV1.sol";
import {
    StreamPreservationInventoryTypes as T
} from "../../interfaces/stream/preservation/StreamPreservationInventoryTypes.sol";
import {
    StreamPreservationPolicyRenderCriticalTokenReadsV1 as Tokens
} from "./StreamPreservationPolicyRenderCriticalTokenReadsV1.sol";
import {
    StreamPreservationPolicyRenderCriticalScriptReadsV1 as Scripts
} from "./StreamPreservationPolicyRenderCriticalScriptReadsV1.sol";
import {
    StreamPreservationPolicyRenderCriticalRendererReadsV1 as Renderers
} from "./StreamPreservationPolicyRenderCriticalRendererReadsV1.sol";
import {
    StreamPreservationPolicyRenderCriticalProfileReadsV1 as Profiles
} from "./StreamPreservationPolicyRenderCriticalProfileReadsV1.sol";
import {
    IStreamPreservationPolicyContentCheckpointV1 as Content
} from "../../interfaces/stream/finality/IStreamPreservationPolicyContentCheckpointV1.sol";

import {
    StreamPreservationPolicyAdmissionInventoryV1 as Preservation
} from "./StreamPreservationPolicyAdmissionInventoryV1.sol";

library StreamPreservationPolicyRenderCriticalTokenStagesV1 {
    function appendOutput(State.State storage s, bytes32 id, Content.Payload memory payload)
        public
    {
        _stage(s, id, 0);
        uint64 ordinal = s.records.plans[id].nextToken;
        State.append(
            s,
            id,
            Tokens.tokenItems(s.records.dependencies, s.contexts[id], ordinal, payload),
            _witness(s, id, ordinal, 0, 0, 0)
        );
        s.progress[id].phase = 1;
    }

    function appendScript(State.State storage s, bytes32 id, bool libraryOnly) public {
        uint8 phase = libraryOnly ? 2 : 1;
        _stage(s, id, phase);
        uint64 ordinal = s.records.plans[id].nextToken;
        T.Item[] memory rows =
            Scripts.items(s.records.dependencies, s.contexts[id], ordinal, libraryOnly);
        State.append(s, id, rows, _witness(s, id, ordinal, phase, 0, 0));
        s.progress[id].phase = phase + 1;
    }

    function appendRenderer(State.State storage s, bytes32 id) public {
        _stage(s, id, 3);
        (T.Item memory row, uint64 count) = Renderers.item(
            s.records.dependencies,
            s.contexts[id],
            s.records.plans[id].nextToken,
            s.progress[id].row
        );
        _row(s, id, row, count);
    }

    function appendProfile(State.State storage s, bytes32 id) public {
        _stage(s, id, 4);
        (T.Item memory row, uint64 count) = Profiles.item(
            s.records.dependencies,
            s.contexts[id],
            s.records.plans[id].nextToken,
            s.progress[id].row
        );
        _row(s, id, row, count);
    }

    function appendPreservation(State.State storage s, bytes32 id) public {
        _stage(s, id, 5);
        (, Tokens.Original memory o) =
            Tokens.sourceAt(s.records.dependencies, s.contexts[id], s.records.plans[id].nextToken);
        (T.Item memory row, uint64 count) =
            Preservation.item(s.records.dependencies, o.selection, o.output, s.progress[id].row);
        _row(s, id, row, count);
    }

    function _row(State.State storage s, bytes32 id, T.Item memory row, uint64 count) private {
        State.Progress storage progress = s.progress[id];
        if (count == 0 || progress.row >= count || (progress.row != 0 && progress.count != count)) {
            revert T.InventorySourceChanged();
        }
        progress.count = count;
        T.Item[] memory rows = new T.Item[](1);
        rows[0] = row;
        State.append(
            s,
            id,
            rows,
            _witness(s, id, s.records.plans[id].nextToken, progress.phase, progress.row, count)
        );
        if (++progress.row == count) {
            progress.row = 0;
            progress.count = 0;
            if (progress.phase == 5) {
                progress.phase = 0;
                ++s.records.plans[id].nextToken;
            } else {
                ++progress.phase;
            }
        }
    }

    function _stage(State.State storage s, bytes32 id, uint8 phase) private view {
        State.stage(s, id, 8);
        if (
            s.progress[id].phase != phase
                || s.records.plans[id].nextToken >= s.records.plans[id].tokenCount
        ) revert T.InventoryIncomplete();
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
                keccak256("6529STREAM_PRESERVATION_POLICY_TOKEN_STAGE_V1"),
                s.contexts[id].records.checkpointHash,
                s.contexts[id].source.content.selectionHash,
                ordinal,
                phase,
                row,
                count
            )
        );
    }
}

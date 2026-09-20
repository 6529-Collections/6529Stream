// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamPolicyRenderCriticalStateV2 as State
} from "./StreamPolicyRenderCriticalStateV2.sol";
import {
    StreamPreservationInventoryTypes as T
} from "../../interfaces/stream/preservation/StreamPreservationInventoryTypes.sol";
import {
    StreamPolicyRenderCriticalTokenReadsV2 as Tokens
} from "./StreamPolicyRenderCriticalTokenReadsV2.sol";
import {
    StreamPolicyRenderCriticalScriptReadsV2 as Scripts
} from "./StreamPolicyRenderCriticalScriptReadsV2.sol";
import {
    StreamPolicyRenderCriticalRendererReadsV2 as Renderers
} from "./StreamPolicyRenderCriticalRendererReadsV2.sol";
import {
    StreamPolicyRenderCriticalProfileReadsV2 as Profiles
} from "./StreamPolicyRenderCriticalProfileReadsV2.sol";
import {
    IStreamPolicyContentCheckpointV2 as Content
} from "../../interfaces/stream/finality/IStreamPolicyContentCheckpointV2.sol";

library StreamPolicyRenderCriticalTokenStagesV2 {
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
            if (progress.phase == 4) {
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
                keccak256("6529STREAM_POLICY_TOKEN_STAGE_V2"),
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

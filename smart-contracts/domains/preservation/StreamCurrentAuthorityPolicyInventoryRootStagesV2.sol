// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamCurrentAuthorityInventoryTypes as D
} from "../../interfaces/stream/preservation/StreamCurrentAuthorityInventoryTypes.sol";
import {
    StreamCurrentAuthorityInventorySelection as Authority
} from "./StreamCurrentAuthorityInventorySelection.sol";
import {
    StreamArtistArchiveOriginTypes as O
} from "../../interfaces/stream/preservation/StreamArtistArchiveOriginTypes.sol";
import { StreamMultiOriginInventoryState as Origins } from "./StreamMultiOriginInventoryState.sol";
import {
    StreamRenderCriticalSourceTypes as S
} from "../../interfaces/stream/preservation/StreamRenderCriticalSourceTypes.sol";
import {
    StreamPreservationInventoryTypes as T
} from "../../interfaces/stream/preservation/StreamPreservationInventoryTypes.sol";
import {
    StreamPolicyRenderCriticalStateV2 as State
} from "./StreamPolicyRenderCriticalStateV2.sol";
import {
    StreamCurrentAuthorityPolicyInventoryGuardV2 as Guard
} from "./StreamCurrentAuthorityPolicyInventoryGuardV2.sol";
import { StreamMultiOriginRootCalls as RootCalls } from "./StreamMultiOriginRootCalls.sol";
import {
    IStreamScopedContentRootPublication as Aggregate
} from "../../interfaces/stream/metadata/IStreamScopedContentRootPublication.sol";

/// @dev Fixed linked worker; storage references and delegate context belong to the inventory host.
library StreamCurrentAuthorityPolicyInventoryRootStagesV2 {
    function appendRootAuthorization(
        mapping(bytes32 => State.State) storage _states,
        Origins.State storage _origins,
        mapping(bytes32 => Authority.State) storage _authorities,
        bytes32 id,
        address actor,
        uint64 observedAt,
        Aggregate.Aggregate calldata originalAggregate,
        O.ReceiptWitness calldata receipt
    ) public {
        Guard.requireCurrent(_states[id], _origins, _authorities[id], id);
        State.stage(_states[id], id, 6);
        T.Item[] memory rows = new T.Item[](1);
        O.RecordOrigin memory original;
        (rows[0], original) = RootCalls.policyContentItem(
            _states[id].records.dependencies,
            _origins.dependencies,
            _states[id].contexts[id],
            actor,
            observedAt,
            originalAggregate,
            _states[id].records.plans[id].sourceContextHash,
            receipt
        );
        Origins.remember(
            _origins,
            id,
            _states[id].records.plans[id].sourceContextHash,
            rows[0],
            original,
            bytes32(0),
            actor,
            keccak256("ORIGINAL_POLICY_CONTENT_ROOT_AUTHORIZATION_V2")
        );
        State.append(_states[id], id, rows, _states[id].contexts[id].records.rootRecordHash);
        _states[id].records.plans[id].completedStages = 7;
    }

    function appendOriginRuntime(
        mapping(bytes32 => State.State) storage _states,
        Origins.State storage _origins,
        mapping(bytes32 => Authority.State) storage _authorities,
        bytes32 id
    ) public {
        State.stage(_states[id], id, 8);
        Guard.requireCurrent(_states[id], _origins, _authorities[id], id);
        T.Plan storage p = _states[id].records.plans[id];
        State.Progress storage token = _states[id].progress[id];
        if (p.nextToken != p.tokenCount || token.phase != 0 || token.row != 0 || token.count != 0) {
            revert T.InventoryIncomplete();
        }
        (T.Item[] memory rows, bytes32 witness) = Origins.runtimeItems(_origins, id);
        State.append(_states[id], id, rows, witness);
    }
}

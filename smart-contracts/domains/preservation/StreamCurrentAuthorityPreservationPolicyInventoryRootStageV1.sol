// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    StreamCurrentAuthorityInventorySelection as Authority
} from "./StreamCurrentAuthorityInventorySelection.sol";

import {
    StreamArtistArchiveOriginTypes as O
} from "../../interfaces/stream/preservation/StreamArtistArchiveOriginTypes.sol";
import { StreamMultiOriginInventoryState as Origins } from "./StreamMultiOriginInventoryState.sol";
import {
    StreamCurrentAuthorityPreservationPolicyInventoryGuardV1 as Guard
} from "./StreamCurrentAuthorityPreservationPolicyInventoryGuardV1.sol";

import {
    StreamMultiOriginPreservationPolicyRootAuthorizationV1 as RootCalls
} from "./StreamMultiOriginPreservationPolicyRootAuthorizationV1.sol";

import {
    StreamPreservationInventoryTypes as T
} from "../../interfaces/stream/preservation/StreamPreservationInventoryTypes.sol";
import "../../interfaces/stream/preservation/IStreamPreservationPolicyRenderCriticalInventoryV1.sol";

import {
    IStreamScopedContentRootPublication as Aggregate
} from "../../interfaces/stream/metadata/IStreamScopedContentRootPublication.sol";

import "../../interfaces/stream/metadata/IStreamWorkRecordSelection.sol";
import "../../interfaces/stream/metadata/StreamRightsRecordTypes.sol";
import "../../interfaces/stream/metadata/IStreamConservationRecordSelection.sol";
import "../../interfaces/stream/finality/IStreamOnchainContentCheckpoint.sol";
import "../../interfaces/stream/preservation/IStreamReferenceRenderPublication.sol";

import {
    StreamPreservationPolicyRenderCriticalStateV1 as State
} from "./StreamPreservationPolicyRenderCriticalStateV1.sol";

/// @notice Fixed linked operations retain the original host storage and domains.
library StreamCurrentAuthorityPreservationPolicyInventoryRootStageV1 {
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
        (rows[0], original) = RootCalls.contentItem(
            _states[id].records.dependencies,
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
            keccak256("ORIGINAL_PRESERVATION_POLICY_CONTENT_ROOT_AUTHORIZATION_V1")
        );
        State.append(_states[id], id, rows, _states[id].contexts[id].records.rootRecordHash);
        _states[id].records.plans[id].completedStages = 7;
    }
}

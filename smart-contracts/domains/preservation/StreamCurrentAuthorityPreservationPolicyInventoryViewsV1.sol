// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    StreamCurrentAuthorityPreservationPolicyRenderCriticalSourceReadsV1 as OriginSources
} from "./StreamCurrentAuthorityPreservationPolicyRenderCriticalSourceReadsV1.sol";
import {
    StreamCurrentAuthorityInventoryTypes as D
} from "../../interfaces/stream/preservation/StreamCurrentAuthorityInventoryTypes.sol";

import {
    StreamCurrentAuthorityInventorySelection as Authority
} from "./StreamCurrentAuthorityInventorySelection.sol";

import { StreamMultiOriginInventoryState as Origins } from "./StreamMultiOriginInventoryState.sol";
import {
    StreamCurrentAuthorityPreservationPolicyInventoryGuardV1 as Guard
} from "./StreamCurrentAuthorityPreservationPolicyInventoryGuardV1.sol";

import {
    StreamPreservationInventoryTypes as T
} from "../../interfaces/stream/preservation/StreamPreservationInventoryTypes.sol";
import "../../interfaces/stream/preservation/IStreamPreservationPolicyRenderCriticalInventoryV1.sol";

import {
    StreamPreservationPolicyRenderCriticalTypesV1 as C
} from "../../interfaces/stream/preservation/StreamPreservationPolicyRenderCriticalTypesV1.sol";

import "../../interfaces/stream/metadata/IStreamWorkRecordSelection.sol";
import "../../interfaces/stream/metadata/StreamRightsRecordTypes.sol";
import "../../interfaces/stream/metadata/IStreamConservationRecordSelection.sol";
import "../../interfaces/stream/finality/IStreamOnchainContentCheckpoint.sol";
import "../../interfaces/stream/preservation/IStreamReferenceRenderPublication.sol";

import {
    StreamPreservationPolicyRenderCriticalStateV1 as State
} from "./StreamPreservationPolicyRenderCriticalStateV1.sol";
import {
    StreamPreservationPolicyRenderCriticalDefinitionStagesV1
} from "./StreamPreservationPolicyRenderCriticalDefinitionStagesV1.sol";

/// @notice Fixed linked operations retain the original host storage and domains.
library StreamCurrentAuthorityPreservationPolicyInventoryViewsV1 {
    function requireCurrent(
        mapping(bytes32 => State.State) storage _states,
        mapping(bytes32 => Authority.State) storage _authorities,
        Authority.Config storage _config,
        bytes32 _dependencyHash,
        Origins.State storage _origins,
        uint256 collectionId
    ) public view returns (bytes memory) {
        T.Evidence memory result;
        D.Capture memory captured = Authority.resolve(_config);
        (C.Context memory c,,, bytes32 lineageHash) =
            OriginSources.current(captured.dependencies, _origins.dependencies, collectionId);
        bytes32 id = Guard.planId(_dependencyHash, captured, c, lineageHash);
        result = _states[id].records.completed[id];
        if (result.renderCriticalEvidenceHash == 0) revert T.InventoryIncomplete();
        Guard.requireCurrent(_states[id], _origins, _authorities[id], id);
        Origins.requirePins(_origins, id);
        StreamPreservationPolicyRenderCriticalDefinitionStagesV1.requireDefinitions(
            _states[id], id, false
        );

        return abi.encode(result);
    }

    function requireFullDefinitionBytes(
        mapping(bytes32 => State.State) storage _states,
        Origins.State storage _origins,
        mapping(bytes32 => Authority.State) storage _authorities,
        bytes32 id
    ) public view {
        if (_states[id].records.completed[id].renderCriticalEvidenceHash == 0) {
            revert T.InventoryIncomplete();
        }
        Guard.requireCurrent(_states[id], _origins, _authorities[id], id);
        StreamPreservationPolicyRenderCriticalDefinitionStagesV1.requireDefinitions(
            _states[id], id, true
        );
    }
}

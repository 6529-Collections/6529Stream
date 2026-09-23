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
    StreamScopedPreservationPolicyRenderCriticalTypesV1 as Scoped
} from "../../interfaces/stream/preservation/StreamScopedPreservationPolicyRenderCriticalTypesV1.sol";

import {
    StreamPreservationInventoryTypes as T
} from "../../interfaces/stream/preservation/StreamPreservationInventoryTypes.sol";
import {
    StreamFinalityScope
} from "../../interfaces/stream/finality/StreamArtworkFinalityTypes.sol";

import {
    StreamCurrentAuthorityScopedPreservationPolicyRenderCriticalStateV1 as State
} from "./StreamCurrentAuthorityScopedPreservationPolicyRenderCriticalStateV1.sol";
import {
    StreamCurrentAuthorityScopedPreservationPolicyRenderCriticalSourceReadsV1 as Sources
} from "./StreamCurrentAuthorityScopedPreservationPolicyRenderCriticalSourceReadsV1.sol";

import {
    StreamCurrentAuthorityScopedPreservationPolicyRenderCriticalDefinitionStagesV1 as Definitions
} from "./StreamCurrentAuthorityScopedPreservationPolicyRenderCriticalDefinitionStagesV1.sol";

/// @notice Fixed linked ABI encoding of original inventory reads.
library StreamCurrentAuthorityScopedPreservationPolicyInventoryViewsV1 {
    function requireCurrent(
        mapping(bytes32 => State.State) storage _states,
        Authority.Config storage _config,
        O.Dependencies storage _originDependencies,
        bytes32 _dependencyHash,
        StreamFinalityScope calldata scope
    ) public view returns (bytes memory) {
        Scoped.Evidence memory e;
        D.Capture memory captured = Authority.resolve(_config);
        (Scoped.Context memory c,,, bytes32 lineageHash) =
            Sources.current(captured.dependencies, _originDependencies, scope);
        bytes32 id = State.idFor(_dependencyHash, captured, c, lineageHash);
        e = _states[id].completed[id];
        if (e.inventory.renderCriticalEvidenceHash == 0) revert T.InventoryIncomplete();
        State.requireCurrent(_states[id], id);
        Origins.requirePins(_states[id].origins, id);
        Definitions.requireDefinitions(_states[id], id, false);

        return abi.encode(e);
    }

    function sourceContext(State.State storage state_, bytes32 id)
        public
        view
        returns (bytes memory)
    {
        if (state_.plans[id].progress.collectionId == 0) revert T.InventoryIncomplete();
        return abi.encode(state_.contexts[id]);
    }

    function requireFullDefinitionBytes(State.State storage state_, bytes32 id) public view {
        if (state_.completed[id].inventory.renderCriticalEvidenceHash == 0) {
            revert T.InventoryIncomplete();
        }
        State.requireCurrent(state_, id);
        Definitions.requireDefinitions(state_, id, true);
    }
}

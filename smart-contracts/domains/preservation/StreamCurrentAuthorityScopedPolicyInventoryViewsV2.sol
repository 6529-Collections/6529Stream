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
    StreamScopedPolicyRenderCriticalTypesV2 as Scoped
} from "../../interfaces/stream/preservation/StreamScopedPolicyRenderCriticalTypesV2.sol";

import {
    StreamPreservationInventoryTypes as T
} from "../../interfaces/stream/preservation/StreamPreservationInventoryTypes.sol";
import {
    StreamFinalityScope
} from "../../interfaces/stream/finality/StreamArtworkFinalityTypes.sol";

import {
    StreamCurrentAuthorityScopedPolicyRenderCriticalStateV2 as State
} from "./StreamCurrentAuthorityScopedPolicyRenderCriticalStateV2.sol";
import {
    StreamMultiOriginScopedPolicyRenderCriticalSourceReadsV2 as Sources
} from "./StreamMultiOriginScopedPolicyRenderCriticalSourceReadsV2.sol";

import {
    StreamCurrentAuthorityScopedPolicyRenderCriticalDefinitionStagesV2 as Definitions
} from "./StreamCurrentAuthorityScopedPolicyRenderCriticalDefinitionStagesV2.sol";

/// @notice Fixed linked operations retain the original host storage and domains.
library StreamCurrentAuthorityScopedPolicyInventoryViewsV2 {
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

    function requireFullDefinitionBytes(mapping(bytes32 => State.State) storage _states, bytes32 id)
        public
        view
    {
        if (_states[id].completed[id].inventory.renderCriticalEvidenceHash == 0) {
            revert T.InventoryIncomplete();
        }
        State.requireCurrent(_states[id], id);
        Definitions.requireDefinitions(_states[id], id, true);
    }

    function sourceContext(mapping(bytes32 => State.State) storage _states, bytes32 id)
        public
        view
        returns (bytes memory)
    {
        if (_states[id].plans[id].progress.collectionId == 0) revert T.InventoryIncomplete();
        return abi.encode(_states[id].contexts[id]);
    }
}

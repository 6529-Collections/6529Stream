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

/// @notice Fixed linked operations retain the original host storage and domains.
library StreamCurrentAuthorityScopedPolicyInventoryBeginV2 {
    event ScopedInventoryStarted(
        uint16 schemaVersion, bytes32 indexed id, StreamFinalityScope scope, bytes32 contextHash
    );

    function beginInventory(
        mapping(bytes32 => State.State) storage _states,
        Authority.Config storage _config,
        O.Dependencies storage _originDependencies,
        bytes32 _dependencyHash,
        StreamFinalityScope calldata scope
    ) public returns (bytes32 id) {
        D.Capture memory captured = Authority.resolve(_config);
        (
            Scoped.Context memory c,
            O.Origin memory current,
            O.Origin memory presented,
            bytes32 lineageHash
        ) = Sources.current(captured.dependencies, _originDependencies, scope);
        id = State.idFor(_dependencyHash, captured, c, lineageHash);
        if (_states[id].plans[id].progress.collectionId != 0) return id;
        Authority.remember(_states[id].authority, _config, captured);
        _states[id].dependencies = captured.dependencies;
        _states[id].dependencyHash = _dependencyHash;
        _states[id].origins.dependencies = _originDependencies;
        Origins.initialize(_states[id].origins, id, current, presented, lineageHash);
        _states[id].contexts[id] = c;
        Scoped.Plan storage plan_ = _states[id].plans[id];
        plan_.scope = scope;
        T.Plan storage p = plan_.progress;
        p.collectionId = scope.collectionId;
        p.subject = c.subject;
        p.artistId = c.artistId;
        p.sourceContextHash = D.contextHash(captured, keccak256(abi.encode(c)), lineageHash);
        p.tokenCount = c.tokenCount;
        emit ScopedInventoryStarted(2, id, scope, p.sourceContextHash);
    }
}

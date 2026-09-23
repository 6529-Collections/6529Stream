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

import {
    StreamArtistArchiveOriginTypes as O
} from "../../interfaces/stream/preservation/StreamArtistArchiveOriginTypes.sol";
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

/// @notice Fixed linked operations retain the original host storage and domains.
library StreamCurrentAuthorityPreservationPolicyInventoryBeginV1 {
    event InventoryStarted(
        bytes32 indexed planId, uint256 indexed collectionId, bytes32 sourceContextHash
    );

    function beginInventory(
        mapping(bytes32 => State.State) storage _states,
        mapping(bytes32 => Authority.State) storage _authorities,
        Authority.Config storage _config,
        bytes32 _dependencyHash,
        Origins.State storage _origins,
        uint256 collectionId
    ) public returns (bytes32 id) {
        D.Capture memory captured = Authority.resolve(_config);
        (
            C.Context memory c,
            O.Origin memory current,
            O.Origin memory presented,
            bytes32 lineageHash
        ) = OriginSources.current(captured.dependencies, _origins.dependencies, collectionId);
        id = Guard.planId(_dependencyHash, captured, c, lineageHash);
        if (_states[id].records.plans[id].collectionId != 0) return id;
        Authority.remember(_authorities[id], _config, captured);
        _states[id].records.dependencies = captured.dependencies;
        _states[id].records.dependencyHash = _dependencyHash;
        Origins.initialize(_origins, id, current, presented, lineageHash);
        _states[id].contexts[id] = c;
        _states[id].records.contexts[id] = c.records;
        T.Plan storage p = _states[id].records.plans[id];
        p.collectionId = collectionId;
        p.subject = c.records.subject;
        p.artistId = c.records.artistId;
        p.sourceContextHash = D.contextHash(captured, keccak256(abi.encode(c)), lineageHash);
        p.tokenCount = c.records.tokenCount;
        emit InventoryStarted(id, collectionId, p.sourceContextHash);
    }
}

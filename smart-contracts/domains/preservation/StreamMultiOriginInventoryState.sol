// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    StreamArtistArchiveOriginTypes as O
} from "../../interfaces/stream/preservation/StreamArtistArchiveOriginTypes.sol";
import {
    StreamArtistRecoveredHydrationTypes as RH
} from "../../interfaces/stream/artist/StreamArtistRecoveredHydrationTypes.sol";
import {
    StreamPreservationInventoryTypes as T
} from "../../interfaces/stream/preservation/StreamPreservationInventoryTypes.sol";
import {
    StreamPreservationInventoryChains as Chains
} from "./StreamPreservationInventoryChains.sol";
import { StreamPreservationInventoryItems as Items } from "./StreamPreservationInventoryItems.sol";
import { StreamPreservationInventoryIO as IO } from "./StreamPreservationInventoryIO.sol";

/// @dev Host-owned table. Only authenticated typed stages admit origins; this library is not
/// an admission reader. Runtime materialization closes membership before the final seal.
library StreamMultiOriginInventoryState {
    struct State {
        O.Dependencies dependencies;
        mapping(bytes32 => O.Origin[]) origins;
        mapping(bytes32 => mapping(bytes32 => uint256)) indices;
        mapping(bytes32 => bytes32) chain;
        mapping(bytes32 => bytes32) lineage;
        mapping(bytes32 => uint256) runtimeCursor;
        mapping(bytes32 => bytes32) sealedRoot;
        mapping(bytes32 => mapping(bytes32 => O.RecordOrigin)) records;
    }

    function initialize(
        State storage state,
        bytes32 id,
        O.Origin memory current,
        O.Origin memory presented,
        bytes32 lineageHash
    ) public {
        if (id == 0 || lineageHash == 0 || state.lineage[id] != 0) {
            revert O.InvalidArchiveOrigin();
        }
        state.lineage[id] = lineageHash;
        _admit(state, id, current);
        _admit(state, id, presented);
    }

    function remember(
        State storage state,
        bytes32 id,
        bytes32 contextHash,
        T.Item memory item,
        O.RecordOrigin memory original,
        bytes32 expectedReceipt,
        address actor,
        bytes32 role
    ) public {
        if (
            state.lineage[id] == 0 || state.sealedRoot[id] != 0 || state.runtimeCursor[id] != 0
                || contextHash == 0 || actor == address(0)
                || original.sourceContextHash != contextHash || original.actor != actor
                || original.semanticRecordHash == 0 || original.role != role
                || original.occurrence.receipt.recordHash == 0
                || (expectedReceipt != 0
                    && original.occurrence.receipt.recordHash != expectedReceipt)
                || original.occurrence.position.point.environmentHash
                    != RH.originHash(original.producer.environment)
                || item.kind != T.Kind.STATE_BUNDLE || item.role != role
                || item.source != original.producer.environment.archive
                || item.sourceRecord != O.evidenceId(original) || item.sourceIndex != 1
                || item.provenanceHash == 0
        ) revert O.InvalidArchiveOrigin();
        _admit(state, id, original.producer);
        bytes32 key = Chains.itemHash(item);
        O.RecordOrigin storage prior = state.records[id][key];
        if (
            prior.sourceContextHash != 0
                && O.recordOriginHash(prior) != O.recordOriginHash(original)
        ) revert O.InvalidArchiveOrigin();
        state.records[id][key] = original;
    }

    function _admit(State storage state, bytes32 id, O.Origin memory origin) private {
        _pins(origin);
        bytes32 environment = RH.originHash(origin.environment);
        uint256 index = state.indices[id][environment];
        if (index != 0) {
            if (O.originPinHash(state.origins[id][index - 1]) != O.originPinHash(origin)) {
                revert O.InvalidArchiveOrigin();
            }
            return;
        }
        uint256 count = state.origins[id].length;
        if (count >= O.MAX_ORIGINS) revert O.ArchiveOriginLimit();
        state.indices[id][environment] = count + 1;
        state.origins[id].push(origin);
        state.chain[id] = O.appendOrigin(state.chain[id], count, origin);
    }

    function runtimeItems(State storage state, bytes32 id)
        public
        returns (T.Item[] memory rows, bytes32 witness)
    {
        uint256 index = state.runtimeCursor[id];
        if (
            state.lineage[id] == 0 || state.sealedRoot[id] != 0 || index >= state.origins[id].length
        ) revert T.InventoryIncomplete();
        O.Origin memory origin = state.origins[id][index];
        _pins(origin);
        bytes32 original = RH.originHash(origin.environment);
        witness = O.originPinHash(origin);
        rows = new T.Item[](10);
        rows[0] = Items.runtime(
            keccak256("ARTIST_ORIGIN_REGISTRY_RUNTIME"),
            origin.environment.registry,
            original,
            index
        );
        rows[1] = Items.runtime(
            keccak256("ARTIST_ORIGIN_COORDINATOR_RUNTIME"),
            origin.environment.coordinator,
            original,
            index
        );
        rows[2] = Items.runtime(
            keccak256("ARTIST_ORIGIN_ARCHIVE_RUNTIME"), origin.environment.archive, original, index
        );
        for (uint256 i; i < 7; ++i) {
            rows[3 + i] = Items.runtime(
                keccak256("ARTIST_ORIGIN_OWNER_RUNTIME"), origin.environment.owners[i], original, i
            );
        }
        for (uint256 i; i < 10; ++i) {
            rows[i].provenanceHash = witness;
        }
        state.runtimeCursor[id] = index + 1;
    }

    function seal(State storage state, bytes32 id) public returns (bytes32 root) {
        if (
            state.lineage[id] == 0 || state.sealedRoot[id] != 0
                || state.runtimeCursor[id] != state.origins[id].length
        ) revert T.InventoryIncomplete();
        requirePins(state, id);
        root = O.sealedOriginSetHash(state.origins[id].length, state.chain[id]);
        state.sealedRoot[id] = root;
    }

    function requirePins(State storage state, bytes32 id) public view {
        for (uint256 i; i < state.origins[id].length; ++i) {
            _pins(state.origins[id][i]);
        }
    }

    function _pins(O.Origin memory origin) private view {
        if (
            origin.environment.chainId != block.chainid || origin.environment.core == address(0)
                || origin.environment.manager == address(0)
                || origin.environment.suiteConfigurationHash == 0
        ) revert O.InvalidArchiveOrigin();
        IO.pin(origin.environment.registry, origin.registryCodeHash);
        IO.pin(origin.environment.coordinator, origin.coordinatorCodeHash);
        IO.pin(origin.environment.archive, origin.archiveCodeHash);
        for (uint256 i; i < 7; ++i) {
            IO.pin(origin.environment.owners[i], origin.environment.ownerCodeHashes[i]);
        }
    }
}

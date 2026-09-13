// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import { StreamArtistGuardianHistory as History } from "./StreamArtistGuardianHistory.sol";
import { StreamArtistHashes } from "./StreamArtistHashes.sol";
import {
    StreamArtistGuardianVestingTypes as V
} from "../../interfaces/stream/artist/StreamArtistGuardianVestingTypes.sol";

/// @notice Append-only snapshots of the complete guardian prefix at actual authority vesting.
/// @dev Fixed owner supplies only facts authenticated by its successful transition producer.
library StreamArtistGuardianVestingHistory {
    struct State {
        mapping(bytes32 => V.Snapshot) snapshots;
        mapping(bytes32 => bytes32) latest;
    }
    event ArtistGuardianVestingRecorded(
        uint16 schemaVersion,
        bytes32 indexed artistId,
        bytes32 indexed transitionRecordHash,
        bytes32 indexed commitment,
        uint16 operationId,
        uint64 ownerRevision,
        uint64 guardianCount,
        bytes32 guardianHistoryCommitment,
        bytes32 previousTransitionRecordHash
    );

    function record(
        State storage s,
        History.State storage history,
        StreamArtistHashes.Environment memory environment,
        V.Snapshot memory item,
        uint64 actualGuardianCount
    ) public returns (bytes32) {
        if (
            environment.chainId != block.chainid || environment.registry == address(0)
                || item.artistId == 0 || item.transitionRecordHash == 0 || item.ownerRevision == 0
                || item.executedAt == 0 || item.executedAt != block.timestamp
                || item.oldAddress == address(0) || item.newAddress == address(0)
                || item.oldAddress == item.newAddress
                || !((item.operationId == 32
                        && (item.authorityClass == 1 || item.authorityClass == 3))
                    || (item.operationId == 40 && item.authorityClass == 3)
                    || (item.operationId == 35
                        && (item.authorityClass == 1 || item.authorityClass == 3)))
                || item.commitment != 0 || item.previousCommitment != 0
                || s.snapshots[item.transitionRecordHash].commitment != 0
        ) revert V.InvalidGuardianVesting(item.transitionRecordHash);
        bytes32 previous = s.latest[item.artistId];
        if (previous != item.previousTransitionRecordHash) {
            revert V.IncompleteGuardianVestingHistory(
                item.artistId, item.previousTransitionRecordHash
            );
        }
        if (previous != 0) {
            V.Snapshot storage prior = s.snapshots[previous];
            if (
                prior.artistId != item.artistId || prior.transitionRecordHash != previous
                    || prior.commitment == 0 || prior.ownerRevision >= item.ownerRevision
                    || prior.executedAt > item.executedAt
            ) {
                revert V.IncompleteGuardianVestingHistory(item.artistId, previous);
            }
            item.previousCommitment = prior.commitment;
        }
        // Derive the complete prefix, never accept a caller-supplied Head as authority.
        item.guardians = History.requireComplete(history, item.artistId, actualGuardianCount);
        if (item.guardians.ownerRevision >= item.ownerRevision) {
            revert V.InvalidGuardianVesting(item.transitionRecordHash);
        }
        item.commitment = _commitment(environment, item);
        s.snapshots[item.transitionRecordHash] = item;
        s.latest[item.artistId] = item.transitionRecordHash;
        emit ArtistGuardianVestingRecorded(
            1,
            item.artistId,
            item.transitionRecordHash,
            item.commitment,
            item.operationId,
            item.ownerRevision,
            item.guardians.count,
            item.guardians.commitment,
            item.previousTransitionRecordHash
        );
        return item.commitment;
    }

    function _commitment(StreamArtistHashes.Environment memory environment, V.Snapshot memory item)
        private
        view
        returns (bytes32)
    {
        // Two static tuples concatenate to the same exact seventeen-word preimage.
        return keccak256(
            bytes.concat(
                abi.encode(
                    keccak256("6529STREAM_ARTIST_GUARDIAN_VESTING_V1"),
                    environment.chainId,
                    environment.registry,
                    address(this)
                ),
                abi.encode(
                    item.artistId,
                    item.transitionRecordHash,
                    item.operationId,
                    item.ownerRevision,
                    item.executedAt,
                    item.oldAddress,
                    item.newAddress,
                    item.authorityClass,
                    item.guardians,
                    item.previousTransitionRecordHash,
                    item.previousCommitment
                )
            )
        );
    }

    function encoded(State storage s, bytes32 artistId, bytes32 recordHash)
        public
        view
        returns (bytes memory)
    {
        V.Snapshot memory item = s.snapshots[recordHash];
        if (
            artistId == 0 || recordHash == 0 || item.artistId != artistId
                || item.transitionRecordHash != recordHash || item.commitment == 0
        ) {
            revert V.InvalidGuardianVesting(recordHash);
        }
        return abi.encode(item);
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    StreamArtistGuardianHistoryTypes as H
} from "../../interfaces/stream/artist/StreamArtistGuardianHistoryTypes.sol";
import {
    StreamArtistRotationTypes as R
} from "../../interfaces/stream/artist/StreamArtistRotationTypes.sol";
import {
    StreamArtistOnboardingTypes as T
} from "../../interfaces/stream/artist/StreamArtistOnboardingTypes.sol";
import { StreamArtistHashes } from "./StreamArtistHashes.sol";
import { StreamArtistRotationHashes } from "./StreamArtistRotationHashes.sol";

/// @notice Bounded admission indexing over storage owned by the fixed Identity host.
/// @dev Caller must authenticate actual operation28 admission before appending, and actual local recovery association before freezing.
library StreamArtistGuardianHistory {
    struct State {
        mapping(bytes32 => H.Head) heads;
        mapping(bytes32 => H.Entry) entries;
        mapping(bytes32 => mapping(uint64 => bytes32)) records;
        mapping(bytes32 => mapping(address => uint64)) firstMembership;
        mapping(bytes32 => H.Snapshot) snapshots;
    }

    function append(
        State storage s,
        StreamArtistHashes.Environment memory environment,
        R.GuardianRecord memory record,
        uint64 admissionCount,
        uint64 successfulOwnerRevision
    ) public returns (bytes32 commitment) {
        bytes32 artistId = record.terms.artistId;
        H.Head storage prior = s.heads[artistId];
        if (
            artistId == bytes32(0) || environment.chainId != block.chainid
                || environment.registry == address(0) || record.recordHash == bytes32(0)
                || record.signer == address(0) || record.authorityClass == 0
                || prior.count == type(uint64).max || admissionCount != prior.count + 1
                || successfulOwnerRevision <= prior.ownerRevision
                || s.entries[record.recordHash].recordHash != bytes32(0)
                || (prior.count == 0
                        ? prior.commitment != bytes32(0)
                        : prior.commitment == bytes32(0))
                || StreamArtistRotationHashes.guardianRecord(
                        environment,
                        record.terms,
                        T.Authorization(record.nonce, record.signedAt, bytes(""))
                    ) != record.recordHash
        ) revert H.InvalidGuardianHistory(artistId);
        _shape(record.terms);
        H.Entry memory entry = H.Entry(
            artistId,
            admissionCount,
            successfulOwnerRevision,
            record.recordHash,
            keccak256(abi.encode(record)),
            prior.commitment,
            bytes32(0)
        );
        commitment = keccak256(
            abi.encode(
                keccak256("6529STREAM_ARTIST_GUARDIAN_ADMISSION_HISTORY_V1"),
                environment.chainId,
                environment.registry,
                address(this),
                entry.artistId,
                entry.index,
                entry.ownerRevision,
                entry.recordHash,
                entry.recordDataHash,
                entry.previousCommitment
            )
        );
        entry.commitment = commitment;
        s.entries[record.recordHash] = entry;
        s.records[artistId][admissionCount] = record.recordHash;
        s.heads[artistId] = H.Head(admissionCount, successfulOwnerRevision, commitment);
        for (uint256 i; i < record.terms.guardians.length; ++i) {
            address guardian = record.terms.guardians[i];
            if (s.firstMembership[artistId][guardian] == 0) {
                s.firstMembership[artistId][guardian] = admissionCount;
            }
        }
    }

    function requireComplete(State storage s, bytes32 artistId, uint64 admissionCount)
        public
        view
        returns (H.Head memory head)
    {
        head = s.heads[artistId];
        if (artistId == bytes32(0) || head.count != admissionCount) {
            revert H.InvalidGuardianHistory(artistId);
        }
        if (admissionCount == 0) {
            if (head.ownerRevision != 0 || head.commitment != bytes32(0)) {
                revert H.InvalidGuardianHistory(artistId);
            }
        } else {
            H.Entry storage last = s.entries[s.records[artistId][admissionCount]];
            if (
                head.ownerRevision == 0 || head.commitment == bytes32(0)
                    || last.artistId != artistId || last.index != admissionCount
                    || last.ownerRevision != head.ownerRevision
                    || last.commitment != head.commitment || last.recordHash == bytes32(0)
            ) {
                revert H.InvalidGuardianHistory(artistId);
            }
        }
    }

    function freeze(
        State storage s,
        bytes32 actionId,
        bytes32 associationHash,
        bytes32 artistId,
        uint64 admissionCount
    ) public returns (H.Snapshot memory snapshot) {
        H.Head memory head = requireComplete(s, artistId, admissionCount);
        if (
            actionId == bytes32(0) || associationHash == bytes32(0) || admissionCount == 0
                || s.snapshots[actionId].associationHash != bytes32(0)
        ) {
            revert H.InvalidGuardianHistorySnapshot(actionId);
        }
        snapshot = H.Snapshot(artistId, head.count, head.commitment, associationHash);
        s.snapshots[actionId] = snapshot;
    }

    /// @dev This is prefix membership only. The caller establishes which entire prefix has veto standing.
    function member(
        State storage s,
        bytes32 actionId,
        bytes32 associationHash,
        bytes32 artistId,
        address actor
    ) public view returns (bool) {
        H.Snapshot storage snapshot = s.snapshots[actionId];
        if (
            associationHash == bytes32(0) || snapshot.associationHash != associationHash
                || snapshot.artistId != artistId || snapshot.count == 0
                || snapshot.historyCommitment == bytes32(0)
        ) {
            revert H.InvalidGuardianHistorySnapshot(actionId);
        }
        uint64 first = s.firstMembership[artistId][actor];
        return actor != address(0) && first != 0 && first <= snapshot.count;
    }

    function _shape(R.GuardianSet memory terms) private pure {
        if (
            terms.guardians.length > 8 || terms.minContestSeconds > 30 days
                || (terms.guardians.length == 0
                        ? terms.approvalThreshold != 0
                        : terms.approvalThreshold == 0
                        || terms.approvalThreshold > terms.guardians.length)
        ) {
            revert H.InvalidGuardianHistory(terms.artistId);
        }
        address previous;
        for (uint256 i; i < terms.guardians.length; ++i) {
            if (terms.guardians[i] <= previous) revert H.InvalidGuardianHistory(terms.artistId);
            previous = terms.guardians[i];
        }
    }
}

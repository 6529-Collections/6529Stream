// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    StreamArtistRecoveredIdentityHydrationTypes as IH
} from "../../interfaces/stream/artist/StreamArtistRecoveredIdentityHydrationTypes.sol";
import {
    StreamArtistRecoveredHydrationTypes as RH
} from "../../interfaces/stream/artist/StreamArtistRecoveredHydrationTypes.sol";

import {
    StreamArtistRecoveredHydrationChronology as Chronology
} from "./StreamArtistRecoveredHydrationChronology.sol";

/// @notice Fixed original Identity source validation stage.
library StreamArtistRecoveredIdentitySourceVestings {
    function validate(IH.Bundle calldata b, RH.OwnerProvenance calldata p) public pure {
        uint256 expected = b.recoveries.length;
        for (uint256 i; i < b.rotations.length; ++i) {
            if (b.rotations[i].record.transition.executedAt != 0) ++expected;
        }
        for (uint256 i; i < b.estates.length; ++i) {
            if (b.estates[i].execution.executedAt != 0) ++expected;
        }
        for (uint256 i; i < b.notices.length; ++i) {
            if (b.notices[i].phase == 3) ++expected;
        }
        if (b.vestings.length != expected) revert IH.InvalidRecoveredIdentity(b.artistId);
        bytes32 previous;
        bytes32 commitment;
        for (uint256 i; i < b.vestings.length; ++i) {
            IH.VestingRow calldata r = b.vestings[i];
            _point(p, r.point);
            if (
                r.snapshot.artistId != b.artistId || r.snapshot.transitionRecordHash == 0
                    || r.snapshot.commitment == 0
                    || r.snapshot.previousTransitionRecordHash != previous
                    || r.snapshot.previousCommitment != commitment
                    || r.snapshot.ownerRevision != r.point.ownerRevision
                    || (r.snapshot.authorityClass != 1 && r.snapshot.authorityClass != 3)
            ) revert IH.InvalidRecoveredIdentity(r.snapshot.transitionRecordHash);
            if (i != 0) _ordered(p, b.vestings[i - 1].point, r.point);
            bool actual;
            for (uint256 j; j < b.rotations.length; ++j) {
                if (
                    r.snapshot.operationId == 32
                        && b.rotations[j].record.recordHash == r.snapshot.transitionRecordHash
                        && b.rotations[j].record.transition.executedAt == r.snapshot.executedAt
                        && r.snapshot.executedAt != 0
                ) actual = true;
            }
            for (uint256 j; j < b.recoveries.length; ++j) {
                if (
                    r.snapshot.operationId == 35
                        && b.recoveries[j].record.recordHash == r.snapshot.transitionRecordHash
                        && _samePoint(b.recoveries[j].position.point, r.point)
                ) actual = true;
            }
            for (uint256 j; j < b.estates.length; ++j) {
                if (
                    r.snapshot.operationId == 40
                        && b.estates[j].request.recordHash == r.snapshot.transitionRecordHash
                        && b.estates[j].execution.executedAt == r.snapshot.executedAt
                        && r.snapshot.executedAt != 0
                ) actual = true;
            }
            for (uint256 j; j < b.notices.length; ++j) {
                if (
                    r.snapshot.operationId == 43
                        && b.notices[j].terminal.recordHash == r.snapshot.transitionRecordHash
                        && b.notices[j].phase == 3
                        && _samePoint(
                            _occurrence(p, b.artistId, 43, r.snapshot.transitionRecordHash), r.point
                        )
                ) actual = true;
            }
            if (!actual) revert IH.InvalidRecoveredIdentity(r.snapshot.transitionRecordHash);
            previous = r.snapshot.transitionRecordHash;
            commitment = r.snapshot.commitment;
        }
        if (
            b.heads.latestVesting != previous || b.heads.latestExecution != previous
                || b.heads.latestRecovery != b.recoveries[b.recoveries.length - 1].record.recordHash
        ) revert IH.InvalidRecoveredIdentity(b.artistId);
    }

    function _occurrence(RH.OwnerProvenance calldata p, bytes32 artist, uint16 op, bytes32 key)
        private
        pure
        returns (RH.Point memory point)
    {
        bool found;
        for (uint256 i; i < p.journal.length; ++i) {
            RH.JournalEntry memory j = p.journal[i];
            if (
                j.receipt.operation != op || j.receipt.artistId != artist
                    || j.receipt.recordHash != key
            ) continue;
            if (found || key == 0) revert IH.InvalidRecoveredIdentity(key);
            found = true;
            point = j.position.point;
        }
        if (!found) revert IH.InvalidRecoveredIdentity(key);
    }

    function _point(RH.OwnerProvenance calldata p, RH.Point memory point) private pure {
        if (point.ownerIndex != 2) revert IH.InvalidRecoveredIdentity(point.environmentHash);
        Chronology.validateOwnerPoint(p, 2, point);
    }

    function _ordered(RH.OwnerProvenance calldata p, RH.Point memory a, RH.Point memory b)
        private
        pure
    {
        if (!Chronology.beforeOwner(p, 2, a, b)) {
            revert IH.InvalidRecoveredIdentity(b.environmentHash);
        }
    }

    function _samePoint(RH.Point memory a, RH.Point memory b) private pure returns (bool) {
        return keccak256(abi.encode(a)) == keccak256(abi.encode(b));
    }
}

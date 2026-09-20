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
library StreamArtistRecoveredIdentitySourceGuardians {
    function validate(IH.Bundle calldata b, RH.OwnerProvenance calldata p) public pure {
        if (
            b.heads.guardianHistory.count != b.guardians.length
                || b.heads.guardianRecordsSeen != b.guardians.length
                || b.heads.guardianIndex.count != b.guardians.length
                || b.heads.guardianIndex.historyCommitment != b.heads.guardianHistory.commitment
        ) revert IH.InvalidRecoveredIdentity(b.artistId);
        bytes32 previous;
        for (uint256 i; i < b.guardians.length; ++i) {
            IH.GuardianRow calldata r = b.guardians[i];
            if (
                r.entry.artistId != b.artistId || r.entry.index != i + 1
                    || r.entry.recordHash != r.record.recordHash
                    || r.entry.ownerRevision != r.position.point.ownerRevision
                    || r.entry.previousCommitment != previous
                    || r.entry.recordDataHash != keccak256(abi.encode(r.record))
            ) revert IH.InvalidRecoveredIdentity(r.record.recordHash);
            if (i != 0) _ordered(p, b.guardians[i - 1].position.point, r.position.point);
            previous = r.entry.commitment;
            for (uint256 j; j < r.record.terms.guardians.length; ++j) {
                bool found;
                for (uint256 k; k < b.memberships.length; ++k) {
                    if (b.memberships[k].actor == r.record.terms.guardians[j]) found = true;
                }
                if (!found) revert IH.InvalidRecoveredIdentity(r.record.recordHash);
            }
        }
        if (previous != b.heads.guardianHistory.commitment) {
            revert IH.InvalidRecoveredIdentity(b.artistId);
        }
        address previousActor;
        for (uint256 i; i < b.memberships.length; ++i) {
            IH.MembershipRow calldata r = b.memberships[i];
            if (r.actor <= previousActor || r.indices.length == 0 || r.first != r.indices[0]) {
                revert IH.InvalidRecoveredIdentity(b.artistId);
            }
            previousActor = r.actor;
            uint256 cursor;
            for (uint256 j; j < b.guardians.length; ++j) {
                bool member;
                for (uint256 k; k < b.guardians[j].record.terms.guardians.length; ++k) {
                    if (b.guardians[j].record.terms.guardians[k] == r.actor) member = true;
                }
                if (member) {
                    if (cursor >= r.indices.length || r.indices[cursor++] != j + 1) {
                        revert IH.InvalidRecoveredIdentity(b.artistId);
                    }
                }
            }
            if (cursor != r.indices.length) revert IH.InvalidRecoveredIdentity(b.artistId);
        }
        for (uint256 i; i < b.rotations.length; ++i) {
            IH.RotationRow calldata r = b.rotations[i];
            bool found;
            for (uint256 j; j < b.guardians.length; ++j) {
                if (b.guardians[j].record.recordHash == r.record.guardianSetRecordHash) {
                    found = true;
                    if (r.approvals.length != b.guardians[j].record.terms.guardians.length) {
                        revert IH.InvalidRecoveredIdentity(r.record.recordHash);
                    }
                }
            }
            uint256 approved;
            for (uint256 j; j < r.approvals.length; ++j) {
                if (r.approvals[j]) ++approved;
            }
            if (!found || approved != r.record.guardianApprovals) {
                revert IH.InvalidRecoveredIdentity(r.record.recordHash);
            }
        }
    }

    function _ordered(RH.OwnerProvenance calldata p, RH.Point memory a, RH.Point memory b)
        private
        pure
    {
        if (!Chronology.beforeOwner(p, 2, a, b)) {
            revert IH.InvalidRecoveredIdentity(b.environmentHash);
        }
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    StreamArtistRecoveredIdentityHydrationTypes as IH
} from "../../interfaces/stream/artist/StreamArtistRecoveredIdentityHydrationTypes.sol";
import {
    StreamArtistIdentityDismissalTypes as D
} from "../../interfaces/stream/artist/StreamArtistIdentityDismissalTypes.sol";
import {
    StreamArtistRecoveredIdentityHydrationState as X
} from "./StreamArtistRecoveredIdentityHydrationState.sol";
import {
    StreamArtistRecoveredIdentityImportEstate as Estate
} from "./StreamArtistRecoveredIdentityImportEstate.sol";
import {
    StreamArtistRecoveredIdentitySourceFrame as Frame
} from "./StreamArtistRecoveredIdentitySourceFrame.sol";

/// @notice Fixed authority phase of the original recovered Identity import.
/// @dev The fixed importer passes the complete canonical Bundle after SourceCodec validation.
/// Linked library calls retain the host's 17 declared roots and storage context.
library StreamArtistRecoveredIdentityImportAuthority {
    function install(uint256[17] memory roots, bytes calldata canonical) public {
        IH.Bundle calldata b = Frame.bundle(canonical);
        _authority(roots, b);
        Estate.install(roots, canonical);
    }

    function _authority(uint256[17] memory r, IH.Bundle calldata b) private {
        for (uint256 i; i < b.guardians.length; ++i) {
            IH.GuardianRow memory row = b.guardians[i];
            IH.GuardianRow memory zero;
            bytes32 key = row.record.recordHash;
            _empty(
                abi.encode(
                    X.rotations(r).guardians[key],
                    X.recovery(r).guardianHistory.entries[key],
                    X.recovery(r).guardianSupersession.statuses[key]
                ),
                abi.encode(zero.record, zero.entry, zero.status),
                key
            );
            if (X.recovery(r).guardianHistory.records[b.artistId][row.entry.index] != 0) {
                revert IH.InvalidRecoveredIdentity(key);
            }
            X.rotations(r).guardians[key] = row.record;
            X.recovery(r).guardianHistory.entries[key] = row.entry;
            X.recovery(r).guardianHistory.records[b.artistId][row.entry.index] = key;
            X.recovery(r).guardianSupersession.statuses[key] = row.status;
        }
        for (uint256 i; i < b.memberships.length; ++i) {
            IH.MembershipRow memory row = b.memberships[i];
            if (
                X.recovery(r).guardianHistory.firstMembership[b.artistId][row.actor] != 0
                    || X.recovery(r).guardianSupersession.memberships[b.artistId][row.actor].length
                        != 0
            ) revert IH.InvalidRecoveredIdentity(b.artistId);
            X.recovery(r).guardianHistory.firstMembership[b.artistId][row.actor] = row.first;
            X.recovery(r).guardianSupersession.memberships[b.artistId][row.actor] = row.indices;
        }
        for (uint256 i; i < b.rotations.length; ++i) {
            IH.RotationRow memory row = b.rotations[i];
            IH.RotationRow memory zero;
            bytes32 key = row.record.recordHash;
            _empty(abi.encode(X.rotations(r).rotations[key]), abi.encode(zero.record), key);
            address[] memory members =
            X.rotations(r).guardians[row.record.guardianSetRecordHash].terms.guardians;
            for (uint256 j; j < members.length; ++j) {
                if (X.rotations(r).approvals[key][members[j]]) {
                    revert IH.InvalidRecoveredIdentity(key);
                }
                X.rotations(r).approvals[key][members[j]] = row.approvals[j];
            }
            X.rotations(r).rotations[key] = row.record;
        }
        for (uint256 i; i < b.contests.length; ++i) {
            IH.ContestRow memory row = b.contests[i];
            IH.ContestRow memory zero;
            _empty(
                abi.encode(X.contests(r).records[row.record.recordHash]),
                abi.encode(zero.record),
                row.record.recordHash
            );
            X.contests(r).records[row.record.recordHash] = row.record;
        }
        for (uint256 i; i < b.causes.length; ++i) {
            IH.CauseRow memory row = b.causes[i];
            IH.CauseRow memory zero;
            bytes32 key = row.cause.causeHash;
            _empty(
                abi.encode(X.resolutions(r).causes[key], X.dormancy(r).causeNotice[key]),
                abi.encode(zero.cause, bytes32(0)),
                key
            );
            X.resolutions(r).causes[key] = row.cause;
            X.dormancy(r).causeNotice[key] = row.notice;
        }
        for (uint256 i; i < b.dismissals.length; ++i) {
            IH.DismissalRow memory row = b.dismissals[i];
            IH.DismissalRow memory zero;
            _empty(
                abi.encode(X.resolutions(r).records[row.record.recordHash]),
                abi.encode(zero.record),
                row.record.recordHash
            );
            X.resolutions(r).records[row.record.recordHash] = row.record;
        }
        for (uint256 i; i < b.closures.length; ++i) {
            IH.ClosureRow memory row = b.closures[i];
            D.Closure memory zero;
            _empty(
                abi.encode(X.resolutions(r).closures[row.transition]),
                abi.encode(zero),
                row.transition
            );
            X.resolutions(r).closures[row.transition] = row.closure;
        }
        for (uint256 i; i < b.standing.length; ++i) {
            IH.StandingRow memory row = b.standing[i];
            D.StandingJudgment memory zero;
            _empty(
                abi.encode(
                    X.rotations(r).retirement[b.artistId][row.account],
                    X.rotations(r).standingRevocation[b.artistId][row.account],
                    X.resolutions(r).standingJudgments[b.artistId][row.account]
                ),
                abi.encode(bytes32(0), bytes32(0), zero),
                b.artistId
            );
            X.rotations(r).retirement[b.artistId][row.account] = row.retirement;
            X.rotations(r).standingRevocation[b.artistId][row.account] = row.revocation;
            X.resolutions(r).standingJudgments[b.artistId][row.account] = row.judgment;
        }
        for (uint256 i; i < b.standingRecords.length; ++i) {
            IH.StandingRecordRow memory row = b.standingRecords[i];
            IH.StandingRecordRow memory zero;
            bytes32 key = row.record.recordHash;
            _empty(
                abi.encode(
                    X.rotations(r).standingRecords[key],
                    X.rewinds(r).statuses[key],
                    X.rewinds(r).standingRecordContinuations[key]
                ),
                abi.encode(zero.record, zero.status, bytes32(0)),
                key
            );
            X.rotations(r).standingRecords[key] = row.record;
            X.rewinds(r).statuses[key] = row.status;
            X.rewinds(r).standingRecordContinuations[key] = row.rewindContinuation;
        }
    }

    function _empty(bytes memory old, bytes memory zero, bytes32 key) private pure {
        if (keccak256(old) != keccak256(zero)) revert IH.InvalidRecoveredIdentity(key);
    }
}

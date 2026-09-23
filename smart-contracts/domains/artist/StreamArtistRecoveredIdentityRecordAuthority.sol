// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    StreamArtistRecoveredIdentityHydrationTypes as IH
} from "../../interfaces/stream/artist/StreamArtistRecoveredIdentityHydrationTypes.sol";

import {
    IStreamArtistRotationReads
} from "../../interfaces/stream/artist/IStreamArtistRotation.sol";
import {
    IStreamArtistGuardianHistory
} from "../../interfaces/stream/artist/IStreamArtistGuardianHistory.sol";
import {
    IStreamArtistGuardianSupersession
} from "../../interfaces/stream/artist/IStreamArtistGuardianSupersession.sol";

import {
    IStreamArtistIdentityContestOwner
} from "../../interfaces/stream/artist/IStreamArtistIdentityContest.sol";
import {
    IStreamArtistIdentityDismissalOwner
} from "../../interfaces/stream/artist/IStreamArtistIdentityDismissal.sol";

import {
    IStreamArtistIdentityRecoveryOwnerV3
} from "../../interfaces/stream/artist/IStreamArtistIdentityRecoveryV3.sol";

import {
    IStreamArtistEstateOwner
} from "../../interfaces/stream/artist/IStreamArtistEstateOwner.sol";
import {
    IStreamArtistDormancyOwner,
    StreamArtistDormancyTypes as Dorm
} from "../../interfaces/stream/artist/IStreamArtistDormancy.sol";

import {
    StreamArtistGuardianHistoryTypes as GH
} from "../../interfaces/stream/artist/StreamArtistGuardianHistoryTypes.sol";

import {
    StreamArtistEstateTypes as Estate
} from "../../interfaces/stream/artist/StreamArtistEstateTypes.sol";
import {
    StreamArtistRecoveryRewindTypes as W
} from "../../interfaces/stream/artist/StreamArtistRecoveryRewindTypes.sol";

/// @notice Original complete Identity authority getter comparisons.
library StreamArtistRecoveredIdentityRecordAuthority {
    function validate(address owner, IH.Bundle calldata b) public view {
        for (uint256 i; i < b.guardians.length; ++i) {
            IH.GuardianRow calldata r = b.guardians[i];
            if (r.record.terms.artistId != b.artistId || r.entry.index != i + 1) {
                revert IH.InvalidRecoveredIdentity(r.record.recordHash);
            }
            _same(
                abi.encode(r.record),
                abi.encode(
                    IStreamArtistRotationReads(owner).guardianSetRecord(r.record.recordHash)
                ),
                r.record.recordHash
            );
            (GH.Head memory head, GH.Entry memory entry,,) = IStreamArtistGuardianHistory(owner)
                .guardianHistoryState(b.artistId, uint64(i + 1), address(0), 0);
            _same(abi.encode(head), abi.encode(b.heads.guardianHistory), b.artistId);
            _same(abi.encode(entry), abi.encode(r.entry), r.record.recordHash);
            _same(
                abi.encode(r.status),
                abi.encode(
                    IStreamArtistGuardianSupersession(owner)
                        .guardianRecordSupersession(r.record.recordHash)
                ),
                r.record.recordHash
            );
        }
        for (uint256 i; i < b.rotations.length; ++i) {
            IH.RotationRow calldata r = b.rotations[i];
            if (r.record.terms.artistId != b.artistId) {
                revert IH.InvalidRecoveredIdentity(r.record.recordHash);
            }
            _same(
                abi.encode(r.record),
                abi.encode(IStreamArtistRotationReads(owner).rotationRecord(r.record.recordHash)),
                r.record.recordHash
            );
        }
        for (uint256 i; i < b.contests.length; ++i) {
            IH.ContestRow calldata r = b.contests[i];
            if (r.record.terms.artistId != b.artistId) {
                revert IH.InvalidRecoveredIdentity(r.record.recordHash);
            }
            _same(
                abi.encode(r.record),
                abi.encode(
                    IStreamArtistIdentityContestOwner(owner)
                        .identityContestRecord(r.record.recordHash)
                ),
                r.record.recordHash
            );
        }
        for (uint256 i; i < b.causes.length; ++i) {
            IH.CauseRow calldata r = b.causes[i];
            if (r.cause.facts.artistId != b.artistId) {
                revert IH.InvalidRecoveredIdentity(r.cause.causeHash);
            }
            _same(
                abi.encode(r.cause),
                abi.encode(
                    IStreamArtistIdentityDismissalOwner(owner)
                        .identityContestCause(r.cause.causeHash)
                ),
                r.cause.causeHash
            );
            (bytes32 notice,,) = IStreamArtistDormancyOwner(owner)
                .dormancyResolutionState(b.artistId, r.cause.causeHash);
            if (notice != r.notice) revert IH.InvalidRecoveredIdentity(r.cause.causeHash);
        }
        for (uint256 i; i < b.dismissals.length; ++i) {
            IH.DismissalRow calldata r = b.dismissals[i];
            if (r.record.terms.artistId != b.artistId) {
                revert IH.InvalidRecoveredIdentity(r.record.recordHash);
            }
            _same(
                abi.encode(r.record),
                abi.encode(
                    IStreamArtistIdentityDismissalOwner(owner)
                        .identityContestDismissalRecord(r.record.recordHash)
                ),
                r.record.recordHash
            );
        }
        for (uint256 i; i < b.closures.length; ++i) {
            _same(
                abi.encode(b.closures[i].closure),
                abi.encode(
                    IStreamArtistIdentityDismissalOwner(owner)
                        .identityTransitionClosure(b.artistId, b.closures[i].transition)
                ),
                b.closures[i].transition
            );
        }
        for (uint256 i; i < b.standingRecords.length; ++i) {
            IH.StandingRecordRow calldata r = b.standingRecords[i];
            if (r.record.terms.artistId != b.artistId) {
                revert IH.InvalidRecoveredIdentity(r.record.recordHash);
            }
            _same(
                abi.encode(r.record),
                abi.encode(
                    IStreamArtistRotationReads(owner).standingRevocationRecord(r.record.recordHash)
                ),
                r.record.recordHash
            );
            _status(
                owner, W.RecordKind.PRIOR_ADDRESS_STANDING_REVOCATION, r.record.recordHash, r.status
            );
            if (
                r.rewindContinuation
                    != IStreamArtistIdentityRecoveryOwnerV3(owner)
                        .standingRevocationRecoveryContinuationV3(r.record.recordHash)
            ) revert IH.InvalidRecoveredIdentity(r.record.recordHash);
        }
        for (uint256 i; i < b.estates.length; ++i) {
            IH.EstateRow calldata r = b.estates[i];
            if (r.request.terms.artistId != b.artistId) {
                revert IH.InvalidRecoveredIdentity(r.request.recordHash);
            }
            (
                Estate.RequestRecord memory request,
                uint8 phase,
                Estate.ExecutionFacts memory execution
            ) = IStreamArtistEstateOwner(owner).estateActivationRecord(r.request.recordHash);
            _same(
                abi.encode(r.request, r.phase, r.execution),
                abi.encode(request, phase, execution),
                r.request.recordHash
            );
            _same(
                abi.encode(r.transition),
                abi.encode(
                    IStreamArtistRotationReads(owner).artistTransitionState(r.request.recordHash)
                ),
                r.request.recordHash
            );
        }
        for (uint256 i; i < b.notices.length; ++i) {
            IH.NoticeRow calldata r = b.notices[i];
            if (r.notice.terms.artistId != b.artistId) {
                revert IH.InvalidRecoveredIdentity(r.notice.recordHash);
            }
            (Dorm.Notice memory notice, uint8 phase, Dorm.Terminal memory terminal) =
                IStreamArtistDormancyOwner(owner).dormancyRecord(r.notice.recordHash);
            _same(
                abi.encode(r.notice, r.phase, r.terminal),
                abi.encode(notice, phase, terminal),
                r.notice.recordHash
            );
            if (phase == 3) {
                _same(
                    abi.encode(r.transition),
                    abi.encode(
                        IStreamArtistRotationReads(owner).artistTransitionState(terminal.recordHash)
                    ),
                    r.notice.recordHash
                );
            }
        }
    }

    function _status(address owner, W.RecordKind kind, bytes32 hash, W.StatusV3 calldata status)
        private
        view
    {
        _same(
            abi.encode(status),
            abi.encode(
                IStreamArtistIdentityRecoveryOwnerV3(owner).recoveryRecordStatusV3(kind, hash)
            ),
            hash
        );
    }

    function _same(bytes memory a, bytes memory b, bytes32 key) private pure {
        if (keccak256(a) != keccak256(b)) revert IH.InvalidRecoveredIdentity(key);
    }
}

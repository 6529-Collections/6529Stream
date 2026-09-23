// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    StreamArtistRecoveryRewindTypes as W
} from "../../interfaces/stream/artist/StreamArtistRecoveryRewindTypes.sol";
import {
    StreamArtistOnboardingTypes as T
} from "../../interfaces/stream/artist/StreamArtistOnboardingTypes.sol";
import {
    StreamArtistRotationTypes as R
} from "../../interfaces/stream/artist/StreamArtistRotationTypes.sol";
import {
    StreamArtistGuardianVestingTypes as V
} from "../../interfaces/stream/artist/StreamArtistGuardianVestingTypes.sol";
import { IStreamArtistOwner } from "../../interfaces/stream/artist/IStreamArtistOwner.sol";
import {
    IStreamArtistRotationReads
} from "../../interfaces/stream/artist/IStreamArtistRotation.sol";
import {
    IStreamArtistIdentityRecoveryOwner
} from "../../interfaces/stream/artist/IStreamArtistIdentityRecovery.sol";
import {
    IStreamArtistEstateOwner
} from "../../interfaces/stream/artist/IStreamArtistEstateOwner.sol";
import {
    IStreamArtistDormancyOwner
} from "../../interfaces/stream/artist/IStreamArtistDormancy.sol";
import { StreamArtistRotationHashes as RH } from "./StreamArtistRotationHashes.sol";
import {
    StreamArtistRecoveryRewindAdmission as A
} from "./StreamArtistRecoveryRewindAdmission.sol";
import {
    StreamArtistRecoveryRewindContinuations as C
} from "./StreamArtistRecoveryRewindContinuations.sol";
import {
    StreamArtistRecoveredIdentityRuntime as Recovered
} from "./StreamArtistRecoveredIdentityRuntime.sol";
import {
    StreamArtistRecoveredRuntimeReads as Runtime
} from "./StreamArtistRecoveredRuntimeReads.sol";
import {
    StreamArtistRecoveryRewindRecordReads as Records
} from "./StreamArtistRecoveryRewindRecordReads.sol";

/// @notice Fixed original standing admission reads for recovery rewind.
/// @dev Preserves the original read and validation order. The caller retains journal
/// admission and final Facts wrapping; this library owns no state or routing choice.
library StreamArtistRecoveryRewindStandingReads {
    function standing(
        W.EnvironmentV3 memory e,
        bytes32 artistId,
        bytes32 hash,
        Records.Source memory source
    ) public view returns (Records.Facts memory f) {
        R.StandingRecord memory r =
            IStreamArtistRotationReads(e.identityOwner).standingRevocationRecord(hash);
        if (
            r.recordHash != hash || r.terms.artistId != artistId || r.signer == address(0)
                || (r.authorityClass != 1 && r.authorityClass != 3) || r.signedAt == 0
                || r.signedAt > block.timestamp || r.terms.revokedAddress == address(0)
                || r.terms.retiredTransitionRecordHash == 0
                || RH.standingRecordForAuthority(
                        A.hashes(source.original),
                        r.terms,
                        r.signer,
                        r.authorityClass,
                        r.nonce,
                        r.signedAt
                    ) != hash
        ) revert W.InvalidRecoveryRewindRecord(hash);
        T.ReplayCell memory admitted;
        T.ReplayCell memory n;
        bytes32 admission;
        V.Snapshot memory v;
        R.TransitionState memory t;
        if (source.imported) {
            Runtime.ReplayFact memory admittedAt;
            (admittedAt, admission) = C.standingAt(e, r, source.occurrence);
            Runtime.Context memory clock = Runtime.load(e, 2);
            Runtime.ReplayFact memory nonce = Runtime.replay(
                clock,
                source.occurrence.position.point.environmentHash,
                keccak256("identity_authority.replay.nonce_allocator"),
                keccak256(abi.encode(artistId, r.nonce))
            );
            if (
                nonce.cell.commitment == 0 || nonce.cell.status != 2 || nonce.cell.kind != 1
                    || !Recovered.samePoint(nonce.admission.point, admittedAt.admission.point)
            ) {
                revert W.InvalidRecoveryRewindRecord(hash);
            }
            Runtime.OriginFact memory vesting;
            (v, t, vesting) = A.vestingAt(e, artistId, r.terms.retiredTransitionRecordHash);
            if (!Runtime.before(clock, vesting.point, admittedAt.admission.point)) {
                revert W.InvalidRecoveryRewindRecord(hash);
            }
            admitted = admittedAt.cell;
            n = nonce.cell;
            admission = keccak256(abi.encode(admission, admittedAt, nonce, vesting));
        } else {
            (admitted, admission) = C.standing(e, r);
            // Original51 stores inclusion time rather than the signed authorization deadline.
            n = IStreamArtistOwner(e.identityOwner)
                .replayCell(
                    A.key(
                        e,
                        keccak256("identity_authority.replay.nonce_allocator"),
                        keccak256(abi.encode(artistId, r.nonce))
                    )
                );
            if (
                n.commitment == 0 || n.status != 2 || n.kind != 1
                    || n.touchedRevision != admitted.touchedRevision
            ) {
                revert W.InvalidRecoveryRewindRecord(hash);
            }
            (v, t) = A.vesting(e, artistId, r.terms.retiredTransitionRecordHash);
        }
        (address prior, bytes32 guardian, uint64 tail) = _standingTerms(e, v);
        if (
            prior != r.terms.revokedAddress || v.oldAddress != prior || tail < 30 days
                || uint256(t.postWindowEndsAt) + tail > r.signedAt
                || (!source.imported && admitted.touchedRevision <= v.ownerRevision)
        ) revert W.InvalidRecoveryRewindRecord(hash);
        // Later retirements and later compromise markers do not erase this original admission.
        // The selector resolves its exact retirement scope against the current standing inventory.
        f.selected.originalDataHash = keccak256(abi.encode(r));
        f.selected.nonce = r.nonce;
        f.selected.admissionProof = keccak256(abi.encode(admission, n, v, t, prior, guardian, tail));
        f.transition = t;
        f.admissionRevision = admitted.touchedRevision;
        f.authorityClass = r.authorityClass;
        f.eligible = true;
        f.account = r.terms.revokedAddress;
        f.retirementHash = r.terms.retiredTransitionRecordHash;
        f.valueHash = r.terms.reasonHash;
    }

    function _standingTerms(W.EnvironmentV3 memory e, V.Snapshot memory v)
        private
        view
        returns (address prior, bytes32 guardian, uint64 tail)
    {
        if (v.operationId == 32) {
            R.RotationRecord memory r =
                IStreamArtistRotationReads(e.identityOwner).rotationRecord(v.transitionRecordHash);
            if (r.recordHash != v.transitionRecordHash || r.terms.artistId != v.artistId) {
                revert W.InvalidRecoveryRewindRecord(v.transitionRecordHash);
            }
            return (r.terms.oldAddress, r.guardianSetRecordHash, r.standingTail);
        }
        if (v.operationId == 35) {
            return IStreamArtistIdentityRecoveryOwner(e.identityOwner)
                .recoveryTransitionStanding(v.transitionRecordHash);
        }
        if (v.operationId == 40) {
            return IStreamArtistEstateOwner(e.identityOwner)
                .estateTransitionStanding(v.transitionRecordHash);
        }
        if (v.operationId == 43) {
            return IStreamArtistDormancyOwner(e.identityOwner)
                .dormancyTransitionStanding(v.transitionRecordHash);
        }
        revert W.InvalidRecoveryRewindRecord(v.transitionRecordHash);
    }
}

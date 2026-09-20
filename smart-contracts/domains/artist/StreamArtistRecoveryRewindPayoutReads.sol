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
    StreamArtistSuccessionTypes as S
} from "../../interfaces/stream/artist/StreamArtistSuccessionTypes.sol";
import {
    StreamArtistIdentityDismissalTypes as D
} from "../../interfaces/stream/artist/StreamArtistIdentityDismissalTypes.sol";
import {
    StreamArtistGuardianVestingTypes as V
} from "../../interfaces/stream/artist/StreamArtistGuardianVestingTypes.sol";
import {
    IStreamArtistNativeReceipts,
    StreamArtistHistoryTypes as N
} from "../../interfaces/stream/artist/IStreamArtistHistory.sol";
import { IStreamArtistOwner } from "../../interfaces/stream/artist/IStreamArtistOwner.sol";
import {
    IStreamArtistIdentityOwner
} from "../../interfaces/stream/artist/IStreamArtistIdentityOwner.sol";
import {
    IStreamArtistSuccessionReads
} from "../../interfaces/stream/artist/IStreamArtistSuccessionRecords.sol";
import {
    IStreamArtistIdentityRevisionReads,
    StreamArtistIdentityRevisionTypes as Doc
} from "../../interfaces/stream/artist/IStreamArtistIdentityRevision.sol";
import {
    IStreamArtistStewardSanctionGrant as Grant
} from "../../interfaces/stream/artist/IStreamArtistStewardSanctionGrant.sol";
import {
    IStreamArtistRotationReads
} from "../../interfaces/stream/artist/IStreamArtistRotation.sol";
import {
    IStreamArtistIdentityDismissalOwner
} from "../../interfaces/stream/artist/IStreamArtistIdentityDismissal.sol";
import {
    IStreamArtistPayoutOwner
} from "../../interfaces/stream/artist/IStreamArtistPayoutOwner.sol";
import {
    IStreamArtistPayoutTransitionOwner
} from "../../interfaces/stream/artist/IStreamArtistPayoutTransitionOwner.sol";
import {
    IStreamArtistPayoutResolutionOwner
} from "../../interfaces/stream/artist/IStreamArtistPayoutResolutionOwner.sol";
import {
    IStreamArtistIdentityRecoveryOwnerV3
} from "../../interfaces/stream/artist/IStreamArtistIdentityRecoveryV3.sol";
import {
    IStreamArtistRecoveryRewindEvidence
} from "../../interfaces/stream/artist/IStreamArtistRecoveryRewindEvidence.sol";
import {
    IStreamArtistIdentityRecoveryOwner
} from "../../interfaces/stream/artist/IStreamArtistIdentityRecovery.sol";
import {
    IStreamArtistEstateOwner
} from "../../interfaces/stream/artist/IStreamArtistEstateOwner.sol";
import {
    IStreamArtistDormancyOwner
} from "../../interfaces/stream/artist/IStreamArtistDormancy.sol";
import { StreamArtistHashes as H } from "./StreamArtistHashes.sol";
import { StreamArtistSuccessionHashes as SH } from "./StreamArtistSuccessionHashes.sol";
import { StreamArtistRotationHashes as RH } from "./StreamArtistRotationHashes.sol";
import {
    StreamArtistRecoveryRewindAdmission as A
} from "./StreamArtistRecoveryRewindAdmission.sol";
import {
    StreamArtistRecoveryRewindContinuations as C
} from "./StreamArtistRecoveryRewindContinuations.sol";

import { StreamArtistRecoveryRewindRecordReads } from "./StreamArtistRecoveryRewindRecordReads.sol";

/// @notice Original op18 facts, split from the six-family reader without changing admission checks.
library StreamArtistRecoveryRewindPayoutReads {
    function payout(W.EnvironmentV3 memory e, bytes32 artistId, bytes32 hash)
        public
        view
        returns (StreamArtistRecoveryRewindRecordReads.Facts memory f)
    {
        (W.PayoutOriginalV3 memory r, bytes32 evidenceHash) = _payoutOriginal(e, hash);
        T.PayoutDesignation memory stored =
            IStreamArtistPayoutOwner(e.payoutOwner).designationRecord(hash);
        if (
            r.recordHash != hash || stored.artistId != artistId || r.signer == address(0)
                || r.terms.payoutAccount == address(0) || r.signedAt == 0
                || r.signedAt > block.timestamp || (r.authorityClass != 1 && r.authorityClass != 3)
                || keccak256(abi.encode(stored)) != keccak256(abi.encode(r.terms))
                || H.payoutRecordForAuthority(
                        A.hashes(e), r.terms, r.signer, r.authorityClass, r.nonce, r.signedAt
                    ) != hash
        ) revert W.InvalidRecoveryRewindRecord(hash);
        T.ReplayCell memory n = A.nonce(
            e,
            artistId,
            r.nonce,
            H.payoutDigest(A.hashes(e), r.terms, T.Authorization(r.nonce, r.signedAt, new bytes(0)))
        );
        if (r.terms.previousDesignationRecordHash != 0) {
            T.PayoutDesignation memory previous = IStreamArtistPayoutOwner(e.payoutOwner)
                .designationRecord(r.terms.previousDesignationRecordHash);
            if (
                previous.artistId != artistId || previous.payoutAccount == address(0)
                    || previous.payoutAccount == r.terms.payoutAccount
            ) revert W.InvalidRecoveryRewindRecord(hash);
        }
        f.selected.originalDataHash = keccak256(abi.encode(stored, r, evidenceHash));
        f.selected.nonce = r.nonce;
        f.association = IStreamArtistPayoutTransitionOwner(e.payoutOwner)
            .payoutDesignationProvisionalAssociation(hash);
        f.admissionRevision = n.touchedRevision;
        f.authorityClass = r.authorityClass;
        f.previousRecordHash = r.terms.previousDesignationRecordHash;
        f.account = r.terms.payoutAccount;
        f.abandonmentHash =
            IStreamArtistPayoutResolutionOwner(e.payoutOwner).payoutAbandonment(hash);
        _association(e, artistId, r.signer, f);
        bytes32 abandonedProof;
        if (f.abandonmentHash != 0) {
            (D.Record memory d, T.ReplayCell memory cell) = A.dismissal(e, f.abandonmentHash);
            D.Closure memory c = IStreamArtistIdentityDismissalOwner(e.identityOwner)
                .identityTransitionClosure(artistId, f.association.transitionRecordHash);
            if (
                d.terms.artistId != artistId || !c.abandoned
                    || c.dismissalRecordHash != f.abandonmentHash
                    || f.association.transitionRecordHash == 0
                    || c.windowEndsAt != f.association.windowEndsAt
                    || cell.touchedRevision <= n.touchedRevision
            ) revert W.InvalidRecoveryRewindRecord(hash);
            abandonedProof = keccak256(abi.encode(d, cell, c));
        }
        f.selected.admissionProof =
            keccak256(abi.encode(f.selected.admissionProof, n, evidenceHash, abandonedProof));
        bytes32 continuationProof = C.payout(e, r, n);
        if (continuationProof != 0) {
            f.selected.admissionProof = keccak256(
                abi.encode(
                    keccak256("6529STREAM_ARTIST_RECOVERY_PAYOUT_RECORD_ADMISSION_V3"),
                    f.selected.admissionProof,
                    continuationProof
                )
            );
        }
    }

    function _association(
        W.EnvironmentV3 memory e,
        bytes32 artistId,
        address signer,
        StreamArtistRecoveryRewindRecordReads.Facts memory f
    ) private view {
        (f.transition, f.eligible, f.selected.admissionProof) = A.association(
            e, artistId, f.association, signer, f.authorityClass, f.admissionRevision
        );
    }

    function _payoutOriginal(W.EnvironmentV3 memory e, bytes32 hash)
        private
        view
        returns (W.PayoutOriginalV3 memory r, bytes32 evidenceHash)
    {
        (address target, bytes32 pin) =
            IStreamArtistIdentityRecoveryOwnerV3(e.identityOwner).recoveryRewindEvidenceBinding();
        if (target.code.length == 0 || pin == 0 || target.codehash != pin) {
            revert W.RecoveryRewindDependencyChanged(target);
        }
        IStreamArtistRecoveryRewindEvidence p = IStreamArtistRecoveryRewindEvidence(target);
        if (
            p.owner() != e.identityOwner || p.payoutOwner() != e.payoutOwner
                || p.artistRegistry() != e.registry || p.deploymentChainId() != e.chainId
                || p.coordinator() != e.coordinator || p.archive() != e.archive
                || p.core() != e.core || p.mintManager() != e.manager
        ) revert W.RecoveryRewindDependencyChanged(target);
        bytes32 identityPin;
        bytes32 payoutPin;
        (r, evidenceHash, identityPin, payoutPin) = p.payoutOriginalV3(hash);
        if (
            identityPin != e.identityCodeHash || payoutPin != e.payoutCodeHash || evidenceHash == 0
                || evidenceHash != W.payoutOriginalHash(e, r) || r.recordHash != hash
        ) revert W.InvalidRecoveryPayoutOriginal(hash);
    }
}

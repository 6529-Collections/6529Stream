// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { StreamArtistGuardianHistory as History } from "./StreamArtistGuardianHistory.sol";
import { StreamArtistRotationState as RotationState } from "./StreamArtistRotationState.sol";
import { StreamArtistRotationHashes } from "./StreamArtistRotationHashes.sol";
import { StreamArtistHashes } from "./StreamArtistHashes.sol";
import { StreamArtistLivingRecoveryReads as Living } from "./StreamArtistLivingRecoveryReads.sol";
import {
    StreamArtistGuardianHistoryTypes as GH
} from "../../interfaces/stream/artist/StreamArtistGuardianHistoryTypes.sol";
import {
    StreamArtistGuardianVestingTypes as V
} from "../../interfaces/stream/artist/StreamArtistGuardianVestingTypes.sol";
import {
    StreamArtistRotationTypes as R
} from "../../interfaces/stream/artist/StreamArtistRotationTypes.sol";
import {
    StreamArtistOnboardingTypes as T
} from "../../interfaces/stream/artist/StreamArtistOnboardingTypes.sol";
import {
    StreamArtistIdentityRecoveryOperationTypes as Recovery
} from "../../interfaces/stream/artist/StreamArtistIdentityRecoveryOperationTypes.sol";

/// @notice Original estate guardian prefix and later admitted successor guardian records.
/// @dev The caller first authenticates the original op40 vesting, current cause and unchanged
/// authority plan. This library does not grant recovery authority or reauthorize historical op28.
library StreamArtistRecoveryEstateGuardians {
    function prefix(
        History.State storage history,
        RotationState.State storage rotations,
        StreamArtistHashes.Environment memory environment,
        bytes32 artistId,
        uint64 count,
        V.Snapshot memory vesting
    ) public view returns (GH.Head memory current) {
        current = History.requireComplete(history, artistId, count);
        GH.Head memory saved = vesting.guardians;
        if (
            vesting.artistId != artistId || vesting.operationId != 40 || vesting.authorityClass != 3
                || vesting.transitionRecordHash == 0 || vesting.commitment == 0
                || vesting.ownerRevision == 0 || vesting.newAddress == address(0)
                || current.count < saved.count || vesting.ownerRevision <= saved.ownerRevision
        ) revert Recovery.UnsupportedIdentityRecoveryProfile(artistId);
        if (saved.count == 0) {
            if (saved.ownerRevision != 0 || saved.commitment != 0) {
                revert Recovery.UnsupportedIdentityRecoveryProfile(artistId);
            }
            return current;
        }
        bytes32 last = history.records[artistId][saved.count];
        R.GuardianRecord memory record = rotations.guardians[last];
        GH.Entry memory entry = _record(history, environment, artistId, current, record);
        if (
            entry.index != saved.count || entry.ownerRevision != saved.ownerRevision
                || entry.commitment != saved.commitment
                || entry.ownerRevision >= vesting.ownerRevision || record.authorityClass != 1
        ) revert Recovery.UnsupportedIdentityRecoveryProfile(artistId);
    }

    function guardian(
        History.State storage history,
        RotationState.State storage rotations,
        StreamArtistHashes.Environment memory environment,
        bytes32 artistId,
        uint64 count,
        V.Snapshot memory vesting,
        uint64 originalWindowEndsAt
    ) public view returns (R.GuardianRecord memory g) {
        GH.Head memory current = prefix(history, rotations, environment, artistId, count, vesting);
        bytes32 head = RotationState.operativeGuardian(rotations, artistId);
        if (head == 0) {
            if (
                current.count != 0 || rotations.stableGuardian[artistId] != 0
                    || rotations.provisionalGuardian[artistId] != 0
            ) {
                revert Recovery.UnsupportedIdentityRecoveryProfile(artistId);
            }
            return g;
        }
        g = rotations.guardians[head];
        if (g.recordHash != head) revert Recovery.UnsupportedIdentityRecoveryProfile(artistId);
        GH.Entry memory entry = _record(history, environment, artistId, current, g);
        if (g.authorityClass == 1) {
            if (
                entry.index > vesting.guardians.count
                    || entry.ownerRevision >= vesting.ownerRevision
                    || !_livingAssociation(rotations, environment, artistId, vesting, g, entry)
            ) {
                revert Recovery.UnsupportedIdentityRecoveryProfile(artistId);
            }
        } else if (g.authorityClass == 3) {
            if (
                entry.index <= vesting.guardians.count
                    || entry.ownerRevision <= vesting.ownerRevision
                    || g.signer != vesting.newAddress
            ) {
                revert Recovery.UnsupportedIdentityRecoveryProfile(artistId);
            }
            if (g.provisional.transitionRecordHash == 0) {
                if (g.provisional.windowEndsAt != 0) {
                    revert Recovery.UnsupportedIdentityRecoveryProfile(artistId);
                }
            } else if (
                g.provisional.transitionRecordHash != vesting.transitionRecordHash
                    || g.provisional.windowEndsAt != originalWindowEndsAt
            ) {
                revert Recovery.UnsupportedIdentityRecoveryProfile(artistId);
            }
        } else {
            revert Recovery.UnsupportedIdentityRecoveryProfile(artistId);
        }
        if (!RotationState.eligible(rotations, artistId, g.provisional)) {
            revert Recovery.UnsupportedIdentityRecoveryProfile(artistId);
        }
    }

    /// @dev Caller authenticates the exact original op40/terminal op32 pair before this read.
    function afterRotation(
        History.State storage history,
        RotationState.State storage rotations,
        StreamArtistHashes.Environment memory environment,
        bytes32 artistId,
        uint64 count,
        V.Snapshot memory origin,
        uint64 originalWindowEndsAt,
        V.Snapshot memory terminal,
        uint64 terminalWindowEndsAt
    ) public view returns (R.GuardianRecord memory g) {
        GH.Head memory current = prefix(history, rotations, environment, artistId, count, origin);
        bytes32 head = RotationState.operativeGuardian(rotations, artistId);
        if (head == 0) {
            return guardian(
                history, rotations, environment, artistId, count, origin, originalWindowEndsAt
            );
        }
        g = rotations.guardians[head];
        if (g.recordHash != head) revert Recovery.UnsupportedIdentityRecoveryProfile(artistId);
        GH.Entry memory entry = _record(history, environment, artistId, current, g);
        if (g.authorityClass == 1) {
            if (
                entry.index > terminal.guardians.count
                    || entry.ownerRevision >= terminal.ownerRevision
                    || g.signedAt > terminal.executedAt
            ) revert Recovery.UnsupportedIdentityRecoveryProfile(artistId);
            return guardian(
                history, rotations, environment, artistId, count, origin, originalWindowEndsAt
            );
        }
        if (entry.index <= terminal.guardians.count) {
            if (
                g.authorityClass != 3 || entry.index <= origin.guardians.count
                    || entry.ownerRevision <= origin.ownerRevision
                    || entry.ownerRevision >= terminal.ownerRevision
                    || g.signedAt < origin.executedAt || g.signedAt > terminal.executedAt
                    || !_priorEstateAssociation(
                        rotations, environment, artistId, origin, originalWindowEndsAt, g
                    ) || !RotationState.eligible(rotations, artistId, g.provisional)
            ) {
                revert Recovery.UnsupportedIdentityRecoveryProfile(artistId);
            }
            return g;
        }
        if (
            g.authorityClass != 3 || g.signer != terminal.newAddress
                || entry.index <= terminal.guardians.count
                || entry.ownerRevision <= terminal.ownerRevision || g.signedAt < terminal.executedAt
                || (g.provisional.transitionRecordHash == 0
                        ? g.provisional.windowEndsAt != 0
                        : g.provisional.transitionRecordHash != terminal.transitionRecordHash
                        || g.provisional.windowEndsAt != terminalWindowEndsAt)
                || !RotationState.eligible(rotations, artistId, g.provisional)
        ) revert Recovery.UnsupportedIdentityRecoveryProfile(artistId);
    }

    function _priorEstateAssociation(
        RotationState.State storage rotations,
        StreamArtistHashes.Environment memory e,
        bytes32 artistId,
        V.Snapshot memory origin,
        uint64 originalWindowEndsAt,
        R.GuardianRecord memory g
    ) private view returns (bool) {
        R.ProvisionalAssociation memory a = g.provisional;
        if (a.transitionRecordHash == 0) return a.windowEndsAt == 0;
        if (a.transitionRecordHash == origin.transitionRecordHash) {
            return g.signer == origin.newAddress && a.windowEndsAt == originalWindowEndsAt;
        }
        R.RotationRecord memory r = rotations.rotations[a.transitionRecordHash];
        return r.recordHash == a.transitionRecordHash && r.terms.artistId == artistId
            && r.terms.oldAddress != address(0) && r.terms.newAddress == g.signer
            && r.terms.oldAddress != r.terms.newAddress && r.transition.artistId == artistId
            && r.transition.recordHash == r.recordHash && r.transition.phase == 2
            && r.transition.executedAt >= origin.executedAt && r.transition.executedAt <= g.signedAt
            && g.signedAt < a.windowEndsAt && r.transition.postWindowEndsAt == a.windowEndsAt
            && StreamArtistRotationHashes.rotationRecord(
                e, r.terms, r.oldNonce, r.transition.stagedAt, r.transition.contestEndsAt
            ) == r.recordHash;
    }

    function _livingAssociation(
        RotationState.State storage rotations,
        StreamArtistHashes.Environment memory e,
        bytes32 artistId,
        V.Snapshot memory estate,
        R.GuardianRecord memory g,
        GH.Entry memory entry
    ) private view returns (bool) {
        R.ProvisionalAssociation memory a = g.provisional;
        if (a.transitionRecordHash == 0) return a.windowEndsAt == 0;
        if (estate.previousTransitionRecordHash == 0 || estate.previousCommitment == 0) {
            return false;
        }
        R.RotationRecord memory r = rotations.rotations[a.transitionRecordHash];
        if (r.recordHash == 0) {
            // A retained class1 guardian may have been admitted during an original35 window,
            // including an older recovery whose association survived a later living recovery.
            Living.Facts memory recovered =
                Living.read(address(this), e.registry, e.chainId, artistId, a.transitionRecordHash);
            V.Snapshot memory v = recovered.vesting;
            return v.newAddress == g.signer && v.executedAt <= g.signedAt
                && g.signedAt < a.windowEndsAt
                && recovered.transition.postWindowEndsAt == a.windowEndsAt
                && v.executedAt <= estate.executedAt && v.ownerRevision < estate.ownerRevision
                && v.ownerRevision < entry.ownerRevision && v.guardians.count < entry.index
                && RotationState.eligible(rotations, artistId, a);
        }
        return r.recordHash == a.transitionRecordHash && r.terms.artistId == artistId
            && r.terms.oldAddress != address(0) && r.terms.newAddress == g.signer
            && r.terms.oldAddress != r.terms.newAddress && r.transition.artistId == artistId
            && r.transition.recordHash == r.recordHash && r.transition.phase == 2
            && r.transition.executedAt != 0 && r.transition.executedAt <= g.signedAt
            && g.signedAt < a.windowEndsAt && r.transition.postWindowEndsAt == a.windowEndsAt
            && StreamArtistRotationHashes.rotationRecord(
                e, r.terms, r.oldNonce, r.transition.stagedAt, r.transition.contestEndsAt
            ) == r.recordHash && RotationState.eligible(rotations, artistId, a);
    }

    function _record(
        History.State storage history,
        StreamArtistHashes.Environment memory environment,
        bytes32 artistId,
        GH.Head memory current,
        R.GuardianRecord memory g
    ) private view returns (GH.Entry memory entry) {
        entry = history.entries[g.recordHash];
        if (
            g.recordHash == 0 || g.terms.artistId != artistId || g.signer == address(0)
                || g.signedAt == 0 || g.terms.guardians.length > 8
                || g.terms.minContestSeconds > 30 days || entry.artistId != artistId
                || entry.recordHash != g.recordHash || entry.index == 0
                || entry.index > current.count || entry.ownerRevision == 0
                || entry.ownerRevision > current.ownerRevision || entry.commitment == 0
                || entry.recordDataHash != keccak256(abi.encode(g))
                || history.records[artistId][entry.index] != g.recordHash
                || StreamArtistRotationHashes.guardianRecord(
                        environment, g.terms, T.Authorization(g.nonce, g.signedAt, bytes(""))
                    ) != g.recordHash
        ) revert Recovery.UnsupportedIdentityRecoveryProfile(artistId);
    }
}

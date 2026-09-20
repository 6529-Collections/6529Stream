// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import { StreamArtistLivingRecoveryReads as Living } from "./StreamArtistLivingRecoveryReads.sol";
import {
    IStreamArtistIdentityRecoveryOwner
} from "../../interfaces/stream/artist/IStreamArtistIdentityRecovery.sol";

import { StreamArtistGuardianHistory as History } from "./StreamArtistGuardianHistory.sol";
import { StreamArtistRotationState as RotationState } from "./StreamArtistRotationState.sol";
import { StreamArtistRotationHashes } from "./StreamArtistRotationHashes.sol";
import { StreamArtistHashes } from "./StreamArtistHashes.sol";
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

import {
    StreamArtistRecoveredIdentityRuntime as Recovered
} from "./StreamArtistRecoveredIdentityRuntime.sol";
import {
    StreamArtistRecoveredRuntimeReads as Runtime
} from "./StreamArtistRecoveredRuntimeReads.sol";
import {
    StreamArtistRecoveredHydrationState as Imported
} from "./StreamArtistRecoveredHydrationState.sol";

/// @notice Original dormancy guardian prefix and later admitted designated-successor records.
/// @dev The caller first authenticates the original op43 vesting, current cause and unchanged
/// authority plan. This library does not grant recovery authority or reauthorize historical op28.
library StreamArtistRecoveryDormancyGuardians {
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
        if (Imported.commitment() != 0) {
            Recovered.vesting(
                Recovered.load(address(this), environment.registry, environment.chainId), vesting
            );
        }
        if (
            vesting.artistId != artistId || vesting.operationId != 43 || vesting.authorityClass != 3
                || vesting.transitionRecordHash == 0 || vesting.commitment == 0
                || vesting.ownerRevision == 0 || vesting.newAddress == address(0)
                || current.count < saved.count
                || (Imported.commitment() == 0 && vesting.ownerRevision <= saved.ownerRevision)
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
                || entry.commitment != saved.commitment || !_before(environment, entry, vesting)
                || record.authorityClass != 1
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
                entry.index > vesting.guardians.count || !_before(environment, entry, vesting)
                    || !_livingAssociation(rotations, environment, artistId, vesting, g)
            ) {
                revert Recovery.UnsupportedIdentityRecoveryProfile(artistId);
            }
        } else if (g.authorityClass == 3) {
            if (
                entry.index <= vesting.guardians.count || !_after(environment, entry, vesting)
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
                entry.index > terminal.guardians.count || !_before(environment, entry, terminal)
                    || g.signedAt > terminal.executedAt
            ) revert Recovery.UnsupportedIdentityRecoveryProfile(artistId);
            return guardian(
                history, rotations, environment, artistId, count, origin, originalWindowEndsAt
            );
        }
        if (entry.index <= terminal.guardians.count) {
            if (
                g.authorityClass != 3 || entry.index <= origin.guardians.count
                    || !_after(environment, entry, origin) || !_before(environment, entry, terminal)
                    || g.signedAt < origin.executedAt || g.signedAt > terminal.executedAt
                    || !_priorRotationAssociation(
                        rotations, environment, artistId, origin, originalWindowEndsAt, g
                    ) || !RotationState.eligible(rotations, artistId, g.provisional)
            ) {
                revert Recovery.UnsupportedIdentityRecoveryProfile(artistId);
            }
            return g;
        }
        if (
            g.authorityClass != 3 || g.signer != terminal.newAddress
                || entry.index <= terminal.guardians.count || !_after(environment, entry, terminal)
                || g.signedAt < terminal.executedAt
                || (g.provisional.transitionRecordHash == 0
                        ? g.provisional.windowEndsAt != 0
                        : g.provisional.transitionRecordHash != terminal.transitionRecordHash
                        || g.provisional.windowEndsAt != terminalWindowEndsAt)
                || !RotationState.eligible(rotations, artistId, g.provisional)
        ) revert Recovery.UnsupportedIdentityRecoveryProfile(artistId);
    }

    function _priorRotationAssociation(
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
                _original(e, 29, artistId, r.recordHash),
                r.terms,
                r.oldNonce,
                r.transition.stagedAt,
                r.transition.contestEndsAt
            ) == r.recordHash;
    }

    function _livingAssociation(
        RotationState.State storage rotations,
        StreamArtistHashes.Environment memory e,
        bytes32 artistId,
        V.Snapshot memory estate,
        R.GuardianRecord memory g
    ) private view returns (bool) {
        R.ProvisionalAssociation memory a = g.provisional;
        if (a.transitionRecordHash == 0) return a.windowEndsAt == 0;
        if (estate.previousTransitionRecordHash == 0 || estate.previousCommitment == 0) {
            return false;
        }
        // A retained living guardian may precede more than one admitted living recovery.
        // Authenticate its own saved operation35; today's latest recovery is not its signer.
        if (
            IStreamArtistIdentityRecoveryOwner(address(this))
                .identityRecoveryRecord(a.transitionRecordHash)
                .recordHash != 0
        ) {
            Living.Facts memory living = Living.read(
                address(this), e.registry, e.chainId, artistId, a.transitionRecordHash
            );
            return living.record.fields.newAddress == g.signer
                && living.record.fields.recoveredAt <= g.signedAt
                && _vestingBefore(e, living.vesting, estate)
                && living.vesting.guardians.count <= estate.guardians.count
                && g.signedAt < a.windowEndsAt
                && living.transition.postWindowEndsAt == a.windowEndsAt
                && RotationState.eligible(rotations, artistId, a);
        }
        R.RotationRecord memory r = rotations.rotations[a.transitionRecordHash];
        return r.recordHash == a.transitionRecordHash && r.terms.artistId == artistId
            && r.terms.oldAddress != address(0) && r.terms.newAddress == g.signer
            && r.terms.oldAddress != r.terms.newAddress && r.transition.artistId == artistId
            && r.transition.recordHash == r.recordHash && r.transition.phase == 2
            && r.transition.executedAt != 0 && r.transition.executedAt <= g.signedAt
            && g.signedAt < a.windowEndsAt && r.transition.postWindowEndsAt == a.windowEndsAt
            && StreamArtistRotationHashes.rotationRecord(
                _original(e, 29, artistId, r.recordHash),
                r.terms,
                r.oldNonce,
                r.transition.stagedAt,
                r.transition.contestEndsAt
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
        StreamArtistHashes.Environment memory original = environment;
        if (Imported.commitment() != 0) {
            original = Recovered.hashes(
                Recovered.guardian(
                    Recovered.load(address(this), environment.registry, environment.chainId),
                    entry,
                    g
                )
                .environment
            );
        }
        if (
            g.recordHash == 0 || g.terms.artistId != artistId || g.signer == address(0)
                || g.signedAt == 0 || g.terms.guardians.length > 8
                || g.terms.minContestSeconds > 30 days || entry.artistId != artistId
                || entry.recordHash != g.recordHash || entry.index == 0
                || entry.index > current.count || entry.ownerRevision == 0
                || (Imported.commitment() == 0 && entry.ownerRevision > current.ownerRevision)
                || entry.commitment == 0 || entry.recordDataHash != keccak256(abi.encode(g))
                || history.records[artistId][entry.index] != g.recordHash
                || StreamArtistRotationHashes.guardianRecord(
                        original, g.terms, T.Authorization(g.nonce, g.signedAt, bytes(""))
                    ) != g.recordHash
        ) revert Recovery.UnsupportedIdentityRecoveryProfile(artistId);
    }

    function _original(
        StreamArtistHashes.Environment memory e,
        uint16 operation,
        bytes32 artistId,
        bytes32 record
    ) private view returns (StreamArtistHashes.Environment memory) {
        if (Imported.commitment() == 0) return e;
        return Recovered.hashes(
            Recovered.nativeFact(
                Recovered.load(address(this), e.registry, e.chainId), operation, artistId, record
            )
            .environment
        );
    }

    function _before(
        StreamArtistHashes.Environment memory e,
        GH.Entry memory entry,
        V.Snapshot memory v
    ) private view returns (bool) {
        if (Imported.commitment() == 0) {
            return entry.ownerRevision < v.ownerRevision;
        }
        Runtime.Context memory clock = Recovered.load(address(this), e.registry, e.chainId);
        return Runtime.before(
            clock, Recovered.guardianEntry(clock, entry).point, Recovered.vesting(clock, v).point
        );
    }

    function _after(
        StreamArtistHashes.Environment memory e,
        GH.Entry memory entry,
        V.Snapshot memory v
    ) private view returns (bool) {
        if (Imported.commitment() == 0) {
            return entry.ownerRevision > v.ownerRevision;
        }
        Runtime.Context memory clock = Recovered.load(address(this), e.registry, e.chainId);
        return Runtime.before(
            clock, Recovered.vesting(clock, v).point, Recovered.guardianEntry(clock, entry).point
        );
    }

    function _vestingBefore(
        StreamArtistHashes.Environment memory e,
        V.Snapshot memory a,
        V.Snapshot memory b
    ) private view returns (bool) {
        if (Imported.commitment() == 0) {
            return a.ownerRevision < b.ownerRevision;
        }
        Runtime.Context memory clock = Recovered.load(address(this), e.registry, e.chainId);
        return Runtime.before(
            clock, Recovered.vesting(clock, a).point, Recovered.vesting(clock, b).point
        );
    }
}

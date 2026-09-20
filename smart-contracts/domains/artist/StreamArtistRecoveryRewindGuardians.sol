// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    StreamArtistIdentityRecoveryState as Recovery
} from "./StreamArtistIdentityRecoveryState.sol";
import { StreamArtistRotationState as Rotations } from "./StreamArtistRotationState.sol";
import { StreamArtistGuardianHistory as History } from "./StreamArtistGuardianHistory.sol";
import { StreamArtistIdentityState as Identity } from "./StreamArtistIdentityState.sol";
import {
    StreamArtistRecoveryAdjudicationHistory as Ancestry
} from "./StreamArtistRecoveryAdjudicationHistory.sol";
import {
    StreamArtistRecoveryRewindEvidenceReads as Evidence
} from "./StreamArtistRecoveryRewindEvidenceReads.sol";
import { StreamArtistRotationHashes } from "./StreamArtistRotationHashes.sol";
import {
    StreamArtistRecoveryEvidenceTypes as E
} from "../../interfaces/stream/artist/StreamArtistRecoveryEvidenceTypes.sol";
import {
    StreamArtistGuardianHistoryTypes as GH
} from "../../interfaces/stream/artist/StreamArtistGuardianHistoryTypes.sol";
import {
    StreamArtistGuardianVestingTypes as V
} from "../../interfaces/stream/artist/StreamArtistGuardianVestingTypes.sol";
import {
    StreamArtistGuardianAppealTypes as Appeal
} from "../../interfaces/stream/artist/StreamArtistGuardianAppealTypes.sol";
import {
    StreamArtistIdentityRecoveryOperationTypes as I
} from "../../interfaces/stream/artist/StreamArtistIdentityRecoveryOperationTypes.sol";
import {
    StreamArtistRotationTypes as R
} from "../../interfaces/stream/artist/StreamArtistRotationTypes.sol";
import {
    StreamArtistIdentityDismissalTypes as D
} from "../../interfaces/stream/artist/StreamArtistIdentityDismissalTypes.sol";
import {
    StreamArtistOnboardingTypes as T
} from "../../interfaces/stream/artist/StreamArtistOnboardingTypes.sol";

/// @notice V3 guardian policy partitions the complete request without changing the original35 hashes.
import {
    StreamArtistRecoveryRewindTypes as W
} from "../../interfaces/stream/artist/StreamArtistRecoveryRewindTypes.sol";
import {
    StreamArtistRecoveryEvidenceReads as OriginalEvidence
} from "./StreamArtistRecoveryEvidenceReads.sol";
import {
    IStreamArtistSuccessionReads
} from "../../interfaces/stream/artist/IStreamArtistSuccessionRecords.sol";
import {
    StreamArtistSuccessionTypes as Succession
} from "../../interfaces/stream/artist/StreamArtistSuccessionTypes.sol";
import { StreamArtistSuccessionHashes } from "./StreamArtistSuccessionHashes.sol";

library StreamArtistRecoveryRewindGuardians {
    struct Facts {
        GH.Head history;
        V.Snapshot cutoff;
        Appeal.Finding[] findings;
        bytes32 requiredRole;
        bytes32 commitment;
    }

    function read(
        Recovery.State storage s,
        Rotations.State storage rotations,
        Identity.OwnerContext memory o,
        W.ResolutionManifestV3 memory manifest,
        bytes32 manifestHash,
        I.Request memory request,
        Ancestry.Facts memory ancestry,
        bytes32[] memory exclusions,
        bytes32 restoredDirective
    ) public view returns (Facts memory f) {
        f.history = History.requireComplete(
            s.guardianHistory, manifest.artistId, s.guardianRecordsSeen[manifest.artistId]
        );
        if (
            s.guardianSupersession.indexedHeads[manifest.artistId].count != f.history.count
                || s.guardianSupersession.indexedHeads[manifest.artistId].historyCommitment
                    != f.history.commitment
        ) revert GH.InvalidGuardianHistory(manifest.artistId);
        f.cutoff = _cutoff(manifest, ancestry);
        if (f.cutoff.transitionRecordHash != 0) _prefix(s, manifest.artistId, f.cutoff, f.history);
        f.findings = new Appeal.Finding[](exclusions.length);
        uint256 required;
        bool protectedPrefix;
        bytes32 previous;
        for (uint256 index; index < exclusions.length; ++index) {
            bytes32 hash = exclusions[index];
            GH.Entry memory entry = s.guardianHistory.entries[hash];
            R.GuardianRecord memory record = rotations.guardians[hash];
            if (
                hash <= previous || entry.recordHash != hash || entry.artistId != manifest.artistId
                    || entry.index == 0 || entry.index > f.history.count || entry.ownerRevision == 0
                    || entry.ownerRevision > f.history.ownerRevision || entry.commitment == 0
                    || s.guardianHistory.records[manifest.artistId][entry.index] != hash
                    || record.recordHash != hash || record.terms.artistId != manifest.artistId
                    || record.signer == address(0)
                    || (record.authorityClass != 1 && record.authorityClass != 3)
                    || entry.recordDataHash != keccak256(abi.encode(record))
                    || s.guardianSupersession.statuses[hash].recoveryRecordHash != 0
                    || StreamArtistRotationHashes.guardianRecord(
                            o.environment,
                            record.terms,
                            T.Authorization(record.nonce, record.signedAt, new bytes(0))
                        ) != hash
            ) revert E.InvalidRecoveryManifest(manifestHash);
            bool afterCutoff = f.cutoff.transitionRecordHash != 0
                && entry.index > f.cutoff.guardians.count
                && entry.ownerRevision > f.cutoff.ownerRevision;
            if (!afterCutoff) protectedPrefix = true;
            if (!afterCutoff && !_provisional(record, entry, ancestry)) {
                if (record.terms.guardians.length == 0) {
                    revert E.InvalidRecoveryManifest(manifestHash);
                }
                f.findings[required++] = Appeal.Finding(hash, record.terms.guardians);
            }
            previous = hash;
        }
        Appeal.Finding[] memory findings = f.findings;
        assembly ("memory-safe") { mstore(findings, required) }
        bytes32 policy;
        if (required != 0) {
            Evidence.AppealEvidence memory appeal =
                Evidence.appeal(o, manifestHash, request.evidenceHash, findings);
            f.requiredRole = Appeal.APPEAL;
            policy = keccak256(abi.encode(appeal));
        } else {
            if (request.evidenceHash != manifest.resolutionEvidenceHash) {
                revert E.InvalidRecoveryManifest(manifestHash);
            }
            f.requiredRole = Appeal.ARBITER;
        }
        // Both sides of the same frozen plan protect every pre-cutoff exclusion, including
        // NONE/provisional ordinary-tier cases. An excluded banning directive remains binding.
        if (protectedPrefix) {
            policy = keccak256(
                abi.encode(
                    policy,
                    OriginalEvidence.requireGuardianDirective(o, manifest.artistId),
                    _restoredDirective(o, manifest.artistId, restoredDirective)
                )
            );
        }
        f.commitment = keccak256(
            abi.encode(
                keccak256("6529STREAM_ARTIST_RECOVERY_GUARDIAN_ADJUDICATION_V3"),
                manifestHash,
                f.history,
                f.cutoff,
                f.requiredRole,
                f.findings,
                policy,
                ancestry.historyProof,
                exclusions
            )
        );
    }

    function _restoredDirective(Identity.OwnerContext memory o, bytes32 artistId, bytes32 hash)
        private
        view
        returns (Succession.DirectiveRecord memory saved)
    {
        if (hash == 0) return saved;
        saved = IStreamArtistSuccessionReads(address(this)).estateDirectiveRecord(hash);
        if (
            saved.recordHash != hash || saved.terms.artistId != artistId
                || saved.authorityClass != 1 || saved.signer == address(0)
                || StreamArtistSuccessionHashes.directiveRecord(
                        o.environment,
                        saved.terms,
                        T.Authorization(saved.nonce, saved.signedAt, new bytes(0))
                    ) != hash
        ) {
            revert W.InvalidRecoveryRewindRecord(hash);
        }
        if ((saved.terms.forbiddenCapabilities & 256) != 0) {
            revert Succession.ForbiddenCapability(artistId, 256, hash);
        }
    }

    function _cutoff(W.ResolutionManifestV3 memory manifest, Ancestry.Facts memory a)
        private
        pure
        returns (V.Snapshot memory first)
    {
        if (manifest.basis == E.VestingBasis.NO_CONTESTED_VESTING) {
            if (manifest.contestedVestings.length != 0) {
                revert E.InvalidRecoveryManifest(bytes32(0));
            }
            return first;
        }
        if (manifest.contestedVestings.length == 0) revert E.InvalidRecoveryManifest(bytes32(0));
        uint256 matched;
        // Original members are newest first. Reverse iteration establishes execution order,
        // including same-block vestings, without sorting hashes or trusting caller timestamps.
        for (uint256 cursor = a.members.length; cursor != 0; --cursor) {
            V.Snapshot memory v = a.members[cursor - 1].vesting;
            if (matched == manifest.contestedVestings.length) break;
            E.VestingReference memory ref = manifest.contestedVestings[matched];
            if (v.transitionRecordHash != ref.transitionRecordHash) continue;
            if (v.transitionRecordHash == 0 || v.commitment != ref.vestingCommitment) {
                revert E.InvalidRecoveryManifest(ref.transitionRecordHash);
            }
            if (matched == 0) first = v;
            ++matched;
        }
        if (matched != manifest.contestedVestings.length) {
            revert E.InvalidRecoveryManifest(bytes32(0));
        }
    }

    function _prefix(
        Recovery.State storage s,
        bytes32 artistId,
        V.Snapshot memory cutoff,
        GH.Head memory current
    ) private view {
        GH.Head memory prefix = cutoff.guardians;
        if (prefix.count > current.count || prefix.ownerRevision >= cutoff.ownerRevision) {
            revert GH.InvalidGuardianHistory(artistId);
        }
        if (prefix.count == 0) {
            if (prefix.ownerRevision != 0 || prefix.commitment != 0) {
                revert GH.InvalidGuardianHistory(artistId);
            }
        } else {
            GH.Entry memory tip =
                s.guardianHistory.entries[s.guardianHistory.records[artistId][prefix.count]];
            if (
                tip.artistId != artistId || tip.index != prefix.count
                    || tip.ownerRevision != prefix.ownerRevision
                    || tip.commitment != prefix.commitment || prefix.commitment == 0
            ) revert GH.InvalidGuardianHistory(artistId);
        }
    }

    function _provisional(
        R.GuardianRecord memory record,
        GH.Entry memory entry,
        Ancestry.Facts memory a
    ) private view returns (bool) {
        if (record.provisional.transitionRecordHash == 0) return false;
        for (uint256 index; index < a.members.length; ++index) {
            V.Snapshot memory v = a.members[index].vesting;
            if (v.transitionRecordHash != record.provisional.transitionRecordHash) continue;
            R.TransitionState memory t = a.members[index].transition;
            D.Closure memory closed = a.closures[index];
            if (
                t.recordHash != v.transitionRecordHash || t.artistId != record.terms.artistId
                    || t.phase != 2 || t.executedAt == 0 || t.executedAt != v.executedAt
                    || record.provisional.windowEndsAt != t.postWindowEndsAt
                    || record.signedAt >= t.postWindowEndsAt || record.signer != v.newAddress
                    || record.authorityClass != v.authorityClass
                    || entry.ownerRevision <= v.ownerRevision || entry.index <= v.guardians.count
            ) revert E.InvalidRecoveryManifest(v.transitionRecordHash);
            // An explicit adjudicated closure is not an open provisional association.
            if (closed.dismissalRecordHash != 0) return false;
            return block.timestamp < t.postWindowEndsAt
                || (t.contestedAt != 0 && t.contestedAt < t.postWindowEndsAt);
        }
        revert E.InvalidRecoveryManifest(record.provisional.transitionRecordHash);
    }
}

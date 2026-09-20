// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    StreamArtistRecoveredIdentityHydrationTypes as IH
} from "../../interfaces/stream/artist/StreamArtistRecoveredIdentityHydrationTypes.sol";
import {
    StreamArtistRecoveredHydrationTypes as RH
} from "../../interfaces/stream/artist/StreamArtistRecoveredHydrationTypes.sol";
import {
    StreamArtistOnboardingTypes as T
} from "../../interfaces/stream/artist/StreamArtistOnboardingTypes.sol";
import {
    StreamArtistRecoveryRewindTypes as W
} from "../../interfaces/stream/artist/StreamArtistRecoveryRewindTypes.sol";
import {
    StreamArtistRecoveredIdentityHydrationState as X
} from "./StreamArtistRecoveredIdentityHydrationState.sol";
import {
    StreamArtistRecoveredHydrationState as ProvenanceState
} from "./StreamArtistRecoveredHydrationState.sol";
import {
    StreamArtistRecoveredIdentitySourceFrame as Frame
} from "./StreamArtistRecoveredIdentitySourceFrame.sol";

/// @notice Original principal checks followed, after all other stages, by heads and artifact points.
/// @dev The fixed importer passes the complete canonical Bundle after SourceCodec validation.
/// Linked library calls retain the host's 17 declared roots and storage context.
library StreamArtistRecoveredIdentityImportPrincipal {
    function check(uint256[17] memory roots, bytes32 artistId, bytes calldata canonical)
        public
        view
    {
        IH.Bundle calldata b = Frame.bundle(canonical);
        if (b.artistId != artistId) revert IH.InvalidRecoveredIdentity(artistId);
        _emptyPrincipal(roots, b);
    }

    function finish(
        uint256[17] memory roots,
        bytes calldata canonical,
        RH.OwnerProvenance memory provenance
    ) public {
        IH.Bundle calldata b = Frame.bundle(canonical);
        _heads(roots, b);
        _points(roots, b, provenance);
    }

    function _emptyPrincipal(uint256[17] memory r, IH.Bundle calldata b) private view {
        T.Identity memory empty;
        if (
            keccak256(abi.encode(X.identity(r).identities[b.artistId]))
                    != keccak256(abi.encode(empty))
                || X.identity(r).activeIdentity[b.identity.authorityAddress] != 0
                || (X.identity(r).nextRegistrationNonce != 0
                    && X.identity(r).nextRegistrationNonce != b.nextRegistrationNonce)
                || X.rotations(r).latestTransition[b.artistId] != 0
                || X.rotations(r).latestExecution[b.artistId] != 0
                || X.rotations(r).pending[b.artistId] != 0 || X.recovery(r).latest[b.artistId] != 0
                || X.recovery(r).guardianHistory.heads[b.artistId].count != 0
                || X.recovery(r).guardianHistory.heads[b.artistId].commitment != 0
                || X.recovery(r).guardianHistory.heads[b.artistId].ownerRevision != 0
                || X.recovery(r).guardianRecordsSeen[b.artistId] != 0
                || X.recovery(r).pendingAction[b.artistId] != 0
                || X.recovery(r).vestingHistory.latest[b.artistId] != 0
                || X.recovery(r).guardianSupersession.indexedHeads[b.artistId].count != 0
                || X.recovery(r).guardianSupersession.indexedHeads[b.artistId].historyCommitment
                    != 0 || X.resolutions(r).currentCause[b.artistId] != 0
                || X.resolutions(r).latestResolution[b.artistId] != 0
                || X.resolutions(r).continuationHead[b.artistId] != 0
                || X.contests(r).latest[b.artistId] != 0 || X.estate(r).pending[b.artistId] != 0
                || X.estate(r).authorityActivation[b.artistId] != 0
                || X.estate(r).livingActivity[b.artistId] != 0
                || X.estate(r).delegationEpoch[b.artistId] != 0
                || X.dormancy(r).activation[b.artistId] != 0
                || X.dormancy(r).latestNotice[b.artistId] != 0
                || X.dormancy(r).activity[b.artistId] != 0
                || X.findings(r).activityEpoch[b.artistId] != 0
                || X.findings(r).hasUncancelledFindings[b.artistId]
                || X.rewinds(r).statusCommitments[b.artistId] != 0
                || X.rewinds(r).revisionHead[b.artistId] != 0
                || X.rewinds(r).capabilityHead[b.artistId] != 0
                || X.rotations(r).stableGuardian[b.artistId] != 0
                || X.rotations(r).provisionalGuardian[b.artistId] != 0
                || X.revisions(r).latestRecord[b.artistId] != 0
                || X.revisions(r).pendingRecord[b.artistId] != 0
                || X.succession(r).stableDesignation[b.artistId] != 0
                || X.succession(r).candidateDesignation[b.artistId] != 0
                || X.succession(r).stableDirective[b.artistId] != 0
                || X.succession(r).candidateDirective[b.artistId] != 0
                || X.sanctions(r).stable[b.artistId] != 0
                || X.sanctions(r).candidate[b.artistId] != 0
        ) revert IH.InvalidRecoveredIdentity(b.artistId);
    }

    function _heads(uint256[17] memory r, IH.Bundle calldata b) private {
        bytes32 id = b.artistId;
        X.identity(r).identities[id] = b.identity;
        X.identity(r).activeIdentity[b.identity.authorityAddress] = id;
        X.identity(r).nextRegistrationNonce = b.nextRegistrationNonce;
        X.rotations(r).latestTransition[id] = b.heads.latestTransition;
        X.rotations(r).latestExecution[id] = b.heads.latestExecution;
        X.rotations(r).pending[id] = b.heads.pendingRotation;
        X.contests(r).latest[id] = b.heads.latestContest;
        X.resolutions(r).currentCause[id] = b.heads.currentCause;
        X.resolutions(r).latestResolution[id] = b.heads.latestDismissal;
        X.resolutions(r).continuationHead[id] = b.heads.originalRevisionContinuation;
        X.recovery(r).latest[id] = b.heads.latestRecovery;
        X.recovery(r).pendingAction[id] = b.heads.pendingRecoveryAction;
        X.recovery(r).vestingHistory.latest[id] = b.heads.latestVesting;
        X.estate(r).pending[id] = b.heads.pendingEstate;
        X.estate(r).authorityActivation[id] = b.heads.estateActivation;
        X.dormancy(r).activation[id] = b.heads.dormancyActivation;
        X.dormancy(r).latestNotice[id] = b.heads.latestNotice;
        X.estate(r).livingActivity[id] = b.heads.livingActivity;
        X.dormancy(r).activity[id] = b.heads.dormancyActivity;
        X.findings(r).activityEpoch[id] = b.heads.findingActivity;
        X.findings(r).hasUncancelledFindings[id] = b.heads.hasUncancelledFindings;
        X.estate(r).delegationEpoch[id] = b.heads.delegationEpoch;
        X.recovery(r).guardianRecordsSeen[id] = b.heads.guardianRecordsSeen;
        X.recovery(r).guardianHistory.heads[id] = b.heads.guardianHistory;
        X.recovery(r).guardianSupersession.indexedHeads[id] = b.heads.guardianIndex;
        W.IdentityInventoryV3 memory v = b.heads.inventory;
        X.rotations(r).stableGuardian[id] = v.guardians.stable;
        X.rotations(r).provisionalGuardian[id] = v.guardians.candidate;
        X.succession(r).stableDesignation[id] = v.designations.stable;
        X.succession(r).candidateDesignation[id] = v.designations.candidate;
        X.succession(r).stableDirective[id] = v.directives.stable;
        X.succession(r).candidateDirective[id] = v.directives.candidate;
        X.revisions(r).latestRecord[id] = v.revisions.stable;
        X.revisions(r).pendingRecord[id] = v.revisions.candidate;
        X.sanctions(r).stable[id] = v.sanctionGrants.stable;
        X.sanctions(r).candidate[id] = v.sanctionGrants.candidate;
        X.rewinds(r).revisionHead[id] = v.revisionContinuationHash;
        X.rewinds(r).statusCommitments[id] = v.supersessionStateCommitment;
        X.rewinds(r).capabilityHead[id] = b.heads.capabilityContinuation;
    }

    /// @dev The common worker has already installed the authenticated owner-local prefix.
    /// Keep all occurrences there, but give only unique primary semantic keys an artifact point.
    /// In particular the secondary35 supersession-list hash can recur and is never a record key.
    function _points(uint256[17] memory roots, IH.Bundle calldata b, RH.OwnerProvenance memory p)
        private
    {
        for (uint256 i; i < p.journal.length; ++i) {
            RH.JournalEntry memory j = p.journal[i];
            if (j.receipt.artistId != b.artistId) continue;
            uint16 op = j.receipt.operation;
            bool primary = op == 1 || op == 19 || op == 23 || op == 25 || op == 26 || op == 28
                || op == 29 || op == 31 || op == 33 || op == 36 || op == 37 || op == 38 || op == 41
                || op == 42 || op == 43 || op == 51 || op == 58;
            if (op == 35) {
                primary = X.recovery(roots).records[j.receipt.recordHash].recordHash
                    == j.receipt.recordHash;
            }
            if (!primary) continue;
            bytes32 kind = keccak256(
                abi.encode(keccak256("6529STREAM_ARTIST_RECOVERED_NATIVE_RECORD_V1"), op)
            );
            ProvenanceState.installArtifact(kind, j.receipt.recordHash, j.position.point);
        }
        for (uint256 i; i < b.vestings.length; ++i) {
            ProvenanceState.installArtifact(
                keccak256("identity_authority.hydration.guardian_vesting"),
                b.vestings[i].snapshot.transitionRecordHash,
                b.vestings[i].point
            );
        }
        for (uint256 i; i < b.actions.length; ++i) {
            ProvenanceState.installArtifact(
                keccak256("identity_authority.replay.recovery_preparation"),
                b.actions[i].association.action.actionId,
                b.actions[i].point
            );
        }
        for (uint256 i; i < b.originalContinuations.length; ++i) {
            ProvenanceState.installArtifact(
                keccak256("identity_authority.hydration.dismissal_continuation"),
                b.originalContinuations[i].continuation.continuationHash,
                b.originalContinuations[i].point
            );
        }
        for (uint256 i; i < b.revisionContinuations.length; ++i) {
            ProvenanceState.installArtifact(
                keccak256("identity_authority.hydration.revision_continuation_v3"),
                b.revisionContinuations[i].continuation.continuationHash,
                b.revisionContinuations[i].point
            );
        }
        for (uint256 i; i < b.standingContinuations.length; ++i) {
            ProvenanceState.installArtifact(
                keccak256("identity_authority.hydration.standing_continuation_v3"),
                b.standingContinuations[i].continuation.continuationHash,
                b.standingContinuations[i].point
            );
        }
        for (uint256 i; i < b.capabilityContinuations.length; ++i) {
            ProvenanceState.installArtifact(
                keccak256("identity_authority.hydration.capability_continuation_v3"),
                b.capabilityContinuations[i].continuation.recoveryRecordHash,
                b.capabilityContinuations[i].point
            );
        }
    }
}

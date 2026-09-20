// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import { StreamArtistRecoveryRewindState as Rewind } from "./StreamArtistRecoveryRewindState.sol";
import {
    StreamArtistRecoveryRewindTypes as W
} from "../../interfaces/stream/artist/StreamArtistRecoveryRewindTypes.sol";
import {
    StreamArtistRecoveryRewindContext as Context
} from "./StreamArtistRecoveryRewindContext.sol";
import {
    StreamArtistRecoveryRewindEvidenceReads as Evidence
} from "./StreamArtistRecoveryRewindEvidenceReads.sol";
import { StreamArtistIdentityState as Identity } from "./StreamArtistIdentityState.sol";
import { StreamArtistRotationState as Rotations } from "./StreamArtistRotationState.sol";
import {
    StreamArtistIdentityRevisionState as Revisions
} from "./StreamArtistIdentityRevisionState.sol";
import { StreamArtistSuccessionState as Succession } from "./StreamArtistSuccessionState.sol";
import { StreamArtistStewardSanctionState as Grants } from "./StreamArtistStewardSanctionState.sol";
import {
    StreamArtistIdentityResolutionState as Resolutions
} from "./StreamArtistIdentityResolutionState.sol";

/// @notice Apply one authenticated plan without altering any original record or consumed replay cell.
library StreamArtistRecoveryRewindApply {
    function applyPlan(
        Rewind.State storage s,
        Identity.State storage identity,
        Rotations.State storage rotations,
        Revisions.State storage revisions,
        Succession.State storage succession,
        Grants.State storage grants,
        Resolutions.State storage resolutions,
        Identity.OwnerContext memory o,
        Context.Facts memory f,
        bytes32 actionId,
        bytes32 record,
        uint32 originalCapabilities
    ) public returns (bytes32 commitment) {
        W.EnvironmentV3 memory e = Evidence.environment(o);
        bytes32 id = f.source.manifest.artistId;
        if (
            record == 0 || f.plan.commitment == 0
                || s.actions[actionId].selectionCommitment != f.plan.commitment
        ) {
            revert W.InvalidRecoveryRewindPreparation(actionId);
        }
        bytes32 previous = s.statusCommitments[id];
        for (uint256 i; i < f.source.manifest.supersededRecords.length; ++i) {
            W.RecordReference memory ref = f.source.manifest.supersededRecords[i];
            if (
                ref.kind == W.RecordKind.GUARDIAN_SET || ref.kind == W.RecordKind.PAYOUT_DESIGNATION
            ) continue;
            if (s.statuses[ref.recordHash].recoveryRecordHash != 0) {
                revert W.InvalidRecoveryRewindRecord(ref.recordHash);
            }
            s.statuses[ref.recordHash] =
                W.StatusV3(id, ref.kind, record, actionId, f.plan.commitment);
            previous = keccak256(abi.encode(previous, ref.recordHash, s.statuses[ref.recordHash]));
        }
        s.statusCommitments[id] = keccak256(
            abi.encode(
                keccak256("6529STREAM_ARTIST_RECOVERY_REWIND_IDENTITY_STATUSES_V3"),
                uint16(3),
                e,
                id,
                record,
                actionId,
                f.plan.commitment,
                previous
            )
        );
        succession.stableDesignation[id] = f.plan.designation.operative.recordHash;
        succession.candidateDesignation[id] = f.plan.designation.retainedCandidateRecordHash;
        succession.stableDirective[id] = f.plan.directive.operative.recordHash;
        succession.candidateDirective[id] = f.plan.directive.retainedCandidateRecordHash;
        grants.stable[id] = f.plan.sanctionGrant.operative.recordHash;
        grants.candidate[id] = f.plan.sanctionGrant.retainedCandidateRecordHash;
        bytes32 revision = _revision(s, identity, revisions, e, o.revision + 1, f, actionId, record);
        bytes32 standing =
            _standing(s, rotations, resolutions, e, o.revision + 1, f, actionId, record);
        bytes32 capability =
            _capability(s, identity, succession, e, f, actionId, record, originalCapabilities);
        commitment = keccak256(
            abi.encode(
                keccak256("6529STREAM_ARTIST_RECOVERY_REWIND_IDENTITY_APPLY_V3"),
                uint16(3),
                e,
                id,
                record,
                actionId,
                f.plan,
                s.statusCommitments[id],
                revision,
                standing,
                capability
            )
        );
    }

    function _revision(
        Rewind.State storage s,
        Identity.State storage identity,
        Revisions.State storage revisions,
        W.EnvironmentV3 memory e,
        uint64 revision,
        Context.Facts memory f,
        bytes32 actionId,
        bytes32 record
    ) private returns (bytes32) {
        bytes32 id = f.source.manifest.artistId;
        W.FamilyPointers memory before_ = f.source.selectionBasis.inventory.revisions;
        bytes32 tip = before_.candidate == 0 ? before_.stable : before_.candidate;
        W.FamilySelectionV3 memory selected = f.plan.identityRevision;
        revisions.latestRecord[id] = selected.operative.recordHash;
        revisions.pendingRecord[id] = selected.retainedCandidateRecordHash;
        // A retained provisional child remains occupied. Only explicitly resolving the actual
        // branch tip opens a fresh key; an excluded sibling cannot reset this branch.
        if (
            tip != 0 && tip != selected.operative.recordHash
                && selected.retainedCandidateRecordHash == 0
                && s.statuses[tip].recoveryRecordHash == record
                && s.statuses[tip].kind == W.RecordKind.IDENTITY_REVISION
        ) {
            W.RevisionContinuationV3 memory c;
            c.artistId = id;
            c.recoveryRecordHash = record;
            c.actionId = actionId;
            c.planCommitment = f.plan.commitment;
            c.stableRevisionRecordHash = selected.operative.recordHash;
            c.stableDocumentHash = c.stableRevisionRecordHash == 0
                ? identity.identities[id].identityRecordHash
                : revisions.records[c.stableRevisionRecordHash].revisedRecordHash;
            c.resolvedChildRecordHash = tip;
            c.ownerRevision = revision;
            c.continuationHash = W.revisionContinuationHash(e, c);
            if (s.revisionContinuations[c.continuationHash].continuationHash != 0) {
                revert W.InvalidRecoveryRewindRecord(c.continuationHash);
            }
            s.revisionContinuations[c.continuationHash] = c;
            s.revisionHead[id] = c.continuationHash;
        }
        return keccak256(abi.encode(before_, selected, s.revisionHead[id]));
    }

    function _standing(
        Rewind.State storage s,
        Rotations.State storage rotations,
        Resolutions.State storage resolutions,
        W.EnvironmentV3 memory e,
        uint64 revision,
        Context.Facts memory f,
        bytes32 actionId,
        bytes32 record
    ) private returns (bytes32 result) {
        bytes32 id = f.source.manifest.artistId;
        for (uint256 i; i < f.plan.standing.length; ++i) {
            W.StandingSelectionV3 memory selected = f.plan.standing[i];
            if (
                keccak256(abi.encode(resolutions.standingJudgments[id][selected.priorAddress]))
                    != selected.independentJudgmentHash
            ) {
                revert W.InvalidRecoveryRewindRecord(selected.expectedRevocationRecordHash);
            }
            bytes32 scope = Rewind.standingScope(id, selected.priorAddress, selected.retirementHash);
            // Original35 can itself create a newer retirement of an address that returned.
            // Neither an older51 nor its new status can alter that newer retirement.
            if (rotations.retirement[id][selected.priorAddress] == selected.retirementHash) {
                if (
                    rotations.standingRevocation[id][selected.priorAddress]
                            != selected.expectedRevocationRecordHash
                        || s.standingHeads[scope] != selected.continuationCommitment
                ) {
                    revert W.InvalidRecoveryRewindRecord(selected.expectedRevocationRecordHash);
                }
                bytes32 retained = selected.retainedRevocation.recordHash;
                bytes32 previous = selected.expectedRevocationRecordHash;
                if (retained != previous) {
                    if (previous == 0 || s.statuses[previous].recoveryRecordHash != record) {
                        revert W.InvalidRecoveryRewindRecord(previous);
                    }
                    rotations.standingRevocation[id][selected.priorAddress] = retained;
                    W.StandingContinuationV3 memory c = W.StandingContinuationV3(
                        id,
                        selected.priorAddress,
                        selected.retirementHash,
                        record,
                        actionId,
                        f.plan.commitment,
                        retained,
                        previous,
                        revision,
                        bytes32(0)
                    );
                    c.continuationHash = W.standingContinuationHash(e, c);
                    if (s.standingContinuations[c.continuationHash].continuationHash != 0) {
                        revert W.InvalidRecoveryRewindRecord(c.continuationHash);
                    }
                    s.standingContinuations[c.continuationHash] = c;
                    s.standingHeads[scope] = c.continuationHash;
                }
            }
            result = keccak256(
                abi.encode(
                    result,
                    selected,
                    rotations.retirement[id][selected.priorAddress],
                    rotations.standingRevocation[id][selected.priorAddress],
                    s.standingHeads[scope]
                )
            );
        }
    }

    function _capability(
        Rewind.State storage s,
        Identity.State storage identity,
        Succession.State storage succession,
        W.EnvironmentV3 memory e,
        Context.Facts memory f,
        bytes32 actionId,
        bytes32 record,
        uint32 originalCapabilities
    ) private returns (bytes32) {
        bytes32 id = f.source.manifest.artistId;
        if (identity.identities[id].authorityClass != 3) return bytes32(0);
        W.CapabilityContinuationV3 memory c;
        c.artistId = id;
        c.originalActivationRecordHash = f.source.ancestry.origin.transitionRecordHash;
        c.originalActivationCapabilities = originalCapabilities;
        c.recoveryRecordHash = record;
        c.actionId = actionId;
        c.manifestHash = f.plan.manifestHash;
        c.planCommitment = f.plan.commitment;
        c.designationRecordHash = f.plan.designation.operative.recordHash;
        c.pairedDirectiveRecordHash =
        succession.designations[c.designationRecordHash].terms.directiveHash;
        c.forbiddenDirectiveRecordHash = f.plan.directive.operative.recordHash;
        c.authorityAddress = identity.identities[id].authorityAddress;
        c.effectiveCapabilities = f.effectiveCapabilities;
        c.commitment = W.capabilityContinuationHash(e, c);
        if (s.capabilityContinuations[record].commitment != 0) {
            revert W.InvalidRecoveryRewindRecord(record);
        }
        s.capabilityContinuations[record] = c;
        s.capabilityHead[id] = record;
        return c.commitment;
    }
}

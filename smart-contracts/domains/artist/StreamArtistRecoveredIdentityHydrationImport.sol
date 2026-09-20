// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamArtistRecoveredIdentityHydrationTypes as IH
} from "../../interfaces/stream/artist/StreamArtistRecoveredIdentityHydrationTypes.sol";
import {
    StreamArtistRecoveredHydrationTypes as RH
} from "../../interfaces/stream/artist/StreamArtistRecoveredHydrationTypes.sol";
import {
    StreamArtistRecoveredTimingTypes as TM
} from "../../interfaces/stream/artist/StreamArtistRecoveredTimingTypes.sol";
import {
    StreamArtistOnboardingTypes as T
} from "../../interfaces/stream/artist/StreamArtistOnboardingTypes.sol";
import {
    StreamArtistRecoveryRewindTypes as W
} from "../../interfaces/stream/artist/StreamArtistRecoveryRewindTypes.sol";
import {
    StreamArtistIdentityDismissalTypes as D
} from "../../interfaces/stream/artist/StreamArtistIdentityDismissalTypes.sol";
import {
    StreamArtistRecoveredIdentityHydrationState as X
} from "./StreamArtistRecoveredIdentityHydrationState.sol";
import {
    StreamArtistRecoveredIdentityHydrationSource as Codec
} from "./StreamArtistRecoveredIdentityHydrationSource.sol";
import {
    StreamArtistRecoveredIdentityHydrationExportRows as Export
} from "./StreamArtistRecoveredIdentityHydrationExportRows.sol";
import {
    StreamArtistRecoveredTimingInventory as Timing
} from "./StreamArtistRecoveredTimingInventory.sol";
import {
    StreamArtistEntropyUnavailabilityStore as Entropy
} from "./StreamArtistEntropyUnavailabilityStore.sol";
import {
    StreamArtistIdentityRecoveryReceipts as Receipts
} from "./StreamArtistIdentityRecoveryReceipts.sol";
import { StreamArtistNonceAvailability as Nonces } from "./StreamArtistNonceAvailability.sol";
import {
    StreamArtistAuthorityCheckpoint as Checkpoint
} from "./StreamArtistAuthorityCheckpoint.sol";
import { StreamArtistPayloadStore as Payload } from "./StreamArtistPayloadStore.sol";
import {
    StreamArtistRecoveredHydrationState as ProvenanceState
} from "./StreamArtistRecoveredHydrationState.sol";

/// @notice Empty-key typed installation by the fixed host after complete source/cutover admission.
/// @dev Roots are the host's declared 17 slots. Replay aliases, provenance, semantic history
/// prefix and the sole owner/Archive mutation remain the common operation60 worker's duties.
/// This worker never invokes original record producers, emits original events or appends native rows.
library StreamArtistRecoveredIdentityHydrationImport {
    struct Repudiation {
        uint64 seconds_;
        uint64 revision;
        mapping(bytes32 => bool) actions;
    }

    function importEncoded(
        uint256[17] memory roots,
        bytes32 artistId,
        bytes memory raw,
        RH.OwnerProvenance memory provenance
    ) public returns (bytes32 commitment) {
        IH.Bundle memory b = Codec.decode(raw, provenance);
        if (b.artistId != artistId) revert IH.InvalidRecoveredIdentity(artistId);
        _emptyPrincipal(roots, b);
        _records(roots, b);
        _authority(roots, b);
        _recovery(roots, b);
        _continuations(roots, b);
        _nonces(roots, b);
        _timing(roots, b.timing);
        _heads(roots, b);
        _points(roots, b, provenance);
        return keccak256(abi.encode(IH.SCHEMA, b));
    }

    /// @dev The common worker has already installed the authenticated owner-local prefix.
    /// Keep all occurrences there, but give only unique primary semantic keys an artifact point.
    /// In particular the secondary35 supersession-list hash can recur and is never a record key.
    function _points(uint256[17] memory roots, IH.Bundle memory b, RH.OwnerProvenance memory p)
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

    function _emptyPrincipal(uint256[17] memory r, IH.Bundle memory b) private view {
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

    function _records(uint256[17] memory r, IH.Bundle memory b) private {
        for (uint256 i; i < b.documents.length; ++i) {
            IH.DocumentRow memory row = b.documents[i];
            bytes memory old = X.identity(r).documents[row.documentHash];
            if (old.length != 0 && keccak256(old) != keccak256(row.document)) {
                revert IH.InvalidRecoveredIdentity(row.documentHash);
            }
            X.identity(r).documents[row.documentHash] = row.document;
            Payload.store(keccak256("ARTIST_IDENTITY_DOCUMENT"), row.document);
        }
        for (uint256 i; i < b.signatures.length; ++i) {
            IH.SignatureRow memory row = b.signatures[i];
            bytes memory old = X.identity(r).signatures[row.recordHash];
            if (old.length != 0 && keccak256(old) != keccak256(row.signature)) {
                revert IH.InvalidRecoveredIdentity(row.recordHash);
            }
            X.identity(r).signatures[row.recordHash] = row.signature;
            Payload.store(keccak256("ARTIST_SIGNATURE_BUNDLE"), row.signature);
        }
        for (uint256 i; i < b.revisions.length; ++i) {
            IH.RevisionRow memory row = b.revisions[i];
            IH.RevisionRow memory zero;
            bytes32 key = row.record.recordHash;
            _empty(
                abi.encode(
                    X.revisions(r).records[key],
                    X.revisions(r).associations[key],
                    X.rewinds(r).statuses[key],
                    X.rewinds(r).revisionRecordContinuations[key]
                ),
                abi.encode(zero.record, zero.association, zero.status, zero.rewindContinuation),
                key
            );
            X.revisions(r).records[key] = row.record;
            X.revisions(r).associations[key] = row.association;
            X.rewinds(r).statuses[key] = row.status;
            X.rewinds(r).revisionRecordContinuations[key] = row.rewindContinuation;
        }
        for (uint256 i; i < b.delegations.length; ++i) {
            IH.DelegationRow memory row = b.delegations[i];
            IH.DelegationRow memory zero;
            _empty(
                abi.encode(
                    X.delegations(r).records[row.recordHash], X.estate(r).grantEpoch[row.recordHash]
                ),
                abi.encode(zero.record, uint64(0)),
                row.recordHash
            );
            bytes32 lane = keccak256(abi.encode(b.artistId, row.record.grant.delegate));
            bytes32 old = X.delegations(r).current[lane];
            if (old != 0 && old != row.current) revert IH.InvalidRecoveredIdentity(lane);
            X.delegations(r).records[row.recordHash] = row.record;
            X.delegations(r).current[lane] = row.current;
            X.estate(r).grantEpoch[row.recordHash] = row.epoch;
        }
        for (uint256 i; i < b.designations.length; ++i) {
            IH.DesignationRow memory row = b.designations[i];
            IH.DesignationRow memory zero;
            bytes32 key = row.record.recordHash;
            _empty(
                abi.encode(X.succession(r).designations[key], X.rewinds(r).statuses[key]),
                abi.encode(zero.record, zero.status),
                key
            );
            X.succession(r).designations[key] = row.record;
            X.rewinds(r).statuses[key] = row.status;
        }
        for (uint256 i; i < b.directives.length; ++i) {
            IH.DirectiveRow memory row = b.directives[i];
            IH.DirectiveRow memory zero;
            bytes32 key = row.record.recordHash;
            _empty(
                abi.encode(X.succession(r).directives[key], X.rewinds(r).statuses[key]),
                abi.encode(zero.record, zero.status),
                key
            );
            if (X.succession(r).payloads[key].length != 0) revert IH.InvalidRecoveredIdentity(key);
            X.succession(r).directives[key] = row.record;
            X.succession(r).payloads[key] = row.payload;
            X.rewinds(r).statuses[key] = row.status;
            Payload.store(keccak256("ARTIST_DIRECTIVE_PAYLOAD"), row.payload);
        }
        for (uint256 i; i < b.sanctionGrants.length; ++i) {
            IH.GrantRow memory row = b.sanctionGrants[i];
            IH.GrantRow memory zero;
            bytes32 key = row.record.recordHash;
            _empty(
                abi.encode(X.sanctions(r).records[key], X.rewinds(r).statuses[key]),
                abi.encode(zero.record, zero.status),
                key
            );
            X.sanctions(r).records[key] = row.record;
            X.rewinds(r).statuses[key] = row.status;
        }
    }

    function _authority(uint256[17] memory r, IH.Bundle memory b) private {
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
        _estate(r, b);
    }

    function _estate(uint256[17] memory r, IH.Bundle memory b) private {
        for (uint256 i; i < b.estates.length; ++i) {
            IH.EstateRow memory row = b.estates[i];
            IH.EstateRow memory zero;
            bytes32 key = row.request.recordHash;
            _empty(
                abi.encode(
                    X.estate(r).requests[key],
                    X.estate(r).phases[key],
                    X.estate(r).executions[key],
                    X.estate(r).transitions[key]
                ),
                abi.encode(zero.request, uint8(0), zero.execution, zero.transition),
                key
            );
            X.estate(r).requests[key] = row.request;
            X.estate(r).phases[key] = row.phase;
            X.estate(r).executions[key] = row.execution;
            X.estate(r).transitions[key] = row.transition;
        }
        for (uint256 i; i < b.notices.length; ++i) {
            IH.NoticeRow memory row = b.notices[i];
            IH.NoticeRow memory zero;
            bytes32 key = row.notice.recordHash;
            _empty(
                abi.encode(
                    X.dormancy(r).notices[key],
                    X.dormancy(r).phases[key],
                    X.dormancy(r).terminalForNotice[key]
                ),
                abi.encode(zero.notice, uint8(0), bytes32(0)),
                key
            );
            X.dormancy(r).notices[key] = row.notice;
            X.dormancy(r).phases[key] = row.phase;
            if (row.terminal.recordHash != 0) {
                bytes32 terminal = row.terminal.recordHash;
                _empty(
                    abi.encode(
                        X.dormancy(r).terminals[terminal], X.dormancy(r).transitions[terminal]
                    ),
                    abi.encode(zero.terminal, zero.transition),
                    terminal
                );
                X.dormancy(r).terminalForNotice[key] = terminal;
                X.dormancy(r).terminals[terminal] = row.terminal;
                X.dormancy(r).transitions[terminal] = row.transition;
            }
        }
        for (uint256 i; i < b.findings.length; ++i) {
            IH.FindingRow memory row = b.findings[i];
            IH.FindingRow memory zero;
            bytes32 key = row.record.recordHash;
            _empty(
                abi.encode(
                    X.findings(r).records[key],
                    X.findings(r).admissions[key],
                    Entropy.state().admissions[key],
                    Entropy.state().origins[key]
                ),
                abi.encode(zero.record, zero.admission, zero.entropyAdmission, address(0)),
                key
            );
            bytes32 scope = keccak256(abi.encode(b.artistId, row.record.terms.collectionId));
            bytes32 old = X.findings(r).latest[scope];
            if (old != 0 && old != row.latestForCollection) {
                revert IH.InvalidRecoveredIdentity(scope);
            }
            X.findings(r).records[key] = row.record;
            X.findings(r).admissions[key] = row.admission;
            X.findings(r).latest[scope] = row.latestForCollection;
            Entropy.state().admissions[key] = row.entropyAdmission;
            Entropy.state().origins[key] = row.entropyOrigin;
        }
    }

    function _recovery(uint256[17] memory r, IH.Bundle memory b) private {
        for (uint256 i; i < b.recoveries.length; ++i) {
            IH.RecoveryRow memory row = b.recoveries[i];
            IH.RecoveryRow memory zero;
            bytes32 key = row.record.recordHash;
            _empty(
                abi.encode(
                    X.recovery(r).records[key],
                    X.recovery(r).transitions[key],
                    X.recovery(r).recoveryGuardians[key]
                ),
                abi.encode(zero.record, zero.transition, bytes32(0)),
                key
            );
            if (
                X.recovery(r).receipts.receipts[Receipts.PRIMARY][key] != 0
                    || X.recovery(r).receipts.secondaryOccurrences[row.secondaryOccurrence] != 0
            ) revert IH.InvalidRecoveredIdentity(key);
            X.recovery(r).records[key] = row.record;
            X.recovery(r).transitions[key] = row.transition;
            X.recovery(r).recoveryGuardians[key] = row.guardian;
            X.recovery(r).receipts.receipts[Receipts.PRIMARY][key] = row.primaryReceipt;
            X.recovery(r).receipts.secondaryOccurrences[row.secondaryOccurrence] =
            row.secondaryReceipt;
        }
        for (uint256 i; i < b.vestings.length; ++i) {
            IH.VestingRow memory row = b.vestings[i];
            IH.VestingRow memory zero;
            bytes32 key = row.snapshot.transitionRecordHash;
            _empty(
                abi.encode(X.recovery(r).vestingHistory.snapshots[key]),
                abi.encode(zero.snapshot),
                key
            );
            X.recovery(r).vestingHistory.snapshots[key] = row.snapshot;
        }
        for (uint256 i; i < b.actions.length; ++i) {
            IH.ActionRow memory row = b.actions[i];
            IH.ActionRow memory zero;
            bytes32 key = row.association.action.actionId;
            _empty(
                abi.encode(
                    X.recovery(r).actions[key],
                    X.recovery(r).vetoes[key],
                    X.recovery(r).actionExecutions[key],
                    X.recovery(r).guardianHistory.snapshots[key]
                ),
                abi.encode(zero.association, zero.veto, bytes32(0), zero.guardianSnapshot),
                key
            );
            _empty(
                abi.encode(
                    X.recovery(r).guardianSupersession.plans[key],
                    X.recovery(r).guardianSupersession.elections[key],
                    X.recovery(r).guardianSupersession.restoredGuardians[key]
                ),
                abi.encode(zero.plan, zero.election, zero.restoredGuardian),
                key
            );
            _empty(
                abi.encode(X.adjudication(r).actions[key], X.rewinds(r).actions[key]),
                abi.encode(zero.evidenceV2, zero.evidenceV3),
                key
            );
            X.recovery(r).actions[key] = row.association;
            X.recovery(r).vetoes[key] = row.veto;
            X.recovery(r).actionExecutions[key] = row.execution;
            X.recovery(r).guardianHistory.snapshots[key] = row.guardianSnapshot;
            X.recovery(r).guardianSupersession.plans[key] = row.plan;
            X.recovery(r).guardianSupersession.elections[key] = row.election;
            X.recovery(r).guardianSupersession.restoredGuardians[key] = row.restoredGuardian;
            for (uint256 j; j < b.memberships.length; ++j) {
                if (
                    X.recovery(r).guardianSupersession
                            .excludedMemberships[key][b.memberships[j].actor] != 0
                ) revert IH.InvalidRecoveredIdentity(key);
                X.recovery(r).guardianSupersession
                    .excludedMemberships[key][b.memberships[j].actor] = row.excludedMemberships[j];
            }
            X.adjudication(r).actions[key] = row.evidenceV2;
            X.rewinds(r).actions[key] = row.evidenceV3;
            if (row.evidenceV2.manifestHash != 0) {
                if (X.adjudication(r).manifestActions[row.evidenceV2.manifestHash] != 0) {
                    revert IH.InvalidRecoveredIdentity(row.evidenceV2.manifestHash);
                }
                X.adjudication(r).manifestActions[row.evidenceV2.manifestHash] =
                row.manifestActionV2;
            }
            if (row.evidenceV3.manifestHash != 0) {
                if (X.rewinds(r).manifestActions[row.evidenceV3.manifestHash] != 0) {
                    revert IH.InvalidRecoveredIdentity(row.evidenceV3.manifestHash);
                }
                X.rewinds(r).manifestActions[row.evidenceV3.manifestHash] = row.manifestActionV3;
            }
        }
    }

    function _continuations(uint256[17] memory r, IH.Bundle memory b) private {
        for (uint256 i; i < b.originalContinuations.length; ++i) {
            IH.OriginalContinuationRow memory row = b.originalContinuations[i];
            IH.OriginalContinuationRow memory zero;
            bytes32 key = row.continuation.continuationHash;
            _empty(
                abi.encode(X.resolutions(r).continuations[key]), abi.encode(zero.continuation), key
            );
            X.resolutions(r).continuations[key] = row.continuation;
        }
        for (uint256 i; i < b.revisionContinuations.length; ++i) {
            IH.RevisionContinuationRow memory row = b.revisionContinuations[i];
            IH.RevisionContinuationRow memory zero;
            bytes32 key = row.continuation.continuationHash;
            _empty(
                abi.encode(X.rewinds(r).revisionContinuations[key]),
                abi.encode(zero.continuation),
                key
            );
            X.rewinds(r).revisionContinuations[key] = row.continuation;
        }
        for (uint256 i; i < b.standingContinuations.length; ++i) {
            IH.StandingContinuationRow memory row = b.standingContinuations[i];
            IH.StandingContinuationRow memory zero;
            bytes32 key = row.continuation.continuationHash;
            _empty(
                abi.encode(X.rewinds(r).standingContinuations[key]),
                abi.encode(zero.continuation),
                key
            );
            bytes32 scope = keccak256(
                abi.encode(
                    b.artistId, row.continuation.priorAddress, row.continuation.retirementHash
                )
            );
            bytes32 old = X.rewinds(r).standingHeads[scope];
            if (old != 0 && old != row.scopeHead) revert IH.InvalidRecoveredIdentity(scope);
            X.rewinds(r).standingContinuations[key] = row.continuation;
            X.rewinds(r).standingHeads[scope] = row.scopeHead;
        }
        for (uint256 i; i < b.capabilityContinuations.length; ++i) {
            IH.CapabilityContinuationRow memory row = b.capabilityContinuations[i];
            IH.CapabilityContinuationRow memory zero;
            bytes32 key = row.continuation.recoveryRecordHash;
            _empty(
                abi.encode(X.rewinds(r).capabilityContinuations[key]),
                abi.encode(zero.continuation),
                key
            );
            X.rewinds(r).capabilityContinuations[key] = row.continuation;
        }
    }

    function _nonces(uint256[17] memory r, IH.Bundle memory b) private {
        for (uint256 i; i < b.nonces.length; ++i) {
            IH.NonceLane memory row = b.nonces[i];
            if (row.kind == 1) {
                _nonce(X.identity(r).nonceAvailability[row.key], row);
            } else if (row.kind == 2) {
                _nonce(X.delegations(r).availability[row.key], row);
                X.delegations(r).hints[row.key] = row.hint;
            } else if (row.kind == 4) {
                _nonce(X.rotations(r).acceptanceNonces[row.key], row);
                X.rotations(r).acceptanceHint[row.key] = row.hint;
            } else if (row.kind == 5) {
                _nonce(X.estate(r).nonceAvailability[row.key], row);
                X.estate(r).nonceHints[row.key] = row.hint;
            } else {
                revert IH.InvalidRecoveredIdentity(row.key);
            }
        }
    }

    function _nonce(Nonces.Index storage s, IH.NonceLane memory row) private {
        if (row.words.length == 0 || row.words.length > RH.MAX_NONCE_PREFIXES || s.exhausted) {
            revert IH.InvalidRecoveredIdentity(row.key);
        }
        for (uint256 i; i < row.words.length; ++i) {
            uint256 prefix = row.words[i].prefix;
            for (uint8 level; level < 32; ++level) {
                uint256 old = s.full[level][prefix];
                if (old != 0 && old != row.words[i].words[level]) {
                    revert IH.InvalidRecoveredIdentity(row.key);
                }
                s.full[level][prefix] = row.words[i].words[level];
                prefix >>= 8;
            }
            if (i != 0 && row.words[i].exhausted != row.words[0].exhausted) {
                revert IH.InvalidRecoveredIdentity(row.key);
            }
            Checkpoint.noteNonce(
                row.kind, row.key, row.words[i].prefix, keccak256(abi.encode(row.words[i]))
            );
        }
        s.exhausted = row.words[0].exhausted;
        (bool available, uint256 hint) = Nonces.firstUnused(s);
        if (available && hint != row.hint) revert IH.InvalidRecoveredIdentity(row.key);
    }

    function _timing(uint256[17] memory r, TM.Bundle memory b) private {
        TM.Configuration memory old = Export.configuration(r);
        TM.Configuration memory zero;
        if (
            keccak256(abi.encode(old)) != keccak256(abi.encode(zero))
                && keccak256(abi.encode(old)) != keccak256(abi.encode(b.configuration))
        ) revert TM.RecoveredTimingUnavailable();
        Timing.install(b);
        X.rotations(r).rotationContestSeconds = b.configuration.values[0];
        X.rotations(r).priorStandingTailSeconds = b.configuration.values[1];
        X.estate(r).noticeSeconds = b.configuration.values[2];
        X.dormancy(r).inactivitySeconds = b.configuration.values[3];
        X.dormancy(r).noticeSeconds = b.configuration.values[4];
        X.findings(r).noticeSeconds = b.configuration.values[5];
        _repudiation().seconds_ = b.configuration.values[6];
        X.rotations(r).timingRevision = b.configuration.revisions[0];
        X.estate(r).noticeRevision = b.configuration.revisions[1];
        X.dormancy(r).timingRevision = b.configuration.revisions[2];
        X.findings(r).timingRevision = b.configuration.revisions[3];
        _repudiation().revision = b.configuration.revisions[4];
        for (uint256 i; i < b.entries.length; ++i) {
            TM.Input memory c = b.entries[i].change;
            (, uint8 group,) = Timing.parameter(c.parameter);
            if (group == 0) X.rotations(r).timingActions[c.actionKey] = true;
            else if (group == 1) X.estate(r).timingActions[c.actionKey] = true;
            else if (group == 2) X.dormancy(r).timingActions[c.actionKey] = true;
            else if (group == 3) X.findings(r).timingActions[c.actionKey] = true;
            else _repudiation().actions[c.actionKey] = true;
        }
    }

    function _heads(uint256[17] memory r, IH.Bundle memory b) private {
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

    function _empty(bytes memory old, bytes memory zero, bytes32 key) private pure {
        if (keccak256(old) != keccak256(zero)) revert IH.InvalidRecoveredIdentity(key);
    }

    function _repudiation() private pure returns (Repudiation storage s) {
        bytes32 slot = keccak256("6529STREAM_ARTIST_REPUDIATION_TIMING_V1");
        assembly ("memory-safe") { s.slot := slot }
    }
}

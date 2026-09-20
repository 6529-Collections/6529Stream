// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    IStreamArtistRecoveredTimingInventory
} from "../../interfaces/stream/artist/StreamArtistRecoveredTimingTypes.sol";
import {
    IStreamArtistEntropyFindingHydrationOwner
} from "../../interfaces/stream/artist/IStreamArtistEntropyFindingHydration.sol";

import {
    StreamArtistRecoveredIdentityHydrationTypes as IH
} from "../../interfaces/stream/artist/StreamArtistRecoveredIdentityHydrationTypes.sol";
import {
    IStreamArtistIdentityOwner
} from "../../interfaces/stream/artist/IStreamArtistIdentityOwner.sol";
import {
    IStreamArtistIdentityRevisionOwner
} from "../../interfaces/stream/artist/IStreamArtistIdentityRevision.sol";
import {
    IStreamArtistDelegationOwner
} from "../../interfaces/stream/artist/IStreamArtistDelegationOwner.sol";
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
    IStreamArtistGuardianVestingHistory
} from "../../interfaces/stream/artist/IStreamArtistGuardianVestingHistory.sol";
import {
    IStreamArtistIdentityContestOwner
} from "../../interfaces/stream/artist/IStreamArtistIdentityContest.sol";
import {
    IStreamArtistIdentityDismissalOwner
} from "../../interfaces/stream/artist/IStreamArtistIdentityDismissal.sol";
import {
    IStreamArtistIdentityRecoveryOwner
} from "../../interfaces/stream/artist/IStreamArtistIdentityRecovery.sol";
import {
    IStreamArtistIdentityRecoveryOwnerV2
} from "../../interfaces/stream/artist/IStreamArtistIdentityRecoveryV2.sol";
import {
    IStreamArtistIdentityRecoveryOwnerV3
} from "../../interfaces/stream/artist/IStreamArtistIdentityRecoveryV3.sol";
import {
    IStreamArtistRecoveryActionOwner
} from "../../interfaces/stream/artist/IStreamArtistRecoveryAction.sol";
import {
    IStreamArtistSuccessionReads
} from "../../interfaces/stream/artist/IStreamArtistSuccessionRecords.sol";
import {
    IStreamArtistEstateOwner
} from "../../interfaces/stream/artist/IStreamArtistEstateOwner.sol";
import {
    IStreamArtistDormancyOwner,
    StreamArtistDormancyTypes as Dorm
} from "../../interfaces/stream/artist/IStreamArtistDormancy.sol";
import {
    IStreamArtistStewardSanctionGrant
} from "../../interfaces/stream/artist/IStreamArtistStewardSanctionGrant.sol";
import {
    IStreamArtistGuardianSelectionOwner
} from "../../interfaces/stream/artist/IStreamArtistGuardianSelectionPreparation.sol";
import {
    StreamArtistGuardianSelectionTypes as Selection
} from "../../interfaces/stream/artist/StreamArtistGuardianSelectionTypes.sol";
import {
    StreamArtistRotationTypes as R
} from "../../interfaces/stream/artist/StreamArtistRotationTypes.sol";
import {
    IStreamArtistUnavailabilityOwner
} from "../../interfaces/stream/artist/IStreamArtistUnavailability.sol";
import {
    IStreamArtistEntropyUnavailabilityOwner,
    StreamArtistEntropyUnavailabilityTypes as EU
} from "../../interfaces/stream/artist/IStreamArtistEntropyUnavailability.sol";
import {
    StreamArtistRecoveryTypes as Finding
} from "../../interfaces/stream/artist/StreamArtistRecoveryTypes.sol";
import {
    StreamArtistUnavailabilityTypes as U
} from "../../interfaces/stream/artist/StreamArtistUnavailabilityTypes.sol";
import {
    StreamArtistGuardianHistoryTypes as GH
} from "../../interfaces/stream/artist/StreamArtistGuardianHistoryTypes.sol";
import {
    StreamArtistRecoveryActionTypes as A
} from "../../interfaces/stream/artist/StreamArtistRecoveryActionTypes.sol";
import {
    StreamArtistEstateTypes as Estate
} from "../../interfaces/stream/artist/StreamArtistEstateTypes.sol";
import {
    StreamArtistRecoveryRewindTypes as W
} from "../../interfaces/stream/artist/StreamArtistRecoveryRewindTypes.sol";

/// @notice Independent joins to original typed getters after the fixed raw export.
/// @dev Historical signatures are copied, never revalidated against today's signer readiness.
library StreamArtistRecoveredIdentityHydrationRecords {
    function validate(address owner, IH.Bundle memory b) public view {
        _same(
            abi.encode(b.identity),
            abi.encode(IStreamArtistIdentityOwner(owner).identity(b.artistId)),
            b.artistId
        );
        if (
            IStreamArtistIdentityOwner(owner).activeIdentity(b.identity.authorityAddress)
                    != b.artistId
                || b.nextRegistrationNonce
                    != IStreamArtistIdentityOwner(owner).nextRegistrationNonce()
                || keccak256(b.identityDocument) != b.identity.identityRecordHash
        ) revert IH.InvalidRecoveredIdentity(b.artistId);
        _same(
            b.identityDocument,
            IStreamArtistIdentityOwner(owner).identityDocumentBytes(b.identity.identityRecordHash),
            b.artistId
        );
        for (uint256 i; i < b.documents.length; ++i) {
            if (keccak256(b.documents[i].document) != b.documents[i].documentHash) {
                revert IH.InvalidRecoveredIdentity(b.documents[i].documentHash);
            }
            _same(
                b.documents[i].document,
                IStreamArtistIdentityOwner(owner)
                    .identityDocumentBytes(b.documents[i].documentHash),
                b.documents[i].documentHash
            );
        }
        for (uint256 i; i < b.signatures.length; ++i) {
            _same(
                b.signatures[i].signature,
                IStreamArtistIdentityOwner(owner).signatureBundle(b.signatures[i].recordHash),
                b.signatures[i].recordHash
            );
        }
        _records(owner, b);
        _authority(owner, b);
        _recovery(owner, b);
        _continuations(owner, b);
        _findings(owner, b);
        _same(
            abi.encode(b.timing.checkpoint),
            abi.encode(IStreamArtistRecoveredTimingInventory(owner).recoveredTimingCheckpoint()),
            b.artistId
        );
        _same(
            abi.encode(b.heads.inventory),
            abi.encode(
                IStreamArtistIdentityRecoveryOwnerV3(owner).recoveryRewindInventoryV3(b.artistId)
            ),
            b.artistId
        );
        if (
            b.heads.capabilityContinuation
                != IStreamArtistIdentityRecoveryOwnerV3(owner)
                    .latestRecoveryCapabilityContinuationV3(b.artistId)
        ) revert IH.InvalidRecoveredIdentity(b.artistId);
    }

    function _records(address owner, IH.Bundle memory b) private view {
        for (uint256 i; i < b.revisions.length; ++i) {
            IH.RevisionRow memory r = b.revisions[i];
            if (
                r.record.artistId != b.artistId
                    || keccak256(r.document) != r.record.revisedRecordHash
            ) revert IH.InvalidRecoveredIdentity(r.record.recordHash);
            _same(
                abi.encode(r.record),
                abi.encode(
                    IStreamArtistIdentityRevisionOwner(owner)
                        .identityRevisionRecord(r.record.recordHash)
                ),
                r.record.recordHash
            );
            _same(
                r.document,
                IStreamArtistIdentityOwner(owner).identityDocumentBytes(r.record.revisedRecordHash),
                r.record.recordHash
            );
            _same(
                abi.encode(r.association),
                abi.encode(
                    IStreamArtistRotationReads(owner)
                        .identityRevisionProvisionalAssociation(r.record.recordHash)
                ),
                r.record.recordHash
            );
            _status(owner, W.RecordKind.IDENTITY_REVISION, r.record.recordHash, r.status);
            if (
                r.rewindContinuation
                    != IStreamArtistIdentityRecoveryOwnerV3(owner)
                        .identityRevisionRecoveryContinuationV3(r.record.recordHash)
            ) revert IH.InvalidRecoveredIdentity(r.record.recordHash);
        }
        for (uint256 i; i < b.delegations.length; ++i) {
            IH.DelegationRow memory r = b.delegations[i];
            if (r.record.grant.artistId != b.artistId) {
                revert IH.InvalidRecoveredIdentity(r.recordHash);
            }
            _same(
                abi.encode(r.record),
                abi.encode(IStreamArtistDelegationOwner(owner).delegationRecord(r.recordHash)),
                r.recordHash
            );
            (, uint64 epoch,) = IStreamArtistEstateOwner(owner).delegationEpochState(r.recordHash);
            if (r.epoch != epoch) revert IH.InvalidRecoveredIdentity(r.recordHash);
        }
        for (uint256 i; i < b.designations.length; ++i) {
            IH.DesignationRow memory r = b.designations[i];
            if (r.record.terms.artistId != b.artistId) {
                revert IH.InvalidRecoveredIdentity(r.record.recordHash);
            }
            _same(
                abi.encode(r.record),
                abi.encode(
                    IStreamArtistSuccessionReads(owner)
                        .successorDesignationRecord(r.record.recordHash)
                ),
                r.record.recordHash
            );
            _status(owner, W.RecordKind.SUCCESSOR_DESIGNATION, r.record.recordHash, r.status);
        }
        for (uint256 i; i < b.directives.length; ++i) {
            IH.DirectiveRow memory r = b.directives[i];
            if (r.record.terms.artistId != b.artistId) {
                revert IH.InvalidRecoveredIdentity(r.record.recordHash);
            }
            _same(
                abi.encode(r.record),
                abi.encode(
                    IStreamArtistSuccessionReads(owner).estateDirectiveRecord(r.record.recordHash)
                ),
                r.record.recordHash
            );
            _same(
                r.payload,
                IStreamArtistSuccessionReads(owner).estateDirectivePayload(r.record.recordHash),
                r.record.recordHash
            );
            _status(owner, W.RecordKind.ESTATE_DIRECTIVE, r.record.recordHash, r.status);
        }
        for (uint256 i; i < b.sanctionGrants.length; ++i) {
            IH.GrantRow memory r = b.sanctionGrants[i];
            if (r.record.terms.artistId != b.artistId) {
                revert IH.InvalidRecoveredIdentity(r.record.recordHash);
            }
            _same(
                abi.encode(r.record),
                abi.encode(
                    IStreamArtistStewardSanctionGrant(owner)
                        .stewardSanctionGrantRecord(r.record.recordHash)
                ),
                r.record.recordHash
            );
            _status(owner, W.RecordKind.STEWARD_SANCTION_GRANT, r.record.recordHash, r.status);
        }
    }

    function _authority(address owner, IH.Bundle memory b) private view {
        for (uint256 i; i < b.guardians.length; ++i) {
            IH.GuardianRow memory r = b.guardians[i];
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
            IH.RotationRow memory r = b.rotations[i];
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
            IH.ContestRow memory r = b.contests[i];
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
            IH.CauseRow memory r = b.causes[i];
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
            IH.DismissalRow memory r = b.dismissals[i];
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
            IH.StandingRecordRow memory r = b.standingRecords[i];
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
            IH.EstateRow memory r = b.estates[i];
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
            IH.NoticeRow memory r = b.notices[i];
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

    function _recovery(address owner, IH.Bundle memory b) private view {
        for (uint256 i; i < b.recoveries.length; ++i) {
            IH.RecoveryRow memory r = b.recoveries[i];
            if (r.record.fields.artistId != b.artistId) {
                revert IH.InvalidRecoveredIdentity(r.record.recordHash);
            }
            _same(
                abi.encode(r.record),
                abi.encode(
                    IStreamArtistIdentityRecoveryOwner(owner)
                        .identityRecoveryRecord(r.record.recordHash)
                ),
                r.record.recordHash
            );
            _same(
                abi.encode(r.transition),
                abi.encode(
                    IStreamArtistRotationReads(owner).artistTransitionState(r.record.recordHash)
                ),
                r.record.recordHash
            );
            (bytes32 primary, bytes32 occurrence, bytes32 secondary) = IStreamArtistIdentityRecoveryOwner(
                    owner
                ).identityRecoveryReceipts(r.record.recordHash);
            _same(
                abi.encode(r.primaryReceipt, r.secondaryOccurrence, r.secondaryReceipt),
                abi.encode(primary, occurrence, secondary),
                r.record.recordHash
            );
            (, bytes32 guardian,) = IStreamArtistIdentityRecoveryOwner(owner)
                .recoveryTransitionStanding(r.record.recordHash);
            if (guardian != r.guardian) revert IH.InvalidRecoveredIdentity(r.record.recordHash);
        }
        for (uint256 i; i < b.vestings.length; ++i) {
            IH.VestingRow memory r = b.vestings[i];
            _same(
                abi.encode(r.snapshot),
                abi.encode(
                    IStreamArtistGuardianVestingHistory(owner)
                        .guardianVestingSnapshot(b.artistId, r.snapshot.transitionRecordHash)
                ),
                r.snapshot.transitionRecordHash
            );
        }
        for (uint256 i; i < b.actions.length; ++i) {
            IH.ActionRow memory r = b.actions[i];
            bytes32 action = r.association.action.actionId;
            if (action == 0 || r.association.artistId != b.artistId) {
                revert IH.InvalidRecoveredIdentity(action);
            }
            (
                A.Association memory association,
                A.Veto memory veto,
                bytes32 execution,
                uint64 count
            ) = IStreamArtistRecoveryActionOwner(owner)
                .identityRecoveryActionState(b.artistId, action);
            _same(
                abi.encode(r.association, r.veto, r.execution),
                abi.encode(association, veto, execution),
                action
            );
            (Selection.Result memory election, R.GuardianRecord memory restored) =
                IStreamArtistGuardianSelectionOwner(owner).guardianRecoverySelection(action);
            _same(
                abi.encode(r.election, r.restoredGuardian), abi.encode(election, restored), action
            );
            if (count != b.heads.guardianRecordsSeen) revert IH.InvalidRecoveredIdentity(action);
            (,, GH.Snapshot memory frozen,) = IStreamArtistGuardianHistory(owner)
                .guardianHistoryState(b.artistId, 0, address(0), action);
            _same(abi.encode(r.guardianSnapshot), abi.encode(frozen), action);
            _same(
                abi.encode(r.evidenceV2),
                abi.encode(
                    IStreamArtistIdentityRecoveryOwnerV2(owner)
                        .identityRecoveryEvidenceState(b.artistId, action)
                ),
                action
            );
            _same(
                abi.encode(r.evidenceV3),
                abi.encode(
                    IStreamArtistIdentityRecoveryOwnerV3(owner)
                        .identityRecoveryEvidenceStateV3(b.artistId, action)
                ),
                action
            );
        }
    }

    function _continuations(address owner, IH.Bundle memory b) private view {
        for (uint256 i; i < b.originalContinuations.length; ++i) {
            bytes32 key = b.originalContinuations[i].continuation.continuationHash;
            _same(
                abi.encode(b.originalContinuations[i].continuation),
                abi.encode(
                    IStreamArtistIdentityDismissalOwner(owner).identityRevisionContinuation(key)
                ),
                key
            );
        }
        for (uint256 i; i < b.revisionContinuations.length; ++i) {
            bytes32 key = b.revisionContinuations[i].continuation.continuationHash;
            _same(
                abi.encode(b.revisionContinuations[i].continuation),
                abi.encode(
                    IStreamArtistIdentityRecoveryOwnerV3(owner).recoveryRevisionContinuationV3(key)
                ),
                key
            );
        }
        for (uint256 i; i < b.standingContinuations.length; ++i) {
            bytes32 key = b.standingContinuations[i].continuation.continuationHash;
            _same(
                abi.encode(b.standingContinuations[i].continuation),
                abi.encode(
                    IStreamArtistIdentityRecoveryOwnerV3(owner).recoveryStandingContinuationV3(key)
                ),
                key
            );
        }
        for (uint256 i; i < b.capabilityContinuations.length; ++i) {
            bytes32 key = b.capabilityContinuations[i].continuation.recoveryRecordHash;
            _same(
                abi.encode(b.capabilityContinuations[i].continuation),
                abi.encode(
                    IStreamArtistIdentityRecoveryOwnerV3(owner)
                        .recoveryCapabilityContinuationV3(key)
                ),
                key
            );
        }
    }

    function _findings(address owner, IH.Bundle memory b) private view {
        for (uint256 i; i < b.findings.length; ++i) {
            IH.FindingRow memory r = b.findings[i];
            if (r.record.terms.artistId != b.artistId) {
                revert IH.InvalidRecoveredIdentity(r.record.recordHash);
            }
            (Finding.FindingRecord memory record, U.Admission memory admission) = IStreamArtistUnavailabilityOwner(
                    owner
                ).unavailabilityFindingRecord(r.record.recordHash);
            _same(
                abi.encode(r.record, r.admission),
                abi.encode(record, admission),
                r.record.recordHash
            );
            (Finding.FindingRecord memory entropyRecord, EU.Admission memory entropyAdmission) = IStreamArtistEntropyUnavailabilityOwner(
                    owner
                ).entropyUnavailabilityFindingRecord(r.record.recordHash);
            _same(
                abi.encode(r.record, r.entropyAdmission),
                abi.encode(entropyRecord, entropyAdmission),
                r.record.recordHash
            );
            if (
                r.entropyOrigin
                    != IStreamArtistEntropyFindingHydrationOwner(owner)
                        .entropyUnavailabilityFindingOrigin(r.record.recordHash)
            ) revert IH.InvalidRecoveredIdentity(r.record.recordHash);
            if (
                r.latestForCollection
                    != IStreamArtistUnavailabilityOwner(owner)
                        .latestUnavailabilityFinding(b.artistId, r.record.terms.collectionId)
            ) revert IH.InvalidRecoveredIdentity(r.record.recordHash);
        }
    }

    function _status(address owner, W.RecordKind kind, bytes32 hash, W.StatusV3 memory status)
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

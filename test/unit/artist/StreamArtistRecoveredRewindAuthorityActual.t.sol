// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { StreamArtistRecoveryRewindsActualTest } from "./StreamArtistRecoveryRewindsActual.t.sol";
import { ArtistUnitGovernance, ArtistUnitRoles } from "./ArtistOnboardingFixture.sol";
import { ArtistSanctionFinalityFixture } from "./ArtistSanctionFinalityFixture.sol";
import {
    StreamArtistOnboardingRegistry
} from "../../../smart-contracts/domains/artist/StreamArtistOnboardingRegistry.sol";
import {
    StreamArtistOnboardingCoordinator
} from "../../../smart-contracts/domains/artist/StreamArtistOnboardingCoordinator.sol";
import {
    StreamArtistArchiveV2
} from "../../../smart-contracts/domains/artist/StreamArtistArchiveV2.sol";
import {
    StreamArtistRecoveredHydrationTypes as RH
} from "../../../smart-contracts/interfaces/stream/artist/StreamArtistRecoveredHydrationTypes.sol";
import {
    IStreamArtistRecoveredHydration as Recovered,
    IStreamArtistRecoveredHydrationOwner as RecoveredOwner,
    IStreamArtistRecoveredNativeChronology as NativeClock
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistRecoveredHydration.sol";
import {
    StreamArtistAuthorityHydrationTypes as AH,
    IStreamArtistAuthorityHydrationOwner as HydrationOwner
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistAuthorityHydration.sol";
import {
    StreamArtistMultipleHydrationTypes as MH
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistMultipleAuthorityHydration.sol";
import {
    StreamArtistOnboardingTypes as T
} from "../../../smart-contracts/interfaces/stream/artist/StreamArtistOnboardingTypes.sol";
import {
    StreamArtistRotationTypes as R
} from "../../../smart-contracts/interfaces/stream/artist/StreamArtistRotationTypes.sol";
import {
    IStreamArtistOwner as Owner
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistOwner.sol";
import {
    IStreamArtistOnboarding
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistOnboarding.sol";
import {
    IStreamArtistRotation
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistRotation.sol";
import {
    IStreamArtistRotationReads
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistRotationOwner.sol";
import {
    IStreamArtistIdentityOwner
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistIdentityOwner.sol";
import {
    IStreamArtistIdentityRecoveryOwner
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistIdentityRecovery.sol";
import {
    IStreamArtistGuardianVestingHistory
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistGuardianVestingHistory.sol";
import {
    StreamArtistIdentityRecoveryOperationTypes as Recovery
} from "../../../smart-contracts/interfaces/stream/artist/StreamArtistIdentityRecoveryOperationTypes.sol";
import {
    IStreamArtistRecoveryActionOwner
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistRecoveryAction.sol";
import {
    StreamArtistRecoveryActionTypes as RecoveryAction
} from "../../../smart-contracts/interfaces/stream/artist/StreamArtistRecoveryActionTypes.sol";
import {
    IStreamArtistIdentityContest
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistIdentityContest.sol";
import {
    StreamArtistIdentityDismissalTypes as Dismissal
} from "../../../smart-contracts/interfaces/stream/artist/StreamArtistIdentityDismissalTypes.sol";
import {
    IStreamArtistArchiveV2
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistArchiveV2.sol";
import {
    IStreamArtistAuthorityCheckpoint as CP
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistAuthorityCheckpoint.sol";
import {
    IStreamArtistHistory as History,
    IStreamArtistNativeReceipts as Native,
    StreamArtistHistoryTypes as HT
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistHistory.sol";
import {
    IStreamGovernanceReads
} from "../../../smart-contracts/interfaces/stream/governance/IStreamGovernanceReads.sol";
import {
    GovernanceCall,
    GovernanceActionStatus
} from "../../../smart-contracts/interfaces/stream/governance/StreamGovernanceTypes.sol";
import {
    StreamArtistRecoveredHydrationPrepared as Prepared
} from "../../../smart-contracts/domains/artist/StreamArtistRecoveredHydrationPrepared.sol";
import {
    StreamArtistRecoveredHydrationCommit as Commit
} from "../../../smart-contracts/domains/artist/StreamArtistRecoveredHydrationCommit.sol";
import {
    StreamArtistRecoveredHydrationGuards as Guards
} from "../../../smart-contracts/domains/artist/StreamArtistRecoveredHydrationGuards.sol";
import {
    StreamArtistRecoveredHydrationOwnerPayload as Payload
} from "../../../smart-contracts/domains/artist/StreamArtistRecoveredHydrationOwnerPayload.sol";
import {
    StreamArtistRecoveredPayloadHydration as Publications
} from "../../../smart-contracts/domains/artist/StreamArtistRecoveredPayloadHydration.sol";
import {
    IStreamArtistRecoveredTimingInventory
} from "../../../smart-contracts/interfaces/stream/artist/StreamArtistRecoveredTimingTypes.sol";

import {
    StreamArtistRecoveryRewindTypes as W
} from "../../../smart-contracts/interfaces/stream/artist/StreamArtistRecoveryRewindTypes.sol";
import {
    IStreamArtistIdentityRecoveryOwnerV3 as RewindOwner
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistIdentityRecoveryV3.sol";
import {
    IStreamArtistRecoveryPayoutOwnerV3 as RewindPayout
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistRecoveryPayoutOwnerV3.sol";
import {
    IStreamArtistRecoveryRewindEvidence as RewindPublisher
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistRecoveryRewindEvidence.sol";
import {
    IStreamArtistRecoveryRewindSelection as RewindSelection
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistRecoveryRewindSelection.sol";
import {
    StreamArtistSuccessionTypes as Succ
} from "../../../smart-contracts/interfaces/stream/artist/StreamArtistSuccessionTypes.sol";
import {
    StreamArtistIdentityRevisionTypes as Doc
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistIdentityRevision.sol";
import {
    IStreamArtistStewardSanctionGrant as Grant
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistStewardSanctionGrant.sol";
import {
    IStreamArtistIdentityDismissalOwner
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistIdentityDismissal.sol";
import {
    StreamArtistIdentityContestTypes as Contest
} from "../../../smart-contracts/interfaces/stream/artist/StreamArtistIdentityContestTypes.sol";
import {
    StreamArtistRecoveryRewindOperations as RewindOperations
} from "../../../smart-contracts/domains/artist/StreamArtistRecoveryRewindOperations.sol";
import {
    IStreamArtistPayoutOwner
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistPayoutOwner.sol";
import {
    IStreamArtistPayoutTransitionOwner
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistPayoutTransitionOwner.sol";
import {
    StreamArtistPayoutLifecycle
} from "../../../smart-contracts/domains/artist/StreamArtistPayoutLifecycle.sol";
import {
    IStreamArtistSuccessionReads
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistSuccessionRecords.sol";
import {
    IStreamArtistIdentityRevisionReads
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistIdentityRevision.sol";

/// @notice Actual six-family V3 rewind source followed by seven-owner profile10 transport.
/// @dev Invokes the existing real mixed-plan/Safe/APPEAL/Archive source recipe unchanged.
/// Its inherited typed Core and governance facts remain the explicit boundaries, including
/// its source rollback probes. Capabilities, source checkpoints and semantic records are real.
/// The concrete owners advertise the first-graph mask31; native execution and gas evidence remain pending.
contract StreamArtistRecoveredRewindAuthorityActualTest is StreamArtistRecoveryRewindsActualTest {
    bytes32 private constant RH_LEAF =
        0xea04da6644046a7c731e99312c32df311e81aa7e137dfc2a49c2116bb325195d;
    bytes32 private constant RH_POINTER = keccak256("ARTIST_REGISTRY");

    struct Successor {
        StreamArtistOnboardingRegistry registry;
        StreamArtistArchiveV2 archive;
        StreamArtistOnboardingCoordinator coordinator;
        address identity;
    }
    AH.Origin[][7] private rhCandidates;
    bytes32 private rhGuardian;
    bytes32 private rhRecovery;
    bytes32 private rhOriginalAction;

    struct OriginalExecution {
        bytes32 tag;
        Recovery.Request request;
        T.Authorization acceptance;
        T.SignerApproval proof;
        Contest.GovernanceWitness governance;
        Recovery.Context context;
        Recovery.Record record;
        W.EvidenceStateV3 state;
        RewindOperations.Evidence evidence;
        bytes32 payoutMutation;
        bytes noticeBefore;
        bytes noticeAfter;
    }
    W.RecordReference[] private vrRecords;
    bytes32 private vrRevision;
    bytes32 private vrPayout;
    bytes32 private vrStanding;
    address private vrRetired;
    bytes32 private vrRetirement;

    function testRecoveredV3MixedPlanImportPreservesSixFamilyOriginalsAndRetries() external {
        _vrBaseline();
        Successor memory next = _rhCutover();
        RH.Request memory request = _rhRequest();
        Commit.Prepared memory prepared =
            Prepared.prepare(next.coordinator.suiteConfiguration(), request);
        request.expectedSemanticInventory = Prepared.inventory(prepared);
        bytes32 before_ = _rhDestinationHash(next);
        ++request.records.authority.expectedSource[5].ownerState.revision;
        avm.expectRevert(RH.InvalidRecoveredHydrationProvenance.selector);
        Recovered(address(next.registry)).hydrateRecoveredArtistAuthority(request);
        require(
            _rhDestinationHash(next) == before_,
            "stale actual Payout prefix has no destination effect"
        );
        --request.records.authority.expectedSource[5].ownerState.revision;
        bytes32 sourceBefore = _vrOriginals(suite.owners[2], suite.owners[5]);
        bytes32 operative = _vrOperative(suite.owners[2], suite.owners[5]);
        bytes32 value = Recovered(address(next.registry)).hydrateRecoveredArtistAuthority(request);
        _rhImported(next, prepared, value);
        T.SuiteConfiguration memory target = next.coordinator.suiteConfiguration();
        require(
            _vrOriginals(next.identity, target.owners[5]) == sourceBefore
                && _vrOperative(next.identity, target.owners[5]) == operative,
            "full original six-family records, permanent statuses and continuations retained"
        );
        _vrContinuations(next.identity, target.owners[5]);
        require(
            _vrOriginals(suite.owners[2], suite.owners[5]) == sourceBefore,
            "source remains unchanged"
        );
    }

    function testRecoveredV3Fresh25And18ConsumeRetainedContinuationsAnd51KeepsItsRule() external {
        _vrBaseline();
        Successor memory next = _rhCutover();
        RH.Request memory request = _rhRequest();
        Commit.Prepared memory prepared =
            Prepared.prepare(next.coordinator.suiteConfiguration(), request);
        request.expectedSemanticInventory = Prepared.inventory(prepared);
        bytes32 originals = _vrOriginals(suite.owners[2], suite.owners[5]);
        bytes32 operative = _vrOperative(suite.owners[2], suite.owners[5]);
        bytes32 value = Recovered(address(next.registry)).hydrateRecoveredArtistAuthority(request);
        _rhImported(next, prepared, value);
        _rhAdopt(next);
        _vrContinuations(suite.owners[2], suite.owners[5]);
        require(
            _vrOriginals(suite.owners[2], suite.owners[5]) == originals
                && _vrOperative(suite.owners[2], suite.owners[5]) == operative,
            "exact original V3 facts before fresh writes"
        );
        T.Snapshot memory beforeIdentity = Owner(suite.owners[2]).ownerStateSnapshotV2();
        T.Snapshot memory beforePayout = Owner(suite.owners[5]).ownerStateSnapshotV2();
        W.RevisionContinuationV3 memory revision =
            RewindOwner(suite.owners[2]).recoveryRevisionContinuationV3(vrRevision);
        W.PayoutContinuationV3 memory payout =
            RewindPayout(suite.owners[5]).payoutRecoveryContinuationV3(vrPayout);
        require(
            revision.ownerRevision > beforeIdentity.revision
                && payout.payoutOwnerRevision > beforePayout.revision,
            "old source counters exceed genuine local counters; no revision-floor workaround"
        );
        bytes32 doc = _reviseDocument(bytes("fresh destination revision after original V3"));
        require(
            RewindOwner(suite.owners[2]).identityRevisionRecoveryContinuationV3(doc) == vrRevision,
            "actual25 records its imported original continuation"
        );
        bytes32 revisionScope = keccak256(
            abi.encode(
                artistId, revision.stableRevisionRecordHash, revision.stableDocumentHash, vrRevision
            )
        );
        _vrConsumed(
            2,
            "identity_authority.replay.identity_revision_recovery_continuation",
            revisionScope,
            doc,
            Owner(suite.owners[2]).ownerStateSnapshotV2().revision
        );
        bytes32 payment = _dismissalPayout(address(0x1701));
        require(
            RewindPayout(suite.owners[5]).payoutDesignationRecoveryContinuationV3(payment)
                == vrPayout,
            "actual18 records its imported original payout continuation"
        );
        _vrConsumed(
            5,
            "payout_lifecycle.replay.recovery_continuation",
            keccak256(abi.encode(artistId, vrPayout, payout.stable.recordHash)),
            payment,
            Owner(suite.owners[5]).ownerStateSnapshotV2().revision
        );
        require(
            Native(suite.owners[2]).artistNativeReceiptCount() == 1
                && Native(suite.owners[2]).artistNativeReceiptAt(0).recordHash == doc
                && Native(suite.owners[5]).artistNativeReceiptCount() == 1
                && Native(suite.owners[5]).artistNativeReceiptAt(0).recordHash == payment
                && NativeClock(suite.owners[2]).artistNativeReceiptRevisionAt(0)
                    == beforeIdentity.revision + 1
                && NativeClock(suite.owners[5]).artistNativeReceiptRevisionAt(0)
                    == beforePayout.revision + 1,
            "only genuine local25 and18 occurrences appended"
        );
        require(
            ingress.identityRevisionProvisionalAssociation(doc).transitionRecordHash == rhRecovery
                && IStreamArtistPayoutTransitionOwner(suite.owners[5])
                .payoutDesignationProvisionalAssociation(payment)
                .transitionRecordHash == rhRecovery,
            "both fresh provisional records retain the real source35 execution association"
        );
        require(
            Owner(suite.owners[2]).ownerStateSnapshotV2().revision == beforeIdentity.revision + 2
                && Owner(suite.owners[5]).ownerStateSnapshotV2().revision
                    == beforePayout.revision + 1,
            "actual local counters advance normally"
        );
        require(
            _vrOriginals(suite.owners[2], suite.owners[5]) == originals,
            "fresh continuation consumers do not rewrite original records, statuses or continuation bodies"
        );
        // The mixed-plan source named this original32 in its compromise. Restoring its old51
        // status does not erase the original contestedAt or create standing eligibility.
        require(
            ingress.artistTransitionState(vrRetirement).contestedAt != 0,
            "actual contested retirement retained"
        );
        R.StandingRevocation memory standing = R.StandingRevocation(
            artistId, vrRetired, keccak256("fresh51 after import"), vrRetirement
        );
        T.Authorization memory a = _authorization(false);
        a.signature = _signature(ingress.standingRevocationDigest(standing, a));
        bytes32 before_ = _rhDestinationHash(next);
        vm.expectRevert(abi.encodeWithSelector(R.InvalidPriorStanding.selector, vrRetired));
        ingress.revokePriorAddressStanding(standing, a);
        require(
            _rhDestinationHash(next) == before_,
            "original contested-retirement denial remains atomic"
        );
    }

    function _vrBaseline() private {
        // This accepted fixture authors all six non-guardian families and a protected guardian,
        // publishes genuine V3/APPEAL evidence and executes the original registered35 pair.
        testRewindMixedPlanSelectsAllFamiliesAgainstOneOriginalSource();
        rhRecovery = ingress.latestIdentityRecovery(artistId);
        Recovery.Record memory recovered = ingress.identityRecoveryRecord(rhRecovery);
        rhOriginalAction = recovered.fields.governanceActionId;
        (RecoveryAction.Association memory action,, bytes32 execution,) = IStreamArtistRecoveryActionOwner(
                suite.owners[2]
            ).identityRecoveryActionState(artistId, rhOriginalAction);
        require(
            rhRecovery != 0 && execution == rhRecovery
                && recovered.fields.vestedAuthorityClass == 1,
            "actual executed V3 original35 source"
        );
        rhGuardian = action.guardian.recordHash;
        W.EvidenceStateV3 memory state = RewindOwner(suite.owners[2])
            .identityRecoveryEvidenceStateV3(artistId, rhOriginalAction);
        (address publisher, bytes32 publisherPin) =
            RewindOwner(suite.owners[2]).recoveryRewindEvidenceBinding();
        require(
            publisher.codehash == publisherPin && publisherPin != 0, "fixed source V3 publisher"
        );
        (W.ResolutionManifestV3 memory manifest,,) =
            RewindPublisher(publisher).resolutionManifestV3(state.manifestHash);
        require(
            manifest.supersededRecords.length == 7, "all six non-guardian families plus guardian"
        );
        W.IdentityInventoryV3 memory identity =
            RewindOwner(suite.owners[2]).recoveryRewindInventoryV3(artistId);
        W.PayoutInventoryV3 memory payout =
            RewindPayout(suite.owners[5]).payoutRewindInventoryV3(artistId);
        vrRevision = identity.revisionContinuationHash;
        vrPayout = payout.continuationCommitment;
        for (uint256 i; i < manifest.supersededRecords.length; ++i) {
            W.RecordReference memory r = manifest.supersededRecords[i];
            if (r.kind != W.RecordKind.PRIOR_ADDRESS_STANDING_REVOCATION) continue;
            R.StandingRecord memory record = ingress.standingRevocationRecord(r.recordHash);
            vrRetired = record.terms.revokedAddress;
            vrRetirement = record.terms.retiredTransitionRecordHash;
            (,,, vrStanding) =
                RewindOwner(suite.owners[2]).recoveryStandingScopeV3(artistId, vrRetired);
        }
        _vrContinuations(suite.owners[2], suite.owners[5]);
        _vrWitnesses();
    }

    function _vrContinuations(address identity, address payout) private view {
        require(
            vrRevision != 0 && vrPayout != 0 && vrStanding != 0,
            "all three real V3 continuation heads"
        );
        W.RevisionContinuationV3 memory d =
            RewindOwner(identity).recoveryRevisionContinuationV3(vrRevision);
        W.StandingContinuationV3 memory s =
            RewindOwner(identity).recoveryStandingContinuationV3(vrStanding);
        W.PayoutContinuationV3 memory p =
            RewindPayout(payout).payoutRecoveryContinuationV3(vrPayout);
        require(
            d.continuationHash == vrRevision && d.recoveryRecordHash == rhRecovery
                && s.continuationHash == vrStanding && s.recoveryRecordHash == rhRecovery
                && p.continuationHash == vrPayout && p.recoveryRecordHash == rhRecovery,
            "original actual35 binds all retained continuation bodies"
        );
    }

    function _vrConsumed(
        uint8 owner,
        string memory surface,
        bytes32 scope,
        bytes32 record,
        uint64 revision
    ) private view {
        bytes32 key = _rhSourceKey(owner, AH.Origin(keccak256(bytes(surface)), scope));
        T.ReplayCell memory cell = Owner(suite.owners[owner]).replayCell(key);
        require(
            cell.commitment == record && cell.kind == 1 && cell.status == 2
                && cell.touchedRevision == revision,
            "genuine original writer consumed current-domain continuation replay once"
        );
        RH.Point memory point =
            RecoveredOwner(suite.owners[owner]).recoveredHydrationReplayPoint(key);
        RH.OriginEnvironment memory original =
            RecoveredOwner(suite.owners[owner]).recoveredHydrationOrigin(point.environmentHash);
        require(
            point.ownerIndex == owner && point.ownerRevision == revision
                && original.registry == address(ingress)
                && original.owners[owner] == suite.owners[owner]
                && RH.originHash(original) == point.environmentHash,
            "fresh consumption has actual local mutation chronology"
        );
    }

    function _vrWitnesses() private {
        _rhCandidate(
            0, "binding_lifecycle.replay.proposal_key", keccak256(abi.encode(uint256(1), uint64(1)))
        );
        _rhCandidate(
            2,
            "identity_authority.replay.nonce_allocator",
            keccak256(abi.encode(bytes32(0), uint256(0)))
        );
        HT.Receipt memory accepted = Native(suite.owners[3]).artistNativeReceiptAt(0);
        (bytes memory inner,) = abi.decode(
            _operationPayload(2, address(this), accepted.recordHash), (bytes, R.AuthorityFact)
        );
        (
            uint256 collection,
            T.Binding memory binding,
            T.Authorization memory a,
            T.SignerApproval memory proof
        ) = abi.decode(inner, (uint256, T.Binding, T.Authorization, T.SignerApproval));
        require(
            collection == 1 && binding.artistId == artistId,
            "original accepted singleton Archive body"
        );
        _rhAuthorization(proof.digest, a.nonce);
        _rhCandidate(
            3,
            "acceptance_lifecycle.replay.record_uniqueness",
            keccak256(abi.encode(collection, binding.generation, uint8(1), proof.signer))
        );
        uint256 count = Native(suite.owners[2]).artistNativeReceiptCount();
        for (uint256 i; i < count; ++i) {
            _vrIdentityWitness(Native(suite.owners[2]).artistNativeReceiptAt(i));
        }
        count = Native(suite.owners[5]).artistNativeReceiptCount();
        for (uint256 i; i < count; ++i) {
            HT.Receipt memory row = Native(suite.owners[5]).artistNativeReceiptAt(i);
            require(
                row.operation == 18 && row.artistId == artistId,
                "bounded original Payout source graph"
            );
            (,, T.SignerApproval memory p, T.Authorization memory effective,,,) = abi.decode(
                _operationPayload(18, address(this), row.recordHash),
                (
                    T.PayoutDesignation,
                    T.Authorization,
                    T.SignerApproval,
                    T.Authorization,
                    R.TransitionState,
                    R.TransitionState,
                    Dismissal.PayoutResolutionFacts
                )
            );
            _rhAuthorization(p.digest, effective.nonce);
            vrRecords.push(W.RecordReference(W.RecordKind.PAYOUT_DESIGNATION, row.recordHash));
        }
        _rhCandidate(
            5, "payout_lifecycle.replay.designation_chain", keccak256(abi.encode(artistId))
        );
        _rhCandidate(5, "payout_lifecycle.replay.recovery_rewind", rhRecovery);
        _rhCandidate(2, "identity_authority.replay.one_way_cutover_latch", 0);
    }

    function _vrIdentityWitness(HT.Receipt memory row) private {
        require(row.artistId == artistId, "one actual Identity graph");
        bytes32 hash = row.recordHash;
        if (row.operation == 1) return;
        if (row.operation == 28) {
            R.GuardianRecord memory r = ingress.guardianSetRecord(hash);
            _rhAuthorization(
                ingress.guardianSetDigest(r.terms, T.Authorization(r.nonce, r.signedAt, "")),
                r.nonce
            );
            _rhCandidate(
                2,
                "identity_authority.replay.guardian_set_chain",
                keccak256(abi.encode(artistId, r.nonce))
            );
            vrRecords.push(W.RecordReference(W.RecordKind.GUARDIAN_SET, hash));
        } else if (row.operation == 29) {
            _vrRotationWitness(hash);
        } else if (row.operation == 33) {
            Contest.Record memory r = ingress.identityContestRecord(hash);
            if (r.recordHash == 0) {
                require(
                    ingress.identityContestCause(hash).causeHash == hash, "actual secondary33 cause"
                );
                return;
            }
            _rhCandidate(
                2,
                "identity_authority.replay.contest_record_hash_and_subject_key",
                keccak256(
                    abi.encode(
                        keccak256("subject"),
                        artistId,
                        r.terms.subjectRecordHash,
                        r.terms.evidenceHash,
                        r.terms.reasonHash
                    )
                )
            );
            _rhCandidate(
                2,
                "identity_authority.replay.contest_record_hash_and_subject_key",
                keccak256(abi.encode(keccak256("record"), hash))
            );
        } else if (row.operation == 35) {
            if (hash != rhRecovery) {
                require(
                    hash == ingress.identityRecoveryRecord(rhRecovery).fields.supersededRecordsHash,
                    "actual secondary35 list"
                );
                return;
            }
            _vrRecoveryWitness();
        } else if (row.operation == 36) {
            Succ.DesignationRecord memory r = ingress.successorDesignationRecord(hash);
            _rhAuthorization(
                ingress.successorDesignationDigest(
                    r.terms, T.Authorization(r.nonce, r.signedAt, "")
                ),
                r.nonce
            );
            _rhCandidate(
                2, "identity_authority.replay.succession_chain", keccak256(abi.encode(hash))
            );
            vrRecords.push(W.RecordReference(W.RecordKind.SUCCESSOR_DESIGNATION, hash));
        } else if (row.operation == 37) {
            Succ.DirectiveRecord memory r = ingress.estateDirectiveRecord(hash);
            _rhAuthorization(
                ingress.estateDirectiveDigest(r.terms, T.Authorization(r.nonce, r.signedAt, "")),
                r.nonce
            );
            _rhCandidate(
                2, "identity_authority.replay.directive_chain", keccak256(abi.encode(hash))
            );
            vrRecords.push(W.RecordReference(W.RecordKind.ESTATE_DIRECTIVE, hash));
        } else if (row.operation == 25) {
            Doc.Record memory r = ingress.identityRevisionRecord(hash);
            Doc.Revision memory p = Doc.Revision(
                artistId, r.previousRecordHash, r.revisedRecordHash, r.identityRecordURI
            );
            _rhAuthorization(
                ingress.identityRevisionDigest(p, T.Authorization(r.nonce, r.signedAt, "")), r.nonce
            );
            _rhCandidate(
                2,
                "identity_authority.replay.identity_revision_chain",
                keccak256(abi.encode(artistId, r.previousRevisionRecord, r.previousRecordHash))
            );
            vrRecords.push(W.RecordReference(W.RecordKind.IDENTITY_REVISION, hash));
        } else if (row.operation == 19) {
            Grant.GrantRecord memory r = Grant(address(ingress)).stewardSanctionGrantRecord(hash);
            _rhAuthorization(
                Grant(address(ingress))
                    .stewardSanctionGrantDigest(r.terms, T.Authorization(r.nonce, r.signedAt, "")),
                r.nonce
            );
            _rhCandidate(2, "identity_authority.replay.grant_chain", keccak256(abi.encode(hash)));
            vrRecords.push(W.RecordReference(W.RecordKind.STEWARD_SANCTION_GRANT, hash));
        } else if (row.operation == 51) {
            (
                R.StandingRevocation memory p,
                T.Authorization memory a,
                T.SignerApproval memory proof
            ) = abi.decode(
                _operationPayload(51, address(this), hash),
                (R.StandingRevocation, T.Authorization, T.SignerApproval)
            );
            // StandingRecord.signedAt is observed inclusion; the original signed deadline comes
            // from the admitted Archive authorization, never from that differently named field.
            _rhAuthorization(proof.digest, a.nonce);
            require(
                proof.digest == ingress.standingRevocationDigest(p, a),
                "exact original51 deadline digest"
            );
            _rhCandidate(
                2,
                "identity_authority.replay.standing_revocation_key",
                keccak256(abi.encode(artistId, p.revokedAddress, p.retiredTransitionRecordHash))
            );
            vrRecords.push(W.RecordReference(W.RecordKind.PRIOR_ADDRESS_STANDING_REVOCATION, hash));
        } else {
            revert("unhandled actual Identity native writer in bounded source recipe");
        }
    }

    function _vrRotationWitness(bytes32 hash) private {
        (
            R.Rotation memory p,
            T.Authorization memory oldA,
            T.Authorization memory newA,
            T.SignerApproval memory oldProof,
            T.SignerApproval memory newProof,
            R.RotationRecord memory r
        ) = abi.decode(
            _operationPayload(29, address(this), hash),
            (
                R.Rotation,
                T.Authorization,
                T.Authorization,
                T.SignerApproval,
                T.SignerApproval,
                R.RotationRecord
            )
        );
        require(r.recordHash == hash && p.artistId == artistId, "actual source29 Archive");
        _rhAuthorization(oldProof.digest, oldA.nonce);
        _rhCandidate(
            2,
            "identity_authority.replay.authorization_consumed_digest",
            keccak256(abi.encode(artistId, newProof.digest))
        );
        _rhCandidate(
            2,
            "identity_authority.replay.nonce_allocator",
            keccak256(
                abi.encode(keccak256("rotation_acceptance"), artistId, p.newAddress, newA.nonce)
            )
        );
        _rhCandidate(
            2, "identity_authority.replay.rotation_key", keccak256(abi.encode(artistId, hash))
        );
        require(ingress.rotationRecord(hash).transition.phase == 2, "actual source32 execution");
        _rhCandidate(2, "identity_authority.replay.rotation_execution_key", hash);
        _rhCandidate(
            2,
            "identity_authority.replay.standing_retirement",
            keccak256(abi.encode(artistId, p.oldAddress, hash))
        );
    }

    function _vrRecoveryWitness() private {
        // Original execution evidence is an ABI tuple. A dynamic struct's initial offset is the
        // only envelope added for typed decoding; every field remains the original Archive byte.
        OriginalExecution memory e = abi.decode(
            bytes.concat(
                abi.encode(uint256(32)),
                _operationPayload(35, manager.governanceAuthority(), rhRecovery)
            ),
            (OriginalExecution)
        );
        require(
            e.tag == keccak256("6529STREAM_ARTIST_RECOVERY_REWIND_EXECUTION_EVIDENCE_V3")
                && e.record.recordHash == rhRecovery && e.governance.actionId == rhOriginalAction
                && e.state.manifestHash != 0 && e.evidence.manifestHash == e.state.manifestHash,
            "exact original V3 execution evidence and original35"
        );
        _rhCandidate(2, "identity_authority.replay.recovery_preparation", rhOriginalAction);
        _rhCandidate(
            2,
            "identity_authority.replay.authorization_consumed_digest",
            keccak256(abi.encode(artistId, e.record.acceptanceDigest))
        );
        _rhCandidate(
            2,
            "identity_authority.replay.nonce_allocator",
            keccak256(
                abi.encode(
                    keccak256("rotation_acceptance"),
                    artistId,
                    e.request.newAddress,
                    e.acceptance.nonce
                )
            )
        );
        _rhCandidate(
            2,
            "identity_authority.replay.contest_resolution",
            keccak256(abi.encode(artistId, e.context.causeHash))
        );
        _rhCandidate(
            2,
            "identity_authority.replay.recovery_action",
            keccak256(
                abi.encode(
                    rhOriginalAction,
                    e.context.scopeHash,
                    e.context.oldValueHash,
                    e.context.newValueHash
                )
            )
        );
        _rhCandidate(
            2,
            "identity_authority.replay.standing_retirement",
            keccak256(abi.encode(artistId, e.context.incumbent, rhRecovery))
        );
    }

    function _vrOriginals(address identity, address payout) private view returns (bytes32 value) {
        value = keccak256(
            abi.encode(
                _rhRecoveryFacts(identity),
                RewindOwner(identity).identityRecoveryEvidenceStateV3(artistId, rhOriginalAction),
                RewindOwner(identity).recoveryRevisionContinuationV3(vrRevision),
                RewindOwner(identity).recoveryStandingContinuationV3(vrStanding),
                RewindPayout(payout).payoutRecoveryContinuationV3(vrPayout)
            )
        );
        for (uint256 i; i < vrRecords.length; ++i) {
            W.RecordReference memory r = vrRecords[i];
            W.StatusV3 memory status = r.kind == W.RecordKind.PAYOUT_DESIGNATION
                ? RewindPayout(payout).payoutRecoveryRecordStatusV3(r.recordHash)
                : RewindOwner(identity).recoveryRecordStatusV3(r.kind, r.recordHash);
            value = keccak256(abi.encode(value, r, status, _vrRecord(identity, payout, r)));
        }
        value = keccak256(
            abi.encode(
                value,
                IStreamArtistRotationReads(identity).artistTransitionState(vrRetirement),
                IStreamArtistGuardianVestingHistory(identity)
                    .guardianVestingSnapshot(artistId, vrRetirement),
                IStreamArtistIdentityDismissalOwner(identity)
                    .identityTransitionClosure(artistId, vrRetirement)
            )
        );
    }

    function _vrOperative(address identity, address payout) private view returns (bytes32) {
        (bytes32 retirement, bytes32 revocation, bytes32 judgment, bytes32 continuation) =
            RewindOwner(identity).recoveryStandingScopeV3(artistId, vrRetired);
        return keccak256(
            abi.encode(
                RewindOwner(identity).recoveryRewindInventoryV3(artistId),
                RewindPayout(payout).payoutRewindInventoryV3(artistId),
                retirement,
                revocation,
                judgment,
                continuation,
                IStreamArtistSuccessionReads(identity).operativeSuccessorRecord(artistId),
                IStreamArtistSuccessionReads(identity).operativeEstateDirective(artistId),
                IStreamArtistIdentityRevisionReads(identity).operativeIdentityRecord(artistId)
            )
        );
    }

    function _vrRecord(address identity, address payout, W.RecordReference memory r)
        private
        view
        returns (bytes memory)
    {
        if (r.kind == W.RecordKind.GUARDIAN_SET) {
            return abi.encode(IStreamArtistRotationReads(identity).guardianSetRecord(r.recordHash));
        }
        if (r.kind == W.RecordKind.SUCCESSOR_DESIGNATION) {
            return abi.encode(
                IStreamArtistSuccessionReads(identity).successorDesignationRecord(r.recordHash)
            );
        }
        if (r.kind == W.RecordKind.ESTATE_DIRECTIVE) {
            return abi.encode(
                IStreamArtistSuccessionReads(identity).estateDirectiveRecord(r.recordHash),
                IStreamArtistSuccessionReads(identity).estateDirectivePayload(r.recordHash)
            );
        }
        if (r.kind == W.RecordKind.IDENTITY_REVISION) {
            Doc.Record memory record =
                IStreamArtistIdentityRevisionReads(identity).identityRevisionRecord(r.recordHash);
            return abi.encode(
                record,
                IStreamArtistIdentityRevisionReads(identity)
                    .identityDocumentBytes(record.revisedRecordHash),
                IStreamArtistRotationReads(identity)
                    .identityRevisionProvisionalAssociation(r.recordHash)
            );
        }
        if (r.kind == W.RecordKind.PAYOUT_DESIGNATION) {
            return abi.encode(
                IStreamArtistPayoutOwner(payout).designationRecord(r.recordHash),
                IStreamArtistPayoutTransitionOwner(payout)
                    .payoutDesignationProvisionalAssociation(r.recordHash),
                StreamArtistPayoutLifecycle(payout).payoutAbandonment(r.recordHash)
            );
        }
        if (r.kind == W.RecordKind.STEWARD_SANCTION_GRANT) {
            return abi.encode(
                Grant(identity).stewardSanctionGrantRecord(r.recordHash),
                Grant(identity).stewardSanctionGrantSignature(r.recordHash)
            );
        }
        return
            abi.encode(IStreamArtistRotationReads(identity).standingRevocationRecord(r.recordHash));
    }

    function _rhActive(bytes32 action, uint8 class_, bytes32 scope, bytes32 old_, bytes32 next_)
        private
    {
        address authority = manager.governanceAuthority();
        avm.mockCall(
            authority,
            abi.encodeCall(IStreamGovernanceReads.currentAction, ()),
            abi.encode(true, action, class_, scope, old_, next_)
        );
        (bool active, bytes32 id, uint8 c, bytes32 s, bytes32 o, bytes32 n) =
            IStreamGovernanceReads(authority).currentAction();
        require(
            active && id == action && c == class_ && s == scope && o == old_ && n == next_,
            "exact governed current-action witness"
        );
    }

    function _rhInactive() private {
        _inactive();
        (bool active, bytes32 id, uint8 c, bytes32 s, bytes32 o, bytes32 n) =
            IStreamGovernanceReads(manager.governanceAuthority()).currentAction();
        require(
            !active && id == 0 && c == 0 && s == 0 && o == 0 && n == 0,
            "all-zero inactive context restored"
        );
    }

    function rhExecuteNewSafe(address target, bytes calldata data) external returns (bool) {
        require(msg.sender == address(this), "fixture caller");
        return executeSafe(rotationSafe, rotationKeys, target, 0, data, 0);
    }

    function _rhCandidate(uint8 owner, string memory surface, bytes32 scope) private {
        rhCandidates[owner].push(AH.Origin(keccak256(bytes(surface)), scope));
    }

    function _rhAuthorization(bytes32 digest, uint256 nonce) private {
        _rhCandidate(
            2,
            "identity_authority.replay.authorization_consumed_digest",
            keccak256(abi.encode(artistId, digest))
        );
        _rhCandidate(
            2, "identity_authority.replay.nonce_allocator", keccak256(abi.encode(artistId, nonce))
        );
    }

    function _rhRequest() private view returns (RH.Request memory p) {
        (, p.expectedSourceImportCommitment,) =
            RecoveredOwner(suite.owners[2]).recoveredHydrationImportedPrefix();
        p.records.authority.artistIds = new bytes32[](1);
        p.records.authority.artistIds[0] = artistId;
        p.records.authority.collections = new MH.Collection[](1);
        p.records.authority.collections[0] = MH.Collection(artistId, 1, new AH.PolicyKey[](0));
        for (uint8 owner; owner < 7; ++owner) {
            p.expectedCapabilities[owner] =
                RecoveredOwner(suite.owners[owner]).recoveredAuthorityHydrationCapability();
            CP.Checkpoint memory checkpoint = CP(suite.owners[owner]).authorityCheckpoint();
            p.records.authority.expectedSource[owner] = checkpoint;
            p.records.authority.replayOrigins[owner] = new AH.Origin[](checkpoint.replayCount);
            for (uint256 j; j < checkpoint.replayCount; ++j) {
                (bytes32 key,) = CP(suite.owners[owner]).authorityReplayAt(j);
                bool found;
                for (uint256 k; k < rhCandidates[owner].length; ++k) {
                    if (_rhSourceKey(owner, rhCandidates[owner][k]) != key) continue;
                    p.records.authority.replayOrigins[owner][j] = rhCandidates[owner][k];
                    found = true;
                    break;
                }
                require(found, "exact writer preimage for every real source key");
            }
        }
    }

    function _rhSourceKey(uint8 owner, AH.Origin memory logical) private view returns (bytes32) {
        return keccak256(
            abi.encode(
                keccak256("6529STREAM_ARTIST_OWNER_REPLAY_KEY_V2"),
                block.chainid,
                address(ingress),
                address(coordinator),
                address(archive),
                suite.owners[owner],
                Owner(suite.owners[owner]).domainId(),
                logical.surface,
                logical.scope
            )
        );
    }

    function _rhImported(Successor memory next, Commit.Prepared memory prepared, bytes32 value)
        private
        view
    {
        require(value != 0, "actual operation60 commitment");
        T.SuiteConfiguration memory destination = next.coordinator.suiteConfiguration();
        for (uint8 i; i < 7; ++i) {
            address owner = destination.owners[i];
            T.Snapshot memory after_ = Owner(owner).ownerStateSnapshotV2();
            require(
                after_.revision == prepared.admission.before_[i].revision + 1
                    && after_.recordChainTip == prepared.admission.before_[i].recordChainTip,
                "one destination mutation without fake original receipts"
            );
            require(
                HydrationOwner(owner).authorityHydrationCommitment() == value
                    && Native(owner).artistNativeReceiptCount() == 0,
                "every owner installed, local native journal still empty"
            );
            (RH.OwnerProvenance memory prefix, bytes32 commitment, uint64 installedAt) =
                RecoveredOwner(owner).recoveredHydrationImportedPrefix();
            require(
                commitment == value && installedAt == after_.revision
                    && keccak256(abi.encode(prefix))
                        == keccak256(
                            abi.encode(RH.ownerProvenance(prepared.admission.provenance, i))
                        ),
                "exact full imported prefix including paired native occurrences"
            );
            (, Payload.Payload memory payload) = Payload.decode(prepared.data[i].typedState, i);
            require(
                keccak256(abi.encode(Publications.collect(owner, i)))
                    == keccak256(abi.encode(payload.publications)),
                "original source pointers remain catalogued"
            );
            RH.NonceInventory[] memory nonces =
                Guards.collectNonces(owner, CP(owner).authorityCheckpoint());
            require(
                keccak256(abi.encode(nonces)) == keccak256(abi.encode(payload.nonces)),
                "complete original nonce words and hints"
            );
            _rhGuardCells(
                owner, i, prepared.data[i], prefix, destination, address(next.coordinator)
            );
        }
        require(
            keccak256(abi.encode(IStreamArtistIdentityOwner(next.identity).identity(artistId)))
                == keccak256(
                    abi.encode(IStreamArtistIdentityOwner(suite.owners[2]).identity(artistId))
                ),
            "exact recovered identity"
        );
        require(
            keccak256(abi.encode(next.registry.guardianSetRecord(rhGuardian)))
                == keccak256(abi.encode(ingress.guardianSetRecord(rhGuardian))),
            "exact original guardian body"
        );
        require(
            keccak256(abi.encode(next.registry.identityRecoveryRecord(rhRecovery)))
                == keccak256(abi.encode(ingress.identityRecoveryRecord(rhRecovery))),
            "exact original35 body"
        );
        require(
            _rhRecoveryFacts(next.identity) == _rhRecoveryFacts(suite.owners[2]),
            "original transition, vesting, action and receipt oracle"
        );
        (,,, uint64 sourceCount) = IStreamArtistRecoveryActionOwner(suite.owners[2])
            .identityRecoveryActionState(artistId, currentId);
        (,,, uint64 targetCount) = IStreamArtistRecoveryActionOwner(next.identity)
            .identityRecoveryActionState(artistId, currentId);
        require(sourceCount == targetCount, "full lifetime guardian count imported");
        require(
            keccak256(
                abi.encode(
                    IStreamArtistRecoveredTimingInventory(next.identity).recoveredTimingCheckpoint()
                )
            ) == keccak256(abi.encode(prepared.timing)),
            "separate timing retained"
        );
    }

    function _rhGuardCells(
        address owner,
        uint8 index,
        AH.OwnerData memory data,
        RH.OwnerProvenance memory prefix,
        T.SuiteConfiguration memory destination,
        address destinationCoordinator
    ) private view {
        RH.OriginEnvironment memory env;
        env.chainId = block.chainid;
        env.registry = destination.registry;
        env.coordinator = destinationCoordinator;
        env.archive = destination.archive;
        env.owners = destination.owners;
        for (uint256 j; j < data.origins.length; ++j) {
            bytes32 key = Guards.replayKey(env, index, data.origins[j]);
            if (
                index == 2
                    && data.origins[j].surface
                        == keccak256("identity_authority.replay.one_way_cutover_latch")
            ) {
                require(
                    Owner(owner).replayCell(key).status == 0,
                    "source57 history does not seal destination"
                );
                continue;
            }
            if (
                index == 2
                    && (data.origins[j].surface
                            == keccak256("identity_authority.replay.verified_lane_key")
                        || data.origins[j].surface
                            == keccak256("identity_authority.replay.import_binding"))
            ) {
                T.ReplayCell memory local = Owner(owner).replayCell(key);
                require(
                    local.commitment != 0 && local.kind == 1 && local.status == 2,
                    "actual current56 latch stays current"
                );
                RH.Point memory point = RecoveredOwner(owner).recoveredHydrationReplayPoint(key);
                require(
                    point.ownerIndex == 2
                        && point.ownerRevision < Owner(owner).ownerStateSnapshotV2().revision,
                    "current56 point precedes local60"
                );
                continue;
            }
            require(
                keccak256(abi.encode(Owner(owner).replayCell(key)))
                    == keccak256(abi.encode(data.cells[j])),
                "exact current guard retained"
            );
            bool found;
            for (uint256 k; k < prefix.aliases.length; ++k) {
                if (prefix.aliases[k].originalKey != data.sourceKeys[j]) continue;
                require(
                    keccak256(abi.encode(RecoveredOwner(owner).recoveredHydrationReplayPoint(key)))
                        == keccak256(abi.encode(prefix.aliases[k].admittedAt)),
                    "copied mutation clock retains source origin"
                );
                found = true;
            }
            require(found, "guard belongs to original prefix");
        }
    }

    function _rhRecoveryFacts(address owner) private view returns (bytes32) {
        (bytes32 primary, bytes32 occurrence, bytes32 secondary) =
            IStreamArtistIdentityRecoveryOwner(owner).identityRecoveryReceipts(rhRecovery);
        // The fourth return is today's lifetime guardian count, which a fresh28 must increase.
        // Only the original immutable action association/veto/execution belong in this digest.
        (
            RecoveryAction.Association memory action,
            RecoveryAction.Veto memory veto,
            bytes32 execution,
        ) = IStreamArtistRecoveryActionOwner(owner)
            .identityRecoveryActionState(artistId, rhOriginalAction);
        return keccak256(
            abi.encode(
                IStreamArtistIdentityRecoveryOwner(owner).identityRecoveryRecord(rhRecovery),
                IStreamArtistRotationReads(owner).artistTransitionState(rhRecovery),
                IStreamArtistGuardianVestingHistory(owner)
                    .guardianVestingSnapshot(artistId, rhRecovery),
                IStreamArtistIdentityDismissalOwner(owner)
                    .identityTransitionClosure(artistId, rhRecovery),
                primary,
                occurrence,
                secondary,
                action,
                veto,
                execution
            )
        );
    }

    function _rhSourceHash() private view returns (bytes32 hash) {
        for (uint8 i; i < 7; ++i) {
            hash = keccak256(
                abi.encode(
                    hash,
                    CP(suite.owners[i]).authorityCheckpoint(),
                    Publications.collect(suite.owners[i], i)
                )
            );
        }
        return keccak256(
            abi.encode(
                hash,
                _rhRecoveryFacts(suite.owners[2]),
                ingress.identityRecoveryRecord(rhRecovery),
                ingress.guardianSetRecord(rhGuardian)
            )
        );
    }

    function _rhDestinationHash(Successor memory next) private view returns (bytes32 hash) {
        T.SuiteConfiguration memory s = next.coordinator.suiteConfiguration();
        for (uint8 i; i < 7; ++i) {
            (RH.OwnerProvenance memory prefix, bytes32 value, uint64 importedAt) =
                RecoveredOwner(s.owners[i]).recoveredHydrationImportedPrefix();
            hash = keccak256(
                abi.encode(
                    hash,
                    CP(s.owners[i]).authorityCheckpoint(),
                    prefix,
                    value,
                    importedAt,
                    Publications.collect(s.owners[i], i)
                )
            );
        }
        return keccak256(
            abi.encode(
                hash,
                IStreamArtistIdentityOwner(next.identity).identity(artistId),
                IStreamArtistRecoveredTimingInventory(next.identity).recoveredTimingCheckpoint()
            )
        );
    }

    function _rhCutover() private returns (Successor memory next) {
        next = _rhNext();
        HT.Leaf[] memory rows = _rhLeaves(History(address(ingress)));
        (bytes32 root,) = _rhProof(address(ingress), rows, 0);
        bytes32 manifest = keccak256("recovered actual source manifest");
        HT.Context memory c = History(address(next.registry))
            .artistHistoryImportContext(address(ingress), uint64(block.number), root, manifest);
        _rhCandidate(
            2,
            "identity_authority.replay.governance_action",
            keccak256(
                abi.encode(
                    keccak256("unit authority gas raise"),
                    c.scopeHash,
                    c.oldValueHash,
                    c.newValueHash
                )
            )
        );
        _rhCandidate(
            2,
            "identity_authority.replay.import_binding_key",
            keccak256(
                abi.encode(HT.Binding(address(ingress), uint64(block.number), root, manifest))
            )
        );
        _rhCandidate(
            2,
            "identity_authority.replay.verified_lane_key",
            keccak256(abi.encode(uint8(1), artistId))
        );
        _rhCandidate(
            2,
            "identity_authority.replay.import_binding",
            keccak256(abi.encode(uint256(0), uint8(1), artistId))
        );
        _rhCandidate(
            2,
            "identity_authority.replay.verified_lane_key",
            keccak256(abi.encode(uint8(2), bytes32(uint256(1))))
        );
        _rhCandidate(
            2,
            "identity_authority.replay.import_binding",
            keccak256(abi.encode(uint256(0), uint8(2), bytes32(uint256(1))))
        );
        ArtistUnitGovernance authority = ArtistUnitGovernance(manager.governanceAuthority());
        authority.configureContestReads(
            suite.roleRegistry, address(artist), manifest, "urn:history"
        );
        avm.mockCall(
            address(authority),
            abi.encodeWithSignature("currentAction()"),
            abi.encode(
                true,
                keccak256("unit authority gas raise"),
                uint8(1),
                c.scopeHash,
                c.oldValueHash,
                c.newValueHash
            )
        );
        (
            bool active,
            bytes32 action,
            uint8 class_,
            bytes32 scope,
            bytes32 oldHash,
            bytes32 newHash
        ) = IStreamGovernanceReads(address(authority)).currentAction();
        require(
            active && action == keccak256("unit authority gas raise") && class_ == 1
                && scope == c.scopeHash && oldHash == c.oldValueHash && newHash == c.newValueHash,
            "exact current op55 witness"
        );
        require(
            this.executeTargetSafe(
                address(authority),
                abi.encodeCall(
                    ArtistUnitGovernance.executeModuleContext,
                    (
                        address(next.registry),
                        abi.encodeCall(
                            History.commitArtistHistoryImportRoot,
                            (address(ingress), uint64(block.number), root, manifest)
                        ),
                        uint8(1),
                        c.scopeHash,
                        c.oldValueHash,
                        c.newValueHash
                    )
                )
            ),
            "actual Safe governed55"
        );
        _inactive();
        (active, action, class_, scope, oldHash, newHash) =
            IStreamGovernanceReads(address(authority)).currentAction();
        require(
            !active && action == 0 && class_ == 0 && scope == 0 && oldHash == 0 && newHash == 0,
            "inactive after actual55"
        );
        core.set(RH_POINTER, address(next.registry), false);
        History(address(ingress)).observeRegistryCutover();
        (, uint64 count) = History(address(ingress)).artistHistoryLane(1, artistId);
        (, bytes32[] memory proof) = _rhProof(address(ingress), rows, count - 1);
        History(address(next.registry)).verifyImportedLaneTip(0, rows[count - 1], proof);
        (, proof) = _rhProof(address(ingress), rows, rows.length - 1);
        History(address(next.registry)).verifyImportedLaneTip(0, rows[rows.length - 1], proof);
    }

    function _rhAdopt(Successor memory next) private {
        ingress = next.registry;
        coordinator = next.coordinator;
        archive = next.archive;
        suite = next.coordinator.suiteConfiguration();
        artist = rotationSafe;
        keys = rotationKeys;
        nextNonce = IStreamArtistIdentityOwner(next.identity).identity(artistId).nonceHint;
    }

    function _rhNext() private returns (Successor memory next) {
        T.SuiteConfiguration memory s = suite;
        address governance = manager.governanceAuthority();
        ArtistSanctionFinalityFixture finalityFixture = new ArtistSanctionFinalityFixture();
        uint256 nonce = avm.getNonce(address(this));
        address registry_ = avm.computeCreateAddress(address(this), nonce);
        address archive_ = avm.computeCreateAddress(address(this), nonce + 1);
        address coordinator_ = avm.computeCreateAddress(address(this), nonce + 9);
        address identity_ = avm.computeCreateAddress(address(this), nonce + 4);
        address[3] memory facade;
        address[3] memory identity;
        for (uint8 i; i < 3; ++i) {
            facade[i] = artistExtensionFactory.deployRegistry(i + 4, registry_, coordinator_);
        }
        for (uint8 i; i < 3; ++i) {
            identity[i] = artistExtensionFactory.deployIdentity(
                i + 1, [identity_, registry_, coordinator_, archive_, s.core, s.mintManager]
            );
        }
        next.registry = StreamArtistOnboardingRegistry(
            payable(_artistArtifactCreate(
                    "smart-contracts/domains/artist/StreamArtistOnboardingRegistry.sol:StreamArtistOnboardingRegistry",
                    abi.encode(
                        s.core,
                        s.mintManager,
                        coordinator_,
                        governance,
                        address(estateCoverageProvider),
                        keccak256("recovered successor deployment"),
                        "urn:recovered-successor",
                        keccak256("recovered successor manifest"),
                        address(artistExtensionFactory),
                        facade
                    )
                ))
        );
        next.archive = StreamArtistArchiveV2(
            payable(_artistArtifactCreate(
                    "smart-contracts/domains/artist/StreamArtistArchiveV2.sol:StreamArtistArchiveV2",
                    abi.encode(registry_, coordinator_)
                ))
        );
        s.registry = registry_;
        s.archive = archive_;
        string[7] memory artifacts_ = [
            "smart-contracts/domains/artist/StreamArtistBindingLifecycle.sol:StreamArtistBindingLifecycle",
            "smart-contracts/domains/artist/StreamArtistCollaboratorLifecycle.sol:StreamArtistCollaboratorLifecycle",
            "smart-contracts/domains/artist/StreamArtistIdentityAuthority.sol:StreamArtistIdentityAuthority",
            "smart-contracts/domains/artist/StreamArtistAcceptanceLifecycle.sol:StreamArtistAcceptanceLifecycle",
            "smart-contracts/domains/artist/StreamArtistAttributionLifecycle.sol:StreamArtistAttributionLifecycle",
            "smart-contracts/domains/artist/StreamArtistPayoutLifecycle.sol:StreamArtistPayoutLifecycle",
            "smart-contracts/domains/artist/StreamArtistConsentFinalityLifecycle.sol:StreamArtistConsentFinalityLifecycle"
        ];
        for (uint8 i; i < 7; ++i) {
            bytes memory args = i == 2
                ? abi.encode(
                    registry_,
                    coordinator_,
                    archive_,
                    s.core,
                    s.mintManager,
                    address(artistExtensionFactory),
                    identity
                )
                : abi.encode(registry_, coordinator_, archive_, s.core, s.mintManager);
            s.owners[i] = _artistArtifactCreate(artifacts_[i], args);
        }
        ArtistUnitGovernance(governance)
            .configureContestReads(
                s.roleRegistry,
                address(artist),
                keccak256("recovered successor finality"),
                "urn:successor"
            );
        address finality = finalityFixture.deploy(s.core, s.metadata, registry_, governance);
        next.coordinator = StreamArtistOnboardingCoordinator(
            payable(_artistArtifactCreate(
                    "smart-contracts/domains/artist/StreamArtistOnboardingCoordinator.sol:StreamArtistOnboardingCoordinator",
                    abi.encode(s, finality)
                ))
        );
        next.identity = s.owners[2];
        require(
            address(next.registry) == registry_ && address(next.archive) == archive_
                && address(next.coordinator) == coordinator_ && next.identity == identity_,
            "actual successor deployment pins"
        );
    }

    function _rhLeaves(History h) private view returns (HT.Leaf[] memory rows) {
        (, uint64 a) = h.artistHistoryLane(1, artistId);
        (, uint64 b) = h.artistHistoryLane(2, bytes32(uint256(1)));
        rows = new HT.Leaf[](uint256(a) + b);
        for (uint64 i; i < a; ++i) {
            (bytes32 r, bytes32 c) = h.artistHistoryRecordAt(1, artistId, i);
            rows[i] = HT.Leaf(1, artistId, i, r, c);
        }
        for (uint64 i; i < b; ++i) {
            (bytes32 r, bytes32 c) = h.artistHistoryRecordAt(2, bytes32(uint256(1)), i);
            rows[uint256(a) + i] = HT.Leaf(2, bytes32(uint256(1)), i, r, c);
        }
    }

    function _rhLeaf(address predecessor, HT.Leaf memory p) private view returns (bytes32) {
        return keccak256(
            bytes.concat(
                keccak256(
                    abi.encode(
                        RH_LEAF,
                        block.chainid,
                        predecessor,
                        p.laneKind,
                        p.laneKey,
                        p.sequence,
                        p.recordHash,
                        p.recordChainHash
                    )
                )
            )
        );
    }

    function _rhProof(address predecessor, HT.Leaf[] memory leaves, uint256 index)
        private
        view
        returns (bytes32 root, bytes32[] memory proof)
    {
        bytes32[] memory layer = new bytes32[](leaves.length);
        proof = new bytes32[](64);
        uint256 used;
        uint256 n = leaves.length;
        for (uint256 i; i < n; ++i) {
            layer[i] = _rhLeaf(predecessor, leaves[i]);
        }
        while (n > 1) {
            if ((index ^ 1) < n) proof[used++] = layer[index ^ 1];
            uint256 nextN = (n + 1) / 2;
            for (uint256 i; i < nextN; ++i) {
                uint256 j = i * 2;
                if (j + 1 == n) {
                    layer[i] = layer[j];
                } else {
                    bytes32 a = layer[j];
                    bytes32 b = layer[j + 1];
                    layer[i] = a < b ? keccak256(abi.encode(a, b)) : keccak256(abi.encode(b, a));
                }
            }
            index /= 2;
            n = nextN;
        }
        root = layer[0];
        assembly ("memory-safe") { mstore(proof, used) }
    }
}

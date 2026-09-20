// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./StreamArtistDormancyRepeatedRecoveryActual.t.sol";
import { StreamArtistHashes } from "../../../smart-contracts/domains/artist/StreamArtistHashes.sol";
import {
    IStreamArtistPayoutTransitionOwner
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistPayoutTransitionOwner.sol";
import {
    IStreamArtistPayoutOwner
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistPayoutOwner.sol";
import {
    StreamArtistSuccessionTypes as Succ
} from "../../../smart-contracts/interfaces/stream/artist/StreamArtistSuccessionTypes.sol";
import {
    StreamArtistRecoveryEvidenceTypes as EV2
} from "../../../smart-contracts/interfaces/stream/artist/StreamArtistRecoveryEvidenceTypes.sol";
import {
    IStreamArtistIdentityRecoveryV2
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistIdentityRecoveryV2.sol";
import {
    IStreamArtistRecoveryEvidence,
    IStreamArtistRecoveryEvidenceBinding
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistRecoveryEvidence.sol";
import {
    IStreamArtistRecoverySelectionPreparation,
    IStreamArtistRecoverySelectionBinding
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistRecoverySelectionPreparation.sol";
import {
    IStreamArtistStewardSanctionGrant as RWGrant
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistStewardSanctionGrant.sol";
import {
    StreamArtistIdentityRevisionTypes as RWRevision
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistIdentityRevision.sol";
import {
    StreamArtistRecoveryRewindTypes as W
} from "../../../smart-contracts/interfaces/stream/artist/StreamArtistRecoveryRewindTypes.sol";
import {
    IStreamArtistIdentityRecoveryV3,
    IStreamArtistIdentityRecoveryOwnerV3
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistIdentityRecoveryV3.sol";
import {
    IStreamArtistRecoveryRewindEvidence
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistRecoveryRewindEvidence.sol";
import {
    IStreamArtistRecoveryRewindSelection
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistRecoveryRewindSelection.sol";
import {
    IStreamArtistRecoveryPayoutOwnerV3
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistRecoveryPayoutOwnerV3.sol";
import {
    IStreamArtistNativeReceipts,
    StreamArtistHistoryTypes as RWHistory
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistHistory.sol";

/// @notice V3 rewinds over original Artist owners, Safes, records and Archive.
/// @dev Governance scheduling/Core are typed unit boundaries; excluded records use actual writers.
contract StreamArtistRecoveryRewindsActualTest is StreamArtistDormancyRepeatedRecoveryActualTest {
    bytes32 private rwExecution;
    bytes32 private rwOrigin;
    bytes32 private rwRetained;
    bytes32 private rwProtected;
    uint256 private rwSalt = 151000;
    bytes32[] private rwRotations;
    bytes32[] private rwRecoveries;
    bytes32[] private rwEstates;
    bytes32[] private rwDismissals;
    bytes32[] private rwNotices;
    W.RecordReference[] private rwRecords;
    bytes32[] private rwOriginalReplayKeys;
    bytes32[] private rwPayoutContinuations;
    address[] private rwStandingAddresses;
    IdentityRecovery.Context private rwScheduledContext;

    error RewindPayoutFailure();

    struct Rewind {
        IdentityRecovery.Request request;
        T.Authorization acceptance;
        W.ResolutionManifestV3 manifest;
        bytes32 manifestHash;
        bytes32 expectedRole;
        W.ResultV3 selection;
    }

    function testRewindDesignationSelectsActualLateLowerNonceAndKeepsNonceSpent() public {
        _rwSetup(0, 0);
        bytes32 high = _rwDesignation(address(0xAA), 4095, 0, 90);
        bytes32 low = _rwDesignation(address(0xBB), 512, 0, 20);
        bytes32 middle = _rwDesignation(address(0xCC), 256, 0, 40);
        require(
            ingress.operativeSuccessorRecord(artistId) == high,
            "late lower originals remain off-head"
        );
        _rwCompromise(0);
        Rewind memory b = _rwBundle(_rwOne(W.RecordKind.SUCCESSOR_DESIGNATION, high));
        _rwSeal(b);
        require(
            b.selection.designation.operative.recordHash == middle
                && b.selection.designation.operative.nonce == 40,
            "highest retained original nonce"
        );
        W.ReceiptPrefix memory payout = _rwPrefix(5);
        _rwRegister(b);
        _rwFinish(b, 2);
        require(
            ingress.operativeSuccessorRecord(artistId) == middle
                && ingress.successorDesignationRecord(low).recordHash == low
                && IStreamArtistIdentityOwner(suite.owners[2]).nonceUsed(artistId, 90)
                && keccak256(abi.encode(payout)) == keccak256(abi.encode(_rwPrefix(5))),
            "restored current head, immutable lower history and unchanged uninvolved Payout"
        );
        _rwMature();
        bytes32 fresh = _rwDesignation(address(0xDD), 4095, 0, 91);
        require(
            ingress.operativeSuccessorRecord(artistId) == fresh,
            "future original36 advances normally"
        );
    }

    function testRewindDirectiveUsesOffHeadNonceAndFutureOriginalWriter() public {
        _rwSetup(0, 0);
        bytes32 high = _rwDirective(4, 91);
        _rwDirective(2, 21);
        bytes32 retained = _rwDirective(8, 41);
        _rwCompromise(0);
        Rewind memory b = _rwBundle(_rwOne(W.RecordKind.ESTATE_DIRECTIVE, high));
        _rwRecover(b, 0);
        require(
            ingress.operativeEstateDirective(artistId) == retained,
            "retained directive selected by original nonce"
        );
        _rwMature();
        bytes32 fresh = _rwDirective(0, 92);
        require(
            ingress.operativeEstateDirective(artistId) == fresh,
            "restored37 head supports fresh signed37"
        );
    }

    function testRewindOriginal19FalseWithdrawalWinsOverOlderTrueGrant() public {
        _rwSetup(0, 0);
        bytes32 high = _rwGrant(true, 92);
        bytes32 lower = _rwGrant(true, 22);
        bytes32 withdrawal = _rwGrant(false, 42);
        _rwCompromise(0);
        Rewind memory b = _rwBundle(_rwOne(W.RecordKind.STEWARD_SANCTION_GRANT, high));
        _rwRecover(b, 0);
        (bool granted, bytes32 selected) = RWGrant(address(ingress)).stewardSanctionGrant(artistId);
        require(
            !granted && selected == withdrawal
                && RWGrant(address(ingress)).stewardSanctionGrantRecord(lower).terms.granted,
            "false original19 is the winning record, not an invitation to search earlier true"
        );
        _rwMature();
        bytes32 fresh = _rwGrant(true, 93);
        (granted, selected) = RWGrant(address(ingress)).stewardSanctionGrant(artistId);
        require(granted && selected == fresh, "new original19 after restoration");
    }

    function testRewindIdentityHeadUsesFreshContinuationWithoutReopeningOriginalCell() public {
        _rwSetup(0, 0);
        bytes32 base = _rwRevision("retained revision A");
        bytes32 child = _rwRevision("excluded revision B");
        bytes32 oldKey = _rwRevisionKey(child);
        T.ReplayCell memory oldCell = IStreamArtistOwner(suite.owners[2]).replayCell(oldKey);
        require(oldCell.commitment == child && oldCell.status == 2, "original predecessor consumed");
        _rwCompromise(0);
        Rewind memory b = _rwBundle(_rwOne(W.RecordKind.IDENTITY_REVISION, child));
        _rwRecover(b, 2);
        require(
            ingress.operativeIdentityRecord(artistId) == keccak256("retained revision A"),
            "actual document rewind"
        );
        _rwMature();
        bytes32 fresh = _rwRevision("fresh revision C after recovery");
        bytes32 continuation = _rwOwner().identityRevisionRecoveryContinuationV3(fresh);
        W.RevisionContinuationV3 memory c = _rwOwner().recoveryRevisionContinuationV3(continuation);
        require(
            continuation != 0 && c.stableRevisionRecordHash == base
                && c.stableDocumentHash == keccak256("retained revision A")
                && c.resolvedChildRecordHash == child && c.recoveryRecordHash == rwExecution
                && ingress.identityRevisionRecord(fresh).previousRevisionRecord == base
                && keccak256(abi.encode(IStreamArtistOwner(suite.owners[2]).replayCell(oldKey)))
                    == keccak256(abi.encode(oldCell)),
            "new branch uses recovery evidence and retains original consumed cell"
        );
    }

    function testRewindPayoutHeadUsesOriginalPreimageAndBothOwnerFailureRetries() public {
        _rwSetup(0, 0);
        bytes32 base = _rwPayout(address(0x1001));
        bytes32 child = _rwPayout(address(0x1002));
        _rwCompromise(0);
        Rewind memory b = _rwBundle(_rwOne(W.RecordKind.PAYOUT_DESIGNATION, child));
        _rwRecover(b, 3);
        (address account, bytes32 selected) = ingress.artistPayoutAccount(artistId);
        require(
            account == address(0x1001) && selected == base, "restored actual payout predecessor"
        );
        W.PayoutInventoryV3 memory inventory = _rwPayoutOwner().payoutRewindInventoryV3(artistId);
        require(
            inventory.continuationCommitment != 0, "supplemental payout branch evidence retained"
        );
        _rwMature();
        bytes32 fresh = _rwPayout(address(0x1003));
        _rwAssertPayoutAdmission(fresh, inventory.continuationCommitment);
        require(
            IStreamArtistPayoutOwner(suite.owners[5])
                .designationRecord(fresh)
                .previousDesignationRecordHash == base
                && StreamArtistPayoutLifecycle(suite.owners[5]).payoutAbandonment(child) == 0,
            "future18 follows restored branch without synthetic58 abandonment"
        );
        _rwCompromise(0);
        _rwRecover(_rwBundle(new W.RecordReference[](0)), 0);
    }

    function testRewindPayoutOriginalRejectsWrongFieldsBeforeCanonicalPublication() public {
        _rwSetup(0, 0);
        bytes32 record = _rwPayout(address(0x1601));
        W.PayoutOriginalV3 memory original = _rwPayoutOriginal(record);
        bytes32 roots = _roots();
        IStreamArtistRecoveryRewindEvidence publisher = _rwPublisher();
        vm.expectRevert(abi.encodeWithSelector(W.InvalidRecoveryPayoutOriginal.selector, record));
        publisher.payoutOriginalV3(record);
        for (uint256 fault; fault < 6; ++fault) {
            W.PayoutOriginalV3 memory bad = abi.decode(abi.encode(original), (W.PayoutOriginalV3));
            if (fault == 0) bad.signer = address(0xBAD);
            if (fault == 1) bad.authorityClass = 3;
            if (fault == 2) ++bad.nonce;
            if (fault == 3) ++bad.signedAt;
            if (fault == 4) {
                bad.terms.previousDesignationRecordHash = keccak256("wrong predecessor");
            }
            if (fault == 5) bad.terms.payoutAccount = address(0xBAD);
            vm.expectRevert(
                abi.encodeWithSelector(W.InvalidRecoveryPayoutOriginal.selector, record)
            );
            publisher.publishPayoutOriginalV3(bad);
        }
        bytes32 hash = publisher.publishPayoutOriginalV3(original);
        require(
            hash
                    == keccak256(
                        abi.encode(
                            keccak256("6529STREAM_ARTIST_RECOVERY_PAYOUT_ORIGINAL_V3"),
                            uint16(3),
                            _rwEnvironment(),
                            original
                        )
                    ) && publisher.publishPayoutOriginalV3(original) == hash && _roots() == roots,
            "wrong preimages cannot poison exact original content or mutate owners"
        );
        _rwCompromise(0);
        _rwRecover(_rwBundle(_rwOne(W.RecordKind.PAYOUT_DESIGNATION, record)), 0);
    }

    function testRewindInteriorExclusionKeepsActualRetainedDescendants() public {
        _rwSetup(0, 0);
        _rwRevision("interior base document");
        bytes32 middle = _rwRevision("interior excluded document");
        bytes32 tip = _rwRevision("retained descendant document");
        _rwPayout(address(0x1101));
        bytes32 middlePayout = _rwPayout(address(0x1102));
        bytes32 payoutTip = _rwPayout(address(0x1103));
        _rwCompromise(0);
        Rewind memory b = _rwBundle(
            _rwPair(
                W.RecordKind.IDENTITY_REVISION,
                middle,
                W.RecordKind.PAYOUT_DESIGNATION,
                middlePayout
            )
        );
        _rwRecover(b, 0);
        (, bytes32 selected) = ingress.artistPayoutAccount(artistId);
        require(
            b.selection.identityRevision.operative.recordHash == tip && selected == payoutTip
                && ingress.operativeIdentityRecord(artistId)
                    == keccak256("retained descendant document"),
            "interior exclusion does not silently exclude an eligible retained descendant"
        );
    }

    function testRewindRetainedEarlyChildrenStayOccupiedThenExplicitExclusionsReleaseThem() public {
        _rwSetup(0, 0);
        bytes32 stable = _rwRevision("occupied stable document");
        bytes32 stablePayout = _rwPayout(address(0x1201));
        _rwRotate();
        bytes32 child = _rwRevision("occupied early child");
        bytes32 childPayout = _rwPayout(address(0x1202));
        bytes32 earlyExecution = rwExecution;
        _rwCompromise(earlyExecution);
        require(
            ingress.artistTransitionState(earlyExecution).contestedAt
                < ingress.artistTransitionState(earlyExecution).postWindowEndsAt,
            "actual early evidence-contested cohort"
        );
        Rewind memory keep = _rwBundle(new W.RecordReference[](0));
        _rwRecover(keep, 0);
        require(
            keep.selection.identityRevision.retainedCandidateRecordHash == child
                && keep.selection.payout.retainedCandidateRecordHash == childPayout,
            "retained occupied original children"
        );
        _rwMature();
        vm.expectRevert(abi.encodeWithSelector(R.ProvisionalChainOccupied.selector, child));
        this.rewindTryRevision("blocked occupied fork");
        vm.expectRevert(abi.encodeWithSelector(R.ProvisionalChainOccupied.selector, childPayout));
        this.rewindTryPayout(address(0x1203));
        _rwCompromise(0);
        Rewind memory release = _rwBundle(
            _rwPair(
                W.RecordKind.IDENTITY_REVISION, child, W.RecordKind.PAYOUT_DESIGNATION, childPayout
            )
        );
        _rwRecover(release, 2);
        require(
            release.selection.identityRevision.operative.recordHash == stable
                && release.selection.payout.operative.recordHash == stablePayout,
            "release returns exact stable branches"
        );
        _rwMature();
        bytes32 next = _rwRevision("new child after explicit adjudication");
        bytes32 nextPayout = _rwPayout(address(0x1204));
        require(
            ingress.identityRevisionRecord(next).previousRevisionRecord == stable
                && IStreamArtistPayoutOwner(suite.owners[5])
                .designationRecord(nextPayout)
                .previousDesignationRecordHash == stablePayout,
            "explicit release permits both fresh original writers"
        );
    }

    function testRewindOriginalDismissalSiblingNeverSelectsAbandonedSibling() public {
        _rwSetup(0, 0);
        bytes32 stable = _rwRevision("dismissal retained document");
        bytes32 stablePayout = _rwPayout(address(0x1301));
        _rwRotate();
        bytes32 rejected = _rwRevision("abandoned original document");
        bytes32 rejectedPayout = _rwPayout(address(0x1302));
        _rwCompromise(rwExecution);
        bytes32 dismissed = _rwDismiss();
        bytes32 sibling = _rwRevision("actual dismissal replacement");
        bytes32 siblingPayout = _rwPayout(address(0x1303));
        require(
            StreamArtistPayoutLifecycle(suite.owners[5]).payoutAbandonment(rejectedPayout)
                == dismissed,
            "actual58 lazy payout abandonment materialized by original18"
        );
        _rwCompromise(0);
        Rewind memory b = _rwBundle(
            _rwPair(
                W.RecordKind.IDENTITY_REVISION,
                sibling,
                W.RecordKind.PAYOUT_DESIGNATION,
                siblingPayout
            )
        );
        _rwRecover(b, 0);
        require(
            b.selection.identityRevision.operative.recordHash == stable
                && b.selection.payout.operative.recordHash == stablePayout
                && ingress.identityRevisionRecord(rejected).recordHash == rejected,
            "rewind follows selected branch, never abandoned sibling"
        );
        bytes32 continuation =
            _rwPayoutOwner().payoutRewindInventoryV3(artistId).continuationCommitment;
        bytes32 early = _rwPayout(address(0x1304));
        _rwAssertPayoutAdmission(early, continuation);
        require(
            IStreamArtistPayoutTransitionOwner(suite.owners[5])
            .payoutDesignationProvisionalAssociation(early)
            .transitionRecordHash == rwExecution,
            "fresh recovery branch child is genuinely provisional"
        );
        _rwCompromise(rwExecution);
        bytes32 laterDismissal = _rwDismiss();
        bytes32 nextSibling = _rwPayout(address(0x1305));
        require(
            StreamArtistPayoutLifecycle(suite.owners[5]).payoutAbandonment(early) == laterDismissal
                && _rwPayoutOwner().payoutDesignationRecoveryContinuationV3(early) == continuation
                && _rwPayoutOwner().payoutDesignationRecoveryContinuationV3(nextSibling) == 0
                && IStreamArtistPayoutOwner(suite.owners[5])
                .designationRecord(nextSibling)
                .previousDesignationRecordHash == stablePayout,
            "original58 sibling preserves the spent recovery scope and uses its own original admission"
        );
        _rwCompromise(0);
        _rwRecover(_rwBundle(new W.RecordReference[](0)), 0);
    }

    function testRewindFutureActualClass3RevisionStoresHashedAuthorityClass() public {
        _rwSetup(2, 512);
        _rwMature();
        bytes32 base = _rwRevision("class3 retained document");
        bytes32 child = _rwRevision("class3 excluded document");
        RWRevision.Record memory original = ingress.identityRevisionRecord(child);
        require(
            original.authorityClass == 3 && original.signer == address(artist),
            "future actual25 stores actual class3"
        );
        bytes32 expected = keccak256(
            abi.encode(
                bytes32(0x1b7518e9d16da358d15957ec43218eb0b017fbd017e60c75b3126110006034a4),
                block.chainid,
                address(ingress),
                artistId,
                original.previousRecordHash,
                original.revisedRecordHash,
                original.signer,
                uint8(3),
                original.nonce,
                original.signedAt
            )
        );
        require(expected == child, "independent original class3 revision preimage");
        _rwCompromise(0);
        Rewind memory b = _rwBundle(_rwOne(W.RecordKind.IDENTITY_REVISION, child));
        _rwRecover(b, 0);
        require(
            b.selection.identityRevision.operative.recordHash == base
                && ingress.identityRevisionRecord(child).authorityClass == 3,
            "actual class3 selected and retained originals"
        );
    }

    function testRewindClass3RestoredMaskSurvivesRotationAndFurtherV3Recovery() public {
        _rwSetup(0, 0);
        bytes32 retained = _rwDesignation(address(delegateSafe), 512, 0, nextNonce);
        Estate.Execution memory execution = _estateActivateAndAdopt(4095);
        rwOrigin = execution.expectedActivationRecordHash;
        rwExecution = rwOrigin;
        rwEstates.push(rwOrigin);
        (Estate.RequestRecord memory request,, Estate.ExecutionFacts memory original) =
            ingress.estateActivationRecord(rwOrigin);
        _rwMature();
        _rwCompromise(0);
        Rewind memory b =
            _rwBundle(_rwOne(W.RecordKind.SUCCESSOR_DESIGNATION, request.designationRecordHash));
        bytes32 first = _rwRecover(b, 0);
        W.CapabilityContinuationV3 memory continuation =
            _rwOwner().recoveryCapabilityContinuationV3(first);
        require(
            continuation.originalActivationRecordHash == rwOrigin
                && continuation.originalActivationCapabilities == 4095
                && continuation.effectiveCapabilities == 512
                && continuation.designationRecordHash == retained
                && ingress.currentAuthorityCapabilities(artistId).effectiveCapabilities == 512,
            "restored designation supplies exact narrower current authority"
        );
        _rwRotate();
        _rwMature();
        _rwCompromise(0);
        Rewind memory again = _rwBundle(new W.RecordReference[](0));
        _rwRecover(again, 0);
        (,, Estate.ExecutionFacts memory after_) = ingress.estateActivationRecord(rwOrigin);
        require(
            ingress.currentAuthorityCapabilities(artistId).effectiveCapabilities == 512
                && keccak256(abi.encode(original)) == keccak256(abi.encode(after_)),
            "later32 and35 inherit canonical V3 mask without rewriting original40"
        );
        _rwMature();
        _rwCompromise(0);
        _rwRecoverV2();
        require(
            ingress.currentAuthorityCapabilities(artistId).effectiveCapabilities == 512,
            "later original V2 path also authenticates the intervening V3 capability history"
        );
    }

    function testRewindAllDocumentAndPayoutLinksUsesOriginalEmptyFallbacks() public {
        _rwSetup(0, 0);
        bytes32 registration = ingress.operativeIdentityRecord(artistId);
        (, bytes32 firstPayout) = ingress.artistPayoutAccount(artistId);
        bytes32 revision = _rwRevision("only revised document");
        bytes32 payout = _rwPayout(address(0x1501));
        W.RecordReference[] memory list = new W.RecordReference[](3);
        list[0] = W.RecordReference(W.RecordKind.IDENTITY_REVISION, revision);
        list[1] = W.RecordReference(W.RecordKind.PAYOUT_DESIGNATION, firstPayout);
        list[2] = W.RecordReference(W.RecordKind.PAYOUT_DESIGNATION, payout);
        _rwCompromise(0);
        Rewind memory b = _rwBundle(list);
        _rwRecover(b, 3);
        (address account, bytes32 selected) = ingress.artistPayoutAccount(artistId);
        W.SelectedRecordV3 memory empty;
        require(
            ingress.operativeIdentityRecord(artistId) == registration && account == address(0)
                && selected == 0
                && keccak256(abi.encode(b.selection.identityRevision.operative))
                    == keccak256(abi.encode(empty))
                && keccak256(abi.encode(b.selection.payout.operative))
                    == keccak256(abi.encode(empty)),
            "registration fallback and wholly empty payout selection are explicit"
        );
        _rwMature();
        bytes32 fresh = _rwPayout(address(0x1502));
        require(
            IStreamArtistPayoutOwner(suite.owners[5])
            .designationRecord(fresh)
            .previousDesignationRecordHash == 0,
            "new18 starts from actual restored empty branch"
        );
    }

    function testRewindStandingOriginalScopeReauthorizesWithFreshRecoveryContinuation() public {
        _rwSetup(0, 0);
        address retired = address(artist);
        _rwRotate();
        bytes32 retirement = rwExecution;
        R.RotationRecord memory t = ingress.rotationRecord(retirement);
        vm.warp(uint256(t.transition.postWindowEndsAt) + t.standingTail);
        bytes32 revoked = _rwStanding(retired, retirement);
        bytes32 oldKey = _rwReplayKey(
            keccak256("identity_authority.replay.standing_revocation_key"),
            keccak256(abi.encode(artistId, retired, retirement))
        );
        T.ReplayCell memory oldCell = IStreamArtistOwner(suite.owners[2]).replayCell(oldKey);
        _rwCompromise(0);
        Rewind memory b = _rwBundle(_rwOne(W.RecordKind.PRIOR_ADDRESS_STANDING_REVOCATION, revoked));
        _rwRecover(b, 0);
        (bool isRevoked,) = ingress.priorAddressStandingRevoked(artistId, retired);
        require(
            !isRevoked && b.selection.standing.length == 1
                && b.selection.standing[0].retirementHash == retirement,
            "only exact retired-address scope restored"
        );
        _rwMature();
        bytes32 next = _rwStanding(retired, retirement);
        bytes32 hash = _rwOwner().standingRevocationRecoveryContinuationV3(next);
        W.StandingContinuationV3 memory c = _rwOwner().recoveryStandingContinuationV3(hash);
        (isRevoked,) = ingress.priorAddressStandingRevoked(artistId, retired);
        require(
            isRevoked && hash != 0 && c.retirementHash == retirement
                && c.supersededRevocationRecordHash == revoked
                && keccak256(abi.encode(IStreamArtistOwner(suite.owners[2]).replayCell(oldKey)))
                    == keccak256(abi.encode(oldCell)),
            "fresh original51 consumes new continuation while original one-use cell remains intact"
        );
    }

    function testRewindRestoredPriorStandingThenIndependent58SurvivesAnotherPlan() public {
        _rwSetup(0, 0);
        OfficialSafe retired = artist;
        uint256[] memory retiredKeys = keys;
        _rwGuardian(address(delegateSafe), nextNonce);
        _rwRotate();
        bytes32 retirement = rwExecution;
        R.RotationRecord memory t = ingress.rotationRecord(retirement);
        vm.warp(uint256(t.transition.postWindowEndsAt) + t.standingTail);
        bytes32 revoked = _rwStanding(address(retired), retirement);
        vm.expectRevert(abi.encodeWithSelector(T.Unauthorized.selector, address(retired)));
        vm.prank(address(retired));
        ingress.contestArtistIdentity(
            artistId, 0, keccak256("revoked prior evidence"), keccak256("revoked prior reason")
        );
        _rwCompromise(0);
        _rwRecover(_rwBundle(_rwOne(W.RecordKind.PRIOR_ADDRESS_STANDING_REVOCATION, revoked)), 0);
        _rwMature();
        require(
            executeSafe(retired, retiredKeys, address(ingress), 0, _contestData(0), 0),
            "restored actual retired Safe33"
        );
        Dismissal.Request memory p = _dismissalRequest();
        p.removePriorStanding = true;
        p.expectedRetirementHash = retirement;
        bytes32 judgment = _rwDismissRequest(p);
        (bool isRevoked, bytes32 source) =
            ingress.priorAddressStandingRevoked(artistId, address(retired));
        require(
            isRevoked && source == judgment, "independent actual58 judgment after real restoration"
        );
        _rwCompromise(0);
        _rwRecover(_rwBundle(new W.RecordReference[](0)), 2);
        (isRevoked, source) = ingress.priorAddressStandingRevoked(artistId, address(retired));
        require(
            isRevoked && source == judgment
                && ingress.identityContestDismissalRecord(judgment).terms.removePriorStanding,
            "later V3 preserves independent58 and does not revive prior permanent51"
        );
    }

    function testRewindMixedPlanSelectsAllFamiliesAgainstOneOriginalSource() public {
        _rwSetup(0, 0);
        address retired = address(artist);
        _rwRotate();
        R.RotationRecord memory t = ingress.rotationRecord(rwExecution);
        vm.warp(uint256(t.transition.postWindowEndsAt) + t.standingTail);
        bytes32 standing = _rwStanding(retired, rwExecution);
        bytes32 goodDirective = _rwDirective(0, nextNonce);
        bytes32 goodDesignation =
            _rwDesignation(address(delegateSafe), 512, goodDirective, nextNonce);
        bytes32 badDirective = _rwDirective(4, nextNonce);
        bytes32 badDesignation = _rwDesignation(address(0xAABB), 4095, badDirective, nextNonce);
        bytes32 goodRevision = _rwRevision("mixed retained revision");
        bytes32 badRevision = _rwRevision("mixed excluded revision");
        bytes32 goodPayout = _rwPayout(address(0x1401));
        bytes32 badPayout = _rwPayout(address(0x1402));
        bytes32 goodGrant = _rwGrant(false, nextNonce);
        bytes32 badGrant = _rwGrant(true, nextNonce);
        W.RecordReference[] memory list = new W.RecordReference[](7);
        list[0] = W.RecordReference(W.RecordKind.GUARDIAN_SET, rwProtected);
        list[1] = W.RecordReference(W.RecordKind.SUCCESSOR_DESIGNATION, badDesignation);
        list[2] = W.RecordReference(W.RecordKind.ESTATE_DIRECTIVE, badDirective);
        list[3] = W.RecordReference(W.RecordKind.IDENTITY_REVISION, badRevision);
        list[4] = W.RecordReference(W.RecordKind.PAYOUT_DESIGNATION, badPayout);
        list[5] = W.RecordReference(W.RecordKind.STEWARD_SANCTION_GRANT, badGrant);
        list[6] = W.RecordReference(W.RecordKind.PRIOR_ADDRESS_STANDING_REVOCATION, standing);
        _rwCompromise(rwExecution);
        Rewind memory b =
            _rwBundleWithEvidence(list, _rwDeclarations(rwExecution, 0), _rwList(rwProtected, 0));
        _rwSeal(b);
        require(
            b.selection.guardians.selectedRecordHash == rwRetained
                && b.selection.designation.operative.recordHash == goodDesignation
                && b.selection.directive.operative.recordHash == goodDirective
                && b.selection.identityRevision.operative.recordHash == goodRevision
                && b.selection.payout.operative.recordHash == goodPayout
                && b.selection.sanctionGrant.operative.recordHash == goodGrant
                && b.selection.standing.length == 1,
            "all independently elected original winners share one complete immutable plan"
        );
        _rwRegister(b);
        _rwFinish(b, 3);
        require(
            ingress.operativeSuccessorRecord(artistId) == goodDesignation
                && ingress.operativeEstateDirective(artistId) == goodDirective
                && ingress.operativeIdentityRecord(artistId)
                    == keccak256("mixed retained revision"),
            "all operative reads restored atomically"
        );
    }

    function testRewindCurrentStandingCauseWithZeroExecutionPreservesOriginalAbortedP() public {
        _rwSetup(0, 0);
        bytes32 grant = _rwGrant(true, nextNonce);
        bytes32 pending = _rwCapture(true, 0);
        Rewind memory b = _rwBundle(_rwOne(W.RecordKind.STEWARD_SANCTION_GRANT, grant));
        _rwRecover(b, 2);
        require(
            b.manifest.executedHead == 0 && b.manifest.contestedVestings.length == 0
                && ingress.identityRecoveryRecord(rwExecution).terms.expectedCauseHash
                    == b.request.expectedCauseHash,
            "genuine zero-execution C2 needs no fabricated vesting or Contest"
        );
        _rwEmptyClosure(pending);
        _missing(pending);
    }

    function testRewindOriginal43StandingCauseUsesExplicitEmptyExclusionPlan() public {
        _rwSetup(4, 0);
        bytes32 origin = rwOrigin;
        bytes32 pending = _rwCapture(true, 0);
        Rewind memory b = _rwBundle(new W.RecordReference[](0));
        _rwRecover(b, 0);
        require(
            _snapshot(origin).operationId == 43
                && ingress.currentAuthorityCapabilities(artistId).activationRecordHash == origin
                && ingress.currentAuthorityCapabilities(artistId).effectiveCapabilities == 256,
            "original designated43 remains the actual class3 authority origin"
        );
        _rwEmptyClosure(pending);
    }

    function testRewindOldStandingScopeCannotOverwriteLaterRetirementOfSameSafe() public {
        _rwSetup(0, 0);
        OfficialSafe first = artist;
        uint256[] memory firstKeys = keys;
        _rwRotate();
        bytes32 firstRetirement = rwExecution;
        R.RotationRecord memory old = ingress.rotationRecord(firstRetirement);
        vm.warp(uint256(old.transition.postWindowEndsAt) + old.standingTail);
        bytes32 oldRevocation = _rwStanding(address(first), firstRetirement);
        _rwMature();
        rotationSafe = first;
        rotationKeys = firstKeys;
        rwExecution = _stageRotation(ingress.lastArtistTransition(artistId));
        rwRotations.push(rwExecution);
        _executeTimedRotation(rwExecution);
        _adoptRotatedSafe();
        _rwRotate();
        bytes32 secondRetirement = rwExecution;
        R.RotationRecord memory current = ingress.rotationRecord(secondRetirement);
        vm.warp(uint256(current.transition.postWindowEndsAt) + current.standingTail);
        bytes32 currentRevocation = _rwStanding(address(first), secondRetirement);
        _rwCompromise(0);
        Rewind memory b =
            _rwBundle(_rwOne(W.RecordKind.PRIOR_ADDRESS_STANDING_REVOCATION, oldRevocation));
        _rwRecover(b, 0);
        (bool revoked, bytes32 source) =
            ingress.priorAddressStandingRevoked(artistId, address(first));
        (bytes32 retirement, bytes32 pointer,, bytes32 continuation) =
            _rwOwner().recoveryStandingScopeV3(artistId, address(first));
        require(
            revoked && source == currentRevocation && retirement == secondRetirement
                && pointer == currentRevocation && continuation == 0,
            "old-scope adjudication leaves actual later retirement and revocation untouched"
        );
    }

    function testRewindExcludedPairedDirectiveDoesNotSilentlyRelinkDesignation() public {
        _rwSetup(0, 0);
        bytes32 paired = _rwDirective(0, nextNonce);
        _rwDesignation(address(delegateSafe), 512, paired, nextNonce);
        _rwCompromise(0);
        Rewind memory b = _rwBundle(_rwOne(W.RecordKind.ESTATE_DIRECTIVE, paired));
        IStreamArtistRecoveryRewindSelection worker = _rwSelection();
        bytes32 key = worker.beginSelectionV3(b.manifestHash);
        uint256 count = b.manifest.identity.receiptCount + b.manifest.payout.receiptCount;
        for (uint256 i = 1; i < count; ++i) {
            worker.continueSelectionV3(key, 1);
        }
        bytes32 roots = _roots();
        vm.expectRevert(abi.encodeWithSelector(W.InvalidRecoveryRewindSelection.selector, key));
        worker.continueSelectionV3(key, 1);
        require(roots == _roots(), "selected paired directive exclusion rejects whole plan");
    }

    function testRewindFreshDesignationCannotReusePermanentlyExcludedDirective() public {
        _rwSetup(0, 0);
        bytes32 directive = _rwDirective(0, nextNonce);
        _rwCompromise(0);
        _rwRecover(_rwBundle(_rwOne(W.RecordKind.ESTATE_DIRECTIVE, directive)), 0);
        _rwMature();
        require(
            _rwOwner()
            .recoveryRecordStatusV3(W.RecordKind.ESTATE_DIRECTIVE, directive)
            .recoveryRecordHash == rwExecution,
            "original37 is permanently superseded by actual35"
        );
        Succ.Designation memory p = _successorTerms(address(0xD170), 1);
        p.directiveHash = directive;
        T.Authorization memory a = T.Authorization(nextNonce, uint64(block.timestamp), "");
        a.signature = _signature(ingress.successorDesignationDigest(p, a));
        bytes32 roots = _roots();
        bytes32 originals = _rwOriginals();
        W.ReceiptPrefix memory prefix = _rwPrefix(2);
        T.Identity memory identity = IStreamArtistIdentityOwner(suite.owners[2]).identity(artistId);
        bytes32 key = _rwReplayKey(
            keccak256("identity_authority.replay.nonce_allocator"),
            keccak256(abi.encode(artistId, a.nonce))
        );
        T.ReplayCell memory originalCell = IStreamArtistOwner(suite.owners[2]).replayCell(key);
        require(
            !IStreamArtistIdentityOwner(suite.owners[2]).nonceUsed(artistId, a.nonce)
                && originalCell.status == 0,
            "fresh actual nonce before rejected36"
        );
        vm.expectRevert(abi.encodeWithSelector(Succ.InvalidDirective.selector));
        ingress.recordSuccessorDesignation(p, a);
        require(
            roots == _roots() && originals == _rwOriginals()
                && keccak256(abi.encode(prefix)) == keccak256(abi.encode(_rwPrefix(2)))
                && keccak256(abi.encode(identity))
                    == keccak256(
                        abi.encode(IStreamArtistIdentityOwner(suite.owners[2]).identity(artistId))
                    )
                && keccak256(abi.encode(originalCell))
                    == keccak256(abi.encode(IStreamArtistOwner(suite.owners[2]).replayCell(key)))
                && !IStreamArtistIdentityOwner(suite.owners[2]).nonceUsed(artistId, a.nonce),
            "rejected old directive pairing changes no owner, native row, nonce or original evidence"
        );
        bytes32 fresh = _rwDesignation(address(0xD171), 512, 0, a.nonce);
        require(
            ingress.operativeSuccessorRecord(artistId) == fresh
                && IStreamArtistIdentityOwner(suite.owners[2]).nonceUsed(artistId, a.nonce),
            "same unspent nonce remains available to a valid original36"
        );
    }

    function testRewindRetainedIneligibleDesignationKeepsItsDirectiveDependency() public {
        _rwSetup(0, 0);
        bytes32 directive = _rwDirective(0, nextNonce);
        _rwRotate();
        bytes32 candidate = _rwDesignation(address(0xD180), 512, directive, nextNonce);
        _rwCompromise(0);
        R.TransitionState memory transition = ingress.artistTransitionState(rwExecution);
        Succ.DesignationRecord memory original = ingress.successorDesignationRecord(candidate);
        W.IdentityInventoryV3 memory inventory = _rwOwner().recoveryRewindInventoryV3(artistId);
        require(
            transition.contestedAt == 0 && block.timestamp < transition.postWindowEndsAt
                && original.provisional.transitionRecordHash == rwExecution
                && original.provisional.windowEndsAt == transition.postWindowEndsAt
                && inventory.designations.candidate == candidate
                && ingress.operativeSuccessorRecord(artistId) != candidate,
            "genuine unmarked current32 has retained, temporarily ineligible paired36"
        );
        Rewind memory b = _rwBundle(_rwOne(W.RecordKind.ESTATE_DIRECTIVE, directive));
        IStreamArtistRecoveryRewindSelection worker = _rwSelection();
        bytes32 key = worker.beginSelectionV3(b.manifestHash);
        uint256 count = b.manifest.identity.receiptCount + b.manifest.payout.receiptCount;
        for (uint256 i = 1; i < count; ++i) {
            worker.continueSelectionV3(key, 1);
        }
        bytes32 roots = _roots();
        bytes32 originals = _rwOriginals();
        vm.expectRevert(abi.encodeWithSelector(W.InvalidRecoveryRewindSelection.selector, key));
        worker.continueSelectionV3(key, 1);
        require(
            roots == _roots() && originals == _rwOriginals()
                && keccak256(abi.encode(inventory))
                    == keccak256(abi.encode(_rwOwner().recoveryRewindInventoryV3(artistId)))
                && keccak256(abi.encode(original))
                    == keccak256(abi.encode(ingress.successorDesignationRecord(candidate)))
                && _rwOwner()
                .recoveryRecordStatusV3(W.RecordKind.ESTATE_DIRECTIVE, directive)
                .recoveryRecordHash == 0,
            "failed finalization retains the exact candidate and original directive without relinking"
        );
        vm.warp(transition.postWindowEndsAt);
        require(
            ingress.operativeSuccessorRecord(artistId) == candidate
                && ingress.successorDesignationRecord(candidate).terms.directiveHash == directive,
            "untouched candidate can actually mature, so its dependency must be checked before35"
        );
    }

    function testRewindStrictFreshnessRejectsUnrelatedIdentityAdmission() public {
        _rwSetup(0, 0);
        bytes32 other = _rwOtherIdentity();
        Succ.Designation memory high =
            Succ.Designation(other, address(0xBB), 1, 0, keccak256("unrelated high"), 0);
        T.Authorization memory highA = T.Authorization(90, 0, "");
        vm.prank(vm.addr(190001));
        bytes32 oldHead = ingress.recordSuccessorDesignation(high, highA);
        _rwCompromise(0);
        Rewind memory b = _rwBundle(new W.RecordReference[](0));
        _rwSeal(b);
        Succ.Designation memory p =
            Succ.Designation(other, address(0xAA), 1, 0, keccak256("unrelated"), 0);
        T.Authorization memory a = T.Authorization(0, 0, "");
        vm.prank(vm.addr(190001));
        ingress.recordSuccessorDesignation(p, a);
        require(
            ingress.operativeSuccessorRecord(other) == oldHead,
            "new lower nonce remains genuinely off-head"
        );
        _rwExpectStaleSelection(b);
    }

    function testRewindStrictFreshnessChecksPayoutPrefixEvenWithFreshIdentityPrefix() public {
        _rwSetup(0, 0);
        bytes32 other = _rwOtherIdentity();
        _rwCompromise(0);
        Rewind memory b = _rwBundle(new W.RecordReference[](0));
        _rwOtherPayout(other);
        b.manifest.identity = _rwPrefix(2);
        b.manifestHash = _rwPublisher().publishResolutionManifestV3(b.manifest);
        bytes32 roots = _roots();
        vm.expectRevert(
            abi.encodeWithSelector(W.InvalidRecoveryRewindSelection.selector, b.manifestHash)
        );
        _rwSelection().beginSelectionV3(b.manifestHash);
        require(roots == _roots(), "stale Payout source alone rejects selection");
    }

    function testRewindActualPayoutAfterPreparationInvalidatesExecutionWithoutSideEffects() public {
        _rwSetup(0, 0);
        bytes32 other = _rwOtherIdentity();
        _rwCompromise(0);
        Rewind memory b = _rwBundle(new W.RecordReference[](0));
        _rwSeal(b);
        _rwRegister(b);
        _rwOtherPayout(other);
        bytes32 before_ = _rwAtomic(b);
        vm.warp(scheduled.notBefore);
        scheduled.status = GovernanceActionStatus.EXECUTED;
        _publish();
        vm.expectRevert(
            abi.encodeWithSelector(W.InvalidRecoveryRewindSelection.selector, b.selection.sourceKey)
        );
        this.executeRewindV3(b);
        _rwInactive();
        require(before_ == _rwAtomic(b), "genuine18 drift invalidates prepared35 atomically");
    }

    function rewindTryRevision(string calldata document) external returns (bytes32) {
        require(msg.sender == address(this), "fixture self");
        return _rwRevision(document);
    }

    function rewindTryPayout(address account) external returns (bytes32) {
        require(msg.sender == address(this), "fixture self");
        return _rwPayout(account);
    }

    function _rwRevisionKey(bytes32 child) private view returns (bytes32) {
        RWRevision.Record memory r = ingress.identityRevisionRecord(child);
        return _rwReplayKey(
            keccak256("identity_authority.replay.identity_revision_chain"),
            keccak256(abi.encode(artistId, r.previousRevisionRecord, r.previousRecordHash))
        );
    }

    function _rwOtherIdentity() private returns (bytes32 other) {
        T.BindingProposal memory p = _proposal(0);
        p.artistAddress = vm.addr(190001);
        (other,) =
            ingress.proposeArtistBinding(2, p, bytes("unit identity document"), "Other identity");
    }

    function _rwOtherPayout(bytes32 other) private {
        T.PayoutDesignation memory p = T.PayoutDesignation(other, address(0xC0FFEE), 0);
        T.Authorization memory a = T.Authorization(0, 0, "");
        vm.prank(vm.addr(190001));
        ingress.recordPayoutDesignation(p, a);
    }

    function _rwExpectStaleSelection(Rewind memory b) private {
        bytes32 roots = _roots();
        vm.expectRevert(
            abi.encodeWithSelector(W.InvalidRecoveryRewindSelection.selector, b.selection.sourceKey)
        );
        _rwSelection().requireSelectionV3(b.manifestHash);
        require(roots == _roots(), "strict source freshness rejects owner advancement");
    }

    function _rwDismissRequest(Dismissal.Request memory p) private returns (bytes32 record) {
        ArtistAppealUnitRoles(suite.roleRegistry).setArbiter(address(artist), true);
        ArtistUnitGovernance(manager.governanceAuthority())
            .configureContestReads(
                suite.roleRegistry, address(artist), p.reasonHash, "urn:rewind:original58"
            );
        Dismissal.Context memory x = ingress.identityContestDismissalContext(p);
        _rwWitness(x.scopeHash, x.oldValueHash, x.newValueHash);
        record = _dismissalExecute(p, 1, 0);
        _rwInactive();
        rwDismissals.push(record);
        require(
            ingress.identityContestDismissalRecord(record).terms.expectedCauseHash
                == p.expectedCauseHash,
            "exact original58 producer"
        );
    }

    function _rwRecoverV2() private {
        _rwRecoveryGovernanceReads();
        _newRotationSafe(++rwSalt);
        Dismissal.Cause memory cause = ingress.currentIdentityContestCause(artistId);
        IdentityRecovery.Request memory p = IdentityRecovery.Request(
            artistId,
            address(rotationSafe),
            cause.facts.authorityClass,
            cause.causeHash,
            ingress.latestIdentityContestDismissal(artistId),
            keccak256("V2 after original V3 plan"),
            cause.facts.reasonHash,
            new bytes32[](0)
        );
        EV2.ResolutionManifest memory manifest = EV2.ResolutionManifest(
            artistId,
            _ownerSnapshot().revision,
            cause.causeHash,
            p.expectedResolutionHash,
            rwExecution,
            EV2.VestingBasis.NO_CONTESTED_VESTING,
            Appeal27.requestCommitment(p),
            p.evidenceHash,
            new EV2.VestingReference[](0),
            p.supersededRecordHashes
        );
        (address evidence,) =
            IStreamArtistRecoveryEvidenceBinding(suite.owners[2]).recoveryEvidenceBinding();
        bytes32 manifestHash =
            IStreamArtistRecoveryEvidence(evidence).publishResolutionManifest(manifest);
        (address selection,) = IStreamArtistRecoverySelectionBinding(suite.owners[2])
            .recoverySelectionPreparationBinding();
        IStreamArtistRecoverySelectionPreparation worker =
            IStreamArtistRecoverySelectionPreparation(selection);
        bytes32 key = worker.beginSelectionV2(manifestHash);
        (GH.Head memory history,,,) = IStreamArtistGuardianHistory(suite.owners[2])
            .guardianHistoryState(artistId, 0, address(0), 0);
        for (uint64 i; i <= history.count; ++i) {
            Selection.Progress memory progress = worker.continueSelectionV2(key, 1);
            if (progress.complete) break;
        }
        require(
            worker.requireSelectionV2(manifestHash).commitment != 0,
            "completed original V2 selection"
        );
        T.Authorization memory a = _acceptance(p);
        IStreamArtistIdentityRecoveryV2 registry = IStreamArtistIdentityRecoveryV2(address(ingress));
        IdentityRecovery.Context memory c = registry.identityRecoveryContextV2(p, a, manifestHash);
        currentId = keccak256(abi.encode("V2 follows V3", ++rwSalt));
        GovernanceCall[] memory calls = new GovernanceCall[](1);
        calls[0] = GovernanceCall(
            address(ingress),
            0,
            IStreamArtistIdentityRecoveryV2.recoverArtistIdentityV2.selector,
            keccak256(
                abi.encodeCall(
                    IStreamArtistIdentityRecoveryV2.recoverArtistIdentityV2, (p, a, manifestHash)
                )
            ),
            c.scopeHash,
            c.oldValueHash,
            c.newValueHash
        );
        scheduled.status = GovernanceActionStatus.SCHEDULED;
        scheduled.actionClass = 2;
        scheduled.target = address(ingress);
        scheduled.selector = calls[0].selector;
        scheduled.callHash = keccak256(
            abi.encode(
                bytes32(0x10f09566fb70f7947b61639c2a53b3aec872069a8b46edd08ba14eb2b5942b70), calls
            )
        );
        scheduled.notBefore = uint64(block.timestamp + 72 hours);
        scheduled.expiresAfter = scheduled.notBefore + 1 days;
        scheduled.proposer = address(artist);
        scheduled.executor = address(0);
        scheduled.canceller = address(0);
        scheduled.vetoer = address(0);
        scheduled.reasonHash = p.reasonHash;
        scheduled.reasonURI = "urn:unit:V2-after-V3";
        scheduled.manifestHash = keccak256("sealed unit system manifest");
        ArtistUnitGovernance(manager.governanceAuthority())
            .configureContestReads(
                suite.roleRegistry, address(artist), p.reasonHash, scheduled.reasonURI
            );
        _publish();
        bytes32 originals = _rwOriginals();
        uint64 epoch = c.delegationEpoch;
        registry.registerIdentityRecoveryActionV2(currentId, calls, p, a, manifestHash);
        vm.warp(scheduled.notBefore);
        scheduled.status = GovernanceActionStatus.EXECUTED;
        _publish();
        avm.mockCall(
            manager.governanceAuthority(),
            abi.encodeCall(IStreamGovernanceReads.currentAction, ()),
            abi.encode(true, currentId, uint8(2), c.scopeHash, c.oldValueHash, c.newValueHash)
        );
        ArtistUnitGovernance(manager.governanceAuthority())
            .executeModuleContext(
                address(ingress),
                abi.encodeCall(
                    IStreamArtistIdentityRecoveryV2.recoverArtistIdentityV2, (p, a, manifestHash)
                ),
                2,
                c.scopeHash,
                c.oldValueHash,
                c.newValueHash
            );
        _rwInactive();
        bytes32 record = ingress.latestIdentityRecovery(artistId);
        _rwReceipts(record);
        require(
            _rwOriginals() == originals
                && _snapshot(record).previousTransitionRecordHash == rwExecution
                && ingress.identityRecoveryRecord(record).delegationEpoch == epoch + 1,
            "V2 preserves all original V3 ancestry and emits original35 receipts"
        );
        rwExecution = record;
        rwRecoveries.push(record);
        _adoptRotatedSafe();
    }

    function _rwOwner() private view returns (IStreamArtistIdentityRecoveryOwnerV3) {
        return IStreamArtistIdentityRecoveryOwnerV3(suite.owners[2]);
    }

    function _rwRegistry() private view returns (IStreamArtistIdentityRecoveryV3) {
        return IStreamArtistIdentityRecoveryV3(address(ingress));
    }

    function _rwPayoutOwner() private view returns (IStreamArtistRecoveryPayoutOwnerV3) {
        return IStreamArtistRecoveryPayoutOwnerV3(suite.owners[5]);
    }

    function _rwPublisher() private view returns (IStreamArtistRecoveryRewindEvidence p) {
        (address target, bytes32 hash) = _rwOwner().recoveryRewindEvidenceBinding();
        require(hash != 0 && target.codehash == hash, "pinned V3 evidence publisher");
        p = IStreamArtistRecoveryRewindEvidence(target);
        require(
            p.owner() == suite.owners[2] && p.payoutOwner() == suite.owners[5]
                && p.artistRegistry() == address(ingress)
                && p.coordinator() == address(coordinator),
            "original two semantic owners"
        );
    }

    function _rwSelection() private view returns (IStreamArtistRecoveryRewindSelection p) {
        (address target, bytes32 hash) = _rwOwner().recoveryRewindSelectionBinding();
        require(hash != 0 && target.codehash == hash, "pinned V3 selection worker");
        p = IStreamArtistRecoveryRewindSelection(target);
    }

    function _rwPrefix(uint256 owner) private view returns (W.ReceiptPrefix memory) {
        return W.ReceiptPrefix(
            IStreamArtistOwner(suite.owners[owner]).ownerStateSnapshotV2(),
            IStreamArtistNativeReceipts(suite.owners[owner]).artistNativeReceiptCount()
        );
    }

    function _rwEnvironment() private view returns (W.EnvironmentV3 memory) {
        return W.EnvironmentV3(
            block.chainid,
            address(ingress),
            suite.owners[2],
            suite.owners[2].codehash,
            suite.owners[5],
            suite.owners[5].codehash,
            address(coordinator),
            suite.archive,
            suite.core,
            suite.mintManager
        );
    }

    function _rwOne(W.RecordKind kind, bytes32 hash)
        private
        pure
        returns (W.RecordReference[] memory list)
    {
        list = new W.RecordReference[](hash == 0 ? 0 : 1);
        if (hash != 0) list[0] = W.RecordReference(kind, hash);
    }

    function _rwPair(W.RecordKind k1, bytes32 h1, W.RecordKind k2, bytes32 h2)
        private
        pure
        returns (W.RecordReference[] memory list)
    {
        list = new W.RecordReference[](2);
        list[0] = W.RecordReference(k1, h1);
        list[1] = W.RecordReference(k2, h2);
    }

    function _rwBundle(W.RecordReference[] memory excluded) private returns (Rewind memory b) {
        return _rwBundleWithEvidence(excluded, new bytes32[](0), new bytes32[](0));
    }

    function _rwBundleWithEvidence(
        W.RecordReference[] memory excluded,
        bytes32[] memory declared,
        bytes32[] memory hostile
    ) private returns (Rewind memory b) {
        _rwPublishPayouts();
        for (uint256 i = 1; i < excluded.length; ++i) {
            for (uint256 j = i; j != 0 && excluded[j].recordHash < excluded[j - 1].recordHash; --j) {
                (excluded[j], excluded[j - 1]) = (excluded[j - 1], excluded[j]);
            }
        }
        _newRotationSafe(++rwSalt);
        Dismissal.Cause memory c = ingress.currentIdentityContestCause(artistId);
        bytes32[] memory hashes = new bytes32[](excluded.length);
        for (uint256 i; i < hashes.length; ++i) {
            hashes[i] = excluded[i].recordHash;
        }
        b.request = IdentityRecovery.Request(
            artistId,
            address(rotationSafe),
            c.facts.authorityClass,
            c.causeHash,
            ingress.latestIdentityContestDismissal(artistId),
            keccak256(abi.encode("V3 resolution evidence", ++rwSalt)),
            c.facts.kind == 1 ? c.facts.reasonHash : keccak256("V3 standing reason"),
            hashes
        );
        b.manifest = W.ResolutionManifestV3(
            artistId,
            _rwPrefix(2),
            _rwPrefix(5),
            c.causeHash,
            b.request.expectedResolutionHash,
            rwExecution,
            declared.length == 0
                ? EV2.VestingBasis.NO_CONTESTED_VESTING
                : EV2.VestingBasis.DECLARED_VESTINGS,
            Appeal27.requestCommitment(b.request),
            b.request.evidenceHash,
            new EV2.VestingReference[](declared.length),
            excluded
        );
        for (uint256 i; i < declared.length; ++i) {
            b.manifest.contestedVestings[i] =
                EV2.VestingReference(declared[i], _snapshot(declared[i]).commitment);
        }
        bytes32 roots = _roots();
        b.manifestHash = _rwPublisher().publishResolutionManifestV3(b.manifest);
        require(
            b.manifestHash
                == keccak256(
                    abi.encode(
                        keccak256("6529STREAM_ARTIST_RECOVERY_RESOLUTION_MANIFEST_V3"),
                        uint16(3),
                        _rwEnvironment(),
                        b.manifest
                    )
                ),
            "literal V3 manifest environment and value"
        );
        b.expectedRole = hostile.length == 0 ? Appeal27.ARBITER : Appeal27.APPEAL;
        if (hostile.length != 0) {
            W.AppealDocumentV3 memory d = W.AppealDocumentV3(
                b.manifestHash,
                keccak256("V3 original hostile findings"),
                new Appeal27.Finding[](hostile.length)
            );
            for (uint256 i; i < hostile.length; ++i) {
                d.findings[i] = Appeal27.Finding(
                    hostile[i], ingress.guardianSetRecord(hostile[i]).terms.guardians
                );
            }
            b.request.evidenceHash = _rwPublisher().publishAppealV3(d);
        }
        b.acceptance = _acceptance(b.request);
        require(_roots() == roots, "publication changes no semantic owner");
    }

    function _rwSeal(Rewind memory b) private returns (W.ResultV3 memory result) {
        IStreamArtistRecoveryRewindSelection worker = _rwSelection();
        bytes32 roots = _roots();
        bytes32 originals = _rwOriginals();
        bytes32 key = worker.beginSelectionV3(b.manifestHash);
        (W.BasisV3 memory basis, W.ProgressV3 memory progress) = worker.selectionV3(key);
        require(
            !progress.complete && progress.identityProcessed == 0 && progress.payoutProcessed == 0,
            "explicit unprocessed two-owner selection"
        );
        vm.expectRevert(abi.encodeWithSelector(W.InvalidRecoveryRewindSelection.selector, key));
        worker.requireSelectionV3(b.manifestHash);
        uint256 bound = b.manifest.identity.receiptCount + b.manifest.payout.receiptCount
            + basis.identity.guardianHistory.count + 2;
        for (uint256 i; i < bound && !progress.complete; ++i) {
            uint256 previous =
                progress.identityProcessed + progress.payoutProcessed + progress.guardiansProcessed;
            progress = worker.continueSelectionV3(key, 1);
            require(
                progress.identityProcessed + progress.payoutProcessed + progress.guardiansProcessed
                        > previous || progress.complete,
                "bounded scan advances original inventory"
            );
        }
        result = worker.requireSelectionV3(b.manifestHash);
        require(
            progress.complete && result.commitment != 0 && result.sourceKey == key
                && progress.identityProcessed == b.manifest.identity.receiptCount
                && progress.payoutProcessed == b.manifest.payout.receiptCount
                && result.manifestHash == b.manifestHash && _roots() == roots
                && _rwOriginals() == originals,
            "complete immutable two-owner election has no owner write"
        );
        b.selection = result;
    }

    function _rwContext(Rewind memory b) private view returns (IdentityRecovery.Context memory) {
        return _rwRegistry().identityRecoveryContextV3(b.request, b.acceptance, b.manifestHash);
    }

    function _rwRegister(Rewind memory b) private {
        _rwRecoveryGovernanceReads();
        rwScheduledContext = _rwContext(b);
        IdentityRecovery.Context memory c = rwScheduledContext;
        currentId = keccak256(abi.encode("V3 rewind action", ++rwSalt));
        GovernanceCall[] memory calls = new GovernanceCall[](1);
        calls[0] = GovernanceCall(
            address(ingress),
            0,
            IStreamArtistIdentityRecoveryV3.recoverArtistIdentityV3.selector,
            keccak256(
                abi.encodeCall(
                    IStreamArtistIdentityRecoveryV3.recoverArtistIdentityV3,
                    (b.request, b.acceptance, b.manifestHash)
                )
            ),
            c.scopeHash,
            c.oldValueHash,
            c.newValueHash
        );
        scheduled.status = GovernanceActionStatus.SCHEDULED;
        scheduled.actionClass = 2;
        scheduled.target = address(ingress);
        scheduled.selector = calls[0].selector;
        scheduled.callHash = keccak256(
            abi.encode(
                bytes32(0x10f09566fb70f7947b61639c2a53b3aec872069a8b46edd08ba14eb2b5942b70), calls
            )
        );
        scheduled.notBefore = uint64(block.timestamp + 72 hours);
        scheduled.expiresAfter = scheduled.notBefore + 1 days;
        scheduled.proposer = b.expectedRole == Appeal27.APPEAL ? address(this) : address(artist);
        scheduled.executor = address(0);
        scheduled.canceller = address(0);
        scheduled.vetoer = address(0);
        scheduled.reasonHash = b.request.reasonHash;
        scheduled.reasonURI = "urn:unit:rewind-v3";
        scheduled.manifestHash = keccak256("sealed unit system manifest");
        ArtistUnitGovernance(manager.governanceAuthority())
            .configureContestReads(
                suite.roleRegistry, scheduled.proposer, b.request.reasonHash, scheduled.reasonURI
            );
        _publish();
        bytes32 originals = _rwOriginals();
        bytes32 association = _rwRegistry()
            .registerIdentityRecoveryActionV3(
                currentId, calls, b.request, b.acceptance, b.manifestHash
            );
        W.EvidenceStateV3 memory e =
            _rwRegistry().identityRecoveryEvidenceStateV3(artistId, currentId);
        W.PreparationSealV3 memory seal = _rwSelection().preparationSealV3(b.selection.sourceKey);
        require(
            association != 0 && e.associationHash == association && e.manifestHash == b.manifestHash
                && e.requiredRole == b.expectedRole
                && e.selectionCommitment == b.selection.commitment
                && seal.associationHash == association && seal.commitment != 0
                && keccak256(abi.encode(seal.identityAfterPreparation))
                    == keccak256(abi.encode(_ownerSnapshot()))
                && _ownerSnapshot().revision == b.manifest.identity.snapshot.revision + 1
                && _rwPrefix(2).receiptCount == b.manifest.identity.receiptCount
                && keccak256(abi.encode(_rwPrefix(5))) == keccak256(abi.encode(b.manifest.payout))
                && originals == _rwOriginals()
                && keccak256(abi.encode(c)) == keccak256(abi.encode(_rwContext(b))),
            "exact own preparation delta and stable executable context"
        );
    }

    function executeRewindV3(Rewind calldata b) external returns (bytes32) {
        require(msg.sender == address(this), "V3 fixture self");
        IdentityRecovery.Context memory c = rwScheduledContext;
        avm.mockCall(
            manager.governanceAuthority(),
            abi.encodeCall(IStreamGovernanceReads.currentAction, ()),
            abi.encode(true, currentId, uint8(2), c.scopeHash, c.oldValueHash, c.newValueHash)
        );
        ArtistUnitGovernance(manager.governanceAuthority())
            .executeModuleContext(
                address(ingress),
                abi.encodeCall(
                    IStreamArtistIdentityRecoveryV3.recoverArtistIdentityV3,
                    (b.request, b.acceptance, b.manifestHash)
                ),
                2,
                c.scopeHash,
                c.oldValueHash,
                c.newValueHash
            );
        _rwInactive();
        return ingress.latestIdentityRecovery(artistId);
    }

    function _rwRecover(Rewind memory b, uint8 failures) private returns (bytes32 record) {
        _rwSeal(b);
        _rwRegister(b);
        return _rwFinish(b, failures);
    }

    function _rwFinish(Rewind memory b, uint8 failures) private returns (bytes32 record) {
        bytes32 beforeAtomic = _rwAtomic(b);
        bytes32 originals = _rwOriginals();
        bytes32 journal2 = _rwJournal(2, b.manifest.identity.receiptCount);
        bytes32 journal5 = _rwJournal(5, b.manifest.payout.receiptCount);
        uint64 epoch = _rwContext(b).delegationEpoch;
        bytes32 causeBytes = _rwCause(b.request.expectedCauseHash);
        W.PayoutInventoryV3 memory payoutBefore = _rwPayoutOwner().payoutRewindInventoryV3(artistId);
        bytes32 causeKey = _rwReplayKey(
            keccak256("identity_authority.replay.contest_resolution"),
            keccak256(abi.encode(artistId, b.request.expectedCauseHash))
        );
        T.ReplayCell memory emptyReplay;
        require(
            keccak256(abi.encode(IStreamArtistOwner(suite.owners[2]).replayCell(causeKey)))
                == keccak256(abi.encode(emptyReplay)),
            "original current cause unconsumed before35"
        );
        W.EvidenceStateV3 memory e =
            _rwRegistry().identityRecoveryEvidenceStateV3(artistId, currentId);
        vm.warp(scheduled.notBefore);
        scheduled.status = GovernanceActionStatus.EXECUTED;
        _publish();
        if (failures & 1 != 0) {
            avm.mockCallRevert(
                suite.owners[5],
                abi.encodeWithSelector(
                    IStreamArtistRecoveryPayoutOwnerV3.applyRecoveryRewindV3.selector
                ),
                abi.encodeWithSelector(RewindPayoutFailure.selector)
            );
            vm.expectRevert(abi.encodeWithSelector(RewindPayoutFailure.selector));
            this.executeRewindV3(b);
            avm.clearMockedCalls();
            _rwRecoveryGovernanceReads();
            _publish();
            _rwInactive();
            require(_rwAtomic(b) == beforeAtomic, "Payout failure restores all Identity changes");
        }
        if (failures & 2 != 0) {
            _overflow();
            this.executeRewindV3(b);
            _rwInactive();
            vm.roll(restoreBlock);
            require(
                _rwAtomic(b) == beforeAtomic,
                "late Archive restores both owners and all continuations"
            );
        }
        T.Snapshot memory before_ = _ownerSnapshot();
        vm.recordLogs();
        record = this.executeRewindV3(b);
        _assertSnapshot(_snapshot(record), 35, before_, vm.getRecordedLogs());
        _rwReceipts(record);
        require(
            originals == _rwOriginals()
                && _rwJournal(2, b.manifest.identity.receiptCount) == journal2
                && _rwJournal(5, b.manifest.payout.receiptCount) == journal5
                && _rwPrefix(5).receiptCount == b.manifest.payout.receiptCount
                && _rwPrefix(2).receiptCount == b.manifest.identity.receiptCount + 2
                && _snapshot(record).previousTransitionRecordHash == rwExecution
                && ingress.identityRecoveryRecord(record).delegationEpoch == epoch + 1,
            "original records/journals immutable and original35 advances epoch once"
        );
        Estate.AuthorityCapabilities memory caps = ingress.currentAuthorityCapabilities(artistId);
        T.ReplayCell memory consumed = IStreamArtistOwner(suite.owners[2]).replayCell(causeKey);
        (bool accepted,) =
            ingress.rotationAcceptanceNonceState(artistId, b.request.newAddress, b.acceptance.nonce);
        require(
            caps.authorityAddress == b.request.newAddress
                && caps.authorityClass == b.request.vestedAuthorityClass
                && caps.effectiveCapabilities == e.effectiveCapabilities && accepted
                && consumed.commitment == record && consumed.kind == 1 && consumed.status == 2
                && consumed.touchedRevision == before_.revision + 1
                && _rwCause(b.request.expectedCauseHash) == causeBytes,
            "full-plan authority is installed"
        );
        for (uint256 i; i < b.manifest.supersededRecords.length; ++i) {
            W.RecordReference memory r = b.manifest.supersededRecords[i];
            W.StatusV3 memory s = r.kind == W.RecordKind.PAYOUT_DESIGNATION
                ? _rwPayoutOwner().payoutRecoveryRecordStatusV3(r.recordHash)
                : _rwOwner().recoveryRecordStatusV3(r.kind, r.recordHash);
            require(
                s.artistId == artistId && s.kind == r.kind && s.recoveryRecordHash == record
                    && s.actionId == currentId && s.planCommitment == b.selection.commitment,
                "write-once exact typed permanent status"
            );
        }
        _rwAssertPayoutApply(b, record, payoutBefore);
        rwRecoveries.push(record);
        rwExecution = record;
        _adoptRotatedSafe();
    }

    function _rwJournal(uint256 owner, uint256 count) private view returns (bytes32 value) {
        for (uint256 i; i < count; ++i) {
            value = keccak256(
                abi.encode(
                    value, IStreamArtistNativeReceipts(suite.owners[owner]).artistNativeReceiptAt(i)
                )
            );
        }
    }

    /// @dev The local governance fixture deliberately supplies the exact fixed-width read ABI.
    /// Scheduling facts and currentAction remain the separate typed original-action witnesses.
    function _rwRecoveryGovernanceReads() private {
        address executor = manager.governanceAuthority();
        uint256[29] memory bootstrap;
        bootstrap[0] = 1;
        bootstrap[1] = 1;
        bootstrap[2] = uint256(uint160(suite.roleRegistry));
        bootstrap[3] = uint256(suite.roleRegistry.codehash);
        bootstrap[4] = uint256(uint160(executor));
        bootstrap[5] = uint256(executor.codehash);
        avm.mockCall(
            executor,
            abi.encodeCall(IStreamGovernanceReads.systemManifestBootstrapState, ()),
            abi.encode(bootstrap)
        );
        avm.mockCall(
            executor,
            abi.encodeCall(IStreamGovernanceReads.minimumDelay, (uint8(2))),
            abi.encode(uint256(72 hours))
        );
    }

    function _rwAtomic(Rewind memory b) private view returns (bytes32 value) {
        (bool used, uint256 hint) =
            ingress.rotationAcceptanceNonceState(artistId, b.request.newAddress, b.acceptance.nonce);
        value = keccak256(
            abi.encode(
                _roots(),
                _rwPrefix(2),
                _rwPrefix(5),
                _rwOriginals(),
                _rwOwner().recoveryRewindInventoryV3(artistId),
                _rwPayoutOwner().payoutRewindInventoryV3(artistId),
                _rwRegistry().identityRecoveryEvidenceStateV3(artistId, currentId),
                IStreamArtistIdentityOwner(suite.owners[2]).identity(artistId),
                ingress.currentIdentityContestCause(artistId),
                ingress.latestIdentityRecovery(artistId),
                used,
                hint
            )
        );
        for (uint256 i; i < rwRecords.length; ++i) {
            W.RecordReference memory r = rwRecords[i];
            W.StatusV3 memory s = r.kind == W.RecordKind.PAYOUT_DESIGNATION
                ? _rwPayoutOwner().payoutRecoveryRecordStatusV3(r.recordHash)
                : _rwOwner().recoveryRecordStatusV3(r.kind, r.recordHash);
            value = keccak256(abi.encode(value, s));
        }
        for (uint256 i; i < rwStandingAddresses.length; ++i) {
            (bytes32 a, bytes32 r, bytes32 j, bytes32 c) =
                _rwOwner().recoveryStandingScopeV3(artistId, rwStandingAddresses[i]);
            value = keccak256(abi.encode(value, a, r, j, c));
        }
    }

    function _rwOriginals() private view returns (bytes32 value) {
        value = _rwHistory();
        for (uint256 i; i < rwRecords.length; ++i) {
            W.RecordReference memory r = rwRecords[i];
            bytes memory data;
            if (r.kind == W.RecordKind.SUCCESSOR_DESIGNATION) {
                data = abi.encode(ingress.successorDesignationRecord(r.recordHash));
            } else if (r.kind == W.RecordKind.ESTATE_DIRECTIVE) {
                data = abi.encode(
                    ingress.estateDirectiveRecord(r.recordHash),
                    ingress.estateDirectivePayload(r.recordHash)
                );
            } else if (r.kind == W.RecordKind.IDENTITY_REVISION) {
                RWRevision.Record memory d = ingress.identityRevisionRecord(r.recordHash);
                data = abi.encode(
                    d,
                    ingress.identityRevisionProvisionalAssociation(r.recordHash),
                    ingress.identityDocumentBytes(d.revisedRecordHash)
                );
            } else if (r.kind == W.RecordKind.PAYOUT_DESIGNATION) {
                data = abi.encode(
                    IStreamArtistPayoutOwner(suite.owners[5]).designationRecord(r.recordHash),
                    IStreamArtistPayoutTransitionOwner(suite.owners[5])
                        .payoutDesignationProvisionalAssociation(r.recordHash),
                    StreamArtistPayoutLifecycle(suite.owners[5]).payoutAbandonment(r.recordHash),
                    _rwPayoutOwner().payoutDesignationRecoveryContinuationV3(r.recordHash)
                );
            } else if (r.kind == W.RecordKind.STEWARD_SANCTION_GRANT) {
                data = abi.encode(
                    RWGrant(address(ingress)).stewardSanctionGrantRecord(r.recordHash),
                    RWGrant(address(ingress)).stewardSanctionGrantSignature(r.recordHash)
                );
            } else if (r.kind == W.RecordKind.PRIOR_ADDRESS_STANDING_REVOCATION) {
                data = abi.encode(ingress.standingRevocationRecord(r.recordHash));
            } else {
                data = abi.encode(ingress.guardianSetRecord(r.recordHash));
            }
            value = keccak256(abi.encode(value, r, data));
        }
        for (uint256 i; i < rwOriginalReplayKeys.length; ++i) {
            value = keccak256(
                abi.encode(
                    value,
                    rwOriginalReplayKeys[i],
                    IStreamArtistOwner(suite.owners[2]).replayCell(rwOriginalReplayKeys[i])
                )
            );
        }
        for (uint256 i; i < rwPayoutContinuations.length; ++i) {
            value = keccak256(
                abi.encode(
                    value, _rwPayoutOwner().payoutRecoveryContinuationV3(rwPayoutContinuations[i])
                )
            );
        }
    }

    function _rwAssertPayoutApply(
        Rewind memory b,
        bytes32 recovery,
        W.PayoutInventoryV3 memory before_
    ) private {
        bool changed;
        bytes32 released;
        for (uint256 i; i < b.manifest.supersededRecords.length; ++i) {
            W.RecordReference memory ref = b.manifest.supersededRecords[i];
            if (ref.kind != W.RecordKind.PAYOUT_DESIGNATION) continue;
            changed = true;
            if (ref.recordHash == before_.candidate.recordHash) released = ref.recordHash;
        }
        if (released == 0) {
            for (uint256 i; i < b.manifest.supersededRecords.length; ++i) {
                W.RecordReference memory ref = b.manifest.supersededRecords[i];
                if (
                    ref.kind == W.RecordKind.PAYOUT_DESIGNATION
                        && ref.recordHash == before_.stable.recordHash
                ) released = ref.recordHash;
            }
        }
        W.PayoutInventoryV3 memory after_ = _rwPayoutOwner().payoutRewindInventoryV3(artistId);
        W.ReceiptPrefix memory prefix = _rwPrefix(5);
        if (!changed) {
            require(
                keccak256(abi.encode(prefix)) == keccak256(abi.encode(b.manifest.payout))
                    && keccak256(abi.encode(before_)) == keccak256(abi.encode(after_)),
                "no payout exclusions leave complete owner snapshot and inventory unchanged"
            );
            return;
        }
        W.PayoutContinuationV3 memory c =
            _rwPayoutOwner().payoutRecoveryContinuationV3(after_.continuationCommitment);
        require(
            c.artistId == artistId && c.recoveryRecordHash == recovery && c.actionId == currentId
                && c.manifestHash == b.manifestHash && c.planCommitment == b.selection.commitment
                && b.selection.payout.branchCommitment != 0
                && c.identityOwnerRevision == _ownerSnapshot().revision
                && c.previousContinuationHash == before_.continuationCommitment
                && c.releasedChildRecordHash == released
                && c.payoutOwnerRevision == b.manifest.payout.snapshot.revision + 1
                && c.payoutOwnerRevision == prefix.snapshot.revision
                && prefix.snapshot.recordChainTip == b.manifest.payout.snapshot.recordChainTip
                && prefix.receiptCount == b.manifest.payout.receiptCount
                && c.stable.recordHash == b.selection.payout.operative.recordHash
                && c.candidate.recordHash == b.selection.payout.retainedCandidateRecordHash
                && keccak256(abi.encode(c.stable)) == keccak256(abi.encode(after_.stable))
                && keccak256(abi.encode(c.candidate)) == keccak256(abi.encode(after_.candidate))
                && after_.supersessionStateCommitment != before_.supersessionStateCommitment,
            "one exact Payout mutation with historical branch evidence and no synthetic native row"
        );
        bytes32 actual = c.continuationHash;
        c.continuationHash = 0;
        require(
            actual == after_.continuationCommitment && actual != 0
                && actual
                    == keccak256(
                        abi.encode(
                            keccak256("6529STREAM_ARTIST_RECOVERY_PAYOUT_CONTINUATION_V3"),
                            uint16(3),
                            _rwEnvironment(),
                            c
                        )
                    ),
            "literal payout continuation preimage"
        );
        rwPayoutContinuations.push(actual);
    }

    function _rwAssertPayoutAdmission(bytes32 record, bytes32 expected) private view {
        bytes32 hash = _rwPayoutOwner().payoutDesignationRecoveryContinuationV3(record);
        W.PayoutContinuationV3 memory c = _rwPayoutOwner().payoutRecoveryContinuationV3(hash);
        T.PayoutDesignation memory p =
            IStreamArtistPayoutOwner(suite.owners[5]).designationRecord(record);
        T.Payout memory empty;
        bytes32 scope = keccak256(abi.encode(artistId, hash, p.previousDesignationRecordHash));
        bytes32 key = keccak256(
            abi.encode(
                keccak256("6529STREAM_ARTIST_OWNER_REPLAY_KEY_V2"),
                block.chainid,
                address(ingress),
                address(coordinator),
                suite.archive,
                suite.owners[5],
                keccak256("domain:payout_lifecycle"),
                keccak256("payout_lifecycle.replay.recovery_continuation"),
                scope
            )
        );
        T.ReplayCell memory cell = IStreamArtistOwner(suite.owners[5]).replayCell(key);
        require(
            hash == expected && hash != 0 && c.continuationHash == hash
                && p.previousDesignationRecordHash == c.stable.recordHash
                && keccak256(abi.encode(c.candidate)) == keccak256(abi.encode(empty))
                && cell.commitment == record && cell.kind == 1 && cell.status == 2
                && cell.touchedRevision > c.payoutOwnerRevision
                && cell.touchedRevision == _rwPrefix(5).snapshot.revision,
            "actual18 consumes one new Payout continuation and preserves original nonces"
        );
    }

    function _rwRemember(W.RecordKind kind, bytes32 record, uint256 nonce) private {
        rwRecords.push(W.RecordReference(kind, record));
        rwOriginalReplayKeys.push(
            _rwReplayKey(
                keccak256("identity_authority.replay.nonce_allocator"),
                keccak256(abi.encode(artistId, nonce))
            )
        );
        bytes32 surface;
        if (kind == W.RecordKind.SUCCESSOR_DESIGNATION) {
            surface = keccak256("identity_authority.replay.succession_chain");
        }
        if (kind == W.RecordKind.ESTATE_DIRECTIVE) {
            surface = keccak256("identity_authority.replay.directive_chain");
        }
        if (kind == W.RecordKind.STEWARD_SANCTION_GRANT) {
            surface = keccak256("identity_authority.replay.grant_chain");
        }
        if (surface != 0) {
            bytes32 key = _rwReplayKey(surface, keccak256(abi.encode(record)));
            require(
                IStreamArtistOwner(suite.owners[2]).replayCell(key).commitment == record,
                "actual family admission cell"
            );
            rwOriginalReplayKeys.push(key);
        }
        if (kind == W.RecordKind.IDENTITY_REVISION) {
            bytes32 key = _rwRevisionKey(record);
            if (IStreamArtistOwner(suite.owners[2]).replayCell(key).commitment == record) {
                rwOriginalReplayKeys.push(key);
            }
        }
        if (kind == W.RecordKind.PRIOR_ADDRESS_STANDING_REVOCATION) {
            R.StandingRecord memory s = ingress.standingRevocationRecord(record);
            rwOriginalReplayKeys.push(
                _rwReplayKey(
                    keccak256("identity_authority.replay.standing_revocation_key"),
                    keccak256(
                        abi.encode(
                            artistId, s.terms.revokedAddress, s.terms.retiredTransitionRecordHash
                        )
                    )
                )
            );
        }
        nextNonce = IStreamArtistIdentityOwner(suite.owners[2]).identity(artistId).nonceHint;
    }

    function _rwDesignation(address successor, uint32 caps, bytes32 directive, uint256 nonce)
        private
        returns (bytes32 r)
    {
        Succ.Designation memory p = _successorTerms(successor, successor.code.length == 0 ? 1 : 2);
        p.grantedCapabilities = caps;
        p.directiveHash = directive;
        T.Authorization memory a = T.Authorization(nonce, uint64(block.timestamp), "");
        a.signature = _signature(ingress.successorDesignationDigest(p, a));
        r = ingress.recordSuccessorDesignation(p, a);
        _rwRemember(W.RecordKind.SUCCESSOR_DESIGNATION, r, nonce);
    }

    function _rwDirective(uint32 forbidden, uint256 nonce) private returns (bytes32 r) {
        (Succ.Directive memory p, Succ.PublicDocument memory d) = _directiveTerms(forbidden);
        T.Authorization memory a = T.Authorization(nonce, uint64(block.timestamp), "");
        a.signature = _signature(ingress.estateDirectiveDigest(p, a));
        r = ingress.recordEstateDirective(p, a, d);
        _rwRemember(W.RecordKind.ESTATE_DIRECTIVE, r, nonce);
    }

    function _rwGrant(bool granted, uint256 nonce) private returns (bytes32 r) {
        RWGrant.Grant memory p =
            RWGrant.Grant(artistId, granted, keccak256(abi.encode("original19", nonce)));
        T.Authorization memory a = T.Authorization(nonce, uint64(block.timestamp), "");
        a.signature = _signature(RWGrant(address(ingress)).stewardSanctionGrantDigest(p, a));
        r = RWGrant(address(ingress)).recordStewardSanctionGrant(p, a);
        _rwRemember(W.RecordKind.STEWARD_SANCTION_GRANT, r, nonce);
    }

    function _rwRevision(string memory text_) private returns (bytes32 r) {
        uint256 nonce = nextNonce;
        r = _reviseDocument(bytes(text_));
        _rwRemember(W.RecordKind.IDENTITY_REVISION, r, nonce);
    }

    function _rwPayout(address account) private returns (bytes32 r) {
        uint256 nonce = nextNonce;
        r = _dismissalPayout(account);
        _rwRemember(W.RecordKind.PAYOUT_DESIGNATION, r, nonce);
    }

    function _rwPayoutOriginal(bytes32 record)
        private
        view
        returns (W.PayoutOriginalV3 memory original)
    {
        (
            T.PayoutDesignation memory p,,
            T.SignerApproval memory proof,
            T.Authorization memory a,,,
        ) = abi.decode(
            _operationPayload(18, address(this), record),
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
        StreamArtistHashes.Environment memory env = StreamArtistHashes.Environment(
            block.chainid, address(ingress), suite.core, suite.mintManager
        );
        uint8 class_ = StreamArtistHashes.payoutRecordForAuthority(
                env, p, proof.signer, 1, a.nonce, a.time
            ) == record
            ? 1
            : 3;
        require(
            StreamArtistHashes.payoutRecordForAuthority(
                env, p, proof.signer, class_, a.nonce, a.time
            ) == record,
            "original Archive tuple exactly authenticates payout hash"
        );
        original = W.PayoutOriginalV3(record, p, proof.signer, class_, a.nonce, a.time);
    }

    function _rwPublishPayouts() private {
        uint256 count = _rwPrefix(5).receiptCount;
        for (uint256 i; i < count; ++i) {
            RWHistory.Receipt memory row =
                IStreamArtistNativeReceipts(suite.owners[5]).artistNativeReceiptAt(i);
            if (row.operation != 18 || row.artistId != artistId) continue;
            W.PayoutOriginalV3 memory original = _rwPayoutOriginal(row.recordHash);
            bytes32 evidence = _rwPublisher().publishPayoutOriginalV3(original);
            (
                W.PayoutOriginalV3 memory saved,
                bytes32 commitment,
                bytes32 identityCode,
                bytes32 payoutCode
            ) = _rwPublisher().payoutOriginalV3(row.recordHash);
            require(
                evidence == commitment && commitment != 0
                    && identityCode == suite.owners[2].codehash
                    && payoutCode == suite.owners[5].codehash
                    && keccak256(abi.encode(saved)) == keccak256(abi.encode(original)),
                "immutable original payout witness"
            );
        }
    }

    function _rwStanding(address prior, bytes32 retirement) private returns (bytes32 r) {
        R.StandingRevocation memory p = R.StandingRevocation(
            artistId, prior, keccak256(abi.encode("original51", ++rwSalt)), retirement
        );
        T.Authorization memory a = _authorization(false);
        a.signature = _signature(ingress.standingRevocationDigest(p, a));
        r = ingress.revokePriorAddressStanding(p, a);
        _rwRemember(W.RecordKind.PRIOR_ADDRESS_STANDING_REVOCATION, r, a.nonce);
        rwStandingAddresses.push(prior);
    }

    function _rwSetup(uint8 profile, uint32 capabilities) private {
        require(profile == 0 || profile == 2 || profile == 4, "explicit fixture profile");
        if (profile >= 4) {
            this.dsSetup(0);
            rwExecution = ingress.lastArtistTransition(artistId);
            (, GH.Entry memory lower,,) = IStreamArtistGuardianHistory(suite.owners[2])
                .guardianHistoryState(artistId, 1, address(0), 0);
            (, GH.Entry memory upper,,) = IStreamArtistGuardianHistory(suite.owners[2])
                .guardianHistoryState(artistId, 2, address(0), 0);
            rwRetained = lower.recordHash;
            rwProtected = upper.recordHash;
            rwOrigin = ingress.currentAuthorityCapabilities(artistId).activationRecordHash;
            (bytes32 notice,,) = IStreamArtistDormancy(address(ingress)).dormancyNotice(artistId);
            rwNotices.push(notice);
            bytes32 prior = ingress.latestIdentityRecovery(artistId);
            if (prior != 0) rwRecoveries.push(prior);
        } else {
            _deployAppealSuite();
            _accept();
            _payout();
            _delegateSetup();
            address[] memory members = new address[](1);
            members[0] = address(delegateSafe);
            rwRetained = _guardianRecord(members, 1, 10 days, nextNonce);
            members[0] = address(artist);
            rwProtected = _guardianRecord(members, 1, 20 days, nextNonce);
            if (profile >= 2) {
                Estate.Execution memory e = _estateActivateAndAdopt(capabilities);
                rwExecution = e.expectedActivationRecordHash;
                rwOrigin = rwExecution;
                rwEstates.push(rwExecution);
                require(_snapshot(rwExecution).operationId == 40, "actual40 origin");
            }
        }
        ArtistAppealUnitRoles(suite.roleRegistry).setAppeal(address(this), true);
        if (rwExecution == 0) {
            R.TransitionState memory empty;
            require(
                ingress.lastArtistTransition(artistId) == 0
                    && ingress.latestIdentityRecovery(artistId) == 0
                    && keccak256(abi.encode(ingress.artistTransitionState(0)))
                        == keccak256(abi.encode(empty)),
                "genuinely no executed or staged predecessor"
            );
        }
    }

    function _rwMature() private {
        if (rwExecution == 0) return;
        uint64 end = ingress.artistTransitionState(rwExecution).postWindowEndsAt;
        if (block.timestamp < end) vm.warp(end);
    }

    function _rwRotate() private {
        _rwMature();
        bytes32 previous = rwExecution;
        _newRotationSafe(++rwSalt);
        rwExecution = _stageRotation(ingress.lastArtistTransition(artistId));
        rwRotations.push(rwExecution);
        _executeTimedRotation(rwExecution);
        _adoptRotatedSafe();
        V.Snapshot memory v = _snapshot(rwExecution);
        require(
            v.operationId == 32 && v.previousTransitionRecordHash == previous
                && v.previousCommitment
                    == (previous == 0 ? bytes32(0) : _snapshot(previous).commitment),
            "actual32 snapshot follows execution, independently of staging history"
        );
    }

    function _rwWitness(bytes32 scope, bytes32 old_, bytes32 next_) private {
        address authority = manager.governanceAuthority();
        bytes32 id = keccak256("unit authority gas raise");
        avm.mockCall(
            authority,
            abi.encodeCall(IStreamGovernanceReads.currentAction, ()),
            abi.encode(true, id, uint8(1), scope, old_, next_)
        );
        (bool active, bytes32 actual, uint8 class_, bytes32 s, bytes32 o, bytes32 n) =
            IStreamGovernanceReads(authority).currentAction();
        require(
            active && actual == id && class_ == 1 && s == scope && o == old_ && n == next_,
            "exact active original producer witness"
        );
    }

    function _rwInactive() private {
        _inactive();
        (bool active, bytes32 id, uint8 class_, bytes32 s, bytes32 o, bytes32 n) =
            IStreamGovernanceReads(manager.governanceAuthority()).currentAction();
        require(
            !active && id == 0 && class_ == 0 && s == 0 && o == 0 && n == 0,
            "exact inactive action after real producer"
        );
    }

    function _rwCompromise(bytes32 subject) private {
        ArtistAppealUnitRoles(suite.roleRegistry).setArbiter(address(artist), true);
        bytes32 evidence = keccak256(abi.encode("staging family compromise", ++rwSalt));
        bytes32 reason = keccak256(abi.encode("staging family reason", evidence));
        ArtistUnitGovernance authority = ArtistUnitGovernance(manager.governanceAuthority());
        authority.configureContestReads(
            suite.roleRegistry, address(artist), reason, "urn:family:33"
        );
        (bytes32 scope, bytes32 old_, bytes32 next_) =
            ingress.identityContestGovernanceContext(artistId, subject, evidence, reason);
        _rwWitness(scope, old_, next_);
        authority.executeModuleContext(
            address(ingress),
            abi.encodeCall(
                IStreamArtistIdentityContest.contestArtistIdentity,
                (artistId, subject, evidence, reason)
            ),
            1,
            scope,
            old_,
            next_
        );
        _rwInactive();
        Dismissal.Cause memory c = ingress.currentIdentityContestCause(artistId);
        Contest.Record memory saved = ingress.identityContestRecord(c.facts.referenceHash);
        require(
            c.facts.kind == 1 && c.facts.executedTransitionHash == rwExecution
                && saved.recordHash == c.facts.referenceHash
                && saved.terms.subjectRecordHash == subject && saved.terms.evidenceHash == evidence
                && saved.terms.reasonHash == reason && c.facts.incumbent == address(artist)
                && _operationPayload(33, manager.governanceAuthority(), saved.recordHash).length
                    != 0,
            "actual governed33 captures current execution and exact original subject"
        );
    }

    function _rwDismiss() private returns (bytes32 record) {
        Dismissal.Request memory p = _dismissalRequest();
        Dismissal.Cause memory cause = ingress.currentIdentityContestCause(artistId);
        ArtistAppealUnitRoles(suite.roleRegistry).setArbiter(address(artist), true);
        ArtistUnitGovernance(manager.governanceAuthority())
            .configureContestReads(
                suite.roleRegistry, address(artist), p.reasonHash, "urn:unit:dismissal"
            );
        Dismissal.Context memory x = ingress.identityContestDismissalContext(p);
        _rwWitness(x.scopeHash, x.oldValueHash, x.newValueHash);
        record = _dismissalExecute(p, 1, 0);
        _rwInactive();
        rwDismissals.push(record);
        Dismissal.Record memory d = ingress.identityContestDismissalRecord(record);
        require(
            d.terms.expectedCauseHash == cause.causeHash && d.recordHash == record
                && d.actionClass == 1 && d.actionId == keccak256("unit authority gas raise")
                && d.governanceWitnessHash != 0 && d.authorityClass == cause.facts.authorityClass,
            "actual dismissal retains original cause and authority"
        );
        if (cause.facts.pendingTransitionHash != 0) {
            Dismissal.Closure memory closed =
                ingress.identityTransitionClosure(artistId, cause.facts.pendingTransitionHash);
            require(
                closed.dismissalRecordHash == record && closed.abandoned
                    && closed.contestedAt == cause.facts.enteredAt,
                "actual dismissal closes captured pending cohort"
            );
        }
        if (rwExecution == 0) _rwEmptyClosure(0);
    }

    function _rwCapture(bool veto, bytes32 subject) private returns (bytes32 pending) {
        _rwMature();
        ArtistAppealUnitRoles(suite.roleRegistry).setArbiter(address(artist), true);
        _newRotationSafe(++rwSalt);
        pending = _stageRotation(ingress.lastArtistTransition(artistId));
        rwRotations.push(pending);
        bytes32 priorContest = ingress.latestIdentityContest(artistId);
        if (veto) {
            require(
                executeSafe(
                    artist,
                    keys,
                    address(ingress),
                    0,
                    abi.encodeCall(
                        IStreamArtistRotation.vetoArtistRotation, (artistId, pending, bytes32(0))
                    ),
                    0
                ),
                "actual incumbent Safe vetoes pending32 with zero reason"
            );
        } else {
            _rwCompromise(subject);
        }
        Dismissal.Cause memory c = ingress.currentIdentityContestCause(artistId);
        R.TransitionState memory t = ingress.rotationRecord(pending).transition;
        require(
            c.facts.kind == (veto ? 2 : 1) && c.facts.pendingTransitionHash == pending
                && c.facts.executedTransitionHash == rwExecution
                && c.facts.priorStatus == c.facts.authorityClass && t.phase == 3
                && t.executedAt == 0 && t.postWindowEndsAt == 0
                && t.contestedAt == c.facts.enteredAt,
            "real current cause aborts P without installing or dismissing it"
        );
        if (veto) {
            require(
                c.facts.referenceHash == pending && c.facts.evidenceHash == 0
                    && c.facts.reasonHash == 0
                    && ingress.latestIdentityContest(artistId) == priorContest,
                "C2 is original veto with no synthetic Contest"
            );
            T.ReplayCell memory cell = IStreamArtistOwner(suite.owners[2])
                .replayCell(
                    _rwReplayKey(keccak256("identity_authority.replay.rotation_veto_key"), pending)
                );
            require(
                cell.commitment == pending && cell.status == 2 && cell.kind == 1,
                "original veto replay"
            );
        }
        _rwEmptyClosure(pending);
        _missing(pending);
    }

    function _rwEmptyClosure(bytes32 record) private view {
        Dismissal.Closure memory empty;
        require(
            keccak256(abi.encode(ingress.identityTransitionClosure(artistId, record)))
                == keccak256(abi.encode(empty)),
            "complete original closure remains empty"
        );
    }

    function _rwReplayKey(bytes32 operation, bytes32 scope) private view returns (bytes32) {
        IStreamArtistOwner owner = IStreamArtistOwner(suite.owners[2]);
        return keccak256(
            abi.encode(
                keccak256("6529STREAM_ARTIST_OWNER_REPLAY_KEY_V2"),
                block.chainid,
                address(ingress),
                address(coordinator),
                suite.archive,
                address(owner),
                owner.domainId(),
                operation,
                scope
            )
        );
    }

    function _rwCause(bytes32 hash) private view returns (bytes32) {
        Dismissal.Cause memory c = ingress.identityContestCause(hash);
        return keccak256(abi.encode(c, ingress.identityContestRecord(c.facts.referenceHash)));
    }

    function _rwHistory() private view returns (bytes32 value) {
        if (rwOrigin != 0) {
            value = keccak256(
                abi.encode(
                    rwOrigin,
                    _snapshot(rwOrigin),
                    ingress.artistTransitionState(rwOrigin),
                    ingress.identityTransitionClosure(artistId, rwOrigin)
                )
            );
        }
        for (uint256 i; i < rwRotations.length; ++i) {
            bytes32 r = rwRotations[i];
            value = keccak256(
                abi.encode(
                    value,
                    ingress.rotationRecord(r),
                    ingress.artistTransitionState(r),
                    ingress.identityTransitionClosure(artistId, r)
                )
            );
        }
        for (uint256 i; i < rwRecoveries.length; ++i) {
            bytes32 r = rwRecoveries[i];
            IdentityRecovery.Record memory item = ingress.identityRecoveryRecord(r);
            (bytes32 primary, bytes32 occurrence, bytes32 secondary) =
                IStreamArtistIdentityRecoveryOwner(suite.owners[2]).identityRecoveryReceipts(r);
            value = keccak256(
                abi.encode(
                    value,
                    item,
                    _rwOwner().recoveryCapabilityContinuationV3(r),
                    _rwRegistry()
                        .identityRecoveryEvidenceStateV3(artistId, item.fields.governanceActionId),
                    _snapshot(r),
                    ingress.artistTransitionState(r),
                    ingress.identityTransitionClosure(artistId, r),
                    primary,
                    occurrence,
                    secondary
                )
            );
        }
        for (uint256 i; i < rwEstates.length; ++i) {
            (Estate.RequestRecord memory r, uint8 phase, Estate.ExecutionFacts memory e) =
                ingress.estateActivationRecord(rwEstates[i]);
            value = keccak256(
                abi.encode(
                    value,
                    r,
                    phase,
                    e,
                    ingress.artistTransitionState(r.recordHash),
                    ingress.identityTransitionClosure(artistId, r.recordHash)
                )
            );
        }
        for (uint256 i; i < rwDismissals.length; ++i) {
            Dismissal.Record memory d = ingress.identityContestDismissalRecord(rwDismissals[i]);
            Dismissal.Cause memory c = ingress.identityContestCause(d.terms.expectedCauseHash);
            value = keccak256(
                abi.encode(value, d, c, ingress.identityContestRecord(c.facts.referenceHash))
            );
        }
        for (uint256 i; i < rwNotices.length; ++i) {
            (Dormancy27.Notice memory n, uint8 phase, Dormancy27.Terminal memory t) =
                IStreamArtistDormancy(address(ingress)).dormancyRecord(rwNotices[i]);
            value = keccak256(abi.encode(value, n, phase, t));
        }
        (GH.Head memory head,,,) = IStreamArtistGuardianHistory(suite.owners[2])
            .guardianHistoryState(artistId, 0, address(0), 0);
        value = keccak256(abi.encode(value, head));
        for (uint64 i = 1; i <= head.count; ++i) {
            (, GH.Entry memory entry,,) = IStreamArtistGuardianHistory(suite.owners[2])
                .guardianHistoryState(artistId, i, address(0), 0);
            value = keccak256(abi.encode(value, entry, ingress.guardianSetRecord(entry.recordHash)));
        }
    }

    function _rwReceipts(bytes32 record) private view {
        IdentityRecovery.Record memory original = ingress.identityRecoveryRecord(record);
        require(
            record
                    == keccak256(
                        abi.encode(
                            bytes32(
                                0x459749364fd07c3a8f1998b82d893d33ef0942c30d94666b42dac1e37ba5feff
                            ),
                            block.chainid,
                            address(ingress),
                            original.fields.artistId,
                            original.fields.oldAddress,
                            original.fields.newAddress,
                            original.fields.vestedAuthorityClass,
                            original.fields.evidenceHash,
                            original.fields.reasonHash,
                            original.fields.supersededRecordsHash,
                            original.fields.governanceActionId,
                            original.fields.recoveredAt
                        )
                    )
                && original.fields.supersededRecordsHash
                    == keccak256(
                        abi.encode(
                            bytes32(
                                0x0c8573762967a1af597f2a7afc4b655a87b3e22d2b11fbab6cf13c6f7b1396ae
                            ),
                            original.terms.supersededRecordHashes
                        )
                    ),
            "unchanged literal original35 semantic preimages"
        );
        IStreamArtistOwner owner = IStreamArtistOwner(suite.owners[2]);
        T.Snapshot memory s = owner.ownerStateSnapshotV2();
        uint64 sequence = uint64(uint256(vm.load(address(owner), bytes32(0))) >> 64);
        require(sequence >= 2, "two actual receipts");
        bytes32 secondaryDomain = 0x0c8573762967a1af597f2a7afc4b655a87b3e22d2b11fbab6cf13c6f7b1396ae;
        bytes32[13] memory words;
        words[0] = 0x2524f38d4b0732cdfa0810161b89161cfa6da3e7cc1b6cab90fd8b71fbfbd861;
        words[1] = bytes32(uint256(2));
        words[2] = bytes32(block.chainid);
        words[3] = bytes32(uint256(uint160(address(ingress))));
        words[4] = bytes32(uint256(uint160(address(coordinator))));
        words[5] = bytes32(uint256(uint160(suite.archive)));
        words[6] = bytes32(uint256(uint160(address(owner))));
        words[7] = 0x6579e41542b1bfc6684ea87b09373c4f4690857bd046eb4faf0f92a42bc88adb;
        words[8] = bytes32(uint256(s.revision));
        words[9] = bytes32(uint256(sequence - 1));
        words[10] = bytes32(uint256(uint160(manager.governanceAuthority())));
        words[11] = 0x459749364fd07c3a8f1998b82d893d33ef0942c30d94666b42dac1e37ba5feff;
        words[12] = record;
        bytes32 primary = keccak256(abi.encode(words));
        words[9] = bytes32(uint256(sequence));
        words[11] = secondaryDomain;
        words[12] = ingress.identityRecoveryRecord(record).fields.supersededRecordsHash;
        bytes32 secondary = keccak256(abi.encode(words));
        bytes32 occurrence = keccak256(
            abi.encode(
                bytes32(0x05c1b33dc3307a69a2b02b1fdcc96323c6c2dcb072805ca38ec6462ded34ce09),
                uint16(2),
                record,
                secondaryDomain,
                words[12]
            )
        );
        (bytes32 p, bytes32 o, bytes32 x) =
            IStreamArtistIdentityRecoveryOwner(suite.owners[2]).identityRecoveryReceipts(record);
        require(
            p == primary && o == occurrence && x == secondary && p != x && p != record,
            "exact original two receipts and occurrence"
        );
    }

    function _rwList(bytes32 first, bytes32 second) private pure returns (bytes32[] memory values) {
        values = new bytes32[](first == 0 ? 0 : second == 0 ? 1 : 2);
        if (first == 0) return values;
        values[0] = first;
        if (second != 0) {
            values[1] = second;
            if (first > second) (values[0], values[1]) = (second, first);
        }
    }

    function _rwDeclarations(bytes32 oldest, bytes32 newest)
        private
        pure
        returns (bytes32[] memory values)
    {
        values = new bytes32[](oldest == 0 ? 0 : newest == 0 ? 1 : 2);
        if (oldest != 0) values[0] = oldest;
        if (newest != 0) values[1] = newest;
    }

    function _rwGuardian(address member, uint256 nonce) private returns (bytes32 record) {
        address[] memory members = new address[](1);
        members[0] = member;
        record = _guardianRecord(members, 1, 10 days, nonce);
        R.GuardianRecord memory actual = ingress.guardianSetRecord(record);
        require(actual.signer == address(artist) && actual.nonce == nonce, "actual guardian writer");
        if (
            rwExecution != 0
                && block.timestamp < ingress.artistTransitionState(rwExecution).postWindowEndsAt
        ) {
            require(
                actual.provisional.transitionRecordHash == rwExecution
                    && actual.provisional.windowEndsAt
                        == ingress.artistTransitionState(rwExecution).postWindowEndsAt,
                "original association identifies the actual takeover window"
            );
        }
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./StreamArtistDormancyRepeatedRecoveryActual.t.sol";
import {
    StreamArtistRecoveryEvidenceTypes as EV2
} from "../../../smart-contracts/interfaces/stream/artist/StreamArtistRecoveryEvidenceTypes.sol";
import {
    IStreamArtistRecoveryEvidence,
    IStreamArtistRecoveryEvidenceBinding
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistRecoveryEvidence.sol";
import {
    IStreamArtistIdentityRecoveryV2
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistIdentityRecoveryV2.sol";
import {
    IStreamArtistRecoverySelectionPreparation,
    IStreamArtistRecoverySelectionBinding
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistRecoverySelectionPreparation.sol";
import {
    StreamArtistRecoverySelectionTypesV2 as SV2
} from "../../../smart-contracts/interfaces/stream/artist/StreamArtistRecoverySelectionTypesV2.sol";
import {
    StreamArtistSuccessionTypes as AVSucc
} from "../../../smart-contracts/interfaces/stream/artist/StreamArtistSuccessionTypes.sol";

/// @notice Explicit V2 recovery adjudication over original Artist owners, Safes and Archive.
/// @dev Core and action scheduling retain the inherited typed unit boundaries. Original causes,
/// vestings, guardian admissions, dismissals and receipts are produced by their actual writers.
contract StreamArtistRecoveryAdjudicationActualTest is
    StreamArtistDormancyRepeatedRecoveryActualTest
{
    struct Adjudication {
        IdentityRecovery.Request request;
        T.Authorization acceptance;
        EV2.ResolutionManifest manifest;
        bytes32 manifestHash;
        bytes32 expectedRole;
    }
    bytes32 private avExecution;
    bytes32 private avOrigin;
    bytes32 private avRetained;
    bytes32 private avProtected;
    IdentityRecovery.Context private avScheduledContext;
    uint256 private avSalt = 121000;
    bytes32[] private avRotations;
    bytes32[] private avRecoveries;
    bytes32[] private avEstates;
    bytes32[] private avDismissals;
    bytes32[] private avNotices;

    function testAdjudicationZeroExecutionStandingNoneCompletesEmptyAppealElectionAndRetry()
        public
    {
        _avSetup(0, 0);
        bytes32 pending = _avCapture(true, 0);
        Adjudication memory b = _avBundle(
            _avDeclarations(0, 0),
            _avList(avRetained, avProtected),
            _avList(avRetained, avProtected)
        );
        require(
            b.manifest.executedHead == 0 && b.manifest.contestedVestings.length == 0,
            "NONE has no invented execution or cutoff"
        );
        _avSeal(b, 0);
        _avRecover(b, 0, true);
        _avEmptyClosure(pending);
        _missing(pending);
    }

    function testAdjudicationZeroExecutionGeneralCauseRetainedSafeVetoSurvivesDelay() public {
        _avSetup(0, 0);
        _avCompromise(0);
        Adjudication memory b =
            _avBundle(_avDeclarations(0, 0), _avList(avProtected, 0), _avList(avProtected, 0));
        _avSeal(b, avRetained);
        _avRegister(b);
        vm.expectRevert(abi.encodeWithSelector(A.InvalidRecoveryGuardian.selector, address(artist)));
        vm.prank(address(artist));
        ingress.vetoIdentityRecovery(artistId, keccak256("excluded-only guardian"));
        vm.warp(scheduled.notBefore);
        this.vetoByGuardian(keccak256("retained original Safe veto"));
        (, A.Veto memory veto,,) = ingress.identityRecoveryActionState(artistId, currentId);
        require(
            veto.vetoer == address(delegateSafe) && veto.vetoedAt == block.timestamp,
            "independent retained membership veto survives the scheduling delay"
        );
        scheduled.status = GovernanceActionStatus.EXECUTED;
        _publish();
        _avExpectExecutionFailure(
            b, abi.encodeWithSelector(A.RecoveryActionVetoed.selector, currentId)
        );
    }

    function testAdjudicationEarlyCurrent35GeneralCauseRecoversWithoutDismissal() public {
        _avSetup(0, 0);
        _avCompromise(0);
        Adjudication memory first = _avBundle(_avDeclarations(0, 0), _avList(0, 0), _avList(0, 0));
        _avSeal(first, avProtected);
        bytes32 original = _avRecover(first, avProtected, false);
        require(
            block.timestamp < ingress.artistTransitionState(original).postWindowEndsAt,
            "fresh35 is genuinely in its post-vesting window"
        );
        _avCompromise(0);
        Dismissal.Cause memory cause = ingress.currentIdentityContestCause(artistId);
        require(
            cause.facts.enteredAt < ingress.artistTransitionState(original).postWindowEndsAt,
            "current C1 entered early, not backdated or dismissed"
        );
        Adjudication memory b =
            _avBundle(_avDeclarations(original, 0), _avList(0, 0), _avList(0, 0));
        _avSeal(b, avProtected);
        _avRecover(b, avProtected, true);
        _avEmptyClosure(original);
    }

    function testAdjudicationPriorSupersededOnlyGuardianCannotVetoLaterRecovery() public {
        _avSetup(0, 0);
        address hostile = address(artist);
        require(
            ingress.guardianSetRecord(avRetained).nonce
                < ingress.guardianSetRecord(avProtected).nonce,
            "retained Safe belongs to the original lower-nonce guardian record"
        );
        _avCompromise(0);
        Adjudication memory first =
            _avBundle(_avDeclarations(0, 0), _avList(avProtected, 0), _avList(avProtected, 0));
        _avSeal(first, avRetained);
        bytes32 firstRecovery = _avRecover(first, avRetained, false);
        require(
            _status(avProtected).recoveryRecordHash == firstRecovery
                && _status(avRetained).recoveryRecordHash == 0,
            "actual first35 permanently excludes only the hostile guardian admission"
        );

        _avCompromise(0);
        Adjudication memory later = _avBundle(_avDeclarations(0, 0), _avList(0, 0), _avList(0, 0));
        _avSeal(later, avRetained);
        _avRegister(later);
        bytes32 roots = _roots();
        bytes32 history = _avHistory();
        vm.expectRevert(abi.encodeWithSelector(A.InvalidRecoveryGuardian.selector, hostile));
        vm.prank(hostile);
        ingress.vetoIdentityRecovery(artistId, keccak256("previously superseded guardian"));
        require(
            roots == _roots() && history == _avHistory()
                && _status(avProtected).recoveryRecordHash == firstRecovery,
            "empty current exclusions never restore previously superseded-only membership"
        );

        vm.warp(scheduled.notBefore);
        this.vetoByGuardian(keccak256("retained lower-nonce Safe vetoes later recovery"));
        (, A.Veto memory veto,,) = ingress.identityRecoveryActionState(artistId, currentId);
        require(
            veto.vetoer == address(delegateSafe) && veto.vetoedAt == block.timestamp,
            "retained original membership still supplies independent veto standing"
        );
        scheduled.status = GovernanceActionStatus.EXECUTED;
        _publish();
        _avExpectExecutionFailure(
            later, abi.encodeWithSelector(A.RecoveryActionVetoed.selector, currentId)
        );
    }

    function testAdjudicationNonzeroNoneUsesIndependentEarlyProvisionalGuardian() public {
        _avSetup(0, 0);
        _avRotate();
        bytes32 original = avExecution;
        bytes32 provisional = _avGuardian(address(artist), 122000);
        _avCompromise(original);
        R.GuardianRecord memory record = ingress.guardianSetRecord(provisional);
        require(
            record.provisional.transitionRecordHash == original
                && ingress.artistTransitionState(original).contestedAt
                    < record.provisional.windowEndsAt,
            "real admission remains independently provisional under the early current marker"
        );
        Adjudication memory b =
            _avBundle(_avDeclarations(0, 0), _avList(provisional, 0), _avList(0, 0));
        require(
            b.manifest.executedHead != 0 && b.manifest.contestedVestings.length == 0,
            "empty declared set is independent of genuine nonzero ancestry"
        );
        _avSeal(b, avProtected);
        _avRecover(b, avProtected, true);
        _avEmptyClosure(original);
    }

    function testAdjudicationNonzeroNoneMatureStandingGuardianNeedsAppeal() public {
        _avSetup(0, 0);
        _avRotate();
        bytes32 post = _avGuardian(address(artist), 122001);
        _avCapture(true, 0);
        Adjudication memory ordinary =
            _avBundle(_avDeclarations(0, 0), _avList(post, 0), _avList(0, 0));
        _avExpectContextFailure(
            ordinary,
            abi.encodeWithSelector(
                EV2.InvalidRecoveryAppealEvidence.selector, ordinary.request.evidenceHash
            )
        );
        Adjudication memory b = _avBundle(_avDeclarations(0, 0), _avList(post, 0), _avList(post, 0));
        _avSeal(b, avProtected);
        _avRecover(b, avProtected, false);
    }

    function testAdjudicationEarliestDeclaredVestingPrecedesActualExecutionAndHistoricalSubject()
        public
    {
        _avSetup(0, 0);
        _avRotate();
        bytes32 older = avExecution;
        bytes32 middle = _avGuardian(address(artist), 122002);
        _avRotate();
        bytes32 newer = avExecution;
        _avMature();
        _avCompromise(older);
        require(
            _snapshot(older).guardians.count == 2 && _snapshot(newer).guardians.count == 3,
            "middle admission is after oldest cutoff and before latest execution"
        );
        Adjudication memory b =
            _avBundle(_avDeclarations(older, newer), _avList(middle, 0), _avList(0, 0));
        _avSeal(b, avProtected);
        _avRecover(b, avProtected, true);
    }

    function testAdjudicationClass3EstateStandingMultipleDeclaredVestings() public {
        _avSetup(2, 4095);
        bytes32 origin = avOrigin;
        bytes32 post = _avGuardian(address(artist), 122003);
        _avRotate();
        _avCapture(true, 0);
        Adjudication memory b =
            _avBundle(_avDeclarations(origin, avExecution), _avList(post, 0), _avList(0, 0));
        _avSeal(b, avProtected);
        _avRecover(b, avProtected, false);
        require(
            ingress.currentAuthorityCapabilities(artistId).activationRecordHash == origin,
            "class3 recovery retains the actual original40 origin"
        );
    }

    function testAdjudicationClass3DormancyEarlyGeneralCurrentCauseNone() public {
        _avSetup(4, 0);
        bytes32 original = avOrigin;
        require(
            block.timestamp < ingress.artistTransitionState(original).postWindowEndsAt,
            "actual43 early window"
        );
        _avCompromise(0);
        Adjudication memory b = _avBundle(_avDeclarations(0, 0), _avList(0, 0), _avList(0, 0));
        _avSeal(b, avProtected);
        _avRecover(b, avProtected, true);
        _avEmptyClosure(original);
    }

    function testAdjudicationClass3RepeatedFreshGeneralCauseAfterPendingStandingDismissal() public {
        _avSetup(4, 0);
        _avCompromise(avExecution);
        Adjudication memory first =
            _avBundle(_avDeclarations(avExecution, 0), _avList(0, 0), _avList(0, 0));
        _avSeal(first, avProtected);
        bytes32 prior = _avRecover(first, avProtected, false);
        bytes32 pending = _avCapture(true, 0);
        bytes32 dismissal = _avDismiss();
        require(
            ingress.identityTransitionClosure(artistId, prior).dismissalRecordHash == dismissal
                && ingress.identityTransitionClosure(artistId, pending).dismissalRecordHash
                    == dismissal,
            "real dismissal created nonempty executed and pending closures"
        );
        _avCompromise(0);
        Adjudication memory b = _avBundle(_avDeclarations(prior, 0), _avList(0, 0), _avList(0, 0));
        _avSeal(b, avProtected);
        _avRecover(b, avProtected, true);
    }

    function testAdjudicationClass3CurrentPendingHistoricalSubjectAndNone() public {
        _avSetup(2, 4095);
        bytes32 original = avOrigin;
        _avRotate();
        _avCapture(false, original);
        Adjudication memory b = _avBundle(_avDeclarations(0, 0), _avList(0, 0), _avList(0, 0));
        _avSeal(b, avProtected);
        _avRecover(b, avProtected, false);
    }

    function testAdjudicationDeclaredReferencesRejectWrongCommitmentAndReverseOrder() public {
        _avSetup(0, 0);
        _avRotate();
        bytes32 older = avExecution;
        _avRotate();
        bytes32 newer = avExecution;
        _avMature();
        _avCompromise(newer);
        Adjudication memory b =
            _avBundle(_avDeclarations(older, newer), _avList(0, 0), _avList(0, 0));
        bytes32 originalHash = b.manifestHash;
        bytes32 originalCommitment = b.manifest.contestedVestings[0].vestingCommitment;
        b.manifest.contestedVestings[0].vestingCommitment = keccak256("not original commitment");
        b.manifestHash = _avPublishManifest(b.manifest);
        _avExpectContextFailure(
            b, abi.encodeWithSelector(EV2.InvalidRecoveryManifest.selector, older)
        );
        b.manifest.contestedVestings[0].vestingCommitment = originalCommitment;
        (b.manifest.contestedVestings[0], b.manifest.contestedVestings[1]) =
        (b.manifest.contestedVestings[1], b.manifest.contestedVestings[0]);
        b.manifestHash = _avPublishManifest(b.manifest);
        _avExpectContextFailure(
            b, abi.encodeWithSelector(EV2.InvalidRecoveryManifest.selector, bytes32(0))
        );
        (b.manifest.contestedVestings[0], b.manifest.contestedVestings[1]) =
        (b.manifest.contestedVestings[1], b.manifest.contestedVestings[0]);
        b.manifestHash = _avPublishManifest(b.manifest);
        require(
            b.manifestHash == originalHash,
            "immutable original declaration survives rejected variants"
        );
        _avSeal(b, avProtected);
        _avRecover(b, avProtected, false);
    }

    function testAdjudicationManifestGrammarRejectsNoneWithReferencesAndDuplicateExclusions()
        public
    {
        _avSetup(0, 0);
        _avRotate();
        _avMature();
        _avCompromise(avExecution);
        Adjudication memory b =
            _avBundle(_avDeclarations(avExecution, 0), _avList(0, 0), _avList(0, 0));
        IStreamArtistRecoveryEvidence publisher = _avPublisher();
        bytes32 roots = _roots();
        b.manifest.basis = EV2.VestingBasis.NO_CONTESTED_VESTING;
        vm.expectRevert(abi.encodeWithSelector(EV2.InvalidRecoveryManifest.selector, bytes32(0)));
        publisher.publishResolutionManifest(b.manifest);
        b.manifest.basis = EV2.VestingBasis.DECLARED_VESTINGS;
        b.manifest.supersededRecordHashes = new bytes32[](2);
        b.manifest.supersededRecordHashes[0] = avProtected;
        b.manifest.supersededRecordHashes[1] = avProtected;
        vm.expectRevert(abi.encodeWithSelector(EV2.InvalidRecoveryManifest.selector, bytes32(0)));
        publisher.publishResolutionManifest(b.manifest);
        require(roots == _roots(), "invalid publication never touches owner state");
    }

    function testAdjudicationManifestRejectsUnexecutedPendingAsDeclaredVesting() public {
        _avSetup(0, 0);
        _avRotate();
        bytes32 pending = _avCapture(true, 0);
        Adjudication memory b =
            _avBundle(_avDeclarations(avExecution, 0), _avList(0, 0), _avList(0, 0));
        b.manifest.contestedVestings[0] =
            EV2.VestingReference(pending, keccak256("invented P vesting"));
        b.manifestHash = _avPublishManifest(b.manifest);
        _avExpectContextFailure(
            b, abi.encodeWithSelector(EV2.InvalidRecoveryManifest.selector, bytes32(0))
        );
        _missing(pending);
        _avEmptyClosure(pending);
    }

    function testAdjudicationAppealRequiresExactHostilePartiesAndSameManifest() public {
        _avSetup(0, 0);
        _avCompromise(0);
        Adjudication memory b =
            _avBundle(_avDeclarations(0, 0), _avList(avProtected, 0), _avList(avProtected, 0));
        bytes32 good = b.request.evidenceHash;
        (EV2.AppealDocumentV2 memory doc,) = _avPublisher().appealEvidenceV2(good);
        address original = doc.findings[0].parties[0];
        doc.findings[0].parties[0] = address(delegateSafe);
        b.request.evidenceHash = _avPublisher().publishAppealV2(doc);
        _avExpectContextFailure(
            b,
            abi.encodeWithSelector(
                EV2.InvalidRecoveryAppealEvidence.selector, b.request.evidenceHash
            )
        );
        doc.findings[0].parties[0] = original;
        doc.resolutionManifestHash = keccak256("different manifest");
        b.request.evidenceHash = _avPublisher().publishAppealV2(doc);
        _avExpectContextFailure(
            b,
            abi.encodeWithSelector(
                EV2.InvalidRecoveryAppealEvidence.selector, b.request.evidenceHash
            )
        );
        b.request.evidenceHash = good;
        _avSeal(b, avRetained);
        _avRecover(b, avRetained, false);
    }

    function testAdjudicationDirectiveForbidsProtectedGuardianAtAppealTier() public {
        _avSetup(0, 0);
        bytes32 directive = _directiveRecord(256);
        _avCompromise(0);
        Adjudication memory b =
            _avBundle(_avDeclarations(0, 0), _avList(avProtected, 0), _avList(avProtected, 0));
        _avExpectContextFailure(
            b,
            abi.encodeWithSelector(
                AVSucc.ForbiddenCapability.selector, artistId, uint32(256), directive
            )
        );
        require(
            ingress.operativeEstateDirective(artistId) == directive
                && _status(avProtected).recoveryRecordHash == 0,
            "original binding directive and guardian remain operative"
        );
    }

    function testAdjudicationExactV2SelectorManifestTargetValueAndUniqueCall() public {
        _avSetup(0, 0);
        _avCompromise(0);
        Adjudication memory b = _avBundle(_avDeclarations(0, 0), _avList(0, 0), _avList(0, 0));
        _avSeal(b, avProtected);
        for (uint8 variant; variant < 5; ++variant) {
            GovernanceCall[] memory calls = _avSchedule(b);
            if (variant == 0) {
                calls[1].selector = IStreamArtistIdentityRecovery.recoverArtistIdentity.selector;
            } else if (variant == 1) {
                calls[1].callDataHash = keccak256(
                    abi.encodeCall(
                        IStreamArtistIdentityRecoveryV2.recoverArtistIdentityV2,
                        (b.request, b.acceptance, keccak256("different published manifest"))
                    )
                );
            } else if (variant == 2) {
                calls[1].target = suite.owners[2];
            } else if (variant == 3) {
                calls[1].value = 1;
            } else {
                calls[0] = calls[1];
            }
            _avBadCalls(b, calls);
        }
        _avRecover(b, avProtected, false);
    }

    function testAdjudicationNewActionNeedsFreshAnchorAndPreservesOldAssociation() public {
        _avSetup(0, 0);
        _avCompromise(0);
        Adjudication memory b = _avBundle(_avDeclarations(0, 0), _avList(0, 0), _avList(0, 0));
        _avSeal(b, avProtected);
        _avRegister(b);
        bytes32 oldAction = currentId;
        bytes32 oldEvidence =
            keccak256(abi.encode(_avRegistry().identityRecoveryEvidenceState(artistId, oldAction)));
        (A.Association memory original,,,) =
            ingress.identityRecoveryActionState(artistId, oldAction);
        require(
            _avContext(b).oldValueHash == avScheduledContext.oldValueHash,
            "the original saved pre-preparation anchor remains executable"
        );
        scheduled.status = GovernanceActionStatus.CANCELLED;
        _publish();
        GovernanceCall[] memory calls = _avSchedule(b);
        bytes32 roots = _roots();
        vm.expectRevert(abi.encodeWithSelector(A.InvalidRecoveryAction.selector, currentId));
        _avRegistry()
            .registerIdentityRecoveryActionV2(
                currentId, calls, b.request, b.acceptance, b.manifestHash
            );
        require(roots == _roots(), "old preparation anchor cannot register a new action");
        b.manifest.ownerRevision = _ownerSnapshot().revision;
        b.manifestHash = _avPublishManifest(b.manifest);
        _avSeal(b, avProtected);
        _avRecover(b, avProtected, false);
        (A.Association memory retained,,,) =
            ingress.identityRecoveryActionState(artistId, oldAction);
        require(
            keccak256(abi.encode(retained)) == keccak256(abi.encode(original))
                && oldEvidence
                    == keccak256(
                        abi.encode(_avRegistry().identityRecoveryEvidenceState(artistId, oldAction))
                    ),
            "newly anchored action retains the old original association and manifest binding"
        );
    }

    function testAdjudicationRoleRevisionChangeInvalidatesPreparedAppeal() public {
        _avSetup(0, 0);
        _avCompromise(0);
        Adjudication memory b =
            _avBundle(_avDeclarations(0, 0), _avList(avProtected, 0), _avList(avProtected, 0));
        _avSeal(b, avRetained);
        _avRegister(b);
        ArtistAppealUnitRoles(suite.roleRegistry).setArbiter(address(0xBEEF), true);
        vm.warp(scheduled.notBefore);
        scheduled.status = GovernanceActionStatus.EXECUTED;
        _publish();
        _avExpectExecutionFailure(
            b, abi.encodeWithSelector(IdentityRecovery.InvalidIdentityRecoveryGovernance.selector)
        );
    }

    function testAdjudicationNewAnchorKeepsPriorAssociationAndPermanentVeto() public {
        _avSetup(0, 0);
        _avCompromise(0);
        Adjudication memory b = _avBundle(_avDeclarations(0, 0), _avList(0, 0), _avList(0, 0));
        _avSeal(b, avProtected);
        _avRegister(b);
        bytes32 oldAction = currentId;
        this.vetoByGuardian(keccak256("veto remains on the original action"));
        (A.Association memory original, A.Veto memory veto,,) =
            ingress.identityRecoveryActionState(artistId, oldAction);
        bytes32 saved = keccak256(
            abi.encode(
                original, veto, _avRegistry().identityRecoveryEvidenceState(artistId, oldAction)
            )
        );
        require(veto.vetoer == address(delegateSafe), "real old action veto");
        scheduled.status = GovernanceActionStatus.CANCELLED;
        _publish();
        b.manifest.ownerRevision = _ownerSnapshot().revision;
        b.manifestHash = _avPublishManifest(b.manifest);
        _avSeal(b, avProtected);
        _avRecover(b, avProtected, false);
        (A.Association memory retained, A.Veto memory retainedVeto,,) =
            ingress.identityRecoveryActionState(artistId, oldAction);
        require(
            saved
                == keccak256(
                    abi.encode(
                        retained,
                        retainedVeto,
                        _avRegistry().identityRecoveryEvidenceState(artistId, oldAction)
                    )
                ),
            "refreshing preparation never erases the earlier action, evidence or veto"
        );
    }

    function testAdjudicationGovernanceRootChangeInvalidatesPreparedAppeal() public {
        _avSetup(0, 0);
        _avCompromise(0);
        Adjudication memory b =
            _avBundle(_avDeclarations(0, 0), _avList(avProtected, 0), _avList(avProtected, 0));
        _avSeal(b, avRetained);
        _avRegister(b);
        ArtistAppealUnitGovernance(manager.governanceAuthority()).configureRoot(address(this));
        vm.warp(scheduled.notBefore);
        scheduled.status = GovernanceActionStatus.EXECUTED;
        _publish();
        _avExpectExecutionFailure(
            b, abi.encodeWithSelector(IdentityRecovery.InvalidIdentityRecoveryGovernance.selector)
        );
    }

    function testAdjudicationNewSideAcceptanceDeadlineAndExactGoodRetry() public {
        _avSetup(0, 0);
        _avCompromise(0);
        Adjudication memory b = _avBundle(_avDeclarations(0, 0), _avList(0, 0), _avList(0, 0));
        _avSeal(b, avProtected);
        uint64 goodDeadline = b.acceptance.time;
        b.acceptance.time = uint64(block.timestamp + 1 hours);
        GovernanceCall[] memory calls = _avSchedule(b);
        bytes32 roots = _roots();
        vm.expectRevert(abi.encodeWithSelector(A.InvalidRecoveryAction.selector, currentId));
        _avRegistry()
            .registerIdentityRecoveryActionV2(
                currentId, calls, b.request, b.acceptance, b.manifestHash
            );
        require(
            roots == _roots(),
            "preparation rejects an acceptance expiring before the governance delay"
        );
        b.acceptance.time = goodDeadline;
        _avRecover(b, avProtected, true);
    }

    function testAdjudicationV1ContextBytesIgnoreV2PublicationAndExternalSelection() public {
        _avSetup(0, 0);
        _avRotate();
        _avMature();
        _avCompromise(avExecution);
        _newRotationSafe(++avSalt);
        IdentityRecovery.Request memory p = _terms();
        T.Authorization memory acceptance = _acceptance(p);
        bytes32 beforeContext =
            keccak256(abi.encode(ingress.identityRecoveryContext(p, acceptance)));
        Adjudication memory b =
            _avBundle(_avDeclarations(avExecution, 0), _avList(0, 0), _avList(0, 0));
        _avSeal(b, avProtected);
        require(
            beforeContext == keccak256(abi.encode(ingress.identityRecoveryContext(p, acceptance))),
            "V2 publication and election do not relabel or mutate the V1 context"
        );
    }

    function testAdjudicationConsumedEarly35RemainsOriginalAcrossLater35And32() public {
        _avSetup(0, 0);
        _avCompromise(0);
        Adjudication memory first = _avBundle(_avDeclarations(0, 0), _avList(0, 0), _avList(0, 0));
        _avSeal(first, avProtected);
        bytes32 earliest = _avRecover(first, avProtected, false);
        _avCompromise(earliest);
        Adjudication memory second =
            _avBundle(_avDeclarations(earliest, 0), _avList(0, 0), _avList(0, 0));
        _avSeal(second, avProtected);
        _avRecover(second, avProtected, false);
        _avRotate();
        bytes32 terminalRotation = avExecution;
        bytes32 consumedPending = _avCapture(true, 0);
        Adjudication memory b =
            _avBundle(_avDeclarations(earliest, terminalRotation), _avList(0, 0), _avList(0, 0));
        _avSeal(b, avProtected);
        _avRecover(b, avProtected, true);
        _avCompromise(0);
        Adjudication memory later =
            _avBundle(_avDeclarations(earliest, terminalRotation), _avList(0, 0), _avList(0, 0));
        _avSeal(later, avProtected);
        _avRecover(later, avProtected, false);
        require(
            ingress.artistTransitionState(earliest).contestedAt
                < ingress.artistTransitionState(earliest).postWindowEndsAt,
            "consumed early marker remains original through later authoritative ancestry"
        );
        _avEmptyClosure(earliest);
        _avEmptyClosure(consumedPending);
        _missing(consumedPending);
    }

    function testAdjudicationActualNewSafeRejectsWrongAcceptanceWithoutConsumption() public {
        _avSetup(0, 0);
        _avCompromise(0);
        Adjudication memory b = _avBundle(_avDeclarations(0, 0), _avList(0, 0), _avList(0, 0));
        b.acceptance.signature = hex"01";
        _avSeal(b, avProtected);
        _avRegister(b);
        vm.warp(scheduled.notBefore);
        scheduled.status = GovernanceActionStatus.EXECUTED;
        _publish();
        _avExpectExecutionFailure(b, abi.encodeWithSelector(T.InvalidSignature.selector));
    }

    // 0 initial living, 2 original40, 4 original43. Later35s use the explicit V2 path below.
    function _avSetup(uint8 profile, uint32 capabilities) private {
        require(profile == 0 || profile == 2 || profile == 4, "explicit fixture profile");
        if (profile >= 4) {
            this.dsSetup(0);
            avExecution = ingress.lastArtistTransition(artistId);
            (, GH.Entry memory lower,,) = IStreamArtistGuardianHistory(suite.owners[2])
                .guardianHistoryState(artistId, 1, address(0), 0);
            (, GH.Entry memory upper,,) = IStreamArtistGuardianHistory(suite.owners[2])
                .guardianHistoryState(artistId, 2, address(0), 0);
            avRetained = lower.recordHash;
            avProtected = upper.recordHash;
            avOrigin = ingress.currentAuthorityCapabilities(artistId).activationRecordHash;
            (bytes32 notice,,) = IStreamArtistDormancy(address(ingress)).dormancyNotice(artistId);
            avNotices.push(notice);
            bytes32 prior = ingress.latestIdentityRecovery(artistId);
            if (prior != 0) avRecoveries.push(prior);
        } else {
            _deployAppealSuite();
            _accept();
            _payout();
            _delegateSetup();
            address[] memory members = new address[](1);
            members[0] = address(delegateSafe);
            avRetained = _guardianRecord(members, 1, 10 days, nextNonce);
            members[0] = address(artist);
            avProtected = _guardianRecord(members, 1, 20 days, nextNonce);
            if (profile >= 2) {
                Estate.Execution memory e = _estateActivateAndAdopt(capabilities);
                avExecution = e.expectedActivationRecordHash;
                avOrigin = avExecution;
                avEstates.push(avExecution);
                require(_snapshot(avExecution).operationId == 40, "actual40 origin");
            }
        }
        ArtistAppealUnitRoles(suite.roleRegistry).setAppeal(address(this), true);
        if (avExecution == 0) {
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

    function _avMature() private {
        if (avExecution == 0) return;
        uint64 end = ingress.artistTransitionState(avExecution).postWindowEndsAt;
        if (block.timestamp < end) vm.warp(end);
    }

    function _avRotate() private {
        _avMature();
        bytes32 previous = avExecution;
        _newRotationSafe(++avSalt);
        avExecution = _stageRotation(ingress.lastArtistTransition(artistId));
        avRotations.push(avExecution);
        _executeTimedRotation(avExecution);
        _adoptRotatedSafe();
        V.Snapshot memory v = _snapshot(avExecution);
        require(
            v.operationId == 32 && v.previousTransitionRecordHash == previous
                && v.previousCommitment
                    == (previous == 0 ? bytes32(0) : _snapshot(previous).commitment),
            "actual32 snapshot follows execution, independently of staging history"
        );
    }

    function _avWitness(bytes32 scope, bytes32 old_, bytes32 next_) private {
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

    function _avInactive() private {
        _inactive();
        (bool active, bytes32 id, uint8 class_, bytes32 s, bytes32 o, bytes32 n) =
            IStreamGovernanceReads(manager.governanceAuthority()).currentAction();
        require(
            !active && id == 0 && class_ == 0 && s == 0 && o == 0 && n == 0,
            "exact inactive action after real producer"
        );
    }

    function _avCompromise(bytes32 subject) private {
        ArtistAppealUnitRoles(suite.roleRegistry).setArbiter(address(artist), true);
        bytes32 evidence = keccak256(abi.encode("staging family compromise", ++avSalt));
        bytes32 reason = keccak256(abi.encode("staging family reason", evidence));
        ArtistUnitGovernance authority = ArtistUnitGovernance(manager.governanceAuthority());
        authority.configureContestReads(
            suite.roleRegistry, address(artist), reason, "urn:family:33"
        );
        (bytes32 scope, bytes32 old_, bytes32 next_) =
            ingress.identityContestGovernanceContext(artistId, subject, evidence, reason);
        _avWitness(scope, old_, next_);
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
        _avInactive();
        Dismissal.Cause memory c = ingress.currentIdentityContestCause(artistId);
        Contest.Record memory saved = ingress.identityContestRecord(c.facts.referenceHash);
        require(
            c.facts.kind == 1 && c.facts.executedTransitionHash == avExecution
                && saved.recordHash == c.facts.referenceHash
                && saved.terms.subjectRecordHash == subject && saved.terms.evidenceHash == evidence
                && saved.terms.reasonHash == reason && c.facts.incumbent == address(artist)
                && _operationPayload(33, manager.governanceAuthority(), saved.recordHash).length
                    != 0,
            "actual governed33 captures current execution and exact original subject"
        );
    }

    function _avDismiss() private returns (bytes32 record) {
        Dismissal.Request memory p = _dismissalRequest();
        Dismissal.Cause memory cause = ingress.currentIdentityContestCause(artistId);
        ArtistAppealUnitRoles(suite.roleRegistry).setArbiter(address(artist), true);
        ArtistUnitGovernance(manager.governanceAuthority())
            .configureContestReads(
                suite.roleRegistry, address(artist), p.reasonHash, "urn:unit:dismissal"
            );
        Dismissal.Context memory x = ingress.identityContestDismissalContext(p);
        _avWitness(x.scopeHash, x.oldValueHash, x.newValueHash);
        record = _dismissalExecute(p, 1, 0);
        _avInactive();
        avDismissals.push(record);
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
        if (avExecution == 0) _avEmptyClosure(0);
    }

    function _avCapture(bool veto, bytes32 subject) private returns (bytes32 pending) {
        _avMature();
        ArtistAppealUnitRoles(suite.roleRegistry).setArbiter(address(artist), true);
        _newRotationSafe(++avSalt);
        pending = _stageRotation(ingress.lastArtistTransition(artistId));
        avRotations.push(pending);
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
            _avCompromise(subject);
        }
        Dismissal.Cause memory c = ingress.currentIdentityContestCause(artistId);
        R.TransitionState memory t = ingress.rotationRecord(pending).transition;
        require(
            c.facts.kind == (veto ? 2 : 1) && c.facts.pendingTransitionHash == pending
                && c.facts.executedTransitionHash == avExecution
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
                    _avReplayKey(keccak256("identity_authority.replay.rotation_veto_key"), pending)
                );
            require(
                cell.commitment == pending && cell.status == 2 && cell.kind == 1,
                "original veto replay"
            );
        }
        _avEmptyClosure(pending);
        _missing(pending);
    }

    function _avEmptyClosure(bytes32 record) private view {
        Dismissal.Closure memory empty;
        require(
            keccak256(abi.encode(ingress.identityTransitionClosure(artistId, record)))
                == keccak256(abi.encode(empty)),
            "complete original closure remains empty"
        );
    }

    function _avReplayKey(bytes32 operation, bytes32 scope) private view returns (bytes32) {
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

    function _avCause(bytes32 hash) private view returns (bytes32) {
        Dismissal.Cause memory c = ingress.identityContestCause(hash);
        return keccak256(abi.encode(c, ingress.identityContestRecord(c.facts.referenceHash)));
    }

    function _avHistory() private view returns (bytes32 value) {
        if (avOrigin != 0) {
            value = keccak256(
                abi.encode(
                    avOrigin,
                    _snapshot(avOrigin),
                    ingress.artistTransitionState(avOrigin),
                    ingress.identityTransitionClosure(artistId, avOrigin)
                )
            );
        }
        for (uint256 i; i < avRotations.length; ++i) {
            bytes32 r = avRotations[i];
            value = keccak256(
                abi.encode(
                    value,
                    ingress.rotationRecord(r),
                    ingress.artistTransitionState(r),
                    ingress.identityTransitionClosure(artistId, r)
                )
            );
        }
        for (uint256 i; i < avRecoveries.length; ++i) {
            bytes32 r = avRecoveries[i];
            (bytes32 primary, bytes32 occurrence, bytes32 secondary) =
                IStreamArtistIdentityRecoveryOwner(suite.owners[2]).identityRecoveryReceipts(r);
            value = keccak256(
                abi.encode(
                    value,
                    ingress.identityRecoveryRecord(r),
                    _snapshot(r),
                    ingress.artistTransitionState(r),
                    ingress.identityTransitionClosure(artistId, r),
                    primary,
                    occurrence,
                    secondary
                )
            );
        }
        for (uint256 i; i < avEstates.length; ++i) {
            (Estate.RequestRecord memory r, uint8 phase, Estate.ExecutionFacts memory e) =
                ingress.estateActivationRecord(avEstates[i]);
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
        for (uint256 i; i < avDismissals.length; ++i) {
            Dismissal.Record memory d = ingress.identityContestDismissalRecord(avDismissals[i]);
            Dismissal.Cause memory c = ingress.identityContestCause(d.terms.expectedCauseHash);
            value = keccak256(
                abi.encode(value, d, c, ingress.identityContestRecord(c.facts.referenceHash))
            );
        }
        for (uint256 i; i < avNotices.length; ++i) {
            (Dormancy27.Notice memory n, uint8 phase, Dormancy27.Terminal memory t) =
                IStreamArtistDormancy(address(ingress)).dormancyRecord(avNotices[i]);
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

    function _avReceipts(bytes32 record) private view {
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

    function _avRegistry() private view returns (IStreamArtistIdentityRecoveryV2) {
        return IStreamArtistIdentityRecoveryV2(address(ingress));
    }

    function _avSelection()
        private
        view
        returns (IStreamArtistRecoverySelectionPreparation preparation)
    {
        (address target, bytes32 hash) = IStreamArtistRecoverySelectionBinding(suite.owners[2])
            .recoverySelectionPreparationBinding();
        require(target.codehash == hash && hash != 0, "fixed V2 selection helper");
        preparation = IStreamArtistRecoverySelectionPreparation(target);
    }

    function _avSeal(Adjudication memory b, bytes32 expected) private returns (bytes32 key) {
        IStreamArtistRecoverySelectionPreparation preparation = _avSelection();
        bytes32 roots = _roots();
        bytes32 history = _avHistory();
        key = preparation.beginSelectionV2(b.manifestHash);
        (SV2.Basis memory basis, Selection.Progress memory progress) = preparation.selectionV2(key);
        require(
            basis.manifestHash == b.manifestHash && basis.artistId == artistId
                && basis.ownerCodeHash == suite.owners[2].codehash && basis.sourceCommitment != 0
                && basis.history.count >= 2 && progress.processed == 0 && !progress.complete,
            "explicit election starts from the complete original guardian prefix"
        );
        vm.expectRevert(
            abi.encodeWithSelector(
                Selection.IncompleteGuardianSelection.selector, key, uint64(0), basis.history.count
            )
        );
        preparation.requireSelectionV2(b.manifestHash);
        for (uint64 index = 1; index <= basis.history.count; ++index) {
            progress = preparation.continueSelectionV2(key, 1);
            require(
                progress.processed == index && progress.complete == (index == basis.history.count),
                "one original admission is processed per bounded call"
            );
        }
        Selection.Result memory result = preparation.requireSelectionV2(b.manifestHash);
        require(
            progress.complete && result.sourceKey == key && result.commitment != 0
                && result.selectedRecordHash == expected && progress.selectedRecordHash == expected
                && result.selectedDataHash
                    == (expected == 0
                            ? bytes32(0)
                            : keccak256(abi.encode(ingress.guardianSetRecord(expected))))
                && roots == _roots() && history == _avHistory(),
            "completed election, including explicit empty selection, grants no owner mutation"
        );
        if (expected == 0) {
            require(result.selectedNonce == 0, "empty selection has no invented nonce");
        }
    }

    function _avExpectContextFailure(Adjudication memory b, bytes memory error) private {
        bytes32 roots = _roots();
        bytes32 history = _avHistory();
        vm.expectRevert(error);
        _avRegistry().identityRecoveryContextV2(b.request, b.acceptance, b.manifestHash);
        (bool used,) =
            ingress.rotationAcceptanceNonceState(artistId, b.request.newAddress, b.acceptance.nonce);
        require(
            !used && roots == _roots() && history == _avHistory(),
            "invalid evidence changes no original history, acceptance or owner root"
        );
    }

    function _avBadCalls(Adjudication memory b, GovernanceCall[] memory calls) private {
        scheduled.callHash = keccak256(
            abi.encode(
                bytes32(0x10f09566fb70f7947b61639c2a53b3aec872069a8b46edd08ba14eb2b5942b70), calls
            )
        );
        _publish();
        bytes32 roots = _roots();
        bytes32 history = _avHistory();
        vm.expectRevert(abi.encodeWithSelector(A.InvalidRecoveryAction.selector, currentId));
        _avRegistry()
            .registerIdentityRecoveryActionV2(
                currentId, calls, b.request, b.acceptance, b.manifestHash
            );
        EV2.EvidenceStateV2 memory empty;
        (bool used,) =
            ingress.rotationAcceptanceNonceState(artistId, b.request.newAddress, b.acceptance.nonce);
        require(
            roots == _roots() && history == _avHistory() && !used
                && keccak256(
                        abi.encode(_avRegistry().identityRecoveryEvidenceState(artistId, currentId))
                    ) == keccak256(abi.encode(empty)),
            "mismatched scheduled calls retain no supplemental association"
        );
    }

    function _avExpectExecutionFailure(Adjudication memory b, bytes memory error) private {
        bytes32 roots = _roots();
        bytes32 history = _avHistory();
        bytes32 evidence =
            keccak256(abi.encode(_avRegistry().identityRecoveryEvidenceState(artistId, currentId)));
        vm.expectRevert(error);
        this.executeAdjudication(b);
        _avInactive();
        (bool used,) =
            ingress.rotationAcceptanceNonceState(artistId, b.request.newAddress, b.acceptance.nonce);
        require(
            !used && roots == _roots() && history == _avHistory()
                && evidence
                    == keccak256(
                        abi.encode(_avRegistry().identityRecoveryEvidenceState(artistId, currentId))
                    ),
            "failed V2 execution preserves original history, acceptance and saved evidence"
        );
    }

    function _avPublisher() private view returns (IStreamArtistRecoveryEvidence publisher) {
        (address target, bytes32 codeHash) =
            IStreamArtistRecoveryEvidenceBinding(suite.owners[2]).recoveryEvidenceBinding();
        require(target.codehash == codeHash && codeHash != 0, "fixed V2 evidence publisher");
        publisher = IStreamArtistRecoveryEvidence(target);
        require(
            publisher.owner() == suite.owners[2] && publisher.artistRegistry() == address(ingress)
                && publisher.deploymentChainId() == block.chainid
                && publisher.coordinator() == address(coordinator)
                && publisher.archive() == suite.archive && publisher.core() == suite.core
                && publisher.mintManager() == suite.mintManager,
            "manifest uses the original fixed suite"
        );
    }

    function _avList(bytes32 first, bytes32 second) private pure returns (bytes32[] memory values) {
        values = new bytes32[](first == 0 ? 0 : second == 0 ? 1 : 2);
        if (first == 0) return values;
        values[0] = first;
        if (second != 0) {
            values[1] = second;
            if (first > second) (values[0], values[1]) = (second, first);
        }
    }

    function _avDeclarations(bytes32 oldest, bytes32 newest)
        private
        pure
        returns (bytes32[] memory values)
    {
        values = new bytes32[](oldest == 0 ? 0 : newest == 0 ? 1 : 2);
        if (oldest != 0) values[0] = oldest;
        if (newest != 0) values[1] = newest;
    }

    function _avGuardian(address member, uint256 nonce) private returns (bytes32 record) {
        address[] memory members = new address[](1);
        members[0] = member;
        record = _guardianRecord(members, 1, 10 days, nonce);
        R.GuardianRecord memory actual = ingress.guardianSetRecord(record);
        require(actual.signer == address(artist) && actual.nonce == nonce, "actual guardian writer");
        if (
            avExecution != 0
                && block.timestamp < ingress.artistTransitionState(avExecution).postWindowEndsAt
        ) {
            require(
                actual.provisional.transitionRecordHash == avExecution
                    && actual.provisional.windowEndsAt
                        == ingress.artistTransitionState(avExecution).postWindowEndsAt,
                "original association identifies the actual takeover window"
            );
        }
    }

    function _avBundle(
        bytes32[] memory declared,
        bytes32[] memory excluded,
        bytes32[] memory hostile
    ) private returns (Adjudication memory b) {
        _newRotationSafe(++avSalt);
        Dismissal.Cause memory cause = ingress.currentIdentityContestCause(artistId);
        b.request = IdentityRecovery.Request(
            artistId,
            address(rotationSafe),
            cause.facts.authorityClass,
            cause.causeHash,
            ingress.latestIdentityContestDismissal(artistId),
            keccak256(abi.encode("V2 independent resolution evidence", ++avSalt)),
            cause.facts.kind == 1
                ? cause.facts.reasonHash
                : keccak256("V2 standing resolution reason"),
            excluded
        );
        b.manifest = EV2.ResolutionManifest(
            artistId,
            _ownerSnapshot().revision,
            cause.causeHash,
            b.request.expectedResolutionHash,
            avExecution,
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
        b.manifestHash = _avPublishManifest(b.manifest);
        b.expectedRole = hostile.length == 0 ? Appeal27.ARBITER : Appeal27.APPEAL;
        if (hostile.length != 0) {
            EV2.AppealDocumentV2 memory d = EV2.AppealDocumentV2(
                b.manifestHash,
                keccak256("V2 exact hostile guardian findings"),
                new Appeal27.Finding[](hostile.length)
            );
            for (uint256 i; i < hostile.length; ++i) {
                d.findings[i] = Appeal27.Finding(
                    hostile[i], ingress.guardianSetRecord(hostile[i]).terms.guardians
                );
            }
            b.request.evidenceHash = _avPublisher().publishAppealV2(d);
            require(
                b.request.evidenceHash
                    == keccak256(
                        abi.encode(
                            keccak256("6529STREAM_ARTIST_HOSTILE_GUARDIAN_EVIDENCE_V2"),
                            uint16(2),
                            block.chainid,
                            address(ingress),
                            suite.owners[2],
                            d
                        )
                    ),
                "literal V2 appeal document preimage"
            );
        }
        b.acceptance = _acceptance(b.request);
        require(
            roots == _roots() && b.manifest.ownerRevision == _ownerSnapshot().revision,
            "publication grants no authority and advances no owner revision"
        );
    }

    function _avPublishManifest(EV2.ResolutionManifest memory m) private returns (bytes32 hash) {
        hash = _avPublisher().publishResolutionManifest(m);
        require(
            hash
                == keccak256(
                    abi.encode(
                        keccak256("6529STREAM_ARTIST_RECOVERY_RESOLUTION_MANIFEST_V1"),
                        uint16(1),
                        block.chainid,
                        address(ingress),
                        suite.owners[2],
                        suite.owners[2].codehash,
                        address(coordinator),
                        suite.archive,
                        suite.core,
                        suite.mintManager,
                        m
                    )
                ),
            "literal fixed-environment manifest preimage"
        );
        (EV2.ResolutionManifest memory saved, bytes32 ownerCodeHash) =
            _avPublisher().resolutionManifest(hash);
        require(
            keccak256(abi.encode(saved)) == keccak256(abi.encode(m))
                && ownerCodeHash == suite.owners[2].codehash,
            "exact immutable manifest readback"
        );
    }

    function _avContext(Adjudication memory b)
        private
        view
        returns (IdentityRecovery.Context memory)
    {
        return _avRegistry().identityRecoveryContextV2(b.request, b.acceptance, b.manifestHash);
    }

    function _avSchedule(Adjudication memory b) private returns (GovernanceCall[] memory calls) {
        IdentityRecovery.Context memory c = _avContext(b);
        avScheduledContext = c;
        currentId = keccak256(abi.encode("V2 adjudication action", ++avSalt));
        calls = new GovernanceCall[](2);
        calls[0] = GovernanceCall(
            address(0x2222),
            7,
            bytes4(0x12345678),
            keccak256("preceding V2 call"),
            keccak256("other scope"),
            keccak256("other old"),
            keccak256("other new")
        );
        calls[1] = GovernanceCall(
            address(ingress),
            0,
            IStreamArtistIdentityRecoveryV2.recoverArtistIdentityV2.selector,
            keccak256(
                abi.encodeCall(
                    IStreamArtistIdentityRecoveryV2.recoverArtistIdentityV2,
                    (b.request, b.acceptance, b.manifestHash)
                )
            ),
            c.scopeHash,
            c.oldValueHash,
            c.newValueHash
        );
        scheduled.status = GovernanceActionStatus.SCHEDULED;
        scheduled.actionClass = 2;
        scheduled.target = calls[0].target;
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
        scheduled.reasonURI = "urn:unit:adjudication-v2";
        scheduled.manifestHash = keccak256("sealed unit system manifest");
        ArtistUnitGovernance(manager.governanceAuthority())
            .configureContestReads(
                suite.roleRegistry, scheduled.proposer, b.request.reasonHash, scheduled.reasonURI
            );
        _publish();
    }

    function _avRegister(Adjudication memory b) private returns (bytes32 association) {
        GovernanceCall[] memory calls = _avSchedule(b);
        bytes32 history = _avHistory();
        IdentityRecovery.Context memory beforeContext = _avContext(b);
        association = _avRegistry()
            .registerIdentityRecoveryActionV2(
                currentId, calls, b.request, b.acceptance, b.manifestHash
            );
        EV2.EvidenceStateV2 memory e =
            _avRegistry().identityRecoveryEvidenceState(artistId, currentId);
        require(
            association != 0 && e.associationHash == association && e.manifestHash == b.manifestHash
                && e.preparedFromOwnerRevision == b.manifest.ownerRevision
                && e.requiredRole == b.expectedRole && e.basisCommitment != 0
                && e.selectionCommitment != 0
                && _ownerSnapshot().revision == b.manifest.ownerRevision + 1
                && history == _avHistory()
                && keccak256(abi.encode(beforeContext)) == keccak256(abi.encode(_avContext(b))),
            "preparation saves exact anchor and manifest while keeping the executable context stable"
        );
    }

    function executeAdjudication(Adjudication calldata b) external returns (bytes32 record) {
        require(msg.sender == address(this), "V2 fixture caller");
        IdentityRecovery.Context memory c = avScheduledContext;
        address authority = manager.governanceAuthority();
        avm.mockCall(
            authority,
            abi.encodeCall(IStreamGovernanceReads.currentAction, ()),
            abi.encode(true, currentId, uint8(2), c.scopeHash, c.oldValueHash, c.newValueHash)
        );
        (bool active, bytes32 id, uint8 class_, bytes32 scope, bytes32 old_, bytes32 next_) =
            IStreamGovernanceReads(authority).currentAction();
        require(
            active && id == currentId && class_ == 2 && scope == c.scopeHash
                && old_ == c.oldValueHash && next_ == c.newValueHash,
            "exact V2 current action witness"
        );
        ArtistUnitGovernance(authority)
            .executeModuleContext(
                address(ingress),
                abi.encodeCall(
                    IStreamArtistIdentityRecoveryV2.recoverArtistIdentityV2,
                    (b.request, b.acceptance, b.manifestHash)
                ),
                2,
                c.scopeHash,
                c.oldValueHash,
                c.newValueHash
            );
        _avInactive();
        return ingress.latestIdentityRecovery(artistId);
    }

    function _avRecover(Adjudication memory b, bytes32 selected, bool retry)
        private
        returns (bytes32 record)
    {
        _avRegister(b);
        return _avFinish(b, selected, retry);
    }

    function _avFinish(Adjudication memory b, bytes32 selected, bool retry)
        private
        returns (bytes32 record)
    {
        bytes32 prior = ingress.latestIdentityRecovery(artistId);
        bytes32 oldExecution = avExecution;
        bytes32 history = _avHistory();
        bytes32 cause = _avCause(b.request.expectedCauseHash);
        Estate.AuthorityCapabilities memory originalCaps =
            ingress.currentAuthorityCapabilities(artistId);
        uint64 epoch = _avContext(b).delegationEpoch;
        bytes32 evidence =
            keccak256(abi.encode(_avRegistry().identityRecoveryEvidenceState(artistId, currentId)));
        vm.warp(scheduled.notBefore);
        scheduled.status = GovernanceActionStatus.EXECUTED;
        _publish();
        T.Snapshot memory before_ = _ownerSnapshot();
        bytes32 roots = _roots();
        bytes32 replay = _avReplayKey(
            keccak256("identity_authority.replay.contest_resolution"),
            keccak256(abi.encode(artistId, b.request.expectedCauseHash))
        );
        T.ReplayCell memory empty;
        require(
            keccak256(abi.encode(IStreamArtistOwner(suite.owners[2]).replayCell(replay)))
                == keccak256(abi.encode(empty)),
            "unconsumed original cause before V2 execution"
        );
        if (retry) {
            _overflow();
            this.executeAdjudication(b);
            _avInactive();
            (bool used,) = ingress.rotationAcceptanceNonceState(
                artistId, b.request.newAddress, b.acceptance.nonce
            );
            require(
                !used && roots == _roots() && history == _avHistory()
                    && cause == _avCause(b.request.expectedCauseHash)
                    && ingress.latestIdentityRecovery(artistId) == prior
                    && evidence
                        == keccak256(
                            abi.encode(
                                _avRegistry().identityRecoveryEvidenceState(artistId, currentId)
                            )
                        )
                    && keccak256(abi.encode(IStreamArtistOwner(suite.owners[2]).replayCell(replay)))
                    == keccak256(abi.encode(empty)),
                "late Archive failure rolls back acceptance, replay, exclusions, evidence and every original execution"
            );
            vm.roll(restoreBlock);
        }
        vm.recordLogs();
        record = this.executeAdjudication(b);
        _assertSnapshot(_snapshot(record), 35, before_, vm.getRecordedLogs());
        _avReceipts(record);
        Estate.AuthorityCapabilities memory caps = ingress.currentAuthorityCapabilities(artistId);
        (,,, bytes32 guardian) = ingress.guardianSet(artistId);
        (bool accepted,) =
            ingress.rotationAcceptanceNonceState(artistId, b.request.newAddress, b.acceptance.nonce);
        T.ReplayCell memory consumed = IStreamArtistOwner(suite.owners[2]).replayCell(replay);
        require(
            record != prior && _snapshot(record).previousTransitionRecordHash == oldExecution
                && _snapshot(record).previousCommitment
                    == (oldExecution == 0 ? bytes32(0) : _snapshot(oldExecution).commitment)
                && ingress.identityRecoveryRecord(record).delegationEpoch == epoch + 1
                && caps.authorityClass == b.request.vestedAuthorityClass
                && caps.status == b.request.vestedAuthorityClass
                && caps.authorityAddress == b.request.newAddress
                && caps.activationRecordHash == originalCaps.activationRecordHash
                && caps.effectiveCapabilities == originalCaps.effectiveCapabilities
                && guardian == selected && accepted && consumed.commitment == record
                && consumed.kind == 1 && consumed.status == 2
                && consumed.touchedRevision == before_.revision + 1 && history == _avHistory()
                && cause == _avCause(b.request.expectedCauseHash),
            "V2 preserves original history, installs exact selected head and advances the epoch once"
        );
        for (uint256 i; i < b.request.supersededRecordHashes.length; ++i) {
            require(
                _status(b.request.supersededRecordHashes[i]).recoveryRecordHash == record,
                "only the exact registered exclusions become permanent"
            );
        }
        roots = _roots();
        (bool ok,) = address(this).call(abi.encodeCall(this.executeAdjudication, (b)));
        _avInactive();
        require(
            !ok && roots == _roots() && history == _avHistory(), "consumed V2 action cannot replay"
        );
        avRecoveries.push(record);
        avExecution = record;
        _adoptRotatedSafe();
    }
}

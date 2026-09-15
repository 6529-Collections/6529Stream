// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./StreamArtistDormancyRecoveryActual.t.sol";
import {
    IStreamArtistRotation
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistRotation.sol";

/// @notice Actual op43 -> staged op29/standing veto31 -> dismissal58 -> fresh op33 -> elected35.
/// @dev Real Artist/Safe/Archive. Core/Executor remain the original typed aggregate fixture.
contract StreamArtistDormancyStandingHistoryActualTest is StreamArtistDormancyRecoveryActualTest {
    bytes32 private dsLast;
    bytes32 private dsFirst;
    bytes32 private dsLatest;
    bytes32 private dsCandidate;
    bytes32 private dsSaved;
    uint64 private dsCount = 2;
    bytes32[] private dsRotations;
    bytes32[] private dsDismissals;

    modifier standingSelf() {
        require(msg.sender == address(this), "self only");
        _;
    }

    function standingDormancySetup(bool priorLiving) external standingSelf {
        this.prepareDormancyOrigin(priorLiving);
        this.completeDormancyOrigin();
    }

    function standingDormancyAt(uint64 when, uint256 salt, bytes32 reason, bool candidate)
        external
        standingSelf
    {
        vm.warp(when);
        this.standingDormancyStage(salt);
        if (candidate) this.standingDormancyGuardian(true);
        this.standingDormancyVeto(reason);
    }

    function standingDormancyStage(uint256 salt) external standingSelf {
        _newRotationSafe(salt);
        dsLast = _stageRotation(dsLast == 0 ? origin : dsLast);
        dsRotations.push(dsLast);
        R.RotationRecord memory r = ingress.rotationRecord(dsLast);
        (bool used,) =
            ingress.rotationAcceptanceNonceState(artistId, r.terms.newAddress, r.newNonce);
        require(
            used && r.terms.oldAddress == address(artist) && r.transition.phase == 1,
            "actual two-sided rotation and permanent acceptance nonce"
        );
    }

    function standingDormancyGuardian(bool provisional) external standingSelf {
        address[] memory members = new address[](2);
        members[0] = ingress.guardianSetRecord(originalGuardian).terms.guardians[0];
        members[1] = address(delegateSafe);
        if (members[0] > members[1]) (members[0], members[1]) = (members[1], members[0]);
        bytes32 record = _guardianRecord(members, 1, 15 days, provisional ? 1001 : 2000);
        R.GuardianRecord memory g = ingress.guardianSetRecord(record);
        ++dsCount;
        require(g.authorityClass == 3 && g.signer == address(artist), "original appointed signer");
        if (provisional) {
            dsCandidate = record;
            require(
                g.provisional.transitionRecordHash == dsLast
                    && g.provisional.windowEndsAt
                        == ingress.rotationRecord(dsLast).transition.contestEndsAt,
                "candidate belongs to actual pending rotation"
            );
        } else {
            selectedGuardian = record;
            require(
                g.provisional.transitionRecordHash == 0 && g.provisional.windowEndsAt == 0,
                "fresh post-closure record has no abandoned association"
            );
        }
    }

    function standingDormancyVeto(bytes32 reason) external standingSelf {
        require(
            executeSafe(
                artist,
                keys,
                address(ingress),
                0,
                abi.encodeCall(
                    IStreamArtistRotation.vetoArtistRotation, (artistId, dsLast, reason)
                ),
                0
            ),
            "actual current successor Safe standing veto"
        );
        Dismissal.Cause memory c = ingress.currentIdentityContestCause(artistId);
        require(
            c.facts.kind == 2 && c.facts.referenceHash == dsLast
                && c.facts.pendingTransitionHash == dsLast
                && c.facts.executedTransitionHash == origin && c.facts.evidenceHash == 0
                && c.facts.reasonHash == reason && c.facts.authorityClass == 3
                && c.facts.priorStatus == 3 && c.facts.previousResolutionHash == dsLatest
                && ingress.rotationRecord(dsLast).transition.phase == 3,
            "canonical op31 cause with zero evidence and optional zero reason"
        );
    }

    function standingDormancyDismiss() external standingSelf {
        Dismissal.Request memory p = _dismissalRequest();
        dsLatest = _dismissalExecute(p, 1, 0);
        dsDismissals.push(dsLatest);
        if (dsFirst == 0) dsFirst = dsLatest;
        Dismissal.Closure memory original = ingress.identityTransitionClosure(artistId, origin);
        Dismissal.Record memory r = ingress.identityContestDismissalRecord(dsLatest);
        Dismissal.Cause memory c = ingress.identityContestCause(p.expectedCauseHash);
        require(
            original.dismissalRecordHash == dsFirst && original.transitionRecordHash == origin
                && original.windowEndsAt == windowEnd
                && original.contestedAt == ingress.artistTransitionState(origin).contestedAt
                && original.abandoned
                    == (original.contestedAt != 0 && original.contestedAt < windowEnd)
                && r.authorityClass == 3 && r.restoredStatus == 3 && r.incumbent == address(artist)
                && r.actionId != 0 && r.governanceWitnessHash != 0
                && _operationPayload(58, manager.governanceAuthority(), dsLatest).length != 0,
            "original op43 closure and actual dismissal58 Archive"
        );
        if (c.facts.kind == 2) {
            if (dsDismissals.length == 1) {
                require(
                    original.contestedAt == 0 && !original.abandoned,
                    "first standing cause does not fabricate an op43 contest marker"
                );
            }
            Dismissal.Closure memory pending =
                ingress.identityTransitionClosure(artistId, c.facts.referenceHash);
            require(
                pending.dismissalRecordHash == dsLatest && pending.abandoned
                    && pending.contestedAt == c.facts.enteredAt
                    && pending.windowEndsAt
                        == ingress.rotationRecord(c.facts.referenceHash).transition.contestEndsAt,
                "same dismissal permanently abandons the separate pending rotation"
            );
        }
    }

    function standingDormancyCompromise(uint64 when) external standingSelf {
        vm.warp(when);
        this.standingDormancyRecordCause(origin);
    }

    function standingDormancyRecordCause(bytes32 subject) external standingSelf {
        ArtistUnitGovernance authority = ArtistUnitGovernance(manager.governanceAuthority());
        ArtistUnitRoles(suite.roleRegistry).setArbiter(address(artist), true);
        bytes32 evidence = keccak256(
            abi.encode("dormancy standing compromise", subject, dsLatest, block.timestamp)
        );
        bytes32 reason =
            keccak256(abi.encode("dormancy standing reason", subject, dsLatest, block.timestamp));
        authority.configureContestReads(
            suite.roleRegistry, address(artist), reason, "urn:dormancy:standing"
        );
        (bytes32 scope, bytes32 old_, bytes32 next_) =
            ingress.identityContestGovernanceContext(artistId, subject, evidence, reason);
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
        Dismissal.Cause memory c = ingress.currentIdentityContestCause(artistId);
        require(
            c.facts.kind == 1 && c.facts.referenceHash != dsLast
                && c.facts.executedTransitionHash == subject && c.facts.pendingTransitionHash == 0
                && c.facts.previousResolutionHash == dsLatest
                && c.facts.enteredAt == block.timestamp,
            "fresh original op33 cause distinct from historical standing veto"
        );
        if (dsLatest != 0) {
            require(
                c.facts.previousCauseHash
                    == ingress.identityContestDismissalRecord(dsLatest).terms.expectedCauseHash,
                "fresh cause follows the actual latest dismissal"
            );
        }
    }

    function standingDormancyTerms()
        external
        standingSelf
        returns (IdentityRecovery.Request memory p, T.Authorization memory a)
    {
        _newRotationSafe(97099);
        Dismissal.Cause memory c = ingress.currentIdentityContestCause(artistId);
        p = IdentityRecovery.Request(
            artistId,
            address(rotationSafe),
            3,
            c.causeHash,
            dsLatest,
            c.facts.evidenceHash,
            c.facts.reasonHash,
            new bytes32[](0)
        );
        a = _acceptance(p);
    }

    function standingDormancyRegister()
        external
        standingSelf
        returns (IdentityRecovery.Request memory p, T.Authorization memory a)
    {
        (p, a) = this.standingDormancyTerms();
        GovernanceCall[] memory calls =
            _schedule(keccak256("dormancy standing original recovery"), p, a);
        ingress.registerIdentityRecoveryAction(currentId, calls, p, a);
        (RA.Association memory association,,, uint64 count) =
            ingress.identityRecoveryActionState(artistId, currentId);
        require(
            count == dsCount && association.guardian.recordHash == selectedGuardian,
            "exact operational guardian and complete retained lifetime prefix"
        );
        dsSaved = _standingHistory();
    }

    function _standingHistory() private view returns (bytes32 h) {
        (Dorm.Notice memory n, uint8 phase, Dorm.Terminal memory t) =
            _dorm().dormancyRecord(noticeHash);
        h = keccak256(
            abi.encode(
                n,
                phase,
                t,
                IStreamArtistGuardianVestingHistory(suite.owners[2])
                    .guardianVestingSnapshot(artistId, origin),
                ingress.artistTransitionState(origin),
                ingress.identityTransitionClosure(artistId, origin),
                ingress.successorDesignationRecord(t.plan.designation),
                ingress.guardianSetRecord(originalGuardian),
                ingress.guardianSetRecord(lowerGuardian),
                ingress.guardianSetRecord(dsCandidate),
                ingress.guardianSetRecord(selectedGuardian)
            )
        );
        for (uint256 i; i < dsRotations.length; ++i) {
            bytes32 id = dsRotations[i];
            h = keccak256(
                abi.encode(
                    h, ingress.rotationRecord(id), ingress.identityTransitionClosure(artistId, id)
                )
            );
        }
        for (uint256 i; i < dsDismissals.length; ++i) {
            Dismissal.Record memory r = ingress.identityContestDismissalRecord(dsDismissals[i]);
            h = keccak256(abi.encode(h, r, ingress.identityContestCause(r.terms.expectedCauseHash)));
        }
    }

    function _assertStandingRecovery(bytes32 record, IdentityRecovery.Request memory p)
        private
        view
    {
        Estate.AuthorityCapabilities memory caps = ingress.currentAuthorityCapabilities(artistId);
        V.Snapshot memory v = IStreamArtistGuardianVestingHistory(suite.owners[2])
            .guardianVestingSnapshot(artistId, record);
        (bytes32 primary, bytes32 occurrence, bytes32 secondary) =
            IStreamArtistIdentityRecoveryOwner(suite.owners[2]).identityRecoveryReceipts(record);
        require(
            record != 0 && caps.authorityClass == 3 && caps.status == 3
                && caps.authorityAddress == p.newAddress && caps.activationRecordHash == origin
                && caps.effectiveCapabilities == 256 && v.operationId == 35
                && v.previousTransitionRecordHash == origin && primary == record && occurrence != 0
                && secondary != 0 && secondary != primary && _standingHistory() == dsSaved
                && _operationPayload(35, manager.governanceAuthority(), record).length != 0,
            "original appointment/capabilities/history plus all original recovery receipts"
        );
    }

    function _abandoned() private view {
        R.GuardianRecord memory g = ingress.guardianSetRecord(dsCandidate);
        require(
            dsCandidate != 0 && g.provisional.transitionRecordHash != origin
                && !IStreamArtistRotationOwner(suite.owners[2])
                    .provisionalRecordEligible(artistId, g.provisional),
            "abandoned pending guardian never matures"
        );
    }

    function _one(bool prior, bool candidate) private {
        this.standingDormancySetup(prior);
        this.standingDormancyAt(windowEnd, 97001, bytes32(0), candidate);
        this.standingDormancyDismiss();
        this.standingDormancyCompromise(windowEnd + 1);
    }

    function _repeated() private {
        this.standingDormancySetup(false);
        this.standingDormancyAt(windowEnd, 97001, bytes32(0), false);
        this.standingDormancyDismiss();
        this.standingDormancyAt(windowEnd + 1, 97002, keccak256("second standing reason"), false);
        this.standingDormancyDismiss();
        this.standingDormancyCompromise(windowEnd + 2);
        this.standingDormancyDismiss();
        require(
            dsLatest != dsFirst, "original closure remains distinct from later kind1 resolution"
        );
        this.standingDormancyCompromise(windowEnd + 3);
    }

    function testDormancyStandingZeroReasonPriorLivingHistoryArchiveRollbackAndExactRetry() public {
        _one(true, true);
        _abandoned();
        (IdentityRecovery.Request memory p, T.Authorization memory a) =
            this.standingDormancyRegister();
        this.enterDormancyExecution();
        bytes32 roots = _roots();
        uint256 safeNonce = rotationSafe.nonce();
        avm.mockCallRevert(
            suite.archive,
            abi.encodePacked(IStreamArtistArchiveV2.appendArtistEvidenceV2.selector),
            abi.encodeWithSelector(LateRecoveryArchive.selector)
        );
        avm.expectRevert(LateRecoveryArchive.selector);
        this.executeRegistered(p, a);
        (bool used,) = ingress.rotationAcceptanceNonceState(artistId, p.newAddress, a.nonce);
        require(
            !used && rotationSafe.nonce() == safeNonce && _roots() == roots
                && ingress.latestIdentityRecovery(artistId) == 0 && _standingHistory() == dsSaved
                && _identity().identity(artistId).status == 4,
            "late Archive rolls back authority, acceptance and history"
        );
        avm.clearMockedCalls();
        _publish();
        bytes32 record = this.executeRegistered(p, a);
        _assertStandingRecovery(record, p);
        _abandoned();
        (bool replay,) = address(this).call(abi.encodeCall(this.executeRegistered, (p, a)));
        require(
            !replay && ingress.latestIdentityRecovery(artistId) == record,
            "original action cannot replay"
        );
    }

    function testDormancyStandingAfterEarlyKind1ClosureKeepsOriginalAbandonment() public {
        this.standingDormancySetup(false);
        this.standingDormancyCompromise(windowEnd - 10);
        this.standingDormancyDismiss();
        bytes32 first = dsFirst;
        this.standingDormancyAt(windowEnd - 9, 97001, bytes32(0), true);
        this.standingDormancyDismiss();
        require(
            dsLatest != first
                && ingress.identityTransitionClosure(artistId, origin).dismissalRecordHash == first
                && ingress.identityTransitionClosure(artistId, origin).abandoned,
            "standing dismissal does not replace original early kind1 closure"
        );
        this.standingDormancyCompromise(windowEnd - 8);
        (IdentityRecovery.Request memory p, T.Authorization memory a) =
            this.standingDormancyRegister();
        this.enterDormancyExecution();
        _assertStandingRecovery(this.executeRegistered(p, a), p);
        _abandoned();
    }

    function testDormancyStandingRepeatedVetoAndLaterCompromiseDismissalRemainDistinct() public {
        _repeated();
        (IdentityRecovery.Request memory p, T.Authorization memory a) =
            this.standingDormancyRegister();
        this.enterDormancyExecution();
        _assertStandingRecovery(this.executeRegistered(p, a), p);
    }

    function testDormancyStandingFreshGuardianAfterDismissalRetainsCompleteHistory() public {
        this.standingDormancySetup(false);
        this.standingDormancyAt(windowEnd, 97001, bytes32(0), true);
        this.standingDormancyDismiss();
        this.standingDormancyGuardian(false);
        _abandoned();
        this.standingDormancyCompromise(windowEnd + 1);
        (IdentityRecovery.Request memory p, T.Authorization memory a) =
            this.standingDormancyRegister();
        require(
            dsCount == 4 && ingress.identityRecoveryContext(p, a).postContestSeconds == 15 days,
            "new eligible guardian controls timing without deleting abandoned lifetime history"
        );
        this.enterDormancyExecution();
        _assertStandingRecovery(this.executeRegistered(p, a), p);
        _abandoned();
    }

    function _slot(bytes32 value, bytes32[] memory reads) private view returns (bytes32 slot) {
        uint256 count;
        for (uint256 i; i < reads.length; ++i) {
            if (vm.load(suite.owners[2], reads[i]) == value) {
                slot = reads[i];
                ++count;
            }
        }
        require(value != 0 && count == 1, "unique actual immutable owner field");
    }

    function _missingClosure(
        bytes32 transition,
        IdentityRecovery.Request memory p,
        T.Authorization memory a
    ) private {
        DormancyRecoveryStorageVm trace = DormancyRecoveryStorageVm(address(vm));
        trace.record();
        IStreamArtistIdentityDismissalOwner(suite.owners[2])
            .identityTransitionClosure(artistId, transition);
        (bytes32[] memory slots,) = trace.accesses(suite.owners[2]);
        require(slots.length == 4, "actual four packed closure cells");
        bytes32[] memory saved = new bytes32[](4);
        for (uint256 i; i < 4; ++i) {
            saved[i] = vm.load(suite.owners[2], slots[i]);
            vm.store(suite.owners[2], slots[i], bytes32(0));
        }
        avm.expectPartialRevert(IdentityRecovery.UnsupportedIdentityRecoveryProfile.selector);
        ingress.identityRecoveryContext(p, a);
        for (uint256 i; i < 4; ++i) {
            vm.store(suite.owners[2], slots[i], saved[i]);
        }
    }

    function testDormancyStandingRequiresBothClosuresAndOriginalFirstDismissal() public {
        _repeated();
        (IdentityRecovery.Request memory p, T.Authorization memory a) =
            this.standingDormancyRegister();
        bytes32 expected = keccak256(abi.encode(ingress.identityRecoveryContext(p, a)));
        _missingClosure(origin, p, a);
        _missingClosure(dsLast, p, a);
        DormancyRecoveryStorageVm trace = DormancyRecoveryStorageVm(address(vm));
        trace.record();
        ingress.identityTransitionClosure(artistId, origin);
        (bytes32[] memory reads,) = trace.accesses(suite.owners[2]);
        bytes32 slot = _slot(dsFirst, reads);
        vm.store(suite.owners[2], slot, dsLatest);
        avm.expectPartialRevert(IdentityRecovery.UnsupportedIdentityRecoveryProfile.selector);
        ingress.identityRecoveryContext(p, a);
        vm.store(suite.owners[2], slot, dsFirst);
        require(
            expected == keccak256(abi.encode(ingress.identityRecoveryContext(p, a))),
            "restored exact whole context"
        );
        this.enterDormancyExecution();
        _assertStandingRecovery(this.executeRegistered(p, a), p);
    }

    function testDormancyStandingHistoricalCauseDriftRefusesRegisteredIntentAndRestores() public {
        _repeated();
        (IdentityRecovery.Request memory p, T.Authorization memory a) =
            this.standingDormancyRegister();
        bytes32 expected = keccak256(abi.encode(ingress.identityRecoveryContext(p, a)));
        DormancyRecoveryStorageVm trace = DormancyRecoveryStorageVm(address(vm));
        bytes32 vetoCause =
            ingress.identityContestDismissalRecord(dsDismissals[1]).terms.expectedCauseHash;
        trace.record();
        ingress.identityContestCause(vetoCause);
        (bytes32[] memory reads,) = trace.accesses(suite.owners[2]);
        bytes32 slot = _slot(keccak256("second standing reason"), reads);
        vm.store(suite.owners[2], slot, p.reasonHash);
        avm.expectPartialRevert(IdentityRecovery.UnsupportedIdentityRecoveryProfile.selector);
        ingress.identityRecoveryContext(p, a);
        vm.store(suite.owners[2], slot, keccak256("second standing reason"));
        require(
            expected == keccak256(abi.encode(ingress.identityRecoveryContext(p, a))),
            "historical reason restored independently of new reason"
        );
        this.enterDormancyExecution();
        _assertStandingRecovery(this.executeRegistered(p, a), p);
    }

    function testDormancyStandingLowerNonceLifetimeSafeVetoSurvivesAbandonment() public {
        _one(false, true);
        (IdentityRecovery.Request memory p, T.Authorization memory a) =
            this.standingDormancyRegister();
        require(
            executeSafe(
                delegateSafe,
                delegateKeys,
                address(ingress),
                0,
                abi.encodeCall(
                    IStreamArtistRecoveryAction.vetoIdentityRecovery,
                    (artistId, keccak256("standing dormant lifetime veto"))
                ),
                0
            ),
            "actual lower-nonce original guardian Safe veto"
        );
        (, RA.Veto memory veto,,) = ingress.identityRecoveryActionState(artistId, currentId);
        require(
            veto.vetoer == address(delegateSafe) && selectedGuardian == originalGuardian,
            "original lower-nonce veto is independent of selected operational guardian"
        );
        this.enterDormancyExecution();
        avm.expectPartialRevert(RA.RecoveryActionVetoed.selector);
        this.executeRegistered(p, a);
        require(
            ingress.latestIdentityRecovery(artistId) == 0 && _standingHistory() == dsSaved,
            "history preserved after veto refusal"
        );
        _abandoned();
    }

    function standingDormancyExecuteRotation() external standingSelf {
        _executeTimedRotation(dsLast);
        _adoptRotatedSafe();
        vm.warp(ingress.rotationRecord(dsLast).transition.postWindowEndsAt);
        this.standingDormancyRecordCause(dsLast);
    }

    function testDormancyStandingExecutedInterveningRotationHasAdmittedRecoveryContext() public {
        this.standingDormancySetup(false);
        this.standingDormancyAt(windowEnd, 97001, bytes32(0), false);
        this.standingDormancyDismiss();
        this.standingDormancyStage(97002);
        this.standingDormancyExecuteRotation();
        (IdentityRecovery.Request memory p, T.Authorization memory a) = this.standingDormancyTerms();
        IdentityRecovery.Context memory context = ingress.identityRecoveryContext(p, a);
        require(
            context.incumbent == address(artist) && context.causeHash == p.expectedCauseHash,
            "admitted original closed appointment with current executed rotation"
        );
        require(
            ingress.latestIdentityRecovery(artistId) == 0
                && IStreamArtistGuardianVestingHistory(suite.owners[2])
                .guardianVestingSnapshot(artistId, dsLast)
                .operationId == 32,
            "actual later vesting is retained by the separate rotated profile"
        );
    }
}

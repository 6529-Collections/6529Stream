// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./StreamArtistDormancyRecoveryActual.t.sol";

/// @notice Actual designated op43 -> class3 op32 history -> op33 -> registered op35.
/// @dev Real Artist owners, Archive and threshold Safes; Core and governance remain typed unit boundaries.
contract StreamArtistDormancyRotationRecoveryActualTest is StreamArtistDormancyRecoveryActualTest {
    bytes32 internal drTerminal;
    bytes32[] internal drRotations;
    bytes32 internal drCandidate;
    bytes32 internal drSelected;
    bytes32 internal drHistory;
    uint64 internal drWindow;
    uint32 internal drCaps;
    OfficialSafe internal drLiving;
    uint256[] internal drLivingKeys;
    OfficialSafe internal drSuccessor;
    uint256[] internal drSuccessorKeys;

    modifier drSelf() {
        require(msg.sender == address(this), "self only");
        _;
    }

    function rotatedDormancySetup(bool prior) external drSelf {
        drLiving = artist;
        drLivingKeys = keys;
        this.prepareDormancyOrigin(prior);
        this.completeDormancyOrigin();
        drSuccessor = artist;
        drSuccessorKeys = keys;
        drCaps = 256;
        drTerminal = origin;
        drWindow = windowEnd;
        drSelected = originalGuardian;
    }

    function rotatedDormancyZeroPlan() external drSelf {
        drLiving = artist;
        drLivingKeys = keys;
        _accept();
        _payout();
        _delegateSetup();
        address[] memory members = new address[](1);
        members[0] = address(artist);
        originalGuardian = _guardianRecord(members, 1, 10 days, 900);
        members[0] = address(delegateSafe);
        lowerGuardian = _guardianRecord(members, 1, 20 days, 100);
        _newRotationSafe(98100);
        Succ.Designation memory plan = _successorTerms(address(rotationSafe), 2);
        plan.grantedCapabilities = 0;
        _successionRecord(plan);
        this.completeDormancyOrigin();
        drSuccessor = artist;
        drSuccessorKeys = keys;
        drTerminal = origin;
        drWindow = windowEnd;
        drSelected = originalGuardian;
    }

    function rotatedDormancyAt(uint64 when) external drSelf {
        vm.warp(when);
    }

    function rotatedDormancyStage(uint256 salt, bool early, bool returnToSuccessor)
        external
        drSelf
    {
        bytes32 prior = drTerminal;
        if (returnToSuccessor) {
            rotationSafe = drSuccessor;
            rotationKeys = drSuccessorKeys;
        } else {
            _newRotationSafe(salt);
        }
        drTerminal = _stageRotation(ingress.lastArtistTransition(artistId));
        if (early) {
            require(
                executeSafe(
                    drLiving,
                    drLivingKeys,
                    address(ingress),
                    0,
                    abi.encodeCall(
                        IStreamArtistRotation.approveArtistRotation, (artistId, drTerminal)
                    ),
                    0
                ),
                "original lifetime Safe accelerates actual rotation"
            );
            ingress.executeArtistRotation(artistId, drTerminal);
        } else {
            _executeTimedRotation(drTerminal);
        }
        _adoptRotatedSafe();
        drRotations.push(drTerminal);
        R.RotationRecord memory r = ingress.rotationRecord(drTerminal);
        V.Snapshot memory v = _drSnapshot(drTerminal);
        drWindow = r.transition.postWindowEndsAt;
        require(
            v.operationId == 32 && v.authorityClass == 3 && v.newAddress == address(artist)
                && v.previousTransitionRecordHash == prior
                && v.previousCommitment == _drSnapshot(prior).commitment && r.transition.phase == 2
                && (early
                        ? r.transition.executedAt < r.transition.contestEndsAt
                        && r.guardianApprovals >= r.approvalThreshold
                        : r.transition.executedAt == r.transition.contestEndsAt),
            "actual same-class terminal and immutable parent"
        );
        require(
            ingress.currentAuthorityCapabilities(artistId).activationRecordHash == origin
                && ingress.currentAuthorityCapabilities(artistId).effectiveCapabilities == drCaps,
            "rotation preserves original appointment mask"
        );
    }

    function rotatedDormancyGuardian(uint256 nonce) external drSelf {
        address[] memory members = new address[](2);
        members[0] = address(drLiving);
        members[1] = address(delegateSafe);
        if (members[0] > members[1]) (members[0], members[1]) = (members[1], members[0]);
        drCandidate = _guardianRecord(members, 1, 15 days, nonce);
        drSelected = drCandidate;
        R.GuardianRecord memory g = ingress.guardianSetRecord(drCandidate);
        require(
            g.authorityClass == 3 && g.signer == address(artist),
            "actual current successor signed guardian"
        );
    }

    function rotatedDormancyCompromise(uint64 when) external drSelf {
        vm.warp(when);
        this.rotatedDormancyRecordCause();
    }

    function rotatedDormancyRecordCause() external drSelf {
        ArtistUnitGovernance authority = ArtistUnitGovernance(manager.governanceAuthority());
        ArtistUnitRoles(suite.roleRegistry).setArbiter(address(artist), true);
        bytes32 evidence = keccak256(
            abi.encode(
                "rotated dormancy evidence",
                drTerminal,
                ingress.latestIdentityContestDismissal(artistId),
                block.timestamp
            )
        );
        bytes32 reason = keccak256(abi.encode("rotated dormancy reason", evidence));
        authority.configureContestReads(
            suite.roleRegistry, address(artist), reason, "urn:rotated-dormancy"
        );
        (bytes32 scope, bytes32 old_, bytes32 next_) =
            ingress.identityContestGovernanceContext(artistId, drTerminal, evidence, reason);
        authority.executeModuleContext(
            address(ingress),
            abi.encodeCall(
                IStreamArtistIdentityContest.contestArtistIdentity,
                (artistId, drTerminal, evidence, reason)
            ),
            1,
            scope,
            old_,
            next_
        );
        Dismissal.Cause memory c = ingress.currentIdentityContestCause(artistId);
        require(
            c.facts.kind == 1 && c.facts.authorityClass == 3 && c.facts.priorStatus == 3
                && c.facts.executedTransitionHash == drTerminal
                && c.facts.incumbent == address(artist) && c.facts.enteredAt == block.timestamp
                && ingress.artistTransitionState(origin).contestedAt == 0,
            "fresh actual cause names terminal and leaves origin unmarked"
        );
    }

    function rotatedDormancyDismiss() external drSelf {
        bytes32 record = _dismissalExecute(_dismissalRequest(), 1, 0);
        require(
            ingress.identityTransitionClosure(artistId, drTerminal).dismissalRecordHash != 0
                && ingress.identityTransitionClosure(artistId, origin).dismissalRecordHash == 0
                && _operationPayload(58, manager.governanceAuthority(), record).length != 0,
            "actual dismissal closes rotation only, with original Archive"
        );
        (,,, drSelected) = ingress.guardianSet(artistId);
    }

    function rotatedDormancyStanding(uint256 salt) external drSelf {
        _newRotationSafe(salt);
        bytes32 pending = _stageRotation(ingress.lastArtistTransition(artistId));
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
            "actual standing Safe veto with zero reason"
        );
        require(
            ingress.currentIdentityContestCause(artistId).facts.kind == 2,
            "standing episode retains original kind2 producer"
        );
        this.rotatedDormancyDismiss();
    }

    function rotatedDormancyTerms()
        external
        drSelf
        returns (IdentityRecovery.Request memory p, T.Authorization memory a)
    {
        _newRotationSafe(98999);
        Dismissal.Cause memory c = ingress.currentIdentityContestCause(artistId);
        p = IdentityRecovery.Request(
            artistId,
            address(rotationSafe),
            3,
            c.causeHash,
            ingress.latestIdentityContestDismissal(artistId),
            c.facts.evidenceHash,
            c.facts.reasonHash,
            new bytes32[](0)
        );
        a = _acceptance(p);
    }

    function rotatedDormancyRegister(
        IdentityRecovery.Request calldata p,
        T.Authorization calldata a
    ) external drSelf {
        GovernanceCall[] memory calls =
            _schedule(keccak256("dormancy rotated elected action"), p, a);
        ingress.registerIdentityRecoveryAction(currentId, calls, p, a);
        (RA.Association memory association,,, uint64 count) =
            ingress.identityRecoveryActionState(artistId, currentId);
        (GH.Head memory head,, GH.Snapshot memory saved,) = IStreamArtistGuardianHistory(
                suite.owners[2]
            ).guardianHistoryState(artistId, 0, address(0), currentId);
        require(
            association.guardian.recordHash == drSelected && count == head.count
                && saved.count == count && saved.historyCommitment == head.commitment
                && association.contextHash
                    == keccak256(abi.encode(ingress.identityRecoveryContext(p, a))),
            "same operational guardian and complete immutable lifetime history in election"
        );
        drHistory = _drHistory();
    }

    function _drSnapshot(bytes32 record) internal view returns (V.Snapshot memory) {
        return IStreamArtistGuardianVestingHistory(suite.owners[2])
            .guardianVestingSnapshot(artistId, record);
    }

    function _drHistory() internal view returns (bytes32 h) {
        (Dorm.Notice memory n, uint8 phase, Dorm.Terminal memory t) =
            _dorm().dormancyRecord(noticeHash);
        h = keccak256(
            abi.encode(
                n,
                phase,
                t,
                _drSnapshot(origin),
                ingress.artistTransitionState(origin),
                ingress.identityTransitionClosure(artistId, origin),
                ingress.successorDesignationRecord(t.plan.designation),
                ingress.guardianSetRecord(originalGuardian),
                ingress.guardianSetRecord(lowerGuardian),
                ingress.guardianSetRecord(drCandidate)
            )
        );
        for (uint256 i; i < drRotations.length; ++i) {
            bytes32 id = drRotations[i];
            Dismissal.Closure memory closed = ingress.identityTransitionClosure(artistId, id);
            Dismissal.Record memory resolution =
                ingress.identityContestDismissalRecord(closed.dismissalRecordHash);
            h = keccak256(
                abi.encode(
                    h,
                    ingress.rotationRecord(id),
                    _drSnapshot(id),
                    closed,
                    resolution,
                    ingress.identityContestCause(resolution.terms.expectedCauseHash)
                )
            );
        }
    }

    function _drAssert(bytes32 record, IdentityRecovery.Request memory p, T.Authorization memory a)
        internal
        view
    {
        Estate.AuthorityCapabilities memory caps = ingress.currentAuthorityCapabilities(artistId);
        V.Snapshot memory v = _drSnapshot(record);
        _assertOriginalRecoveryReceipts(record);
        (bool used,) = ingress.rotationAcceptanceNonceState(artistId, p.newAddress, a.nonce);
        require(
            record != 0 && caps.authorityClass == 3 && caps.status == 3
                && caps.authorityAddress == p.newAddress && caps.activationRecordHash == origin
                && caps.effectiveCapabilities == drCaps && v.operationId == 35
                && v.previousTransitionRecordHash == drTerminal
                && v.previousCommitment == _drSnapshot(drTerminal).commitment && used
                && _operationPayload(35, manager.governanceAuthority(), record).length != 0
                && _drHistory() == drHistory,
            "original op43 rights, actual terminal parent, acceptance, all receipts and unchanged history"
        );
    }

    function _drStart(bool prior) internal {
        this.rotatedDormancySetup(prior);
        this.rotatedDormancyAt(drWindow);
        this.rotatedDormancyStage(98001, false, false);
    }

    function _drRequest()
        internal
        returns (IdentityRecovery.Request memory p, T.Authorization memory a)
    {
        (p, a) = this.rotatedDormancyTerms();
        this.rotatedDormancyRegister(p, a);
    }

    function testDormancyRotationRecoveryKeepsLivingAncestryAppointmentAndOriginalReceipts()
        public
    {
        _drStart(true);
        this.rotatedDormancyCompromise(drWindow);
        (IdentityRecovery.Request memory p, T.Authorization memory a) = _drRequest();
        this.enterDormancyExecution();
        bytes32 record = this.executeRegistered(p, a);
        _drAssert(record, p, a);
        (bool ok,) = address(this).call(abi.encodeCall(this.executeRegistered, (p, a)));
        require(
            !ok && ingress.latestIdentityRecovery(artistId) == record,
            "same cause/action cannot replay"
        );
    }

    function testDormancyMultipleRotationsRetainIntermediateGuardianAndAllowAddressReturn() public {
        _drStart(false);
        this.rotatedDormancyAt(drWindow);
        this.rotatedDormancyGuardian(2001);
        bytes32 intermediate = drCandidate;
        this.rotatedDormancyStage(98002, false, true);
        this.rotatedDormancyCompromise(drWindow);
        (IdentityRecovery.Request memory p, T.Authorization memory a) = _drRequest();
        require(
            drSelected == intermediate
                && ingress.guardianSetRecord(intermediate).signer != address(artist)
                && ingress.identityRecoveryContext(p, a).postContestSeconds == 15 days,
            "immutable intermediate signer remains eligible after address return"
        );
        this.enterDormancyExecution();
        _drAssert(this.executeRegistered(p, a), p, a);
    }

    function testDormancyZeroMaskSuccessorRotatesWithOriginalGuardianAccelerationAndRecovers()
        public
    {
        this.rotatedDormancyZeroPlan();
        this.rotatedDormancyAt(drWindow);
        this.rotatedDormancyStage(98003, true, false);
        this.rotatedDormancyCompromise(drWindow);
        (IdentityRecovery.Request memory p, T.Authorization memory a) = _drRequest();
        this.enterDormancyExecution();
        _drAssert(this.executeRegistered(p, a), p, a);
        _adoptRotatedSafe();
        vm.expectRevert(
            abi.encodeWithSelector(
                Estate.EstateCapabilityUnavailable.selector, artistId, uint32(256)
            )
        );
        this.rotatedDormancyGuardian(3001);
        require(
            ingress.currentAuthorityCapabilities(artistId).effectiveCapabilities == 0,
            "recovery does not grant guardian-writing capability to a zero-mask successor"
        );
    }

    function testDormancyTerminalEarlyClosureNeverMaturesCandidateAndFreshGuardianCanRecover()
        public
    {
        _drStart(false);
        this.rotatedDormancyGuardian(2001);
        bytes32 abandoned = drCandidate;
        this.rotatedDormancyCompromise(drWindow - 10);
        this.rotatedDormancyDismiss();
        this.rotatedDormancyGuardian(2002);
        require(
            ingress.guardianSetRecord(drCandidate).provisional.transitionRecordHash == 0,
            "fresh post-closure record has no abandoned association"
        );
        this.rotatedDormancyCompromise(drWindow - 9);
        (IdentityRecovery.Request memory p, T.Authorization memory a) = _drRequest();
        this.enterDormancyExecution();
        require(
            !IStreamArtistRotationOwner(suite.owners[2])
                .provisionalRecordEligible(
                    artistId, ingress.guardianSetRecord(abandoned).provisional
                ),
            "abandoned guardian remains ineligible after time"
        );
        _drAssert(this.executeRegistered(p, a), p, a);
    }

    function testDormancyClosedIntermediateRotationAndStandingAttemptPreserveActualChain() public {
        _drStart(false);
        this.rotatedDormancyCompromise(drWindow - 10);
        this.rotatedDormancyDismiss();
        this.rotatedDormancyStage(98004, false, false);
        this.rotatedDormancyAt(drWindow);
        this.rotatedDormancyStanding(98005);
        this.rotatedDormancyStage(98006, false, false);
        this.rotatedDormancyCompromise(drWindow);
        (IdentityRecovery.Request memory p, T.Authorization memory a) = _drRequest();
        this.enterDormancyExecution();
        _drAssert(this.executeRegistered(p, a), p, a);
    }

    function testDormancyRotationEarlyCauseRemainsInvalidAfterItsWindowExpires() public {
        _drStart(false);
        this.rotatedDormancyCompromise(drWindow - 1);
        (IdentityRecovery.Request memory p, T.Authorization memory a) = this.rotatedDormancyTerms();
        bytes32 same = keccak256(abi.encode(p, a));
        avm.expectPartialRevert(IdentityRecovery.UnsupportedIdentityRecoveryProfile.selector);
        ingress.identityRecoveryContext(p, a);
        this.rotatedDormancyAt(drWindow + 1 days);
        avm.expectPartialRevert(IdentityRecovery.UnsupportedIdentityRecoveryProfile.selector);
        ingress.identityRecoveryContext(p, a);
        require(
            keccak256(abi.encode(p, a)) == same,
            "same original early cause never matures by waiting"
        );
    }

    function testDormancyRotationOriginalLowerNonceSafeRetainsLifetimeVeto() public {
        _drStart(false);
        this.rotatedDormancyGuardian(2001);
        this.rotatedDormancyCompromise(drWindow);
        (IdentityRecovery.Request memory p, T.Authorization memory a) = _drRequest();
        require(
            executeSafe(
                delegateSafe,
                delegateKeys,
                address(ingress),
                0,
                abi.encodeCall(
                    IStreamArtistRecoveryAction.vetoIdentityRecovery,
                    (artistId, keccak256("lifetime objection"))
                ),
                0
            ),
            "lower nonce original lifetime Safe veto"
        );
        this.enterDormancyExecution();
        avm.expectPartialRevert(RA.RecoveryActionVetoed.selector);
        this.executeRegistered(p, a);
        require(
            ingress.latestIdentityRecovery(artistId) == 0 && _drHistory() == drHistory,
            "fresh operational set never erases original lifetime veto"
        );
    }

    function testDormancyRotationParentCorruptionRefusesAndExactRestorePreservesRegisteredIntent()
        public
    {
        _drStart(false);
        this.rotatedDormancyAt(drWindow);
        this.rotatedDormancyStage(98007, false, false);
        this.rotatedDormancyCompromise(drWindow);
        (IdentityRecovery.Request memory p, T.Authorization memory a) = _drRequest();
        bytes32 context = keccak256(abi.encode(ingress.identityRecoveryContext(p, a)));
        bytes32 original = _drSnapshot(drTerminal).previousCommitment;
        DormancyRecoveryStorageVm trace = DormancyRecoveryStorageVm(address(vm));
        trace.record();
        _drSnapshot(drTerminal);
        (bytes32[] memory reads,) = trace.accesses(suite.owners[2]);
        bytes32 slot;
        uint256 count;
        for (uint256 i; i < reads.length; ++i) {
            if (vm.load(suite.owners[2], reads[i]) == original) {
                slot = reads[i];
                ++count;
            }
        }
        require(count == 1 && original != 0, "unique actual immutable parent commitment cell");
        vm.store(suite.owners[2], slot, keccak256("foreign parent"));
        avm.expectPartialRevert(IdentityRecovery.UnsupportedIdentityRecoveryProfile.selector);
        this.executeRegistered(p, a);
        vm.store(suite.owners[2], slot, original);
        require(
            keccak256(abi.encode(ingress.identityRecoveryContext(p, a))) == context,
            "exact original elected context restored"
        );
        this.enterDormancyExecution();
        _drAssert(this.executeRegistered(p, a), p, a);
    }

    function testDormancyRotationLateArchiveFailureRestoresAuthorityNonceAndIdenticalSafeAcceptance()
        public
    {
        _drStart(false);
        this.rotatedDormancyCompromise(drWindow);
        (IdentityRecovery.Request memory p, T.Authorization memory a) = _drRequest();
        this.enterDormancyExecution();
        bytes32 roots = _roots();
        bytes32 principal = keccak256(abi.encode(_identity().identity(artistId)));
        uint256 nonce = rotationSafe.nonce();
        bytes32 exact = keccak256(abi.encode(p, a));
        avm.mockCallRevert(
            suite.archive,
            abi.encodePacked(IStreamArtistArchiveV2.appendArtistEvidenceV2.selector),
            abi.encodeWithSelector(LateRecoveryArchive.selector)
        );
        avm.expectRevert(LateRecoveryArchive.selector);
        this.executeRegistered(p, a);
        (bool used,) = ingress.rotationAcceptanceNonceState(artistId, p.newAddress, a.nonce);
        require(
            !used && _roots() == roots && _drHistory() == drHistory && rotationSafe.nonce() == nonce
                && ingress.latestIdentityRecovery(artistId) == 0
                && keccak256(abi.encode(_identity().identity(artistId))) == principal,
            "late Archive restores every authority root, history, acceptance and Safe nonce"
        );
        avm.clearMockedCalls();
        _publish();
        require(
            keccak256(abi.encode(p, a)) == exact, "byte-identical original Safe acceptance retry"
        );
        _drAssert(this.executeRegistered(p, a), p, a);
    }
}

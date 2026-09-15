// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "./StreamArtistDormancyRecoveryActual.t.sol";

/// @notice Actual op43 -> op33 -> dismissal58 -> fresh op33 -> registered op35.
/// @dev Actual Artist/Safe/Archive; typed Core/Executor and aggregate fixture scope.
contract StreamArtistClosedDormancyRecoveryActualTest is StreamArtistDormancyRecoveryActualTest {
    bytes32 private cdFirst;
    bytes32 private cdLatest;
    bytes32 private cdCandidate;
    bytes32 private cdHistory;

    function closedDormancySetup(bool priorLivingRotation, bool early, bool candidate) external {
        require(msg.sender == address(this), "self only");
        this.prepareDormancyOrigin(priorLivingRotation);
        this.completeDormancyOrigin();
        if (candidate) this.closedDormancyCandidate();
        this.closedDormancyCompromise(early ? windowEnd - 10 : windowEnd);
        this.closedDormancyDismiss(early);
    }

    function closedDormancyCandidate() external {
        require(msg.sender == address(this), "self only");
        address[] memory members = new address[](2);
        members[0] = ingress.guardianSetRecord(originalGuardian).terms.guardians[0];
        members[1] = address(delegateSafe);
        if (members[0] > members[1]) (members[0], members[1]) = (members[1], members[0]);
        cdCandidate = _guardianRecord(members, 1, 15 days, 1001);
        R.GuardianRecord memory g = ingress.guardianSetRecord(cdCandidate);
        require(
            g.authorityClass == 3 && g.signer == address(artist)
                && g.provisional.transitionRecordHash == origin
                && g.provisional.windowEndsAt == windowEnd,
            "actual appointed successor writes into original provisional window"
        );
    }

    function closedDormancyCompromise(uint64 when) external {
        require(msg.sender == address(this), "self only");
        vm.warp(when);
        this.closedDormancyRecordCause();
    }

    function closedDormancyRecordCause() external {
        require(msg.sender == address(this), "self only");
        ArtistUnitGovernance authority = ArtistUnitGovernance(manager.governanceAuthority());
        ArtistUnitRoles(suite.roleRegistry).setArbiter(address(artist), true);
        bytes32 evidence =
            keccak256(abi.encode("closed dormancy evidence", origin, cdLatest, block.timestamp));
        bytes32 reason =
            keccak256(abi.encode("closed dormancy reason", origin, cdLatest, block.timestamp));
        authority.configureContestReads(
            suite.roleRegistry, address(artist), reason, "urn:closed-dormancy"
        );
        (bytes32 scope, bytes32 old_, bytes32 next_) =
            ingress.identityContestGovernanceContext(artistId, origin, evidence, reason);
        authority.executeModuleContext(
            address(ingress),
            abi.encodeCall(
                IStreamArtistIdentityContest.contestArtistIdentity,
                (artistId, origin, evidence, reason)
            ),
            1,
            scope,
            old_,
            next_
        );
        Dismissal.Cause memory cause = ingress.currentIdentityContestCause(artistId);
        require(
            cause.facts.kind == 1 && cause.facts.authorityClass == 3 && cause.facts.priorStatus == 3
                && cause.facts.incumbent == address(artist)
                && cause.facts.executedTransitionHash == origin
                && cause.facts.previousResolutionHash == cdLatest
                && cause.facts.enteredAt == block.timestamp,
            "actual new op33 cause and original appointment"
        );
        if (cdLatest != 0) {
            require(
                cause.facts.previousCauseHash
                    == ingress.identityContestDismissalRecord(cdLatest).terms.expectedCauseHash,
                "current previous cause is actual latest dismissed cause"
            );
        }
    }

    function closedDormancyDismiss(bool abandoned) external {
        require(msg.sender == address(this), "self only");
        Dismissal.Request memory p = _dismissalRequest();
        cdLatest = _dismissalExecute(p, 1, 0);
        if (cdFirst == 0) cdFirst = cdLatest;
        Dismissal.Closure memory closed = ingress.identityTransitionClosure(artistId, origin);
        Dismissal.Record memory r = ingress.identityContestDismissalRecord(cdLatest);
        require(
            closed.transitionRecordHash == origin && closed.dismissalRecordHash == cdFirst
                && closed.windowEndsAt == windowEnd && closed.abandoned == abandoned
                && r.incumbent == address(artist) && r.authorityClass == 3 && r.restoredStatus == 3
                && r.actionId != 0 && r.governanceWitnessHash != 0
                && _operationPayload(58, manager.governanceAuthority(), cdLatest).length != 0,
            "actual dismissal58 Archive and immutable first closure"
        );
    }

    function closedDormancyRegister(bytes32 action)
        external
        returns (IdentityRecovery.Request memory p, T.Authorization memory a)
    {
        require(msg.sender == address(this), "self only");
        _newRotationSafe(9601);
        Dismissal.Cause memory cause = ingress.currentIdentityContestCause(artistId);
        p = IdentityRecovery.Request(
            artistId,
            address(rotationSafe),
            3,
            cause.causeHash,
            cdLatest,
            cause.facts.evidenceHash,
            cause.facts.reasonHash,
            new bytes32[](0)
        );
        a = _acceptance(p);
        GovernanceCall[] memory calls = _schedule(action, p, a);
        ingress.registerIdentityRecoveryAction(currentId, calls, p, a);
        (RA.Association memory association,,, uint64 count) =
            ingress.identityRecoveryActionState(artistId, action);
        bytes32 expected = cdCandidate != 0
            && !ingress.identityTransitionClosure(artistId, origin).abandoned
            ? cdCandidate
            : originalGuardian;
        require(
            association.guardian.recordHash == expected && count == (cdCandidate == 0 ? 2 : 3),
            "full original prefix plus exact eligible guardian selection"
        );
        cdHistory = _closedHistory();
    }

    function _closedHistory() private view returns (bytes32) {
        (Dorm.Notice memory n, uint8 phase, Dorm.Terminal memory t) =
            _dorm().dormancyRecord(noticeHash);
        Dismissal.Record memory first = ingress.identityContestDismissalRecord(cdFirst);
        Dismissal.Record memory latest = ingress.identityContestDismissalRecord(cdLatest);
        V.Snapshot memory v = IStreamArtistGuardianVestingHistory(suite.owners[2])
            .guardianVestingSnapshot(artistId, origin);
        return keccak256(
            abi.encode(
                n,
                phase,
                t,
                v,
                ingress.artistTransitionState(origin),
                ingress.identityTransitionClosure(artistId, origin),
                first,
                latest,
                ingress.identityContestCause(first.terms.expectedCauseHash),
                ingress.identityContestCause(latest.terms.expectedCauseHash),
                ingress.guardianSetRecord(originalGuardian),
                ingress.guardianSetRecord(lowerGuardian),
                ingress.guardianSetRecord(cdCandidate)
            )
        );
    }

    function _assertClosedRecovery(bytes32 record, IdentityRecovery.Request memory p) private view {
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
                && secondary != 0 && secondary != primary
                && _operationPayload(35, manager.governanceAuthority(), record).length != 0
                && _closedHistory() == cdHistory,
            "same canonical appointment and all immutable closure facts after recovery"
        );
    }

    function _abandoned() private view {
        R.GuardianRecord memory g = ingress.guardianSetRecord(cdCandidate);
        require(
            g.provisional.transitionRecordHash == origin
                && !IStreamArtistRotationOwner(suite.owners[2])
                    .provisionalRecordEligible(artistId, g.provisional),
            "abandoned original candidate never matures"
        );
    }

    function testClosedDormancyEarlyDismissalPriorLivingHistoryAndArchiveExactRetry() public {
        this.closedDormancySetup(true, true, true);
        _abandoned();
        this.closedDormancyCompromise(windowEnd - 9);
        (IdentityRecovery.Request memory p, T.Authorization memory a) =
            this.closedDormancyRegister(keccak256("closed dormancy late archive"));
        this.enterDormancyExecution();
        bytes32 roots = _roots();
        avm.mockCallRevert(
            suite.archive,
            abi.encodePacked(IStreamArtistArchiveV2.appendArtistEvidenceV2.selector),
            abi.encodeWithSelector(LateRecoveryArchive.selector)
        );
        avm.expectRevert(LateRecoveryArchive.selector);
        this.executeRegistered(p, a);
        (bool used,) = ingress.rotationAcceptanceNonceState(artistId, p.newAddress, a.nonce);
        require(
            !used && ingress.latestIdentityRecovery(artistId) == 0 && _roots() == roots
                && _closedHistory() == cdHistory && _identity().identity(artistId).status == 4,
            "late Archive failure preserves closure, nonce and original authority"
        );
        avm.clearMockedCalls();
        _publish();
        bytes32 record = this.executeRegistered(p, a);
        _assertClosedRecovery(record, p);
        _abandoned();
        (bool ok,) = address(this).call(abi.encodeCall(this.executeRegistered, (p, a)));
        require(
            !ok && ingress.latestIdentityRecovery(artistId) == record,
            "consumed exact action cannot replay"
        );
    }

    function testClosedDormancyPostWindowDismissalPreservesMatureGuardian() public {
        this.closedDormancySetup(false, false, true);
        R.GuardianRecord memory g = ingress.guardianSetRecord(cdCandidate);
        require(
            IStreamArtistRotationOwner(suite.owners[2])
                .provisionalRecordEligible(artistId, g.provisional),
            "original candidate matured before non-abandoned contest"
        );
        this.closedDormancyCompromise(windowEnd + 1);
        (IdentityRecovery.Request memory p, T.Authorization memory a) =
            this.closedDormancyRegister(keccak256("mature dormancy guardian"));
        require(
            ingress.identityRecoveryContext(p, a).postContestSeconds == 15 days,
            "actual mature guardian timing"
        );
        this.enterDormancyExecution();
        _assertClosedRecovery(this.executeRegistered(p, a), p);
    }

    function _twice() private {
        this.closedDormancySetup(false, true, false);
        this.closedDormancyCompromise(windowEnd - 9);
        this.closedDormancyDismiss(true);
        require(cdLatest != cdFirst, "second actual dismissal with distinct original cause");
        this.closedDormancyCompromise(windowEnd - 8);
    }

    function testClosedDormancyInterveningDismissalsKeepFirstClosureAndOriginalAuthority() public {
        _twice();
        (IdentityRecovery.Request memory p, T.Authorization memory a) =
            this.closedDormancyRegister(keccak256("intervening dormancy dismissal"));
        this.enterDormancyExecution();
        _assertClosedRecovery(this.executeRegistered(p, a), p);
    }

    function _slot(bytes32 value, bytes32[] memory reads) private view returns (bytes32 slot) {
        uint256 count;
        for (uint256 i; i < reads.length; ++i) {
            if (vm.load(suite.owners[2], reads[i]) == value) {
                slot = reads[i];
                ++count;
            }
        }
        require(value != 0 && count == 1, "unique actual owner field");
    }

    function testClosedDormancyMissingOrLatestSubstitutedClosureRefusesThenExactRestore() public {
        _twice();
        (IdentityRecovery.Request memory p, T.Authorization memory a) =
            this.closedDormancyRegister(keccak256("original dormancy closure required"));
        bytes32 context = keccak256(abi.encode(ingress.identityRecoveryContext(p, a)));
        DormancyRecoveryStorageVm trace = DormancyRecoveryStorageVm(address(vm));
        trace.record();
        ingress.identityTransitionClosure(artistId, origin);
        (bytes32[] memory reads,) = trace.accesses(suite.owners[2]);
        bytes32 slot = _slot(cdFirst, reads);
        vm.store(suite.owners[2], slot, cdLatest);
        avm.expectPartialRevert(IdentityRecovery.UnsupportedIdentityRecoveryProfile.selector);
        ingress.identityRecoveryContext(p, a);
        vm.store(suite.owners[2], slot, bytes32(0));
        avm.expectPartialRevert(IdentityRecovery.UnsupportedIdentityRecoveryProfile.selector);
        ingress.identityRecoveryContext(p, a);
        vm.store(suite.owners[2], slot, cdFirst);
        trace.record();
        IStreamArtistIdentityDismissalOwner(suite.owners[2])
            .identityTransitionClosure(artistId, origin);
        (bytes32[] memory closureSlots,) = trace.accesses(suite.owners[2]);
        require(closureSlots.length == 4, "actual four packed closure slots");
        bytes32[] memory saved = new bytes32[](4);
        for (uint256 i; i < 4; ++i) {
            saved[i] = vm.load(suite.owners[2], closureSlots[i]);
            vm.store(suite.owners[2], closureSlots[i], bytes32(0));
        }
        avm.expectPartialRevert(IdentityRecovery.UnsupportedIdentityRecoveryProfile.selector);
        ingress.identityRecoveryContext(p, a);
        for (uint256 i; i < 4; ++i) {
            vm.store(suite.owners[2], closureSlots[i], saved[i]);
        }
        require(
            keccak256(abi.encode(ingress.identityRecoveryContext(p, a))) == context,
            "exact immutable first closure restored for same request"
        );
        this.enterDormancyExecution();
        _assertClosedRecovery(this.executeRegistered(p, a), p);
    }

    function testClosedDormancyLatestCauseDriftCannotReuseRegisteredContext() public {
        _twice();
        (IdentityRecovery.Request memory p, T.Authorization memory a) =
            this.closedDormancyRegister(keccak256("latest dormancy cause required"));
        bytes32 context = keccak256(abi.encode(ingress.identityRecoveryContext(p, a)));
        DormancyRecoveryStorageVm trace = DormancyRecoveryStorageVm(address(vm));
        trace.record();
        bytes32 original = ingress.identityContestDismissalRecord(cdLatest).terms.expectedCauseHash;
        (bytes32[] memory reads,) = trace.accesses(suite.owners[2]);
        bytes32 slot = _slot(original, reads);
        vm.store(suite.owners[2], slot, p.expectedCauseHash);
        avm.expectPartialRevert(IdentityRecovery.UnsupportedIdentityRecoveryProfile.selector);
        ingress.identityRecoveryContext(p, a);
        vm.store(suite.owners[2], slot, original);
        require(
            keccak256(abi.encode(ingress.identityRecoveryContext(p, a))) == context,
            "original latest cause is bound into both scheduled hashes"
        );
        this.enterDormancyExecution();
        _assertClosedRecovery(this.executeRegistered(p, a), p);
    }

    function testClosedDormancyLowerNonceLifetimeGuardianVetoSurvivesAbandonment() public {
        this.closedDormancySetup(false, true, true);
        this.closedDormancyCompromise(windowEnd - 9);
        bytes32 action = keccak256("closed dormancy lifetime veto");
        (IdentityRecovery.Request memory p, T.Authorization memory a) =
            this.closedDormancyRegister(action);
        require(
            executeSafe(
                delegateSafe,
                delegateKeys,
                address(ingress),
                0,
                abi.encodeCall(
                    IStreamArtistRecoveryAction.vetoIdentityRecovery,
                    (artistId, keccak256("lower nonce lifetime guardian"))
                ),
                0
            ),
            "actual Safe lifetime veto"
        );
        (, RA.Veto memory veto,,) = ingress.identityRecoveryActionState(artistId, action);
        require(veto.vetoer == address(delegateSafe), "original lower nonce guardian witness");
        this.enterDormancyExecution();
        avm.expectPartialRevert(RA.RecoveryActionVetoed.selector);
        this.executeRegistered(p, a);
        require(
            ingress.latestIdentityRecovery(artistId) == 0 && _closedHistory() == cdHistory,
            "dismissal does not erase lifetime veto"
        );
        vm.warp(uint256(windowEnd) + 1 days);
        _abandoned();
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./StreamArtistDormancyRotationRecoveryActual.t.sol";

/// @notice Actual original op43 dismissal followed by executed rotations and first elected recovery.
/// @dev Real Artist/Archive/Safe; the inherited Core and governance fixtures remain typed boundaries.
contract StreamArtistDormancyClosedOriginRotationRecoveryActualTest is
    StreamArtistDormancyRotationRecoveryActualTest
{
    bytes32 private coFirst;
    bytes32 private coLatest;
    bytes32 private coAbandoned;
    bytes32 private coSaved;

    function closedOriginCauseAt(uint64 when) external drSelf {
        vm.warp(when);
        this.closedOriginRecordCause();
    }

    function closedOriginRecordCause() external drSelf {
        ArtistUnitGovernance authority = ArtistUnitGovernance(manager.governanceAuthority());
        ArtistUnitRoles(suite.roleRegistry).setArbiter(address(artist), true);
        bytes32 evidence = keccak256(
            abi.encode(
                "closed origin episode",
                drTerminal,
                ingress.latestIdentityContestDismissal(artistId),
                block.timestamp
            )
        );
        bytes32 reason = keccak256(abi.encode("closed origin reason", evidence));
        authority.configureContestReads(
            suite.roleRegistry, address(artist), reason, "urn:closed-origin-rotation"
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
                && c.facts.incumbent == address(artist) && c.facts.enteredAt == block.timestamp,
            "actual cause follows selected execution and incumbent"
        );
    }

    function closedOriginDismiss() external drSelf {
        bytes32 record = _dismissalExecute(_dismissalRequest(), 1, 0);
        if (drTerminal == origin) {
            coLatest = record;
            if (coFirst == 0) coFirst = record;
        }
        Dismissal.Closure memory closed = ingress.identityTransitionClosure(artistId, origin);
        Dismissal.Record memory first = ingress.identityContestDismissalRecord(coFirst);
        require(
            closed.dismissalRecordHash == coFirst && closed.transitionRecordHash == origin
                && closed.windowEndsAt == windowEnd && first.incumbent == address(drSuccessor)
                && first.authorityClass == 3 && first.restoredStatus == 3
                && _operationPayload(58, manager.governanceAuthority(), record).length != 0,
            "immutable original closure, actual original appointed principal and Archive"
        );
        (,,, drSelected) = ingress.guardianSet(artistId);
    }

    function closedOriginStanding() external drSelf {
        _newRotationSafe(99101);
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
            "original appointed Safe standing veto"
        );
        Dismissal.Cause memory c = ingress.currentIdentityContestCause(artistId);
        require(
            c.facts.kind == 2 && c.facts.reasonHash == 0 && c.facts.evidenceHash == 0
                && c.facts.executedTransitionHash == origin && c.facts.referenceHash == pending,
            "actual original kind2 cause retains zero reason/evidence"
        );
        this.closedOriginDismiss();
        require(
            ingress.identityTransitionClosure(artistId, pending).abandoned
                && !ingress.identityTransitionClosure(artistId, origin).abandoned,
            "different pending abandonment and expired executed origin closure"
        );
    }

    function closedOriginSetup(bool prior, bool standing, bool candidate) external drSelf {
        this.rotatedDormancySetup(prior);
        if (candidate) {
            this.rotatedDormancyGuardian(2001);
            coAbandoned = drCandidate;
        }
        if (standing) {
            this.rotatedDormancyAt(windowEnd);
            this.closedOriginStanding();
        } else {
            this.closedOriginCauseAt(windowEnd - 10);
            this.closedOriginDismiss();
        }
    }

    function _coOriginals() private view returns (bytes32) {
        Dismissal.Record memory first = ingress.identityContestDismissalRecord(coFirst);
        Dismissal.Record memory latest = ingress.identityContestDismissalRecord(coLatest);
        return keccak256(
            abi.encode(
                ingress.identityTransitionClosure(artistId, origin),
                first,
                latest,
                ingress.identityContestCause(first.terms.expectedCauseHash),
                ingress.identityContestCause(latest.terms.expectedCauseHash),
                ingress.guardianSetRecord(coAbandoned)
            )
        );
    }

    function _coRequest()
        private
        returns (IdentityRecovery.Request memory p, T.Authorization memory a)
    {
        (p, a) = this.rotatedDormancyTerms();
        this.rotatedDormancyRegister(p, a);
        coSaved = _coOriginals();
    }

    function _coAssert(bytes32 record, IdentityRecovery.Request memory p, T.Authorization memory a)
        private
        view
    {
        _drAssert(record, p, a);
        require(
            _coOriginals() == coSaved,
            "original principal dismissal/cause/history remain exact after recovery"
        );
        if (coAbandoned != 0) {
            require(
                !IStreamArtistRotationOwner(suite.owners[2])
                    .provisionalRecordEligible(
                        artistId, ingress.guardianSetRecord(coAbandoned).provisional
                    ),
                "abandoned original candidate never matures"
            );
        }
    }

    function testClosedDormancyOriginPriorLivingHistoryRotationAndIdenticalArchiveRetry() public {
        this.closedOriginSetup(true, false, true);
        this.rotatedDormancyStage(99102, false, false);
        this.closedOriginCauseAt(drWindow);
        (IdentityRecovery.Request memory p, T.Authorization memory a) = _coRequest();
        this.enterDormancyExecution();
        bytes32 roots = _roots();
        bytes32 principal = keccak256(abi.encode(_identity().identity(artistId)));
        bytes32 same = keccak256(abi.encode(p, a));
        uint256 nonce = rotationSafe.nonce();
        avm.mockCallRevert(
            suite.archive,
            abi.encodePacked(IStreamArtistArchiveV2.appendArtistEvidenceV2.selector),
            abi.encodeWithSelector(LateRecoveryArchive.selector)
        );
        avm.expectRevert(LateRecoveryArchive.selector);
        this.executeRegistered(p, a);
        (bool used,) = ingress.rotationAcceptanceNonceState(artistId, p.newAddress, a.nonce);
        require(
            !used && _roots() == roots && ingress.latestIdentityRecovery(artistId) == 0
                && rotationSafe.nonce() == nonce && _coOriginals() == coSaved
                && _drHistory() == drHistory
                && keccak256(abi.encode(_identity().identity(artistId))) == principal,
            "whole original and terminal history/authority/replay rollback"
        );
        avm.clearMockedCalls();
        _publish();
        require(keccak256(abi.encode(p, a)) == same, "byte-identical original Safe acceptance");
        _coAssert(this.executeRegistered(p, a), p, a);
    }

    function testClosedDormancyOriginStandingZeroReasonThenRepeatedExecutedRotations() public {
        this.closedOriginSetup(false, true, false);
        this.rotatedDormancyStage(99103, false, false);
        this.rotatedDormancyAt(drWindow);
        this.rotatedDormancyGuardian(2001);
        this.rotatedDormancyStage(99104, false, true);
        this.closedOriginCauseAt(drWindow);
        (IdentityRecovery.Request memory p, T.Authorization memory a) = _coRequest();
        this.enterDormancyExecution();
        _coAssert(this.executeRegistered(p, a), p, a);
    }

    function testClosedDormancyOriginKeepsFirstAndLaterOriginalDismissalsDistinct() public {
        this.closedOriginSetup(false, false, false);
        this.closedOriginCauseAt(windowEnd - 9);
        this.closedOriginDismiss();
        require(
            coLatest != coFirst
                && ingress.identityTransitionClosure(artistId, origin).dismissalRecordHash
                    == coFirst,
            "original immutable closure cannot move to a later dismissal"
        );
        this.rotatedDormancyStage(99105, false, false);
        this.closedOriginCauseAt(drWindow);
        (IdentityRecovery.Request memory p, T.Authorization memory a) = _coRequest();
        this.enterDormancyExecution();
        bytes32 record = this.executeRegistered(p, a);
        _coAssert(record, p, a);
        (bool ok,) = address(this).call(abi.encodeCall(this.executeRegistered, (p, a)));
        require(
            !ok && ingress.latestIdentityRecovery(artistId) == record,
            "exact elected action remains consumed"
        );
    }

    function testClosedDormancyOriginAndTerminalClosuresCannotSubstituteForEachOther() public {
        this.closedOriginSetup(false, false, false);
        this.rotatedDormancyStage(99106, false, false);
        this.closedOriginCauseAt(drWindow - 10);
        this.closedOriginDismiss();
        bytes32 terminalFirst =
            ingress.identityTransitionClosure(artistId, drTerminal).dismissalRecordHash;
        this.closedOriginCauseAt(drWindow - 9);
        (IdentityRecovery.Request memory p, T.Authorization memory a) = _coRequest();
        bytes32 context = keccak256(abi.encode(ingress.identityRecoveryContext(p, a)));
        DormancyRecoveryStorageVm trace = DormancyRecoveryStorageVm(address(vm));
        trace.record();
        ingress.identityTransitionClosure(artistId, origin);
        (bytes32[] memory reads,) = trace.accesses(suite.owners[2]);
        bytes32 slot;
        uint256 count;
        for (uint256 i; i < reads.length; ++i) {
            if (vm.load(suite.owners[2], reads[i]) == coFirst) {
                slot = reads[i];
                ++count;
            }
        }
        require(
            count == 1 && coFirst != 0 && terminalFirst != 0 && terminalFirst != coFirst,
            "two actual distinct immutable original/terminal closure records"
        );
        vm.store(suite.owners[2], slot, terminalFirst);
        avm.expectPartialRevert(IdentityRecovery.UnsupportedIdentityRecoveryProfile.selector);
        this.executeRegistered(p, a);
        vm.store(suite.owners[2], slot, bytes32(0));
        avm.expectPartialRevert(IdentityRecovery.UnsupportedIdentityRecoveryProfile.selector);
        this.executeRegistered(p, a);
        vm.store(suite.owners[2], slot, coFirst);
        require(
            keccak256(abi.encode(ingress.identityRecoveryContext(p, a))) == context,
            "exact original closure restoration retains registered intent"
        );
        this.enterDormancyExecution();
        _coAssert(this.executeRegistered(p, a), p, a);
    }

    function testClosedDormancyOriginAbandonedGuardianDoesNotEraseLowerNonceLifetimeVeto() public {
        this.closedOriginSetup(false, false, true);
        this.rotatedDormancyStage(99107, false, false);
        this.rotatedDormancyAt(drWindow);
        this.rotatedDormancyGuardian(2002);
        this.closedOriginCauseAt(drWindow);
        (IdentityRecovery.Request memory p, T.Authorization memory a) = _coRequest();
        require(
            executeSafe(
                delegateSafe,
                delegateKeys,
                address(ingress),
                0,
                abi.encodeCall(
                    IStreamArtistRecoveryAction.vetoIdentityRecovery,
                    (artistId, keccak256("old guardian objection"))
                ),
                0
            ),
            "actual lifetime guardian Safe veto after abandoned origin and fresh terminal set"
        );
        this.enterDormancyExecution();
        avm.expectPartialRevert(RA.RecoveryActionVetoed.selector);
        this.executeRegistered(p, a);
        require(
            ingress.latestIdentityRecovery(artistId) == 0 && _coOriginals() == coSaved,
            "lifetime veto preserves original closed history"
        );
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./StreamArtistEstateRotatedRecoveryActual.t.sol";
import {
    StreamArtistDelegationTypes as ClosedEstateDelegation
} from "../../../smart-contracts/interfaces/stream/artist/StreamArtistDelegationTypes.sol";
import {
    StreamArtistRecoveryEstateRotationOrigin
} from "../../../smart-contracts/domains/artist/StreamArtistRecoveryEstateRotationOrigin.sol";

/// @notice Actual closed op40 -> one or more executed op32 -> registered op35 histories.
/// @dev Artist/Safe/Archive are real. Core/governance facts retain the existing typed unit boundary.
contract StreamArtistClosedEstateRotationRecoveryActualTest is
    StreamArtistEstateRotatedRecoveryActualTest
{
    bytes32 private crDismissal;
    bytes32 private crCause;
    bytes32 private crOriginal;
    bytes32 private crPriorDismissal;
    uint64 private crOriginWindow;

    function closedOriginSetup(uint32 caps, bool early, bool standing, uint8 livingDepth)
        external
        onlySelf
    {
        erLiving = artist;
        erLivingKeys = keys;
        erCaps = caps;
        this.historySetup(livingDepth, caps, livingDepth != 0);
        erOrigin = ingress.currentAuthorityCapabilities(artistId).activationRecordHash;
        erTerminal = erOrigin;
        (,,, erGuardian) = ingress.guardianSet(artistId);
        R.TransitionState memory origin = ingress.artistTransitionState(erOrigin);
        crOriginWindow = origin.postWindowEndsAt;
        if (standing) {
            this.historyStandingEpisode(crOriginWindow, 67001, bytes32(0));
        } else {
            this.closedOriginCompromise(erOrigin, early ? origin.executedAt + 1 : crOriginWindow);
        }
        crCause = ingress.currentIdentityContestCause(artistId).causeHash;
        crDismissal = this.closedOriginDismiss(erOrigin);
        Dismissal.Closure memory c = ingress.identityTransitionClosure(artistId, erOrigin);
        require(
            c.dismissalRecordHash == crDismissal && c.abandoned == early
                && c.windowEndsAt == crOriginWindow
                && (standing ? c.contestedAt == 0 : c.contestedAt != 0),
            "original op41 closes the original40 episode before any executed successor rotation"
        );
        crOriginal = _crOriginal();
        require(
            address(StreamArtistRecoveryEstateRotationOrigin).code.length <= 24576,
            "bounded original closure helper runtime"
        );
    }

    function closedOriginCompromise(bytes32 subject, uint64 when) external onlySelf {
        vm.warp(when);
        ArtistUnitGovernance authority = ArtistUnitGovernance(manager.governanceAuthority());
        ArtistUnitRoles(suite.roleRegistry).setArbiter(address(artist), true);
        bytes32 evidence = keccak256(abi.encode("closed origin compromise", subject, when));
        bytes32 reason = keccak256(abi.encode("closed origin reason", subject, when));
        authority.configureContestReads(
            suite.roleRegistry, address(artist), reason, "urn:unit:closed-origin"
        );
        (bytes32 scope, bytes32 oldHash, bytes32 newHash) =
            ingress.identityContestGovernanceContext(artistId, subject, evidence, reason);
        authority.executeModuleContext(
            address(ingress),
            abi.encodeCall(
                IStreamArtistIdentityContest.contestArtistIdentity,
                (artistId, subject, evidence, reason)
            ),
            1,
            scope,
            oldHash,
            newHash
        );
        Dismissal.Cause memory cause = ingress.currentIdentityContestCause(artistId);
        require(
            cause.facts.kind == 1 && cause.facts.executedTransitionHash == subject
                && cause.facts.incumbent == address(artist) && cause.facts.enteredAt == when,
            "actual governance op33 captures the current executed head and actual incumbent"
        );
        if (crOriginal != 0) require(_crOriginal() == crOriginal, "original40 closure unchanged");
    }

    function closedOriginDismiss(bytes32 subject) external onlySelf returns (bytes32 record) {
        Dismissal.Request memory p = _dismissalRequest();
        record = _dismissalExecute(p, 1, 0);
        Dismissal.Record memory r = ingress.identityContestDismissalRecord(record);
        require(
            r.recordHash == record && r.incumbent == address(artist)
                && r.terms.expectedCauseHash == p.expectedCauseHash
                && ingress.identityContestCause(p.expectedCauseHash).facts.executedTransitionHash
                    == subject,
            "original dismissal is admitted against its own incumbent and executed transition"
        );
        if (crOriginal != 0) {
            require(_crOriginal() == crOriginal, "later dismissal keeps original40");
        }
    }

    function closedOriginNext(uint256 salt, bool returnOriginalSuccessor) external onlySelf {
        bytes32 parent = erTerminal;
        bytes32 stagedParent = ingress.lastArtistTransition(artistId);
        if (returnOriginalSuccessor) {
            rotationSafe = delegateSafe;
            rotationKeys = delegateKeys;
        } else {
            _newRotationSafe(salt);
        }
        erTerminal = _stageRotation(stagedParent);
        _executeTimedRotation(erTerminal);
        _adoptRotatedSafe();
        erWindow = ingress.rotationRecord(erTerminal).transition.postWindowEndsAt;
        V.Snapshot memory v = _snapshot(erTerminal);
        require(
            v.previousTransitionRecordHash == parent
                && v.previousCommitment == _snapshot(parent).commitment && v.operationId == 32
                && v.authorityClass == 3
                && ingress.rotationRecord(erTerminal).terms.expectedPreviousTransitionRecordHash
                    == stagedParent
                && ingress.currentAuthorityCapabilities(artistId).activationRecordHash == erOrigin
                && ingress.currentAuthorityCapabilities(artistId).effectiveCapabilities == erCaps
                && _crOriginal() == crOriginal,
            "actual writer chains the complete executed history independently of staged history"
        );
    }

    function closedOriginTerminalStanding(uint256 salt) external onlySelf {
        vm.warp(erWindow);
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
            "actual current successor Safe files a separate zero-reason terminal standing veto"
        );
        Dismissal.Cause memory cause = ingress.currentIdentityContestCause(artistId);
        require(
            cause.facts.kind == 2 && cause.facts.executedTransitionHash == erTerminal
                && cause.facts.pendingTransitionHash == pending && cause.facts.evidenceHash == 0
                && cause.facts.reasonHash == 0 && _crOriginal() == crOriginal,
            "terminal standing cause does not substitute for the original estate closure"
        );
    }

    function _crOriginal() private view returns (bytes32) {
        return keccak256(
            abi.encode(
                ingress.identityTransitionClosure(artistId, erOrigin),
                ingress.identityContestDismissalRecord(crDismissal),
                ingress.identityContestCause(crCause)
            )
        );
    }

    function _crRecover(uint256 salt, bool retry) private {
        (IdentityRecovery.Request memory p, T.Authorization memory a) = this.historyPrepare(salt);
        this.rotatedEstateRegister(p, a);
        this.rotatedEstateRecover(p, a, retry);
        require(_crOriginal() == crOriginal, "op35 preserves the full original40 closure bytes");
    }

    function testClosedOriginEarlyDismissalAdmitsDirectRotationBeforeOriginalWindow() public {
        this.closedOriginSetup(4095, true, false, 0);
        this.closedOriginNext(67002, false);
        require(
            ingress.rotationRecord(erTerminal).transition.stagedAt < crOriginWindow,
            "actual successor rotation stages before the abandoned original estate window ends"
        );
        this.closedOriginCompromise(erTerminal, erWindow);
        _crRecover(67003, true);
    }

    function closedOriginAcceleratedSetup() external onlySelf {
        erLiving = artist;
        erLivingKeys = keys;
        erCaps = 4095;
        _delegateSetup();
        address[] memory members = new address[](1);
        members[0] = address(artist);
        erGuardian = _guardianRecord(members, 1, 10 days, 900);
        Estate.Execution memory p = _estatePendingFixture(erCaps);
        erOrigin = p.expectedActivationRecordHash;
        this.executeEstateAccelerator(p, 1, 0);
        artist = delegateSafe;
        keys = delegateKeys;
        nextNonce = IStreamArtistIdentityOwner(suite.owners[2]).identity(artistId).nonceHint;
        erTerminal = erOrigin;
        (Estate.RequestRecord memory request,, Estate.ExecutionFacts memory x) =
            ingress.estateActivationRecord(erOrigin);
        require(
            x.executedAt < request.noticeEndsAt && x.governanceWitnessHash != 0,
            "actual original40 acceleration retains its admitted governance witness"
        );
        crOriginWindow = ingress.artistTransitionState(erOrigin).postWindowEndsAt;
        this.closedOriginCompromise(erOrigin, x.executedAt + 1);
        crCause = ingress.currentIdentityContestCause(artistId).causeHash;
        crDismissal = this.closedOriginDismiss(erOrigin);
        crOriginal = _crOriginal();
    }

    function testClosedAcceleratedOriginRetainsIntermediateGuardianAcrossThreeRotations() public {
        this.closedOriginAcceleratedSetup();
        this.closedOriginNext(67027, false);
        this.rotatedEstateGuardians();
        bytes32 originalRotation = erTerminal;
        this.historyWarp(erWindow);
        this.closedOriginNext(67028, false);
        this.historyWarp(erWindow);
        this.closedOriginNext(67029, false);
        this.closedOriginCompromise(erTerminal, erWindow);
        require(
            ingress.guardianSetRecord(erGuardian).provisional.transitionRecordHash
                == originalRotation,
            "complete guardian history retains the earlier successor's original record"
        );
        _crRecover(67030, true);
    }

    function testClosedOriginMatureClosureAndThreeRotationsRetainZeroCapabilities() public {
        this.closedOriginSetup(0, false, false, 0);
        this.closedOriginNext(67004, false);
        this.historyWarp(erWindow);
        this.closedOriginNext(67005, false);
        this.historyWarp(erWindow);
        this.closedOriginNext(67006, false);
        this.closedOriginCompromise(erTerminal, erWindow);
        _crRecover(67007, true);
        require(
            ingress.currentAuthorityCapabilities(artistId).effectiveCapabilities == 0,
            "closed origin and repeated rotations cannot increase original capabilities"
        );
    }

    function testClosedOriginStandingClosureKeepsDifferentStagedAndExecutedParents() public {
        this.closedOriginSetup(4095, false, true, 2);
        bytes32 pending = ingress.lastArtistTransition(artistId);
        this.closedOriginNext(67008, false);
        require(
            pending != erOrigin && _snapshot(erTerminal).previousTransitionRecordHash == erOrigin
                && ingress.rotationRecord(erTerminal).terms.expectedPreviousTransitionRecordHash
                    == pending,
            "first executed32 follows both actual original40 and dismissed pending32 histories"
        );
        this.historyWarp(erWindow);
        this.closedOriginNext(67009, false);
        this.historyWarp(erWindow);
        this.closedOriginNext(67010, false);
        this.closedOriginCompromise(erTerminal, erWindow);
        _crRecover(67011, true);
    }

    function testClosedOriginAndSeparateTerminalStandingClosureRemainIndependent() public {
        this.closedOriginSetup(4095, true, false, 0);
        this.closedOriginNext(67012, false);
        this.closedOriginTerminalStanding(67013);
        bytes32 terminalDismissal = this.closedOriginDismiss(erTerminal);
        require(
            terminalDismissal != crDismissal
                && ingress.identityTransitionClosure(artistId, erTerminal).dismissalRecordHash
                    == terminalDismissal
                && ingress.identityContestDismissalRecord(terminalDismissal).incumbent
                != ingress.identityContestDismissalRecord(crDismissal).incumbent,
            "both original closures retain distinct dismissal records and original incumbents"
        );
        this.closedOriginCompromise(erTerminal, erWindow + 1);
        _crRecover(67014, true);
    }

    function testClosedOriginRetainsOriginalLivingDismissalBoundary() public {
        this.closedOriginCompromise(bytes32(0), uint64(block.timestamp));
        crPriorDismissal = this.closedOriginDismiss(bytes32(0));
        ArtistUnitGovernance(manager.governanceAuthority())
            .configureContestReads(
                address(estateFixityRoles),
                address(this),
                keccak256("archival fixture"),
                "urn:unit:archival"
            );
        this.closedOriginSetup(4095, false, false, 1);
        Dismissal.Cause memory cause = ingress.identityContestCause(crCause);
        require(
            cause.facts.previousResolutionHash == crPriorDismissal
                && cause.facts.previousCauseHash
                    == ingress.identityContestDismissalRecord(crPriorDismissal).terms
                        .expectedCauseHash
                && ingress.identityContestDismissalRecord(crPriorDismissal).authorityClass == 1,
            "original40 cause binds nonzero admitted living resolution history"
        );
        this.closedOriginNext(67015, false);
        this.closedOriginCompromise(erTerminal, erWindow);
        (IdentityRecovery.Request memory p, T.Authorization memory a) = this.historyPrepare(67016);
        bytes32 context = keccak256(abi.encode(ingress.identityRecoveryContext(p, a)));
        _crCorruptRecord(p, a, crPriorDismissal, context);
        this.rotatedEstateRegister(p, a);
        this.rotatedEstateRecover(p, a, true);
    }

    function testClosedOriginReturnedSuccessorDoesNotReplaceOriginalClosure() public {
        this.closedOriginSetup(0, true, false, 0);
        this.closedOriginNext(67017, false);
        this.historyWarp(erWindow);
        this.closedOriginNext(0, true);
        require(address(artist) == address(delegateSafe), "original estate successor returns");
        this.historyWarp(erWindow);
        this.closedOriginNext(67018, false);
        this.closedOriginCompromise(erTerminal, erWindow);
        _crRecover(67019, false);
    }

    function _crReadSlot(bytes32 value) private returns (bytes32 slot) {
        (bytes32[] memory reads,) = ClosedEstateStorageVm(address(vm)).accesses(suite.owners[2]);
        uint256 found;
        for (uint256 i; i < reads.length; ++i) {
            if (vm.load(suite.owners[2], reads[i]) == value) {
                slot = reads[i];
                ++found;
            }
        }
        require(value != 0 && found == 1, "one observed original field; no guessed storage slot");
    }

    function _crRejected(IdentityRecovery.Request memory p, T.Authorization memory a) private {
        bytes32 roots = _roots();
        vm.expectRevert(
            abi.encodeWithSelector(
                IdentityRecovery.UnsupportedIdentityRecoveryProfile.selector, artistId
            )
        );
        ingress.identityRecoveryContext(p, a);
        (bool used,) = ingress.rotationAcceptanceNonceState(artistId, p.newAddress, a.nonce);
        require(!used && roots == _roots(), "failed context leaves acceptance and Archive intact");
    }

    function _crCorruptRecord(
        IdentityRecovery.Request memory p,
        T.Authorization memory a,
        bytes32 record,
        bytes32 context
    ) private {
        ClosedEstateStorageVm(address(vm)).record();
        bytes32 value = ingress.identityContestDismissalRecord(record).cohortHash;
        bytes32 slot = _crReadSlot(value);
        vm.store(suite.owners[2], slot, bytes32(uint256(value) ^ 1));
        _crRejected(p, a);
        vm.store(suite.owners[2], slot, value);
        require(
            keccak256(abi.encode(ingress.identityRecoveryContext(p, a))) == context,
            "exact original dismissal repair restores the identical request context"
        );
    }

    function testClosedOriginRejectsSubstitutionMissingClosureAndCauseDriftThenRetries() public {
        this.closedOriginSetup(4095, true, false, 0);
        this.closedOriginNext(67020, false);
        this.historyWarp(erWindow);
        this.closedOriginNext(67021, false);
        this.historyWarp(erWindow);
        this.closedOriginNext(67022, false);
        this.closedOriginTerminalStanding(67023);
        bytes32 foreign = this.closedOriginDismiss(erTerminal);
        this.closedOriginCompromise(erTerminal, erWindow + 1);
        (IdentityRecovery.Request memory p, T.Authorization memory a) = this.historyPrepare(67024);
        bytes32 context = keccak256(abi.encode(ingress.identityRecoveryContext(p, a)));
        ClosedEstateStorageVm(address(vm)).record();
        bytes32 original = ingress.identityTransitionClosure(artistId, erOrigin).dismissalRecordHash;
        bytes32 slot = _crReadSlot(original);
        vm.store(suite.owners[2], slot, foreign);
        _crRejected(p, a);
        vm.store(suite.owners[2], slot, bytes32(0));
        _crRejected(p, a);
        vm.store(suite.owners[2], slot, original);
        _crCorruptRecord(p, a, crDismissal, context);
        ClosedEstateStorageVm(address(vm)).record();
        bytes32 evidence = ingress.identityContestCause(crCause).facts.evidenceHash;
        slot = _crReadSlot(evidence);
        vm.store(suite.owners[2], slot, bytes32(uint256(evidence) ^ 1));
        _crRejected(p, a);
        vm.store(suite.owners[2], slot, evidence);
        require(
            _crOriginal() == crOriginal
                && keccak256(abi.encode(ingress.identityRecoveryContext(p, a))) == context,
            "full original cause and closure repair restores exact context after three rotations"
        );
        this.rotatedEstateRegister(p, a);
        this.rotatedEstateRecover(p, a, true);
    }

    function testClosedOriginCannotMatureAnEarlyUnresolvedTerminalCompromise() public {
        this.closedOriginSetup(4095, true, false, 0);
        this.closedOriginNext(67025, false);
        this.closedOriginCompromise(erTerminal, erWindow - 1);
        (IdentityRecovery.Request memory p, T.Authorization memory a) = this.historyPrepare(67026);
        _crRejected(p, a);
        this.historyWarp(erWindow + 1);
        _crRejected(p, a);
        require(_crOriginal() == crOriginal, "original closure cannot cure terminal abandonment");
    }

    function testClosedOriginRejectsChangedEpochAfterMultipleRotationsThenExactRetry() public {
        bytes32 grant = _grant(
            ClosedEstateDelegation.Grant(
                artistId,
                address(0xC0FEE),
                1,
                4,
                uint64(block.timestamp),
                uint64(block.timestamp + 400 days),
                5,
                keccak256("original epoch read fixture")
            )
        );
        this.closedOriginSetup(4095, false, false, 0);
        this.closedOriginNext(67031, false);
        this.historyWarp(erWindow);
        this.closedOriginNext(67032, false);
        this.closedOriginCompromise(erTerminal, erWindow);
        (IdentityRecovery.Request memory p, T.Authorization memory a) = this.historyPrepare(67033);
        bytes32 context = keccak256(abi.encode(ingress.identityRecoveryContext(p, a)));
        ClosedEstateStorageVm(address(vm)).record();
        (bool valid, uint64 recorded, uint64 current) =
            IStreamArtistEstateOwner(suite.owners[2]).delegationEpochState(grant);
        require(!valid && recorded == 0 && current == 1, "actual op40 incremented original epoch");
        bytes32 slot = _crReadSlot(bytes32(uint256(current)));
        vm.store(suite.owners[2], slot, bytes32(uint256(current) + 1));
        _crRejected(p, a);
        vm.store(suite.owners[2], slot, bytes32(uint256(current)));
        require(
            context == keccak256(abi.encode(ingress.identityRecoveryContext(p, a))),
            "restoring actual current epoch restores the identical registered request context"
        );
        this.rotatedEstateRegister(p, a);
        this.rotatedEstateRecover(p, a, true);
    }

    function testClosedOriginRetainsLowerNonceGuardianLifetimeVeto() public {
        this.closedOriginSetup(4095, true, false, 0);
        this.closedOriginNext(67034, false);
        this.rotatedEstateGuardians();
        this.closedOriginCompromise(erTerminal, erWindow);
        (IdentityRecovery.Request memory p, T.Authorization memory a) = this.historyPrepare(67035);
        this.rotatedEstateRegister(p, a);
        this.historyWarp(scheduled.notBefore);
        require(
            executeSafe(
                erVeto,
                erVetoKeys,
                address(ingress),
                0,
                abi.encodeCall(
                    IStreamArtistRecoveryAction.vetoIdentityRecovery,
                    (artistId, keccak256("closed original40 lifetime veto"))
                ),
                0
            ),
            "retained lower-nonce guardian Safe still vetoes actual registered recovery"
        );
        bytes32 roots = _roots();
        scheduled.status = GovernanceActionStatus.EXECUTED;
        _publish();
        vm.expectRevert(abi.encodeWithSelector(A.RecoveryActionVetoed.selector, currentId));
        this.executeRegistered(p, a);
        (bool used,) = ingress.rotationAcceptanceNonceState(artistId, p.newAddress, a.nonce);
        require(
            !used && roots == _roots() && _crOriginal() == crOriginal
                && ingress.latestIdentityRecovery(artistId) == 0,
            "lifetime veto preserves acceptance, original closures, authority and Archive"
        );
    }
}

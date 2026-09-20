// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./StreamArtistClosedRepeatedRecoveryActual.t.sol";
import {
    IStreamArtistIdentityDismissal
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistIdentityDismissal.sol";

/// @notice Actual op35 -> one or more two-sided op32 -> fresh registered op35 histories.
/// @dev Actual Artist, threshold Safes and Archive; inherited typed Core/governance and
/// aggregate CREATE boundaries remain explicit. Run testRotatedRepeat* for this focused host.
contract StreamArtistRotatedRepeatedRecoveryActualTest is
    StreamArtistClosedRepeatedRecoveryActualTest
{
    bytes32 private rtPrior;
    bytes32 private rtTerminal;
    bytes32 private rtPermanent;
    bytes32 private rtIntermediate;
    bytes32 private rtOriginals;
    bytes32 private rtFirstClosure;
    bytes32 private rtLatestClosure;
    bytes32 private rtStanding;
    uint64 private rtEpoch;
    Estate.AuthorityCapabilities private rtCapabilities;
    bytes32[] private rtRotations;

    function rotatedRepeatSetup(bool estate, bool closed) external onlySelf {
        if (closed) {
            this.closedRepeatSetup(estate, true);
            this.closedRepeatFreshGuardian();
        } else {
            this.repeatedRecoverySetup(estate);
        }
        rtPrior = ingress.latestIdentityRecovery(artistId);
        rtTerminal = rtPrior;
        IdentityRecovery.Record memory prior = ingress.identityRecoveryRecord(rtPrior);
        rtPermanent = prior.terms.supersededRecordHashes[0];
        rtEpoch = prior.delegationEpoch;
        rtCapabilities = ingress.currentAuthorityCapabilities(artistId);
        require(
            prior.fields.newAddress == address(artist) && _snapshot(rtPrior).operationId == 35
                && _status(rtPermanent).recoveryRecordHash == rtPrior,
            "original executed recovery and permanent exclusion, not a fabricated head"
        );
        if (closed) {
            Dismissal.Closure memory c = ingress.identityTransitionClosure(artistId, rtPrior);
            require(c.dismissalRecordHash != 0 && c.abandoned, "original op35 closed early");
        }
    }

    function rotatedRepeatNext(uint256 salt, bool returnPriorOld) external onlySelf {
        bytes32 previousExecution = rtTerminal;
        R.TransitionState memory previous = ingress.artistTransitionState(previousExecution);
        if (ingress.identityTransitionClosure(artistId, previousExecution).dismissalRecordHash == 0)
        {
            if (block.timestamp < previous.postWindowEndsAt) vm.warp(previous.postWindowEndsAt);
        }
        if (returnPriorOld) {
            // The actual living bootstrap retires its second Safe, salt 63002, in op35.
            // Its original keys sign the new acceptance; an address-only substitution cannot pass.
            rotationSafe =
                OfficialSafe(payable(ingress.identityRecoveryRecord(rtPrior).fields.oldAddress));
            rotationKeys = new uint256[](2);
            rotationKeys[0] = 0xCA1100 + 63002;
            rotationKeys[1] = 0xCA2200 + 63002;
        } else {
            _newRotationSafe(salt);
        }
        bytes32 previousStaging = ingress.lastArtistTransition(artistId);
        bytes32 next = _stageRotation(previousStaging);
        _executeTimedRotation(next);
        _adoptRotatedSafe();
        rtTerminal = next;
        rtRotations.push(next);
        V.Snapshot memory v = _snapshot(next);
        require(
            v.operationId == 32 && v.authorityClass == rtCapabilities.authorityClass
                && v.previousTransitionRecordHash == previousExecution
                && v.previousCommitment == _snapshot(previousExecution).commitment
                && v.newAddress == address(artist)
                && ingress.rotationRecord(next).terms.expectedPreviousTransitionRecordHash
                    == previousStaging && ingress.latestIdentityRecovery(artistId) == rtPrior
                && ingress.identityRecoveryRecord(rtPrior).delegationEpoch == rtEpoch,
            "legitimate op32 extends executed history without replacing original recovery"
        );
        Estate.AuthorityCapabilities memory caps = ingress.currentAuthorityCapabilities(artistId);
        require(
            caps.activationRecordHash == rtCapabilities.activationRecordHash
                && caps.effectiveCapabilities == rtCapabilities.effectiveCapabilities,
            "rotation preserves original authority origin and capabilities"
        );
    }

    function rotatedRepeatGuardian() external onlySelf {
        address[] memory members = new address[](1);
        members[0] = address(artist);
        rtIntermediate = _guardianRecord(members, 1, 15 days, nextNonce + 100);
        require(
            ingress.guardianSetRecord(rtIntermediate).provisional.transitionRecordHash
                == rtTerminal,
            "actual intermediate principal writes its own original guardian cohort"
        );
    }

    function rotatedRepeatCompromise(uint64 when) external onlySelf {
        vm.warp(when);
        ArtistAppealUnitRoles(suite.roleRegistry).setArbiter(address(artist), true);
        ArtistUnitGovernance authority = ArtistUnitGovernance(manager.governanceAuthority());
        bytes32 evidence = keccak256(abi.encode("rotated repeat compromise", rtTerminal, when));
        bytes32 reason = keccak256(abi.encode("rotated repeat reason", rtTerminal, when));
        authority.configureContestReads(
            suite.roleRegistry, address(artist), reason, "urn:unit:rotated-repeat"
        );
        (bytes32 scope, bytes32 oldHash, bytes32 newHash) =
            ingress.identityContestGovernanceContext(artistId, rtTerminal, evidence, reason);
        authority.executeModuleContext(
            address(ingress),
            abi.encodeCall(
                IStreamArtistIdentityContest.contestArtistIdentity,
                (artistId, rtTerminal, evidence, reason)
            ),
            1,
            scope,
            oldHash,
            newHash
        );
        Dismissal.Cause memory cause = ingress.currentIdentityContestCause(artistId);
        require(
            cause.facts.kind == 1 && cause.facts.executedTransitionHash == rtTerminal
                && cause.facts.incumbent == address(artist)
                && cause.facts.authorityClass == rtCapabilities.authorityClass
                && ingress.latestIdentityRecovery(artistId) == rtPrior,
            "fresh actual compromise names terminal rotation, not prior recovery"
        );
    }

    function rotatedRepeatStanding(uint256 salt) external onlySelf {
        vm.warp(ingress.artistTransitionState(rtTerminal).postWindowEndsAt);
        _newRotationSafe(salt);
        rtStanding = _stageRotation(ingress.lastArtistTransition(artistId));
        require(
            executeSafe(
                artist,
                keys,
                address(ingress),
                0,
                abi.encodeCall(
                    IStreamArtistRotation.vetoArtistRotation, (artistId, rtStanding, bytes32(0))
                ),
                0
            ),
            "actual incumbent Safe vetoes its pending successor"
        );
        Dismissal.Cause memory cause = ingress.currentIdentityContestCause(artistId);
        require(
            cause.facts.kind == 2 && cause.facts.pendingTransitionHash == rtStanding
                && cause.facts.executedTransitionHash == rtTerminal
                && ingress.rotationRecord(rtStanding).transition.phase == 3,
            "standing cause preserves separate pending and executed parents"
        );
    }

    function rotatedRepeatDismiss() external onlySelf {
        rtLatestClosure = _dismissalExecute(_dismissalRequest(), 1, 0);
        if (rtFirstClosure == 0) rtFirstClosure = rtLatestClosure;
        Dismissal.Closure memory closed = ingress.identityTransitionClosure(artistId, rtTerminal);
        require(
            closed.dismissalRecordHash == rtFirstClosure
                && ingress.identityContestDismissalRecord(rtLatestClosure).incumbent
                    == address(artist),
            "actual dismissal restores the same principal and keeps first terminal closure"
        );
    }

    function rotatedRepeatTerms(uint256 salt)
        external
        onlySelf
        returns (IdentityRecovery.Request memory p, T.Authorization memory a)
    {
        _newRotationSafe(salt);
        Dismissal.Cause memory cause = ingress.currentIdentityContestCause(artistId);
        p = IdentityRecovery.Request(
            artistId,
            address(rotationSafe),
            rtCapabilities.authorityClass,
            cause.causeHash,
            ingress.latestIdentityContestDismissal(artistId),
            cause.facts.evidenceHash,
            cause.facts.reasonHash,
            new bytes32[](0)
        );
        a = _acceptance(p);
    }

    function _rtHistory() private view returns (bytes32 history) {
        (bytes32 primary, bytes32 occurrence, bytes32 secondary) =
            IStreamArtistIdentityRecoveryOwner(suite.owners[2]).identityRecoveryReceipts(rtPrior);
        history = keccak256(
            abi.encode(
                ingress.identityRecoveryRecord(rtPrior),
                _snapshot(rtPrior),
                ingress.artistTransitionState(rtPrior),
                primary,
                occurrence,
                secondary,
                ingress.identityTransitionClosure(artistId, rtPrior),
                _status(rtPermanent),
                ingress.guardianSetRecord(rtIntermediate),
                ingress.rotationRecord(rtStanding),
                ingress.identityContestDismissalRecord(rtFirstClosure),
                ingress.identityContestDismissalRecord(rtLatestClosure)
            )
        );
        for (uint256 i; i < rtRotations.length; ++i) {
            bytes32 r = rtRotations[i];
            history = keccak256(
                abi.encode(
                    history,
                    ingress.rotationRecord(r),
                    _snapshot(r),
                    ingress.identityTransitionClosure(artistId, r)
                )
            );
        }
    }

    function rotatedRepeatRegister(IdentityRecovery.Request calldata p, T.Authorization calldata a)
        external
        onlySelf
    {
        IdentityRecovery.Context memory c = ingress.identityRecoveryContext(p, a);
        require(
            c.delegationEpoch == rtEpoch && c.incumbent == address(artist),
            "unchanged original epoch and current authority"
        );
        GovernanceCall[] memory calls = _schedule(
            keccak256(abi.encode("rotated repeat original action", rtPrior, rtTerminal)), p, a
        );
        ingress.registerIdentityRecoveryAction(currentId, calls, p, a);
        rtOriginals = _rtHistory();
    }

    function rotatedRepeatExecute(
        IdentityRecovery.Request calldata p,
        T.Authorization calldata a,
        bool retry
    ) external onlySelf {
        T.Snapshot memory before_ = _ownerSnapshot();
        address incumbent = address(artist);
        vm.warp(scheduled.notBefore);
        scheduled.status = GovernanceActionStatus.EXECUTED;
        _publish();
        if (retry) {
            bytes32 roots = _roots();
            _overflow();
            this.executeRegistered(p, a);
            _inactive();
            (bool used,) = ingress.rotationAcceptanceNonceState(artistId, p.newAddress, a.nonce);
            require(
                !used && roots == _roots() && rtOriginals == _rtHistory()
                    && ingress.latestIdentityRecovery(artistId) == rtPrior,
                "late Archive failure restores exact authority, history, roots and acceptance"
            );
            vm.roll(restoreBlock);
        }
        vm.recordLogs();
        bytes32 record = this.executeRegistered(p, a);
        V.Snapshot memory v = _snapshot(record);
        _assertSnapshot(v, 35, before_, vm.getRecordedLogs());
        Estate.AuthorityCapabilities memory caps = ingress.currentAuthorityCapabilities(artistId);
        (bool used,) = ingress.rotationAcceptanceNonceState(artistId, p.newAddress, a.nonce);
        (bytes32 primary, bytes32 occurrence, bytes32 secondary) =
            IStreamArtistIdentityRecoveryOwner(suite.owners[2]).identityRecoveryReceipts(record);
        require(
            record != rtPrior
                && ingress.identityRecoveryRecord(record).delegationEpoch == rtEpoch + 1
                && v.previousTransitionRecordHash == rtTerminal
                && v.previousCommitment == _snapshot(rtTerminal).commitment
                && v.oldAddress == incumbent && v.newAddress == p.newAddress
                && caps.authorityClass == rtCapabilities.authorityClass
                && caps.effectiveCapabilities == rtCapabilities.effectiveCapabilities
                && caps.activationRecordHash == rtCapabilities.activationRecordHash
                && caps.authorityAddress == p.newAddress && caps.status == caps.authorityClass
                && _rtHistory() == rtOriginals && used && primary != 0 && occurrence != 0
                && secondary != 0 && primary != secondary,
            "fresh recovery chains terminal32 and preserves original35 evidence and authority origin"
        );
        bytes32 roots = _roots();
        vm.expectRevert(
            abi.encodeWithSelector(IdentityRecovery.InvalidIdentityRecovery.selector, artistId)
        );
        this.executeRegistered(p, a);
        require(
            roots == _roots() && _rtHistory() == rtOriginals,
            "same action and acceptance stay consumed"
        );
    }

    function _rtFinish(uint256 salt, bool retry) private {
        this.rotatedRepeatCompromise(ingress.artistTransitionState(rtTerminal).postWindowEndsAt);
        (IdentityRecovery.Request memory p, T.Authorization memory a) =
            this.rotatedRepeatTerms(salt);
        this.rotatedRepeatRegister(p, a);
        this.rotatedRepeatExecute(p, a, retry);
    }

    function testRotatedRepeatLivingSingleRotationAndArchiveRetry() public {
        this.rotatedRepeatSetup(false, false);
        this.rotatedRepeatNext(71001, false);
        _rtFinish(71002, true);
    }

    function testRotatedRepeatEstateMultipleRotationsRetainIntermediateGuardian() public {
        this.rotatedRepeatSetup(true, false);
        this.rotatedRepeatNext(71011, false);
        this.rotatedRepeatGuardian();
        bytes32 cohort = rtTerminal;
        this.rotatedRepeatNext(71012, false);
        this.rotatedRepeatNext(71013, false);
        (,,, bytes32 selected) = ingress.guardianSet(artistId);
        require(
            selected == rtIntermediate
                && ingress.guardianSetRecord(selected).provisional.transitionRecordHash == cohort,
            "intermediate guardian remains operative after later actual rotations"
        );
        _rtFinish(71014, true);
    }

    function testRotatedRepeatLivingOriginalClosedRecoveryBeforeRotation() public {
        this.rotatedRepeatSetup(false, true);
        this.rotatedRepeatNext(71021, false);
        _rtFinish(71022, true);
    }

    function testRotatedRepeatEstateOriginalClosedRecoveryBeforeMultipleRotations() public {
        this.rotatedRepeatSetup(true, true);
        this.rotatedRepeatNext(71031, false);
        this.rotatedRepeatNext(71032, false);
        _rtFinish(71033, false);
    }

    function testRotatedRepeatRetiredPriorAddressReturnsThenRotatesAgain() public {
        this.rotatedRepeatSetup(false, false);
        this.rotatedRepeatNext(71041, false);
        this.rotatedRepeatNext(0, true);
        require(
            address(artist) == ingress.identityRecoveryRecord(rtPrior).fields.oldAddress,
            "original pre-recovery retired Safe returns through two-sided acceptance"
        );
        this.rotatedRepeatNext(71042, false);
        _rtFinish(71043, true);
    }

    function testRotatedRepeatTerminalStandingDismissalThenFreshCompromise() public {
        this.rotatedRepeatSetup(false, false);
        this.rotatedRepeatNext(71051, false);
        this.rotatedRepeatStanding(71052);
        this.rotatedRepeatDismiss();
        require(
            ingress.lastArtistTransition(artistId) == rtStanding && rtStanding != rtTerminal,
            "dismissed pending head remains distinct from executed terminal"
        );
        this.rotatedRepeatCompromise(uint64(block.timestamp + 1));
        (IdentityRecovery.Request memory p, T.Authorization memory a) =
            this.rotatedRepeatTerms(71053);
        this.rotatedRepeatRegister(p, a);
        this.rotatedRepeatExecute(p, a, true);
    }

    function testRotatedRepeatOriginalLowerNonceLifetimeSafeStillVetoes() public {
        this.rotatedRepeatSetup(false, false);
        this.rotatedRepeatNext(71061, false);
        this.rotatedRepeatNext(71062, false);
        this.rotatedRepeatCompromise(ingress.artistTransitionState(rtTerminal).postWindowEndsAt);
        (IdentityRecovery.Request memory p, T.Authorization memory a) =
            this.rotatedRepeatTerms(71063);
        this.rotatedRepeatRegister(p, a);
        vm.warp(scheduled.notBefore);
        this.vetoByGuardian(keccak256("original lifetime veto after recovered rotations"));
        bytes32 roots = _roots();
        scheduled.status = GovernanceActionStatus.EXECUTED;
        _publish();
        vm.expectRevert(abi.encodeWithSelector(A.RecoveryActionVetoed.selector, currentId));
        this.executeRegistered(p, a);
        _inactive();
        (bool used,) = ingress.rotationAcceptanceNonceState(artistId, p.newAddress, a.nonce);
        require(
            !used && _roots() == roots && _rtHistory() == rtOriginals
                && ingress.latestIdentityRecovery(artistId) == rtPrior,
            "original lifetime veto preserves authority, history, replay and receipts"
        );
    }

    function testRotatedRepeatEarlyTerminalCompromiseNeverMaturesByWaiting() public {
        this.rotatedRepeatSetup(false, false);
        this.rotatedRepeatNext(71071, false);
        uint64 ends = ingress.artistTransitionState(rtTerminal).postWindowEndsAt;
        this.rotatedRepeatCompromise(ends - 1);
        (IdentityRecovery.Request memory p, T.Authorization memory a) =
            this.rotatedRepeatTerms(71072);
        bytes32 original = _rtHistory();
        vm.expectRevert();
        ingress.identityRecoveryContext(p, a);
        vm.warp(ends + 1);
        vm.expectRevert();
        ingress.identityRecoveryContext(p, a);
        (bool used,) = ingress.rotationAcceptanceNonceState(artistId, p.newAddress, a.nonce);
        require(
            !used && original == _rtHistory()
                && ingress.latestIdentityRecovery(artistId) == rtPrior,
            "waiting cannot repair the same contested terminal cohort"
        );
    }

    function _rtSlot(bytes memory getter, bytes32 original, bool addressOnly)
        private
        returns (bytes32 slot)
    {
        ClosedEstateStorageVm probe = ClosedEstateStorageVm(address(vm));
        probe.record();
        (bool ok,) = suite.owners[2].staticcall(getter);
        require(ok, "actual original getter succeeds");
        (bytes32[] memory reads,) = probe.accesses(suite.owners[2]);
        uint256 matches;
        for (uint256 i; i < reads.length; ++i) {
            bytes32 value = vm.load(suite.owners[2], reads[i]);
            if (addressOnly) value = bytes32(uint256(uint160(uint256(value))));
            if (value == original) {
                slot = reads[i];
                ++matches;
            }
        }
        require(original != 0 && matches == 1, "unique observed original field; no guessed slot");
    }

    function _rtCorrupt(
        IdentityRecovery.Request memory p,
        T.Authorization memory a,
        bytes32 slot,
        bytes32 replacement,
        bytes32 context
    ) private {
        bytes32 original = vm.load(suite.owners[2], slot);
        bytes32 roots = _roots();
        bytes32 history = _rtHistory();
        vm.store(suite.owners[2], slot, replacement);
        (bool ok,) =
            address(ingress).staticcall(abi.encodeCall(ingress.identityRecoveryContext, (p, a)));
        require(!ok, "altered original evidence must reject the same signed request");
        (bool used,) = ingress.rotationAcceptanceNonceState(artistId, p.newAddress, a.nonce);
        require(!used && roots == _roots(), "rejection cannot consume replay or Archive state");
        vm.store(suite.owners[2], slot, original);
        require(
            history == _rtHistory()
                && context == keccak256(abi.encode(ingress.identityRecoveryContext(p, a))),
            "restored original bytes admit the identical current request and signature"
        );
    }

    function _rtCorruptHash(
        IdentityRecovery.Request memory p,
        T.Authorization memory a,
        bytes memory getter,
        bytes32 value,
        bytes32 context
    ) private {
        _rtCorrupt(p, a, _rtSlot(getter, value, false), bytes32(uint256(value) ^ 1), context);
    }

    function testRotatedRepeatRejectsOriginParentHeadPrincipalAndGuardianPrefixThenRetries()
        public
    {
        this.rotatedRepeatSetup(true, false);
        this.rotatedRepeatNext(71081, false);
        this.rotatedRepeatGuardian();
        this.rotatedRepeatNext(71082, false);
        this.rotatedRepeatCompromise(ingress.artistTransitionState(rtTerminal).postWindowEndsAt);
        (IdentityRecovery.Request memory p, T.Authorization memory a) =
            this.rotatedRepeatTerms(71083);
        bytes32 context = keccak256(abi.encode(ingress.identityRecoveryContext(p, a)));
        bytes memory originRead = abi.encodeCall(
            IStreamArtistGuardianVestingHistory.guardianVestingSnapshot, (artistId, rtPrior)
        );
        _rtCorruptHash(p, a, originRead, _snapshot(rtPrior).commitment, context);
        _rtCorruptHash(p, a, originRead, _snapshot(rtPrior).guardians.commitment, context);
        _rtCorruptHash(
            p,
            a,
            abi.encodeCall(IStreamArtistIdentityRecoveryOwner.identityRecoveryRecord, (rtPrior)),
            ingress.identityRecoveryRecord(rtPrior).contextHash,
            context
        );
        _rtCorruptHash(
            p,
            a,
            abi.encodeCall(
                IStreamArtistGuardianVestingHistory.guardianVestingSnapshot, (artistId, rtTerminal)
            ),
            _snapshot(rtTerminal).previousCommitment,
            context
        );
        _rtCorruptHash(
            p,
            a,
            abi.encodeCall(IStreamArtistRotationReads.lastArtistTransition, (artistId)),
            rtTerminal,
            context
        );
        _rtCorruptHash(
            p,
            a,
            abi.encodeCall(IStreamArtistIdentityRecoveryOwner.latestIdentityRecovery, (artistId)),
            rtPrior,
            context
        );
        bytes32 principalSlot = _rtSlot(
            abi.encodeCall(IStreamArtistIdentityOwner.identity, (artistId)),
            bytes32(uint256(uint160(address(artist)))),
            true
        );
        _rtCorrupt(
            p,
            a,
            principalSlot,
            bytes32(uint256(vm.load(suite.owners[2], principalSlot)) ^ 1),
            context
        );
        this.rotatedRepeatRegister(p, a);
        this.rotatedRepeatExecute(p, a, true);
    }

    function testRotatedRepeatRejectsOriginalClosureRemovalThenIdenticalRetry() public {
        this.rotatedRepeatSetup(false, true);
        this.rotatedRepeatNext(71091, false);
        this.rotatedRepeatCompromise(ingress.artistTransitionState(rtTerminal).postWindowEndsAt);
        (IdentityRecovery.Request memory p, T.Authorization memory a) =
            this.rotatedRepeatTerms(71092);
        bytes32 context = keccak256(abi.encode(ingress.identityRecoveryContext(p, a)));
        bytes32 first = ingress.identityTransitionClosure(artistId, rtPrior).dismissalRecordHash;
        bytes32 slot = _rtSlot(
            abi.encodeCall(
                IStreamArtistIdentityDismissal.identityTransitionClosure, (artistId, rtPrior)
            ),
            first,
            false
        );
        _rtCorrupt(p, a, slot, bytes32(0), context);
        this.rotatedRepeatRegister(p, a);
        this.rotatedRepeatExecute(p, a, true);
    }

    function testRotatedRepeatTerminalOriginalClosureCannotBecomeLaterDismissal() public {
        this.rotatedRepeatSetup(true, false);
        this.rotatedRepeatNext(71101, false);
        this.rotatedRepeatStanding(71102);
        this.rotatedRepeatDismiss();
        this.rotatedRepeatCompromise(uint64(block.timestamp + 1));
        this.rotatedRepeatDismiss();
        this.rotatedRepeatCompromise(uint64(block.timestamp + 1));
        require(rtFirstClosure != rtLatestClosure, "independent second terminal resolution");
        (IdentityRecovery.Request memory p, T.Authorization memory a) =
            this.rotatedRepeatTerms(71103);
        bytes32 context = keccak256(abi.encode(ingress.identityRecoveryContext(p, a)));
        bytes32 slot = _rtSlot(
            abi.encodeCall(
                IStreamArtistIdentityDismissal.identityTransitionClosure, (artistId, rtTerminal)
            ),
            rtFirstClosure,
            false
        );
        _rtCorrupt(p, a, slot, rtLatestClosure, context);
        _rtCorrupt(p, a, slot, bytes32(0), context);
        this.rotatedRepeatRegister(p, a);
        this.rotatedRepeatExecute(p, a, true);
    }

    function rotatedRepeatAdopt() external onlySelf {
        _adoptRotatedSafe();
        rtPrior = ingress.latestIdentityRecovery(artistId);
        rtTerminal = rtPrior;
        rtEpoch = ingress.identityRecoveryRecord(rtPrior).delegationEpoch;
        rtCapabilities = ingress.currentAuthorityCapabilities(artistId);
        delete rtRotations;
    }

    function testRotatedRepeatInterveningActual35RejectsStaleOriginAndAdmitsNewest35() public {
        this.rotatedRepeatSetup(false, false);
        bytes32 stale = rtPrior;
        this.rotatedRepeatNext(71111, false);
        _rtFinish(71112, false);
        this.rotatedRepeatAdopt();
        require(
            rtPrior != stale
                && rtEpoch == ingress.identityRecoveryRecord(stale).delegationEpoch + 1,
            "intervening actual recovery advances the original epoch"
        );
        this.rotatedRepeatNext(71113, false);
        this.rotatedRepeatCompromise(ingress.artistTransitionState(rtTerminal).postWindowEndsAt);
        (IdentityRecovery.Request memory p, T.Authorization memory a) =
            this.rotatedRepeatTerms(71114);
        bytes32 context = keccak256(abi.encode(ingress.identityRecoveryContext(p, a)));
        bytes32 slot = _rtSlot(
            abi.encodeCall(IStreamArtistIdentityRecoveryOwner.latestIdentityRecovery, (artistId)),
            rtPrior,
            false
        );
        _rtCorrupt(p, a, slot, stale, context);
        this.rotatedRepeatRegister(p, a);
        this.rotatedRepeatExecute(p, a, true);
    }

    function _rtCurrentEpochSlot(bytes32 grant) private returns (bytes32 slot) {
        ClosedEstateStorageVm probe = ClosedEstateStorageVm(address(vm));
        probe.record();
        (bool valid, uint64 recorded, uint64 current) =
            IStreamArtistEstateOwner(suite.owners[2]).delegationEpochState(grant);
        require(
            valid && recorded == rtEpoch && current == rtEpoch,
            "actual post35 grant witnesses current epoch"
        );
        (bytes32[] memory reads,) = probe.accesses(suite.owners[2]);
        uint256 matches;
        for (uint256 i; i < reads.length; ++i) {
            bytes32 original = vm.load(suite.owners[2], reads[i]);
            if (original != bytes32(uint256(current))) continue;
            vm.store(suite.owners[2], reads[i], bytes32(uint256(current) + 1));
            (, uint64 afterRecorded, uint64 afterCurrent) =
                IStreamArtistEstateOwner(suite.owners[2]).delegationEpochState(grant);
            vm.store(suite.owners[2], reads[i], original);
            if (afterRecorded == recorded && afterCurrent == current + 1) {
                slot = reads[i];
                ++matches;
            }
        }
        require(matches == 1, "current epoch isolated from immutable grant epoch by actual getter");
    }

    function _rtRejectModeledEpochAdvance(uint16 operation) private {
        this.rotatedRepeatSetup(false, false);
        bytes32 grant = _grant(_delegation(1, 1, 0, type(uint64).max, 3));
        this.rotatedRepeatNext(71200 + operation, false);
        this.rotatedRepeatCompromise(ingress.artistTransitionState(rtTerminal).postWindowEndsAt);
        (IdentityRecovery.Request memory p, T.Authorization memory a) =
            this.rotatedRepeatTerms(71300 + operation);
        bytes32 context = keccak256(abi.encode(ingress.identityRecoveryContext(p, a)));
        _rtCorrupt(p, a, _rtCurrentEpochSlot(grant), bytes32(uint256(rtEpoch) + 1), context);
        this.rotatedRepeatRegister(p, a);
        this.rotatedRepeatExecute(p, a, false);
    }

    /// @dev Storage fault isolates op40's epoch effect; this does not execute an intervening op40.
    function testRotatedRepeatRejectsModeled40EpochAdvanceWithUnchangedRecoveryOrigin() public {
        _rtRejectModeledEpochAdvance(40);
    }

    /// @dev Storage fault isolates op43's epoch effect; actual op43 composition remains separate.
    function testRotatedRepeatRejectsModeled43EpochAdvanceWithUnchangedRecoveryOrigin() public {
        _rtRejectModeledEpochAdvance(43);
    }

    function _rtLegacyPriorHash(IdentityRecovery.Record memory prior)
        private
        view
        returns (bytes32)
    {
        (A.Association memory association,,,) = ingress.identityRecoveryActionState(
            artistId, prior.fields.governanceActionId
        );
        (bytes32 primary, bytes32 occurrence, bytes32 secondary) = IStreamArtistIdentityRecoveryOwner(
                suite.owners[2]
            ).identityRecoveryReceipts(prior.recordHash);
        return keccak256(
            abi.encode(
                keccak256("6529STREAM_ARTIST_ADMITTED_PRIOR_RECOVERY_V1"),
                prior,
                _snapshot(prior.recordHash),
                association,
                association.guardian.recordHash,
                primary,
                occurrence,
                secondary
            )
        );
    }

    function _rtAssertLegacyContext(
        IdentityRecovery.Request memory p,
        T.Authorization memory a,
        bytes32 closureProof
    ) private view {
        // Rebuild only the original context preimages from public original facts;
        // no production admission helper or copied historical verifier is called.
        bytes32 priorHash = ingress.latestIdentityRecovery(artistId);
        IdentityRecovery.Context memory c = ingress.identityRecoveryContext(p, a);
        Dismissal.Cause memory cause = ingress.currentIdentityContestCause(artistId);
        IdentityRecovery.Record memory prior = ingress.identityRecoveryRecord(priorHash);
        (GH.Head memory head,,,) = IStreamArtistGuardianHistory(suite.owners[2])
            .guardianHistoryState(artistId, 0, address(0), 0);
        (,,, bytes32 selected) = ingress.guardianSet(artistId);
        bytes32 scope = keccak256(
            abi.encode(
                keccak256("6529STREAM_ARTIST_IDENTITY_RECOVERY_SCOPE_V2"),
                block.chainid,
                address(ingress),
                suite.owners[2],
                artistId
            )
        );
        bytes32 oldHash = keccak256(
            abi.encode(
                keccak256("6529STREAM_ARTIST_REPEAT_RECOVERY_STATE_V1"),
                scope,
                cause,
                ingress.identityContestRecord(cause.facts.referenceHash),
                IStreamArtistIdentityOwner(suite.owners[2]).identity(artistId),
                _rtLegacyPriorHash(prior),
                ingress.artistTransitionState(priorHash),
                head,
                ingress.guardianSetRecord(selected),
                ingress.currentAuthorityCapabilities(artistId),
                p.expectedResolutionHash,
                c.postContestSeconds,
                c.standingTailSeconds,
                c.timingRevision,
                c.delegationEpoch,
                bytes32(0)
            )
        );
        if (closureProof != 0) {
            oldHash = keccak256(
                abi.encode(
                    keccak256("6529STREAM_ARTIST_CLOSED_REPEAT_RECOVERY_STATE_V1"),
                    oldHash,
                    closureProof
                )
            );
        }
        bytes32 newHash = keccak256(
            abi.encode(
                keccak256("6529STREAM_ARTIST_IDENTITY_RECOVERY_INTENT_V2"),
                scope,
                oldHash,
                p,
                a.nonce,
                a.time
            )
        );
        require(
            c.scopeHash == scope && c.oldValueHash == oldHash && c.newValueHash == newHash,
            "original repeat context keeps its exact immediate or closed preimage"
        );
    }

    function _rtLegacyDismissalProof(bytes32 record) private view returns (bytes32) {
        Dismissal.Record memory r = ingress.identityContestDismissalRecord(record);
        Dismissal.Cause memory cause = ingress.identityContestCause(r.terms.expectedCauseHash);
        return
            keccak256(
                abi.encode(r, cause, ingress.identityContestRecord(cause.facts.referenceHash))
            );
    }

    function testRotatedRepeatLegacyImmediateContextKeepsOriginalHashBytes() public {
        this.repeatedRecoverySetup(false);
        bytes32 priorHash = ingress.latestIdentityRecovery(artistId);
        this.repeatedRecoveryGuardian();
        this.repeatedRecoveryCompromise(ingress.artistTransitionState(priorHash).postWindowEndsAt);
        (IdentityRecovery.Request memory p, T.Authorization memory a) =
            this.repeatedRecoveryTerms(false, 71131);
        _rtAssertLegacyContext(p, a, bytes32(0));
        this.repeatedRecoveryRegister(p, a);
        this.repeatedRecoveryExecute(p, a, true);
    }

    function testRotatedRepeatLegacyClosedImmediateContextKeepsOriginalHashBytes() public {
        this.closedRepeatSetup(true, true);
        this.closedRepeatFreshGuardian();
        this.closedRepeatCompromise(uint64(block.timestamp + 1));
        (IdentityRecovery.Request memory p, T.Authorization memory a) =
            this.closedRepeatTerms(false, 71141);
        Dismissal.Closure memory closed =
            ingress.identityTransitionClosure(artistId, ingress.latestIdentityRecovery(artistId));
        require(
            closed.abandoned && closed.dismissalRecordHash != 0, "actual original early closure"
        );
        bytes32 proof = keccak256(
            abi.encode(
                keccak256("6529STREAM_ARTIST_ADMITTED_RECOVERY_CLOSURE_V1"),
                closed,
                _rtLegacyDismissalProof(closed.dismissalRecordHash),
                _rtLegacyDismissalProof(p.expectedResolutionHash)
            )
        );
        _rtAssertLegacyContext(p, a, proof);
        this.closedRepeatRegister(p, a);
        this.closedRepeatExecute(p, a, true);
    }
}

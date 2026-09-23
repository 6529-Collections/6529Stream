// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./StreamArtistEstateRotatedRecoveryActual.t.sol";

/// @notice Successive estate rotations and permanently closed historical cohorts.
/// @dev Actual Artist/Safe/Archive; typed unit Core/governance and aggregate CREATE boundaries.
contract StreamArtistEstateHistoryBatchActualTest is StreamArtistEstateRotatedRecoveryActualTest {
    bytes32 private hbFirst;
    bytes32 private hbLatest;
    bytes32 private hbAbandoned;
    bytes32 private hbAbandonedBytes;

    function historyBatchCompromise(uint64 when) external onlySelf {
        uint64 originalMarker = ingress.rotationRecord(erTerminal).transition.contestedAt;
        Dismissal.Closure memory closed = ingress.identityTransitionClosure(artistId, erTerminal);
        vm.warp(when);
        ArtistUnitGovernance authority = ArtistUnitGovernance(manager.governanceAuthority());
        ArtistUnitRoles(suite.roleRegistry).setArbiter(address(artist), true);
        bytes32 evidence = keccak256(abi.encode("estate batch compromise", erTerminal, when));
        bytes32 reason = keccak256(abi.encode("estate batch reason", erTerminal, when));
        authority.configureContestReads(
            suite.roleRegistry, address(artist), reason, "urn:unit:estate-batch"
        );
        (bytes32 scope, bytes32 oldHash, bytes32 newHash) =
            ingress.identityContestGovernanceContext(artistId, erTerminal, evidence, reason);
        authority.executeModuleContext(
            address(ingress),
            abi.encodeCall(
                IStreamArtistIdentityContest.contestArtistIdentity,
                (artistId, erTerminal, evidence, reason)
            ),
            1,
            scope,
            oldHash,
            newHash
        );
        Dismissal.Cause memory cause = ingress.currentIdentityContestCause(artistId);
        require(
            cause.facts.kind == 1 && cause.facts.executedTransitionHash == erTerminal
                && cause.facts.enteredAt == when && cause.facts.incumbent == address(artist)
                && cause.facts.previousResolutionHash == hbLatest
                && ingress.rotationRecord(erTerminal).transition.contestedAt
                    == (closed.dismissalRecordHash == 0 ? when : originalMarker),
            "new actual op33 preserves the first marker of a closed rotation"
        );
    }

    function historyBatchDismiss(bool abandoned) external onlySelf {
        Dismissal.Request memory p = _dismissalRequest();
        bytes32 recordHash = _dismissalExecute(p, 1, 0);
        Dismissal.Record memory r = ingress.identityContestDismissalRecord(recordHash);
        Dismissal.Cause memory cause = ingress.identityContestCause(p.expectedCauseHash);
        require(
            r.recordHash == recordHash && r.authorityClass == 3 && r.restoredStatus == 3
                && r.incumbent == address(artist) && r.actionId != 0 && r.governanceWitnessHash != 0
                && r.terms.expectedResolutionHash == hbLatest
                && cause.facts.executedTransitionHash == erTerminal,
            "original op41 admits the exact terminal episode and previous resolution"
        );
        hbLatest = recordHash;
        if (hbFirst == 0) hbFirst = recordHash;
        Dismissal.Closure memory c = ingress.identityTransitionClosure(artistId, erTerminal);
        Dismissal.Closure memory empty;
        require(
            c.dismissalRecordHash == hbFirst && c.abandoned == abandoned
                && c.windowEndsAt == erWindow
                && c.contestedAt == ingress.rotationRecord(erTerminal).transition.contestedAt
                && keccak256(abi.encode(ingress.identityTransitionClosure(artistId, erOrigin)))
                    == keccak256(abi.encode(empty)),
            "first terminal closure is immutable and does not rewrite original op40"
        );
    }

    function historyBatchStableGuardian() external onlySelf {
        hbAbandoned = erGuardian;
        hbAbandonedBytes = keccak256(abi.encode(ingress.guardianSetRecord(hbAbandoned)));
        address[] memory members = new address[](1);
        members[0] = address(artist);
        erGuardian = _guardianRecord(members, 1, 14 days, 2000);
        R.GuardianRecord memory g = ingress.guardianSetRecord(erGuardian);
        require(
            g.provisional.transitionRecordHash == 0 && g.provisional.windowEndsAt == 0
                && g.authorityClass == 3 && g.signer == address(artist),
            "post-closure guardian is a fresh original stable class3 record"
        );
    }

    function historyBatchStanding(uint256 salt) external onlySelf {
        _newRotationSafe(salt);
        bytes32 previous = ingress.lastArtistTransition(artistId);
        bytes32 pending = _stageRotation(previous);
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
            "actual current successor Safe files original zero-reason standing veto"
        );
        Dismissal.Cause memory cause = ingress.currentIdentityContestCause(artistId);
        require(
            cause.facts.kind == 2 && cause.facts.pendingTransitionHash == pending
                && cause.facts.executedTransitionHash == erTerminal && cause.facts.evidenceHash == 0
                && cause.facts.reasonHash == 0
                && ingress.rotationRecord(pending).transition.phase == 3,
            "original kind2 cause retains the distinct abandoned pending rotation"
        );
    }

    function _hbRecover(uint256 salt, bool retry) private {
        (IdentityRecovery.Request memory p, T.Authorization memory a) = this.historyPrepare(salt);
        this.rotatedEstateRegister(p, a);
        this.rotatedEstateRecover(p, a, retry);
    }

    function _hbAbandoned() private view {
        (,,, bytes32 current) = ingress.guardianSet(artistId);
        require(
            current == erGuardian && current != hbAbandoned && current != erLower
                && ingress.guardianSetRecord(hbAbandoned).provisional.transitionRecordHash
                    == erTerminal
                && hbAbandonedBytes
                    == keccak256(abi.encode(ingress.guardianSetRecord(hbAbandoned))),
            "abandoned terminal guardians stay archived and never become operative"
        );
    }

    function testHistoryBatchEarlyClosedTerminalFreshGuardianAndArchiveRetry() public {
        this.rotatedEstateSetup(4095, false, true, 0);
        uint64 first = erWindow - 2;
        this.historyBatchCompromise(first);
        this.historyBatchDismiss(true);
        this.historyBatchStableGuardian();
        this.historyBatchCompromise(first + 1);
        _hbAbandoned();
        _hbRecover(61001, true);
        _hbAbandoned();
    }

    function testHistoryBatchPostWindowClosureRetainsZeroCapabilities() public {
        this.rotatedEstateSetup(0, true, false, 0);
        this.historyBatchCompromise(erWindow);
        this.historyBatchDismiss(false);
        this.historyBatchCompromise(erWindow + 1);
        _hbRecover(61002, false);
        require(
            ingress.currentAuthorityCapabilities(artistId).effectiveCapabilities == 0,
            "closed history never upgrades original zero-mask authority"
        );
    }

    function testHistoryBatchStandingClosureAndInterveningDismissal() public {
        this.rotatedEstateSetup(4095, false, false, 0);
        this.historyWarp(erWindow);
        this.historyBatchStanding(61003);
        this.historyBatchDismiss(false);
        this.historyBatchCompromise(erWindow + 1);
        this.historyBatchDismiss(false);
        this.historyBatchCompromise(erWindow + 2);
        require(hbFirst != hbLatest, "latest episode is independent of original closure");
        _hbRecover(61004, true);
    }

    function testHistoryBatchAbandonedLowerNonceSafeStillVetoes() public {
        this.rotatedEstateSetup(4095, false, true, 0);
        this.historyBatchCompromise(erWindow - 2);
        this.historyBatchDismiss(true);
        this.historyBatchStableGuardian();
        this.historyBatchCompromise(erWindow - 1);
        (IdentityRecovery.Request memory p, T.Authorization memory a) = this.historyPrepare(61005);
        this.rotatedEstateRegister(p, a);
        this.historyWarp(scheduled.notBefore);
        _hbAbandoned();
        require(
            executeSafe(
                erVeto,
                erVetoKeys,
                address(ingress),
                0,
                abi.encodeCall(
                    IStreamArtistRecoveryAction.vetoIdentityRecovery,
                    (artistId, keccak256("abandoned terminal lifetime veto"))
                ),
                0
            ),
            "abandoned lower-nonce original Safe remains a lifetime veto member"
        );
        bytes32 roots = _roots();
        scheduled.status = GovernanceActionStatus.EXECUTED;
        _publish();
        vm.expectRevert(abi.encodeWithSelector(A.RecoveryActionVetoed.selector, currentId));
        this.executeRegistered(p, a);
        (bool used,) = ingress.rotationAcceptanceNonceState(artistId, p.newAddress, a.nonce);
        require(
            !used && roots == _roots() && ingress.latestIdentityRecovery(artistId) == 0,
            "lifetime veto preserves acceptance, authority and Archive roots"
        );
    }

    function _hbClosureSlot() private returns (bytes32 slot) {
        ClosedEstateStorageVm probe = ClosedEstateStorageVm(address(vm));
        probe.record();
        Dismissal.Closure memory c = ingress.identityTransitionClosure(artistId, erTerminal);
        (bytes32[] memory reads,) = probe.accesses(suite.owners[2]);
        uint256 found;
        for (uint256 i; i < reads.length; ++i) {
            if (vm.load(suite.owners[2], reads[i]) == c.dismissalRecordHash) {
                slot = reads[i];
                ++found;
            }
        }
        require(
            found == 1 && c.dismissalRecordHash == hbFirst, "unique actual original closure field"
        );
    }

    function testHistoryBatchRejectsSubstitutedOrMissingClosureThenIdenticalRetry() public {
        this.rotatedEstateSetup(4095, false, true, 0);
        this.historyBatchCompromise(erWindow - 3);
        this.historyBatchDismiss(true);
        this.historyBatchStableGuardian();
        this.historyBatchCompromise(erWindow - 2);
        this.historyBatchDismiss(true);
        this.historyBatchCompromise(erWindow - 1);
        (IdentityRecovery.Request memory p, T.Authorization memory a) = this.historyPrepare(61006);
        bytes32 expected = keccak256(abi.encode(ingress.identityRecoveryContext(p, a)));
        bytes32 slot = _hbClosureSlot();
        vm.store(suite.owners[2], slot, hbLatest);
        vm.expectRevert(
            abi.encodeWithSelector(
                IdentityRecovery.UnsupportedIdentityRecoveryProfile.selector, artistId
            )
        );
        ingress.identityRecoveryContext(p, a);
        vm.store(suite.owners[2], slot, bytes32(0));
        vm.expectRevert(
            abi.encodeWithSelector(
                IdentityRecovery.UnsupportedIdentityRecoveryProfile.selector, artistId
            )
        );
        ingress.identityRecoveryContext(p, a);
        vm.store(suite.owners[2], slot, hbFirst);
        require(
            expected == keccak256(abi.encode(ingress.identityRecoveryContext(p, a))),
            "exact immutable closure restoration restores identical signed request context"
        );
        this.rotatedEstateRegister(p, a);
        this.rotatedEstateRecover(p, a, true);
    }

    function historyBatchNext(bool returnOriginal, uint256 salt, bool zeroReason)
        external
        onlySelf
    {
        bytes32 originalExecution = erTerminal;
        if (returnOriginal) {
            rotationSafe = erLiving;
            rotationKeys = erLivingKeys;
        } else {
            _newRotationSafe(salt);
        }
        bytes32 previousStaging = ingress.lastArtistTransition(artistId);
        bytes32 next;
        if (zeroReason) {
            R.Rotation memory terms = _rotationTerms(previousStaging);
            terms.reasonHash = 0;
            (T.Authorization memory oldA, T.Authorization memory newA) =
                _rotationAuthorizations(terms);
            next = ingress.rotateArtistAddress(terms, oldA, newA);
        } else {
            next = _stageRotation(previousStaging);
        }
        _executeTimedRotation(next);
        _adoptRotatedSafe();
        erTerminal = next;
        erWindow = ingress.rotationRecord(next).transition.postWindowEndsAt;
        V.Snapshot memory v = _snapshot(next);
        require(
            v.previousTransitionRecordHash == originalExecution
                && v.previousCommitment == _snapshot(originalExecution).commitment
                && v.authorityClass == 3 && v.newAddress == address(artist)
                && ingress.rotationRecord(next).terms.expectedPreviousTransitionRecordHash
                    == previousStaging
                && ingress.currentAuthorityCapabilities(artistId).activationRecordHash == erOrigin
                && ingress.currentAuthorityCapabilities(artistId).effectiveCapabilities == erCaps,
            "actual op32 preserves separate executed-parent and staged-parent histories"
        );
    }

    function testHistoryBatchThreeRotationsRetainIntermediateGuardianAndRetry() public {
        this.rotatedEstateSetup(4095, false, true, 0);
        bytes32 middleGuardian = erGuardian;
        bytes32 original = erTerminal;
        this.historyWarp(erWindow);
        this.historyBatchNext(false, 61010, false);
        this.historyWarp(erWindow);
        this.historyBatchNext(false, 61011, false);
        this.historyBatchCompromise(erWindow);
        (,,, bytes32 selected) = ingress.guardianSet(artistId);
        require(
            selected == middleGuardian
                && ingress.guardianSetRecord(selected).provisional.transitionRecordHash == original,
            "earlier actual class3 guardian remains operative through later vestings"
        );
        (IdentityRecovery.Request memory p, T.Authorization memory a) = this.historyPrepare(61012);
        bytes32 context = keccak256(abi.encode(ingress.identityRecoveryContext(p, a)));
        _erCorrupt(p, a, _snapshot(erTerminal).previousTransitionRecordHash, 0, context);
        this.rotatedEstateRegister(p, a);
        this.rotatedEstateRecover(p, a, true);
    }

    function testHistoryBatchReturnedOriginalAddressDoesNotRewriteEstateOrigin() public {
        this.rotatedEstateSetup(0, false, false, 0);
        this.historyWarp(erWindow);
        this.historyBatchNext(true, 0, false);
        require(
            address(artist) == address(erLiving),
            "original retired address returns by actual two-sided rotation"
        );
        this.historyWarp(erWindow);
        this.historyBatchNext(false, 61013, false);
        this.historyBatchCompromise(erWindow);
        _hbRecover(61014, false);
        require(
            ingress.currentAuthorityCapabilities(artistId).activationRecordHash == erOrigin,
            "mutable later retirement is not the immutable op40 lineage anchor"
        );
    }

    function testHistoryBatchRotationAfterStandingDismissalRetainsBothParents() public {
        this.rotatedEstateSetup(4095, false, false, 0);
        this.historyWarp(erWindow);
        this.historyBatchStanding(61015);
        this.historyBatchDismiss(false);
        bytes32 previousExecuted = erTerminal;
        bytes32 previousStaged = ingress.lastArtistTransition(artistId);
        this.historyBatchNext(false, 61016, true);
        require(
            previousExecuted != previousStaged
                && _snapshot(erTerminal).previousTransitionRecordHash == previousExecuted
                && ingress.rotationRecord(erTerminal).terms.expectedPreviousTransitionRecordHash
                    == previousStaged && ingress.rotationRecord(erTerminal).terms.reasonHash == 0,
            "dismissed standing attempt remains distinct from the executed vesting parent"
        );
        this.historyBatchCompromise(erWindow);
        _hbRecover(61017, true);
    }
}

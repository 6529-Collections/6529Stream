// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./StreamArtistRepeatedRecoveryActual.t.sol";

/// @notice Actual op35 -> op33 -> op41 -> fresh op33 -> op35 histories.
/// @dev Actual Artist/Safe/Archive; typed unit Core/governance, aggregate source recipes.
contract StreamArtistClosedRepeatedRecoveryActualTest is StreamArtistRepeatedRecoveryActualTest {
    bytes32 private crPrior;
    bytes32 private crCandidate;
    bytes32 private crFresh;
    bytes32 private crFirst;
    bytes32 private crLatest;
    bytes32 private crPermanent;
    bytes32 private crHistory;
    bytes32 private crElection;
    bytes32 private crSelected;
    uint64 private crWindow;
    Estate.AuthorityCapabilities private crCapabilities;

    function closedRepeatSetup(bool estate, bool early) external onlySelf {
        this.repeatedRecoverySetup(estate);
        crPrior = ingress.latestIdentityRecovery(artistId);
        crPermanent = ingress.identityRecoveryRecord(crPrior).terms.supersededRecordHashes[0];
        crCapabilities = ingress.currentAuthorityCapabilities(artistId);
        crWindow = ingress.artistTransitionState(crPrior).postWindowEndsAt;
        address[] memory members = new address[](1);
        members[0] = address(artist);
        crCandidate = _guardianRecord(members, 1, 15 days, nextNonce + 100);
        require(
            ingress.guardianSetRecord(crCandidate).provisional.transitionRecordHash == crPrior,
            "actual recovered principal writes a provisional guardian under op35"
        );
        this.closedRepeatCompromise(early ? crWindow - 10 : crWindow);
        this.closedRepeatDismiss(early);
    }

    function closedRepeatCompromise(uint64 when) external onlySelf {
        vm.warp(when);
        ArtistAppealUnitRoles(suite.roleRegistry).setArbiter(address(artist), true);
        ArtistUnitGovernance authority = ArtistUnitGovernance(manager.governanceAuthority());
        bytes32 evidence = keccak256(abi.encode("closed repeat evidence", crPrior, crLatest, when));
        bytes32 reason = keccak256(abi.encode("closed repeat reason", crPrior, crLatest, when));
        authority.configureContestReads(
            suite.roleRegistry, address(artist), reason, "urn:unit:closed-repeat"
        );
        (bytes32 scope, bytes32 oldHash, bytes32 newHash) =
            ingress.identityContestGovernanceContext(artistId, crPrior, evidence, reason);
        _repeatGovernanceWitness(scope, oldHash, newHash);
        authority.executeModuleContext(
            address(ingress),
            abi.encodeCall(
                IStreamArtistIdentityContest.contestArtistIdentity,
                (artistId, crPrior, evidence, reason)
            ),
            1,
            scope,
            oldHash,
            newHash
        );
        _repeatGovernanceInactive();
        Dismissal.Cause memory cause = ingress.currentIdentityContestCause(artistId);
        require(
            cause.facts.kind == 1 && cause.facts.executedTransitionHash == crPrior
                && cause.facts.incumbent == address(artist) && cause.facts.enteredAt == when
                && cause.facts.authorityClass == crCapabilities.authorityClass,
            "fresh actual op33 retains the original recovery and authority class"
        );
        if (crFirst != 0) {
            require(
                cause.facts.previousResolutionHash == crLatest
                    && cause.facts.previousCauseHash
                        == ingress.identityContestDismissalRecord(crLatest).terms.expectedCauseHash
                    && ingress.artistTransitionState(crPrior).contestedAt
                        == ingress.identityTransitionClosure(artistId, crPrior).contestedAt,
                "fresh compromise keeps the first marker and exact latest resolution links"
            );
        }
    }

    function closedRepeatDismiss(bool abandoned) external onlySelf {
        Dismissal.Request memory p = _dismissalRequest();
        bytes32 previous = ingress.latestIdentityContestDismissal(artistId);
        Dismissal.Context memory context = ingress.identityContestDismissalContext(p);
        _repeatGovernanceWitness(context.scopeHash, context.oldValueHash, context.newValueHash);
        crLatest = _dismissalExecute(p, 1, 0);
        _repeatGovernanceInactive();
        if (crFirst == 0) crFirst = crLatest;
        Dismissal.Record memory r = ingress.identityContestDismissalRecord(crLatest);
        Dismissal.Closure memory c = ingress.identityTransitionClosure(artistId, crPrior);
        require(
            r.recordHash != 0 && r.terms.expectedResolutionHash == previous
                && r.authorityClass == crCapabilities.authorityClass
                && r.restoredStatus == r.authorityClass && r.incumbent == address(artist)
                && r.actionId != 0 && r.governanceWitnessHash != 0
                && c.dismissalRecordHash == crFirst && c.transitionRecordHash == crPrior
                && c.windowEndsAt == crWindow && c.abandoned == abandoned,
            "actual op41 restores the same principal and retains the original closure"
        );
    }

    function closedRepeatFreshGuardian() external onlySelf {
        address[] memory members = new address[](1);
        members[0] = address(artist);
        crFresh = _guardianRecord(members, 1, 20 days, nextNonce + 100);
        R.GuardianRecord memory g = ingress.guardianSetRecord(crFresh);
        (,,, bytes32 selected) = ingress.guardianSet(artistId);
        require(
            g.provisional.transitionRecordHash == 0 && g.provisional.windowEndsAt == 0
                && selected == crFresh && g.signer == address(artist),
            "actual post-dismissal guardian is stable even before the former window ends"
        );
    }

    function closedRepeatTerms(bool exclude, uint256 salt)
        external
        onlySelf
        returns (IdentityRecovery.Request memory p, T.Authorization memory a)
    {
        _newRotationSafe(salt);
        Dismissal.Cause memory cause = ingress.currentIdentityContestCause(artistId);
        p = IdentityRecovery.Request(
            artistId,
            address(rotationSafe),
            crCapabilities.authorityClass,
            cause.causeHash,
            crLatest,
            cause.facts.evidenceHash,
            cause.facts.reasonHash,
            new bytes32[](exclude ? 1 : 0)
        );
        if (exclude) p.supersededRecordHashes[0] = crFresh;
        a = _acceptance(p);
    }

    function _crHistory() private view returns (bytes32) {
        (bytes32 primary, bytes32 occurrence, bytes32 secondary) =
            StreamArtistIdentityAuthority(suite.owners[2]).identityRecoveryReceipts(crPrior);
        (GH.Head memory head,,,) = IStreamArtistGuardianHistory(suite.owners[2])
            .guardianHistoryState(artistId, 0, address(0), 0);
        Dismissal.Record memory first = ingress.identityContestDismissalRecord(crFirst);
        Dismissal.Record memory latest = ingress.identityContestDismissalRecord(crLatest);
        return keccak256(
            abi.encode(
                ingress.identityRecoveryRecord(crPrior),
                _snapshot(crPrior),
                ingress.artistTransitionState(crPrior),
                primary,
                occurrence,
                secondary,
                head,
                ingress.identityTransitionClosure(artistId, crPrior),
                first,
                latest,
                ingress.identityContestCause(first.terms.expectedCauseHash),
                ingress.identityContestCause(latest.terms.expectedCauseHash),
                ingress.guardianSetRecord(crCandidate),
                ingress.guardianSetRecord(crFresh),
                _status(crPermanent)
            )
        );
    }

    function closedRepeatRegister(IdentityRecovery.Request calldata p, T.Authorization calldata a)
        external
        onlySelf
    {
        if (p.supersededRecordHashes.length != 0) {
            IStreamArtistGuardianSelectionPreparation prep = _selectionPreparation();
            crElection = prep.begin(artistId, crPrior, p.supersededRecordHashes);
            Selection.Progress memory progress = prep.continueSelection(crElection, 64);
            crSelected = progress.selectedRecordHash;
            require(
                progress.complete && crSelected != 0 && crSelected != crPermanent
                    && crSelected != crFresh,
                "full election respects prior permanent exclusions and the newly proposed set"
            );
        }
        GovernanceCall[] memory calls = _schedule(
            keccak256(
                abi.encode(
                    "closed repeat independently registered action",
                    crPrior,
                    crLatest,
                    p.expectedCauseHash
                )
            ),
            p,
            a
        );
        ingress.registerIdentityRecoveryAction(currentId, calls, p, a);
        crHistory = _crHistory();
    }

    function closedRepeatExecute(
        IdentityRecovery.Request calldata p,
        T.Authorization calldata a,
        bool retry
    ) external onlySelf returns (bytes32 record) {
        T.Snapshot memory before_ = _ownerSnapshot();
        uint64 epoch = ingress.identityRecoveryRecord(crPrior).delegationEpoch;
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
                !used && _roots() == roots && _crHistory() == crHistory
                    && ingress.latestIdentityRecovery(artistId) == crPrior,
                "late Archive failure rolls back authority, roots, acceptance and every historical proof"
            );
            vm.roll(restoreBlock);
        }
        vm.recordLogs();
        record = this.executeRegistered(p, a);
        V.Snapshot memory v = _snapshot(record);
        _assertSnapshot(v, 35, before_, vm.getRecordedLogs());
        Estate.AuthorityCapabilities memory caps = ingress.currentAuthorityCapabilities(artistId);
        require(
            record != crPrior && ingress.identityRecoveryRecord(record).delegationEpoch == epoch + 1
                && v.previousTransitionRecordHash == crPrior
                && v.previousCommitment == _snapshot(crPrior).commitment
                && caps.authorityAddress == p.newAddress
                && caps.authorityClass == crCapabilities.authorityClass
                && caps.activationRecordHash == crCapabilities.activationRecordHash
                && caps.effectiveCapabilities == crCapabilities.effectiveCapabilities
                && _crHistory() == crHistory,
            "new operation35 preserves prior vesting/action/Archive/closure and original capabilities"
        );
        if (p.supersededRecordHashes.length != 0) {
            (,,, bytes32 selected) = ingress.guardianSet(artistId);
            require(
                selected == crSelected && _status(crFresh).recoveryRecordHash == record
                    && _status(crPermanent).recoveryRecordHash == crPrior,
                "new exclusion generation cannot rewrite the prior permanent judgment"
            );
            IStreamArtistGuardianSelectionPreparation prep = _selectionPreparation();
            vm.expectRevert(
                abi.encodeWithSelector(Selection.InvalidGuardianSelection.selector, crElection)
            );
            prep.continueSelection(crElection, 1);
        }
        bytes32 roots = _roots();
        vm.expectRevert(
            abi.encodeWithSelector(IdentityRecovery.InvalidIdentityRecovery.selector, artistId)
        );
        this.executeRegistered(p, a);
        require(_roots() == roots, "identical consumed action/acceptance cannot replay");
    }

    function _crTerms(uint256 salt)
        private
        returns (IdentityRecovery.Request memory p, T.Authorization memory a)
    {
        return this.closedRepeatTerms(false, salt);
    }

    function _crAbandoned() private view {
        R.GuardianRecord memory g = ingress.guardianSetRecord(crCandidate);
        require(
            g.provisional.transitionRecordHash == crPrior
                && !IStreamArtistRotationOwner(suite.owners[2])
                    .provisionalRecordEligible(artistId, g.provisional),
            "the original abandoned association never matures after expiry or recovery"
        );
    }

    function testClosedRepeatLivingEarlyDismissalFreshGuardianArchiveRetry() public {
        this.closedRepeatSetup(false, true);
        this.closedRepeatFreshGuardian();
        _crAbandoned();
        this.closedRepeatCompromise(crWindow - 9);
        (IdentityRecovery.Request memory p, T.Authorization memory a) = _crTerms(67001);
        this.closedRepeatRegister(p, a);
        this.closedRepeatExecute(p, a, true);
        _crAbandoned();
    }

    function testClosedRepeatEstateLaterDismissalHeadKeepsOriginalCapabilities() public {
        this.closedRepeatSetup(true, true);
        this.closedRepeatFreshGuardian();
        this.closedRepeatCompromise(crWindow - 9);
        this.closedRepeatDismiss(true);
        require(crLatest != crFirst, "actual independent second dismissal");
        this.closedRepeatCompromise(crWindow - 8);
        (IdentityRecovery.Request memory p, T.Authorization memory a) = _crTerms(67002);
        this.closedRepeatRegister(p, a);
        this.closedRepeatExecute(p, a, true);
        _crAbandoned();
    }

    function testClosedRepeatMatureGuardianNewExclusionGenerationAndStaleElection() public {
        this.closedRepeatSetup(false, false);
        R.GuardianRecord memory g = ingress.guardianSetRecord(crCandidate);
        require(
            IStreamArtistRotationOwner(suite.owners[2])
                .provisionalRecordEligible(artistId, g.provisional),
            "non-abandoned post-window guardian stays legitimately mature"
        );
        this.closedRepeatFreshGuardian();
        this.closedRepeatCompromise(crWindow + 1);
        (IdentityRecovery.Request memory p, T.Authorization memory a) =
            this.closedRepeatTerms(true, 67003);
        this.closedRepeatRegister(p, a);
        this.closedRepeatExecute(p, a, true);
    }

    function _crSlot(bytes32 value, bytes32[] memory slots) private view returns (bytes32 slot) {
        uint256 matches;
        for (uint256 i; i < slots.length; ++i) {
            if (vm.load(suite.owners[2], slots[i]) == value) {
                slot = slots[i];
                ++matches;
            }
        }
        require(value != 0 && matches == 1, "unique actual getter field, no guessed slot");
    }

    function testClosedRepeatRejectsSubstitutingLatestDismissalForOriginalClosure() public {
        this.closedRepeatSetup(false, true);
        this.closedRepeatFreshGuardian();
        this.closedRepeatCompromise(crWindow - 9);
        this.closedRepeatDismiss(true);
        this.closedRepeatCompromise(crWindow - 8);
        (IdentityRecovery.Request memory p, T.Authorization memory a) = _crTerms(67004);
        bytes32 original = keccak256(abi.encode(ingress.identityRecoveryContext(p, a)));
        ClosedEstateStorageVm probe = ClosedEstateStorageVm(address(vm));
        probe.record();
        ingress.identityTransitionClosure(artistId, crPrior);
        (bytes32[] memory slots,) = probe.accesses(suite.owners[2]);
        bytes32 slot = _crSlot(crFirst, slots);
        vm.store(suite.owners[2], slot, crLatest);
        vm.expectRevert(
            abi.encodeWithSelector(
                IdentityRecovery.UnsupportedIdentityRecoveryProfile.selector, artistId
            )
        );
        ingress.identityRecoveryContext(p, a);
        vm.store(suite.owners[2], slot, crFirst);
        require(
            keccak256(abi.encode(ingress.identityRecoveryContext(p, a))) == original,
            "original closure restored, same signed current request accepted"
        );
        this.closedRepeatRegister(p, a);
        this.closedRepeatExecute(p, a, false);
    }

    function testClosedRepeatRejectsLatestCauseDriftThenIdenticalAcceptanceRetries() public {
        this.closedRepeatSetup(true, true);
        this.closedRepeatFreshGuardian();
        this.closedRepeatCompromise(crWindow - 9);
        (IdentityRecovery.Request memory p, T.Authorization memory a) = _crTerms(67005);
        bytes32 context = keccak256(abi.encode(ingress.identityRecoveryContext(p, a)));
        ClosedEstateStorageVm probe = ClosedEstateStorageVm(address(vm));
        probe.record();
        bytes32 original = ingress.identityContestDismissalRecord(crLatest).terms.expectedCauseHash;
        (bytes32[] memory slots,) = probe.accesses(suite.owners[2]);
        bytes32 slot = _crSlot(original, slots);
        vm.store(suite.owners[2], slot, p.expectedCauseHash);
        vm.expectRevert(
            abi.encodeWithSelector(
                IdentityRecovery.UnsupportedIdentityRecoveryProfile.selector, artistId
            )
        );
        ingress.identityRecoveryContext(p, a);
        vm.store(suite.owners[2], slot, original);
        require(
            keccak256(abi.encode(ingress.identityRecoveryContext(p, a))) == context,
            "complete historical/current hash restored with unchanged acceptance"
        );
        this.closedRepeatRegister(p, a);
        this.closedRepeatExecute(p, a, true);
    }

    function testClosedRepeatRetainsOriginalLowerNonceLifetimeSafeVeto() public {
        this.closedRepeatSetup(false, true);
        this.closedRepeatFreshGuardian();
        this.closedRepeatCompromise(crWindow - 9);
        (IdentityRecovery.Request memory p, T.Authorization memory a) = _crTerms(67006);
        this.closedRepeatRegister(p, a);
        this.historyWarp(scheduled.notBefore);
        this.vetoByGuardian(keccak256("original lifetime veto after closed repeat"));
        scheduled.status = GovernanceActionStatus.EXECUTED;
        _publish();
        vm.expectRevert(abi.encodeWithSelector(A.RecoveryActionVetoed.selector, currentId));
        this.executeRegistered(p, a);
        _inactive();
        require(
            ingress.latestIdentityRecovery(artistId) == crPrior && _crHistory() == crHistory,
            "closure and prior exclusion do not erase lifetime guardian veto"
        );
    }
}

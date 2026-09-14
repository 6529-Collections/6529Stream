// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./StreamArtistHistoricalGuardianSupersessionActual.t.sol";

/// @notice Actual fresh compromise/action/acceptance after an executed operation35.
/// @dev Actual Artist/Safe/Archive with typed unit governance/Core; aggregate, not capacity evidence.
contract StreamArtistRepeatedRecoveryActualTest is
    StreamArtistHistoricalGuardianSupersessionActualTest
{
    bytes32 private rrPrior;
    bytes32 private rrNewGuardian;
    bytes32 private rrRetained;
    bytes32 private rrOriginals;
    bytes32 private rrPermanentExcluded;
    bytes32 private rrElection;
    uint64 private rrEpoch;
    EState private rrEstate;

    struct EState {
        bytes32 activation;
        uint32 caps;
        uint8 authorityClass;
    }

    function repeatedRecoverySetup(bool estate) external onlySelf {
        if (estate) {
            this.testHistoricalSupersessionEstateRestoresLivingAssociationAndArchiveRetry();
        } else {
            this.testHistoricalSupersessionLivingRestoresEarlierRotationGuardian();
        }
        _adoptRotatedSafe();
        rrPrior = ingress.latestIdentityRecovery(artistId);
        IdentityRecovery.Record memory original = ingress.identityRecoveryRecord(rrPrior);
        rrPermanentExcluded = original.terms.supersededRecordHashes[0];
        (,,, rrRetained) = ingress.guardianSet(artistId);
        Estate.AuthorityCapabilities memory capabilities =
            ingress.currentAuthorityCapabilities(artistId);
        rrEstate = EState(
            capabilities.activationRecordHash,
            capabilities.effectiveCapabilities,
            capabilities.authorityClass
        );
        rrEpoch = original.delegationEpoch;
        require(
            _status(rrPermanentExcluded).recoveryRecordHash == rrPrior,
            "first actual recovery has permanent exclusions, not a synthetic prior head"
        );
    }

    function repeatedRecoveryGuardian() external onlySelf {
        address[] memory members = new address[](1);
        members[0] = address(artist);
        rrNewGuardian = _guardianRecord(members, 1, 15 days, nextNonce + 100);
        R.GuardianRecord memory g = ingress.guardianSetRecord(rrNewGuardian);
        require(
            g.provisional.transitionRecordHash == rrPrior
                && g.provisional.windowEndsAt
                    == ingress.artistTransitionState(rrPrior).postWindowEndsAt,
            "actual recovered principal's op28 is provisional under original op35 window"
        );
    }

    function repeatedRecoveryCompromise(uint64 when) external onlySelf {
        vm.warp(when);
        ArtistAppealUnitRoles(suite.roleRegistry).setArbiter(address(artist), true);
        ArtistUnitGovernance authority = ArtistUnitGovernance(manager.governanceAuthority());
        bytes32 evidence = keccak256(abi.encode("repeat recovery compromise", rrPrior, when));
        bytes32 reason = keccak256(abi.encode("repeat recovery reason", rrPrior, when));
        authority.configureContestReads(
            suite.roleRegistry, address(artist), reason, "urn:unit:repeat-recovery"
        );
        (bytes32 scope, bytes32 oldHash, bytes32 newHash) =
            ingress.identityContestGovernanceContext(artistId, rrPrior, evidence, reason);
        authority.executeModuleContext(
            address(ingress),
            abi.encodeCall(
                IStreamArtistIdentityContest.contestArtistIdentity,
                (artistId, rrPrior, evidence, reason)
            ),
            1,
            scope,
            oldHash,
            newHash
        );
        Dismissal.Cause memory cause = ingress.currentIdentityContestCause(artistId);
        require(
            cause.facts.executedTransitionHash == rrPrior && cause.facts.kind == 1
                && cause.facts.authorityClass == rrEstate.authorityClass
                && ingress.artistTransitionState(rrPrior).contestedAt == when,
            "original op33 writes the actual prior recovery transition marker"
        );
    }

    function repeatedRecoveryTerms(bool exclude, uint256 salt)
        external
        onlySelf
        returns (IdentityRecovery.Request memory p, T.Authorization memory a)
    {
        _newRotationSafe(salt);
        Dismissal.Cause memory cause = ingress.currentIdentityContestCause(artistId);
        p = IdentityRecovery.Request(
            artistId,
            address(rotationSafe),
            rrEstate.authorityClass,
            cause.causeHash,
            ingress.latestIdentityContestDismissal(artistId),
            cause.facts.evidenceHash,
            cause.facts.reasonHash,
            new bytes32[](exclude ? 1 : 0)
        );
        if (exclude) p.supersededRecordHashes[0] = rrNewGuardian;
        a = _acceptance(p);
    }

    function _rrHistory() private view returns (bytes32) {
        IdentityRecovery.Record memory prior = ingress.identityRecoveryRecord(rrPrior);
        (bytes32 primary, bytes32 occurrence, bytes32 secondary) =
            StreamArtistIdentityAuthority(suite.owners[2]).identityRecoveryReceipts(rrPrior);
        (GH.Head memory head,,,) = IStreamArtistGuardianHistory(suite.owners[2])
            .guardianHistoryState(artistId, 0, address(0), 0);
        return keccak256(
            abi.encode(
                prior,
                _snapshot(rrPrior),
                ingress.artistTransitionState(rrPrior),
                primary,
                occurrence,
                secondary,
                head,
                _status(rrPermanentExcluded),
                ingress.guardianSetRecord(rrRetained),
                ingress.guardianSetRecord(rrNewGuardian)
            )
        );
    }

    function repeatedRecoveryRegister(
        IdentityRecovery.Request calldata p,
        T.Authorization calldata a
    ) external onlySelf {
        if (p.supersededRecordHashes.length != 0) {
            IStreamArtistGuardianSelectionPreparation prep = _selectionPreparation();
            rrElection = prep.begin(artistId, rrPrior, p.supersededRecordHashes);
            (GH.Head memory head,,,) = IStreamArtistGuardianHistory(suite.owners[2])
                .guardianHistoryState(artistId, 0, address(0), 0);
            Selection.Basis memory basis = Selection.Basis(
                artistId,
                suite.owners[2].codehash,
                head,
                ingress.artistTransitionState(rrPrior),
                keccak256(abi.encode(p.supersededRecordHashes))
            );
            bytes32 original = keccak256(
                abi.encode(
                    keccak256("6529STREAM_ARTIST_GUARDIAN_SELECTION_SOURCE_V1"),
                    block.chainid,
                    address(ingress),
                    suite.owners[2],
                    basis
                )
            );
            require(
                rrElection
                    == keccak256(
                        abi.encode(
                            keccak256("6529STREAM_ARTIST_GUARDIAN_SELECTION_RECOVERY_BASIS_V1"),
                            original,
                            rrPrior
                        )
                    ),
                "selection independently binds actual prior recovery/permanent-status generation"
            );
            Selection.Progress memory progress = prep.continueSelection(rrElection, 64);
            require(
                progress.complete && progress.selectedRecordHash == rrRetained
                    && progress.selectedRecordHash != rrPermanentExcluded,
                "complete second election skips both old permanent and new proposed exclusions"
            );
        }
        GovernanceCall[] memory calls =
            _schedule(keccak256(abi.encode("new repeat recovery action", rrPrior)), p, a);
        ingress.registerIdentityRecoveryAction(currentId, calls, p, a);
        rrOriginals = _rrHistory();
    }

    function repeatedRecoveryExecute(
        IdentityRecovery.Request calldata p,
        T.Authorization calldata a,
        bool retry
    ) external onlySelf returns (bytes32 record) {
        T.Snapshot memory before_ = _ownerSnapshot();
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
                !used && roots == _roots() && rrOriginals == _rrHistory()
                    && ingress.latestIdentityRecovery(artistId) == rrPrior,
                "late Archive rollback restores exact latest record, delegation epoch, exclusions and acceptance"
            );
            vm.roll(restoreBlock);
        }
        vm.recordLogs();
        record = this.executeRegistered(p, a);
        V.Snapshot memory v = _snapshot(record);
        _assertSnapshot(v, 35, before_, vm.getRecordedLogs());
        Estate.AuthorityCapabilities memory caps = ingress.currentAuthorityCapabilities(artistId);
        require(
            record != rrPrior
                && ingress.identityRecoveryRecord(record).delegationEpoch == rrEpoch + 1
                && v.previousTransitionRecordHash == rrPrior
                && v.previousCommitment == _snapshot(rrPrior).commitment && v.operationId == 35
                && v.newAddress == p.newAddress && _rrHistory() == rrOriginals
                && caps.authorityClass == rrEstate.authorityClass
                && caps.effectiveCapabilities == rrEstate.caps
                && caps.activationRecordHash == rrEstate.activation
                && caps.authorityAddress == p.newAddress,
            "fresh op35 preserves complete prior execution and exact original authority class/capabilities"
        );
        if (p.supersededRecordHashes.length != 0) {
            (,,, bytes32 selected) = ingress.guardianSet(artistId);
            require(
                selected == rrRetained && _status(rrNewGuardian).recoveryRecordHash == record,
                "new status generation restores exact historical retained head"
            );
            IStreamArtistGuardianSelectionPreparation prep = _selectionPreparation();
            vm.expectRevert(
                abi.encodeWithSelector(Selection.InvalidGuardianSelection.selector, rrElection)
            );
            prep.continueSelection(rrElection, 1);
        }
        bytes32 roots = _roots();
        vm.expectRevert(
            abi.encodeWithSelector(IdentityRecovery.InvalidIdentityRecovery.selector, artistId)
        );
        this.executeRegistered(p, a);
        require(roots == _roots(), "same second action and acceptance remain consumed");
    }

    function repeatedRecoveryAdopt() external onlySelf {
        _adoptRotatedSafe();
        rrPrior = ingress.latestIdentityRecovery(artistId);
        rrEpoch = ingress.identityRecoveryRecord(rrPrior).delegationEpoch;
        (,,, rrRetained) = ingress.guardianSet(artistId);
        rrNewGuardian = 0;
        rrElection = 0;
    }

    function _rrRound(bool exclude, uint256 salt, bool retry) private {
        this.repeatedRecoveryGuardian();
        this.repeatedRecoveryCompromise(ingress.artistTransitionState(rrPrior).postWindowEndsAt);
        (IdentityRecovery.Request memory p, T.Authorization memory a) =
            this.repeatedRecoveryTerms(exclude, salt);
        this.repeatedRecoveryRegister(p, a);
        this.repeatedRecoveryExecute(p, a, retry);
    }

    function testRepeatedLivingRecoveryPreservesPriorActionAndArchiveRetry() public {
        this.repeatedRecoverySetup(false);
        _rrRound(false, 64001, true);
    }

    function testRepeatedEstateRecoveryPreservesOriginalOp40Capabilities() public {
        this.repeatedRecoverySetup(true);
        this.repeatedRecoveryGuardian();
        this.repeatedRecoveryCompromise(ingress.artistTransitionState(rrPrior).postWindowEndsAt);
        (IdentityRecovery.Request memory p, T.Authorization memory a) =
            this.repeatedRecoveryTerms(false, 64002);
        bytes32 roots = _roots();
        p.vestedAuthorityClass = 1;
        vm.expectRevert(
            abi.encodeWithSelector(IdentityRecovery.InvalidIdentityRecovery.selector, artistId)
        );
        ingress.identityRecoveryContext(p, a);
        require(
            _roots() == roots && ingress.latestIdentityRecovery(artistId) == rrPrior,
            "repeated recovery cannot promote the original estate into living authority"
        );
        p.vestedAuthorityClass = rrEstate.authorityClass;
        this.repeatedRecoveryRegister(p, a);
        this.repeatedRecoveryExecute(p, a, true);
    }

    function testRepeatedRecoveryThreeDistinctActionsAndExclusionGenerations() public {
        this.repeatedRecoverySetup(true);
        _rrRound(true, 64003, true);
        this.repeatedRecoveryAdopt();
        _rrRound(true, 64004, false);
    }

    function testRepeatedRecoveryContestedWindowNeverMaturesByWaiting() public {
        this.repeatedRecoverySetup(false);
        this.repeatedRecoveryGuardian();
        uint64 ends = ingress.artistTransitionState(rrPrior).postWindowEndsAt;
        this.repeatedRecoveryCompromise(ends - 1);
        (IdentityRecovery.Request memory p, T.Authorization memory a) =
            this.repeatedRecoveryTerms(false, 64005);
        vm.expectRevert(
            abi.encodeWithSelector(
                IdentityRecovery.UnsupportedIdentityRecoveryProfile.selector, artistId
            )
        );
        ingress.identityRecoveryContext(p, a);
        this.historyWarp(ends + 1);
        vm.expectRevert(
            abi.encodeWithSelector(
                IdentityRecovery.UnsupportedIdentityRecoveryProfile.selector, artistId
            )
        );
        ingress.identityRecoveryContext(p, a);
        require(
            ingress.latestIdentityRecovery(artistId) == rrPrior,
            "same in-window cause never matures by waiting"
        );
    }

    function testRepeatedRecoveryRejectsPriorContextCorruptionAndIdenticalRetry() public {
        this.repeatedRecoverySetup(false);
        this.repeatedRecoveryGuardian();
        this.repeatedRecoveryCompromise(ingress.artistTransitionState(rrPrior).postWindowEndsAt);
        (IdentityRecovery.Request memory p, T.Authorization memory a) =
            this.repeatedRecoveryTerms(false, 64006);
        bytes32 context = keccak256(abi.encode(ingress.identityRecoveryContext(p, a)));
        ClosedEstateStorageVm probe = ClosedEstateStorageVm(address(vm));
        probe.record();
        bytes32 original = ingress.identityRecoveryRecord(rrPrior).contextHash;
        (bytes32[] memory slots,) = probe.accesses(suite.owners[2]);
        bytes32 slot;
        uint256 count;
        for (uint256 i; i < slots.length; ++i) {
            if (vm.load(suite.owners[2], slots[i]) == original) {
                slot = slots[i];
                ++count;
            }
        }
        require(
            original != 0 && count == 1, "unique actual prior-record field, not guessed storage"
        );
        vm.store(suite.owners[2], slot, bytes32(uint256(original) ^ 1));
        vm.expectRevert(
            abi.encodeWithSelector(
                IdentityRecovery.UnsupportedIdentityRecoveryProfile.selector, artistId
            )
        );
        ingress.identityRecoveryContext(p, a);
        vm.store(suite.owners[2], slot, original);
        require(
            keccak256(abi.encode(ingress.identityRecoveryContext(p, a))) == context,
            "identical current signed request restored"
        );
        this.repeatedRecoveryRegister(p, a);
        this.repeatedRecoveryExecute(p, a, false);
    }

    function testRepeatedRecoveryRetainsOriginalLowerNonceLifetimeSafeVeto() public {
        this.repeatedRecoverySetup(false);
        this.repeatedRecoveryGuardian();
        this.repeatedRecoveryCompromise(ingress.artistTransitionState(rrPrior).postWindowEndsAt);
        (IdentityRecovery.Request memory p, T.Authorization memory a) =
            this.repeatedRecoveryTerms(false, 64007);
        this.repeatedRecoveryRegister(p, a);
        this.historyWarp(scheduled.notBefore);
        this.vetoByGuardian(keccak256("original lifetime guardian vetoes second recovery"));
        scheduled.status = GovernanceActionStatus.EXECUTED;
        _publish();
        vm.expectRevert(abi.encodeWithSelector(A.RecoveryActionVetoed.selector, currentId));
        this.executeRegistered(p, a);
        _inactive();
        require(
            ingress.latestIdentityRecovery(artistId) == rrPrior && _rrHistory() == rrOriginals,
            "a successful prior recovery does not erase lifetime veto"
        );
    }
}

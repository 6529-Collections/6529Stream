// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./StreamArtistClosedEstateRecoveryActual.t.sol";
import {
    IStreamArtistEstateActivation
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistEstateActivation.sol";
import {
    IStreamArtistRotation
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistRotation.sol";
import {
    StreamArtistSuccessionTypes as HistorySuccession
} from "../../../smart-contracts/interfaces/stream/artist/StreamArtistSuccessionTypes.sol";

/// @notice Actual living rotations/op40, op31/op41 closures and original registered estate recovery.
/// @dev Real Artist/Safe/Archive; Core/governance facts remain typed aggregate unit boundaries.
contract StreamArtistEstateStandingHistoryActualTest is StreamArtistClosedEstateRecoveryActualTest {
    bytes32 private shActivation;
    bytes32 private shPlan;
    bytes32 private shGuardian;
    bytes32 private shLowerGuardian;
    bytes32 private shLastRotation;
    bytes32 private shLastVeto;
    bytes32 private shOriginals;
    uint64 private shWindow;
    uint32 private shCaps;
    address private shLiving;
    address private shSuccessor;
    OfficialSafe private shVetoSafe;
    uint256[] private shVetoKeys;
    bytes32[] private shRotations;
    bytes32[] private shDismissals;

    modifier onlySelf() {
        require(msg.sender == address(this), "test wrapper only");
        _;
    }

    function historyWarp(uint64 when) external onlySelf {
        vm.warp(when);
    }

    function historySetup(uint8 priorRotations, uint32 caps, bool oldPlan) external onlySelf {
        _sizes();
        shCaps = caps;
        shLiving = address(artist);
        _delegateSetup();
        _newRotationSafe(59001);
        shVetoSafe = rotationSafe;
        shVetoKeys = rotationKeys;
        address[] memory members = new address[](1);
        members[0] = address(shVetoSafe);
        shLowerGuardian = _guardianRecord(members, 1, 10 days, 900);
        members[0] = shLiving;
        shGuardian = _guardianRecord(members, 1, 11 days, 1000);
        if (oldPlan) {
            HistorySuccession.Designation memory d = _successorTerms(address(delegateSafe), 2);
            d.grantedCapabilities = caps;
            shPlan = _successionRecord(d);
        }
        for (uint256 i; i < priorRotations; ++i) {
            this.historyLivingRotation(59100 + i, i + 1 == priorRotations);
        }
        this.historyRequestEstate();
        this.historyExecuteEstate();
    }

    function historyLivingRotation(uint256 salt, bool guardian) external onlySelf {
        _newRotationSafe(salt);
        bytes32 r = _stageRotation(shLastRotation);
        shRotations.push(r);
        _executeTimedRotation(r);
        _adoptRotatedSafe();
        shLastRotation = r;
        if (guardian) this.historyLivingGuardian();
        this.historyWarp(ingress.rotationRecord(r).transition.postWindowEndsAt);
    }

    function historyLivingGuardian() external onlySelf {
        address[] memory members = new address[](1);
        members[0] = address(artist);
        shGuardian = _guardianRecord(members, 1, 12 days, 1001);
        R.GuardianRecord memory g = ingress.guardianSetRecord(shGuardian);
        require(
            g.authorityClass == 1 && g.signer == address(artist)
                && g.provisional.transitionRecordHash == shLastRotation,
            "actual provisional living guardian retains its original rotation"
        );
    }

    function historyRequestEstate() external onlySelf {
        if (shPlan == 0) {
            HistorySuccession.Designation memory d = _successorTerms(address(delegateSafe), 2);
            d.grantedCapabilities = shCaps;
            shPlan = _successionRecord(d);
        }
        (bytes32 evidence, bytes32 coverage) = _estateArchiveEvidence(artistId);
        Estate.Request memory p =
            Estate.Request(artistId, address(delegateSafe), evidence, shPlan, coverage);
        T.Authorization memory a = T.Authorization(0, uint64(block.timestamp + 1 days), "");
        require(
            executeSafe(
                delegateSafe,
                delegateKeys,
                address(ingress),
                0,
                abi.encodeCall(IStreamArtistEstateActivation.requestEstateActivation, (p, a)),
                0
            ),
            "original successor Safe request after real living history"
        );
        (,, shActivation) = ingress.estateActivationState(artistId);
    }

    function historyExecuteEstate() external onlySelf {
        (Estate.RequestRecord memory r,,) = ingress.estateActivationRecord(shActivation);
        vm.warp(r.noticeEndsAt);
        ingress.executeEstateActivation(
            Estate.Execution(artistId, shActivation, r.terms.selectedCoverageHash)
        );
        artist = delegateSafe;
        keys = delegateKeys;
        shSuccessor = address(artist);
        nextNonce = IStreamArtistIdentityOwner(suite.owners[2]).identity(artistId).nonceHint;
        V.Snapshot memory v = _snapshot(shActivation);
        shWindow = ingress.artistTransitionState(shActivation).postWindowEndsAt;
        require(
            v.operationId == 40 && v.authorityClass == 3
                && v.previousTransitionRecordHash == shLastRotation
                && v.previousCommitment
                    == (shLastRotation == 0 ? bytes32(0) : _snapshot(shLastRotation).commitment),
            "original op40 links the actual saved living vesting head"
        );
        if (shLastRotation != 0) {
            require(
                ingress.successorDesignationRecord(shPlan).signer == shLiving
                    && r.incumbent != shLiving
                    && ingress.guardianSetRecord(shGuardian).provisional.transitionRecordHash
                        == shLastRotation,
                "retained earlier signer plan and matured living guardian are independent of current incumbent"
            );
        }
    }

    function historyStandingEpisode(uint64 when, uint256 salt, bytes32 reason) external onlySelf {
        vm.warp(when);
        _newRotationSafe(salt);
        bytes32 previous = shLastVeto == 0 ? shActivation : shLastVeto;
        bytes32 r = _stageRotation(previous);
        shRotations.push(r);
        shLastVeto = r;
        require(
            executeSafe(
                artist,
                keys,
                address(ingress),
                0,
                abi.encodeCall(IStreamArtistRotation.vetoArtistRotation, (artistId, r, reason)),
                0
            ),
            "actual current successor Safe standing veto"
        );
        Dismissal.Cause memory cause = ingress.currentIdentityContestCause(artistId);
        R.RotationRecord memory item = ingress.rotationRecord(r);
        require(
            cause.facts.kind == 2 && cause.facts.referenceHash == r
                && cause.facts.pendingTransitionHash == r
                && cause.facts.executedTransitionHash == shActivation
                && cause.facts.evidenceHash == 0 && cause.facts.reasonHash == reason
                && cause.facts.authorityClass == 3 && cause.facts.priorStatus == 3
                && item.transition.phase == 3 && item.transition.executedAt == 0
                && item.transition.contestedAt == cause.facts.enteredAt
                && ingress.artistTransitionState(shActivation).contestedAt == 0,
            "op31 immutable cause differs from op33 and leaves the estate marker unchanged"
        );
        (bool used,) =
            ingress.rotationAcceptanceNonceState(artistId, item.terms.newAddress, item.newNonce);
        require(used, "failed takeover's original acceptance remains consumed");
    }

    function historyDismiss() external onlySelf {
        Dismissal.Request memory p = _dismissalRequest();
        bytes32 d = _dismissalExecute(p, 1, 0);
        shDismissals.push(d);
        Dismissal.Closure memory estate = ingress.identityTransitionClosure(artistId, shActivation);
        Dismissal.Record memory record = ingress.identityContestDismissalRecord(d);
        Dismissal.Cause memory cause = ingress.identityContestCause(p.expectedCauseHash);
        require(
            record.recordHash == d && record.authorityClass == 3 && record.restoredStatus == 3
                && record.actionId != 0 && record.governanceWitnessHash != 0
                && estate.dismissalRecordHash == shDismissals[0] && !estate.abandoned
                && estate.contestedAt == 0 && estate.windowEndsAt == shWindow,
            "actual op41 closes original expired estate without manufacturing a contest marker"
        );
        if (cause.facts.kind == 2) {
            Dismissal.Closure memory pending =
                ingress.identityTransitionClosure(artistId, cause.facts.referenceHash);
            require(
                pending.abandoned && pending.dismissalRecordHash == d
                    && pending.contestedAt == cause.facts.enteredAt,
                "same dismissal permanently abandons the actual pending rotation"
            );
        }
    }

    function historyCompromise(uint64 when) external onlySelf {
        vm.warp(when);
        ArtistUnitGovernance authority = ArtistUnitGovernance(manager.governanceAuthority());
        ArtistUnitRoles(suite.roleRegistry).setArbiter(shSuccessor, true);
        bytes32 evidence = keccak256(abi.encode("standing history new compromise", when));
        bytes32 reason = keccak256(abi.encode("standing history reason", when));
        authority.configureContestReads(
            suite.roleRegistry, shSuccessor, reason, "urn:unit:standing-estate"
        );
        (bytes32 scope, bytes32 oldHash, bytes32 newHash) =
            ingress.identityContestGovernanceContext(artistId, shActivation, evidence, reason);
        authority.executeModuleContext(
            address(ingress),
            abi.encodeCall(
                IStreamArtistIdentityContest.contestArtistIdentity,
                (artistId, shActivation, evidence, reason)
            ),
            1,
            scope,
            oldHash,
            newHash
        );
        require(
            ingress.currentIdentityContestCause(artistId).facts.kind == 1,
            "current recovery remains original compromise admission"
        );
    }

    function historyTerms() external view returns (IdentityRecovery.Request memory p) {
        Dismissal.Cause memory cause = ingress.currentIdentityContestCause(artistId);
        return IdentityRecovery.Request(
            artistId,
            address(rotationSafe),
            3,
            cause.causeHash,
            ingress.latestIdentityContestDismissal(artistId),
            cause.facts.evidenceHash,
            cause.facts.reasonHash,
            new bytes32[](0)
        );
    }

    function historyPrepare(uint256 salt)
        external
        onlySelf
        returns (IdentityRecovery.Request memory p, T.Authorization memory a)
    {
        _newRotationSafe(salt);
        p = this.historyTerms();
        a = _acceptance(p);
    }

    function historyRegister(IdentityRecovery.Request calldata p, T.Authorization calldata a)
        external
        onlySelf
    {
        GovernanceCall[] memory calls =
            _schedule(keccak256("standing estate recovery original action"), p, a);
        ingress.registerIdentityRecoveryAction(currentId, calls, p, a);
        (A.Association memory association,,, uint64 count) = _read();
        (GH.Head memory head,, GH.Snapshot memory saved,) = IStreamArtistGuardianHistory(
                suite.owners[2]
            ).guardianHistoryState(artistId, 0, address(0), currentId);
        require(
            count == head.count && saved.count == head.count
                && saved.historyCommitment == head.commitment
                && association.guardian.recordHash == shGuardian,
            "registered recovery binds original complete prefix including prior living guardian"
        );
        shOriginals = _history();
    }

    function _history() private view returns (bytes32) {
        (Estate.RequestRecord memory r, uint8 phase, Estate.ExecutionFacts memory x) =
            ingress.estateActivationRecord(shActivation);
        bytes32 h = keccak256(
            abi.encode(
                r,
                phase,
                x,
                _snapshot(shActivation),
                ingress.identityTransitionClosure(artistId, shActivation),
                ingress.successorDesignationRecord(shPlan),
                ingress.guardianSetRecord(shGuardian),
                ingress.guardianSetRecord(shLowerGuardian)
            )
        );
        for (uint256 i; i < shRotations.length; ++i) {
            bytes32 id = shRotations[i];
            R.RotationRecord memory rotation = ingress.rotationRecord(id);
            h = keccak256(abi.encode(h, rotation, ingress.identityTransitionClosure(artistId, id)));
            if (rotation.transition.phase == 2) h = keccak256(abi.encode(h, _snapshot(id)));
        }
        for (uint256 i; i < shDismissals.length; ++i) {
            Dismissal.Record memory d = ingress.identityContestDismissalRecord(shDismissals[i]);
            h = keccak256(abi.encode(h, d, ingress.identityContestCause(d.terms.expectedCauseHash)));
        }
        return h;
    }

    function historyRecover(
        IdentityRecovery.Request calldata p,
        T.Authorization calldata a,
        bool retry
    ) external onlySelf {
        T.Identity memory old = IStreamArtistIdentityOwner(suite.owners[2]).identity(artistId);
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
                !used && roots == _roots() && _history() == shOriginals
                    && ingress.latestIdentityRecovery(artistId) == 0
                    && keccak256(abi.encode(old))
                        == keccak256(
                            abi.encode(
                                IStreamArtistIdentityOwner(suite.owners[2]).identity(artistId)
                            )
                        ),
                "late real Archive failure rolls back entire authority/history and original acceptance"
            );
            vm.roll(restoreBlock);
        }
        vm.recordLogs();
        bytes32 recovered = this.executeRegistered(p, a);
        _assertSnapshot(_snapshot(recovered), 35, before_, vm.getRecordedLogs());
        Estate.AuthorityCapabilities memory rights = ingress.currentAuthorityCapabilities(artistId);
        (bool used,) = ingress.rotationAcceptanceNonceState(artistId, p.newAddress, a.nonce);
        (bytes32 primary, bytes32 occurrence, bytes32 secondary) =
            IStreamArtistIdentityRecoveryOwner(suite.owners[2]).identityRecoveryReceipts(recovered);
        require(
            rights.activationRecordHash == shActivation && rights.authorityClass == 3
                && rights.status == 3 && rights.authorityAddress == p.newAddress
                && rights.effectiveCapabilities == shCaps
                && _snapshot(recovered).previousTransitionRecordHash == shActivation
                && _history() == shOriginals && used && primary != 0 && occurrence != 0
                && secondary != 0 && primary != secondary,
            "actual original op35 preserves inherited estate history/capabilities and appends both receipts"
        );
    }

    function testStandingEstateZeroReasonClosureAndIdenticalArchiveRetry() public {
        this.historySetup(0, 4095, false);
        this.historyStandingEpisode(shWindow, 59201, 0);
        IdentityRecovery.Request memory premature = this.historyTerms();
        premature.evidenceHash = keccak256("not op33");
        premature.reasonHash = keccak256("not op33 reason");
        vm.expectRevert(
            abi.encodeWithSelector(IdentityRecovery.InvalidIdentityRecovery.selector, artistId)
        );
        ingress.identityRecoveryContext(premature, T.Authorization(0, shWindow + 1 days, ""));
        this.historyDismiss();
        bytes32 prior = _history();
        vm.expectRevert(abi.encodeWithSignature("Error(string)", "GS013"));
        this.executeArtistSafe(
            abi.encodeCall(
                IStreamArtistRotation.vetoArtistRotation, (artistId, shLastVeto, bytes32(0))
            )
        );
        require(
            _history() == prior && ingress.currentAuthorityCapabilities(artistId).status == 3,
            "repeated veto cannot rewrite history"
        );
        this.historyCompromise(shWindow + 1);
        (IdentityRecovery.Request memory p, T.Authorization memory a) = this.historyPrepare(59202);
        this.historyRegister(p, a);
        this.historyRecover(p, a, true);
    }

    function testStandingEstateTwoVetoEpisodesAndLaterCompromiseDismissal() public {
        this.historySetup(0, 256, false);
        this.historyStandingEpisode(shWindow, 59211, keccak256("first veto"));
        this.historyDismiss();
        this.historyStandingEpisode(shWindow + 1, 59212, keccak256("second veto"));
        this.historyDismiss();
        this.historyCompromise(shWindow + 2);
        this.historyDismiss();
        this.historyCompromise(shWindow + 3);
        (IdentityRecovery.Request memory p, T.Authorization memory a) = this.historyPrepare(59213);
        this.historyRegister(p, a);
        this.historyRecover(p, a, false);
    }

    function testEstateAfterTwoLivingRotationsRetainsOldPlanAndMatureGuardian() public {
        this.historySetup(2, 0, true);
        this.historyCompromise(shWindow);
        (IdentityRecovery.Request memory p, T.Authorization memory a) = this.historyPrepare(59221);
        this.historyRegister(p, a);
        this.historyRecover(p, a, true);
        _adoptRotatedSafe();
        vm.expectRevert(
            abi.encodeWithSelector(
                Estate.EstateCapabilityUnavailable.selector, artistId, uint32(2048)
            )
        );
        this.historyAttemptGuardian();
    }

    function testStandingEstateAfterLivingHistoryRetainsLowerNonceSafeVeto() public {
        this.historySetup(1, 4095, true);
        this.historyStandingEpisode(shWindow, 59231, 0);
        this.historyDismiss();
        this.historyCompromise(shWindow + 1);
        (IdentityRecovery.Request memory p, T.Authorization memory a) = this.historyPrepare(59232);
        this.historyRegister(p, a);
        this.historyWarp(scheduled.notBefore);
        require(
            executeSafe(
                shVetoSafe,
                shVetoKeys,
                address(ingress),
                0,
                abi.encodeCall(
                    IStreamArtistRecoveryAction.vetoIdentityRecovery,
                    (artistId, keccak256("retained lower nonce standing"))
                ),
                0
            ),
            "original lower nonce Safe retains lifetime veto"
        );
        scheduled.status = GovernanceActionStatus.EXECUTED;
        _publish();
        vm.expectRevert(abi.encodeWithSelector(A.RecoveryActionVetoed.selector, currentId));
        this.executeRegistered(p, a);
        _inactive();
        require(_history() == shOriginals, "veto preserves all original history");
        (bool used,) = ingress.rotationAcceptanceNonceState(artistId, p.newAddress, a.nonce);
        require(
            !used && ingress.latestIdentityRecovery(artistId) == 0,
            "veto does not consume new authority acceptance"
        );
    }

    function historyAttemptGuardian() external onlySelf returns (bytes32) {
        address[] memory members = new address[](1);
        members[0] = address(artist);
        return _guardianRecord(members, 1, 10 days, nextNonce);
    }

    function _historySlot(bytes32 id, bool vesting)
        private
        returns (bytes32 slot, bytes32 original)
    {
        ClosedEstateStorageVm trace = ClosedEstateStorageVm(address(vm));
        trace.record();
        if (vesting) original = _snapshot(id).commitment;
        else original = bytes32(uint256(uint160(ingress.rotationRecord(id).terms.newAddress)));
        (bytes32[] memory reads,) = trace.accesses(suite.owners[2]);
        uint256 count;
        for (uint256 i; i < reads.length; ++i) {
            if (vm.load(suite.owners[2], reads[i]) == original) {
                slot = reads[i];
                ++count;
            }
        }
        require(
            original != 0 && count == 1,
            "unique original owner record field; no hardcoded storage layout"
        );
    }

    function _pendingClosureSlot(bytes32 id) private returns (bytes32 slot, bytes32 original) {
        ClosedEstateStorageVm trace = ClosedEstateStorageVm(address(vm));
        trace.record();
        original = ingress.identityTransitionClosure(artistId, id).dismissalRecordHash;
        (bytes32[] memory reads,) = trace.accesses(suite.owners[2]);
        uint256 count;
        for (uint256 i; i < reads.length; ++i) {
            if (vm.load(suite.owners[2], reads[i]) == original) {
                slot = reads[i];
                ++count;
            }
        }
        require(original != 0 && count == 1, "unique actual pending closure dismissal");
    }

    function _emptyEstateClosureControl(
        IdentityRecovery.Request memory p,
        T.Authorization memory a,
        bytes32 expected
    ) private {
        ClosedEstateStorageVm trace = ClosedEstateStorageVm(address(vm));
        trace.record();
        Dismissal.Closure memory original =
            ingress.identityTransitionClosure(artistId, shActivation);
        (bytes32[] memory slots,) = trace.accesses(suite.owners[2]);
        bytes32[] memory values = new bytes32[](slots.length);
        require(
            slots.length == 4 && original.contestedAt == 0 && !original.abandoned,
            "actual non-abandoned estate closure uses its four packed owner slots"
        );
        for (uint256 i; i < slots.length; ++i) {
            bytes32 value = vm.load(suite.owners[2], slots[i]);
            require(
                value == artistId || value == shActivation || value == original.dismissalRecordHash
                    || value == bytes32(uint256(shWindow)),
                "read trace contains only exact original closure fields"
            );
            values[i] = value;
        }
        bytes32 pending =
            keccak256(abi.encode(ingress.identityTransitionClosure(artistId, shLastVeto)));
        bytes32 latest = ingress.latestIdentityContestDismissal(artistId);
        for (uint256 i; i < slots.length; ++i) {
            vm.store(suite.owners[2], slots[i], 0);
        }
        Dismissal.Closure memory empty;
        require(
            keccak256(abi.encode(ingress.identityTransitionClosure(artistId, shActivation)))
                    == keccak256(abi.encode(empty))
                && keccak256(abi.encode(ingress.identityTransitionClosure(artistId, shLastVeto)))
                == pending && ingress.latestIdentityContestDismissal(artistId) == latest,
            "only original estate closure is absent; pending closure and current dismissal remain"
        );
        vm.expectRevert(
            abi.encodeWithSelector(
                IdentityRecovery.UnsupportedIdentityRecoveryProfile.selector, artistId
            )
        );
        ingress.identityRecoveryContext(p, a);
        for (uint256 i; i < slots.length; ++i) {
            vm.store(suite.owners[2], slots[i], values[i]);
        }
        require(
            keccak256(abi.encode(ingress.identityRecoveryContext(p, a))) == expected,
            "restoring the exact complete estate closure restores identical context"
        );
    }

    function testStandingEstateRejectsForeignPendingClosureAndRotationThenRetries() public {
        this.historySetup(0, 4095, false);
        this.historyStandingEpisode(shWindow, 59241, 0);
        this.historyDismiss();
        this.historyStandingEpisode(shWindow + 1, 59242, keccak256("later standing"));
        this.historyDismiss();
        this.historyCompromise(shWindow + 2);
        (IdentityRecovery.Request memory p, T.Authorization memory a) = this.historyPrepare(59243);
        bytes32 expected = keccak256(abi.encode(ingress.identityRecoveryContext(p, a)));
        _emptyEstateClosureControl(p, a, expected);
        (bytes32 slot, bytes32 old) = _pendingClosureSlot(shRotations[0]);
        require(old != shDismissals[1], "distinct actual original and latest dismissals");
        vm.store(suite.owners[2], slot, shDismissals[1]);
        vm.expectRevert(
            abi.encodeWithSelector(
                IdentityRecovery.UnsupportedIdentityRecoveryProfile.selector, artistId
            )
        );
        ingress.identityRecoveryContext(p, a);
        vm.store(suite.owners[2], slot, old);
        require(
            keccak256(abi.encode(ingress.identityRecoveryContext(p, a))) == expected,
            "original pending closure restored exactly"
        );
        this.historyRegister(p, a);
        (slot, old) = _historySlot(shLastVeto, false);
        vm.store(suite.owners[2], slot, bytes32(uint256(uint160(address(0xDEAD1234)))));
        vm.expectRevert(
            abi.encodeWithSelector(
                IdentityRecovery.UnsupportedIdentityRecoveryProfile.selector, artistId
            )
        );
        this.executeRegistered(p, a);
        vm.store(suite.owners[2], slot, old);
        require(
            keccak256(abi.encode(ingress.identityRecoveryContext(p, a))) == expected,
            "original signed rotation and current context restored"
        );
        this.historyRecover(p, a, false);
    }

    function testEstateLivingParentCommitmentDriftRejectsAndIdenticalRetry() public {
        this.historySetup(2, 256, true);
        this.historyCompromise(shWindow);
        (IdentityRecovery.Request memory p, T.Authorization memory a) = this.historyPrepare(59251);
        bytes32 expected = keccak256(abi.encode(ingress.identityRecoveryContext(p, a)));
        (bytes32 slot, bytes32 old) = _historySlot(shLastRotation, true);
        vm.store(suite.owners[2], slot, keccak256("foreign original living commitment"));
        vm.expectRevert(
            abi.encodeWithSelector(
                IdentityRecovery.UnsupportedIdentityRecoveryProfile.selector, artistId
            )
        );
        ingress.identityRecoveryContext(p, a);
        vm.store(suite.owners[2], slot, old);
        require(
            keccak256(abi.encode(ingress.identityRecoveryContext(p, a))) == expected,
            "exact immediate parent restored"
        );
        this.historyRegister(p, a);
        (slot, old) = _historySlot(shRotations[0], true);
        vm.store(suite.owners[2], slot, keccak256("foreign earlier linked commitment"));
        vm.expectRevert(
            abi.encodeWithSelector(
                IdentityRecovery.UnsupportedIdentityRecoveryProfile.selector, artistId
            )
        );
        this.executeRegistered(p, a);
        vm.store(suite.owners[2], slot, old);
        require(
            keccak256(abi.encode(ingress.identityRecoveryContext(p, a))) == expected,
            "exact earlier parent join restored"
        );
        this.historyRecover(p, a, false);
    }
}

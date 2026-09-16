// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./StreamArtistEstateStandingHistoryActual.t.sol";
import {
    StreamArtistRecoveryEstateRotation
} from "../../../smart-contracts/domains/artist/StreamArtistRecoveryEstateRotation.sol";

/// @notice Actual op40 -> class3 op32 -> original op33 and registered op35, with full retained history.
/// @dev Artist/Safe/Archive are real; Core/governance facts and aggregate CREATE remain unit boundaries.
contract StreamArtistEstateRotatedRecoveryActualTest is
    StreamArtistEstateStandingHistoryActualTest
{
    bytes32 internal erOrigin;
    bytes32 internal erTerminal;
    bytes32 internal erGuardian;
    bytes32 internal erLower;
    bytes32 internal erOriginals;
    uint32 internal erCaps;
    OfficialSafe internal erLiving;
    uint256[] internal erLivingKeys;
    OfficialSafe internal erVeto;
    uint256[] internal erVetoKeys;
    uint64 internal erWindow;

    function rotatedEstateSetup(uint32 caps, bool early, bool freshGuardian, uint8 livingDepth)
        external
        onlySelf
    {
        erLiving = artist;
        erLivingKeys = keys;
        erCaps = caps;
        this.historySetup(livingDepth, caps, livingDepth != 0);
        erOrigin = ingress.currentAuthorityCapabilities(artistId).activationRecordHash;
        (,,, erGuardian) = ingress.guardianSet(artistId);
        this.historyWarp(ingress.artistTransitionState(erOrigin).postWindowEndsAt);
        this.rotatedEstateStage(erOrigin, early, 60101);
        if (freshGuardian) this.rotatedEstateGuardians();
        require(
            address(StreamArtistRecoveryEstateRotation).code.length <= 24576,
            "new proof library runtime fits"
        );
    }

    function rotatedEstateStage(bytes32 previous, bool early, uint256 salt) external onlySelf {
        _newRotationSafe(salt);
        erTerminal = _stageRotation(previous);
        R.RotationRecord memory staged = ingress.rotationRecord(erTerminal);
        if (early) {
            require(
                staged.approvalThreshold == 1 && staged.guardianApprovals == 0,
                "original captured guardian threshold"
            );
            require(
                executeSafe(
                    erLiving,
                    erLivingKeys,
                    address(ingress),
                    0,
                    abi.encodeCall(
                        IStreamArtistRotation.approveArtistRotation, (artistId, erTerminal)
                    ),
                    0
                ),
                "original living guardian Safe approves actual successor rotation"
            );
            ingress.executeArtistRotation(artistId, erTerminal);
        } else {
            _executeTimedRotation(erTerminal);
        }
        _adoptRotatedSafe();
        R.RotationRecord memory done = ingress.rotationRecord(erTerminal);
        V.Snapshot memory saved = _snapshot(erTerminal);
        erWindow = done.transition.postWindowEndsAt;
        require(
            saved.operationId == 32 && saved.authorityClass == 3
                && saved.previousTransitionRecordHash == previous
                && saved.previousCommitment == _snapshot(previous).commitment
                && saved.newAddress == address(artist) && done.transition.phase == 2
                && (early
                        ? done.transition.executedAt < done.transition.contestEndsAt
                        && done.guardianApprovals >= done.approvalThreshold
                        : done.transition.executedAt == done.transition.contestEndsAt),
            "original executed op32 keeps exact class3 vesting and actual timing/quorum"
        );
        require(
            ingress.currentAuthorityCapabilities(artistId).activationRecordHash == erOrigin
                && ingress.currentAuthorityCapabilities(artistId).effectiveCapabilities == erCaps,
            "rotation does not replace original estate capability origin"
        );
    }

    function rotatedEstateGuardians() external onlySelf {
        _newRotationSafe(60102);
        erVeto = rotationSafe;
        erVetoKeys = rotationKeys;
        address[] memory members = new address[](1);
        members[0] = address(erVeto);
        erLower = _guardianRecord(members, 1, 13 days, 1500);
        members[0] = address(artist);
        erGuardian = _guardianRecord(members, 1, 14 days, 1600);
        R.GuardianRecord memory g = ingress.guardianSetRecord(erGuardian);
        require(
            g.authorityClass == 3 && g.signer == address(artist)
                && g.provisional.transitionRecordHash == erTerminal
                && g.provisional.windowEndsAt == erWindow,
            "actual terminal successor guardian is provisional under its own rotation"
        );
    }

    function rotatedEstateCompromise(uint64 when) external onlySelf {
        vm.warp(when);
        ArtistUnitGovernance authority = ArtistUnitGovernance(manager.governanceAuthority());
        ArtistUnitRoles(suite.roleRegistry).setArbiter(address(artist), true);
        bytes32 evidence =
            keccak256(abi.encode("rotated estate original compromise", erTerminal, when));
        bytes32 reason = keccak256(abi.encode("rotated estate original reason", erTerminal, when));
        authority.configureContestReads(
            suite.roleRegistry, address(artist), reason, "urn:unit:rotated-estate"
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
            cause.facts.kind == 1 && cause.facts.authorityClass == 3 && cause.facts.priorStatus == 3
                && cause.facts.executedTransitionHash == erTerminal
                && cause.facts.incumbent == address(artist) && cause.facts.enteredAt == when
                && ingress.rotationRecord(erTerminal).transition.contestedAt == when
                && ingress.artistTransitionState(erOrigin).contestedAt == 0,
            "actual op33 names terminal rotation and leaves original estate untouched"
        );
    }

    function rotatedEstateRegister(IdentityRecovery.Request calldata p, T.Authorization calldata a)
        external
        onlySelf
    {
        GovernanceCall[] memory calls =
            _schedule(keccak256("rotated estate exact recovery action"), p, a);
        ingress.registerIdentityRecoveryAction(currentId, calls, p, a);
        (A.Association memory association,,, uint64 count) = _read();
        (GH.Head memory current,, GH.Snapshot memory saved,) = IStreamArtistGuardianHistory(
                suite.owners[2]
            ).guardianHistoryState(artistId, 0, address(0), currentId);
        require(
            count == current.count && saved.count == count
                && saved.historyCommitment == current.commitment
                && association.guardian.recordHash == erGuardian
                && association.contextHash
                    == keccak256(abi.encode(ingress.identityRecoveryContext(p, a))),
            "exact registered context retains complete history and eligible operational guardian"
        );
        erOriginals = _erHistory();
    }

    function _erHistory() internal view returns (bytes32) {
        (Estate.RequestRecord memory r, uint8 phase, Estate.ExecutionFacts memory x) =
            ingress.estateActivationRecord(erOrigin);
        return keccak256(
            abi.encode(
                r,
                phase,
                x,
                ingress.artistTransitionState(erOrigin),
                _snapshot(erOrigin),
                ingress.successorDesignationRecord(r.designationRecordHash),
                ingress.rotationRecord(erTerminal),
                _snapshot(erTerminal),
                ingress.guardianSetRecord(erGuardian),
                ingress.guardianSetRecord(erLower),
                ingress.identityTransitionClosure(artistId, erOrigin),
                ingress.identityTransitionClosure(artistId, erTerminal)
            )
        );
    }

    function rotatedEstateRecover(
        IdentityRecovery.Request calldata p,
        T.Authorization calldata a,
        bool retry
    ) external onlySelf {
        T.Identity memory old = IStreamArtistIdentityOwner(suite.owners[2]).identity(artistId);
        T.Snapshot memory before_ = _ownerSnapshot();
        uint64 epoch = ingress.identityRecoveryContext(p, a).delegationEpoch;
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
                !used && roots == _roots() && _erHistory() == erOriginals
                    && ingress.latestIdentityRecovery(artistId) == 0
                    && keccak256(abi.encode(old))
                        == keccak256(
                            abi.encode(
                                IStreamArtistIdentityOwner(suite.owners[2]).identity(artistId)
                            )
                        ),
                "late actual Archive failure restores exact authority/history/roots and unconsumed acceptance"
            );
            vm.roll(restoreBlock);
        }
        vm.recordLogs();
        bytes32 recovered = this.executeRegistered(p, a);
        V.Snapshot memory v = _snapshot(recovered);
        _assertSnapshot(v, 35, before_, vm.getRecordedLogs());
        Estate.AuthorityCapabilities memory rights = ingress.currentAuthorityCapabilities(artistId);
        (bool used,) = ingress.rotationAcceptanceNonceState(artistId, p.newAddress, a.nonce);
        (bytes32 primary, bytes32 occurrence, bytes32 secondary) =
            IStreamArtistIdentityRecoveryOwner(suite.owners[2]).identityRecoveryReceipts(recovered);
        require(
            rights.activationRecordHash == erOrigin && rights.authorityClass == 3
                && rights.status == 3 && rights.authorityAddress == p.newAddress
                && rights.effectiveCapabilities == erCaps
                && ingress.identityRecoveryRecord(recovered).delegationEpoch == epoch + 1
                && v.oldAddress == old.authorityAddress
                && v.previousTransitionRecordHash == erTerminal
                && v.previousCommitment == _snapshot(erTerminal).commitment
                && _erHistory() == erOriginals && used && primary != 0 && occurrence != 0
                && secondary != 0 && primary != secondary,
            "original registered op35 chains terminal vesting while preserving distinct estate origin and both receipts"
        );
        bytes32 after_ = _roots();
        vm.expectRevert(
            abi.encodeWithSelector(IdentityRecovery.InvalidIdentityRecovery.selector, artistId)
        );
        this.executeRegistered(p, a);
        require(
            after_ == _roots() && _erHistory() == erOriginals,
            "executed recovery replay cannot mutate history or Archive"
        );
    }

    function testRotatedEstateTimedRecoveryAndExactArchiveRetry() public {
        this.rotatedEstateSetup(4095, false, true, 0);
        this.rotatedEstateCompromise(erWindow);
        (IdentityRecovery.Request memory p, T.Authorization memory a) = this.historyPrepare(60111);
        this.rotatedEstateRegister(p, a);
        this.rotatedEstateRecover(p, a, true);
    }

    function testRotatedEstateEarlyGuardianQuorumPreservesZeroCapabilities() public {
        this.rotatedEstateSetup(0, true, false, 0);
        this.rotatedEstateCompromise(erWindow);
        (IdentityRecovery.Request memory p, T.Authorization memory a) = this.historyPrepare(60121);
        this.rotatedEstateRegister(p, a);
        this.rotatedEstateRecover(p, a, false);
    }

    function testRotatedEstateLivingAncestryAndLowerNonceLifetimeVeto() public {
        this.rotatedEstateSetup(4095, false, true, 2);
        this.rotatedEstateCompromise(erWindow);
        (IdentityRecovery.Request memory p, T.Authorization memory a) = this.historyPrepare(60131);
        this.rotatedEstateRegister(p, a);
        (, GH.Entry memory first,,) = IStreamArtistGuardianHistory(suite.owners[2])
            .guardianHistoryState(artistId, 1, address(0), 0);
        R.GuardianRecord memory original = ingress.guardianSetRecord(first.recordHash);
        OfficialSafe originalSafe = OfficialSafe(payable(original.terms.guardians[0]));
        uint256[] memory originalKeys = new uint256[](2);
        originalKeys[0] = 0xCA1100 + 59001;
        originalKeys[1] = 0xCA2200 + 59001;
        require(
            original.authorityClass == 1 && first.index <= _snapshot(erOrigin).guardians.count
                && original.nonce == 900
                && original.nonce < ingress.guardianSetRecord(erGuardian).nonce,
            "actual original living lower-nonce record survives both estate and terminal prefixes"
        );
        this.historyWarp(scheduled.notBefore);
        require(
            executeSafe(
                originalSafe,
                originalKeys,
                address(ingress),
                0,
                abi.encodeCall(
                    IStreamArtistRecoveryAction.vetoIdentityRecovery,
                    (artistId, keccak256("original lower nonce guardian veto"))
                ),
                0
            ),
            "original lower nonce Safe veto is retained through estate and rotation"
        );
        scheduled.status = GovernanceActionStatus.EXECUTED;
        _publish();
        vm.expectRevert(abi.encodeWithSelector(A.RecoveryActionVetoed.selector, currentId));
        this.executeRegistered(p, a);
        _inactive();
        (bool used,) = ingress.rotationAcceptanceNonceState(artistId, p.newAddress, a.nonce);
        require(
            !used && _erHistory() == erOriginals && ingress.latestIdentityRecovery(artistId) == 0,
            "veto preserves authority, history and acceptance"
        );
    }

    function _erCorrupt(
        IdentityRecovery.Request memory p,
        T.Authorization memory a,
        bytes32 id,
        uint8 field,
        bytes32 context
    ) internal {
        ClosedEstateStorageVm probe = ClosedEstateStorageVm(address(vm));
        probe.record();
        bytes32 original;
        if (field == 0) original = _snapshot(id).commitment;
        else if (field == 1) original = _snapshot(id).previousCommitment;
        else original = bytes32(uint256(uint160(ingress.rotationRecord(id).terms.oldAddress)));
        (bytes32[] memory slots,) = probe.accesses(suite.owners[2]);
        bytes32 slot;
        uint256 found;
        for (uint256 i; i < slots.length; ++i) {
            if (vm.load(suite.owners[2], slots[i]) == original) {
                slot = slots[i];
                ++found;
            }
        }
        require(original != 0 && found == 1, "one exact original storage field; no guessed layout");
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
            "same signed request context restored after exact field retry"
        );
    }

    function testRotatedEstateRejectsOriginParentAndTerminalDriftThenRetries() public {
        this.rotatedEstateSetup(4095, false, true, 0);
        this.rotatedEstateCompromise(erWindow);
        (IdentityRecovery.Request memory p, T.Authorization memory a) = this.historyPrepare(60141);
        bytes32 context = keccak256(abi.encode(ingress.identityRecoveryContext(p, a)));
        _erCorrupt(p, a, erOrigin, 0, context);
        _erCorrupt(p, a, erTerminal, 1, context);
        _erCorrupt(p, a, erTerminal, 2, context);
        this.rotatedEstateRegister(p, a);
        this.rotatedEstateRecover(p, a, false);
    }

    function testRotatedEstateRejectsCompromiseInsideTerminalWindow() public {
        this.rotatedEstateSetup(4095, false, true, 0);
        this.rotatedEstateCompromise(erWindow - 1);
        (IdentityRecovery.Request memory p, T.Authorization memory a) = this.historyPrepare(60151);
        bytes32 old = _erHistory();
        vm.expectRevert(
            abi.encodeWithSelector(
                IdentityRecovery.UnsupportedIdentityRecoveryProfile.selector, artistId
            )
        );
        ingress.identityRecoveryContext(p, a);
        (bool used,) = ingress.rotationAcceptanceNonceState(artistId, p.newAddress, a.nonce);
        require(
            !used && _erHistory() == old && ingress.latestIdentityRecovery(artistId) == 0,
            "earlier estate expiry never matures a contested terminal cohort"
        );
        this.historyWarp(erWindow + 1);
        vm.expectRevert(
            abi.encodeWithSelector(
                IdentityRecovery.UnsupportedIdentityRecoveryProfile.selector, artistId
            )
        );
        ingress.identityRecoveryContext(p, a);
        require(
            _erHistory() == old && ingress.latestIdentityRecovery(artistId) == 0,
            "same signed request remains invalid after waiting past terminal expiry"
        );
    }

    function testRotatedEstateAuthenticatesAnExtraExecutedSuccessorDepth() public {
        this.rotatedEstateSetup(0, false, false, 0);
        this.historyWarp(erWindow);
        this.rotatedEstateStage(erTerminal, false, 60161);
        this.rotatedEstateCompromise(erWindow);
        (IdentityRecovery.Request memory p, T.Authorization memory a) = this.historyPrepare(60162);
        bytes32 context = keccak256(abi.encode(ingress.identityRecoveryContext(p, a)));
        _erCorrupt(p, a, erTerminal, 1, context);
        this.rotatedEstateRegister(p, a);
        this.rotatedEstateRecover(p, a, true);
    }
}

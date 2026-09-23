// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./StreamArtistEstateSuccessorGuardianRecoveryActual.t.sol";

/// @notice Actual accelerated op40, retained guardian history, Safe acceptance/veto and op35 Archive effects.
/// @dev Core/action facts and the archival-to-Artist governance role phases remain explicit unit boundaries.
/// This cohort does not prove the full delayed Executor deployment or arbitrary closed/later estate histories.
contract StreamArtistAcceleratedEstateRecoveryActualTest is
    StreamArtistEstateSuccessorGuardianRecoveryActualTest
{
    bytes32 private activation;
    bytes32 private originalGuardian;
    bytes32 private selectedGuardian;
    bytes32 private lowerGuardian;
    bytes32 private originals;
    address private living;
    address private successor;
    uint64 private windowEnd;
    OfficialSafe private vetoSafe;
    uint256[] private vetoKeys;

    function _accelerate(uint32 capabilities) private {
        _sizes();
        living = address(artist);
        _delegateSetup();
        address[] memory members = new address[](1);
        members[0] = living;
        originalGuardian = _guardianRecord(members, 1, 10 days, 900);
        selectedGuardian = originalGuardian;
        Estate.Execution memory p = _estatePendingFixture(capabilities);
        activation = p.expectedActivationRecordHash;
        (Estate.RequestRecord memory requested,,) = ingress.estateActivationRecord(activation);
        require(block.timestamp < requested.noticeEndsAt, "actual early execution boundary");
        this.executeEstateAccelerator(p, 1, 0);
        (Estate.RequestRecord memory saved, uint8 phase, Estate.ExecutionFacts memory executed) =
            ingress.estateActivationRecord(activation);
        require(
            phase == 2 && executed.executedAt >= saved.requestedAt
                && executed.executedAt < saved.noticeEndsAt
                && executed.governanceActionId == keccak256("unit authority gas raise")
                && executed.governanceWitnessHash != 0
                && keccak256(abi.encode(saved)) == keccak256(abi.encode(requested)),
            "actual admitted accelerator retained without rewriting original notice"
        );
        artist = delegateSafe;
        keys = delegateKeys;
        successor = address(artist);
        nextNonce = IStreamArtistIdentityOwner(suite.owners[2]).identity(artistId).nonceHint;
        V.Snapshot memory v = _snapshot(activation);
        windowEnd = ingress.artistTransitionState(activation).postWindowEndsAt;
        require(
            v.operationId == 40 && v.authorityClass == 3 && v.oldAddress == living
                && v.newAddress == successor && v.guardians.count == 1
                && v.previousTransitionRecordHash == 0 && v.previousCommitment == 0
                && windowEnd == executed.executedAt + requested.postContestSeconds,
            "original op40 vesting and full post-activation window"
        );
    }

    function _successorHistory() private {
        _newRotationSafe(57001);
        vetoSafe = rotationSafe;
        vetoKeys = rotationKeys;
        address[] memory members = new address[](2);
        members[0] = living;
        members[1] = successor;
        if (members[0] > members[1]) (members[0], members[1]) = (members[1], members[0]);
        selectedGuardian = _guardianRecord(members, 1, 20 days, 1200);
        members[0] = living;
        members[1] = address(vetoSafe);
        if (members[0] > members[1]) (members[0], members[1]) = (members[1], members[0]);
        lowerGuardian = _guardianRecord(members, 1, 15 days, 1100);
        R.GuardianRecord memory g = ingress.guardianSetRecord(selectedGuardian);
        (GH.Head memory head, GH.Entry memory entry,,) = IStreamArtistGuardianHistory(
                suite.owners[2]
            ).guardianHistoryState(artistId, 2, address(0), 0);
        require(
            head.count == 3 && entry.recordHash == selectedGuardian
                && entry.ownerRevision > _snapshot(activation).ownerRevision
                && g.authorityClass == 3 && g.signer == successor
                && g.provisional.transitionRecordHash == activation
                && g.provisional.windowEndsAt == windowEnd,
            "actual successor post-vesting prefix uses original accelerated window"
        );
        (,,, bytes32 beforeExpiry) = ingress.guardianSet(artistId);
        require(
            beforeExpiry == originalGuardian,
            "successor record cannot vest before original post-window expiry"
        );
    }

    function _compromise(uint64 when) private {
        vm.warp(when);
        _newRotationSafe(57002);
        ArtistUnitGovernance authority = ArtistUnitGovernance(manager.governanceAuthority());
        ArtistUnitRoles(suite.roleRegistry).setArbiter(successor, true);
        authority.configureContestReads(
            suite.roleRegistry,
            successor,
            keccak256("compromise reason"),
            "urn:unit:accelerated-estate-recovery"
        );
        (bytes32 scope, bytes32 oldHash, bytes32 newHash) = ingress.identityContestGovernanceContext(
            artistId, activation, keccak256("compromise evidence"), keccak256("compromise reason")
        );
        authority.executeModuleContext(
            address(ingress), _contestData(activation), 1, scope, oldHash, newHash
        );
        Dismissal.Cause memory cause = ingress.currentIdentityContestCause(artistId);
        require(
            cause.facts.authorityClass == 3 && cause.facts.priorStatus == 3
                && cause.facts.incumbent == successor
                && cause.facts.executedTransitionHash == activation
                && cause.facts.enteredAt == when,
            "original class3 compromise cause retains exact activation and time"
        );
        originals = _originalHash();
    }

    function _originalHash() private view returns (bytes32) {
        (Estate.RequestRecord memory r, uint8 phase, Estate.ExecutionFacts memory x) =
            ingress.estateActivationRecord(activation);
        return keccak256(
            abi.encode(
                r,
                phase,
                x,
                ingress.artistTransitionState(activation),
                _snapshot(activation),
                ingress.guardianSetRecord(originalGuardian),
                ingress.guardianSetRecord(selectedGuardian),
                ingress.guardianSetRecord(lowerGuardian),
                ingress.successorDesignationRecord(r.designationRecordHash),
                ingress.operativeSuccessorRecord(artistId),
                ingress.operativeEstateDirective(artistId)
            )
        );
    }

    function _acceleratedTerms() private view returns (IdentityRecovery.Request memory p) {
        Dismissal.Cause memory cause = ingress.currentIdentityContestCause(artistId);
        p = IdentityRecovery.Request(
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

    function _registerAccelerated(IdentityRecovery.Request memory p, T.Authorization memory a)
        private
    {
        GovernanceCall[] memory calls =
            _schedule(keccak256("original accelerated estate recovery action"), p, a);
        ingress.registerIdentityRecoveryAction(currentId, calls, p, a);
        (A.Association memory association,,, uint64 count) = _read();
        (GH.Head memory head,, GH.Snapshot memory history,) = IStreamArtistGuardianHistory(
                suite.owners[2]
            ).guardianHistoryState(artistId, 0, address(0), currentId);
        require(
            count == (lowerGuardian == 0 ? 1 : 3) && history.count == count && head.count == count
                && history.historyCommitment == head.commitment
                && history.associationHash == association.associationHash
                && association.guardian.recordHash == selectedGuardian
                && association.contextHash
                    == keccak256(abi.encode(ingress.identityRecoveryContext(p, a))),
            "exact original accelerated predecessor and complete current guardian prefix frozen"
        );
    }

    function _publishExecutable() private {
        vm.warp(scheduled.notBefore);
        scheduled.status = GovernanceActionStatus.EXECUTED;
        _publish();
    }

    function _assertAcceleratedRecovery(
        bytes32 recovered,
        IdentityRecovery.Request memory p,
        uint32 capabilities,
        T.Identity memory prior,
        uint64 epoch
    ) private view {
        T.Identity memory principal = IStreamArtistIdentityOwner(suite.owners[2]).identity(artistId);
        Estate.AuthorityCapabilities memory rights = ingress.currentAuthorityCapabilities(artistId);
        IdentityRecovery.Record memory r = ingress.identityRecoveryRecord(recovered);
        V.Snapshot memory v = _snapshot(recovered);
        V.Snapshot memory original = _snapshot(activation);
        (GH.Head memory current,,,) = IStreamArtistGuardianHistory(suite.owners[2])
            .guardianHistoryState(artistId, 0, address(0), 0);
        require(
            principal.authorityAddress == p.newAddress && principal.authorityClass == 3
                && principal.status == 3 && principal.identityRecordHash == prior.identityRecordHash
                && principal.lastAuthorityActionAt == prior.lastAuthorityActionAt
                && rights.activationRecordHash == activation
                && rights.effectiveCapabilities == capabilities
                && rights.authorityAddress == p.newAddress && r.fields.vestedAuthorityClass == 3
                && r.fields.oldAddress == successor && r.fields.newAddress == p.newAddress
                && r.delegationEpoch == epoch + 1,
            "recovered successor retains original accelerated activation and bounded capabilities"
        );
        require(
            v.operationId == 35 && v.authorityClass == 3
                && v.previousTransitionRecordHash == activation
                && v.previousCommitment == original.commitment
                && keccak256(abi.encode(v.guardians)) == keccak256(abi.encode(current))
                && _originalHash() == originals,
            "new vesting chains exact immutable accelerated history and current guardian prefix"
        );
        (bytes32 primary, bytes32 occurrence, bytes32 secondary) =
            IStreamArtistIdentityRecoveryOwner(suite.owners[2]).identityRecoveryReceipts(recovered);
        require(
            primary != 0 && occurrence != 0 && secondary != 0 && primary != secondary,
            "two original ordered Archive receipts"
        );
        (bool livingRevoked, bytes32 livingRetirement) =
            ingress.priorAddressStandingRevoked(artistId, living);
        (bool successorRevoked, bytes32 successorRetirement) =
            ingress.priorAddressStandingRevoked(artistId, successor);
        require(
            !livingRevoked && !successorRevoked && livingRetirement == 0
                && successorRetirement == 0,
            "both actual prior principals retain standing"
        );
    }

    function testAcceleratedEstateRecoveryExtendedHistoryAndIdenticalArchiveRetry() public {
        _accelerate(256);
        _successorHistory();
        _compromise(windowEnd);
        IdentityRecovery.Request memory p = _acceleratedTerms();
        T.Authorization memory a = _acceptance(p);
        IdentityRecovery.Context memory context = ingress.identityRecoveryContext(p, a);
        _registerAccelerated(p, a);
        _publishExecutable();
        T.Identity memory prior = IStreamArtistIdentityOwner(suite.owners[2]).identity(artistId);
        T.Snapshot memory before_ = _ownerSnapshot();
        bytes32 roots = _roots();
        _overflow();
        this.executeRegistered(p, a);
        _inactive();
        (bool used,) = ingress.rotationAcceptanceNonceState(artistId, p.newAddress, a.nonce);
        require(
            !used && _roots() == roots && ingress.latestIdentityRecovery(artistId) == 0
                && keccak256(
                        abi.encode(IStreamArtistIdentityOwner(suite.owners[2]).identity(artistId))
                    ) == keccak256(abi.encode(prior)) && _originalHash() == originals,
            "late Archive failure preserves signed acceptance, original witness, identity and all history"
        );
        vm.roll(restoreBlock);
        vm.recordLogs();
        bytes32 recovered = this.executeRegistered(p, a);
        _assertSnapshot(_snapshot(recovered), 35, before_, vm.getRecordedLogs());
        _assertAcceleratedRecovery(recovered, p, 256, prior, context.delegationEpoch);
        (used,) = ingress.rotationAcceptanceNonceState(artistId, p.newAddress, a.nonce);
        require(used, "identical signed Safe acceptance consumed only by successful recovery");
    }

    function testAcceleratedEstateLowerNonceSuccessorSafeRetainsLifetimeVeto() public {
        _accelerate(256);
        _successorHistory();
        _compromise(windowEnd);
        IdentityRecovery.Request memory p = _acceleratedTerms();
        T.Authorization memory a = _acceptance(p);
        _registerAccelerated(p, a);
        (,,, uint64 earliest) = IStreamArtistGuardianHistory(suite.owners[2])
            .guardianHistoryState(artistId, 0, address(vetoSafe), currentId);
        require(
            earliest == 3 && earliest > _snapshot(activation).guardians.count,
            "guardian only occurs in lower-nonce successor history"
        );
        vm.warp(scheduled.notBefore);
        require(
            executeSafe(
                vetoSafe,
                vetoKeys,
                address(ingress),
                0,
                abi.encodeCall(
                    IStreamArtistRecoveryAction.vetoIdentityRecovery,
                    (artistId, keccak256("accelerated estate lifetime veto"))
                ),
                0
            ),
            "actual historical guardian Safe veto after notBefore"
        );
        bytes32 roots = _roots();
        scheduled.status = GovernanceActionStatus.EXECUTED;
        _publish();
        vm.expectRevert(abi.encodeWithSelector(A.RecoveryActionVetoed.selector, currentId));
        this.executeRegistered(p, a);
        _inactive();
        (bool used,) = ingress.rotationAcceptanceNonceState(artistId, p.newAddress, a.nonce);
        require(
            !used && _roots() == roots && _originalHash() == originals
                && ingress.latestIdentityRecovery(artistId) == 0,
            "unsuperseded prefix veto prevents nonce, witness or authority mutation"
        );
    }

    function testAcceleratedEstateInWindowCompromiseNeverMaturesByElapsedTime() public {
        _accelerate(256);
        _successorHistory();
        _compromise(windowEnd - 1);
        IdentityRecovery.Request memory p = _acceleratedTerms();
        T.Authorization memory a = _acceptance(p);
        bytes32 roots = _roots();
        vm.expectRevert(
            abi.encodeWithSelector(
                IdentityRecovery.UnsupportedIdentityRecoveryProfile.selector, artistId
            )
        );
        ingress.identityRecoveryContext(p, a);
        vm.warp(windowEnd + 1);
        vm.expectRevert(
            abi.encodeWithSelector(
                IdentityRecovery.UnsupportedIdentityRecoveryProfile.selector, artistId
            )
        );
        ingress.identityRecoveryContext(p, a);
        (,,, bytes32 operative) = ingress.guardianSet(artistId);
        require(
            operative == originalGuardian && _roots() == roots && _originalHash() == originals,
            "permanently contested successor cohort cannot silently mature or recover"
        );
    }

    function testAcceleratedZeroCapabilityRecoveryCannotBecomeLivingAuthority() public {
        _accelerate(0);
        _compromise(windowEnd);
        IdentityRecovery.Request memory p = _acceleratedTerms();
        T.Authorization memory a = _acceptance(p);
        p.vestedAuthorityClass = 1;
        vm.expectRevert(
            abi.encodeWithSelector(
                IdentityRecovery.UnsupportedIdentityRecoveryProfile.selector, artistId
            )
        );
        ingress.identityRecoveryContext(p, a);
        p.vestedAuthorityClass = 3;
        IdentityRecovery.Context memory c = ingress.identityRecoveryContext(p, a);
        _registerAccelerated(p, a);
        T.Identity memory prior = IStreamArtistIdentityOwner(suite.owners[2]).identity(artistId);
        _publishExecutable();
        bytes32 recovered = this.executeRegistered(p, a);
        _assertAcceleratedRecovery(recovered, p, 0, prior, c.delegationEpoch);
        _adoptRotatedSafe();
        bytes32 roots = _roots();
        vm.expectRevert(
            abi.encodeWithSelector(
                Estate.EstateCapabilityUnavailable.selector, artistId, uint32(256)
            )
        );
        this.publishAcceleratedGuardian();
        require(
            _roots() == roots
                && ingress.currentAuthorityCapabilities(artistId).effectiveCapabilities == 0,
            "zero original capability remains zero after class3 recovery"
        );
    }

    function publishAcceleratedGuardian() external returns (bytes32) {
        require(msg.sender == address(this), "test wrapper only");
        address[] memory members = new address[](2);
        members[0] = living;
        members[1] = address(artist);
        if (members[0] > members[1]) (members[0], members[1]) = (members[1], members[0]);
        return _guardianRecord(members, 1, 10 days, nextNonce);
    }
}

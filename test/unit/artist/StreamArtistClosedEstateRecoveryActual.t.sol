// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./StreamArtistAcceleratedEstateRecoveryActual.t.sol";

interface ClosedEstateStorageVm {
    function record() external;
    function accesses(address target)
        external
        returns (bytes32[] memory reads, bytes32[] memory writes);
}

/// @notice Actual op40/op33/op41 history followed by registered op35 and original Safe/Archive effects.
/// @dev Aggregate unit Core and governance facts remain explicit boundaries. Only original kind-1
/// compromise closures are covered; standing-contest closures and later activations remain separate.
contract StreamArtistClosedEstateRecoveryActualTest is
    StreamArtistAcceleratedEstateRecoveryActualTest
{
    bytes32 private ceActivation;
    bytes32 private ceOriginalGuardian;
    bytes32 private ceCandidateGuardian;
    bytes32 private ceLowerGuardian;
    bytes32 private ceSelectedGuardian;
    bytes32 private ceCandidateDocument;
    bytes32 private ceCandidatePayout;
    bytes32 private ceOriginalDocument;
    bytes32 private ceOriginalPayout;
    bytes32 private ceFirstDismissal;
    bytes32 private ceLatestDismissal;
    bytes32 private ceOriginals;
    address private ceLiving;
    address private ceSuccessor;
    address private cePayout;
    uint64 private ceWindow;
    uint32 private ceCapabilities;
    OfficialSafe private ceVetoSafe;
    uint256[] private ceVetoKeys;

    function _ceActivate(uint32 caps, bool accelerated) private {
        _sizes();
        ceCapabilities = caps;
        ceLiving = address(artist);
        _delegateSetup();
        address[] memory members = new address[](1);
        members[0] = ceLiving;
        ceOriginalGuardian = _guardianRecord(members, 1, 10 days, 900);
        ceSelectedGuardian = ceOriginalGuardian;
        ceOriginalDocument = ingress.operativeIdentityRecord(artistId);
        (cePayout, ceOriginalPayout) = ingress.artistPayoutAccount(artistId);
        Estate.Execution memory p = _estatePendingFixture(caps);
        ceActivation = p.expectedActivationRecordHash;
        (Estate.RequestRecord memory request,,) = ingress.estateActivationRecord(ceActivation);
        if (accelerated) {
            this.executeEstateAccelerator(p, 1, 0);
        } else {
            vm.warp(request.noticeEndsAt);
            ingress.executeEstateActivation(p);
        }
        artist = delegateSafe;
        keys = delegateKeys;
        ceSuccessor = address(artist);
        nextNonce = IStreamArtistIdentityOwner(suite.owners[2]).identity(artistId).nonceHint;
        (, uint8 phase, Estate.ExecutionFacts memory executed) =
            ingress.estateActivationRecord(ceActivation);
        require(
            phase == 2
                && (accelerated
                        ? executed.executedAt < request.noticeEndsAt
                        && executed.governanceWitnessHash != 0
                        : executed.executedAt == request.noticeEndsAt
                        && executed.governanceWitnessHash == 0),
            "actual original estate execution mode"
        );
        ceWindow = ingress.artistTransitionState(ceActivation).postWindowEndsAt;
        V.Snapshot memory saved = _snapshot(ceActivation);
        require(
            saved.operationId == 40 && saved.authorityClass == 3
                && saved.previousTransitionRecordHash == 0 && saved.guardians.count == 1,
            "original first estate and retained guardian prefix"
        );
    }

    function _ceMembers(address extra) private view returns (address[] memory members) {
        members = new address[](2);
        members[0] = ceLiving;
        members[1] = extra;
        if (members[0] > members[1]) (members[0], members[1]) = (members[1], members[0]);
    }

    function _ceCandidates(bool documents) private {
        _newRotationSafe(58001);
        ceVetoSafe = rotationSafe;
        ceVetoKeys = rotationKeys;
        ceCandidateGuardian = _guardianRecord(_ceMembers(ceSuccessor), 1, 20 days, 1200);
        ceLowerGuardian = _guardianRecord(_ceMembers(address(ceVetoSafe)), 1, 15 days, 1100);
        if (documents) {
            ceCandidateDocument = _reviseDocument(bytes("closed estate provisional document"));
            ceCandidatePayout = _dismissalPayout(address(0xCE01));
        }
        require(
            ingress.guardianSetRecord(ceCandidateGuardian).provisional.transitionRecordHash
                    == ceActivation
                && ingress.guardianSetRecord(ceLowerGuardian).provisional.windowEndsAt == ceWindow,
            "actual provisional higher and lower nonce records"
        );
    }

    // External helper keeps each observed block time across the Foundry warp boundary.
    function closedEstateCompromiseAt(uint64 when) external {
        require(msg.sender == address(this), "test wrapper only");
        vm.warp(when);
        ArtistUnitGovernance authority = ArtistUnitGovernance(manager.governanceAuthority());
        ArtistUnitRoles(suite.roleRegistry).setArbiter(ceSuccessor, true);
        bytes32 evidence = keccak256(abi.encode("closed estate episode evidence", when));
        bytes32 reason = keccak256(abi.encode("closed estate episode reason", when));
        authority.configureContestReads(
            suite.roleRegistry, ceSuccessor, reason, "urn:unit:closed-estate"
        );
        (bytes32 scope, bytes32 oldHash, bytes32 newHash) =
            ingress.identityContestGovernanceContext(artistId, ceActivation, evidence, reason);
        authority.executeModuleContext(
            address(ingress),
            abi.encodeCall(
                IStreamArtistIdentityContest.contestArtistIdentity,
                (artistId, ceActivation, evidence, reason)
            ),
            1,
            scope,
            oldHash,
            newHash
        );
        Dismissal.Cause memory cause = ingress.currentIdentityContestCause(artistId);
        require(
            cause.facts.kind == 1 && cause.facts.authorityClass == 3 && cause.facts.priorStatus == 3
                && cause.facts.enteredAt == when && cause.facts.evidenceHash == evidence
                && cause.facts.reasonHash == reason
                && cause.facts.executedTransitionHash == ceActivation,
            "actual original op33 cause with class3 incumbent"
        );
    }

    function _ceDismiss(bool abandoned) private {
        Dismissal.Request memory p = _dismissalRequest();
        bytes32 hash = _dismissalExecute(p, 1, 0);
        Dismissal.Record memory record = ingress.identityContestDismissalRecord(hash);
        Dismissal.Cause memory cause = ingress.identityContestCause(p.expectedCauseHash);
        require(
            hash != 0 && record.recordHash == hash && record.authorityClass == 3
                && record.restoredStatus == 3 && record.incumbent == ceSuccessor
                && record.actionId != 0 && record.governanceWitnessHash != 0
                && record.terms.expectedResolutionHash == ceLatestDismissal
                && cause.facts.previousResolutionHash == ceLatestDismissal,
            "actual original op41 admission and previous resolution chain"
        );
        ceLatestDismissal = hash;
        if (ceFirstDismissal == 0) ceFirstDismissal = hash;
        Dismissal.Closure memory closed = ingress.identityTransitionClosure(artistId, ceActivation);
        require(
            closed.dismissalRecordHash == ceFirstDismissal
                && closed.transitionRecordHash == ceActivation && closed.abandoned == abandoned
                && closed.windowEndsAt == ceWindow
                && closed.contestedAt == ingress.artistTransitionState(ceActivation).contestedAt,
            "first closure is immutable through each actual dismissal"
        );
        require(
            ingress.currentAuthorityCapabilities(artistId).status == 3,
            "actual dismissal restores original estate authority"
        );
    }

    function _ceFreshGuardian() private {
        ceSelectedGuardian = _guardianRecord(_ceMembers(ceSuccessor), 1, 20 days, 1300);
        R.GuardianRecord memory g = ingress.guardianSetRecord(ceSelectedGuardian);
        (,,, bytes32 selected) = ingress.guardianSet(artistId);
        require(
            g.authorityClass == 3 && g.signer == ceSuccessor
                && g.provisional.transitionRecordHash == 0 && g.provisional.windowEndsAt == 0
                && selected == ceSelectedGuardian,
            "fresh post-dismissal class3 guardian is stable before old window end"
        );
    }

    function _ceAssertAbandoned() private view {
        if (ceCandidateGuardian == 0) return;
        (,,, bytes32 selected) = ingress.guardianSet(artistId);
        require(
            selected == ceSelectedGuardian && selected != ceCandidateGuardian
                && selected != ceLowerGuardian,
            "abandoned guardians never become operative"
        );
        require(
            ingress.guardianSetRecord(ceCandidateGuardian).provisional.transitionRecordHash
                    == ceActivation
                && ingress.guardianSetRecord(ceLowerGuardian).provisional.transitionRecordHash
                == ceActivation,
            "abandoned records keep original permanent associations"
        );
        if (ceCandidateDocument != 0) {
            (address payout, bytes32 payoutRecord) = ingress.artistPayoutAccount(artistId);
            require(
                ingress.operativeIdentityRecord(artistId) == ceOriginalDocument
                    && payout == cePayout && payoutRecord == ceOriginalPayout
                    && ingress.identityRevisionProvisionalAssociation(ceCandidateDocument)
                    .transitionRecordHash == ceActivation
                    && ingress.payoutDesignationProvisionalAssociation(ceCandidatePayout)
                    .transitionRecordHash == ceActivation,
                "original document and payout remain selected; abandoned candidates stay archived"
            );
        }
    }

    function _ceHistoricalHash() private view returns (bytes32) {
        (Estate.RequestRecord memory r, uint8 phase, Estate.ExecutionFacts memory x) =
            ingress.estateActivationRecord(ceActivation);
        return keccak256(
            abi.encode(
                r,
                phase,
                x,
                ingress.artistTransitionState(ceActivation),
                _snapshot(ceActivation),
                ingress.identityTransitionClosure(artistId, ceActivation),
                ingress.identityContestDismissalRecord(ceFirstDismissal),
                ingress.identityContestDismissalRecord(ceLatestDismissal),
                ingress.guardianSetRecord(ceOriginalGuardian),
                ingress.guardianSetRecord(ceCandidateGuardian),
                ingress.guardianSetRecord(ceLowerGuardian),
                ingress.guardianSetRecord(ceSelectedGuardian),
                ingress.successorDesignationRecord(r.designationRecordHash)
            )
        );
    }

    function _ceTerms() private view returns (IdentityRecovery.Request memory p) {
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

    function _ceRegister(IdentityRecovery.Request memory p, T.Authorization memory a) private {
        GovernanceCall[] memory calls =
            _schedule(keccak256("closed estate original recovery"), p, a);
        ingress.registerIdentityRecoveryAction(currentId, calls, p, a);
        (A.Association memory association,,, uint64 count) = _read();
        (GH.Head memory head,, GH.Snapshot memory history,) = IStreamArtistGuardianHistory(
                suite.owners[2]
            ).guardianHistoryState(artistId, 0, address(0), currentId);
        require(
            count == head.count && history.count == count
                && history.historyCommitment == head.commitment
                && association.guardian.recordHash == ceSelectedGuardian
                && association.contextHash
                    == keccak256(abi.encode(ingress.identityRecoveryContext(p, a))),
            "original registered context binds closed proof and complete retained guardian history"
        );
        ceOriginals = _ceHistoricalHash();
    }

    function _ceReady() private {
        vm.warp(scheduled.notBefore);
        scheduled.status = GovernanceActionStatus.EXECUTED;
        _publish();
    }

    function _ceRecover(
        IdentityRecovery.Request memory p,
        T.Authorization memory a,
        bool archiveRetry
    ) private {
        T.Identity memory prior = IStreamArtistIdentityOwner(suite.owners[2]).identity(artistId);
        T.Snapshot memory before_ = _ownerSnapshot();
        uint64 epoch = ingress.identityRecoveryContext(p, a).delegationEpoch;
        _ceReady();
        _ceAssertAbandoned();
        if (archiveRetry) {
            bytes32 roots = _roots();
            _overflow();
            this.executeRegistered(p, a);
            _inactive();
            (bool used,) = ingress.rotationAcceptanceNonceState(artistId, p.newAddress, a.nonce);
            require(
                !used && _roots() == roots && ingress.latestIdentityRecovery(artistId) == 0
                    && _ceHistoricalHash() == ceOriginals
                    && keccak256(
                        abi.encode(IStreamArtistIdentityOwner(suite.owners[2]).identity(artistId))
                    ) == keccak256(abi.encode(prior)),
                "late real Archive failure rolls back nonce authority and full history"
            );
            vm.roll(restoreBlock);
        }
        vm.recordLogs();
        bytes32 recovered = this.executeRegistered(p, a);
        _assertSnapshot(_snapshot(recovered), 35, before_, vm.getRecordedLogs());
        Estate.AuthorityCapabilities memory rights = ingress.currentAuthorityCapabilities(artistId);
        IdentityRecovery.Record memory r = ingress.identityRecoveryRecord(recovered);
        V.Snapshot memory v = _snapshot(recovered);
        require(
            rights.activationRecordHash == ceActivation && rights.authorityClass == 3
                && rights.status == 3 && rights.authorityAddress == p.newAddress
                && rights.effectiveCapabilities == ceCapabilities
                && r.fields.oldAddress == ceSuccessor && r.fields.newAddress == p.newAddress
                && r.delegationEpoch == epoch + 1 && v.previousTransitionRecordHash == ceActivation
                && v.previousCommitment == _snapshot(ceActivation).commitment
                && _ceHistoricalHash() == ceOriginals,
            "recovery preserves original estate closure capabilities and predecessor commitments"
        );
        (bytes32 primary, bytes32 occurrence, bytes32 secondary) =
            IStreamArtistIdentityRecoveryOwner(suite.owners[2]).identityRecoveryReceipts(recovered);
        (bool consumed,) = ingress.rotationAcceptanceNonceState(artistId, p.newAddress, a.nonce);
        require(
            consumed && primary != 0 && occurrence != 0 && secondary != 0 && primary != secondary,
            "original Safe acceptance consumed with both real ordered Archive receipts"
        );
        _ceAssertAbandoned();
    }

    function closedEstateActivate(uint32 caps, bool accelerated) external {
        require(msg.sender == address(this), "test wrapper only");
        _ceActivate(caps, accelerated);
    }

    function closedEstateCandidates(bool documents) external {
        require(msg.sender == address(this), "test wrapper only");
        _ceCandidates(documents);
    }

    function closedEstateDismiss(bool abandoned) external {
        require(msg.sender == address(this), "test wrapper only");
        _ceDismiss(abandoned);
    }

    function closedEstateFreshGuardian() external {
        require(msg.sender == address(this), "test wrapper only");
        _ceFreshGuardian();
    }

    function closedEstateAcceptance(IdentityRecovery.Request calldata p)
        external
        returns (T.Authorization memory)
    {
        require(msg.sender == address(this), "test wrapper only");
        return _acceptance(p);
    }

    function closedEstateRegister(IdentityRecovery.Request calldata p, T.Authorization calldata a)
        external
    {
        require(msg.sender == address(this), "test wrapper only");
        _ceRegister(p, a);
    }

    function closedEstateRecover(
        IdentityRecovery.Request calldata p,
        T.Authorization calldata a,
        bool retry
    ) external {
        require(msg.sender == address(this), "test wrapper only");
        _ceRecover(p, a, retry);
    }

    function testClosedEstateEarlyDismissalFreshGuardianAndArchiveRetry() public {
        this.closedEstateActivate(4095, false);
        this.closedEstateCandidates(true);
        uint64 first = ingress.artistTransitionState(ceActivation).executedAt + 1;
        this.closedEstateCompromiseAt(first);
        this.closedEstateDismiss(true);
        bytes32 retained = _ceHistoricalHash();
        try this.closedEstateCompromiseAt(first) {
            revert("original subject tuple must remain replay-protected after dismissal");
        } catch (bytes memory error) {
            require(
                error.length == 36 && bytes4(error) == T.Replay.selector,
                "same original op33 subject tuple rejects with actual replay error"
            );
        }
        require(
            _ceHistoricalHash() == retained
                && ingress.currentAuthorityCapabilities(artistId).status == 3,
            "failed repeated subject leaves original dismissal and authority unchanged"
        );
        this.closedEstateFreshGuardian();
        this.closedEstateCompromiseAt(first + 1);
        _newRotationSafe(58002);
        IdentityRecovery.Request memory p = _ceTerms();
        T.Authorization memory a = this.closedEstateAcceptance(p);
        require(
            ingress.currentIdentityContestCause(artistId).facts.enteredAt < ceWindow,
            "new cause and preparation precede old window after authenticated early closure"
        );
        this.closedEstateRegister(p, a);
        require(
            scheduled.notBefore >= first + 1 + 72 hours,
            "new recovery keeps its full governance delay"
        );
        this.closedEstateRecover(p, a, true);
    }

    function testClosedAcceleratedEstateInterveningDismissalUsesLatestHead() public {
        this.closedEstateActivate(256, true);
        this.closedEstateCandidates(false);
        uint64 first = ingress.artistTransitionState(ceActivation).executedAt + 1;
        this.closedEstateCompromiseAt(first);
        this.closedEstateDismiss(true);
        this.closedEstateCompromiseAt(first + 1);
        this.closedEstateDismiss(true);
        require(
            ceLatestDismissal != ceFirstDismissal, "two distinct actual admitted dismissal records"
        );
        this.closedEstateFreshGuardian();
        this.closedEstateCompromiseAt(first + 2);
        _newRotationSafe(58003);
        IdentityRecovery.Request memory p = _ceTerms();
        T.Authorization memory a = this.closedEstateAcceptance(p);
        require(
            p.expectedResolutionHash == ceLatestDismissal,
            "original latest resolution in signed request"
        );
        this.closedEstateRegister(p, a);
        this.closedEstateRecover(p, a, false);
    }

    function testClosedEstatePostExpiryDismissalPreservesZeroCapabilities() public {
        this.closedEstateActivate(0, false);
        this.closedEstateCompromiseAt(ceWindow);
        this.closedEstateDismiss(false);
        this.closedEstateCompromiseAt(ceWindow + 1);
        _newRotationSafe(58004);
        IdentityRecovery.Request memory p = _ceTerms();
        T.Authorization memory a = this.closedEstateAcceptance(p);
        p.vestedAuthorityClass = 1;
        vm.expectRevert(
            abi.encodeWithSelector(
                IdentityRecovery.UnsupportedIdentityRecoveryProfile.selector, artistId
            )
        );
        ingress.identityRecoveryContext(p, a);
        p.vestedAuthorityClass = 3;
        this.closedEstateRegister(p, a);
        this.closedEstateRecover(p, a, false);
        _adoptRotatedSafe();
        vm.expectRevert(
            abi.encodeWithSelector(
                Estate.EstateCapabilityUnavailable.selector, artistId, uint32(256)
            )
        );
        this.closedEstateAttemptGuardian();
        require(
            ingress.currentAuthorityCapabilities(artistId).effectiveCapabilities == 0,
            "zero mask never escalates"
        );
    }

    function closedEstateAttemptGuardian() external returns (bytes32) {
        require(msg.sender == address(this), "test wrapper only");
        return _guardianRecord(_ceMembers(address(artist)), 1, 20 days, nextNonce);
    }

    function testClosedEstateAbandonedLowerNonceSafeRetainsVeto() public {
        this.closedEstateActivate(256, false);
        this.closedEstateCandidates(false);
        uint64 first = ingress.artistTransitionState(ceActivation).executedAt + 1;
        this.closedEstateCompromiseAt(first);
        this.closedEstateDismiss(true);
        this.closedEstateFreshGuardian();
        this.closedEstateCompromiseAt(first + 1);
        _newRotationSafe(58005);
        IdentityRecovery.Request memory p = _ceTerms();
        T.Authorization memory a = this.closedEstateAcceptance(p);
        this.closedEstateRegister(p, a);
        (,,, uint64 earliest) = IStreamArtistGuardianHistory(suite.owners[2])
            .guardianHistoryState(artistId, 0, address(ceVetoSafe), currentId);
        require(
            earliest == 3
                && ingress.guardianSetRecord(ceLowerGuardian).nonce
                    < ingress.guardianSetRecord(ceSelectedGuardian).nonce,
            "veto Safe appears only in abandoned lower nonce record"
        );
        vm.warp(scheduled.notBefore);
        _ceAssertAbandoned();
        require(
            executeSafe(
                ceVetoSafe,
                ceVetoKeys,
                address(ingress),
                0,
                abi.encodeCall(
                    IStreamArtistRecoveryAction.vetoIdentityRecovery,
                    (artistId, keccak256("abandoned guardian veto"))
                ),
                0
            ),
            "actual abandoned historical member Safe veto"
        );
        bytes32 roots = _roots();
        scheduled.status = GovernanceActionStatus.EXECUTED;
        _publish();
        vm.expectRevert(abi.encodeWithSelector(A.RecoveryActionVetoed.selector, currentId));
        this.executeRegistered(p, a);
        _inactive();
        (bool used,) = ingress.rotationAcceptanceNonceState(artistId, p.newAddress, a.nonce);
        require(
            !used && _roots() == roots && _ceHistoricalHash() == ceOriginals
                && ingress.latestIdentityRecovery(artistId) == 0,
            "lifetime veto blocks authority and replay writes"
        );
    }

    function _ceRecordActionSlot(bytes32 recordHash)
        private
        returns (bytes32 slot, bytes32 original)
    {
        ClosedEstateStorageVm trace = ClosedEstateStorageVm(address(vm));
        trace.record();
        Dismissal.Record memory record = ingress.identityContestDismissalRecord(recordHash);
        (bytes32[] memory reads,) = trace.accesses(suite.owners[2]);
        uint256 count;
        for (uint256 i; i < reads.length; ++i) {
            if (vm.load(suite.owners[2], reads[i]) == record.actionId) {
                slot = reads[i];
                ++count;
            }
        }
        require(count == 1 && record.actionId != 0, "unique actual immutable dismissal action slot");
        original = vm.load(suite.owners[2], slot);
    }

    function _ceClosureSlot() private returns (bytes32 slot) {
        ClosedEstateStorageVm trace = ClosedEstateStorageVm(address(vm));
        trace.record();
        Dismissal.Closure memory closed = ingress.identityTransitionClosure(artistId, ceActivation);
        (bytes32[] memory reads,) = trace.accesses(suite.owners[2]);
        uint256 count;
        for (uint256 i; i < reads.length; ++i) {
            if (vm.load(suite.owners[2], reads[i]) == closed.dismissalRecordHash) {
                slot = reads[i];
                ++count;
            }
        }
        require(
            count == 1 && closed.dismissalRecordHash == ceFirstDismissal,
            "unique original closure dismissal slot"
        );
    }

    function testClosedEstateRejectsOriginalAndLatestRecordDriftThenIdenticalRetry() public {
        this.closedEstateActivate(256, false);
        uint64 first = ingress.artistTransitionState(ceActivation).executedAt + 1;
        this.closedEstateCompromiseAt(first);
        this.closedEstateDismiss(true);
        this.closedEstateCompromiseAt(first + 1);
        this.closedEstateDismiss(true);
        this.closedEstateCompromiseAt(first + 2);
        _newRotationSafe(58006);
        IdentityRecovery.Request memory p = _ceTerms();
        T.Authorization memory a = this.closedEstateAcceptance(p);
        bytes32 expected = keccak256(abi.encode(ingress.identityRecoveryContext(p, a)));
        bytes32 closureSlot = _ceClosureSlot();
        vm.store(suite.owners[2], closureSlot, ceLatestDismissal);
        vm.expectRevert(
            abi.encodeWithSelector(
                IdentityRecovery.UnsupportedIdentityRecoveryProfile.selector, artistId
            )
        );
        ingress.identityRecoveryContext(p, a);
        vm.store(suite.owners[2], closureSlot, ceFirstDismissal);
        require(
            keccak256(abi.encode(ingress.identityRecoveryContext(p, a))) == expected,
            "later valid dismissal cannot replace the original closure proof"
        );
        (bytes32 originalSlot, bytes32 originalAction) = _ceRecordActionSlot(ceFirstDismissal);
        vm.store(suite.owners[2], originalSlot, keccak256("foreign original dismissal action"));
        vm.expectRevert(
            abi.encodeWithSelector(
                IdentityRecovery.UnsupportedIdentityRecoveryProfile.selector, artistId
            )
        );
        ingress.identityRecoveryContext(p, a);
        vm.store(suite.owners[2], originalSlot, originalAction);
        require(
            keccak256(abi.encode(ingress.identityRecoveryContext(p, a))) == expected,
            "exact original proof restored"
        );
        this.closedEstateRegister(p, a);
        (bytes32 latestSlot, bytes32 latestAction) = _ceRecordActionSlot(ceLatestDismissal);
        require(latestSlot != originalSlot, "independent latest record storage");
        vm.store(suite.owners[2], latestSlot, keccak256("foreign latest dismissal action"));
        vm.expectRevert(
            abi.encodeWithSelector(
                IdentityRecovery.UnsupportedIdentityRecoveryProfile.selector, artistId
            )
        );
        this.executeRegistered(p, a);
        vm.store(suite.owners[2], latestSlot, latestAction);
        require(
            keccak256(abi.encode(ingress.identityRecoveryContext(p, a))) == expected,
            "identical prepared context restored"
        );
        this.closedEstateRecover(p, a, false);
    }

    function testClosedEstateWrongLatestResolutionAndUnclosedHistoryRemainRejected() public {
        this.closedEstateActivate(256, false);
        uint64 first = ingress.artistTransitionState(ceActivation).executedAt + 1;
        this.closedEstateCompromiseAt(first);
        _newRotationSafe(58007);
        IdentityRecovery.Request memory p = _ceTerms();
        T.Authorization memory a = this.closedEstateAcceptance(p);
        vm.warp(ceWindow + 1);
        vm.expectRevert(
            abi.encodeWithSelector(
                IdentityRecovery.UnsupportedIdentityRecoveryProfile.selector, artistId
            )
        );
        ingress.identityRecoveryContext(p, a);
        this.closedEstateDismiss(true);
        this.closedEstateCompromiseAt(ceWindow + 2);
        p = _ceTerms();
        a = this.closedEstateAcceptance(p);
        IdentityRecovery.Context memory correct = ingress.identityRecoveryContext(p, a);
        p.expectedResolutionHash = keccak256("foreign latest resolution");
        vm.expectRevert(
            abi.encodeWithSelector(IdentityRecovery.InvalidIdentityRecovery.selector, artistId)
        );
        ingress.identityRecoveryContext(p, a);
        p.expectedResolutionHash = ceLatestDismissal;
        require(
            keccak256(abi.encode(ingress.identityRecoveryContext(p, a)))
                == keccak256(abi.encode(correct)),
            "actual latest resolution exact retry"
        );
        this.closedEstateRegister(p, a);
        this.closedEstateRecover(p, a, false);
    }
}

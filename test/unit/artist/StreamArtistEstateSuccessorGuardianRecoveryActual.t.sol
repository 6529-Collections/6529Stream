// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "./StreamArtistEstateRecoveryActual.t.sol";

/// @dev Actual estate successor op28, original op40 chronology, full-history op34 veto,
/// and op35/Safe/Archive. Original archival-to-Artist typed Executor role phases remain
/// explicit. Governance scheduling and the full current deployment are separate evidence.
contract StreamArtistEstateSuccessorGuardianRecoveryActualTest is
    StreamArtistEstateRecoveryActualTest
{
    bytes32 private sgActivation;
    bytes32 private sgOriginalGuardian;
    bytes32 private sgSelected;
    bytes32 private sgLower;
    bytes32 private sgOriginals;
    address private sgLiving;
    address private sgSuccessor;
    OfficialSafe private sgVetoSafe;
    uint256[] private sgVetoKeys;
    uint64 private sgWindow;
    uint64 private sgCount;

    function _sgMembers(address extra) private view returns (address[] memory members) {
        members = new address[](2);
        members[0] = sgLiving;
        members[1] = extra;
        if (members[0] > members[1]) (members[0], members[1]) = (members[1], members[0]);
        require(members[0] != members[1], "distinct guardian members");
    }

    function _sgActivate(uint32 caps) private {
        _sizes();
        sgLiving = address(artist);
        _delegateSetup();
        address[] memory members = new address[](1);
        members[0] = sgLiving;
        sgOriginalGuardian = _guardianRecord(members, 1, 10 days, 900);
        Estate.Execution memory execution = _estateActivateAndAdopt(caps);
        sgActivation = execution.expectedActivationRecordHash;
        sgSuccessor = address(artist);
        V.Snapshot memory v = _snapshot(sgActivation);
        require(
            v.operationId == 40 && v.authorityClass == 3 && v.guardians.count == 1
                && v.oldAddress == sgLiving && v.newAddress == sgSuccessor
                && v.previousTransitionRecordHash == 0,
            "first actual estate and original guardian prefix"
        );
        sgWindow = ingress.artistTransitionState(sgActivation).postWindowEndsAt;
        sgCount = 1;
    }

    function _sgAdmitSuccessorHistory(bool afterWindow) private {
        if (afterWindow) vm.warp(sgWindow);
        _newRotationSafe(56001);
        sgVetoSafe = rotationSafe;
        sgVetoKeys = rotationKeys;
        sgSelected = _guardianRecord(_sgMembers(sgSuccessor), 1, 20 days, 1200);
        sgLower = _guardianRecord(_sgMembers(address(sgVetoSafe)), 1, 15 days, 1100);
        sgCount = 3;
        R.GuardianRecord memory selected = ingress.guardianSetRecord(sgSelected);
        R.GuardianRecord memory lower = ingress.guardianSetRecord(sgLower);
        V.Snapshot memory v = _snapshot(sgActivation);
        (GH.Head memory head, GH.Entry memory entry,,) = IStreamArtistGuardianHistory(
                suite.owners[2]
            ).guardianHistoryState(artistId, 2, address(0), 0);
        require(
            head.count == 3 && entry.recordHash == sgSelected
                && entry.ownerRevision > v.ownerRevision,
            "successful owner revision proves post-vesting admission"
        );
        require(
            selected.authorityClass == 3 && lower.authorityClass == 3
                && selected.signer == sgSuccessor && lower.signer == sgSuccessor,
            "actual original successor authors both selected and lower nonce records"
        );
        require(
            ingress.currentAuthorityCapabilities(artistId).effectiveCapabilities == 256,
            "SET-only additive maintenance never needs displacement permission"
        );
        if (afterWindow) {
            require(
                selected.provisional.transitionRecordHash == 0
                    && selected.provisional.windowEndsAt == 0,
                "post-window successor record has canonical empty association"
            );
        } else {
            require(
                selected.provisional.transitionRecordHash == sgActivation
                    && selected.provisional.windowEndsAt == sgWindow
                    && selected.signedAt == v.executedAt,
                "same-time later owner revision retains exact original association"
            );
            (,,, bytes32 beforeHead) = ingress.guardianSet(artistId);
            require(
                beforeHead == sgOriginalGuardian,
                "provisional record does not replace original early"
            );
            vm.warp(sgWindow);
        }
        (,,, bytes32 current) = ingress.guardianSet(artistId);
        require(
            current == sgSelected && current != sgLower,
            "exact expiry highest eligible nonce is operative"
        );
    }

    function _sgContest() private {
        _newRotationSafe(56002);
        ArtistUnitGovernance authority = ArtistUnitGovernance(manager.governanceAuthority());
        ArtistUnitRoles(suite.roleRegistry).setArbiter(address(artist), true);
        authority.configureContestReads(
            suite.roleRegistry,
            address(artist),
            keccak256("compromise reason"),
            "urn:unit:estate-successor-recovery"
        );
        (bytes32 scope, bytes32 oldHash, bytes32 newHash) = ingress.identityContestGovernanceContext(
            artistId, sgActivation, keccak256("compromise evidence"), keccak256("compromise reason")
        );
        authority.executeModuleContext(
            address(ingress), _contestData(sgActivation), 1, scope, oldHash, newHash
        );
        Dismissal.Cause memory cause = ingress.currentIdentityContestCause(artistId);
        require(
            cause.facts.authorityClass == 3 && cause.facts.priorStatus == 3
                && cause.facts.incumbent == sgSuccessor && cause.facts.enteredAt == sgWindow,
            "actual class3 contest at the immutable original window end"
        );
        sgOriginals = _sgOriginalHash();
    }

    function _sgOriginalHash() private view returns (bytes32) {
        (Estate.RequestRecord memory request, uint8 phase, Estate.ExecutionFacts memory execution) =
            ingress.estateActivationRecord(sgActivation);
        return keccak256(
            abi.encode(
                request,
                phase,
                execution,
                _snapshot(sgActivation),
                ingress.artistTransitionState(sgActivation),
                ingress.successorDesignationRecord(request.designationRecordHash),
                ingress.operativeSuccessorRecord(artistId),
                ingress.operativeEstateDirective(artistId),
                ingress.guardianSetRecord(sgOriginalGuardian),
                ingress.guardianSetRecord(sgSelected),
                ingress.guardianSetRecord(sgLower)
            )
        );
    }

    function _sgTerms() private view returns (IdentityRecovery.Request memory p) {
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

    function _sgPrepare(IdentityRecovery.Request memory p, T.Authorization memory a, bytes32 id)
        private
    {
        GovernanceCall[] memory calls = _schedule(id, p, a);
        ingress.registerIdentityRecoveryAction(currentId, calls, p, a);
        (A.Association memory association,,, uint64 count) = _read();
        (GH.Head memory head,, GH.Snapshot memory snapshot,) = IStreamArtistGuardianHistory(
                suite.owners[2]
            ).guardianHistoryState(artistId, 0, address(0), currentId);
        require(
            count == sgCount && head.count == sgCount && snapshot.count == sgCount
                && snapshot.historyCommitment == head.commitment
                && snapshot.associationHash == association.associationHash,
            "owner freezes complete original-plus-successor history"
        );
        require(
            association.guardian.recordHash == (sgSelected == 0 ? sgOriginalGuardian : sgSelected)
                && association.contextHash
                    == keccak256(abi.encode(ingress.identityRecoveryContext(p, a))),
            "context and preparation use identical original estate guardian basis"
        );
    }

    function _sgAssertRecovery(bytes32 record, IdentityRecovery.Request memory p, uint64 epoch)
        private
        view
    {
        IdentityRecovery.Record memory item = ingress.identityRecoveryRecord(record);
        Estate.AuthorityCapabilities memory caps = ingress.currentAuthorityCapabilities(artistId);
        V.Snapshot memory v = _snapshot(record);
        V.Snapshot memory original = _snapshot(sgActivation);
        require(
            caps.authorityAddress == p.newAddress && caps.authorityClass == 3 && caps.status == 3
                && caps.effectiveCapabilities == 256 && caps.activationRecordHash == sgActivation,
            "estate recovered key keeps original SET-only capability plan"
        );
        require(
            item.postContestSeconds == 20 days && item.delegationEpoch == epoch + 1
                && item.fields.oldAddress == sgSuccessor && item.fields.vestedAuthorityClass == 3,
            "selected successor guardian latency controls fresh recovery window"
        );
        require(
            v.operationId == 35 && v.authorityClass == 3 && v.guardians.count == sgCount
                && original.guardians.count == 1 && v.previousTransitionRecordHash == sgActivation
                && v.previousCommitment == original.commitment && _sgOriginalHash() == sgOriginals,
            "new vesting extends chronology without rewriting original prefix or records"
        );
        (address prior, bytes32 guardian, uint64 tail) =
            IStreamArtistIdentityRecoveryOwner(suite.owners[2]).recoveryTransitionStanding(record);
        require(
            prior == sgSuccessor && guardian == sgSelected && tail != 0,
            "saved standing retains exact admitted class3 guardian record"
        );
        (bytes32 primary, bytes32 occurrence, bytes32 secondary) =
            IStreamArtistIdentityRecoveryOwner(suite.owners[2]).identityRecoveryReceipts(record);
        require(
            primary != 0 && occurrence != 0 && secondary != 0 && primary != secondary,
            "two immutable ordered receipt commitments remain"
        );
    }

    function testActualEstateSuccessorProvisionalGuardianMaturesAndArchiveRetry() public {
        _sgActivate(256);
        _sgAdmitSuccessorHistory(false);
        _sgContest();
        IdentityRecovery.Request memory p = _sgTerms();
        T.Authorization memory a = _acceptance(p);
        IdentityRecovery.Context memory context = ingress.identityRecoveryContext(p, a);
        _sgPrepare(p, a, keccak256("provisional successor guardian recovery"));
        vm.warp(scheduled.notBefore);
        scheduled.status = GovernanceActionStatus.EXECUTED;
        _publish();
        bytes32 roots = _roots();
        T.Snapshot memory before_ = _ownerSnapshot();
        _overflow();
        this.executeRegistered(p, a);
        _inactive();
        (bool used,) = ingress.rotationAcceptanceNonceState(artistId, p.newAddress, a.nonce);
        require(
            !used && _roots() == roots && ingress.latestIdentityRecovery(artistId) == 0
                && _sgOriginalHash() == sgOriginals,
            "late Archive failure rolls back all new authority and vesting writes"
        );
        vm.roll(restoreBlock);
        vm.recordLogs();
        bytes32 record = this.executeRegistered(p, a);
        _assertSnapshot(_snapshot(record), 35, before_, vm.getRecordedLogs());
        _sgAssertRecovery(record, p, context.delegationEpoch);
    }

    function testActualEstateSuccessorPostWindowLowerNonceGuardianVeto() public {
        _sgActivate(256);
        _sgAdmitSuccessorHistory(true);
        _sgContest();
        IdentityRecovery.Request memory p = _sgTerms();
        T.Authorization memory a = _acceptance(p);
        _sgPrepare(p, a, keccak256("post-window successor guardian veto"));
        (address[] memory selected,,,) = ingress.guardianSet(artistId);
        for (uint256 i; i < selected.length; ++i) {
            require(selected[i] != address(sgVetoSafe), "veto actor not operative");
        }
        (,,, uint64 earliest) = IStreamArtistGuardianHistory(suite.owners[2])
            .guardianHistoryState(artistId, 0, address(sgVetoSafe), currentId);
        require(
            earliest == 3 && earliest > _snapshot(sgActivation).guardians.count,
            "veto actor occurs only in successor lower-nonce history"
        );
        vm.warp(scheduled.notBefore);
        require(
            executeSafe(
                sgVetoSafe,
                sgVetoKeys,
                address(ingress),
                0,
                abi.encodeCall(
                    IStreamArtistRecoveryAction.vetoIdentityRecovery,
                    (artistId, keccak256("successor lifetime veto"))
                ),
                0
            ),
            "actual lower-nonce successor guardian Safe veto"
        );
        bytes32 roots = _roots();
        scheduled.status = GovernanceActionStatus.EXECUTED;
        _publish();
        vm.expectRevert(abi.encodeWithSelector(A.RecoveryActionVetoed.selector, currentId));
        this.executeRegistered(p, a);
        _inactive();
        (bool used,) = ingress.rotationAcceptanceNonceState(artistId, p.newAddress, a.nonce);
        require(
            !used && _roots() == roots && ingress.latestIdentityRecovery(artistId) == 0
                && _sgOriginalHash() == sgOriginals,
            "full retained prefix veto blocks action without nonce or authority effect"
        );
    }

    function sgAdditiveGuardians() external returns (bytes32) {
        require(msg.sender == address(this), "test wrapper only");
        return _guardianRecord(_sgMembers(sgSuccessor), 1, 20 days, 1200);
    }

    function testActualZeroMaskEstateAdditiveGuardianAdmissionRejectsSetBit() public {
        _sgActivate(0);
        bytes32 roots = _roots();
        (GH.Head memory head,,,) = IStreamArtistGuardianHistory(suite.owners[2])
            .guardianHistoryState(artistId, 0, address(0), 0);
        vm.expectRevert(
            abi.encodeWithSelector(
                Estate.EstateCapabilityUnavailable.selector, artistId, uint32(256)
            )
        );
        this.sgAdditiveGuardians();
        (GH.Head memory after_,,,) = IStreamArtistGuardianHistory(suite.owners[2])
            .guardianHistoryState(artistId, 0, address(0), 0);
        require(
            _roots() == roots && keccak256(abi.encode(head)) == keccak256(abi.encode(after_))
                && ingress.currentAuthorityCapabilities(artistId).effectiveCapabilities == 0,
            "zero mask cannot admit additive guardian history and never gains SET permission"
        );
    }
}

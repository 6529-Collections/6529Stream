// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./StreamArtistDormancyGuardianSupersessionActual.t.sol";
import {
    IStreamArtistIdentityDismissal
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistIdentityDismissal.sol";

interface RepeatedDormancyStorageVm {
    function record() external;
    function accesses(address target)
        external
        returns (bytes32[] memory reads, bytes32[] memory writes);
}

/// @notice Original designated43 -> actual35 -> fresh33 -> independently registered35.
/// @dev Real Artist owners, threshold Safes and Archive; inherited Core/governance facts are typed
/// unit boundaries. This new host does not change the first-recovery fixture or its assertions.
contract StreamArtistDormancyRepeatedRecoveryActualTest is
    StreamArtistDormancyGuardianSupersessionActualTest
{
    bytes32 private rrOrigin;
    bytes32 private rrNotice;
    bytes32 private rrTerminal;
    bytes32 private rrPrevious;
    uint64 private rrWindow;
    uint32 private rrCapabilities;
    uint256 private rrNonce = 72000;
    bytes32[] private rrRecoveries;
    bytes32[] private rrRotations;
    bytes32[] private rrExcluded;
    bytes32 private rrFrozen;
    bytes32 private rrElection;

    modifier rrSelf() {
        require(msg.sender == address(this), "repeat dormancy fixture caller");
        _;
    }

    function rrStart() external rrSelf {
        // Freeze the actual first43 -> first35 producer path before extending its consumer.
        this.testArt27EmptyListCompatibilityKeepsDesignatedOriginAndExactReceipts();
        _rrCaptureStart();
    }

    function rrStartExcluded() external rrSelf {
        this.testArt27Direct43PostCutoffSameTimestampArbiterAndOriginalReceipts();
        _rrCaptureStart();
    }

    function _rrCaptureStart() private {
        Estate.AuthorityCapabilities memory caps = ingress.currentAuthorityCapabilities(artistId);
        rrOrigin = caps.activationRecordHash;
        rrCapabilities = caps.effectiveCapabilities;
        (rrNotice,,) = IStreamArtistDormancy(address(ingress)).dormancyNotice(artistId);
        rrPrevious = ingress.latestIdentityRecovery(artistId);
        rrTerminal = rrPrevious;
        rrWindow = ingress.artistTransitionState(rrTerminal).postWindowEndsAt;
        require(
            rrPrevious != 0 && _snapshot(rrOrigin).operationId == 43
                && _snapshot(rrPrevious).operationId == 35 && caps.authorityClass == 3
                && caps.authorityAddress == address(rotationSafe),
            "actual first recovery retains designated43 origin and new Safe"
        );
        _adoptRotatedSafe();
        rrRecoveries.push(rrPrevious);
        bytes32[] memory excluded =
        ingress.identityRecoveryRecord(rrPrevious).terms.supersededRecordHashes;
        for (uint256 i; i < excluded.length; ++i) {
            rrExcluded.push(excluded[i]);
        }
    }

    function rrAt(uint64 when) external rrSelf {
        vm.warp(when);
    }

    function rrRotate() external rrSelf {
        bytes32 previous = rrTerminal;
        _rrMatureUnclosed();
        _newRotationSafe(++rrNonce);
        rrTerminal = _stageRotation(ingress.lastArtistTransition(artistId));
        _executeTimedRotation(rrTerminal);
        _adoptRotatedSafe();
        rrRotations.push(rrTerminal);
        rrWindow = ingress.artistTransitionState(rrTerminal).postWindowEndsAt;
        V.Snapshot memory v = _snapshot(rrTerminal);
        require(
            v.operationId == 32 && v.authorityClass == 3
                && v.previousTransitionRecordHash == previous
                && v.previousCommitment == _snapshot(previous).commitment
                && ingress.latestIdentityRecovery(artistId) == rrPrevious
                && ingress.currentAuthorityCapabilities(artistId).activationRecordHash == rrOrigin,
            "actual same-epoch32 appends the precise current execution and preserves original43"
        );
    }

    function rrDismiss() external rrSelf {
        bytes32 first = ingress.identityTransitionClosure(artistId, rrTerminal).dismissalRecordHash;
        Dismissal.Request memory p = _dismissalRequest();
        ArtistAppealUnitRoles(suite.roleRegistry).setArbiter(address(artist), true);
        ArtistUnitGovernance authority = ArtistUnitGovernance(manager.governanceAuthority());
        authority.configureContestReads(
            suite.roleRegistry, address(artist), p.reasonHash, "urn:repeat43:dismissal"
        );
        Dismissal.Context memory x = ingress.identityContestDismissalContext(p);
        _rrGovernanceWitness(x.scopeHash, x.oldValueHash, x.newValueHash);
        authority.executeModuleContext(
            address(ingress),
            abi.encodeCall(IStreamArtistIdentityDismissal.dismissArtistIdentityContest, (p)),
            1,
            x.scopeHash,
            x.oldValueHash,
            x.newValueHash
        );
        _inactive();
        bytes32 record = ingress.latestIdentityContestDismissal(artistId);
        require(
            ingress.identityTransitionClosure(artistId, rrTerminal).dismissalRecordHash
                == (first == 0 ? record : first),
            "first authenticated closure is retained"
        );
    }

    function rrStanding() external rrSelf {
        _rrMatureUnclosed();
        _newRotationSafe(++rrNonce);
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
            "actual current Safe standing veto"
        );
        Dismissal.Cause memory cause = ingress.currentIdentityContestCause(artistId);
        require(
            cause.facts.kind == 2 && cause.facts.executedTransitionHash == rrTerminal
                && cause.facts.pendingTransitionHash == pending && cause.facts.evidenceHash == 0
                && cause.facts.reasonHash == 0,
            "standing cause preserves zero-reason producer and exact execution"
        );
        this.rrDismiss();
    }

    function _rrMatureUnclosed() private {
        if (
            ingress.identityTransitionClosure(artistId, rrTerminal).dismissalRecordHash == 0
                && block.timestamp < rrWindow
        ) this.rrAt(rrWindow);
    }

    function rrGuardian(address member, uint64 window, uint256 nonce)
        external
        rrSelf
        returns (bytes32)
    {
        address[] memory members = new address[](1);
        members[0] = member;
        return _guardianRecord(members, 1, window, nonce);
    }

    function rrCompromise(uint64 when) external rrSelf {
        vm.warp(when);
        this.rrRecordCause();
    }

    function rrRecordCause() external rrSelf {
        ArtistAppealUnitRoles(suite.roleRegistry).setArbiter(address(artist), true);
        bytes32 evidence = keccak256(
            abi.encode(
                "repeat43 evidence",
                rrTerminal,
                block.timestamp,
                ingress.latestIdentityContestDismissal(artistId)
            )
        );
        bytes32 reason = keccak256(abi.encode("repeat43 reason", evidence));
        ArtistUnitGovernance authority = ArtistUnitGovernance(manager.governanceAuthority());
        authority.configureContestReads(suite.roleRegistry, address(artist), reason, "urn:repeat43");
        (bytes32 scope, bytes32 old_, bytes32 next_) =
            ingress.identityContestGovernanceContext(artistId, rrTerminal, evidence, reason);
        _rrGovernanceWitness(scope, old_, next_);
        authority.executeModuleContext(
            address(ingress),
            abi.encodeCall(
                IStreamArtistIdentityContest.contestArtistIdentity,
                (artistId, rrTerminal, evidence, reason)
            ),
            1,
            scope,
            old_,
            next_
        );
        _inactive();
        Dismissal.Cause memory cause = ingress.currentIdentityContestCause(artistId);
        require(
            cause.facts.kind == 1 && cause.facts.authorityClass == 3 && cause.facts.priorStatus == 3
                && cause.facts.executedTransitionHash == rrTerminal
                && cause.facts.incumbent == address(artist)
                && ingress.latestIdentityRecovery(artistId) == rrPrevious,
            "fresh actual33 binds the current principal and latest admitted35 or32"
        );
    }

    function _rrGovernanceWitness(bytes32 scope, bytes32 old_, bytes32 next_) private {
        // Inherited registered35 leaves a selector-wide currentAction mock behind. Replace that
        // typed Executor boundary for this exact new producer; changing the unit double's storage
        // alone cannot supersede a Foundry mock. Restore its inactive boundary after execution.
        avm.mockCall(
            manager.governanceAuthority(),
            abi.encodeWithSignature("currentAction()"),
            abi.encode(true, keccak256("unit authority gas raise"), uint8(1), scope, old_, next_)
        );
    }

    function rrRequest()
        external
        rrSelf
        returns (IdentityRecovery.Request memory p, T.Authorization memory a)
    {
        _newRotationSafe(++rrNonce);
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
        a = _acceptance(p);
    }

    function testRepeatedDormancyActualFirst35ThenFresh33RequestKeepsOriginal43Origin() public {
        this.rrStart();
        this.rrCompromise(rrWindow);
        (IdentityRecovery.Request memory p, T.Authorization memory a) = this.rrRequest();
        IdentityRecovery.Context memory context = ingress.identityRecoveryContext(p, a);
        require(
            context.incumbent == address(artist)
                && context.delegationEpoch
                    == ingress.identityRecoveryRecord(rrPrevious).delegationEpoch
                && ingress.currentAuthorityCapabilities(artistId).activationRecordHash == rrOrigin
                && ingress.currentAuthorityCapabilities(artistId).effectiveCapabilities
                    == rrCapabilities,
            "fresh second recovery admits original43 capabilities without substituting an op40 activation"
        );
    }

    function _rrHistory() private view returns (bytes32 value) {
        (Dormancy27.Notice memory n, uint8 phase, Dormancy27.Terminal memory t) =
            IStreamArtistDormancy(address(ingress)).dormancyRecord(rrNotice);
        value = keccak256(
            abi.encode(
                n,
                phase,
                t,
                _snapshot(rrOrigin),
                ingress.artistTransitionState(rrOrigin),
                ingress.successorDesignationRecord(t.plan.designation),
                ingress.estateDirectiveRecord(t.plan.directive)
            )
        );
        for (uint256 i; i < rrRecoveries.length; ++i) {
            bytes32 record = rrRecoveries[i];
            (bytes32 primary, bytes32 occurrence, bytes32 secondary) =
                IStreamArtistIdentityRecoveryOwner(suite.owners[2]).identityRecoveryReceipts(record);
            value = keccak256(
                abi.encode(
                    value,
                    ingress.identityRecoveryRecord(record),
                    _snapshot(record),
                    primary,
                    occurrence,
                    secondary
                )
            );
        }
        // Captured after the current contest/closure, before each new recovery. Original32 records
        // retain their real mutable contest marker; the recovery itself must not rewrite any of them.
        for (uint256 i; i < rrRotations.length; ++i) {
            bytes32 record = rrRotations[i];
            value = keccak256(
                abi.encode(
                    value, ingress.rotationRecord(record), _snapshot(record), _rrClosure(record)
                )
            );
        }
        for (uint256 i; i < rrExcluded.length; ++i) {
            value = keccak256(abi.encode(value, rrExcluded[i], _status(rrExcluded[i])));
        }
        (GH.Head memory head,,,) = IStreamArtistGuardianHistory(suite.owners[2])
            .guardianHistoryState(artistId, 0, address(0), 0);
        value = keccak256(abi.encode(value, head));
        for (uint64 i = 1; i <= head.count; ++i) {
            (, GH.Entry memory entry,,) = IStreamArtistGuardianHistory(suite.owners[2])
                .guardianHistoryState(artistId, i, address(0), 0);
            value = keccak256(abi.encode(value, entry, ingress.guardianSetRecord(entry.recordHash)));
        }
    }

    function _rrClosure(bytes32 transition) private view returns (bytes32) {
        Dismissal.Closure memory closed = ingress.identityTransitionClosure(artistId, transition);
        Dismissal.Record memory r =
            ingress.identityContestDismissalRecord(closed.dismissalRecordHash);
        return
            keccak256(
                abi.encode(closed, r, ingress.identityContestCause(r.terms.expectedCauseHash))
            );
    }

    function _rrRegister(IdentityRecovery.Request memory p, T.Authorization memory a) private {
        GovernanceCall[] memory calls = _schedule(
            keccak256(abi.encode("repeat designated43 action", rrPrevious, rrTerminal, rrNonce)),
            p,
            a
        );
        ingress.registerIdentityRecoveryAction(currentId, calls, p, a);
        (A.Association memory association,,, uint64 count) = _read();
        (GH.Head memory head,, GH.Snapshot memory frozen,) = IStreamArtistGuardianHistory(
                suite.owners[2]
            ).guardianHistoryState(artistId, 0, address(0), currentId);
        require(
            count == head.count && frozen.count == count
                && frozen.historyCommitment == head.commitment
                && association.contextHash
                    == keccak256(abi.encode(ingress.identityRecoveryContext(p, a))),
            "new independent registration binds exact request and complete current guardian prefix"
        );
        rrFrozen = _rrHistory();
    }

    function _rrElect(IdentityRecovery.Request memory p, T.Authorization memory a, bytes32 selected)
        private
    {
        IStreamArtistGuardianSelectionPreparation preparation = _selectionPreparation();
        rrElection = preparation.begin(artistId, rrTerminal, p.supersededRecordHashes);
        (GH.Head memory head,,,) = IStreamArtistGuardianHistory(suite.owners[2])
            .guardianHistoryState(artistId, 0, address(0), 0);
        bytes32 roots = _roots();
        vm.expectRevert(
            abi.encodeWithSelector(
                Selection.IncompleteGuardianSelection.selector, rrElection, uint64(0), head.count
            )
        );
        ingress.identityRecoveryContext(p, a);
        Selection.Progress memory progress = preparation.continueSelection(rrElection, 1);
        require(!progress.complete && progress.processed == 1, "partial prefix cannot elect a head");
        vm.expectRevert(
            abi.encodeWithSelector(
                Selection.IncompleteGuardianSelection.selector, rrElection, uint64(1), head.count
            )
        );
        ingress.identityRecoveryContext(p, a);
        progress = preparation.continueSelection(rrElection, 64);
        require(
            progress.complete && progress.processed == head.count
                && progress.selectedRecordHash == selected && roots == _roots(),
            "complete election keeps permanent exclusions and chooses the retained lower nonce"
        );
    }

    function _rrRecover(
        IdentityRecovery.Request memory p,
        T.Authorization memory a,
        bytes32 selected,
        bool retry
    ) private returns (bytes32 record) {
        uint64 epoch = ingress.identityRecoveryContext(p, a).delegationEpoch;
        this.rrAt(scheduled.notBefore);
        scheduled.status = GovernanceActionStatus.EXECUTED;
        _publish();
        T.Snapshot memory before_ = _ownerSnapshot();
        if (retry) _rrRollback(p, a, epoch);
        vm.recordLogs();
        record = this.executeRegistered(p, a);
        _assertSnapshot(_snapshot(record), 35, before_, vm.getRecordedLogs());
        _rrReceipts(record);
        IdentityRecovery.Record memory saved = ingress.identityRecoveryRecord(record);
        Estate.AuthorityCapabilities memory caps = ingress.currentAuthorityCapabilities(artistId);
        V.Snapshot memory v = _snapshot(record);
        (,,, bytes32 operative) = ingress.guardianSet(artistId);
        (bool used,) = ingress.rotationAcceptanceNonceState(artistId, p.newAddress, a.nonce);
        require(
            caps.authorityClass == 3 && caps.status == 3 && caps.authorityAddress == p.newAddress
                && caps.activationRecordHash == rrOrigin
                && caps.effectiveCapabilities == rrCapabilities
                && saved.delegationEpoch == epoch + 1
                && v.previousTransitionRecordHash == rrTerminal
                && v.previousCommitment == _snapshot(rrTerminal).commitment && used
                && operative == selected
                && saved.fields.supersededRecordsHash
                    == RecoveryHashes.supersession(p.supersededRecordHashes)
                && keccak256(abi.encode(saved.terms.supersededRecordHashes))
                    == keccak256(abi.encode(p.supersededRecordHashes)) && _rrHistory() == rrFrozen
                && _operationPayload(35, manager.governanceAuthority(), record).length != 0,
            "each actual35 increments its current epoch and retains exact original43 rights and prior records"
        );
        for (uint256 i; i < p.supersededRecordHashes.length; ++i) {
            GS.Status memory status = _status(p.supersededRecordHashes[i]);
            require(
                status.recoveryRecordHash == record && status.actionId == currentId,
                "new exact permanent exclusion"
            );
        }
        require(_status(selected).recoveryRecordHash == 0, "operative guardian remains retained");
        bytes32 roots = _roots();
        (bool ok,) = address(this).call(abi.encodeCall(this.executeRegistered, (p, a)));
        _inactive();
        require(
            !ok && roots == _roots() && _rrHistory() == rrFrozen,
            "identical action and acceptance cannot replay"
        );
        rrRecoveries.push(record);
        for (uint256 i; i < p.supersededRecordHashes.length; ++i) {
            rrExcluded.push(p.supersededRecordHashes[i]);
        }
        rrPrevious = record;
        rrTerminal = record;
        rrWindow = ingress.artistTransitionState(record).postWindowEndsAt;
        _adoptRotatedSafe();
    }

    function _rrRollback(IdentityRecovery.Request memory p, T.Authorization memory a, uint64 epoch)
        private
    {
        bytes32 roots = _roots();
        bytes32 signed = keccak256(abi.encode(p, a));
        bytes32 principal =
            keccak256(abi.encode(IStreamArtistIdentityOwner(suite.owners[2]).identity(artistId)));
        (,,, bytes32 oldHead) = ingress.guardianSet(artistId);
        uint256 safeNonce = rotationSafe.nonce();
        _overflow();
        this.executeRegistered(p, a);
        _inactive();
        (,,, bytes32 head) = ingress.guardianSet(artistId);
        (bool used,) = ingress.rotationAcceptanceNonceState(artistId, p.newAddress, a.nonce);
        require(
            !used && roots == _roots() && _rrHistory() == rrFrozen && head == oldHead
                && ingress.latestIdentityRecovery(artistId) == rrPrevious
                && rotationSafe.nonce() == safeNonce
                && principal
                    == keccak256(
                        abi.encode(IStreamArtistIdentityOwner(suite.owners[2]).identity(artistId))
                    ) && ingress.identityRecoveryContext(p, a).delegationEpoch == epoch,
            "late actual Archive overflow rolls back epoch, authority, roots, nonce, heads and original history"
        );
        for (uint256 i; i < p.supersededRecordHashes.length; ++i) {
            require(
                _status(p.supersededRecordHashes[i]).recoveryRecordHash == 0,
                "failed append cannot adjudicate"
            );
        }
        vm.roll(restoreBlock);
        require(
            signed == keccak256(abi.encode(p, a)),
            "retry uses identical original Safe acceptance bytes"
        );
    }

    // Independent original thirteen-word receipt oracle; receipt commitments are not record IDs.
    function _rrReceipts(bytes32 record) private view {
        IStreamArtistOwner owner = IStreamArtistOwner(suite.owners[2]);
        T.Snapshot memory state = owner.ownerStateSnapshotV2();
        uint256 prefix = uint256(vm.load(address(owner), bytes32(0)));
        uint64 sequence = uint64(prefix >> 64);
        require(
            uint64(prefix) == state.revision && sequence >= 2,
            "actual receipt revision and sequence"
        );
        IdentityRecovery.Record memory saved = ingress.identityRecoveryRecord(record);
        bytes32 secondaryDomain = 0x0c8573762967a1af597f2a7afc4b655a87b3e22d2b11fbab6cf13c6f7b1396ae;
        bytes32[13] memory words;
        words[0] = 0x2524f38d4b0732cdfa0810161b89161cfa6da3e7cc1b6cab90fd8b71fbfbd861;
        words[1] = bytes32(uint256(2));
        words[2] = bytes32(block.chainid);
        words[3] = bytes32(uint256(uint160(address(ingress))));
        words[4] = bytes32(uint256(uint160(address(coordinator))));
        words[5] = bytes32(uint256(uint160(suite.archive)));
        words[6] = bytes32(uint256(uint160(address(owner))));
        words[7] = 0x6579e41542b1bfc6684ea87b09373c4f4690857bd046eb4faf0f92a42bc88adb;
        words[8] = bytes32(uint256(state.revision));
        words[9] = bytes32(uint256(sequence - 1));
        words[10] = bytes32(uint256(uint160(manager.governanceAuthority())));
        words[11] = 0x459749364fd07c3a8f1998b82d893d33ef0942c30d94666b42dac1e37ba5feff;
        words[12] = record;
        bytes32 expectedPrimary = keccak256(abi.encode(words));
        words[9] = bytes32(uint256(sequence));
        words[11] = secondaryDomain;
        words[12] = saved.fields.supersededRecordsHash;
        bytes32 expectedSecondary = keccak256(abi.encode(words));
        bytes32 expectedOccurrence = keccak256(
            abi.encode(
                bytes32(0x05c1b33dc3307a69a2b02b1fdcc96323c6c2dcb072805ca38ec6462ded34ce09),
                uint16(2),
                record,
                secondaryDomain,
                saved.fields.supersededRecordsHash
            )
        );
        (bytes32 primary, bytes32 occurrence, bytes32 secondary) =
            IStreamArtistIdentityRecoveryOwner(suite.owners[2]).identityRecoveryReceipts(record);
        require(
            primary == expectedPrimary && occurrence == expectedOccurrence
                && secondary == expectedSecondary && primary != record && primary != secondary,
            "exact original domains, two typed receipt commitments and secondary occurrence"
        );
    }

    function _rrRound(uint8 rotations, bool retry) private returns (bytes32 record) {
        for (uint256 i; i < rotations; ++i) {
            this.rrRotate();
        }
        this.rrCompromise(rrWindow);
        (IdentityRecovery.Request memory p, T.Authorization memory a) = this.rrRequest();
        (,,, bytes32 head) = ingress.guardianSet(artistId);
        _rrRegister(p, a);
        return _rrRecover(p, a, head, retry);
    }

    function testRepeatedDormancyDirectSecond35PreservesOriginAndRetriesExactArchiveReceipt()
        public
    {
        this.rrStart();
        bytes32 first = rrPrevious;
        bytes32 second = _rrRound(0, true);
        require(
            first != second && ingress.identityRecoveryRecord(second).delegationEpoch == 3,
            "second recovery uses epoch3"
        );
    }

    function testRepeatedDormancyOneExecuted32PreservesOriginal43AndExactPrior35() public {
        this.rrStart();
        _rrRound(1, true);
    }

    function testRepeatedDormancyMultiple32AndLater35RoundsAdvanceBeyondOriginalEpochPlusOne()
        public
    {
        this.rrStart();
        _rrRound(3, true);
        _rrRound(0, true);
        bytes32 fourth = _rrRound(2, true);
        (,, Dormancy27.Terminal memory original) =
            IStreamArtistDormancy(address(ingress)).dormancyRecord(rrNotice);
        require(
            original.delegationEpoch == 1
                && ingress.identityRecoveryRecord(fourth).delegationEpoch == 5
                && rrRecoveries.length == 4
                && ingress.currentAuthorityCapabilities(artistId).activationRecordHash == rrOrigin,
            "original43 epoch stays1 while independent35 rounds reach5"
        );
    }

    function testRepeatedDormancyPermanentSupersessionAndLowerNonceElectionSurviveFurtherRounds()
        public
    {
        this.rrStartExcluded();
        bytes32 oldExcluded = rrExcluded[0];
        bytes32 oldStatus = keccak256(abi.encode(_status(oldExcluded)));
        bytes32 post = this.rrGuardian(address(artist), 25 days, 3000);
        bytes32 retained = this.rrGuardian(address(delegateSafe), 10 days, 2500);
        this.rrCompromise(rrWindow);
        (IdentityRecovery.Request memory p, T.Authorization memory a) = this.rrRequest();
        p.supersededRecordHashes = new bytes32[](1);
        p.supersededRecordHashes[0] = post;
        a = _acceptance(p);
        _rrElect(p, a, retained);
        _rrRegister(p, a);
        (Selection.Result memory elected, R.GuardianRecord memory saved) = IStreamArtistGuardianSelectionOwner(
                suite.owners[2]
            ).guardianRecoverySelection(currentId);
        require(
            elected.sourceKey == rrElection && elected.selectedRecordHash == retained
                && saved.recordHash == retained && saved.nonce == 2500,
            "registration retains actual selected record, not a reconstructed guardian list"
        );
        _rrRecover(p, a, retained, true);
        _rrRound(1, true);
        require(
            keccak256(abi.encode(_status(oldExcluded))) == oldStatus,
            "earlier adjudication remains permanently exact"
        );
    }

    function testRepeatedDormancyRetainedPrefixGuardianStillVetoesNewRegistered35() public {
        this.rrStartExcluded();
        this.rrCompromise(rrWindow);
        (IdentityRecovery.Request memory p, T.Authorization memory a) = this.rrRequest();
        _rrRegister(p, a);
        this.rrAt(scheduled.notBefore + 1);
        this.vetoByGuardian(keccak256("retained original43 prefix still controls repeated35"));
        (, A.Veto memory veto,,) = _read();
        require(veto.vetoer == address(delegateSafe), "retained lower-nonce original guardian veto");
        scheduled.status = GovernanceActionStatus.EXECUTED;
        _publish();
        bytes32 roots = _roots();
        vm.expectRevert(abi.encodeWithSelector(A.RecoveryActionVetoed.selector, currentId));
        this.executeRegistered(p, a);
        _inactive();
        require(
            roots == _roots() && _rrHistory() == rrFrozen,
            "veto leaves every original record and prior exclusion intact"
        );
    }

    function testRepeatedDormancyEarlyClosed35ThenFresh33KeepsOriginalClosure() public {
        this.rrStart();
        bytes32 first = rrPrevious;
        this.rrCompromise(rrWindow - 1);
        this.rrDismiss();
        bytes32 closed = _rrClosure(first);
        this.rrCompromise(rrWindow + 1);
        (IdentityRecovery.Request memory p, T.Authorization memory a) = this.rrRequest();
        (,,, bytes32 head) = ingress.guardianSet(artistId);
        _rrRegister(p, a);
        _rrRecover(p, a, head, true);
        require(
            _rrClosure(first) == closed, "fresh episode cannot rewrite original closed35 dismissal"
        );
    }

    function testRepeatedDormancyStandingClosed35Then32AndStandingClosedTerminalKeepBothClosures()
        public
    {
        this.rrStart();
        bytes32 first = rrPrevious;
        this.rrStanding();
        bytes32 originalClosure = _rrClosure(first);
        bytes32 abandoned = ingress.lastArtistTransition(artistId);
        this.rrRotate();
        bytes32 terminal = rrTerminal;
        require(
            ingress.rotationRecord(terminal).terms.expectedPreviousTransitionRecordHash == abandoned
                && _snapshot(terminal).previousTransitionRecordHash == first,
            "pending stage predecessor and actual executed parent remain distinct"
        );
        this.rrStanding();
        bytes32 terminalClosure = _rrClosure(terminal);
        this.rrCompromise(rrWindow + 1);
        (IdentityRecovery.Request memory p, T.Authorization memory a) = this.rrRequest();
        (,,, bytes32 head) = ingress.guardianSet(artistId);
        _rrRegister(p, a);
        _rrRecover(p, a, head, true);
        require(
            _rrClosure(first) == originalClosure && _rrClosure(terminal) == terminalClosure,
            "independent original and terminal standing closures remain exact"
        );
    }

    function testRepeatedDormancyEarlyClosedTerminal32ThenFresh33RetainsExactClosure() public {
        this.rrStart();
        this.rrRotate();
        this.rrRotate();
        bytes32 terminal = rrTerminal;
        this.rrCompromise(rrWindow - 1);
        this.rrDismiss();
        bytes32 closed = _rrClosure(terminal);
        this.rrCompromise(rrWindow + 1);
        (IdentityRecovery.Request memory p, T.Authorization memory a) = this.rrRequest();
        (,,, bytes32 head) = ingress.guardianSet(artistId);
        _rrRegister(p, a);
        _rrRecover(p, a, head, true);
        require(
            _rrClosure(terminal) == closed, "original early32 closure is independently preserved"
        );
    }

    function _rrEarlyUnclosed(uint8 rotations) private {
        this.rrStart();
        for (uint256 i; i < rotations; ++i) {
            this.rrRotate();
        }
        this.rrCompromise(rrWindow - 1);
        (IdentityRecovery.Request memory p, T.Authorization memory a) = this.rrRequest();
        bytes32 roots = _roots();
        vm.expectRevert();
        ingress.identityRecoveryContext(p, a);
        this.rrAt(rrWindow + 1);
        vm.expectRevert();
        ingress.identityRecoveryContext(p, a);
        require(
            roots == _roots() && ingress.latestIdentityRecovery(artistId) == rrPrevious,
            "time cannot mature an unresolved early contest into a new admitted recovery"
        );
    }

    function testRepeatedDormancyUnclosedEarly35DoesNotMatureIntoRepeat() public {
        _rrEarlyUnclosed(0);
    }

    function testRepeatedDormancyUnclosedEarly32DoesNotMatureIntoRepeat() public {
        _rrEarlyUnclosed(1);
    }

    function _rrSlot(bytes memory getter, bytes32 value) private returns (bytes32 slot) {
        RepeatedDormancyStorageVm probe = RepeatedDormancyStorageVm(address(vm));
        probe.record();
        (bool ok,) = suite.owners[2].staticcall(getter);
        require(ok, "actual fixed-owner original getter");
        (bytes32[] memory reads,) = probe.accesses(suite.owners[2]);
        uint256 matches;
        for (uint256 i; i < reads.length; ++i) {
            if (vm.load(suite.owners[2], reads[i]) == value) {
                slot = reads[i];
                ++matches;
            }
        }
        require(
            value != 0 && matches == 1, "unique observed original slot, not guessed mapping layout"
        );
    }

    function _rrCorrupt(
        IdentityRecovery.Request memory p,
        T.Authorization memory a,
        bytes32 slot,
        bytes32 replacement,
        bytes32 context
    ) private {
        bytes32 original = vm.load(suite.owners[2], slot);
        require(replacement != original, "corruption changes original bytes");
        bytes32 roots = _roots();
        bytes32 history = _rrHistory();
        vm.store(suite.owners[2], slot, replacement);
        (bool ok,) =
            address(ingress).staticcall(abi.encodeCall(ingress.identityRecoveryContext, (p, a)));
        require(!ok, "altered original43 or admitted35 evidence rejects the same signed request");
        (bool used,) = ingress.rotationAcceptanceNonceState(artistId, p.newAddress, a.nonce);
        require(!used && roots == _roots(), "rejection leaves acceptance and Archive untouched");
        vm.store(suite.owners[2], slot, original);
        require(
            history == _rrHistory()
                && context == keccak256(abi.encode(ingress.identityRecoveryContext(p, a))),
            "exact original-byte restoration admits identical request and Safe signature"
        );
    }

    function _rrCorruptHash(
        IdentityRecovery.Request memory p,
        T.Authorization memory a,
        bytes memory getter,
        bytes32 value,
        bytes32 context
    ) private {
        _rrCorrupt(p, a, _rrSlot(getter, value), bytes32(uint256(value) ^ 1), context);
    }

    function testRepeatedDormancyRejectsAlteredOriginalNoticeTerminalVestingMaskAndEpochThenRetries()
        public
    {
        this.rrStartExcluded();
        _rrRound(1, false);
        this.rrRotate();
        this.rrCompromise(rrWindow);
        (IdentityRecovery.Request memory p, T.Authorization memory a) = this.rrRequest();
        bytes32 context = keccak256(abi.encode(ingress.identityRecoveryContext(p, a)));
        (Dormancy27.Notice memory notice,, Dormancy27.Terminal memory terminal) =
            IStreamArtistDormancy(address(ingress)).dormancyRecord(rrNotice);
        bytes memory read = abi.encodeCall(IStreamArtistDormancy.dormancyRecord, (rrNotice));
        _rrCorruptHash(p, a, read, notice.terms.evidenceHash, context);
        _rrCorruptHash(p, a, read, terminal.evidenceHash, context);
        _rrCorruptHash(
            p,
            a,
            abi.encodeCall(
                IStreamArtistGuardianVestingHistory.guardianVestingSnapshot, (artistId, rrOrigin)
            ),
            _snapshot(rrOrigin).commitment,
            context
        );
        // Plan packs address + class + uint32 mask. Locate that exact observed word before changing one bit.
        bytes32 planWord = bytes32(
            uint256(uint160(terminal.plan.authority))
                | (uint256(terminal.plan.authorityClass) << 160)
                | (uint256(terminal.plan.capabilities) << 168)
        );
        _rrCorrupt(
            p, a, _rrSlot(read, planWord), bytes32(uint256(planWord) ^ (uint256(1) << 168)), context
        );
        // The terminal's declared final uint64 epoch follows its full-word witness hash.
        bytes32 epochSlot = bytes32(uint256(_rrSlot(read, terminal.witnessHash)) + 1);
        require(
            vm.load(suite.owners[2], epochSlot) == bytes32(uint256(terminal.delegationEpoch)),
            "observed terminal epoch layout"
        );
        _rrCorrupt(p, a, epochSlot, bytes32(uint256(terminal.delegationEpoch) + 1), context);
        _rrCorruptHash(
            p,
            a,
            abi.encodeCall(IStreamArtistIdentityRecoveryOwner.identityRecoveryRecord, (rrPrevious)),
            ingress.identityRecoveryRecord(rrPrevious).contextHash,
            context
        );
        IdentityRecovery.Record memory prior = ingress.identityRecoveryRecord(rrPrevious);
        // acceptanceDigest, nonce, four packed uint64 timing fields, then the standalone epoch.
        bytes32 priorEpochSlot = bytes32(
            uint256(
                _rrSlot(
                    abi.encodeCall(
                        IStreamArtistIdentityRecoveryOwner.identityRecoveryRecord, (rrPrevious)
                    ),
                    prior.acceptanceDigest
                )
            ) + 3
        );
        require(
            vm.load(suite.owners[2], priorEpochSlot) == bytes32(uint256(prior.delegationEpoch)),
            "observed prior35 epoch layout"
        );
        _rrCorrupt(p, a, priorEpochSlot, bytes32(uint256(prior.delegationEpoch) + 1), context);
        (,,, bytes32 head) = ingress.guardianSet(artistId);
        _rrRegister(p, a);
        _rrRecover(p, a, head, true);
    }

    function testRepeatedDormancyClass4RequestCannotReplaceDesignatedRecoveryClass() public {
        this.rrStart();
        this.rrCompromise(rrWindow);
        (IdentityRecovery.Request memory p, T.Authorization memory a) = this.rrRequest();
        bytes32 context = keccak256(abi.encode(ingress.identityRecoveryContext(p, a)));
        bytes32 roots = _roots();
        p.vestedAuthorityClass = 4;
        vm.expectRevert();
        ingress.identityRecoveryContext(p, a);
        p.vestedAuthorityClass = 3;
        require(
            roots == _roots()
                && context == keccak256(abi.encode(ingress.identityRecoveryContext(p, a))),
            "class4 rejected without changing original class3 retry"
        );
    }

    function rrBeginBoundaryDormancy() external rrSelf returns (bytes32 notice) {
        uint64 last =
            IStreamArtistIdentityOwner(suite.owners[2]).identity(artistId).lastAuthorityActionAt;
        (uint64 inactivity,,) =
            ingress.artistWindowInfo(keccak256("ARTIST_DORMANCY_MIN_INACTIVITY_SECONDS"));
        vm.warp(uint256(last) + inactivity);
        Dormancy27.Initiation memory p = Dormancy27.Initiation(
            artistId, keccak256("held history original outreach"), "urn:held-history:outreach"
        );
        IStreamArtistDormancy dormancy = IStreamArtistDormancy(address(ingress));
        Dormancy27.Context memory x = dormancy.dormancyInitiationContext(p);
        ArtistUnitGovernance authority = ArtistUnitGovernance(manager.governanceAuthority());
        authority.configureContestReads(
            suite.roleRegistry, address(this), p.evidenceHash, "urn:held-history"
        );
        avm.mockCall(
            suite.roleRegistry,
            abi.encodeCall(
                IStreamRoleRegistry.hasRole,
                (keccak256("ROLE_ARTIST_DORMANCY_ADMIN"), address(this))
            ),
            abi.encode(true)
        );
        _rrGovernanceWitness(x.scopeHash, x.oldValueHash, x.newValueHash);
        authority.executeModuleContext(
            address(ingress),
            abi.encodeCall(IStreamArtistDormancy.initiateArtistDormancy, (p)),
            1,
            x.scopeHash,
            x.oldValueHash,
            x.newValueHash
        );
        _inactive();
        (notice,,) = dormancy.dormancyNotice(artistId);
    }

    function rrCompleteBoundaryDormancy(bytes32 notice) external rrSelf {
        IStreamArtistDormancy dormancy = IStreamArtistDormancy(address(ingress));
        (Dormancy27.Notice memory n,,) = dormancy.dormancyRecord(notice);
        vm.warp(n.noticeEndsAt);
        vm.roll(500);
        Dormancy27.Completion memory p = Dormancy27.Completion(
            artistId, notice, address(rotationSafe), keccak256("held history actual completion")
        );
        (Dormancy27.Context memory x,) = dormancy.dormancyCompletionContext(p);
        bytes memory evidence =
            IStreamArtistDormancyEvidence(address(ingress)).dormancyCompletionEvidence(p);
        ArtistUnitGovernance authority = ArtistUnitGovernance(manager.governanceAuthority());
        authority.configureContestReads(
            suite.roleRegistry, address(this), keccak256(evidence), "urn:held-history"
        );
        _rrGovernanceWitness(x.scopeHash, x.oldValueHash, x.newValueHash);
        authority.executeModuleContext(
            address(ingress),
            abi.encodeCall(IStreamArtistDormancy.completeArtistDormancy, (p)),
            1,
            x.scopeHash,
            x.oldValueHash,
            x.newValueHash
        );
        _inactive();
        (,, Dormancy27.Terminal memory terminal) = dormancy.dormancyRecord(notice);
        rrOrigin = terminal.recordHash;
        rrTerminal = rrOrigin;
        rrWindow = ingress.artistTransitionState(rrOrigin).postWindowEndsAt;
        _adoptRotatedSafe();
    }

    function testRepeatedDormancyLiving35ThenDesignated43AdmitsFreshClass3Context() public {
        _deployAppealSuite();
        _accept();
        _payout();
        this.testActualRecoverySnapshotSharesOneRevisionAndTwoReceiptsWithArchiveRetry();
        rrPrevious = ingress.latestIdentityRecovery(artistId);
        require(_snapshot(rrPrevious).authorityClass == 1, "actual earlier living35");
        _adoptRotatedSafe();
        _newRotationSafe(++rrNonce);
        Succ27.Designation memory plan = _successorTerms(address(rotationSafe), 2);
        plan.grantedCapabilities = 256;
        _successionRecord(plan);
        bytes32 notice = this.rrBeginBoundaryDormancy();
        this.rrCompleteBoundaryDormancy(notice);
        require(
            _snapshot(rrOrigin).previousTransitionRecordHash == rrPrevious
                && _snapshot(rrOrigin).authorityClass == 3
                && ingress.latestIdentityRecovery(artistId) == rrPrevious,
            "actual living35 precedes the new designated43 authority and remains the latest recovery"
        );
        this.rrCompromise(rrWindow);
        (IdentityRecovery.Request memory p, T.Authorization memory a) = this.rrRequest();
        bytes32 roots = _roots();
        IdentityRecovery.Context memory context = ingress.identityRecoveryContext(p, a);
        (,, Dormancy27.Terminal memory terminal) =
            IStreamArtistDormancy(address(ingress)).dormancyRecord(notice);
        (bool used,) = ingress.rotationAcceptanceNonceState(artistId, p.newAddress, a.nonce);
        require(
            !used && roots == _roots() && ingress.latestIdentityRecovery(artistId) == rrPrevious
                && context.incumbent == address(artist)
                && context.delegationEpoch == terminal.delegationEpoch
                && context.delegationEpoch
                    == ingress.identityRecoveryRecord(rrPrevious).delegationEpoch + 1
                && context.oldValueHash != 0 && context.newValueHash != 0,
            "fresh class3 context retains old living35 and uses the original43 epoch without consuming acceptance"
        );
    }
}

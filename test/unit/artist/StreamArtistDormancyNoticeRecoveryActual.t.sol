// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./StreamArtistDormancyRepeatedRecoveryActual.t.sol";
import {
    IStreamArtistDormancyOwner
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistDormancy.sol";

/// @notice Actual active-notice status2 contest/dismissal -> designated43 -> elected35.
/// @dev One existing Artist/Safe/Archive graph. The original notice, causes and receipts are real;
/// Core and governed scheduling use the inherited exact typed unit boundaries. No class4/hydration.
contract StreamArtistDormancyNoticeRecoveryActualTest is
    StreamArtistDormancyRepeatedRecoveryActualTest
{
    bytes32 private nrOrigin;
    bytes32 private nrNotice;
    bytes32 private nrTerminal;
    bytes32 private nrPrior;
    bytes32 private nrBefore43;
    bytes32 private nrDesignation;
    bytes32 private nrProtected;
    bytes32 private nrRetained;
    bytes32 private nrFrozen;
    bytes32 private nrElection;
    bytes32 private nrOriginalNotice;
    bytes32 private nrOldClosure;
    uint64 private nrWindow;
    uint64 private nrNoticeStart;
    uint64 private nrDeadline;
    uint32 private nrMask;
    uint256 private nrSalt = 87000;
    bytes32[] private nrRecoveries;
    bytes32[] private nrRotations;
    bytes32[] private nrExcluded;
    bytes32[] private nrDismissals;
    bytes32[] private nrNoticeCauses;
    bytes32[] private nrNoticeDismissals;

    modifier nrSelf() {
        require(msg.sender == address(this), "notice recovery fixture caller");
        _;
    }

    // mode: 0 no execution, 1 living32, 2 living35, 3 already-closed living35, 4 living35 -> living32.
    function nrSetup(uint8 mode) external nrSelf {
        require(mode <= 4, "bounded notice fixture mode");
        _deployAppealSuite();
        _accept();
        _payout();
        if (mode >= 2) {
            this.testActualRecoverySnapshotSharesOneRevisionAndTwoReceiptsWithArchiveRetry();
            nrPrior = ingress.latestIdentityRecovery(artistId);
            _nrReceipts(nrPrior);
            nrRecoveries.push(nrPrior);
            nrTerminal = nrPrior;
            nrWindow = ingress.artistTransitionState(nrPrior).postWindowEndsAt;
            _adoptRotatedSafe();
            if (mode == 3) {
                this.nrCompromise(nrWindow - 1);
                this.nrDismiss();
            }
            if (mode == 4) this.nrRotate();
        } else {
            _delegateSetup();
            if (mode == 1) {
                this.rrGuardian(address(delegateSafe), 10 days, 7);
                _newRotationSafe(++nrSalt);
                nrTerminal = _stageRotation(0);
                _executeTimedRotation(nrTerminal);
                _adoptRotatedSafe();
                nrRotations.push(nrTerminal);
                nrWindow = ingress.artistTransitionState(nrTerminal).postWindowEndsAt;
            }
        }
        nrBefore43 = nrTerminal;
        nrOldClosure = _nrClosure(nrBefore43);
        nrRetained = this.rrGuardian(address(delegateSafe), 10 days, 900);
        nrProtected = this.rrGuardian(address(artist), 20 days, 1000);
        _newRotationSafe(++nrSalt);
        Succ27.Designation memory plan = _successorTerms(address(rotationSafe), 2);
        plan.grantedCapabilities = 256;
        nrDesignation = _successionRecord(plan);
        nrNotice = this.rrBeginBoundaryDormancy();
        (Dormancy27.Notice memory n, uint8 phase, Dormancy27.Terminal memory t) =
            IStreamArtistDormancy(address(ingress)).dormancyRecord(nrNotice);
        nrOriginalNotice = keccak256(abi.encode(n));
        nrNoticeStart = n.initiatedAt;
        nrDeadline = n.noticeEndsAt;
        require(
            phase == 1 && t.recordHash == 0 && n.incumbent == address(artist)
                && IStreamArtistIdentityOwner(suite.owners[2]).identity(artistId).status == 2
                && ingress.latestIdentityRecovery(artistId) == nrPrior,
            "actual phase1 notice retains original living principal, deadline and latest35"
        );
        ArtistAppealUnitRoles(suite.roleRegistry).setAppeal(address(this), true);
    }

    function nrNoticeCompromise(uint64 when) external nrSelf {
        this.nrNoticeSubject(when, nrTerminal);
    }

    function nrNoticeSubject(uint64 when, bytes32 subject) external nrSelf {
        this.rrAt(when);
        this.nrRecordSubject(subject);
        Dismissal.Cause memory cause = ingress.currentIdentityContestCause(artistId);
        (bytes32 joined, uint8 phase, bytes32 terminal) = IStreamArtistDormancyOwner(
                suite.owners[2]
            ).dormancyResolutionState(artistId, cause.causeHash);
        require(
            cause.facts.priorStatus == 2 && cause.facts.authorityClass == 1
                && cause.facts.executedTransitionHash == nrBefore43
                && cause.facts.pendingTransitionHash == 0 && joined == nrNotice && phase == 1
                && terminal == 0
                && IStreamArtistIdentityOwner(suite.owners[2]).identity(artistId).status == 4,
            "actual op33 stores original priorStatus2 causeNotice join without completing or cancelling notice"
        );
        require(
            ingress.identityContestRecord(cause.facts.referenceHash).terms.subjectRecordHash
                == subject,
            "original op33 retains exact zero, current or historical subject separately from current execution"
        );
        nrNoticeCauses.push(cause.causeHash);
        _nrAssertNotice(4);
    }

    function nrNoticeDismiss() external nrSelf {
        bytes32 cause = ingress.currentIdentityContestCause(artistId).causeHash;
        this.nrDismiss();
        bytes32 record = ingress.latestIdentityContestDismissal(artistId);
        Dismissal.Record memory d = ingress.identityContestDismissalRecord(record);
        require(
            d.terms.expectedCauseHash == cause && d.authorityClass == 1 && d.restoredStatus == 2
                && d.incumbent == address(artist) && d.actionId != 0
                && d.governanceWitnessHash != 0,
            "actual dismissal restores notice status2, not ordinary living status1"
        );
        nrNoticeDismissals.push(record);
        _nrAssertNotice(2);
    }

    function nrEpisode(uint64 when) external nrSelf {
        this.nrNoticeCompromise(when);
        this.nrNoticeDismiss();
    }

    function _nrAssertNotice(uint8 expectedStatus) private view {
        (Dormancy27.Notice memory n, uint8 phase, Dormancy27.Terminal memory t) =
            IStreamArtistDormancy(address(ingress)).dormancyRecord(nrNotice);
        (bytes32 notice, uint8 currentPhase, bytes32 terminal) =
            IStreamArtistDormancy(address(ingress)).dormancyNotice(artistId);
        (uint8 status, uint64 end,) =
            IStreamArtistDormancy(address(ingress)).dormancyState(artistId);
        require(
            keccak256(abi.encode(n)) == nrOriginalNotice && phase == 1 && currentPhase == 1
                && notice == nrNotice && terminal == 0 && t.recordHash == 0
                && status == expectedStatus && end == nrDeadline
                && IStreamArtistIdentityOwner(suite.owners[2])
                .identity(artistId)
                .lastAuthorityActionAt == n.priorLivenessAt,
            "original active notice, deadline and liveness remain exact through each governed episode"
        );
    }

    function nrComplete() external nrSelf {
        // Active phase1 may persist past its deadline. Never rewind a later actual dismissal.
        if (block.timestamp < nrDeadline) this.rrAt(nrDeadline);
        IStreamArtistDormancy dormancy = IStreamArtistDormancy(address(ingress));
        Dormancy27.Completion memory p = Dormancy27.Completion(
            artistId,
            nrNotice,
            address(rotationSafe),
            keccak256("original notice completion after dismissal")
        );
        (Dormancy27.Context memory x, Dormancy27.Plan memory plan) =
            dormancy.dormancyCompletionContext(p);
        bytes memory evidence =
            IStreamArtistDormancyEvidence(address(ingress)).dormancyCompletionEvidence(p);
        require(
            keccak256(evidence)
                == keccak256(
                    abi.encode(
                        keccak256("6529STREAM_ARTIST_DORMANCY_COMPLETION_EVIDENCE_V1"),
                        uint16(1),
                        p,
                        plan
                    )
                ),
            "unchanged original43 completion evidence domain"
        );
        ArtistUnitGovernance authority = ArtistUnitGovernance(manager.governanceAuthority());
        authority.configureContestReads(
            suite.roleRegistry, address(this), keccak256(evidence), "urn:notice-recovery:completion"
        );
        _nrWitness(x.scopeHash, x.oldValueHash, x.newValueHash);
        authority.executeModuleContext(
            address(ingress),
            abi.encodeCall(IStreamArtistDormancy.completeArtistDormancy, (p)),
            1,
            x.scopeHash,
            x.oldValueHash,
            x.newValueHash
        );
        _inactive();
        (Dormancy27.Notice memory n, uint8 phase, Dormancy27.Terminal memory t) =
            dormancy.dormancyRecord(nrNotice);
        nrOrigin = t.recordHash;
        nrTerminal = nrOrigin;
        nrWindow = ingress.artistTransitionState(nrOrigin).postWindowEndsAt;
        _adoptRotatedSafe();
        Estate.AuthorityCapabilities memory caps = ingress.currentAuthorityCapabilities(artistId);
        nrMask = caps.effectiveCapabilities;
        require(
            phase == 3 && keccak256(abi.encode(n)) == nrOriginalNotice && t.noticeHash == nrNotice
                && t.plan.designation == nrDesignation && t.authorityClass == 3
                && caps.activationRecordHash == nrOrigin && nrMask == 256
                && ingress.latestIdentityRecovery(artistId) == nrPrior
                && t.delegationEpoch
                    == (nrPrior == 0
                            ? 1
                            : ingress.identityRecoveryRecord(nrPrior).delegationEpoch + 1)
                && _snapshot(nrOrigin).previousTransitionRecordHash == nrBefore43
                && _snapshot(nrOrigin).previousCommitment
                    == (nrBefore43 == 0 ? bytes32(0) : _snapshot(nrBefore43).commitment),
            "actual43 retains original notice, precise living predecessor and its separate current epoch"
        );
        for (uint256 i; i < nrNoticeCauses.length; ++i) {
            (bytes32 joined, uint8 currentPhase, bytes32 terminal) = IStreamArtistDormancyOwner(
                    suite.owners[2]
                ).dormancyResolutionState(artistId, nrNoticeCauses[i]);
            require(
                joined == nrNotice && currentPhase == 3 && terminal == nrOrigin,
                "historical causeNotice now points to this completed original notice without replaying live dismissal rules"
            );
        }
        for (uint256 i; i < nrNoticeDismissals.length; ++i) {
            require(
                ingress.identityContestDismissalRecord(nrNoticeDismissals[i]).dismissedAt
                    <= t.observedAt,
                "completion never predates an admitted active-notice dismissal"
            );
        }
    }

    function _nrWitness(bytes32 scope, bytes32 old_, bytes32 next_) private {
        address authority = manager.governanceAuthority();
        bytes32 actionId = keccak256("unit authority gas raise");
        avm.mockCall(
            authority,
            abi.encodeCall(IStreamGovernanceReads.currentAction, ()),
            abi.encode(true, actionId, uint8(1), scope, old_, next_)
        );
        (
            bool active,
            bytes32 id,
            uint8 class_,
            bytes32 observedScope,
            bytes32 observedOld,
            bytes32 observedNew
        ) = IStreamGovernanceReads(authority).currentAction();
        require(
            active && id == actionId && class_ == 1 && observedScope == scope && observedOld == old_
                && observedNew == next_,
            "exact active producer witness replaces inherited inactive mock"
        );
    }

    function nrCompromise(uint64 when) external nrSelf {
        this.rrAt(when);
        this.nrRecordCause();
    }

    function nrRecordCause() external nrSelf {
        this.nrRecordSubject(nrTerminal);
    }

    function nrRecordSubject(bytes32 subject) external nrSelf {
        ArtistAppealUnitRoles(suite.roleRegistry).setArbiter(address(artist), true);
        bytes32 evidence = keccak256(
            abi.encode(
                "notice recovery cause",
                nrTerminal,
                block.timestamp,
                ingress.latestIdentityContestDismissal(artistId)
            )
        );
        bytes32 reason = keccak256(abi.encode("notice recovery reason", evidence));
        ArtistUnitGovernance authority = ArtistUnitGovernance(manager.governanceAuthority());
        authority.configureContestReads(
            suite.roleRegistry, address(artist), reason, "urn:notice-recovery:cause"
        );
        (bytes32 scope, bytes32 old_, bytes32 next_) =
            ingress.identityContestGovernanceContext(artistId, subject, evidence, reason);
        _nrWitness(scope, old_, next_);
        authority.executeModuleContext(
            address(ingress),
            abi.encodeCall(
                IStreamArtistIdentityContest.contestArtistIdentity,
                (artistId, subject, evidence, reason)
            ),
            1,
            scope,
            old_,
            next_
        );
        _inactive();
        Dismissal.Cause memory cause = ingress.currentIdentityContestCause(artistId);
        require(
            cause.facts.kind == 1 && cause.facts.executedTransitionHash == nrTerminal
                && cause.facts.incumbent == address(artist)
                && cause.facts.authorityClass == (nrOrigin == 0 ? 1 : 3)
                && ingress.latestIdentityRecovery(artistId) == nrPrior,
            "new actual33 names the operative execution while preserving latest old35"
        );
    }

    function nrDismiss() external nrSelf {
        bytes32 first = ingress.identityTransitionClosure(artistId, nrTerminal).dismissalRecordHash;
        Dismissal.Request memory p = _dismissalRequest();
        ArtistAppealUnitRoles(suite.roleRegistry).setArbiter(address(artist), true);
        ArtistUnitGovernance authority = ArtistUnitGovernance(manager.governanceAuthority());
        authority.configureContestReads(
            suite.roleRegistry, address(artist), p.reasonHash, "urn:notice-recovery:dismissal"
        );
        Dismissal.Context memory x = ingress.identityContestDismissalContext(p);
        _nrWitness(x.scopeHash, x.oldValueHash, x.newValueHash);
        authority.executeModuleContext(
            address(ingress),
            abi.encodeCall(IStreamArtistIdentityDismissal.dismissArtistIdentityContest, (p)),
            1,
            x.scopeHash,
            x.oldValueHash,
            x.newValueHash
        );
        _inactive();
        nrDismissals.push(ingress.latestIdentityContestDismissal(artistId));
        require(
            ingress.identityTransitionClosure(artistId, nrTerminal).dismissalRecordHash
                == (nrTerminal == 0
                        ? bytes32(0)
                        : first == 0 ? ingress.latestIdentityContestDismissal(artistId) : first),
            "first original closure remains fixed"
        );
        if (nrTerminal == 0) {
            Dismissal.Closure memory empty;
            require(
                keccak256(abi.encode(ingress.identityTransitionClosure(artistId, 0)))
                    == keccak256(abi.encode(empty)),
                "zero execution has no fabricated closure"
            );
        }
    }

    function _nrMature() private {
        if (
            ingress.identityTransitionClosure(artistId, nrTerminal).dismissalRecordHash == 0
                && block.timestamp < nrWindow
        ) {
            this.rrAt(nrWindow);
        }
    }

    function nrRotate() external nrSelf {
        _nrMature();
        bytes32 previous = nrTerminal;
        _newRotationSafe(++nrSalt);
        nrTerminal = _stageRotation(ingress.lastArtistTransition(artistId));
        _executeTimedRotation(nrTerminal);
        _adoptRotatedSafe();
        nrRotations.push(nrTerminal);
        nrWindow = ingress.artistTransitionState(nrTerminal).postWindowEndsAt;
        Estate.AuthorityCapabilities memory caps = ingress.currentAuthorityCapabilities(artistId);
        require(
            _snapshot(nrTerminal).previousTransitionRecordHash == previous
                && _snapshot(nrTerminal).previousCommitment == _snapshot(previous).commitment
                && ingress.latestIdentityRecovery(artistId) == nrPrior
                && caps.authorityClass == (nrOrigin == 0 ? 1 : 3)
                && caps.activationRecordHash == nrOrigin,
            "actual32 retains exact executed parent, latest35 and original43"
        );
    }

    function nrStanding() external nrSelf {
        _nrMature();
        _newRotationSafe(++nrSalt);
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
            "real Safe standing veto"
        );
        Dismissal.Cause memory cause = ingress.currentIdentityContestCause(artistId);
        require(
            cause.facts.kind == 2 && cause.facts.executedTransitionHash == nrTerminal
                && cause.facts.pendingTransitionHash == pending && cause.facts.evidenceHash == 0
                && cause.facts.reasonHash == 0,
            "original zero-reason standing producer"
        );
        this.nrDismiss();
    }

    function nrRequest(bytes32 first, bytes32 second)
        external
        nrSelf
        returns (IdentityRecovery.Request memory p, T.Authorization memory a)
    {
        _newRotationSafe(++nrSalt);
        Dismissal.Cause memory cause = ingress.currentIdentityContestCause(artistId);
        bytes32[] memory excluded = new bytes32[](first == 0 ? 0 : second == 0 ? 1 : 2);
        if (first != 0) excluded[0] = first;
        if (second != 0) {
            excluded[1] = second;
            if (first > second) (excluded[0], excluded[1]) = (second, first);
        }
        p = IdentityRecovery.Request(
            artistId,
            address(rotationSafe),
            cause.facts.authorityClass,
            cause.causeHash,
            ingress.latestIdentityContestDismissal(artistId),
            cause.facts.evidenceHash,
            cause.facts.reasonHash,
            excluded
        );
        a = _acceptance(p);
    }

    function _nrClosure(bytes32 record) private view returns (bytes32) {
        Dismissal.Closure memory c = ingress.identityTransitionClosure(artistId, record);
        Dismissal.Record memory d = ingress.identityContestDismissalRecord(c.dismissalRecordHash);
        Dismissal.Cause memory cause = ingress.identityContestCause(d.terms.expectedCauseHash);
        return keccak256(
            abi.encode(c, d, cause, ingress.rotationRecord(cause.facts.pendingTransitionHash))
        );
    }

    function _nrHistory() private view returns (bytes32 value) {
        if (nrOrigin != 0) {
            (Dormancy27.Notice memory n, uint8 phase, Dormancy27.Terminal memory t) =
                IStreamArtistDormancy(address(ingress)).dormancyRecord(nrNotice);
            value = keccak256(
                abi.encode(
                    n,
                    phase,
                    t,
                    _snapshot(nrOrigin),
                    ingress.artistTransitionState(nrOrigin),
                    _nrClosure(nrOrigin)
                )
            );
        }
        value = keccak256(abi.encode(value, ingress.successorDesignationRecord(nrDesignation)));
        for (uint256 i; i < nrRecoveries.length; ++i) {
            bytes32 record = nrRecoveries[i];
            (bytes32 primary, bytes32 occurrence, bytes32 secondary) =
                IStreamArtistIdentityRecoveryOwner(suite.owners[2]).identityRecoveryReceipts(record);
            value = keccak256(
                abi.encode(
                    value,
                    ingress.identityRecoveryRecord(record),
                    _snapshot(record),
                    ingress.artistTransitionState(record),
                    _nrClosure(record),
                    primary,
                    occurrence,
                    secondary
                )
            );
        }
        for (uint256 i; i < nrRotations.length; ++i) {
            bytes32 record = nrRotations[i];
            value = keccak256(
                abi.encode(
                    value, ingress.rotationRecord(record), _snapshot(record), _nrClosure(record)
                )
            );
        }
        for (uint256 i; i < nrExcluded.length; ++i) {
            value = keccak256(abi.encode(value, _status(nrExcluded[i])));
        }
        for (uint256 i; i < nrDismissals.length; ++i) {
            Dismissal.Record memory d = ingress.identityContestDismissalRecord(nrDismissals[i]);
            value = keccak256(
                abi.encode(value, d, ingress.identityContestCause(d.terms.expectedCauseHash))
            );
        }
        for (uint256 i; i < nrNoticeCauses.length; ++i) {
            Dismissal.Cause memory cause = ingress.identityContestCause(nrNoticeCauses[i]);
            (bytes32 notice, uint8 phase, bytes32 terminal) = IStreamArtistDormancyOwner(
                    suite.owners[2]
                ).dormancyResolutionState(artistId, nrNoticeCauses[i]);
            value = keccak256(
                abi.encode(
                    value,
                    cause,
                    ingress.identityContestRecord(cause.facts.referenceHash),
                    notice,
                    phase,
                    terminal
                )
            );
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

    function _nrRegister(IdentityRecovery.Request memory p, T.Authorization memory a, bool appeal)
        private
    {
        GovernanceCall[] memory calls = _schedule(
            keccak256(abi.encode("notice recovery action", nrPrior, nrTerminal, nrSalt)), p, a
        );
        if (appeal) {
            scheduled.proposer = address(this);
            ArtistUnitGovernance(manager.governanceAuthority())
                .configureContestReads(
                    suite.roleRegistry, address(this), p.reasonHash, scheduled.reasonURI
                );
            _publish();
        }
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
            "registration binds exact request and complete current history"
        );
        nrFrozen = _nrHistory();
    }

    function _nrElect(IdentityRecovery.Request memory p, T.Authorization memory a, bytes32 selected)
        private
    {
        IStreamArtistGuardianSelectionPreparation prep = _selectionPreparation();
        nrElection = prep.begin(artistId, nrTerminal, p.supersededRecordHashes);
        (GH.Head memory head,,,) = IStreamArtistGuardianHistory(suite.owners[2])
            .guardianHistoryState(artistId, 0, address(0), 0);
        bytes32 roots = _roots();
        vm.expectRevert(
            abi.encodeWithSelector(
                Selection.IncompleteGuardianSelection.selector, nrElection, uint64(0), head.count
            )
        );
        ingress.identityRecoveryContext(p, a);
        Selection.Progress memory progress = prep.continueSelection(nrElection, 1);
        require(!progress.complete, "partial guardian prefix is not complete election");
        progress = prep.continueSelection(nrElection, 64);
        require(
            progress.complete && progress.processed == head.count
                && progress.selectedRecordHash == selected && roots == _roots(),
            "complete original-record election"
        );
    }

    function _nrRecover(
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
        if (retry) _nrRollback(p, a, epoch);
        vm.recordLogs();
        record = this.executeRegistered(p, a);
        _assertSnapshot(_snapshot(record), 35, before_, vm.getRecordedLogs());
        _nrReceipts(record);
        IdentityRecovery.Record memory r = ingress.identityRecoveryRecord(record);
        Estate.AuthorityCapabilities memory caps = ingress.currentAuthorityCapabilities(artistId);
        (,,, bytes32 head) = ingress.guardianSet(artistId);
        (bool used,) = ingress.rotationAcceptanceNonceState(artistId, p.newAddress, a.nonce);
        require(
            caps.authorityClass == p.vestedAuthorityClass && caps.status == p.vestedAuthorityClass
                && caps.authorityAddress == p.newAddress && r.delegationEpoch == epoch + 1
                && _snapshot(record).previousTransitionRecordHash == nrTerminal
                && _snapshot(record).previousCommitment == _snapshot(nrTerminal).commitment && used
                && head == selected && _nrHistory() == nrFrozen
                && r.fields.supersededRecordsHash
                    == RecoveryHashes.supersession(p.supersededRecordHashes)
                && keccak256(abi.encode(r.terms.supersededRecordHashes))
                    == keccak256(abi.encode(p.supersededRecordHashes)),
            "actual35 increments current epoch, preserves every original record and applies only exact exclusions"
        );
        if (nrOrigin != 0) {
            require(
                caps.activationRecordHash == nrOrigin && caps.effectiveCapabilities == nrMask,
                "all later class3 recoveries retain exact original43 capabilities"
            );
        }
        for (uint256 i; i < p.supersededRecordHashes.length; ++i) {
            GS.Status memory status = _status(p.supersededRecordHashes[i]);
            require(
                status.recoveryRecordHash == record && status.actionId == currentId,
                "exact permanent adjudication"
            );
        }
        require(
            _status(selected).recoveryRecordHash == 0
                && _operationPayload(35, manager.governanceAuthority(), record).length != 0,
            "retained original head and actual Archive payload"
        );
        bytes32 roots = _roots();
        (bool ok,) = address(this).call(abi.encodeCall(this.executeRegistered, (p, a)));
        _inactive();
        require(
            !ok && roots == _roots() && _nrHistory() == nrFrozen,
            "identical old action cannot replay"
        );
        nrRecoveries.push(record);
        for (uint256 i; i < p.supersededRecordHashes.length; ++i) {
            nrExcluded.push(p.supersededRecordHashes[i]);
        }
        nrPrior = record;
        nrTerminal = record;
        nrWindow = ingress.artistTransitionState(record).postWindowEndsAt;
        _adoptRotatedSafe();
    }

    function _nrRollback(IdentityRecovery.Request memory p, T.Authorization memory a, uint64 epoch)
        private
    {
        bytes32 roots = _roots();
        bytes32 request = keccak256(abi.encode(p, a));
        bytes32 principal =
            keccak256(abi.encode(IStreamArtistIdentityOwner(suite.owners[2]).identity(artistId)));
        (,,, bytes32 oldHead) = ingress.guardianSet(artistId);
        uint256 nonce = rotationSafe.nonce();
        _overflow();
        this.executeRegistered(p, a);
        _inactive();
        (,,, bytes32 head) = ingress.guardianSet(artistId);
        (bool used,) = ingress.rotationAcceptanceNonceState(artistId, p.newAddress, a.nonce);
        require(
            !used && roots == _roots() && nrFrozen == _nrHistory()
                && ingress.latestIdentityRecovery(artistId) == nrPrior && head == oldHead
                && rotationSafe.nonce() == nonce
                && ingress.identityRecoveryContext(p, a).delegationEpoch == epoch
                && principal
                    == keccak256(
                        abi.encode(IStreamArtistIdentityOwner(suite.owners[2]).identity(artistId))
                    ),
            "late Archive failure restores old35/43 history, epoch, principal, heads and acceptance"
        );
        for (uint256 i; i < p.supersededRecordHashes.length; ++i) {
            require(
                _status(p.supersededRecordHashes[i]).recoveryRecordHash == 0,
                "no failed adjudication"
            );
        }
        vm.roll(restoreBlock);
        require(
            request == keccak256(abi.encode(p, a)),
            "byte-identical request and Safe signature retry"
        );
    }

    // Independent original thirteen-word receipt oracle; receipt commitments are not record IDs.
    function _nrReceipts(bytes32 record) private view {
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

    function _nrRound(uint8 rotations, bool retry) private returns (bytes32 record) {
        for (uint256 i; i < rotations; ++i) {
            this.nrRotate();
        }
        this.nrCompromise(nrWindow);
        (IdentityRecovery.Request memory p, T.Authorization memory a) = this.nrRequest(0, 0);
        (,,, bytes32 head) = ingress.guardianSet(artistId);
        _nrRegister(p, a, false);
        return _nrRecover(p, a, head, retry);
    }

    function _nrPublisher() private view returns (IStreamArtistGuardianAppealEvidence publisher) {
        address child = StreamArtistIdentityAuthority(suite.owners[2]).identityRecoveryExtension();
        (address target, bytes32 codeHash) =
            IStreamArtistGuardianAppealBinding(child).guardianAppealEvidenceBinding();
        require(codeHash != 0 && target.codehash == codeHash, "pinned appeal evidence publisher");
        publisher = IStreamArtistGuardianAppealEvidence(target);
        require(
            publisher.owner() == suite.owners[2] && publisher.artistRegistry() == address(ingress),
            "same fixed owner graph"
        );
    }

    function _nrAppeal(IdentityRecovery.Request memory p, bytes32 protectedRecord)
        private
        returns (IdentityRecovery.Request memory, T.Authorization memory)
    {
        Dismissal.Cause memory cause = ingress.currentIdentityContestCause(artistId);
        Appeal27.Document memory document = Appeal27.Document(
            Appeal27.requestCommitment(p),
            cause.causeHash,
            cause.facts.referenceHash,
            _snapshot(nrTerminal).commitment,
            nrTerminal,
            keccak256("notice recovery specific findings"),
            new Appeal27.Finding[](1)
        );
        address[] memory parties = ingress.guardianSetRecord(protectedRecord).terms.guardians;
        document.findings[0] = Appeal27.Finding(protectedRecord, parties);
        bytes32 roots = _roots();
        bytes32 latest = ingress.latestIdentityRecovery(artistId);
        p.evidenceHash = _nrPublisher().publish(document);
        require(
            roots == _roots() && ingress.latestIdentityRecovery(artistId) == latest
                && p.evidenceHash
                    == Appeal27.documentHash(
                        block.chainid, address(ingress), suite.owners[2], document
                    ),
            "publication authenticates exact original facts without granting recovery authority"
        );
        return (p, _acceptance(p));
    }

    function _nrRole(IdentityRecovery.Request memory p, bytes32 expected) private view {
        require(
            IStreamArtistGuardianAppealOwner(suite.owners[2])
                .guardianRecoveryAuthorityRole(artistId, p.supersededRecordHashes) == expected,
            "exact current cutoff determines protected APPEAL or later-principal ARBITER"
        );
    }

    function _nrSlot(bytes memory getter, bytes32 expected) private returns (bytes32 slot) {
        RepeatedDormancyStorageVm probe = RepeatedDormancyStorageVm(address(vm));
        probe.record();
        (bool ok,) = suite.owners[2].staticcall(getter);
        require(ok, "fixed owner original read succeeds");
        (bytes32[] memory reads,) = probe.accesses(suite.owners[2]);
        uint256 matches;
        for (uint256 i; i < reads.length; ++i) {
            if (vm.load(suite.owners[2], reads[i]) == expected) {
                slot = reads[i];
                ++matches;
            }
        }
        require(expected != 0 && matches == 1, "unique observed original storage field");
    }

    function _nrCorrupt(
        IdentityRecovery.Request memory p,
        T.Authorization memory a,
        bytes32 slot,
        bytes32 replacement,
        bytes32 context
    ) private {
        bytes32 original = vm.load(suite.owners[2], slot);
        require(original != replacement, "corruption changes original bytes");
        bytes32 roots = _roots();
        bytes32 history = _nrHistory();
        vm.store(suite.owners[2], slot, replacement);
        (bool ok,) =
            address(ingress).staticcall(abi.encodeCall(ingress.identityRecoveryContext, (p, a)));
        require(!ok, "same signed request rejects corrupted original proof");
        (bool used,) = ingress.rotationAcceptanceNonceState(artistId, p.newAddress, a.nonce);
        require(!used && roots == _roots(), "failed read cannot consume nonce or Archive state");
        vm.store(suite.owners[2], slot, original);
        require(
            history == _nrHistory()
                && context == keccak256(abi.encode(ingress.identityRecoveryContext(p, a))),
            "exact restoration admits byte-identical request and signature"
        );
    }

    function _nrCorruptHash(
        IdentityRecovery.Request memory p,
        T.Authorization memory a,
        bytes memory getter,
        bytes32 value,
        bytes32 context
    ) private {
        _nrCorrupt(p, a, _nrSlot(getter, value), bytes32(uint256(value) ^ 1), context);
    }

    // The canonical map and the original notice record contain the same hash. Distinguish them
    // by the fixed-owner getter's empty-join behavior, restoring every probed word immediately.
    function _nrCauseNoticeSlot(bytes32 cause) private returns (bytes32 slot) {
        RepeatedDormancyStorageVm probe = RepeatedDormancyStorageVm(address(vm));
        bytes memory getter =
            abi.encodeCall(IStreamArtistDormancyOwner.dormancyResolutionState, (artistId, cause));
        probe.record();
        (bool ok,) = suite.owners[2].staticcall(getter);
        require(ok, "actual original causeNotice read");
        (bytes32[] memory reads,) = probe.accesses(suite.owners[2]);
        uint256 matches;
        for (uint256 i; i < reads.length; ++i) {
            if (vm.load(suite.owners[2], reads[i]) != nrNotice) continue;
            vm.store(suite.owners[2], reads[i], 0);
            (bool healthy, bytes memory raw) = suite.owners[2].staticcall(getter);
            vm.store(suite.owners[2], reads[i], nrNotice);
            if (healthy && raw.length == 96) {
                (bytes32 notice, uint8 phase, bytes32 terminal) =
                    abi.decode(raw, (bytes32, uint8, bytes32));
                if (notice == 0 && phase == 0 && terminal == 0) {
                    slot = reads[i];
                    ++matches;
                }
            }
        }
        require(matches == 1, "one observed canonical causeNotice map entry");
    }

    function _nrEmptyClosure(
        IdentityRecovery.Request memory p,
        T.Authorization memory a,
        bytes32 dismissalSlot,
        bytes32 context
    ) private {
        // Locate the actual struct by its uniquely observed dismissal field, then verify all
        // four original words against the typed getter before touching the complete closure.
        Dismissal.Closure memory c = ingress.identityTransitionClosure(artistId, nrBefore43);
        bytes32 base = bytes32(uint256(dismissalSlot) - 2);
        bytes32[4] memory saved;
        for (uint256 i; i < 4; ++i) {
            saved[i] = vm.load(suite.owners[2], bytes32(uint256(base) + i));
        }
        require(
            saved[0] == c.artistId && saved[1] == c.transitionRecordHash
                && saved[2] == c.dismissalRecordHash
                && saved[3]
                    == bytes32(
                        uint256(c.windowEndsAt) | uint256(c.contestedAt) << 64
                            | uint256(c.abandoned ? 1 : 0) << 128
                    ),
            "observed full closure matches original typed storage layout"
        );
        bytes32 roots = _roots();
        bytes32 history = _nrHistory();
        for (uint256 i; i < 4; ++i) {
            vm.store(suite.owners[2], bytes32(uint256(base) + i), 0);
        }
        Dismissal.Closure memory empty;
        require(
            keccak256(abi.encode(ingress.identityTransitionClosure(artistId, nrBefore43)))
                == keccak256(abi.encode(empty)),
            "entire nonzero predecessor closure is absent"
        );
        (bool ok,) =
            address(ingress).staticcall(abi.encodeCall(ingress.identityRecoveryContext, (p, a)));
        (bool used,) = ingress.rotationAcceptanceNonceState(artistId, p.newAddress, a.nonce);
        require(
            !ok && !used && _roots() == roots,
            "missing first closure cannot admit or mutate recovery"
        );
        for (uint256 i; i < 4; ++i) {
            vm.store(suite.owners[2], bytes32(uint256(base) + i), saved[i]);
        }
        require(
            history == _nrHistory()
                && context == keccak256(abi.encode(ingress.identityRecoveryContext(p, a))),
            "complete original closure restore admits identical request"
        );
    }

    function testDormancyNoticeZeroExecutionRestoresOriginalNoticeThenRecoversWithExactReceipts()
        public
    {
        this.nrSetup(0);
        this.nrEpisode(nrNoticeStart + 1);
        require(
            nrBefore43 == 0
                && ingress.identityTransitionClosure(artistId, 0).dismissalRecordHash == 0,
            "no invented initial execution or closure"
        );
        this.nrComplete();
        bytes32 record = _nrRound(0, true);
        require(
            ingress.identityRecoveryRecord(record).delegationEpoch == 2
                && _snapshot(nrOrigin).previousTransitionRecordHash == 0,
            "zero predecessor keeps exact43 then35 epochs"
        );
    }

    function testDormancyNoticeLiving32ZeroSubjectClosesActualExecutionAndAllowsRotationRecovery()
        public
    {
        this.nrSetup(1);
        this.nrNoticeSubject(nrNoticeStart + 1, 0);
        this.nrNoticeDismiss();
        require(
            ingress.identityTransitionClosure(artistId, nrBefore43).dismissalRecordHash
                    == nrNoticeDismissals[0]
                && ingress.identityContestCause(nrNoticeCauses[0]).facts.executedTransitionHash
                == nrBefore43,
            "zero op33 subject still closes actual living32 execution"
        );
        this.nrComplete();
        _nrRound(1, true);
    }

    function testDormancyNoticePreviouslyUnclosedLiving35GetsFirstClosureInsideNotice() public {
        this.nrSetup(2);
        require(
            ingress.identityTransitionClosure(artistId, nrBefore43).dismissalRecordHash == 0,
            "original35 unclosed at initiation"
        );
        this.nrEpisode(nrNoticeStart + 1);
        Dismissal.Closure memory c = ingress.identityTransitionClosure(artistId, nrBefore43);
        require(
            c.dismissalRecordHash == nrNoticeDismissals[0] && c.contestedAt > nrNoticeStart
                && !c.abandoned
                && ingress.identityContestDismissalRecord(c.dismissalRecordHash).restoredStatus
                    == 2,
            "first notice closure is authenticated separately from a pre-init living closure"
        );
        bytes32 living = nrPrior;
        this.nrComplete();
        bytes32 record = _nrRound(0, true);
        require(
            ingress.identityRecoveryRecord(living).delegationEpoch == 1
                && ingress.identityRecoveryRecord(record).delegationEpoch == 3,
            "original living35 and later class3 epochs remain distinct"
        );
    }

    function testDormancyNoticeEarlierClass1ClosureRemainsDistinctFromMultipleNoticeDismissals()
        public
    {
        this.nrSetup(3);
        bytes32 original =
            ingress.identityTransitionClosure(artistId, nrBefore43).dismissalRecordHash;
        require(
            ingress.identityContestDismissalRecord(original).restoredStatus == 1,
            "pre-init actual living closure"
        );
        this.nrEpisode(nrNoticeStart + 1);
        this.nrEpisode(nrNoticeStart + 2);
        require(
            _nrClosure(nrBefore43) == nrOldClosure
                && ingress.identityContestDismissalRecord(nrNoticeDismissals[0]).terms
                        .expectedResolutionHash == original
                && ingress.identityContestDismissalRecord(nrNoticeDismissals[1]).terms
                    .expectedResolutionHash == nrNoticeDismissals[0],
            "contiguous status2 suffix preserves separate first class1 closure and exact prior resolution links"
        );
        this.nrComplete();
        _nrRound(2, true);
        require(
            _nrClosure(nrBefore43) == nrOldClosure,
            "first living closure remains byte-identical after rotations and recovery"
        );
    }

    function testDormancyNoticeThreeEpisodesKeepOriginalDeadlineAndAllCauseNoticeJoins() public {
        this.nrSetup(0);
        this.nrEpisode(nrNoticeStart + 1);
        this.nrEpisode(nrNoticeStart + 2);
        this.nrEpisode(nrDeadline - 1);
        require(
            nrNoticeCauses.length == 3 && nrNoticeDismissals.length == 3,
            "three actual notice episodes"
        );
        this.nrComplete();
        _nrRound(0, true);
    }

    function testDormancyNoticeAfterDeadlineEpisodeRemainsActiveAndCompletionNeverRewinds() public {
        this.nrSetup(2);
        this.nrEpisode(nrDeadline + 1);
        uint64 dismissed = ingress.identityContestDismissalRecord(nrNoticeDismissals[0]).dismissedAt;
        require(dismissed > nrDeadline, "actual phase1 dismissal occurs after original deadline");
        this.nrComplete();
        (Dormancy27.Notice memory n,, Dormancy27.Terminal memory t) =
            IStreamArtistDormancy(address(ingress)).dormancyRecord(nrNotice);
        require(
            n.noticeEndsAt == nrDeadline && t.observedAt >= dismissed,
            "original deadline retained without time rewind"
        );
        _nrRound(1, true);
    }

    function testDormancyNoticeUnresolvedCompromiseBlocksCompletionUntilExactDismissal() public {
        this.nrSetup(0);
        this.nrNoticeCompromise(nrNoticeStart + 1);
        bytes32 roots = _roots();
        vm.expectRevert(abi.encodeWithSelector(Dormancy27.InvalidDormancy.selector, artistId));
        this.nrComplete();
        require(
            roots == _roots() && nrOrigin == 0,
            "unresolved notice cannot complete or change Archive roots"
        );
        _nrAssertNotice(4);
        this.nrNoticeDismiss();
        this.nrComplete();
        _nrRound(0, true);
    }

    function testDormancyNoticeLaterArbiterGuardianElectionRetainsOriginalNoticeHistory() public {
        this.nrSetup(2);
        this.nrEpisode(nrNoticeStart + 1);
        this.nrComplete();
        bytes32 post = this.rrGuardian(address(artist), 25 days, 3000);
        bytes32 retained = this.rrGuardian(address(delegateSafe), 10 days, 2500);
        this.nrCompromise(nrWindow);
        (IdentityRecovery.Request memory p, T.Authorization memory a) = this.nrRequest(post, 0);
        _nrRole(p, Appeal27.ARBITER);
        _nrElect(p, a, retained);
        _nrRegister(p, a, false);
        _nrRecover(p, a, retained, true);
    }

    function testDormancyNoticeProtectedAppealUsesCurrentCompromiseAndOriginalNoticeEvidenceSeparately()
        public
    {
        this.nrSetup(2);
        this.nrEpisode(nrNoticeStart + 1);
        this.nrComplete();
        this.nrCompromise(nrWindow);
        (IdentityRecovery.Request memory p, T.Authorization memory a) =
            this.nrRequest(nrProtected, 0);
        _nrRole(p, Appeal27.APPEAL);
        vm.expectRevert(
            abi.encodeWithSelector(Appeal27.InvalidGuardianAppeal.selector, p.evidenceHash)
        );
        ingress.identityRecoveryContext(p, a);
        Dismissal.Cause memory old = ingress.identityContestCause(nrNoticeCauses[0]);
        Appeal27.Document memory wrong = Appeal27.Document(
            Appeal27.requestCommitment(p),
            old.causeHash,
            old.facts.referenceHash,
            _snapshot(nrTerminal).commitment,
            nrTerminal,
            keccak256("notice evidence cannot replace current class3 compromise"),
            new Appeal27.Finding[](1)
        );
        address[] memory parties = ingress.guardianSetRecord(nrProtected).terms.guardians;
        wrong.findings[0] = Appeal27.Finding(nrProtected, parties);
        p.evidenceHash = _nrPublisher().publish(wrong);
        a = _acceptance(p);
        vm.expectRevert(
            abi.encodeWithSelector(Appeal27.InvalidGuardianAppeal.selector, p.evidenceHash)
        );
        ingress.identityRecoveryContext(p, a);
        (p, a) = _nrAppeal(p, nrProtected);
        _nrElect(p, a, nrRetained);
        _nrRegister(p, a, true);
        _nrRecover(p, a, nrRetained, true);
    }

    function testDormancyNoticeLaterClass3RecoveryRoundsKeepEveryOriginalStatus2Episode() public {
        this.nrSetup(3);
        this.nrEpisode(nrNoticeStart + 1);
        this.nrEpisode(nrDeadline + 1);
        this.nrComplete();
        _nrRound(1, true);
        _nrRound(2, true);
        bytes32 record = _nrRound(0, true);
        require(
            ingress.identityRecoveryRecord(record).delegationEpoch == 5
                && ingress.currentAuthorityCapabilities(artistId).activationRecordHash == nrOrigin
                && ingress.identityContestDismissalRecord(nrNoticeDismissals[0]).restoredStatus == 2
                && ingress.identityContestDismissalRecord(nrNoticeDismissals[1]).restoredStatus
                    == 2,
            "later repeated35 rounds retain every original notice episode and original43 capability origin"
        );
    }

    function testDormancyNoticeMissingCanonicalCauseNoticeJoinRejectsThenExactRestoreRetries()
        public
    {
        this.nrSetup(2);
        this.nrEpisode(nrNoticeStart + 1);
        this.nrEpisode(nrNoticeStart + 2);
        this.nrComplete();
        this.nrRotate();
        this.nrCompromise(nrWindow);
        (IdentityRecovery.Request memory p, T.Authorization memory a) = this.nrRequest(0, 0);
        bytes32 context = keccak256(abi.encode(ingress.identityRecoveryContext(p, a)));
        for (uint256 i; i < nrNoticeCauses.length; ++i) {
            _nrCorrupt(p, a, _nrCauseNoticeSlot(nrNoticeCauses[i]), 0, context);
        }
        (,,, bytes32 head) = ingress.guardianSet(artistId);
        _nrRegister(p, a, false);
        _nrRecover(p, a, head, true);
    }

    function testDormancyNoticeLaterDismissalCannotReplaceOrEraseOriginalFirstNoticeClosure()
        public
    {
        this.nrSetup(2);
        this.nrEpisode(nrNoticeStart + 1);
        this.nrEpisode(nrNoticeStart + 2);
        this.nrComplete();
        this.nrCompromise(nrWindow);
        (IdentityRecovery.Request memory p, T.Authorization memory a) = this.nrRequest(0, 0);
        bytes32 context = keccak256(abi.encode(ingress.identityRecoveryContext(p, a)));
        bytes32 slot = _nrSlot(
            abi.encodeCall(ingress.identityTransitionClosure, (artistId, nrBefore43)),
            nrNoticeDismissals[0]
        );
        _nrCorrupt(p, a, slot, nrNoticeDismissals[1], context);
        _nrEmptyClosure(p, a, slot, context);
        (,,, bytes32 head) = ingress.guardianSet(artistId);
        _nrRegister(p, a, false);
        _nrRecover(p, a, head, true);
    }

    function testDormancyNoticeOriginalRestoredStatusAndDismissalCommitmentsRejectCorruptionThenRetry()
        public
    {
        this.nrSetup(3);
        this.nrEpisode(nrNoticeStart + 1);
        this.nrComplete();
        this.nrCompromise(nrWindow);
        (IdentityRecovery.Request memory p, T.Authorization memory a) = this.nrRequest(0, 0);
        bytes32 context = keccak256(abi.encode(ingress.identityRecoveryContext(p, a)));
        Dismissal.Record memory d = ingress.identityContestDismissalRecord(nrNoticeDismissals[0]);
        bytes memory getter = abi.encodeCall(ingress.identityContestDismissalRecord, (d.recordHash));
        _nrCorruptHash(p, a, getter, d.cohortHash, context);
        _nrCorruptHash(p, a, getter, d.governanceWitnessHash, context);
        bytes32 packed = bytes32(
            uint256(uint160(d.incumbent)) | uint256(d.authorityClass) << 160
                | uint256(d.restoredStatus) << 168 | uint256(d.dismissedAt) << 176
        );
        _nrCorrupt(
            p, a, _nrSlot(getter, packed), bytes32(uint256(packed) ^ (uint256(3) << 168)), context
        );
        bytes32 original =
            ingress.identityTransitionClosure(artistId, nrBefore43).dismissalRecordHash;
        require(original != d.recordHash, "separate original pre-init closure");
        _nrCorrupt(
            p,
            a,
            _nrSlot(
                abi.encodeCall(ingress.identityTransitionClosure, (artistId, nrBefore43)), original
            ),
            d.recordHash,
            context
        );
        (,,, bytes32 head) = ingress.guardianSet(artistId);
        _nrRegister(p, a, false);
        _nrRecover(p, a, head, true);
    }

    function testDormancyNoticeHistoricalLiving35SubjectGetsLateMarkerWithoutInventedClosure()
        public
    {
        this.nrSetup(4);
        bytes32 living = nrPrior;
        bytes32 current = nrBefore43;
        require(
            ingress.identityTransitionClosure(artistId, living).dismissalRecordHash == 0,
            "historical living35 unclosed before notice"
        );
        this.nrNoticeSubject(nrNoticeStart + 1, living);
        this.nrNoticeDismiss();
        uint64 marked = ingress.artistTransitionState(living).contestedAt;
        require(
            marked == nrNoticeStart + 1 && marked > ingress.artistTransitionState(current).stagedAt
                && ingress.identityTransitionClosure(artistId, living).dismissalRecordHash == 0
                && ingress.identityTransitionClosure(artistId, current).dismissalRecordHash
                    == nrNoticeDismissals[0],
            "late historical op33 subject is marked while only actual current32 execution receives closure"
        );
        this.nrComplete();
        this.nrRotate();
        this.nrCompromise(nrWindow);
        (IdentityRecovery.Request memory p, T.Authorization memory a) = this.nrRequest(0, 0);
        bytes32 context = keccak256(abi.encode(ingress.identityRecoveryContext(p, a)));
        R.TransitionState memory old = ingress.artistTransitionState(living);
        bytes32 marker = bytes32(uint256(old.contestedAt) | uint256(old.phase) << 64);
        bytes32 markerSlot =
            _nrSlot(abi.encodeCall(ingress.artistTransitionState, (living)), marker);
        _nrCorrupt(p, a, markerSlot, bytes32(uint256(old.phase) << 64), context);
        _nrCorrupt(
            p, a, markerSlot, bytes32(uint256(marked + 1) | uint256(old.phase) << 64), context
        );
        bytes32 closureSlot = _nrSlot(
            abi.encodeCall(ingress.identityTransitionClosure, (artistId, current)),
            nrNoticeDismissals[0]
        );
        _nrEmptyClosure(p, a, closureSlot, context);
        (,,, bytes32 head) = ingress.guardianSet(artistId);
        _nrRegister(p, a, false);
        _nrRecover(p, a, head, true);
        require(
            ingress.artistTransitionState(living).contestedAt == marked
                && ingress.identityTransitionClosure(artistId, living).dismissalRecordHash == 0,
            "later recovery preserves original historical marker without invented closure"
        );
    }
}

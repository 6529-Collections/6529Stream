// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./StreamArtistDormancyRepeatedRecoveryActual.t.sol";
import {
    IStreamArtistDormancyOwner
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistDormancy.sol";

import {
    IStreamArtistStewardSanctionGrant as CNGrant
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistStewardSanctionGrant.sol";

/// @notice Actual living35 -> intervening closure/cancelled-notice history -> fresh ACTIVE1 -> living35.
/// @dev One existing Artist/Safe/Archive graph. The original notices, causes and receipts are real;
/// Core and governed scheduling use the inherited exact typed unit boundaries. No class4/hydration.
contract StreamArtistLivingHistoryRecoveryActualTest is
    StreamArtistDormancyRepeatedRecoveryActualTest
{
    bytes32 private lhNotice;
    bytes32 private lhTerminal;
    bytes32 private lhPrior;
    bytes32 private lhNoticeExecution;
    bytes32 private lhDesignation;
    bytes32 private lhProtected;
    bytes32 private lhRetained;
    bytes32 private lhFrozen;
    bytes32 private lhElection;
    bytes32 private lhOriginalNotice;
    uint64 private lhWindow;
    uint64 private lhNoticeStart;
    uint64 private lhDeadline;
    uint256 private lhSalt = 87000;
    bytes32[] private lhRecoveries;
    bytes32[] private lhRotations;
    bytes32[] private lhPendings;
    bytes32[] private lhExcluded;
    bytes32[] private lhDismissals;
    bytes32[] private lhNoticeCauses;
    bytes32[] private lhNoticeDismissals;
    bytes32[] private lhCauseNotices;
    bytes32[] private lhNotices;
    bytes32[] private lhCancelled;
    bytes32[] private lhCancellationHashes;
    bytes32[] private lhActivityGrants;
    uint256 private lhCancellationCount;
    address private lhDesignatedAddress;
    uint256[] private lhDesignatedKeys;

    modifier lhSelf() {
        require(msg.sender == address(this), "living history recovery fixture caller");
        _;
    }

    function lhSetup(bool beginNotice) external lhSelf {
        _deployAppealSuite();
        _accept();
        _payout();
        this.testActualRecoverySnapshotSharesOneRevisionAndTwoReceiptsWithArchiveRetry();
        lhPrior = ingress.latestIdentityRecovery(artistId);
        _lhReceipts(lhPrior);
        lhRecoveries.push(lhPrior);
        lhTerminal = lhPrior;
        lhWindow = ingress.artistTransitionState(lhPrior).postWindowEndsAt;
        _adoptRotatedSafe();
        lhRetained = this.rrGuardian(address(delegateSafe), 10 days, 900);
        lhProtected = this.rrGuardian(address(artist), 20 days, 1000);
        _newRotationSafe(++lhSalt);
        Succ27.Designation memory plan = _successorTerms(address(rotationSafe), 2);
        plan.grantedCapabilities = 256;
        lhDesignation = _successionRecord(plan);
        lhDesignatedAddress = address(rotationSafe);
        lhDesignatedKeys = rotationKeys;
        ArtistAppealUnitRoles(suite.roleRegistry).setAppeal(address(this), true);
        require(
            ingress.identityRecoveryRecord(lhPrior).delegationEpoch == 1
                && ingress.currentAuthorityCapabilities(artistId).authorityClass == 1
                && _snapshot(lhPrior).previousTransitionRecordHash == 0
                && _snapshot(lhPrior).previousCommitment == 0,
            "actual first living35, original receipts and inherited principal Safe"
        );
        if (beginNotice) this.lhBeginNotice();
    }

    function lhBeginNotice() external lhSelf {
        require(
            IStreamArtistIdentityOwner(suite.owners[2]).identity(artistId).status == 1,
            "notice begins only from actual restored living status"
        );
        _lhPreservedCancellations();
        lhNoticeExecution = lhTerminal;
        lhNotice = this.rrBeginBoundaryDormancy();
        lhNotices.push(lhNotice);
        (Dormancy27.Notice memory n, uint8 phase, Dormancy27.Terminal memory t) =
            IStreamArtistDormancy(address(ingress)).dormancyRecord(lhNotice);
        lhOriginalNotice = keccak256(abi.encode(n));
        lhNoticeStart = n.initiatedAt;
        lhDeadline = n.noticeEndsAt;
        require(
            phase == 1 && t.recordHash == 0 && n.priorActivity == lhCancellationCount
                && n.incumbent == address(artist)
                && ingress.latestIdentityRecovery(artistId) == lhPrior,
            "actual notice preserves latest living35 and exact prior cancellation count"
        );
        _lhAssertNotice(2);
    }

    function lhNoticeCompromise(uint64 when) external lhSelf {
        this.lhNoticeSubject(when, lhTerminal);
    }

    function lhNoticeSubject(uint64 when, bytes32 subject) external lhSelf {
        this.rrAt(when);
        this.lhRecordSubject(subject);
        Dismissal.Cause memory cause = ingress.currentIdentityContestCause(artistId);
        (bytes32 joined, uint8 phase, bytes32 terminal) = IStreamArtistDormancyOwner(
                suite.owners[2]
            ).dormancyResolutionState(artistId, cause.causeHash);
        require(
            cause.facts.priorStatus == 2 && cause.facts.authorityClass == 1
                && cause.facts.executedTransitionHash == lhNoticeExecution
                && cause.facts.pendingTransitionHash == 0 && joined == lhNotice && phase == 1
                && terminal == 0
                && IStreamArtistIdentityOwner(suite.owners[2]).identity(artistId).status == 4,
            "actual op33 stores original priorStatus2 causeNotice join without completing or cancelling notice"
        );
        require(
            ingress.identityContestRecord(cause.facts.referenceHash).terms.subjectRecordHash
                == subject,
            "original op33 retains exact zero, current or historical subject separately from current execution"
        );
        lhNoticeCauses.push(cause.causeHash);
        lhCauseNotices.push(lhNotice);
        _lhAssertNotice(4);
    }

    function lhNoticeDismiss() external lhSelf {
        bytes32 cause = ingress.currentIdentityContestCause(artistId).causeHash;
        this.lhDismiss();
        bytes32 record = ingress.latestIdentityContestDismissal(artistId);
        Dismissal.Record memory d = ingress.identityContestDismissalRecord(record);
        require(
            d.terms.expectedCauseHash == cause && d.authorityClass == 1 && d.restoredStatus == 2
                && d.incumbent == address(artist) && d.actionId != 0
                && d.governanceWitnessHash != 0,
            "actual dismissal restores notice status2, not ordinary living status1"
        );
        lhNoticeDismissals.push(record);
        _lhAssertNotice(2);
    }

    function lhEpisode(uint64 when) external lhSelf {
        this.lhNoticeCompromise(when);
        this.lhNoticeDismiss();
    }

    function _lhAssertNotice(uint8 expectedStatus) private view {
        (Dormancy27.Notice memory n, uint8 phase, Dormancy27.Terminal memory t) =
            IStreamArtistDormancy(address(ingress)).dormancyRecord(lhNotice);
        (bytes32 notice, uint8 currentPhase, bytes32 terminal) =
            IStreamArtistDormancy(address(ingress)).dormancyNotice(artistId);
        (uint8 status, uint64 end,) =
            IStreamArtistDormancy(address(ingress)).dormancyState(artistId);
        require(
            keccak256(abi.encode(n)) == lhOriginalNotice && phase == 1 && currentPhase == 1
                && notice == lhNotice && terminal == 0 && t.recordHash == 0
                && status == expectedStatus && end == lhDeadline
                && IStreamArtistIdentityOwner(suite.owners[2])
                .identity(artistId)
                .lastAuthorityActionAt == n.priorLivenessAt,
            "original active notice, deadline and liveness remain exact through each governed episode"
        );
    }

    function _lhWitness(bytes32 scope, bytes32 old_, bytes32 next_) private {
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

    function lhCancel(uint8 method, bool retry) external lhSelf {
        require(method <= 2 && (!retry || method == 2), "bounded original cancellation producers");
        (Dormancy27.Notice memory n, uint8 phase,) =
            IStreamArtistDormancy(address(ingress)).dormancyRecord(lhNotice);
        T.Identity memory before_ = IStreamArtistIdentityOwner(suite.owners[2]).identity(artistId);
        require(
            phase == 1 && n.priorActivity == lhCancellationCount,
            "actual open notice before cancellation"
        );
        address actor = method == 1 ? lhDesignatedAddress : address(artist);
        uint8 class_ = method == 1 ? 3 : 1;
        if (method == 2) {
            CNGrant.Grant memory p = CNGrant.Grant(
                artistId, true, keccak256(abi.encode("cancelled notice signed activity", lhNotice))
            );
            T.Authorization memory a = _authorization(true);
            a.signature = _signature(CNGrant(address(ingress)).stewardSanctionGrantDigest(p, a));
            bytes32 request = keccak256(abi.encode(p, a));
            if (retry) {
                bytes32 roots = _roots();
                bytes32 history = _lhHistory();
                _overflow();
                CNGrant(address(ingress)).recordStewardSanctionGrant(p, a);
                require(
                    roots == _roots() && history == _lhHistory()
                        && !IStreamArtistIdentityOwner(suite.owners[2]).nonceUsed(artistId, a.nonce)
                        && keccak256(abi.encode(before_))
                            == keccak256(
                                abi.encode(
                                    IStreamArtistIdentityOwner(suite.owners[2]).identity(artistId)
                                )
                            ),
                    "late actual Archive failure restores notice, principal, cancellation counter and signed nonce"
                );
                vm.roll(restoreBlock);
            }
            bytes32 grant = CNGrant(address(ingress)).recordStewardSanctionGrant(p, a);
            require(
                request == keccak256(abi.encode(p, a))
                    && CNGrant(address(ingress)).stewardSanctionGrantRecord(grant).signer == actor
                    && _operationPayload(19, address(this), grant).length != 0,
                "identical original signed activity and actual operation19 Archive record"
            );
            lhActivityGrants.push(grant);
        } else {
            OfficialSafe signer = method == 1 ? OfficialSafe(payable(lhDesignatedAddress)) : artist;
            uint256[] memory signingKeys = method == 1 ? lhDesignatedKeys : keys;
            require(
                executeSafe(
                    signer,
                    signingKeys,
                    address(ingress),
                    0,
                    abi.encodeCall(
                        IStreamArtistDormancy.cancelArtistDormancy, (artistId, lhNotice, bytes32(0))
                    ),
                    0
                ),
                "actual authorized threshold Safe operation42"
            );
        }
        (Dormancy27.Notice memory saved, uint8 cancelled, Dormancy27.Terminal memory t) =
            IStreamArtistDormancy(address(ingress)).dormancyRecord(lhNotice);
        ++lhCancellationCount;
        bytes32 record = t.recordHash;
        Dormancy27.Terminal memory preimage;
        preimage.noticeHash = t.noticeHash;
        preimage.actor = t.actor;
        preimage.authorityClass = t.authorityClass;
        preimage.observedAt = t.observedAt;
        require(
            cancelled == 2 && keccak256(abi.encode(saved)) == lhOriginalNotice
                && t.noticeHash == lhNotice && t.actor == actor && t.authorityClass == class_
                && t.observedAt == block.timestamp && lhCancellationCount == n.priorActivity + 1
                && record
                    == keccak256(
                        abi.encode(
                            keccak256("6529STREAM_ARTIST_DORMANCY_CANCELLATION_V1"),
                            block.chainid,
                            address(ingress),
                            suite.owners[2],
                            preimage,
                            lhCancellationCount
                        )
                    ),
            "unchanged original cancellation domain, zero-hash terminal preimage and exact next activity counter"
        );
        Dormancy27.Plan memory emptyPlan;
        require(
            t.appointmentBlock == 0 && t.evidenceHash == 0 && t.actionId == 0 && t.witnessHash == 0
                && t.delegationEpoch == 0
                && keccak256(abi.encode(t.plan)) == keccak256(abi.encode(emptyPlan)),
            "cancellation is original liveness, never an authority installation"
        );
        T.Identity memory after_ = IStreamArtistIdentityOwner(suite.owners[2]).identity(artistId);
        require(
            after_.status == (before_.status == 4 ? 4 : 1)
                && after_.authorityAddress == before_.authorityAddress && after_.authorityClass == 1
                && after_.lastAuthorityActionAt == t.observedAt
                && ingress.latestIdentityRecovery(artistId) == lhPrior,
            "authenticated cancellation refreshes liveness but never dismisses a genuine compromise"
        );
        if (method != 2) {
            require(
                _operationPayload(42, actor, record).length != 0, "original operation42 archived"
            );
        }
        lhCancelled.push(lhNotice);
        lhCancellationHashes.push(keccak256(abi.encode(saved, cancelled, t)));
        _lhPreservedCancellations();
    }

    function _lhPreservedCancellations() private view {
        for (uint256 i; i < lhCancelled.length; ++i) {
            (Dormancy27.Notice memory n, uint8 phase, Dormancy27.Terminal memory t) =
                IStreamArtistDormancy(address(ingress)).dormancyRecord(lhCancelled[i]);
            require(
                phase == 2 && lhCancellationHashes[i] == keccak256(abi.encode(n, phase, t)),
                "every cancelled original notice and terminal remains byte-identical"
            );
        }
    }

    function lhDismissAfterCancellation() external lhSelf {
        bytes32 cause = ingress.currentIdentityContestCause(artistId).causeHash;
        this.lhDismiss();
        Dismissal.Record memory d = ingress.identityContestDismissalRecord(
            ingress.latestIdentityContestDismissal(artistId)
        );
        (bytes32 notice, uint8 phase, bytes32 terminal) =
            IStreamArtistDormancyOwner(suite.owners[2]).dormancyResolutionState(artistId, cause);
        require(
            d.terms.expectedCauseHash == cause && d.restoredStatus == 1 && d.authorityClass == 1
                && notice == lhNotice && phase == 2 && terminal != 0
                && IStreamArtistIdentityOwner(suite.owners[2]).identity(artistId).status == 1,
            "actual dismissal after cancellation restores ACTIVE1 while immutable cause remains priorStatus2"
        );
        lhNoticeDismissals.push(d.recordHash);
        _lhPreservedCancellations();
    }

    function lhCompromise(uint64 when) external lhSelf {
        this.rrAt(when);
        this.lhRecordCause();
    }

    function lhActiveEpisode(uint64 when, bytes32 subject) external lhSelf {
        this.rrAt(when);
        this.lhRecordSubject(subject);
        Dismissal.Cause memory cause = ingress.currentIdentityContestCause(artistId);
        require(
            cause.facts.priorStatus == 1 && cause.facts.authorityClass == 1,
            "actual intervening ACTIVE1 episode, separate from any cancelled notice"
        );
        this.lhDismiss();
        require(
            IStreamArtistIdentityOwner(suite.owners[2]).identity(artistId).status == 1
                && ingress.identityContestDismissalRecord(
                    ingress.latestIdentityContestDismissal(artistId)
                )
                .restoredStatus == 1,
            "intervening ACTIVE1 dismissal restores same living principal"
        );
    }

    function lhRecordCause() external lhSelf {
        this.lhRecordSubject(lhTerminal);
    }

    function lhRecordSubject(bytes32 subject) external lhSelf {
        ArtistAppealUnitRoles(suite.roleRegistry).setArbiter(address(artist), true);
        bytes32 evidence = keccak256(
            abi.encode(
                "living history recovery cause",
                lhTerminal,
                block.timestamp,
                ingress.latestIdentityContestDismissal(artistId)
            )
        );
        bytes32 reason = keccak256(abi.encode("living history recovery reason", evidence));
        ArtistUnitGovernance authority = ArtistUnitGovernance(manager.governanceAuthority());
        authority.configureContestReads(
            suite.roleRegistry, address(artist), reason, "urn:living-history-recovery:cause"
        );
        (bytes32 scope, bytes32 old_, bytes32 next_) =
            ingress.identityContestGovernanceContext(artistId, subject, evidence, reason);
        _lhWitness(scope, old_, next_);
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
            cause.facts.kind == 1 && cause.facts.executedTransitionHash == lhTerminal
                && cause.facts.incumbent == address(artist) && cause.facts.authorityClass == 1
                && ingress.latestIdentityRecovery(artistId) == lhPrior,
            "new actual33 names the operative execution while preserving latest old35"
        );
    }

    function lhDismiss() external lhSelf {
        bytes32 first = ingress.identityTransitionClosure(artistId, lhTerminal).dismissalRecordHash;
        Dismissal.Request memory p = _dismissalRequest();
        ArtistAppealUnitRoles(suite.roleRegistry).setArbiter(address(artist), true);
        ArtistUnitGovernance authority = ArtistUnitGovernance(manager.governanceAuthority());
        authority.configureContestReads(
            suite.roleRegistry,
            address(artist),
            p.reasonHash,
            "urn:living-history-recovery:dismissal"
        );
        Dismissal.Context memory x = ingress.identityContestDismissalContext(p);
        _lhWitness(x.scopeHash, x.oldValueHash, x.newValueHash);
        authority.executeModuleContext(
            address(ingress),
            abi.encodeCall(IStreamArtistIdentityDismissal.dismissArtistIdentityContest, (p)),
            1,
            x.scopeHash,
            x.oldValueHash,
            x.newValueHash
        );
        _inactive();
        lhDismissals.push(ingress.latestIdentityContestDismissal(artistId));
        require(
            ingress.identityTransitionClosure(artistId, lhTerminal).dismissalRecordHash
                == (lhTerminal == 0
                        ? bytes32(0)
                        : first == 0 ? ingress.latestIdentityContestDismissal(artistId) : first),
            "first original closure remains fixed"
        );
        if (lhTerminal == 0) {
            Dismissal.Closure memory empty;
            require(
                keccak256(abi.encode(ingress.identityTransitionClosure(artistId, 0)))
                    == keccak256(abi.encode(empty)),
                "zero execution has no fabricated closure"
            );
        }
    }

    function _lhMature() private {
        if (
            ingress.identityTransitionClosure(artistId, lhTerminal).dismissalRecordHash == 0
                && block.timestamp < lhWindow
        ) {
            this.rrAt(lhWindow);
        }
    }

    function lhRotate() external lhSelf {
        _lhMature();
        bytes32 previous = lhTerminal;
        _newRotationSafe(++lhSalt);
        lhTerminal = _stageRotation(ingress.lastArtistTransition(artistId));
        _executeTimedRotation(lhTerminal);
        _adoptRotatedSafe();
        lhRotations.push(lhTerminal);
        lhWindow = ingress.artistTransitionState(lhTerminal).postWindowEndsAt;
        Estate.AuthorityCapabilities memory caps = ingress.currentAuthorityCapabilities(artistId);
        require(
            _snapshot(lhTerminal).previousTransitionRecordHash == previous
                && _snapshot(lhTerminal).previousCommitment == _snapshot(previous).commitment
                && ingress.latestIdentityRecovery(artistId) == lhPrior && caps.authorityClass == 1
                && caps.activationRecordHash == 0,
            "actual32 retains exact executed parent and original latest living35"
        );
    }

    function lhStanding() external lhSelf {
        _lhMature();
        _newRotationSafe(++lhSalt);
        bytes32 pending = _stageRotation(ingress.lastArtistTransition(artistId));
        lhPendings.push(pending);
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
            cause.facts.kind == 2 && cause.facts.executedTransitionHash == lhTerminal
                && cause.facts.pendingTransitionHash == pending && cause.facts.evidenceHash == 0
                && cause.facts.reasonHash == 0,
            "original zero-reason standing producer"
        );
        this.lhDismiss();
    }

    function lhAbortPendingWithCompromise(bool zeroSubject)
        external
        lhSelf
        returns (bytes32 pending)
    {
        _lhMature();
        _newRotationSafe(++lhSalt);
        pending = _stageRotation(ingress.lastArtistTransition(artistId));
        lhPendings.push(pending);
        this.lhRecordSubject(zeroSubject ? bytes32(0) : lhTerminal);
        Dismissal.Cause memory cause = ingress.currentIdentityContestCause(artistId);
        require(
            cause.facts.kind == 1 && cause.facts.priorStatus == 1
                && cause.facts.executedTransitionHash == lhTerminal
                && cause.facts.pendingTransitionHash == pending
                && ingress.rotationRecord(pending).transition.phase == 3,
            "actual ACTIVE op33 captures current execution and aborts pending32 together"
        );
        this.lhDismiss();
        bytes32 dismissal = ingress.latestIdentityContestDismissal(artistId);
        Dismissal.Closure memory pendingClosure =
            ingress.identityTransitionClosure(artistId, pending);
        require(
            pendingClosure.dismissalRecordHash == dismissal
                && pendingClosure.transitionRecordHash == pending && pendingClosure.abandoned
                && pendingClosure.contestedAt == cause.facts.enteredAt
                && ingress.identityTransitionClosure(artistId, lhTerminal).dismissalRecordHash != 0
                && ingress.identityContestDismissalRecord(dismissal).restoredStatus == 1,
            "one actual dismissal installs exact pending closure and preserves current execution's first closure"
        );
    }

    function lhRequest(bytes32 first, bytes32 second)
        external
        lhSelf
        returns (IdentityRecovery.Request memory p, T.Authorization memory a)
    {
        _newRotationSafe(++lhSalt);
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

    function _lhClosure(bytes32 record) private view returns (bytes32) {
        Dismissal.Closure memory c = ingress.identityTransitionClosure(artistId, record);
        Dismissal.Record memory d = ingress.identityContestDismissalRecord(c.dismissalRecordHash);
        Dismissal.Cause memory cause = ingress.identityContestCause(d.terms.expectedCauseHash);
        return keccak256(
            abi.encode(c, d, cause, ingress.rotationRecord(cause.facts.pendingTransitionHash))
        );
    }

    function _lhHistory() private view returns (bytes32 value) {
        for (uint256 i; i < lhNotices.length; ++i) {
            (Dormancy27.Notice memory notice, uint8 phase, Dormancy27.Terminal memory terminal) =
                IStreamArtistDormancy(address(ingress)).dormancyRecord(lhNotices[i]);
            value = keccak256(abi.encode(value, notice, phase, terminal));
        }
        for (uint256 i; i < lhActivityGrants.length; ++i) {
            value = keccak256(
                abi.encode(
                    value, CNGrant(address(ingress)).stewardSanctionGrantRecord(lhActivityGrants[i])
                )
            );
        }
        value = keccak256(abi.encode(value, ingress.successorDesignationRecord(lhDesignation)));
        for (uint256 i; i < lhRecoveries.length; ++i) {
            bytes32 record = lhRecoveries[i];
            (bytes32 primary, bytes32 occurrence, bytes32 secondary) =
                IStreamArtistIdentityRecoveryOwner(suite.owners[2]).identityRecoveryReceipts(record);
            value = keccak256(
                abi.encode(
                    value,
                    ingress.identityRecoveryRecord(record),
                    _snapshot(record),
                    ingress.artistTransitionState(record),
                    _lhClosure(record),
                    primary,
                    occurrence,
                    secondary
                )
            );
        }
        for (uint256 i; i < lhRotations.length; ++i) {
            bytes32 record = lhRotations[i];
            value = keccak256(
                abi.encode(
                    value, ingress.rotationRecord(record), _snapshot(record), _lhClosure(record)
                )
            );
        }
        for (uint256 i; i < lhPendings.length; ++i) {
            value = keccak256(
                abi.encode(value, ingress.rotationRecord(lhPendings[i]), _lhClosure(lhPendings[i]))
            );
        }
        for (uint256 i; i < lhExcluded.length; ++i) {
            value = keccak256(abi.encode(value, _status(lhExcluded[i])));
        }
        for (uint256 i; i < lhDismissals.length; ++i) {
            Dismissal.Record memory d = ingress.identityContestDismissalRecord(lhDismissals[i]);
            value = keccak256(
                abi.encode(
                    value,
                    d,
                    ingress.identityContestCause(d.terms.expectedCauseHash),
                    ingress.identityContestRecord(
                        ingress.identityContestCause(d.terms.expectedCauseHash).facts.referenceHash
                    )
                )
            );
        }
        for (uint256 i; i < lhNoticeCauses.length; ++i) {
            Dismissal.Cause memory cause = ingress.identityContestCause(lhNoticeCauses[i]);
            (bytes32 notice, uint8 phase, bytes32 terminal) = IStreamArtistDormancyOwner(
                    suite.owners[2]
                ).dormancyResolutionState(artistId, lhNoticeCauses[i]);
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

    function _lhRegister(IdentityRecovery.Request memory p, T.Authorization memory a, bool appeal)
        private
    {
        GovernanceCall[] memory calls = _schedule(
            keccak256(abi.encode("living history recovery action", lhPrior, lhTerminal, lhSalt)),
            p,
            a
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
        lhFrozen = _lhHistory();
    }

    function _lhElect(IdentityRecovery.Request memory p, T.Authorization memory a, bytes32 selected)
        private
    {
        IStreamArtistGuardianSelectionPreparation prep = _selectionPreparation();
        lhElection = prep.begin(artistId, lhTerminal, p.supersededRecordHashes);
        (GH.Head memory head,,,) = IStreamArtistGuardianHistory(suite.owners[2])
            .guardianHistoryState(artistId, 0, address(0), 0);
        bytes32 roots = _roots();
        vm.expectRevert(
            abi.encodeWithSelector(
                Selection.IncompleteGuardianSelection.selector, lhElection, uint64(0), head.count
            )
        );
        ingress.identityRecoveryContext(p, a);
        Selection.Progress memory progress = prep.continueSelection(lhElection, 1);
        require(!progress.complete, "partial guardian prefix is not complete election");
        progress = prep.continueSelection(lhElection, 64);
        require(
            progress.complete && progress.processed == head.count
                && progress.selectedRecordHash == selected && roots == _roots(),
            "complete original-record election"
        );
    }

    function _lhRecover(
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
        if (retry) _lhRollback(p, a, epoch);
        vm.recordLogs();
        record = this.executeRegistered(p, a);
        _assertSnapshot(_snapshot(record), 35, before_, vm.getRecordedLogs());
        _lhReceipts(record);
        IdentityRecovery.Record memory r = ingress.identityRecoveryRecord(record);
        Estate.AuthorityCapabilities memory caps = ingress.currentAuthorityCapabilities(artistId);
        (,,, bytes32 head) = ingress.guardianSet(artistId);
        (bool used,) = ingress.rotationAcceptanceNonceState(artistId, p.newAddress, a.nonce);
        require(
            caps.authorityClass == p.vestedAuthorityClass && caps.status == p.vestedAuthorityClass
                && caps.authorityAddress == p.newAddress && r.delegationEpoch == epoch + 1
                && _snapshot(record).previousTransitionRecordHash == lhTerminal
                && _snapshot(record).previousCommitment == _snapshot(lhTerminal).commitment && used
                && head == selected && _lhHistory() == lhFrozen
                && r.fields.supersededRecordsHash
                    == RecoveryHashes.supersession(p.supersededRecordHashes)
                && keccak256(abi.encode(r.terms.supersededRecordHashes))
                    == keccak256(abi.encode(p.supersededRecordHashes)),
            "actual35 increments current epoch, preserves every original record and applies only exact exclusions"
        );
        require(
            caps.authorityClass == 1 && caps.status == 1 && caps.activationRecordHash == 0
                && caps.effectiveCapabilities == 4095,
            "every later35 remains actual living authority with no43 origin"
        );
        _lhPreservedCancellations();
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
            !ok && roots == _roots() && _lhHistory() == lhFrozen,
            "identical old action cannot replay"
        );
        lhRecoveries.push(record);
        for (uint256 i; i < p.supersededRecordHashes.length; ++i) {
            lhExcluded.push(p.supersededRecordHashes[i]);
        }
        lhPrior = record;
        lhTerminal = record;
        lhWindow = ingress.artistTransitionState(record).postWindowEndsAt;
        _adoptRotatedSafe();
    }

    function _lhRollback(IdentityRecovery.Request memory p, T.Authorization memory a, uint64 epoch)
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
            !used && roots == _roots() && lhFrozen == _lhHistory()
                && ingress.latestIdentityRecovery(artistId) == lhPrior && head == oldHead
                && rotationSafe.nonce() == nonce
                && ingress.identityRecoveryContext(p, a).delegationEpoch == epoch
                && principal
                    == keccak256(
                        abi.encode(IStreamArtistIdentityOwner(suite.owners[2]).identity(artistId))
                    ),
            "late Archive failure restores original living history, epoch, principal, heads and acceptance"
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
    function _lhReceipts(bytes32 record) private view {
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

    function _lhRound(uint8 rotations, bool retry) private returns (bytes32 record) {
        for (uint256 i; i < rotations; ++i) {
            this.lhRotate();
        }
        this.lhCompromise(uint64(block.timestamp > lhWindow ? block.timestamp + 1 : lhWindow));
        (IdentityRecovery.Request memory p, T.Authorization memory a) = this.lhRequest(0, 0);
        (,,, bytes32 head) = ingress.guardianSet(artistId);
        _lhRegister(p, a, false);
        return _lhRecover(p, a, head, retry);
    }

    function _lhPublisher() private view returns (IStreamArtistGuardianAppealEvidence publisher) {
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

    function _lhAppeal(IdentityRecovery.Request memory p, bytes32 protectedRecord)
        private
        returns (IdentityRecovery.Request memory, T.Authorization memory)
    {
        Dismissal.Cause memory cause = ingress.currentIdentityContestCause(artistId);
        Appeal27.Document memory document = Appeal27.Document(
            Appeal27.requestCommitment(p),
            cause.causeHash,
            cause.facts.referenceHash,
            _snapshot(lhTerminal).commitment,
            lhTerminal,
            keccak256("living history recovery specific findings"),
            new Appeal27.Finding[](1)
        );
        address[] memory parties = ingress.guardianSetRecord(protectedRecord).terms.guardians;
        document.findings[0] = Appeal27.Finding(protectedRecord, parties);
        bytes32 roots = _roots();
        bytes32 latest = ingress.latestIdentityRecovery(artistId);
        p.evidenceHash = _lhPublisher().publish(document);
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

    function _lhRole(IdentityRecovery.Request memory p, bytes32 expected) private view {
        require(
            IStreamArtistGuardianAppealOwner(suite.owners[2])
                .guardianRecoveryAuthorityRole(artistId, p.supersededRecordHashes) == expected,
            "exact current cutoff determines protected APPEAL or later-principal ARBITER"
        );
    }

    function _lhSlot(bytes memory getter, bytes32 expected) private returns (bytes32 slot) {
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

    function _lhCorrupt(
        IdentityRecovery.Request memory p,
        T.Authorization memory a,
        bytes32 slot,
        bytes32 replacement,
        bytes32 context
    ) private {
        bytes32 original = vm.load(suite.owners[2], slot);
        require(original != replacement, "corruption changes original bytes");
        bytes32 roots = _roots();
        bytes32 history = _lhHistory();
        vm.store(suite.owners[2], slot, replacement);
        (bool ok,) =
            address(ingress).staticcall(abi.encodeCall(ingress.identityRecoveryContext, (p, a)));
        require(!ok, "same signed request rejects corrupted original proof");
        (bool used,) = ingress.rotationAcceptanceNonceState(artistId, p.newAddress, a.nonce);
        require(!used && roots == _roots(), "failed read cannot consume nonce or Archive state");
        vm.store(suite.owners[2], slot, original);
        require(
            history == _lhHistory()
                && context == keccak256(abi.encode(ingress.identityRecoveryContext(p, a))),
            "exact restoration admits byte-identical request and signature"
        );
    }

    function _lhCorruptHash(
        IdentityRecovery.Request memory p,
        T.Authorization memory a,
        bytes memory getter,
        bytes32 value,
        bytes32 context
    ) private {
        _lhCorrupt(p, a, _lhSlot(getter, value), bytes32(uint256(value) ^ 1), context);
    }

    // The canonical map and the original notice record contain the same hash. Distinguish them
    // by the fixed-owner getter's empty-join behavior, restoring every probed word immediately.
    function _lhCauseNoticeSlot(bytes32 cause) private returns (bytes32 slot) {
        RepeatedDormancyStorageVm probe = RepeatedDormancyStorageVm(address(vm));
        (bytes32 originalNotice,,) =
            IStreamArtistDormancyOwner(suite.owners[2]).dormancyResolutionState(artistId, cause);
        require(originalNotice != 0, "actual canonical notice join");
        bytes memory getter =
            abi.encodeCall(IStreamArtistDormancyOwner.dormancyResolutionState, (artistId, cause));
        probe.record();
        (bool ok,) = suite.owners[2].staticcall(getter);
        require(ok, "actual original causeNotice read");
        (bytes32[] memory reads,) = probe.accesses(suite.owners[2]);
        uint256 matches;
        for (uint256 i; i < reads.length; ++i) {
            if (vm.load(suite.owners[2], reads[i]) != originalNotice) continue;
            vm.store(suite.owners[2], reads[i], 0);
            (bool healthy, bytes memory raw) = suite.owners[2].staticcall(getter);
            vm.store(suite.owners[2], reads[i], originalNotice);
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

    function _lhEmptyClosure(
        IdentityRecovery.Request memory p,
        T.Authorization memory a,
        bytes32 execution,
        bytes32 dismissalSlot,
        bytes32 context
    ) private {
        // Locate the actual struct by its uniquely observed dismissal field, then verify all
        // four original words against the typed getter before touching the complete closure.
        Dismissal.Closure memory c = ingress.identityTransitionClosure(artistId, execution);
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
        bytes32 history = _lhHistory();
        for (uint256 i; i < 4; ++i) {
            vm.store(suite.owners[2], bytes32(uint256(base) + i), 0);
        }
        Dismissal.Closure memory empty;
        require(
            keccak256(abi.encode(ingress.identityTransitionClosure(artistId, execution)))
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
            history == _lhHistory()
                && context == keccak256(abi.encode(ingress.identityRecoveryContext(p, a))),
            "complete original closure restore admits identical request"
        );
    }

    function _lhFinish() private returns (bytes32 record) {
        (IdentityRecovery.Request memory p, T.Authorization memory a) = this.lhRequest(0, 0);
        (,,, bytes32 head) = ingress.guardianSet(artistId);
        _lhRegister(p, a, false);
        return _lhRecover(p, a, head, true);
    }

    function _lhNoticeCounterSlot(bytes32 notice) private returns (bytes32 slot) {
        (Dormancy27.Notice memory n,,) =
            IStreamArtistDormancy(address(ingress)).dormancyRecord(notice);
        bytes32 witnessSlot =
            _lhSlot(abi.encodeCall(IStreamArtistDormancy.dormancyRecord, (notice)), n.witnessHash);
        slot = bytes32(uint256(witnessSlot) - 2);
        require(
            vm.load(suite.owners[2], slot) == bytes32(n.priorActivity)
                && vm.load(suite.owners[2], bytes32(uint256(slot) + 1)) == n.actionId,
            "observed immutable notice counter is adjacent to exact action and witness words"
        );
    }

    function testLivingHistoryNoInterveningHistoryKeepsDirectRepeatedRecoveryBaseline() public {
        this.lhSetup(false);
        bytes32 record = _lhRound(0, true);
        require(
            ingress.identityRecoveryRecord(record).delegationEpoch == 2 && lhNotices.length == 0,
            "original fresh FIRST then immediate repeated living35 path remains supported"
        );
    }

    function testLivingHistoryNoDismissalExecuted32SuffixKeepsOriginalRepeatedBaseline() public {
        this.lhSetup(false);
        bytes32 prior = lhPrior;
        bytes32 record = _lhRound(2, true);
        require(
            ingress.identityRecoveryRecord(record).delegationEpoch == 2
                && ingress.identityRecoveryRecord(prior).delegationEpoch == 1
                && lhRotations.length == 2,
            "two actual32 rotations retain prior35 and consume no epoch"
        );
    }

    function testLivingHistoryCancelledD2NoticeThenFreshActive1RepeatsWithExactReceipts() public {
        this.lhSetup(true);
        this.lhEpisode(lhNoticeStart + 1);
        this.lhCancel(0, false);
        bytes32 original = lhNoticeDismissals[0];
        bytes32 record = _lhRound(0, true);
        require(
            ingress.identityRecoveryRecord(record).delegationEpoch == 2
                && ingress.identityContestDismissalRecord(original).restoredStatus == 2,
            "original status2 dismissal remains historical while fresh ACTIVE1 drives actual repeated35"
        );
    }

    function testLivingHistoryCancelledContestedNoticeD1ThenFreshActive1Repeats() public {
        this.lhSetup(true);
        this.lhNoticeCompromise(lhNoticeStart + 1);
        this.lhCancel(0, false);
        this.lhDismissAfterCancellation();
        require(
            ingress.identityContestCause(lhNoticeCauses[0]).facts.priorStatus == 2
                && ingress.identityContestDismissalRecord(lhNoticeDismissals[0]).restoredStatus
                    == 1,
            "actual cancellation changes restoration status without rewriting original cause"
        );
        _lhRound(0, true);
    }

    function testLivingHistorySeveralSameTimeD2AndLaterActive1ClosuresKeepOriginalFirst() public {
        this.lhSetup(true);
        uint64 when = lhNoticeStart + 1;
        this.lhEpisode(when);
        this.lhEpisode(when);
        bytes32 first = lhNoticeDismissals[0];
        this.lhCancel(0, false);
        this.lhActiveEpisode(uint64(block.timestamp + 1), lhTerminal);
        this.lhActiveEpisode(uint64(block.timestamp + 1), bytes32(0));
        require(
            ingress.identityTransitionClosure(artistId, lhTerminal).dismissalRecordHash == first
                && first != lhNoticeDismissals[1],
            "all intermediate episodes preserve exact first closure despite same timestamps"
        );
        _lhRound(0, true);
    }

    function testLivingHistoryExecuted32BeforeCancelledNoticeRetainsActualExecutionAncestry()
        public
    {
        this.lhSetup(false);
        bytes32 living = lhPrior;
        this.lhRotate();
        bytes32 execution = lhTerminal;
        this.lhBeginNotice();
        this.lhEpisode(lhNoticeStart + 1);
        this.lhCancel(0, false);
        bytes32 record = _lhRound(0, true);
        require(
            _snapshot(record).previousTransitionRecordHash == execution
                && _snapshot(execution).previousTransitionRecordHash == living
                && ingress.identityRecoveryRecord(living).delegationEpoch == 1,
            "actual old35 and terminal32 remain separate from later cancellation"
        );
    }

    function testLivingHistoryCancelledNoticesAcrossRotatedPrincipalsRetainEveryCounterAndClosure()
        public
    {
        this.lhSetup(true);
        this.lhEpisode(lhNoticeStart + 1);
        this.lhCancel(0, false);
        this.lhRotate();
        this.lhBeginNotice();
        this.lhNoticeCompromise(lhNoticeStart + 1);
        this.lhCancel(0, false);
        this.lhDismissAfterCancellation();
        bytes32 record = _lhRound(1, true);
        require(
            lhCancellationCount == 2 && lhCancelled.length == 2
                && ingress.identityRecoveryRecord(record).delegationEpoch == 2,
            "separate original cancelled notices follow real principal rotations with unchanged old35 epoch"
        );
    }

    function testLivingHistoryFreshCurrentZeroSubjectBindsActualNonzeroExecution() public {
        this.lhSetup(true);
        this.lhEpisode(lhNoticeStart + 1);
        this.lhCancel(0, false);
        this.rrAt(uint64(block.timestamp + 1));
        this.lhRecordSubject(0);
        Dismissal.Cause memory current = ingress.currentIdentityContestCause(artistId);
        require(
            current.facts.priorStatus == 1 && current.facts.executedTransitionHash == lhTerminal
                && lhTerminal != 0
                && ingress.identityContestRecord(current.facts.referenceHash).terms
                    .subjectRecordHash == 0,
            "fresh actual current op33 subject0 is distinct from its nonzero captured execution"
        );
        _lhFinish();
    }

    function testLivingHistoryFreshHistoricalSubjectLateMarkerRejectsRemovalThenExactRetry()
        public
    {
        this.lhSetup(false);
        bytes32 living = lhPrior;
        this.lhRotate();
        bytes32 current = lhTerminal;
        this.lhBeginNotice();
        this.lhNoticeSubject(lhNoticeStart + 1, 0);
        this.lhNoticeDismiss();
        this.lhCancel(0, false);
        this.rrAt(uint64(block.timestamp + 1));
        this.lhRecordSubject(living);
        R.TransitionState memory old = ingress.artistTransitionState(living);
        require(
            old.contestedAt > ingress.artistTransitionState(current).stagedAt
                && ingress.identityTransitionClosure(artistId, living).dismissalRecordHash == 0,
            "fresh historical op33 marks earlier unclosed35 without fabricating its closure"
        );
        (IdentityRecovery.Request memory p, T.Authorization memory a) = this.lhRequest(0, 0);
        bytes32 context = keccak256(abi.encode(ingress.identityRecoveryContext(p, a)));
        bytes32 marker = bytes32(uint256(old.contestedAt) | uint256(old.phase) << 64);
        bytes32 slot = _lhSlot(abi.encodeCall(ingress.artistTransitionState, (living)), marker);
        _lhCorrupt(p, a, slot, bytes32(uint256(old.phase) << 64), context);
        _lhCorrupt(
            p, a, slot, bytes32(uint256(old.contestedAt + 1) | uint256(old.phase) << 64), context
        );
        (,,, bytes32 head) = ingress.guardianSet(artistId);
        _lhRegister(p, a, false);
        _lhRecover(p, a, head, true);
    }

    function testLivingHistoryCancelledNoticeAndClosedPendingStandingPermitDirectThenRotatedRepeat()
        public
    {
        this.lhSetup(true);
        this.lhEpisode(lhNoticeStart + 1);
        this.lhCancel(0, false);
        this.lhStanding();
        bytes32 pending = lhPendings[0];
        require(
            ingress.rotationRecord(pending).transition.phase == 3
                && ingress.identityTransitionClosure(artistId, pending).abandoned,
            "actual pending32 standing veto has its own permanent abandoned closure"
        );
        _lhRound(0, true);
        this.lhBeginNotice();
        this.lhEpisode(lhNoticeStart + 1);
        this.lhCancel(0, false);
        this.lhStanding();
        bytes32 laterPending = lhPendings[1];
        bytes32 record = _lhRound(1, true);
        bytes32 executed = _snapshot(record).previousTransitionRecordHash;
        require(
            ingress.rotationRecord(executed).terms.expectedPreviousTransitionRecordHash
                    == laterPending && ingress.identityRecoveryRecord(record).delegationEpoch == 3,
            "later actual32 binds separately authenticated abandoned staging and executed parent"
        );
    }

    function testLivingHistoryThreeRecoveryRoundsKeepEveryOldNoticeAndAdvanceExactlyOnce() public {
        this.lhSetup(false);
        for (uint8 i; i < 3; ++i) {
            this.lhBeginNotice();
            this.lhEpisode(lhNoticeStart + 1);
            this.lhCancel(0, false);
            bytes32 record = _lhRound(i % 2, true);
            require(
                ingress.identityRecoveryRecord(record).delegationEpoch == uint64(i) + 2,
                "each successful living35 increments current epoch exactly once"
            );
        }
        require(
            lhCancellationCount == 3 && lhRecoveries.length == 4,
            "original first35 and every later actual notice/recovery retained"
        );
    }

    function testLivingHistoryLaterArbiterThenProtectedAppealPreservePermanentExclusions() public {
        this.lhSetup(true);
        this.lhEpisode(lhNoticeStart + 1);
        this.lhCancel(0, false);
        this.lhCompromise(uint64(block.timestamp + 1));
        (IdentityRecovery.Request memory p, T.Authorization memory a) =
            this.lhRequest(lhProtected, 0);
        _lhRole(p, Appeal27.ARBITER);
        _lhElect(p, a, lhRetained);
        _lhRegister(p, a, false);
        bytes32 first = _lhRecover(p, a, lhRetained, true);
        bytes32 candidate = this.rrGuardian(address(artist), 25 days, 4000);
        this.lhRotate();
        this.lhCompromise(lhWindow);
        (p, a) = this.lhRequest(candidate, 0);
        _lhRole(p, Appeal27.APPEAL);
        vm.expectRevert(
            abi.encodeWithSelector(Appeal27.InvalidGuardianAppeal.selector, p.evidenceHash)
        );
        ingress.identityRecoveryContext(p, a);
        (p, a) = _lhAppeal(p, candidate);
        _lhElect(p, a, lhRetained);
        _lhRegister(p, a, true);
        bytes32 second = _lhRecover(p, a, lhRetained, true);
        require(
            _status(lhProtected).recoveryRecordHash == first
                && _status(candidate).recoveryRecordHash == second,
            "independent adjudications remain permanent across later35 and32 histories"
        );
    }

    function testLivingHistoryCorruptedOriginalNoticeCauseAndDismissalRejectThenRestoreIdenticalRequest()
        public
    {
        this.lhSetup(true);
        this.lhNoticeCompromise(lhNoticeStart + 1);
        this.lhCancel(0, false);
        this.lhDismissAfterCancellation();
        this.lhCompromise(uint64(block.timestamp + 1));
        (IdentityRecovery.Request memory p, T.Authorization memory a) = this.lhRequest(0, 0);
        bytes32 context = keccak256(abi.encode(ingress.identityRecoveryContext(p, a)));
        (Dormancy27.Notice memory n,, Dormancy27.Terminal memory t) =
            IStreamArtistDormancy(address(ingress)).dormancyRecord(lhNotice);
        bytes memory getter = abi.encodeCall(IStreamArtistDormancy.dormancyRecord, (lhNotice));
        _lhCorruptHash(p, a, getter, n.witnessHash, context);
        _lhCorrupt(p, a, _lhNoticeCounterSlot(lhNotice), bytes32(n.priorActivity + 1), context);
        bytes32 packed = bytes32(
            uint256(uint160(t.actor)) | uint256(t.authorityClass) << 160 | uint256(t.observedAt)
                << 168
        );
        _lhCorrupt(
            p, a, _lhSlot(getter, packed), bytes32(uint256(packed) ^ (uint256(1) << 168)), context
        );
        _lhCorrupt(p, a, _lhCauseNoticeSlot(lhNoticeCauses[0]), 0, context);
        Dismissal.Cause memory cause = ingress.identityContestCause(lhNoticeCauses[0]);
        _lhCorruptHash(
            p,
            a,
            abi.encodeCall(ingress.identityContestCause, (cause.causeHash)),
            cause.facts.previousCauseHash,
            context
        );
        Dismissal.Record memory d = ingress.identityContestDismissalRecord(lhNoticeDismissals[0]);
        _lhCorruptHash(
            p,
            a,
            abi.encodeCall(ingress.identityContestDismissalRecord, (d.recordHash)),
            d.governanceWitnessHash,
            context
        );
        (,,, bytes32 head) = ingress.guardianSet(artistId);
        _lhRegister(p, a, false);
        _lhRecover(p, a, head, true);
    }

    function testLivingHistoryOriginalFirstClosureCannotBeReplacedOrErased() public {
        this.lhSetup(true);
        this.lhEpisode(lhNoticeStart + 1);
        this.lhEpisode(lhNoticeStart + 1);
        this.lhCancel(0, false);
        this.lhCompromise(uint64(block.timestamp + 1));
        (IdentityRecovery.Request memory p, T.Authorization memory a) = this.lhRequest(0, 0);
        bytes32 context = keccak256(abi.encode(ingress.identityRecoveryContext(p, a)));
        bytes32 slot = _lhSlot(
            abi.encodeCall(ingress.identityTransitionClosure, (artistId, lhNoticeExecution)),
            lhNoticeDismissals[0]
        );
        _lhCorrupt(p, a, slot, lhNoticeDismissals[1], context);
        _lhEmptyClosure(p, a, lhNoticeExecution, slot, context);
        (,,, bytes32 head) = ingress.guardianSet(artistId);
        _lhRegister(p, a, false);
        _lhRecover(p, a, head, true);
    }

    function testLivingHistoryOriginal35AndExecuted32VestingCommitmentsRejectCorruptionThenRetry()
        public
    {
        this.lhSetup(true);
        bytes32 living = lhPrior;
        this.lhEpisode(lhNoticeStart + 1);
        this.lhCancel(0, false);
        this.lhRotate();
        this.lhCompromise(lhWindow);
        (IdentityRecovery.Request memory p, T.Authorization memory a) = this.lhRequest(0, 0);
        bytes32 context = keccak256(abi.encode(ingress.identityRecoveryContext(p, a)));
        _lhCorruptHash(
            p,
            a,
            abi.encodeCall(
                IStreamArtistGuardianVestingHistory.guardianVestingSnapshot, (artistId, living)
            ),
            _snapshot(living).guardians.commitment,
            context
        );
        _lhCorruptHash(
            p,
            a,
            abi.encodeCall(
                IStreamArtistGuardianVestingHistory.guardianVestingSnapshot, (artistId, lhTerminal)
            ),
            _snapshot(lhTerminal).previousCommitment,
            context
        );
        IdentityRecovery.Record memory original = ingress.identityRecoveryRecord(living);
        _lhCorruptHash(
            p,
            a,
            abi.encodeCall(ingress.identityRecoveryRecord, (living)),
            original.contextHash,
            context
        );
        (,,, bytes32 head) = ingress.guardianSet(artistId);
        _lhRegister(p, a, false);
        _lhRecover(p, a, head, true);
    }

    function testLivingHistoryUnclosedEarlyCurrentCompromiseDoesNotMatureByWaiting() public {
        this.lhSetup(false);
        this.lhCompromise(lhWindow - 1);
        (IdentityRecovery.Request memory p, T.Authorization memory a) = this.lhRequest(0, 0);
        bytes32 roots = _roots();
        vm.expectRevert(
            abi.encodeWithSelector(
                IdentityRecovery.UnsupportedIdentityRecoveryProfile.selector, artistId
            )
        );
        ingress.identityRecoveryContext(p, a);
        this.rrAt(lhWindow + 1);
        vm.expectRevert(
            abi.encodeWithSelector(
                IdentityRecovery.UnsupportedIdentityRecoveryProfile.selector, artistId
            )
        );
        ingress.identityRecoveryContext(p, a);
        (bool used,) = ingress.rotationAcceptanceNonceState(artistId, p.newAddress, a.nonce);
        require(
            !used && roots == _roots()
                && ingress.identityTransitionClosure(artistId, lhTerminal).dismissalRecordHash == 0,
            "passing time never fabricates an omitted current closure or consumes authority"
        );
    }

    function testLivingHistoryDeepExecutedChainRetainsPendingCompromiseAbortAndRejectsMissingClosure()
        public
    {
        this.lhSetup(false);
        bytes32 living = lhPrior;
        this.lhRotate();
        bytes32 first = lhTerminal;
        bytes32 pending = this.lhAbortPendingWithCompromise(false);
        bytes32 firstClosure = _lhClosure(first);
        bytes32 pendingClosure = _lhClosure(pending);
        this.lhRotate();
        bytes32 second = lhTerminal;
        this.lhRotate();
        bytes32 third = lhTerminal;
        require(
            _snapshot(first).previousTransitionRecordHash == living
                && _snapshot(second).previousTransitionRecordHash == first
                && ingress.rotationRecord(second).terms.expectedPreviousTransitionRecordHash
                    == pending && _snapshot(third).previousTransitionRecordHash == second,
            "deep actual execution chain retains separate abandoned staging predecessor"
        );
        this.lhCompromise(lhWindow);
        (IdentityRecovery.Request memory p, T.Authorization memory a) = this.lhRequest(0, 0);
        bytes32 context = keccak256(abi.encode(ingress.identityRecoveryContext(p, a)));
        bytes32 original = ingress.identityTransitionClosure(artistId, pending).dismissalRecordHash;
        bytes32 slot = _lhSlot(
            abi.encodeCall(ingress.identityTransitionClosure, (artistId, pending)), original
        );
        _lhEmptyClosure(p, a, pending, slot, context);
        (,,, bytes32 head) = ingress.guardianSet(artistId);
        _lhRegister(p, a, false);
        bytes32 record = _lhRecover(p, a, head, true);
        require(
            _lhClosure(first) == firstClosure && _lhClosure(pending) == pendingClosure
                && ingress.identityRecoveryRecord(record).delegationEpoch == 2,
            "deep pending-C1 history preserves both original closures and increments epoch only for35"
        );
    }

    function testLivingHistoryPendingCompromiseClosureSupportsDirect35AndTerminal32Repeats()
        public
    {
        this.lhSetup(false);
        bytes32 firstPending = this.lhAbortPendingWithCompromise(true);
        bytes32 firstClosure = _lhClosure(firstPending);
        bytes32 first = _lhRound(0, true);
        require(
            ingress.identityRecoveryRecord(first).delegationEpoch == 2,
            "direct35 continuation accepts actual zero-subject pending compromise closure"
        );
        this.lhRotate();
        bytes32 terminal = lhTerminal;
        bytes32 secondPending = this.lhAbortPendingWithCompromise(false);
        bytes32 secondClosure = _lhClosure(secondPending);
        bytes32 second = _lhRound(0, true);
        require(
            _snapshot(second).previousTransitionRecordHash == terminal
                && ingress.identityRecoveryRecord(second).delegationEpoch == 3
                && _lhClosure(firstPending) == firstClosure
                && _lhClosure(secondPending) == secondClosure,
            "terminal32 and prior35 pending-C1 closures remain independently exact across further recovery"
        );
    }
}

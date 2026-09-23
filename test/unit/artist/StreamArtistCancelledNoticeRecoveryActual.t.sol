// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./StreamArtistDormancyRepeatedRecoveryActual.t.sol";
import {
    IStreamArtistDormancyOwner
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistDormancy.sol";

import {
    IStreamArtistStewardSanctionGrant as CNGrant
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistStewardSanctionGrant.sol";

/// @notice Actual cancelled notice histories -> new designated43 -> elected35 without an intervening35.
/// @dev One existing Artist/Safe/Archive graph. The original notices, causes and receipts are real;
/// Core and governed scheduling use the inherited exact typed unit boundaries. No class4/hydration.
contract StreamArtistCancelledNoticeRecoveryActualTest is
    StreamArtistDormancyRepeatedRecoveryActualTest
{
    bytes32 private cnOrigin;
    bytes32 private cnNotice;
    bytes32 private cnTerminal;
    bytes32 private cnPrior;
    bytes32 private cnBefore43;
    bytes32 private cnDesignation;
    bytes32 private cnProtected;
    bytes32 private cnRetained;
    bytes32 private cnFrozen;
    bytes32 private cnElection;
    bytes32 private cnOriginalNotice;
    bytes32 private cnOldClosure;
    uint64 private cnWindow;
    uint64 private cnNoticeStart;
    uint64 private cnDeadline;
    uint32 private cnMask;
    uint256 private cnSalt = 87000;
    bytes32[] private cnRecoveries;
    bytes32[] private cnRotations;
    bytes32[] private cnExcluded;
    bytes32[] private cnDismissals;
    bytes32[] private cnNoticeCauses;
    bytes32[] private cnNoticeDismissals;
    bytes32[] private cnCauseNotices;
    bytes32[] private cnNotices;
    bytes32[] private cnCancelled;
    bytes32[] private cnCancellationHashes;
    bytes32[] private cnActivityGrants;
    uint256 private cnCancellationCount;
    address private cnDesignatedAddress;
    uint256[] private cnDesignatedKeys;

    modifier cnSelf() {
        require(msg.sender == address(this), "cancelled notice recovery fixture caller");
        _;
    }

    // mode: 0 no execution, 1 living32, 2 living35, 3 already-closed living35, 4 living35 -> living32.
    function cnSetup(uint8 mode) external cnSelf {
        require(mode <= 4, "bounded notice fixture mode");
        _deployAppealSuite();
        _accept();
        _payout();
        if (mode >= 2) {
            this.testActualRecoverySnapshotSharesOneRevisionAndTwoReceiptsWithArchiveRetry();
            cnPrior = ingress.latestIdentityRecovery(artistId);
            _cnReceipts(cnPrior);
            cnRecoveries.push(cnPrior);
            cnTerminal = cnPrior;
            cnWindow = ingress.artistTransitionState(cnPrior).postWindowEndsAt;
            _adoptRotatedSafe();
            if (mode == 3) {
                this.cnCompromise(cnWindow - 1);
                this.cnDismiss();
            }
            if (mode == 4) this.cnRotate();
        } else {
            _delegateSetup();
            if (mode == 1) {
                this.rrGuardian(address(delegateSafe), 10 days, 7);
                _newRotationSafe(++cnSalt);
                cnTerminal = _stageRotation(0);
                _executeTimedRotation(cnTerminal);
                _adoptRotatedSafe();
                cnRotations.push(cnTerminal);
                cnWindow = ingress.artistTransitionState(cnTerminal).postWindowEndsAt;
            }
        }
        cnBefore43 = cnTerminal;
        cnOldClosure = _cnClosure(cnBefore43);
        cnRetained = this.rrGuardian(address(delegateSafe), 10 days, 900);
        cnProtected = this.rrGuardian(address(artist), 20 days, 1000);
        _newRotationSafe(++cnSalt);
        Succ27.Designation memory plan = _successorTerms(address(rotationSafe), 2);
        plan.grantedCapabilities = 256;
        cnDesignation = _successionRecord(plan);
        cnDesignatedAddress = address(rotationSafe);
        cnDesignatedKeys = rotationKeys;
        cnNotice = this.rrBeginBoundaryDormancy();
        cnNotices.push(cnNotice);
        (Dormancy27.Notice memory n, uint8 phase, Dormancy27.Terminal memory t) =
            IStreamArtistDormancy(address(ingress)).dormancyRecord(cnNotice);
        cnOriginalNotice = keccak256(abi.encode(n));
        cnNoticeStart = n.initiatedAt;
        cnDeadline = n.noticeEndsAt;
        require(
            phase == 1 && t.recordHash == 0 && n.incumbent == address(artist)
                && IStreamArtistIdentityOwner(suite.owners[2]).identity(artistId).status == 2
                && ingress.latestIdentityRecovery(artistId) == cnPrior,
            "actual phase1 notice retains original living principal, deadline and latest35"
        );
        ArtistAppealUnitRoles(suite.roleRegistry).setAppeal(address(this), true);
    }

    function cnNoticeCompromise(uint64 when) external cnSelf {
        this.cnNoticeSubject(when, cnTerminal);
    }

    function cnNoticeSubject(uint64 when, bytes32 subject) external cnSelf {
        this.rrAt(when);
        this.cnRecordSubject(subject);
        Dismissal.Cause memory cause = ingress.currentIdentityContestCause(artistId);
        (bytes32 joined, uint8 phase, bytes32 terminal) = IStreamArtistDormancyOwner(
                suite.owners[2]
            ).dormancyResolutionState(artistId, cause.causeHash);
        require(
            cause.facts.priorStatus == 2 && cause.facts.authorityClass == 1
                && cause.facts.executedTransitionHash == cnBefore43
                && cause.facts.pendingTransitionHash == 0 && joined == cnNotice && phase == 1
                && terminal == 0
                && IStreamArtistIdentityOwner(suite.owners[2]).identity(artistId).status == 4,
            "actual op33 stores original priorStatus2 causeNotice join without completing or cancelling notice"
        );
        require(
            ingress.identityContestRecord(cause.facts.referenceHash).terms.subjectRecordHash
                == subject,
            "original op33 retains exact zero, current or historical subject separately from current execution"
        );
        cnNoticeCauses.push(cause.causeHash);
        cnCauseNotices.push(cnNotice);
        _cnAssertNotice(4);
    }

    function cnNoticeDismiss() external cnSelf {
        bytes32 cause = ingress.currentIdentityContestCause(artistId).causeHash;
        this.cnDismiss();
        bytes32 record = ingress.latestIdentityContestDismissal(artistId);
        Dismissal.Record memory d = ingress.identityContestDismissalRecord(record);
        require(
            d.terms.expectedCauseHash == cause && d.authorityClass == 1 && d.restoredStatus == 2
                && d.incumbent == address(artist) && d.actionId != 0
                && d.governanceWitnessHash != 0,
            "actual dismissal restores notice status2, not ordinary living status1"
        );
        cnNoticeDismissals.push(record);
        _cnAssertNotice(2);
    }

    function cnEpisode(uint64 when) external cnSelf {
        this.cnNoticeCompromise(when);
        this.cnNoticeDismiss();
    }

    function _cnAssertNotice(uint8 expectedStatus) private view {
        (Dormancy27.Notice memory n, uint8 phase, Dormancy27.Terminal memory t) =
            IStreamArtistDormancy(address(ingress)).dormancyRecord(cnNotice);
        (bytes32 notice, uint8 currentPhase, bytes32 terminal) =
            IStreamArtistDormancy(address(ingress)).dormancyNotice(artistId);
        (uint8 status, uint64 end,) =
            IStreamArtistDormancy(address(ingress)).dormancyState(artistId);
        require(
            keccak256(abi.encode(n)) == cnOriginalNotice && phase == 1 && currentPhase == 1
                && notice == cnNotice && terminal == 0 && t.recordHash == 0
                && status == expectedStatus && end == cnDeadline
                && IStreamArtistIdentityOwner(suite.owners[2])
                .identity(artistId)
                .lastAuthorityActionAt == n.priorLivenessAt,
            "original active notice, deadline and liveness remain exact through each governed episode"
        );
    }

    function cnComplete() external cnSelf {
        rotationSafe = OfficialSafe(payable(cnDesignatedAddress));
        rotationKeys = cnDesignatedKeys;
        // Active phase1 may persist past its deadline. Never rewind a later actual dismissal.
        if (block.timestamp < cnDeadline) this.rrAt(cnDeadline);
        IStreamArtistDormancy dormancy = IStreamArtistDormancy(address(ingress));
        Dormancy27.Completion memory p = Dormancy27.Completion(
            artistId,
            cnNotice,
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
            suite.roleRegistry,
            address(this),
            keccak256(evidence),
            "urn:cancelled-notice-recovery:completion"
        );
        _cnWitness(x.scopeHash, x.oldValueHash, x.newValueHash);
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
            dormancy.dormancyRecord(cnNotice);
        cnOrigin = t.recordHash;
        cnTerminal = cnOrigin;
        cnWindow = ingress.artistTransitionState(cnOrigin).postWindowEndsAt;
        _adoptRotatedSafe();
        Estate.AuthorityCapabilities memory caps = ingress.currentAuthorityCapabilities(artistId);
        cnMask = caps.effectiveCapabilities;
        require(
            phase == 3 && keccak256(abi.encode(n)) == cnOriginalNotice && t.noticeHash == cnNotice
                && t.plan.designation == cnDesignation && t.authorityClass == 3
                && caps.activationRecordHash == cnOrigin && cnMask == 256
                && ingress.latestIdentityRecovery(artistId) == cnPrior
                && t.delegationEpoch
                    == (cnPrior == 0
                            ? 1
                            : ingress.identityRecoveryRecord(cnPrior).delegationEpoch + 1)
                && _snapshot(cnOrigin).previousTransitionRecordHash == cnBefore43
                && _snapshot(cnOrigin).previousCommitment
                    == (cnBefore43 == 0 ? bytes32(0) : _snapshot(cnBefore43).commitment),
            "actual43 retains original notice, precise living predecessor and its separate current epoch"
        );
        for (uint256 i; i < cnNoticeCauses.length; ++i) {
            (bytes32 joined, uint8 currentPhase, bytes32 terminal) = IStreamArtistDormancyOwner(
                    suite.owners[2]
                ).dormancyResolutionState(artistId, cnNoticeCauses[i]);
            (, uint8 savedPhase, Dormancy27.Terminal memory savedTerminal) =
                dormancy.dormancyRecord(cnCauseNotices[i]);
            require(
                joined == cnCauseNotices[i] && currentPhase == savedPhase
                    && terminal == savedTerminal.recordHash
                    && (currentPhase == 2 || currentPhase == 3),
                "each original causeNotice retains its own cancelled or completed terminal"
            );
        }
        for (uint256 i; i < cnNoticeDismissals.length; ++i) {
            require(
                ingress.identityContestDismissalRecord(cnNoticeDismissals[i]).dismissedAt
                    <= t.observedAt,
                "completion never predates an admitted active-notice dismissal"
            );
        }
        _cnPreservedCancellations();
    }

    function _cnWitness(bytes32 scope, bytes32 old_, bytes32 next_) private {
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

    function cnBeginNext() external cnSelf {
        require(
            cnOrigin == 0
                && IStreamArtistIdentityOwner(suite.owners[2]).identity(artistId).status == 1,
            "new notice requires actual restored living status without intervening35"
        );
        _cnPreservedCancellations();
        cnBefore43 = cnTerminal;
        cnOldClosure = _cnClosure(cnBefore43);
        cnNotice = this.rrBeginBoundaryDormancy();
        cnNotices.push(cnNotice);
        (Dormancy27.Notice memory n, uint8 phase, Dormancy27.Terminal memory t) =
            IStreamArtistDormancy(address(ingress)).dormancyRecord(cnNotice);
        cnOriginalNotice = keccak256(abi.encode(n));
        cnNoticeStart = n.initiatedAt;
        cnDeadline = n.noticeEndsAt;
        require(
            phase == 1 && t.recordHash == 0 && n.priorActivity == cnCancellationCount
                && n.incumbent == address(artist)
                && ingress.latestIdentityRecovery(artistId) == cnPrior,
            "new actual notice captures exact cancellation counter and unchanged latest35"
        );
        _cnAssertNotice(2);
        _cnPreservedCancellations();
    }

    // 0 current principal Safe, 1 operative designated Safe, 2 signed op19 activity.
    function cnCancel(uint8 method, bool retry) external cnSelf {
        require(method <= 2 && (!retry || method == 2), "bounded original cancellation producers");
        (Dormancy27.Notice memory n, uint8 phase,) =
            IStreamArtistDormancy(address(ingress)).dormancyRecord(cnNotice);
        T.Identity memory before_ = IStreamArtistIdentityOwner(suite.owners[2]).identity(artistId);
        require(
            phase == 1 && n.priorActivity == cnCancellationCount,
            "actual open notice before cancellation"
        );
        address actor = method == 1 ? cnDesignatedAddress : address(artist);
        uint8 class_ = method == 1 ? 3 : 1;
        if (method == 2) {
            CNGrant.Grant memory p = CNGrant.Grant(
                artistId, true, keccak256(abi.encode("cancelled notice signed activity", cnNotice))
            );
            T.Authorization memory a = _authorization(true);
            a.signature = _signature(CNGrant(address(ingress)).stewardSanctionGrantDigest(p, a));
            bytes32 request = keccak256(abi.encode(p, a));
            if (retry) {
                bytes32 roots = _roots();
                bytes32 history = _cnHistory();
                _overflow();
                CNGrant(address(ingress)).recordStewardSanctionGrant(p, a);
                require(
                    roots == _roots() && history == _cnHistory()
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
            cnActivityGrants.push(grant);
        } else {
            OfficialSafe signer = method == 1 ? OfficialSafe(payable(cnDesignatedAddress)) : artist;
            uint256[] memory signingKeys = method == 1 ? cnDesignatedKeys : keys;
            require(
                executeSafe(
                    signer,
                    signingKeys,
                    address(ingress),
                    0,
                    abi.encodeCall(
                        IStreamArtistDormancy.cancelArtistDormancy, (artistId, cnNotice, bytes32(0))
                    ),
                    0
                ),
                "actual authorized threshold Safe operation42"
            );
        }
        (Dormancy27.Notice memory saved, uint8 cancelled, Dormancy27.Terminal memory t) =
            IStreamArtistDormancy(address(ingress)).dormancyRecord(cnNotice);
        ++cnCancellationCount;
        bytes32 record = t.recordHash;
        Dormancy27.Terminal memory preimage;
        preimage.noticeHash = t.noticeHash;
        preimage.actor = t.actor;
        preimage.authorityClass = t.authorityClass;
        preimage.observedAt = t.observedAt;
        require(
            cancelled == 2 && keccak256(abi.encode(saved)) == cnOriginalNotice
                && t.noticeHash == cnNotice && t.actor == actor && t.authorityClass == class_
                && t.observedAt == block.timestamp && cnCancellationCount == n.priorActivity + 1
                && record
                    == keccak256(
                        abi.encode(
                            keccak256("6529STREAM_ARTIST_DORMANCY_CANCELLATION_V1"),
                            block.chainid,
                            address(ingress),
                            suite.owners[2],
                            preimage,
                            cnCancellationCount
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
                && ingress.latestIdentityRecovery(artistId) == cnPrior,
            "authenticated cancellation refreshes liveness but never dismisses a genuine compromise"
        );
        if (method != 2) {
            require(
                _operationPayload(42, actor, record).length != 0, "original operation42 archived"
            );
        }
        cnCancelled.push(cnNotice);
        cnCancellationHashes.push(keccak256(abi.encode(saved, cancelled, t)));
        _cnPreservedCancellations();
    }

    function _cnPreservedCancellations() private view {
        for (uint256 i; i < cnCancelled.length; ++i) {
            (Dormancy27.Notice memory n, uint8 phase, Dormancy27.Terminal memory t) =
                IStreamArtistDormancy(address(ingress)).dormancyRecord(cnCancelled[i]);
            require(
                phase == 2 && cnCancellationHashes[i] == keccak256(abi.encode(n, phase, t)),
                "every cancelled original notice and terminal remains byte-identical"
            );
        }
    }

    function cnDismissAfterCancellation() external cnSelf {
        bytes32 cause = ingress.currentIdentityContestCause(artistId).causeHash;
        this.cnDismiss();
        Dismissal.Record memory d = ingress.identityContestDismissalRecord(
            ingress.latestIdentityContestDismissal(artistId)
        );
        (bytes32 notice, uint8 phase, bytes32 terminal) =
            IStreamArtistDormancyOwner(suite.owners[2]).dormancyResolutionState(artistId, cause);
        require(
            d.terms.expectedCauseHash == cause && d.restoredStatus == 1 && d.authorityClass == 1
                && notice == cnNotice && phase == 2 && terminal != 0
                && IStreamArtistIdentityOwner(suite.owners[2]).identity(artistId).status == 1,
            "actual dismissal after cancellation restores ACTIVE1 while immutable cause remains priorStatus2"
        );
        cnNoticeDismissals.push(d.recordHash);
        _cnPreservedCancellations();
    }

    function cnExecuteDismissalContext(Dismissal.Request memory p, Dismissal.Context memory x)
        external
        cnSelf
    {
        ArtistUnitGovernance authority = ArtistUnitGovernance(manager.governanceAuthority());
        authority.configureContestReads(
            suite.roleRegistry,
            address(artist),
            p.reasonHash,
            "urn:cancelled-notice:stale-dismissal"
        );
        _cnWitness(x.scopeHash, x.oldValueHash, x.newValueHash);
        authority.executeModuleContext(
            address(ingress),
            abi.encodeCall(IStreamArtistIdentityDismissal.dismissArtistIdentityContest, (p)),
            1,
            x.scopeHash,
            x.oldValueHash,
            x.newValueHash
        );
        _inactive();
    }

    function cnCompromise(uint64 when) external cnSelf {
        this.rrAt(when);
        this.cnRecordCause();
    }

    function cnRecordCause() external cnSelf {
        this.cnRecordSubject(cnTerminal);
    }

    function cnRecordSubject(bytes32 subject) external cnSelf {
        ArtistAppealUnitRoles(suite.roleRegistry).setArbiter(address(artist), true);
        bytes32 evidence = keccak256(
            abi.encode(
                "cancelled notice recovery cause",
                cnTerminal,
                block.timestamp,
                ingress.latestIdentityContestDismissal(artistId)
            )
        );
        bytes32 reason = keccak256(abi.encode("cancelled notice recovery reason", evidence));
        ArtistUnitGovernance authority = ArtistUnitGovernance(manager.governanceAuthority());
        authority.configureContestReads(
            suite.roleRegistry, address(artist), reason, "urn:cancelled-notice-recovery:cause"
        );
        (bytes32 scope, bytes32 old_, bytes32 next_) =
            ingress.identityContestGovernanceContext(artistId, subject, evidence, reason);
        _cnWitness(scope, old_, next_);
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
            cause.facts.kind == 1 && cause.facts.executedTransitionHash == cnTerminal
                && cause.facts.incumbent == address(artist)
                && cause.facts.authorityClass == (cnOrigin == 0 ? 1 : 3)
                && ingress.latestIdentityRecovery(artistId) == cnPrior,
            "new actual33 names the operative execution while preserving latest old35"
        );
    }

    function cnDismiss() external cnSelf {
        bytes32 first = ingress.identityTransitionClosure(artistId, cnTerminal).dismissalRecordHash;
        Dismissal.Request memory p = _dismissalRequest();
        ArtistAppealUnitRoles(suite.roleRegistry).setArbiter(address(artist), true);
        ArtistUnitGovernance authority = ArtistUnitGovernance(manager.governanceAuthority());
        authority.configureContestReads(
            suite.roleRegistry,
            address(artist),
            p.reasonHash,
            "urn:cancelled-notice-recovery:dismissal"
        );
        Dismissal.Context memory x = ingress.identityContestDismissalContext(p);
        _cnWitness(x.scopeHash, x.oldValueHash, x.newValueHash);
        authority.executeModuleContext(
            address(ingress),
            abi.encodeCall(IStreamArtistIdentityDismissal.dismissArtistIdentityContest, (p)),
            1,
            x.scopeHash,
            x.oldValueHash,
            x.newValueHash
        );
        _inactive();
        cnDismissals.push(ingress.latestIdentityContestDismissal(artistId));
        require(
            ingress.identityTransitionClosure(artistId, cnTerminal).dismissalRecordHash
                == (cnTerminal == 0
                        ? bytes32(0)
                        : first == 0 ? ingress.latestIdentityContestDismissal(artistId) : first),
            "first original closure remains fixed"
        );
        if (cnTerminal == 0) {
            Dismissal.Closure memory empty;
            require(
                keccak256(abi.encode(ingress.identityTransitionClosure(artistId, 0)))
                    == keccak256(abi.encode(empty)),
                "zero execution has no fabricated closure"
            );
        }
    }

    function _cnMature() private {
        if (
            ingress.identityTransitionClosure(artistId, cnTerminal).dismissalRecordHash == 0
                && block.timestamp < cnWindow
        ) {
            this.rrAt(cnWindow);
        }
    }

    function cnRotate() external cnSelf {
        _cnMature();
        bytes32 previous = cnTerminal;
        _newRotationSafe(++cnSalt);
        cnTerminal = _stageRotation(ingress.lastArtistTransition(artistId));
        _executeTimedRotation(cnTerminal);
        _adoptRotatedSafe();
        cnRotations.push(cnTerminal);
        cnWindow = ingress.artistTransitionState(cnTerminal).postWindowEndsAt;
        Estate.AuthorityCapabilities memory caps = ingress.currentAuthorityCapabilities(artistId);
        require(
            _snapshot(cnTerminal).previousTransitionRecordHash == previous
                && _snapshot(cnTerminal).previousCommitment == _snapshot(previous).commitment
                && ingress.latestIdentityRecovery(artistId) == cnPrior
                && caps.authorityClass == (cnOrigin == 0 ? 1 : 3)
                && caps.activationRecordHash == cnOrigin,
            "actual32 retains exact executed parent, latest35 and original43"
        );
    }

    function cnStanding() external cnSelf {
        _cnMature();
        _newRotationSafe(++cnSalt);
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
            cause.facts.kind == 2 && cause.facts.executedTransitionHash == cnTerminal
                && cause.facts.pendingTransitionHash == pending && cause.facts.evidenceHash == 0
                && cause.facts.reasonHash == 0,
            "original zero-reason standing producer"
        );
        this.cnDismiss();
    }

    function cnRequest(bytes32 first, bytes32 second)
        external
        cnSelf
        returns (IdentityRecovery.Request memory p, T.Authorization memory a)
    {
        _newRotationSafe(++cnSalt);
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

    function _cnClosure(bytes32 record) private view returns (bytes32) {
        Dismissal.Closure memory c = ingress.identityTransitionClosure(artistId, record);
        Dismissal.Record memory d = ingress.identityContestDismissalRecord(c.dismissalRecordHash);
        Dismissal.Cause memory cause = ingress.identityContestCause(d.terms.expectedCauseHash);
        return keccak256(
            abi.encode(c, d, cause, ingress.rotationRecord(cause.facts.pendingTransitionHash))
        );
    }

    function _cnHistory() private view returns (bytes32 value) {
        for (uint256 i; i < cnNotices.length; ++i) {
            (Dormancy27.Notice memory notice, uint8 phase, Dormancy27.Terminal memory terminal) =
                IStreamArtistDormancy(address(ingress)).dormancyRecord(cnNotices[i]);
            value = keccak256(abi.encode(value, notice, phase, terminal));
        }
        for (uint256 i; i < cnActivityGrants.length; ++i) {
            value = keccak256(
                abi.encode(
                    value, CNGrant(address(ingress)).stewardSanctionGrantRecord(cnActivityGrants[i])
                )
            );
        }
        if (cnOrigin != 0) {
            (Dormancy27.Notice memory n, uint8 phase, Dormancy27.Terminal memory t) =
                IStreamArtistDormancy(address(ingress)).dormancyRecord(cnNotice);
            value = keccak256(
                abi.encode(
                    value,
                    n,
                    phase,
                    t,
                    _snapshot(cnOrigin),
                    ingress.artistTransitionState(cnOrigin),
                    _cnClosure(cnOrigin)
                )
            );
        }
        value = keccak256(abi.encode(value, ingress.successorDesignationRecord(cnDesignation)));
        for (uint256 i; i < cnRecoveries.length; ++i) {
            bytes32 record = cnRecoveries[i];
            (bytes32 primary, bytes32 occurrence, bytes32 secondary) =
                IStreamArtistIdentityRecoveryOwner(suite.owners[2]).identityRecoveryReceipts(record);
            value = keccak256(
                abi.encode(
                    value,
                    ingress.identityRecoveryRecord(record),
                    _snapshot(record),
                    ingress.artistTransitionState(record),
                    _cnClosure(record),
                    primary,
                    occurrence,
                    secondary
                )
            );
        }
        for (uint256 i; i < cnRotations.length; ++i) {
            bytes32 record = cnRotations[i];
            value = keccak256(
                abi.encode(
                    value, ingress.rotationRecord(record), _snapshot(record), _cnClosure(record)
                )
            );
        }
        for (uint256 i; i < cnExcluded.length; ++i) {
            value = keccak256(abi.encode(value, _status(cnExcluded[i])));
        }
        for (uint256 i; i < cnDismissals.length; ++i) {
            Dismissal.Record memory d = ingress.identityContestDismissalRecord(cnDismissals[i]);
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
        for (uint256 i; i < cnNoticeCauses.length; ++i) {
            Dismissal.Cause memory cause = ingress.identityContestCause(cnNoticeCauses[i]);
            (bytes32 notice, uint8 phase, bytes32 terminal) = IStreamArtistDormancyOwner(
                    suite.owners[2]
                ).dormancyResolutionState(artistId, cnNoticeCauses[i]);
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

    function _cnRegister(IdentityRecovery.Request memory p, T.Authorization memory a, bool appeal)
        private
    {
        GovernanceCall[] memory calls = _schedule(
            keccak256(abi.encode("cancelled notice recovery action", cnPrior, cnTerminal, cnSalt)),
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
        cnFrozen = _cnHistory();
    }

    function _cnElect(IdentityRecovery.Request memory p, T.Authorization memory a, bytes32 selected)
        private
    {
        IStreamArtistGuardianSelectionPreparation prep = _selectionPreparation();
        cnElection = prep.begin(artistId, cnTerminal, p.supersededRecordHashes);
        (GH.Head memory head,,,) = IStreamArtistGuardianHistory(suite.owners[2])
            .guardianHistoryState(artistId, 0, address(0), 0);
        bytes32 roots = _roots();
        vm.expectRevert(
            abi.encodeWithSelector(
                Selection.IncompleteGuardianSelection.selector, cnElection, uint64(0), head.count
            )
        );
        ingress.identityRecoveryContext(p, a);
        Selection.Progress memory progress = prep.continueSelection(cnElection, 1);
        require(!progress.complete, "partial guardian prefix is not complete election");
        progress = prep.continueSelection(cnElection, 64);
        require(
            progress.complete && progress.processed == head.count
                && progress.selectedRecordHash == selected && roots == _roots(),
            "complete original-record election"
        );
    }

    function _cnRecover(
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
        if (retry) _cnRollback(p, a, epoch);
        vm.recordLogs();
        record = this.executeRegistered(p, a);
        _assertSnapshot(_snapshot(record), 35, before_, vm.getRecordedLogs());
        _cnReceipts(record);
        IdentityRecovery.Record memory r = ingress.identityRecoveryRecord(record);
        Estate.AuthorityCapabilities memory caps = ingress.currentAuthorityCapabilities(artistId);
        (,,, bytes32 head) = ingress.guardianSet(artistId);
        (bool used,) = ingress.rotationAcceptanceNonceState(artistId, p.newAddress, a.nonce);
        require(
            caps.authorityClass == p.vestedAuthorityClass && caps.status == p.vestedAuthorityClass
                && caps.authorityAddress == p.newAddress && r.delegationEpoch == epoch + 1
                && _snapshot(record).previousTransitionRecordHash == cnTerminal
                && _snapshot(record).previousCommitment == _snapshot(cnTerminal).commitment && used
                && head == selected && _cnHistory() == cnFrozen
                && r.fields.supersededRecordsHash
                    == RecoveryHashes.supersession(p.supersededRecordHashes)
                && keccak256(abi.encode(r.terms.supersededRecordHashes))
                    == keccak256(abi.encode(p.supersededRecordHashes)),
            "actual35 increments current epoch, preserves every original record and applies only exact exclusions"
        );
        if (cnOrigin != 0) {
            require(
                caps.activationRecordHash == cnOrigin && caps.effectiveCapabilities == cnMask,
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
            !ok && roots == _roots() && _cnHistory() == cnFrozen,
            "identical old action cannot replay"
        );
        cnRecoveries.push(record);
        for (uint256 i; i < p.supersededRecordHashes.length; ++i) {
            cnExcluded.push(p.supersededRecordHashes[i]);
        }
        cnPrior = record;
        cnTerminal = record;
        cnWindow = ingress.artistTransitionState(record).postWindowEndsAt;
        _adoptRotatedSafe();
    }

    function _cnRollback(IdentityRecovery.Request memory p, T.Authorization memory a, uint64 epoch)
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
            !used && roots == _roots() && cnFrozen == _cnHistory()
                && ingress.latestIdentityRecovery(artistId) == cnPrior && head == oldHead
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
    function _cnReceipts(bytes32 record) private view {
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

    function _cnRound(uint8 rotations, bool retry) private returns (bytes32 record) {
        for (uint256 i; i < rotations; ++i) {
            this.cnRotate();
        }
        this.cnCompromise(cnWindow);
        (IdentityRecovery.Request memory p, T.Authorization memory a) = this.cnRequest(0, 0);
        (,,, bytes32 head) = ingress.guardianSet(artistId);
        _cnRegister(p, a, false);
        return _cnRecover(p, a, head, retry);
    }

    function _cnPublisher() private view returns (IStreamArtistGuardianAppealEvidence publisher) {
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

    function _cnAppeal(IdentityRecovery.Request memory p, bytes32 protectedRecord)
        private
        returns (IdentityRecovery.Request memory, T.Authorization memory)
    {
        Dismissal.Cause memory cause = ingress.currentIdentityContestCause(artistId);
        Appeal27.Document memory document = Appeal27.Document(
            Appeal27.requestCommitment(p),
            cause.causeHash,
            cause.facts.referenceHash,
            _snapshot(cnTerminal).commitment,
            cnTerminal,
            keccak256("cancelled notice recovery specific findings"),
            new Appeal27.Finding[](1)
        );
        address[] memory parties = ingress.guardianSetRecord(protectedRecord).terms.guardians;
        document.findings[0] = Appeal27.Finding(protectedRecord, parties);
        bytes32 roots = _roots();
        bytes32 latest = ingress.latestIdentityRecovery(artistId);
        p.evidenceHash = _cnPublisher().publish(document);
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

    function _cnRole(IdentityRecovery.Request memory p, bytes32 expected) private view {
        require(
            IStreamArtistGuardianAppealOwner(suite.owners[2])
                .guardianRecoveryAuthorityRole(artistId, p.supersededRecordHashes) == expected,
            "exact current cutoff determines protected APPEAL or later-principal ARBITER"
        );
    }

    function _cnSlot(bytes memory getter, bytes32 expected) private returns (bytes32 slot) {
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

    function _cnCorrupt(
        IdentityRecovery.Request memory p,
        T.Authorization memory a,
        bytes32 slot,
        bytes32 replacement,
        bytes32 context
    ) private {
        bytes32 original = vm.load(suite.owners[2], slot);
        require(original != replacement, "corruption changes original bytes");
        bytes32 roots = _roots();
        bytes32 history = _cnHistory();
        vm.store(suite.owners[2], slot, replacement);
        (bool ok,) =
            address(ingress).staticcall(abi.encodeCall(ingress.identityRecoveryContext, (p, a)));
        require(!ok, "same signed request rejects corrupted original proof");
        (bool used,) = ingress.rotationAcceptanceNonceState(artistId, p.newAddress, a.nonce);
        require(!used && roots == _roots(), "failed read cannot consume nonce or Archive state");
        vm.store(suite.owners[2], slot, original);
        require(
            history == _cnHistory()
                && context == keccak256(abi.encode(ingress.identityRecoveryContext(p, a))),
            "exact restoration admits byte-identical request and signature"
        );
    }

    function _cnCorruptHash(
        IdentityRecovery.Request memory p,
        T.Authorization memory a,
        bytes memory getter,
        bytes32 value,
        bytes32 context
    ) private {
        _cnCorrupt(p, a, _cnSlot(getter, value), bytes32(uint256(value) ^ 1), context);
    }

    // The canonical map and the original notice record contain the same hash. Distinguish them
    // by the fixed-owner getter's empty-join behavior, restoring every probed word immediately.
    function _cnCauseNoticeSlot(bytes32 cause) private returns (bytes32 slot) {
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

    function _cnEmptyClosure(
        IdentityRecovery.Request memory p,
        T.Authorization memory a,
        bytes32 dismissalSlot,
        bytes32 context
    ) private {
        // Locate the actual struct by its uniquely observed dismissal field, then verify all
        // four original words against the typed getter before touching the complete closure.
        Dismissal.Closure memory c = ingress.identityTransitionClosure(artistId, cnBefore43);
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
        bytes32 history = _cnHistory();
        for (uint256 i; i < 4; ++i) {
            vm.store(suite.owners[2], bytes32(uint256(base) + i), 0);
        }
        Dismissal.Closure memory empty;
        require(
            keccak256(abi.encode(ingress.identityTransitionClosure(artistId, cnBefore43)))
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
            history == _cnHistory()
                && context == keccak256(abi.encode(ingress.identityRecoveryContext(p, a))),
            "complete original closure restore admits identical request"
        );
    }

    function _cnFinish() private returns (bytes32 record) {
        (IdentityRecovery.Request memory p, T.Authorization memory a) = this.cnRequest(0, 0);
        (,,, bytes32 head) = ingress.guardianSet(artistId);
        _cnRegister(p, a, false);
        return _cnRecover(p, a, head, true);
    }

    function _cnNoticeCounterSlot(bytes32 notice) private returns (bytes32 slot) {
        (Dormancy27.Notice memory n,,) =
            IStreamArtistDormancy(address(ingress)).dormancyRecord(notice);
        bytes32 witnessSlot =
            _cnSlot(abi.encodeCall(IStreamArtistDormancy.dormancyRecord, (notice)), n.witnessHash);
        slot = bytes32(uint256(witnessSlot) - 2);
        require(
            vm.load(suite.owners[2], slot) == bytes32(n.priorActivity)
                && vm.load(suite.owners[2], bytes32(uint256(slot) + 1)) == n.actionId,
            "observed immutable notice counter is adjacent to exact action and witness words"
        );
    }

    function testCancelledNoticeZeroExecutionD2ThenNewNoticeDirectRecoveryPreservesReceipts()
        public
    {
        this.cnSetup(0);
        this.cnEpisode(cnNoticeStart + 1);
        this.cnCancel(0, false);
        this.cnBeginNext();
        this.cnComplete();
        bytes32 record = _cnRound(0, true);
        require(
            ingress.identityRecoveryRecord(record).delegationEpoch == 2 && cnCancelled.length == 1
                && ingress.identityTransitionClosure(artistId, 0).dismissalRecordHash == 0,
            "no invented prior execution, epoch or zero closure across cancelled notice"
        );
    }

    function testCancelledNoticeLiving32OldD2AndNewD2SuffixPermitPost43Rotation() public {
        this.cnSetup(1);
        this.cnEpisode(cnNoticeStart + 1);
        bytes32 closure =
            ingress.identityTransitionClosure(artistId, cnTerminal).dismissalRecordHash;
        this.cnCancel(0, false);
        this.cnBeginNext();
        this.cnEpisode(cnNoticeStart + 1);
        require(
            ingress.identityTransitionClosure(artistId, cnTerminal).dismissalRecordHash == closure,
            "new notice dismissal never replaces original cancelled-notice first closure"
        );
        this.cnComplete();
        _cnRound(1, true);
    }

    function testCancelledNoticeLiving35D2ThenDesigneeCancellationRetainsOriginalLivingOrigin()
        public
    {
        this.cnSetup(2);
        bytes32 living = cnPrior;
        this.cnEpisode(cnNoticeStart + 1);
        this.cnCancel(1, false);
        this.cnBeginNext();
        this.cnComplete();
        bytes32 record = _cnRound(0, true);
        require(
            ingress.identityRecoveryRecord(living).delegationEpoch == 1
                && ingress.identityRecoveryRecord(record).delegationEpoch == 3
                && _snapshot(cnOrigin).previousTransitionRecordHash == living,
            "operative designee cancellation grants no epoch or authority transition"
        );
    }

    function testCancelledNoticeContestedCancellationRequiresFreshDismissalRestoringActive1()
        public
    {
        this.cnSetup(2);
        this.cnNoticeCompromise(cnNoticeStart + 1);
        Dismissal.Request memory p = _dismissalRequest();
        Dismissal.Context memory old = ingress.identityContestDismissalContext(p);
        this.cnCancel(0, false);
        Dismissal.Context memory fresh = ingress.identityContestDismissalContext(p);
        require(
            fresh.oldValueHash != old.oldValueHash && fresh.cohortHash != old.cohortHash,
            "actual phase2 terminal invalidates original staged dismissal cohort"
        );
        bytes32 roots = _roots();
        vm.expectRevert(abi.encodeWithSelector(Contest.InvalidContestGovernance.selector));
        this.cnExecuteDismissalContext(p, old);
        _inactive();
        require(
            roots == _roots()
                && IStreamArtistIdentityOwner(suite.owners[2]).identity(artistId).status == 4,
            "stale context cannot dismiss the cancelled contested notice"
        );
        this.cnDismissAfterCancellation();
        this.cnBeginNext();
        this.cnComplete();
        _cnRound(0, true);
    }

    function testCancelledNoticeMultipleD2ThenFinalD1AndCurrentNoticeD2RemainSeparate() public {
        this.cnSetup(2);
        this.cnEpisode(cnNoticeStart + 1);
        this.cnEpisode(cnNoticeStart + 2);
        this.cnNoticeCompromise(cnNoticeStart + 3);
        this.cnCancel(0, false);
        this.cnDismissAfterCancellation();
        require(
            ingress.identityContestDismissalRecord(cnNoticeDismissals[0]).restoredStatus == 2
                && ingress.identityContestDismissalRecord(cnNoticeDismissals[1]).restoredStatus == 2
                && ingress.identityContestDismissalRecord(cnNoticeDismissals[2]).restoredStatus
                    == 1,
            "original earlier D2 records survive actual final D1 on same cancelled notice"
        );
        this.cnBeginNext();
        this.cnEpisode(cnDeadline + 1);
        this.cnComplete();
        _cnRound(1, true);
    }

    function testCancelledNoticeThreeOriginalCancellationsCarryExactCountersIntoNewCompletion()
        public
    {
        this.cnSetup(0);
        for (uint8 i; i < 3; ++i) {
            this.cnEpisode(cnNoticeStart + 1);
            this.cnCancel(i % 2, false);
            this.cnBeginNext();
        }
        require(
            cnCancellationCount == 3 && cnCancelled.length == 3 && cnNotices.length == 4,
            "three independently retained phase2 notices and monotonic activity counter"
        );
        this.cnEpisode(cnNoticeStart + 1);
        this.cnComplete();
        _cnRound(0, true);
    }

    function testCancelledNoticeSignedActivityCancellationRollsBackAndRetriesIdenticalAuthorization()
        public
    {
        this.cnSetup(1);
        this.cnEpisode(cnNoticeStart + 1);
        this.cnCancel(2, true);
        require(
            cnActivityGrants.length == 1 && cnCancellationCount == 1,
            "one successful actual signed activity and one cancellation after Archive retry"
        );
        this.cnBeginNext();
        this.cnComplete();
        _cnRound(1, true);
    }

    function testCancelledNoticeFirstStatus2ClosureSurvivesLaterActive1Dismissal() public {
        this.cnSetup(2);
        this.cnEpisode(cnNoticeStart + 1);
        bytes32 closure = _cnClosure(cnTerminal);
        this.cnCancel(0, false);
        this.rrAt(uint64(block.timestamp + 1));
        this.cnRecordSubject(0);
        Dismissal.Cause memory active = ingress.currentIdentityContestCause(artistId);
        require(
            active.facts.priorStatus == 1 && active.facts.executedTransitionHash == cnTerminal
                && cnTerminal != 0
                && ingress.identityContestRecord(active.facts.referenceHash).terms.subjectRecordHash
                == 0,
            "new independent ACTIVE1 zero-subject episode still captures actual nonzero execution"
        );
        this.cnDismiss();
        require(
            ingress.identityContestDismissalRecord(ingress.latestIdentityContestDismissal(artistId))
                .restoredStatus == 1 && _cnClosure(cnTerminal) == closure,
            "later ACTIVE1 dismissal preserves first cancelled-notice D2 closure"
        );
        this.cnBeginNext();
        this.cnComplete();
        _cnRound(0, true);
    }

    function testCancelledNoticeOldClosurePermitsLaterLiving32AndRetainsChangedGuardianHead()
        public
    {
        this.cnSetup(2);
        bytes32 living = cnPrior;
        this.cnEpisode(cnNoticeStart + 1);
        bytes32 closure = _cnClosure(living);
        this.cnCancel(0, false);
        this.cnRotate();
        bytes32 rotation = cnTerminal;
        bytes32 later = this.rrGuardian(address(delegateSafe), 25 days, 3000);
        this.cnBeginNext();
        this.cnEpisode(cnNoticeStart + 1);
        this.cnComplete();
        require(
            _snapshot(cnOrigin).previousTransitionRecordHash == rotation
                && _cnClosure(living) == closure,
            "actual living32 stages after old closure without rewriting original35"
        );
        this.cnCompromise(cnWindow);
        bytes32 record = _cnFinish();
        (,,, bytes32 head) = ingress.guardianSet(artistId);
        require(
            head == later && ingress.identityRecoveryRecord(record).delegationEpoch == 3,
            "later actual guardian head and original living epoch survive cancelled-notice rotation boundary"
        );
    }

    function testCancelledNoticeProtectedAppealElectsRetainedOriginalGuardianAfterNewNotice()
        public
    {
        this.cnSetup(2);
        this.cnEpisode(cnNoticeStart + 1);
        this.cnCancel(0, false);
        this.cnBeginNext();
        this.cnEpisode(cnNoticeStart + 1);
        this.cnComplete();
        this.cnCompromise(cnWindow);
        (IdentityRecovery.Request memory p, T.Authorization memory a) =
            this.cnRequest(cnProtected, 0);
        _cnRole(p, Appeal27.APPEAL);
        vm.expectRevert(
            abi.encodeWithSelector(Appeal27.InvalidGuardianAppeal.selector, p.evidenceHash)
        );
        ingress.identityRecoveryContext(p, a);
        (p, a) = _cnAppeal(p, cnProtected);
        _cnElect(p, a, cnRetained);
        _cnRegister(p, a, true);
        _cnRecover(p, a, cnRetained, true);
    }

    function testCancelledNoticeOriginalNoticeCounterAndCancellationFactsRejectCorruptionThenRetry()
        public
    {
        this.cnSetup(2);
        this.cnEpisode(cnNoticeStart + 1);
        this.cnCancel(0, false);
        bytes32 oldNotice = cnNotice;
        this.cnBeginNext();
        this.cnComplete();
        this.cnCompromise(cnWindow);
        (IdentityRecovery.Request memory p, T.Authorization memory a) = this.cnRequest(0, 0);
        bytes32 context = keccak256(abi.encode(ingress.identityRecoveryContext(p, a)));
        (Dormancy27.Notice memory n,, Dormancy27.Terminal memory t) =
            IStreamArtistDormancy(address(ingress)).dormancyRecord(oldNotice);
        bytes memory getter = abi.encodeCall(IStreamArtistDormancy.dormancyRecord, (oldNotice));
        _cnCorruptHash(p, a, getter, n.terms.evidenceHash, context);
        _cnCorruptHash(p, a, getter, n.witnessHash, context);
        _cnCorrupt(p, a, _cnNoticeCounterSlot(oldNotice), bytes32(n.priorActivity + 1), context);
        bytes32 packed = bytes32(
            uint256(uint160(t.actor)) | uint256(t.authorityClass) << 160 | uint256(t.observedAt)
                << 168
        );
        _cnCorrupt(
            p, a, _cnSlot(getter, packed), bytes32(uint256(packed) ^ (uint256(1) << 168)), context
        );
        _cnCorrupt(p, a, _cnNoticeCounterSlot(cnNotice), bytes32(uint256(0)), context);
        (,,, bytes32 head) = ingress.guardianSet(artistId);
        _cnRegister(p, a, false);
        _cnRecover(p, a, head, true);
    }

    function testCancelledNoticeCauseNoticeAndOriginalDismissalLinksRejectSubstitutionThenRetry()
        public
    {
        this.cnSetup(3);
        this.cnEpisode(cnNoticeStart + 1);
        this.cnNoticeCompromise(cnNoticeStart + 2);
        this.cnCancel(0, false);
        this.cnDismissAfterCancellation();
        this.cnBeginNext();
        this.cnEpisode(cnNoticeStart + 1);
        this.cnComplete();
        this.cnCompromise(cnWindow);
        (IdentityRecovery.Request memory p, T.Authorization memory a) = this.cnRequest(0, 0);
        bytes32 context = keccak256(abi.encode(ingress.identityRecoveryContext(p, a)));
        _cnCorrupt(p, a, _cnCauseNoticeSlot(cnNoticeCauses[0]), cnNotice, context);
        _cnCorrupt(p, a, _cnCauseNoticeSlot(cnNoticeCauses[1]), 0, context);
        Dismissal.Record memory d = ingress.identityContestDismissalRecord(cnNoticeDismissals[1]);
        bytes memory getter = abi.encodeCall(ingress.identityContestDismissalRecord, (d.recordHash));
        _cnCorruptHash(p, a, getter, d.terms.expectedResolutionHash, context);
        _cnCorruptHash(p, a, getter, d.governanceWitnessHash, context);
        bytes32 packed = bytes32(
            uint256(uint160(d.incumbent)) | uint256(d.authorityClass) << 160
                | uint256(d.restoredStatus) << 168 | uint256(d.dismissedAt) << 176
        );
        _cnCorrupt(
            p, a, _cnSlot(getter, packed), bytes32(uint256(packed) ^ (uint256(3) << 168)), context
        );
        (,,, bytes32 head) = ingress.guardianSet(artistId);
        _cnRegister(p, a, false);
        _cnRecover(p, a, head, true);
    }

    function testCancelledNoticeLaterClass3RepeatsPreserveAllOldCancellationRecordsAndEpochs()
        public
    {
        this.cnSetup(2);
        this.cnEpisode(cnNoticeStart + 1);
        this.cnCancel(0, false);
        this.cnBeginNext();
        this.cnNoticeCompromise(cnNoticeStart + 1);
        this.cnCancel(1, false);
        this.cnDismissAfterCancellation();
        this.cnBeginNext();
        this.cnComplete();
        _cnRound(1, true);
        bytes32 record = _cnRound(2, true);
        require(
            ingress.identityRecoveryRecord(record).delegationEpoch == 4
                && ingress.currentAuthorityCapabilities(artistId).activationRecordHash == cnOrigin
                && cnCancellationCount == 2,
            "repeated class3 recovery retains original43 and exact old cancellation counts"
        );
        _cnPreservedCancellations();
    }

    function testCancelledNoticeFreshActive1FirstLivingRecoveryRemainsSeparateAbsorptionBaseline()
        public
    {
        this.cnSetup(0);
        this.cnNoticeCompromise(cnNoticeStart + 1);
        this.cnCancel(0, false);
        this.cnDismissAfterCancellation();
        this.cnCompromise(uint64(block.timestamp + 1));
        require(
            ingress.currentIdentityContestCause(artistId).facts.priorStatus == 1 && cnPrior == 0
                && cnOrigin == 0,
            "fresh actual ACTIVE1 cause uses already-supported FIRST living35 profile"
        );
        (IdentityRecovery.Request memory p, T.Authorization memory a) = this.cnRequest(0, 0);
        require(p.vestedAuthorityClass == 1, "no completed dormancy or class3 origin is fabricated");
        _cnRegister(p, a, false);
        this.rrAt(scheduled.notBefore);
        scheduled.status = GovernanceActionStatus.EXECUTED;
        _publish();
        T.Snapshot memory before_ = _ownerSnapshot();
        _cnRollback(p, a, 0);
        vm.recordLogs();
        bytes32 record = this.executeRegistered(p, a);
        _assertSnapshot(_snapshot(record), 35, before_, vm.getRecordedLogs());
        _cnReceipts(record);
        require(
            ingress.identityRecoveryRecord(record).delegationEpoch == 1
                && _snapshot(record).previousTransitionRecordHash == 0
                && _snapshot(record).previousCommitment == 0
                && ingress.currentAuthorityCapabilities(artistId).authorityClass == 1
                && _cnHistory() == cnFrozen,
            "original fresh living recovery absorbs resolved history without pretending the cancelled notice vested authority"
        );
        _cnPreservedCancellations();
    }

    function testCancelledNoticeSameTimestampDismissalsKeepExactFirstClosureAndRejectLaterSubstitution()
        public
    {
        this.cnSetup(2);
        uint64 when = cnNoticeStart + 1;
        this.cnEpisode(when);
        this.cnEpisode(when);
        bytes32 first = cnNoticeDismissals[0];
        bytes32 second = cnNoticeDismissals[1];
        require(
            first != second && ingress.identityContestDismissalRecord(first).dismissedAt == when
                && ingress.identityContestDismissalRecord(second).dismissedAt == when
                && ingress.identityTransitionClosure(artistId, cnTerminal).dismissalRecordHash
                    == first,
            "same timestamp episodes retain exact producer order and original first closure"
        );
        this.cnCancel(0, false);
        this.cnBeginNext();
        this.cnComplete();
        this.cnCompromise(cnWindow);
        (IdentityRecovery.Request memory p, T.Authorization memory a) = this.cnRequest(0, 0);
        bytes32 context = keccak256(abi.encode(ingress.identityRecoveryContext(p, a)));
        bytes32 slot = _cnSlot(
            abi.encodeCall(ingress.identityTransitionClosure, (artistId, cnBefore43)), first
        );
        _cnCorrupt(p, a, slot, second, context);
        _cnEmptyClosure(p, a, slot, context);
        (,,, bytes32 head) = ingress.guardianSet(artistId);
        _cnRegister(p, a, false);
        _cnRecover(p, a, head, true);
    }
}

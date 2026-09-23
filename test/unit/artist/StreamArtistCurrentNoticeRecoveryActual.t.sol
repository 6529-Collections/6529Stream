// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./StreamArtistDormancyRepeatedRecoveryActual.t.sol";
import {
    StreamArtistRecoveryEvidenceTypes as EV2
} from "../../../smart-contracts/interfaces/stream/artist/StreamArtistRecoveryEvidenceTypes.sol";
import {
    IStreamArtistRecoveryEvidence,
    IStreamArtistRecoveryEvidenceBinding
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistRecoveryEvidence.sol";
import {
    IStreamArtistIdentityRecoveryV2
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistIdentityRecoveryV2.sol";
import {
    IStreamArtistRecoverySelectionPreparation,
    IStreamArtistRecoverySelectionBinding
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistRecoverySelectionPreparation.sol";
import {
    StreamArtistRecoverySelectionTypesV2 as SV2
} from "../../../smart-contracts/interfaces/stream/artist/StreamArtistRecoverySelectionTypesV2.sol";
import {
    IStreamArtistDormancyOwner
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistDormancy.sol";

/// @notice Current-notice V2 recovery over original Artist owners, Safes and Archive.
/// @dev Core and action scheduling retain the inherited typed unit boundaries. Original causes,
/// vestings, guardian admissions, dismissals and receipts are produced by their actual writers.
contract StreamArtistCurrentNoticeRecoveryActualTest is
    StreamArtistDormancyRepeatedRecoveryActualTest
{
    struct Adjudication {
        IdentityRecovery.Request request;
        T.Authorization acceptance;
        EV2.ResolutionManifest manifest;
        bytes32 manifestHash;
        bytes32 expectedRole;
    }

    struct NoticeSnapshot {
        Dismissal.Cause cause;
        Dormancy27.Notice notice;
        uint8 phase;
        Dormancy27.Terminal terminal;
        T.ReplayCell cancellation;
    }
    bytes32 private nrExecution;
    bytes32 private nrRetained;
    bytes32 private nrProtected;
    bytes32 private nrActiveNotice;
    IdentityRecovery.Context private nrScheduledContext;
    uint256 private nrSalt = 121000;
    bytes32[] private nrRotations;
    bytes32[] private nrRecoveries;
    bytes32[] private nrDismissals;
    bytes32[] private nrNotices;

    function testCurrentNoticeZeroExecutionRecoveryCancelsWithAcceptedSafeAndRetry() public {
        _nrSetup();
        _nrBeginNotice();
        _nrCompromise(0);
        _nrRequireNoticeCause();
        Adjudication memory b = _nrBundle(_nrDeclarations(0, 0), _nrList(0, 0), _nrList(0, 0));
        _nrSeal(b, nrProtected);
        _nrRecover(b, nrProtected, true);
    }

    function testCurrentNoticeExecuted32NamedCausePreservesNoticeAndDeadline() public {
        _nrSetup();
        _nrRotate();
        bytes32 execution = nrExecution;
        _nrBeginNotice();
        _nrCompromise(execution);
        _nrRequireNoticeCause();
        Adjudication memory b =
            _nrBundle(_nrDeclarations(execution, 0), _nrList(0, 0), _nrList(0, 0));
        _nrSeal(b, nrProtected);
        _nrRecover(b, nrProtected, true);
        _nrEmptyClosure(execution);
    }

    function testCurrentNoticePrior35Then32HistoricalSubjectRetainsFullAncestry() public {
        _nrSetup();
        _nrCompromise(0);
        Adjudication memory first = _nrBundle(_nrDeclarations(0, 0), _nrList(0, 0), _nrList(0, 0));
        _nrSeal(first, nrProtected);
        bytes32 prior = _nrRecover(first, nrProtected, false);
        _nrRotate();
        _nrBeginNotice();
        _nrCompromise(prior);
        _nrRequireNoticeCause();
        Adjudication memory b =
            _nrBundle(_nrDeclarations(prior, nrExecution), _nrList(0, 0), _nrList(0, 0));
        _nrSeal(b, nrProtected);
        _nrRecover(b, nrProtected, true);
    }

    function testCurrentNoticeRepeatedDismissedCausesKeepOriginalNoticeJoin() public {
        _nrSetup();
        _nrRotate();
        _nrBeginNotice();
        bytes32 noticeFacts = _nrNoticeState();
        for (uint256 index; index < 2; ++index) {
            _nrCompromise(index == 0 ? nrExecution : bytes32(0));
            bytes32 cause = _nrRequireNoticeCause();
            bytes32 dismissal = _nrDismiss();
            require(
                ingress.identityContestDismissalRecord(dismissal).restoredStatus == 2
                    && _nrNoticeState() == noticeFacts,
                "actual dismissal restores pending notice without changing its deadline or terminal"
            );
            (bytes32 joined, uint8 phase, bytes32 terminal) =
                IStreamArtistDormancyOwner(suite.owners[2]).dormancyResolutionState(artistId, cause);
            require(
                joined == nrActiveNotice && phase == 1 && terminal == 0,
                "each dismissed original cause retains its own actual notice association"
            );
        }
        _nrCompromise(0);
        _nrRequireNoticeCause();
        Adjudication memory b = _nrBundle(_nrDeclarations(0, 0), _nrList(0, 0), _nrList(0, 0));
        _nrSeal(b, nrProtected);
        _nrRecover(b, nrProtected, true);
    }

    function testCurrentNoticeCancelledWhileContestedRetainsOriginalCancellationOnRecovery()
        public
    {
        _nrSetup();
        _nrBeginNotice();
        _nrCompromise(0);
        bytes32 cause = _nrRequireNoticeCause();
        _nrCancelNotice();
        bytes32 cancelled = _nrNoticeState();
        require(
            ingress.currentIdentityContestCause(artistId).causeHash == cause
                && IStreamArtistIdentityOwner(suite.owners[2]).identity(artistId).status == 4,
            "living cancellation preserves the unresolved native compromise"
        );
        Adjudication memory b = _nrBundle(_nrDeclarations(0, 0), _nrList(0, 0), _nrList(0, 0));
        _nrSeal(b, nrProtected);
        _nrRecover(b, nrProtected, true);
        require(
            _nrNoticeState() == cancelled,
            "accepted recovery updates liveness without replacing the original phase2 terminal"
        );
    }

    function testCurrentNoticeRecoveryStartsFutureNoticeAndRecoversAgain() public {
        _nrSetup();
        _nrBeginNotice();
        _nrCompromise(0);
        _nrRequireNoticeCause();
        Adjudication memory first = _nrBundle(_nrDeclarations(0, 0), _nrList(0, 0), _nrList(0, 0));
        _nrSeal(first, nrProtected);
        bytes32 recovered = _nrRecover(first, nrProtected, false);
        bytes32 oldNotice = nrActiveNotice;
        (Dormancy27.Notice memory original, uint8 phase, Dormancy27.Terminal memory terminal) =
            IStreamArtistDormancy(address(ingress)).dormancyRecord(oldNotice);
        bytes32 oldFacts = keccak256(abi.encode(original, phase, terminal));
        _nrBeginNotice();
        (Dormancy27.Notice memory fresh,,) =
            IStreamArtistDormancy(address(ingress)).dormancyRecord(nrActiveNotice);
        require(
            fresh.recordHash != oldNotice && fresh.priorActivity == original.priorActivity + 1
                && fresh.priorLivenessAt
                    == ingress.identityRecoveryRecord(recovered).fields.recoveredAt,
            "new notice uses the accepted recovery activity and exact next cancellation counter"
        );
        _nrCompromise(0);
        _nrRequireNoticeCause();
        Adjudication memory later =
            _nrBundle(_nrDeclarations(recovered, 0), _nrList(0, 0), _nrList(0, 0));
        _nrSeal(later, nrProtected);
        _nrRecover(later, nrProtected, true);
        (original, phase, terminal) =
            IStreamArtistDormancy(address(ingress)).dormancyRecord(oldNotice);
        require(
            oldFacts == keccak256(abi.encode(original, phase, terminal)),
            "subsequent notice and recovery preserve the first notice and actual cancellation"
        );
    }

    function testCurrentNoticeCancellationAfterPreparationNeedsFreshManifestAnchor() public {
        _nrSetup();
        _nrBeginNotice();
        _nrCompromise(0);
        _nrRequireNoticeCause();
        Adjudication memory b = _nrBundle(_nrDeclarations(0, 0), _nrList(0, 0), _nrList(0, 0));
        _nrSeal(b, nrProtected);
        _nrRegister(b);
        _nrCancelNotice();
        _nrExpectContextFailure(
            b, abi.encodeWithSelector(EV2.InvalidRecoveryManifest.selector, b.manifestHash)
        );
        scheduled.status = GovernanceActionStatus.CANCELLED;
        _publish();
        b.manifest.ownerRevision = _ownerSnapshot().revision;
        b.manifestHash = _nrPublishManifest(b.manifest);
        _nrSeal(b, nrProtected);
        _nrRecover(b, nrProtected, true);
    }

    function testCurrentNoticeRecoveredCauseSupportsLaterOrdinaryRecoveryWithoutNewNotice() public {
        _nrSetup();
        _nrBeginNotice();
        _nrCompromise(0);
        _nrRequireNoticeCause();
        Adjudication memory first = _nrBundle(_nrDeclarations(0, 0), _nrList(0, 0), _nrList(0, 0));
        _nrSeal(first, nrProtected);
        bytes32 prior = _nrRecover(first, nrProtected, false);
        bytes32 originalNotice = nrActiveNotice;
        bytes32 originalCancellation = _nrNoticeState();
        _nrCompromise(0);
        Dismissal.Cause memory ordinary = ingress.currentIdentityContestCause(artistId);
        (bytes32 joined,,) = IStreamArtistDormancyOwner(suite.owners[2])
            .dormancyResolutionState(artistId, ordinary.causeHash);
        require(
            ordinary.facts.priorStatus == 1 && ordinary.facts.executedTransitionHash == prior
                && joined == 0,
            "fresh ordinary33 has no fabricated current notice association"
        );
        Adjudication memory later =
            _nrBundle(_nrDeclarations(prior, 0), _nrList(0, 0), _nrList(0, 0));
        _nrSeal(later, nrProtected);
        _nrRecover(later, nrProtected, true);
        (bytes32 latest, uint8 phase,) =
            IStreamArtistDormancy(address(ingress)).dormancyNotice(artistId);
        require(
            latest == originalNotice && phase == 2 && _nrNoticeState() == originalCancellation,
            "ordinary second35 authenticates the consumed notice history without another cancellation"
        );
    }

    function testCurrentNoticeCompromiseAfterOriginalDeadlineDoesNotInventCompletion() public {
        _nrSetup();
        _nrBeginNotice();
        (Dormancy27.Notice memory original,,) =
            IStreamArtistDormancy(address(ingress)).dormancyRecord(nrActiveNotice);
        vm.warp(uint256(original.noticeEndsAt) + 1);
        (, uint8 phase, Dormancy27.Terminal memory terminal) =
            IStreamArtistDormancy(address(ingress)).dormancyRecord(nrActiveNotice);
        require(
            phase == 1 && terminal.recordHash == 0 && nrExecution == 0
                && ingress.lastArtistTransition(artistId) == 0,
            "elapsed notice deadline alone executes no43 or terminal"
        );
        _nrCompromise(0);
        bytes32 cause = _nrRequireNoticeCause();
        require(
            ingress.identityContestCause(cause).facts.enteredAt > original.noticeEndsAt,
            "real current33 is first entered after the captured deadline"
        );
        Adjudication memory b = _nrBundle(_nrDeclarations(0, 0), _nrList(0, 0), _nrList(0, 0));
        _nrSeal(b, nrProtected);
        _nrRecover(b, nrProtected, true);
        (Dormancy27.Notice memory retained,,) =
            IStreamArtistDormancy(address(ingress)).dormancyRecord(nrActiveNotice);
        require(
            keccak256(abi.encode(retained)) == keccak256(abi.encode(original))
                && _snapshot(nrExecution).previousTransitionRecordHash == 0,
            "recovery keeps the original deadline and genuine zero-execution predecessor"
        );
    }

    function testCurrentNoticeRetainedSafeVetoDoesNotCancelOrRewriteNotice() public {
        _nrSetup();
        _nrBeginNotice();
        _nrCompromise(0);
        _nrRequireNoticeCause();
        Adjudication memory b =
            _nrBundle(_nrDeclarations(0, 0), _nrList(nrProtected, 0), _nrList(nrProtected, 0));
        _nrSeal(b, nrRetained);
        _nrRegister(b);
        bytes32 notice = _nrNoticeState();
        vm.warp(scheduled.notBefore);
        this.vetoByGuardian(keccak256("retained original Safe veto of current-notice recovery"));
        require(
            _nrNoticeState() == notice,
            "guardian recovery veto is not an accepted living cancellation"
        );
        scheduled.status = GovernanceActionStatus.EXECUTED;
        _publish();
        _nrExpectExecutionFailure(
            b, abi.encodeWithSelector(A.RecoveryActionVetoed.selector, currentId)
        );
        require(
            _nrNoticeState() == notice,
            "rejected recovery leaves original notice provenance unchanged"
        );
    }

    function _nrBeginNotice() private {
        T.Identity memory principal = IStreamArtistIdentityOwner(suite.owners[2]).identity(artistId);
        (uint64 inactivity,,) =
            ingress.artistWindowInfo(keccak256("ARTIST_DORMANCY_MIN_INACTIVITY_SECONDS"));
        vm.warp(uint256(principal.lastAuthorityActionAt) + inactivity);
        Dormancy27.Initiation memory p = Dormancy27.Initiation(
            artistId,
            keccak256(abi.encode("actual current notice contact evidence", ++nrSalt)),
            "urn:current-notice:outreach"
        );
        IStreamArtistDormancy dormancy = IStreamArtistDormancy(address(ingress));
        Dormancy27.Context memory c = dormancy.dormancyInitiationContext(p);
        ArtistUnitGovernance authority = ArtistUnitGovernance(manager.governanceAuthority());
        authority.configureContestReads(
            suite.roleRegistry, address(this), p.evidenceHash, p.reasonURI
        );
        avm.mockCall(
            suite.roleRegistry,
            abi.encodeCall(
                IStreamRoleRegistry.hasRole,
                (keccak256("ROLE_ARTIST_DORMANCY_ADMIN"), address(this))
            ),
            abi.encode(true)
        );
        _nrWitness(c.scopeHash, c.oldValueHash, c.newValueHash);
        authority.executeModuleContext(
            address(ingress),
            abi.encodeCall(IStreamArtistDormancy.initiateArtistDormancy, (p)),
            1,
            c.scopeHash,
            c.oldValueHash,
            c.newValueHash
        );
        _nrInactive();
        (nrActiveNotice,,) = dormancy.dormancyNotice(artistId);
        nrNotices.push(nrActiveNotice);
        (Dormancy27.Notice memory n, uint8 phase, Dormancy27.Terminal memory terminal) =
            dormancy.dormancyRecord(nrActiveNotice);
        Dormancy27.Terminal memory empty;
        require(
            phase == 1 && n.incumbent == address(artist)
                && n.priorLivenessAt == principal.lastAuthorityActionAt
                && n.initiatedAt == block.timestamp
                && n.noticeEndsAt == n.initiatedAt + n.noticeSeconds
                && keccak256(abi.encode(terminal)) == keccak256(abi.encode(empty))
                && IStreamArtistIdentityOwner(suite.owners[2]).identity(artistId).status == 2,
            "actual41 captures original incumbent, liveness, deadline and wholly empty terminal"
        );
        require(
            n.recordHash
                == keccak256(
                    abi.encode(
                        keccak256("6529STREAM_ARTIST_DORMANCY_NOTICE_V1"),
                        block.chainid,
                        address(ingress),
                        suite.owners[2],
                        n.terms,
                        n.incumbent,
                        n.initiatedAt,
                        n.noticeEndsAt,
                        n.inactivitySeconds,
                        n.noticeSeconds,
                        n.timingRevision,
                        n.priorLivenessAt,
                        n.priorActivity,
                        n.actionId,
                        n.witnessHash
                    )
                ),
            "independent canonical original41 preimage"
        );
    }

    function _nrRequireNoticeCause() private view returns (bytes32 hash) {
        Dismissal.Cause memory c = ingress.currentIdentityContestCause(artistId);
        (bytes32 notice, uint8 phase, bytes32 terminal) = IStreamArtistDormancyOwner(
                suite.owners[2]
            ).dormancyResolutionState(artistId, c.causeHash);
        require(
            c.facts.kind == 1 && c.facts.authorityClass == 1 && c.facts.priorStatus == 2
                && c.facts.executedTransitionHash == nrExecution
                && c.facts.pendingTransitionHash == 0 && notice == nrActiveNotice && phase == 1
                && terminal == 0,
            "native current33 records priorStatus2 and exact original active notice"
        );
        return c.causeHash;
    }

    function _nrCancelNotice() private {
        require(
            executeSafe(
                artist,
                keys,
                address(ingress),
                0,
                abi.encodeCall(
                    IStreamArtistDormancy.cancelArtistDormancy,
                    (artistId, nrActiveNotice, bytes32(0))
                ),
                0
            ),
            "original incumbent Safe explicitly cancels while contested"
        );
        (, uint8 phase, Dormancy27.Terminal memory terminal) =
            IStreamArtistDormancy(address(ingress)).dormancyRecord(nrActiveNotice);
        require(
            phase == 2 && terminal.actor == address(artist) && terminal.authorityClass == 1,
            "real42 terminal remains distinct from a completion"
        );
    }

    function _nrNoticeState() private view returns (bytes32) {
        if (nrActiveNotice == 0) return 0;
        (Dormancy27.Notice memory n, uint8 phase, Dormancy27.Terminal memory terminal) =
            IStreamArtistDormancy(address(ingress)).dormancyRecord(nrActiveNotice);
        return keccak256(abi.encode(n, phase, terminal));
    }

    function _nrNoticeSnapshot(bytes32 causeHash) private view returns (NoticeSnapshot memory n) {
        n.cause = ingress.identityContestCause(causeHash);
        if (n.cause.facts.priorStatus != 2) return n;
        (bytes32 notice,,) =
            IStreamArtistDormancyOwner(suite.owners[2]).dormancyResolutionState(artistId, causeHash);
        require(notice == nrActiveNotice, "exact current cause original notice join");
        (n.notice, n.phase, n.terminal) =
            IStreamArtistDormancy(address(ingress)).dormancyRecord(notice);
        n.cancellation = IStreamArtistOwner(suite.owners[2])
            .replayCell(
                _nrReplayKey(
                    keccak256("identity_authority.replay.dormancy_cancellation_key"), notice
                )
            );
    }

    function _nrNoticeEvidence(NoticeSnapshot memory n) private pure returns (bytes memory) {
        return abi.encode(n.cause, n.notice, n.phase, n.terminal);
    }

    function _nrAssertNoticeRecovery(
        bytes32 record,
        NoticeSnapshot memory before_,
        Vm.Log[] memory logs
    ) private view {
        IdentityRecovery.Record memory recovered = ingress.identityRecoveryRecord(record);
        uint256 cancellationEvents;
        bytes32 topic =
            keccak256("ArtistDormancyCancelled(uint16,bytes32,bytes32,address,uint8,bytes32)");
        for (uint256 index; index < logs.length; ++index) {
            if (
                logs[index].emitter == suite.owners[2] && logs[index].topics.length != 0
                    && logs[index].topics[0] == topic
            ) ++cancellationEvents;
        }
        if (before_.notice.recordHash == 0) {
            require(cancellationEvents == 0, "non-notice baseline35 invents no cancellation");
            return;
        }
        NoticeSnapshot memory after_ = _nrNoticeSnapshot(before_.cause.causeHash);
        require(
            keccak256(abi.encode(before_.cause, before_.notice))
                    == keccak256(abi.encode(after_.cause, after_.notice)) && after_.phase == 2
                && IStreamArtistIdentityOwner(suite.owners[2])
                .identity(artistId)
                .lastAuthorityActionAt == recovered.fields.recoveredAt,
            "recovery keeps original33/41 and advances accepted new-side liveness"
        );
        if (before_.phase == 1) {
            Dormancy27.Terminal memory expected;
            expected.noticeHash = before_.notice.recordHash;
            expected.actor = recovered.fields.newAddress;
            expected.authorityClass = 1;
            expected.observedAt = recovered.fields.recoveredAt;
            expected.recordHash = keccak256(
                abi.encode(
                    keccak256("6529STREAM_ARTIST_DORMANCY_CANCELLATION_V1"),
                    block.chainid,
                    address(ingress),
                    suite.owners[2],
                    expected,
                    before_.notice.priorActivity + 1
                )
            );
            T.ReplayCell memory empty;
            require(
                cancellationEvents == 1
                    && keccak256(abi.encode(before_.cancellation)) == keccak256(abi.encode(empty))
                    && keccak256(abi.encode(after_.terminal)) == keccak256(abi.encode(expected))
                    && after_.cancellation.commitment == expected.recordHash
                    && after_.cancellation.kind == 1 && after_.cancellation.status == 2
                    && after_.cancellation.touchedRevision == _snapshot(record).ownerRevision,
                "accepted Safe creates exact original42, zero completion fields and same-commit replay revision"
            );
            for (uint256 index; index < logs.length; ++index) {
                Vm.Log memory item = logs[index];
                if (
                    item.emitter != suite.owners[2] || item.topics.length == 0
                        || item.topics[0] != topic
                ) continue;
                (uint16 schema, address actor, uint8 class_, bytes32 hash) =
                    abi.decode(item.data, (uint16, address, uint8, bytes32));
                require(
                    item.topics.length == 3 && item.topics[1] == artistId
                        && item.topics[2] == expected.noticeHash && schema == 1
                        && actor == expected.actor && class_ == 1 && hash == expected.recordHash,
                    "exact original cancellation event identifies the accepted new Safe"
                );
            }
        } else {
            require(
                before_.phase == 2 && cancellationEvents == 0
                    && keccak256(abi.encode(before_.terminal, before_.cancellation))
                        == keccak256(abi.encode(after_.terminal, after_.cancellation)),
                "phase2 recovery retains the actual earlier cancellation without another terminal or counter change"
            );
        }
        bytes memory payload = _operationPayload(35, manager.governanceAuthority(), record);
        (
            bytes32 domain,
            bytes memory original,
            bytes memory noticeBefore,
            bytes memory noticeAfter
        ) = abi.decode(payload, (bytes32, bytes, bytes, bytes));
        require(
            domain == keccak256("6529STREAM_ARTIST_CURRENT_NOTICE_RECOVERY_EXECUTION_V1")
                && original.length != 0
                && keccak256(noticeBefore) == keccak256(_nrNoticeEvidence(before_))
                && keccak256(noticeAfter) == keccak256(_nrNoticeEvidence(after_)),
            "original Archive outer evidence binds exact notice provenance before and after recovery"
        );
    }

    function _nrSetup() private {
        _deployAppealSuite();
        _accept();
        _payout();
        _delegateSetup();
        address[] memory members = new address[](1);
        members[0] = address(delegateSafe);
        nrRetained = _guardianRecord(members, 1, 10 days, nextNonce);
        members[0] = address(artist);
        nrProtected = _guardianRecord(members, 1, 20 days, nextNonce);
        ArtistAppealUnitRoles(suite.roleRegistry).setAppeal(address(this), true);
        R.TransitionState memory empty;
        require(
            ingress.lastArtistTransition(artistId) == 0
                && ingress.latestIdentityRecovery(artistId) == 0
                && keccak256(abi.encode(ingress.artistTransitionState(0)))
                    == keccak256(abi.encode(empty)),
            "genuinely no executed or staged predecessor"
        );
    }

    function _nrMature() private {
        if (nrExecution == 0) return;
        uint64 end = ingress.artistTransitionState(nrExecution).postWindowEndsAt;
        if (block.timestamp < end) vm.warp(end);
    }

    function _nrRotate() private {
        _nrMature();
        bytes32 previous = nrExecution;
        _newRotationSafe(++nrSalt);
        nrExecution = _stageRotation(ingress.lastArtistTransition(artistId));
        nrRotations.push(nrExecution);
        _executeTimedRotation(nrExecution);
        _adoptRotatedSafe();
        V.Snapshot memory v = _snapshot(nrExecution);
        require(
            v.operationId == 32 && v.previousTransitionRecordHash == previous
                && v.previousCommitment
                    == (previous == 0 ? bytes32(0) : _snapshot(previous).commitment),
            "actual32 snapshot follows execution, independently of staging history"
        );
    }

    function _nrWitness(bytes32 scope, bytes32 old_, bytes32 next_) private {
        address authority = manager.governanceAuthority();
        bytes32 id = keccak256("unit authority gas raise");
        avm.mockCall(
            authority,
            abi.encodeCall(IStreamGovernanceReads.currentAction, ()),
            abi.encode(true, id, uint8(1), scope, old_, next_)
        );
        (bool active, bytes32 actual, uint8 class_, bytes32 s, bytes32 o, bytes32 n) =
            IStreamGovernanceReads(authority).currentAction();
        require(
            active && actual == id && class_ == 1 && s == scope && o == old_ && n == next_,
            "exact active original producer witness"
        );
    }

    function _nrInactive() private {
        _inactive();
        (bool active, bytes32 id, uint8 class_, bytes32 s, bytes32 o, bytes32 n) =
            IStreamGovernanceReads(manager.governanceAuthority()).currentAction();
        require(
            !active && id == 0 && class_ == 0 && s == 0 && o == 0 && n == 0,
            "exact inactive action after real producer"
        );
    }

    function _nrCompromise(bytes32 subject) private {
        ArtistAppealUnitRoles(suite.roleRegistry).setArbiter(address(artist), true);
        bytes32 evidence = keccak256(abi.encode("staging family compromise", ++nrSalt));
        bytes32 reason = keccak256(abi.encode("staging family reason", evidence));
        ArtistUnitGovernance authority = ArtistUnitGovernance(manager.governanceAuthority());
        authority.configureContestReads(
            suite.roleRegistry, address(artist), reason, "urn:family:33"
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
        _nrInactive();
        Dismissal.Cause memory c = ingress.currentIdentityContestCause(artistId);
        Contest.Record memory saved = ingress.identityContestRecord(c.facts.referenceHash);
        require(
            c.facts.kind == 1 && c.facts.executedTransitionHash == nrExecution
                && saved.recordHash == c.facts.referenceHash
                && saved.terms.subjectRecordHash == subject && saved.terms.evidenceHash == evidence
                && saved.terms.reasonHash == reason && c.facts.incumbent == address(artist)
                && _operationPayload(33, manager.governanceAuthority(), saved.recordHash).length
                    != 0,
            "actual governed33 captures current execution and exact original subject"
        );
    }

    function _nrDismiss() private returns (bytes32 record) {
        Dismissal.Request memory p = _dismissalRequest();
        Dismissal.Cause memory cause = ingress.currentIdentityContestCause(artistId);
        ArtistAppealUnitRoles(suite.roleRegistry).setArbiter(address(artist), true);
        ArtistUnitGovernance(manager.governanceAuthority())
            .configureContestReads(
                suite.roleRegistry, address(artist), p.reasonHash, "urn:unit:dismissal"
            );
        Dismissal.Context memory x = ingress.identityContestDismissalContext(p);
        _nrWitness(x.scopeHash, x.oldValueHash, x.newValueHash);
        record = _dismissalExecute(p, 1, 0);
        _nrInactive();
        nrDismissals.push(record);
        Dismissal.Record memory d = ingress.identityContestDismissalRecord(record);
        require(
            d.terms.expectedCauseHash == cause.causeHash && d.recordHash == record
                && d.actionClass == 1 && d.actionId == keccak256("unit authority gas raise")
                && d.governanceWitnessHash != 0 && d.authorityClass == cause.facts.authorityClass,
            "actual dismissal retains original cause and authority"
        );
        if (cause.facts.pendingTransitionHash != 0) {
            Dismissal.Closure memory closed =
                ingress.identityTransitionClosure(artistId, cause.facts.pendingTransitionHash);
            require(
                closed.dismissalRecordHash == record && closed.abandoned
                    && closed.contestedAt == cause.facts.enteredAt,
                "actual dismissal closes captured pending cohort"
            );
        }
        if (nrExecution == 0) _nrEmptyClosure(0);
    }

    function _nrEmptyClosure(bytes32 record) private view {
        Dismissal.Closure memory empty;
        require(
            keccak256(abi.encode(ingress.identityTransitionClosure(artistId, record)))
                == keccak256(abi.encode(empty)),
            "complete original closure remains empty"
        );
    }

    function _nrReplayKey(bytes32 operation, bytes32 scope) private view returns (bytes32) {
        IStreamArtistOwner owner = IStreamArtistOwner(suite.owners[2]);
        return keccak256(
            abi.encode(
                keccak256("6529STREAM_ARTIST_OWNER_REPLAY_KEY_V2"),
                block.chainid,
                address(ingress),
                address(coordinator),
                suite.archive,
                address(owner),
                owner.domainId(),
                operation,
                scope
            )
        );
    }

    function _nrCause(bytes32 hash) private view returns (bytes32) {
        Dismissal.Cause memory c = ingress.identityContestCause(hash);
        return keccak256(abi.encode(c, ingress.identityContestRecord(c.facts.referenceHash)));
    }

    function _nrHistory() private view returns (bytes32 value) {
        for (uint256 i; i < nrRotations.length; ++i) {
            bytes32 r = nrRotations[i];
            value = keccak256(
                abi.encode(
                    value,
                    ingress.rotationRecord(r),
                    ingress.artistTransitionState(r),
                    ingress.identityTransitionClosure(artistId, r)
                )
            );
        }
        for (uint256 i; i < nrRecoveries.length; ++i) {
            bytes32 r = nrRecoveries[i];
            (bytes32 primary, bytes32 occurrence, bytes32 secondary) =
                IStreamArtistIdentityRecoveryOwner(suite.owners[2]).identityRecoveryReceipts(r);
            value = keccak256(
                abi.encode(
                    value,
                    ingress.identityRecoveryRecord(r),
                    _snapshot(r),
                    ingress.artistTransitionState(r),
                    ingress.identityTransitionClosure(artistId, r),
                    primary,
                    occurrence,
                    secondary
                )
            );
        }
        for (uint256 i; i < nrDismissals.length; ++i) {
            Dismissal.Record memory d = ingress.identityContestDismissalRecord(nrDismissals[i]);
            Dismissal.Cause memory c = ingress.identityContestCause(d.terms.expectedCauseHash);
            value = keccak256(
                abi.encode(value, d, c, ingress.identityContestRecord(c.facts.referenceHash))
            );
        }
        for (uint256 i; i < nrNotices.length; ++i) {
            (Dormancy27.Notice memory n, uint8 phase, Dormancy27.Terminal memory t) =
                IStreamArtistDormancy(address(ingress)).dormancyRecord(nrNotices[i]);
            // Current-notice35 may create its one genuine cancellation; that exact permitted
            // mutation is checked separately. Older notices retain their whole terminal state.
            value = n.recordHash == nrActiveNotice
                ? keccak256(abi.encode(value, n))
                : keccak256(abi.encode(value, n, phase, t));
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

    function _nrReceipts(bytes32 record) private view {
        IStreamArtistOwner owner = IStreamArtistOwner(suite.owners[2]);
        T.Snapshot memory s = owner.ownerStateSnapshotV2();
        uint64 sequence = uint64(uint256(vm.load(address(owner), bytes32(0))) >> 64);
        require(sequence >= 2, "two actual receipts");
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
        words[8] = bytes32(uint256(s.revision));
        words[9] = bytes32(uint256(sequence - 1));
        words[10] = bytes32(uint256(uint160(manager.governanceAuthority())));
        words[11] = 0x459749364fd07c3a8f1998b82d893d33ef0942c30d94666b42dac1e37ba5feff;
        words[12] = record;
        bytes32 primary = keccak256(abi.encode(words));
        words[9] = bytes32(uint256(sequence));
        words[11] = secondaryDomain;
        words[12] = ingress.identityRecoveryRecord(record).fields.supersededRecordsHash;
        bytes32 secondary = keccak256(abi.encode(words));
        bytes32 occurrence = keccak256(
            abi.encode(
                bytes32(0x05c1b33dc3307a69a2b02b1fdcc96323c6c2dcb072805ca38ec6462ded34ce09),
                uint16(2),
                record,
                secondaryDomain,
                words[12]
            )
        );
        (bytes32 p, bytes32 o, bytes32 x) =
            IStreamArtistIdentityRecoveryOwner(suite.owners[2]).identityRecoveryReceipts(record);
        require(
            p == primary && o == occurrence && x == secondary && p != x && p != record,
            "exact original two receipts and occurrence"
        );
    }

    function _nrRegistry() private view returns (IStreamArtistIdentityRecoveryV2) {
        return IStreamArtistIdentityRecoveryV2(address(ingress));
    }

    function _nrSelection()
        private
        view
        returns (IStreamArtistRecoverySelectionPreparation preparation)
    {
        (address target, bytes32 hash) = IStreamArtistRecoverySelectionBinding(suite.owners[2])
            .recoverySelectionPreparationBinding();
        require(target.codehash == hash && hash != 0, "fixed V2 selection helper");
        preparation = IStreamArtistRecoverySelectionPreparation(target);
    }

    function _nrSeal(Adjudication memory b, bytes32 expected) private returns (bytes32 key) {
        IStreamArtistRecoverySelectionPreparation preparation = _nrSelection();
        bytes32 roots = _roots();
        bytes32 history = _nrHistory();
        key = preparation.beginSelectionV2(b.manifestHash);
        (SV2.Basis memory basis, Selection.Progress memory progress) = preparation.selectionV2(key);
        require(
            basis.manifestHash == b.manifestHash && basis.artistId == artistId
                && basis.ownerCodeHash == suite.owners[2].codehash && basis.sourceCommitment != 0
                && basis.history.count >= 2 && progress.processed == 0 && !progress.complete,
            "explicit election starts from the complete original guardian prefix"
        );
        vm.expectRevert(
            abi.encodeWithSelector(
                Selection.IncompleteGuardianSelection.selector, key, uint64(0), basis.history.count
            )
        );
        preparation.requireSelectionV2(b.manifestHash);
        for (uint64 index = 1; index <= basis.history.count; ++index) {
            progress = preparation.continueSelectionV2(key, 1);
            require(
                progress.processed == index && progress.complete == (index == basis.history.count),
                "one original admission is processed per bounded call"
            );
        }
        Selection.Result memory result = preparation.requireSelectionV2(b.manifestHash);
        require(
            progress.complete && result.sourceKey == key && result.commitment != 0
                && result.selectedRecordHash == expected && progress.selectedRecordHash == expected
                && result.selectedDataHash
                    == (expected == 0
                            ? bytes32(0)
                            : keccak256(abi.encode(ingress.guardianSetRecord(expected))))
                && roots == _roots() && history == _nrHistory(),
            "completed election, including explicit empty selection, grants no owner mutation"
        );
        if (expected == 0) {
            require(result.selectedNonce == 0, "empty selection has no invented nonce");
        }
    }

    function _nrExpectContextFailure(Adjudication memory b, bytes memory error) private {
        bytes32 roots = _roots();
        bytes32 history = _nrHistory();
        vm.expectRevert(error);
        _nrRegistry().identityRecoveryContextV2(b.request, b.acceptance, b.manifestHash);
        (bool used,) =
            ingress.rotationAcceptanceNonceState(artistId, b.request.newAddress, b.acceptance.nonce);
        require(
            !used && roots == _roots() && history == _nrHistory(),
            "invalid evidence changes no original history, acceptance or owner root"
        );
    }

    function _nrExpectExecutionFailure(Adjudication memory b, bytes memory error) private {
        bytes32 roots = _roots();
        bytes32 history = _nrHistory();
        bytes32 evidence =
            keccak256(abi.encode(_nrRegistry().identityRecoveryEvidenceState(artistId, currentId)));
        vm.expectRevert(error);
        this.executeNoticeAdjudication(b);
        _nrInactive();
        (bool used,) =
            ingress.rotationAcceptanceNonceState(artistId, b.request.newAddress, b.acceptance.nonce);
        require(
            !used && roots == _roots() && history == _nrHistory()
                && evidence
                    == keccak256(
                        abi.encode(_nrRegistry().identityRecoveryEvidenceState(artistId, currentId))
                    ),
            "failed V2 execution preserves original history, acceptance and saved evidence"
        );
    }

    function _nrPublisher() private view returns (IStreamArtistRecoveryEvidence publisher) {
        (address target, bytes32 codeHash) =
            IStreamArtistRecoveryEvidenceBinding(suite.owners[2]).recoveryEvidenceBinding();
        require(target.codehash == codeHash && codeHash != 0, "fixed V2 evidence publisher");
        publisher = IStreamArtistRecoveryEvidence(target);
        require(
            publisher.owner() == suite.owners[2] && publisher.artistRegistry() == address(ingress)
                && publisher.deploymentChainId() == block.chainid
                && publisher.coordinator() == address(coordinator)
                && publisher.archive() == suite.archive && publisher.core() == suite.core
                && publisher.mintManager() == suite.mintManager,
            "manifest uses the original fixed suite"
        );
    }

    function _nrList(bytes32 first, bytes32 second) private pure returns (bytes32[] memory values) {
        values = new bytes32[](first == 0 ? 0 : second == 0 ? 1 : 2);
        if (first == 0) return values;
        values[0] = first;
        if (second != 0) {
            values[1] = second;
            if (first > second) (values[0], values[1]) = (second, first);
        }
    }

    function _nrDeclarations(bytes32 oldest, bytes32 newest)
        private
        pure
        returns (bytes32[] memory values)
    {
        values = new bytes32[](oldest == 0 ? 0 : newest == 0 ? 1 : 2);
        if (oldest != 0) values[0] = oldest;
        if (newest != 0) values[1] = newest;
    }

    function _nrBundle(
        bytes32[] memory declared,
        bytes32[] memory excluded,
        bytes32[] memory hostile
    ) private returns (Adjudication memory b) {
        _newRotationSafe(++nrSalt);
        Dismissal.Cause memory cause = ingress.currentIdentityContestCause(artistId);
        b.request = IdentityRecovery.Request(
            artistId,
            address(rotationSafe),
            cause.facts.authorityClass,
            cause.causeHash,
            ingress.latestIdentityContestDismissal(artistId),
            keccak256(abi.encode("V2 independent resolution evidence", ++nrSalt)),
            cause.facts.kind == 1
                ? cause.facts.reasonHash
                : keccak256("V2 standing resolution reason"),
            excluded
        );
        b.manifest = EV2.ResolutionManifest(
            artistId,
            _ownerSnapshot().revision,
            cause.causeHash,
            b.request.expectedResolutionHash,
            nrExecution,
            declared.length == 0
                ? EV2.VestingBasis.NO_CONTESTED_VESTING
                : EV2.VestingBasis.DECLARED_VESTINGS,
            Appeal27.requestCommitment(b.request),
            b.request.evidenceHash,
            new EV2.VestingReference[](declared.length),
            excluded
        );
        for (uint256 i; i < declared.length; ++i) {
            b.manifest.contestedVestings[i] =
                EV2.VestingReference(declared[i], _snapshot(declared[i]).commitment);
        }
        bytes32 roots = _roots();
        b.manifestHash = _nrPublishManifest(b.manifest);
        b.expectedRole = hostile.length == 0 ? Appeal27.ARBITER : Appeal27.APPEAL;
        if (hostile.length != 0) {
            EV2.AppealDocumentV2 memory d = EV2.AppealDocumentV2(
                b.manifestHash,
                keccak256("V2 exact hostile guardian findings"),
                new Appeal27.Finding[](hostile.length)
            );
            for (uint256 i; i < hostile.length; ++i) {
                d.findings[i] = Appeal27.Finding(
                    hostile[i], ingress.guardianSetRecord(hostile[i]).terms.guardians
                );
            }
            b.request.evidenceHash = _nrPublisher().publishAppealV2(d);
            require(
                b.request.evidenceHash
                    == keccak256(
                        abi.encode(
                            keccak256("6529STREAM_ARTIST_HOSTILE_GUARDIAN_EVIDENCE_V2"),
                            uint16(2),
                            block.chainid,
                            address(ingress),
                            suite.owners[2],
                            d
                        )
                    ),
                "literal V2 appeal document preimage"
            );
        }
        b.acceptance = _acceptance(b.request);
        require(
            roots == _roots() && b.manifest.ownerRevision == _ownerSnapshot().revision,
            "publication grants no authority and advances no owner revision"
        );
    }

    function _nrPublishManifest(EV2.ResolutionManifest memory m) private returns (bytes32 hash) {
        hash = _nrPublisher().publishResolutionManifest(m);
        require(
            hash
                == keccak256(
                    abi.encode(
                        keccak256("6529STREAM_ARTIST_RECOVERY_RESOLUTION_MANIFEST_V1"),
                        uint16(1),
                        block.chainid,
                        address(ingress),
                        suite.owners[2],
                        suite.owners[2].codehash,
                        address(coordinator),
                        suite.archive,
                        suite.core,
                        suite.mintManager,
                        m
                    )
                ),
            "literal fixed-environment manifest preimage"
        );
        (EV2.ResolutionManifest memory saved, bytes32 ownerCodeHash) =
            _nrPublisher().resolutionManifest(hash);
        require(
            keccak256(abi.encode(saved)) == keccak256(abi.encode(m))
                && ownerCodeHash == suite.owners[2].codehash,
            "exact immutable manifest readback"
        );
    }

    function _nrContext(Adjudication memory b)
        private
        view
        returns (IdentityRecovery.Context memory)
    {
        return _nrRegistry().identityRecoveryContextV2(b.request, b.acceptance, b.manifestHash);
    }

    function _nrSchedule(Adjudication memory b) private returns (GovernanceCall[] memory calls) {
        IdentityRecovery.Context memory c = _nrContext(b);
        nrScheduledContext = c;
        currentId = keccak256(abi.encode("V2 adjudication action", ++nrSalt));
        calls = new GovernanceCall[](2);
        calls[0] = GovernanceCall(
            address(0x2222),
            7,
            bytes4(0x12345678),
            keccak256("preceding V2 call"),
            keccak256("other scope"),
            keccak256("other old"),
            keccak256("other new")
        );
        calls[1] = GovernanceCall(
            address(ingress),
            0,
            IStreamArtistIdentityRecoveryV2.recoverArtistIdentityV2.selector,
            keccak256(
                abi.encodeCall(
                    IStreamArtistIdentityRecoveryV2.recoverArtistIdentityV2,
                    (b.request, b.acceptance, b.manifestHash)
                )
            ),
            c.scopeHash,
            c.oldValueHash,
            c.newValueHash
        );
        scheduled.status = GovernanceActionStatus.SCHEDULED;
        scheduled.actionClass = 2;
        scheduled.target = calls[0].target;
        scheduled.selector = calls[0].selector;
        scheduled.callHash = keccak256(
            abi.encode(
                bytes32(0x10f09566fb70f7947b61639c2a53b3aec872069a8b46edd08ba14eb2b5942b70), calls
            )
        );
        scheduled.notBefore = uint64(block.timestamp + 72 hours);
        scheduled.expiresAfter = scheduled.notBefore + 1 days;
        scheduled.proposer = b.expectedRole == Appeal27.APPEAL ? address(this) : address(artist);
        scheduled.executor = address(0);
        scheduled.canceller = address(0);
        scheduled.vetoer = address(0);
        scheduled.reasonHash = b.request.reasonHash;
        scheduled.reasonURI = "urn:unit:adjudication-v2";
        scheduled.manifestHash = keccak256("sealed unit system manifest");
        ArtistUnitGovernance(manager.governanceAuthority())
            .configureContestReads(
                suite.roleRegistry, scheduled.proposer, b.request.reasonHash, scheduled.reasonURI
            );
        _publish();
    }

    function _nrRegister(Adjudication memory b) private returns (bytes32 association) {
        GovernanceCall[] memory calls = _nrSchedule(b);
        bytes32 history = _nrHistory();
        IdentityRecovery.Context memory beforeContext = _nrContext(b);
        association = _nrRegistry()
            .registerIdentityRecoveryActionV2(
                currentId, calls, b.request, b.acceptance, b.manifestHash
            );
        EV2.EvidenceStateV2 memory e =
            _nrRegistry().identityRecoveryEvidenceState(artistId, currentId);
        require(
            association != 0 && e.associationHash == association && e.manifestHash == b.manifestHash
                && e.preparedFromOwnerRevision == b.manifest.ownerRevision
                && e.requiredRole == b.expectedRole && e.basisCommitment != 0
                && e.selectionCommitment != 0
                && _ownerSnapshot().revision == b.manifest.ownerRevision + 1
                && history == _nrHistory()
                && keccak256(abi.encode(beforeContext)) == keccak256(abi.encode(_nrContext(b))),
            "preparation saves exact anchor and manifest while keeping the executable context stable"
        );
        NoticeSnapshot memory notice = _nrNoticeSnapshot(b.request.expectedCauseHash);
        if (notice.notice.recordHash != 0) {
            bytes memory payload =
                _operationPayload(A.PREPARE_OPERATION, address(this), association);
            (bytes32 domain, bytes memory original, bytes memory facts) =
                abi.decode(payload, (bytes32, bytes, bytes));
            require(
                domain == keccak256("6529STREAM_ARTIST_CURRENT_NOTICE_RECOVERY_PREPARATION_V1")
                    && original.length != 0
                    && keccak256(facts) == keccak256(_nrNoticeEvidence(notice)),
                "preparation Archive binds the exact current33 cause and original notice state"
            );
        }
    }

    function executeNoticeAdjudication(Adjudication calldata b) external returns (bytes32 record) {
        require(msg.sender == address(this), "V2 fixture caller");
        IdentityRecovery.Context memory c = nrScheduledContext;
        address authority = manager.governanceAuthority();
        avm.mockCall(
            authority,
            abi.encodeCall(IStreamGovernanceReads.currentAction, ()),
            abi.encode(true, currentId, uint8(2), c.scopeHash, c.oldValueHash, c.newValueHash)
        );
        (bool active, bytes32 id, uint8 class_, bytes32 scope, bytes32 old_, bytes32 next_) =
            IStreamGovernanceReads(authority).currentAction();
        require(
            active && id == currentId && class_ == 2 && scope == c.scopeHash
                && old_ == c.oldValueHash && next_ == c.newValueHash,
            "exact V2 current action witness"
        );
        ArtistUnitGovernance(authority)
            .executeModuleContext(
                address(ingress),
                abi.encodeCall(
                    IStreamArtistIdentityRecoveryV2.recoverArtistIdentityV2,
                    (b.request, b.acceptance, b.manifestHash)
                ),
                2,
                c.scopeHash,
                c.oldValueHash,
                c.newValueHash
            );
        _nrInactive();
        return ingress.latestIdentityRecovery(artistId);
    }

    function _nrRecover(Adjudication memory b, bytes32 selected, bool retry)
        private
        returns (bytes32 record)
    {
        _nrRegister(b);
        return _nrFinish(b, selected, retry);
    }

    function _nrFinish(Adjudication memory b, bytes32 selected, bool retry)
        private
        returns (bytes32 record)
    {
        NoticeSnapshot memory noticeBefore = _nrNoticeSnapshot(b.request.expectedCauseHash);
        bytes32 noticeState = _nrNoticeState();
        bytes32 prior = ingress.latestIdentityRecovery(artistId);
        bytes32 oldExecution = nrExecution;
        bytes32 history = _nrHistory();
        bytes32 cause = _nrCause(b.request.expectedCauseHash);
        Estate.AuthorityCapabilities memory originalCaps =
            ingress.currentAuthorityCapabilities(artistId);
        uint64 epoch = _nrContext(b).delegationEpoch;
        bytes32 evidence =
            keccak256(abi.encode(_nrRegistry().identityRecoveryEvidenceState(artistId, currentId)));
        vm.warp(scheduled.notBefore);
        scheduled.status = GovernanceActionStatus.EXECUTED;
        _publish();
        T.Snapshot memory before_ = _ownerSnapshot();
        bytes32 roots = _roots();
        bytes32 replay = _nrReplayKey(
            keccak256("identity_authority.replay.contest_resolution"),
            keccak256(abi.encode(artistId, b.request.expectedCauseHash))
        );
        T.ReplayCell memory empty;
        require(
            keccak256(abi.encode(IStreamArtistOwner(suite.owners[2]).replayCell(replay)))
                == keccak256(abi.encode(empty)),
            "unconsumed original cause before V2 execution"
        );
        if (retry) {
            _overflow();
            this.executeNoticeAdjudication(b);
            _nrInactive();
            (bool used,) = ingress.rotationAcceptanceNonceState(
                artistId, b.request.newAddress, b.acceptance.nonce
            );
            require(
                !used && roots == _roots() && history == _nrHistory()
                    && noticeState == _nrNoticeState()
                    && cause == _nrCause(b.request.expectedCauseHash)
                    && ingress.latestIdentityRecovery(artistId) == prior
                    && evidence
                        == keccak256(
                            abi.encode(
                                _nrRegistry().identityRecoveryEvidenceState(artistId, currentId)
                            )
                        )
                    && keccak256(abi.encode(IStreamArtistOwner(suite.owners[2]).replayCell(replay)))
                    == keccak256(abi.encode(empty)),
                "late Archive failure rolls back acceptance, replay, exclusions, evidence and every original execution"
            );
            vm.roll(restoreBlock);
        }
        vm.recordLogs();
        record = this.executeNoticeAdjudication(b);
        Vm.Log[] memory logs = vm.getRecordedLogs();
        _assertSnapshot(_snapshot(record), 35, before_, logs);
        _nrReceipts(record);
        _nrAssertNoticeRecovery(record, noticeBefore, logs);
        Estate.AuthorityCapabilities memory caps = ingress.currentAuthorityCapabilities(artistId);
        (,,, bytes32 guardian) = ingress.guardianSet(artistId);
        (bool accepted,) =
            ingress.rotationAcceptanceNonceState(artistId, b.request.newAddress, b.acceptance.nonce);
        T.ReplayCell memory consumed = IStreamArtistOwner(suite.owners[2]).replayCell(replay);
        require(
            record != prior && _snapshot(record).previousTransitionRecordHash == oldExecution
                && _snapshot(record).previousCommitment
                    == (oldExecution == 0 ? bytes32(0) : _snapshot(oldExecution).commitment)
                && ingress.identityRecoveryRecord(record).delegationEpoch == epoch + 1
                && caps.authorityClass == b.request.vestedAuthorityClass
                && caps.status == b.request.vestedAuthorityClass
                && caps.authorityAddress == b.request.newAddress
                && caps.activationRecordHash == originalCaps.activationRecordHash
                && caps.effectiveCapabilities == originalCaps.effectiveCapabilities
                && guardian == selected && accepted && consumed.commitment == record
                && consumed.kind == 1 && consumed.status == 2
                && consumed.touchedRevision == before_.revision + 1 && history == _nrHistory()
                && cause == _nrCause(b.request.expectedCauseHash),
            "V2 preserves original history, installs exact selected head and advances the epoch once"
        );
        for (uint256 i; i < b.request.supersededRecordHashes.length; ++i) {
            require(
                _status(b.request.supersededRecordHashes[i]).recoveryRecordHash == record,
                "only the exact registered exclusions become permanent"
            );
        }
        roots = _roots();
        (bool ok,) = address(this).call(abi.encodeCall(this.executeNoticeAdjudication, (b)));
        _nrInactive();
        require(
            !ok && roots == _roots() && history == _nrHistory(), "consumed V2 action cannot replay"
        );
        nrRecoveries.push(record);
        nrExecution = record;
        _adoptRotatedSafe();
    }
}

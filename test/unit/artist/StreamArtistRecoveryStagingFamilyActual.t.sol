// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./StreamArtistDormancyRepeatedRecoveryActual.t.sol";
import {
    IStreamArtistDormancyOwner
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistDormancy.sol";
import {
    IStreamArtistEstateActivation
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistEstateActivation.sol";
import {
    IStreamArtistStewardSanctionGrant as SFGrant
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistStewardSanctionGrant.sol";

/// @notice Original pending32 veto/compromise producers across living and retained estate origins.
/// @dev Actual Artist owners, threshold Safes and Archive. Core and governed action scheduling
/// retain the inherited typed unit boundaries. No synthetic Contest is supplied for a veto.
contract StreamArtistRecoveryStagingFamilyActualTest is
    StreamArtistDormancyRepeatedRecoveryActualTest
{
    bytes32 private sfExecution;
    bytes32 private sfOrigin;
    bytes32 private sfRetained;
    bytes32 private sfProtected;
    uint256 private sfSalt = 101000;
    bytes32 private sfEstateEvidence;
    bytes32 private sfEstateCoverage;
    bytes32[] private sfRotations;
    bytes32[] private sfRecoveries;
    bytes32[] private sfEstates;
    bytes32[] private sfDismissals;
    bytes32[] private sfNotices;

    // Profiles: 0 first living, 1 repeated living, 2 first40, 3 repeated40,
    // 4 first43, 5 repeated43. Each case uses one appeal-capable graph from the existing fixtures.
    function _sfSetup(uint8 profile, uint32 capabilities) private {
        if (profile >= 4) {
            if (profile == 4) this.dsSetup(0);
            else this.rrStart();
            sfExecution = ingress.lastArtistTransition(artistId);
            (, GH.Entry memory lower,,) = IStreamArtistGuardianHistory(suite.owners[2])
                .guardianHistoryState(artistId, 1, address(0), 0);
            (, GH.Entry memory upper,,) = IStreamArtistGuardianHistory(suite.owners[2])
                .guardianHistoryState(artistId, 2, address(0), 0);
            sfRetained = lower.recordHash;
            sfProtected = upper.recordHash;
            sfOrigin = ingress.currentAuthorityCapabilities(artistId).activationRecordHash;
            (bytes32 notice,,) = IStreamArtistDormancy(address(ingress)).dormancyNotice(artistId);
            sfNotices.push(notice);
            bytes32 prior = ingress.latestIdentityRecovery(artistId);
            if (prior != 0) sfRecoveries.push(prior);
        } else {
            _deployAppealSuite();
            _accept();
            _payout();
            _delegateSetup();
            address[] memory members = new address[](1);
            members[0] = address(delegateSafe);
            sfRetained = _guardianRecord(members, 1, 10 days, nextNonce);
            members[0] = address(artist);
            sfProtected = _guardianRecord(members, 1, 20 days, nextNonce);
            if (profile >= 2) {
                Estate.Execution memory e = _estateActivateAndAdopt(capabilities);
                sfExecution = e.expectedActivationRecordHash;
                sfOrigin = sfExecution;
                sfEstates.push(sfExecution);
                require(_snapshot(sfExecution).operationId == 40, "actual40 origin");
            }
            if (profile == 1 || profile == 3) {
                _sfMature();
                _sfCompromise(sfExecution);
                _sfRecover(0, false, false, false);
            }
        }
        ArtistAppealUnitRoles(suite.roleRegistry).setAppeal(address(this), true);
        if (sfExecution == 0) {
            R.TransitionState memory empty;
            require(
                ingress.lastArtistTransition(artistId) == 0
                    && ingress.latestIdentityRecovery(artistId) == 0
                    && keccak256(abi.encode(ingress.artistTransitionState(0)))
                        == keccak256(abi.encode(empty)),
                "genuinely no executed or staged predecessor"
            );
        }
    }

    function _sfMature() private {
        if (sfExecution == 0) return;
        uint64 end = ingress.artistTransitionState(sfExecution).postWindowEndsAt;
        if (block.timestamp < end) vm.warp(end);
    }

    function _sfRotate() private {
        _sfMature();
        bytes32 previous = sfExecution;
        _newRotationSafe(++sfSalt);
        sfExecution = _stageRotation(ingress.lastArtistTransition(artistId));
        sfRotations.push(sfExecution);
        _executeTimedRotation(sfExecution);
        _adoptRotatedSafe();
        V.Snapshot memory v = _snapshot(sfExecution);
        require(
            v.operationId == 32 && v.previousTransitionRecordHash == previous
                && v.previousCommitment
                    == (previous == 0 ? bytes32(0) : _snapshot(previous).commitment),
            "actual32 snapshot follows execution, independently of staging history"
        );
    }

    function _sfWitness(bytes32 scope, bytes32 old_, bytes32 next_) private {
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

    function _sfInactive() private {
        _inactive();
        (bool active, bytes32 id, uint8 class_, bytes32 s, bytes32 o, bytes32 n) =
            IStreamGovernanceReads(manager.governanceAuthority()).currentAction();
        require(
            !active && id == 0 && class_ == 0 && s == 0 && o == 0 && n == 0,
            "exact inactive action after real producer"
        );
    }

    function _sfCompromise(bytes32 subject) private {
        ArtistAppealUnitRoles(suite.roleRegistry).setArbiter(address(artist), true);
        bytes32 evidence = keccak256(abi.encode("staging family compromise", ++sfSalt));
        bytes32 reason = keccak256(abi.encode("staging family reason", evidence));
        ArtistUnitGovernance authority = ArtistUnitGovernance(manager.governanceAuthority());
        authority.configureContestReads(
            suite.roleRegistry, address(artist), reason, "urn:family:33"
        );
        (bytes32 scope, bytes32 old_, bytes32 next_) =
            ingress.identityContestGovernanceContext(artistId, subject, evidence, reason);
        _sfWitness(scope, old_, next_);
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
        _sfInactive();
        Dismissal.Cause memory c = ingress.currentIdentityContestCause(artistId);
        Contest.Record memory saved = ingress.identityContestRecord(c.facts.referenceHash);
        require(
            c.facts.kind == 1 && c.facts.executedTransitionHash == sfExecution
                && saved.recordHash == c.facts.referenceHash
                && saved.terms.subjectRecordHash == subject && saved.terms.evidenceHash == evidence
                && saved.terms.reasonHash == reason && c.facts.incumbent == address(artist)
                && _operationPayload(33, manager.governanceAuthority(), saved.recordHash).length
                    != 0,
            "actual governed33 captures current execution and exact original subject"
        );
    }

    function _sfDismiss() private returns (bytes32 record) {
        Dismissal.Request memory p = _dismissalRequest();
        Dismissal.Cause memory cause = ingress.currentIdentityContestCause(artistId);
        ArtistAppealUnitRoles(suite.roleRegistry).setArbiter(address(artist), true);
        ArtistUnitGovernance(manager.governanceAuthority())
            .configureContestReads(
                suite.roleRegistry, address(artist), p.reasonHash, "urn:unit:dismissal"
            );
        Dismissal.Context memory x = ingress.identityContestDismissalContext(p);
        _sfWitness(x.scopeHash, x.oldValueHash, x.newValueHash);
        record = _dismissalExecute(p, 1, 0);
        _sfInactive();
        sfDismissals.push(record);
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
        if (sfExecution == 0) _sfEmptyClosure(0);
    }

    function _sfCloseExecution() private returns (bytes32 closureHash) {
        require(sfExecution != 0, "actual execution to close");
        _sfMature();
        _sfCompromise(sfExecution);
        bytes32 dismissal = _sfDismiss();
        R.TransitionState memory t = ingress.artistTransitionState(sfExecution);
        Dismissal.Closure memory closed = ingress.identityTransitionClosure(artistId, sfExecution);
        require(
            t.phase == 2 && t.executedAt != 0 && t.contestedAt >= t.postWindowEndsAt
                && closed.artistId == artistId && closed.transitionRecordHash == sfExecution
                && closed.dismissalRecordHash == dismissal && dismissal != 0
                && closed.windowEndsAt == t.postWindowEndsAt && closed.contestedAt == t.contestedAt
                && !closed.abandoned,
            "actual late33 dismissal creates the retained mature execution closure"
        );
        return keccak256(abi.encode(closed));
    }

    function _sfCapture(bool veto, bytes32 subject) private returns (bytes32 pending) {
        _sfMature();
        ArtistAppealUnitRoles(suite.roleRegistry).setArbiter(address(artist), true);
        _newRotationSafe(++sfSalt);
        pending = _stageRotation(ingress.lastArtistTransition(artistId));
        sfRotations.push(pending);
        bytes32 priorContest = ingress.latestIdentityContest(artistId);
        if (veto) {
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
                "actual incumbent Safe vetoes pending32 with zero reason"
            );
        } else {
            _sfCompromise(subject);
        }
        Dismissal.Cause memory c = ingress.currentIdentityContestCause(artistId);
        R.TransitionState memory t = ingress.rotationRecord(pending).transition;
        require(
            c.facts.kind == (veto ? 2 : 1) && c.facts.pendingTransitionHash == pending
                && c.facts.executedTransitionHash == sfExecution
                && c.facts.priorStatus == c.facts.authorityClass && t.phase == 3
                && t.executedAt == 0 && t.postWindowEndsAt == 0
                && t.contestedAt == c.facts.enteredAt,
            "real current cause aborts P without installing or dismissing it"
        );
        if (veto) {
            require(
                c.facts.referenceHash == pending && c.facts.evidenceHash == 0
                    && c.facts.reasonHash == 0
                    && ingress.latestIdentityContest(artistId) == priorContest,
                "C2 is original veto with no synthetic Contest"
            );
            T.ReplayCell memory cell = IStreamArtistOwner(suite.owners[2])
                .replayCell(
                    _sfReplayKey(keccak256("identity_authority.replay.rotation_veto_key"), pending)
                );
            require(
                cell.commitment == pending && cell.status == 2 && cell.kind == 1,
                "original veto replay"
            );
        }
        _sfEmptyClosure(pending);
        _missing(pending);
    }

    function _sfEmptyClosure(bytes32 record) private view {
        Dismissal.Closure memory empty;
        require(
            keccak256(abi.encode(ingress.identityTransitionClosure(artistId, record)))
                == keccak256(abi.encode(empty)),
            "complete original closure remains empty"
        );
    }

    function _sfRequest(bool exclude)
        private
        returns (IdentityRecovery.Request memory p, T.Authorization memory a)
    {
        _newRotationSafe(++sfSalt);
        Dismissal.Cause memory c = ingress.currentIdentityContestCause(artistId);
        bytes32[] memory exclusions = new bytes32[](exclude ? 1 : 0);
        if (exclude) exclusions[0] = sfProtected;
        p = IdentityRecovery.Request(
            artistId,
            address(rotationSafe),
            c.facts.authorityClass,
            c.causeHash,
            ingress.latestIdentityContestDismissal(artistId),
            c.facts.kind == 1
                ? c.facts.evidenceHash
                : keccak256("independent recovery evidence after C2"),
            c.facts.kind == 1
                ? c.facts.reasonHash
                : keccak256("independent recovery reason after C2"),
            exclusions
        );
        a = _acceptance(p);
    }

    function _sfAppeal(IdentityRecovery.Request memory p)
        private
        returns (IdentityRecovery.Request memory, T.Authorization memory)
    {
        Dismissal.Cause memory c = ingress.currentIdentityContestCause(artistId);
        Appeal27.Document memory document = Appeal27.Document(
            Appeal27.requestCommitment(p),
            c.causeHash,
            c.facts.referenceHash,
            _snapshot(sfExecution).commitment,
            sfExecution,
            keccak256("staging family original guardian findings"),
            new Appeal27.Finding[](1)
        );
        document.findings[0] =
            Appeal27.Finding(sfProtected, ingress.guardianSetRecord(sfProtected).terms.guardians);
        address child = StreamArtistIdentityAuthority(suite.owners[2]).identityRecoveryExtension();
        (address publisher, bytes32 codeHash) =
            IStreamArtistGuardianAppealBinding(child).guardianAppealEvidenceBinding();
        require(publisher.codehash == codeHash && codeHash != 0, "fixed appeal publisher");
        p.evidenceHash = IStreamArtistGuardianAppealEvidence(publisher).publish(document);
        require(
            p.evidenceHash
                == Appeal27.documentHash(
                    block.chainid, address(ingress), suite.owners[2], document
                ),
            "original published appeal commitment"
        );
        return (p, _acceptance(p));
    }

    function _sfRegister(
        IdentityRecovery.Request memory p,
        T.Authorization memory a,
        bool appeal,
        bool later
    ) private {
        GovernanceCall[] memory calls =
            _schedule(keccak256(abi.encode("family35 action", ++sfSalt)), p, a);
        if (appeal) {
            scheduled.proposer = address(this);
            ArtistUnitGovernance(manager.governanceAuthority())
                .configureContestReads(
                    suite.roleRegistry, address(this), p.reasonHash, scheduled.reasonURI
                );
        }
        // This unrelated native row is included in the original full action commitment.
        calls[0].value = 7;
        scheduled.callHash = keccak256(
            abi.encode(
                bytes32(0x10f09566fb70f7947b61639c2a53b3aec872069a8b46edd08ba14eb2b5942b70), calls
            )
        );
        _publish();
        ingress.registerIdentityRecoveryAction(currentId, calls, p, a);
        if (later) {
            bytes32 previousAction = currentId;
            (A.Association memory previous,,,) = _read();
            scheduled.status = GovernanceActionStatus.CANCELLED;
            _publish();
            currentId = keccak256(abi.encode("later family35 action", ++sfSalt));
            scheduled.status = GovernanceActionStatus.SCHEDULED;
            _publish();
            ingress.registerIdentityRecoveryAction(currentId, calls, p, a);
            (A.Association memory retained,,,) =
                ingress.identityRecoveryActionState(artistId, previousAction);
            require(
                keccak256(abi.encode(retained)) == keccak256(abi.encode(previous)),
                "later registration preserves original action"
            );
        }
        (A.Association memory bound,,,) = _read();
        require(
            bound.contextHash == keccak256(abi.encode(ingress.identityRecoveryContext(p, a))),
            "registered original context"
        );
    }

    function _sfRecover(bytes32 pending, bool appeal, bool retry, bool later)
        private
        returns (bytes32 record)
    {
        (IdentityRecovery.Request memory p, T.Authorization memory a) = _sfRequest(appeal);
        bytes32 selected;
        (,,, selected) = ingress.guardianSet(artistId);
        if (appeal) {
            (p, a) = _sfAppeal(p);
            bytes32 roots = _roots();
            bytes32 election =
                _selectionPreparation().begin(artistId, sfExecution, p.supersededRecordHashes);
            Selection.Progress memory progress =
                _selectionPreparation().continueSelection(election, 64);
            require(
                progress.complete && progress.selectedRecordHash == sfRetained && roots == _roots(),
                "actual bounded guardian election at executed cutoff"
            );
            selected = sfRetained;
        }
        return _sfExecute(p, a, pending, selected, appeal, retry, later);
    }

    function _sfExecute(
        IdentityRecovery.Request memory p,
        T.Authorization memory a,
        bytes32 pending,
        bytes32 selected,
        bool appeal,
        bool retry,
        bool later
    ) private returns (bytes32 record) {
        bytes32 oldExecution = sfExecution;
        bytes32 prior = ingress.latestIdentityRecovery(artistId);
        Estate.AuthorityCapabilities memory originalCaps =
            ingress.currentAuthorityCapabilities(artistId);
        uint64 epoch = ingress.identityRecoveryContext(p, a).delegationEpoch;
        bytes32 history = _sfHistory();
        bytes32 cause = _sfCause(p.expectedCauseHash);
        bytes32 key = _sfReplayKey(
            keccak256("identity_authority.replay.contest_resolution"),
            keccak256(abi.encode(artistId, p.expectedCauseHash))
        );
        T.ReplayCell memory empty;
        require(
            keccak256(abi.encode(IStreamArtistOwner(suite.owners[2]).replayCell(key)))
                == keccak256(abi.encode(empty)),
            "unconsumed original cause"
        );
        _sfRegister(p, a, appeal, later);
        vm.warp(scheduled.notBefore);
        scheduled.status = GovernanceActionStatus.EXECUTED;
        _publish();
        bytes32 roots = _roots();
        T.Snapshot memory before_ = _ownerSnapshot();
        if (retry) {
            _overflow();
            this.executeRegistered(p, a);
            _sfInactive();
            (bool used,) = ingress.rotationAcceptanceNonceState(artistId, p.newAddress, a.nonce);
            require(
                !used && _roots() == roots && history == _sfHistory()
                    && cause == _sfCause(p.expectedCauseHash)
                    && ingress.latestIdentityRecovery(artistId) == prior
                    && ingress.identityRecoveryContext(p, a).delegationEpoch == epoch
                    && keccak256(abi.encode(IStreamArtistOwner(suite.owners[2]).replayCell(key)))
                        == keccak256(abi.encode(empty)),
                "late Archive failure restores epoch, originals, cause replay and acceptance"
            );
            if (pending != 0) _sfEmptyClosure(pending);
            vm.roll(restoreBlock);
        }
        vm.recordLogs();
        record = this.executeRegistered(p, a);
        _sfInactive();
        V.Snapshot memory v = _snapshot(record);
        _assertSnapshot(v, 35, before_, vm.getRecordedLogs());
        _sfReceipts(record);
        Estate.AuthorityCapabilities memory caps = ingress.currentAuthorityCapabilities(artistId);
        T.ReplayCell memory consumed = IStreamArtistOwner(suite.owners[2]).replayCell(key);
        (,,, bytes32 head) = ingress.guardianSet(artistId);
        (bool accepted,) = ingress.rotationAcceptanceNonceState(artistId, p.newAddress, a.nonce);
        require(
            v.previousTransitionRecordHash == oldExecution
                && v.previousCommitment
                    == (oldExecution == 0 ? bytes32(0) : _snapshot(oldExecution).commitment)
                && ingress.identityRecoveryRecord(record).delegationEpoch == epoch + 1
                && caps.authorityClass == p.vestedAuthorityClass
                && caps.status == p.vestedAuthorityClass && caps.authorityAddress == p.newAddress
                && caps.activationRecordHash == originalCaps.activationRecordHash
                && caps.effectiveCapabilities == originalCaps.effectiveCapabilities
                && head == selected && accepted && consumed.commitment == record
                && consumed.kind == 1 && consumed.status == 2
                && consumed.touchedRevision == v.ownerRevision && history == _sfHistory()
                && cause == _sfCause(p.expectedCauseHash)
                && _operationPayload(35, manager.governanceAuthority(), record).length != 0,
            "real35 consumes exact cause once and preserves original ancestry, origin, capabilities and history"
        );
        if (pending != 0) {
            _sfEmptyClosure(pending);
            _missing(pending);
        }
        if (appeal) {
            require(
                _status(sfProtected).recoveryRecordHash == record
                    && _status(sfRetained).recoveryRecordHash == 0,
                "exact elected lifetime exclusion"
            );
        }
        roots = _roots();
        (bool ok,) = address(this).call(abi.encodeCall(this.executeRegistered, (p, a)));
        _sfInactive();
        require(
            !ok && roots == _roots() && history == _sfHistory(),
            "consumed exact action cannot replay"
        );
        sfRecoveries.push(record);
        sfExecution = record;
        _adoptRotatedSafe();
    }

    function _sfReplayKey(bytes32 operation, bytes32 scope) private view returns (bytes32) {
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

    function _sfCause(bytes32 hash) private view returns (bytes32) {
        Dismissal.Cause memory c = ingress.identityContestCause(hash);
        return keccak256(abi.encode(c, ingress.identityContestRecord(c.facts.referenceHash)));
    }

    function _sfHistory() private view returns (bytes32 value) {
        if (sfOrigin != 0) {
            value = keccak256(
                abi.encode(
                    sfOrigin,
                    _snapshot(sfOrigin),
                    ingress.artistTransitionState(sfOrigin),
                    ingress.identityTransitionClosure(artistId, sfOrigin)
                )
            );
        }
        for (uint256 i; i < sfRotations.length; ++i) {
            bytes32 r = sfRotations[i];
            value = keccak256(
                abi.encode(
                    value,
                    ingress.rotationRecord(r),
                    ingress.artistTransitionState(r),
                    ingress.identityTransitionClosure(artistId, r)
                )
            );
        }
        for (uint256 i; i < sfRecoveries.length; ++i) {
            bytes32 r = sfRecoveries[i];
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
        for (uint256 i; i < sfEstates.length; ++i) {
            (Estate.RequestRecord memory r, uint8 phase, Estate.ExecutionFacts memory e) =
                ingress.estateActivationRecord(sfEstates[i]);
            value = keccak256(
                abi.encode(
                    value,
                    r,
                    phase,
                    e,
                    ingress.artistTransitionState(r.recordHash),
                    ingress.identityTransitionClosure(artistId, r.recordHash)
                )
            );
        }
        for (uint256 i; i < sfDismissals.length; ++i) {
            Dismissal.Record memory d = ingress.identityContestDismissalRecord(sfDismissals[i]);
            Dismissal.Cause memory c = ingress.identityContestCause(d.terms.expectedCauseHash);
            value = keccak256(
                abi.encode(value, d, c, ingress.identityContestRecord(c.facts.referenceHash))
            );
        }
        for (uint256 i; i < sfNotices.length; ++i) {
            (Dormancy27.Notice memory n, uint8 phase, Dormancy27.Terminal memory t) =
                IStreamArtistDormancy(address(ingress)).dormancyRecord(sfNotices[i]);
            value = keccak256(abi.encode(value, n, phase, t));
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

    // Literal original owner receipt and occurrence domains, independent of new reader proofs.
    function _sfReceipts(bytes32 record) private view {
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

    function _sfCancelledNotice() private {
        _sfMature();
        bytes32 notice = this.rrBeginBoundaryDormancy();
        sfNotices.push(notice);
        _sfCompromise(sfExecution);
        bytes32 cause = ingress.currentIdentityContestCause(artistId).causeHash;
        bytes32 dismissal = _sfDismiss();
        require(
            ingress.identityContestDismissalRecord(dismissal).restoredStatus == 2,
            "original D2 before cancellation"
        );
        require(
            executeSafe(
                artist,
                keys,
                address(ingress),
                0,
                abi.encodeCall(
                    IStreamArtistDormancy.cancelArtistDormancy, (artistId, notice, bytes32(0))
                ),
                0
            ),
            "actual original notice cancellation"
        );
        (Dormancy27.Notice memory n, uint8 phase, Dormancy27.Terminal memory t) =
            IStreamArtistDormancy(address(ingress)).dormancyRecord(notice);
        (bytes32 joined, uint8 resolved, bytes32 terminal) =
            IStreamArtistDormancyOwner(suite.owners[2]).dormancyResolutionState(artistId, cause);
        Dormancy27.Terminal memory preimage;
        preimage.noticeHash = notice;
        preimage.actor = address(artist);
        preimage.authorityClass = 1;
        preimage.observedAt = uint64(block.timestamp);
        require(
            phase == 2 && joined == notice && resolved == 2 && terminal == t.recordHash
                && t.recordHash
                    == keccak256(
                        abi.encode(
                            keccak256("6529STREAM_ARTIST_DORMANCY_CANCELLATION_V1"),
                            block.chainid,
                            address(ingress),
                            suite.owners[2],
                            preimage,
                            n.priorActivity + 1
                        )
                    ),
            "actual cancelled notice and original status2 cause retain exact counter preimage"
        );
    }

    function _sfEstateRequest() private returns (bytes32 estate) {
        _sfMature();
        bytes32 designation = _successionRecord(_successorTerms(address(delegateSafe), 2));
        // Reuse the actual immutable archival evidence; its family/envelope writers reject
        // duplicate publication. Each new request uses the original successor nonce lane.
        if (sfEstateEvidence == 0) {
            (sfEstateEvidence, sfEstateCoverage) = _estateArchiveEvidence(artistId);
        }
        Estate.Request memory request = Estate.Request(
            artistId, address(delegateSafe), sfEstateEvidence, designation, sfEstateCoverage
        );
        T.Authorization memory authorization = T.Authorization(
            ingress.estateActivationNonceHint(artistId, address(delegateSafe)),
            uint64(block.timestamp + 1 days),
            ""
        );
        require(
            executeSafe(
                delegateSafe,
                delegateKeys,
                address(ingress),
                0,
                abi.encodeCall(
                    IStreamArtistEstateActivation.requestEstateActivation, (request, authorization)
                ),
                0
            ),
            "actual successor Safe request with current nonce"
        );
        (,, estate) = ingress.estateActivationState(artistId);
        sfEstates.push(estate);
    }

    // method 0 explicit39, 1 signed living19, 2 actual33 then dismissal. Each keeps S as staging head.
    function _sfCancelledEstate(uint8 method) private returns (bytes32 estate) {
        estate = _sfEstateRequest();
        (Estate.RequestRecord memory original,,) = ingress.estateActivationRecord(estate);
        T.Snapshot memory before_ = _ownerSnapshot();
        vm.recordLogs();
        if (method == 0) {
            require(
                executeSafe(
                    artist,
                    keys,
                    address(ingress),
                    0,
                    abi.encodeCall(
                        IStreamArtistEstateActivation.cancelEstateActivation, (artistId, estate)
                    ),
                    0
                ),
                "actual explicit39 cancellation"
            );
        } else if (method == 1) {
            SFGrant.Grant memory p = SFGrant.Grant(
                artistId, true, keccak256(abi.encode("estate cancellation signed19", estate))
            );
            T.Authorization memory a = _authorization(true);
            a.signature = _signature(SFGrant(address(ingress)).stewardSanctionGrantDigest(p, a));
            bytes32 record = SFGrant(address(ingress)).recordStewardSanctionGrant(p, a);
            require(
                _operationPayload(19, address(this), record).length != 0,
                "actual original signed19 Archive row"
            );
        } else {
            _sfCompromise(estate);
        }
        _assertEstateCancellationEvent(vm.getRecordedLogs(), estate, method == 2 ? 0 : 1);
        (Estate.RequestRecord memory saved, uint8 phase, Estate.ExecutionFacts memory execution) =
            ingress.estateActivationRecord(estate);
        R.TransitionState memory t = ingress.artistTransitionState(estate);
        T.ReplayCell memory cell = IStreamArtistOwner(suite.owners[2])
            .replayCell(
                _sfReplayKey(
                    keccak256("identity_authority.replay.activation_cancellation_key"), estate
                )
            );
        require(
            keccak256(abi.encode(original)) == keccak256(abi.encode(saved)) && phase == 3
                && t.phase == 3 && t.executedAt == 0 && t.postWindowEndsAt == 0
                && execution.executedAt == 0 && ingress.lastArtistTransition(artistId) == estate
                && cell.status == 2 && cell.commitment == estate
                && cell.touchedRevision == before_.revision + 1
                && _ownerSnapshot().revision == before_.revision + 1
                && t.contestedAt == (method == 2 ? uint64(block.timestamp) : uint64(0)),
            "original cancelled S has one exact mutation/replay revision and no synthesized40"
        );
        _missing(estate);
        if (method == 2) _sfDismiss();
    }

    function testStagingFamilyFirstLivingZeroExecutionC1ArchiveRetryAndNoPendingCutoff() public {
        _sfSetup(0, 0);
        bytes32 pending = _sfCapture(false, 0);
        (IdentityRecovery.Request memory excluded, T.Authorization memory a) = _sfRequest(true);
        (bool ok,) = address(ingress)
            .staticcall(abi.encodeCall(ingress.identityRecoveryContext, (excluded, a)));
        require(
            !ok && sfExecution == 0,
            "nonempty supersession cannot use unexecuted P as vested cutoff"
        );
        _sfRecover(pending, false, true, true);
    }

    function testStagingFamilyFirstLivingZeroExecutionC2OriginalZeroReason() public {
        _sfSetup(0, 0);
        bytes32 estate = _sfCancelledEstate(0);
        bytes32 pending = _sfCapture(true, 0);
        require(
            ingress.rotationRecord(pending).terms.expectedPreviousTransitionRecordHash == estate,
            "first35 zero-execution staging predecessor is actual cancelled S"
        );
        _sfRecover(pending, false, true, false);
    }

    function testStagingFamilyFirstLiving32ExecutionC1ZeroSubject() public {
        _sfSetup(0, 0);
        _sfRotate();
        bytes32 estate = _sfEstateRequest();
        bytes32 pending = _sfCapture(false, 0);
        T.ReplayCell memory cancellation = IStreamArtistOwner(suite.owners[2])
            .replayCell(
                _sfReplayKey(
                    keccak256("identity_authority.replay.activation_cancellation_key"), estate
                )
            );
        T.ReplayCell memory stage = IStreamArtistOwner(suite.owners[2])
            .replayCell(
                _sfReplayKey(
                    keccak256("identity_authority.replay.rotation_key"),
                    keccak256(abi.encode(artistId, pending))
                )
            );
        (, uint8 phase, Estate.ExecutionFacts memory execution) =
            ingress.estateActivationRecord(estate);
        require(
            phase == 3 && execution.executedAt == 0
                && ingress.rotationRecord(pending).terms.expectedPreviousTransitionRecordHash
                    == estate && cancellation.status == 2 && cancellation.commitment == estate
                && stage.status == 2 && stage.commitment == pending
                && cancellation.touchedRevision == stage.touchedRevision,
            "actual stage29 living action cancels S in the same revision and preserves its staging guard"
        );
        _sfRecover(pending, false, true, false);
    }

    function testStagingFamilyFirstLiving32ExecutionC2() public {
        _sfSetup(0, 0);
        _sfRotate();
        _sfRecover(_sfCapture(true, 0), false, true, false);
    }

    function testStagingFamilyFirst40ZeroCapabilitiesC1OriginalGuardianAppeal() public {
        _sfSetup(2, 0);
        _sfRecover(_sfCapture(false, sfExecution), true, true, false);
    }

    function testStagingFamilyFirst40RotationC2() public {
        _sfSetup(2, 4095);
        bytes32 closed = _sfCloseExecution();
        _sfRotate();
        _sfRecover(_sfCapture(true, 0), false, true, false);
        require(
            keccak256(abi.encode(ingress.identityTransitionClosure(artistId, sfOrigin))) == closed,
            "original40 closure retains its first dismissal"
        );
    }

    function testStagingFamilyRepeated40C1AndLaterRegisteredNativeRows() public {
        _sfSetup(3, 4095);
        bytes32 prior = sfExecution;
        bytes32 closed = _sfCloseExecution();
        _sfRecover(_sfCapture(false, 0), false, true, true);
        require(
            keccak256(abi.encode(ingress.identityTransitionClosure(artistId, prior))) == closed,
            "original35 closure retains its first dismissal"
        );
    }

    function testStagingFamilyRepeated40ZeroCapabilitiesRotationC2() public {
        _sfSetup(3, 0);
        _sfRotate();
        _sfRecover(_sfCapture(true, 0), false, true, false);
    }

    function testStagingFamilyFirst43C1OriginalGuardianAppeal() public {
        _sfSetup(4, 0);
        _sfRecover(_sfCapture(false, sfExecution), true, true, false);
    }

    function testStagingFamilyFirst43RotationC2() public {
        _sfSetup(4, 0);
        bytes32 closed = _sfCloseExecution();
        _sfRotate();
        _sfRecover(_sfCapture(true, 0), false, true, false);
        require(
            keccak256(abi.encode(ingress.identityTransitionClosure(artistId, sfOrigin))) == closed,
            "original43 closure retains its first dismissal"
        );
    }

    function testStagingFamilyRepeated43C1() public {
        _sfSetup(5, 0);
        _sfRecover(_sfCapture(false, 0), false, true, false);
    }

    function testStagingFamilyRepeated43RotationC2() public {
        _sfSetup(5, 0);
        _sfRotate();
        _sfRecover(_sfCapture(true, 0), false, true, false);
    }

    function testStagingFamilyZeroExecutionDismissedPendingCancelledNoticeThenCurrentC1() public {
        _sfSetup(0, 0);
        _sfCapture(true, 0);
        _sfDismiss();
        _sfCancelledNotice();
        _sfRecover(_sfCapture(false, 0), false, true, false);
    }

    function testStagingFamily32DismissedPendingCancelledNoticeThenCurrentC2() public {
        _sfSetup(0, 0);
        _sfRotate();
        _sfCapture(false, sfExecution);
        _sfDismiss();
        _sfCancelledNotice();
        _sfRecover(_sfCapture(true, 0), false, true, false);
    }

    function testStagingFamilyCancelledEstateAllOriginalProducersAcrossZero32AndRepeated35()
        public
    {
        _sfSetup(0, 0);
        bytes32 estate = _sfCancelledEstate(0);
        bytes32 pending = _sfCapture(false, 0);
        require(
            ingress.rotationRecord(pending).terms.expectedPreviousTransitionRecordHash == estate,
            "zero-execution P follows actual cancelled S"
        );
        _sfDismiss();
        _sfCompromise(0);
        Dismissal.Cause memory fresh = ingress.currentIdentityContestCause(artistId);
        require(
            sfExecution == 0 && ingress.latestIdentityRecovery(artistId) == 0
                && ingress.lastArtistTransition(artistId) == pending
                && fresh.facts.executedTransitionHash == 0
                && fresh.facts.pendingTransitionHash == 0,
            "fresh actual33 has no current P or execution while retaining dismissed staging history"
        );
        _sfRecover(0, false, true, false);
        _sfRotate();
        estate = _sfCancelledEstate(1);
        pending = _sfCapture(true, 0);
        require(
            ingress.rotationRecord(pending).terms.expectedPreviousTransitionRecordHash == estate,
            "actual32 P follows signed-activity cancelled S"
        );
        _sfRecover(pending, false, true, false);
        estate = _sfCancelledEstate(2);
        pending = _sfCapture(false, sfExecution);
        require(
            ingress.rotationRecord(pending).terms.expectedPreviousTransitionRecordHash == estate,
            "repeated35 P follows actual33 cancelled S"
        );
        _sfRecover(pending, false, true, false);
    }

    function _sfSlot(bytes memory getter, bytes32 expected) private returns (bytes32 slot) {
        RepeatedDormancyStorageVm probe = RepeatedDormancyStorageVm(address(vm));
        probe.record();
        (bool ok,) = suite.owners[2].staticcall(getter);
        require(ok, "healthy original fixed-owner getter");
        (bytes32[] memory reads,) = probe.accesses(suite.owners[2]);
        uint256 count;
        for (uint256 i; i < reads.length; ++i) {
            if (vm.load(suite.owners[2], reads[i]) == expected) {
                slot = reads[i];
                ++count;
            }
        }
        require(expected != 0 && count == 1, "one exact observed source field");
    }

    function _sfCorrupt(
        IdentityRecovery.Request memory p,
        T.Authorization memory a,
        bytes32 slot,
        bytes32 replacement,
        bytes32 context
    ) private {
        bytes32 original = vm.load(suite.owners[2], slot);
        require(original != replacement, "source mutation changes bytes");
        bytes32 roots = _roots();
        bytes32 history = _sfHistory();
        vm.store(suite.owners[2], slot, replacement);
        (bool ok,) =
            address(ingress).staticcall(abi.encodeCall(ingress.identityRecoveryContext, (p, a)));
        (bool used,) = ingress.rotationAcceptanceNonceState(artistId, p.newAddress, a.nonce);
        require(
            !ok && !used && _roots() == roots,
            "malformed original facts fail before acceptance or owner mutation"
        );
        vm.store(suite.owners[2], slot, original);
        require(
            history == _sfHistory()
                && context == keccak256(abi.encode(ingress.identityRecoveryContext(p, a))),
            "exact source restore admits identical original request"
        );
    }

    function _sfEmptyClosureSlot(bytes32 pending) private returns (bytes32 slot) {
        RepeatedDormancyStorageVm probe = RepeatedDormancyStorageVm(address(vm));
        bytes memory getter = abi.encodeCall(ingress.identityTransitionClosure, (artistId, pending));
        probe.record();
        (bool ok,) = suite.owners[2].staticcall(getter);
        require(ok, "actual empty closure getter");
        (bytes32[] memory reads,) = probe.accesses(suite.owners[2]);
        bytes32 sentinel = keccak256("staging family empty closure probe");
        uint256 count;
        for (uint256 i; i < reads.length; ++i) {
            if (vm.load(suite.owners[2], reads[i]) != 0) continue;
            vm.store(suite.owners[2], reads[i], sentinel);
            (bool healthy, bytes memory raw) = suite.owners[2].staticcall(getter);
            vm.store(suite.owners[2], reads[i], 0);
            if (healthy && raw.length == 192) {
                Dismissal.Closure memory c = abi.decode(raw, (Dismissal.Closure));
                if (
                    c.artistId == sentinel && c.transitionRecordHash == 0
                        && c.dismissalRecordHash == 0 && c.windowEndsAt == 0 && c.contestedAt == 0
                        && !c.abandoned
                ) {
                    slot = reads[i];
                    ++count;
                }
            }
        }
        require(count == 1, "one discriminated original empty closure field");
        _sfEmptyClosure(pending);
    }

    function testStagingFamilyOriginalSourcesRejectTamperingAndExactRestoreRetriesC1AndC2() public {
        _sfSetup(0, 0);
        _sfRotate();
        bytes32 estate = _sfCancelledEstate(0);
        bytes32 pending = _sfCapture(false, 0);
        (IdentityRecovery.Request memory p, T.Authorization memory a) = _sfRequest(false);
        bytes32 context = keccak256(abi.encode(ingress.identityRecoveryContext(p, a)));
        bytes memory getter = abi.encodeCall(ingress.rotationRecord, (pending));
        // The producer's staging guard is outside the signed32 digest. It still must name S,
        // never skip that original unexecuted request to reach the earlier executed32.
        _sfCorrupt(p, a, _sfSlot(getter, estate), sfExecution, context);
        R.RotationRecord memory r = ingress.rotationRecord(pending);
        _sfCorrupt(p, a, _sfSlot(getter, r.guardianSetRecordHash), 0, context);
        bytes32 marker = bytes32(uint256(r.transition.contestedAt) | (uint256(3) << 64));
        _sfCorrupt(p, a, _sfSlot(getter, marker), bytes32(uint256(2) << 64), context);
        _sfCorrupt(p, a, _sfEmptyClosureSlot(pending), artistId, context);
        _sfCorrupt(p, a, _sfEmptyClosureSlot(0), artistId, context);
        _sfEmptyClosure(0);
        Dismissal.Cause memory c = ingress.currentIdentityContestCause(artistId);
        _sfCorrupt(
            p,
            a,
            _sfSlot(abi.encodeCall(ingress.identityContestCause, (c.causeHash)), pending),
            estate,
            context
        );
        _sfCorrupt(
            p,
            a,
            _sfSlot(
                abi.encodeCall(ingress.identityContestRecord, (c.facts.referenceHash)), pending
            ),
            estate,
            context
        );
        bytes32 cancelKey = _sfReplayKey(
            keccak256("identity_authority.replay.activation_cancellation_key"), estate
        );
        _sfCorrupt(
            p,
            a,
            _sfSlot(abi.encodeCall(IStreamArtistOwner.replayCell, (cancelKey)), estate),
            0,
            context
        );
        (,,, bytes32 selected) = ingress.guardianSet(artistId);
        _sfExecute(p, a, pending, selected, false, true, false);

        pending = _sfCapture(true, 0);
        (p, a) = _sfRequest(false);
        context = keccak256(abi.encode(ingress.identityRecoveryContext(p, a)));
        bytes32 vetoKey =
            _sfReplayKey(keccak256("identity_authority.replay.rotation_veto_key"), pending);
        _sfCorrupt(
            p,
            a,
            _sfSlot(abi.encodeCall(IStreamArtistOwner.replayCell, (vetoKey)), pending),
            0,
            context
        );
        _sfExecute(p, a, pending, selected, false, true, false);
    }

    function _sfCurrentEstateRecovery(bytes32 subject) private {
        bytes32 estate = _sfEstateRequest();
        bytes32 resolution = ingress.latestIdentityContestDismissal(artistId);
        _sfCompromise(subject == 0 ? estate : subject);
        Dismissal.Cause memory c = ingress.currentIdentityContestCause(artistId);
        Contest.Record memory contest = ingress.identityContestRecord(c.facts.referenceHash);
        (, uint8 phase, Estate.ExecutionFacts memory execution) =
            ingress.estateActivationRecord(estate);
        R.RotationRecord memory empty;
        require(
            c.facts.pendingTransitionHash == estate && c.facts.executedTransitionHash == sfExecution
                && contest.pendingTransitionRecordHash == estate && phase == 3
                && execution.executedAt == 0
                && ingress.artistTransitionState(estate).contestedAt == c.facts.enteredAt
                && ingress.latestIdentityContestDismissal(artistId) == resolution
                && keccak256(abi.encode(ingress.rotationRecord(estate)))
                    == keccak256(abi.encode(empty)),
            "actual current33 cancels original S without a dismissal or invented rotation"
        );
        _sfRecover(estate, false, true, false);
        require(
            ingress.latestIdentityContestDismissal(artistId) == resolution,
            "direct35 consumes current estate compromise without manufacturing a dismissal"
        );
    }

    function testStagingFamilyCurrentEstateCompromiseRecoversDirectlyAtZero32AndRepeated35()
        public
    {
        _sfSetup(0, 0);
        _sfCurrentEstateRecovery(0);
        _sfRotate();
        _sfCurrentEstateRecovery(sfExecution);
        _sfCurrentEstateRecovery(sfExecution);
        require(
            ingress.identityRecoveryRecord(sfExecution).delegationEpoch == 3,
            "three real direct recoveries preserve current S episodes across zero,32 and35 heads"
        );
    }

    function testStagingFamilyOriginal40AfterLiving35Then32AndCurrentPending() public {
        _sfSetup(1, 0);
        bytes32 living = ingress.latestIdentityRecovery(artistId);
        address[] memory members = new address[](1);
        members[0] = address(delegateSafe);
        bytes32 guardian = _guardianRecord(members, 1, 10 days, nextNonce + 1000);
        R.GuardianRecord memory saved = ingress.guardianSetRecord(guardian);
        uint64 window = ingress.artistTransitionState(living).postWindowEndsAt;
        require(
            saved.authorityClass == 1 && saved.signer == address(artist)
                && saved.provisional.transitionRecordHash == living
                && saved.provisional.windowEndsAt == window && saved.signedAt < window,
            "real living guardian is installed during the original35 provisional window"
        );
        _sfMature();
        (,,, bytes32 operative) = ingress.guardianSet(artistId);
        require(operative == guardian, "original35 guardian matures before40 request");
        Estate.Execution memory e = _estateActivateAndAdopt(0);
        sfOrigin = e.expectedActivationRecordHash;
        sfExecution = sfOrigin;
        sfEstates.push(sfOrigin);
        require(
            _snapshot(sfOrigin).operationId == 40
                && _snapshot(sfOrigin).previousTransitionRecordHash == living
                && ingress.latestIdentityRecovery(artistId) == living,
            "actual40 crosses from original latest living35 with zero successor capabilities"
        );
        _sfRotate();
        bytes32 pending = _sfCapture(false, living);
        _sfRecover(pending, false, true, false);
        (,,, operative) = ingress.guardianSet(artistId);
        require(
            ingress.identityRecoveryRecord(sfExecution).fields.vestedAuthorityClass == 3
                && ingress.currentAuthorityCapabilities(artistId).activationRecordHash == sfOrigin
                && operative == guardian
                && keccak256(abi.encode(ingress.guardianSetRecord(guardian)))
                    == keccak256(abi.encode(saved)),
            "recovery keeps original40 origin while ancestry reaches the real living35 root"
        );
    }
}

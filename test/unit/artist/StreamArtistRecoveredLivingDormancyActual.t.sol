// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./StreamArtistDormancyRepeatedRecoveryActual.t.sol";

/// @notice Actual recovered living authority -> designated dormancy -> elected successor recovery.
/// @dev Reuses one Artist/Safe/Archive graph. Governance scheduling and Core remain the inherited
/// typed unit boundaries; historical records and owner mutations are real. No class4 or hydration.
contract StreamArtistRecoveredLivingDormancyActualTest is
    StreamArtistDormancyRepeatedRecoveryActualTest
{
    bytes32 private g3Origin;
    bytes32 private g3Notice;
    bytes32 private g3Terminal;
    bytes32 private g3Prior;
    bytes32 private g3Designation;
    bytes32 private g3Protected;
    bytes32 private g3Retained;
    bytes32 private g3Abandoned;
    bytes32 private g3Frozen;
    bytes32 private g3Election;
    address private g3ProtectedParty;
    uint64 private g3Window;
    uint32 private g3Mask;
    uint256 private g3Salt = 83000;
    bytes32[] private g3Recoveries;
    bytes32[] private g3Rotations;
    bytes32[] private g3Excluded;
    bytes32[] private g3Dismissals;

    modifier g3Self() {
        require(msg.sender == address(this), "recovered living fixture caller");
        _;
    }

    // oldClosure: 0 none, 1 early compromise/dismissal, 2 mature standing veto/dismissal.
    function g3Setup(uint8 oldClosure, bool earlierAssociation) external g3Self {
        _g3Setup(oldClosure, earlierAssociation, 0, 0);
    }

    function g3SetupWithLivingRotations() external g3Self {
        _g3Setup(2, false, 2, 2);
    }

    function _g3Setup(
        uint8 oldClosure,
        bool earlierAssociation,
        uint8 livingRotations,
        uint8 laterDismissals
    ) private {
        _deployAppealSuite();
        _accept();
        _payout();
        this.testActualRecoverySnapshotSharesOneRevisionAndTwoReceiptsWithArchiveRetry();
        g3Prior = ingress.latestIdentityRecovery(artistId);
        _g3Receipts(g3Prior);
        g3Recoveries.push(g3Prior);
        g3Terminal = g3Prior;
        g3Window = ingress.artistTransitionState(g3Prior).postWindowEndsAt;
        require(
            _snapshot(g3Prior).operationId == 35 && _snapshot(g3Prior).authorityClass == 1,
            "actual living35 predecessor"
        );
        _adoptRotatedSafe();
        if (oldClosure == 1) {
            g3Abandoned = this.rrGuardian(address(artist), 25 days, 500);
            this.g3Compromise(g3Window - 1);
            this.g3Dismiss();
        } else if (oldClosure == 2) {
            this.g3Standing();
        }
        bytes32 firstClosure = _g3Closure(g3Prior);
        for (uint256 i; i < laterDismissals; ++i) {
            this.g3Compromise(uint64(block.timestamp + 1));
            this.g3Dismiss();
            require(
                _g3Closure(g3Prior) == firstClosure,
                "later pre-notice episodes retain the original standing closure"
            );
        }
        g3ProtectedParty = address(artist);
        g3Retained = this.rrGuardian(address(delegateSafe), 10 days, 900);
        g3Protected = this.rrGuardian(g3ProtectedParty, 20 days, 1000);
        _newRotationSafe(++g3Salt);
        OfficialSafe designated = rotationSafe;
        uint256[] memory designatedKeys = rotationKeys;
        Succ27.Designation memory plan = _successorTerms(address(designated), 2);
        plan.grantedCapabilities = 256;
        g3Designation = _successionRecord(plan);
        R.ProvisionalAssociation memory association =
        ingress.successorDesignationRecord(g3Designation).provisional;
        require(
            association.transitionRecordHash == (oldClosure == 0 ? g3Prior : bytes32(0)),
            "actual designation binds living35 or its admitted closure, never a synthetic rotation"
        );
        if (earlierAssociation) {
            require(oldClosure == 0, "bounded earlier-association fixture");
            bytes32 first = g3Prior;
            _g3Round(0, false);
            require(
                g3Prior != first && _snapshot(g3Prior).authorityClass == 1
                    && ingress.successorDesignationRecord(g3Designation).provisional
                            .transitionRecordHash == first
                    && ingress.guardianSetRecord(g3Protected).provisional.transitionRecordHash
                    == first,
                "another real living35 retains the earlier35 designation and guardian associations"
            );
        }
        bytes32 stagedPredecessor = ingress.lastArtistTransition(artistId);
        for (uint256 i; i < livingRotations; ++i) {
            this.g3Rotate();
            require(
                _snapshot(g3Terminal).authorityClass == 1, "actual pre-notice rotation stays living"
            );
            if (i == 0) {
                require(
                    ingress.rotationRecord(g3Terminal).terms.expectedPreviousTransitionRecordHash
                            == stagedPredecessor
                        && _snapshot(g3Terminal).previousTransitionRecordHash == g3Prior,
                    "abandoned staging predecessor is separate from the executed living35 parent"
                );
            }
        }
        bytes32 previousExecution = g3Terminal;
        rotationSafe = designated;
        rotationKeys = designatedKeys;
        g3Notice = this.rrBeginBoundaryDormancy();
        this.rrCompleteBoundaryDormancy(g3Notice);
        Estate.AuthorityCapabilities memory caps = ingress.currentAuthorityCapabilities(artistId);
        g3Origin = caps.activationRecordHash;
        g3Terminal = g3Origin;
        g3Mask = caps.effectiveCapabilities;
        g3Window = ingress.artistTransitionState(g3Origin).postWindowEndsAt;
        (,, Dormancy27.Terminal memory terminal) =
            IStreamArtistDormancy(address(ingress)).dormancyRecord(g3Notice);
        require(
            caps.authorityClass == 3 && caps.status == 3 && caps.authorityAddress == address(artist)
                && g3Mask == 256 && terminal.plan.designation == g3Designation
                && terminal.delegationEpoch
                    == ingress.identityRecoveryRecord(g3Prior).delegationEpoch + 1
                && ingress.latestIdentityRecovery(artistId) == g3Prior
                && _snapshot(g3Origin).previousTransitionRecordHash == previousExecution
                && _snapshot(g3Origin).previousCommitment
                    == _snapshot(previousExecution).commitment,
            "actual43 retains latest living35, precise living execution parent, original class3 capabilities and epoch"
        );
        ArtistAppealUnitRoles(suite.roleRegistry).setAppeal(address(this), true);
    }

    function _g3Witness(bytes32 scope, bytes32 old_, bytes32 next_) private {
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

    function g3Compromise(uint64 when) external g3Self {
        this.rrAt(when);
        this.g3RecordCause();
    }

    function g3RecordCause() external g3Self {
        ArtistAppealUnitRoles(suite.roleRegistry).setArbiter(address(artist), true);
        bytes32 evidence = keccak256(
            abi.encode(
                "recovered living cause",
                g3Terminal,
                block.timestamp,
                ingress.latestIdentityContestDismissal(artistId)
            )
        );
        bytes32 reason = keccak256(abi.encode("recovered living reason", evidence));
        ArtistUnitGovernance authority = ArtistUnitGovernance(manager.governanceAuthority());
        authority.configureContestReads(
            suite.roleRegistry, address(artist), reason, "urn:recovered-living:cause"
        );
        (bytes32 scope, bytes32 old_, bytes32 next_) =
            ingress.identityContestGovernanceContext(artistId, g3Terminal, evidence, reason);
        _g3Witness(scope, old_, next_);
        authority.executeModuleContext(
            address(ingress),
            abi.encodeCall(
                IStreamArtistIdentityContest.contestArtistIdentity,
                (artistId, g3Terminal, evidence, reason)
            ),
            1,
            scope,
            old_,
            next_
        );
        _inactive();
        Dismissal.Cause memory cause = ingress.currentIdentityContestCause(artistId);
        require(
            cause.facts.kind == 1 && cause.facts.executedTransitionHash == g3Terminal
                && cause.facts.incumbent == address(artist)
                && cause.facts.authorityClass == (g3Origin == 0 ? 1 : 3)
                && ingress.latestIdentityRecovery(artistId) == g3Prior,
            "new actual33 names the operative execution while preserving latest old35"
        );
    }

    function g3Dismiss() external g3Self {
        bytes32 first = ingress.identityTransitionClosure(artistId, g3Terminal).dismissalRecordHash;
        Dismissal.Request memory p = _dismissalRequest();
        ArtistAppealUnitRoles(suite.roleRegistry).setArbiter(address(artist), true);
        ArtistUnitGovernance authority = ArtistUnitGovernance(manager.governanceAuthority());
        authority.configureContestReads(
            suite.roleRegistry, address(artist), p.reasonHash, "urn:recovered-living:dismissal"
        );
        Dismissal.Context memory x = ingress.identityContestDismissalContext(p);
        _g3Witness(x.scopeHash, x.oldValueHash, x.newValueHash);
        authority.executeModuleContext(
            address(ingress),
            abi.encodeCall(IStreamArtistIdentityDismissal.dismissArtistIdentityContest, (p)),
            1,
            x.scopeHash,
            x.oldValueHash,
            x.newValueHash
        );
        _inactive();
        g3Dismissals.push(ingress.latestIdentityContestDismissal(artistId));
        require(
            ingress.identityTransitionClosure(artistId, g3Terminal).dismissalRecordHash
                == (first == 0 ? ingress.latestIdentityContestDismissal(artistId) : first),
            "first original closure remains fixed"
        );
    }

    function _g3Mature() private {
        if (
            ingress.identityTransitionClosure(artistId, g3Terminal).dismissalRecordHash == 0
                && block.timestamp < g3Window
        ) {
            this.rrAt(g3Window);
        }
    }

    function g3Rotate() external g3Self {
        _g3Mature();
        bytes32 previous = g3Terminal;
        _newRotationSafe(++g3Salt);
        g3Terminal = _stageRotation(ingress.lastArtistTransition(artistId));
        _executeTimedRotation(g3Terminal);
        _adoptRotatedSafe();
        g3Rotations.push(g3Terminal);
        g3Window = ingress.artistTransitionState(g3Terminal).postWindowEndsAt;
        Estate.AuthorityCapabilities memory caps = ingress.currentAuthorityCapabilities(artistId);
        require(
            _snapshot(g3Terminal).previousTransitionRecordHash == previous
                && _snapshot(g3Terminal).previousCommitment == _snapshot(previous).commitment
                && ingress.latestIdentityRecovery(artistId) == g3Prior
                && caps.authorityClass == (g3Origin == 0 ? 1 : 3)
                && caps.activationRecordHash == g3Origin,
            "actual32 retains exact executed parent, latest35 and original43"
        );
    }

    function g3Standing() external g3Self {
        _g3Mature();
        _newRotationSafe(++g3Salt);
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
            cause.facts.kind == 2 && cause.facts.executedTransitionHash == g3Terminal
                && cause.facts.pendingTransitionHash == pending && cause.facts.evidenceHash == 0
                && cause.facts.reasonHash == 0,
            "original zero-reason standing producer"
        );
        this.g3Dismiss();
    }

    function g3Request(bytes32 first, bytes32 second)
        external
        g3Self
        returns (IdentityRecovery.Request memory p, T.Authorization memory a)
    {
        _newRotationSafe(++g3Salt);
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

    function _g3Closure(bytes32 record) private view returns (bytes32) {
        Dismissal.Closure memory c = ingress.identityTransitionClosure(artistId, record);
        Dismissal.Record memory d = ingress.identityContestDismissalRecord(c.dismissalRecordHash);
        Dismissal.Cause memory cause = ingress.identityContestCause(d.terms.expectedCauseHash);
        return keccak256(
            abi.encode(c, d, cause, ingress.rotationRecord(cause.facts.pendingTransitionHash))
        );
    }

    function _g3History() private view returns (bytes32 value) {
        if (g3Origin != 0) {
            (Dormancy27.Notice memory n, uint8 phase, Dormancy27.Terminal memory t) =
                IStreamArtistDormancy(address(ingress)).dormancyRecord(g3Notice);
            value = keccak256(
                abi.encode(
                    n,
                    phase,
                    t,
                    _snapshot(g3Origin),
                    ingress.artistTransitionState(g3Origin),
                    _g3Closure(g3Origin)
                )
            );
        }
        value = keccak256(abi.encode(value, ingress.successorDesignationRecord(g3Designation)));
        for (uint256 i; i < g3Recoveries.length; ++i) {
            bytes32 record = g3Recoveries[i];
            (bytes32 primary, bytes32 occurrence, bytes32 secondary) =
                IStreamArtistIdentityRecoveryOwner(suite.owners[2]).identityRecoveryReceipts(record);
            value = keccak256(
                abi.encode(
                    value,
                    ingress.identityRecoveryRecord(record),
                    _snapshot(record),
                    ingress.artistTransitionState(record),
                    _g3Closure(record),
                    primary,
                    occurrence,
                    secondary
                )
            );
        }
        for (uint256 i; i < g3Rotations.length; ++i) {
            bytes32 record = g3Rotations[i];
            value = keccak256(
                abi.encode(
                    value, ingress.rotationRecord(record), _snapshot(record), _g3Closure(record)
                )
            );
        }
        for (uint256 i; i < g3Excluded.length; ++i) {
            value = keccak256(abi.encode(value, _status(g3Excluded[i])));
        }
        for (uint256 i; i < g3Dismissals.length; ++i) {
            Dismissal.Record memory d = ingress.identityContestDismissalRecord(g3Dismissals[i]);
            value = keccak256(
                abi.encode(value, d, ingress.identityContestCause(d.terms.expectedCauseHash))
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

    function _g3Register(IdentityRecovery.Request memory p, T.Authorization memory a, bool appeal)
        private
    {
        GovernanceCall[] memory calls = _schedule(
            keccak256(abi.encode("recovered living action", g3Prior, g3Terminal, g3Salt)), p, a
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
        g3Frozen = _g3History();
    }

    function _g3Elect(IdentityRecovery.Request memory p, T.Authorization memory a, bytes32 selected)
        private
    {
        IStreamArtistGuardianSelectionPreparation prep = _selectionPreparation();
        g3Election = prep.begin(artistId, g3Terminal, p.supersededRecordHashes);
        (GH.Head memory head,,,) = IStreamArtistGuardianHistory(suite.owners[2])
            .guardianHistoryState(artistId, 0, address(0), 0);
        bytes32 roots = _roots();
        vm.expectRevert(
            abi.encodeWithSelector(
                Selection.IncompleteGuardianSelection.selector, g3Election, uint64(0), head.count
            )
        );
        ingress.identityRecoveryContext(p, a);
        Selection.Progress memory progress = prep.continueSelection(g3Election, 1);
        require(!progress.complete, "partial guardian prefix is not complete election");
        progress = prep.continueSelection(g3Election, 64);
        require(
            progress.complete && progress.processed == head.count
                && progress.selectedRecordHash == selected && roots == _roots(),
            "complete original-record election"
        );
    }

    function _g3Recover(
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
        if (retry) _g3Rollback(p, a, epoch);
        vm.recordLogs();
        record = this.executeRegistered(p, a);
        _assertSnapshot(_snapshot(record), 35, before_, vm.getRecordedLogs());
        _g3Receipts(record);
        IdentityRecovery.Record memory r = ingress.identityRecoveryRecord(record);
        Estate.AuthorityCapabilities memory caps = ingress.currentAuthorityCapabilities(artistId);
        (,,, bytes32 head) = ingress.guardianSet(artistId);
        (bool used,) = ingress.rotationAcceptanceNonceState(artistId, p.newAddress, a.nonce);
        require(
            caps.authorityClass == p.vestedAuthorityClass && caps.status == p.vestedAuthorityClass
                && caps.authorityAddress == p.newAddress && r.delegationEpoch == epoch + 1
                && _snapshot(record).previousTransitionRecordHash == g3Terminal
                && _snapshot(record).previousCommitment == _snapshot(g3Terminal).commitment && used
                && head == selected && _g3History() == g3Frozen
                && r.fields.supersededRecordsHash
                    == RecoveryHashes.supersession(p.supersededRecordHashes)
                && keccak256(abi.encode(r.terms.supersededRecordHashes))
                    == keccak256(abi.encode(p.supersededRecordHashes)),
            "actual35 increments current epoch, preserves every original record and applies only exact exclusions"
        );
        if (g3Origin != 0) {
            require(
                caps.activationRecordHash == g3Origin && caps.effectiveCapabilities == g3Mask,
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
            !ok && roots == _roots() && _g3History() == g3Frozen,
            "identical old action cannot replay"
        );
        g3Recoveries.push(record);
        for (uint256 i; i < p.supersededRecordHashes.length; ++i) {
            g3Excluded.push(p.supersededRecordHashes[i]);
        }
        g3Prior = record;
        g3Terminal = record;
        g3Window = ingress.artistTransitionState(record).postWindowEndsAt;
        _adoptRotatedSafe();
    }

    function _g3Rollback(IdentityRecovery.Request memory p, T.Authorization memory a, uint64 epoch)
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
            !used && roots == _roots() && g3Frozen == _g3History()
                && ingress.latestIdentityRecovery(artistId) == g3Prior && head == oldHead
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
    function _g3Receipts(bytes32 record) private view {
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

    function _g3Round(uint8 rotations, bool retry) private returns (bytes32 record) {
        for (uint256 i; i < rotations; ++i) {
            this.g3Rotate();
        }
        this.g3Compromise(g3Window);
        (IdentityRecovery.Request memory p, T.Authorization memory a) = this.g3Request(0, 0);
        (,,, bytes32 head) = ingress.guardianSet(artistId);
        _g3Register(p, a, false);
        return _g3Recover(p, a, head, retry);
    }

    function _g3Publisher() private view returns (IStreamArtistGuardianAppealEvidence publisher) {
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

    function _g3Appeal(IdentityRecovery.Request memory p, bytes32 protectedRecord)
        private
        returns (IdentityRecovery.Request memory, T.Authorization memory)
    {
        Dismissal.Cause memory cause = ingress.currentIdentityContestCause(artistId);
        Appeal27.Document memory document = Appeal27.Document(
            Appeal27.requestCommitment(p),
            cause.causeHash,
            cause.facts.referenceHash,
            _snapshot(g3Terminal).commitment,
            g3Terminal,
            keccak256("recovered living specific findings"),
            new Appeal27.Finding[](1)
        );
        address[] memory parties = ingress.guardianSetRecord(protectedRecord).terms.guardians;
        document.findings[0] = Appeal27.Finding(protectedRecord, parties);
        bytes32 roots = _roots();
        bytes32 latest = ingress.latestIdentityRecovery(artistId);
        p.evidenceHash = _g3Publisher().publish(document);
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

    function _g3Role(IdentityRecovery.Request memory p, bytes32 expected) private view {
        require(
            IStreamArtistGuardianAppealOwner(suite.owners[2])
                .guardianRecoveryAuthorityRole(artistId, p.supersededRecordHashes) == expected,
            "exact current cutoff determines protected APPEAL or later-principal ARBITER"
        );
    }

    function testRecoveredLivingDormancyDirectRecoveryHasOriginalReceiptsAndAtomicArchiveRetry()
        public
    {
        this.g3Setup(0, false);
        bytes32 living = g3Prior;
        bytes32 recovered = _g3Round(0, true);
        require(
            ingress.identityRecoveryRecord(living).delegationEpoch == 1
                && ingress.identityRecoveryRecord(recovered).delegationEpoch == 3
                && _snapshot(recovered).previousTransitionRecordHash == g3Origin,
            "living1 then original43 epoch2 then class3 recovery epoch3"
        );
    }

    function testRecoveredLivingDormancyOnePost43RotationKeepsLivingPredecessorAndOrigin() public {
        this.g3Setup(0, false);
        _g3Round(1, true);
    }

    function testRecoveredLivingDormancyThreePost43RotationsKeepExactCompleteExecutionHistory()
        public
    {
        this.g3Setup(0, false);
        _g3Round(3, true);
        require(
            g3Rotations.length == 3 && g3Recoveries.length == 2,
            "three actual32 and two actual35 records retained"
        );
    }

    function testRecoveredLivingDormancyEarlier35DesignationAndGuardiansSurviveAnotherLiving35()
        public
    {
        this.g3Setup(0, true);
        bytes32 first = g3Recoveries[0];
        bytes32 second = g3Recoveries[1];
        require(
            first != second
                && ingress.successorDesignationRecord(g3Designation).provisional
                        .transitionRecordHash == first
                && ingress.guardianSetRecord(g3Protected).provisional.transitionRecordHash == first
                && _snapshot(g3Origin).previousTransitionRecordHash == second,
            "historical association is not substituted with latest35"
        );
        bytes32 recovered = _g3Round(1, true);
        require(
            ingress.identityRecoveryRecord(recovered).delegationEpoch == 4,
            "two living recoveries plus original43 and new class3 recovery"
        );
    }

    function testRecoveredLivingDormancyLivingRotationsAfterStanding35AndRepeatedDismissalsKeepExactBoundary()
        public
    {
        this.g3SetupWithLivingRotations();
        bytes32 living = g3Prior;
        bytes32 previous = _snapshot(g3Origin).previousTransitionRecordHash;
        Dismissal.Closure memory first = ingress.identityTransitionClosure(artistId, living);
        bytes32 latest = ingress.latestIdentityContestDismissal(artistId);
        Dismissal.Record memory last = ingress.identityContestDismissalRecord(latest);
        require(
            first.dismissalRecordHash != 0 && first.dismissalRecordHash != latest
                && last.authorityClass == 1 && last.restoredStatus == 1
                && last.terms.expectedResolutionHash != first.dismissalRecordHash
                && _snapshot(previous).operationId == 32 && _snapshot(previous).authorityClass == 1
                && g3Rotations.length == 2
                && _snapshot(g3Rotations[0]).previousTransitionRecordHash == living,
            "two later original dismissals and actual living32 suffix retain the standing35 boundary"
        );
        bytes32 closed = _g3Closure(living);
        bytes32 record = _g3Round(1, true);
        require(
            ingress.identityRecoveryRecord(record).delegationEpoch == 3
                && _g3Closure(living) == closed && g3Rotations.length == 3,
            "pre-notice living32 and post43 successor32 preserve exact epoch and independent original closure"
        );
    }

    function testRecoveredLivingDormancyClosedLiving35DoesNotReviveAbandonedGuardian() public {
        this.g3Setup(1, false);
        bytes32 living = g3Prior;
        bytes32 closure = _g3Closure(living);
        require(
            ingress.identityTransitionClosure(artistId, living).abandoned
                && ingress.guardianSetRecord(g3Abandoned).provisional.transitionRecordHash
                    == living,
            "real abandoned living35 association"
        );
        _g3Round(0, true);
        (,,, bytes32 head) = ingress.guardianSet(artistId);
        require(
            head == g3Protected && head != g3Abandoned && _g3Closure(living) == closure,
            "later43 recovery retains old closure and stable replacement guardian"
        );
        require(
            !IStreamArtistRotationOwner(suite.owners[2])
                .provisionalRecordEligible(
                    artistId, ingress.guardianSetRecord(g3Abandoned).provisional
                ),
            "abandoned old35 guardian remains explicitly ineligible after the later recovery"
        );
    }

    function testRecoveredLivingDormancyOldStanding35AndIndependent43ClosureStayAuthenticated()
        public
    {
        this.g3Setup(2, false);
        bytes32 living = g3Prior;
        bytes32 originalClosure = _g3Closure(living);
        this.g3Compromise(g3Window - 1);
        this.g3Dismiss();
        bytes32 dormancyClosure = _g3Closure(g3Origin);
        this.g3Compromise(g3Window + 1);
        (IdentityRecovery.Request memory p, T.Authorization memory a) = this.g3Request(0, 0);
        (,,, bytes32 head) = ingress.guardianSet(artistId);
        _g3Register(p, a, false);
        _g3Recover(p, a, head, true);
        require(
            _g3Closure(living) == originalClosure && _g3Closure(g3Origin) == dormancyClosure,
            "old class1 standing closure and new class3 early closure remain separate immutable records"
        );
    }

    function testRecoveredLivingDormancyClosed43ThenRotationsAndTerminalStandingPreserveAllParents()
        public
    {
        this.g3Setup(1, false);
        bytes32 living = g3Prior;
        bytes32 livingClosure = _g3Closure(living);
        this.g3Compromise(g3Window - 1);
        this.g3Dismiss();
        bytes32 originClosure = _g3Closure(g3Origin);
        this.g3Rotate();
        this.g3Rotate();
        bytes32 terminal = g3Terminal;
        this.g3Standing();
        bytes32 terminalClosure = _g3Closure(terminal);
        this.g3Compromise(g3Window + 1);
        (IdentityRecovery.Request memory p, T.Authorization memory a) = this.g3Request(0, 0);
        (,,, bytes32 head) = ingress.guardianSet(artistId);
        _g3Register(p, a, false);
        _g3Recover(p, a, head, true);
        require(
            _g3Closure(living) == livingClosure && _g3Closure(g3Origin) == originClosure
                && _g3Closure(terminal) == terminalClosure,
            "three independent original closures cannot substitute for one another"
        );
    }

    function testRecoveredLivingDormancyLaterSameTimestampGuardianUsesArbiterAndCompleteLowerNonceElection()
        public
    {
        this.g3Setup(0, false);
        bytes32 post = this.rrGuardian(address(artist), 25 days, 3000);
        bytes32 retained = this.rrGuardian(address(delegateSafe), 10 days, 2500);
        R.GuardianRecord memory later = ingress.guardianSetRecord(post);
        (, GH.Entry memory entry,,) = IStreamArtistGuardianHistory(suite.owners[2])
            .guardianHistoryState(artistId, _snapshot(g3Origin).guardians.count + 1, address(0), 0);
        require(
            later.signedAt == _snapshot(g3Origin).executedAt
                && later.signer == _snapshot(g3Origin).newAddress && entry.recordHash == post
                && entry.ownerRevision > _snapshot(g3Origin).ownerRevision,
            "same timestamp later owner admission"
        );
        this.g3Compromise(g3Window);
        (IdentityRecovery.Request memory p, T.Authorization memory a) = this.g3Request(post, 0);
        _g3Role(p, Appeal27.ARBITER);
        _g3Elect(p, a, retained);
        _g3Register(p, a, false);
        (Selection.Result memory selection, R.GuardianRecord memory original) = IStreamArtistGuardianSelectionOwner(
                suite.owners[2]
            ).guardianRecoverySelection(currentId);
        require(
            selection.sourceKey == g3Election && selection.selectedRecordHash == retained
                && original.recordHash == retained && original.nonce == 2500,
            "actual lower-nonce elected record"
        );
        _g3Recover(p, a, retained, true);
    }

    function testRecoveredLivingDormancyProtectedLiving35PrefixRequiresExactAppeal() public {
        this.g3Setup(0, true);
        this.g3Compromise(g3Window);
        (IdentityRecovery.Request memory p, T.Authorization memory a) =
            this.g3Request(g3Protected, 0);
        _g3Role(p, Appeal27.APPEAL);
        vm.expectRevert(
            abi.encodeWithSelector(Appeal27.InvalidGuardianAppeal.selector, p.evidenceHash)
        );
        ingress.identityRecoveryContext(p, a);
        (p, a) = _g3Appeal(p, g3Protected);
        _g3Elect(p, a, g3Retained);
        _g3Register(p, a, true);
        _g3Recover(p, a, g3Retained, true);
    }

    function testRecoveredLivingDormancyPost43GuardianBecomesProtectedAtNext32WithMixedAppeal()
        public
    {
        this.g3Setup(0, false);
        bytes32 intermediate = this.rrGuardian(address(artist), 25 days, 3000);
        this.g3Rotate();
        bytes32 post = this.rrGuardian(address(artist), 30 days, 4000);
        this.g3Compromise(g3Window);
        (IdentityRecovery.Request memory p, T.Authorization memory a) =
            this.g3Request(intermediate, post);
        _g3Role(p, Appeal27.APPEAL);
        vm.expectRevert(
            abi.encodeWithSelector(Appeal27.InvalidGuardianAppeal.selector, p.evidenceHash)
        );
        ingress.identityRecoveryContext(p, a);
        (p, a) = _g3Appeal(p, intermediate);
        _g3Elect(p, a, g3Protected);
        _g3Register(p, a, true);
        _g3Recover(p, a, g3Protected, true);
    }

    function testRecoveredLivingDormancyExcludedOnlySafeCannotVetoButRetainedGuardianCan() public {
        this.g3Setup(0, false);
        bytes32 post = this.rrGuardian(address(artist), 25 days, 3000);
        this.g3Compromise(g3Window);
        (IdentityRecovery.Request memory p, T.Authorization memory a) = this.g3Request(post, 0);
        _g3Elect(p, a, g3Protected);
        _g3Register(p, a, false);
        this.rrAt(scheduled.notBefore + 1);
        require(
            !executeSafe(
                artist,
                keys,
                address(ingress),
                0,
                abi.encodeCall(
                    IStreamArtistRecoveryAction.vetoIdentityRecovery,
                    (artistId, keccak256("excluded-only Safe"))
                ),
                0
            ),
            "actual excluded-only Safe call fails"
        );
        this.vetoByGuardian(keccak256("retained original living guardian"));
        (, A.Veto memory veto,,) = _read();
        require(
            veto.vetoer == address(delegateSafe),
            "retained prefix Safe veto survives authority changes"
        );
        scheduled.status = GovernanceActionStatus.EXECUTED;
        _publish();
        bytes32 roots = _roots();
        vm.expectRevert(abi.encodeWithSelector(A.RecoveryActionVetoed.selector, currentId));
        this.executeRegistered(p, a);
        _inactive();
        require(
            roots == _roots() && _g3History() == g3Frozen && _status(post).recoveryRecordHash == 0,
            "veto prevents mutation and permanent adjudication"
        );
    }

    function testRecoveredLivingDormancyLaterClass3RepeatKeepsOriginal43AndPermanentSupersession()
        public
    {
        this.g3Setup(0, true);
        bytes32 post = this.rrGuardian(address(artist), 25 days, 3000);
        this.g3Compromise(g3Window);
        (IdentityRecovery.Request memory p, T.Authorization memory a) = this.g3Request(post, 0);
        _g3Elect(p, a, g3Protected);
        _g3Register(p, a, false);
        bytes32 first = _g3Recover(p, a, g3Protected, true);
        bytes32 status = keccak256(abi.encode(_status(post)));
        _g3Round(2, true);
        bytes32 third = _g3Round(0, true);
        require(
            ingress.identityRecoveryRecord(first).delegationEpoch == 4
                && ingress.identityRecoveryRecord(third).delegationEpoch == 6
                && status == keccak256(abi.encode(_status(post)))
                && ingress.currentAuthorityCapabilities(artistId).activationRecordHash == g3Origin,
            "two earlier living recoveries and three later class3 recoveries retain exact original43 and permanent decision"
        );
    }

    function _g3Slot(bytes memory getter, bytes32 expected) private returns (bytes32 slot) {
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

    function _g3Corrupt(
        IdentityRecovery.Request memory p,
        T.Authorization memory a,
        bytes32 slot,
        bytes32 replacement,
        bytes32 context
    ) private {
        bytes32 original = vm.load(suite.owners[2], slot);
        require(original != replacement, "corruption changes original bytes");
        bytes32 roots = _roots();
        bytes32 history = _g3History();
        vm.store(suite.owners[2], slot, replacement);
        (bool ok,) =
            address(ingress).staticcall(abi.encodeCall(ingress.identityRecoveryContext, (p, a)));
        require(!ok, "same signed request rejects corrupted original proof");
        (bool used,) = ingress.rotationAcceptanceNonceState(artistId, p.newAddress, a.nonce);
        require(!used && roots == _roots(), "failed read cannot consume nonce or Archive state");
        vm.store(suite.owners[2], slot, original);
        require(
            history == _g3History()
                && context == keccak256(abi.encode(ingress.identityRecoveryContext(p, a))),
            "exact restoration admits byte-identical request and signature"
        );
    }

    function _g3CorruptHash(
        IdentityRecovery.Request memory p,
        T.Authorization memory a,
        bytes memory getter,
        bytes32 value,
        bytes32 context
    ) private {
        _g3Corrupt(p, a, _g3Slot(getter, value), bytes32(uint256(value) ^ 1), context);
    }

    function testRecoveredLivingDormancyRejectsAlteredHistoricalLiving35AndAssociationThenRetries()
        public
    {
        this.g3Setup(0, true);
        this.g3Rotate();
        this.g3Compromise(g3Window);
        (IdentityRecovery.Request memory p, T.Authorization memory a) = this.g3Request(0, 0);
        bytes32 context = keccak256(abi.encode(ingress.identityRecoveryContext(p, a)));
        bytes32 first = g3Recoveries[0];
        _g3CorruptHash(
            p,
            a,
            abi.encodeCall(IStreamArtistIdentityRecoveryOwner.identityRecoveryRecord, (first)),
            ingress.identityRecoveryRecord(first).contextHash,
            context
        );
        _g3CorruptHash(
            p,
            a,
            abi.encodeCall(IStreamArtistIdentityRecoveryOwner.identityRecoveryRecord, (g3Prior)),
            ingress.identityRecoveryRecord(g3Prior).contextHash,
            context
        );
        _g3CorruptHash(
            p,
            a,
            abi.encodeCall(
                IStreamArtistGuardianVestingHistory.guardianVestingSnapshot, (artistId, first)
            ),
            _snapshot(first).commitment,
            context
        );
        _g3Corrupt(
            p,
            a,
            _g3Slot(
                abi.encodeCall(
                    IStreamArtistIdentityRecoveryOwner.latestIdentityRecovery, (artistId)
                ),
                g3Prior
            ),
            first,
            context
        );
        _g3Corrupt(
            p,
            a,
            _g3Slot(abi.encodeCall(ingress.successorDesignationRecord, (g3Designation)), first),
            g3Prior,
            context
        );
        _g3Corrupt(
            p,
            a,
            _g3Slot(abi.encodeCall(ingress.guardianSetRecord, (g3Protected)), first),
            g3Prior,
            context
        );
        (,,, bytes32 head) = ingress.guardianSet(artistId);
        _g3Register(p, a, false);
        _g3Recover(p, a, head, true);
    }

    function testRecoveredLivingDormancyRejectsAlteredOriginEpochPrefixAndOldClosureThenRetries()
        public
    {
        this.g3Setup(1, false);
        bytes32 living = g3Prior;
        this.g3Rotate();
        this.g3Compromise(g3Window);
        (IdentityRecovery.Request memory p, T.Authorization memory a) = this.g3Request(0, 0);
        bytes32 context = keccak256(abi.encode(ingress.identityRecoveryContext(p, a)));
        (Dormancy27.Notice memory n,, Dormancy27.Terminal memory t) =
            IStreamArtistDormancy(address(ingress)).dormancyRecord(g3Notice);
        bytes memory read = abi.encodeCall(IStreamArtistDormancy.dormancyRecord, (g3Notice));
        _g3CorruptHash(p, a, read, n.terms.evidenceHash, context);
        _g3CorruptHash(p, a, read, t.evidenceHash, context);
        bytes32 epochSlot = bytes32(uint256(_g3Slot(read, t.witnessHash)) + 1);
        require(
            vm.load(suite.owners[2], epochSlot) == bytes32(uint256(t.delegationEpoch)),
            "observed terminal epoch follows full witness field"
        );
        _g3Corrupt(p, a, epochSlot, bytes32(uint256(t.delegationEpoch) + 1), context);
        _g3CorruptHash(
            p,
            a,
            abi.encodeCall(
                IStreamArtistGuardianVestingHistory.guardianVestingSnapshot, (artistId, g3Origin)
            ),
            _snapshot(g3Origin).previousCommitment,
            context
        );
        _g3CorruptHash(
            p,
            a,
            abi.encodeCall(
                IStreamArtistGuardianVestingHistory.guardianVestingSnapshot, (artistId, g3Origin)
            ),
            _snapshot(g3Origin).guardians.commitment,
            context
        );
        bytes32 dismissal = ingress.identityTransitionClosure(artistId, living).dismissalRecordHash;
        _g3CorruptHash(
            p,
            a,
            abi.encodeCall(ingress.identityContestDismissalRecord, (dismissal)),
            ingress.identityContestDismissalRecord(dismissal).cohortHash,
            context
        );
        (,,, bytes32 head) = ingress.guardianSet(artistId);
        _g3Register(p, a, false);
        _g3Recover(p, a, head, true);
    }

    function _g3EarlyUnclosed(bool rotated) private {
        this.g3Setup(0, false);
        if (rotated) this.g3Rotate();
        this.g3Compromise(g3Window - 1);
        (IdentityRecovery.Request memory p, T.Authorization memory a) = this.g3Request(0, 0);
        bytes32 roots = _roots();
        vm.expectRevert();
        ingress.identityRecoveryContext(p, a);
        this.rrAt(g3Window + 1);
        vm.expectRevert();
        ingress.identityRecoveryContext(p, a);
        (bool used,) = ingress.rotationAcceptanceNonceState(artistId, p.newAddress, a.nonce);
        require(
            !used && roots == _roots() && ingress.latestIdentityRecovery(artistId) == g3Prior,
            "waiting cannot replace the missing original closure or consume the old living recovery"
        );
    }

    function testRecoveredLivingDormancyEarlyUnclosed43NeverMaturesIntoRecovery() public {
        _g3EarlyUnclosed(false);
    }

    function testRecoveredLivingDormancyEarlyUnclosed32NeverMaturesIntoRecovery() public {
        _g3EarlyUnclosed(true);
    }
}

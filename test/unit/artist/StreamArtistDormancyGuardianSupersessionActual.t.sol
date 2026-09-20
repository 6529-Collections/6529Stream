// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./ArtistGuardianAppealFixture.sol";
import {
    IStreamArtistDormancy,
    IStreamArtistDormancyEvidence,
    StreamArtistDormancyTypes as Dormancy27
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistDormancy.sol";
import {
    StreamArtistGuardianAppealTypes as Appeal27
} from "../../../smart-contracts/interfaces/stream/artist/StreamArtistGuardianAppealTypes.sol";
import {
    IStreamArtistGuardianAppealEvidence,
    IStreamArtistGuardianAppealBinding,
    IStreamArtistGuardianAppealOwner
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistGuardianAppealEvidence.sol";
import {
    StreamArtistSuccessionTypes as Succ27
} from "../../../smart-contracts/interfaces/stream/artist/StreamArtistSuccessionTypes.sol";
import {
    IStreamRoleRegistry
} from "../../../smart-contracts/interfaces/stream/governance/IStreamRoleRegistry.sol";
import {
    IStreamArtistIdentityContestOwner
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistIdentityContest.sol";

/// @notice First designated-dormancy recovery with actual guardian exclusions and original receipts.
/// @dev Real Artist owners, Archive and threshold Safes. Core, Executor scheduling and dormancy-role
/// facts use the inherited typed unit boundary; appeal root/role revisions use its pinned graph.
/// No prior op35 or class4 appointment is used. Existing fixtures and their assertions are unchanged.
contract StreamArtistDormancyGuardianSupersessionActualTest is ArtistGuardianAppealFixture {
    // Original pre-ART27 facts tuple, assembled only from public immutable fixture records.
    // This is a hash oracle, not a second admission verifier.
    struct OriginalDormancyFacts27 {
        Dormancy27.Notice notice;
        Dormancy27.Terminal terminal;
        R.TransitionState transition;
        V.Snapshot vesting;
        V.Snapshot previous;
        GH.Head guardians;
        Succ27.DesignationRecord designation;
        Succ27.DirectiveRecord paired;
        Succ27.DirectiveRecord forbidden;
        Contest.Record contest;
    }
    bytes32 private dsNotice;
    bytes32 private dsOrigin;
    bytes32 private dsTerminal;
    bytes32 private dsPlan;
    bytes32 private dsDirective;
    bytes32 private dsProtected;
    bytes32 private dsRetained;
    bytes32 private dsPost;
    bytes32 private dsMiddle;
    bytes32 private dsAbandoned;
    bytes32 private dsCause;
    bytes32 private dsFrozenHistory;
    bytes32 private dsElection;
    uint64 private dsWindow;
    uint32 private dsCapabilities;
    address private dsProtectedParty;
    bytes32[] private dsRotations;
    bytes32[] private dsGuardians;

    modifier dsSelf() {
        require(msg.sender == address(this), "ART27 fixture caller");
        _;
    }

    function dsSetup(uint32 forbidden) external dsSelf {
        _deployAppealSuite();
        _accept();
        _payout();
        _delegateSetup();
        if (forbidden != 0) dsDirective = _directiveRecord(forbidden);
        dsProtectedParty = address(artist);
        dsRetained = this.dsGuardian(address(delegateSafe), 10 days, 900);
        dsProtected = this.dsGuardian(dsProtectedParty, 20 days, 1000);
        _newRotationSafe(71001);
        Succ27.Designation memory plan = _successorTerms(address(rotationSafe), 2);
        plan.grantedCapabilities = 256;
        dsPlan = _successionRecord(plan);
        dsNotice = this.dsBeginNotice();
        this.dsCompleteNotice();
        ArtistAppealUnitRoles(suite.roleRegistry).setAppeal(address(this), true);
        V.Snapshot memory v = _snapshot(dsOrigin);
        require(
            v.operationId == 43 && v.authorityClass == 3 && v.guardians.count == 2
                && v.previousTransitionRecordHash == 0 && v.previousCommitment == 0
                && ingress.latestIdentityRecovery(artistId) == 0,
            "first actual designated43 admits the complete living prefix without prior recovery"
        );
    }

    function dsAt(uint64 when) external dsSelf {
        vm.warp(when);
    }

    function _dsDormancyCall(bytes memory data, Dormancy27.Context memory x, bytes32 evidence)
        private
    {
        ArtistUnitGovernance authority = ArtistUnitGovernance(manager.governanceAuthority());
        authority.configureContestReads(
            suite.roleRegistry, address(this), evidence, "urn:art27:dormancy"
        );
        avm.mockCall(
            suite.roleRegistry,
            abi.encodeCall(
                IStreamRoleRegistry.hasRole,
                (keccak256("ROLE_ARTIST_DORMANCY_ADMIN"), address(this))
            ),
            abi.encode(true)
        );
        authority.executeModuleContext(
            address(ingress), data, 1, x.scopeHash, x.oldValueHash, x.newValueHash
        );
    }

    function dsBeginNotice() external dsSelf returns (bytes32 notice) {
        uint64 last =
            IStreamArtistIdentityOwner(suite.owners[2]).identity(artistId).lastAuthorityActionAt;
        (uint64 inactivity,,) =
            ingress.artistWindowInfo(keccak256("ARTIST_DORMANCY_MIN_INACTIVITY_SECONDS"));
        vm.warp(uint256(last) + inactivity);
        Dormancy27.Initiation memory p = Dormancy27.Initiation(
            artistId, keccak256("ART27 actual contact attempts"), "urn:art27:outreach"
        );
        IStreamArtistDormancy dormancy = IStreamArtistDormancy(address(ingress));
        _dsDormancyCall(
            abi.encodeCall(IStreamArtistDormancy.initiateArtistDormancy, (p)),
            dormancy.dormancyInitiationContext(p),
            p.evidenceHash
        );
        (notice,,) = dormancy.dormancyNotice(artistId);
    }

    function dsCompleteNotice() external dsSelf {
        IStreamArtistDormancy dormancy = IStreamArtistDormancy(address(ingress));
        (Dormancy27.Notice memory notice,,) = dormancy.dormancyRecord(dsNotice);
        vm.warp(notice.noticeEndsAt);
        vm.roll(500);
        Dormancy27.Completion memory p = Dormancy27.Completion(
            artistId, dsNotice, address(rotationSafe), keccak256("ART27 original completion")
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
            "unchanged original43 evidence preimage"
        );
        _dsDormancyCall(
            abi.encodeCall(IStreamArtistDormancy.completeArtistDormancy, (p)),
            x,
            keccak256(evidence)
        );
        (,, Dormancy27.Terminal memory terminal) = dormancy.dormancyRecord(dsNotice);
        dsOrigin = terminal.recordHash;
        dsTerminal = dsOrigin;
        _adoptRotatedSafe();
        dsWindow = ingress.artistTransitionState(dsOrigin).postWindowEndsAt;
        Estate.AuthorityCapabilities memory caps = ingress.currentAuthorityCapabilities(artistId);
        dsCapabilities = caps.effectiveCapabilities;
        require(
            caps.authorityClass == 3 && caps.status == 3 && caps.activationRecordHash == dsOrigin
                && terminal.plan.designation == dsPlan
                && _operationPayload(43, manager.governanceAuthority(), dsOrigin).length != 0,
            "actual designated completion and Archive retain original rights"
        );
    }

    function dsGuardian(address member, uint64 window, uint256 nonce)
        external
        dsSelf
        returns (bytes32 record)
    {
        address[] memory members = new address[](1);
        members[0] = member;
        record = _guardianRecord(members, 1, window, nonce);
        dsGuardians.push(record);
    }

    function dsRotate(uint256 salt) external dsSelf {
        bytes32 previous = dsTerminal;
        _newRotationSafe(salt);
        dsTerminal = _stageRotation(ingress.lastArtistTransition(artistId));
        _executeTimedRotation(dsTerminal);
        _adoptRotatedSafe();
        dsRotations.push(dsTerminal);
        dsWindow = ingress.rotationRecord(dsTerminal).transition.postWindowEndsAt;
        V.Snapshot memory v = _snapshot(dsTerminal);
        require(
            v.operationId == 32 && v.authorityClass == 3
                && v.previousTransitionRecordHash == previous
                && v.previousCommitment == _snapshot(previous).commitment
                && ingress.currentAuthorityCapabilities(artistId).activationRecordHash == dsOrigin
                && ingress.latestIdentityRecovery(artistId) == 0,
            "actual32 preserves the original43 and appends its exact executed parent"
        );
    }

    function dsCompromise(uint64 when) external dsSelf {
        vm.warp(when);
        this.dsRecordCause();
    }

    function dsRecordCause() external dsSelf {
        ArtistAppealUnitRoles(suite.roleRegistry).setArbiter(address(artist), true);
        bytes32 evidence = keccak256(
            abi.encode(
                "ART27 compromise",
                dsTerminal,
                block.timestamp,
                ingress.latestIdentityContestDismissal(artistId)
            )
        );
        bytes32 reason = keccak256(abi.encode("ART27 reason", evidence));
        ArtistUnitGovernance authority = ArtistUnitGovernance(manager.governanceAuthority());
        authority.configureContestReads(
            suite.roleRegistry, address(artist), reason, "urn:art27:cause"
        );
        (bytes32 scope, bytes32 old_, bytes32 next_) =
            ingress.identityContestGovernanceContext(artistId, dsTerminal, evidence, reason);
        authority.executeModuleContext(
            address(ingress),
            abi.encodeCall(
                IStreamArtistIdentityContest.contestArtistIdentity,
                (artistId, dsTerminal, evidence, reason)
            ),
            1,
            scope,
            old_,
            next_
        );
        Dismissal.Cause memory cause = ingress.currentIdentityContestCause(artistId);
        dsCause = cause.causeHash;
        require(
            cause.facts.kind == 1 && cause.facts.authorityClass == 3 && cause.facts.priorStatus == 3
                && cause.facts.executedTransitionHash == dsTerminal
                && cause.facts.incumbent == address(artist)
                && ingress.latestIdentityRecovery(artistId) == 0,
            "actual original33 names the current designated execution"
        );
    }

    function dsDismiss() external dsSelf {
        bytes32 first = ingress.identityTransitionClosure(artistId, dsTerminal).dismissalRecordHash;
        bytes32 record = _dismissalExecute(_dismissalRequest(), 1, 0);
        require(
            ingress.identityTransitionClosure(artistId, dsTerminal).dismissalRecordHash
                == (first == 0 ? record : first),
            "admitted closure keeps its first original dismissal"
        );
    }

    function dsStanding(uint256 salt) external dsSelf {
        _newRotationSafe(salt);
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
            "actual Safe veto captures a separate zero-reason pending rotation"
        );
        Dismissal.Cause memory cause = ingress.currentIdentityContestCause(artistId);
        require(
            cause.facts.kind == 2 && cause.facts.executedTransitionHash == dsTerminal
                && cause.facts.pendingTransitionHash == pending && cause.facts.evidenceHash == 0
                && cause.facts.reasonHash == 0,
            "standing episode retains its original producer facts"
        );
        this.dsDismiss();
    }

    function _dsList(bytes32 first, bytes32 second) private pure returns (bytes32[] memory list) {
        list = new bytes32[](first == 0 ? 0 : second == 0 ? 1 : 2);
        if (first == 0) return list;
        list[0] = first;
        if (second != 0) {
            list[1] = second;
            if (first > second) (list[0], list[1]) = (second, first);
        }
    }

    function dsRequest(bytes32 first, bytes32 second)
        external
        dsSelf
        returns (IdentityRecovery.Request memory p, T.Authorization memory a)
    {
        _newRotationSafe(71999);
        Dismissal.Cause memory cause = ingress.currentIdentityContestCause(artistId);
        p = IdentityRecovery.Request(
            artistId,
            address(rotationSafe),
            3,
            cause.causeHash,
            ingress.latestIdentityContestDismissal(artistId),
            cause.facts.evidenceHash,
            cause.facts.reasonHash,
            _dsList(first, second)
        );
        a = _acceptance(p);
    }

    function _dsPublisher() private view returns (IStreamArtistGuardianAppealEvidence publisher) {
        address child = StreamArtistIdentityAuthority(suite.owners[2]).identityRecoveryExtension();
        (address target, bytes32 hash) =
            IStreamArtistGuardianAppealBinding(child).guardianAppealEvidenceBinding();
        require(hash != 0 && target.codehash == hash, "exact fixed appeal publisher runtime");
        publisher = IStreamArtistGuardianAppealEvidence(target);
        require(
            publisher.owner() == suite.owners[2] && publisher.artistRegistry() == address(ingress),
            "original publisher owner and registry"
        );
    }

    function _dsDocument(IdentityRecovery.Request memory p)
        private
        view
        returns (Appeal27.Document memory d)
    {
        Dismissal.Cause memory cause = ingress.currentIdentityContestCause(artistId);
        d = Appeal27.Document(
            Appeal27.requestCommitment(p),
            cause.causeHash,
            cause.facts.referenceHash,
            _snapshot(dsTerminal).commitment,
            dsTerminal,
            keccak256("ART27 specific hostile findings"),
            new Appeal27.Finding[](1)
        );
        address[] memory parties = new address[](1);
        parties[0] = dsProtectedParty;
        d.findings[0] = Appeal27.Finding(dsProtected, parties);
    }

    function _dsPublishAppeal(IdentityRecovery.Request memory p)
        private
        returns (IdentityRecovery.Request memory, T.Authorization memory)
    {
        Appeal27.Document memory d = _dsDocument(p);
        bytes32 roots = _roots();
        p.evidenceHash = _dsPublisher().publish(d);
        require(
            _roots() == roots && ingress.latestIdentityRecovery(artistId) == 0
                && p.evidenceHash
                    == Appeal27.documentHash(block.chainid, address(ingress), suite.owners[2], d)
                && IStreamArtistGuardianAppealOwner(suite.owners[2])
                    .guardianRecoveryAuthorityRole(artistId, p.supersededRecordHashes)
                == Appeal27.APPEAL,
            "publication authenticates no authority and protected history requires APPEAL"
        );
        return (p, _acceptance(p));
    }

    function _dsElect(IdentityRecovery.Request memory p, T.Authorization memory a, bytes32 selected)
        private
    {
        IStreamArtistGuardianSelectionPreparation preparation = _selectionPreparation();
        dsElection = preparation.begin(artistId, dsTerminal, p.supersededRecordHashes);
        (GH.Head memory head,,,) = IStreamArtistGuardianHistory(suite.owners[2])
            .guardianHistoryState(artistId, 0, address(0), 0);
        bytes32 roots = _roots();
        vm.expectRevert(
            abi.encodeWithSelector(
                Selection.IncompleteGuardianSelection.selector, dsElection, uint64(0), head.count
            )
        );
        ingress.identityRecoveryContext(p, a);
        Selection.Progress memory progress = preparation.continueSelection(dsElection, 1);
        require(!progress.complete && progress.processed == 1, "one member is not the whole prefix");
        vm.expectRevert(
            abi.encodeWithSelector(
                Selection.IncompleteGuardianSelection.selector, dsElection, uint64(1), head.count
            )
        );
        ingress.identityRecoveryContext(p, a);
        progress = preparation.continueSelection(dsElection, 64);
        require(
            progress.complete && progress.processed == head.count
                && progress.selectedRecordHash == selected && roots == _roots(),
            "bounded complete election selects the highest eligible retained nonce without owner writes"
        );
    }

    function _dsRegister(IdentityRecovery.Request memory p, T.Authorization memory a, bool appeal)
        private
    {
        GovernanceCall[] memory calls = _schedule(keccak256("ART27 exact elected action"), p, a);
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
            "registered action binds the exact request and complete original guardian history"
        );
        dsFrozenHistory = _dsHistory();
    }

    function _dsHistory() private view returns (bytes32 result) {
        (Dormancy27.Notice memory n, uint8 phase, Dormancy27.Terminal memory t) =
            IStreamArtistDormancy(address(ingress)).dormancyRecord(dsNotice);
        result = keccak256(
            abi.encode(
                n,
                phase,
                t,
                _snapshot(dsOrigin),
                ingress.artistTransitionState(dsOrigin),
                ingress.successorDesignationRecord(dsPlan),
                ingress.estateDirectiveRecord(dsDirective),
                _dsClosure(dsOrigin),
                ingress.identityContestCause(dsCause)
            )
        );
        for (uint256 i; i < dsRotations.length; ++i) {
            bytes32 id = dsRotations[i];
            result = keccak256(
                abi.encode(result, ingress.rotationRecord(id), _snapshot(id), _dsClosure(id))
            );
        }
        for (uint256 i; i < dsGuardians.length; ++i) {
            result = keccak256(abi.encode(result, ingress.guardianSetRecord(dsGuardians[i])));
        }
    }

    function _dsClosure(bytes32 id) private view returns (bytes32) {
        Dismissal.Closure memory closed = ingress.identityTransitionClosure(artistId, id);
        Dismissal.Record memory r =
            ingress.identityContestDismissalRecord(closed.dismissalRecordHash);
        return
            keccak256(
                abi.encode(closed, r, ingress.identityContestCause(r.terms.expectedCauseHash))
            );
    }

    function _dsRecover(
        IdentityRecovery.Request memory p,
        T.Authorization memory a,
        bytes32 selected,
        bool retry
    ) private {
        uint64 epoch = ingress.identityRecoveryContext(p, a).delegationEpoch;
        bytes32 principal =
            keccak256(abi.encode(IStreamArtistIdentityOwner(suite.owners[2]).identity(artistId)));
        (,,, bytes32 oldHead) = ingress.guardianSet(artistId);
        this.dsAt(scheduled.notBefore);
        scheduled.status = GovernanceActionStatus.EXECUTED;
        _publish();
        T.Snapshot memory before_ = _ownerSnapshot();
        if (retry) _dsRollback(p, a, oldHead, principal, epoch);
        vm.recordLogs();
        bytes32 recovered = this.executeRegistered(p, a);
        _assertSnapshot(_snapshot(recovered), 35, before_, vm.getRecordedLogs());
        _dsReceipts(recovered);
        IdentityRecovery.Record memory r = ingress.identityRecoveryRecord(recovered);
        Estate.AuthorityCapabilities memory caps = ingress.currentAuthorityCapabilities(artistId);
        V.Snapshot memory v = _snapshot(recovered);
        (,,, bytes32 operative) = ingress.guardianSet(artistId);
        (bool used,) = ingress.rotationAcceptanceNonceState(artistId, p.newAddress, a.nonce);
        require(
            caps.authorityClass == 3 && caps.status == 3 && caps.authorityAddress == p.newAddress
                && caps.activationRecordHash == dsOrigin
                && caps.effectiveCapabilities == dsCapabilities && r.delegationEpoch == epoch + 1
                && v.previousTransitionRecordHash == dsTerminal
                && v.previousCommitment == _snapshot(dsTerminal).commitment && used
                && r.fields.supersededRecordsHash
                    == RecoveryHashes.supersession(p.supersededRecordHashes)
                && keccak256(abi.encode(r.terms.supersededRecordHashes))
                    == keccak256(abi.encode(p.supersededRecordHashes)) && operative == selected
                && _dsHistory() == dsFrozenHistory
                && _operationPayload(35, manager.governanceAuthority(), recovered).length != 0,
            "op35 preserves original43 rights/history, increments epoch and admits only the exact excluded list"
        );
        for (uint256 i; i < p.supersededRecordHashes.length; ++i) {
            GS.Status memory status = _status(p.supersededRecordHashes[i]);
            require(
                status.recoveryRecordHash == recovered && status.actionId == currentId,
                "exact executed adjudication"
            );
        }
        require(
            _status(selected).recoveryRecordHash == 0, "selected original guardian remains retained"
        );
        bytes32 roots = _roots();
        (bool ok,) = address(this).call(abi.encodeCall(this.executeRegistered, (p, a)));
        _inactive();
        require(
            !ok && roots == _roots() && _dsHistory() == dsFrozenHistory,
            "same action and acceptance cannot replay"
        );
    }

    function _dsRollback(
        IdentityRecovery.Request memory p,
        T.Authorization memory a,
        bytes32 oldHead,
        bytes32 principal,
        uint64 epoch
    ) private {
        bytes32 roots = _roots();
        bytes32 signed = keccak256(abi.encode(p, a));
        uint256 safeNonce = rotationSafe.nonce();
        _overflow();
        this.executeRegistered(p, a);
        _inactive();
        (,,, bytes32 current) = ingress.guardianSet(artistId);
        (bool used,) = ingress.rotationAcceptanceNonceState(artistId, p.newAddress, a.nonce);
        require(
            !used && current == oldHead && roots == _roots() && _dsHistory() == dsFrozenHistory
                && ingress.latestIdentityRecovery(artistId) == 0
                && rotationSafe.nonce() == safeNonce
                && principal
                    == keccak256(
                        abi.encode(IStreamArtistIdentityOwner(suite.owners[2]).identity(artistId))
                    ) && ingress.identityRecoveryContext(p, a).delegationEpoch == epoch,
            "actual late Archive overflow restores heads, authority, epoch, roots, acceptance and original history"
        );
        for (uint256 i; i < p.supersededRecordHashes.length; ++i) {
            require(
                _status(p.supersededRecordHashes[i]).recoveryRecordHash == 0,
                "failed append leaves no adjudication"
            );
        }
        vm.roll(restoreBlock);
        require(keccak256(abi.encode(p, a)) == signed, "byte-identical Safe acceptance retry");
    }

    // Independent original thirteen-word receipt oracle; receipt commitments are not record IDs.
    function _dsReceipts(bytes32 record) private view {
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

    function _dsStart(uint8 depth) private {
        this.dsSetup(0);
        for (uint256 i; i < depth; ++i) {
            this.dsAt(dsWindow);
            this.dsRotate(71100 + i);
        }
    }

    function _dsArbiter(IdentityRecovery.Request memory p) private view {
        require(
            IStreamArtistGuardianAppealOwner(suite.owners[2])
                .guardianRecoveryAuthorityRole(artistId, p.supersededRecordHashes)
            == Appeal27.ARBITER,
            "only actual later records by the cutoff principal use ARBITER"
        );
    }

    function testArt27Direct43PostCutoffSameTimestampArbiterAndOriginalReceipts() public {
        _dsStart(0);
        dsPost = this.dsGuardian(address(artist), 10 days, 100);
        (, GH.Entry memory entry,,) = IStreamArtistGuardianHistory(suite.owners[2])
            .guardianHistoryState(artistId, 3, address(artist), 0);
        V.Snapshot memory cutoff = _snapshot(dsTerminal);
        R.GuardianRecord memory later = ingress.guardianSetRecord(dsPost);
        require(
            entry.recordHash == dsPost && entry.ownerRevision > cutoff.ownerRevision
                && later.signedAt == cutoff.executedAt && later.signer == cutoff.newAddress
                && later.authorityClass == cutoff.authorityClass,
            "same timestamp is distinguished by actual admitted owner revision"
        );
        this.dsCompromise(dsWindow);
        (IdentityRecovery.Request memory p, T.Authorization memory a) = this.dsRequest(dsPost, 0);
        _dsArbiter(p);
        _dsRegister(p, a, false);
        _dsRecover(p, a, dsProtected, true);
    }

    function testArt27ThreeRotationsElectRetainedLowerNonceHeadAndRollback() public {
        _dsStart(3);
        dsPost = this.dsGuardian(address(artist), 25 days, 2000);
        dsMiddle = this.dsGuardian(address(delegateSafe), 10 days, 1500);
        this.dsCompromise(dsWindow);
        (IdentityRecovery.Request memory p, T.Authorization memory a) = this.dsRequest(dsPost, 0);
        _dsArbiter(p);
        _dsElect(p, a, dsMiddle);
        require(
            ingress.identityRecoveryContext(p, a).postContestSeconds == 10 days,
            "retained head sets the recovery window"
        );
        _dsRegister(p, a, false);
        (Selection.Result memory selection, R.GuardianRecord memory restored) = IStreamArtistGuardianSelectionOwner(
                suite.owners[2]
            ).guardianRecoverySelection(currentId);
        require(
            selection.sourceKey == dsElection && selection.selectedRecordHash == dsMiddle
                && restored.recordHash == dsMiddle && restored.nonce == 1500,
            "registration saves exact complete election and original lower-nonce record"
        );
        _dsRecover(p, a, dsMiddle, true);
    }

    function testArt27EarlyClosed43CandidateCannotBecomeOperativeAfterRotation() public {
        _dsStart(0);
        dsAbandoned = this.dsGuardian(address(artist), 25 days, 2001);
        this.dsCompromise(dsWindow - 10);
        this.dsDismiss();
        bytes32 originalClosure = _dsClosure(dsOrigin);
        this.dsRotate(71201);
        dsPost = this.dsGuardian(address(artist), 15 days, 3000);
        this.dsCompromise(dsWindow);
        (IdentityRecovery.Request memory p, T.Authorization memory a) = this.dsRequest(dsPost, 0);
        _dsElect(p, a, dsProtected);
        _dsRegister(p, a, false);
        _dsRecover(p, a, dsProtected, true);
        require(
            originalClosure == _dsClosure(dsOrigin)
                && !IStreamArtistRotationOwner(suite.owners[2])
                    .provisionalRecordEligible(
                        artistId, ingress.guardianSetRecord(dsAbandoned).provisional
                    ),
            "original abandoned candidate stays archived and ineligible after exclusion and recovery"
        );
    }

    function testArt27StandingClosed43AndSeparateTerminalClosureRetainBothParents() public {
        _dsStart(0);
        this.dsAt(dsWindow);
        this.dsStanding(71202);
        bytes32 originClosure = _dsClosure(dsOrigin);
        bytes32 pending = ingress.lastArtistTransition(artistId);
        bytes32 pendingRecord = keccak256(abi.encode(ingress.rotationRecord(pending)));
        this.dsRotate(71203);
        require(
            _snapshot(dsTerminal).previousTransitionRecordHash == dsOrigin
                && ingress.rotationRecord(dsTerminal).terms.expectedPreviousTransitionRecordHash
                    == pending,
            "first executed successor follows distinct staged and executed parents"
        );
        this.dsAt(dsWindow);
        this.dsRotate(71204);
        this.dsAt(dsWindow);
        this.dsStanding(71205);
        bytes32 terminalClosure = _dsClosure(dsTerminal);
        dsPost = this.dsGuardian(address(artist), 15 days, 3000);
        this.dsCompromise(dsWindow + 1);
        (IdentityRecovery.Request memory p, T.Authorization memory a) = this.dsRequest(dsPost, 0);
        _dsElect(p, a, dsProtected);
        _dsRegister(p, a, false);
        _dsRecover(p, a, dsProtected, true);
        require(
            originClosure == _dsClosure(dsOrigin) && terminalClosure == _dsClosure(dsTerminal)
                && pendingRecord == keccak256(abi.encode(ingress.rotationRecord(pending))),
            "independent original and terminal closures and pending history remain byte-exact"
        );
    }

    function dsCurrentVeto() external dsSelf {
        require(
            executeSafe(
                artist,
                keys,
                address(ingress),
                0,
                abi.encodeCall(
                    IStreamArtistRecoveryAction.vetoIdentityRecovery,
                    (artistId, keccak256("ART27 current Safe veto"))
                ),
                0
            ),
            "actual current Safe veto"
        );
    }

    function testArt27ExcludedOnlySafeCannotVetoButRetainedPrefixCan() public {
        _dsStart(1);
        dsPost = this.dsGuardian(address(artist), 25 days, 2000);
        this.dsCompromise(dsWindow);
        (IdentityRecovery.Request memory p, T.Authorization memory a) = this.dsRequest(dsPost, 0);
        _dsElect(p, a, dsProtected);
        _dsRegister(p, a, false);
        vm.expectRevert();
        this.dsCurrentVeto();
        vm.prank(address(artist));
        vm.expectRevert(abi.encodeWithSelector(A.InvalidRecoveryGuardian.selector, address(artist)));
        ingress.vetoIdentityRecovery(artistId, keccak256("ART27 excluded membership"));
        this.dsAt(scheduled.notBefore + 1);
        this.vetoByGuardian(keccak256("ART27 retained lower-nonce prefix"));
        (, A.Veto memory veto,,) = _read();
        require(
            veto.vetoer == address(delegateSafe),
            "original retained Safe veto survives head exclusion"
        );
        _dsVetoed(p, a);
    }

    function testArt27SameSafeRetainedMembershipStillVetoes() public {
        _dsStart(0);
        dsPost = this.dsGuardian(address(artist), 25 days, 2000);
        dsMiddle = this.dsGuardian(address(artist), 10 days, 1500);
        this.dsCompromise(dsWindow);
        (IdentityRecovery.Request memory p, T.Authorization memory a) = this.dsRequest(dsPost, 0);
        _dsElect(p, a, dsMiddle);
        _dsRegister(p, a, false);
        this.dsAt(scheduled.notBefore + 1);
        this.dsCurrentVeto();
        (, A.Veto memory veto,,) = _read();
        require(
            veto.vetoer == address(artist),
            "exclusion is record-specific, not an address-wide veto removal"
        );
        _dsVetoed(p, a);
    }

    function _dsVetoed(IdentityRecovery.Request memory p, T.Authorization memory a) private {
        bytes32 roots = _roots();
        scheduled.status = GovernanceActionStatus.EXECUTED;
        _publish();
        vm.expectRevert(abi.encodeWithSelector(A.RecoveryActionVetoed.selector, currentId));
        this.executeRegistered(p, a);
        _inactive();
        (bool used,) = ingress.rotationAcceptanceNonceState(artistId, p.newAddress, a.nonce);
        require(
            !used && roots == _roots() && ingress.latestIdentityRecovery(artistId) == 0
                && _status(dsPost).recoveryRecordHash == 0 && _dsHistory() == dsFrozenHistory,
            "vetoed action cannot apply recovery, consume acceptance or mutate original history"
        );
    }

    function testArt27Direct43ProtectedPrefixRequiresAppealAndExactArchiveRetry() public {
        _dsStart(0);
        this.dsCompromise(dsWindow);
        (IdentityRecovery.Request memory p, T.Authorization memory a) =
            this.dsRequest(dsProtected, 0);
        vm.expectRevert(
            abi.encodeWithSelector(Appeal27.InvalidGuardianAppeal.selector, p.evidenceHash)
        );
        ingress.identityRecoveryContext(p, a);
        (p, a) = _dsPublishAppeal(p);
        _dsElect(p, a, dsRetained);
        _dsRegister(p, a, true);
        _dsRecover(p, a, dsRetained, true);
    }

    function testArt27RotatedMixedAppealUsesActualTerminalCutoffAndOriginalRights() public {
        _dsStart(2);
        dsPost = this.dsGuardian(address(artist), 25 days, 2000);
        this.dsCompromise(dsWindow);
        (IdentityRecovery.Request memory p, T.Authorization memory a) =
            this.dsRequest(dsProtected, dsPost);
        (p, a) = _dsPublishAppeal(p);
        _dsElect(p, a, dsRetained);
        _dsRegister(p, a, true);
        _dsRecover(p, a, dsRetained, true);
    }

    function _dsBadDocument(IdentityRecovery.Request memory p, Appeal27.Document memory d) private {
        bytes32 roots = _roots();
        p.evidenceHash = _dsPublisher().publish(d);
        T.Authorization memory a = _acceptance(p);
        vm.expectRevert(
            abi.encodeWithSelector(Appeal27.InvalidGuardianAppeal.selector, p.evidenceHash)
        );
        ingress.identityRecoveryContext(p, a);
        require(
            roots == _roots() && ingress.latestIdentityRecovery(artistId) == 0,
            "invalid evidence grants no authority"
        );
    }

    function testArt27RejectsWrongMissingExtraAndStaleAppealBindingsThenRetries() public {
        _dsStart(1);
        dsPost = this.dsGuardian(address(artist), 25 days, 2000);
        this.dsCompromise(dsWindow);
        (IdentityRecovery.Request memory p, T.Authorization memory a) =
            this.dsRequest(dsProtected, dsPost);
        Appeal27.Document memory d = _dsDocument(p);
        d.findings[0].parties[0] = address(delegateSafe);
        _dsBadDocument(p, d);
        d = _dsDocument(p);
        d.causeHash = keccak256("unrelated cause");
        _dsBadDocument(p, d);
        d = _dsDocument(p);
        d.contestRecordHash = keccak256("unrelated actual33");
        _dsBadDocument(p, d);
        d = _dsDocument(p);
        d.transitionRecordHash = dsOrigin;
        d.vestingCommitment = _snapshot(dsOrigin).commitment;
        _dsBadDocument(p, d);
        d = _dsDocument(p);
        d.requestCommitment = keccak256("another request or exclusion list");
        _dsBadDocument(p, d);
        d = _dsDocument(p);
        Appeal27.Finding memory requiredFinding = d.findings[0];
        address[] memory parties = new address[](1);
        parties[0] = address(delegateSafe);
        Appeal27.Finding memory extra = Appeal27.Finding(dsRetained, parties);
        d.findings = new Appeal27.Finding[](2);
        (d.findings[0], d.findings[1]) =
            dsProtected < dsRetained ? (requiredFinding, extra) : (extra, requiredFinding);
        _dsBadDocument(p, d);
        d = _dsDocument(p);
        bytes32[] memory originalList = p.supersededRecordHashes;
        IdentityRecovery.Request memory missing = p;
        missing.supersededRecordHashes = _dsList(dsProtected, dsRetained);
        d.requestCommitment = Appeal27.requestCommitment(missing);
        _dsBadDocument(missing, d);
        p.supersededRecordHashes = originalList;
        (p, a) = _dsPublishAppeal(p);
        _dsElect(p, a, dsRetained);
        _dsRegister(p, a, true);
        _dsRecover(p, a, dsRetained, false);
    }

    function _dsAppealRevision(bool root) private {
        _dsStart(0);
        this.dsCompromise(dsWindow);
        (IdentityRecovery.Request memory p, T.Authorization memory a) =
            this.dsRequest(dsProtected, 0);
        (p, a) = _dsPublishAppeal(p);
        _dsElect(p, a, dsRetained);
        _dsRegister(p, a, true);
        if (root) {
            ArtistAppealUnitGovernance(manager.governanceAuthority())
                .configureRoot(address(delegateSafe));
            ArtistAppealUnitGovernance(manager.governanceAuthority()).configureRoot(address(this));
        } else {
            ArtistAppealUnitRoles(suite.roleRegistry).setAppeal(address(this), false);
            vm.expectRevert(
                abi.encodeWithSelector(Appeal27.InvalidGuardianAppeal.selector, bytes32(0))
            );
            ingress.identityRecoveryContext(p, a);
            ArtistAppealUnitRoles(suite.roleRegistry).setAppeal(address(this), true);
        }
        this.dsAt(scheduled.notBefore);
        scheduled.status = GovernanceActionStatus.EXECUTED;
        _publish();
        bytes32 roots = _roots();
        vm.expectRevert(abi.encodeWithSelector(A.InvalidRecoveryAction.selector, currentId));
        this.executeRegistered(p, a);
        _inactive();
        require(
            roots == _roots() && ingress.latestIdentityRecovery(artistId) == 0
                && _status(dsProtected).recoveryRecordHash == 0 && _dsHistory() == dsFrozenHistory,
            "restoring membership cannot restore a queued witness from an older revision"
        );
    }

    function testArt27AppealRoleRevisionDoesNotReviveQueuedAction() public {
        _dsAppealRevision(false);
    }

    function testArt27AppealRootRevisionDoesNotReviveQueuedAction() public {
        _dsAppealRevision(true);
    }

    function _dsForbidden(uint32 forbidden) private {
        this.dsSetup(forbidden);
        this.dsCompromise(dsWindow);
        (IdentityRecovery.Request memory p,) = this.dsRequest(dsProtected, 0);
        Appeal27.Document memory d = _dsDocument(p);
        p.evidenceHash = _dsPublisher().publish(d);
        T.Authorization memory a = _acceptance(p);
        bytes32 roots = _roots();
        vm.expectRevert(
            abi.encodeWithSelector(
                Succ27.ForbiddenCapability.selector, artistId, uint32(256), dsDirective
            )
        );
        ingress.identityRecoveryContext(p, a);
        require(
            roots == _roots() && _status(dsProtected).recoveryRecordHash == 0,
            "exact original directive blocks guardian maintenance"
        );
    }

    function testArt27GuardianMaintenanceDirectiveRejectsAppeal() public {
        _dsForbidden(256);
    }

    function testArt27BothGuardianPermissionsForbiddenRejectsAppeal() public {
        _dsForbidden(2304);
    }

    function testArt27DisplacementOnlyDirectiveAllowsGuardianMaintenance() public {
        this.dsSetup(2048);
        this.dsCompromise(dsWindow);
        (IdentityRecovery.Request memory p, T.Authorization memory a) =
            this.dsRequest(dsProtected, 0);
        (p, a) = _dsPublishAppeal(p);
        _dsElect(p, a, dsRetained);
        _dsRegister(p, a, true);
        _dsRecover(p, a, dsRetained, false);
        require(
            ingress.operativeEstateDirective(artistId) == dsDirective,
            "original displacement restriction remains unchanged"
        );
    }

    function testArt27EmptyListCompatibilityKeepsDesignatedOriginAndExactReceipts() public {
        _dsStart(0);
        this.dsCompromise(dsWindow);
        (IdentityRecovery.Request memory p, T.Authorization memory a) = this.dsRequest(0, 0);
        require(p.supersededRecordHashes.length == 0, "original empty-list profile");
        require(
            keccak256(abi.encode(ingress.identityRecoveryContext(p, a)))
                == keccak256(abi.encode(_dsOriginalEmptyContext(p, a))),
            "literal original empty-list facts, wrappers and intent remain byte-identical"
        );
        _dsRegister(p, a, false);
        _dsRecover(p, a, dsProtected, true);
    }

    function _dsOriginalEmptyContext(IdentityRecovery.Request memory p, T.Authorization memory a)
        private
        view
        returns (IdentityRecovery.Context memory c)
    {
        OriginalDormancyFacts27 memory f;
        (f.notice,, f.terminal) = IStreamArtistDormancy(address(ingress)).dormancyRecord(dsNotice);
        f.transition = ingress.artistTransitionState(dsOrigin);
        f.vesting = _snapshot(dsOrigin);
        (f.guardians,,,) = IStreamArtistGuardianHistory(suite.owners[2])
            .guardianHistoryState(artistId, 0, address(0), 0);
        f.designation = ingress.successorDesignationRecord(dsPlan);
        f.paired = ingress.estateDirectiveRecord(f.designation.terms.directiveHash);
        f.forbidden = ingress.estateDirectiveRecord(f.terminal.plan.directive);
        Dismissal.Cause memory cause = ingress.currentIdentityContestCause(artistId);
        f.contest = IStreamArtistIdentityContestOwner(suite.owners[2])
            .identityContestRecord(cause.facts.referenceHash);
        T.Identity memory principal = IStreamArtistIdentityOwner(suite.owners[2]).identity(artistId);
        R.GuardianRecord memory guardian = ingress.guardianSetRecord(dsProtected);
        require(
            dsTerminal == dsOrigin && f.vesting.previousTransitionRecordHash == 0
                && f.guardians.count == 2 && guardian.terms.minContestSeconds == 20 days
                && f.terminal.delegationEpoch == 1 && p.expectedResolutionHash == 0,
            "literal compatibility oracle uses the unchanged original fixture inputs"
        );
        bytes32 predecessor = keccak256(
            abi.encode(
                keccak256("6529STREAM_ARTIST_RECOVERY_FIRST_DORMANCY_FACTS_V1"),
                block.chainid,
                address(ingress),
                suite.owners[2],
                f
            )
        );
        c.causeHash = cause.causeHash;
        c.incumbent = principal.authorityAddress;
        c.postContestSeconds = 20 days;
        c.standingTailSeconds = 90 days;
        c.timingRevision = 1;
        c.delegationEpoch = 1;
        c.scopeHash = keccak256(
            abi.encode(
                keccak256("6529STREAM_ARTIST_IDENTITY_RECOVERY_SCOPE_V2"),
                block.chainid,
                address(ingress),
                suite.owners[2],
                artistId
            )
        );
        c.oldValueHash = keccak256(
            abi.encode(
                keccak256("6529STREAM_ARTIST_IDENTITY_RECOVERY_STATE_V2"),
                c.scopeHash,
                cause,
                principal,
                p.expectedResolutionHash,
                c.postContestSeconds,
                c.standingTailSeconds,
                c.timingRevision,
                c.delegationEpoch
            )
        );
        c.oldValueHash = keccak256(
            abi.encode(
                keccak256("6529STREAM_ARTIST_GUARDED_RECOVERY_STATE_V1"),
                c.oldValueHash,
                guardian,
                uint64(2)
            )
        );
        c.oldValueHash = keccak256(
            abi.encode(
                keccak256("6529STREAM_ARTIST_RECOVERY_GUARDIAN_HISTORY_CONTEXT_V1"),
                c.oldValueHash,
                f.guardians
            )
        );
        c.oldValueHash = keccak256(
            abi.encode(
                keccak256("6529STREAM_ARTIST_RECOVERY_FIRST_DORMANCY_CONTEXT_V1"),
                c.oldValueHash,
                predecessor
            )
        );
        c.newValueHash = keccak256(
            abi.encode(
                keccak256("6529STREAM_ARTIST_IDENTITY_RECOVERY_INTENT_V2"),
                c.scopeHash,
                c.oldValueHash,
                p,
                a.nonce,
                a.time
            )
        );
    }

    function testArt27EarlierSuccessorGuardianBecomesProtectedAtNextActualRotation() public {
        _dsStart(0);
        bytes32 intermediate = this.dsGuardian(address(artist), 15 days, 2000);
        this.dsAt(dsWindow);
        this.dsRotate(71206);
        this.dsCompromise(dsWindow);
        (IdentityRecovery.Request memory p, T.Authorization memory a) =
            this.dsRequest(intermediate, 0);
        require(
            IStreamArtistGuardianAppealOwner(suite.owners[2])
                .guardianRecoveryAuthorityRole(artistId, p.supersededRecordHashes)
            == Appeal27.APPEAL,
            "guardian predating actual latest32 is protected even though written after original43"
        );
        vm.expectRevert(
            abi.encodeWithSelector(Appeal27.InvalidGuardianAppeal.selector, p.evidenceHash)
        );
        ingress.identityRecoveryContext(p, a);
        Appeal27.Document memory d = _dsDocument(p);
        d.findings[0].guardianRecordHash = intermediate;
        d.findings[0].parties[0] = ingress.guardianSetRecord(intermediate).terms.guardians[0];
        p.evidenceHash = _dsPublisher().publish(d);
        a = _acceptance(p);
        _dsElect(p, a, dsProtected);
        _dsRegister(p, a, true);
        _dsRecover(p, a, dsProtected, false);
    }
}

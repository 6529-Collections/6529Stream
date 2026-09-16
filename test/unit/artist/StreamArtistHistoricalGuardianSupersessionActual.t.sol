// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./StreamArtistEstateHistoryBatchActual.t.sol";
import "./ArtistGuardianAppealFixture.sol";
import {
    StreamArtistGuardianAppealTypes as Appeal
} from "../../../smart-contracts/interfaces/stream/artist/StreamArtistGuardianAppealTypes.sol";
import {
    IStreamArtistGuardianAppealEvidence,
    IStreamArtistGuardianAppealBinding,
    IStreamArtistGuardianAppealOwner
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistGuardianAppealEvidence.sol";

/// @notice Actual historical/estate guardian adjudication, complete election and registered recovery.
/// @dev Artist, Safe and Archive are real; Core/governance/role facts and aggregate CREATE are unit boundaries.
contract StreamArtistHistoricalGuardianSupersessionActualTest is
    StreamArtistEstateHistoryBatchActualTest,
    ArtistGuardianAppealFixture
{
    bytes32 private ssTerminal;
    bytes32 private ssOrigin;
    bytes32 private ssExcluded;
    bytes32 private ssRetained;
    bytes32 private ssOriginals;
    OfficialSafe private ssRetainedSafe;
    uint256[] private ssRetainedKeys;

    function supersessionLivingStage(bytes32 previous, uint256 salt) external onlySelf {
        _newRotationSafe(salt);
        ssTerminal = _stageRotation(previous);
    }

    function supersessionLivingExecute() external onlySelf {
        _executeTimedRotation(ssTerminal);
        _adoptRotatedSafe();
    }

    function supersessionGuardian(uint256 nonce, uint64 floor) external onlySelf returns (bytes32) {
        address[] memory members = new address[](1);
        members[0] = address(artist);
        return _guardianRecord(members, 1, floor, nonce);
    }

    function supersessionSetup(uint8 mode) external onlySelf {
        _deployAppealSuite();
        if (mode == 0) {
            _delegateSetup();
            address[] memory members = new address[](1);
            members[0] = address(delegateSafe);
            _guardianRecord(members, 1, 10 days, 900);
            this.supersessionLivingStage(0, 63001);
            this.supersessionLivingExecute();
            ssRetained = this.supersessionGuardian(1000, 11 days);
            ssRetainedSafe = artist;
            ssRetainedKeys = keys;
            this.historyWarp(ingress.artistTransitionState(ssTerminal).postWindowEndsAt);
            this.supersessionLivingStage(ssTerminal, 63002);
            this.supersessionLivingExecute();
            ssExcluded = this.supersessionGuardian(1100, 20 days);
        } else if (mode == 1) {
            this.historySetup(1, 4095, true);
            ssOrigin = ingress.currentAuthorityCapabilities(artistId).activationRecordHash;
            ssTerminal = ssOrigin;
            (,,, ssRetained) = ingress.guardianSet(artistId);
            ssExcluded = this.supersessionGuardian(2000, 20 days);
        } else {
            this.rotatedEstateSetup(4095, false, true, 1);
            ssOrigin = erOrigin;
            ssRetained = erGuardian;
            ssRetainedSafe = artist;
            ssRetainedKeys = keys;
            this.historyWarp(erWindow);
            this.rotatedEstateStage(erTerminal, false, 63003);
            ssTerminal = erTerminal;
            ssExcluded = this.supersessionGuardian(2100, 20 days);
        }
        R.GuardianRecord memory retained = ingress.guardianSetRecord(ssRetained);
        require(
            retained.provisional.transitionRecordHash != 0
                && retained.provisional.transitionRecordHash != ssTerminal,
            "retained eligible guardian belongs to an actual earlier transition"
        );
    }

    function supersessionCompromise() external onlySelf {
        vm.warp(ingress.artistTransitionState(ssTerminal).postWindowEndsAt);
        ArtistAppealUnitRoles(suite.roleRegistry).setArbiter(address(artist), true);
        ArtistUnitGovernance authority = ArtistUnitGovernance(manager.governanceAuthority());
        bytes32 evidence = keccak256(abi.encode("historical supersession evidence", ssTerminal));
        bytes32 reason = keccak256(abi.encode("historical supersession reason", ssTerminal));
        authority.configureContestReads(
            suite.roleRegistry, address(artist), reason, "urn:unit:history-supersession"
        );
        (bytes32 scope, bytes32 oldHash, bytes32 newHash) =
            ingress.identityContestGovernanceContext(artistId, ssTerminal, evidence, reason);
        authority.executeModuleContext(
            address(ingress),
            abi.encodeCall(
                IStreamArtistIdentityContest.contestArtistIdentity,
                (artistId, ssTerminal, evidence, reason)
            ),
            1,
            scope,
            oldHash,
            newHash
        );
        Dismissal.Cause memory cause = ingress.currentIdentityContestCause(artistId);
        require(
            cause.facts.executedTransitionHash == ssTerminal && cause.facts.kind == 1,
            "original op33 selects the exact current execution, never an earlier caller cutoff"
        );
    }

    function supersessionTerms(bool preVesting)
        external
        onlySelf
        returns (IdentityRecovery.Request memory p, T.Authorization memory a)
    {
        _newRotationSafe(63011);
        Dismissal.Cause memory cause = ingress.currentIdentityContestCause(artistId);
        p = IdentityRecovery.Request(
            artistId,
            address(rotationSafe),
            cause.facts.authorityClass,
            cause.causeHash,
            ingress.latestIdentityContestDismissal(artistId),
            cause.facts.evidenceHash,
            cause.facts.reasonHash,
            new bytes32[](1)
        );
        p.supersededRecordHashes[0] = preVesting ? ssRetained : ssExcluded;
        a = _acceptance(p);
    }

    function _ssPublisher() private view returns (IStreamArtistGuardianAppealEvidence publisher) {
        address child = StreamArtistIdentityAuthority(suite.owners[2]).identityRecoveryExtension();
        (address target, bytes32 codeHash) =
            IStreamArtistGuardianAppealBinding(child).guardianAppealEvidenceBinding();
        require(target.codehash == codeHash && codeHash != 0, "canonical fixed evidence child");
        publisher = IStreamArtistGuardianAppealEvidence(target);
    }

    function supersessionAppeal(IdentityRecovery.Request calldata original, bool wrongCutoff)
        external
        onlySelf
        returns (IdentityRecovery.Request memory p)
    {
        p = original;
        Dismissal.Cause memory cause = ingress.currentIdentityContestCause(artistId);
        R.GuardianRecord memory excluded = ingress.guardianSetRecord(p.supersededRecordHashes[0]);
        Appeal.Finding[] memory findings = new Appeal.Finding[](1);
        findings[0] = Appeal.Finding(excluded.recordHash, excluded.terms.guardians);
        Appeal.Document memory document = Appeal.Document(
            Appeal.requestCommitment(p),
            cause.causeHash,
            cause.facts.referenceHash,
            _snapshot(ssTerminal).commitment,
            ssTerminal,
            keccak256("explicit historical hostile guardian finding"),
            findings
        );
        if (wrongCutoff) {
            document.vestingCommitment =
            _snapshot(excluded.provisional.transitionRecordHash).commitment;
        }
        bytes32 before_ = _roots();
        p.evidenceHash = _ssPublisher().publish(document);
        require(before_ == _roots(), "publication grants no owner authority");
    }

    function _ssElection(
        IdentityRecovery.Request memory p,
        T.Authorization memory a,
        bytes32 selected
    ) private {
        IStreamArtistGuardianSelectionPreparation prep = _selectionPreparation();
        bytes32 key = prep.begin(artistId, ssTerminal, p.supersededRecordHashes);
        (GH.Head memory head,,,) = IStreamArtistGuardianHistory(suite.owners[2])
            .guardianHistoryState(artistId, 0, address(0), 0);
        bytes32 roots = _roots();
        vm.expectRevert(
            abi.encodeWithSelector(
                Selection.IncompleteGuardianSelection.selector, key, uint64(0), head.count
            )
        );
        ingress.identityRecoveryContext(p, a);
        Selection.Progress memory progress = prep.continueSelection(key, 1);
        require(
            !progress.complete && progress.processed == 1, "first chunk is not a complete election"
        );
        vm.expectRevert(
            abi.encodeWithSelector(
                Selection.IncompleteGuardianSelection.selector, key, uint64(1), head.count
            )
        );
        ingress.identityRecoveryContext(p, a);
        progress = prep.continueSelection(key, head.count);
        require(
            progress.complete && progress.processed == head.count
                && progress.selectedRecordHash == selected,
            "complete canonical history elects highest eligible retained nonce across actual associations"
        );
        require(roots == _roots(), "preparation does not mutate owner roots");
    }

    function _ssHistory() private view returns (bytes32) {
        (GH.Head memory head,,,) = IStreamArtistGuardianHistory(suite.owners[2])
            .guardianHistoryState(artistId, 0, address(0), 0);
        bytes32 result;
        for (uint64 index = 1; index <= head.count; ++index) {
            (, GH.Entry memory entry,,) = IStreamArtistGuardianHistory(suite.owners[2])
                .guardianHistoryState(artistId, index, address(0), 0);
            result =
                keccak256(abi.encode(result, entry, ingress.guardianSetRecord(entry.recordHash)));
        }
        return keccak256(
            abi.encode(
                result, head, _snapshot(ssTerminal), ingress.artistTransitionState(ssTerminal)
            )
        );
    }

    function supersessionRegister(
        IdentityRecovery.Request calldata p,
        T.Authorization calldata a,
        bool appeal
    ) external onlySelf {
        GovernanceCall[] memory calls = _schedule(
            keccak256("historical guardian exact registered recovery"), p, a
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
        ssOriginals = _ssHistory();
    }

    function supersessionExecute(
        IdentityRecovery.Request calldata p,
        T.Authorization calldata a,
        bytes32 selected,
        bool retry
    ) external onlySelf {
        Estate.AuthorityCapabilities memory capabilities;
        if (ssOrigin != 0) capabilities = ingress.currentAuthorityCapabilities(artistId);
        T.Snapshot memory before_ = _ownerSnapshot();
        vm.warp(scheduled.notBefore);
        scheduled.status = GovernanceActionStatus.EXECUTED;
        _publish();
        bytes32 roots = _roots();
        if (retry) {
            _overflow();
            this.executeRegistered(p, a);
            _inactive();
            (bool used,) = ingress.rotationAcceptanceNonceState(artistId, p.newAddress, a.nonce);
            require(
                !used && roots == _roots() && _ssHistory() == ssOriginals
                    && _status(p.supersededRecordHashes[0]).recoveryRecordHash == 0,
                "late Archive failure restores election, exclusion, roots, history and acceptance"
            );
            vm.roll(restoreBlock);
        }
        vm.recordLogs();
        bytes32 recovered = this.executeRegistered(p, a);
        _assertSnapshot(_snapshot(recovered), 35, before_, vm.getRecordedLogs());
        (,,, bytes32 actual) = ingress.guardianSet(artistId);
        require(
            actual == selected && _ssHistory() == ssOriginals
                && _status(p.supersededRecordHashes[0]).recoveryRecordHash == recovered
                && _status(selected).recoveryRecordHash == 0,
            "actual op35 applies only exact exclusions and restores the complete elected head"
        );
        if (ssOrigin != 0) {
            Estate.AuthorityCapabilities memory after_ =
                ingress.currentAuthorityCapabilities(artistId);
            require(
                after_.authorityClass == 3 && after_.status == 3
                    && after_.authorityAddress == p.newAddress
                    && after_.activationRecordHash == capabilities.activationRecordHash
                    && after_.effectiveCapabilities == capabilities.effectiveCapabilities,
                "guardian adjudication does not widen the original estate capability mask"
            );
        }
        (bytes32 primary, bytes32 occurrence, bytes32 secondary) =
            StreamArtistIdentityAuthority(suite.owners[2]).identityRecoveryReceipts(recovered);
        require(
            primary != 0 && occurrence != 0 && secondary != 0 && primary != secondary,
            "original two receipts"
        );
        roots = _roots();
        vm.expectRevert(
            abi.encodeWithSelector(IdentityRecovery.InvalidIdentityRecovery.selector, artistId)
        );
        this.executeRegistered(p, a);
        require(roots == _roots(), "same action/request/acceptance cannot replay");
    }

    function _ssPost(uint8 mode) private {
        this.supersessionSetup(mode);
        this.supersessionCompromise();
        (IdentityRecovery.Request memory p, T.Authorization memory a) =
            this.supersessionTerms(false);
        require(
            IStreamArtistGuardianAppealOwner(suite.owners[2])
                .guardianRecoveryAuthorityRole(artistId, p.supersededRecordHashes)
            == Appeal.ARBITER,
            "later admission is ordinary Arbiter tier"
        );
        _ssElection(p, a, ssRetained);
        require(
            ingress.identityRecoveryContext(p, a).postContestSeconds
                == ingress.guardianSetRecord(ssRetained).terms.minContestSeconds,
            "historical elected guardian sets the original recovery minimum"
        );
        this.supersessionRegister(p, a, false);
        this.supersessionExecute(p, a, ssRetained, true);
    }

    function testHistoricalSupersessionLivingRestoresEarlierRotationGuardian() public {
        _ssPost(0);
    }

    function testHistoricalSupersessionEstateRestoresLivingAssociationAndArchiveRetry() public {
        _ssPost(1);
    }

    function testHistoricalSupersessionRotatedEstateRestoresIntermediateClass3Guardian() public {
        _ssPost(2);
    }

    function testHistoricalSupersessionEstateAppealRequiresExactDocumentAndRoot() public {
        this.supersessionSetup(1);
        this.supersessionCompromise();
        (IdentityRecovery.Request memory p, T.Authorization memory a) = this.supersessionTerms(true);
        require(
            IStreamArtistGuardianAppealOwner(suite.owners[2])
                .guardianRecoveryAuthorityRole(artistId, p.supersededRecordHashes) == Appeal.APPEAL,
            "original pre-estate prefix never becomes ordinary Arbiter evidence"
        );
        vm.expectRevert(
            abi.encodeWithSelector(Appeal.InvalidGuardianAppeal.selector, p.evidenceHash)
        );
        ingress.identityRecoveryContext(p, a);
        p = this.supersessionAppeal(p, false);
        // A correctly published document still carries no role authority.
        vm.expectRevert(abi.encodeWithSelector(Appeal.InvalidGuardianAppeal.selector, bytes32(0)));
        ingress.identityRecoveryContext(p, a);
        ArtistAppealUnitRoles(suite.roleRegistry).setAppeal(address(this), true);
        // Excluding the earlier record does not need a head rewind: the current highest remains.
        this.supersessionRegister(p, a, true);
        this.supersessionExecute(p, a, ssExcluded, true);
    }

    function testHistoricalSupersessionRejectsEarlierCutoffThenSameAcceptanceRetries() public {
        this.supersessionSetup(2);
        this.supersessionCompromise();
        (IdentityRecovery.Request memory p, T.Authorization memory a) = this.supersessionTerms(true);
        ArtistAppealUnitRoles(suite.roleRegistry).setAppeal(address(this), true);
        IdentityRecovery.Request memory wrong = this.supersessionAppeal(p, true);
        vm.expectRevert(
            abi.encodeWithSelector(Appeal.InvalidGuardianAppeal.selector, wrong.evidenceHash)
        );
        ingress.identityRecoveryContext(wrong, a);
        bytes32 roots = _roots();
        p = this.supersessionAppeal(p, false);
        require(roots == _roots(), "correct evidence does not consume the original Safe acceptance");
        this.supersessionRegister(p, a, true);
        this.supersessionExecute(p, a, ssExcluded, false);
    }

    function testHistoricalSupersessionRetainedLifetimeSafeVetoSurvivesNewCutoff() public {
        this.supersessionSetup(2);
        this.supersessionCompromise();
        (IdentityRecovery.Request memory p, T.Authorization memory a) =
            this.supersessionTerms(false);
        _ssElection(p, a, ssRetained);
        this.supersessionRegister(p, a, false);
        this.historyWarp(scheduled.notBefore);
        require(
            executeSafe(
                ssRetainedSafe,
                ssRetainedKeys,
                address(ingress),
                0,
                abi.encodeCall(
                    IStreamArtistRecoveryAction.vetoIdentityRecovery,
                    (artistId, keccak256("retained intermediate guardian veto"))
                ),
                0
            ),
            "original retained Safe membership remains in complete veto history"
        );
        scheduled.status = GovernanceActionStatus.EXECUTED;
        _publish();
        vm.expectRevert(abi.encodeWithSelector(A.RecoveryActionVetoed.selector, currentId));
        this.executeRegistered(p, a);
        _inactive();
        require(
            _status(ssExcluded).recoveryRecordHash == 0 && _ssHistory() == ssOriginals,
            "retained veto prevents permanent exclusion and authority movement"
        );
    }
}

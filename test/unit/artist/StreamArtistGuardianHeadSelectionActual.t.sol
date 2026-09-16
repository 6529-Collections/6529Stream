// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "./StreamArtistGuardianSupersessionActual.t.sol";
import {
    StreamArtistGuardianSelectionDeployment
} from "../../../smart-contracts/domains/artist/StreamArtistGuardianSelectionDeployment.sol";
import {
    StreamArtistRecoveryExtensionDeployment
} from "../../../smart-contracts/domains/artist/StreamArtistRecoveryExtensionDeployment.sol";

contract StreamArtistGuardianHeadSelectionActualTest is StreamArtistGuardianSupersessionActualTest {
    bytes32 private middleGuardian;

    function _headCase(bool emptyMiddle) private {
        _delegateSetup();
        address[] memory members = new address[](1);
        members[0] = address(delegateSafe);
        lifetimeGuardian = _guardianRecord(members, 1, 0, 900);
        _newRotationSafe(43001);
        soleRotation = _stageRotation(0);
        _executeTimedRotation(soleRotation);
        _adoptRotatedSafe();
        require(_snapshot(soleRotation).guardians.count == 1, "original pre-vesting prefix");
        members[0] = address(artist);
        attackerGuardian = _guardianRecord(members, 1, 20 days, 2000);
        members = new address[](emptyMiddle ? 0 : 1);
        if (!emptyMiddle) members[0] = address(delegateSafe);
        middleGuardian = _guardianRecord(members, emptyMiddle ? 0 : 1, 10 days, 1500);
        vm.warp(ingress.rotationRecord(soleRotation).transition.postWindowEndsAt);
        (,,, bytes32 selected) = ingress.guardianSet(artistId);
        require(
            selected == attackerGuardian, "higher attacker head matured; middle stayed unselected"
        );
        _newRotationSafe(43002);
        ArtistUnitGovernance authority = ArtistUnitGovernance(manager.governanceAuthority());
        ArtistUnitRoles(suite.roleRegistry).setArbiter(address(artist), true);
        authority.configureContestReads(
            suite.roleRegistry, address(artist), keccak256("compromise reason"), "urn:unit:contest"
        );
        (bytes32 scope, bytes32 oldHash, bytes32 newHash) = ingress.identityContestGovernanceContext(
            artistId, soleRotation, keccak256("compromise evidence"), keccak256("compromise reason")
        );
        authority.executeModuleContext(
            address(ingress), _contestData(soleRotation), 1, scope, oldHash, newHash
        );
        guardianBeforeHash = keccak256(abi.encode(ingress.guardianSetRecord(attackerGuardian)));
        rotationBeforeHash = keccak256(abi.encode(ingress.rotationRecord(soleRotation)));
        _headSizes();
    }

    function _headSizes() private view {
        _sizes();
        require(
            address(StreamArtistGuardianSelectionDeployment).code.length <= 24576,
            "selection factory size"
        );
        require(
            address(StreamArtistRecoveryExtensionDeployment).code.length <= 24576,
            "recovery child factory size"
        );
        require(
            address(_selectionPreparation()).code.length <= 24576,
            "selection preparation runtime size"
        );
    }

    function _prepareElection(IdentityRecovery.Request memory p, T.Authorization memory a)
        private
        returns (bytes32 key)
    {
        IStreamArtistGuardianSelectionPreparation preparation = _selectionPreparation();
        key = preparation.begin(artistId, soleRotation, p.supersededRecordHashes);
        bytes32 roots = _roots();
        vm.expectRevert(
            abi.encodeWithSelector(
                Selection.IncompleteGuardianSelection.selector, key, uint64(0), uint64(3)
            )
        );
        ingress.identityRecoveryContext(p, a);
        Selection.Progress memory progress = preparation.continueSelection(key, 1);
        require(
            progress.processed == 1 && progress.selectedRecordHash == lifetimeGuardian
                && !progress.complete
        );
        vm.expectRevert(
            abi.encodeWithSelector(
                Selection.IncompleteGuardianSelection.selector, key, uint64(1), uint64(3)
            )
        );
        ingress.identityRecoveryContext(p, a);
        progress = preparation.continueSelection(key, 2);
        require(
            progress.complete && progress.processed == 3
                && progress.selectedRecordHash == middleGuardian
        );
        require(_roots() == roots, "external election creates no owner authority/revision");
        (,,, bytes32 current) = ingress.guardianSet(artistId);
        require(current == attackerGuardian, "sealed computation does not mutate operative head");
        require(
            ingress.identityRecoveryContext(p, a).postContestSeconds == 10 days,
            "restored selection sets post-vesting window"
        );
    }

    function testActualHeadSupersessionRestoresUnselectedRecordAndFutureSelection() public {
        _headCase(false);
        IdentityRecovery.Request memory p = _nonemptyTerms();
        T.Authorization memory a = _acceptance(p);
        bytes32 electionKey = _prepareElection(p, a);
        GovernanceCall[] memory calls = _schedule(keccak256("actual restored head"), p, a);
        ingress.registerIdentityRecoveryAction(currentId, calls, p, a);
        (Selection.Result memory result, R.GuardianRecord memory restored) = IStreamArtistGuardianSelectionOwner(
                suite.owners[2]
            ).guardianRecoverySelection(currentId);
        require(
            result.sourceKey == electionKey && result.commitment != 0
                && result.selectedRecordHash == middleGuardian
        );
        require(restored.recordHash == middleGuardian && restored.nonce == 1500);
        (A.Association memory association,,,) =
            ingress.identityRecoveryActionState(artistId, currentId);
        require(
            association.guardian.recordHash == attackerGuardian,
            "original association retains pre-recovery operative fact"
        );
        vm.expectRevert();
        this.vetoByAttacker(keccak256("excluded current head"));
        vm.warp(scheduled.notBefore);
        scheduled.status = GovernanceActionStatus.EXECUTED;
        _publish();
        bytes32 roots = _roots();
        T.Snapshot memory before_ = _ownerSnapshot();
        _overflow();
        this.executeRegistered(p, a);
        _inactive();
        (,,, bytes32 current) = ingress.guardianSet(artistId);
        (bool used,) = ingress.rotationAcceptanceNonceState(artistId, p.newAddress, a.nonce);
        require(
            current == attackerGuardian && !used && _roots() == roots
                && _status(attackerGuardian).recoveryRecordHash == 0,
            "late Archive restores old heads, acceptance, status and owner state"
        );
        vm.roll(restoreBlock);
        vm.recordLogs();
        bytes32 recovered = this.executeRegistered(p, a);
        _assertSnapshot(_snapshot(recovered), 35, before_, vm.getRecordedLogs());
        (,,, current) = ingress.guardianSet(artistId);
        require(
            current == middleGuardian && _status(attackerGuardian).recoveryRecordHash == recovered
        );
        IdentityRecovery.Record memory record = ingress.identityRecoveryRecord(recovered);
        require(
            record.postContestSeconds == 10 days
                && record.fields.supersededRecordsHash
                    == RecoveryHashes.supersession(p.supersededRecordHashes)
        );
        (address prior, bytes32 standingGuardian, uint64 tail) =
            StreamArtistIdentityAuthority(suite.owners[2]).recoveryTransitionStanding(recovered);
        require(
            prior == record.fields.oldAddress && standingGuardian == middleGuardian
                && tail == record.standingTailSeconds
        );
        require(
            guardianBeforeHash == keccak256(abi.encode(ingress.guardianSetRecord(attackerGuardian)))
                && rotationBeforeHash
                    == keccak256(abi.encode(ingress.rotationRecord(soleRotation))),
            "executed original history unchanged"
        );
        address helper = address(_selectionPreparation());
        bytes memory helperCode = helper.code;
        vm.etch(helper, "");
        (prior, standingGuardian, tail) =
            StreamArtistIdentityAuthority(suite.owners[2]).recoveryTransitionStanding(recovered);
        require(
            prior == record.fields.oldAddress && standingGuardian == middleGuardian
                && tail == record.standingTailSeconds,
            "saved standing does not reread preparation liveness"
        );
        vm.etch(helper, helperCode);
        _adoptRotatedSafe();
        address[] memory members = new address[](1);
        members[0] = address(delegateSafe);
        bytes32 next = _guardianRecord(members, 1, 12 days, 1600);
        (,,, current) = ingress.guardianSet(artistId);
        require(current == middleGuardian, "new authority's candidate waits actual recovery window");
        vm.warp(ingress.artistTransitionState(recovered).postWindowEndsAt);
        (,,, current) = ingress.guardianSet(artistId);
        require(
            current == next && _status(attackerGuardian).recoveryRecordHash == recovered,
            "nonce below excluded head can become operative without resurrecting that head"
        );
        _headSizes();
    }

    function testActualRetainedPrefixVetoBlocksHeadSupersessionAfterNotBefore() public {
        _headCase(false);
        IdentityRecovery.Request memory p = _nonemptyTerms();
        T.Authorization memory a = _acceptance(p);
        _prepareElection(p, a);
        GovernanceCall[] memory calls =
            _schedule(keccak256("retained prefix rejects head recovery"), p, a);
        ingress.registerIdentityRecoveryAction(currentId, calls, p, a);
        vm.warp(scheduled.notBefore + 1);
        this.vetoByGuardian(keccak256("retained lifetime and middle memberships"));
        (, A.Veto memory veto,,) = ingress.identityRecoveryActionState(artistId, currentId);
        require(veto.vetoer == address(delegateSafe));
        bytes32 roots = _roots();
        scheduled.status = GovernanceActionStatus.EXECUTED;
        _publish();
        vm.expectRevert(abi.encodeWithSelector(A.RecoveryActionVetoed.selector, currentId));
        this.executeRegistered(p, a);
        _inactive();
        (,,, bytes32 current) = ingress.guardianSet(artistId);
        require(
            current == attackerGuardian && _roots() == roots
                && _status(attackerGuardian).recoveryRecordHash == 0
        );
    }

    function testActualEligibleEmptySetRetainsNonzeroRestoredIdentity() public {
        _headCase(true);
        IdentityRecovery.Request memory p = _nonemptyTerms();
        T.Authorization memory a = _acceptance(p);
        _prepareElection(p, a);
        GovernanceCall[] memory calls = _schedule(keccak256("restore admitted empty set"), p, a);
        ingress.registerIdentityRecoveryAction(currentId, calls, p, a);
        vm.warp(scheduled.notBefore);
        scheduled.status = GovernanceActionStatus.EXECUTED;
        _publish();
        bytes32 recovered = this.executeRegistered(p, a);
        (address[] memory members, uint32 threshold, uint64 minimum, bytes32 current) =
            ingress.guardianSet(artistId);
        require(
            members.length == 0 && threshold == 0 && minimum == 10 days && current == middleGuardian
        );
        (, bytes32 standingGuardian,) =
            StreamArtistIdentityAuthority(suite.owners[2]).recoveryTransitionStanding(recovered);
        require(
            standingGuardian == middleGuardian
                && ingress.identityRecoveryRecord(recovered).postContestSeconds == 10 days
        );
        _headSizes();
    }
}

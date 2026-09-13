// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "./ArtistGuardianAppealFixture.sol";
import {
    StreamArtistSuccessionTypes as Succ
} from "../../../smart-contracts/interfaces/stream/artist/StreamArtistSuccessionTypes.sol";
import {
    StreamArtistGuardianAppealTypes as Appeal
} from "../../../smart-contracts/interfaces/stream/artist/StreamArtistGuardianAppealTypes.sol";
import {
    IStreamArtistGuardianAppealEvidence,
    IStreamArtistGuardianAppealBinding,
    IStreamArtistGuardianAppealOwner
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistGuardianAppealEvidence.sol";
import {
    StreamArtistGuardianAppealDeployment
} from "../../../smart-contracts/domains/artist/StreamArtistGuardianAppealDeployment.sol";

contract StreamArtistGuardianAppealActualTest is ArtistGuardianAppealFixture {
    bytes32 private postGuardian;
    address private hostileParty;

    function _appealCase(uint32 forbidden, bool mixed) private {
        _deployAppealSuite();
        _delegateSetup();
        if (forbidden != 0) _directiveRecord(forbidden);
        address[] memory members = new address[](1);
        members[0] = address(delegateSafe);
        lifetimeGuardian = _guardianRecord(members, 1, 10 days, 900);
        hostileParty = address(artist);
        members[0] = hostileParty;
        attackerGuardian = _guardianRecord(members, 1, 20 days, 1000);
        _newRotationSafe(44001);
        soleRotation = _stageRotation(0);
        _executeTimedRotation(soleRotation);
        _adoptRotatedSafe();
        require(_snapshot(soleRotation).guardians.count == 2, "exact pre-vesting history");
        if (mixed) {
            members[0] = address(artist);
            postGuardian = _guardianRecord(members, 1, 25 days, 1100);
        }
        vm.warp(ingress.rotationRecord(soleRotation).transition.postWindowEndsAt);
        _newRotationSafe(44002);
        ArtistAppealUnitRoles(suite.roleRegistry).setArbiter(address(artist), true);
        ArtistAppealUnitRoles(suite.roleRegistry).setAppeal(address(this), true);
        ArtistUnitGovernance authority = ArtistUnitGovernance(manager.governanceAuthority());
        authority.configureContestReads(
            suite.roleRegistry,
            address(artist),
            keccak256("compromise reason"),
            "urn:unit:appeal-contest"
        );
        (bytes32 scope, bytes32 oldHash, bytes32 newHash) = ingress.identityContestGovernanceContext(
            artistId, soleRotation, keccak256("compromise evidence"), keccak256("compromise reason")
        );
        authority.executeModuleContext(
            address(ingress), _contestData(soleRotation), 1, scope, oldHash, newHash
        );
        require(
            ArtistAppealUnitGovernance(address(authority)).owner() == address(this),
            "same graph root"
        );
        require(
            ArtistAppealUnitRoles(suite.roleRegistry).owner() == address(authority),
            "actual suite role owner"
        );
        guardianBeforeHash = keccak256(abi.encode(ingress.guardianSetRecord(attackerGuardian)));
        rotationBeforeHash = keccak256(abi.encode(ingress.rotationRecord(soleRotation)));
    }

    function _publisher() private view returns (IStreamArtistGuardianAppealEvidence p) {
        address child = StreamArtistIdentityAuthority(suite.owners[2]).identityRecoveryExtension();
        (address target, bytes32 hash) =
            IStreamArtistGuardianAppealBinding(child).guardianAppealEvidenceBinding();
        require(target.codehash == hash && hash != 0, "fixed evidence runtime");
        p = IStreamArtistGuardianAppealEvidence(target);
        require(
            p.owner() == suite.owners[2] && p.artistRegistry() == address(ingress),
            "fixed evidence graph"
        );
    }

    function _appealTerms()
        private
        view
        returns (IdentityRecovery.Request memory p, Appeal.Document memory d)
    {
        p = _nonemptyTerms();
        if (postGuardian != 0) {
            p.supersededRecordHashes = new bytes32[](2);
            (p.supersededRecordHashes[0], p.supersededRecordHashes[1]) = attackerGuardian
                < postGuardian
                ? (attackerGuardian, postGuardian)
                : (postGuardian, attackerGuardian);
        }
        Dismissal.Cause memory cause = ingress.currentIdentityContestCause(artistId);
        d = Appeal.Document(
            Appeal.requestCommitment(p),
            cause.causeHash,
            cause.facts.referenceHash,
            _snapshot(soleRotation).commitment,
            soleRotation,
            keccak256("specific hostile guardian findings"),
            new Appeal.Finding[](1)
        );
        address[] memory parties = new address[](1);
        parties[0] = hostileParty;
        d.findings[0] = Appeal.Finding(attackerGuardian, parties);
    }

    function _publishAppeal()
        private
        returns (IdentityRecovery.Request memory p, T.Authorization memory a)
    {
        Appeal.Document memory d;
        (p, d) = _appealTerms();
        bytes32 roots = _roots();
        p.evidenceHash = _publisher().publish(d);
        require(
            _roots() == roots && ingress.latestIdentityRecovery(artistId) == 0,
            "publication grants no local authority/revision"
        );
        require(
            p.evidenceHash
                == Appeal.documentHash(block.chainid, address(ingress), suite.owners[2], d)
        );
        require(
            IStreamArtistGuardianAppealOwner(suite.owners[2])
                .guardianRecoveryAuthorityRole(artistId, p.supersededRecordHashes) == Appeal.APPEAL
        );
        a = _acceptance(p);
    }

    function _election(IdentityRecovery.Request memory p) private {
        bytes32 key =
            _selectionPreparation().begin(artistId, soleRotation, p.supersededRecordHashes);
        Selection.Progress memory progress = _selectionPreparation().continueSelection(key, 64);
        require(
            progress.complete && progress.selectedRecordHash == lifetimeGuardian,
            "complete appeal election preserves retained history"
        );
    }

    function _scheduleAppeal(IdentityRecovery.Request memory p, T.Authorization memory a)
        private
        returns (GovernanceCall[] memory calls)
    {
        calls = _schedule(keccak256("actual root appeal action"), p, a);
        scheduled.proposer = address(this);
        ArtistUnitGovernance(manager.governanceAuthority())
            .configureContestReads(
                suite.roleRegistry, address(this), p.reasonHash, scheduled.reasonURI
            );
        _publish();
    }

    function _appealSizes() private view {
        _sizes();
        require(
            address(StreamArtistGuardianAppealDeployment).code.length <= 24576,
            "appeal factory runtime"
        );
        require(address(_publisher()).code.length <= 24576, "appeal publisher runtime");
    }

    function testActualRootAppealRecoveryAndAtomicArchiveRetry() public {
        _appealCase(0, false);
        (IdentityRecovery.Request memory p, T.Authorization memory a) = _publishAppeal();
        _election(p);
        GovernanceCall[] memory calls = _scheduleAppeal(p, a);
        ingress.registerIdentityRecoveryAction(currentId, calls, p, a);
        bytes32 roots = _roots();
        vm.prank(hostileParty);
        vm.expectRevert(abi.encodeWithSelector(A.InvalidRecoveryGuardian.selector, hostileParty));
        ingress.vetoIdentityRecovery(artistId, keccak256("excluded pre-vesting party"));
        require(_roots() == roots && _status(attackerGuardian).recoveryRecordHash == 0);
        vm.warp(scheduled.notBefore);
        scheduled.status = GovernanceActionStatus.EXECUTED;
        _publish();
        T.Snapshot memory before_ = _ownerSnapshot();
        _overflow();
        this.executeRegistered(p, a);
        _inactive();
        (bool used,) = ingress.rotationAcceptanceNonceState(artistId, p.newAddress, a.nonce);
        require(
            !used && _roots() == roots && _status(attackerGuardian).recoveryRecordHash == 0,
            "Archive rollback is atomic"
        );
        vm.roll(restoreBlock);
        vm.recordLogs();
        bytes32 record = this.executeRegistered(p, a);
        _assertSnapshot(_snapshot(record), 35, before_, vm.getRecordedLogs());
        require(
            _status(attackerGuardian).recoveryRecordHash == record
                && _status(lifetimeGuardian).recoveryRecordHash == 0
        );
        (,,, bytes32 selected) = ingress.guardianSet(artistId);
        require(
            selected == lifetimeGuardian
                && ingress.identityRecoveryRecord(record).postContestSeconds == 10 days
        );
        (bytes32 primary, bytes32 occurrence, bytes32 secondary) =
            StreamArtistIdentityAuthority(suite.owners[2]).identityRecoveryReceipts(record);
        require(primary != 0 && secondary != 0 && occurrence != 0 && primary != secondary);
        require(
            guardianBeforeHash == keccak256(abi.encode(ingress.guardianSetRecord(attackerGuardian)))
                && rotationBeforeHash
                    == keccak256(abi.encode(ingress.rotationRecord(soleRotation))),
            "original records remain exact"
        );
        _appealSizes();
    }

    function testActualMixedAppealKeepsRetainedGuardianVetoAfterNotBefore() public {
        _appealCase(0, true);
        (IdentityRecovery.Request memory p, T.Authorization memory a) = _publishAppeal();
        _election(p);
        GovernanceCall[] memory calls = _scheduleAppeal(p, a);
        ingress.registerIdentityRecoveryAction(currentId, calls, p, a);
        vm.warp(scheduled.notBefore + 1);
        this.vetoByGuardian(keccak256("retained original guardian veto"));
        (, A.Veto memory veto,,) = _read();
        require(veto.vetoer == address(delegateSafe));
        scheduled.status = GovernanceActionStatus.EXECUTED;
        _publish();
        vm.expectRevert(abi.encodeWithSelector(A.RecoveryActionVetoed.selector, currentId));
        this.executeRegistered(p, a);
        require(
            _status(attackerGuardian).recoveryRecordHash == 0
                && _status(postGuardian).recoveryRecordHash == 0
        );
    }

    function testActualAppealRoleRevisionInvalidatesPreparedAction() public {
        _appealCase(0, false);
        (IdentityRecovery.Request memory p, T.Authorization memory a) = _publishAppeal();
        _election(p);
        GovernanceCall[] memory calls = _scheduleAppeal(p, a);
        ingress.registerIdentityRecoveryAction(currentId, calls, p, a);
        bytes32 roots = _roots();
        ArtistAppealUnitRoles roles = ArtistAppealUnitRoles(suite.roleRegistry);
        roles.setAppeal(address(this), false);
        vm.expectRevert(abi.encodeWithSelector(Appeal.InvalidGuardianAppeal.selector, bytes32(0)));
        ingress.identityRecoveryContext(p, a);
        roles.setAppeal(address(this), true);
        vm.warp(scheduled.notBefore);
        scheduled.status = GovernanceActionStatus.EXECUTED;
        _publish();
        vm.expectRevert(abi.encodeWithSelector(A.InvalidRecoveryAction.selector, currentId));
        this.executeRegistered(p, a);
        require(
            _roots() == roots && ingress.latestIdentityRecovery(artistId) == 0,
            "regrant does not revive an old role witness"
        );
    }

    function testActualOperativeDirectiveAbsolutelyForbidsAppeal() public {
        _appealCase(2048, false);
        (IdentityRecovery.Request memory p, T.Authorization memory a) = _publishAppeal();
        bytes32 directive = ingress.operativeEstateDirective(artistId);
        require(directive != 0);
        vm.expectRevert(
            abi.encodeWithSelector(
                Succ.ForbiddenCapability.selector, artistId, uint32(2048), directive
            )
        );
        ingress.identityRecoveryContext(p, a);
        require(
            ingress.latestIdentityRecovery(artistId) == 0
                && _status(attackerGuardian).recoveryRecordHash == 0
        );
    }

    function _rejectDocument(IdentityRecovery.Request memory p, Appeal.Document memory d) private {
        p.evidenceHash = _publisher().publish(d);
        T.Authorization memory a = _acceptance(p);
        vm.expectRevert(
            abi.encodeWithSelector(Appeal.InvalidGuardianAppeal.selector, p.evidenceHash)
        );
        ingress.identityRecoveryContext(p, a);
    }

    function testActualWrongExtraAndMissingHostileEvidenceCannotAuthorizeAppeal() public {
        _appealCase(0, false);
        (IdentityRecovery.Request memory p, Appeal.Document memory d) = _appealTerms();
        bytes32 roots = _roots();
        d.findings[0].parties[0] = address(delegateSafe);
        _rejectDocument(p, d);
        (, d) = _appealTerms();
        d.contestRecordHash = keccak256("unrelated original contest");
        _rejectDocument(p, d);
        (, d) = _appealTerms();
        address[] memory parties = new address[](1);
        parties[0] = address(delegateSafe);
        Appeal.Finding memory extra = Appeal.Finding(lifetimeGuardian, parties);
        Appeal.Finding memory original = d.findings[0];
        d.findings = new Appeal.Finding[](2);
        (d.findings[0], d.findings[1]) =
            lifetimeGuardian < attackerGuardian ? (extra, original) : (original, extra);
        _rejectDocument(p, d);
        (, d) = _appealTerms();
        p.supersededRecordHashes = new bytes32[](2);
        (p.supersededRecordHashes[0], p.supersededRecordHashes[1]) = lifetimeGuardian
            < attackerGuardian
            ? (lifetimeGuardian, attackerGuardian)
            : (attackerGuardian, lifetimeGuardian);
        d.requestCommitment = Appeal.requestCommitment(p);
        _rejectDocument(p, d);
        require(_roots() == roots && ingress.latestIdentityRecovery(artistId) == 0);
        T.Authorization memory a;
        (p, a) = _publishAppeal();
        _election(p);
        require(
            ingress.identityRecoveryContext(p, a).postContestSeconds == 10 days,
            "exact original document still succeeds"
        );
    }
}

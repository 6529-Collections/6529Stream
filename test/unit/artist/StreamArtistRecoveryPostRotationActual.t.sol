// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    IStreamArtistGuardianHistory
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistGuardianHistory.sol";
import {
    StreamArtistGuardianHistoryTypes as GH
} from "../../../smart-contracts/interfaces/stream/artist/StreamArtistGuardianHistoryTypes.sol";

import {
    ArtistOnboardingFixture,
    ArtistUnitGovernance,
    ArtistUnitRoles
} from "./ArtistOnboardingFixture.sol";
import { Vm } from "../../regression/legacy/helpers/CharacterizationTestBase.sol";
import { OfficialSafe } from "../../helpers/OfficialSafeFixture.sol";
import {
    IStreamArtistIdentityRecovery,
    IStreamArtistIdentityRecoveryOwner
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistIdentityRecovery.sol";
import {
    IStreamArtistIdentityOwner
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistIdentityOwner.sol";
import {
    IStreamArtistOwner
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistOwner.sol";
import {
    IStreamArtistIdentityContest
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistIdentityContest.sol";
import {
    IStreamArtistRotationOwner,
    IStreamArtistRotationReads
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistRotationOwner.sol";
import {
    IStreamGovernanceReads
} from "../../../smart-contracts/interfaces/stream/governance/IStreamGovernanceReads.sol";
import {
    StreamArtistIdentityRecoveryOperationTypes as IdentityRecovery
} from "../../../smart-contracts/interfaces/stream/artist/StreamArtistIdentityRecoveryOperationTypes.sol";
import {
    StreamArtistOnboardingTypes as T
} from "../../../smart-contracts/interfaces/stream/artist/StreamArtistOnboardingTypes.sol";
import {
    StreamArtistRotationTypes as R
} from "../../../smart-contracts/interfaces/stream/artist/StreamArtistRotationTypes.sol";
import {
    StreamArtistIdentityContestTypes as Contest
} from "../../../smart-contracts/interfaces/stream/artist/StreamArtistIdentityContestTypes.sol";
import {
    StreamArtistIdentityDismissalTypes as Dismissal
} from "../../../smart-contracts/interfaces/stream/artist/StreamArtistIdentityDismissalTypes.sol";
import {
    StreamArtistIdentityAuthority
} from "../../../smart-contracts/domains/artist/StreamArtistIdentityAuthority.sol";
import {
    StreamArtistIdentityRecoveryExtension
} from "../../../smart-contracts/domains/artist/StreamArtistIdentityRecoveryExtension.sol";
import {
    StreamArtistIdentityRecoveryGovernance
} from "../../../smart-contracts/domains/artist/StreamArtistIdentityRecoveryGovernance.sol";

import {
    IStreamArtistRecoveryAction,
    IStreamArtistRecoveryActionOwner
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistRecoveryAction.sol";
import {
    StreamArtistRecoveryActionTypes as A
} from "../../../smart-contracts/interfaces/stream/artist/StreamArtistRecoveryActionTypes.sol";
import {
    IStreamGovernanceActionFacts
} from "../../../smart-contracts/interfaces/stream/governance/IStreamGovernanceActionFacts.sol";
import {
    GovernanceCall,
    GovernanceAction,
    GovernanceActionStatus
} from "../../../smart-contracts/interfaces/stream/governance/StreamGovernanceTypes.sol";

/// @dev Actual Identity/facade/Coordinator/Safe/Archive; scheduled governance facts and current context are explicit typed boundaries.
contract StreamArtistRecoveryPostRotationActualTest is ArtistOnboardingFixture {
    uint256 private restoreBlock;
    GovernanceAction private scheduled;
    bytes32 private currentId;

    function _sizes() private view {
        StreamArtistIdentityAuthority owner = StreamArtistIdentityAuthority(suite.owners[2]);
        require(
            address(ingress).code.length <= 24576 && address(coordinator).code.length <= 24576
                && address(owner).code.length <= 24576,
            "actual host runtime sizes"
        );
        require(
            owner.identityWriterExtension().code.length <= 24576
                && owner.identityEstateExtension().code.length <= 24576
                && owner.identityRecoveryExtension().code.length <= 24576,
            "actual fixed child runtime sizes"
        );
    }

    function _governedInitialContest() private {
        ArtistUnitGovernance authority = ArtistUnitGovernance(manager.governanceAuthority());
        ArtistUnitRoles(suite.roleRegistry).setArbiter(address(artist), true);
        authority.configureContestReads(
            suite.roleRegistry, address(artist), keccak256("compromise reason"), "urn:unit:contest"
        );
        (bytes32 scope, bytes32 oldHash, bytes32 newHash) = ingress.identityContestGovernanceContext(
            artistId, 0, keccak256("compromise evidence"), keccak256("compromise reason")
        );
        authority.executeModuleContext(
            address(ingress), _contestData(0), 1, scope, oldHash, newHash
        );
        require(
            IStreamArtistIdentityOwner(suite.owners[2]).identity(artistId).status == 4,
            "actual cause"
        );
        require(
            IStreamArtistRotationReads(suite.owners[2]).lastArtistTransition(artistId) == 0,
            "no prior transition"
        );
    }

    function _terms() private view returns (IdentityRecovery.Request memory) {
        return IdentityRecovery.Request(
            artistId,
            address(rotationSafe),
            1,
            ingress.currentIdentityContestCause(artistId).causeHash,
            ingress.latestIdentityContestDismissal(artistId),
            keccak256("recovery evidence"),
            keccak256("recovery reason"),
            new bytes32[](0)
        );
    }

    function _acceptance(IdentityRecovery.Request memory p)
        private
        returns (T.Authorization memory a)
    {
        a = T.Authorization(0, uint64(block.timestamp + 30 days), "");
        R.Rotation memory rotation =
            R.Rotation(artistId, address(artist), p.newAddress, p.reasonHash, 0);
        a.signature = safeThresholdSignature(
            rotationKeys,
            safeMessageDigest(
                rotationSafe, abi.encode(ingress.rotationAcceptanceDigest(rotation, a))
            )
        );
    }

    function _guarded() private returns (bytes32 guardian) {
        _sizes();
        _delegateSetup();
        _newRotationSafe(36001);
        address[] memory members = new address[](1);
        members[0] = address(delegateSafe);
        guardian = _guardianRecord(members, 1, 10 days, nextNonce);
        (,,, uint64 count) = ingress.identityRecoveryActionState(artistId, bytes32(0));
        require(count == 1, "actual op28 counted");
        _governedInitialContest();
    }

    function _calls(IdentityRecovery.Request memory p, T.Authorization memory a)
        private
        view
        returns (GovernanceCall[] memory calls)
    {
        IdentityRecovery.Context memory c = ingress.identityRecoveryContext(p, a);
        calls = new GovernanceCall[](2);
        calls[0] = GovernanceCall(
            address(0x2222),
            0,
            bytes4(0x12345678),
            keccak256("preceding exact call"),
            keccak256("other scope"),
            keccak256("other old"),
            keccak256("other new")
        );
        calls[1] = GovernanceCall(
            address(ingress),
            0,
            IStreamArtistIdentityRecovery.recoverArtistIdentity.selector,
            keccak256(abi.encodeCall(IStreamArtistIdentityRecovery.recoverArtistIdentity, (p, a))),
            c.scopeHash,
            c.oldValueHash,
            c.newValueHash
        );
    }

    function _schedule(bytes32 id, IdentityRecovery.Request memory p, T.Authorization memory a)
        private
        returns (GovernanceCall[] memory calls)
    {
        currentId = id;
        calls = _calls(p, a);
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
        scheduled.proposer = address(artist);
        scheduled.executor = address(0);
        scheduled.canceller = address(0);
        scheduled.vetoer = address(0);
        scheduled.reasonHash = p.reasonHash;
        scheduled.reasonURI = "urn:unit:registered-recovery";
        scheduled.manifestHash = keccak256("sealed fixture manifest");
        ArtistUnitGovernance authority = ArtistUnitGovernance(manager.governanceAuthority());
        authority.configureContestReads(
            suite.roleRegistry, address(artist), p.reasonHash, scheduled.reasonURI
        );
        bytes32[29] memory bootstrap;
        bootstrap[0] = bytes32(uint256(1));
        bootstrap[1] = bytes32(uint256(1));
        avm.mockCall(
            address(authority),
            abi.encodeWithSelector(IStreamGovernanceReads.systemManifestBootstrapState.selector),
            abi.encode(bootstrap)
        );
        avm.mockCall(
            address(authority),
            abi.encodeCall(IStreamGovernanceReads.minimumDelay, (uint8(2))),
            abi.encode(uint64(72 hours))
        );
        _publish();
    }

    function _publish() private {
        address authority = manager.governanceAuthority();
        avm.mockCall(
            authority,
            abi.encodeCall(IStreamGovernanceReads.governanceAction, (currentId)),
            abi.encode(scheduled)
        );
        avm.mockCall(
            authority,
            abi.encodeCall(IStreamGovernanceActionFacts.governanceActionFacts, (currentId)),
            abi.encode(
                IStreamGovernanceActionFacts.ActionFacts(
                    scheduled.status,
                    scheduled.actionClass,
                    scheduled.callHash,
                    scheduled.notBefore,
                    scheduled.expiresAfter
                )
            )
        );
    }

    function executeRegistered(IdentityRecovery.Request calldata p, T.Authorization calldata a)
        external
        returns (bytes32)
    {
        require(msg.sender == address(this), "fixture caller");
        IdentityRecovery.Context memory c = ingress.identityRecoveryContext(p, a);
        address authority = manager.governanceAuthority();
        avm.mockCall(
            authority,
            abi.encodeWithSignature("currentAction()"),
            abi.encode(true, currentId, uint8(2), c.scopeHash, c.oldValueHash, c.newValueHash)
        );
        ArtistUnitGovernance(authority)
            .executeModuleContext(
                address(ingress),
                abi.encodeCall(IStreamArtistIdentityRecovery.recoverArtistIdentity, (p, a)),
                2,
                c.scopeHash,
                c.oldValueHash,
                c.newValueHash
            );
        _inactive();
        return ingress.latestIdentityRecovery(artistId);
    }

    function _inactive() private {
        avm.mockCall(
            manager.governanceAuthority(),
            abi.encodeWithSignature("currentAction()"),
            abi.encode(false, bytes32(0), uint8(0), bytes32(0), bytes32(0), bytes32(0))
        );
    }

    function vetoByGuardian(bytes32 reason) external {
        require(msg.sender == address(this), "fixture caller");
        require(
            executeSafe(
                delegateSafe,
                delegateKeys,
                address(ingress),
                0,
                abi.encodeCall(
                    IStreamArtistRecoveryAction.vetoIdentityRecovery, (artistId, reason)
                ),
                0
            ),
            "guardian Safe veto"
        );
    }

    function _read()
        private
        view
        returns (A.Association memory a, A.Veto memory v, bytes32 executed, uint64 count)
    {
        return ingress.identityRecoveryActionState(artistId, currentId);
    }

    function testActualGuardedRecoverySavedGuardianPostWindowAndAcceptanceRollback() public {
        bytes32 guardian = _guarded();
        IdentityRecovery.Request memory p = _terms();
        T.Authorization memory a = _acceptance(p);
        GovernanceCall[] memory calls = _schedule(keccak256("executed guarded action"), p, a);
        ingress.registerIdentityRecoveryAction(currentId, calls, p, a);
        vm.warp(scheduled.notBefore);
        scheduled.status = GovernanceActionStatus.EXECUTED;
        _publish();
        bytes32 roots = _roots();
        restoreBlock = block.number;
        vm.roll(uint256(type(uint64).max) + 1);
        vm.expectRevert(
            abi.encodeWithSignature(
                "ArtistArchiveBlockNumberOverflow(uint256)", uint256(type(uint64).max) + 1
            )
        );
        this.executeRegistered(p, a);
        _inactive();
        require(_roots() == roots, "guarded nonce pair and archive rollback");
        (,, bytes32 executed,) = _read();
        (bool used,) = ingress.rotationAcceptanceNonceState(artistId, p.newAddress, a.nonce);
        require(executed == 0 && !used, "no leaked action or nonce");
        vm.roll(restoreBlock);
        uint256 at = block.timestamp;
        bytes32 record = this.executeRegistered(p, a);
        IdentityRecovery.Record memory item = ingress.identityRecoveryRecord(record);
        (address prior, bytes32 savedGuardian, uint64 tail) =
            IStreamArtistIdentityRecoveryOwner(suite.owners[2]).recoveryTransitionStanding(record);
        (,, executed,) = _read();
        R.TransitionState memory transition = ingress.artistTransitionState(record);
        require(
            executed == record && record != 0 && item.fields.governanceActionId == currentId
                && item.postContestSeconds == 10 days,
            "actual guarded permanent recovery"
        );
        require(
            prior == address(artist) && savedGuardian == guardian
                && tail == item.standingTailSeconds && transition.postWindowEndsAt == at + 10 days,
            "original guardian and max postvesting window"
        );
        (bytes32 active, uint64 end, bool contested) = ingress.activeAuthorityWindow(artistId);
        require(active == record && end == at + 10 days && !contested, "common active window");
        (used,) = ingress.rotationAcceptanceNonceState(artistId, p.newAddress, a.nonce);
        require(used, "original shared acceptance nonce consumed");
        _sizes();
    }

    bytes32 private predecessor;
    bytes32 private originalGuardian;
    bytes32 private selectedGuardian;
    address private originalArtist;
    uint64 private predecessorEnd;

    function _postRotation(bool provisional, bool mature) private {
        _delegateSetup();
        originalArtist = address(artist);
        address[] memory members = new address[](1);
        members[0] = address(delegateSafe);
        originalGuardian = _guardianRecord(members, 1, 10 days, nextNonce);
        _newRotationSafe(38101);
        predecessor = _stageRotation(0);
        _executeTimedRotation(predecessor);
        _adoptRotatedSafe();
        predecessorEnd = ingress.rotationRecord(predecessor).transition.postWindowEndsAt;
        selectedGuardian = originalGuardian;
        if (provisional) {
            members[0] = address(artist);
            selectedGuardian = _guardianRecord(members, 1, 20 days, nextNonce);
            R.GuardianRecord memory candidate = ingress.guardianSetRecord(selectedGuardian);
            require(
                candidate.provisional.transitionRecordHash == predecessor
                    && candidate.provisional.windowEndsAt == predecessorEnd,
                "actual provisional association"
            );
            (,,, bytes32 selectedBefore) = ingress.guardianSet(artistId);
            require(selectedBefore == originalGuardian, "candidate not yet operative");
        }
        if (mature) vm.warp(predecessorEnd);
        bytes32 roots = _roots();
        (,,, bytes32 selected) = ingress.guardianSet(artistId);
        require(
            selected == (mature ? selectedGuardian : originalGuardian),
            "actual selected original set"
        );
        require(roots == _roots(), "maturation is read only");
        _newRotationSafe(38102);
        ArtistUnitGovernance authority = ArtistUnitGovernance(manager.governanceAuthority());
        ArtistUnitRoles(suite.roleRegistry).setArbiter(address(artist), true);
        authority.configureContestReads(
            suite.roleRegistry, address(artist), keccak256("compromise reason"), "urn:unit:contest"
        );
        (bytes32 scope, bytes32 oldHash, bytes32 newHash) = ingress.identityContestGovernanceContext(
            artistId, predecessor, keccak256("compromise evidence"), keccak256("compromise reason")
        );
        authority.executeModuleContext(
            address(ingress), _contestData(predecessor), 1, scope, oldHash, newHash
        );
        Dismissal.Cause memory cause = ingress.currentIdentityContestCause(artistId);
        require(
            cause.facts.executedTransitionHash == predecessor
                && cause.facts.incumbent == address(artist) && cause.facts.priorStatus == 1,
            "actual late living cause joins predecessor"
        );
    }

    function _success(IdentityRecovery.Request memory p, T.Authorization memory a)
        private
        returns (bytes32)
    {
        vm.warp(scheduled.notBefore);
        scheduled.status = GovernanceActionStatus.EXECUTED;
        _publish();
        return this.executeRegistered(p, a);
    }

    function testActualFirstRotationRecoveryPreservesOriginalAndNewStanding() public {
        _postRotation(false, true);
        R.RotationRecord memory original = ingress.rotationRecord(predecessor);
        require(
            original.transition.contestedAt == predecessorEnd, "exact end contest remains mature"
        );
        IdentityRecovery.Request memory p = _terms();
        T.Authorization memory a = _acceptance(p);
        GovernanceCall[] memory calls =
            _schedule(keccak256("first completed rotation recovery"), p, a);
        ingress.registerIdentityRecoveryAction(currentId, calls, p, a);
        bytes32 record = _success(p, a);
        IdentityRecovery.Record memory recovered = ingress.identityRecoveryRecord(record);
        (address prior, bytes32 guardian, uint64 tail) =
            IStreamArtistIdentityRecoveryOwner(suite.owners[2]).recoveryTransitionStanding(record);
        require(
            record != 0 && recovered.fields.oldAddress == address(artist)
                && recovered.fields.newAddress == address(rotationSafe)
                && recovered.postContestSeconds == 10 days,
            "actual post-rotation recovery"
        );
        require(
            prior == address(artist) && guardian == originalGuardian
                && tail == recovered.standingTailSeconds,
            "old-key authored guardian retained in new standing"
        );
        require(
            ingress.guardianSetRecord(guardian).signer == originalArtist && originalArtist != prior,
            "historical signer is not confused with incumbent"
        );
        require(
            keccak256(abi.encode(original))
                == keccak256(abi.encode(ingress.rotationRecord(predecessor))),
            "original executed rotation stays permanent"
        );
        (bytes32 active, uint64 end, bool contested) = ingress.activeAuthorityWindow(artistId);
        require(
            active == record && end == block.timestamp + 10 days && !contested,
            "fresh common window"
        );
        _sizes();
    }

    function testActualMatureProvisionalGuardianAndOlderPrefixVeto() public {
        _postRotation(true, true);
        IdentityRecovery.Request memory p = _terms();
        T.Authorization memory a = _acceptance(p);
        GovernanceCall[] memory calls =
            _schedule(keccak256("mature provisional recovery veto"), p, a);
        bytes32 association = ingress.registerIdentityRecoveryAction(currentId, calls, p, a);
        (A.Association memory saved,,,) = _read();
        require(
            saved.guardian.recordHash == selectedGuardian
                && saved.guardian.provisional.transitionRecordHash == predecessor,
            "mature selected record frozen exactly"
        );
        (GH.Head memory history,, GH.Snapshot memory prefix, uint64 first) = IStreamArtistGuardianHistory(
                suite.owners[2]
            ).guardianHistoryState(artistId, 0, address(delegateSafe), currentId);
        require(
            history.count == 2 && prefix.count == 2 && first == 1
                && prefix.associationHash == association
                && prefix.historyCommitment == history.commitment,
            "older set remains in frozen two-record prefix"
        );
        vm.warp(scheduled.notBefore);
        this.vetoByGuardian(keccak256("old original guardian veto"));
        bytes32 oldId = currentId;
        GovernanceAction memory old = scheduled;
        scheduled.status = GovernanceActionStatus.EXECUTED;
        _publish();
        bytes32 roots = _roots();
        vm.expectRevert(abi.encodeWithSelector(A.RecoveryActionVetoed.selector, currentId));
        this.executeRegistered(p, a);
        _inactive();
        (bool used,) = ingress.rotationAcceptanceNonceState(artistId, p.newAddress, a.nonce);
        require(
            !used && roots == _roots() && ingress.latestIdentityRecovery(artistId) == 0,
            "prefix veto blocks actual recovery and acceptance"
        );
        avm.mockCall(
            manager.governanceAuthority(),
            abi.encodeCall(IStreamGovernanceActionFacts.governanceActionFacts, (oldId)),
            abi.encode(
                IStreamGovernanceActionFacts.ActionFacts(
                    GovernanceActionStatus.CANCELLED,
                    2,
                    old.callHash,
                    old.notBefore,
                    old.expiresAfter
                )
            )
        );
        calls = _schedule(keccak256("fresh mature provisional recovery"), p, a);
        ingress.registerIdentityRecoveryAction(currentId, calls, p, a);
        bytes32 record = _success(p, a);
        require(
            ingress.identityRecoveryRecord(record).postContestSeconds == 20 days,
            "operative provisional set determines postvesting minimum"
        );
        (, bytes32 guardian,) =
            IStreamArtistIdentityRecoveryOwner(suite.owners[2]).recoveryTransitionStanding(record);
        require(
            guardian == selectedGuardian
                && ingress.guardianSetRecord(guardian).provisional.transitionRecordHash
                    == predecessor,
            "original provisional provenance is permanent"
        );
        (, A.Veto memory veto,,) = ingress.identityRecoveryActionState(artistId, oldId);
        require(veto.vetoer == address(delegateSafe), "earlier local veto is permanent");
        _sizes();
    }

    function testActualWithinWindowRotationContestNeverMaturesIntoThisProfile() public {
        _postRotation(false, false);
        IdentityRecovery.Request memory p = _terms();
        T.Authorization memory a = _acceptance(p);
        bytes32 roots = _roots();
        vm.expectRevert(
            abi.encodeWithSelector(
                IdentityRecovery.UnsupportedIdentityRecoveryProfile.selector, artistId
            )
        );
        ingress.identityRecoveryContext(p, a);
        vm.warp(uint256(predecessorEnd) + 1);
        vm.expectRevert(
            abi.encodeWithSelector(
                IdentityRecovery.UnsupportedIdentityRecoveryProfile.selector, artistId
            )
        );
        ingress.identityRecoveryContext(p, a);
        (bool used,) = ingress.rotationAcceptanceNonceState(artistId, p.newAddress, a.nonce);
        require(
            roots == _roots() && !used && ingress.latestIdentityRecovery(artistId) == 0,
            "no time-only adjudication or leaked acceptance"
        );
    }
}

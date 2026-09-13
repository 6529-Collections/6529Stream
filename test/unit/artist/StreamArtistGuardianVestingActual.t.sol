// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamArtistEstateExtensionDeployment
} from "../../../smart-contracts/domains/artist/StreamArtistEstateExtensionDeployment.sol";
import {
    IStreamArtistRotation
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistRotation.sol";
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
import {
    StreamArtistGuardianVestingTypes as V
} from "../../../smart-contracts/interfaces/stream/artist/StreamArtistGuardianVestingTypes.sol";
import {
    IStreamArtistGuardianVestingHistory
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistGuardianVestingHistory.sol";
import {
    StreamArtistEstateTypes as Estate
} from "../../../smart-contracts/interfaces/stream/artist/StreamArtistEstateTypes.sol";

contract StreamArtistGuardianVestingActualTest is ArtistOnboardingFixture {
    uint256 private restoreBlock;
    GovernanceAction private scheduled;
    bytes32 private currentId;

    function _sizes() private view {
        require(
            address(StreamArtistEstateExtensionDeployment).code.length <= 24576,
            "actual fixed Estate deployment library runtime size"
        );
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

    function _snapshot(bytes32 record) private view returns (V.Snapshot memory) {
        return IStreamArtistGuardianVestingHistory(suite.owners[2])
            .guardianVestingSnapshot(artistId, record);
    }

    function _missing(bytes32 record) private {
        address owner = suite.owners[2];
        vm.expectRevert(abi.encodeWithSelector(V.InvalidGuardianVesting.selector, record));
        IStreamArtistGuardianVestingHistory(owner).guardianVestingSnapshot(artistId, record);
    }

    function _ownerSnapshot() private view returns (T.Snapshot memory) {
        return IStreamArtistOwner(suite.owners[2]).ownerStateSnapshotV2();
    }

    function _assertSnapshot(
        V.Snapshot memory s,
        uint16 operation,
        T.Snapshot memory before_,
        Vm.Log[] memory logs
    ) private view {
        require(
            s.artistId == artistId && s.transitionRecordHash != 0 && s.operationId == operation
                && s.ownerRevision == before_.revision + 1 && s.executedAt == block.timestamp
                && s.oldAddress != s.newAddress && s.newAddress != address(0),
            "actual vesting identity/revision"
        );
        require(_ownerSnapshot().revision == s.ownerRevision, "single successful owner revision");
        require(
            s.commitment
                == keccak256(
                    abi.encode(
                        keccak256("6529STREAM_ARTIST_GUARDIAN_VESTING_V1"),
                        block.chainid,
                        address(ingress),
                        suite.owners[2],
                        s.artistId,
                        s.transitionRecordHash,
                        s.operationId,
                        s.ownerRevision,
                        s.executedAt,
                        s.oldAddress,
                        s.newAddress,
                        s.authorityClass,
                        s.guardians,
                        s.previousTransitionRecordHash,
                        s.previousCommitment
                    )
                ),
            "exact owner-bound snapshot hash"
        );
        uint256 count;
        for (uint256 i; i < logs.length; ++i) {
            if (
                logs[i].emitter != suite.owners[2] || logs[i].topics.length == 0
                    || logs[i].topics[0]
                        != keccak256(
                            "ArtistGuardianVestingRecorded(uint16,bytes32,bytes32,bytes32,uint16,uint64,uint64,bytes32,bytes32)"
                        )
            ) continue;
            require(
                logs[i].topics.length == 4 && logs[i].topics[1] == artistId
                    && logs[i].topics[2] == s.transitionRecordHash
                    && logs[i].topics[3] == s.commitment
                    && keccak256(logs[i].data)
                        == keccak256(
                            abi.encode(
                                uint16(1),
                                operation,
                                s.ownerRevision,
                                s.guardians.count,
                                s.guardians.commitment,
                                s.previousTransitionRecordHash
                            )
                        ),
                "exact snapshot event"
            );
            ++count;
        }
        require(count == 1, "one actual vesting event");
    }

    function _overflow() private {
        restoreBlock = block.number;
        vm.roll(uint256(type(uint64).max) + 1);
        vm.expectRevert(
            abi.encodeWithSignature(
                "ArtistArchiveBlockNumberOverflow(uint256)", uint256(type(uint64).max) + 1
            )
        );
    }

    function testActualRotationSnapshotOrdersSameTimeGuardianAdmissionsAndRetriesArchive() public {
        _delegateSetup();
        address[] memory members = new address[](1);
        members[0] = address(delegateSafe);
        bytes32 selected = _guardianRecord(members, 1, 0, 9);
        members[0] = address(artist);
        bytes32 unselected = _guardianRecord(members, 1, 0, 1);
        _newRotationSafe(41001);
        bytes32 record = _stageRotation(0);
        _missing(record);
        require(
            executeSafe(
                delegateSafe,
                delegateKeys,
                address(ingress),
                0,
                abi.encodeCall(IStreamArtistRotation.approveArtistRotation, (artistId, record)),
                0
            ),
            "actual guardian approval"
        );
        _missing(record);
        (GH.Head memory head,,,) = IStreamArtistGuardianHistory(suite.owners[2])
            .guardianHistoryState(artistId, 0, address(0), 0);
        require(
            head.count == 2
                && ingress.guardianSetRecord(unselected).nonce
                    < ingress.guardianSetRecord(selected).nonce,
            "full unselected admission prefix"
        );
        T.Snapshot memory before_ = _ownerSnapshot();
        bytes32 roots = _roots();
        _overflow();
        ingress.executeArtistRotation(artistId, record);
        require(
            _roots() == roots && ingress.rotationRecord(record).transition.phase == 1,
            "actual vesting and owner rollback"
        );
        _missing(record);
        vm.roll(restoreBlock);
        vm.recordLogs();
        ingress.executeArtistRotation(artistId, record);
        Vm.Log[] memory logs = vm.getRecordedLogs();
        V.Snapshot memory saved = _snapshot(record);
        _assertSnapshot(saved, 32, before_, logs);
        require(
            keccak256(abi.encode(saved.guardians)) == keccak256(abi.encode(head))
                && saved.guardians.ownerRevision < saved.ownerRevision && saved.authorityClass == 1
                && _ownerSnapshot().recordChainTip == before_.recordChainTip,
            "original record-zero commit and full prefix"
        );
        require(
            saved.executedAt == ingress.guardianSetRecord(unselected).signedAt
                && saved.executedAt < ingress.rotationRecord(record).transition.contestEndsAt,
            "same-time early approved execution"
        );
        _adoptRotatedSafe();
        bytes32 later = _guardianRecord(new address[](0), 0, 0, nextNonce);
        (, GH.Entry memory entry,,) = IStreamArtistGuardianHistory(suite.owners[2])
            .guardianHistoryState(artistId, 3, address(0), 0);
        require(
            entry.recordHash == later && entry.ownerRevision > saved.ownerRevision
                && ingress.guardianSetRecord(later).signedAt == saved.executedAt,
            "same timestamp later admission is after cutoff"
        );
        vm.warp(ingress.rotationRecord(record).transition.postWindowEndsAt);
        _newRotationSafe(41002);
        bytes32 second = _stageRotation(record);
        R.RotationRecord memory staged = ingress.rotationRecord(second);
        vm.warp(staged.transition.contestEndsAt);
        before_ = _ownerSnapshot();
        vm.recordLogs();
        ingress.executeArtistRotation(artistId, second);
        logs = vm.getRecordedLogs();
        V.Snapshot memory next = _snapshot(second);
        _assertSnapshot(next, 32, before_, logs);
        require(
            next.previousTransitionRecordHash == record
                && next.previousCommitment == saved.commitment && next.guardians.count == 3
                && keccak256(abi.encode(saved)) == keccak256(abi.encode(_snapshot(record))),
            "immutable predecessor chain"
        );
        _sizes();
    }

    function testActualEstateEmptyPrefixSnapshotAndLateArchiveRetry() public {
        address old = address(artist);
        Estate.Execution memory p = _estatePendingFixture(4095);
        bytes32 record = p.expectedActivationRecordHash;
        (Estate.RequestRecord memory original,,) = ingress.estateActivationRecord(record);
        bytes32 originalHash = keccak256(abi.encode(original));
        _missing(record);
        vm.warp(original.noticeEndsAt);
        T.Snapshot memory before_ = _ownerSnapshot();
        bytes32 roots = _roots();
        _overflow();
        ingress.executeEstateActivation(p);
        _missing(record);
        (, uint8 phase,) = ingress.estateActivationRecord(record);
        require(_roots() == roots && phase == 1, "estate activation and snapshot rolled back");
        vm.roll(restoreBlock);
        vm.recordLogs();
        ingress.executeEstateActivation(p);
        Vm.Log[] memory logs = vm.getRecordedLogs();
        V.Snapshot memory saved = _snapshot(record);
        _assertSnapshot(saved, 40, before_, logs);
        require(
            saved.oldAddress == old && saved.newAddress == address(delegateSafe)
                && saved.authorityClass == 3 && saved.guardians.count == 0
                && saved.guardians.commitment == 0 && saved.commitment != 0
                && saved.previousTransitionRecordHash == 0
                && _ownerSnapshot().recordChainTip == before_.recordChainTip,
            "empty prefix is explicit and original no-record commit preserved"
        );
        (original,,) = ingress.estateActivationRecord(record);
        require(keccak256(abi.encode(original)) == originalHash, "original request bytes unchanged");
        _sizes();
    }

    function testActualRecoverySnapshotSharesOneRevisionAndTwoReceiptsWithArchiveRetry() public {
        _guarded();
        IdentityRecovery.Request memory p = _terms();
        T.Authorization memory a = _acceptance(p);
        GovernanceCall[] memory calls = _schedule(keccak256("vesting recovery action"), p, a);
        ingress.registerIdentityRecoveryAction(currentId, calls, p, a);
        vm.warp(scheduled.notBefore);
        scheduled.status = GovernanceActionStatus.EXECUTED;
        _publish();
        T.Snapshot memory before_ = _ownerSnapshot();
        bytes32 roots = _roots();
        _overflow();
        this.executeRegistered(p, a);
        _inactive();
        (bool used,) = ingress.rotationAcceptanceNonceState(artistId, p.newAddress, a.nonce);
        require(
            _roots() == roots && !used && ingress.latestIdentityRecovery(artistId) == 0,
            "recovery nonce/records/snapshot transaction rollback"
        );
        vm.roll(restoreBlock);
        vm.recordLogs();
        bytes32 recovered = this.executeRegistered(p, a);
        Vm.Log[] memory logs = vm.getRecordedLogs();
        V.Snapshot memory saved = _snapshot(recovered);
        _assertSnapshot(saved, 35, before_, logs);
        require(
            saved.guardians.count == 1 && saved.oldAddress == address(artist)
                && saved.newAddress == p.newAddress && saved.previousTransitionRecordHash == 0,
            "same admitted recovery primary and original prefix"
        );
        (bytes32 primary, bytes32 occurrence, bytes32 secondary) =
            IStreamArtistIdentityRecoveryOwner(suite.owners[2]).identityRecoveryReceipts(recovered);
        require(
            primary != 0 && secondary != 0 && occurrence != 0 && primary != occurrence
                && _ownerSnapshot().recordChainTip != before_.recordChainTip,
            "original ordered two-receipt append remains present"
        );
        _sizes();
    }
}

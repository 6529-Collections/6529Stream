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
contract StreamArtistGuardianRecoveryActualTest is ArtistOnboardingFixture {
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

    function testActualPreparationOneRevisionExactSnapshotAndLateArchiveRetry() public {
        bytes32 guardian = _guarded();
        IdentityRecovery.Request memory p = _terms();
        T.Authorization memory a = _acceptance(p);
        GovernanceCall[] memory calls = _schedule(keccak256("prepared action"), p, a);
        IdentityRecovery.Context memory context = ingress.identityRecoveryContext(p, a);
        T.Snapshot memory before_ = IStreamArtistOwner(suite.owners[2]).ownerStateSnapshotV2();
        bytes32 roots = _roots();
        restoreBlock = block.number;
        vm.roll(uint256(type(uint64).max) + 1);
        vm.expectRevert(
            abi.encodeWithSignature(
                "ArtistArchiveBlockNumberOverflow(uint256)", uint256(type(uint64).max) + 1
            )
        );
        ingress.registerIdentityRecoveryAction(currentId, calls, p, a);
        require(_roots() == roots, "auxiliary owner and archive rollback");
        (A.Association memory empty,,,) = _read();
        require(empty.associationHash == 0, "no leaked association");
        vm.roll(restoreBlock);
        bytes32 hash = ingress.registerIdentityRecoveryAction(currentId, calls, p, a);
        (A.Association memory item, A.Veto memory v, bytes32 executed, uint64 count) = _read();
        T.Snapshot memory after_ = IStreamArtistOwner(suite.owners[2]).ownerStateSnapshotV2();
        require(
            after_.revision == before_.revision + 1
                && after_.recordChainTip == before_.recordChainTip
                && after_.stateRoot != before_.stateRoot,
            "one revision and no semantic append"
        );
        require(
            item.associationHash == hash && item.ownerRevision == after_.revision
                && item.preparedBy == address(this) && item.preparedAt == block.timestamp,
            "actual indexer receipt"
        );
        require(
            item.guardian.recordHash == guardian && item.action.callIndex == 1
                && item.action.callsHash == scheduled.callHash
                && item.action.callDataHash == calls[1].callDataHash,
            "full second-call and original guardian binding"
        );
        require(
            item.requestHash == keccak256(abi.encode(p))
                && item.acceptanceHash == keccak256(abi.encode(a))
                && item.contextHash == keccak256(abi.encode(context)),
            "exact immutable preimages"
        );
        require(
            keccak256(abi.encode(ingress.identityRecoveryContext(p, a)))
                == keccak256(abi.encode(context)),
            "registration cannot change scheduled context"
        );
        (bool used, uint256 hint) =
            ingress.rotationAcceptanceNonceState(artistId, p.newAddress, a.nonce);
        require(
            !used && hint == 0 && count == 1 && executed == 0 && v.vetoer == address(0),
            "no acceptance or execution created"
        );
        roots = _roots();
        vm.expectRevert();
        ingress.registerIdentityRecoveryAction(currentId, calls, p, a);
        require(roots == _roots(), "duplicate immutable association");
    }

    function testActualGuardianVetoAfterNotBeforeAndAuthoritativeCancellationReplacement() public {
        _guarded();
        IdentityRecovery.Request memory p = _terms();
        T.Authorization memory a = _acceptance(p);
        GovernanceCall[] memory calls = _schedule(keccak256("vetoed action"), p, a);
        ingress.registerIdentityRecoveryAction(currentId, calls, p, a);
        vm.warp(uint256(scheduled.notBefore) + 1);
        bytes32 reason = keccak256("registered guardian veto");
        bytes32 roots = _roots();
        vm.expectRevert(abi.encodeWithSelector(A.InvalidRecoveryGuardian.selector, address(this)));
        ingress.vetoIdentityRecovery(artistId, reason);
        require(roots == _roots(), "unrelated actor denied");
        restoreBlock = block.number;
        vm.roll(uint256(type(uint64).max) + 1);
        vm.expectRevert();
        this.vetoByGuardian(reason);
        require(roots == _roots(), "late veto archive rollback");
        vm.roll(restoreBlock);
        T.Snapshot memory before_ = IStreamArtistOwner(suite.owners[2]).ownerStateSnapshotV2();
        vm.recordLogs();
        this.vetoByGuardian(reason);
        Vm.Log[] memory logs = vm.getRecordedLogs();
        bool found;
        for (uint256 i; i < logs.length; ++i) {
            if (
                logs[i].emitter == suite.owners[2]
                    && logs[i].topics[0]
                        == keccak256(
                            "ArtistIdentityRecoveryVetoed(uint16,bytes32,address,bytes32,bytes32)"
                        )
            ) {
                require(
                    logs[i].topics.length == 3 && logs[i].topics[1] == artistId
                        && logs[i].topics[2] == bytes32(uint256(uint160(address(delegateSafe))))
                        && keccak256(logs[i].data)
                            == keccak256(abi.encode(uint16(2), reason, currentId)),
                    "exact veto event"
                );
                found = true;
            }
        }
        require(found, "veto event found");
        (, A.Veto memory v,,) = _read();
        T.Snapshot memory after_ = IStreamArtistOwner(suite.owners[2]).ownerStateSnapshotV2();
        require(
            v.vetoer == address(delegateSafe) && v.reasonHash == reason
                && v.vetoedAt == block.timestamp && after_.revision == before_.revision + 1
                && after_.recordChainTip == before_.recordChainTip,
            "permanent veto no semantic append"
        );
        roots = _roots();
        scheduled.status = GovernanceActionStatus.EXECUTED;
        _publish();
        vm.expectRevert(abi.encodeWithSelector(A.RecoveryActionVetoed.selector, currentId));
        this.executeRegistered(p, a);
        _inactive();
        require(
            roots == _roots() && ingress.latestIdentityRecovery(artistId) == 0,
            "veto blocks actual op35 atomically"
        );
        scheduled.status = GovernanceActionStatus.SCHEDULED;
        _publish();
        bytes32 oldId = currentId;
        GovernanceAction memory oldAction = scheduled;
        calls = _schedule(keccak256("replacement action"), p, a);
        vm.expectRevert(abi.encodeWithSelector(A.RecoveryActionStillLive.selector, oldId));
        ingress.registerIdentityRecoveryAction(currentId, calls, p, a);
        oldAction.status = GovernanceActionStatus.CANCELLED;
        avm.mockCall(
            manager.governanceAuthority(),
            abi.encodeCall(IStreamGovernanceActionFacts.governanceActionFacts, (oldId)),
            abi.encode(
                IStreamGovernanceActionFacts.ActionFacts(
                    oldAction.status,
                    2,
                    oldAction.callHash,
                    oldAction.notBefore,
                    oldAction.expiresAfter
                )
            )
        );
        ingress.registerIdentityRecoveryAction(currentId, calls, p, a);
        (A.Association memory next,,,) = _read();
        require(next.action.actionId == currentId, "cancelled old action permits new association");
        (, A.Veto memory oldVeto,,) = ingress.identityRecoveryActionState(artistId, oldId);
        require(oldVeto.vetoer == address(delegateSafe), "old veto never erased");
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

    function admitGuardianBoundary(uint256 nonce, bool empty) external returns (bytes32) {
        require(msg.sender == address(this), "fixture caller");
        address[] memory members = new address[](empty ? 0 : 1);
        if (!empty) members[0] = address(artist);
        return _guardianRecord(members, empty ? 0 : 1, 0, nonce);
    }

    function testActualGuardianAdmissionCountIncludesUnselectedAndArchiveRollback() public {
        restoreBlock = block.number;
        bytes32 roots = _roots();
        vm.roll(uint256(type(uint64).max) + 1);
        vm.expectRevert();
        this.admitGuardianBoundary(9, false);
        require(_roots() == roots, "op28 late count rollback");
        vm.roll(restoreBlock);
        (,,, uint64 count) = ingress.identityRecoveryActionState(artistId, 0);
        require(count == 0, "failed admission uncounted");
        bytes32 first = this.admitGuardianBoundary(9, false);
        bytes32 second = this.admitGuardianBoundary(1, true);
        (,,, bytes32 head) = ingress.guardianSet(artistId);
        (,,, count) = ingress.identityRecoveryActionState(artistId, 0);
        require(
            count == 2 && head == first && first != second
                && ingress.guardianSetRecord(second).recordHash == second,
            "lower nonce empty record retained and counted"
        );
        _newRotationSafe(36004);
        _governedInitialContest();
        IdentityRecovery.Request memory p = _terms();
        T.Authorization memory a = _acceptance(p);
        IdentityRecovery.Context memory context = ingress.identityRecoveryContext(p, a);
        require(context.oldValueHash != 0, "complete two-record initial history now supported");
        (GH.Head memory history, GH.Entry memory entry,, uint64 firstIndex) = IStreamArtistGuardianHistory(
                suite.owners[2]
            ).guardianHistoryState(artistId, 2, address(artist), 0);
        require(
            history.count == 2 && history.commitment == entry.commitment
                && entry.recordHash == second && entry.index == 2 && firstIndex == 1,
            "actual original and unselected records form complete indexed history"
        );
    }

    function _historySnapshot(
        bytes32 action,
        bytes32 association,
        uint64 count,
        address member,
        uint64 first
    ) private view returns (GH.Snapshot memory snapshot) {
        (GH.Head memory head,, GH.Snapshot memory captured, uint64 index) = IStreamArtistGuardianHistory(
                suite.owners[2]
            ).guardianHistoryState(artistId, 0, member, action);
        require(
            head.count == count && captured.count == count
                && head.commitment == captured.historyCommitment
                && captured.associationHash == association && captured.artistId == artistId
                && index == first,
            "actual complete immutable action prefix"
        );
        return captured;
    }

    function _replaceGuardianWithEmpty(uint256 firstNonce, bool lowerNonceMember)
        private
        returns (bytes32 original, bytes32 selected)
    {
        _sizes();
        _delegateSetup();
        _newRotationSafe(36009);
        address[] memory members = new address[](1);
        members[0] = lowerNonceMember ? address(artist) : address(delegateSafe);
        original = _guardianRecord(members, 1, 10 days, firstNonce);
        if (lowerNonceMember) {
            members[0] = address(delegateSafe);
            original = _guardianRecord(members, 1, 20 days, 1);
        }
        selected = _guardianRecord(new address[](0), 0, 0, firstNonce + 1);
        (,,, bytes32 current) = ingress.guardianSet(artistId);
        require(current == selected && original != selected, "new selected empty set");
        _governedInitialContest();
    }

    function testActualOldSelectedGuardianRetainsVetoAfterEmptyReplacement() public {
        (bytes32 original, bytes32 selected) = _replaceGuardianWithEmpty(9, false);
        IdentityRecovery.Request memory p = _terms();
        T.Authorization memory a = _acceptance(p);
        GovernanceCall[] memory calls = _schedule(keccak256("old selected historical veto"), p, a);
        bytes32 roots = _roots();
        restoreBlock = block.number;
        vm.roll(uint256(type(uint64).max) + 1);
        vm.expectRevert();
        ingress.registerIdentityRecoveryAction(currentId, calls, p, a);
        require(_roots() == roots, "historical preparation Archive rollback");
        (,, GH.Snapshot memory empty,) = IStreamArtistGuardianHistory(suite.owners[2])
            .guardianHistoryState(artistId, 0, address(delegateSafe), currentId);
        require(empty.associationHash == 0, "failed preparation has no history snapshot");
        vm.roll(restoreBlock);
        bytes32 association = ingress.registerIdentityRecoveryAction(currentId, calls, p, a);
        GH.Snapshot memory before_ =
            _historySnapshot(currentId, association, 2, address(delegateSafe), 1);
        (A.Association memory saved,,,) = _read();
        require(
            saved.guardian.recordHash == selected && saved.guardian.terms.guardians.length == 0,
            "standing cannot come from selected empty record"
        );
        (, GH.Entry memory first,,) = IStreamArtistGuardianHistory(suite.owners[2])
            .guardianHistoryState(artistId, 1, address(delegateSafe), currentId);
        require(
            first.recordHash == original && first.index == 1, "actual historical member provenance"
        );
        vm.warp(uint256(scheduled.expiresAfter) + 1);
        this.vetoByGuardian(keccak256("old guardian full staged veto"));
        (, A.Veto memory veto,,) = _read();
        require(
            veto.vetoer == address(delegateSafe),
            "old selected member vetoes while still SCHEDULED after expiry"
        );
        require(
            keccak256(abi.encode(before_))
                == keccak256(
                    abi.encode(
                        _historySnapshot(currentId, association, 2, address(delegateSafe), 1)
                    )
                ),
            "veto does not replace saved history"
        );
    }

    function testActualUnselectedGuardianVetoThenFreshRecoveryKeepsSelectedWindow() public {
        (bytes32 unselected, bytes32 selected) = _replaceGuardianWithEmpty(9, true);
        IdentityRecovery.Request memory p = _terms();
        T.Authorization memory a = _acceptance(p);
        GovernanceCall[] memory calls = _schedule(keccak256("unselected guardian veto"), p, a);
        bytes32 association = ingress.registerIdentityRecoveryAction(currentId, calls, p, a);
        _historySnapshot(currentId, association, 3, address(delegateSafe), 2);
        (, GH.Entry memory entry,,) = IStreamArtistGuardianHistory(suite.owners[2])
            .guardianHistoryState(artistId, 2, address(delegateSafe), currentId);
        require(
            entry.recordHash == unselected && ingress.guardianSetRecord(unselected).nonce == 1,
            "lower nonce never selected but admitted"
        );
        vm.warp(scheduled.notBefore);
        this.vetoByGuardian(keccak256("unselected record veto"));
        bytes32 oldId = currentId;
        GovernanceAction memory old = scheduled;
        scheduled.status = GovernanceActionStatus.EXECUTED;
        _publish();
        bytes32 roots = _roots();
        vm.expectRevert(abi.encodeWithSelector(A.RecoveryActionVetoed.selector, currentId));
        this.executeRegistered(p, a);
        _inactive();
        require(
            roots == _roots() && ingress.latestIdentityRecovery(artistId) == 0,
            "historical veto blocks real recovery"
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
        calls = _schedule(keccak256("fresh action after historical veto"), p, a);
        bytes32 nextAssociation = ingress.registerIdentityRecoveryAction(currentId, calls, p, a);
        _historySnapshot(currentId, nextAssociation, 3, address(delegateSafe), 2);
        vm.warp(scheduled.notBefore);
        scheduled.status = GovernanceActionStatus.EXECUTED;
        _publish();
        bytes32 record = this.executeRegistered(p, a);
        IdentityRecovery.Record memory recovered = ingress.identityRecoveryRecord(record);
        require(
            record != 0 && recovered.postContestSeconds == 7 days,
            "operative empty set uses global window, not every historical latency"
        );
        (, bytes32 saved,) =
            IStreamArtistIdentityRecoveryOwner(suite.owners[2]).recoveryTransitionStanding(record);
        require(saved == selected, "common standing preserves singular selected snapshot");
        (, A.Veto memory permanent,,) = ingress.identityRecoveryActionState(artistId, oldId);
        require(permanent.vetoer == address(delegateSafe), "earlier veto remains permanent");
        _historySnapshot(oldId, association, 3, address(delegateSafe), 2);
        _sizes();
    }
}

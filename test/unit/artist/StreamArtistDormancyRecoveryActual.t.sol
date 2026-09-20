// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    IStreamArtistGuardianHistory
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistGuardianHistory.sol";
import {
    StreamArtistGuardianHistoryTypes as GH
} from "../../../smart-contracts/interfaces/stream/artist/StreamArtistGuardianHistoryTypes.sol";

import "./StreamArtistDormancyLifecycle.t.sol";
import { Vm } from "../../regression/legacy/helpers/CharacterizationTestBase.sol";
import { OfficialSafe } from "../../helpers/OfficialSafeFixture.sol";
import {
    StreamArtistGuardianAppealTypes as DormancyAppeal
} from "../../../smart-contracts/interfaces/stream/artist/StreamArtistGuardianAppealTypes.sol";
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
    StreamArtistRecoveryActionTypes as RA
} from "../../../smart-contracts/interfaces/stream/artist/StreamArtistRecoveryActionTypes.sol";
import {
    IStreamGovernanceActionFacts
} from "../../../smart-contracts/interfaces/stream/governance/IStreamGovernanceActionFacts.sol";
import {
    GovernanceCall,
    GovernanceAction,
    GovernanceActionStatus
} from "../../../smart-contracts/interfaces/stream/governance/StreamGovernanceTypes.sol";

import {
    StreamArtistGuardianVestingTypes as V
} from "../../../smart-contracts/interfaces/stream/artist/StreamArtistGuardianVestingTypes.sol";
import "../../../smart-contracts/interfaces/stream/artist/IStreamArtistGuardianVestingHistory.sol";

interface DormancyRecoveryStorageVm {
    function record() external;
    function accesses(address target) external returns (bytes32[] memory, bytes32[] memory);
}

/// @notice Actual designated op43→op33→registered op35 with Safe/Archive; typed Executor/Core only.
contract StreamArtistDormancyRecoveryActualTest is StreamArtistDormancyLifecycleTest {
    GovernanceAction internal scheduled;
    bytes32 internal currentId;
    bytes32 internal origin;
    bytes32 internal noticeHash;
    bytes32 internal originalGuardian;
    bytes32 internal lowerGuardian;
    bytes32 internal selectedGuardian;
    bytes32 private originalPlan;
    bytes32 private beforeHistory;
    bytes32 private livingRotation;
    address private living;
    uint64 internal windowEnd;
    error LateRecoveryArchive();

    function _snapshot(bytes32 record) private view returns (V.Snapshot memory v) {
        v = IStreamArtistGuardianVestingHistory(suite.owners[2])
            .guardianVestingSnapshot(artistId, record);
    }

    function _originals() private view returns (bytes32) {
        (Dorm.Notice memory n, uint8 phase, Dorm.Terminal memory t) =
            _dorm().dormancyRecord(noticeHash);
        return keccak256(
            abi.encode(
                n,
                phase,
                t,
                _snapshot(origin),
                ingress.artistTransitionState(origin),
                ingress.guardianSetRecord(originalGuardian),
                ingress.guardianSetRecord(lowerGuardian),
                ingress.successorDesignationRecord(originalPlan)
            )
        );
    }

    function prepareDormancyOrigin(bool priorRotation) external {
        require(msg.sender == address(this), "self only");
        _accept();
        _payout();
        _delegateSetup();
        living = address(artist);
        address[] memory members = new address[](1);
        members[0] = living;
        originalGuardian = _guardianRecord(members, 1, 10 days, 900);
        members[0] = address(delegateSafe);
        lowerGuardian = _guardianRecord(members, 1, 20 days, 100);
        _newRotationSafe(9501);
        OfficialSafe successor = rotationSafe;
        uint256[] memory successorKeys = rotationKeys;
        Succ.Designation memory plan = _successorTerms(address(successor), 2);
        plan.grantedCapabilities = 256;
        originalPlan = _successionRecord(plan);
        if (priorRotation) {
            _newRotationSafe(9502);
            livingRotation = _stageRotation(0);
            _executeTimedRotation(livingRotation);
            _adoptRotatedSafe();
        }
        rotationSafe = successor;
        rotationKeys = successorKeys;
    }

    function completeDormancyOrigin() external {
        require(msg.sender == address(this), "self only");
        noticeHash = this.beginDormancyNotice();
        origin = this.completeDormancyNotice(noticeHash);
        _adoptRotatedSafe();
        windowEnd = ingress.artistTransitionState(origin).postWindowEndsAt;
        V.Snapshot memory v = _snapshot(origin);
        require(
            v.operationId == 43 && v.authorityClass == 3 && v.guardians.count == 2
                && v.previousTransitionRecordHash == livingRotation,
            "actual op43 original complete prefix"
        );
        selectedGuardian = originalGuardian;
    }

    function freshDormancyGuardian() external {
        require(msg.sender == address(this), "self only");
        vm.warp(windowEnd);
        // The fresh frame below observes time after warp for the original signed op28.
        this.writeDormancyGuardian();
    }

    function writeDormancyGuardian() external {
        require(msg.sender == address(this), "self only");
        address[] memory members = new address[](2);
        members[0] = living;
        members[1] = address(delegateSafe);
        if (members[0] > members[1]) (members[0], members[1]) = (members[1], members[0]);
        selectedGuardian = _guardianRecord(members, 1, 15 days, 1001);
        R.GuardianRecord memory g = ingress.guardianSetRecord(selectedGuardian);
        require(
            g.authorityClass == 3 && g.signer == address(artist)
                && g.provisional.transitionRecordHash == 0,
            "fresh current successor guardian"
        );
    }

    function fileDormancyRecoveryCause(bool early) external {
        require(msg.sender == address(this), "self only");
        vm.warp(early ? windowEnd - 1 : windowEnd);
        this.recordDormancyRecoveryCause();
    }

    function recordDormancyRecoveryCause() external {
        require(msg.sender == address(this), "self only");
        ArtistUnitGovernance authority = ArtistUnitGovernance(manager.governanceAuthority());
        ArtistUnitRoles(suite.roleRegistry).setArbiter(address(artist), true);
        authority.configureContestReads(
            suite.roleRegistry,
            address(artist),
            keccak256("compromise reason"),
            "urn:dormancy:recovery"
        );
        (bytes32 scope, bytes32 oldHash, bytes32 newHash) = ingress.identityContestGovernanceContext(
            artistId, origin, keccak256("compromise evidence"), keccak256("compromise reason")
        );
        authority.executeModuleContext(
            address(ingress), _contestData(origin), 1, scope, oldHash, newHash
        );
        beforeHistory = _originals();
        _newRotationSafe(9503);
    }

    function _terms() private view returns (IdentityRecovery.Request memory p) {
        Dismissal.Cause memory cause = ingress.currentIdentityContestCause(artistId);
        return IdentityRecovery.Request(
            artistId,
            address(rotationSafe),
            3,
            cause.causeHash,
            ingress.latestIdentityContestDismissal(artistId),
            cause.facts.evidenceHash,
            cause.facts.reasonHash,
            new bytes32[](0)
        );
    }

    function prepareDormancyRecovery(bytes32 action)
        external
        returns (IdentityRecovery.Request memory p, T.Authorization memory a)
    {
        require(msg.sender == address(this), "self only");
        p = _terms();
        a = _acceptance(p);
        GovernanceCall[] memory calls = _schedule(action, p, a);
        ingress.registerIdentityRecoveryAction(currentId, calls, p, a);
        (RA.Association memory association,,, uint64 count) = _read();
        require(
            association.guardian.recordHash == selectedGuardian
                && count == (selectedGuardian == originalGuardian ? 2 : 3),
            "exact selected guardian and complete frozen history"
        );
    }

    function enterDormancyExecution() external {
        require(msg.sender == address(this), "self only");
        vm.warp(scheduled.notBefore);
        scheduled.status = GovernanceActionStatus.EXECUTED;
        _publish();
    }

    function _setupRecovery(bool prior, bool fresh, bool early) private {
        this.prepareDormancyOrigin(prior);
        this.completeDormancyOrigin();
        if (fresh) this.freshDormancyGuardian();
        this.fileDormancyRecoveryCause(early);
    }

    function _assertRecovery(bytes32 record, IdentityRecovery.Request memory p) private view {
        T.Identity memory current = _identity().identity(artistId);
        Estate.AuthorityCapabilities memory caps = ingress.currentAuthorityCapabilities(artistId);
        require(
            current.authorityClass == 3 && current.status == 3
                && current.authorityAddress == p.newAddress && caps.effectiveCapabilities == 256
                && caps.activationRecordHash == origin,
            "original appointed estate authority survives"
        );
        V.Snapshot memory v = _snapshot(record);
        require(
            v.operationId == 35 && v.authorityClass == 3 && v.previousTransitionRecordHash == origin
                && v.previousCommitment == _snapshot(origin).commitment,
            "new recovery custody link"
        );
        _assertOriginalRecoveryReceipts(record);
        require(
            _operationPayload(35, manager.governanceAuthority(), record).length != 0
                && _originals() == beforeHistory,
            "actual Archive and immutable appointment history"
        );
    }

    /// @dev Independent thirteen-word receipt oracle. The original owner prefix packs
    /// revision and record sequence in slot0; the public snapshot independently checks revision.
    /// These assertions run immediately after recovery, before any later owner mutation.
    function _assertOriginalRecoveryReceipts(bytes32 record) internal view {
        IStreamArtistOwner owner = IStreamArtistOwner(suite.owners[2]);
        T.Snapshot memory snapshot = owner.ownerStateSnapshotV2();
        uint256 prefix = uint256(vm.load(address(owner), bytes32(0)));
        uint64 sequence = uint64(prefix >> 64);
        require(uint64(prefix) == snapshot.revision && sequence >= 2, "actual owner receipt cursor");
        IdentityRecovery.Record memory saved = ingress.identityRecoveryRecord(record);
        require(saved.recordHash == record && record != 0, "actual immutable recovery record");
        bytes32 primaryDomain = 0x459749364fd07c3a8f1998b82d893d33ef0942c30d94666b42dac1e37ba5feff;
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
        words[8] = bytes32(uint256(snapshot.revision));
        words[9] = bytes32(uint256(sequence - 1));
        words[10] = bytes32(uint256(uint160(manager.governanceAuthority())));
        words[11] = primaryDomain;
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
            IStreamArtistIdentityRecoveryOwner(address(owner)).identityRecoveryReceipts(record);
        require(
            primary == expectedPrimary && occurrence == expectedOccurrence
                && secondary == expectedSecondary && primary != record && secondary != primary,
            "exact two typed receipt commitments and secondary occurrence"
        );
    }

    function testDesignatedDormancyRecoveryPreservesOriginalAuthorityAndReceipts() public {
        _setupRecovery(false, false, false);
        (IdentityRecovery.Request memory p, T.Authorization memory a) =
            this.prepareDormancyRecovery(keccak256("dormancy recovery"));
        this.enterDormancyExecution();
        bytes32 record = this.executeRegistered(p, a);
        _assertRecovery(record, p);
        (bool ok,) = address(this).call(abi.encodeCall(this.executeRegistered, (p, a)));
        require(
            !ok && ingress.latestIdentityRecovery(artistId) == record,
            "executed cause/action cannot replay"
        );
    }

    function testDormancyRecoveryRetainsPlanWrittenBeforeLivingRotation() public {
        _setupRecovery(true, false, false);
        require(
            _snapshot(origin).previousCommitment == _snapshot(livingRotation).commitment
                && ingress.successorDesignationRecord(originalPlan).signer == living,
            "original signer and actual living parent"
        );
        (IdentityRecovery.Request memory p, T.Authorization memory a) =
            this.prepareDormancyRecovery(keccak256("rotated living dormancy"));
        this.enterDormancyExecution();
        _assertRecovery(this.executeRegistered(p, a), p);
    }

    function testDormancyRecoveryAdmitsFreshClass3GuardianWithoutLosingPrefix() public {
        _setupRecovery(false, true, false);
        (IdentityRecovery.Request memory p, T.Authorization memory a) =
            this.prepareDormancyRecovery(keccak256("fresh estate guardian"));
        require(
            ingress.identityRecoveryContext(p, a).postContestSeconds == 15 days,
            "operative current guardian timing"
        );
        this.enterDormancyExecution();
        _assertRecovery(this.executeRegistered(p, a), p);
    }

    function testLowerNonceLivingGuardianStillVetoesDormancyRecovery() public {
        _setupRecovery(false, false, false);
        (IdentityRecovery.Request memory p, T.Authorization memory a) =
            this.prepareDormancyRecovery(keccak256("dormancy lifetime veto"));
        require(
            executeSafe(
                delegateSafe,
                delegateKeys,
                address(ingress),
                0,
                abi.encodeCall(
                    IStreamArtistRecoveryAction.vetoIdentityRecovery,
                    (artistId, keccak256("original lower nonce objection"))
                ),
                0
            ),
            "actual lower nonce Safe veto"
        );
        (, RA.Veto memory veto,,) = _read();
        require(veto.vetoer == address(delegateSafe), "original lifetime guardian witness");
        this.enterDormancyExecution();
        avm.expectPartialRevert(RA.RecoveryActionVetoed.selector);
        this.executeRegistered(p, a);
        require(
            ingress.latestIdentityRecovery(artistId) == 0 && _originals() == beforeHistory,
            "veto remains permanent for action"
        );
    }

    function testDormancyInWindowCauseCannotMatureByWaiting() public {
        _setupRecovery(false, false, true);
        (IdentityRecovery.Request memory p, T.Authorization memory a) =
            this.dormancyRecoveryRequest();
        bytes32 original = keccak256(abi.encode(p, a));
        avm.expectPartialRevert(IdentityRecovery.UnsupportedIdentityRecoveryProfile.selector);
        ingress.identityRecoveryContext(p, a);
        vm.warp(uint256(windowEnd) + 1 days);
        avm.expectPartialRevert(IdentityRecovery.UnsupportedIdentityRecoveryProfile.selector);
        ingress.identityRecoveryContext(p, a);
        require(
            keccak256(abi.encode(p, a)) == original,
            "identical still-live acceptance cannot mature an early cause"
        );
    }

    function dormancyRecoveryRequest()
        external
        returns (IdentityRecovery.Request memory p, T.Authorization memory a)
    {
        require(msg.sender == address(this), "self only");
        p = _terms();
        a = _acceptance(p);
    }

    function testSavedDormancyPlanDriftInvalidatesStagedContextAndExactRestoreRetries() public {
        _setupRecovery(false, false, false);
        (IdentityRecovery.Request memory p, T.Authorization memory a) =
            this.prepareDormancyRecovery(keccak256("saved dormancy plan"));
        IdentityRecovery.Context memory before_ = ingress.identityRecoveryContext(p, a);
        DormancyRecoveryStorageVm trace = DormancyRecoveryStorageVm(address(vm));
        trace.record();
        _dorm().dormancyRecord(noticeHash);
        (bytes32[] memory reads,) = trace.accesses(suite.owners[2]);
        bytes32 slot;
        uint256 count;
        for (uint256 i; i < reads.length; ++i) {
            if (vm.load(suite.owners[2], reads[i]) == originalPlan) {
                slot = reads[i];
                ++count;
            }
        }
        require(count == 1, "unique actual saved appointment designation slot");
        vm.store(suite.owners[2], slot, keccak256("foreign saved plan"));
        avm.expectPartialRevert(IdentityRecovery.UnsupportedIdentityRecoveryProfile.selector);
        ingress.identityRecoveryContext(p, a);
        vm.store(suite.owners[2], slot, originalPlan);
        require(
            keccak256(abi.encode(ingress.identityRecoveryContext(p, a)))
                == keccak256(abi.encode(before_)),
            "exact original staged context restored"
        );
        this.enterDormancyExecution();
        _assertRecovery(this.executeRegistered(p, a), p);
    }

    function testDormancyRecoveryLateArchiveRollbackAllowsIdenticalSignedRetry() public {
        _setupRecovery(false, false, false);
        (IdentityRecovery.Request memory p, T.Authorization memory a) =
            this.prepareDormancyRecovery(keccak256("dormancy late archive"));
        this.enterDormancyExecution();
        bytes32 roots = _roots();
        bytes32 principal = keccak256(abi.encode(_identity().identity(artistId)));
        avm.mockCallRevert(
            suite.archive,
            abi.encodePacked(IStreamArtistArchiveV2.appendArtistEvidenceV2.selector),
            abi.encodeWithSelector(LateRecoveryArchive.selector)
        );
        avm.expectRevert(LateRecoveryArchive.selector);
        this.executeRegistered(p, a);
        (bool used,) = ingress.rotationAcceptanceNonceState(artistId, p.newAddress, a.nonce);
        require(
            !used && _roots() == roots
                && keccak256(abi.encode(_identity().identity(artistId))) == principal
                && ingress.latestIdentityRecovery(artistId) == 0 && _originals() == beforeHistory,
            "all original replay/history rollback"
        );
        avm.clearMockedCalls();
        _publish();
        _assertRecovery(this.executeRegistered(p, a), p);
    }

    function testDormancyClassEscalationAndUnprovenProtectedSupersessionStayClosed() public {
        _setupRecovery(false, false, false);
        this.checkDormancyClasses();
    }

    function checkDormancyClasses() external {
        require(msg.sender == address(this), "self only");
        IdentityRecovery.Request memory p = _terms();
        T.Authorization memory a = _acceptance(p);
        p.vestedAuthorityClass = 1;
        avm.expectPartialRevert(IdentityRecovery.UnsupportedIdentityRecoveryProfile.selector);
        ingress.identityRecoveryContext(p, a);
        p.vestedAuthorityClass = 4;
        avm.expectPartialRevert(IdentityRecovery.UnsupportedIdentityRecoveryProfile.selector);
        ingress.identityRecoveryContext(p, a);
        p.vestedAuthorityClass = 3;
        p.supersededRecordHashes = new bytes32[](1);
        p.supersededRecordHashes[0] = lowerGuardian;
        vm.expectRevert(
            abi.encodeWithSelector(DormancyAppeal.InvalidGuardianAppeal.selector, p.evidenceHash)
        );
        ingress.identityRecoveryContext(p, a);
        p.supersededRecordHashes = new bytes32[](0);
        require(
            ingress.identityRecoveryContext(p, a).causeHash == p.expectedCauseHash,
            "same original valid request remains"
        );
    }

    function _acceptance(IdentityRecovery.Request memory p)
        internal
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
        internal
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
        _publish();
    }

    function _publish() internal {
        address authority = manager.governanceAuthority();
        // clearMockedCalls also removes these typed Executor prerequisites. Restore the
        // same sealed/delay facts along with the saved action before an identical retry.
        bytes32[29] memory bootstrap;
        bootstrap[0] = bytes32(uint256(1));
        bootstrap[1] = bytes32(uint256(1));
        avm.mockCall(
            authority,
            abi.encodeWithSelector(IStreamGovernanceReads.systemManifestBootstrapState.selector),
            abi.encode(bootstrap)
        );
        avm.mockCall(
            authority,
            abi.encodeCall(IStreamGovernanceReads.minimumDelay, (uint8(2))),
            abi.encode(uint64(72 hours))
        );
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

    function _read()
        private
        view
        returns (RA.Association memory a, RA.Veto memory v, bytes32 executed, uint64 count)
    {
        return ingress.identityRecoveryActionState(artistId, currentId);
    }
}

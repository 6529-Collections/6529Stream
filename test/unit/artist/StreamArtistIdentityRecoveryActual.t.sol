// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

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

/// @dev Actual facade/Coordinator/owners/fixed children/Safe/Archive; Core and canonical Executor/roles remain typed fixture boundaries.
contract StreamArtistIdentityRecoveryActualTest is ArtistOnboardingFixture {
    uint256 private recoveryRestoreBlock;

    struct RecoveryCohort {
        bytes32 record;
        bytes32 saved;
        bytes32 priorDocument;
        bytes32 revision;
        bytes32 document;
        uint64 end;
        OfficialSafe priorSafe;
        uint256[] priorKeys;
    }

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

    function _execute(
        IdentityRecovery.Request memory p,
        T.Authorization memory a,
        uint8 actionClass,
        bool sealed_
    ) private returns (bytes32) {
        ArtistUnitGovernance authority = ArtistUnitGovernance(manager.governanceAuthority());
        authority.configureContestReads(
            suite.roleRegistry, address(artist), p.reasonHash, "urn:unit:recovery"
        );
        // The real sealed-Executor witness has a separate governance cohort. This exact 29-word response is a unit boundary.
        bytes32[29] memory bootstrap;
        bootstrap[0] = bytes32(uint256(1));
        bootstrap[1] = sealed_ ? bytes32(uint256(1)) : bytes32(0);
        avm.mockCall(
            address(authority),
            abi.encodeWithSelector(IStreamGovernanceReads.systemManifestBootstrapState.selector),
            abi.encode(bootstrap)
        );
        IdentityRecovery.Context memory c =
            IStreamArtistIdentityRecovery(address(ingress)).identityRecoveryContext(p, a);
        authority.executeModuleContext(
            address(ingress),
            abi.encodeCall(IStreamArtistIdentityRecovery.recoverArtistIdentity, (p, a)),
            actionClass,
            c.scopeHash,
            c.oldValueHash,
            c.newValueHash
        );
        return IStreamArtistIdentityRecovery(address(ingress)).latestIdentityRecovery(artistId);
    }

    function executeRecoveryBoundary(
        IdentityRecovery.Request calldata p,
        T.Authorization calldata a,
        uint8 actionClass,
        bool sealed_
    ) external {
        require(msg.sender == address(this), "fixture caller");
        _execute(p, a, actionClass, sealed_);
    }

    function _recordHash(IdentityRecovery.Record memory item) private view returns (bytes32) {
        bytes32[12] memory w;
        w[0] = 0x459749364fd07c3a8f1998b82d893d33ef0942c30d94666b42dac1e37ba5feff;
        w[1] = bytes32(block.chainid);
        w[2] = bytes32(uint256(uint160(address(ingress))));
        w[3] = item.fields.artistId;
        w[4] = bytes32(uint256(uint160(item.fields.oldAddress)));
        w[5] = bytes32(uint256(uint160(item.fields.newAddress)));
        w[6] = bytes32(uint256(item.fields.vestedAuthorityClass));
        w[7] = item.fields.evidenceHash;
        w[8] = item.fields.reasonHash;
        w[9] = keccak256(
            abi.encode(
                bytes32(0x0c8573762967a1af597f2a7afc4b655a87b3e22d2b11fbab6cf13c6f7b1396ae),
                new bytes32[](0)
            )
        );
        w[10] = item.fields.governanceActionId;
        w[11] = bytes32(uint256(item.fields.recoveredAt));
        return keccak256(abi.encode(w));
    }

    function _savedRecovery(bytes32 record) private view returns (bytes32) {
        (bytes32 primary, bytes32 occurrence, bytes32 secondary) =
            IStreamArtistIdentityRecoveryOwner(suite.owners[2]).identityRecoveryReceipts(record);
        return keccak256(
            abi.encode(
                IStreamArtistIdentityRecovery(address(ingress)).identityRecoveryRecord(record),
                primary,
                occurrence,
                secondary
            )
        );
    }

    function executeRecoveryContestBoundary(
        OfficialSafe oldSafe,
        uint256[] calldata oldKeys,
        bytes32 record
    ) external {
        require(msg.sender == address(this), "test only");
        require(
            executeSafe(oldSafe, oldKeys, address(ingress), 0, _contestData(record), 0),
            "actual retired Safe contest"
        );
    }

    function executeRecoveryFreshContestBoundary(
        OfficialSafe oldSafe,
        uint256[] calldata oldKeys,
        bytes32 record
    ) external {
        require(msg.sender == address(this), "test only");
        require(
            executeSafe(
                oldSafe,
                oldKeys,
                address(ingress),
                0,
                abi.encodeCall(
                    IStreamArtistIdentityContest.contestArtistIdentity,
                    (
                        artistId,
                        record,
                        keccak256("distinct post-dismissal compromise evidence"),
                        keccak256("distinct post-dismissal compromise reason")
                    )
                ),
                0
            ),
            "actual retired Safe fresh contest"
        );
    }

    function _recoveryContestCohort(bool early) private {
        _sizes();
        _newRotationSafe(early ? 35010 : 35011);
        _governedInitialContest();
        IdentityRecovery.Request memory p = _terms();
        RecoveryCohort memory f;
        f.record = _execute(p, _acceptance(p), 2, true);
        f.saved = _savedRecovery(f.record);
        f.priorSafe = artist;
        f.priorKeys = keys;
        f.end =
        IStreamArtistRotationReads(suite.owners[2]).artistTransitionState(f.record).postWindowEndsAt;
        f.priorDocument = ingress.operativeIdentityRecord(artistId);
        _adoptRotatedSafe();
        bytes memory document = bytes("new recovery authority provisional identity document");
        f.document = keccak256(document);
        f.revision = _reviseDocument(document);
        require(
            ingress.operativeIdentityRecord(artistId) == f.priorDocument,
            "new-side revision waits for its recovery window"
        );
        vm.warp(early ? f.end - 1 : f.end);
        if (early) {
            bytes32 roots = _roots();
            recoveryRestoreBlock = block.number;
            vm.roll(uint256(type(uint64).max) + 1);
            vm.expectRevert();
            this.executeRecoveryContestBoundary(f.priorSafe, f.priorKeys, f.record);
            require(
                _roots() == roots
                    && IStreamArtistRotationReads(suite.owners[2])
                        .artistTransitionState(f.record)
                        .contestedAt == 0,
                "late Archive failure rolls cause, transition marker and all owner roots back"
            );
            vm.roll(recoveryRestoreBlock);
        }
        uint64 beforeRevision = IStreamArtistOwner(suite.owners[2]).ownerStateSnapshotV2().revision;
        this.executeRecoveryContestBoundary(f.priorSafe, f.priorKeys, f.record);
        R.TransitionState memory t =
            IStreamArtistRotationReads(suite.owners[2]).artistTransitionState(f.record);
        require(t.contestedAt == (early ? f.end - 1 : f.end), "exact recovery contest timestamp");
        require(
            IStreamArtistOwner(suite.owners[2]).ownerStateSnapshotV2().revision
                == beforeRevision + 1,
            "one operation33 owner commit"
        );
        Dismissal.Cause memory cause = ingress.currentIdentityContestCause(artistId);
        require(
            cause.facts.executedTransitionHash == f.record
                && cause.facts.incumbent == address(artist) && cause.facts.priorStatus == 1
                && cause.facts.actorRetirementHash == f.record,
            "actual saved cause and retired-address association"
        );
        vm.warp(uint256(f.end) + 1);
        bool eligible = IStreamArtistRotationOwner(suite.owners[2])
            .provisionalRecordEligible(artistId, R.ProvisionalAssociation(f.record, f.end));
        require(
            eligible == !early
                && ingress.operativeIdentityRecord(artistId)
                    == (early ? f.priorDocument : f.document),
            "recovery cohort obeys exact contest boundary"
        );
        (bytes32 active, uint64 end, bool contested) = ingress.activeAuthorityWindow(artistId);
        require(
            early
                ? active == f.record && end == f.end && contested
                : active == 0 && end == 0 && !contested,
            "common active window consumes stored marker"
        );
        bytes32 dismissal = _dismissalExecute(_dismissalRequest(), 1, 0);
        Dismissal.Closure memory closure = ingress.identityTransitionClosure(artistId, f.record);
        require(
            closure.artistId == artistId && closure.transitionRecordHash == f.record
                && closure.dismissalRecordHash == dismissal && closure.windowEndsAt == f.end
                && closure.contestedAt == t.contestedAt && closure.abandoned == early,
            "actual typed dismissal closes recovery transition"
        );
        require(
            ingress.identityRevisionRecord(f.revision).revisedRecordHash == f.document
                && ingress.operativeIdentityRecord(artistId)
                    == (early ? f.priorDocument : f.document),
            "raw child history retained and rejected cohort never matures"
        );
        (active, end, contested) = ingress.activeAuthorityWindow(artistId);
        require(
            active == 0 && end == 0 && !contested && _savedRecovery(f.record) == f.saved,
            "dismissal clears operative window without rewriting recovery or receipts"
        );
        bytes32 closed = keccak256(abi.encode(closure));
        vm.warp(uint256(f.end) + 2);
        bytes32 rootsBeforeReplay = _roots();
        vm.expectRevert();
        this.executeRecoveryContestBoundary(f.priorSafe, f.priorKeys, f.record);
        require(_roots() == rootsBeforeReplay, "dismissal cannot reopen an identical contest tuple");
        this.executeRecoveryFreshContestBoundary(f.priorSafe, f.priorKeys, f.record);
        require(
            IStreamArtistRotationReads(suite.owners[2]).artistTransitionState(f.record).contestedAt
                    == t.contestedAt
                && keccak256(abi.encode(ingress.identityTransitionClosure(artistId, f.record)))
                    == closed,
            "resolved marker and closure remain immutable under a later valid contest"
        );
    }

    function testActualRecoveryInWindowContestRollsBackAndDismissesProvisionalCohort() public {
        _recoveryContestCohort(true);
    }

    function testActualRecoveryContestAtEqualityPreservesMatureCohortAndClosure() public {
        _recoveryContestCohort(false);
    }

    function testActualInitialRecoverySafeProofArchiveAndTransitionConsumers() public {
        _sizes();
        _newRotationSafe(35001);
        _governedInitialContest();
        T.Identity memory beforeIdentity =
            IStreamArtistIdentityOwner(suite.owners[2]).identity(artistId);
        IdentityRecovery.Request memory p = _terms();
        T.Authorization memory a = _acceptance(p);
        T.Snapshot memory before_ = IStreamArtistOwner(suite.owners[2]).ownerStateSnapshotV2();
        vm.recordLogs();
        bytes32 hash = _execute(p, a, 2, true);
        Vm.Log[] memory logs = vm.getRecordedLogs();
        IdentityRecovery.Record memory item =
            IStreamArtistIdentityRecovery(address(ingress)).identityRecoveryRecord(hash);
        require(hash == _recordHash(item), "literal permanent twelve words");
        (bytes32 primaryReceipt, bytes32 occurrence, bytes32 secondaryReceipt) =
            IStreamArtistIdentityRecoveryOwner(suite.owners[2]).identityRecoveryReceipts(hash);
        require(
            primaryReceipt != 0 && secondaryReceipt != 0
                && occurrence
                    == keccak256(
                        abi.encode(
                            bytes32(
                                0x05c1b33dc3307a69a2b02b1fdcc96323c6c2dcb072805ca38ec6462ded34ce09
                            ),
                            uint16(2),
                            hash,
                            bytes32(
                                0x0c8573762967a1af597f2a7afc4b655a87b3e22d2b11fbab6cf13c6f7b1396ae
                            ),
                            item.fields.supersededRecordsHash
                        )
                    ),
            "actual stored pair receipts"
        );
        require(
            item.fields.oldAddress == address(artist)
                && item.fields.newAddress == address(rotationSafe)
                && item.fields.vestedAuthorityClass == 1,
            "same identity reassigned"
        );
        require(
            item.terms.expectedCauseHash == p.expectedCauseHash
                && ingress.latestIdentityContestDismissal(artistId) == p.expectedResolutionHash,
            "recovery never aliases dismissal"
        );
        require(
            IStreamArtistOwner(suite.owners[2]).ownerStateSnapshotV2().revision
                == before_.revision + 1,
            "one actual owner revision"
        );
        T.Identity memory afterIdentity =
            IStreamArtistIdentityOwner(suite.owners[2]).identity(artistId);
        require(
            afterIdentity.lastAuthorityActionAt == beforeIdentity.lastAuthorityActionAt
                && afterIdentity.nonceHint == beforeIdentity.nonceHint && afterIdentity.status == 1,
            "new-side acceptance is not current authority liveness"
        );
        R.TransitionState memory t =
            IStreamArtistRotationReads(suite.owners[2]).artistTransitionState(hash);
        require(
            t.recordHash == hash && t.artistId == artistId && t.phase == 2
                && t.executedAt == block.timestamp
                && t.postWindowEndsAt == block.timestamp + item.postContestSeconds,
            "actual third transition branch"
        );
        (bytes32 active, uint64 end, bool contested) = ingress.activeAuthorityWindow(artistId);
        require(active == hash && end == t.postWindowEndsAt && !contested, "actual active window");
        require(
            !IStreamArtistRotationOwner(suite.owners[2])
                .provisionalRecordEligible(artistId, R.ProvisionalAssociation(hash, end)),
            "new provisional cohort not mature"
        );
        uint256 count;
        for (uint256 i; i < logs.length; ++i) {
            if (
                logs[i].emitter == suite.owners[2] && logs[i].topics.length != 0
                    && logs[i].topics[0]
                        == keccak256(
                            "ArtistIdentityRecovered(uint16,bytes32,address,address,uint8,bytes32,bytes32,bytes32,uint64,bytes32,bytes32,bytes32[])"
                        )
            ) {
                ++count;
                require(
                    logs[i].topics.length == 4 && logs[i].topics[1] == artistId
                        && logs[i].topics[2] == bytes32(uint256(uint160(address(artist))))
                        && logs[i].topics[3] == bytes32(uint256(uint160(address(rotationSafe)))),
                    "actual recovery topics"
                );
                require(
                    keccak256(logs[i].data)
                        == keccak256(
                            abi.encode(
                                uint16(2),
                                uint8(1),
                                p.evidenceHash,
                                p.reasonHash,
                                item.fields.supersededRecordsHash,
                                item.fields.recoveredAt,
                                hash,
                                item.fields.governanceActionId,
                                p.supersededRecordHashes
                            )
                        ),
                    "exact event data"
                );
            }
        }
        require(
            count == 1 && _operationPayload(35, manager.governanceAuthority(), hash).length != 0,
            "one event and actual immutable Archive"
        );
        (address prior, bytes32 guardian, uint64 tail) =
            IStreamArtistIdentityRecoveryOwner(suite.owners[2]).recoveryTransitionStanding(hash);
        require(
            prior == address(artist) && guardian == 0 && tail == item.standingTailSeconds,
            "typed recovery standing"
        );
        vm.warp(end);
        require(
            IStreamArtistRotationOwner(suite.owners[2])
                .provisionalRecordEligible(artistId, R.ProvisionalAssociation(hash, end)),
            "actual maturity equality"
        );
        // Actual retired Safe must resolve recovery standing through the fixed same-Identity fallback.
        require(
            executeSafe(artist, keys, address(ingress), 0, _contestData(hash), 0),
            "actual prior Safe standing after recovery"
        );
        require(
            IStreamArtistIdentityOwner(suite.owners[2]).identity(artistId).status == 4,
            "later contest is actual"
        );
    }

    function testActualRecoveryLateArchiveFailureRestoresNonceOwnersAndSameAcceptance() public {
        _sizes();
        _newRotationSafe(35002);
        _governedInitialContest();
        IdentityRecovery.Request memory p = _terms();
        T.Authorization memory a = _acceptance(p);
        bytes32 before_ = _roots();
        recoveryRestoreBlock = block.number;
        vm.roll(uint256(type(uint64).max) + 1);
        vm.expectRevert(
            abi.encodeWithSignature(
                "ArtistArchiveBlockNumberOverflow(uint256)", uint256(type(uint64).max) + 1
            )
        );
        this.executeRecoveryBoundary(p, a, 2, true);
        require(
            _roots() == before_
                && IStreamArtistIdentityRecovery(address(ingress)).latestIdentityRecovery(artistId)
                    == 0,
            "late owner/pair rollback"
        );
        (bool used, uint256 hint) =
            ingress.rotationAcceptanceNonceState(artistId, address(rotationSafe), 0);
        require(!used && hint == 0, "shared nonce rollback");
        vm.roll(recoveryRestoreBlock);
        require(
            block.number == recoveryRestoreBlock && block.number <= type(uint64).max,
            "healthy block restored from fixture storage"
        );
        bytes32 hash = _execute(p, a, 2, true);
        require(hash != 0, "identical approved proof retry");
        (used, hint) = ingress.rotationAcceptanceNonceState(artistId, address(rotationSafe), 0);
        require(used && hint == 1, "original acceptance allocator");
    }

    function testActualRecoveryRejectsUnsealedOrdinaryWrongProofAndDirectOwnerCalls() public {
        _sizes();
        _newRotationSafe(35003);
        _governedInitialContest();
        IdentityRecovery.Request memory p = _terms();
        T.Authorization memory a = _acceptance(p);
        bytes32 before_ = _roots();
        avm.expectRevert(IdentityRecovery.InvalidIdentityRecoveryGovernance.selector);
        this.executeRecoveryBoundary(p, a, 2, false);
        avm.expectRevert(IdentityRecovery.InvalidIdentityRecoveryGovernance.selector);
        this.executeRecoveryBoundary(p, a, 1, true);
        T.Authorization memory bad = T.Authorization(a.nonce, a.time, hex"01");
        avm.expectRevert(T.InvalidSignature.selector);
        this.executeRecoveryBoundary(p, bad, 2, true);
        T.ActionContext memory c = T.ActionContext(
            35,
            manager.governanceAuthority(),
            IStreamArtistOwner(suite.owners[2]).ownerStateSnapshotV2()
        );
        Contest.GovernanceWitness memory g;
        T.SignerApproval memory proof =
            T.SignerApproval(address(rotationSafe), bytes32(uint256(1)), false);
        vm.expectRevert(abi.encodeWithSelector(T.Unauthorized.selector, address(this)));
        IStreamArtistIdentityRecoveryOwner(suite.owners[2]).recoverIdentity(c, p, a, proof, g);
        address child = StreamArtistIdentityAuthority(suite.owners[2]).identityRecoveryExtension();
        vm.expectRevert(
            abi.encodeWithSelector(
                StreamArtistIdentityRecoveryExtension.ExtensionWrongHost.selector, child
            )
        );
        IStreamArtistIdentityRecoveryOwner(child).recoverIdentity(c, p, a, proof, g);
        require(before_ == _roots(), "all actual guard failures rollback");
        require(_execute(p, a, 2, true) != 0, "healthy restored control");
    }
}

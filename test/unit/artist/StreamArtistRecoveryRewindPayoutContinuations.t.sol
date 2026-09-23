// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    StreamArtistRecoveryRewindTypes as W
} from "../../../smart-contracts/interfaces/stream/artist/StreamArtistRecoveryRewindTypes.sol";
import {
    StreamArtistOnboardingTypes as T
} from "../../../smart-contracts/interfaces/stream/artist/StreamArtistOnboardingTypes.sol";
import {
    StreamArtistRotationTypes as R
} from "../../../smart-contracts/interfaces/stream/artist/StreamArtistRotationTypes.sol";
import {
    IStreamArtistIdentityRecoveryOwnerV3
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistIdentityRecoveryV3.sol";
import {
    IStreamArtistOwner
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistOwner.sol";
import {
    IStreamArtistPayoutOwner
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistPayoutOwner.sol";
import {
    IStreamArtistRecoveryPayoutOwnerV3
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistRecoveryPayoutOwnerV3.sol";
import {
    StreamArtistLivingRecoveryReads as Living
} from "../../../smart-contracts/domains/artist/StreamArtistLivingRecoveryReads.sol";
import {
    StreamArtistRecoveredIdentityRuntime as Recovered
} from "../../../smart-contracts/domains/artist/StreamArtistRecoveredIdentityRuntime.sol";
import {
    StreamArtistRecoveredRuntimeReads as Runtime
} from "../../../smart-contracts/domains/artist/StreamArtistRecoveredRuntimeReads.sol";
import {
    IStreamArtistRecoveredPayoutHydration
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistRecoveredPayoutHydration.sol";

import {
    StreamArtistRecoveryRewindContinuations as Actual
} from "../../../smart-contracts/domains/artist/StreamArtistRecoveryRewindContinuations.sol";
import {
    StreamArtistRecoveredHydrationTypes as RH
} from "../../../smart-contracts/interfaces/stream/artist/StreamArtistRecoveredHydrationTypes.sol";
import {
    StreamArtistHistoryTypes as H
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistHistory.sol";
import {
    IStreamArtistAuthorityCheckpoint as CP
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistAuthorityCheckpoint.sol";
import {
    StreamArtistIdentityRecoveryOperationTypes as IR
} from "../../../smart-contracts/interfaces/stream/artist/StreamArtistIdentityRecoveryOperationTypes.sol";
import {
    StreamArtistGuardianVestingTypes as V
} from "../../../smart-contracts/interfaces/stream/artist/StreamArtistGuardianVestingTypes.sol";
import {
    StreamArtistGuardianHistoryTypes as GH
} from "../../../smart-contracts/interfaces/stream/artist/StreamArtistGuardianHistoryTypes.sol";
import {
    StreamArtistRecoveryActionTypes as Action
} from "../../../smart-contracts/interfaces/stream/artist/StreamArtistRecoveryActionTypes.sol";

/// @dev Literal original payout/payoutAt/_recovery bodies from Git32ae0361. Only library name differs.
library FrozenPayoutContinuations {
    function payoutAt(
        W.EnvironmentV3 memory e,
        W.PayoutOriginalV3 memory r,
        Runtime.ReplayFact memory nonce,
        Runtime.ReceiptFact memory occurrence
    ) public view returns (bytes32) {
        IStreamArtistRecoveryPayoutOwnerV3 owner = IStreamArtistRecoveryPayoutOwnerV3(e.payoutOwner);
        bytes32 head = owner.payoutDesignationRecoveryContinuationV3(r.recordHash);
        if (head == 0) return 0;
        Runtime.Context memory payoutClock = Runtime.load(e, 5);
        Runtime.Context memory identityClock = Runtime.load(e, 2);
        Runtime.ReceiptFact memory actual = Runtime.receiptAt(payoutClock, occurrence.logicalIndex);
        if (
            keccak256(abi.encode(actual)) != keccak256(abi.encode(occurrence))
                || occurrence.receipt.operation != 18
                || occurrence.receipt.artistId != r.terms.artistId
                || occurrence.receipt.recordHash != r.recordHash
        ) revert W.InvalidRecoveryRewindRecord(r.recordHash);
        Runtime.OriginFact memory origin = Runtime.auxiliary(
            payoutClock, keccak256("payout_lifecycle.hydration.continuation_v3"), head
        );
        W.PayoutContinuationV3 memory c = owner.payoutRecoveryContinuationV3(head);
        T.Payout memory empty;
        if (
            c.artistId != r.terms.artistId || c.continuationHash != head || c.manifestHash == 0
                || c.payoutOwnerRevision != origin.point.ownerRevision
                || W.payoutContinuationHash(Runtime.rewindEnvironment(origin.environment), c)
                    != head || c.stable.recordHash != r.terms.previousDesignationRecordHash
                || c.stable.account == r.terms.payoutAccount
                || keccak256(abi.encode(c.candidate)) != keccak256(abi.encode(empty))
                || !Runtime.before(payoutClock, origin.point, occurrence.position.point)
        ) revert W.InvalidRecoveryRewindRecord(r.recordHash);
        if (c.stable.recordHash == 0) {
            if (c.stable.account != address(0)) revert W.InvalidRecoveryRewindRecord(r.recordHash);
        } else {
            T.PayoutDesignation memory stable =
                IStreamArtistPayoutOwner(e.payoutOwner).designationRecord(c.stable.recordHash);
            if (
                stable.artistId != c.artistId || stable.payoutAccount == address(0)
                    || stable.payoutAccount != c.stable.account
            ) revert W.InvalidRecoveryRewindRecord(r.recordHash);
        }
        Runtime.ReceiptFact memory creation =
            Recovered.nativeFact(identityClock, 35, c.artistId, c.recoveryRecordHash);
        if (
            creation.position.point.environmentHash != origin.point.environmentHash
                || creation.position.point.ownerRevision != c.identityOwnerRevision
                || !Runtime.before(identityClock, creation.position.point, nonce.admission.point)
        ) revert W.InvalidRecoveryRewindRecord(r.recordHash);
        bytes32 recovered = _recovery(
            e,
            c.artistId,
            c.recoveryRecordHash,
            c.actionId,
            c.planCommitment,
            c.identityOwnerRevision
        );
        W.EvidenceStateV3 memory evidence = IStreamArtistIdentityRecoveryOwnerV3(e.identityOwner)
            .identityRecoveryEvidenceStateV3(c.artistId, c.actionId);
        Runtime.ReplayFact memory applied = Runtime.replay(
            payoutClock,
            origin.point.environmentHash,
            keccak256("payout_lifecycle.replay.recovery_rewind"),
            c.recoveryRecordHash
        );
        Runtime.ReplayFact memory admitted = Runtime.replay(
            payoutClock,
            occurrence.position.point.environmentHash,
            keccak256("payout_lifecycle.replay.recovery_continuation"),
            keccak256(abi.encode(c.artistId, head, r.terms.previousDesignationRecordHash))
        );
        if (
            evidence.manifestHash != c.manifestHash || applied.cell.kind != 1
                || applied.cell.status != 2 || applied.cell.commitment != c.planCommitment
                || !Recovered.samePoint(applied.admission.point, origin.point)
                || IStreamArtistRecoveredPayoutHydration(e.payoutOwner)
                        .payoutRecoveryAppliedCommitmentV3(c.recoveryRecordHash) == 0
                || admitted.cell.kind != 1 || admitted.cell.status != 2
                || admitted.cell.commitment != r.recordHash
                || !Recovered.samePoint(admitted.admission.point, occurrence.position.point)
        ) revert W.InvalidRecoveryRewindRecord(r.recordHash);
        return keccak256(
            abi.encode(
                keccak256("6529STREAM_ARTIST_RECOVERED_PAYOUT_CONTINUATION_V1"),
                c,
                recovered,
                evidence,
                origin,
                applied,
                admitted,
                occurrence
            )
        );
    }

    function payout(
        W.EnvironmentV3 memory e,
        W.PayoutOriginalV3 memory r,
        T.ReplayCell memory nonce
    ) public view returns (bytes32) {
        IStreamArtistRecoveryPayoutOwnerV3 owner = IStreamArtistRecoveryPayoutOwnerV3(e.payoutOwner);
        bytes32 head = owner.payoutDesignationRecoveryContinuationV3(r.recordHash);
        if (head == 0) return 0;
        W.PayoutContinuationV3 memory c = owner.payoutRecoveryContinuationV3(head);
        T.Payout memory empty;
        if (
            c.artistId != r.terms.artistId || c.continuationHash != head
                || W.payoutContinuationHash(e, c) != head || c.manifestHash == 0
                || c.stable.recordHash != r.terms.previousDesignationRecordHash
                || c.stable.account == r.terms.payoutAccount
                || keccak256(abi.encode(c.candidate)) != keccak256(abi.encode(empty))
                || c.identityOwnerRevision >= nonce.touchedRevision || c.payoutOwnerRevision == 0
        ) revert W.InvalidRecoveryRewindRecord(r.recordHash);
        if (c.stable.recordHash == 0) {
            if (c.stable.account != address(0)) revert W.InvalidRecoveryRewindRecord(r.recordHash);
        } else {
            T.PayoutDesignation memory stable =
                IStreamArtistPayoutOwner(e.payoutOwner).designationRecord(c.stable.recordHash);
            if (
                stable.artistId != c.artistId || stable.payoutAccount == address(0)
                    || stable.payoutAccount != c.stable.account
            ) revert W.InvalidRecoveryRewindRecord(r.recordHash);
        }
        bytes32 recovered = _recovery(
            e,
            c.artistId,
            c.recoveryRecordHash,
            c.actionId,
            c.planCommitment,
            c.identityOwnerRevision
        );
        W.EvidenceStateV3 memory evidence = IStreamArtistIdentityRecoveryOwnerV3(e.identityOwner)
            .identityRecoveryEvidenceStateV3(c.artistId, c.actionId);
        if (evidence.manifestHash != c.manifestHash) {
            revert W.InvalidRecoveryRewindRecord(r.recordHash);
        }
        bytes32 key = keccak256(
            abi.encode(
                keccak256("6529STREAM_ARTIST_OWNER_REPLAY_KEY_V2"),
                e.chainId,
                e.registry,
                e.coordinator,
                e.archive,
                e.payoutOwner,
                keccak256("domain:payout_lifecycle"),
                keccak256("payout_lifecycle.replay.recovery_continuation"),
                keccak256(abi.encode(c.artistId, head, r.terms.previousDesignationRecordHash))
            )
        );
        T.ReplayCell memory admitted = IStreamArtistOwner(e.payoutOwner).replayCell(key);
        if (
            admitted.commitment != r.recordHash || admitted.status != 2 || admitted.kind != 1
                || admitted.touchedRevision <= c.payoutOwnerRevision
                || admitted.touchedRevision
                    > IStreamArtistOwner(e.payoutOwner).ownerStateSnapshotV2().revision
        ) revert W.InvalidRecoveryRewindRecord(r.recordHash);
        return keccak256(abi.encode(c, recovered, evidence, key, admitted));
    }

    function _recovery(
        W.EnvironmentV3 memory e,
        bytes32 artistId,
        bytes32 record,
        bytes32 action,
        bytes32 plan,
        uint64 revision
    ) private view returns (bytes32) {
        Living.Facts memory r = Living.readFamily(
            e.identityOwner, e.registry, e.chainId, artistId, record
        );
        W.EvidenceStateV3 memory evidence = IStreamArtistIdentityRecoveryOwnerV3(e.identityOwner)
            .identityRecoveryEvidenceStateV3(artistId, action);
        if (
            action == 0 || plan == 0 || revision == 0
                || r.record.fields.governanceActionId != action
                || r.vesting.ownerRevision != revision || evidence.manifestHash == 0
                || evidence.associationHash == 0 || evidence.selectionCommitment != plan
                || evidence.sourceKey == 0 || evidence.sourceCommitment == 0
        ) revert W.InvalidRecoveryRewindRecord(record);
        return keccak256(abi.encode(r.proof, evidence));
    }
}

error PayoutContinuationBoundaryCaller(address actual);
error PayoutContinuationBoundaryFailure(bytes32 callHash);
error PayoutContinuationBoundaryMissing(bytes32 callHash);

/// @dev Exact typed ABI responses, explicitly seeded instead of admitted by an Artist Coordinator.
/// Every production getter must execute in the comparison host's delegatecall context.
contract PayoutContinuationBoundary {
    address private immutable caller;
    mapping(bytes32 => bytes) private responses;
    mapping(bytes32 => bool) private present;
    mapping(bytes32 => bool) private failures;

    constructor(address caller_) {
        caller = caller_;
    }

    function set(bytes memory call_, bytes memory response) external {
        bytes32 key = keccak256(call_);
        responses[key] = response;
        present[key] = true;
    }

    function fail(bytes memory call_, bool enabled) external {
        failures[keccak256(call_)] = enabled;
    }

    fallback(bytes calldata call_) external returns (bytes memory) {
        if (msg.sender != caller) revert PayoutContinuationBoundaryCaller(msg.sender);
        bytes32 key = keccak256(call_);
        if (failures[key]) revert PayoutContinuationBoundaryFailure(key);
        if (!present[key]) revert PayoutContinuationBoundaryMissing(key);
        return responses[key];
    }
}

contract PayoutContinuationComparisonHost {
    function nativeRead(
        bool original,
        W.EnvironmentV3 memory e,
        W.PayoutOriginalV3 memory r,
        T.ReplayCell memory nonce
    ) external view returns (bytes32) {
        return original ? FrozenPayoutContinuations.payout(e, r, nonce) : Actual.payout(e, r, nonce);
    }

    function recoveredRead(
        bool original,
        W.EnvironmentV3 memory e,
        W.PayoutOriginalV3 memory r,
        Runtime.ReplayFact memory nonce,
        Runtime.ReceiptFact memory occurrence
    ) external view returns (bytes32) {
        return original
            ? FrozenPayoutContinuations.payoutAt(e, r, nonce, occurrence)
            : Actual.payoutAt(e, r, nonce, occurrence);
    }
}

/// @notice Differential continuation reads, including a successful retained imported-history path.
/// @dev Actual Runtime/Provenance/Chronology/Recovered/Living execute over explicitly typed owner
/// responses. This does not assert original signatures, Safe/governance, op60/source-certificate
/// admission, full seven-owner semantic coherence, or current-stack integration acceptance.
contract StreamArtistRecoveryRewindPayoutContinuationsTest {
    bytes32 private constant ARTIST = bytes32(uint256(111));
    bytes32 private constant IMPORT = keccak256("explicit retained prefix marker");
    bytes32 private constant APPLY = keccak256("payout_lifecycle.replay.recovery_rewind");
    bytes32 private constant ADMIT = keccak256("payout_lifecycle.replay.recovery_continuation");
    bytes32 private constant AUX = keccak256("payout_lifecycle.hydration.continuation_v3");
    bytes32 private constant PREPARE = keccak256("identity_authority.replay.recovery_preparation");
    bytes32 private constant VESTING = keccak256("identity_authority.hydration.guardian_vesting");
    PayoutContinuationComparisonHost private host;
    PayoutContinuationBoundary private identity;
    PayoutContinuationBoundary private payoutOwner;
    PayoutContinuationBoundary private coordinator;
    T.SuiteConfiguration private suite;
    W.EnvironmentV3 private environment;

    struct Fixture {
        bool imported;
        RH.OriginEnvironment origin;
        RH.OriginEnvironment current;
        RH.OwnerProvenance identityPrefix;
        RH.OwnerProvenance payoutPrefix;
        W.PayoutOriginalV3 payout;
        W.PayoutContinuationV3 continuation;
        IR.Record recovery;
        R.TransitionState transition;
        V.Snapshot vesting;
        Action.Association association;
        GH.Snapshot frozen;
        W.EvidenceStateV3 evidence;
        Runtime.ReceiptFact creation;
        Runtime.ReceiptFact occurrence;
        Runtime.OriginFact originFact;
        Runtime.ReplayFact nonce;
        Runtime.ReplayFact applied;
        Runtime.ReplayFact admitted;
        bytes32 expectedRecoveryProof;
    }

    function setUp() public {
        host = new PayoutContinuationComparisonHost();
        identity = new PayoutContinuationBoundary(address(host));
        payoutOwner = new PayoutContinuationBoundary(address(host));
        coordinator = new PayoutContinuationBoundary(address(host));
        suite.registry = address(new PayoutContinuationBoundary(address(host)));
        suite.archive = address(new PayoutContinuationBoundary(address(host)));
        suite.core = address(new PayoutContinuationBoundary(address(host)));
        suite.mintManager = address(new PayoutContinuationBoundary(address(host)));
        for (uint8 i; i < 7; ++i) {
            suite.owners[i] = i == 2
                ? address(identity)
                : i == 5
                    ? address(payoutOwner)
                    : address(new PayoutContinuationBoundary(address(host)));
        }
        environment = W.EnvironmentV3(
            block.chainid,
            suite.registry,
            address(identity),
            address(identity).codehash,
            address(payoutOwner),
            address(payoutOwner).codehash,
            address(coordinator),
            suite.archive,
            suite.core,
            suite.mintManager
        );
        coordinator.set(abi.encodeWithSignature("suiteConfiguration()"), abi.encode(suite));
        coordinator.set(abi.encodeWithSignature("deploymentChainId()"), abi.encode(block.chainid));
        _ownerConfiguration(identity, 2);
        _ownerConfiguration(payoutOwner, 5);
    }

    function _ownerConfiguration(PayoutContinuationBoundary target, uint8 index) private {
        target.set(abi.encodeWithSignature("artistRegistry()"), abi.encode(environment.registry));
        target.set(
            abi.encodeWithSignature("operationCoordinator()"), abi.encode(environment.coordinator)
        );
        target.set(abi.encodeWithSignature("archiveV2()"), abi.encode(environment.archive));
        target.set(abi.encodeWithSignature("core()"), abi.encode(environment.core));
        target.set(abi.encodeWithSignature("mintManager()"), abi.encode(environment.manager));
        target.set(abi.encodeWithSignature("deploymentChainId()"), abi.encode(environment.chainId));
        target.set(abi.encodeWithSignature("domainId()"), abi.encode(_domain(index)));
    }

    function _fixture(bool imported) private returns (Fixture memory f) {
        f.imported = imported;
        f.current = _current();
        f.origin = abi.decode(abi.encode(f.current), (RH.OriginEnvironment));
        if (imported) {
            f.origin.registry = address(1000);
            f.origin.coordinator = address(2000);
            f.origin.archive = address(3000);
            f.origin.suiteConfigurationHash = bytes32(uint256(4000));
            for (uint8 i; i < 7; ++i) {
                f.origin.owners[i] = address(uint160(5000 + uint256(i)));
                f.origin.ownerCodeHashes[i] = bytes32(6000 + uint256(i));
            }
        }
        _recoveryFixture(f);
        f.payout.terms = T.PayoutDesignation(ARTIST, address(881), bytes32(uint256(882)));
        f.payout.recordHash = keccak256("original18 record at explicit consumer boundary");
        f.payout.signer = address(883);
        f.payout.authorityClass = 1;
        f.payout.nonce = 19;
        f.payout.signedAt = 500;
        W.PayoutContinuationV3 memory c;
        c.artistId = ARTIST;
        c.recoveryRecordHash = f.recovery.recordHash;
        c.actionId = f.recovery.fields.governanceActionId;
        c.manifestHash = f.evidence.manifestHash;
        c.planCommitment = f.evidence.selectionCommitment;
        c.identityOwnerRevision = 70;
        c.payoutOwnerRevision = 90;
        c.stable = T.Payout(address(884), f.payout.terms.previousDesignationRecordHash);
        c.releasedChildRecordHash = bytes32(uint256(885));
        c.previousContinuationHash = bytes32(uint256(886));
        c.continuationHash = W.payoutContinuationHash(_rewind(f.origin), c);
        f.continuation = c;
        bytes32 oldHash = RH.originHash(f.origin);
        bytes32 currentHash = RH.originHash(f.current);
        f.creation = Runtime.ReceiptFact(
            RH.Position(RH.Point(oldHash, 2, 70), 0),
            H.Receipt(35, ARTIST, 0, f.recovery.recordHash),
            f.origin,
            0
        );
        f.occurrence = Runtime.ReceiptFact(
            RH.Position(RH.Point(currentHash, 5, imported ? 3 : 95), 0),
            H.Receipt(18, ARTIST, 0, f.payout.recordHash),
            f.current,
            imported ? 1 : 0
        );
        f.originFact = Runtime.OriginFact(RH.Point(oldHash, 5, 90), f.origin);
        f.nonce.cell = T.ReplayCell(bytes32(uint256(901)), imported ? 2 : 80, 1, 2);
        f.nonce.admission =
            Runtime.OriginFact(RH.Point(currentHash, 2, f.nonce.cell.touchedRevision), f.current);
        f.applied = Runtime.ReplayFact(
            _key(f.origin, 5, APPLY, c.recoveryRecordHash),
            T.ReplayCell(c.planCommitment, 90, 1, 2),
            f.originFact
        );
        f.admitted = Runtime.ReplayFact(
            _key(f.current, 5, ADMIT, _scope(c)),
            T.ReplayCell(f.payout.recordHash, f.occurrence.position.point.ownerRevision, 1, 2),
            Runtime.OriginFact(f.occurrence.position.point, f.current)
        );
        if (imported) {
            f.identityPrefix = _prefix(
                f.origin,
                2,
                H.Receipt(35, ARTIST, 0, f.recovery.recordHash),
                70,
                PREPARE,
                c.actionId,
                f.association.associationHash,
                50
            );
            f.payoutPrefix = _prefix(
                f.origin,
                5,
                H.Receipt(18, ARTIST, 0, bytes32(uint256(920))),
                40,
                APPLY,
                c.recoveryRecordHash,
                c.planCommitment,
                90
            );
        }
        _installPrefix(identity, f.identityPrefix, imported);
        _installPrefix(payoutOwner, f.payoutPrefix, imported);
        _checkpoint(identity, 2, imported ? 8 : 100);
        _checkpoint(payoutOwner, 5, imported ? 9 : 100);
        _native(identity, imported ? 0 : 1, f.creation.receipt, 70);
        _native(payoutOwner, 1, f.occurrence.receipt, f.occurrence.position.point.ownerRevision);
        _point(identity, VESTING, f.recovery.recordHash, f.creation.position.point);
        _point(identity, PREPARE, c.actionId, RH.Point(oldHash, 2, 50));
        _point(payoutOwner, AUX, c.continuationHash, f.originFact.point);
        _replay(payoutOwner, f.admitted);
        if (!imported) {
            _replay(payoutOwner, f.applied);
            _replay(
                identity,
                Runtime.ReplayFact(
                    _key(f.origin, 2, PREPARE, c.actionId),
                    T.ReplayCell(f.association.associationHash, 50, 1, 2),
                    Runtime.OriginFact(RH.Point(oldHash, 2, 50), f.origin)
                )
            );
        }
        _installRecovery(f);
        _installContinuation(f);
        f.expectedRecoveryProof = _recoveryProof(f);
    }

    function _recoveryFixture(Fixture memory f) private pure {
        IR.Record memory r;
        r.fields.artistId = ARTIST;
        r.fields.oldAddress = address(701);
        r.fields.newAddress = address(702);
        r.fields.vestedAuthorityClass = 1;
        r.fields.evidenceHash = bytes32(uint256(703));
        r.fields.reasonHash = bytes32(uint256(704));
        r.fields.governanceActionId = bytes32(uint256(705));
        r.fields.recoveredAt = 400;
        r.terms.artistId = ARTIST;
        r.terms.newAddress = r.fields.newAddress;
        r.terms.vestedAuthorityClass = 1;
        r.terms.expectedCauseHash = bytes32(uint256(706));
        r.terms.expectedResolutionHash = bytes32(uint256(707));
        r.terms.evidenceHash = r.fields.evidenceHash;
        r.terms.reasonHash = r.fields.reasonHash;
        r.terms.supersededRecordHashes = new bytes32[](2);
        r.terms.supersededRecordHashes[0] = bytes32(uint256(708));
        r.terms.supersededRecordHashes[1] = bytes32(uint256(709));
        r.fields.supersededRecordsHash = keccak256(
            abi.encode(
                bytes32(0x0c8573762967a1af597f2a7afc4b655a87b3e22d2b11fbab6cf13c6f7b1396ae),
                r.terms.supersededRecordHashes
            )
        );
        r.recordHash = keccak256(
            abi.encode(
                bytes32(0x459749364fd07c3a8f1998b82d893d33ef0942c30d94666b42dac1e37ba5feff),
                f.origin.chainId,
                f.origin.registry,
                r.fields
            )
        );
        r.executor = address(710);
        r.proposer = address(711);
        r.governanceWitnessHash = bytes32(uint256(712));
        r.contextHash = bytes32(uint256(713));
        r.acceptanceDigest = bytes32(uint256(714));
        r.acceptanceNonce = 715;
        r.acceptanceDeadline = 500;
        r.postContestSeconds = 72 hours;
        r.standingTailSeconds = 30 days;
        r.timingRevision = 3;
        r.delegationEpoch = 4;
        f.recovery = r;
        f.transition =
            R.TransitionState(ARTIST, r.recordHash, 400, 400, 400, uint64(400 + 72 hours), 0, 2);
        V.Snapshot memory v;
        v.artistId = ARTIST;
        v.transitionRecordHash = r.recordHash;
        v.operationId = 35;
        v.ownerRevision = 70;
        v.executedAt = 400;
        v.oldAddress = r.fields.oldAddress;
        v.newAddress = r.fields.newAddress;
        v.authorityClass = 1;
        v.commitment = keccak256(
            bytes.concat(
                abi.encode(
                    keccak256("6529STREAM_ARTIST_GUARDIAN_VESTING_V1"),
                    f.origin.chainId,
                    f.origin.registry,
                    f.origin.owners[2]
                ),
                abi.encode(
                    v.artistId,
                    v.transitionRecordHash,
                    v.operationId,
                    v.ownerRevision,
                    v.executedAt,
                    v.oldAddress,
                    v.newAddress,
                    v.authorityClass,
                    v.guardians,
                    v.previousTransitionRecordHash,
                    v.previousCommitment
                )
            )
        );
        f.vesting = v;
        f.association.associationHash = bytes32(uint256(720));
        f.association.artistId = ARTIST;
        f.association.requestHash = keccak256(abi.encode(r.terms));
        f.association.acceptanceHash = bytes32(uint256(721));
        f.association.contextHash = r.contextHash;
        f.association.action.actionId = r.fields.governanceActionId;
        f.association.action.executor = r.executor;
        f.association.action.proposer = r.proposer;
        f.association.preparedBy = address(722);
        f.association.preparedAt = 300;
        f.association.ownerRevision = 50;
        f.frozen = GH.Snapshot(ARTIST, 0, 0, f.association.associationHash);
        f.evidence.manifestHash = bytes32(uint256(730));
        f.evidence.sourceKey = bytes32(uint256(731));
        f.evidence.sourceCommitment = bytes32(uint256(732));
        f.evidence.selectionCommitment = bytes32(uint256(733));
        f.evidence.policyCommitment = bytes32(uint256(734));
        f.evidence.requiredRole = bytes32(uint256(735));
        f.evidence.effectiveCapabilities = 23;
        f.evidence.associationHash = f.association.associationHash;
    }

    function _installRecovery(Fixture memory f) private {
        bytes32 hash = f.recovery.recordHash;
        identity.set(
            abi.encodeWithSignature("identityRecoveryRecord(bytes32)", hash), abi.encode(f.recovery)
        );
        identity.set(
            abi.encodeWithSignature("artistTransitionState(bytes32)", hash),
            abi.encode(f.transition)
        );
        identity.set(
            abi.encodeWithSignature("guardianVestingSnapshot(bytes32,bytes32)", ARTIST, hash),
            abi.encode(f.vesting)
        );
        Action.Veto memory veto;
        identity.set(
            abi.encodeWithSignature(
                "identityRecoveryActionState(bytes32,bytes32)", ARTIST, f.continuation.actionId
            ),
            abi.encode(f.association, veto, hash, uint64(0))
        );
        GH.Head memory head;
        GH.Entry memory entry;
        identity.set(
            abi.encodeWithSignature(
                "guardianHistoryState(bytes32,uint64,address,bytes32)",
                ARTIST,
                uint64(0),
                address(0),
                f.continuation.actionId
            ),
            abi.encode(head, entry, f.frozen, uint64(0))
        );
        identity.set(
            abi.encodeWithSignature("recoveryTransitionStanding(bytes32)", hash),
            abi.encode(f.recovery.fields.oldAddress, bytes32(0), uint64(30 days))
        );
        identity.set(
            abi.encodeWithSignature("identityRecoveryReceipts(bytes32)", hash),
            abi.encode(bytes32(uint256(741)), bytes32(uint256(742)), bytes32(uint256(743)))
        );
        identity.set(
            abi.encodeWithSignature(
                "identityRecoveryEvidenceStateV3(bytes32,bytes32)", ARTIST, f.continuation.actionId
            ),
            abi.encode(f.evidence)
        );
    }

    function _installContinuation(Fixture memory f) private {
        payoutOwner.set(
            abi.encodeWithSignature(
                "payoutDesignationRecoveryContinuationV3(bytes32)", f.payout.recordHash
            ),
            abi.encode(f.continuation.continuationHash)
        );
        payoutOwner.set(
            abi.encodeWithSignature(
                "payoutRecoveryContinuationV3(bytes32)", f.continuation.continuationHash
            ),
            abi.encode(f.continuation)
        );
        payoutOwner.set(
            abi.encodeWithSignature("designationRecord(bytes32)", f.continuation.stable.recordHash),
            abi.encode(
                T.PayoutDesignation(ARTIST, f.continuation.stable.account, bytes32(uint256(744)))
            )
        );
        payoutOwner.set(
            abi.encodeWithSignature(
                "payoutRecoveryAppliedCommitmentV3(bytes32)", f.continuation.recoveryRecordHash
            ),
            abi.encode(bytes32(uint256(745)))
        );
    }

    function _current() private view returns (RH.OriginEnvironment memory o) {
        o.chainId = environment.chainId;
        o.registry = environment.registry;
        o.coordinator = environment.coordinator;
        o.archive = environment.archive;
        o.core = environment.core;
        o.manager = environment.manager;
        o.suiteConfigurationHash = keccak256(abi.encode(suite));
        for (uint256 i; i < 7; ++i) {
            o.owners[i] = suite.owners[i];
            o.ownerCodeHashes[i] = suite.owners[i].codehash;
        }
    }

    function _prefix(
        RH.OriginEnvironment memory o,
        uint8 index,
        H.Receipt memory row,
        uint64 rowRevision,
        bytes32 surface,
        bytes32 scope,
        bytes32 commitment,
        uint64 revision
    ) private pure returns (RH.OwnerProvenance memory p) {
        bytes32 hash = RH.originHash(o);
        p.origins = new RH.OriginEnvironment[](1);
        p.origins[0] = o;
        p.eras = new RH.OwnerEra[](1);
        p.eras[0] = RH.OwnerEra(hash, _checkpointValue(index, 100, 1), 1, 0, 0);
        p.journal = new RH.JournalEntry[](1);
        p.journal[0] = RH.JournalEntry(RH.Position(RH.Point(hash, index, rowRevision), 0), row);
        p.aliases = new RH.ReplayAlias[](1);
        p.aliases[0] = RH.ReplayAlias(
            hash,
            index,
            surface,
            scope,
            _key(o, index, surface, scope),
            T.ReplayCell(commitment, revision, 1, 2),
            RH.Point(hash, index, revision)
        );
    }

    function _installPrefix(
        PayoutContinuationBoundary target,
        RH.OwnerProvenance memory p,
        bool imported
    ) private {
        target.set(
            abi.encodeWithSignature("recoveredHydrationImportedPrefix()"),
            abi.encode(p, imported ? IMPORT : bytes32(0), uint64(imported ? 1 : 0))
        );
        target.set(
            abi.encodeWithSignature("authorityHydrationCommitment()"),
            abi.encode(imported ? IMPORT : bytes32(0))
        );
    }

    function _checkpointValue(uint8 index, uint64 revision, uint256 replayCount)
        private
        pure
        returns (CP.Checkpoint memory)
    {
        return CP.Checkpoint(
            RH.CHECKPOINT,
            T.Snapshot(_domain(index), revision, bytes32(uint256(1)), bytes32(uint256(2))),
            bytes32(0),
            replayCount,
            bytes32(0),
            0
        );
    }

    function _checkpoint(PayoutContinuationBoundary target, uint8 index, uint64 revision) private {
        CP.Checkpoint memory cp = _checkpointValue(index, revision, 0);
        target.set(abi.encodeWithSignature("authorityCheckpoint()"), abi.encode(cp));
        target.set(abi.encodeWithSignature("ownerStateSnapshotV2()"), abi.encode(cp.ownerState));
    }

    function _native(
        PayoutContinuationBoundary target,
        uint256 count,
        H.Receipt memory row,
        uint64 revision
    ) private {
        target.set(abi.encodeWithSignature("artistNativeReceiptCount()"), abi.encode(count));
        target.set(
            abi.encodeWithSignature("artistNativeReceiptAt(uint256)", uint256(0)), abi.encode(row)
        );
        target.set(
            abi.encodeWithSignature("artistNativeReceiptRevisionAt(uint256)", uint256(0)),
            abi.encode(revision)
        );
    }

    function _point(PayoutContinuationBoundary target, bytes32 kind, bytes32 key, RH.Point memory p)
        private
    {
        target.set(
            abi.encodeWithSignature("recoveredHydrationAuxiliaryPoint(bytes32,bytes32)", kind, key),
            abi.encode(p)
        );
    }

    function _replay(PayoutContinuationBoundary target, Runtime.ReplayFact memory fact) private {
        target.set(
            abi.encodeWithSignature("replayCell(bytes32)", fact.originalKey), abi.encode(fact.cell)
        );
        target.set(
            abi.encodeWithSignature("recoveredHydrationReplayPoint(bytes32)", fact.originalKey),
            abi.encode(fact.admission.point)
        );
    }

    function _domain(uint8 index) private pure returns (bytes32) {
        return
            index == 2
                ? keccak256("domain:identity_authority")
                : keccak256("domain:payout_lifecycle");
    }

    function _key(RH.OriginEnvironment memory o, uint8 index, bytes32 surface, bytes32 scope)
        private
        pure
        returns (bytes32)
    {
        return keccak256(
            abi.encode(
                keccak256("6529STREAM_ARTIST_OWNER_REPLAY_KEY_V2"),
                o.chainId,
                o.registry,
                o.coordinator,
                o.archive,
                o.owners[index],
                _domain(index),
                surface,
                scope
            )
        );
    }

    function _scope(W.PayoutContinuationV3 memory c) private pure returns (bytes32) {
        return keccak256(abi.encode(c.artistId, c.continuationHash, c.stable.recordHash));
    }

    function _rewind(RH.OriginEnvironment memory o) private pure returns (W.EnvironmentV3 memory) {
        return W.EnvironmentV3(
            o.chainId,
            o.registry,
            o.owners[2],
            o.ownerCodeHashes[2],
            o.owners[5],
            o.ownerCodeHashes[5],
            o.coordinator,
            o.archive,
            o.core,
            o.manager
        );
    }

    function _recoveryProof(Fixture memory f) private pure returns (bytes32) {
        // Independent frozen hash domains and complete facts, with no call to Living.readFamily.
        Living.Admission memory admitted;
        admitted.association = f.association;
        admitted.frozen = f.frozen;
        admitted.primary = bytes32(uint256(741));
        admitted.occurrence = bytes32(uint256(742));
        admitted.secondary = bytes32(uint256(743));
        bytes32 living = keccak256(
            abi.encode(
                keccak256("6529STREAM_ARTIST_ADMITTED_LIVING_RECOVERY_V1"),
                f.recovery,
                f.transition,
                f.vesting,
                admitted
            )
        );
        living = keccak256(
            abi.encode(keccak256("6529STREAM_ARTIST_ADMITTED_RECOVERY_FAMILY_V2"), living)
        );
        if (f.imported) {
            living = keccak256(
                abi.encode(
                    keccak256("6529STREAM_ARTIST_RECOVERED_ADMITTED_RECOVERY_SOURCE_V1"),
                    living,
                    IMPORT,
                    f.creation
                )
            );
        }
        return keccak256(abi.encode(living, f.evidence));
    }

    function _expected(Fixture memory f, bool at) private pure returns (bytes32) {
        if (!at) {
            return keccak256(
                abi.encode(
                    f.continuation,
                    f.expectedRecoveryProof,
                    f.evidence,
                    f.admitted.originalKey,
                    f.admitted.cell
                )
            );
        }
        return keccak256(
            abi.encode(
                keccak256("6529STREAM_ARTIST_RECOVERED_PAYOUT_CONTINUATION_V1"),
                f.continuation,
                f.expectedRecoveryProof,
                f.evidence,
                f.originFact,
                f.applied,
                f.admitted,
                f.occurrence
            )
        );
    }

    function _call(Fixture memory f, bool at, bool original) private returns (bool, bytes memory) {
        bytes memory data = at
            ? abi.encodeCall(
                host.recoveredRead, (original, environment, f.payout, f.nonce, f.occurrence)
            )
            : abi.encodeCall(host.nativeRead, (original, environment, f.payout, f.nonce.cell));
        return address(host).call(data);
    }

    function _good(Fixture memory f, bool at) private {
        (bool ok, bytes memory actual) = _call(f, at, false);
        (bool oldOk, bytes memory original) = _call(f, at, true);
        require(ok && oldOk, "both actual and frozen success");
        require(keccak256(actual) == keccak256(original), "complete return bytes parity");
        require(
            keccak256(actual) == keccak256(abi.encode(_expected(f, at))),
            "literal full proof oracle"
        );
        require(abi.decode(actual, (bytes32)) != 0, "nonzero admitted continuation");
    }

    function _reject(Fixture memory f, bool at, bytes memory expected) private {
        (bool ok, bytes memory actual) = _call(f, at, false);
        (bool oldOk, bytes memory original) = _call(f, at, true);
        require(!ok && !oldOk, "both actual and frozen refusal");
        require(keccak256(actual) == keccak256(original), "complete error bytes parity");
        require(keccak256(actual) == keccak256(expected), "exact independent error oracle");
    }

    function _invalid(Fixture memory f) private pure returns (bytes memory) {
        return abi.encodeWithSelector(W.InvalidRecoveryRewindRecord.selector, f.payout.recordHash);
    }

    function _copy(Fixture memory f) private pure returns (Fixture memory) {
        return abi.decode(abi.encode(f), (Fixture));
    }

    function testNativeNonzeroContinuationAndEmptyStableHaveLiteralProofs() public {
        Fixture memory f = _fixture(false);
        _good(f, false);
        _good(f, true);
        // A genuine empty predecessor remains distinct from a nonzero account with no record.
        f.continuation.stable = T.Payout(address(0), bytes32(0));
        f.payout.terms.previousDesignationRecordHash = 0;
        _rehead(f);
        _good(f, false);
        _good(f, true);
    }

    function testRetainedRecoveryAndContinuationPrecedeLowCurrentOwnerRevisions() public {
        Fixture memory f = _fixture(true);
        require(
            f.identityPrefix.journal.length == 1 && f.payoutPrefix.journal.length == 1,
            "both prefixes actually retained"
        );
        require(
            f.origin.registry != f.current.registry && f.origin.owners[2] != address(identity)
                && f.origin.owners[5] != address(payoutOwner),
            "original and operative owners distinct"
        );
        require(
            f.continuation.identityOwnerRevision > f.nonce.cell.touchedRevision
                && f.continuation.payoutOwnerRevision > f.admitted.cell.touchedRevision,
            "old raw counters exceed current counters"
        );
        // Old APPLY is read from the retained alias; no current-domain key or old owner RPC fallback.
        payoutOwner.fail(
            abi.encodeWithSignature("replayCell(bytes32)", f.applied.originalKey), true
        );
        payoutOwner.fail(
            abi.encodeWithSignature(
                "replayCell(bytes32)", _key(f.current, 5, APPLY, f.continuation.recoveryRecordHash)
            ),
            true
        );
        _good(f, true);
    }

    function testZeroContinuationHeadReturnsBeforeAnyRuntimeOrIdentityReads() public {
        Fixture memory f = _fixture(true);
        payoutOwner.set(
            abi.encodeWithSignature(
                "payoutDesignationRecoveryContinuationV3(bytes32)", f.payout.recordHash
            ),
            abi.encode(bytes32(0))
        );
        coordinator.fail(abi.encodeWithSignature("suiteConfiguration()"), true);
        identity.fail(abi.encodeWithSignature("deploymentChainId()"), true);
        payoutOwner.fail(
            abi.encodeWithSignature(
                "payoutRecoveryContinuationV3(bytes32)", f.continuation.continuationHash
            ),
            true
        );
        for (uint256 i; i < 4; ++i) {
            (bool ok, bytes memory result) = _call(f, i >= 2, i % 2 == 1);
            require(
                ok && keccak256(result) == keccak256(abi.encode(bytes32(0))),
                "zero head exact return and early exit"
            );
        }
    }

    function testNativeContinuationStableAndReplayGuardsRejectThenRetry() public {
        Fixture memory f = _fixture(false);
        for (uint256 i; i < 16; ++i) {
            Fixture memory bad = _copy(f);
            if (i < 10) {
                if (i == 0) bad.continuation.artistId = bytes32(uint256(999));
                if (i == 1) bad.continuation.manifestHash = 0;
                if (i == 2) bad.continuation.stable.recordHash = bytes32(uint256(998));
                if (i == 3) bad.continuation.stable.account = bad.payout.terms.payoutAccount;
                if (i == 4) {
                    bad.continuation.candidate = T.Payout(address(997), bytes32(uint256(996)));
                }
                if (i == 5) {
                    bad.continuation.identityOwnerRevision = bad.nonce.cell.touchedRevision;
                }
                if (i == 6) bad.continuation.payoutOwnerRevision = 0;
                if (i == 7) {
                    bad.continuation.stable.recordHash = 0;
                    bad.payout.terms.previousDesignationRecordHash = 0;
                }
                _rehead(bad);
                if (i == 8) {
                    bad.continuation.continuationHash = bytes32(uint256(995));
                    _installContinuation(bad);
                }
                if (i == 9) {
                    payoutOwner.set(
                        abi.encodeWithSignature(
                            "designationRecord(bytes32)", bad.continuation.stable.recordHash
                        ),
                        abi.encode(T.PayoutDesignation(ARTIST, address(994), bytes32(0)))
                    );
                }
            } else {
                if (i == 10) bad.admitted.cell.commitment = 0;
                if (i == 11) bad.admitted.cell.status = 1;
                if (i == 12) bad.admitted.cell.kind = 2;
                if (i == 13) {
                    bad.admitted.cell.touchedRevision = bad.continuation.payoutOwnerRevision;
                }
                if (i == 14) bad.admitted.cell.touchedRevision = 101;
                if (i == 15) {
                    bad.evidence.manifestHash = bytes32(uint256(993));
                    _installRecovery(bad);
                }
                _replay(payoutOwner, bad.admitted);
            }
            _reject(bad, false, _invalid(bad));
            _installRecovery(f);
            _installContinuation(f);
            _replay(payoutOwner, f.admitted);
            _good(f, false);
        }
    }

    function testImportedOccurrenceAndSeparateOwnerChronologyRejectThenRetry() public {
        Fixture memory f = _fixture(true);
        for (uint256 i; i < 10; ++i) {
            Fixture memory bad = _copy(f);
            bytes memory expected = _invalid(bad);
            if (i == 0) bad.occurrence.logicalIndex = 0;
            if (i == 1) bad.occurrence.receipt.recordHash = bytes32(uint256(991));
            if (i == 2) bad.occurrence.position.nativeIndex = 1;
            if (i == 3) bad.occurrence.environment = bad.origin;
            if (i == 4) {
                bad.nonce.admission.point = RH.Point(RH.originHash(f.origin), 2, 70);
            }
            if (i == 5) {
                bad.nonce.admission.point.ownerIndex = 5;
                expected = _pointError(bad.nonce.admission.point);
            }
            if (i == 6) {
                bad.originFact.point.environmentHash = RH.originHash(f.current);
                bad.originFact.point.ownerRevision = 3;
                _point(payoutOwner, AUX, f.continuation.continuationHash, bad.originFact.point);
            }
            if (i == 7) {
                bad.continuation.identityOwnerRevision = 69;
                _rehead(bad);
            }
            if (i == 8) {
                // Exact retained original18 occurrence, but older than its purported continuation.
                bad.payoutPrefix.journal[0].receipt = bad.occurrence.receipt;
                bad.payoutPrefix.journal[0].position.point.ownerRevision = 89;
                bad.occurrence = Runtime.ReceiptFact(
                    bad.payoutPrefix.journal[0].position,
                    bad.payoutPrefix.journal[0].receipt,
                    bad.origin,
                    0
                );
                _installPrefix(payoutOwner, bad.payoutPrefix, true);
            }
            if (i == 9) {
                // Both owner-local prefixes remain well-formed; their original suites disagree.
                bad.identityPrefix.origins[0].archive = address(9876);
                bytes32 hash = RH.originHash(bad.identityPrefix.origins[0]);
                bad.identityPrefix.eras[0].originHash = hash;
                bad.identityPrefix.journal[0].position.point.environmentHash = hash;
                bad.identityPrefix.aliases[0].originHash = hash;
                bad.identityPrefix.aliases[0].admittedAt.environmentHash = hash;
                bad.identityPrefix.aliases[0].originalKey =
                    _key(bad.identityPrefix.origins[0], 2, PREPARE, bad.continuation.actionId);
                _installPrefix(identity, bad.identityPrefix, true);
            }
            _reject(bad, true, expected);
            _installPrefix(identity, f.identityPrefix, true);
            _installPrefix(payoutOwner, f.payoutPrefix, true);
            _point(payoutOwner, AUX, f.continuation.continuationHash, f.originFact.point);
            _installContinuation(f);
            _replay(payoutOwner, f.admitted);
            _good(f, true);
        }
    }

    function testImportedAppliedAndAdmissionReplayJoinsRejectThenRetry() public {
        Fixture memory f = _fixture(true);
        for (uint256 i; i < 10; ++i) {
            Fixture memory bad = _copy(f);
            if (i < 4) {
                RH.ReplayAlias memory a = bad.payoutPrefix.aliases[0];
                if (i == 0) a.cell.commitment = bytes32(uint256(990));
                if (i == 1) a.cell.kind = 2;
                if (i == 2) a.cell.status = 1;
                if (i == 3) {
                    a.cell.touchedRevision = 89;
                    a.admittedAt.ownerRevision = 89;
                }
                _installPrefix(payoutOwner, bad.payoutPrefix, true);
            } else if (i < 8) {
                if (i == 4) bad.admitted.cell.commitment = bytes32(uint256(989));
                if (i == 5) bad.admitted.cell.kind = 2;
                if (i == 6) bad.admitted.cell.status = 1;
                if (i == 7) {
                    bad.admitted.cell.touchedRevision = 4;
                    bad.admitted.admission.point.ownerRevision = 4;
                }
                _replay(payoutOwner, bad.admitted);
            } else if (i == 8) {
                payoutOwner.set(
                    abi.encodeWithSignature(
                        "payoutRecoveryAppliedCommitmentV3(bytes32)",
                        f.continuation.recoveryRecordHash
                    ),
                    abi.encode(bytes32(0))
                );
            } else {
                bad.evidence.manifestHash = bytes32(uint256(988));
                _installRecovery(bad);
            }
            _reject(bad, true, _invalid(bad));
            _installPrefix(payoutOwner, f.payoutPrefix, true);
            _installRecovery(f);
            _installContinuation(f);
            _replay(payoutOwner, f.admitted);
            _good(f, true);
        }
    }

    function testRealRecoveredLivingProofAndUniqueCreationCannotBeBypassed() public {
        Fixture memory f = _fixture(true);
        for (uint256 i; i < 6; ++i) {
            Fixture memory bad = _copy(f);
            bytes memory expected;
            if (i == 0) {
                bad.recovery.terms.reasonHash = bytes32(uint256(987));
                _installRecovery(bad);
                expected =
                    abi.encodeWithSelector(IR.UnsupportedIdentityRecoveryProfile.selector, ARTIST);
            } else if (i == 1) {
                bad.identityPrefix.aliases[0].cell.commitment = bytes32(uint256(986));
                _installPrefix(identity, bad.identityPrefix, true);
                expected = abi.encodeWithSelector(RH.InvalidRecoveredHydrationProvenance.selector);
            } else if (i == 2) {
                bad.evidence.sourceCommitment = 0;
                _installRecovery(bad);
                expected = abi.encodeWithSelector(
                    W.InvalidRecoveryRewindRecord.selector, f.recovery.recordHash
                );
            } else if (i == 3) {
                // Current suffix duplicates the same retained original35; nativeFact must refuse.
                _native(identity, 1, f.creation.receipt, 2);
                expected = abi.encodeWithSelector(RH.InvalidRecoveredHydrationProvenance.selector);
            } else if (i == 4) {
                _point(
                    identity,
                    VESTING,
                    f.recovery.recordHash,
                    RH.Point(RH.originHash(f.origin), 2, 69)
                );
                expected = abi.encodeWithSelector(RH.InvalidRecoveredHydrationProvenance.selector);
            } else {
                bad.identityPrefix.journal[0].receipt.collectionId = 55;
                _installPrefix(identity, bad.identityPrefix, true);
                expected = abi.encodeWithSelector(RH.InvalidRecoveredHydrationProvenance.selector);
            }
            _reject(bad, true, expected);
            _installPrefix(identity, f.identityPrefix, true);
            _installRecovery(f);
            _native(identity, 0, f.creation.receipt, 70);
            _point(identity, VESTING, f.recovery.recordHash, f.creation.position.point);
            _good(f, true);
        }
    }

    function testCallerContextAndOrderedOwnerFailuresBubbleExactBytes() public {
        Fixture memory f = _fixture(true);
        bytes[] memory calls = new bytes[](8);
        PayoutContinuationBoundary[] memory owners = new PayoutContinuationBoundary[](8);
        owners[0] = payoutOwner;
        calls[0] = abi.encodeWithSignature(
            "payoutDesignationRecoveryContinuationV3(bytes32)", f.payout.recordHash
        );
        owners[1] = coordinator;
        calls[1] = abi.encodeWithSignature("suiteConfiguration()");
        owners[2] = payoutOwner;
        calls[2] = abi.encodeWithSignature(
            "recoveredHydrationAuxiliaryPoint(bytes32,bytes32)",
            AUX,
            f.continuation.continuationHash
        );
        owners[3] = payoutOwner;
        calls[3] = abi.encodeWithSignature(
            "payoutRecoveryContinuationV3(bytes32)", f.continuation.continuationHash
        );
        owners[4] = payoutOwner;
        calls[4] =
            abi.encodeWithSignature("designationRecord(bytes32)", f.continuation.stable.recordHash);
        owners[5] = identity;
        calls[5] = abi.encodeWithSignature("identityRecoveryRecord(bytes32)", f.recovery.recordHash);
        owners[6] = identity;
        calls[6] =
            abi.encodeWithSignature("identityRecoveryReceipts(bytes32)", f.recovery.recordHash);
        owners[7] = payoutOwner;
        calls[7] = abi.encodeWithSignature(
            "payoutRecoveryAppliedCommitmentV3(bytes32)", f.recovery.recordHash
        );
        for (uint256 i; i < calls.length; ++i) {
            owners[i].fail(calls[i], true);
            if (i + 1 < calls.length) owners[i + 1].fail(calls[i + 1], true);
            _reject(
                f,
                true,
                abi.encodeWithSelector(
                    PayoutContinuationBoundaryFailure.selector, keccak256(calls[i])
                )
            );
            owners[i].fail(calls[i], false);
            if (i + 1 < calls.length) owners[i + 1].fail(calls[i + 1], false);
        }
        (bool ok, bytes memory error) = address(identity).call(calls[5]);
        require(
            !ok
                && keccak256(error)
                    == keccak256(
                        abi.encodeWithSelector(
                            PayoutContinuationBoundaryCaller.selector, address(this)
                        )
                    ),
            "caller probe is active"
        );
        _good(f, true);
        // Native ordering goes straight from head to continuation, with no Runtime suite query.
        f = _fixture(false);
        bytes memory continuationCall = abi.encodeWithSignature(
            "payoutRecoveryContinuationV3(bytes32)", f.continuation.continuationHash
        );
        bytes memory recoveryCall =
            abi.encodeWithSignature("identityRecoveryRecord(bytes32)", f.recovery.recordHash);
        coordinator.fail(abi.encodeWithSignature("suiteConfiguration()"), true);
        payoutOwner.fail(continuationCall, true);
        identity.fail(recoveryCall, true);
        _reject(
            f,
            false,
            abi.encodeWithSelector(
                PayoutContinuationBoundaryFailure.selector, keccak256(continuationCall)
            )
        );
        payoutOwner.fail(continuationCall, false);
        _reject(
            f,
            false,
            abi.encodeWithSelector(
                PayoutContinuationBoundaryFailure.selector, keccak256(recoveryCall)
            )
        );
        identity.fail(recoveryCall, false);
        _good(f, false);
    }

    function _pointError(RH.Point memory point) private pure returns (bytes memory) {
        return abi.encodeWithSelector(
            RH.InvalidRecoveredHydrationPoint.selector,
            point.environmentHash,
            point.ownerIndex,
            point.ownerRevision
        );
    }

    function _rehead(Fixture memory f) private {
        f.continuation.continuationHash =
            W.payoutContinuationHash(_rewind(f.origin), f.continuation);
        f.admitted.originalKey = _key(f.current, 5, ADMIT, _scope(f.continuation));
        _installContinuation(f);
        _replay(payoutOwner, f.admitted);
        _point(payoutOwner, AUX, f.continuation.continuationHash, f.originFact.point);
    }
}

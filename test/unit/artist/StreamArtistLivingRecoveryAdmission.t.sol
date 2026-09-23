// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    IStreamArtistOwner
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistOwner.sol";
import {
    IStreamArtistIdentityRecoveryOwner
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistIdentityRecovery.sol";
import {
    IStreamArtistRecoveryActionOwner
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistRecoveryAction.sol";
import {
    IStreamArtistGuardianHistory
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistGuardianHistory.sol";
import {
    IStreamArtistGuardianVestingHistory
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistGuardianVestingHistory.sol";
import {
    IStreamArtistRotationReads
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistRotation.sol";
import {
    StreamArtistIdentityRecoveryOperationTypes as IdentityRecovery
} from "../../../smart-contracts/interfaces/stream/artist/StreamArtistIdentityRecoveryOperationTypes.sol";
import {
    StreamArtistRotationTypes as R
} from "../../../smart-contracts/interfaces/stream/artist/StreamArtistRotationTypes.sol";
import {
    StreamArtistGuardianVestingTypes as V
} from "../../../smart-contracts/interfaces/stream/artist/StreamArtistGuardianVestingTypes.sol";
import {
    StreamArtistGuardianHistoryTypes as GH
} from "../../../smart-contracts/interfaces/stream/artist/StreamArtistGuardianHistoryTypes.sol";
import {
    StreamArtistRecoveryActionTypes as A
} from "../../../smart-contracts/interfaces/stream/artist/StreamArtistRecoveryActionTypes.sol";
import {
    StreamArtistIdentityRecoveryHashes as Hashes
} from "../../../smart-contracts/domains/artist/StreamArtistIdentityRecoveryHashes.sol";
import {
    StreamArtistRecoveredIdentityRuntime as Recovered
} from "../../../smart-contracts/domains/artist/StreamArtistRecoveredIdentityRuntime.sol";
import {
    StreamArtistRecoveredRuntimeReads as Runtime
} from "../../../smart-contracts/domains/artist/StreamArtistRecoveredRuntimeReads.sol";

/// @notice Original admitted class-1 operation35 evidence from the fixed Identity owner.
/// @dev Callers supply their fixed owner and decide current-head, epoch and closure eligibility.
/// This reader neither reauthorizes historical governance nor consults mutable retirement state.
/// @dev Complete frozen original reader at Git95cc0e0; library name and import paths only differ.
library FrozenLivingRecoveryReads {
    struct Facts {
        IdentityRecovery.Record record;
        R.TransitionState transition;
        V.Snapshot vesting;
        bytes32 proof;
    }

    struct Environment {
        address owner;
        address registry;
        uint256 chainId;
        bool imported;
        Runtime.Context runtime;
    }

    struct Admission {
        A.Association association;
        GH.Snapshot frozen;
        V.Snapshot parent;
        bytes32 guardian;
        bytes32 primary;
        bytes32 occurrence;
        bytes32 secondary;
    }

    function read(
        address owner,
        address registry,
        uint256 chainId,
        bytes32 artistId,
        bytes32 recordHash
    ) public view returns (Facts memory f) {
        if (
            chainId != block.chainid || owner.code.length == 0 || registry == address(0)
                || artistId == 0 || recordHash == 0
                || IStreamArtistOwner(owner).deploymentChainId() != chainId
                || IStreamArtistOwner(owner).artistRegistry() != registry
        ) revert IdentityRecovery.UnsupportedIdentityRecoveryProfile(artistId);
        Environment memory e = _environment(owner, registry, chainId);
        f.record = IStreamArtistIdentityRecoveryOwner(owner).identityRecoveryRecord(recordHash);
        f.transition = IStreamArtistRotationReads(owner).artistTransitionState(recordHash);
        f.vesting = IStreamArtistGuardianVestingHistory(owner)
            .guardianVestingSnapshot(artistId, recordHash);
        _record(e, artistId, recordHash, f, false);
        f.proof = _admission(e, f, false);
        if (e.imported) f.proof = _sourceProof(e, f);
    }

    /// @notice Original admitted class1 or class3 operation35 for complete V2 ancestry.
    /// @dev Current authority and cause/closure eligibility remain caller-owned.
    function readFamily(
        address owner,
        address registry,
        uint256 chainId,
        bytes32 artistId,
        bytes32 recordHash
    ) public view returns (Facts memory f) {
        if (
            chainId != block.chainid || owner.code.length == 0 || registry == address(0)
                || artistId == 0 || recordHash == 0
                || IStreamArtistOwner(owner).deploymentChainId() != chainId
                || IStreamArtistOwner(owner).artistRegistry() != registry
        ) {
            revert IdentityRecovery.UnsupportedIdentityRecoveryProfile(artistId);
        }
        Environment memory e = _environment(owner, registry, chainId);
        f.record = IStreamArtistIdentityRecoveryOwner(owner).identityRecoveryRecord(recordHash);
        f.transition = IStreamArtistRotationReads(owner).artistTransitionState(recordHash);
        f.vesting = IStreamArtistGuardianVestingHistory(owner)
            .guardianVestingSnapshot(artistId, recordHash);
        _record(e, artistId, recordHash, f, true);
        f.proof = keccak256(
            abi.encode(
                keccak256("6529STREAM_ARTIST_ADMITTED_RECOVERY_FAMILY_V2"), _admission(e, f, true)
            )
        );
        if (e.imported) f.proof = _sourceProof(e, f);
    }

    function _environment(address owner, address registry, uint256 chainId)
        private
        view
        returns (Environment memory e)
    {
        e.owner = owner;
        e.registry = registry;
        e.chainId = chainId;
        e.imported = Recovered.active(owner);
        if (e.imported) e.runtime = Recovered.load(owner, registry, chainId);
    }

    function _sourceProof(Environment memory e, Facts memory f) private view returns (bytes32) {
        Runtime.ReceiptFact memory original =
            Recovered.nativeFact(e.runtime, 35, f.record.fields.artistId, f.record.recordHash);
        return keccak256(
            abi.encode(
                keccak256("6529STREAM_ARTIST_RECOVERED_ADMITTED_RECOVERY_SOURCE_V1"),
                f.proof,
                e.runtime.importCommitment,
                original
            )
        );
    }

    function _record(
        Environment memory e,
        bytes32 artistId,
        bytes32 recordHash,
        Facts memory f,
        bool family
    ) private view {
        IdentityRecovery.Record memory r = f.record;
        R.TransitionState memory t = f.transition;
        V.Snapshot memory v = f.vesting;
        address registry = e.registry;
        if (e.imported) {
            Runtime.ReceiptFact memory original =
                Recovered.nativeFact(e.runtime, 35, artistId, recordHash);
            Runtime.OriginFact memory vested = Recovered.vesting(e.runtime, v);
            if (!Recovered.samePoint(original.position.point, vested.point)) {
                revert IdentityRecovery.UnsupportedIdentityRecoveryProfile(artistId);
            }
            registry = original.environment.registry;
        }
        if (
            r.recordHash != recordHash || Hashes.record(e.chainId, registry, r.fields) != recordHash
                || r.fields.artistId != artistId || r.fields.oldAddress == address(0)
                || r.fields.newAddress == address(0) || r.fields.oldAddress == r.fields.newAddress
                || (r.fields.vestedAuthorityClass != 1
                    && (!family || r.fields.vestedAuthorityClass != 3)) || r.fields.recoveredAt == 0
                || r.fields.governanceActionId == 0 || r.fields.evidenceHash == 0
                || r.fields.reasonHash == 0 || r.terms.artistId != artistId
                || r.terms.newAddress != r.fields.newAddress
                || r.terms.vestedAuthorityClass != r.fields.vestedAuthorityClass
                || r.terms.expectedCauseHash == 0 || r.terms.evidenceHash != r.fields.evidenceHash
                || r.terms.reasonHash != r.fields.reasonHash
                || Hashes.supersession(r.terms.supersededRecordHashes)
                    != r.fields.supersededRecordsHash || r.executor == address(0)
                || r.proposer == address(0) || r.governanceWitnessHash == 0 || r.contextHash == 0
                || r.acceptanceDigest == 0 || r.acceptanceDeadline < r.fields.recoveredAt
                || r.postContestSeconds < 72 hours || r.standingTailSeconds < 30 days
                || r.timingRevision == 0 || r.delegationEpoch == 0 || t.artistId != artistId
                || t.recordHash != recordHash || t.phase != 2
                || t.executedAt != r.fields.recoveredAt || t.stagedAt != t.executedAt
                || t.contestEndsAt != t.executedAt
                || uint256(t.postWindowEndsAt) != uint256(t.executedAt) + r.postContestSeconds
                || (t.contestedAt != 0 && t.contestedAt < t.executedAt) || v.artistId != artistId
                || v.transitionRecordHash != recordHash || v.operationId != 35
                || v.authorityClass != r.fields.vestedAuthorityClass
                || v.oldAddress != r.fields.oldAddress || v.newAddress != r.fields.newAddress
                || v.executedAt != t.executedAt || v.ownerRevision == 0
                || (!e.imported && v.ownerRevision <= v.guardians.ownerRevision)
                || v.commitment == 0 || v.commitment != _vestingHash(e, v)
        ) revert IdentityRecovery.UnsupportedIdentityRecoveryProfile(artistId);
    }

    function _admission(Environment memory e, Facts memory f, bool family)
        private
        view
        returns (bytes32)
    {
        bytes32 artistId = f.record.fields.artistId;
        bytes32 action = f.record.fields.governanceActionId;
        Admission memory admitted;
        bytes32 executed;
        uint64 actualCount;
        (admitted.association,, executed, actualCount) =
            IStreamArtistRecoveryActionOwner(e.owner).identityRecoveryActionState(artistId, action);
        admitted.frozen = _prefix(e, f.vesting, action, actualCount);
        admitted.parent = _parent(e, f.vesting, actualCount, family);
        address oldAddress;
        uint64 tail;
        (oldAddress, admitted.guardian, tail) = IStreamArtistIdentityRecoveryOwner(e.owner)
            .recoveryTransitionStanding(f.record.recordHash);
        if (oldAddress != f.record.fields.oldAddress || tail != f.record.standingTailSeconds) {
            revert IdentityRecovery.UnsupportedIdentityRecoveryProfile(artistId);
        }
        A.Association memory a = admitted.association;
        if (a.associationHash != 0) {
            if (
                executed != f.record.recordHash || a.artistId != artistId
                    || a.requestHash != keccak256(abi.encode(f.record.terms))
                    || a.contextHash != f.record.contextHash || a.action.actionId != action
                    || a.action.proposer != f.record.proposer
                    || a.action.executor != f.record.executor || a.ownerRevision == 0
                    || (!e.imported && a.ownerRevision >= f.vesting.ownerRevision)
                    || a.preparedAt == 0 || a.preparedAt > f.record.fields.recoveredAt
                    || admitted.frozen.artistId != artistId
                    || admitted.frozen.associationHash != a.associationHash
                    || admitted.frozen.count != f.vesting.guardians.count
                    || admitted.frozen.historyCommitment != f.vesting.guardians.commitment
            ) revert IdentityRecovery.UnsupportedIdentityRecoveryProfile(artistId);
            if (e.imported) {
                Runtime.OriginFact memory prepared = Recovered.preparation(e.runtime, a);
                Runtime.OriginFact memory vested = Recovered.vesting(e.runtime, f.vesting);
                if (!Runtime.before(e.runtime, prepared.point, vested.point)) {
                    revert IdentityRecovery.UnsupportedIdentityRecoveryProfile(artistId);
                }
            }
        } else if (executed != 0 || admitted.guardian != 0 || f.vesting.guardians.count != 0) {
            revert IdentityRecovery.UnsupportedIdentityRecoveryProfile(artistId);
        }
        // The standing getter authenticates a saved restored guardian (including zero) after
        // supersession. It need not equal the pre-recovery association's original guardian.
        (admitted.primary, admitted.occurrence, admitted.secondary) = IStreamArtistIdentityRecoveryOwner(
                e.owner
            ).identityRecoveryReceipts(f.record.recordHash);
        if (
            admitted.primary == 0 || admitted.occurrence == 0 || admitted.secondary == 0
                || admitted.primary == admitted.secondary
        ) revert IdentityRecovery.UnsupportedIdentityRecoveryProfile(artistId);
        // Do not commit today's growing guardian head: all included evidence is original history.
        return keccak256(
            abi.encode(
                keccak256("6529STREAM_ARTIST_ADMITTED_LIVING_RECOVERY_V1"),
                f.record,
                f.transition,
                f.vesting,
                admitted
            )
        );
    }

    function _parent(Environment memory e, V.Snapshot memory v, uint64 actualCount, bool family)
        private
        view
        returns (V.Snapshot memory parent)
    {
        if (v.previousTransitionRecordHash == 0) {
            if (v.previousCommitment != 0) {
                revert IdentityRecovery.UnsupportedIdentityRecoveryProfile(v.artistId);
            }
            return parent;
        }
        parent = IStreamArtistGuardianVestingHistory(e.owner)
            .guardianVestingSnapshot(v.artistId, v.previousTransitionRecordHash);
        if (
            parent.artistId != v.artistId
                || parent.transitionRecordHash != v.previousTransitionRecordHash
                || parent.commitment == 0 || parent.commitment != v.previousCommitment
                || parent.commitment != _vestingHash(e, parent)
                || parent.authorityClass != v.authorityClass
                || (parent.operationId != 32
                    && parent.operationId != 35
                    && (!family || (parent.operationId != 40 && parent.operationId != 43)))
                || parent.oldAddress == address(0) || parent.newAddress != v.oldAddress
                || parent.oldAddress == parent.newAddress || parent.executedAt == 0
                || parent.executedAt > v.executedAt || parent.ownerRevision == 0
                || (!e.imported && parent.ownerRevision >= v.ownerRevision)
                || (!e.imported && parent.ownerRevision <= parent.guardians.ownerRevision)
                || parent.guardians.count > v.guardians.count
                || (!e.imported && parent.guardians.ownerRevision > v.guardians.ownerRevision)
        ) revert IdentityRecovery.UnsupportedIdentityRecoveryProfile(v.artistId);
        if (e.imported) {
            Runtime.OriginFact memory previous = Recovered.vesting(e.runtime, parent);
            Runtime.OriginFact memory next_ = Recovered.vesting(e.runtime, v);
            if (!Runtime.before(e.runtime, previous.point, next_.point)) {
                revert IdentityRecovery.UnsupportedIdentityRecoveryProfile(v.artistId);
            }
        }
        _prefix(e, parent, bytes32(0), actualCount);
    }

    function _prefix(Environment memory e, V.Snapshot memory v, bytes32 action, uint64 actualCount)
        private
        view
        returns (GH.Snapshot memory frozen)
    {
        GH.Head memory head;
        GH.Entry memory last;
        (head, last, frozen,) = IStreamArtistGuardianHistory(e.owner)
            .guardianHistoryState(v.artistId, v.guardians.count, address(0), action);
        // The fixed getter requires the complete current history, then selects this exact saved
        // prefix endpoint from its admitted index. Later admissions do not replace that prefix.
        if (head.count != actualCount || v.guardians.count > head.count) {
            revert IdentityRecovery.UnsupportedIdentityRecoveryProfile(v.artistId);
        }
        if (v.guardians.count == 0) {
            if (v.guardians.ownerRevision != 0 || v.guardians.commitment != 0) {
                revert IdentityRecovery.UnsupportedIdentityRecoveryProfile(v.artistId);
            }
        } else if (
            v.guardians.ownerRevision == 0 || v.guardians.commitment == 0
                || (!e.imported && v.guardians.ownerRevision > head.ownerRevision)
                || last.artistId != v.artistId || last.index != v.guardians.count
                || last.ownerRevision != v.guardians.ownerRevision
                || last.commitment != v.guardians.commitment || last.recordHash == 0
                || last.recordDataHash == 0
                || (!e.imported
                    && last.commitment
                        != keccak256(
                            abi.encode(
                                keccak256("6529STREAM_ARTIST_GUARDIAN_ADMISSION_HISTORY_V1"),
                                e.chainId,
                                e.registry,
                                e.owner,
                                last.artistId,
                                last.index,
                                last.ownerRevision,
                                last.recordHash,
                                last.recordDataHash,
                                last.previousCommitment
                            )
                        ))
        ) {
            revert IdentityRecovery.UnsupportedIdentityRecoveryProfile(v.artistId);
        }
        if (e.imported && v.guardians.count != 0) {
            Recovered.guardianEntry(e.runtime, last);
            if (v.guardians.count != head.count) {
                (, GH.Entry memory current,,) = IStreamArtistGuardianHistory(e.owner)
                    .guardianHistoryState(v.artistId, head.count, address(0), 0);
                Runtime.OriginFact memory earlier = Recovered.guardianEntry(e.runtime, last);
                Runtime.OriginFact memory later = Recovered.guardianEntry(e.runtime, current);
                if (!Runtime.before(e.runtime, earlier.point, later.point)) {
                    revert IdentityRecovery.UnsupportedIdentityRecoveryProfile(v.artistId);
                }
            }
        }
    }

    function _vestingHash(Environment memory e, V.Snapshot memory v)
        private
        view
        returns (bytes32)
    {
        if (e.imported) {
            Runtime.OriginFact memory origin = Recovered.vesting(e.runtime, v);
            return Recovered.vestingHash(origin.environment, v);
        }
        return keccak256(
            bytes.concat(
                abi.encode(
                    keccak256("6529STREAM_ARTIST_GUARDIAN_VESTING_V1"),
                    e.chainId,
                    e.registry,
                    e.owner
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
    }
}

import {
    StreamArtistLivingRecoveryReads as Actual
} from "../../../smart-contracts/domains/artist/StreamArtistLivingRecoveryReads.sol";
import {
    StreamArtistRecoveryRewindTypes as W
} from "../../../smart-contracts/interfaces/stream/artist/StreamArtistRecoveryRewindTypes.sol";
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
    StreamArtistOnboardingTypes as T
} from "../../../smart-contracts/interfaces/stream/artist/StreamArtistOnboardingTypes.sol";

error LivingAdmissionBoundaryCaller(address actual);
error LivingAdmissionBoundaryFailure(bytes32 callHash);
error LivingAdmissionBoundaryMissing(bytes32 callHash);

contract LivingAdmissionBoundary {
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
        if (msg.sender != caller) revert LivingAdmissionBoundaryCaller(msg.sender);
        bytes32 key = keccak256(call_);
        if (failures[key]) revert LivingAdmissionBoundaryFailure(key);
        if (!present[key]) revert LivingAdmissionBoundaryMissing(key);
        return responses[key];
    }
}

contract LivingAdmissionComparisonHost {
    function run(
        bool original,
        bool family,
        address owner,
        address registry,
        uint256 chainId,
        bytes32 artist,
        bytes32 record
    ) external view returns (bytes memory) {
        if (original) {
            return family
                ? abi.encode(
                    FrozenLivingRecoveryReads.readFamily(owner, registry, chainId, artist, record)
                )
                : abi.encode(
                    FrozenLivingRecoveryReads.read(owner, registry, chainId, artist, record)
                );
        }
        return family
            ? abi.encode(Actual.readFamily(owner, registry, chainId, artist, record))
            : abi.encode(Actual.read(owner, registry, chainId, artist, record));
    }
}

/// @notice Source-level differential admission checks through actual Living read/readFamily.
/// @dev Exact-calldata typed owner responses supply explicit historical facts. Runtime, Recovered,
/// provenance and chronology are real. No signature, governance, source-certificate/op60 or complete
/// Artist admission is manufactured or claimed; integrated runtime acceptance remains separate.
contract StreamArtistLivingRecoveryAdmissionTest {
    bytes32 private constant ARTIST = bytes32(uint256(111));
    bytes32 private constant IMPORT = keccak256("explicit living reader retained prefix");
    bytes32 private constant PREPARE = keccak256("identity_authority.replay.recovery_preparation");
    bytes32 private constant VESTING = keccak256("identity_authority.hydration.guardian_vesting");
    LivingAdmissionComparisonHost private host;
    LivingAdmissionBoundary private identity;
    LivingAdmissionBoundary private payoutOwner;
    LivingAdmissionBoundary private coordinator;
    T.SuiteConfiguration private suite;
    W.EnvironmentV3 private environment;

    struct Fixture {
        bool imported;
        RH.OriginEnvironment origin;
        RH.OriginEnvironment current;
        RH.OwnerProvenance prefix;
        IdentityRecovery.Record recovery;
        R.TransitionState transition;
        V.Snapshot vesting;
        V.Snapshot parent;
        A.Association association;
        GH.Snapshot frozen;
        GH.Entry[3] guardians;
        GH.Head currentHead;
        Runtime.ReceiptFact creation;
        bytes32 restoredGuardian;
    }

    function setUp() public {
        host = new LivingAdmissionComparisonHost();
        identity = new LivingAdmissionBoundary(address(host));
        payoutOwner = new LivingAdmissionBoundary(address(host));
        coordinator = new LivingAdmissionBoundary(address(host));
        suite.registry = address(new LivingAdmissionBoundary(address(host)));
        suite.archive = address(new LivingAdmissionBoundary(address(host)));
        suite.core = address(new LivingAdmissionBoundary(address(host)));
        suite.mintManager = address(new LivingAdmissionBoundary(address(host)));
        for (uint8 i; i < 7; ++i) {
            suite.owners[i] = i == 2
                ? address(identity)
                : i == 5
                    ? address(payoutOwner)
                    : address(new LivingAdmissionBoundary(address(host)));
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

    function _ownerConfiguration(LivingAdmissionBoundary target, uint8 index) private {
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

    function _installPrefix(
        LivingAdmissionBoundary target,
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

    function _checkpoint(LivingAdmissionBoundary target, uint8 index, uint64 revision) private {
        CP.Checkpoint memory cp = _checkpointValue(index, revision, 0);
        target.set(abi.encodeWithSignature("authorityCheckpoint()"), abi.encode(cp));
        target.set(abi.encodeWithSignature("ownerStateSnapshotV2()"), abi.encode(cp.ownerState));
    }

    function _point(LivingAdmissionBoundary target, bytes32 kind, bytes32 key, RH.Point memory p)
        private
    {
        target.set(
            abi.encodeWithSignature("recoveredHydrationAuxiliaryPoint(bytes32,bytes32)", kind, key),
            abi.encode(p)
        );
    }

    function _replay(LivingAdmissionBoundary target, Runtime.ReplayFact memory fact) private {
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

    function _recoveryFixture(Fixture memory f, uint8 authorityClass) private pure {
        IdentityRecovery.Record memory r;
        r.fields.artistId = ARTIST;
        r.fields.oldAddress = address(701);
        r.fields.newAddress = address(702);
        r.fields.vestedAuthorityClass = authorityClass;
        r.fields.evidenceHash = bytes32(uint256(703));
        r.fields.reasonHash = bytes32(uint256(704));
        r.fields.governanceActionId = bytes32(uint256(705));
        r.fields.recoveredAt = 400;
        r.terms.artistId = ARTIST;
        r.terms.newAddress = r.fields.newAddress;
        r.terms.vestedAuthorityClass = authorityClass;
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
        v.authorityClass = authorityClass;
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
    }

    function _fixture(bool imported, uint8 authorityClass, uint16 parentOperation)
        private
        returns (Fixture memory f)
    {
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
        _recoveryFixture(f, authorityClass);
        for (uint256 i; i < 3; ++i) {
            GH.Entry memory entry = GH.Entry(
                ARTIST,
                uint64(i + 1),
                uint64(i == 2 ? imported ? 2 : 80 : (i + 1) * 10),
                bytes32(800 + i),
                bytes32(810 + i),
                i == 0 ? bytes32(0) : f.guardians[i - 1].commitment,
                0
            );
            entry.commitment = _guardianHash(i == 2 ? f.current : f.origin, entry);
            f.guardians[i] = entry;
        }
        f.currentHead = GH.Head(3, f.guardians[2].ownerRevision, f.guardians[2].commitment);
        f.vesting.guardians = GH.Head(2, 20, f.guardians[1].commitment);
        f.restoredGuardian = bytes32(uint256(899));
        if (parentOperation != 0) {
            V.Snapshot memory p;
            p.artistId = ARTIST;
            p.transitionRecordHash = bytes32(uint256(820));
            p.operationId = parentOperation;
            p.ownerRevision = 40;
            p.executedAt = 200;
            p.oldAddress = address(821);
            p.newAddress = f.recovery.fields.oldAddress;
            p.authorityClass = authorityClass;
            p.guardians = GH.Head(1, 10, f.guardians[0].commitment);
            p.commitment = _vestingHash(f.origin, p);
            f.parent = p;
            f.vesting.previousTransitionRecordHash = p.transitionRecordHash;
            f.vesting.previousCommitment = p.commitment;
        }
        f.vesting.commitment = _vestingHash(f.origin, f.vesting);
        f.frozen = GH.Snapshot(ARTIST, 2, f.guardians[1].commitment, f.association.associationHash);
        bytes32 originHash = RH.originHash(f.origin);
        f.creation = Runtime.ReceiptFact(
            RH.Position(RH.Point(originHash, 2, 70), parentOperation == 0 ? 2 : 3),
            H.Receipt(35, ARTIST, 0, f.recovery.recordHash),
            f.origin,
            parentOperation == 0 ? 2 : 3
        );
        if (imported) {
            f.prefix.origins = new RH.OriginEnvironment[](1);
            f.prefix.origins[0] = f.origin;
            f.prefix.eras = new RH.OwnerEra[](1);
            uint256 count = parentOperation == 0 ? 3 : 4;
            f.prefix.eras[0] = RH.OwnerEra(originHash, _checkpointValue(2, 100, 1), count, 0, 0);
            f.prefix.journal = new RH.JournalEntry[](count);
            for (uint256 i; i < 2; ++i) {
                f.prefix.journal[i] = RH.JournalEntry(
                    RH.Position(RH.Point(originHash, 2, f.guardians[i].ownerRevision), i),
                    H.Receipt(28, ARTIST, 0, f.guardians[i].recordHash)
                );
            }
            if (parentOperation != 0) {
                f.prefix.journal[2] = RH.JournalEntry(
                    RH.Position(RH.Point(originHash, 2, 40), 2),
                    H.Receipt(parentOperation, ARTIST, 0, f.parent.transitionRecordHash)
                );
            }
            f.prefix.journal[count - 1] = RH.JournalEntry(f.creation.position, f.creation.receipt);
            f.prefix.aliases = new RH.ReplayAlias[](1);
            f.prefix.aliases[0] = RH.ReplayAlias(
                originHash,
                2,
                PREPARE,
                f.recovery.fields.governanceActionId,
                _key(f.origin, 2, PREPARE, f.recovery.fields.governanceActionId),
                T.ReplayCell(f.association.associationHash, 50, 1, 2),
                RH.Point(originHash, 2, 50)
            );
        }
        _installPrefix(identity, f.prefix, imported);
        _checkpoint(identity, 2, imported ? 8 : 100);
        identity.set(
            abi.encodeWithSignature("artistNativeReceiptCount()"),
            abi.encode(uint256(imported ? 1 : 0))
        );
        identity.set(
            abi.encodeWithSignature("artistNativeReceiptAt(uint256)", uint256(0)),
            abi.encode(H.Receipt(28, ARTIST, 0, f.guardians[2].recordHash))
        );
        identity.set(
            abi.encodeWithSignature("artistNativeReceiptRevisionAt(uint256)", uint256(0)),
            abi.encode(f.guardians[2].ownerRevision)
        );
        _point(identity, VESTING, f.recovery.recordHash, RH.Point(originHash, 2, 70));
        if (parentOperation != 0) {
            _point(identity, VESTING, f.parent.transitionRecordHash, RH.Point(originHash, 2, 40));
        }
        _point(identity, PREPARE, f.recovery.fields.governanceActionId, RH.Point(originHash, 2, 50));
        _install(f);
    }

    function _install(Fixture memory f) private {
        bytes32 hash = f.recovery.recordHash;
        bytes32 action = f.recovery.fields.governanceActionId;
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
        if (f.parent.transitionRecordHash != 0) {
            identity.set(
                abi.encodeWithSignature(
                    "guardianVestingSnapshot(bytes32,bytes32)",
                    ARTIST,
                    f.vesting.previousTransitionRecordHash
                ),
                abi.encode(f.parent)
            );
        }
        A.Veto memory veto;
        identity.set(
            abi.encodeWithSignature("identityRecoveryActionState(bytes32,bytes32)", ARTIST, action),
            abi.encode(
                f.association,
                veto,
                f.association.associationHash == 0 ? bytes32(0) : hash,
                f.currentHead.count
            )
        );
        GH.Snapshot memory empty;
        for (uint64 i = 1; i <= 3; ++i) {
            _history(i, bytes32(0), f.currentHead, f.guardians[i - 1], empty);
        }
        GH.Entry memory last;
        if (f.vesting.guardians.count != 0 && f.vesting.guardians.count <= 3) {
            last = f.guardians[f.vesting.guardians.count - 1];
        }
        _history(f.vesting.guardians.count, action, f.currentHead, last, f.frozen);
        identity.set(
            abi.encodeWithSignature("recoveryTransitionStanding(bytes32)", hash),
            abi.encode(
                f.recovery.fields.oldAddress, f.restoredGuardian, f.recovery.standingTailSeconds
            )
        );
        identity.set(
            abi.encodeWithSignature("identityRecoveryReceipts(bytes32)", hash),
            abi.encode(bytes32(uint256(741)), bytes32(uint256(742)), bytes32(uint256(743)))
        );
    }

    function _history(
        uint64 count,
        bytes32 action,
        GH.Head memory head,
        GH.Entry memory last,
        GH.Snapshot memory frozen
    ) private {
        identity.set(
            abi.encodeWithSignature(
                "guardianHistoryState(bytes32,uint64,address,bytes32)",
                ARTIST,
                count,
                address(0),
                action
            ),
            abi.encode(head, last, frozen, uint64(0))
        );
    }

    function _guardianHash(RH.OriginEnvironment memory o, GH.Entry memory g)
        private
        pure
        returns (bytes32)
    {
        return keccak256(
            abi.encode(
                keccak256("6529STREAM_ARTIST_GUARDIAN_ADMISSION_HISTORY_V1"),
                o.chainId,
                o.registry,
                o.owners[2],
                g.artistId,
                g.index,
                g.ownerRevision,
                g.recordHash,
                g.recordDataHash,
                g.previousCommitment
            )
        );
    }

    function _vestingHash(RH.OriginEnvironment memory o, V.Snapshot memory v)
        private
        pure
        returns (bytes32)
    {
        return keccak256(
            bytes.concat(
                abi.encode(
                    keccak256("6529STREAM_ARTIST_GUARDIAN_VESTING_V1"),
                    o.chainId,
                    o.registry,
                    o.owners[2]
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
    }

    function _expected(Fixture memory f, bool family)
        private
        pure
        returns (Actual.Facts memory result)
    {
        result.record = f.recovery;
        result.transition = f.transition;
        result.vesting = f.vesting;
        Actual.Admission memory admitted;
        admitted.association = f.association;
        admitted.frozen = f.frozen;
        admitted.parent = f.parent;
        admitted.guardian = f.restoredGuardian;
        admitted.primary = bytes32(uint256(741));
        admitted.occurrence = bytes32(uint256(742));
        admitted.secondary = bytes32(uint256(743));
        result.proof = keccak256(
            abi.encode(
                keccak256("6529STREAM_ARTIST_ADMITTED_LIVING_RECOVERY_V1"),
                f.recovery,
                f.transition,
                f.vesting,
                admitted
            )
        );
        if (family) {
            result.proof = keccak256(
                abi.encode(keccak256("6529STREAM_ARTIST_ADMITTED_RECOVERY_FAMILY_V2"), result.proof)
            );
        }
        if (f.imported) {
            result.proof = keccak256(
                abi.encode(
                    keccak256("6529STREAM_ARTIST_RECOVERED_ADMITTED_RECOVERY_SOURCE_V1"),
                    result.proof,
                    IMPORT,
                    f.creation
                )
            );
        }
    }

    function _call(Fixture memory f, bool family, bool original)
        private
        returns (bool, bytes memory)
    {
        return address(host)
            .call(
                abi.encodeCall(
                    host.run,
                    (
                        original,
                        family,
                        address(identity),
                        environment.registry,
                        environment.chainId,
                        ARTIST,
                        f.recovery.recordHash
                    )
                )
            );
    }

    function _good(Fixture memory f, bool family) private returns (bytes32 proof) {
        (bool ok, bytes memory actual) = _call(f, family, false);
        (bool oldOk, bytes memory original) = _call(f, family, true);
        require(ok && oldOk, "both reader paths succeed");
        require(keccak256(actual) == keccak256(original), "complete Facts return parity");
        Actual.Facts memory expected = _expected(f, family);
        require(
            keccak256(actual) == keccak256(abi.encode(abi.encode(expected))),
            "independent full Facts and literal proof"
        );
        proof = expected.proof;
        require(proof != 0, "nonzero full admission proof");
    }

    function _reject(Fixture memory f, bool family, bytes memory expected) private {
        (bool ok, bytes memory actual) = _call(f, family, false);
        (bool oldOk, bytes memory original) = _call(f, family, true);
        require(!ok && !oldOk, "both reader paths refuse");
        require(keccak256(actual) == keccak256(original), "full raw error parity");
        require(keccak256(actual) == keccak256(expected), "exact refusal oracle");
    }

    function _copy(Fixture memory f) private pure returns (Fixture memory) {
        return abi.decode(abi.encode(f), (Fixture));
    }

    function _invalid() private pure returns (bytes memory) {
        return abi.encodeWithSelector(
            IdentityRecovery.UnsupportedIdentityRecoveryProfile.selector, ARTIST
        );
    }

    function testNativeClassOneAndFamilyClassesPreserveFullFactsAndProofDomains() public {
        Fixture memory f = _fixture(false, 1, 0);
        bytes32 original = _good(f, false);
        require(_good(f, true) != original, "family domain remains distinct");
        for (uint256 i; i < 4; ++i) {
            uint16 operation = i == 0 ? 32 : i == 1 ? 35 : i == 2 ? 40 : 43;
            f = _fixture(false, i < 2 ? 1 : 3, operation);
            _good(f, true);
            if (i < 2) _good(f, false);
            else _reject(f, false, _invalid());
        }
    }

    function testSavedParentAndFrozenPrefixesIgnoreLaterNativeGuardianHeadGrowth() public {
        Fixture memory f = _fixture(false, 1, 32);
        bytes32 proof = _good(f, true);
        require(
            f.parent.guardians.count == 1 && f.vesting.guardians.count == 2
                && f.currentHead.count == 3,
            "different saved prefixes and current head"
        );
        Fixture memory later = _copy(f);
        later.currentHead = GH.Head(4, 95, bytes32(uint256(990)));
        _install(later);
        require(_good(later, true) == proof, "today's growing head is absent from original proof");
        _install(f);
        require(_good(f, true) == proof, "saved evidence remains exact after read-only head change");
    }

    function testImportedParentAndGuardianHistoryUseOriginalAndCurrentOwnerClocks() public {
        for (uint256 i; i < 2; ++i) {
            Fixture memory f = _fixture(true, i == 0 ? 1 : 3, i == 0 ? 32 : 40);
            require(
                f.prefix.journal.length == 4 && f.prefix.aliases.length == 1,
                "nonempty actual retained reader history"
            );
            require(
                f.origin.registry != environment.registry
                    && f.origin.owners[2] != address(identity),
                "original domain is not current owner"
            );
            require(
                f.currentHead.ownerRevision == 2 && f.vesting.ownerRevision == 70,
                "latest guardian uses low destination revision after old recovery"
            );
            _good(f, true);
            if (i == 0) _good(f, false);
            else _reject(f, false, _invalid());
        }
    }

    function testAdmissionAssociationStandingAndReceiptRefusalsRepairWithoutChangingOriginals()
        public
    {
        Fixture memory f = _fixture(false, 1, 32);
        for (uint256 i; i < 19; ++i) {
            Fixture memory bad = _copy(f);
            if (i == 0) bad.association.artistId = 0;
            if (i == 1) bad.association.requestHash = 0;
            if (i == 2) bad.association.contextHash = 0;
            if (i == 3) bad.association.action.actionId = 0;
            if (i == 4) bad.association.action.proposer = address(0);
            if (i == 5) bad.association.action.executor = address(0);
            if (i == 6) bad.association.ownerRevision = 0;
            if (i == 7) bad.association.ownerRevision = bad.vesting.ownerRevision;
            if (i == 8) bad.association.preparedAt = 0;
            if (i == 9) bad.association.preparedAt = bad.recovery.fields.recoveredAt + 1;
            if (i == 10) bad.frozen.artistId = 0;
            if (i == 11) bad.frozen.associationHash = 0;
            if (i == 12) bad.frozen.count = 1;
            if (i == 13) bad.frozen.historyCommitment = 0;
            _install(bad);
            if (i == 14) {
                A.Veto memory veto;
                identity.set(
                    abi.encodeWithSignature(
                        "identityRecoveryActionState(bytes32,bytes32)",
                        ARTIST,
                        f.recovery.fields.governanceActionId
                    ),
                    abi.encode(f.association, veto, bytes32(0), f.currentHead.count)
                );
            }
            if (i == 15 || i == 16) {
                identity.set(
                    abi.encodeWithSignature(
                        "recoveryTransitionStanding(bytes32)", f.recovery.recordHash
                    ),
                    abi.encode(
                        i == 15 ? address(0) : f.recovery.fields.oldAddress,
                        f.restoredGuardian,
                        i == 16 ? uint64(0) : f.recovery.standingTailSeconds
                    )
                );
            }
            if (i == 17 || i == 18) {
                identity.set(
                    abi.encodeWithSignature(
                        "identityRecoveryReceipts(bytes32)", f.recovery.recordHash
                    ),
                    abi.encode(
                        bytes32(uint256(741)),
                        i == 17 ? bytes32(0) : bytes32(uint256(742)),
                        bytes32(uint256(i == 17 ? 743 : 741))
                    )
                );
            }
            _reject(bad, true, _invalid());
            _install(f);
            _good(f, true);
        }
    }

    function testSavedGuardianPrefixRefusalsPreserveExactErrorsAndHealthyRetry() public {
        Fixture memory f = _fixture(false, 1, 32);
        for (uint256 i; i < 12; ++i) {
            Fixture memory bad = _copy(f);
            if (i == 0) bad.currentHead.count = 1;
            if (i == 1) bad.currentHead.ownerRevision = 19;
            if (i == 2) bad.guardians[1].artistId = 0;
            if (i == 3) bad.guardians[1].index = 1;
            if (i == 4) bad.guardians[1].ownerRevision = 19;
            if (i == 5) bad.guardians[1].commitment = 0;
            if (i == 6) bad.guardians[1].recordHash = 0;
            if (i == 7) bad.guardians[1].recordDataHash = 0;
            if (i == 8) bad.guardians[1].previousCommitment = bytes32(uint256(989));
            if (i == 9) {
                bad.vesting.guardians.ownerRevision = 0;
                bad.vesting.commitment = _vestingHash(bad.origin, bad.vesting);
            }
            if (i == 10) {
                bad.vesting.guardians.commitment = 0;
                bad.vesting.commitment = _vestingHash(bad.origin, bad.vesting);
            }
            _install(bad);
            if (i == 11) {
                GH.Head memory mismatched = GH.Head(4, 80, f.currentHead.commitment);
                _history(
                    2, f.recovery.fields.governanceActionId, mismatched, f.guardians[1], f.frozen
                );
            }
            _reject(bad, true, _invalid());
            _install(f);
            _good(f, true);
        }
    }

    function testParentSnapshotChainAndFamilyGatesRefuseThenRestoreOriginalFacts() public {
        Fixture memory f = _fixture(false, 1, 32);
        for (uint256 i; i < 16; ++i) {
            Fixture memory bad = _copy(f);
            if (i == 0) bad.parent.artistId = 0;
            if (i == 1) bad.parent.transitionRecordHash = bytes32(uint256(988));
            if (i == 2) bad.parent.authorityClass = 3;
            if (i == 3) bad.parent.operationId = 31;
            if (i == 4) bad.parent.oldAddress = address(0);
            if (i == 5) bad.parent.newAddress = address(987);
            if (i == 6) bad.parent.oldAddress = bad.parent.newAddress;
            if (i == 7) bad.parent.executedAt = 0;
            if (i == 8) bad.parent.executedAt = bad.vesting.executedAt + 1;
            if (i == 9) bad.parent.ownerRevision = 0;
            if (i == 10) bad.parent.ownerRevision = bad.vesting.ownerRevision;
            if (i == 11) bad.parent.ownerRevision = bad.parent.guardians.ownerRevision;
            if (i == 12) bad.parent.guardians.count = 3;
            if (i == 13) bad.parent.guardians.ownerRevision = 21;
            bad.parent.commitment = _vestingHash(bad.origin, bad.parent);
            bad.vesting.previousCommitment = bad.parent.commitment;
            if (i == 14) bad.vesting.previousCommitment = bytes32(uint256(986));
            if (i == 15) bad.vesting.previousTransitionRecordHash = 0;
            bad.vesting.commitment = _vestingHash(bad.origin, bad.vesting);
            _install(bad);
            _reject(bad, true, _invalid());
            _install(f);
            _good(f, true);
        }
        Fixture memory familyOnly = _copy(f);
        familyOnly.parent.operationId = 43;
        familyOnly.parent.commitment = _vestingHash(familyOnly.origin, familyOnly.parent);
        familyOnly.vesting.previousCommitment = familyOnly.parent.commitment;
        familyOnly.vesting.commitment = _vestingHash(familyOnly.origin, familyOnly.vesting);
        _install(familyOnly);
        _reject(familyOnly, false, _invalid());
        _good(familyOnly, true);
    }

    function testImportedPreparationParentAndCurrentGuardianJoinsCannotBeRelabeled() public {
        Fixture memory f = _fixture(true, 1, 32);
        for (uint256 i; i < 5; ++i) {
            Fixture memory bad = _copy(f);
            bytes memory expected = _invalid();
            if (i == 0) {
                bad.parent.ownerRevision = 70;
                bad.parent.commitment = _vestingHash(bad.origin, bad.parent);
                bad.vesting.previousCommitment = bad.parent.commitment;
                bad.vesting.commitment = _vestingHash(bad.origin, bad.vesting);
                _point(
                    identity,
                    VESTING,
                    f.parent.transitionRecordHash,
                    RH.Point(RH.originHash(f.origin), 2, 70)
                );
            }
            if (i == 1) {
                bad.association.ownerRevision = 70;
                bad.prefix.aliases[0].cell.touchedRevision = 70;
                bad.prefix.aliases[0].admittedAt.ownerRevision = 70;
                _point(
                    identity,
                    PREPARE,
                    f.recovery.fields.governanceActionId,
                    RH.Point(RH.originHash(f.origin), 2, 70)
                );
                _installPrefix(identity, bad.prefix, true);
            }
            if (i == 2) {
                bad.prefix.aliases[0].cell.commitment = bytes32(uint256(985));
                _installPrefix(identity, bad.prefix, true);
                expected = abi.encodeWithSelector(RH.InvalidRecoveredHydrationProvenance.selector);
            }
            if (i == 3) {
                bad.guardians[2].commitment = 0;
                expected = abi.encodeWithSelector(RH.InvalidRecoveredHydrationProvenance.selector);
            }
            if (i == 4) {
                identity.set(
                    abi.encodeWithSignature("artistNativeReceiptAt(uint256)", uint256(0)),
                    abi.encode(H.Receipt(28, ARTIST, 0, f.guardians[1].recordHash))
                );
                expected = abi.encodeWithSelector(RH.InvalidRecoveredHydrationProvenance.selector);
            }
            _install(bad);
            _reject(bad, true, expected);
            _installPrefix(identity, f.prefix, true);
            _point(
                identity,
                VESTING,
                f.parent.transitionRecordHash,
                RH.Point(RH.originHash(f.origin), 2, 40)
            );
            _point(
                identity,
                PREPARE,
                f.recovery.fields.governanceActionId,
                RH.Point(RH.originHash(f.origin), 2, 50)
            );
            identity.set(
                abi.encodeWithSignature("artistNativeReceiptAt(uint256)", uint256(0)),
                abi.encode(H.Receipt(28, ARTIST, 0, f.guardians[2].recordHash))
            );
            _install(f);
            _good(f, true);
        }
    }

    function testOriginalEmptyGuardianAndAssociationBranchRemainsExplicit() public {
        Fixture memory f = _fixture(false, 1, 0);
        GH.Head memory emptyHead;
        GH.Snapshot memory emptySnapshot;
        A.Association memory emptyAssociation;
        f.vesting.guardians = emptyHead;
        f.vesting.commitment = _vestingHash(f.origin, f.vesting);
        f.frozen = emptySnapshot;
        f.association = emptyAssociation;
        f.currentHead = emptyHead;
        f.restoredGuardian = 0;
        _install(f);
        _good(f, false);
        _good(f, true);
        Fixture memory bad = _copy(f);
        bad.restoredGuardian = bytes32(uint256(984));
        _install(bad);
        _reject(bad, true, _invalid());
        _install(f);
        _good(f, true);
    }

    function testSameHostCallerAndOrderedAdmissionReadsBubbleOriginalFailures() public {
        Fixture memory f = _fixture(false, 1, 32);
        bytes[] memory calls = new bytes[](9);
        calls[0] = abi.encodeWithSignature("identityRecoveryRecord(bytes32)", f.recovery.recordHash);
        calls[1] = abi.encodeWithSignature("artistTransitionState(bytes32)", f.recovery.recordHash);
        calls[2] = abi.encodeWithSignature(
            "guardianVestingSnapshot(bytes32,bytes32)", ARTIST, f.recovery.recordHash
        );
        calls[3] = abi.encodeWithSignature(
            "identityRecoveryActionState(bytes32,bytes32)",
            ARTIST,
            f.recovery.fields.governanceActionId
        );
        calls[4] = abi.encodeWithSignature(
            "guardianHistoryState(bytes32,uint64,address,bytes32)",
            ARTIST,
            uint64(2),
            address(0),
            f.recovery.fields.governanceActionId
        );
        calls[5] = abi.encodeWithSignature(
            "guardianVestingSnapshot(bytes32,bytes32)", ARTIST, f.parent.transitionRecordHash
        );
        calls[6] = abi.encodeWithSignature(
            "guardianHistoryState(bytes32,uint64,address,bytes32)",
            ARTIST,
            uint64(1),
            address(0),
            bytes32(0)
        );
        calls[7] =
            abi.encodeWithSignature("recoveryTransitionStanding(bytes32)", f.recovery.recordHash);
        calls[8] =
            abi.encodeWithSignature("identityRecoveryReceipts(bytes32)", f.recovery.recordHash);
        for (uint256 i; i < calls.length; ++i) {
            identity.fail(calls[i], true);
            if (i + 1 < calls.length) identity.fail(calls[i + 1], true);
            bytes memory expected = abi.encodeWithSelector(
                LivingAdmissionBoundaryFailure.selector, keccak256(calls[i])
            );
            _reject(f, false, expected);
            _reject(f, true, expected);
            identity.fail(calls[i], false);
            if (i + 1 < calls.length) identity.fail(calls[i + 1], false);
        }
        (bool ok, bytes memory error) = address(identity).call(calls[0]);
        require(
            !ok
                && keccak256(error)
                    == keccak256(
                        abi.encodeWithSelector(
                            LivingAdmissionBoundaryCaller.selector, address(this)
                        )
                    ),
            "caller-sensitive owner probe active"
        );
        _good(f, false);
        _good(f, true);
    }
}

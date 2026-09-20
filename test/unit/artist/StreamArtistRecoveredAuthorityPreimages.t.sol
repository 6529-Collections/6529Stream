// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { StreamArtistOwner } from "../../../smart-contracts/domains/artist/StreamArtistOwner.sol";
import {
    StreamArtistRotationState as Rotations
} from "../../../smart-contracts/domains/artist/StreamArtistRotationState.sol";
import {
    StreamArtistEstateState as Estates
} from "../../../smart-contracts/domains/artist/StreamArtistEstateState.sol";
import {
    StreamArtistIdentityState as Identity
} from "../../../smart-contracts/domains/artist/StreamArtistIdentityState.sol";
import {
    StreamArtistGuardianHistory as Guardians
} from "../../../smart-contracts/domains/artist/StreamArtistGuardianHistory.sol";
import {
    StreamArtistGuardianVestingHistory as Vestings
} from "../../../smart-contracts/domains/artist/StreamArtistGuardianVestingHistory.sol";
import {
    StreamArtistHydrationGuards as Guards
} from "../../../smart-contracts/domains/artist/StreamArtistHydrationGuards.sol";
import {
    StreamArtistRecoveredHydrationState as Imported
} from "../../../smart-contracts/domains/artist/StreamArtistRecoveredHydrationState.sol";
import {
    StreamArtistRecoveredRuntimeReads as Runtime
} from "../../../smart-contracts/domains/artist/StreamArtistRecoveredRuntimeReads.sol";
import {
    StreamArtistPayloadStore as Payloads
} from "../../../smart-contracts/domains/artist/StreamArtistPayloadStore.sol";
import {
    StreamArtistNativeReceipts as Native
} from "../../../smart-contracts/domains/artist/StreamArtistNativeReceipts.sol";
import {
    StreamArtistOnboardingTypes as T
} from "../../../smart-contracts/interfaces/stream/artist/StreamArtistOnboardingTypes.sol";
import {
    StreamArtistRecoveredHydrationTypes as RH
} from "../../../smart-contracts/interfaces/stream/artist/StreamArtistRecoveredHydrationTypes.sol";
import {
    StreamArtistAuthorityHydrationTypes as AH
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistAuthorityHydration.sol";
import {
    StreamArtistRotationTypes as R
} from "../../../smart-contracts/interfaces/stream/artist/StreamArtistRotationTypes.sol";
import {
    StreamArtistEstateTypes as E
} from "../../../smart-contracts/interfaces/stream/artist/StreamArtistEstateTypes.sol";
import {
    StreamArtistGuardianVestingTypes as V
} from "../../../smart-contracts/interfaces/stream/artist/StreamArtistGuardianVestingTypes.sol";
import {
    StreamArtistHistoryTypes as H
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistHistory.sol";
import {
    IStreamArtistAuthorityCheckpoint as CP
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistAuthorityCheckpoint.sol";
import {
    IStreamArtistReconstruction
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistReconstruction.sol";

interface RecoveredPreimageVm {
    function warp(uint256 time) external;
    function prank(address actor) external;
    function mockCall(address target, bytes calldata input, bytes calldata output) external;
}

contract RecoveredPreimageBoundary { }

/// @dev Synthetic pending admission/prefix setup followed by the actual original32/40 execution,
/// replay, vesting, common owner commit and PayloadStore writers. This is not Safe/op60 acceptance.
contract RecoveredPreimageOwner is StreamArtistOwner {
    Identity.State private identities;
    Rotations.State private rotations;
    Estates.State private estates;
    Guardians.State private guardians;
    Vestings.State private vestings;

    constructor(T.SuiteConfiguration memory suite, address coordinator)
        StreamArtistOwner(
            suite.registry,
            coordinator,
            suite.archive,
            RH.ownerDomain(2),
            suite.core,
            suite.mintManager
        )
    { }

    function seedPrefix(
        T.ActionContext calldata c,
        RH.OwnerProvenance calldata prefix,
        bool artifact
    ) external {
        _check(c, 60);
        bytes32 value = keccak256(abi.encode(prefix));
        Imported.installOwnerPrefix(prefix, 2, value, _revision + 1);
        AH.OwnerData memory empty;
        Guards.applyGuards(
            _replay, empty, artistRegistry, operationCoordinator, archiveV2, domainId, value
        );
        if (artifact) {
            for (uint256 i; i < prefix.journal.length; ++i) {
                RH.JournalEntry memory row = prefix.journal[i];
                Imported.installArtifact(
                    Runtime.nativeKind(row.receipt.operation),
                    row.receipt.recordHash,
                    row.position.point
                );
            }
        }
        _commit(c, value, value, 0, 0);
    }

    function seedRotation(R.RotationRecord calldata r, bool local) external {
        require(msg.sender == operationCoordinator);
        rotations.rotations[r.recordHash] = r;
        rotations.pending[r.terms.artistId] = r.recordHash;
        rotations.latestTransition[r.terms.artistId] = r.recordHash;
        _principal(r.terms.artistId, r.terms.oldAddress);
        if (local) _native(29, r.recordHash, r.terms.artistId, 0);
    }

    function seedEstate(E.RequestRecord calldata r, bool local) external {
        require(msg.sender == operationCoordinator);
        estates.requests[r.recordHash] = r;
        estates.pending[r.terms.artistId] = r.recordHash;
        estates.phases[r.recordHash] = 1;
        estates.transitions[r.recordHash] = R.TransitionState(
            r.terms.artistId, r.recordHash, r.requestedAt, r.noticeEndsAt, 0, 0, 0, 1
        );
        rotations.latestTransition[r.terms.artistId] = r.recordHash;
        _principal(r.terms.artistId, r.incumbent);
        if (local) _native(38, r.recordHash, r.terms.artistId, 0);
    }

    /// @dev A separate genuine owner mutation establishes a local staging revision for the
    /// synthetic admission fixture. No signed29/38 admission is claimed by seedRotation/seedEstate.
    function stagingRevision(T.ActionContext calldata c) external {
        _check(c, 29);
        _commit(c, keccak256("synthetic stage boundary"), 0, 0, 0);
    }

    function executeRotation(T.ActionContext calldata c, bytes32 artist, bytes32 record) external {
        _check(c, 32);
        R.RotationRecord memory r = rotations.rotations[record];
        Identity.Mutation memory m =
            Rotations.execute(rotations, identities, _replay, _owner(), c, artist, record);
        _vesting(artist, record, 32, r.terms.oldAddress, r.terms.newAddress, 1);
        _commit(c, m.action, m.state, m.replay, m.record);
    }

    function executeEstate(T.ActionContext calldata c, bytes32 artist, bytes32 record) external {
        _check(c, 40);
        E.RequestRecord memory r = estates.requests[record];
        E.AccelerationContext memory acceleration;
        Identity.Mutation memory m = Estates.execute(
            estates,
            identities,
            rotations,
            _replay,
            _owner(),
            c,
            E.Execution(artist, record, keccak256("current authentic coverage fixture")),
            7,
            acceleration,
            0,
            0
        );
        _vesting(artist, record, 40, r.incumbent, r.terms.successor, 3);
        _commit(c, m.action, m.state, m.replay, m.record);
    }

    function recoveredHydrationAuxiliaryPoint(bytes32 kind, bytes32 key)
        external
        view
        override
        returns (RH.Point memory)
    {
        // Production Identity uses its fixed typed native resolver. This fixture resolves only
        // the actual locally appended29/38 rows; retained requests use the real imported metadata.
        for (uint256 i; i < Native.count(); ++i) {
            H.Receipt memory row = Native.at(i);
            if (Runtime.nativeKind(row.operation) == kind && row.recordHash == key) {
                RH.OriginEnvironment memory current = _current();
                return RH.Point(RH.originHash(current), 2, Native.revisionAt(i));
            }
        }
        return Imported.artifact(kind, key);
    }

    function stateOf(bytes32 artist, bytes32 record, bool estate)
        external
        view
        returns (
            R.TransitionState memory transition,
            T.Identity memory principal,
            V.Snapshot memory vesting
        )
    {
        transition = estate ? estates.transitions[record] : rotations.rotations[record].transition;
        principal = identities.identities[artist];
        vesting = vestings.snapshots[record];
    }

    function payload(bytes32 record) external view returns (bytes memory) {
        return Payloads.recordBytes(record);
    }

    function payloadCount() external view returns (uint256) {
        return Payloads.count();
    }

    function _principal(bytes32 artist, address incumbent) private {
        identities.identities[artist].authorityAddress = incumbent;
        identities.identities[artist].authorityClass = 1;
        identities.identities[artist].status = 1;
        identities.activeIdentity[incumbent] = artist;
    }

    function _owner() private view returns (Identity.OwnerContext memory o) {
        o.environment = _environment();
        o.coordinator = operationCoordinator;
        o.archive = archiveV2;
        o.domain = domainId;
        o.revision = _revision;
    }

    function _current() private view returns (RH.OriginEnvironment memory e) {
        // Uses the fixed owner getter rather than inventing an origin table in the producer.
        (bool ok, bytes memory raw) =
            operationCoordinator.staticcall(abi.encodeWithSignature("authorityHydrationSuite()"));
        require(ok, "fixed suite getter");
        T.SuiteConfiguration memory suite = abi.decode(raw, (T.SuiteConfiguration));
        e.chainId = deploymentChainId;
        e.registry = artistRegistry;
        e.coordinator = operationCoordinator;
        e.archive = archiveV2;
        e.owners = suite.owners;
        for (uint256 i; i < 7; ++i) {
            e.ownerCodeHashes[i] = suite.owners[i].codehash;
        }
        e.core = core;
        e.manager = mintManager;
        e.suiteConfigurationHash = keccak256(abi.encode(suite));
    }

    function _vesting(
        bytes32 artist,
        bytes32 record,
        uint16 operation,
        address oldAddress,
        address newAddress,
        uint8 authorityClass
    ) private {
        V.Snapshot memory v;
        v.artistId = artist;
        v.transitionRecordHash = record;
        v.operationId = operation;
        v.ownerRevision = _revision + 1;
        v.executedAt = uint64(block.timestamp);
        v.oldAddress = oldAddress;
        v.newAddress = newAddress;
        v.authorityClass = authorityClass;
        Vestings.record(vestings, guardians, _environment(), v, 0);
    }
}

/// @notice Real execution/preimage regression with explicit synthetic source admission.
/// @dev No capability activation, full seven-owner import, signatures or Safe execution is claimed.
contract StreamArtistRecoveredAuthorityPreimagesTest {
    RecoveredPreimageVm private constant vm =
        RecoveredPreimageVm(address(uint160(uint256(keccak256("hevm cheat code")))));
    bytes32 private constant ARTIST = bytes32(uint256(61));
    address private constant OLD = address(620);
    address private constant NEXT = address(621);
    T.SuiteConfiguration private suite;
    RecoveredPreimageOwner private owner;

    function setUp() public {
        vm.warp(200 days);
        suite.registry = address(new RecoveredPreimageBoundary());
        suite.archive = address(new RecoveredPreimageBoundary());
        suite.core = address(new RecoveredPreimageBoundary());
        suite.mintManager = address(new RecoveredPreimageBoundary());
        for (uint256 i; i < 7; ++i) {
            suite.owners[i] = address(new RecoveredPreimageBoundary());
        }
        owner = new RecoveredPreimageOwner(suite, address(this));
        suite.owners[2] = address(owner);
        _bindings(suite.owners[5], 5);
    }

    function suiteConfiguration() external view returns (T.SuiteConfiguration memory) {
        return suite;
    }

    function authorityHydrationSuite() external view returns (T.SuiteConfiguration memory) {
        return suite;
    }

    function deploymentChainId() external view returns (uint256) {
        return block.chainid;
    }

    function testRecoveredPending29ExecutesWithOriginalPreimageAndCurrentReplayVesting() public {
        R.RotationRecord memory r = _rotation(address(1000));
        _import(29, r.recordHash, true, false);
        owner.seedRotation(r, false);
        T.Snapshot memory before_ = owner.ownerStateSnapshotV2();
        owner.executeRotation(_context(32), ARTIST, r.recordHash);
        _executed(r.recordHash, false, before_, _rotationBytes(address(1000), r));
    }

    function testRecoveredPending38ExecutesWithOriginalPreimageAndCurrentReplayVesting() public {
        E.RequestRecord memory r = _estate(address(1000));
        _import(38, r.recordHash, true, false);
        owner.seedEstate(r, false);
        T.Snapshot memory before_ = owner.ownerStateSnapshotV2();
        owner.executeEstate(_context(40), ARTIST, r.recordHash);
        _executed(r.recordHash, true, before_, _estateBytes(address(1000), r));
    }

    function testRecoveredRepeatedPrefixRetainsUltimateRequestOrigin() public {
        R.RotationRecord memory r = _rotation(address(1000));
        _import(29, r.recordHash, true, true);
        owner.seedRotation(r, false);
        T.Snapshot memory before_ = owner.ownerStateSnapshotV2();
        owner.executeRotation(_context(32), ARTIST, r.recordHash);
        _executed(r.recordHash, false, before_, _rotationBytes(address(1000), r));
    }

    function testRecoveredPendingRequestMissingArtifactRejectsWithoutMutation() public {
        E.RequestRecord memory r = _estate(address(1000));
        _import(38, r.recordHash, false, false);
        owner.seedEstate(r, false);
        _reject(
            abi.encodeCall(owner.executeEstate, (_context(40), ARTIST, r.recordHash)),
            abi.encodeWithSelector(RH.InvalidRecoveredHydrationProvenance.selector),
            r.recordHash,
            true
        );
    }

    function testRecoveredPendingRequestArtifactMustMatchNativeOccurrence() public {
        R.RotationRecord memory r = _rotation(address(1000));
        RH.OwnerProvenance memory p = _import(29, r.recordHash, true, false);
        owner.seedRotation(r, false);
        vm.mockCall(
            address(owner),
            abi.encodeWithSignature(
                "recoveredHydrationAuxiliaryPoint(bytes32,bytes32)",
                Runtime.nativeKind(29),
                r.recordHash
            ),
            abi.encode(RH.Point(p.eras[0].originHash, 2, 89))
        );
        _reject(
            abi.encodeCall(owner.executeRotation, (_context(32), ARTIST, r.recordHash)),
            abi.encodeWithSelector(RH.InvalidRecoveredHydrationProvenance.selector),
            r.recordHash,
            false
        );
    }

    function testRecoveredPendingRequestBodyCannotBeRelabelled() public {
        R.RotationRecord memory r = _rotation(address(1000));
        _import(29, r.recordHash, true, false);
        r.terms.reasonHash = keccak256("corrupted original reason");
        owner.seedRotation(r, false);
        _reject(
            abi.encodeCall(owner.executeRotation, (_context(32), ARTIST, r.recordHash)),
            abi.encodeWithSelector(
                IStreamArtistReconstruction.ArtistPayloadCorrupted.selector,
                r.recordHash,
                keccak256(_rotationBytes(address(1000), r))
            ),
            r.recordHash,
            false
        );
    }

    function testRecoveredPendingRequestsRetainOriginalWaitingRules() public {
        R.RotationRecord memory r = _rotation(address(1000));
        _import(29, r.recordHash, true, false);
        owner.seedRotation(r, false);
        vm.warp(r.transition.contestEndsAt - 1);
        _reject(
            abi.encodeCall(owner.executeRotation, (_context(32), ARTIST, r.recordHash)),
            abi.encodeWithSelector(R.RotationNotExecutable.selector, r.recordHash),
            r.recordHash,
            false
        );
    }

    function testRecoveredPendingEstateRetainsOriginalAccelerationRequirement() public {
        E.RequestRecord memory r = _estate(address(1000));
        _import(38, r.recordHash, true, false);
        owner.seedEstate(r, false);
        vm.warp(r.noticeEndsAt - 1);
        _reject(
            abi.encodeCall(owner.executeEstate, (_context(40), ARTIST, r.recordHash)),
            abi.encodeWithSelector(E.EstateNoticeNotElapsed.selector, r.noticeEndsAt),
            r.recordHash,
            true
        );
    }

    function testRecoveredPendingExecutionRetainsFixedCoordinatorGuard() public {
        R.RotationRecord memory r = _rotation(address(1000));
        _import(29, r.recordHash, true, false);
        owner.seedRotation(r, false);
        bytes memory call_ =
            abi.encodeCall(owner.executeRotation, (_context(32), ARTIST, r.recordHash));
        vm.prank(address(999));
        (bool ok, bytes memory error) = address(owner).call(call_);
        require(
            !ok
                && keccak256(error)
                    == keccak256(abi.encodeWithSelector(T.Unauthorized.selector, address(999))),
            "original fixed coordinator guard"
        );
        require(owner.payloadCount() == 0, "no unauthorized capture");
    }

    function testRecoveredFreshLocalRequestUsesCurrentOriginAfterImport() public {
        RH.OwnerProvenance memory p = _prefix(29, bytes32(uint256(2000)), false);
        p.journal = new RH.JournalEntry[](0);
        p.eras[0].nativeCount = 0;
        owner.seedPrefix(_context(60), p, true);
        owner.stagingRevision(_context(29));
        R.RotationRecord memory r = _rotation(suite.registry);
        owner.seedRotation(r, true);
        T.Snapshot memory before_ = owner.ownerStateSnapshotV2();
        owner.executeRotation(_context(32), ARTIST, r.recordHash);
        _executed(r.recordHash, false, before_, _rotationBytes(suite.registry, r));
        require(owner.artistNativeReceiptCount() == 1, "only existing local29 occurrence");
    }

    function testUnimportedRotationPreimageBytesRemainOriginal() public {
        owner.stagingRevision(_context(29));
        R.RotationRecord memory r = _rotation(suite.registry);
        owner.seedRotation(r, true);
        T.Snapshot memory before_ = owner.ownerStateSnapshotV2();
        owner.executeRotation(_context(32), ARTIST, r.recordHash);
        _executed(r.recordHash, false, before_, _rotationBytes(suite.registry, r));
    }

    function testUnimportedEstatePreimageBytesRemainOriginal() public {
        owner.stagingRevision(_context(29));
        E.RequestRecord memory r = _estate(suite.registry);
        owner.seedEstate(r, true);
        T.Snapshot memory before_ = owner.ownerStateSnapshotV2();
        owner.executeEstate(_context(40), ARTIST, r.recordHash);
        _executed(r.recordHash, true, before_, _estateBytes(suite.registry, r));
    }

    function _import(uint16 operation, bytes32 record, bool artifact, bool repeated)
        private
        returns (RH.OwnerProvenance memory p)
    {
        p = _prefix(operation, record, repeated);
        owner.seedPrefix(_context(60), p, artifact);
    }

    function _prefix(uint16 operation, bytes32 record, bool repeated)
        private
        view
        returns (RH.OwnerProvenance memory p)
    {
        p.origins = new RH.OriginEnvironment[](repeated ? 2 : 1);
        p.eras = new RH.OwnerEra[](p.origins.length);
        for (uint256 j; j < p.origins.length; ++j) {
            RH.OriginEnvironment memory origin;
            origin.chainId = block.chainid;
            origin.registry = address(uint160(1000 + j));
            origin.coordinator = address(uint160(1100 + j));
            origin.archive = address(uint160(1200 + j));
            origin.core = suite.core;
            origin.manager = suite.mintManager;
            origin.suiteConfigurationHash = keccak256(abi.encode("synthetic original suite", j));
            for (uint256 i; i < 7; ++i) {
                origin.owners[i] = address(uint160(1300 + i + j * 10));
                origin.ownerCodeHashes[i] = keccak256(abi.encode("synthetic original owner", i, j));
            }
            p.origins[j] = origin;
            CP.Checkpoint memory cp = CP.Checkpoint(
                RH.CHECKPOINT,
                T.Snapshot(
                    RH.ownerDomain(2),
                    j == 0 ? 90 : 1,
                    keccak256("original state"),
                    keccak256("original tip")
                ),
                0,
                0,
                0,
                0
            );
            p.eras[j] = RH.OwnerEra(
                RH.originHash(origin),
                cp,
                j == 0 ? 1 : 0,
                j == 0 ? 0 : 1,
                j == 0 ? bytes32(0) : keccak256("earlier import")
            );
        }
        p.journal = new RH.JournalEntry[](1);
        p.journal[0] = RH.JournalEntry(
            RH.Position(RH.Point(p.eras[0].originHash, 2, 90), 0),
            H.Receipt(operation, ARTIST, 0, record)
        );
    }

    function _rotation(address registry) private view returns (R.RotationRecord memory r) {
        r.terms.artistId = ARTIST;
        r.terms.oldAddress = OLD;
        r.terms.newAddress = NEXT;
        r.terms.reasonHash = keccak256("original rotation reason");
        r.oldNonce = 7;
        r.effectiveWindow = 7 days;
        r.transition = R.TransitionState(ARTIST, 0, 1, 7 days, 0, 0, 0, 1);
        r.recordHash = keccak256(_rotationBytes(registry, r));
        r.transition.recordHash = r.recordHash;
    }

    function _estate(address registry) private view returns (E.RequestRecord memory r) {
        r.terms.artistId = ARTIST;
        r.terms.successor = NEXT;
        r.terms.evidenceHash = keccak256("original estate evidence");
        r.incumbent = OLD;
        r.authorization.nonce = 9;
        r.requestedAt = 1;
        r.noticeEndsAt = 180 days;
        r.postContestSeconds = 7 days;
        r.recordHash = keccak256(_estateBytes(registry, r));
    }

    function _rotationBytes(address registry, R.RotationRecord memory r)
        private
        view
        returns (bytes memory)
    {
        return abi.encode(
            bytes32(0x8d7c32ae357c27253fd4480fe9d411cefc64a5634952ed8c8ebe7dcf63257ea5),
            block.chainid,
            registry,
            r.terms.artistId,
            r.terms.oldAddress,
            r.terms.newAddress,
            r.terms.reasonHash,
            r.oldNonce,
            r.transition.stagedAt,
            r.transition.contestEndsAt
        );
    }

    function _estateBytes(address registry, E.RequestRecord memory r)
        private
        view
        returns (bytes memory)
    {
        return abi.encode(
            keccak256("6529STREAM_ARTIST_ESTATE_ACTIVATION_RECORD_V1"),
            block.chainid,
            registry,
            r.terms.artistId,
            r.terms.successor,
            r.terms.evidenceHash,
            r.authorization.nonce,
            r.requestedAt,
            r.noticeEndsAt
        );
    }

    function _context(uint16 operation) private view returns (T.ActionContext memory) {
        return T.ActionContext(operation, address(this), owner.ownerStateSnapshotV2());
    }

    function _executed(
        bytes32 record,
        bool estate,
        T.Snapshot memory before_,
        bytes memory expected
    ) private view {
        require(
            keccak256(owner.payload(record)) == record && keccak256(expected) == record,
            "exact original request preimage"
        );
        require(keccak256(owner.payload(record)) == keccak256(expected), "literal original bytes");
        T.Snapshot memory after_ = owner.ownerStateSnapshotV2();
        require(
            after_.revision == before_.revision + 1
                && after_.recordChainTip == before_.recordChainTip,
            "one destination execution commit without synthetic record"
        );
        (R.TransitionState memory t, T.Identity memory principal, V.Snapshot memory v) =
            owner.stateOf(ARTIST, record, estate);
        require(
            t.phase == 2 && t.executedAt == block.timestamp && principal.authorityAddress == NEXT,
            "actual original execution mutation"
        );
        require(
            v.ownerRevision == after_.revision && v.operationId == (estate ? 40 : 32),
            "real destination vesting revision"
        );
        bytes32 commitment = keccak256(
            bytes.concat(
                abi.encode(
                    keccak256("6529STREAM_ARTIST_GUARDIAN_VESTING_V1"),
                    block.chainid,
                    suite.registry,
                    address(owner)
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
        require(v.commitment == commitment, "vesting keeps destination domain");
        T.ReplayCell memory cell = owner.replayCell(_executionKey(record, estate));
        require(
            cell.commitment == record && cell.touchedRevision == after_.revision && cell.kind == 1
                && cell.status == 2,
            "execution replay keeps destination domain/revision"
        );
        require(owner.payloadCount() == 1, "only original preimage captured");
    }

    function _executionKey(bytes32 record, bool estate) private view returns (bytes32) {
        return keccak256(
            abi.encode(
                keccak256("6529STREAM_ARTIST_OWNER_REPLAY_KEY_V2"),
                block.chainid,
                suite.registry,
                address(this),
                suite.archive,
                address(owner),
                RH.ownerDomain(2),
                estate
                    ? keccak256("identity_authority.replay.activation_execution_key")
                    : keccak256("identity_authority.replay.rotation_execution_key"),
                record
            )
        );
    }

    function _reject(bytes memory call_, bytes memory expected, bytes32 record, bool estate)
        private
    {
        bytes32 before_ =
            keccak256(abi.encode(owner.ownerStateSnapshotV2(), owner.authorityCheckpoint()));
        (bool ok, bytes memory error) = address(owner).call(call_);
        require(!ok && keccak256(error) == keccak256(expected), "exact execution failure");
        require(
            before_
                == keccak256(abi.encode(owner.ownerStateSnapshotV2(), owner.authorityCheckpoint())),
            "owner/checkpoint rollback"
        );
        (R.TransitionState memory t, T.Identity memory principal, V.Snapshot memory v) =
            owner.stateOf(ARTIST, record, estate);
        require(
            t.phase == 1 && t.executedAt == 0 && principal.authorityAddress == OLD
                && v.commitment == 0,
            "semantic rollback"
        );
        require(
            owner.payloadCount() == 0
                && owner.replayCell(_executionKey(record, estate)).status == 0,
            "payload/replay rollback"
        );
    }

    function _bindings(address target, uint8 index) private {
        vm.mockCall(target, abi.encodeWithSignature("artistRegistry()"), abi.encode(suite.registry));
        vm.mockCall(
            target, abi.encodeWithSignature("operationCoordinator()"), abi.encode(address(this))
        );
        vm.mockCall(target, abi.encodeWithSignature("archiveV2()"), abi.encode(suite.archive));
        vm.mockCall(target, abi.encodeWithSignature("core()"), abi.encode(suite.core));
        vm.mockCall(target, abi.encodeWithSignature("mintManager()"), abi.encode(suite.mintManager));
        vm.mockCall(
            target, abi.encodeWithSignature("deploymentChainId()"), abi.encode(block.chainid)
        );
        vm.mockCall(
            target, abi.encodeWithSignature("domainId()"), abi.encode(RH.ownerDomain(index))
        );
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamArtistRotationState as Rotations
} from "../../../smart-contracts/domains/artist/StreamArtistRotationState.sol";
import {
    StreamArtistIdentityState as Identity
} from "../../../smart-contracts/domains/artist/StreamArtistIdentityState.sol";
import {
    StreamArtistIdentityResolutionState as Resolution
} from "../../../smart-contracts/domains/artist/StreamArtistIdentityResolutionState.sol";
import {
    StreamArtistRecoveryFamilyHistory as Family
} from "../../../smart-contracts/domains/artist/StreamArtistRecoveryFamilyHistory.sol";
import {
    StreamArtistRecoveryFamilyEpisodes as Episodes
} from "../../../smart-contracts/domains/artist/StreamArtistRecoveryFamilyEpisodes.sol";
import {
    StreamArtistRecoveryFamilyEligibility as Eligibility
} from "../../../smart-contracts/domains/artist/StreamArtistRecoveryFamilyEligibility.sol";
import {
    StreamArtistRecoveryAdjudicationOrigins as Origins
} from "../../../smart-contracts/domains/artist/StreamArtistRecoveryAdjudicationOrigins.sol";
import {
    StreamArtistRecoveryStagingHistory as Stages
} from "../../../smart-contracts/domains/artist/StreamArtistRecoveryStagingHistory.sol";
import {
    StreamArtistRecoveryStagingHeadHistory as Heads
} from "../../../smart-contracts/domains/artist/StreamArtistRecoveryStagingHeadHistory.sol";
import {
    StreamArtistRecoveryRewindCapabilityReads as Capabilities
} from "../../../smart-contracts/domains/artist/StreamArtistRecoveryRewindCapabilityReads.sol";
import {
    StreamArtistRecoveryRewindState as Rewind
} from "../../../smart-contracts/domains/artist/StreamArtistRecoveryRewindState.sol";
import {
    StreamArtistEstateState as EstateState
} from "../../../smart-contracts/domains/artist/StreamArtistEstateState.sol";
import {
    StreamArtistDormancyState as Dormancy
} from "../../../smart-contracts/domains/artist/StreamArtistDormancyState.sol";
import {
    StreamArtistAuthorityCheckpoint as Checkpoint
} from "../../../smart-contracts/domains/artist/StreamArtistAuthorityCheckpoint.sol";
import {
    StreamArtistHashes as H
} from "../../../smart-contracts/domains/artist/StreamArtistHashes.sol";
import {
    StreamArtistOnboardingTypes as T
} from "../../../smart-contracts/interfaces/stream/artist/StreamArtistOnboardingTypes.sol";
import {
    StreamArtistRotationTypes as R
} from "../../../smart-contracts/interfaces/stream/artist/StreamArtistRotationTypes.sol";
import {
    StreamArtistIdentityRecoveryOperationTypes as Recovery
} from "../../../smart-contracts/interfaces/stream/artist/StreamArtistIdentityRecoveryOperationTypes.sol";
import {
    StreamArtistHistoryTypes as Native
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistHistory.sol";
import {
    StreamArtistEstateTypes as E
} from "../../../smart-contracts/interfaces/stream/artist/StreamArtistEstateTypes.sol";
import {
    StreamArtistRecoveredHydrationTypes as RH
} from "../../../smart-contracts/interfaces/stream/artist/StreamArtistRecoveredHydrationTypes.sol";

interface HistoryWorkerVm {
    struct Log {
        bytes32[] topics;
        bytes data;
        address emitter;
    }
    function warp(uint256) external;
    function expectRevert(bytes calldata) external;
    function recordLogs() external;
    function getRecordedLogs() external returns (Log[] memory);
}

/// @dev Typed storage/read fixture only. These tests do not claim an admitted recovery history.
contract RecoveryHistoryWorkerHarness {
    bytes32 public beforeCanary = keccak256("before original roots");
    Rotations.State private rotations;
    Identity.State private identities;
    Resolution.State private resolutions;
    Rewind.State private rewind;
    EstateState.State private estate;
    Dormancy.State private dormancy;
    mapping(bytes32 => T.ReplayCell) private replay;
    Native.Receipt[] private receipts;
    mapping(bytes32 => Recovery.Record) private recoveries;
    bytes32 public afterCanary = keccak256("after original roots");

    constructor() {
        Checkpoint.initialize();
    }

    function environment() public view returns (H.Environment memory) {
        return H.Environment(block.chainid, address(0xBEEF), address(0xC001), address(0xC002));
    }

    function install(bytes32 id, R.RotationRecord memory r, T.Identity memory principal) external {
        rotations.rotations[r.recordHash] = r;
        rotations.pending[id] = r.recordHash;
        identities.identities[id] = principal;
        identities.activeIdentity[principal.authorityAddress] = id;
    }

    function occupy(address account, bytes32 id) external {
        identities.activeIdentity[account] = id;
    }

    function execute(bytes32 id, bytes32 record) external returns (Identity.Mutation memory) {
        Identity.OwnerContext memory o = Identity.OwnerContext(
            environment(),
            address(0xC003),
            address(0xC004),
            keccak256("domain:identity_authority"),
            7
        );
        T.ActionContext memory c;
        c.actor = msg.sender;
        return Rotations.execute(rotations, identities, replay, o, c, id, record);
    }

    function stateHash(
        bytes32 id,
        bytes32 record,
        address oldAddress,
        address newAddress,
        bytes32 a,
        bytes32 b
    ) external view returns (bytes32) {
        return keccak256(
            abi.encode(
                rotations.rotations[record],
                rotations.pending[id],
                rotations.latestExecution[id],
                rotations.retirement[id][oldAddress],
                identities.identities[id],
                identities.activeIdentity[oldAddress],
                identities.activeIdentity[newAddress],
                replay[a],
                replay[b],
                Checkpoint.checkpoint(),
                beforeCanary,
                afterCanary
            )
        );
    }

    function result(bytes32 id, bytes32 record, bytes32 a, bytes32 b)
        external
        view
        returns (
            T.Identity memory,
            R.TransitionState memory,
            T.ReplayCell memory,
            T.ReplayCell memory,
            uint64
        )
    {
        return (
            identities.identities[id],
            rotations.rotations[record].transition,
            replay[a],
            replay[b],
            uint64(Checkpoint.checkpoint().replayCount)
        );
    }

    function episodeResult(Family.Chain memory h)
        external
        view
        returns (Family.Chain memory, bytes32)
    {
        bytes32 proof;
        (proof, h.episodes) = Episodes._episodes(rotations, resolutions, environment(), h);
        return (h, proof);
    }

    function eligible(Family.Chain memory h, R.TransitionState memory t, uint64 at) external view {
        RH.Point memory p;
        Eligibility._eligibleAt(resolutions, h, t, at, 0, p);
    }

    function setReceipts(Native.Receipt[] memory rows, Recovery.Record memory r) external {
        delete receipts;
        for (uint256 i; i < rows.length; ++i) {
            receipts.push(rows[i]);
        }
        recoveries[r.recordHash] = r;
    }

    function artistNativeReceiptCount() external view returns (uint256) {
        return receipts.length;
    }

    function artistNativeReceiptAt(uint256 i) external view returns (Native.Receipt memory) {
        return receipts[i];
    }

    function identityRecoveryRecord(bytes32 record) external view returns (Recovery.Record memory) {
        return recoveries[record];
    }

    function nativeProof(bytes32 id, bytes32 record, uint16 operation)
        external
        view
        returns (bytes32)
    {
        return Origins._native(id, record, operation);
    }

    function selected(bytes32 id) external view returns (Native.Receipt memory) {
        Stages.Environment memory e;
        e.owner = address(this);
        e.registry = address(0xBEEF);
        e.chainId = block.chainid;
        return Heads._select(e, id, 0, 0);
    }

    function installEstate(bytes32 id, address authority, uint32 mask, bool active) external {
        identities.identities[id].authorityAddress = authority;
        identities.identities[id].authorityClass = 3;
        identities.identities[id].status = 3;
        identities.activeIdentity[authority] = active ? id : bytes32(0);
        bytes32 origin = keccak256(abi.encode(id, "origin"));
        estate.authorityActivation[id] = origin;
        estate.phases[origin] = 2;
        estate.requests[origin].recordHash = origin;
        estate.requests[origin].terms.artistId = id;
        estate.executions[origin].activationRecordHash = origin;
        estate.executions[origin].executedAt = 100;
        estate.executions[origin].delegationEpoch = 1;
        estate.executions[origin].effectiveCapabilities = mask;
    }

    function currentCapabilities(bytes32 id)
        external
        view
        returns (E.AuthorityCapabilities memory)
    {
        return Capabilities.current(rewind, identities, estate, dormancy, id);
    }
}

contract StreamArtistRecoveryHistoryWorkersTest {
    HistoryWorkerVm private constant vm =
        HistoryWorkerVm(address(uint160(uint256(keccak256("hevm cheat code")))));
    bytes32 private constant ID = keccak256("worker original artist");
    RecoveryHistoryWorkerHarness private h;

    function setUp() public {
        h = new RecoveryHistoryWorkerHarness();
        vm.warp(1000);
    }

    function _rotation(uint64 end)
        private
        view
        returns (R.RotationRecord memory r, T.Identity memory p)
    {
        r.terms = R.Rotation(ID, address(0x1111), address(0x2222), keccak256("reason"), 0);
        r.oldNonce = 9;
        r.effectiveWindow = 72 hours;
        r.standingTail = 30 days;
        r.timingRevision = 1;
        r.recordHash = keccak256(
            abi.encode(
                bytes32(0x8d7c32ae357c27253fd4480fe9d411cefc64a5634952ed8c8ebe7dcf63257ea5),
                block.chainid,
                address(0xBEEF),
                ID,
                r.terms.oldAddress,
                r.terms.newAddress,
                r.terms.reasonHash,
                r.oldNonce,
                uint64(100),
                end
            )
        );
        r.transition = R.TransitionState(ID, r.recordHash, 100, end, 0, 0, 0, 1);
        p.authorityAddress = r.terms.oldAddress;
        p.authorityClass = 1;
        p.status = 1;
        p.displayName = "unchanged principal";
    }

    function _key(bytes32 surface, bytes32 scope) private view returns (bytes32) {
        return keccak256(
            abi.encode(
                keccak256("6529STREAM_ARTIST_OWNER_REPLAY_KEY_V2"),
                block.chainid,
                address(0xBEEF),
                address(0xC003),
                address(0xC004),
                address(h),
                keccak256("domain:identity_authority"),
                surface,
                scope
            )
        );
    }

    function _keys(R.RotationRecord memory r) private view returns (bytes32 a, bytes32 b) {
        a = _key(keccak256("identity_authority.replay.rotation_execution_key"), r.recordHash);
        b = _key(
            keccak256("identity_authority.replay.standing_retirement"),
            keccak256(abi.encode(ID, r.terms.oldAddress, r.recordHash))
        );
    }

    function _error() private pure returns (bytes memory) {
        return abi.encodeWithSelector(Recovery.UnsupportedIdentityRecoveryProfile.selector, ID);
    }

    function testRotationExecutionPreservesHostReplayAndEventContext() public {
        (R.RotationRecord memory r, T.Identity memory p) = _rotation(900);
        h.install(ID, r, p);
        (bytes32 a, bytes32 b) = _keys(r);
        vm.recordLogs();
        Identity.Mutation memory m = h.execute(ID, r.recordHash);
        HistoryWorkerVm.Log[] memory logs = vm.getRecordedLogs();
        (
            T.Identity memory after_,
            R.TransitionState memory t,
            T.ReplayCell memory ca,
            T.ReplayCell memory cb,
            uint64 count
        ) = h.result(ID, r.recordHash, a, b);
        require(
            after_.authorityAddress == r.terms.newAddress
                && keccak256(bytes(after_.displayName)) == keccak256(bytes(p.displayName)),
            "principal fields"
        );
        require(
            t.phase == 2 && t.executedAt == 1000 && t.postWindowEndsAt == 1000 + 72 hours, "timing"
        );
        require(
            ca.commitment == r.recordHash && cb.commitment == r.recordHash
                && ca.touchedRevision == 8 && cb.touchedRevision == 8 && ca.kind == 1
                && cb.kind == 1 && ca.status == 2 && cb.status == 2 && count == 2,
            "literal replay keys"
        );
        require(m.action == keccak256(abi.encode(ID, r.recordHash, address(this))), "caller actor");
        bytes32 signature =
            keccak256("ArtistAddressRotated(uint16,bytes32,address,address,uint8,bytes32,bytes32)");
        bool found;
        for (uint256 i; i < logs.length; ++i) {
            if (logs[i].topics.length == 0 || logs[i].topics[0] != signature) continue;
            require(
                !found && logs[i].emitter == address(h) && logs[i].topics.length == 4
                    && logs[i].topics[1] == ID
                    && logs[i].topics[2] == bytes32(uint256(uint160(r.terms.oldAddress)))
                    && logs[i].topics[3] == bytes32(uint256(uint160(r.terms.newAddress))),
                "event host/topics"
            );
            require(
                keccak256(logs[i].data)
                    == keccak256(abi.encode(uint16(1), uint8(1), r.terms.reasonHash, r.recordHash)),
                "event fields"
            );
            found = true;
        }
        require(
            found && h.beforeCanary() == keccak256("before original roots")
                && h.afterCanary() == keccak256("after original roots"),
            "event and roots"
        );
        vm.expectRevert(abi.encodeWithSelector(R.InvalidRotation.selector, r.recordHash));
        h.execute(ID, r.recordHash);
    }

    function testRotationOriginalRefusalOrderAndExactRetry() public {
        (R.RotationRecord memory r, T.Identity memory p) = _rotation(2000);
        h.install(ID, r, p);
        h.occupy(p.authorityAddress, 0);
        vm.expectRevert(abi.encodeWithSelector(R.InvalidRotation.selector, bytes32(uint256(9))));
        h.execute(ID, bytes32(uint256(9)));
        vm.expectRevert(abi.encodeWithSelector(T.InvalidIdentity.selector, ID));
        h.execute(ID, r.recordHash);
        h.occupy(p.authorityAddress, ID);
        h.occupy(r.terms.newAddress, keccak256("other"));
        vm.expectRevert(abi.encodeWithSelector(R.RotationNotExecutable.selector, r.recordHash));
        h.execute(ID, r.recordHash);
        vm.warp(2000);
        vm.expectRevert(
            abi.encodeWithSelector(T.AddressAlreadyRegistered.selector, r.terms.newAddress)
        );
        h.execute(ID, r.recordHash);
        h.occupy(r.terms.newAddress, 0);
        h.execute(ID, r.recordHash);
    }

    function testRotationLateClockFailureRollsBackReplayAndCheckpoints() public {
        (R.RotationRecord memory r, T.Identity memory p) = _rotation(900);
        h.install(ID, r, p);
        (bytes32 a, bytes32 b) = _keys(r);
        bytes32 before_ =
            h.stateHash(ID, r.recordHash, r.terms.oldAddress, r.terms.newAddress, a, b);
        vm.warp(uint256(type(uint64).max) + 1);
        vm.expectRevert(abi.encodeWithSelector(T.InvalidRecord.selector));
        h.execute(ID, r.recordHash);
        require(
            h.stateHash(ID, r.recordHash, r.terms.oldAddress, r.terms.newAddress, a, b) == before_,
            "late failure leaked replay roots"
        );
        vm.warp(1000);
        h.execute(ID, r.recordHash);
    }

    function testFamilyEpisodeReturnReplacesOnlyItsArrayAndRetainsFinalResolutionGuard()
        public
        view
    {
        Family.Chain memory c;
        c.artistId = ID;
        c.current.facts.artistId = ID;
        c.episodes = new Family.Episode[](1);
        c.episodes[0].proof = keccak256("stale episode");
        c.bridge.artistId = ID;
        (Family.Chain memory result, bytes32 proof) = h.episodeResult(c);
        require(
            result.episodes.length == 0 && proof == 0 && result.bridge.artistId == ID
                && c.episodes.length == 1,
            "episode array frame"
        );
        c.current.facts.previousResolutionHash = keccak256("unmatched original resolution");
        (bool ok, bytes memory reason) = address(h).staticcall(abi.encodeCall(h.episodeResult, (c)));
        require(!ok && keccak256(reason) == keccak256(_error()), "original final resolution guard");
    }

    function testFamilyEligibilityRetainsInclusiveMaturityAndEarlyContest() public {
        Family.Chain memory c;
        c.artistId = ID;
        R.TransitionState memory t =
            R.TransitionState(ID, keccak256("transition"), 100, 200, 300, 800, 0, 2);
        vm.expectRevert(_error());
        h.eligible(c, t, 299);
        vm.expectRevert(_error());
        h.eligible(c, t, 799);
        h.eligible(c, t, 800);
        t.contestedAt = 799;
        vm.expectRevert(_error());
        h.eligible(c, t, 800);
        t.contestedAt = 800;
        h.eligible(c, t, 800);
    }

    function testNativeOccurrenceProofRetainsPositionAndRejectsDuplicateOrCollection() public {
        bytes32 record = keccak256("native cause");
        Native.Receipt[] memory rows = new Native.Receipt[](2);
        rows[0] = Native.Receipt(33, keccak256("foreign"), 0, record);
        rows[1] = Native.Receipt(33, ID, 0, record);
        Recovery.Record memory r;
        h.setReceipts(rows, r);
        require(
            h.nativeProof(ID, record, 33) == keccak256(abi.encode(uint256(1), rows[1])),
            "original global index"
        );
        rows[0] = rows[1];
        h.setReceipts(rows, r);
        vm.expectRevert(_error());
        h.nativeProof(ID, record, 33);
        rows[0] = Native.Receipt(33, keccak256("foreign"), 0, record);
        rows[1].collectionId = 1;
        h.setReceipts(rows, r);
        vm.expectRevert(_error());
        h.nativeProof(ID, record, 33);
        rows[1].collectionId = 0;
        h.setReceipts(rows, r);
        require(
            h.nativeProof(ID, record, 33) == keccak256(abi.encode(uint256(1), rows[1])),
            "restore original index"
        );
    }

    function testStagingSelectKeepsPrimaryAndSecondary35Positions() public {
        Recovery.Record memory r;
        r.fields.artistId = ID;
        r.terms.supersededRecordHashes = new bytes32[](0);
        r.fields.supersededRecordsHash = keccak256(
            abi.encode(
                bytes32(0x0c8573762967a1af597f2a7afc4b655a87b3e22d2b11fbab6cf13c6f7b1396ae),
                r.terms.supersededRecordHashes
            )
        );
        r.recordHash = keccak256(
            abi.encode(
                bytes32(0x459749364fd07c3a8f1998b82d893d33ef0942c30d94666b42dac1e37ba5feff),
                block.chainid,
                address(0xBEEF),
                r.fields
            )
        );
        Native.Receipt[] memory rows = new Native.Receipt[](2);
        rows[0] = Native.Receipt(35, ID, 0, r.recordHash);
        rows[1] = Native.Receipt(35, ID, 0, r.fields.supersededRecordsHash);
        h.setReceipts(rows, r);
        require(
            keccak256(abi.encode(h.selected(ID))) == keccak256(abi.encode(rows[0])),
            "secondary became transition"
        );
        rows[1].recordHash = keccak256("bad secondary");
        h.setReceipts(rows, r);
        vm.expectRevert(_error());
        h.selected(ID);
        rows[1].recordHash = r.fields.supersededRecordsHash;
        h.setReceipts(rows, r);
        require(h.selected(ID).recordHash == r.recordHash, "same receipt retry");
    }

    function testCurrentEstateCapabilitiesRetainOriginalMaskAndActiveIdentityGuard() public {
        h.installEstate(ID, address(0x3333), 123, true);
        E.AuthorityCapabilities memory c = h.currentCapabilities(ID);
        require(
            c.authorityAddress == address(0x3333) && c.authorityClass == 3 && c.status == 3
                && c.effectiveCapabilities == 123
                && c.activationRecordHash == keccak256(abi.encode(ID, "origin")),
            "original state slots"
        );
        h.installEstate(ID, address(0x3333), 123, false);
        vm.expectRevert(abi.encodeWithSelector(T.InvalidIdentity.selector, ID));
        h.currentCapabilities(ID);
        h.installEstate(ID, address(0x3333), 123, true);
        require(
            keccak256(abi.encode(h.currentCapabilities(ID))) == keccak256(abi.encode(c)),
            "capability exact restore"
        );
    }
}

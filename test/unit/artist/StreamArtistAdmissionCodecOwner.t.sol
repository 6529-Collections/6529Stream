// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "../../regression/legacy/helpers/CharacterizationTestBase.sol";
import { StreamArtistOwner } from "../../../smart-contracts/domains/artist/StreamArtistOwner.sol";
import { StreamArtistOnboardingTypes as T } from "../../../smart-contracts/interfaces/stream/artist/StreamArtistOnboardingTypes.sol";

/// @dev This harness calls the actual original Owner methods. It contains no replacement check,
/// accumulator or replay implementation. Coordinator/Archive are explicit unit boundaries.
contract ArtistAdmissionCodecOwnerHarness is StreamArtistOwner {
    error LateAdmissionProbeFailure();
    bytes32 public constant SURFACE = keccak256("owner admission codec regression");

    constructor() StreamArtistOwner(address(0x101), msg.sender, address(0x202),
        keccak256("owner admission codec probe"), address(0x303), address(0x404)) {}

    function advance(T.ActionContext calldata c, bytes32 scope, bytes32 record, bool failLate)
        external returns (bytes32 key)
    {
        _check(c, 7);
        key = _consume(SURFACE, scope, record);
        _commit(c, bytes32(uint256(11)), bytes32(uint256(12)), key, record);
        if (failLate) revert LateAdmissionProbeFailure();
    }
}

/// @notice Authored proposal tests; no execution or approval is implied by retaining this source.
contract StreamArtistAdmissionCodecOwnerTest is CharacterizationTestBase {
    function _context(ArtistAdmissionCodecOwnerHarness owner) private view returns (T.ActionContext memory) {
        return T.ActionContext(7, address(0x515), owner.ownerStateSnapshotV2());
    }

    function _snapshot(ArtistAdmissionCodecOwnerHarness owner) private view returns (bytes32) {
        return keccak256(abi.encode(owner.ownerStateSnapshotV2(), owner.authorityCheckpoint()));
    }

    function _key(ArtistAdmissionCodecOwnerHarness owner, bytes32 scope) private view returns (bytes32) {
        return keccak256(abi.encode(keccak256("6529STREAM_ARTIST_OWNER_REPLAY_KEY_V2"),
            block.chainid, address(0x101), address(this), address(0x202), address(owner),
            owner.domainId(), owner.SURFACE(), scope));
    }

    function testOwnerAdmissionOriginalCallerPrecedesEveryOtherField() public {
        ArtistAdmissionCodecOwnerHarness owner = new ArtistAdmissionCodecOwnerHarness();
        T.ActionContext memory c = _context(owner);
        c.actor = address(0); c.operationId = 65535;
        c.expected.domainId = 0; c.expected.revision = 19;
        c.expected.stateRoot = 0; c.expected.recordChainTip = 0;
        bytes32 before_ = _snapshot(owner);
        vm.prank(address(0xBAD));
        vm.expectRevert(abi.encodeWithSelector(T.Unauthorized.selector, address(0xBAD)));
        owner.advance(c, bytes32(uint256(1)), bytes32(uint256(2)), false);
        require(_snapshot(owner) == before_, "wrong caller no mutation");
    }

    function testOwnerAdmissionZeroActorPrecedesOperationAndSnapshot() public {
        ArtistAdmissionCodecOwnerHarness owner = new ArtistAdmissionCodecOwnerHarness();
        T.ActionContext memory c = _context(owner);
        c.actor = address(0); c.operationId = 65535; c.expected.domainId = 0;
        bytes32 before_ = _snapshot(owner);
        vm.expectRevert(abi.encodeWithSelector(T.Unauthorized.selector, address(0)));
        owner.advance(c, bytes32(uint256(1)), bytes32(uint256(2)), false);
        require(_snapshot(owner) == before_, "zero actor no mutation");
    }

    function testOwnerAdmissionOperationPrecedesSnapshot() public {
        ArtistAdmissionCodecOwnerHarness owner = new ArtistAdmissionCodecOwnerHarness();
        T.ActionContext memory c = _context(owner);
        c.operationId = 65535; c.expected.domainId = 0;
        bytes32 before_ = _snapshot(owner);
        vm.expectRevert(abi.encodeWithSelector(T.InvalidOperation.selector, uint16(65535)));
        owner.advance(c, bytes32(uint256(1)), bytes32(uint256(2)), false);
        require(_snapshot(owner) == before_, "wrong operation no mutation");
    }

    function testOwnerAdmissionEachOriginalSnapshotFieldRefusesIndependently() public {
        ArtistAdmissionCodecOwnerHarness owner = new ArtistAdmissionCodecOwnerHarness();
        T.ActionContext memory original = _context(owner);
        bytes32 before_ = _snapshot(owner);
        for (uint256 i; i < 4; ++i) {
            T.ActionContext memory wrong = abi.decode(abi.encode(original), (T.ActionContext));
            if (i == 0) wrong.expected.domainId = keccak256("foreign domain");
            if (i == 1) wrong.expected.revision += 1;
            if (i == 2) wrong.expected.stateRoot = keccak256("foreign state");
            if (i == 3) wrong.expected.recordChainTip = keccak256("foreign tip");
            vm.expectRevert(abi.encodeWithSelector(T.StaleOwnerSnapshot.selector, owner.domainId()));
            owner.advance(wrong, bytes32(uint256(1)), bytes32(uint256(2)), false);
            require(_snapshot(owner) == before_, "stale field no mutation");
        }
        require(keccak256(abi.encode(original)) == keccak256(abi.encode(_context(owner))), "independent original context");
    }

    function testOwnerAdmissionOriginalDomainReplayAndStatePreimage() public {
        ArtistAdmissionCodecOwnerHarness owner = new ArtistAdmissionCodecOwnerHarness();
        T.ActionContext memory c = _context(owner);
        bytes32 scope = keccak256("scope"); bytes32 record = keccak256("record");
        bytes32 key = _key(owner, scope);
        bytes32 expectedRoot = keccak256(abi.encode(
            keccak256("6529STREAM_ARTIST_OWNER_STATE_TRANSITION_V2"), block.chainid,
            address(0x101), address(this), address(0x202), address(owner), owner.domainId(),
            uint64(0), uint64(1), c.expected.stateRoot,
            keccak256(abi.encode(uint16(7), c.actor, bytes32(uint256(11)))),
            bytes32(uint256(12)), key, keccak256(abi.encode(record))));
        bytes32 expectedTip = keccak256(abi.encode(
            keccak256("6529STREAM_ARTIST_OWNER_RECORD_TRANSITION_V2"), block.chainid,
            address(0x101), address(this), address(0x202), address(owner), owner.domainId(),
            uint64(0), uint64(1), c.expected.recordChainTip, record));
        require(owner.advance(c, scope, record, false) == key, "exact original replay key");
        T.Snapshot memory after_ = owner.ownerStateSnapshotV2();
        require(after_.revision == 1 && after_.stateRoot == expectedRoot && after_.recordChainTip == expectedTip, "original flat-word accumulator");
        T.ReplayCell memory cell = owner.replayCell(key);
        require(cell.commitment == record && cell.touchedRevision == 1 && cell.kind == 1 && cell.status == 2, "exact original replay cell");
        T.ActionContext memory nextContext = _context(owner);
        vm.expectRevert(abi.encodeWithSelector(T.Replay.selector, key));
        owner.advance(nextContext, scope, record, false);
    }

    function testOwnerAdmissionLateFailureRestoresOriginalStateAndReplayInputs() public {
        ArtistAdmissionCodecOwnerHarness owner = new ArtistAdmissionCodecOwnerHarness();
        T.ActionContext memory c = _context(owner);
        bytes32 scope = keccak256("retry scope"); bytes32 record = keccak256("retry record");
        bytes32 before_ = _snapshot(owner); bytes32 key = _key(owner, scope);
        vm.expectRevert(abi.encodeWithSelector(ArtistAdmissionCodecOwnerHarness.LateAdmissionProbeFailure.selector));
        owner.advance(c, scope, record, true);
        require(_snapshot(owner) == before_ && owner.replayCell(key).status == 0, "whole call reverted");
        // This unit failure flag is not an Archive substitute: genuine identical Safe/Archive
        // retries are retained separately in StreamArtistAdmissionCodecSafeTest.
        require(owner.advance(c, scope, record, false) == key, "same original state and replay inputs");
    }

    function testOwnerAdmissionMalformedCanonicalTupleNeverWrites() public {
        ArtistAdmissionCodecOwnerHarness owner = new ArtistAdmissionCodecOwnerHarness();
        T.ActionContext memory c = _context(owner);
        bytes32 before_ = _snapshot(owner);
        bytes memory valid = abi.encodeCall(owner.advance, (c, bytes32(uint256(1)), bytes32(uint256(2)), false));
        for (uint256 cut; cut < valid.length; cut += 31) {
            bytes memory short_ = new bytes(cut);
            for (uint256 i; i < cut; ++i) short_[i] = valid[i];
            (bool ok,) = address(owner).call(short_);
            require(!ok && _snapshot(owner) == before_, "truncated calldata wrote");
        }
        // A uint16 operation with dirty high bits remains a compiler ABI refusal before _check.
        bytes memory dirty = abi.encodePacked(owner.advance.selector, abi.encode(
            uint256(1) << 16, c.actor, c.expected, bytes32(uint256(1)), bytes32(uint256(2)), false));
        (bool accepted,) = address(owner).call(dirty);
        require(!accepted && _snapshot(owner) == before_, "dirty uint16 accepted");
    }
}

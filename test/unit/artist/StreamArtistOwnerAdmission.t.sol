// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../../../smart-contracts/domains/artist/StreamArtistOwner.sol";
import {
    StreamArtistOnboardingTypes as T
} from "../../../smart-contracts/interfaces/stream/artist/StreamArtistOnboardingTypes.sol";

interface OwnerAdmissionVm {
    function prank(address sender) external;
}

/// @dev The actual common owner gate and accumulators; Coordinator is an explicit test boundary.
contract OwnerAdmissionProbe is StreamArtistOwner {
    constructor()
        StreamArtistOwner(
            address(0x101),
            msg.sender,
            address(0x202),
            keccak256("owner admission domain"),
            address(0x303),
            address(0x404)
        )
    { }

    function commitChecked(T.ActionContext calldata c, bytes32 scope) external {
        _check(c, 7);
        bytes32 key = _consume(keccak256("owner admission regression"), scope, scope);
        _commit(c, keccak256("admission action"), keccak256("admission state"), key, scope);
    }
}

/// @notice Error precedence and refusal atomicity of the unchanged Owner implementation.
/// @dev No proposed extraction is needed by these tests; this is not a full Safe/Archive ceremony.
contract StreamArtistOwnerAdmissionTest {
    OwnerAdmissionVm private constant vm =
        OwnerAdmissionVm(address(uint160(uint256(keccak256("hevm cheat code")))));
    OwnerAdmissionProbe private owner;

    function setUp() public {
        owner = new OwnerAdmissionProbe();
    }

    function _context() private view returns (T.ActionContext memory) {
        return T.ActionContext(7, address(0x515), owner.ownerStateSnapshotV2());
    }

    function _key(bytes32 scope) private view returns (bytes32) {
        return keccak256(
            abi.encode(
                keccak256("6529STREAM_ARTIST_OWNER_REPLAY_KEY_V2"),
                block.chainid,
                address(0x101),
                address(this),
                address(0x202),
                address(owner),
                keccak256("owner admission domain"),
                keccak256("owner admission regression"),
                scope
            )
        );
    }

    function _refused(
        address caller,
        T.ActionContext memory c,
        bytes32 scope,
        bytes memory expected
    ) private {
        bytes32 snapshotBefore = keccak256(abi.encode(owner.ownerStateSnapshotV2()));
        bytes32 checkpointBefore = keccak256(abi.encode(owner.authorityCheckpoint()));
        bytes32 key = _key(scope);
        bytes32 replayBefore = keccak256(abi.encode(owner.replayCell(key)));
        bytes memory callData = abi.encodeCall(owner.commitChecked, (c, scope));
        vm.prank(caller);
        (bool ok, bytes memory reason) = address(owner).call(callData);
        require(!ok && keccak256(reason) == keccak256(expected), "exact first error");
        require(
            keccak256(abi.encode(owner.ownerStateSnapshotV2())) == snapshotBefore, "owner unchanged"
        );
        require(
            keccak256(abi.encode(owner.authorityCheckpoint())) == checkpointBefore,
            "checkpoint unchanged"
        );
        require(keccak256(abi.encode(owner.replayCell(key))) == replayBefore, "replay unchanged");
    }

    function testOwnerAdmissionCallerPrecedesAllOtherInvalidFields() public {
        T.ActionContext memory c;
        c.operationId = 99;
        _refused(
            address(0x999),
            c,
            bytes32(uint256(1)),
            abi.encodeWithSelector(T.Unauthorized.selector, address(0x999))
        );
    }

    function testOwnerAdmissionZeroActorPrecedesOperationAndSnapshot() public {
        T.ActionContext memory c;
        c.operationId = 99;
        _refused(
            address(this),
            c,
            bytes32(uint256(1)),
            abi.encodeWithSelector(T.Unauthorized.selector, address(0))
        );
    }

    function testOwnerAdmissionOperationPrecedesStaleSnapshot() public {
        T.ActionContext memory c;
        c.actor = address(0x515);
        c.operationId = 99;
        _refused(
            address(this),
            c,
            bytes32(uint256(1)),
            abi.encodeWithSelector(T.InvalidOperation.selector, uint16(99))
        );
    }

    function _change(T.ActionContext memory c, uint256 field, bytes32 delta) private pure {
        if (field == 0) c.expected.domainId ^= delta;
        else if (field == 1) c.expected.revision ^= uint64(uint256(delta));
        else if (field == 2) c.expected.stateRoot ^= delta;
        else c.expected.recordChainTip ^= delta;
    }

    function testOwnerAdmissionEverySnapshotFieldIsRequiredAndRefusalLeavesScopeFree() public {
        bytes32 scope = bytes32(uint256(1));
        for (uint256 field; field < 4; ++field) {
            // Obtain a fresh tuple each time; no memory alias can mutate another control.
            T.ActionContext memory c = _context();
            _change(c, field, bytes32(uint256(1)));
            _refused(
                address(this),
                c,
                scope,
                abi.encodeWithSelector(
                    T.StaleOwnerSnapshot.selector, keccak256("owner admission domain")
                )
            );
        }
        owner.commitChecked(_context(), scope);
        T.ReplayCell memory cell = owner.replayCell(_key(scope));
        require(
            cell.commitment == scope && cell.touchedRevision == 1 && cell.kind == 1
                && cell.status == 2,
            "original replay cell"
        );
        require(owner.ownerStateSnapshotV2().revision == 1, "one admitted write");
    }

    function testFuzzOwnerAdmissionForeignSnapshotCannotTouchState(uint8 field, bytes32 delta)
        public
    {
        delta |= bytes32(uint256(1));
        T.ActionContext memory c = _context();
        _change(c, uint256(field) % 4, delta);
        _refused(
            address(this),
            c,
            bytes32(uint256(1)),
            abi.encodeWithSelector(
                T.StaleOwnerSnapshot.selector, keccak256("owner admission domain")
            )
        );
    }

    function _word(address value) private pure returns (bytes32) {
        return bytes32(uint256(uint160(value)));
    }

    function testOwnerAdmissionExactCommitOldSnapshotAndReplayKeepDistinctErrors() public {
        T.ActionContext memory c = _context();
        bytes32 scope = bytes32(uint256(1));
        bytes32 key = _key(scope);
        bytes32[14] memory stateWords = [
            keccak256("6529STREAM_ARTIST_OWNER_STATE_TRANSITION_V2"),
            bytes32(block.chainid),
            _word(address(0x101)),
            _word(address(this)),
            _word(address(0x202)),
            _word(address(owner)),
            c.expected.domainId,
            bytes32(uint256(0)),
            bytes32(uint256(1)),
            c.expected.stateRoot,
            keccak256(abi.encode(uint16(7), c.actor, keccak256("admission action"))),
            keccak256("admission state"),
            key,
            keccak256(abi.encode(scope))
        ];
        bytes32[11] memory tipWords = [
            keccak256("6529STREAM_ARTIST_OWNER_RECORD_TRANSITION_V2"),
            bytes32(block.chainid),
            _word(address(0x101)),
            _word(address(this)),
            _word(address(0x202)),
            _word(address(owner)),
            c.expected.domainId,
            bytes32(uint256(0)),
            bytes32(uint256(1)),
            c.expected.recordChainTip,
            scope
        ];
        owner.commitChecked(c, scope);
        T.Snapshot memory after_ = owner.ownerStateSnapshotV2();
        require(
            after_.revision == 1 && after_.stateRoot == keccak256(abi.encode(stateWords)),
            "literal state words"
        );
        require(after_.recordChainTip == keccak256(abi.encode(tipWords)), "literal record words");
        _refused(
            address(this),
            c,
            scope,
            abi.encodeWithSelector(T.StaleOwnerSnapshot.selector, c.expected.domainId)
        );
        _refused(address(this), _context(), scope, abi.encodeWithSelector(T.Replay.selector, key));
        owner.commitChecked(_context(), bytes32(uint256(2)));
        require(owner.ownerStateSnapshotV2().revision == 2, "fresh scope stays available");
    }
}

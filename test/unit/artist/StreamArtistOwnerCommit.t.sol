// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../../../smart-contracts/domains/artist/StreamArtistAcceptanceLifecycle.sol";

interface OwnerCommitVm {
    struct Log {
        bytes32[] topics;
        bytes data;
        address emitter;
    }
    function expectRevert(bytes calldata reason) external;
    function recordLogs() external;
    function getRecordedLogs() external returns (Log[] memory);
    function prank(address caller) external;
    function warp(uint256 time) external;
}

contract OwnerCommitHarness is StreamArtistOwner {
    constructor()
        StreamArtistOwner(
            address(0x101),
            msg.sender,
            address(0x202),
            keccak256("owner commit probe"),
            address(0x303),
            address(0x404)
        )
    { }

    function commit(
        T.ActionContext calldata c,
        bytes32 action,
        bytes32 state,
        bytes32 replay,
        bytes32 record
    ) external {
        _check(c, 7);
        _commit(c, action, state, replay, record);
    }
}

/// @notice Actual owner accumulators and Acceptance logs against independent flat-word oracles.
/// @dev Coordinator is the test caller; this is a compiler-regression boundary, not full artist ingress.
contract StreamArtistOwnerCommitTest {
    OwnerCommitVm private constant vm =
        OwnerCommitVm(address(uint160(uint256(keccak256("hevm cheat code")))));

    struct Delta {
        bytes32 action;
        bytes32 state;
        bytes32 replay;
        bytes32 record;
    }

    function _word(address a) private pure returns (bytes32) {
        return bytes32(uint256(uint160(a)));
    }

    function _state(StreamArtistOwner owner, T.ActionContext memory c, Delta memory d)
        private
        view
        returns (bytes32)
    {
        bytes32[14] memory w;
        w[0] = keccak256("6529STREAM_ARTIST_OWNER_STATE_TRANSITION_V2");
        w[1] = bytes32(block.chainid);
        w[2] = _word(address(0x101));
        w[3] = _word(address(this));
        w[4] = _word(address(0x202));
        w[5] = _word(address(owner));
        w[6] = c.expected.domainId;
        w[7] = bytes32(uint256(c.expected.revision));
        w[8] = bytes32(uint256(c.expected.revision) + 1);
        w[9] = c.expected.stateRoot;
        bytes32[3] memory actionWords = [bytes32(uint256(c.operationId)), _word(c.actor), d.action];
        w[10] = keccak256(abi.encode(actionWords));
        w[11] = d.state;
        w[12] = d.replay;
        w[13] = keccak256(abi.encode(d.record));
        return keccak256(abi.encode(w));
    }

    function _tip(
        StreamArtistOwner owner,
        T.Snapshot memory before_,
        uint64 sequence,
        bytes32 record
    ) private view returns (bytes32) {
        if (record == 0) return before_.recordChainTip;
        bytes32[11] memory w;
        w[0] = keccak256("6529STREAM_ARTIST_OWNER_RECORD_TRANSITION_V2");
        w[1] = bytes32(block.chainid);
        w[2] = _word(address(0x101));
        w[3] = _word(address(this));
        w[4] = _word(address(0x202));
        w[5] = _word(address(owner));
        w[6] = before_.domainId;
        w[7] = bytes32(uint256(sequence));
        w[8] = bytes32(uint256(sequence) + 1);
        w[9] = before_.recordChainTip;
        w[10] = record;
        return keccak256(abi.encode(w));
    }

    function _assert(
        StreamArtistOwner owner,
        T.ActionContext memory c,
        Delta memory d,
        uint64 sequence
    ) private view {
        T.Snapshot memory after_ = owner.ownerStateSnapshotV2();
        require(after_.revision == c.expected.revision + 1, "one revision");
        require(after_.stateRoot == _state(owner, c, d), "literal fourteen words");
        require(
            after_.recordChainTip == _tip(owner, c.expected, sequence, d.record),
            "literal record eleven words"
        );
    }

    function testOwnerCommitRecordZeroRecordAndThirdRecordExactRoots() public {
        OwnerCommitHarness owner = new OwnerCommitHarness();
        uint64 sequence;
        for (uint256 i; i < 3; ++i) {
            T.ActionContext memory c =
                T.ActionContext(7, address(0x515), owner.ownerStateSnapshotV2());
            Delta memory d = Delta(
                bytes32(i + 1), bytes32(i + 2), bytes32(i + 3), i == 1 ? bytes32(0) : bytes32(i + 4)
            );
            owner.commit(c, d.action, d.state, d.replay, d.record);
            _assert(owner, c, d, sequence);
            if (d.record != 0) ++sequence;
        }
    }

    function testOwnerCommitStaleSnapshotAndCallerRejectBeforeMutation() public {
        OwnerCommitHarness owner = new OwnerCommitHarness();
        T.ActionContext memory c = T.ActionContext(7, address(0x515), owner.ownerStateSnapshotV2());
        vm.prank(address(0x999));
        vm.expectRevert(abi.encodeWithSelector(T.Unauthorized.selector, address(0x999)));
        owner.commit(c, 0, 0, 0, 0);
        require(
            keccak256(abi.encode(owner.ownerStateSnapshotV2()))
                == keccak256(abi.encode(c.expected)),
            "rejected unchanged"
        );
        owner.commit(c, 0, 0, 0, 0);
        vm.expectRevert(abi.encodeWithSelector(T.StaleOwnerSnapshot.selector, c.expected.domainId));
        owner.commit(c, 0, 0, 0, 0);
        require(owner.ownerStateSnapshotV2().revision == 1, "stale did not commit");
    }

    function testFuzzOwnerCommitLiteralPreimage(
        bytes32 action,
        bytes32 state,
        bytes32 replay,
        bytes32 record
    ) public {
        OwnerCommitHarness owner = new OwnerCommitHarness();
        T.ActionContext memory c = T.ActionContext(7, address(0x515), owner.ownerStateSnapshotV2());
        Delta memory d = Delta(action, state, replay, record);
        owner.commit(c, action, state, replay, record);
        _assert(owner, c, d, 0);
    }

    function _record(C.BindingAcceptance memory p, uint8 class_) private view returns (bytes32) {
        bytes32[12] memory w;
        w[0] = keccak256("6529STREAM_ARTIST_ACCEPTANCE_RECORD_V1");
        w[1] = bytes32(block.chainid);
        w[2] = _word(address(0x101));
        w[3] = _word(address(0x303));
        w[4] = bytes32(p.collectionId);
        w[5] = bytes32(uint256(p.generation));
        w[6] = p.bindingHash;
        w[7] = bytes32(uint256(2));
        w[8] = _word(p.account);
        w[9] = bytes32(uint256(class_));
        w[10] = bytes32(uint256(71));
        w[11] = bytes32(uint256(1000));
        return keccak256(abi.encode(w));
    }

    function _replayKey(StreamArtistOwner owner, C.BindingAcceptance memory p)
        private
        view
        returns (bytes32)
    {
        bytes32[9] memory w;
        w[0] = keccak256("6529STREAM_ARTIST_OWNER_REPLAY_KEY_V2");
        w[1] = bytes32(block.chainid);
        w[2] = _word(address(0x101));
        w[3] = _word(address(this));
        w[4] = _word(address(0x202));
        w[5] = _word(address(owner));
        w[6] = owner.domainId();
        w[7] = keccak256("acceptance_lifecycle.replay.record_uniqueness");
        w[8] = keccak256(
            abi.encode(p.collectionId, p.generation, uint8(2), p.account, p.role, p.shareLabelId)
        );
        return keccak256(abi.encode(w));
    }

    function _event(
        OwnerCommitVm.Log memory log_,
        address owner,
        C.BindingAcceptance memory p,
        bytes32 artist,
        uint8 class_,
        bytes32 record
    ) private pure {
        require(log_.emitter == owner && log_.topics.length == 4, "exact emitter/topics");
        require(
            log_.topics[0]
                == keccak256(
                    "CollaboratorAccepted(uint16,uint256,address,bytes32,uint64,bytes32,bytes32,uint8,uint256,uint64,bytes32,bytes32)"
                ),
            "normative topic"
        );
        require(
            log_.topics[1] == bytes32(p.collectionId) && log_.topics[2] == _word(p.account)
                && log_.topics[3] == artist,
            "indexed payload"
        );
        bytes32[9] memory w;
        w[0] = bytes32(uint256(1));
        w[1] = bytes32(uint256(p.generation));
        w[2] = p.role;
        w[3] = p.shareLabelId;
        w[4] = bytes32(uint256(class_));
        w[5] = bytes32(uint256(71));
        w[6] = bytes32(uint256(1000));
        w[7] = record;
        w[8] = p.bindingHash;
        require(keccak256(log_.data) == keccak256(abi.encode(w)), "exact event bytes");
    }

    function _accept(uint8 class_) private {
        vm.warp(1000);
        StreamArtistAcceptanceLifecycle owner = new StreamArtistAcceptanceLifecycle(
            address(0x101), address(this), address(0x202), address(0x303), address(0x404)
        );
        C.BindingAcceptance memory p = C.BindingAcceptance(
            7, 3, keccak256("binding"), address(0x505), keccak256("role"), keccak256("share")
        );
        bytes32 artist = keccak256("collaborator artist");
        T.ActionContext memory c = T.ActionContext(7, address(0x515), owner.ownerStateSnapshotV2());
        bytes32 expected = _record(p, class_);
        vm.recordLogs();
        bytes32 record;
        if (class_ == 1) {
            record = owner.recordCollaboratorAcceptance(c, p, artist, 71);
        } else {
            record = owner.recordCollaboratorAcceptanceWithAuthority(
                c, p, artist, 71, R.AuthorityFact(artist, p.account, 3, 3)
            );
        }
        require(record == expected, "literal acceptance record");
        OwnerCommitVm.Log[] memory logs = vm.getRecordedLogs();
        require(logs.length == 1, "one unchanged event position");
        _event(logs[0], address(owner), p, artist, class_, record);
        bytes32 row = keccak256(abi.encode(p.bindingHash, p.account, p.role, p.shareLabelId));
        bytes32 key = _replayKey(owner, p);
        _assert(
            owner,
            c,
            Delta(
                keccak256(abi.encode(p, artist, uint256(71))),
                keccak256(abi.encode(row, artist, record)),
                keccak256(abi.encode(key, record)),
                record
            ),
            0
        );
        T.ReplayCell memory consumed = owner.replayCell(key);
        require(
            consumed.commitment == record && consumed.status == 2 && consumed.touchedRevision == 1,
            "exact consumed cell"
        );
        require(
            owner.collaboratorAcceptanceRecord(p.bindingHash, p.account, p.role, p.shareLabelId)
                == record,
            "stored row"
        );
        c.expected = owner.ownerStateSnapshotV2();
        vm.expectRevert(abi.encodeWithSelector(T.Replay.selector, key));
        owner.recordCollaboratorAcceptance(c, p, artist, 72);
        require(owner.ownerStateSnapshotV2().revision == 1, "duplicate rollback");
    }

    function testActualCollaboratorAcceptanceClass1EventAndReplay() public {
        _accept(1);
    }

    function testActualCollaboratorAcceptanceClass3EventAndReplay() public {
        _accept(3);
    }
}

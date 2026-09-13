// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamArtistGuardianSelectionPreparation
} from "../../../smart-contracts/domains/artist/StreamArtistGuardianSelectionPreparation.sol";
import {
    StreamArtistGuardianHistory as History
} from "../../../smart-contracts/domains/artist/StreamArtistGuardianHistory.sol";
import {
    StreamArtistRotationHashes
} from "../../../smart-contracts/domains/artist/StreamArtistRotationHashes.sol";
import { StreamArtistHashes } from "../../../smart-contracts/domains/artist/StreamArtistHashes.sol";
import {
    StreamArtistOnboardingTypes as T
} from "../../../smart-contracts/interfaces/stream/artist/StreamArtistOnboardingTypes.sol";
import {
    StreamArtistGuardianSelectionTypes as S
} from "../../../smart-contracts/interfaces/stream/artist/StreamArtistGuardianSelectionTypes.sol";
import {
    StreamArtistGuardianHistoryTypes as H
} from "../../../smart-contracts/interfaces/stream/artist/StreamArtistGuardianHistoryTypes.sol";
import {
    StreamArtistRotationTypes as R
} from "../../../smart-contracts/interfaces/stream/artist/StreamArtistRotationTypes.sol";
import {
    StreamArtistGuardianSupersessionTypes as Supersession
} from "../../../smart-contracts/interfaces/stream/artist/StreamArtistGuardianSupersessionTypes.sol";

interface GuardianSelectionVm {
    function warp(uint256) external;
    function expectRevert(bytes4) external;
    function expectRevert(bytes calldata) external;
}

/// @dev Actual append-only History primitive with typed owner admission/transition boundaries.
contract GuardianSelectionOwnerFixture {
    address public constant artistRegistry = address(0xA001);
    bytes32 public constant artist = keccak256("selection artist");
    bytes32 public constant original = keccak256("original rotation");
    History.State private _history;
    mapping(bytes32 => R.GuardianRecord) private _records;
    mapping(bytes32 => Supersession.Status) private _statuses;
    R.RotationRecord private _rotation;
    uint64 private _revision;

    constructor() {
        _rotation.recordHash = original;
        _rotation.terms =
            R.Rotation(artist, address(0xB001), address(0xB002), bytes32(uint256(1)), 0);
        _rotation.transition = R.TransitionState(artist, original, 10, 100, 100, 200, 0, 2);
    }

    function add(uint256 nonce, bool post, bool empty) external returns (bytes32 hash) {
        address[] memory members = new address[](empty ? 0 : 1);
        if (!empty) members[0] = address(uint160(0xC000 + nonce));
        R.GuardianSet memory terms = R.GuardianSet(artist, members, empty ? 0 : 1, 0);
        StreamArtistHashes.Environment memory e = StreamArtistHashes.Environment(
            block.chainid, artistRegistry, address(0xA002), address(0xA003)
        );
        hash = StreamArtistRotationHashes.guardianRecord(e, terms, T.Authorization(nonce, 100, ""));
        R.GuardianRecord memory record = R.GuardianRecord(
            hash,
            terms,
            post ? address(0xB002) : address(0xB001),
            1,
            nonce,
            100,
            0,
            post ? R.ProvisionalAssociation(original, 200) : R.ProvisionalAssociation(0, 0)
        );
        _records[hash] = record;
        History.append(_history, e, record, _history.heads[artist].count + 1, ++_revision);
    }

    function guardianHistoryState(bytes32 id, uint64 index, address actor, bytes32 action)
        external
        view
        returns (H.Head memory, H.Entry memory, H.Snapshot memory, uint64)
    {
        return (
            _history.heads[id],
            _history.entries[_history.records[id][index]],
            _history.snapshots[action],
            _history.firstMembership[id][actor]
        );
    }

    function guardianSetRecord(bytes32 hash) external view returns (R.GuardianRecord memory) {
        return _records[hash];
    }

    function guardianRecordSupersession(bytes32 hash)
        external
        view
        returns (Supersession.Status memory)
    {
        return _statuses[hash];
    }

    function rotationRecord(bytes32) external view returns (R.RotationRecord memory) {
        return _rotation;
    }

    function artistTransitionState(bytes32) external view returns (R.TransitionState memory) {
        return _rotation.transition;
    }

    function lastArtistTransition(bytes32) external pure returns (bytes32) {
        return original;
    }

    function latestIdentityRecovery(bytes32) external pure returns (bytes32) {
        return 0;
    }

    function contest(uint64 time) external {
        _rotation.transition.contestedAt = time;
    }

    function corrupt(bytes32 hash) external {
        _records[hash].nonce += 1;
    }

    function supersede(bytes32 hash) external {
        _statuses[hash] = Supersession.Status(artist, bytes32(uint256(11)), bytes32(uint256(12)));
    }
}

contract StreamArtistGuardianSelectionPreparationTest {
    GuardianSelectionVm private constant vm =
        GuardianSelectionVm(address(uint160(uint256(keccak256("hevm cheat code")))));
    GuardianSelectionOwnerFixture private owner;
    StreamArtistGuardianSelectionPreparation private preparation;
    bytes32 private artistId;
    bytes32 private original;
    bytes32 private lifetime;
    bytes32 private attacker;
    bytes32 private middle;

    function setUp() external {
        vm.warp(300);
        owner = new GuardianSelectionOwnerFixture();
        preparation =
            new StreamArtistGuardianSelectionPreparation(address(owner), owner.artistRegistry());
        artistId = owner.artist();
        original = owner.original();
        lifetime = owner.add(10, false, false);
        attacker = owner.add(100, true, false);
        middle = owner.add(80, true, false);
    }

    function _list(bytes32 first) private pure returns (bytes32[] memory list) {
        list = new bytes32[](1);
        list[0] = first;
    }

    function _result(bytes32[] memory list) private view returns (S.Result memory) {
        (H.Head memory head,,,) = owner.guardianHistoryState(artistId, 0, address(0), 0);
        return
            preparation.requireSelection(
                artistId, head, owner.artistTransitionState(original), list
            );
    }

    function testCompleteElectionFindsLaterUnselectedHigherThanPriorHead() external {
        bytes32[] memory list = _list(attacker);
        bytes32 key = preparation.begin(artistId, original, list);
        S.Progress memory p = preparation.continueSelection(key, 1);
        require(p.processed == 1 && p.selectedRecordHash == lifetime && !p.complete);
        H.Head memory head = _head();
        R.TransitionState memory transition = owner.artistTransitionState(original);
        vm.expectRevert(
            abi.encodeWithSelector(
                S.IncompleteGuardianSelection.selector, key, uint64(1), uint64(3)
            )
        );
        preparation.requireSelection(artistId, head, transition, list);
        p = preparation.continueSelection(key, 1);
        require(p.processed == 2 && p.selectedRecordHash == lifetime && !p.complete);
        p = preparation.continueSelection(key, 1);
        S.Result memory result = _result(list);
        require(p.complete && p.processed == 3 && result.selectedRecordHash == middle);
        require(result.selectedNonce == 80 && result.commitment != 0 && result.sourceKey == key);
        require(preparation.begin(artistId, original, list) == key);
        require(preparation.continueSelection(key, 20).complete);
    }

    function _head() private view returns (H.Head memory h) {
        (h,,,) = owner.guardianHistoryState(artistId, 0, address(0), 0);
    }

    function testElapsedWindowBasisPreventsMixedMaturityAcrossChunks() external {
        vm.warp(199);
        S.Basis memory basis = S.Basis(
            artistId,
            address(owner).codehash,
            _head(),
            owner.artistTransitionState(original),
            keccak256(abi.encode(_list(attacker)))
        );
        bytes32 expectedKey = keccak256(
            abi.encode(
                keccak256("6529STREAM_ARTIST_GUARDIAN_SELECTION_SOURCE_V1"),
                block.chainid,
                owner.artistRegistry(),
                address(owner),
                basis
            )
        );
        vm.expectRevert(abi.encodeWithSelector(S.InvalidGuardianSelection.selector, expectedKey));
        preparation.begin(artistId, original, _list(attacker));
        vm.warp(200);
        bytes32 key = preparation.begin(artistId, original, _list(attacker));
        require(key == expectedKey);
        preparation.continueSelection(key, 1);
        owner.contest(201);
        vm.expectRevert(abi.encodeWithSelector(S.InvalidGuardianSelection.selector, key));
        preparation.continueSelection(key, 10);
        bytes32 next = preparation.begin(artistId, original, _list(attacker));
        require(next != key);
        preparation.continueSelection(next, 10);
        require(_result(_list(attacker)).selectedRecordHash == middle);
    }

    function testEarlyContestedCohortStaysDiscardedAfterElapsedTime() external {
        owner.contest(199);
        bytes32 key = preparation.begin(artistId, original, _list(attacker));
        preparation.continueSelection(key, 10);
        require(_result(_list(attacker)).selectedRecordHash == lifetime);
    }

    function testCompleteHeadChangeAndRecordMismatchRollbackProgress() external {
        bytes32 key = preparation.begin(artistId, original, _list(attacker));
        preparation.continueSelection(key, 1);
        owner.add(90, true, false);
        vm.expectRevert(abi.encodeWithSelector(S.InvalidGuardianSelection.selector, key));
        preparation.continueSelection(key, 10);
        (, S.Progress memory old) = preparation.selection(key);
        require(old.processed == 1 && !old.complete);
        bytes32 next = preparation.begin(artistId, original, _list(attacker));
        owner.corrupt(middle);
        vm.expectRevert(abi.encodeWithSelector(S.InvalidGuardianSelection.selector, next));
        preparation.continueSelection(next, 10);
        (, S.Progress memory fresh) = preparation.selection(next);
        require(fresh.processed == 0 && fresh.historyTip == 0);
    }

    function testEligibleEmptyRecordDiffersFromNoEligibleRecord() external {
        bytes32 empty = owner.add(110, true, true);
        bytes32 key = preparation.begin(artistId, original, _list(attacker));
        preparation.continueSelection(key, 10);
        require(_result(_list(attacker)).selectedRecordHash == empty);
        owner.supersede(lifetime);
        owner.supersede(middle);
        owner.supersede(attacker);
        bytes32 next = preparation.begin(artistId, original, _list(empty));
        preparation.continueSelection(next, 10);
        S.Result memory result = _result(_list(empty));
        require(result.commitment != 0 && result.selectedRecordHash == 0);
        require(result.selectedDataHash == 0 && result.selectedNonce == 0);
    }

    function testUnknownOrRepeatedExclusionCannotSeal() external {
        bytes32[] memory duplicate = new bytes32[](2);
        duplicate[0] = attacker;
        duplicate[1] = attacker;
        vm.expectRevert(abi.encodeWithSelector(S.InvalidGuardianSelection.selector, attacker));
        preparation.begin(artistId, original, duplicate);
        bytes32 key = preparation.begin(artistId, original, _list(keccak256("not admitted")));
        vm.expectRevert(abi.encodeWithSelector(S.InvalidGuardianSelection.selector, key));
        preparation.continueSelection(key, 10);
        (, S.Progress memory p) = preparation.selection(key);
        require(p.processed == 0 && !p.complete);
    }
}

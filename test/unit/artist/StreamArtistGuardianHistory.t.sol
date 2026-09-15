// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    StreamArtistGuardianHistory as History
} from "../../../smart-contracts/domains/artist/StreamArtistGuardianHistory.sol";
import {
    StreamArtistGuardianHistoryTypes as H
} from "../../../smart-contracts/interfaces/stream/artist/StreamArtistGuardianHistoryTypes.sol";
import {
    StreamArtistRotationTypes as R
} from "../../../smart-contracts/interfaces/stream/artist/StreamArtistRotationTypes.sol";
import { StreamArtistHashes } from "../../../smart-contracts/domains/artist/StreamArtistHashes.sol";

interface GuardianHistoryVm {
    function expectRevert(bytes calldata reason) external;
}

/// @dev Supplied admitted records/revisions and recovery associations are explicit harness boundaries.
contract GuardianHistoryHarness {
    History.State private state;

    function append(R.GuardianRecord calldata record, uint64 count, uint64 revision, bool fail)
        external
        returns (bytes32 result)
    {
        result = History.append(
            state,
            StreamArtistHashes.Environment(
                block.chainid, address(0x1234), address(0x2345), address(0x3456)
            ),
            record,
            count,
            revision
        );
        require(!fail, "late append failure");
    }

    function freeze(bytes32 action, bytes32 association, bytes32 artist, uint64 count, bool fail)
        external
        returns (H.Snapshot memory result)
    {
        result = History.freeze(state, action, association, artist, count);
        require(!fail, "late freeze failure");
    }

    function head(bytes32 artist, uint64 count) external view returns (H.Head memory) {
        return History.requireComplete(state, artist, count);
    }

    function entry(bytes32 record) external view returns (H.Entry memory) {
        return state.entries[record];
    }

    function recordAt(bytes32 artist, uint64 index) external view returns (bytes32) {
        return state.records[artist][index];
    }

    function first(bytes32 artist, address actor) external view returns (uint64) {
        return state.firstMembership[artist][actor];
    }

    function snapshot(bytes32 action) external view returns (H.Snapshot memory) {
        return state.snapshots[action];
    }

    function member(bytes32 action, bytes32 association, bytes32 artist, address actor)
        external
        view
        returns (bool)
    {
        return History.member(state, action, association, artist, actor);
    }
}

contract StreamArtistGuardianHistoryTest {
    GuardianHistoryVm private constant vm =
        GuardianHistoryVm(address(uint160(uint256(keccak256("hevm cheat code")))));
    bytes32 private constant ARTIST = keccak256("first artist");
    bytes32 private constant ACTION = keccak256("scheduled action");
    bytes32 private constant ASSOCIATION = keccak256("owner association");
    GuardianHistoryHarness private host;

    function setUp() public {
        host = new GuardianHistoryHarness();
    }

    function _record(bytes32 artist, address member, uint256 nonce, uint64 signedAt)
        private
        view
        returns (R.GuardianRecord memory g)
    {
        g.terms.artistId = artist;
        g.terms.guardians = new address[](member == address(0) ? 0 : 1);
        if (member != address(0)) {
            g.terms.guardians[0] = member;
            g.terms.approvalThreshold = 1;
        }
        g.signer = address(0x5678);
        g.authorityClass = 1;
        g.nonce = nonce;
        g.signedAt = signedAt;
        g.recordHash = keccak256(
            abi.encode(
                bytes32(0xfb979fce9edd361cf23ba8baee900f7054451db7b563ba0ab11a5ef3621cd297),
                block.chainid,
                address(0x1234),
                artist,
                g.terms.guardians,
                g.terms.approvalThreshold,
                g.terms.minContestSeconds,
                nonce,
                signedAt
            )
        );
    }

    function testAllAdmittedSetsIncludeUnselectedAndRemovedMembers() public {
        R.GuardianRecord memory a = _record(ARTIST, address(1), 9, 30);
        R.GuardianRecord memory b = _record(ARTIST, address(2), 1, 10);
        R.GuardianRecord memory empty = _record(ARTIST, address(0), 10, 40);
        bytes32 first = host.append(a, 1, 2, false);
        bytes32 second = host.append(b, 2, 5, false);
        bytes32 third = host.append(empty, 3, 8, false);
        H.Entry memory e = host.entry(b.recordHash);
        require(
            e.index == 2 && e.ownerRevision == 5 && e.previousCommitment == first,
            "actual append order independent of author nonce/time"
        );
        require(
            e.commitment == second && e.recordDataHash == keccak256(abi.encode(b)),
            "full record facts bound"
        );
        require(
            host.recordAt(ARTIST, 1) == a.recordHash && host.recordAt(ARTIST, 2) == b.recordHash,
            "complete indexed record order"
        );
        require(third == host.head(ARTIST, 3).commitment, "complete head");
        host.freeze(ACTION, ASSOCIATION, ARTIST, 3, false);
        require(
            host.member(ACTION, ASSOCIATION, ARTIST, address(1)), "old selected member retained"
        );
        require(host.member(ACTION, ASSOCIATION, ARTIST, address(2)), "lower nonce member retained");
        require(!host.member(ACTION, ASSOCIATION, ARTIST, address(3)), "zero index not membership");
        require(!host.member(ACTION, ASSOCIATION, ARTIST, address(0)), "zero actor rejected");
    }

    function testSnapshotNeverAdoptsLaterOrOtherArtistMembers() public {
        R.GuardianRecord memory a = _record(ARTIST, address(1), 1, 1);
        host.append(a, 1, 1, false);
        H.Snapshot memory old = host.freeze(ACTION, ASSOCIATION, ARTIST, 1, false);
        host.append(_record(ARTIST, address(2), 2, 2), 2, 2, false);
        bytes32 other = keccak256("second artist");
        host.append(_record(other, address(3), 1, 1), 1, 3, false);
        require(
            keccak256(abi.encode(old)) == keccak256(abi.encode(host.snapshot(ACTION))),
            "immutable old prefix"
        );
        require(!host.member(ACTION, ASSOCIATION, ARTIST, address(2)), "future membership excluded");
        require(!host.member(ACTION, ASSOCIATION, ARTIST, address(3)), "other artist excluded");
        bytes32 next = keccak256("new scheduled action");
        host.freeze(next, ASSOCIATION, ARTIST, 2, false);
        require(
            host.member(next, ASSOCIATION, ARTIST, address(2)),
            "new complete prefix admits later member"
        );
        vm.expectRevert(abi.encodeWithSelector(H.InvalidGuardianHistorySnapshot.selector, ACTION));
        host.member(ACTION, keccak256("wrong association"), ARTIST, address(1));
        vm.expectRevert(abi.encodeWithSelector(H.InvalidGuardianHistorySnapshot.selector, ACTION));
        host.freeze(ACTION, ASSOCIATION, ARTIST, 2, false);
    }

    function testAdmissionRejectsGapsReplayWrongHashAndRevision() public {
        R.GuardianRecord memory a = _record(ARTIST, address(1), 1, 1);
        vm.expectRevert(abi.encodeWithSelector(H.InvalidGuardianHistory.selector, ARTIST));
        host.append(a, 2, 1, false);
        host.append(a, 1, 5, false);
        vm.expectRevert(abi.encodeWithSelector(H.InvalidGuardianHistory.selector, ARTIST));
        host.append(a, 2, 6, false);
        R.GuardianRecord memory b = _record(ARTIST, address(2), 2, 2);
        vm.expectRevert(abi.encodeWithSelector(H.InvalidGuardianHistory.selector, ARTIST));
        host.append(b, 2, 5, false);
        b.terms.guardians[0] = address(3);
        vm.expectRevert(abi.encodeWithSelector(H.InvalidGuardianHistory.selector, ARTIST));
        host.append(b, 2, 6, false);
        require(
            host.head(ARTIST, 1).count == 1 && host.first(ARTIST, address(2)) == 0,
            "all failures preserve head and index"
        );
        b = _record(ARTIST, address(2), 2, 2);
        host.append(b, 2, 6, false);
        require(host.head(ARTIST, 2).count == 2, "healthy same admission succeeds");
    }

    function testEmptySetIsHistoryAndIncompleteCountsCannotFreeze() public {
        require(host.head(ARTIST, 0).commitment == 0, "initial absence");
        host.append(_record(ARTIST, address(0), 1, 1), 1, 1, false);
        vm.expectRevert(abi.encodeWithSelector(H.InvalidGuardianHistory.selector, ARTIST));
        host.head(ARTIST, 0);
        vm.expectRevert(abi.encodeWithSelector(H.InvalidGuardianHistory.selector, ARTIST));
        host.freeze(ACTION, ASSOCIATION, ARTIST, 2, false);
        H.Snapshot memory frozen = host.freeze(ACTION, ASSOCIATION, ARTIST, 1, false);
        require(
            frozen.count == 1 && frozen.historyCommitment != 0,
            "empty admitted record is not absence"
        );
        require(
            !host.member(ACTION, ASSOCIATION, ARTIST, address(1)),
            "empty set grants nobody standing"
        );
    }

    function testLateFailureRollsBackEveryAppendAndSnapshotWrite() public {
        R.GuardianRecord memory a = _record(ARTIST, address(1), 1, 1);
        vm.expectRevert(abi.encodeWithSignature("Error(string)", "late append failure"));
        host.append(a, 1, 1, true);
        require(
            host.head(ARTIST, 0).count == 0 && host.recordAt(ARTIST, 1) == 0,
            "no partial head/index"
        );
        require(
            host.entry(a.recordHash).recordHash == 0 && host.first(ARTIST, address(1)) == 0,
            "no partial record/member"
        );
        host.append(a, 1, 1, false);
        vm.expectRevert(abi.encodeWithSignature("Error(string)", "late freeze failure"));
        host.freeze(ACTION, ASSOCIATION, ARTIST, 1, true);
        require(host.snapshot(ACTION).associationHash == 0, "no partial snapshot");
        host.freeze(ACTION, ASSOCIATION, ARTIST, 1, false);
        require(host.member(ACTION, ASSOCIATION, ARTIST, address(1)), "identical facts retry");
    }

    function testFuzzEarliestMembershipAndExactRoot(uint8 later) public {
        uint64 count = uint64(later % 8) + 2;
        bytes32 prior;
        for (uint64 i = 1; i <= count; ++i) {
            R.GuardianRecord memory g = _record(
                ARTIST, i == 1 || i % 2 == 0 ? address(1) : address(2), uint256(count - i), i
            );
            bytes32 expected = keccak256(
                abi.encode(
                    keccak256("6529STREAM_ARTIST_GUARDIAN_ADMISSION_HISTORY_V1"),
                    block.chainid,
                    address(0x1234),
                    address(host),
                    ARTIST,
                    i,
                    uint64(i + 10),
                    g.recordHash,
                    keccak256(abi.encode(g)),
                    prior
                )
            );
            prior = host.append(g, i, i + 10, false);
            require(
                prior == expected && host.first(ARTIST, address(1)) == 1,
                "root/order/first occurrence"
            );
        }
        require(host.head(ARTIST, count).commitment == prior, "exact final tip");
    }
}

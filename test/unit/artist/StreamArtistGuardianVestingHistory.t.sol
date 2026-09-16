// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamArtistGuardianHistory as History
} from "../../../smart-contracts/domains/artist/StreamArtistGuardianHistory.sol";
import {
    StreamArtistGuardianVestingHistory as Vesting
} from "../../../smart-contracts/domains/artist/StreamArtistGuardianVestingHistory.sol";
import {
    StreamArtistGuardianHistoryTypes as H
} from "../../../smart-contracts/interfaces/stream/artist/StreamArtistGuardianHistoryTypes.sol";
import {
    StreamArtistGuardianVestingTypes as V
} from "../../../smart-contracts/interfaces/stream/artist/StreamArtistGuardianVestingTypes.sol";
import {
    StreamArtistRotationTypes as R
} from "../../../smart-contracts/interfaces/stream/artist/StreamArtistRotationTypes.sol";
import { StreamArtistHashes } from "../../../smart-contracts/domains/artist/StreamArtistHashes.sol";

interface VestingVm {
    function warp(uint256 time) external;
    function expectRevert(bytes calldata reason) external;
}

/// @dev Original guardian/transition admission and successful owner revisions are harness inputs.
contract GuardianVestingHarness {
    History.State private history;
    Vesting.State private vesting;

    function environment() private view returns (StreamArtistHashes.Environment memory) {
        return StreamArtistHashes.Environment(
            block.chainid, address(0x1234), address(0x2345), address(0x3456)
        );
    }

    function append(R.GuardianRecord memory g, uint64 count, uint64 revision) external {
        History.append(history, environment(), g, count, revision);
    }

    function record(V.Snapshot memory item, uint64 count, bool fail) external returns (bytes32) {
        bytes32 result = Vesting.record(vesting, history, environment(), item, count);
        require(!fail, "late vesting failure");
        return result;
    }

    function get(bytes32 artist, bytes32 transition) external view returns (V.Snapshot memory) {
        return abi.decode(Vesting.encoded(vesting, artist, transition), (V.Snapshot));
    }

    function latest(bytes32 artist) external view returns (bytes32) {
        return vesting.latest[artist];
    }
}

contract StreamArtistGuardianVestingHistoryTest {
    VestingVm private constant vm =
        VestingVm(address(uint160(uint256(keccak256("hevm cheat code")))));
    bytes32 private constant ARTIST = keccak256("vesting artist");
    bytes32 private constant FIRST = keccak256("first actual transition");
    bytes32 private constant SECOND = keccak256("second actual transition");
    GuardianVestingHarness private host;

    function setUp() public {
        vm.warp(1000);
        host = new GuardianVestingHarness();
    }

    function _record(uint256 nonce, uint64 signedAt, address member)
        private
        view
        returns (R.GuardianRecord memory g)
    {
        g.terms.artistId = ARTIST;
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
                ARTIST,
                g.terms.guardians,
                g.terms.approvalThreshold,
                g.terms.minContestSeconds,
                nonce,
                signedAt
            )
        );
    }

    function _item(bytes32 transition, bytes32 prior, uint64 revision, uint16 op)
        private
        view
        returns (V.Snapshot memory v)
    {
        v.artistId = ARTIST;
        v.transitionRecordHash = transition;
        v.previousTransitionRecordHash = prior;
        v.ownerRevision = revision;
        v.operationId = op;
        v.executedAt = uint64(block.timestamp);
        v.oldAddress = address(1);
        v.newAddress = address(2);
        v.authorityClass = op == 40 ? 3 : 1;
    }

    function testEmptyPrefixHasPermanentNonzeroSnapshot() public {
        V.Snapshot memory v = _item(FIRST, 0, 2, 32);
        bytes32 hash = host.record(v, 0, false);
        v = host.get(ARTIST, FIRST);
        require(
            hash != 0 && v.commitment == hash && v.guardians.count == 0
                && v.guardians.ownerRevision == 0 && v.guardians.commitment == 0,
            "explicit empty prefix"
        );
        require(v.ownerRevision == 2 && host.latest(ARTIST) == FIRST, "successful owner revision");
        vm.expectRevert(abi.encodeWithSelector(V.InvalidGuardianVesting.selector, SECOND));
        host.get(ARTIST, SECOND);
        vm.expectRevert(abi.encodeWithSelector(V.InvalidGuardianVesting.selector, FIRST));
        host.get(keccak256("other artist"), FIRST);
    }

    function testSameTimestampOrderingUsesCompleteAdmissionPrefix() public {
        host.append(_record(9, 900, address(3)), 1, 3);
        host.append(_record(1, 100, address(4)), 2, 5);
        V.Snapshot memory v = _item(FIRST, 0, 7, 32);
        v.guardians = H.Head(99, 99, keccak256("untrusted head"));
        host.record(v, 2, false);
        V.Snapshot memory before_ = host.get(ARTIST, FIRST);
        require(
            before_.executedAt == block.timestamp && before_.guardians.count == 2
                && before_.guardians.ownerRevision == 5 && before_.ownerRevision == 7,
            "derived complete prefix"
        );
        host.append(_record(10, 100, address(0)), 3, 8);
        require(
            keccak256(abi.encode(before_)) == keccak256(abi.encode(host.get(ARTIST, FIRST))),
            "later same-time admission cannot rewrite prefix"
        );
        host.record(_item(SECOND, FIRST, 9, 35), 3, false);
        V.Snapshot memory after_ = host.get(ARTIST, SECOND);
        require(
            after_.executedAt == before_.executedAt && after_.guardians.count == 3
                && after_.previousCommitment == before_.commitment,
            "same-time linked transitions retain exact revisions"
        );
    }

    function testMissingPriorCannotBeBackfilledAndReplayCannotReplace() public {
        vm.expectRevert(
            abi.encodeWithSelector(V.IncompleteGuardianVestingHistory.selector, ARTIST, FIRST)
        );
        host.record(_item(SECOND, FIRST, 5, 35), 0, false);
        host.record(_item(FIRST, 0, 3, 32), 0, false);
        vm.expectRevert(abi.encodeWithSelector(V.InvalidGuardianVesting.selector, FIRST));
        host.record(_item(FIRST, 0, 4, 32), 0, false);
        vm.expectRevert(
            abi.encodeWithSelector(V.IncompleteGuardianVestingHistory.selector, ARTIST, bytes32(0))
        );
        host.record(_item(SECOND, 0, 5, 35), 0, false);
        vm.expectRevert(
            abi.encodeWithSelector(V.IncompleteGuardianVestingHistory.selector, ARTIST, FIRST)
        );
        host.record(_item(SECOND, FIRST, 3, 35), 0, false);
        host.record(_item(SECOND, FIRST, 4, 35), 0, false);
    }

    function testCountRevisionAndOperationCannotInventVesting() public {
        host.append(_record(1, 1, address(3)), 1, 5);
        vm.expectRevert(abi.encodeWithSelector(H.InvalidGuardianHistory.selector, ARTIST));
        host.record(_item(FIRST, 0, 6, 32), 0, false);
        vm.expectRevert(abi.encodeWithSelector(V.InvalidGuardianVesting.selector, FIRST));
        host.record(_item(FIRST, 0, 5, 32), 1, false);
        vm.expectRevert(abi.encodeWithSelector(V.InvalidGuardianVesting.selector, FIRST));
        host.record(_item(FIRST, 0, 6, 30), 1, false);
        V.Snapshot memory v = _item(FIRST, 0, 6, 40);
        v.authorityClass = 1;
        vm.expectRevert(abi.encodeWithSelector(V.InvalidGuardianVesting.selector, FIRST));
        host.record(v, 1, false);
        host.record(_item(FIRST, 0, 6, 40), 1, false);
        require(
            host.get(ARTIST, FIRST).authorityClass == 3,
            "estate snapshot after authenticating class"
        );
    }

    function testLateFailureRollsBackSnapshotAndLatestForIdenticalRetry() public {
        V.Snapshot memory first = _item(FIRST, 0, 2, 32);
        vm.expectRevert(abi.encodeWithSignature("Error(string)", "late vesting failure"));
        host.record(first, 0, true);
        require(host.latest(ARTIST) == 0, "no partial latest");
        vm.expectRevert(abi.encodeWithSelector(V.InvalidGuardianVesting.selector, FIRST));
        host.get(ARTIST, FIRST);
        bytes32 original = host.record(first, 0, false);
        V.Snapshot memory second = _item(SECOND, FIRST, 3, 35);
        vm.expectRevert(abi.encodeWithSignature("Error(string)", "late vesting failure"));
        host.record(second, 0, true);
        require(
            host.latest(ARTIST) == FIRST && host.get(ARTIST, FIRST).commitment == original,
            "prior history exact"
        );
        host.record(second, 0, false);
        require(host.get(ARTIST, SECOND).previousCommitment == original, "identical retry");
    }

    function testFuzzExactSeventeenWordCommitment(uint16 salt) public {
        V.Snapshot memory v = _item(FIRST, 0, uint64(salt) + 1, 32);
        bytes32[17] memory words;
        words[0] = keccak256("6529STREAM_ARTIST_GUARDIAN_VESTING_V1");
        words[1] = bytes32(block.chainid);
        words[2] = bytes32(uint256(0x1234));
        words[3] = bytes32(uint256(uint160(address(host))));
        words[4] = v.artistId;
        words[5] = v.transitionRecordHash;
        words[6] = bytes32(uint256(v.operationId));
        words[7] = bytes32(uint256(v.ownerRevision));
        words[8] = bytes32(uint256(v.executedAt));
        words[9] = bytes32(uint256(uint160(v.oldAddress)));
        words[10] = bytes32(uint256(uint160(v.newAddress)));
        words[11] = bytes32(uint256(v.authorityClass));
        bytes memory expected = abi.encode(words);
        require(expected.length == 544, "17 exact static words");
        require(host.record(v, 0, false) == keccak256(expected), "independent flat preimage");
        require(abi.encode(host.get(ARTIST, FIRST)).length == 448, "14 exact static return words");
    }
}

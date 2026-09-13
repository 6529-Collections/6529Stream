// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { StreamArtistOwner } from "../../../smart-contracts/domains/artist/StreamArtistOwner.sol";
import {
    StreamArtistIdentityRecoveryReceipts as P
} from "../../../smart-contracts/domains/artist/StreamArtistIdentityRecoveryReceipts.sol";
import {
    StreamArtistIdentityRecoveryHashes as H
} from "../../../smart-contracts/domains/artist/StreamArtistIdentityRecoveryHashes.sol";
import {
    StreamArtistIdentityRecoveryTypes as R
} from "../../../smart-contracts/interfaces/stream/artist/StreamArtistIdentityRecoveryTypes.sol";
import {
    StreamArtistOnboardingTypes as T
} from "../../../smart-contracts/interfaces/stream/artist/StreamArtistOnboardingTypes.sol";

contract IdentityRecoveryReceiptHarness is StreamArtistOwner {
    P.State private receipts;
    event FixturePair(bytes32 primary, bytes32 secondary);
    error LateFixtureFailure();

    constructor(address coordinator, bytes32 domain)
        StreamArtistOwner(
            address(0x11), coordinator, address(0x33), domain, address(0x44), address(0x55)
        )
    { }

    // This fixture authenticates only the real owner caller/snapshot and fixture replay lanes.
    // It does not supply operation35 arbiter, guardian, signature or supersession authority.
    function commit(
        T.ActionContext calldata c,
        R.RecordFields calldata fields,
        bytes32[] calldata list,
        uint256 nonce,
        bool fail
    ) external returns (P.Pair memory pair) {
        _check(c, 35);
        bytes32 actionKey =
            _consume(keccak256("fixture.action"), fields.governanceActionId, fields.artistId);
        bytes32 nonceKey = _consume(
            keccak256("fixture.nonce"),
            keccak256(abi.encode(fields.artistId, nonce)),
            fields.governanceActionId
        );
        pair = _commitIdentityRecovery(
            receipts,
            c,
            fields.governanceActionId,
            bytes32(uint256(0x91)),
            keccak256(abi.encode(actionKey, nonceKey)),
            fields,
            list
        );
        emit FixturePair(pair.primaryHash, pair.secondaryHash);
        if (fail) revert LateFixtureFailure();
    }

    function appendOnly(
        T.ActionContext calldata c,
        R.RecordFields calldata fields,
        bytes32[] calldata list
    ) external returns (P.Pair memory) {
        return _commitIdentityRecovery(
            receipts, c, fields.governanceActionId, bytes32(uint256(0x91)), bytes32(0), fields, list
        );
    }

    function legacy(T.ActionContext calldata c, bytes32 record) external {
        _check(c, 35);
        _commit(c, bytes32(uint256(0x81)), bytes32(uint256(0x91)), bytes32(0), record);
    }

    function sequence() external view returns (uint64) {
        return _recordSequence;
    }

    function primary(bytes32 hash) external view returns (bytes32) {
        return receipts.receipts[P.PRIMARY][hash];
    }

    function secondary(bytes32 key) external view returns (bytes32) {
        return receipts.secondaryOccurrences[key];
    }

    function ordinarySecondary(bytes32 hash) external view returns (bytes32) {
        return receipts.receipts[P.SECONDARY][hash];
    }

    function replayKey(bytes32 surface, bytes32 scope) external view returns (bytes32) {
        return _replayKey(surface, scope);
    }

    function seedSecondary(bytes32 key, bytes32 commitment) external {
        receipts.secondaryOccurrences[key] = commitment;
    }

    function seedCursor(uint64 revision, uint64 seq) external {
        _revision = revision;
        _recordSequence = seq;
    }
}

contract StreamArtistIdentityRecoveryReceiptsTest {
    bytes32 private constant DOMAIN =
        0x6579e41542b1bfc6684ea87b09373c4f4690857bd046eb4faf0f92a42bc88adb;
    bytes32 private constant PRIMARY =
        0x459749364fd07c3a8f1998b82d893d33ef0942c30d94666b42dac1e37ba5feff;
    bytes32 private constant SECONDARY =
        0x0c8573762967a1af597f2a7afc4b655a87b3e22d2b11fbab6cf13c6f7b1396ae;

    function _host() private returns (IdentityRecoveryReceiptHarness) {
        return new IdentityRecoveryReceiptHarness(address(this), DOMAIN);
    }

    function _context(IdentityRecoveryReceiptHarness h)
        private
        view
        returns (T.ActionContext memory)
    {
        return T.ActionContext(35, address(0x77), h.ownerStateSnapshotV2());
    }

    function _fields(uint256 artist, uint256 action, bytes32[] memory list)
        private
        pure
        returns (R.RecordFields memory)
    {
        return R.RecordFields(
            bytes32(artist),
            address(0x22),
            address(0x44),
            1,
            bytes32(uint256(0x55)),
            bytes32(uint256(0x66)),
            H.supersession(list),
            bytes32(action),
            0x01020304
        );
    }

    function _snapshot(IdentityRecoveryReceiptHarness h) private view returns (bytes32) {
        return keccak256(abi.encode(h.ownerStateSnapshotV2(), h.sequence()));
    }

    function _reject(address h, bytes memory data, bytes memory expected) private {
        (bool ok, bytes memory result) = h.call(data);
        require(!ok && keccak256(result) == keccak256(expected), "exact failure");
    }

    function _addr(address a) private pure returns (bytes32) {
        return bytes32(uint256(uint160(a)));
    }

    function _receipt(
        IdentityRecoveryReceiptHarness h,
        uint64 revision,
        uint64 seq,
        bytes32 domain,
        bytes32 semantic
    ) private view returns (bytes32) {
        bytes32[13] memory w;
        w[0] = keccak256("6529STREAM_ARTIST_OWNER_RECORD_COMMITMENT_V2");
        w[1] = bytes32(uint256(2));
        w[2] = bytes32(h.deploymentChainId());
        w[3] = _addr(address(0x11));
        w[4] = _addr(address(this));
        w[5] = _addr(address(0x33));
        w[6] = _addr(address(h));
        w[7] = DOMAIN;
        w[8] = bytes32(uint256(revision));
        w[9] = bytes32(uint256(seq));
        w[10] = _addr(address(0x77));
        w[11] = domain;
        w[12] = semantic;
        return keccak256(abi.encode(w));
    }

    function _chain(IdentityRecoveryReceiptHarness h, uint64 seq, bytes32 tip, bytes32 commitment)
        private
        view
        returns (bytes32)
    {
        bytes32[11] memory w;
        w[0] = keccak256("6529STREAM_ARTIST_OWNER_RECORD_TRANSITION_V2");
        w[1] = bytes32(h.deploymentChainId());
        w[2] = _addr(address(0x11));
        w[3] = _addr(address(this));
        w[4] = _addr(address(0x33));
        w[5] = _addr(address(h));
        w[6] = DOMAIN;
        w[7] = bytes32(uint256(seq));
        w[8] = bytes32(uint256(seq) + 1);
        w[9] = tip;
        w[10] = commitment;
        return keccak256(abi.encode(w));
    }

    function _delta(
        IdentityRecoveryReceiptHarness h,
        T.Snapshot memory before,
        uint64 seq,
        P.Pair memory p
    ) private view returns (bytes32) {
        bytes32[20] memory w;
        w[0] = keccak256("6529STREAM_ARTIST_OWNER_RECORD_DELTA_V2");
        w[1] = bytes32(uint256(2));
        w[2] = bytes32(h.deploymentChainId());
        w[3] = _addr(address(0x11));
        w[4] = _addr(address(this));
        w[5] = _addr(address(0x33));
        w[6] = _addr(address(h));
        w[7] = DOMAIN;
        w[8] = bytes32(uint256(before.revision) + 1);
        w[9] = bytes32(uint256(seq));
        w[10] = bytes32(uint256(seq) + 2);
        w[11] = before.recordChainTip;
        w[12] = bytes32(uint256(2));
        w[13] = PRIMARY;
        w[14] = p.primaryHash;
        w[15] = p.primaryCommitment;
        w[16] = SECONDARY;
        w[17] = p.secondaryHash;
        w[18] = p.secondaryCommitment;
        w[19] = p.nextTip;
        return keccak256(abi.encode(w));
    }

    function _state(
        IdentityRecoveryReceiptHarness h,
        T.Snapshot memory before,
        bytes32 action,
        bytes32 delta
    ) private view returns (bytes32) {
        bytes32[14] memory w;
        w[0] = keccak256("6529STREAM_ARTIST_OWNER_STATE_TRANSITION_V2");
        w[1] = bytes32(h.deploymentChainId());
        w[2] = _addr(address(0x11));
        w[3] = _addr(address(this));
        w[4] = _addr(address(0x33));
        w[5] = _addr(address(h));
        w[6] = DOMAIN;
        w[7] = bytes32(uint256(before.revision));
        w[8] = bytes32(uint256(before.revision) + 1);
        w[9] = before.stateRoot;
        w[10] = keccak256(abi.encode(uint16(35), address(0x77), action));
        w[11] = bytes32(uint256(0x91));
        w[12] = bytes32(0);
        w[13] = delta;
        return keccak256(abi.encode(w));
    }

    function testPairFlatOraclesAndLegacyPrefix() public {
        IdentityRecoveryReceiptHarness h = _host();
        T.Snapshot memory genesis = h.ownerStateSnapshotV2();
        h.legacy(_context(h), bytes32(uint256(0xab)));
        T.Snapshot memory before = h.ownerStateSnapshotV2();
        require(before.revision == 1 && h.sequence() == 1);
        require(
            before.recordChainTip == _chain(h, 0, genesis.recordChainTip, bytes32(uint256(0xab))),
            "legacy raw semantic chain"
        );
        require(
            before.stateRoot
                == _state(
                    h,
                    genesis,
                    bytes32(uint256(0x81)),
                    keccak256(abi.encode(bytes32(uint256(0xab))))
                )
        );
        bytes32[] memory list = new bytes32[](0);
        R.RecordFields memory f = _fields(1, 7, list);
        P.Pair memory p = h.appendOnly(_context(h), f, list);
        require(p.primaryHash == H.record(h.deploymentChainId(), address(0x11), f));
        require(
            p.secondaryHash == 0x273a8a33fd441297e67ff984921de6f3c18a253af20f4d18fbf9ba110a0d15f3
        );
        require(p.primaryCommitment == _receipt(h, 2, 2, PRIMARY, p.primaryHash));
        require(p.secondaryCommitment == _receipt(h, 2, 3, SECONDARY, p.secondaryHash));
        bytes32 firstTip = _chain(h, 1, before.recordChainTip, p.primaryCommitment);
        require(p.nextTip == _chain(h, 2, firstTip, p.secondaryCommitment));
        require(p.recordDelta == _delta(h, before, 1, p));
        T.Snapshot memory afterState = h.ownerStateSnapshotV2();
        require(afterState.revision == 2 && h.sequence() == 3 && p.nextSequence == 3);
        require(
            afterState.recordChainTip == p.nextTip
                && afterState.stateRoot == _state(h, before, f.governanceActionId, p.recordDelta)
        );
        require(
            h.primary(p.primaryHash) == p.primaryCommitment
                && h.secondary(p.occurrenceKey) == p.secondaryCommitment
        );
        require(h.ordinarySecondary(p.secondaryHash) == bytes32(0));
    }

    function testDistinctArtistsReuseEmptyListWithImmutableOccurrences() public {
        IdentityRecoveryReceiptHarness h = _host();
        bytes32[] memory list = new bytes32[](0);
        P.Pair memory a = h.appendOnly(_context(h), _fields(1, 7, list), list);
        P.Pair memory b = h.appendOnly(_context(h), _fields(2, 8, list), list);
        require(a.secondaryHash == b.secondaryHash && a.primaryHash != b.primaryHash);
        require(
            a.occurrenceKey != b.occurrenceKey && a.secondaryCommitment != b.secondaryCommitment
        );
        require(
            h.primary(a.primaryHash) == a.primaryCommitment
                && h.secondary(a.occurrenceKey) == a.secondaryCommitment
        );
        require(h.secondary(b.occurrenceKey) == b.secondaryCommitment && h.sequence() == 4);
    }

    function testFuzzDistinctPrimariesReuseNonemptyList(uint128 first, uint128 gap) public {
        IdentityRecoveryReceiptHarness h = _host();
        bytes32[] memory list = new bytes32[](2);
        list[0] = bytes32(uint256(first) + 1);
        list[1] = bytes32(uint256(first) + uint256(gap) + 2);
        P.Pair memory a = h.appendOnly(_context(h), _fields(1, 7, list), list);
        P.Pair memory b = h.appendOnly(_context(h), _fields(1, 8, list), list);
        require(
            a.secondaryHash == b.secondaryHash && a.primaryHash != b.primaryHash
                && a.occurrenceKey != b.occurrenceKey
        );
        require(
            h.secondary(a.occurrenceKey) == a.secondaryCommitment
                && h.secondary(b.occurrenceKey) == b.secondaryCommitment
        );
    }

    function testMismatchedPrimaryListRollsReplayAndCursorBack() public {
        IdentityRecoveryReceiptHarness h = _host();
        bytes32[] memory list = new bytes32[](0);
        R.RecordFields memory f = _fields(1, 7, list);
        f.supersededRecordsHash = bytes32(uint256(1));
        bytes32 before = _snapshot(h);
        _reject(
            address(h),
            abi.encodeCall(h.commit, (_context(h), f, list, 1, false)),
            abi.encodeWithSelector(P.InvalidRecoveryReceipt.selector)
        );
        require(
            _snapshot(h) == before
                && h.primary(H.record(h.deploymentChainId(), address(0x11), f)) == bytes32(0)
        );
        require(
            h.replayCell(h.replayKey(keccak256("fixture.action"), f.governanceActionId)).status == 0
        );
        f.supersededRecordsHash = H.supersession(list);
        h.commit(_context(h), f, list, 1, false);
    }

    function testPrimaryActionAndNonceReplayRejectIndependently() public {
        IdentityRecoveryReceiptHarness h = _host();
        bytes32[] memory list = new bytes32[](0);
        R.RecordFields memory f = _fields(1, 7, list);
        P.Pair memory p = h.commit(_context(h), f, list, 1, false);
        bytes32 before = _snapshot(h);
        _reject(
            address(h),
            abi.encodeCall(h.appendOnly, (_context(h), f, list)),
            abi.encodeWithSelector(P.DuplicateRecoveryReceipt.selector, p.primaryHash)
        );
        bytes32 key = h.replayKey(keccak256("fixture.action"), f.governanceActionId);
        _reject(
            address(h),
            abi.encodeCall(h.commit, (_context(h), f, list, 2, false)),
            abi.encodeWithSelector(T.Replay.selector, key)
        );
        f.governanceActionId = bytes32(uint256(8));
        key = h.replayKey(keccak256("fixture.nonce"), keccak256(abi.encode(f.artistId, uint256(1))));
        _reject(
            address(h),
            abi.encodeCall(h.commit, (_context(h), f, list, 1, false)),
            abi.encodeWithSelector(T.Replay.selector, key)
        );
        require(_snapshot(h) == before);
        require(
            h.replayCell(h.replayKey(keccak256("fixture.action"), f.governanceActionId)).status == 0
        );
        h.commit(_context(h), f, list, 2, false);
    }

    function testSecondAppendConflictRollsFirstReceiptAndReplayBack() public {
        IdentityRecoveryReceiptHarness h = _host();
        bytes32[] memory list = new bytes32[](0);
        R.RecordFields memory f = _fields(1, 7, list);
        bytes32 primary = H.record(h.deploymentChainId(), address(0x11), f);
        bytes32 key = P.occurrenceKey(primary, f.supersededRecordsHash);
        // Deliberately inconsistent prepared storage reaches the actual second insertion guard.
        h.seedSecondary(key, bytes32(uint256(0xdead)));
        bytes32 before = _snapshot(h);
        _reject(
            address(h),
            abi.encodeCall(h.commit, (_context(h), f, list, 1, false)),
            abi.encodeWithSelector(P.DuplicateRecoveryReceipt.selector, key)
        );
        require(
            h.primary(primary) == bytes32(0) && h.secondary(key) == bytes32(uint256(0xdead))
                && _snapshot(h) == before
        );
        require(
            h.replayCell(h.replayKey(keccak256("fixture.action"), f.governanceActionId)).status == 0
        );
        h.seedSecondary(key, bytes32(0));
        h.commit(_context(h), f, list, 1, false);
    }

    function testLateFailureRollsCompletedPairBackThenSameProofRetries() public {
        IdentityRecoveryReceiptHarness h = _host();
        bytes32[] memory list = new bytes32[](0);
        R.RecordFields memory f = _fields(1, 7, list);
        bytes32 primary = H.record(h.deploymentChainId(), address(0x11), f);
        bytes32 key = P.occurrenceKey(primary, f.supersededRecordsHash);
        bytes32 before = _snapshot(h);
        _reject(
            address(h),
            abi.encodeCall(h.commit, (_context(h), f, list, 1, true)),
            abi.encodeWithSelector(IdentityRecoveryReceiptHarness.LateFixtureFailure.selector)
        );
        require(
            _snapshot(h) == before && h.primary(primary) == bytes32(0)
                && h.secondary(key) == bytes32(0)
        );
        require(
            h.replayCell(h.replayKey(keccak256("fixture.action"), f.governanceActionId)).status == 0
        );
        h.commit(_context(h), f, list, 1, false);
    }

    function testOverflowAndWrongOperationDoNotAdvanceHistory() public {
        IdentityRecoveryReceiptHarness h = _host();
        bytes32[] memory list = new bytes32[](0);
        R.RecordFields memory f = _fields(1, 7, list);
        h.seedCursor(7, type(uint64).max - 1);
        bytes32 before = _snapshot(h);
        _reject(
            address(h),
            abi.encodeCall(h.appendOnly, (_context(h), f, list)),
            abi.encodeWithSignature("Panic(uint256)", uint256(0x11))
        );
        require(_snapshot(h) == before);
        h.seedCursor(type(uint64).max, 0);
        before = _snapshot(h);
        _reject(
            address(h),
            abi.encodeCall(h.appendOnly, (_context(h), f, list)),
            abi.encodeWithSignature("Panic(uint256)", uint256(0x11))
        );
        require(_snapshot(h) == before);
        h.seedCursor(0, 0);
        T.ActionContext memory c = _context(h);
        c.operationId = 34;
        _reject(
            address(h),
            abi.encodeCall(h.appendOnly, (c, f, list)),
            abi.encodeWithSelector(T.InvalidOperation.selector, uint16(34))
        );
        c = _context(h);
        c.actor = address(0);
        _reject(
            address(h),
            abi.encodeCall(h.appendOnly, (c, f, list)),
            abi.encodeWithSelector(T.Unauthorized.selector, address(0))
        );
        c = _context(h);
        c.expected.revision = 1;
        _reject(
            address(h),
            abi.encodeCall(h.appendOnly, (c, f, list)),
            abi.encodeWithSelector(T.StaleOwnerSnapshot.selector, DOMAIN)
        );
        IdentityRecoveryReceiptHarness wrong =
            new IdentityRecoveryReceiptHarness(address(this), bytes32(uint256(1)));
        _reject(
            address(wrong),
            abi.encodeCall(wrong.appendOnly, (_context(wrong), f, list)),
            abi.encodeWithSelector(P.InvalidRecoveryReceipt.selector)
        );
        wrong = new IdentityRecoveryReceiptHarness(
            address(this), 0x1b0dd53dfa76f8d43a27b96148dae3ebe0609a01dfd55dedacf1fb71c51bfba3
        );
        _reject(
            address(wrong),
            abi.encodeCall(wrong.appendOnly, (_context(wrong), f, list)),
            abi.encodeWithSelector(P.InvalidRecoveryReceipt.selector)
        );
        wrong = new IdentityRecoveryReceiptHarness(address(0xdead), DOMAIN);
        _reject(
            address(wrong),
            abi.encodeCall(wrong.appendOnly, (_context(wrong), f, list)),
            abi.encodeWithSelector(T.Unauthorized.selector, address(this))
        );
    }

    function testLiteralFiveWordOccurrenceVector() public pure {
        require(
            P.occurrenceKey(
                0x13d96d7ab525b41942a305e28d561d3393aa134f1f297a69b3a49392d67ee48a,
                0x273a8a33fd441297e67ff984921de6f3c18a253af20f4d18fbf9ba110a0d15f3
            ) == 0x665dcb735498b7fba08f4e57684e476da9bc5b5c4dfba540d9905f990647424a
        );
    }
}

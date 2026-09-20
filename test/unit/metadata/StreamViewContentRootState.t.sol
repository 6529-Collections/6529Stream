// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamMetadataScopedContentState as S
} from "../../../smart-contracts/domains/metadata/StreamMetadataScopedContentState.sol";
import {
    IStreamScopedContentRootPublication as R
} from "../../../smart-contracts/interfaces/stream/metadata/IStreamScopedContentRootPublication.sol";
import {
    StreamMetadataSubjects
} from "../../../smart-contracts/domains/metadata/StreamMetadataSubjects.sol";
import "../../../smart-contracts/interfaces/stream/finality/StreamArtworkFinalityTypes.sol";

interface ViewRootStateVm {
    struct Log {
        bytes32[] topics;
        bytes data;
        address emitter;
    }
    function warp(uint256) external;
    function expectRevert(bytes4) external;
    function expectRevert(bytes calldata) external;
    function recordLogs() external;
    function getRecordedLogs() external returns (Log[] memory);
}

/// @dev State-book harness only: no producer, Artist consent or publication-authority claim.
contract ViewRootStateProbe {
    address public constant CORE = address(0xC0DE);
    uint256 public beforeCanary = 137;
    S.State private state;
    uint256 public afterCanary = 911;

    function append(R.Record memory r, bytes32 consent, bool viewPath) external returns (bytes32) {
        return viewPath ? S.commitView(state, CORE, r, consent) : S.commit(state, CORE, r, consent);
    }

    function preview(R.Record memory r, bool viewPath) external view returns (R.Aggregate memory) {
        return viewPath ? S.nextView(state, CORE, r) : S.next(state, CORE, r);
    }

    function head(StreamFinalityScope memory scope, bool viewPath) external view returns (bytes32) {
        return state.heads[viewPath ? S.viewSubject(CORE, scope) : S.subject(CORE, scope)];
    }

    function record(bytes32 hash) external view returns (R.Record memory) {
        return state.records[hash];
    }

    function aggregate(uint256 collection) external view returns (R.Aggregate memory) {
        return state.aggregates[collection];
    }

    function family(uint256 collection, bytes32 legacy) external view returns (bytes32) {
        return S.family(CORE, collection, legacy, state.aggregates[collection]);
    }

    function scopedContentRootAggregate(uint256 collection)
        external
        view
        returns (R.Aggregate memory)
    {
        return state.aggregates[collection];
    }

    function familyViaOriginalGetter(uint256 collection, bytes32 legacy)
        external
        view
        returns (bytes32)
    {
        return S.familyCurrent(CORE, collection, legacy);
    }

    function maxRevision(uint256 collection) external {
        state.aggregates[collection].revision = type(uint64).max;
    }
}

contract StreamViewContentRootStateTest {
    ViewRootStateVm private constant vm =
        ViewRootStateVm(address(uint160(uint256(keccak256("hevm cheat code")))));
    ViewRootStateProbe private h;
    bytes32 private constant CONSENT = keccak256("original CONTENT_ROOT consent");

    function setUp() public {
        h = new ViewRootStateProbe();
        vm.warp(100);
    }

    function _row(StreamFinalityScopeType kind, uint256 id)
        private
        pure
        returns (R.Record memory r)
    {
        r.publication.scope = StreamFinalityScope(
            kind,
            1,
            kind == StreamFinalityScopeType.TOKEN ? id : 0,
            kind == StreamFinalityScopeType.TOKEN ? bytes32(0) : bytes32(id)
        );
        r.publication.snapshotRecordHash = keccak256(abi.encode("snapshot", kind, id));
        r.publication.snapshotRevision = 1;
        r.publication.manifestURI = "ipfs://reviewed-root";
        r.publisher = address(0xA11CE);
        r.stateHash = keccak256(abi.encode("independently validated typed state", kind, id));
    }

    function _append(R.Record memory r, bool viewPath) private returns (bytes32 hash) {
        R.Aggregate memory prior = h.aggregate(r.publication.scope.collectionId);
        bytes32 id =
            StreamMetadataSubjects.scopeSubject(block.chainid, h.CORE(), r.publication.scope);
        R.Aggregate memory next = R.Aggregate(
            prior.revision + 1,
            keccak256(
                abi.encode(
                    keccak256("6529STREAM_SCOPED_CONTENT_ROOT_APPEND_V1"),
                    block.chainid,
                    address(h),
                    h.CORE(),
                    r.publication.scope.collectionId,
                    prior.transitionChain,
                    prior.revision + 1,
                    id,
                    r.publication.expectedPredecessor,
                    r.stateHash
                )
            )
        );
        require(
            keccak256(abi.encode(h.preview(r, viewPath))) == keccak256(abi.encode(next)),
            "prospective aggregate"
        );
        hash = h.append(r, CONSENT, viewPath);
        r.artistConsent = CONSENT;
        r.publishedAt = uint64(block.timestamp);
        require(
            hash
                == keccak256(
                    abi.encode(
                        keccak256("6529STREAM_SCOPED_CONTENT_ROOT_RECORD_V1"),
                        block.chainid,
                        address(h),
                        h.CORE(),
                        r,
                        next
                    )
                ),
            "record preimage"
        );
        require(keccak256(abi.encode(h.record(hash))) == keccak256(abi.encode(r)), "full record");
        require(h.head(r.publication.scope, viewPath) == hash, "scope head");
        require(
            keccak256(abi.encode(h.aggregate(r.publication.scope.collectionId)))
                == keccak256(abi.encode(next)),
            "committed aggregate"
        );
        require(h.beforeCanary() == 137 && h.afterCanary() == 911, "storage canaries");
        // Internal memory arguments alias the caller. The record oracle must leave its
        // prospective input reusable for the next genuine predecessor/retry assertion.
        r.artistConsent = 0;
        r.publishedAt = 0;
    }

    function testLegacyEntrypointsStillRejectViewAndViewRejectsLegacy() external {
        R.Record memory r = _row(StreamFinalityScopeType.VIEW, 1);
        vm.expectRevert(R.InvalidScopedContentRoot.selector);
        h.preview(r, false);
        vm.expectRevert(R.InvalidScopedContentRoot.selector);
        h.append(r, CONSENT, false);
        for (uint256 i = 1; i < 4; i++) {
            r = _row(StreamFinalityScopeType(i), 1);
            vm.expectRevert(R.InvalidScopedContentRoot.selector);
            h.preview(r, true);
            vm.expectRevert(R.InvalidScopedContentRoot.selector);
            h.append(r, CONSENT, true);
        }
        require(h.aggregate(1).revision == 0, "no widened admission");
    }

    function testViewAndLegacyShareAggregateAndKeepIndependentHeads() external {
        R.Record memory a = _row(StreamFinalityScopeType.VIEW, 7);
        bytes32 ah = _append(a, true);
        R.Record memory b = _row(StreamFinalityScopeType.RELEASE, 7);
        bytes32 bh = _append(b, false);
        R.Record memory c = _row(StreamFinalityScopeType.VIEW, 8);
        _append(c, true);
        a.publication.expectedPredecessor = ah;
        a.stateHash = keccak256("next view state");
        _append(a, true);
        require(h.head(b.publication.scope, false) == bh, "other head retained");
        require(h.aggregate(1).revision == 4, "shared revision");
        bytes32 legacy = keccak256("new collection root");
        R.Aggregate memory agg = h.aggregate(1);
        bytes32 expected = keccak256(
            abi.encode(
                keccak256("6529STREAM_CONTENT_ROOT_FAMILY_WITH_SCOPES_V1"),
                block.chainid,
                address(h),
                h.CORE(),
                uint256(1),
                legacy,
                agg
            )
        );
        require(
            h.family(1, legacy) == expected && h.familyViaOriginalGetter(1, legacy) == expected,
            "original family includes VIEW"
        );
        require(h.family(2, legacy) == legacy, "empty collection unchanged");
    }

    function testExactEventRetainsOriginalSchemaAndCompleteRecord() external {
        R.Record memory r = _row(StreamFinalityScopeType.VIEW, 9);
        vm.recordLogs();
        bytes32 hash = _append(r, true);
        ViewRootStateVm.Log[] memory logs = vm.getRecordedLogs();
        require(logs.length == 1, "one event");
        require(logs[0].emitter == address(h) && logs[0].topics.length == 4, "emitter/topics");
        assert(
            logs[0].topics[0] == 0x37edf9a40eedbcc80cfce0642b3775d6c513d1c520bd7b5ccce6878591f63073
        );
        require(
            logs[0].topics[1] == bytes32(uint256(1)) && logs[0].topics[3] == hash, "event subject"
        );
        require(
            logs[0].topics[2]
                == StreamMetadataSubjects.scopeSubject(
                    block.chainid, h.CORE(), r.publication.scope
                ),
            "canonical scope"
        );
        require(
            keccak256(logs[0].data)
                == keccak256(abi.encode(uint16(1), h.record(hash), h.aggregate(1))),
            "event bytes"
        );
    }

    function testStalePredecessorRollsBackAndSameRecordCanRetry() external {
        R.Record memory r = _row(StreamFinalityScopeType.VIEW, 4);
        bytes32 head = _append(r, true);
        bytes32 before_ = keccak256(abi.encode(h.aggregate(1), h.record(head)));
        vm.expectRevert(
            abi.encodeWithSelector(R.ScopedContentRootLineage.selector, bytes32(0), head)
        );
        h.append(r, CONSENT, true);
        require(
            before_ == keccak256(abi.encode(h.aggregate(1), h.record(head))), "failed append atomic"
        );
        r.publication.expectedPredecessor = head;
        _append(r, true);
    }

    function testMalformedViewShapeAndZeroConsentDoNotWrite() external {
        R.Record memory r = _row(StreamFinalityScopeType.VIEW, 1);
        r.publication.scope.tokenId = 7;
        vm.expectRevert(StreamMetadataSubjects.InvalidMetadataScope.selector);
        h.append(r, CONSENT, true);
        r.publication.scope.tokenId = 0;
        r.publication.scope.scopeId = 0;
        vm.expectRevert(StreamMetadataSubjects.InvalidMetadataScope.selector);
        h.append(r, CONSENT, true);
        r.publication.scope.scopeId = bytes32(uint256(1));
        vm.expectRevert(R.InvalidScopedContentRoot.selector);
        h.append(r, 0, true);
        require(h.aggregate(1).revision == 0, "malformed/unsigned changed aggregate");
    }

    function testOverflowRefusesBothPaths() external {
        h.maxRevision(1);
        vm.expectRevert(R.InvalidScopedContentRoot.selector);
        h.append(_row(StreamFinalityScopeType.VIEW, 1), CONSENT, true);
        vm.expectRevert(R.InvalidScopedContentRoot.selector);
        h.append(_row(StreamFinalityScopeType.TOKEN, 1), CONSENT, false);
        require(h.aggregate(1).revision == type(uint64).max, "overflow wrote");
    }

    function testFuzzMixedAppendHistory(uint8 count, bytes32 salt) external {
        uint256 n = 1 + uint256(count) % 17;
        for (uint256 i; i < n; i++) {
            bool viewPath = i % 2 == 0;
            R.Record memory r = _row(
                viewPath ? StreamFinalityScopeType.VIEW : StreamFinalityScopeType.TOKEN, i + 1
            );
            r.stateHash = keccak256(abi.encode("mixed", salt, i));
            _append(r, viewPath);
        }
        require(h.aggregate(1).revision == n, "complete mixed history");
    }
}

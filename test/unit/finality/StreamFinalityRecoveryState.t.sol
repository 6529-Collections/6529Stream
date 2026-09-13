// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../../../smart-contracts/domains/finality/StreamFinalityRecoveryState.sol";
import "../../../smart-contracts/interfaces/stream/finality/StreamFinalityRecoveryTypes.sol";

interface RecoveryStateVm {
    struct Log {
        bytes32[] topics;
        bytes data;
        address emitter;
    }
    function recordLogs() external;
    function getRecordedLogs() external returns (Log[] memory);
    function etch(address target, bytes calldata code) external;
}

contract RecoveryStateHost {
    StreamFinalityRecoveryState.State private state;
    address private immutable core;
    bytes32 private immutable coreHash;

    constructor(address c) {
        core = c;
        coreHash = c.codehash;
    }

    function append(
        StreamFinalityRecoveryRequest calldata r,
        StreamFinalityRecoveryEvidenceSnapshot calldata e,
        StreamFinalityRecoveryState.Admission calldata a,
        bool fail
    ) external returns (bytes32 hash) {
        hash = StreamFinalityRecoveryState.append(state, r, e, a);
        require(!fail, "late fixture failure");
    }

    function advance(StreamFinalityScope calldata s, bytes32 id) external {
        StreamFinalityRecoveryState.continuePlan(state, s, id, core, coreHash);
    }

    function record(bytes32 id) external view returns (StreamFinalityRecoveryRecord memory) {
        return state.records[id];
    }

    function plan(bytes32 id) external view returns (StreamFinalityRecoveryRefreshPlan memory) {
        return state.plans[id];
    }

    function head(StreamFinalityScope calldata s)
        external
        view
        returns (StreamFinalityRecoveryState.Head memory)
    {
        return state.heads[
            keccak256(abi.encode(uint8(s.scopeType), s.collectionId, s.tokenId, s.scopeId))
        ];
    }

    function route(StreamFinalityScope calldata s, bytes32 kind) external view returns (bytes32) {
        return state.routeOverrides[
            keccak256(abi.encode(uint8(s.scopeType), s.collectionId, s.tokenId, s.scopeId))
        ][kind];
    }

    function count() external view returns (uint256) {
        return state.incompleteCount;
    }

    function assertComplete() external view {
        StreamFinalityRecoveryState.assertComplete(state);
    }
}

contract RecoveryRefreshCoreBoundary {
    bool public failing;
    bool public reenter;
    address public host;
    bytes public reentryData;
    bool public reentryRejected;
    uint256 public calls;
    uint256 public from;
    uint256 public to;
    bytes32 public reason;

    function configure(address h, bool failure, bool recursive, bytes calldata data) external {
        host = h;
        failing = failure;
        reenter = recursive;
        reentryData = data;
    }

    function emitBatchMetadataUpdate(uint256 a, uint256 b, bytes32 r) external {
        require(msg.sender == host && !failing, "Core boundary reject");
        require(a != 0 && b >= a && b - a < 5000, "bounded range");
        if (reenter) {
            (bool ok, bytes memory error) = host.call(reentryData);
            reentryRejected = !ok
                && keccak256(error)
                    == keccak256(
                        abi.encodeWithSelector(
                            StreamFinalityRecoveryState.FinalityRecoveryRefreshReentrancy.selector
                        )
                    );
            require(reentryRejected, "exact recursive guard");
        }
        ++calls;
        from = a;
        to = b;
        reason = r;
    }
}

/// @dev State/callback mechanism only: original, authority, membership and high-water facts are supplied by this harness.
contract StreamFinalityRecoveryStateTest {
    RecoveryStateVm private constant vm =
        RecoveryStateVm(address(uint160(uint256(keccak256("hevm cheat code")))));
    RecoveryStateHost private host;
    RecoveryRefreshCoreBoundary private core;

    function setUp() public {
        core = new RecoveryRefreshCoreBoundary();
        host = new RecoveryStateHost(address(core));
        core.configure(address(host), false, false, "");
    }

    function _request() private pure returns (StreamFinalityRecoveryRequest memory r) {
        r.scope = StreamFinalityScope(StreamFinalityScopeType.COLLECTION, 7, 0, 0);
        r.expectedOriginalFinalityRecordHash = keccak256("original executed record");
        r.expectedOldRouteHash = keccak256("selected original route");
        r.replacementRoute = StreamFinalityComponentExpectation(
            keccak256("renderer"),
            address(0xBEEF),
            0x12345678,
            keccak256("code"),
            keccak256("version"),
            keccak256("component manifest"),
            keccak256("data")
        );
        r.recoveryManifest = StreamFinalityManifestRef(
            "urn:recovery",
            keccak256("urn:recovery"),
            keccak256("actual intent"),
            keccak256("schema"),
            keccak256("canonicalization")
        );
        r.reasonHash = keccak256("reason");
        r.reasonURI = "urn:reason";
    }

    function _evidence() private pure returns (StreamFinalityRecoveryEvidenceSnapshot memory) {
        return StreamFinalityRecoveryEvidenceSnapshot(
            StreamFinalityRecoveryArtistEvidenceKind.APPROVAL,
            keccak256("approval"),
            address(0x1234),
            keccak256("artist"),
            1,
            0,
            keccak256("owner evidence"),
            8,
            77,
            4,
            0
        );
    }

    function _admission(StreamFinalityRecoveryRequest memory r, bytes32 id, uint256 high)
        private
        pure
        returns (StreamFinalityRecoveryState.Admission memory)
    {
        return StreamFinalityRecoveryState.Admission(id, r.scope, r.expectedOldRouteHash, high);
    }

    function _reject(
        StreamFinalityRecoveryRequest memory r,
        StreamFinalityRecoveryState.Admission memory a
    ) private {
        (bool ok,) = address(host).call(abi.encodeCall(host.append, (r, _evidence(), a, false)));
        require(!ok, "must reject");
    }

    function testRecoveryStateFullRecordRoutePreimageAndOrderedEvents() public {
        StreamFinalityRecoveryRequest memory r = _request();
        bytes32 id = keccak256("action one");
        StreamFinalityRecoveryEvidenceSnapshot memory e = _evidence();
        vm.recordLogs();
        bytes32 route = host.append(r, e, _admission(r, id, 10001), false);
        bytes32 expected = keccak256(
            bytes.concat(
                abi.encode(
                    keccak256("6529STREAM_FINALITY_RECOVERY_V1"),
                    block.chainid,
                    address(host),
                    id,
                    r.expectedOriginalFinalityRecordHash,
                    bytes32(0),
                    uint64(1)
                ),
                abi.encode(
                    r.scope, r.replacementRoute, r.recoveryManifest.contentHash, e, r.reasonHash
                )
            )
        );
        require(route == expected, "literal31-word executed route");
        StreamFinalityRecoveryRecord memory record = StreamFinalityRecoveryRecord(
            true,
            id,
            r.scope,
            r.expectedOriginalFinalityRecordHash,
            0,
            1,
            r.expectedOldRouteHash,
            route,
            true,
            r.replacementRoute,
            r.recoveryManifest,
            e,
            r.reasonHash,
            r.reasonURI,
            uint64(block.timestamp)
        );
        require(
            keccak256(abi.encode(host.record(id))) == keccak256(abi.encode(record)),
            "complete immutable executed record"
        );
        RecoveryStateVm.Log[] memory logs = vm.getRecordedLogs();
        require(logs.length == 4, "one lineage evidence execution plan sequence");
        for (uint256 i; i < logs.length; ++i) {
            require(logs[i].emitter == address(host), "owning host emits");
        }
        require(
            logs[0].topics[0]
                    == keccak256(
                        "FinalityRecoveryLineageRecorded(uint16,bytes32,bytes32,bytes32,uint64,bytes32,bytes32)"
                    ) && logs[0].topics[1] == id && logs[0].topics[2] == 0
                && logs[0].topics[3] == r.expectedOriginalFinalityRecordHash,
            "exact indexed lineage"
        );
        require(
            keccak256(logs[0].data)
                == keccak256(abi.encode(uint16(1), uint64(1), r.expectedOldRouteHash, route)),
            "lineage data"
        );
        require(
            logs[1].topics[0]
                    == keccak256(
                        "FinalityRecoveryEvidenceSnapshotted(uint16,bytes32,uint8,bytes32,address,bytes32,uint8,uint64,bytes32,uint64,uint64,uint32,uint32)"
                    ) && keccak256(logs[1].data) == keccak256(abi.encode(uint16(1), e)),
            "all evidence fields"
        );
        require(
            logs[2].topics[0]
                    == keccak256(
                        "FinalityRecoveryExecuted(uint16,uint256,bytes32,bytes32,bytes32,bool,bytes32,string)"
                    )
                && keccak256(logs[2].data)
                    == keccak256(
                        abi.encode(
                            uint16(1),
                            r.recoveryManifest.contentHash,
                            route,
                            true,
                            r.reasonHash,
                            r.reasonURI
                        )
                    ),
            "exact execution event"
        );
        require(
            logs[3].topics[0]
                    == keccak256(
                        "FinalityRecoveryRefreshPlanCreated(uint16,uint256,bytes32,bytes32,uint256,uint256,uint256,bool)"
                    )
                && keccak256(logs[3].data)
                    == keccak256(
                        abi.encode(uint16(1), uint256(10001), uint256(1), uint256(10001), false)
                    ),
            "exact plan event"
        );
        require(
            host.count() == 1 && host.head(r.scope).generation == 1
                && host.route(r.scope, r.replacementRoute.componentType) == id,
            "one active head and plan"
        );
    }

    function testRecoveryStateReplayStaleBaseAndLateFailureLeaveNoAppend() public {
        StreamFinalityRecoveryRequest memory r = _request();
        bytes32 id = keccak256("first");
        host.append(r, _evidence(), _admission(r, id, 10), false);
        bytes32 before_ =
            keccak256(abi.encode(host.record(id), host.head(r.scope), host.plan(id), host.count()));
        _reject(r, _admission(r, id, 10));
        _reject(r, _admission(r, keccak256("stale"), 10));
        r.expectedPredecessorRecoveryId = id;
        r.expectedOriginalFinalityRecordHash = keccak256("rebase");
        _reject(r, _admission(r, keccak256("new"), 10));
        require(
            before_
                == keccak256(
                    abi.encode(host.record(id), host.head(r.scope), host.plan(id), host.count())
                ),
            "failed probes preserve all old facts"
        );
        r.expectedOriginalFinalityRecordHash = _request().expectedOriginalFinalityRecordHash;
        bytes32 next = keccak256("healthy successor");
        (bool ok,) = address(host)
            .call(abi.encodeCall(host.append, (r, _evidence(), _admission(r, next, 10), true)));
        require(!ok, "late fixture revert");
        require(
            !host.record(next).executed
                && before_
                    == keccak256(
                        abi.encode(host.record(id), host.head(r.scope), host.plan(id), host.count())
                    ),
            "late failure restores supersession and head"
        );
        host.append(r, _evidence(), _admission(r, next, 10), false);
        require(
            host.record(next).predecessorRecoveryId == id && host.count() == 1,
            "same candidate retries once"
        );
    }

    function testRecoveryStateRefreshOneCoreCallAtomicRetryAndRecursiveGuard() public {
        StreamFinalityRecoveryRequest memory r = _request();
        bytes32 id = keccak256("refresh");
        host.append(r, _evidence(), _admission(r, id, 10001), false);
        core.configure(address(host), true, false, "");
        (bool ok,) = address(host).call(abi.encodeCall(host.advance, (r.scope, id)));
        require(!ok, "Core failure");
        require(
            host.plan(id).processedThrough == 0 && host.plan(id).chunksEmitted == 0
                && host.count() == 1 && core.calls() == 0,
            "cursor count and callback rollback"
        );
        core.configure(address(host), false, true, abi.encodeCall(host.advance, (r.scope, id)));
        host.advance(r.scope, id);
        require(
            core.calls() == 1 && core.from() == 1 && core.to() == 5000
                && core.reason() == r.recoveryManifest.contentHash && core.reentryRejected(),
            "one bounded callback and recursive rejection"
        );
        host.advance(r.scope, id);
        require(
            core.calls() == 2 && core.from() == 5001 && core.to() == 10000, "second exact range"
        );
        core.configure(address(host), false, false, "");
        host.advance(r.scope, id);
        require(
            core.calls() == 3 && core.from() == 10001 && core.to() == 10001
                && host.plan(id).complete && host.count() == 0,
            "last one and single decrement"
        );
        host.assertComplete();
        (ok,) = address(host).call(abi.encodeCall(host.advance, (r.scope, id)));
        require(!ok && core.calls() == 3, "completed plan cannot emit again");
    }

    function testRecoveryStateSupersessionPreservesHistoryAndOtherRouteOverrides() public {
        StreamFinalityRecoveryRequest memory r = _request();
        bytes32 id = keccak256("old");
        host.append(r, _evidence(), _admission(r, id, 10001), false);
        host.advance(r.scope, id);
        bytes32 history = keccak256(abi.encode(host.record(id)));
        bytes32 renderer = r.replacementRoute.componentType;
        r.expectedPredecessorRecoveryId = id;
        r.replacementRoute.componentType = keccak256("media");
        r.recoveryManifest.contentHash = keccak256("second exact intent");
        bytes32 next = keccak256("next");
        host.append(r, _evidence(), _admission(r, next, 10), false);
        StreamFinalityRecoveryRefreshPlan memory old = host.plan(id);
        require(
            old.superseded && old.supersededByRecoveryId == next && old.processedThrough == 5000
                && host.count() == 1,
            "old partial superseded once, new full plan"
        );
        require(
            history == keccak256(abi.encode(host.record(id))) && host.route(r.scope, renderer) == id
                && host.route(r.scope, r.replacementRoute.componentType) == next,
            "record history and route-specific source preserved"
        );
        (bool ok,) = address(host).call(abi.encodeCall(host.advance, (r.scope, id)));
        require(!ok, "superseded plan cannot resume");
        host.advance(r.scope, next);
        require(host.count() == 0 && core.to() == 10, "new manifest complete full range");
    }

    function testRecoveryStateFiveScopesZeroRangeTokenRangeAndCorePin() public {
        StreamFinalityRecoveryRequest memory r = _request();
        for (uint8 i; i < 5; ++i) {
            r.scope = StreamFinalityScope(
                StreamFinalityScopeType(i),
                7,
                i == 1 ? 99 : 0,
                i > 1 ? keccak256(abi.encode(i)) : bytes32(0)
            );
            bytes32 id = keccak256(abi.encode("scope", i));
            host.append(r, _evidence(), _admission(r, id, i == 1 ? 100 : 0), false);
            StreamFinalityRecoveryRefreshPlan memory p = host.plan(id);
            if (i == 1) {
                require(p.rangeStart == 99 && p.rangeEnd == 99 && !p.complete, "exact token");
                bytes memory code = address(core).code;
                vm.etch(address(core), hex"00");
                (bool ok,) = address(host).call(abi.encodeCall(host.advance, (r.scope, id)));
                require(
                    !ok && host.plan(id).processedThrough == 0, "Core pin failure preserves cursor"
                );
                vm.etch(address(core), code);
                host.advance(r.scope, id);
                require(core.from() == 99 && core.to() == 99, "retained token range");
            } else {
                require(
                    p.complete && p.rangeStart == 0 && p.rangeEnd == 0, "zero high-water complete"
                );
            }
        }
        require(host.count() == 0, "all five scope plans complete");
    }

    function testFuzzRecoveryStateBoundedChunkPartition(uint64 input) public {
        uint256 high = uint256(input) % 20001;
        StreamFinalityRecoveryRequest memory r = _request();
        bytes32 id = keccak256("fuzz");
        host.append(r, _evidence(), _admission(r, id, high), false);
        uint256 processed;
        uint256 chunks;
        while (processed < high) {
            host.advance(r.scope, id);
            require(
                core.from() == processed + 1 && core.to() - core.from() < 5000,
                "gapless bounded range"
            );
            processed = core.to();
            ++chunks;
        }
        require(
            processed == high && core.calls() == chunks && chunks == (high + 4999) / 5000
                && host.count() == 0 && host.plan(id).complete,
            "exact complete partition"
        );
    }
}

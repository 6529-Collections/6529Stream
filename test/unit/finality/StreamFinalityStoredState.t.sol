// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../../regression/legacy/helpers/CharacterizationTestBase.sol";
import "../../helpers/FinalityMocks.sol";
import "../../../smart-contracts/domains/finality/StreamArtworkFinalityStorage.sol";
import "../../../smart-contracts/domains/finality/StreamFinalityRecordState.sol";
import "../../../smart-contracts/domains/finality/StreamFinalityDiagnostics.sol";

/// @dev Isolated exact-storage/emitter harness, deliberately not a finality admission provider.
contract FinalityStoredStateHarness is StreamArtworkFinalityStorage {
    address public immutable discovery;

    constructor(address discovery_) {
        discovery = discovery_;
    }

    function store(
        StreamFinalityScope calldata scope,
        StreamFinalityPreparation.Prepared calldata ctx,
        StreamFinalityComponentExpectation[] calldata components,
        StreamFinalityManifestRef calldata manifest
    ) external {
        StreamFinalityRecordState.store(
            _collectionRecords,
            _collectionComponents,
            _scopedRecords,
            _scopedComponents,
            scope,
            ctx,
            components,
            manifest
        );
    }

    function collection(uint256 id) external view returns (StreamCollectionFinalityRecord memory) {
        return _collectionRecords[id];
    }

    function scoped(bytes32 key) external view returns (StreamScopedFinalityRecord memory) {
        return _scopedRecords[key];
    }

    function components(StreamFinalityScope calldata scope, bytes32 key)
        external
        view
        returns (StreamFinalityComponentExpectation[] memory)
    {
        return scope.scopeType == StreamFinalityScopeType.COLLECTION
            ? _collectionComponents[scope.collectionId]
            : _scopedComponents[key];
    }

    function matches(StreamFinalityScope calldata scope, bytes32 key, bytes32 expectedHash)
        external
        view
        returns (bool)
    {
        return StreamFinalityDiagnostics.matches(
            _components(scope, key), scope, expectedHash, discovery, 150000
        );
    }

    function range(StreamFinalityScope calldata scope, bytes32 key, uint256 start, uint256 limit)
        external
        view
        returns (bool, bytes32, bytes32, uint256)
    {
        return StreamFinalityDiagnostics.range(_components(scope, key), scope, start, limit, 150000);
    }

    function _components(StreamFinalityScope calldata scope, bytes32 key)
        private
        view
        returns (StreamFinalityComponentExpectation[] storage)
    {
        if (scope.scopeType == StreamFinalityScopeType.COLLECTION) {
            return _collectionComponents[scope.collectionId];
        }
        return _scopedComponents[key];
    }
}

contract StreamFinalityStoredStateTest is CharacterizationTestBase {
    MockFinalityDiscovery private discovery;
    FinalityStoredStateHarness private host;
    MockFinalityComponent[2] private targets;

    function setUp() public {
        vm.warp(777);
        discovery = new MockFinalityDiscovery();
        host = new FinalityStoredStateHarness(address(discovery));
        targets[0] = new MockFinalityComponent();
        targets[1] = new MockFinalityComponent();
    }

    function _scope(uint8 kind) private pure returns (StreamFinalityScope memory scope) {
        scope = StreamFinalityScope(
            StreamFinalityScopeType(kind),
            5,
            kind == 1 ? 17 : 0,
            kind > 1 ? keccak256(abi.encode(kind)) : bytes32(0)
        );
    }

    function _data(StreamFinalityScope memory scope)
        private
        returns (
            StreamFinalityPreparation.Prepared memory ctx,
            StreamFinalityComponentExpectation[] memory entries,
            StreamFinalityManifestRef memory manifest
        )
    {
        entries = new StreamFinalityComponentExpectation[](2);
        for (uint256 i; i < 2; ++i) {
            entries[i] = StreamFinalityComponentExpectation(
                bytes32(i + 1),
                address(targets[i]),
                bytes4(0x12345678),
                address(targets[i]).codehash,
                bytes32(uint256(1)),
                keccak256("module"),
                bytes32(i + 100)
            );
            StreamFinalityComponentExpectation memory e = entries[i];
            StreamFinalityComponentState memory state = StreamFinalityComponentState(
                true,
                e.componentType,
                e.component,
                e.interfaceId,
                e.codeHash,
                e.moduleVersion,
                e.manifestHash,
                e.dataHash
            );
            if (scope.scopeType == StreamFinalityScopeType.COLLECTION) {
                targets[i].setCollectionState(scope.collectionId, state);
                discovery.setCollectionComponent(scope.collectionId, i, entries[i]);
            } else {
                targets[i].setScopedState(scope, state);
                discovery.setScopedComponent(scope, i, entries[i]);
            }
        }
        ctx.scopeKey = keccak256(abi.encode(scope));
        ctx.componentsHash =
            keccak256(abi.encode(keccak256("6529STREAM_FINALITY_COMPONENTS_V1"), entries));
        ctx.finalityRecordHash = keccak256(abi.encode("isolated admitted record", scope));
        manifest = StreamFinalityManifestRef(
            "urn:stored-record:dynamic-manifest",
            keccak256("urn:stored-record:dynamic-manifest"),
            keccak256("manifest bytes"),
            keccak256("schema"),
            keccak256("canonicalization")
        );
        if (scope.scopeType == StreamFinalityScopeType.COLLECTION) {
            discovery.setCollectionDiscovery(scope.collectionId, 2, ctx.componentsHash);
        } else {
            discovery.setScopedDiscovery(scope, 2, ctx.componentsHash);
        }
    }

    function testStoredCollectionExactFieldsOrderedComponentsAndEmitterEvents() public {
        StreamFinalityScope memory scope = _scope(0);
        (
            StreamFinalityPreparation.Prepared memory ctx,
            StreamFinalityComponentExpectation[] memory entries,
            StreamFinalityManifestRef memory manifest
        ) = _data(scope);
        vm.recordLogs();
        host.store(scope, ctx, entries, manifest);
        Vm.Log[] memory logs = vm.getRecordedLogs();
        StreamCollectionFinalityRecord memory expected = StreamCollectionFinalityRecord(
            true,
            ctx.finalityRecordHash,
            manifest.contentHash,
            manifest.uriHash,
            manifest.uri,
            ctx.componentsHash,
            address(host),
            777
        );
        require(
            keccak256(abi.encode(host.collection(5))) == keccak256(abi.encode(expected)),
            "exact collection record bytes"
        );
        require(
            keccak256(abi.encode(host.components(scope, ctx.scopeKey)))
                == keccak256(abi.encode(entries)),
            "exact ordered components"
        );
        require(logs.length == 3, "exact store event count");
        require(
            logs[0].emitter == address(host) && logs[0].topics.length == 4
                && logs[0].topics[0]
                    == keccak256(
                        "CollectionArtworkFinalized(uint16,uint256,bytes32,address,bytes32,bytes32,string)"
                    ) && logs[0].topics[1] == bytes32(uint256(5))
                && logs[0].topics[2] == ctx.finalityRecordHash
                && logs[0].topics[3] == bytes32(uint256(uint160(address(this)))),
            "owner/caller collection topics"
        );
        require(
            keccak256(logs[0].data)
                == keccak256(
                    abi.encode(uint16(1), ctx.componentsHash, manifest.contentHash, manifest.uri)
                ),
            "exact dynamic collection event bytes"
        );
        _tail(logs, ctx, manifest);
        require(!host.scoped(ctx.scopeKey).finalized, "collection does not populate scoped root");
        require(
            address(StreamFinalityRecordState).code.length <= 24576, "actual linked writer fits"
        );
        (bool ok,) = address(StreamFinalityRecordState)
            .call(
                abi.encodeWithSelector(
                    StreamFinalityRecordState.store.selector,
                    uint256(0),
                    uint256(1),
                    uint256(2),
                    uint256(3),
                    scope,
                    ctx,
                    entries,
                    manifest
                )
            );
        require(!ok, "nonview library direct CALL rejected");
    }

    function testStoredAllFourScopedVariantsPreserveCollectionRootAndExactRecords() public {
        for (uint8 kind = 1; kind <= 4; ++kind) {
            StreamFinalityScope memory scope = _scope(kind);
            (
                StreamFinalityPreparation.Prepared memory ctx,
                StreamFinalityComponentExpectation[] memory entries,
                StreamFinalityManifestRef memory manifest
            ) = _data(scope);
            vm.recordLogs();
            host.store(scope, ctx, entries, manifest);
            Vm.Log[] memory logs = vm.getRecordedLogs();
            StreamScopedFinalityRecord memory expected = StreamScopedFinalityRecord(
                true,
                scope,
                ctx.finalityRecordHash,
                manifest.contentHash,
                manifest.uriHash,
                ctx.componentsHash,
                manifest.uri,
                address(host),
                777
            );
            require(
                keccak256(abi.encode(host.scoped(ctx.scopeKey))) == keccak256(abi.encode(expected)),
                "exact scoped record bytes"
            );
            require(
                keccak256(abi.encode(host.components(scope, ctx.scopeKey)))
                    == keccak256(abi.encode(entries)),
                "exact scoped component array"
            );
            require(
                logs.length == 3 && logs[0].emitter == address(host) && logs[0].topics.length == 4
                    && logs[0].topics[0]
                        == keccak256(
                            "ArtworkScopeFinalized(uint16,uint8,uint256,bytes32,uint256,bytes32,bytes32,bytes32,string)"
                        ) && logs[0].topics[1] == bytes32(uint256(kind))
                    && logs[0].topics[2] == bytes32(uint256(5))
                    && logs[0].topics[3] == ctx.finalityRecordHash,
                "exact scoped topics"
            );
            require(
                keccak256(logs[0].data)
                    == keccak256(
                        abi.encode(
                            uint16(1),
                            scope.tokenId,
                            scope.scopeId,
                            ctx.componentsHash,
                            manifest.contentHash,
                            manifest.uri
                        )
                    ),
                "exact scoped event payload"
            );
            _tail(logs, ctx, manifest);
            require(
                !host.collection(5).finalized
                    && host.matches(scope, ctx.scopeKey, ctx.componentsHash),
                "scoped writes isolated and diagnostic readable"
            );
        }
    }

    function _tail(
        Vm.Log[] memory logs,
        StreamFinalityPreparation.Prepared memory ctx,
        StreamFinalityManifestRef memory manifest
    ) private view {
        require(
            logs[1].emitter == address(host) && logs[1].topics.length == 2
                && logs[1].topics[0]
                    == keccak256("FinalityManifestPointerRecorded(uint16,bytes32,address,bytes32)")
                && logs[1].topics[1] == ctx.finalityRecordHash
                && keccak256(logs[1].data)
                    == keccak256(abi.encode(uint16(1), address(host), manifest.contentHash)),
            "second exact pointer event"
        );
        require(
            logs[2].emitter == address(host) && logs[2].topics.length == 3
                && logs[2].topics[0]
                    == keccak256("ArtworkTerminalFreezeExecuted(uint16,bytes32,bytes32,address)")
                && logs[2].topics[1] == ctx.scopeKey && logs[2].topics[2] == ctx.finalityRecordHash
                && keccak256(logs[2].data) == keccak256(abi.encode(uint16(1), address(this))),
            "third exact terminal event"
        );
    }

    function testDiagnosticsMalformedDependenciesEmptyRangesAndHealthyRestoration() public {
        StreamFinalityScope memory scope = _scope(0);
        (
            StreamFinalityPreparation.Prepared memory ctx,
            StreamFinalityComponentExpectation[] memory entries,
            StreamFinalityManifestRef memory manifest
        ) = _data(scope);
        host.store(scope, ctx, entries, manifest);
        require(host.matches(scope, ctx.scopeKey, ctx.componentsHash), "healthy stored route");
        for (uint8 mode = 1; mode <= 4; ++mode) {
            targets[0].setMode(mode);
            require(
                !host.matches(scope, ctx.scopeKey, ctx.componentsHash),
                "malformed component fail closed"
            );
            targets[0].setMode(0);
            discovery.setReadMode(mode);
            require(
                !host.matches(scope, ctx.scopeKey, ctx.componentsHash),
                "malformed count fail closed"
            );
            discovery.setReadMode(0);
            discovery.setHashReadMode(mode);
            require(
                !host.matches(scope, ctx.scopeKey, ctx.componentsHash), "malformed hash fail closed"
            );
            discovery.setHashReadMode(0);
            discovery.setComponentReadMode(mode);
            require(
                !host.matches(scope, ctx.scopeKey, ctx.componentsHash),
                "malformed discovery row fail closed"
            );
            discovery.setComponentReadMode(0);
            require(
                host.matches(scope, ctx.scopeKey, ctx.componentsHash),
                "same stored route healthy restoration"
            );
        }
        bytes32 empty = keccak256(
            abi.encode(
                keccak256("6529STREAM_FINALITY_COMPONENTS_V1"),
                new StreamFinalityComponentExpectation[](0)
            )
        );
        (bool matches_, bytes32 expected, bytes32 observed, uint256 next) =
            host.range(scope, ctx.scopeKey, 0, 0);
        require(
            matches_ && expected == empty && observed == empty && next == 0, "empty range exact"
        );
        (matches_, expected, observed, next) =
            host.range(scope, ctx.scopeKey, type(uint256).max, type(uint256).max);
        require(
            matches_ && expected == empty && observed == empty && next == 2,
            "out of range clamps without overflow"
        );
        (matches_, expected, observed, next) = host.range(scope, ctx.scopeKey, 0, type(uint256).max);
        require(
            matches_ && expected == ctx.componentsHash && observed == ctx.componentsHash
                && next == 2,
            "whole range exact"
        );
    }
}

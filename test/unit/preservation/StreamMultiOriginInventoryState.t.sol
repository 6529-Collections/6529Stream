// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    StreamMultiOriginInventoryState as Origins
} from "../../../smart-contracts/domains/preservation/StreamMultiOriginInventoryState.sol";
import {
    StreamArtistArchiveOriginTypes as O
} from "../../../smart-contracts/interfaces/stream/preservation/StreamArtistArchiveOriginTypes.sol";
import {
    StreamArtistRecoveredHydrationTypes as RH
} from "../../../smart-contracts/interfaces/stream/artist/StreamArtistRecoveredHydrationTypes.sol";
import {
    StreamPreservationInventoryTypes as T
} from "../../../smart-contracts/interfaces/stream/preservation/StreamPreservationInventoryTypes.sol";
import {
    StreamPreservationInventoryChains as Chains
} from "../../../smart-contracts/domains/preservation/StreamPreservationInventoryChains.sol";

interface MultiOriginStateVm {
    function expectRevert() external;
    function expectRevert(bytes4) external;
    function etch(address, bytes calldata) external;
}

contract MultiOriginPinFixture {
    function value() external pure returns (uint256) {
        return 1;
    }
}

/// @dev Synthetic storage harness bypasses typed source admission. It exercises the actual
/// table/capsule/runtime kernel and transaction rollback, not migration or Archive validity.
contract MultiOriginStateHarness {
    Origins.State private _state;

    function seed(bytes32 id, O.Origin memory a, O.Origin memory b) external {
        Origins.initialize(_state, id, a, b, keccak256("authenticated lineage fixture"));
    }

    function remember(
        bytes32 id,
        bytes32 contextHash,
        T.Item memory item,
        O.RecordOrigin memory original
    ) public {
        Origins.remember(
            _state,
            id,
            contextHash,
            item,
            original,
            keccak256("receipt"),
            address(0x1234),
            keccak256("ORIGINAL_ARTIST_PUBLICATION_AUTHORIZATION")
        );
    }

    function rememberThenFailSeal(
        bytes32 id,
        bytes32 contextHash,
        T.Item memory item,
        O.RecordOrigin memory original
    ) external {
        remember(id, contextHash, item, original);
        Origins.seal(_state, id);
    }

    function runtime(bytes32 id) external returns (T.Item[] memory rows, bytes32 witness) {
        return Origins.runtimeItems(_state, id);
    }

    function seal(bytes32 id) external returns (bytes32) {
        return Origins.seal(_state, id);
    }

    function count(bytes32 id) external view returns (uint256) {
        return _state.origins[id].length;
    }

    function at(bytes32 id, uint256 index) external view returns (O.Origin memory) {
        return _state.origins[id][index];
    }

    function root(bytes32 id) external view returns (bytes32) {
        return _state.sealedRoot[id];
    }

    function cursor(bytes32 id) external view returns (uint256) {
        return _state.runtimeCursor[id];
    }

    function record(bytes32 id, bytes32 hash) external view returns (O.RecordOrigin memory) {
        return _state.records[id][hash];
    }
}

contract StreamMultiOriginInventoryStateTest {
    MultiOriginStateVm private constant vm =
        MultiOriginStateVm(address(uint160(uint256(keccak256("hevm cheat code")))));
    bytes32 private constant ID = keccak256("plan");
    bytes32 private constant CONTEXT = keccak256("exact source context");
    bytes32 private constant ROLE = keccak256("ORIGINAL_ARTIST_PUBLICATION_AUTHORIZATION");

    function testSeedDeduplicatesAndPreservesCurrentThenPresentationOrder() public {
        MultiOriginStateHarness h = new MultiOriginStateHarness();
        address pin = address(new MultiOriginPinFixture());
        O.Origin memory a = _origin(pin, 1);
        O.Origin memory b = _origin(pin, 2);
        h.seed(ID, a, b);
        require(
            h.count(ID) == 2 && O.originPinHash(h.at(ID, 0)) == O.originPinHash(a)
                && O.originPinHash(h.at(ID, 1)) == O.originPinHash(b),
            "seed order"
        );
        h.seed(bytes32(uint256(2)), a, a);
        require(h.count(bytes32(uint256(2))) == 1, "same graph deduplicates");
        require(h.root(ID) == 0, "not sealed early");
        vm.expectRevert(O.InvalidArchiveOrigin.selector);
        h.seed(ID, a, b);
    }

    function testFirstRecordUseAddsOriginAndPreservesExactCapsule() public {
        MultiOriginStateHarness h = new MultiOriginStateHarness();
        address pin = address(new MultiOriginPinFixture());
        h.seed(ID, _origin(pin, 1), _origin(pin, 2));
        (T.Item memory item, O.RecordOrigin memory original) = _record(_origin(pin, 3));
        h.remember(ID, CONTEXT, item, original);
        h.remember(ID, CONTEXT, item, original);
        require(
            h.count(ID) == 3 && O.originPinHash(h.at(ID, 2)) == O.originPinHash(original.producer),
            "first use order and dedup"
        );
        require(
            O.recordOriginHash(h.record(ID, Chains.itemHash(item))) == O.recordOriginHash(original),
            "exact capsule"
        );
    }

    function testCapsuleContextActorOccurrenceAndArchiveCannotBeRebound() public {
        MultiOriginStateHarness h = new MultiOriginStateHarness();
        address pin = address(new MultiOriginPinFixture());
        h.seed(ID, _origin(pin, 1), _origin(pin, 1));
        (T.Item memory item, O.RecordOrigin memory original) = _record(_origin(pin, 2));
        vm.expectRevert(O.InvalidArchiveOrigin.selector);
        h.remember(ID, bytes32(uint256(4)), item, original);
        original.actor = address(0x9999);
        vm.expectRevert(O.InvalidArchiveOrigin.selector);
        h.remember(ID, CONTEXT, item, original);
        original.actor = address(0x1234);
        original.occurrence.position.point.environmentHash = bytes32(uint256(5));
        vm.expectRevert(O.InvalidArchiveOrigin.selector);
        h.remember(ID, CONTEXT, item, original);
        original.occurrence.position.point.environmentHash =
            RH.originHash(original.producer.environment);
        item.sourceRecord = bytes32(uint256(6));
        vm.expectRevert(O.InvalidArchiveOrigin.selector);
        h.remember(ID, CONTEXT, item, original);
        item.sourceRecord = O.evidenceId(original);
        item.source = address(0x9876);
        vm.expectRevert(O.InvalidArchiveOrigin.selector);
        h.remember(ID, CONTEXT, item, original);
        require(h.count(ID) == 1, "all failed admissions roll back");
    }

    function testSameItemCannotOverwriteDifferentCapsule() public {
        MultiOriginStateHarness h = new MultiOriginStateHarness();
        address pin = address(new MultiOriginPinFixture());
        h.seed(ID, _origin(pin, 1), _origin(pin, 1));
        (T.Item memory item, O.RecordOrigin memory original) = _record(_origin(pin, 1));
        h.remember(ID, CONTEXT, item, original);
        bytes32 before_ = O.recordOriginHash(original);
        original.semanticRecordHash = keccak256("different saved record");
        vm.expectRevert(O.InvalidArchiveOrigin.selector);
        h.remember(ID, CONTEXT, item, original);
        require(
            O.recordOriginHash(h.record(ID, Chains.itemHash(item))) == before_, "capsule unchanged"
        );
    }

    function testSeventeenthOriginAcceptedAndEighteenthAtomicallyRejected() public {
        MultiOriginStateHarness h = new MultiOriginStateHarness();
        address pin = address(new MultiOriginPinFixture());
        h.seed(ID, _origin(pin, 1), _origin(pin, 2));
        for (uint256 i = 3; i <= 17; ++i) {
            (T.Item memory item, O.RecordOrigin memory original) = _record(_origin(pin, i));
            h.remember(ID, CONTEXT, item, original);
        }
        (T.Item memory item18, O.RecordOrigin memory original18) = _record(_origin(pin, 18));
        vm.expectRevert(O.ArchiveOriginLimit.selector);
        h.remember(ID, CONTEXT, item18, original18);
        require(
            h.count(ID) == 17 && h.record(ID, Chains.itemHash(item18)).sourceContextHash == 0,
            "bound and rollback"
        );
    }

    function testRuntimeClosureAndSealBindExactOrderedTable() public {
        MultiOriginStateHarness h = new MultiOriginStateHarness();
        address pin = address(new MultiOriginPinFixture());
        O.Origin memory a = _origin(pin, 1);
        O.Origin memory b = _origin(pin, 2);
        h.seed(ID, a, b);
        vm.expectRevert(T.InventoryIncomplete.selector);
        h.seal(ID);
        (T.Item[] memory rows, bytes32 witness) = h.runtime(ID);
        require(rows.length == 10 && witness == O.originPinHash(a), "one bounded graph");
        require(
            rows[0].role == keccak256("ARTIST_ORIGIN_REGISTRY_RUNTIME")
                && rows[2].role == keccak256("ARTIST_ORIGIN_ARCHIVE_RUNTIME"),
            "runtime roles"
        );
        for (uint256 i; i < 10; ++i) {
            require(
                rows[i].kind == T.Kind.CONTRACT_RUNTIME && rows[i].source == pin
                    && rows[i].provenanceHash == witness && rows[i].byteSize == pin.code.length,
                "runtime facts"
            );
            require(
                keccak256(rows[i].digest) == keccak256(abi.encodePacked(pin.codehash)),
                "runtime digest"
            );
        }
        (T.Item memory item, O.RecordOrigin memory original) = _record(_origin(pin, 3));
        vm.expectRevert(O.InvalidArchiveOrigin.selector);
        h.remember(ID, CONTEXT, item, original);
        vm.expectRevert(T.InventoryIncomplete.selector);
        h.seal(ID);
        h.runtime(ID);
        bytes32 chain = O.appendOrigin(O.appendOrigin(0, 0, a), 1, b);
        bytes32 root = h.seal(ID);
        require(
            root == O.sealedOriginSetHash(2, chain) && h.root(ID) == root && h.cursor(ID) == 2,
            "exact seal"
        );
        vm.expectRevert(T.InventoryIncomplete.selector);
        h.runtime(ID);
        vm.expectRevert(T.InventoryIncomplete.selector);
        h.seal(ID);
        vm.expectRevert(O.InvalidArchiveOrigin.selector);
        h.remember(ID, CONTEXT, item, original);
    }

    function testChangedRuntimeRejectsSealThenIdenticalRetrySucceeds() public {
        MultiOriginStateHarness h = new MultiOriginStateHarness();
        address pin = address(new MultiOriginPinFixture());
        O.Origin memory a = _origin(pin, 1);
        h.seed(ID, a, a);
        h.runtime(ID);
        bytes memory originalCode = pin.code;
        vm.etch(pin, hex"60006000f3");
        vm.expectRevert();
        h.seal(ID);
        require(h.root(ID) == 0 && h.cursor(ID) == 1, "failed seal unchanged");
        vm.etch(pin, originalCode);
        require(h.seal(ID) == O.sealedOriginSetHash(1, O.appendOrigin(0, 0, a)), "identical retry");
    }

    function testLateFailureRollsBackTableAndCapsuleBeforeIdenticalRetry() public {
        MultiOriginStateHarness h = new MultiOriginStateHarness();
        address pin = address(new MultiOriginPinFixture());
        h.seed(ID, _origin(pin, 1), _origin(pin, 1));
        (T.Item memory item, O.RecordOrigin memory original) = _record(_origin(pin, 2));
        vm.expectRevert(T.InventoryIncomplete.selector);
        h.rememberThenFailSeal(ID, CONTEXT, item, original);
        require(
            h.count(ID) == 1 && h.record(ID, Chains.itemHash(item)).sourceContextHash == 0,
            "atomic rollback"
        );
        h.remember(ID, CONTEXT, item, original);
        require(
            h.count(ID) == 2
                && O.recordOriginHash(h.record(ID, Chains.itemHash(item)))
                    == O.recordOriginHash(original),
            "identical retry"
        );
    }

    function _origin(address pin, uint256 n) private view returns (O.Origin memory o) {
        o.environment.chainId = block.chainid;
        o.environment.registry = pin;
        o.environment.coordinator = pin;
        o.environment.archive = pin;
        o.environment.core = pin;
        o.environment.manager = pin;
        o.environment.suiteConfigurationHash = keccak256(abi.encode(n));
        o.registryCodeHash = pin.codehash;
        o.coordinatorCodeHash = pin.codehash;
        o.archiveCodeHash = pin.codehash;
        for (uint256 i; i < 7; ++i) {
            o.environment.owners[i] = pin;
            o.environment.ownerCodeHashes[i] = pin.codehash;
        }
    }

    function _record(O.Origin memory producer)
        private
        pure
        returns (T.Item memory item, O.RecordOrigin memory r)
    {
        r.producer = producer;
        r.actor = address(0x1234);
        r.sourceContextHash = CONTEXT;
        r.role = ROLE;
        r.semanticRecordHash = keccak256("saved typed record");
        r.occurrence.position.point.environmentHash = RH.originHash(producer.environment);
        r.occurrence.position.point.ownerIndex = 4;
        r.occurrence.position.point.ownerRevision = 1;
        r.occurrence.receipt.operation = 24;
        r.occurrence.receipt.recordHash = keccak256("receipt");
        item.kind = T.Kind.STATE_BUNDLE;
        item.role = ROLE;
        item.source = producer.environment.archive;
        item.sourceRecord = O.evidenceId(r);
        item.sourceIndex = 1;
        item.algorithm = 1;
        item.canonicalizationId = keccak256("RAW");
        item.digest = abi.encodePacked(keccak256("archive bytes"));
        item.byteSize = 13;
        item.provenanceHash = O.recordOriginHash(r);
    }
}

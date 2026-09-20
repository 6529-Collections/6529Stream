// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    StreamArtistRecoveredPayloadHydration as PH
} from "../../../smart-contracts/domains/artist/StreamArtistRecoveredPayloadHydration.sol";
import {
    StreamArtistPayloadStore as Store
} from "../../../smart-contracts/domains/artist/StreamArtistPayloadStore.sol";
import {
    StreamArtistPayloadSync as Sync
} from "../../../smart-contracts/domains/artist/StreamArtistPayloadSync.sol";
import {
    StreamArtistArchiveV2
} from "../../../smart-contracts/domains/artist/StreamArtistArchiveV2.sol";
import {
    IStreamArtistReconstruction,
    IStreamArtistPayloadArchive
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistReconstruction.sol";
import {
    StreamArtistOnboardingTypes as T
} from "../../../smart-contracts/interfaces/stream/artist/StreamArtistOnboardingTypes.sol";
import { SSTORE2 } from "../../../smart-contracts/libraries/SSTORE2.sol";

interface RecoveredPayloadVm {
    function expectRevert(bytes calldata reason) external;
    function mockCall(address target, bytes calldata input, bytes calldata output) external;
    function mockCallRevert(address target, bytes calldata input, bytes calldata reason) external;
    function clearMockedCalls() external;
    function etch(address target, bytes calldata code) external;
}

/// @dev Actual carrier store with a narrow test-only semantic writer. This is not an authority owner.
contract RecoveredPayloadOwner {
    address public immutable coordinator;

    constructor(address coordinator_) {
        coordinator = coordinator_;
    }

    function put(bytes32 kind, bytes calldata data) external returns (address) {
        return Store.store(kind, data);
    }

    function putRecord(bytes calldata data) external returns (bytes32 hash) {
        hash = keccak256(data);
        Store.preimage(hash, data);
    }

    function importRows(uint8 ownerIndex, PH.Row[] memory rows) external {
        require(msg.sender == coordinator, "fixed fixture coordinator");
        PH.applyCatalog(ownerIndex, rows);
    }

    function recordPreimageBytes(bytes32 hash) external view returns (bytes memory) {
        return Store.recordBytes(hash);
    }

    function storedPayloadCount() external view returns (uint256) {
        return Store.count();
    }

    function storedPayloadAt(uint256 index) external view returns (address, bytes32, bytes32) {
        return Store.at(index);
    }
}

/// @dev Real Archive and original sync; source admission/semantic hydration are outside this fixture.
contract RecoveredPayloadCoordinator {
    T.SuiteConfiguration private suite;
    StreamArtistArchiveV2 public immutable archive;
    uint256 public completed;

    error LateFailure();

    constructor() {
        archive = new StreamArtistArchiveV2(address(0x6529), address(this));
        suite.archive = address(archive);
        for (uint8 i = 2; i < 7; i += 2) {
            suite.owners[i] = address(new RecoveredPayloadOwner(address(this)));
        }
    }

    function owner(uint8 index) external view returns (RecoveredPayloadOwner) {
        return RecoveredPayloadOwner(suite.owners[index]);
    }

    function hydrate(address source, uint8 index, PH.Row[] memory rows, bool fail) external {
        PH.requireSource(source, index, rows);
        RecoveredPayloadOwner(suite.owners[index]).importRows(index, rows);
        PH.requireSource(source, index, rows);
        Sync.sync(suite);
        ++completed;
        if (fail) revert LateFailure();
    }

    function hydrateAndChangeSource(address source, PH.Row[] memory rows) external {
        PH.requireSource(source, 2, rows);
        RecoveredPayloadOwner(suite.owners[2]).importRows(2, rows);
        RecoveredPayloadOwner(source).put(keccak256("changed source"), hex"01");
        PH.requireSource(source, 2, rows);
        Sync.sync(suite);
        ++completed;
    }

    function sync() external {
        Sync.sync(suite);
    }
}

/// @notice Component regressions over original PayloadStore/SSTORE2/Archive and sync producers.
/// @dev Authenticated seven-owner source admission and full Safe operation60 remain separate tests.
contract StreamArtistRecoveredPayloadHydrationTest {
    RecoveredPayloadVm private constant vm =
        RecoveredPayloadVm(address(uint160(uint256(keccak256("hevm cheat code")))));
    bytes32 private constant RECORD = keccak256("ARTIST_RECORD_PREIMAGE");
    bytes32 private constant DOCUMENT = keccak256("ARTIST_IDENTITY_DOCUMENT");
    RecoveredPayloadOwner private source;
    RecoveredPayloadCoordinator private destination;

    error CatalogFailure();
    error AncestorRead();

    function setUp() public {
        source = new RecoveredPayloadOwner(address(this));
        destination = new RecoveredPayloadCoordinator();
    }

    function testOriginalPreimageAndEveryCatalogRowReachCurrentArchive() public {
        bytes memory original =
            abi.encode("original record", block.chainid, address(0xA), uint64(91));
        bytes32 record = source.putRecord(original);
        source.put(DOCUMENT, hex"010203");
        PH.Row[] memory rows = PH.collect(address(source), 2);
        destination.hydrate(address(source), 2, rows, false);
        _same(rows, PH.collect(address(destination.owner(2)), 2));
        _archive(rows, destination.archive());
        require(
            keccak256(destination.owner(2).recordPreimageBytes(record)) == record, "owner bytes"
        );
        require(
            keccak256(destination.archive().recordPreimageBytes(record)) == keccak256(original),
            "archive original domain bytes"
        );
    }

    function testAllThreeOriginalCatalogOwnersSyncAndRepeatedSyncIsIdempotent() public {
        for (uint8 i = 2; i < 7; i += 2) {
            RecoveredPayloadOwner original = new RecoveredPayloadOwner(address(this));
            original.putRecord(abi.encode(i, "actual catalog"));
            PH.Row[] memory rows = PH.collect(address(original), i);
            destination.hydrate(address(original), i, rows, false);
            _same(rows, PH.collect(address(destination.owner(i)), i));
        }
        require(destination.archive().storedPayloadCount() == 3, "all supported owners");
        destination.sync();
        require(destination.archive().storedPayloadCount() == 3, "sync cursor retained");
    }

    function testRepeatedImportFlattensOriginalPointersAndKeepsNewLocalSuffix() public {
        bytes memory original = abi.encode("A original registry", address(0xA), uint256(35));
        bytes32 a = source.putRecord(original);
        PH.Row[] memory first = PH.collect(address(source), 2);
        destination.hydrate(address(source), 2, first, false);
        RecoveredPayloadOwner middle = destination.owner(2);
        bytes32 b =
            middle.putRecord(abi.encode("B original registry", address(destination), uint256(32)));
        // Re-storing imported semantic payloads reuses the original pointer and index.
        middle.putRecord(original);
        require(middle.storedPayloadCount() == 2, "deduped imported payload");
        vm.mockCallRevert(
            address(source),
            abi.encodeWithSignature("storedPayloadCount()"),
            abi.encodeWithSelector(AncestorRead.selector)
        );
        vm.mockCallRevert(
            address(source),
            abi.encodeWithSignature("storedPayloadAt(uint256)", uint256(0)),
            abi.encodeWithSelector(AncestorRead.selector)
        );
        PH.Row[] memory second = PH.collect(address(middle), 2);
        RecoveredPayloadCoordinator last = new RecoveredPayloadCoordinator();
        last.hydrate(address(middle), 2, second, false);
        require(second[0].pointer == first[0].pointer, "ultimate A pointer");
        _same(second, PH.collect(address(last.owner(2)), 2));
        _archive(second, last.archive());
        require(keccak256(last.archive().recordPreimageBytes(a)) == a, "A preimage");
        require(keccak256(last.archive().recordPreimageBytes(b)) == b, "B preimage");
    }

    function testMissingReorderedAndSubstitutedSourceRowsReject() public {
        source.putRecord(hex"01");
        source.put(DOCUMENT, hex"02");
        PH.Row[] memory rows = PH.collect(address(source), 2);
        PH.Row[] memory omitted = new PH.Row[](1);
        omitted[0] = rows[0];
        vm.expectRevert(
            abi.encodeWithSelector(PH.InvalidRecoveredPayloadCatalog.selector, uint8(2))
        );
        this.requireSource(address(source), 2, omitted);
        (rows[0], rows[1]) = (rows[1], rows[0]);
        vm.expectRevert(abi.encodeWithSelector(PH.InvalidRecoveredPayloadRow.selector, uint256(0)));
        this.requireSource(address(source), 2, rows);
        rows = PH.collect(address(source), 2);
        // A valid equal-content carrier is still not the actual source row.
        rows[0].pointer = SSTORE2.write(hex"01");
        vm.expectRevert(abi.encodeWithSelector(PH.InvalidRecoveredPayloadRow.selector, uint256(0)));
        this.requireSource(address(source), 2, rows);
        require(destination.owner(2).storedPayloadCount() == 0, "no partial destination writes");
    }

    function testDuplicateContentKeysRejectEvenWithDifferentPointers() public {
        PH.Row[] memory rows = new PH.Row[](2);
        rows[0] = PH.Row(SSTORE2.write(hex"01"), RECORD, keccak256(hex"01"));
        rows[1] = PH.Row(SSTORE2.write(hex"01"), RECORD, keccak256(hex"01"));
        vm.expectRevert(
            abi.encodeWithSelector(PH.InvalidRecoveredPayloadCatalog.selector, uint8(2))
        );
        this.shape(2, rows);
        rows[1].payloadType = DOCUMENT;
        this.shape(2, rows);
        source.importRows(2, rows);
        require(source.storedPayloadCount() == 2, "different type is a different content key");
    }

    function testSourceGetterCannotConcealDuplicateRows() public {
        source.putRecord(hex"01");
        PH.Row[] memory rows = PH.collect(address(source), 2);
        vm.mockCall(
            address(source), abi.encodeWithSignature("storedPayloadCount()"), abi.encode(uint256(2))
        );
        vm.mockCall(
            address(source),
            abi.encodeWithSignature("storedPayloadAt(uint256)", uint256(1)),
            abi.encode(rows[0].pointer, rows[0].payloadType, rows[0].payloadHash)
        );
        vm.expectRevert(
            abi.encodeWithSelector(PH.InvalidRecoveredPayloadCatalog.selector, uint8(2))
        );
        this.collect(address(source), 2);
    }

    function testOnlyCatalogOwnersCanCarryRowsAndOtherOwnersNeedNoGetter() public {
        source.putRecord(hex"01");
        PH.Row[] memory rows = PH.collect(address(source), 2);
        for (uint8 i; i < 7; ++i) {
            if (i == 2 || i == 4 || i == 6) continue;
            require(PH.collect(address(0xBEEF), i).length == 0, "no nonexistent owner getter");
            PH.requireSource(address(0xBEEF), i, new PH.Row[](0));
            vm.expectRevert(abi.encodeWithSelector(PH.InvalidRecoveredPayloadCatalog.selector, i));
            this.shape(i, rows);
        }
        vm.expectRevert(
            abi.encodeWithSelector(PH.InvalidRecoveredPayloadCatalog.selector, uint8(7))
        );
        this.shape(7, new PH.Row[](0));
    }

    function testFiniteTransportCapRejectsBeforeSourceRowReads() public {
        vm.mockCall(
            address(source),
            abi.encodeWithSignature("storedPayloadCount()"),
            abi.encode(uint256(16_385))
        );
        vm.expectRevert(
            abi.encodeWithSelector(PH.InvalidRecoveredPayloadCatalog.selector, uint8(2))
        );
        this.collect(address(source), 2);
        PH.Row[] memory rows = new PH.Row[](16_385);
        vm.expectRevert(
            abi.encodeWithSelector(PH.InvalidRecoveredPayloadCatalog.selector, uint8(2))
        );
        this.shape(2, rows);
    }

    function testZeroFieldsInvalidPointersAndChangedContentReject() public {
        PH.Row[] memory rows = new PH.Row[](1);
        vm.expectRevert(abi.encodeWithSelector(PH.InvalidRecoveredPayloadRow.selector, uint256(0)));
        this.shape(2, rows);
        rows[0] = PH.Row(address(0xBEEF), RECORD, keccak256(hex"01"));
        vm.expectRevert(
            abi.encodeWithSelector(SSTORE2.SSTORE2InvalidPointer.selector, address(0xBEEF))
        );
        source.importRows(2, rows);
        rows[0].pointer = SSTORE2.write(hex"02");
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamArtistReconstruction.ArtistPayloadCorrupted.selector,
                keccak256(hex"01"),
                keccak256(hex"02")
            )
        );
        source.importRows(2, rows);
        require(source.storedPayloadCount() == 0, "invalid carriers not installed");
    }

    function testCorruptOriginalCarrierFailsCollectAndPostWriteRecheckThenRestores() public {
        source.putRecord(hex"01");
        PH.Row[] memory rows = PH.collect(address(source), 2);
        bytes memory originalCode = rows[0].pointer.code;
        vm.etch(rows[0].pointer, hex"0002");
        bytes memory expected = abi.encodeWithSelector(
            IStreamArtistReconstruction.ArtistPayloadCorrupted.selector,
            keccak256(hex"01"),
            keccak256(hex"02")
        );
        vm.expectRevert(expected);
        this.collect(address(source), 2);
        vm.expectRevert(expected);
        this.requireSource(address(source), 2, rows);
        vm.etch(rows[0].pointer, originalCode);
        destination.hydrate(address(source), 2, rows, false);
        _archive(rows, destination.archive());
    }

    function testSourceCatalogGrowthDuringImportRollsBackBothSides() public {
        source.putRecord(hex"01");
        PH.Row[] memory rows = PH.collect(address(source), 2);
        vm.expectRevert(
            abi.encodeWithSelector(PH.InvalidRecoveredPayloadCatalog.selector, uint8(2))
        );
        destination.hydrateAndChangeSource(address(source), rows);
        require(source.storedPayloadCount() == 1, "source callback rolled back");
        require(destination.owner(2).storedPayloadCount() == 0, "destination catalog rolled back");
        require(destination.archive().storedPayloadCount() == 0, "archive unchanged");
        destination.hydrate(address(source), 2, rows, false);
        _archive(rows, destination.archive());
    }

    function testArchiveSyncFailureAndLateFailureRollbackThenExactRetry() public {
        source.putRecord(hex"01");
        PH.Row[] memory rows = PH.collect(address(source), 2);
        vm.mockCallRevert(
            address(destination.archive()),
            abi.encodePacked(IStreamArtistPayloadArchive.registerArtistStoredPayload.selector),
            abi.encodeWithSelector(CatalogFailure.selector)
        );
        vm.expectRevert(abi.encodeWithSelector(CatalogFailure.selector));
        destination.hydrate(address(source), 2, rows, false);
        require(destination.owner(2).storedPayloadCount() == 0, "sync failure owner rollback");
        require(destination.archive().storedPayloadCount() == 0, "sync failure archive rollback");
        vm.clearMockedCalls();
        vm.expectRevert(abi.encodeWithSelector(RecoveredPayloadCoordinator.LateFailure.selector));
        destination.hydrate(address(source), 2, rows, true);
        require(
            destination.owner(2).storedPayloadCount() == 0 && destination.completed() == 0,
            "late owner rollback"
        );
        require(destination.archive().storedPayloadCount() == 0, "late archive rollback");
        destination.hydrate(address(source), 2, rows, false);
        require(destination.completed() == 1, "retry completed");
        _archive(rows, destination.archive());
    }

    function collect(address owner, uint8 index) external view returns (PH.Row[] memory) {
        return PH.collect(owner, index);
    }

    function shape(uint8 index, PH.Row[] memory rows) external pure {
        PH.validateShape(index, rows);
    }

    function requireSource(address owner, uint8 index, PH.Row[] memory rows) external view {
        PH.requireSource(owner, index, rows);
    }

    function _same(PH.Row[] memory expected, PH.Row[] memory actual) private pure {
        require(
            keccak256(abi.encode(expected)) == keccak256(abi.encode(actual)),
            "exact pointer/type/hash order"
        );
    }

    function _archive(PH.Row[] memory rows, StreamArtistArchiveV2 archive) private view {
        require(archive.storedPayloadCount() == rows.length, "complete archive catalog");
        for (uint256 i; i < rows.length; ++i) {
            (address pointer, bytes32 kind, bytes32 hash) = archive.storedPayloadAt(i);
            require(
                pointer == rows[i].pointer && kind == rows[i].payloadType
                    && hash == rows[i].payloadHash,
                "original archive row"
            );
            require(keccak256(SSTORE2.read(pointer)) == hash, "exact original bytes");
        }
    }
}

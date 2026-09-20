// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    StreamArtistRecoveredHydrationTypes as RH
} from "../../../smart-contracts/interfaces/stream/artist/StreamArtistRecoveredHydrationTypes.sol";
import {
    StreamArtistOnboardingTypes as T
} from "../../../smart-contracts/interfaces/stream/artist/StreamArtistOnboardingTypes.sol";
import {
    StreamArtistHistoryTypes as H
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistHistory.sol";
import {
    IStreamArtistAuthorityCheckpoint as CP
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistAuthorityCheckpoint.sol";
import {
    IStreamArtistImportedReceiptRead as API
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistImportedReceiptRead.sol";
import {
    StreamArtistRecoveredHydrationState as Imported
} from "../../../smart-contracts/domains/artist/StreamArtistRecoveredHydrationState.sol";
import {
    StreamArtistRecoveredOwnerReads as Reads
} from "../../../smart-contracts/domains/artist/StreamArtistRecoveredOwnerReads.sol";
import {
    StreamArtistOwnerHydration as Original
} from "../../../smart-contracts/domains/artist/StreamArtistOwnerHydration.sol";
import {
    StreamArtistNativeReceipts as Native
} from "../../../smart-contracts/domains/artist/StreamArtistNativeReceipts.sol";

/// @dev Real immutable-prefix installation/read dispatch in a synthetic owner host. The only
/// direct namespace writes are explicitly named corruption controls below. This is not a full
/// owner authorization, original-source authentication, Coordinator or operation60 flow test.
contract ImportedReceiptReadHarness {
    bytes32 private constant IMPORTED_SLOT =
        keccak256("6529STREAM_ARTIST_RECOVERED_HYDRATION_STATE_V1");
    bytes32 private constant REPLAY_KEY = keccak256("unrelated actual replay cell");
    address public constant CURRENT_REGISTRY = address(9001);
    uint256 public firstSentinel = 17;
    mapping(bytes32 => T.ReplayCell) private _replay;
    uint256 public secondSentinel = 29;
    uint8 private immutable _bindingOwner;

    constructor(uint8 bindingOwner) {
        _bindingOwner = bindingOwner;
        _replay[REPLAY_KEY] = T.ReplayCell(keccak256("unchanged replay commitment"), 7, 1, 2);
    }

    function install(
        RH.OwnerProvenance memory prefix,
        uint8 storedOwner,
        bytes32 commitment,
        uint64 importRevision
    ) external {
        Imported.installOwnerPrefix(prefix, storedOwner, commitment, importRevision);
    }

    function appendNative(H.Receipt calldata receipt, uint64 revision) external {
        Native.record(
            receipt.operation, receipt.recordHash, receipt.artistId, receipt.collectionId, revision
        );
    }

    function recoveredHydrationImportedReceiptAt(uint256)
        external
        view
        returns (RH.JournalEntry memory, bytes32, uint64)
    {
        // Same fixed worker and terminal ABI return used by StreamArtistOwner; the binding is
        // test-local so this does not claim to exercise a concrete production owner constructor.
        bytes memory result = Reads.read(
            _replay,
            Original.Binding(
                CURRENT_REGISTRY, address(9002), address(9003), RH.ownerDomain(_bindingOwner)
            ),
            0,
            msg.data
        );
        assembly ("memory-safe") { return(add(result, 32), mload(result)) }
    }

    function observedState() external view returns (bytes32) {
        bytes32 nativeHash;
        for (uint256 i; i < Native.count(); ++i) {
            nativeHash = keccak256(abi.encode(nativeHash, Native.at(i), Native.revisionAt(i)));
        }
        return keccak256(
            abi.encode(
                Imported.importedPrefix(),
                Imported.commitment(),
                Imported.importedAtRevision(),
                firstSentinel,
                secondSentinel,
                _replay[REPLAY_KEY],
                Native.count(),
                nativeHash
            )
        );
    }

    function corruptHeader(bytes32 commitment, bytes32 profile, uint64 revision, uint8 owner)
        external
    {
        Imported.State storage s = _imported();
        s.commitment = commitment;
        s.profile = profile;
        s.importedAtRevision = revision;
        s.ownerIndex = owner;
    }

    function corruptOriginIndex(bytes32 origin, uint256 plus) external {
        _imported().originIndexPlusOne[origin] = plus;
    }

    function corruptOrigin(uint256 index, RH.OriginEnvironment calldata origin) external {
        _imported().origins[index] = origin;
    }

    function corruptEra(uint256 index, RH.OwnerEra calldata era) external {
        _imported().eras[index] = era;
    }

    function corruptEntry(uint256 index, RH.JournalEntry calldata entry) external {
        _imported().journal[index] = entry;
    }

    function _imported() private pure returns (Imported.State storage s) {
        bytes32 slot = IMPORTED_SLOT;
        assembly ("memory-safe") { s.slot := slot }
    }
}

/// @notice Genuine installed-state/dispatch tests with synthetic structurally valid origins.
/// No mocked successful getter, source admission, Archive membership or full Safe-flow claim.
contract StreamArtistImportedReceiptReadTest {
    bytes32 private constant COMMITMENT = keccak256("saved complete import commitment");
    uint64 private constant IMPORT_REVISION = 3;
    bytes32 private constant ARTIST = keccak256("selected synthetic artist");
    uint256 private constant COLLECTION = 77;
    ImportedReceiptReadHarness private host;

    function setUp() public {
        host = new ImportedReceiptReadHarness(4);
    }

    function testImportedReceiptExact320ByteTupleAndOriginalCoordinates() public {
        RH.OwnerProvenance memory p = _prefix(4);
        _install(host, p, 4);
        for (uint256 i; i < p.journal.length; ++i) {
            _assertReceipt(host, i, p.journal[i]);
        }
        // Old local90 and newer local5 retain separate environments; the destination's actual
        // import revision3 neither rebases nor replaces either original source coordinate.
        require(p.journal[0].position.point.ownerRevision == 90, "original high revision");
        require(p.journal[2].position.point.ownerRevision == 5, "later low revision");
    }

    function testImportedReceiptRepeatedHashKeepsDistinctOriginsAndNativeIndices() public {
        RH.OwnerProvenance memory p = _prefix(4);
        p.journal[2].receipt = p.journal[1].receipt;
        _install(host, p, 4);
        _assertReceipt(host, 1, p.journal[1]);
        _assertReceipt(host, 2, p.journal[2]);
        require(
            p.journal[1].position.point.environmentHash
                != p.journal[2].position.point.environmentHash,
            "two original environments"
        );
        require(
            p.journal[1].position.nativeIndex == 1 && p.journal[2].position.nativeIndex == 0,
            "original local index is not imported index"
        );
    }

    function testImportedReceiptNativeOnlyOwnerNeverFallsBackToItsLocalJournal() public {
        _reject(host, 0);
        host.appendNative(H.Receipt(24, ARTIST, COLLECTION, keccak256("actual native receipt")), 1);
        bytes32 before_ = host.observedState();
        _reject(host, 0);
        _reject(host, 1);
        require(host.observedState() == before_, "native journal unchanged");
    }

    function testImportedReceiptRejectsPastEndAndMaximumIndexWithoutMutation() public {
        RH.OwnerProvenance memory p = _prefix(4);
        _install(host, p, 4);
        bytes32 before_ = host.observedState();
        _reject(host, p.journal.length);
        _reject(host, type(uint256).max);
        _assertReceipt(host, p.journal.length - 1, p.journal[p.journal.length - 1]);
        require(host.observedState() == before_, "failed reads leave exact installed state");
    }

    function testImportedReceiptRejectsAbsentMarkersWrongProfileAndStoredOwner() public {
        RH.OwnerProvenance memory p = _prefix(4);
        _install(host, p, 4);
        host.corruptHeader(0, RH.PROFILE, IMPORT_REVISION, 4);
        _reject(host, 0);
        host.corruptHeader(COMMITMENT, keccak256("unsupported profile"), IMPORT_REVISION, 4);
        _reject(host, 0);
        host.corruptHeader(COMMITMENT, RH.PROFILE, 0, 4);
        _reject(host, 0);
        host.corruptHeader(COMMITMENT, RH.PROFILE, IMPORT_REVISION, 6);
        _reject(host, 0);
        host.corruptHeader(COMMITMENT, RH.PROFILE, IMPORT_REVISION, 7);
        _reject(host, 0);
        host.corruptHeader(COMMITMENT, RH.PROFILE, IMPORT_REVISION, 4);
        _assertReceipt(host, 0, p.journal[0]);
    }

    function testImportedReceiptRejectsDifferentActualReadBindingOwner() public {
        ImportedReceiptReadHarness content = new ImportedReceiptReadHarness(6);
        _install(content, _prefix(4), 4);
        _reject(content, 0);
    }

    function testImportedReceiptRejectsMissingMisindexedAndMismatchedOriginEra() public {
        RH.OwnerProvenance memory p = _prefix(4);
        _install(host, p, 4);
        bytes32 origin = p.eras[0].originHash;
        host.corruptOriginIndex(origin, 0);
        _reject(host, 0);
        host.corruptOriginIndex(origin, p.eras.length + 1);
        _reject(host, 0);
        host.corruptOriginIndex(origin, 2);
        _reject(host, 0);
        host.corruptOriginIndex(origin, 1);
        RH.OwnerEra memory era = abi.decode(abi.encode(p.eras[0]), (RH.OwnerEra));
        era.originHash = keccak256("different stored era");
        host.corruptEra(0, era);
        _reject(host, 0);
        host.corruptEra(0, p.eras[0]);
        _assertReceipt(host, 0, p.journal[0]);
    }

    function testImportedReceiptRejectsCurrentRegistryRelabeledAsImportedOrigin() public {
        RH.OwnerProvenance memory p = _prefix(4);
        _install(host, p, 4);
        RH.OriginEnvironment memory origin = p.origins[0];
        origin.registry = host.CURRENT_REGISTRY();
        host.corruptOrigin(0, origin);
        _reject(host, 0);
    }

    function testImportedReceiptRejectsRowOwnerOriginAndNativeIndexOutsideEra() public {
        RH.OwnerProvenance memory p = _prefix(4);
        _install(host, p, 4);
        RH.JournalEntry memory entry = _copy(p.journal[0]);
        entry.position.point.ownerIndex = 6;
        host.corruptEntry(0, entry);
        _reject(host, 0);
        entry = _copy(p.journal[0]);
        entry.position.point.environmentHash = keccak256("unknown imported origin");
        host.corruptEntry(0, entry);
        _reject(host, 0);
        entry = _copy(p.journal[0]);
        entry.position.nativeIndex = p.eras[0].nativeCount;
        host.corruptEntry(0, entry);
        _reject(host, 0);
        entry.position.nativeIndex = type(uint256).max;
        host.corruptEntry(0, entry);
        _reject(host, 0);
        host.corruptEntry(0, p.journal[0]);
        _assertReceipt(host, 0, p.journal[0]);
    }

    function testImportedReceiptEnforcesExclusiveLowerAndInclusiveUpperRevision() public {
        RH.OwnerProvenance memory p = _prefix(4);
        _install(host, p, 4);
        RH.JournalEntry memory entry = _copy(p.journal[2]);
        entry.position.point.ownerRevision = 0;
        host.corruptEntry(2, entry);
        _reject(host, 2);
        entry.position.point.ownerRevision = p.eras[1].lowerRevision;
        host.corruptEntry(2, entry);
        _reject(host, 2);
        entry.position.point.ownerRevision = p.eras[1].checkpoint.ownerState.revision + 1;
        host.corruptEntry(2, entry);
        _reject(host, 2);
        entry.position.point.ownerRevision = p.eras[1].checkpoint.ownerState.revision;
        host.corruptEntry(2, entry);
        _assertReceipt(host, 2, entry);
    }

    function testImportedReceiptRejectsZeroStoredOperationAndRecord() public {
        RH.OwnerProvenance memory p = _prefix(4);
        _install(host, p, 4);
        RH.JournalEntry memory entry = _copy(p.journal[0]);
        entry.receipt.operation = 0;
        host.corruptEntry(0, entry);
        _reject(host, 0);
        entry = _copy(p.journal[0]);
        entry.receipt.recordHash = 0;
        host.corruptEntry(0, entry);
        _reject(host, 0);
        host.corruptEntry(0, p.journal[0]);
        _assertReceipt(host, 0, p.journal[0]);
    }

    function testImportedReceiptReadsPreservePrefixReplayNativeAndOrdinarySentinels() public {
        RH.OwnerProvenance memory p = _prefix(4);
        _install(host, p, 4);
        host.appendNative(H.Receipt(24, ARTIST, COLLECTION, keccak256("later local record")), 4);
        bytes32 before_ = host.observedState();
        _assertReceipt(host, 2, p.journal[2]);
        _assertReceipt(host, 0, p.journal[0]);
        _assertReceipt(host, 2, p.journal[2]);
        _reject(host, 3);
        require(host.observedState() == before_, "all observed state preserved");
        require(host.firstSentinel() == 17 && host.secondSentinel() == 29, "ordinary slots");
    }

    function testFuzzImportedReceiptTypedRolesAndIndex(uint8 selector, uint256 index) public {
        uint8 owner = selector % 2 == 0 ? 4 : 6;
        ImportedReceiptReadHarness selected = new ImportedReceiptReadHarness(owner);
        RH.OwnerProvenance memory p = _prefix(owner);
        _install(selected, p, owner);
        uint256 valid = index % p.journal.length;
        bytes32 before_ = selected.observedState();
        _assertReceipt(selected, valid, p.journal[valid]);
        if (index >= p.journal.length) _reject(selected, index);
        require(selected.observedState() == before_, "fuzz reads remain read-only");
    }

    function _install(ImportedReceiptReadHarness target, RH.OwnerProvenance memory p, uint8 owner)
        private
    {
        target.install(p, owner, COMMITMENT, IMPORT_REVISION);
    }

    function _assertReceipt(
        ImportedReceiptReadHarness target,
        uint256 index,
        RH.JournalEntry memory expected
    ) private view {
        (bool ok, bytes memory raw) = address(target)
            .staticcall(abi.encodeCall(API.recoveredHydrationImportedReceiptAt, (index)));
        require(ok, "actual imported read succeeds");
        require(raw.length == 320, "exact ten-word return, no outer bytes wrapper");
        require(
            keccak256(raw) == keccak256(abi.encode(expected, COMMITMENT, IMPORT_REVISION)),
            "byte-exact stored row, commitment and local import revision"
        );
        (RH.JournalEntry memory got, bytes32 commitment, uint64 at) =
            API(address(target)).recoveredHydrationImportedReceiptAt(index);
        require(
            keccak256(abi.encode(got)) == keccak256(abi.encode(expected))
                && commitment == COMMITMENT && at == IMPORT_REVISION,
            "typed caller sees the declared tuple"
        );
    }

    function _reject(ImportedReceiptReadHarness target, uint256 index) private view {
        (bool ok, bytes memory reason) = address(target)
            .staticcall(abi.encodeCall(API.recoveredHydrationImportedReceiptAt, (index)));
        require(!ok, "invalid imported row rejected");
        require(
            keccak256(reason)
                == keccak256(
                    abi.encodeWithSelector(RH.InvalidRecoveredHydrationProvenance.selector)
                ),
            "exact provenance failure, not panic or unknown selector"
        );
    }

    function _copy(RH.JournalEntry memory entry) private pure returns (RH.JournalEntry memory) {
        // Independent memory object so a negative case cannot mutate the later positive oracle.
        return abi.decode(abi.encode(entry), (RH.JournalEntry));
    }

    function _prefix(uint8 owner) private pure returns (RH.OwnerProvenance memory p) {
        p.origins = new RH.OriginEnvironment[](2);
        p.eras = new RH.OwnerEra[](2);
        p.journal = new RH.JournalEntry[](3);
        p.aliases = new RH.ReplayAlias[](0);
        for (uint256 i; i < 2; ++i) {
            RH.OriginEnvironment memory origin;
            origin.chainId = 1;
            origin.registry = address(uint160(100 + i * 100));
            origin.coordinator = address(uint160(101 + i * 100));
            origin.archive = address(uint160(102 + i * 100));
            origin.core = address(500);
            origin.manager = address(501);
            origin.suiteConfigurationHash = bytes32(600 + i);
            for (uint8 j; j < 7; ++j) {
                origin.owners[j] = address(uint160(110 + i * 100 + j));
                origin.ownerCodeHashes[j] = bytes32(uint256(700) + i * 100 + j);
            }
            CP.Checkpoint memory cp;
            cp.schema = RH.CHECKPOINT;
            cp.ownerState = T.Snapshot(
                RH.ownerDomain(owner),
                i == 0 ? uint64(100) : uint64(8),
                bytes32(800 + i),
                bytes32(900 + i)
            );
            p.origins[i] = origin;
            p.eras[i] = RH.OwnerEra(
                RH.originHash(origin),
                cp,
                i == 0 ? 2 : 1,
                i == 0 ? uint64(0) : uint64(3),
                i == 0 ? bytes32(0) : keccak256("actual earlier import commitment")
            );
        }
        for (uint256 i; i < 3; ++i) {
            bool first = i < 2;
            p.journal[i] = RH.JournalEntry(
                RH.Position(
                    RH.Point(
                        p.eras[first ? 0 : 1].originHash, owner, first ? uint64(90 + i) : uint64(5)
                    ),
                    first ? i : 0
                ),
                H.Receipt(owner == 4 ? 24 : 17, ARTIST, COLLECTION, bytes32(1000 + i))
            );
        }
    }
}

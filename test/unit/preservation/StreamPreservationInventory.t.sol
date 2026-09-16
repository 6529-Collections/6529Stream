// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../../../smart-contracts/domains/preservation/StreamPreservationInventoryChains.sol";
import "../../../smart-contracts/domains/preservation/StreamPreservationTypedReferences.sol";
import {
    StreamPreservationInventoryItems as Items
} from "../../../smart-contracts/domains/preservation/StreamPreservationInventoryItems.sol";

interface InventoryVm {
    function expectRevert() external;
}

/// @notice Independent finite-chain arithmetic and complete typed-field walk controls.
/// @dev Pure/source correspondence only; actual source and coverage hosts are separate tests.
contract StreamPreservationInventoryTest {
    InventoryVm private constant vm =
        InventoryVm(address(uint160(uint256(keccak256("hevm cheat code")))));
    bytes32 private constant KEY = keccak256("segment");
    bytes32 private constant RECORD = keccak256("original");

    function testFuzzInMemorySegmentMatchesOriginalPublic(uint8 count, bytes32 salt) public pure {
        T.Item[] memory rows = new T.Item[](uint256(count) % 33);
        for (uint256 i; i < rows.length; ++i) {
            rows[i] = _item();
            rows[i].sourceIndex = i;
            rows[i].provenanceHash = keccak256(abi.encode(salt, i));
            rows[i].uri = string(abi.encodePacked("urn:original:", salt));
        }
        T.Segment memory original = StreamPreservationInventoryChains.segment(KEY, RECORD, rows);
        T.Segment memory current =
            StreamPreservationInventoryChains.segmentInMemory(KEY, RECORD, rows);
        require(
            keccak256(abi.encode(original)) == keccak256(abi.encode(current)),
            "exact original chain"
        );
    }

    function testInMemorySegmentRejectsOriginalInvalidKeyAndWitness() public {
        vm.expectRevert();
        this.inMemorySegmentForTest(0, RECORD);
        vm.expectRevert();
        this.inMemorySegmentForTest(KEY, 0);
        T.Segment memory empty = this.inMemorySegmentForTest(KEY, RECORD);
        require(empty.itemCount == 0 && empty.firstLink == 0, "same explicit empty segment");
    }

    function testFuzzSegmentScratchPreservesAliasesAndLaterAllocation(uint8 count, bytes32 salt)
        public
        pure
    {
        _scratchParity(uint256(count) % 65, salt);
    }

    function testSegmentScratchPreservesFourHundredSeventyNineOccurrences() public pure {
        _scratchParity(479, keccak256("complete reference occurrence count"));
    }

    function _scratchParity(uint256 count, bytes32 salt) private pure {
        bytes memory shared = abi.encodePacked(salt, bytes1(0), salt, bytes1(0xff), salt);
        T.Item[] memory rows = new T.Item[](count);
        for (uint256 i; i < count; ++i) {
            rows[i] = _item();
            rows[i].sourceIndex = i;
            rows[i].uri = string(shared);
            rows[i].digest = shared;
            rows[i].provenanceHash = keccak256(abi.encode(salt, i));
        }
        bytes memory originalRows = abi.encode(rows);
        bytes32 originalRowsHash = keccak256(originalRows);
        bytes32 originalSharedHash = keccak256(shared);
        T.Segment memory original = StreamPreservationInventoryChains.segment(KEY, RECORD, rows);
        uint256 before_;
        assembly ("memory-safe") { before_ := mload(0x40) }
        T.Segment memory current =
            StreamPreservationInventoryChains.segmentInMemory(KEY, RECORD, rows);
        uint256 after_;
        assembly ("memory-safe") { after_ := mload(0x40) }
        require(after_ >= before_ && after_ - before_ <= 256, "only returned segment retained");
        // This deliberately overwrites the reclaimed hash buffers after checking Solidity's
        // ordinary zero-initialized allocation. All input aliases and return data must survive.
        bytes memory later = new bytes(4096);
        for (uint256 i; i < later.length; ++i) {
            require(later[i] == 0, "later allocation starts zero");
            later[i] = bytes1(uint8(i));
        }
        require(keccak256(originalRows) == originalRowsHash, "earlier encoded bytes retained");
        require(keccak256(shared) == originalSharedHash, "aliased bytes retained");
        require(keccak256(abi.encode(rows)) == originalRowsHash, "complete ordered inputs retained");
        require(
            keccak256(abi.encode(current)) == keccak256(abi.encode(original)),
            "literal original public chain retained after reuse"
        );
    }

    function inMemorySegmentForTest(bytes32 key, bytes32 witness)
        external
        pure
        returns (T.Segment memory)
    {
        return StreamPreservationInventoryChains.segmentInMemory(key, witness, new T.Item[](0));
    }

    function testLiteralBackwardsChainAndRepeatedOccurrence() public pure {
        T.Item[] memory rows = new T.Item[](3);
        rows[0] = _item();
        rows[1] = _item();
        rows[2] = _item();
        T.Segment memory segment = StreamPreservationInventoryChains.segment(KEY, RECORD, rows);
        bytes32 next;
        for (uint256 i = 3; i != 0;) {
            --i;
            bytes32 item =
                keccak256(abi.encode(keccak256("6529STREAM_PRESERVATION_ITEM_V1"), rows[i]));
            next = keccak256(
                abi.encode(
                    keccak256("6529STREAM_PRESERVATION_ITEM_LINK_V1"),
                    KEY,
                    uint64(3),
                    uint64(i),
                    item,
                    next
                )
            );
        }
        require(segment.firstLink == next && segment.itemCount == 3, "literal full chain");
        require(
            StreamPreservationInventoryChains.link(KEY, 3, 0, rows[0], bytes32(uint256(1)))
                != StreamPreservationInventoryChains.link(KEY, 3, 1, rows[0], bytes32(uint256(1))),
            "index bound"
        );
    }

    function testWrongTerminalAndEarlyTerminationRejected() public {
        vm.expectRevert();
        StreamPreservationInventoryChains.link(KEY, 2, 0, _item(), 0);
        vm.expectRevert();
        StreamPreservationInventoryChains.link(KEY, 2, 1, _item(), RECORD);
        vm.expectRevert();
        StreamPreservationInventoryChains.link(KEY, 2, 2, _item(), 0);
        vm.expectRevert();
        StreamPreservationInventoryChains.link(0, 1, 0, _item(), 0);
    }

    function testEmptySegmentIsExplicitAndBoundToWitness() public pure {
        T.Segment memory empty =
            StreamPreservationInventoryChains.segment(KEY, RECORD, new T.Item[](0));
        require(empty.firstLink == 0 && empty.itemCount == 0, "explicit empty");
        bytes32 a = StreamPreservationInventoryChains.append(0, 0, empty);
        empty.sourceWitnessHash = keccak256("different applicability");
        require(
            a != StreamPreservationInventoryChains.append(0, 0, empty), "applicability committed"
        );
    }

    function testAllSixIntentReferencesAndIndependentWaiverRetained() public pure {
        C.Intent memory value = _intent();
        T.Item[] memory rows = StreamPreservationTypedReferences.intent(
            address(0x1234), RECORD, keccak256(StreamArtistIntentJson.serialize(value)), value
        );
        require(rows.length == 10, "all nine plus interview");
        C.Reference[6] memory refs = [
            value.display.scale,
            value.display.timing,
            value.display.color,
            value.display.interaction,
            value.display.motion,
            value.display.frameRate
        ];
        for (uint256 i; i < 6; ++i) {
            require(
                rows[i].algorithm == i + 1
                    && keccak256(rows[i].digest) == keccak256(refs[i].digest),
                "algorithm and bytes"
            );
            require(rows[i].sourceRecord == RECORD && rows[i].sourceIndex == i, "source occurrence");
        }
        require(
            rows[9].role == keccak256("INTERVIEW_WAIVER") && rows[9].provenanceHash == 0,
            "waiver has no original interview"
        );
    }

    function testIntentWaiverStillRequiresItsOwnInterviewDeclaration() public pure {
        C.IntentWaiver memory value;
        C.Intent memory source = _intent();
        value.subjectId = source.subjectId;
        value.profileHash = StreamConservationDefinitions.WAIVER_PROFILE_HASH;
        value.artist = source.artist;
        value.waiverStatement = _ref(1);
        value.interview = source.interview;
        T.Item[] memory rows = StreamPreservationTypedReferences.waiver(
            address(0x1234), RECORD, keccak256(StreamArtistIntentWaiverJson.serialize(value)), value
        );
        require(
            rows.length == 2 && rows[0].role == keccak256("ARTIST_INTENT_WAIVER")
                && rows[1].role == keccak256("INTERVIEW_WAIVER"),
            "separate statuses"
        );
    }

    function testWrongPayloadAndInactiveFieldsFailBeforeWalk() public {
        C.Intent memory value = _intent();
        bytes32 hash = keccak256(StreamArtistIntentJson.serialize(value));
        vm.expectRevert();
        StreamPreservationTypedReferences.intent(
            address(0x1234), RECORD, bytes32(uint256(hash) ^ 1), value
        );
        value.interview.record.recordHash = RECORD;
        vm.expectRevert();
        StreamPreservationTypedReferences.intent(address(0x1234), RECORD, hash, value);
    }

    function testCompleteInterviewIncludesUnselectedCatalogReferences() public pure {
        C.Interview memory value = _interview();
        C.Format memory format;
        format.kind = C.FormatKind.CATALOG;
        format.formatId = bytes32(uint256(1));
        format.catalog.name = "INVENTORY_FORMATS";
        format.catalog.selectedEntryId = format.formatId;
        format.catalog.entries = new C.CatalogEntry[](2);
        format.catalog.entries[0] = C.CatalogEntry(
            format.formatId, C.MappingKind.PRONOM, "fmt/111", C.Reference(0, 0, "", "")
        );
        format.catalog.entries[1] =
            C.CatalogEntry(bytes32(uint256(2)), C.MappingKind.SPECIFICATION, "", _ref(5));
        value.transcript.format = format;
        value.captures = new C.Capture[](1);
        value.captures[0] = C.Capture(C.CaptureKind.VIDEO, C.Payload(_ref(6), format));
        T.Item[] memory rows = StreamPreservationTypedReferences.interview(
            address(0x1234), RECORD, keccak256(StreamArtistInterviewJson.serialize(value)), value
        );
        require(
            rows.length == 9,
            "instrument two participants transcript catalog spec capture catalog spec"
        );
        require(
            rows[4].kind == T.Kind.REGISTERED_DOCUMENT && rows[5].algorithm == 5
                && rows[7].kind == T.Kind.REGISTERED_DOCUMENT && rows[8].algorithm == 5,
            "unselected refs not dropped"
        );
        require(rows[5].provenanceHash != rows[8].provenanceHash, "same catalog different role");
    }

    function testEmptyNativeBytesNeverBecomeAbsentImage() public pure {
        T.Item memory empty = Items.bytesItem(
            T.Kind.NATIVE_BYTES, keccak256("TOKEN_DATA"), address(0x1234), RECORD, 1, ""
        );
        T.Item memory absent = Items.absent(keccak256("TOKEN_IMAGE"), address(0x1234), RECORD, 1);
        require(
            empty.kind == T.Kind.EMPTY_BYTES && empty.algorithm == 1
                && bytes32(empty.digest) == keccak256(""),
            "exact empty data"
        );
        require(
            absent.kind == T.Kind.ABSENT && absent.algorithm == 0 && absent.digest.length == 0,
            "absence is not content"
        );
    }

    function testFuzzEveryItemFieldBindsItsSegment(bytes32 change, uint64 count) public pure {
        if (change == 0) change = bytes32(uint256(1));
        count = uint64(uint256(count) % 100 + 1);
        T.Item memory value = _item();
        bytes32 old = StreamPreservationInventoryChains.link(KEY, count, count - 1, value, 0);
        value.provenanceHash = change;
        require(
            old != StreamPreservationInventoryChains.link(KEY, count, count - 1, value, 0),
            "provenance bound"
        );
        require(
            old != StreamPreservationInventoryChains.link(KEY, count + 1, count, _item(), 0),
            "count bound"
        );
    }

    function _item() private pure returns (T.Item memory row) {
        return Items.bytesItem(
            T.Kind.NATIVE_BYTES,
            keccak256("SCRIPT"),
            address(0x1234),
            RECORD,
            0,
            bytes("complete source")
        );
    }

    function _ref(uint16 algorithm) private pure returns (C.Reference memory) {
        return C.Reference(
            algorithm,
            keccak256("RAW_BYTES"),
            abi.encode(bytes32(uint256(algorithm))),
            "ipfs://original-reference"
        );
    }

    function _intent() private pure returns (C.Intent memory value) {
        value.subjectId = bytes32(uint256(1));
        value.profileHash = StreamConservationDefinitions.INTENT_PROFILE_HASH;
        value.artist = C.ArtistClaim(
            bytes32(uint256(2)), 1, bytes32(uint256(3)), C.StatementOrigin.ARTIST_INTENT
        );
        value.display = C.Display(_ref(1), _ref(2), _ref(3), _ref(4), _ref(5), _ref(6));
        value.variabilityTolerances = _ref(1);
        value.dependencyAging = _ref(2);
        value.significantProperties = _ref(3);
        value.interview.status = C.InterviewStatus.WAIVED;
        value.interview.waiverStatement = _ref(4);
    }

    function _interview() private pure returns (C.Interview memory value) {
        value.subjectId = bytes32(uint256(1));
        value.profileHash = StreamConservationDefinitions.INTERVIEW_PROFILE_HASH;
        value.instrument.document = _ref(1);
        value.interviewDate = 20240229;
        value.participants = new C.Participant[](2);
        value.participants[0] = C.Participant(C.ParticipantRole.ARTIST, "", _ref(2));
        value.participants[1] = C.Participant(C.ParticipantRole.INTERVIEWER, "", _ref(3));
        value.languages = new string[](1);
        value.languages[0] = "en";
        value.transcript.content = _ref(4);
        value.transcript.format.puid = "fmt/111";
        value.transcript.format.formatId = keccak256("PRONOM:fmt/111");
    }
}

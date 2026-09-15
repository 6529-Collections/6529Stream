// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../../../smart-contracts/domains/records/StreamArtistIntentJson.sol";
import "../../../smart-contracts/domains/records/StreamArtistIntentWaiverJson.sol";
import "../../../smart-contracts/domains/records/StreamArtistInterviewJson.sol";
import {
    StreamConservationRecordTypes as T
} from "../../../smart-contracts/interfaces/stream/metadata/StreamConservationRecordTypes.sol";

interface ConservationVm {
    function readFileBinary(string calldata path) external view returns (bytes memory);
    function expectRevert() external;
    function cool(address target) external;
}

/// @notice Pure exact meaning; no record, authority, registry, archives or finality admission.
contract StreamConservationJsonTest {
    ConservationVm private constant vm =
        ConservationVm(address(uint160(uint256(keccak256("hevm cheat code")))));
    bytes32 private constant RAW = keccak256("RAW_BYTES");

    function _ref(uint16 a) private pure returns (T.Reference memory) {
        return T.Reference(a, RAW, abi.encode(bytes32(uint256(3))), "ipfs://conservation-reference");
    }

    function _artist() private pure returns (T.ArtistClaim memory) {
        return T.ArtistClaim(
            bytes32(uint256(6)),
            type(uint64).max,
            bytes32(uint256(7)),
            T.StatementOrigin.ARTIST_INTENT
        );
    }

    function _present() private pure returns (T.InterviewEntry memory e) {
        e.record = T.InterviewRecord(
            type(uint256).max,
            address(0xABaBaBaBABabABabAbAbABAbABabababaBaBABaB),
            address(0xCdCDCdCdcdcdcdCdcDcDCdcDcDCdCdcdCdcDCDcD),
            bytes32(uint256(4)),
            StreamConservationDefinitions.INTERVIEW_SCHEMA_ID,
            StreamConservationDefinitions.INTERVIEW_PROFILE_HASH,
            _ref(2)
        );
    }

    function _waived() private pure returns (T.InterviewEntry memory e) {
        e.status = T.InterviewStatus.WAIVED;
        e.waiverStatement = _ref(2);
    }

    function _intent() private pure returns (T.Intent memory v) {
        v.subjectId = bytes32(uint256(1));
        v.profileHash = StreamConservationDefinitions.INTENT_PROFILE_HASH;
        v.artist = _artist();
        v.display = T.Display(_ref(1), _ref(2), _ref(3), _ref(4), _ref(5), _ref(6));
        v.dependencyAging = _ref(2);
        v.significantProperties = _ref(2);
        v.variabilityTolerances = _ref(2);
        v.interview = _present();
    }

    function _waiver() private pure returns (T.IntentWaiver memory v) {
        v.subjectId = bytes32(uint256(1));
        v.profileHash = StreamConservationDefinitions.WAIVER_PROFILE_HASH;
        v.artist = _artist();
        v.waiverStatement = _ref(2);
        v.interview = _waived();
    }

    function _interview() private pure returns (T.Interview memory v) {
        v.subjectId = bytes32(uint256(1));
        v.profileHash = StreamConservationDefinitions.INTERVIEW_PROFILE_HASH;
        v.instrument.document = _ref(2);
        v.participants = new T.Participant[](2);
        v.participants[0] = T.Participant(T.ParticipantRole.ARTIST, "", _ref(2));
        v.participants[1] = T.Participant(T.ParticipantRole.INTERVIEWER, "", _ref(1));
        v.interviewDate = 20240229;
        v.languages = new string[](3);
        v.languages[0] = "EN-latn-US";
        v.languages[1] = "i-klingon";
        v.languages[2] = "x-exact";
        v.transcript.content = _ref(2);
        v.transcript.format.puid = "fmt/111";
        v.transcript.format.formatId = keccak256("PRONOM:fmt/111");
    }

    function _catalog() private pure returns (T.Catalog memory c) {
        c.name = "CONSERVATION_EXAMPLE_FORMATS_V1";
        c.selectedEntryId = bytes32(uint256(21));
        c.entries = new T.CatalogEntry[](2);
        c.entries[0].entryId = bytes32(uint256(20));
        c.entries[0].puid = "fmt/111";
        c.entries[1].entryId = bytes32(uint256(21));
        c.entries[1].kind = T.MappingKind.SPECIFICATION;
        c.entries[1].specification = _ref(5);
        c.entries[1].specification.digest = hex"00ff";
    }

    function _av() private pure returns (T.Interview memory v) {
        v = _interview();
        v.predecessor = bytes32(uint256(9));
        v.instrument = T.Instrument(
            T.InstrumentKind.NAMED_DERIVATIVE, unicode'Exact " \\ /\r\n\x01 🎨 é', _ref(6)
        );
        v.participants = new T.Participant[](3);
        v.participants[0] = T.Participant(T.ParticipantRole.ARTIST, "", _ref(2));
        v.participants[1] = T.Participant(T.ParticipantRole.INTERVIEWER, "", _ref(1));
        v.participants[2] = T.Participant(T.ParticipantRole.OTHER, "Conservator", _ref(3));
        v.captures = new T.Capture[](2);
        for (uint256 i; i < 2; ++i) {
            v.captures[i].kind = i == 0 ? T.CaptureKind.AUDIO : T.CaptureKind.VIDEO;
            v.captures[i].payload.content = _ref(uint16(4 + i));
            v.captures[i].payload.format.kind = T.FormatKind.CATALOG;
            v.captures[i].payload.format.formatId = bytes32(uint256(21));
            v.captures[i].payload.format.catalog = _catalog();
        }
        v.captures[0].payload.content.digest = new bytes(128);
        for (uint256 i = 1; i < 128; i += 2) {
            v.captures[0].payload.content.digest[i] = 0xff;
        }
        v.captures[1].payload.content.digest = hex"00";
    }

    function _golden(string memory name) private view returns (bytes memory) {
        return
            vm.readFileBinary(
                string.concat("schemas/records/examples/conservation/", name, ".json")
            );
    }

    function _equal(bytes memory a, bytes memory b) private pure {
        require(a.length == b.length && keccak256(a) == keccak256(b), "exact original bytes");
    }

    function intent(T.Intent memory v) external pure returns (bytes memory) {
        return StreamArtistIntentJson.serialize(v);
    }

    function waiver(T.IntentWaiver memory v) external pure returns (bytes memory) {
        return StreamArtistIntentWaiverJson.serialize(v);
    }

    function interview(T.Interview memory v) external pure returns (bytes memory) {
        return StreamArtistInterviewJson.serialize(v);
    }

    function refJSON(T.Reference memory v) external pure returns (string memory) {
        return StreamConservationRecordFields.referenceJSON(v);
    }

    function catalog(T.Catalog memory v) external pure returns (bytes memory) {
        return StreamConservationFormatJson.catalogDocument(v);
    }

    function format(T.Format memory v) external pure returns (string memory) {
        return StreamConservationFormatJson.serialize(v);
    }

    function exactIntent(T.Intent memory v, bytes memory raw) external pure {
        StreamArtistIntentJson.requireExact(v, raw);
    }

    function exactWaiver(T.IntentWaiver memory v, bytes memory raw) external pure {
        StreamArtistIntentWaiverJson.requireExact(v, raw);
    }

    function exactInterview(T.Interview memory v, bytes memory raw) external pure {
        StreamArtistInterviewJson.requireExact(v, raw);
    }

    function testIntentPresentGoldenAllNineNamedReferences() external view {
        _equal(StreamArtistIntentJson.serialize(_intent()), _golden("intent-present"));
    }

    function testIntentEstateAndExplicitInterviewWaiverGolden() external view {
        T.Intent memory v = _intent();
        v.artist.origin = T.StatementOrigin.ESTATE_STATEMENT;
        v.predecessor = bytes32(uint256(9));
        v.interview = _waived();
        _equal(StreamArtistIntentJson.serialize(v), _golden("intent-estate-waived"));
    }

    function testIntentWaiverAndIndependentInterviewWaiverGolden() external view {
        _equal(StreamArtistIntentWaiverJson.serialize(_waiver()), _golden("intent-waiver"));
    }

    function testIntentWaiverPresentInterviewGolden() external view {
        T.IntentWaiver memory v = _waiver();
        v.interview = _present();
        _equal(StreamArtistIntentWaiverJson.serialize(v), _golden("intent-waiver-present"));
    }

    function testInterviewVMQGoldenWithExactCaseAndEmptyCaptures() external view {
        _equal(StreamArtistInterviewJson.serialize(_interview()), _golden("interview-vmq"));
    }

    function testInterviewDerivativeAVGoldenAllOptionalEntries() external view {
        _equal(StreamArtistInterviewJson.serialize(_av()), _golden("interview-derivative-av"));
    }

    function testEntireCatalogGoldenIncludingUnselectedEntry() external view {
        _equal(StreamConservationFormatJson.catalogDocument(_catalog()), _golden("format-catalog"));
    }

    function testExactDefinitionsReconstructAllEightDocuments() external view {
        _definition(
            "STREAM_ARTIST_INTERVIEW_V1",
            StreamConservationDefinitions.INTERVIEW_SCHEMA_HASH,
            StreamConservationDefinitions.INTERVIEW_SCHEMA_BYTES
        );
        _definition(
            "STREAM_ARTIST_INTERVIEW_JSON_PROFILE_V1",
            StreamConservationDefinitions.INTERVIEW_PROFILE_HASH,
            StreamConservationDefinitions.INTERVIEW_PROFILE_BYTES
        );
        _definition(
            "STREAM_ARTIST_INTENT_V1",
            StreamConservationDefinitions.INTENT_SCHEMA_HASH,
            StreamConservationDefinitions.INTENT_SCHEMA_BYTES
        );
        _definition(
            "STREAM_ARTIST_INTENT_JSON_PROFILE_V1",
            StreamConservationDefinitions.INTENT_PROFILE_HASH,
            StreamConservationDefinitions.INTENT_PROFILE_BYTES
        );
        _definition(
            "STREAM_ARTIST_INTENT_WAIVER_V1",
            StreamConservationDefinitions.WAIVER_SCHEMA_HASH,
            StreamConservationDefinitions.WAIVER_SCHEMA_BYTES
        );
        _definition(
            "STREAM_ARTIST_INTENT_WAIVER_JSON_PROFILE_V1",
            StreamConservationDefinitions.WAIVER_PROFILE_HASH,
            StreamConservationDefinitions.WAIVER_PROFILE_BYTES
        );
        _definition(
            "STREAM_CONSERVATION_FORMAT_CATALOG_V1",
            StreamConservationDefinitions.CATALOG_SCHEMA_HASH,
            StreamConservationDefinitions.CATALOG_SCHEMA_BYTES
        );
        _definition(
            "STREAM_CONSERVATION_FORMAT_CATALOG_JSON_PROFILE_V1",
            StreamConservationDefinitions.CATALOG_PROFILE_HASH,
            StreamConservationDefinitions.CATALOG_PROFILE_BYTES
        );
    }

    function _definition(string memory name, bytes32 hash, uint256 size) private view {
        bytes memory raw = vm.readFileBinary(string.concat("schemas/records/", name, ".json"));
        require(raw.length == size && keccak256(raw) == hash, "complete definition");
    }

    function testPresentRejectsEveryWrongPinnedLocatorAndInactiveWaiver() external {
        T.Intent memory v = _intent();
        v.interview.record.profileHash = bytes32(uint256(1));
        vm.expectRevert();
        this.intent(v);
        v = _intent();
        v.interview.record.schemaId = bytes32(uint256(1));
        vm.expectRevert();
        this.intent(v);
        v = _intent();
        v.interview.record.chainId = 0;
        vm.expectRevert();
        this.intent(v);
        v = _intent();
        v.interview.record.core = address(0);
        vm.expectRevert();
        this.intent(v);
        v = _intent();
        v.interview.record.host = address(0);
        vm.expectRevert();
        this.intent(v);
        v = _intent();
        v.interview.record.recordHash = 0;
        vm.expectRevert();
        this.intent(v);
        v = _intent();
        v.interview.waiverStatement = _ref(2);
        vm.expectRevert();
        this.intent(v);
    }

    function testWaivedRejectsEveryNonzeroInactiveLocatorField() external {
        for (uint256 i; i < 10; ++i) {
            T.IntentWaiver memory v = _waiver();
            T.InterviewRecord memory r = v.interview.record;
            if (i == 0) r.chainId = 1;
            else if (i == 1) r.core = address(1);
            else if (i == 2) r.host = address(1);
            else if (i == 3) r.recordHash = bytes32(uint256(1));
            else if (i == 4) r.schemaId = bytes32(uint256(1));
            else if (i == 5) r.profileHash = bytes32(uint256(1));
            else if (i == 6) r.payload.algorithm = 1;
            else if (i == 7) r.payload.canonicalizationId = RAW;
            else if (i == 8) r.payload.digest = hex"00";
            else r.payload.uri = "ipfs://inactive";
            v.interview.record = r;
            vm.expectRevert();
            this.waiver(v);
        }
    }

    function testRequiredIntentReferencesAndWaiverCannotDefaultAbsent() external {
        T.Reference memory empty;
        for (uint256 i; i < 9; ++i) {
            T.Intent memory v = _intent();
            if (i == 0) v.display.scale = empty;
            else if (i == 1) v.display.timing = empty;
            else if (i == 2) v.display.color = empty;
            else if (i == 3) v.display.interaction = empty;
            else if (i == 4) v.display.motion = empty;
            else if (i == 5) v.display.frameRate = empty;
            else if (i == 6) v.dependencyAging = empty;
            else if (i == 7) v.significantProperties = empty;
            else v.variabilityTolerances = empty;
            vm.expectRevert();
            this.intent(v);
        }
        T.IntentWaiver memory w = _waiver();
        w.waiverStatement = empty;
        vm.expectRevert();
        this.waiver(w);
        w = _waiver();
        w.interview.waiverStatement = empty;
        vm.expectRevert();
        this.waiver(w);
    }

    function testOuterProfilesSubjectAndArtistClaimsRejectZeroOrWrong() external {
        T.Intent memory v = _intent();
        v.profileHash = bytes32(uint256(1));
        vm.expectRevert();
        this.intent(v);
        v = _intent();
        v.subjectId = 0;
        vm.expectRevert();
        this.intent(v);
        v = _intent();
        v.artist.artistId = 0;
        vm.expectRevert();
        this.intent(v);
        v = _intent();
        v.artist.bindingGeneration = 0;
        vm.expectRevert();
        this.intent(v);
        v = _intent();
        v.artist.bindingHash = 0;
        vm.expectRevert();
        this.intent(v);
        T.IntentWaiver memory w = _waiver();
        w.profileHash = StreamConservationDefinitions.INTENT_PROFILE_HASH;
        vm.expectRevert();
        this.waiver(w);
        T.Interview memory q = _interview();
        q.profileHash = bytes32(uint256(1));
        vm.expectRevert();
        this.interview(q);
    }

    function testAllSixHashWidthsOpaqueMaximumAndZeroDigestBytes() external {
        for (uint16 a = 1; a <= 6; ++a) {
            T.Reference memory r = _ref(a);
            r.digest = new bytes(a == 4 || a == 5 ? 128 : 32);
            this.refJSON(r);
            r.digest = new bytes(a == 4 || a == 5 ? 129 : 31);
            vm.expectRevert();
            this.refJSON(r);
            r.digest = new bytes(0);
            vm.expectRevert();
            this.refJSON(r);
        }
        T.Reference memory r = _ref(2);
        r.algorithm = 0;
        vm.expectRevert();
        this.refJSON(r);
        r = _ref(2);
        r.algorithm = 7;
        vm.expectRevert();
        this.refJSON(r);
        r = _ref(2);
        r.canonicalizationId = 0;
        vm.expectRevert();
        this.refJSON(r);
    }

    function testURIAndUTF8RejectWithoutNormalization() external {
        T.Reference memory r = _ref(2);
        r.uri = "https:///bad";
        vm.expectRevert();
        this.refJSON(r);
        r.uri = "ipfs://bad\n";
        vm.expectRevert();
        this.refJSON(r);
        bytes memory bad = new bytes(2);
        bad[0] = 0xc0;
        bad[1] = 0x80;
        r.uri = string(bad);
        vm.expectRevert();
        this.refJSON(r);
        r.uri = string.concat("https://", _repeat("x", 2040));
        this.refJSON(r);
        r.uri = string.concat(r.uri, "x");
        vm.expectRevert();
        this.refJSON(r);
    }

    function testInstrumentAndParticipantClosedUnions() external {
        T.Interview memory v = _interview();
        v.instrument.name = "ignored";
        vm.expectRevert();
        this.interview(v);
        v = _interview();
        v.instrument.kind = T.InstrumentKind.NAMED_DERIVATIVE;
        vm.expectRevert();
        this.interview(v);
        v = _interview();
        v.participants[0].otherRole = "ignored";
        vm.expectRevert();
        this.interview(v);
        v = _interview();
        v.participants[0].role = T.ParticipantRole.OTHER;
        vm.expectRevert();
        this.interview(v);
        v.participants[0].otherRole = "Specific role";
        this.interview(v);
        v = _interview();
        v.participants = new T.Participant[](0);
        vm.expectRevert();
        this.interview(v);
    }

    function testDatesExactGregorianAndLanguageRequired() external {
        T.Interview memory v = _interview();
        v.interviewDate = 10101;
        this.interview(v);
        v.interviewDate = 99991231;
        this.interview(v);
        v.interviewDate = 19000229;
        vm.expectRevert();
        this.interview(v);
        v.interviewDate = 20240230;
        vm.expectRevert();
        this.interview(v);
        v = _interview();
        v.languages = new string[](0);
        vm.expectRevert();
        this.interview(v);
        v = _interview();
        v.languages[0] = "sl-rozaj-ROZAJ";
        vm.expectRevert();
        this.interview(v);
    }

    function testSyntaxOnlyLanguageExplicitlyNotDatedRegistryMembership() external view {
        T.Interview memory v = _interview();
        v.languages[0] = "zzzz";
        require(
            StreamArtistInterviewJson.serialize(v).length != 0, "well-formed only; offline rejects"
        );
    }

    function testCatalogUnselectedRowsChangeCommitmentAndStillValidate() external {
        T.Catalog memory c = _catalog();
        bytes32 beforeHash = keccak256(this.catalog(c));
        c.entries[0].puid = "fmt/112";
        require(keccak256(this.catalog(c)) != beforeHash, "whole catalog bound");
        c.entries[0].puid = "fmt/0";
        vm.expectRevert();
        this.catalog(c);
    }

    function testCatalogDuplicateMissingSelectionAndInactiveDataReject() external {
        T.Catalog memory c = _catalog();
        c.entries[0].entryId = c.selectedEntryId;
        vm.expectRevert();
        this.catalog(c);
        c = _catalog();
        c.selectedEntryId = bytes32(uint256(99));
        vm.expectRevert();
        this.catalog(c);
        c = _catalog();
        c.entries[0].specification.algorithm = 2;
        vm.expectRevert();
        this.catalog(c);
        c = _catalog();
        c.entries[1].puid = "fmt/111";
        vm.expectRevert();
        this.catalog(c);
        c = _catalog();
        c.name = "bad name";
        vm.expectRevert();
        this.catalog(c);
    }

    function testPRONOMAndCatalogInactiveFieldsAndSelectedId() external {
        T.Format memory f = _interview().transcript.format;
        f.catalog.name = "ignored";
        vm.expectRevert();
        this.format(f);
        f = _interview().transcript.format;
        f.formatId = bytes32(uint256(1));
        vm.expectRevert();
        this.format(f);
        f = _av().captures[0].payload.format;
        f.puid = "fmt/111";
        vm.expectRevert();
        this.format(f);
        f = _av().captures[0].payload.format;
        f.formatId = bytes32(uint256(20));
        vm.expectRevert();
        this.format(f);
    }

    function testMoreThanEightRowsAndStableOriginalOrder() external view {
        T.Interview memory v = _interview();
        v.participants = new T.Participant[](10);
        for (uint256 i; i < 10; ++i) {
            v.participants[i] = T.Participant(T.ParticipantRole.ARTIST, "", _ref(2));
        }
        v.languages = new string[](12);
        for (uint256 i; i < 12; ++i) {
            v.languages[i] = i % 2 == 0 ? "en" : "fr";
        }
        bytes32 h = keccak256(StreamArtistInterviewJson.serialize(v));
        (v.languages[0], v.languages[1]) = (v.languages[1], v.languages[0]);
        require(h != keccak256(StreamArtistInterviewJson.serialize(v)), "original language order");
        T.Catalog memory c = _catalog();
        c.entries = new T.CatalogEntry[](20);
        c.selectedEntryId = bytes32(uint256(1));
        for (uint256 i; i < 20; ++i) {
            c.entries[i].entryId = bytes32(i + 1);
            c.entries[i].puid = "fmt/111";
        }
        require(StreamConservationFormatJson.catalogDocument(c).length < 8192, "no eight-entry cap");
    }

    function testExact8192InterviewAndNextByteRejects() external {
        T.Interview memory v = _interview();
        v.languages = new string[](1000);
        for (uint256 i; i < 1000; ++i) {
            v.languages[i] = "en";
        }
        uint256 length = this.interview(v).length;
        uint256 extra = 8192 - length;
        require(extra + bytes(v.transcript.content.uri).length <= 2048, "one URI exact bound");
        v.transcript.content.uri = string.concat(v.transcript.content.uri, _repeat("x", extra));
        require(this.interview(v).length == 8192, "complete exact boundary");
        v.transcript.content.uri = string.concat(v.transcript.content.uri, "x");
        vm.expectRevert();
        this.interview(v);
    }
    event Capacity(string shape, uint256 gasUsed);

    function testColdExact8192ThousandLanguageEntriesFits16M() external {
        T.Interview memory v = _interview();
        v.languages = new string[](1000);
        for (uint256 i; i < 1000; ++i) {
            v.languages[i] = "en";
        }
        uint256 extra = 8192 - this.interview(v).length;
        v.transcript.content.uri = string.concat(v.transcript.content.uri, _repeat("x", extra));
        bytes memory data = abi.encodeWithSelector(this.interview.selector, v);
        vm.cool(address(StreamArtistInterviewJson));
        vm.cool(address(StreamConservationLanguage));
        vm.cool(address(StreamConservationFormatJson));
        vm.cool(address(StreamConservationRecordFields));
        vm.cool(address(StreamRecordJson));
        vm.cool(address(StreamMetadataRenderer));
        uint256 beforeGas = gasleft();
        (bool ok, bytes memory result) = address(this).staticcall{ gas: 16_000_000 }(data);
        emit Capacity(
            "8192bytes/1000tags/6-library cooling; direct callee gas excludes intrinsic",
            beforeGas - gasleft()
        );
        require(ok, "practical pure serializer cap");
        require(abi.decode(result, (bytes)).length == 8192, "complete payload");
    }

    function testLanguageArrayExactCaseAndEveryRowValidated() external {
        string[] memory tags = new string[](3);
        tags[0] = "EN-latn-US";
        tags[1] = "x-A-A";
        tags[2] = "en";
        _equal(
            bytes(StreamConservationLanguage.arrayJSON(tags)), bytes('["EN-latn-US","x-A-A","en"]')
        );
        tags[2] = 'en-"bad';
        (bool ok,) = address(StreamConservationLanguage)
            .staticcall(abi.encodeWithSelector(StreamConservationLanguage.arrayJSON.selector, tags));
        require(!ok, "last invalid row rejects before copying");
    }

    function testExactStoredBytesRejectWhitespaceMutationAndTruncation() external {
        T.Intent memory i = _intent();
        bytes memory raw = this.intent(i);
        this.exactIntent(i, raw);
        vm.expectRevert();
        this.exactIntent(i, bytes.concat(raw, bytes(" ")));
        T.IntentWaiver memory w = _waiver();
        raw = this.waiver(w);
        this.exactWaiver(w, raw);
        raw[0] = "[";
        vm.expectRevert();
        this.exactWaiver(w, raw);
        T.Interview memory q = _interview();
        raw = this.interview(q);
        this.exactInterview(q, raw);
        bytes memory shorter = new bytes(raw.length - 1);
        for (uint256 n; n < shorter.length; ++n) {
            shorter[n] = raw[n];
        }
        vm.expectRevert();
        this.exactInterview(q, shorter);
    }

    function testDistinctComposedAndDecomposedUnicodeRetained() external view {
        T.Interview memory v = _interview();
        v.instrument.kind = T.InstrumentKind.NAMED_DERIVATIVE;
        v.instrument.name = unicode"é";
        bytes32 a = keccak256(StreamArtistInterviewJson.serialize(v));
        v.instrument.name = unicode"é";
        require(a != keccak256(StreamArtistInterviewJson.serialize(v)), "no normalization");
    }

    function testFuzzEveryDigestBytePreserved(uint16 seed, bytes32 value) external view {
        uint16 a = seed % 6 + 1;
        T.Reference memory r = _ref(a);
        r.digest = abi.encode(value);
        string memory actual = StreamConservationRecordFields.referenceJSON(r);
        string memory expected = string.concat(
            '{"hash":{"algorithm":',
            string(abi.encodePacked(bytes1(uint8(48 + a)))),
            ',"canonicalizationId":',
            StreamRecordJson.hexValue(RAW),
            ',"digest":',
            StreamRecordJson.hexValue(value),
            '},"uri":"ipfs://conservation-reference"}'
        );
        _equal(bytes(actual), bytes(expected));
    }

    function _repeat(bytes1 c, uint256 n) private pure returns (string memory) {
        bytes memory out = new bytes(n);
        for (uint256 i; i < n; ++i) {
            out[i] = c;
        }
        return string(out);
    }
}

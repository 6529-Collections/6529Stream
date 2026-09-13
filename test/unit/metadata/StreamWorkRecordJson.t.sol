// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../../../smart-contracts/domains/records/StreamWorkRecordJson.sol";
import "../../../smart-contracts/interfaces/stream/metadata/StreamWorkRecordTypes.sol";

interface WorkJsonVm {
    function expectRevert() external;
    function expectRevert(bytes calldata reason) external;
    function readFileBinary(string calldata path) external view returns (bytes memory);
}

/// @notice Pure complete-meaning oracles; no original author/registration/current selection claim.
contract StreamWorkRecordJsonTest {
    WorkJsonVm private constant vm =
        WorkJsonVm(address(uint160(uint256(keccak256("hevm cheat code")))));

    function _simple() private pure returns (StreamWorkRecordTypes.Description memory d) {
        d.subjectId = bytes32(uint256(1));
        d.profileHash = bytes32(uint256(2));
        d.full.title = "Exact work title";
        d.full.creator.kind = StreamWorkRecordTypes.CreatorKind.NAMED;
        d.full.creator.name = "Declared creator";
        d.full.creation.start = 20240229;
        d.full.medium = "Generative instructions";
        d.full.measurements.kind = StreamWorkRecordTypes.MeasurementKind.DIMENSIONLESS_GENERATIVE;
        d.full.creditLine = "Authored credit";
    }

    function _catalog() private pure returns (StreamWorkRecordTypes.Catalog memory c) {
        c.name = "WORK_FORMAT_FIXTURE_V1";
        c.selectedEntryId = bytes32(uint256(12));
        c.entries = new StreamWorkRecordTypes.CatalogEntry[](2);
        c.entries[0].entryId = bytes32(uint256(11));
        c.entries[0].puid = "fmt/199";
        c.entries[1].entryId = bytes32(uint256(12));
        c.entries[1].kind = StreamWorkRecordTypes.MappingKind.SPECIFICATION;
        c.entries[1].specification = StreamWorkRecordTypes.Specification(
            "ipfs://format-specification", bytes32(uint256(13))
        );
    }

    function _complete() private pure returns (StreamWorkRecordTypes.Description memory d) {
        d = _simple();
        d.predecessor = bytes32(uint256(6));
        d.full.title = unicode'Quote " slash / backslash \\ newline\ncontrol\x01 astral 🎨 é';
        d.full.creator = StreamWorkRecordTypes.Creator(
            StreamWorkRecordTypes.CreatorKind.ARTIST,
            bytes32(uint256(3)),
            type(uint64).max,
            bytes32(uint256(4)),
            ""
        );
        d.full.creation =
            StreamWorkRecordTypes.Creation(StreamWorkRecordTypes.DateKind.RANGE, 10101, 20260912);
        d.full.medium = "Digital audiovisual work";
        d.full.creditLine = "Exact authored credit\r\n";
        d.full.hasInscription = true;
        d.full.inscription = "Signature description, not a signature.";
        d.full.edition = StreamWorkRecordTypes.Edition(
            StreamWorkRecordTypes.EditionKind.SERIAL, type(uint256).max - 1, type(uint256).max, ""
        );
        d.full.measurements = StreamWorkRecordTypes.Measurements(
            StreamWorkRecordTypes.MeasurementKind.MEASURED,
            true,
            3840,
            2160,
            true,
            StreamWorkRecordTypes.Rational(2, 4),
            true,
            StreamWorkRecordTypes.Rational(type(uint256).max - 1, type(uint256).max)
        );
        d.full.alternateTitles = new string[](2);
        d.full.alternateTitles[0] = "Titre";
        d.full.alternateTitles[1] = "Titre";
        d.full.languageVariants = new StreamWorkRecordTypes.LanguageVariant[](5);
        d.full.languageVariants[0] = StreamWorkRecordTypes.LanguageVariant(
            StreamWorkRecordTypes.VariantField.TITLE, 0, "fr", "Titre"
        );
        d.full.languageVariants[1] = StreamWorkRecordTypes.LanguageVariant(
            StreamWorkRecordTypes.VariantField.MEDIUM, 0, "sr-Latn-RS", "Medij"
        );
        d.full.languageVariants[2] = StreamWorkRecordTypes.LanguageVariant(
            StreamWorkRecordTypes.VariantField.CREDIT, 0, "und", "Credit"
        );
        d.full.languageVariants[3] = StreamWorkRecordTypes.LanguageVariant(
            StreamWorkRecordTypes.VariantField.INSCRIPTION, 0, "es-419", unicode"Inscripción"
        );
        d.full.languageVariants[4] = StreamWorkRecordTypes.LanguageVariant(
            StreamWorkRecordTypes.VariantField.ALTERNATE_TITLE, 1, "FR", "Autre"
        );
        d.full.authorityReferences = new StreamWorkRecordTypes.AuthorityReference[](5);
        d.full.authorityReferences[0] = StreamWorkRecordTypes.AuthorityReference(
            StreamWorkRecordTypes.AuthorityRole.CREATOR,
            StreamWorkRecordTypes.Authority.ULAN,
            "500115588"
        );
        d.full.authorityReferences[1] = StreamWorkRecordTypes.AuthorityReference(
            StreamWorkRecordTypes.AuthorityRole.CREATOR,
            StreamWorkRecordTypes.Authority.VIAF,
            "1234567890123456789012"
        );
        d.full.authorityReferences[2] = StreamWorkRecordTypes.AuthorityReference(
            StreamWorkRecordTypes.AuthorityRole.CREATOR,
            StreamWorkRecordTypes.Authority.WIKIDATA,
            "Q12345678901234567890"
        );
        d.full.authorityReferences[3] = StreamWorkRecordTypes.AuthorityReference(
            StreamWorkRecordTypes.AuthorityRole.MEDIUM,
            StreamWorkRecordTypes.Authority.GETTY_AAT,
            "300264849"
        );
        d.full.authorityReferences[4] = StreamWorkRecordTypes.AuthorityReference(
            StreamWorkRecordTypes.AuthorityRole.TECHNIQUE,
            StreamWorkRecordTypes.Authority.GETTY_AAT,
            "300054698"
        );
        d.full.format.kind = StreamWorkRecordTypes.FormatKind.CATALOG;
        d.full.format.formatId = bytes32(uint256(12));
        d.full.format.catalog = _catalog();
    }

    function testIndependentSimpleAndExplicitAbsenceGoldens() public view {
        StreamWorkRecordTypes.Description memory d = _simple();
        bytes memory raw = vm.readFileBinary("test/fixtures/metadata/work-simple-v1.json");
        require(StreamWorkRecordJson.requireExact(d, raw) == keccak256(raw), "full literal");
        StreamWorkRecordTypes.Description memory a;
        a.subjectId = d.subjectId;
        a.profileHash = d.profileHash;
        a.form = StreamWorkRecordTypes.Form.DESCRIPTION_ABSENT;
        a.absence = StreamWorkRecordTypes.Absence("An explicit authored absence.", 20260912);
        raw = vm.readFileBinary("test/fixtures/metadata/work-absent-v1.json");
        require(StreamWorkRecordJson.requireExact(a, raw) == keccak256(raw), "absence literal");
    }

    function testIndependentEveryOptionalAVFullWidthAndCatalogGolden() public view {
        bytes memory raw = vm.readFileBinary("test/fixtures/metadata/work-complete-v1.json");
        require(
            StreamWorkRecordJson.requireExact(_complete(), raw) == keccak256(raw),
            "complete literal independent JSON"
        );
        raw = vm.readFileBinary("test/fixtures/metadata/work-catalog-v1.json");
        require(
            keccak256(StreamWorkFormatJson.catalogDocument(_catalog())) == keccak256(raw),
            "entire ordered catalog literal"
        );
    }

    function testRequiredFieldsDoNotBecomeAbsence() public {
        for (uint256 i; i < 6; ++i) {
            StreamWorkRecordTypes.Description memory d = _simple();
            if (i == 0) d.full.title = "";
            if (i == 1) d.full.medium = "";
            if (i == 2) d.full.creditLine = "";
            if (i == 3) d.full.creator.name = "";
            if (i == 4) d.subjectId = 0;
            if (i == 5) d.profileHash = 0;
            vm.expectRevert();
            StreamWorkRecordJson.serialize(d);
        }
        StreamWorkRecordJson.serialize(_simple());
    }

    function testMixedAbsenceRejectsEveryInactiveFullGroup() public {
        for (uint256 i; i < 13; ++i) {
            StreamWorkRecordTypes.Description memory d;
            d.subjectId = bytes32(uint256(1));
            d.profileHash = bytes32(uint256(2));
            d.form = StreamWorkRecordTypes.Form.DESCRIPTION_ABSENT;
            d.absence = StreamWorkRecordTypes.Absence("Authored reason", 20260912);
            if (i == 0) d.full.title = "inactive";
            if (i == 1) d.full.creator.bindingGeneration = 1;
            if (i == 2) d.full.creation.start = 20260912;
            if (i == 3) d.full.format.catalog.name = "inactive";
            if (i == 4) d.full.measurements.durationSeconds.denominator = 1;
            if (i == 5) d.full.edition.statement = "inactive";
            if (i == 6) d.full.medium = "inactive";
            if (i == 7) d.full.creditLine = "inactive";
            if (i == 8) d.full.inscription = "inactive";
            if (i == 9) d.full.alternateTitles = new string[](1);
            if (i == 10) d.full.languageVariants = new StreamWorkRecordTypes.LanguageVariant[](1);
            if (i == 11) {
                d.full.authorityReferences = new StreamWorkRecordTypes.AuthorityReference[](1);
            }
            if (i == 12) d.full.hasInscription = true;
            vm.expectRevert();
            StreamWorkRecordJson.serialize(d);
        }
    }

    function testFullRejectsInactiveAbsenceAndCreatorUnion() public {
        StreamWorkRecordTypes.Description memory d = _simple();
        d.absence.date = 20260912;
        vm.expectRevert();
        StreamWorkRecordJson.serialize(d);
        d.absence.date = 0;
        d.full.creator.artistId = bytes32(uint256(3));
        vm.expectRevert();
        StreamWorkRecordJson.serialize(d);
        d = _complete();
        d.full.creator.name = "inactive";
        vm.expectRevert();
        StreamWorkRecordJson.serialize(d);
        d.full.creator.name = "";
        StreamWorkRecordJson.serialize(d);
    }

    function testGregorianExactRangeLeapAndOrder() public {
        StreamWorkRecordTypes.Description memory d = _simple();
        uint32[5] memory invalid = [uint32(19000229), 20230229, 20261301, 20260431, 0];
        for (uint256 i; i < invalid.length; ++i) {
            d.full.creation.start = invalid[i];
            vm.expectRevert();
            StreamWorkRecordJson.serialize(d);
        }
        d.full.creation.start = 20000229;
        StreamWorkRecordJson.serialize(d);
        d.full.creation.end = 20000229;
        vm.expectRevert();
        StreamWorkRecordJson.serialize(d);
        d.full.creation.kind = StreamWorkRecordTypes.DateKind.RANGE;
        StreamWorkRecordJson.serialize(d);
        d.full.creation.end = 20000228;
        vm.expectRevert();
        StreamWorkRecordJson.serialize(d);
        d.full.creation.end = 99991231;
        StreamWorkRecordJson.serialize(d);
    }

    function testDirectPronomDerivationAndBothLexicalBranches() public {
        StreamWorkRecordTypes.Description memory d = _simple();
        d.full.format.kind = StreamWorkRecordTypes.FormatKind.PRONOM;
        d.full.format.puid = "fmt/199";
        d.full.format.formatId = keccak256("PRONOM:fmt/199");
        StreamWorkRecordJson.serialize(d);
        d.full.format.puid = "x-fmt/1";
        d.full.format.formatId = keccak256("PRONOM:x-fmt/1");
        StreamWorkRecordJson.serialize(d);
        d.full.format.formatId = bytes32(uint256(1));
        vm.expectRevert();
        StreamWorkRecordJson.serialize(d);
        string[5] memory bad = ["fmt/01", "fmt/0", "FMT/1", "fmt/1\n", "mime/video"];
        for (uint256 i; i < bad.length; ++i) {
            d.full.format.puid = bad[i];
            d.full.format.formatId = keccak256(bytes(string.concat("PRONOM:", bad[i])));
            vm.expectRevert();
            StreamWorkRecordJson.serialize(d);
        }
    }

    function testCatalogWholeDocumentAndUnselectedEntryCommitment() public {
        StreamWorkRecordTypes.Description memory d = _complete();
        bytes32 beforeHash = keccak256(StreamWorkRecordJson.serialize(d));
        d.full.format.catalog.entries[0].puid = "fmt/200";
        require(
            keccak256(StreamWorkRecordJson.serialize(d)) != beforeHash,
            "unselected entry still committed"
        );
        d.full.format.catalog.entries[0].puid = "fmt/199";
        require(
            keccak256(StreamWorkRecordJson.serialize(d)) == beforeHash,
            "same complete witness retry"
        );
        d.full.format.catalog.entries[0].entryId = bytes32(uint256(12));
        vm.expectRevert();
        StreamWorkRecordJson.serialize(d);
        d.full.format.catalog.entries[0].entryId = bytes32(uint256(11));
        d.full.format.catalog.selectedEntryId = bytes32(uint256(99));
        d.full.format.formatId = bytes32(uint256(99));
        vm.expectRevert();
        StreamWorkRecordJson.serialize(d);
    }

    function testCatalogInactiveMappingAndFormatUnion() public {
        StreamWorkRecordTypes.Description memory d = _complete();
        d.full.format.catalog.entries[0].specification.digest = bytes32(uint256(1));
        vm.expectRevert();
        StreamWorkRecordJson.serialize(d);
        d = _complete();
        d.full.format.catalog.entries[1].puid = "fmt/1";
        vm.expectRevert();
        StreamWorkRecordJson.serialize(d);
        d = _complete();
        d.full.format.puid = "fmt/1";
        vm.expectRevert();
        StreamWorkRecordJson.serialize(d);
        d = _simple();
        d.full.format.catalog.selectedEntryId = bytes32(uint256(1));
        vm.expectRevert();
        StreamWorkRecordJson.serialize(d);
    }

    function testCatalogBoundsAndSpecificationURI() public {
        StreamWorkRecordTypes.Catalog memory c = _catalog();
        c.name = "bad name";
        vm.expectRevert();
        StreamWorkFormatJson.catalogDocument(c);
        c = _catalog();
        c.entries = new StreamWorkRecordTypes.CatalogEntry[](9);
        vm.expectRevert();
        StreamWorkFormatJson.catalogDocument(c);
        c = _catalog();
        c.entries[1].specification.digest = 0;
        vm.expectRevert();
        StreamWorkFormatJson.catalogDocument(c);
        c = _catalog();
        c.entries[1].specification.uri = "https:///missing-host";
        vm.expectRevert();
        StreamWorkFormatJson.catalogDocument(c);
        c.entries[1].specification.uri = unicode"ipfs://exact-é";
        StreamWorkFormatJson.catalogDocument(c);
    }

    function testEveryMeasuredCombinationAndInactiveZeroes() public {
        StreamWorkRecordTypes.Description memory d = _simple();
        for (uint256 bits = 1; bits < 8; ++bits) {
            bool p = bits & 1 != 0;
            bool a = bits & 2 != 0;
            bool t = bits & 4 != 0;
            d.full.measurements = StreamWorkRecordTypes.Measurements(
                StreamWorkRecordTypes.MeasurementKind.MEASURED,
                p,
                p ? 640 : 0,
                p ? 480 : 0,
                a,
                StreamWorkRecordTypes.Rational(a ? 4 : 0, a ? 3 : 0),
                t,
                StreamWorkRecordTypes.Rational(t ? 30000 : 0, t ? 1001 : 0)
            );
            StreamWorkRecordJson.serialize(d);
        }
        d = _simple();
        d.full.measurements.width = 1;
        vm.expectRevert();
        StreamWorkRecordJson.serialize(d);
        d = _simple();
        d.full.measurements.kind = StreamWorkRecordTypes.MeasurementKind.MEASURED;
        vm.expectRevert();
        StreamWorkRecordJson.serialize(d);
        d.full.measurements.hasDuration = true;
        d.full.measurements.durationSeconds.numerator = 1;
        vm.expectRevert();
        StreamWorkRecordJson.serialize(d);
        d.full.measurements.durationSeconds.denominator = 1;
        StreamWorkRecordJson.serialize(d);
    }

    function testRationalsAreNotReducedAndEditionsAreClosed() public {
        StreamWorkRecordTypes.Description memory d = _complete();
        bytes32 first = keccak256(StreamWorkRecordJson.serialize(d));
        d.full.measurements.aspectRatio = StreamWorkRecordTypes.Rational(1, 2);
        require(
            keccak256(StreamWorkRecordJson.serialize(d)) != first, "no reduction of source pair"
        );
        d.full.edition.number = d.full.edition.total;
        StreamWorkRecordJson.serialize(d);
        d.full.edition.total -= 1;
        vm.expectRevert();
        StreamWorkRecordJson.serialize(d);
        d.full.edition = StreamWorkRecordTypes.Edition(
            StreamWorkRecordTypes.EditionKind.OPEN_SERIES, 0, 0, "Authored ongoing series"
        );
        StreamWorkRecordJson.serialize(d);
        d.full.edition.number = 1;
        vm.expectRevert();
        StreamWorkRecordJson.serialize(d);
        d.full.edition = StreamWorkRecordTypes.Edition(
            StreamWorkRecordTypes.EditionKind.UNIQUE, 0, 0, "inactive"
        );
        vm.expectRevert();
        StreamWorkRecordJson.serialize(d);
    }

    function testOptionalArraysPreserveOrderAndCreatorLanguageTarget() public {
        StreamWorkRecordTypes.Description memory d = _complete();
        bytes32 first = keccak256(StreamWorkRecordJson.serialize(d));
        StreamWorkRecordTypes.AuthorityReference memory old = d.full.authorityReferences[0];
        d.full.authorityReferences[0] = d.full.authorityReferences[1];
        d.full.authorityReferences[1] = old;
        require(keccak256(StreamWorkRecordJson.serialize(d)) != first, "source order retained");
        d = _simple();
        d.full.languageVariants = new StreamWorkRecordTypes.LanguageVariant[](1);
        d.full.languageVariants[0] = StreamWorkRecordTypes.LanguageVariant(
            StreamWorkRecordTypes.VariantField.CREATOR_NAME,
            0,
            "en-Latn-US",
            "Declared translated name"
        );
        StreamWorkRecordJson.serialize(d);
        d.full.languageVariants[0].alternateTitleIndex = 1;
        vm.expectRevert();
        StreamWorkRecordJson.serialize(d);
    }

    function testOptionalTargetsBoundsAndLanguageGrammar() public {
        StreamWorkRecordTypes.Description memory d = _complete();
        d.full.languageVariants[4].alternateTitleIndex = 2;
        vm.expectRevert();
        StreamWorkRecordJson.serialize(d);
        d = _complete();
        d.full.hasInscription = false;
        d.full.inscription = "";
        vm.expectRevert();
        StreamWorkRecordJson.serialize(d);
        string[6] memory bad = ["", "en\n", "en_US", "en-x-private", "english", "en-Latn-1234"];
        for (uint256 i; i < bad.length; ++i) {
            d = _complete();
            d.full.languageVariants[0].language = bad[i];
            vm.expectRevert();
            StreamWorkRecordJson.serialize(d);
        }
        d = _simple();
        d.full.alternateTitles = new string[](9);
        vm.expectRevert();
        StreamWorkRecordJson.serialize(d);
        d = _simple();
        d.full.languageVariants = new StreamWorkRecordTypes.LanguageVariant[](9);
        vm.expectRevert();
        StreamWorkRecordJson.serialize(d);
        d = _simple();
        d.full.authorityReferences = new StreamWorkRecordTypes.AuthorityReference[](17);
        vm.expectRevert();
        StreamWorkRecordJson.serialize(d);
    }

    function testAuthorityRolesAndLiteralIdentifierGrammar() public {
        StreamWorkRecordTypes.Description memory d = _complete();
        d.full.authorityReferences[0].role = StreamWorkRecordTypes.AuthorityRole.MEDIUM;
        vm.expectRevert();
        StreamWorkRecordJson.serialize(d);
        d = _complete();
        d.full.authorityReferences[3].role = StreamWorkRecordTypes.AuthorityRole.CREATOR;
        vm.expectRevert();
        StreamWorkRecordJson.serialize(d);
        string[4] memory bad = ["q42", "Q042", "Q0", "Q42\n"];
        for (uint256 i; i < bad.length; ++i) {
            d = _complete();
            d.full.authorityReferences[2].identifier = bad[i];
            vm.expectRevert();
            StreamWorkRecordJson.serialize(d);
        }
        d = _complete();
        d.full.authorityReferences[0].identifier = "500115588";
        StreamWorkRecordJson.serialize(d);
    }

    function testUTF8ByteBoundsNoNormalizationAndMalformedUTF8() public {
        StreamWorkRecordTypes.Description memory d = _simple();
        bytes memory invalidUtf8 = hex"c0af";
        d.full.title = string(invalidUtf8);
        vm.expectRevert();
        StreamWorkRecordJson.serialize(d);
        d.full.title = unicode"é";
        bytes32 first = keccak256(StreamWorkRecordJson.serialize(d));
        d.full.title = unicode"é";
        require(keccak256(StreamWorkRecordJson.serialize(d)) != first, "no NFC coercion");
        bytes memory title = new bytes(514);
        for (uint256 i; i < title.length; i += 2) {
            title[i] = 0xc3;
            title[i + 1] = 0xa9;
        }
        d.full.title = string(title);
        vm.expectRevert();
        StreamWorkRecordJson.serialize(d);
    }

    function testEncoded8192BoundaryIncludesEscapeAndPunctuation() public {
        StreamWorkRecordTypes.Description memory d = _simple();
        d.full.languageVariants = new StreamWorkRecordTypes.LanguageVariant[](8);
        for (uint256 i; i < 8; ++i) {
            d.full.languageVariants[i] = StreamWorkRecordTypes.LanguageVariant(
                StreamWorkRecordTypes.VariantField.TITLE, 0, "en", _repeat(800)
            );
        }
        uint256 size = StreamWorkRecordJson.serialize(d).length;
        require(size < 8192 && size > 7000, "nonvacuous multi-field basis");
        d.full.creditLine = _repeat(bytes(d.full.creditLine).length + 8192 - size);
        bytes memory exact = StreamWorkRecordJson.serialize(d);
        require(
            exact.length == 8192 && StreamWorkRecordJson.requireExact(d, exact) == keccak256(exact),
            "complete exact limit"
        );
        d.full.creditLine = string.concat(d.full.creditLine, "x");
        vm.expectRevert();
        StreamWorkRecordJson.serialize(d);
    }

    function testUnknownDuplicateNoncanonicalAndChangedPayloadsReject() public {
        StreamWorkRecordTypes.Description memory d = _simple();
        bytes memory golden = vm.readFileBinary("test/fixtures/metadata/work-simple-v1.json");
        bytes[5] memory wrong = [
            bytes("{}"),
            bytes.concat(golden, bytes(" ")),
            bytes('{"version":1,"version":1}'),
            bytes('{"extra":"ignored"}'),
            bytes("")
        ];
        for (uint256 i; i < wrong.length; ++i) {
            vm.expectRevert(abi.encodeWithSelector(StreamRecordJson.RecordPayloadMismatch.selector));
            StreamWorkRecordJson.requireExact(d, wrong[i]);
        }
        StreamWorkRecordJson.requireExact(d, golden);
    }

    function testFuzzChangedStoredByteCannotMatch(uint256 position, uint8 mask) public {
        bytes memory raw = vm.readFileBinary("test/fixtures/metadata/work-simple-v1.json");
        raw[position % raw.length] ^= bytes1(mask == 0 ? 1 : mask);
        vm.expectRevert(abi.encodeWithSelector(StreamRecordJson.RecordPayloadMismatch.selector));
        StreamWorkRecordJson.requireExact(_simple(), raw);
    }

    function testFuzzFullWidthRationalWordsRemainExact(uint256 n, uint256 den) public pure {
        if (n == 0) n = 1;
        if (den == 0) den = 1;
        StreamWorkRecordTypes.Measurements memory m;
        m.hasDuration = true;
        m.durationSeconds = StreamWorkRecordTypes.Rational(n, den);
        string memory expected = string.concat(
            '{"durationSeconds":{"denominator":"',
            _decimal(den),
            '","numerator":"',
            _decimal(n),
            '"},"kind":"measured"}'
        );
        require(
            keccak256(bytes(StreamWorkRecordFields.measurements(m))) == keccak256(bytes(expected)),
            "independent decimal oracle"
        );
    }

    function _decimal(uint256 n) private pure returns (string memory) {
        bytes memory reverse = new bytes(78);
        uint256 count;
        do {
            reverse[count++] = bytes1(uint8(48 + n % 10));
            n /= 10;
        } while (n != 0);
        bytes memory out = new bytes(count);
        for (uint256 i; i < count; ++i) {
            out[i] = reverse[count - 1 - i];
        }
        return string(out);
    }

    function _repeat(uint256 length) private pure returns (string memory) {
        bytes memory out = new bytes(length);
        for (uint256 i; i < length; ++i) {
            out[i] = "x";
        }
        return string(out);
    }
}

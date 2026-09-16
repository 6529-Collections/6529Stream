// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../../../smart-contracts/domains/records/StreamConservationLanguage.sol";

contract StreamConservationLanguageTest {
    function _check(string memory tag, bool expected) private view {
        bytes32 original = keccak256(bytes(tag));
        (bool ok,) = address(StreamConservationLanguage)
            .staticcall(
                abi.encodeWithSelector(StreamConservationLanguage.requireWellFormed.selector, tag)
            );
        require(ok == expected, "RFC grammar acceptance");
        require(keccak256(bytes(tag)) == original, "source tag mutated");
    }

    function testRFCExamplesAcrossAllSyntaxClasses() external view {
        string[18] memory tags = [
            "de",
            "fr",
            "ja",
            "i-enochian",
            "zh-Hant",
            "zh-Hans-CN",
            "sr-Latn-RS",
            "zh-cmn-Hans-CN",
            "zh-yue-HK",
            "sl-rozaj-biske",
            "sl-nedis",
            "de-CH-1901",
            "sl-IT-nedis",
            "en-Latn-US",
            "es-419",
            "de-CH-x-phonebk",
            "az-Arab-x-AZE-derbend",
            "en-a-myext-b-another"
        ];
        for (uint256 i; i < tags.length; ++i) {
            _check(tags[i], true);
        }
    }

    function testCompleteGrandfatheredSetAndExactCaseRetention() external view {
        string[26] memory tags = [
            "en-GB-oed",
            "i-ami",
            "i-bnn",
            "i-default",
            "i-enochian",
            "i-hak",
            "i-klingon",
            "i-lux",
            "i-mingo",
            "i-navajo",
            "i-pwn",
            "i-tao",
            "i-tay",
            "i-tsu",
            "sgn-BE-FR",
            "sgn-BE-NL",
            "sgn-CH-DE",
            "art-lojban",
            "cel-gaulish",
            "no-bok",
            "no-nyn",
            "zh-guoyu",
            "zh-hakka",
            "zh-min",
            "zh-min-nan",
            "zh-xiang"
        ];
        for (uint256 i; i < tags.length; ++i) {
            _check(tags[i], true);
            bytes memory upper = bytes(tags[i]);
            for (uint256 j; j < upper.length; ++j) {
                if (upper[j] >= "a" && upper[j] <= "z") upper[j] = bytes1(uint8(upper[j]) - 32);
            }
            _check(string(upper), true);
        }
    }

    function testMalformedOrderingDelimitersAndMissingExtensionBodiesReject() external view {
        string[24] memory tags = [
            "",
            "a",
            "123",
            "-en",
            "en-",
            "en--US",
            "en_US",
            "en US",
            "en\n",
            "en/US",
            "en-abcdefghi",
            "x",
            "en-x",
            "en-a",
            "en-a-x-private",
            "en-US-Latn",
            "en-Latn-cmn",
            "en-US-GB",
            "en-123-456",
            "en-abcd-abcd",
            "i-notreal",
            "en-GB-oed-x-extra",
            "abc-def-ghi-jkl-mno",
            "en-12ab-12ab"
        ];
        for (uint256 i; i < tags.length; ++i) {
            _check(tags[i], false);
        }
    }

    function testCaseInsensitiveVariantsAndSingletonsRejectButPrivateRepetitionDoesNot()
        external
        view
    {
        _check("sl-rozaj-ROZAJ", false);
        _check("en-abcde-AbCdE", false);
        _check("en-a-foo-A-bar", false);
        _check("en-0-foo-0-bar", false);
        _check("en-a-foo-b-foo", true);
        _check("en-x-foo-foo", true);
        _check("x-a-A-a", true);
    }

    function testWellFormedDoesNotClaimDatedRegistryMembership() external view {
        _check("zzzz", true);
        _check("abcdefgh", true);
        _check("en-abcde", true);
        _check("en-a-unlisted", true);
    }

    function testNoArbitraryTagOrVariantCountCapWithinTotalBound() external view {
        string memory tag = "en";
        for (uint256 i; i < 80; ++i) {
            tag = string.concat(
                tag,
                "-abc",
                string(abi.encodePacked(bytes1(uint8(97 + i / 26)), bytes1(uint8(97 + i % 26))))
            );
        }
        require(bytes(tag).length > 255, "long valid grammar fixture");
        _check(tag, true);
        _check(string.concat(tag, "-abcaa"), false);
    }

    function testNonASCIIAndCompleteTagLimitRejectWithoutTrimming() external view {
        _check(unicode"é", false);
        _check(string(abi.encodePacked("en-", bytes1(0xff))), false);
        bytes memory tag = new bytes(8193);
        tag[0] = "x";
        for (uint256 i = 1; i < tag.length; i += 2) {
            tag[i] = "-";
            tag[i + 1] = "a";
        }
        _check(string(tag), false);
    }

    function testFuzzOriginalCasingNeverChangesLanguageOrUniqueness(uint256 seed) external view {
        bytes memory tag = bytes("sl-rozaj-biske-1994-a-extend-x-private");
        for (uint256 i; i < tag.length; ++i) {
            if ((seed >> (i % 256)) & 1 != 0 && tag[i] >= "a" && tag[i] <= "z") {
                tag[i] = bytes1(uint8(tag[i]) - 32);
            }
        }
        _check(string(tag), true);
        _check(
            string.concat(
                "sl-rozaj-",
                string(abi.encodePacked(bytes1(uint8(seed & 1 == 0 ? 0x72 : 0x52)))),
                "OZAJ"
            ),
            false
        );
    }
}

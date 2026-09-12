// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./StreamRecordJson.sol";
import "./StreamWorkFormatJson.sol";
import "../../interfaces/stream/metadata/StreamWorkRecordTypes.sol";

/// @notice Closed, lossless field encodings for the WORK_DESCRIPTION interpretation.
library StreamWorkRecordFields {
    error InvalidWorkField();

    function creator(StreamWorkRecordTypes.Creator memory c) public pure returns (string memory) {
        if (c.kind == StreamWorkRecordTypes.CreatorKind.ARTIST) {
            if (
                c.artistId == 0 || c.bindingGeneration == 0 || c.bindingHash == 0
                    || bytes(c.name).length != 0
            ) revert InvalidWorkField();
            return string.concat(
                '{"artistId":',
                StreamRecordJson.hexValue(c.artistId),
                ',"association":{"bindingGeneration":',
                StreamRecordJson.unsigned(c.bindingGeneration),
                ',"bindingHash":',
                StreamRecordJson.hexValue(c.bindingHash),
                '},"kind":"artist"}'
            );
        }
        if (c.artistId != 0 || c.bindingGeneration != 0 || c.bindingHash != 0) {
            revert InvalidWorkField();
        }
        return
            string.concat(
                '{"kind":"named","name":', StreamRecordJson.quote(c.name, 512, false), "}"
            );
    }

    function creation(StreamWorkRecordTypes.Creation memory c) public pure returns (string memory) {
        if (c.kind == StreamWorkRecordTypes.DateKind.EXACT) {
            if (c.end != 0) revert InvalidWorkField();
            return string.concat('{"date":', StreamRecordJson.date(c.start), ',"kind":"date"}');
        }
        if (c.end < c.start) revert InvalidWorkField();
        return string.concat(
            '{"end":',
            StreamRecordJson.date(c.end),
            ',"kind":"range","start":',
            StreamRecordJson.date(c.start),
            "}"
        );
    }

    function measurements(StreamWorkRecordTypes.Measurements memory m)
        public
        pure
        returns (string memory)
    {
        if (
            (!m.hasPixels && (m.width != 0 || m.height != 0))
                || (!m.hasAspectRatio
                    && (m.aspectRatio.numerator != 0 || m.aspectRatio.denominator != 0))
                || (!m.hasDuration
                    && (m.durationSeconds.numerator != 0 || m.durationSeconds.denominator != 0))
        ) {
            revert InvalidWorkField();
        }
        if (m.kind == StreamWorkRecordTypes.MeasurementKind.DIMENSIONLESS_GENERATIVE) {
            if (m.hasPixels || m.hasAspectRatio || m.hasDuration) revert InvalidWorkField();
            return '{"kind":"dimensionless_generative"}';
        }
        if (!m.hasPixels && !m.hasAspectRatio && !m.hasDuration) revert InvalidWorkField();
        string memory out = "{";
        if (m.hasAspectRatio) {
            out = string.concat(out, '"aspectRatio":', _rational(m.aspectRatio), ",");
        }
        if (m.hasDuration) {
            out = string.concat(out, '"durationSeconds":', _rational(m.durationSeconds), ",");
        }
        out = string.concat(out, '"kind":"measured"');
        if (m.hasPixels) {
            if (m.width == 0 || m.height == 0) revert InvalidWorkField();
            out = string.concat(
                out,
                ',"pixels":{"height":',
                StreamRecordJson.unsigned(m.height),
                ',"unit":"pixels","width":',
                StreamRecordJson.unsigned(m.width),
                "}"
            );
        }
        return string.concat(out, "}");
    }

    function _rational(StreamWorkRecordTypes.Rational memory r)
        private
        pure
        returns (string memory)
    {
        if (r.numerator == 0 || r.denominator == 0) {
            revert InvalidWorkField();
        }
        return string.concat(
            '{"denominator":',
            StreamRecordJson.unsigned(r.denominator),
            ',"numerator":',
            StreamRecordJson.unsigned(r.numerator),
            "}"
        );
    }

    function edition(StreamWorkRecordTypes.Edition memory e) public pure returns (string memory) {
        if (e.kind == StreamWorkRecordTypes.EditionKind.SERIAL) {
            if (e.number == 0 || e.total < e.number || bytes(e.statement).length != 0) {
                revert InvalidWorkField();
            }
            return string.concat(
                '{"kind":"serial","number":',
                StreamRecordJson.unsigned(e.number),
                ',"total":',
                StreamRecordJson.unsigned(e.total),
                "}"
            );
        }
        if (e.number != 0 || e.total != 0) revert InvalidWorkField();
        if (e.kind == StreamWorkRecordTypes.EditionKind.OPEN_SERIES) {
            return string.concat(
                '{"kind":"open_series","statement":',
                StreamRecordJson.quote(e.statement, 512, false),
                "}"
            );
        }
        if (bytes(e.statement).length != 0) revert InvalidWorkField();
        return '{"kind":"unique"}';
    }

    function alternateTitles(string[] memory titles) public pure returns (string memory) {
        if (titles.length > 8) revert InvalidWorkField();
        string memory out = "[";
        for (uint256 i; i < titles.length; ++i) {
            out = string.concat(
                out, i == 0 ? "" : ",", StreamRecordJson.quote(titles[i], 256, false)
            );
        }
        return string.concat(out, "]");
    }

    function languageVariants(StreamWorkRecordTypes.FullDescription memory f)
        public
        pure
        returns (string memory)
    {
        if (f.languageVariants.length > 8) revert InvalidWorkField();
        string memory out = "[";
        for (uint256 i; i < f.languageVariants.length; ++i) {
            StreamWorkRecordTypes.LanguageVariant memory v = f.languageVariants[i];
            if (v.field == StreamWorkRecordTypes.VariantField.ALTERNATE_TITLE) {
                if (v.alternateTitleIndex >= f.alternateTitles.length) revert InvalidWorkField();
            } else if (v.alternateTitleIndex != 0) {
                revert InvalidWorkField();
            }
            if (
                (v.field == StreamWorkRecordTypes.VariantField.INSCRIPTION && !f.hasInscription)
                    || (v.field == StreamWorkRecordTypes.VariantField.CREATOR_NAME
                        && f.creator.kind != StreamWorkRecordTypes.CreatorKind.NAMED)
            ) revert InvalidWorkField();
            _language(v.language);
            string memory row = "{";
            if (v.field == StreamWorkRecordTypes.VariantField.ALTERNATE_TITLE) {
                row = string.concat(
                    row,
                    '"alternateTitleIndex":',
                    StreamRecordJson.unsigned(v.alternateTitleIndex),
                    ","
                );
            }
            out = string.concat(
                out,
                i == 0 ? "" : ",",
                row,
                '"field":',
                _field(v.field),
                ',"language":',
                StreamRecordJson.quote(v.language, 16, false),
                ',"value":',
                StreamRecordJson.quote(v.value, 1024, false),
                "}"
            );
        }
        return string.concat(out, "]");
    }

    function authorityReferences(StreamWorkRecordTypes.AuthorityReference[] memory refs)
        public
        pure
        returns (string memory)
    {
        if (refs.length > 16) revert InvalidWorkField();
        string memory out = "[";
        for (uint256 i; i < refs.length; ++i) {
            StreamWorkRecordTypes.AuthorityReference memory r = refs[i];
            bool aat = r.authority == StreamWorkRecordTypes.Authority.GETTY_AAT;
            if ((r.role == StreamWorkRecordTypes.AuthorityRole.CREATOR) == aat) {
                revert InvalidWorkField();
            }
            bytes memory id = bytes(r.identifier);
            uint256 start;
            if (r.authority == StreamWorkRecordTypes.Authority.WIKIDATA) {
                if (id.length < 2 || id.length > 21 || id[0] != "Q") revert InvalidWorkField();
                start = 1;
            } else if (r.authority == StreamWorkRecordTypes.Authority.VIAF) {
                if (id.length == 0 || id.length > 22) revert InvalidWorkField();
            } else if (id.length != 9) {
                revert InvalidWorkField();
            }
            if (id[start] < "1" || id[start] > "9") revert InvalidWorkField();
            for (uint256 j = start + 1; j < id.length; ++j) {
                if (id[j] < "0" || id[j] > "9") revert InvalidWorkField();
            }
            out = string.concat(
                out,
                i == 0 ? "" : ",",
                '{"authority":',
                _authority(r.authority),
                ',"identifier":',
                StreamRecordJson.quote(r.identifier, 22, false),
                ',"role":',
                r.role == StreamWorkRecordTypes.AuthorityRole.CREATOR
                    ? '"creator"'
                    : r.role == StreamWorkRecordTypes.AuthorityRole.MEDIUM
                        ? '"medium"'
                        : '"technique"',
                "}"
            );
        }
        return string.concat(out, "]");
    }

    function requireEmptyFull(StreamWorkRecordTypes.FullDescription memory f) public pure {
        if (
            bytes(f.title).length != 0 || bytes(f.medium).length != 0
                || bytes(f.creditLine).length != 0 || f.hasInscription
                || bytes(f.inscription).length != 0 || f.alternateTitles.length != 0
                || f.languageVariants.length != 0 || f.authorityReferences.length != 0
                || uint8(f.creator.kind) != 0 || f.creator.artistId != 0
                || f.creator.bindingGeneration != 0 || f.creator.bindingHash != 0
                || bytes(f.creator.name).length != 0 || uint8(f.creation.kind) != 0
                || f.creation.start != 0 || f.creation.end != 0 || uint8(f.format.kind) != 0
                || f.format.formatId != 0 || bytes(f.format.puid).length != 0
                || uint8(f.edition.kind) != 0 || f.edition.number != 0 || f.edition.total != 0
                || bytes(f.edition.statement).length != 0
        ) revert InvalidWorkField();
        StreamWorkFormatJson.requireEmptyCatalog(f.format.catalog);
        StreamWorkRecordTypes.Measurements memory m = f.measurements;
        if (
            uint8(m.kind) != 0 || m.hasPixels || m.width != 0 || m.height != 0 || m.hasAspectRatio
                || m.aspectRatio.numerator != 0 || m.aspectRatio.denominator != 0 || m.hasDuration
                || m.durationSeconds.numerator != 0 || m.durationSeconds.denominator != 0
        ) revert InvalidWorkField();
    }

    function _language(string memory value) private pure {
        bytes memory b = bytes(value);
        uint256 i;
        while (i < b.length && _alpha(b[i])) ++i;
        if (i < 2 || i > 3) revert InvalidWorkField();
        if (i == b.length) return;
        if (b[i++] != "-") revert InvalidWorkField();
        uint256 start = i;
        while (i < b.length && _alpha(b[i])) ++i;
        if (i - start == 4) {
            if (i == b.length) return;
            if (b[i++] != "-") revert InvalidWorkField();
            start = i;
            while (i < b.length && _alpha(b[i])) ++i;
        }
        if (i - start == 2 && i == b.length) return;
        if (i != start || b.length - start != 3) revert InvalidWorkField();
        for (; i < b.length; ++i) {
            if (b[i] < "0" || b[i] > "9") revert InvalidWorkField();
        }
    }

    function _alpha(bytes1 b) private pure returns (bool) {
        return (b >= "a" && b <= "z") || (b >= "A" && b <= "Z");
    }

    function _field(StreamWorkRecordTypes.VariantField f) private pure returns (string memory) {
        if (f == StreamWorkRecordTypes.VariantField.TITLE) return '"title"';
        if (f == StreamWorkRecordTypes.VariantField.MEDIUM) return '"medium"';
        if (f == StreamWorkRecordTypes.VariantField.CREDIT) return '"creditLine"';
        if (f == StreamWorkRecordTypes.VariantField.INSCRIPTION) return '"inscription"';
        if (f == StreamWorkRecordTypes.VariantField.CREATOR_NAME) return '"creatorName"';
        return '"alternateTitle"';
    }

    function _authority(StreamWorkRecordTypes.Authority a) private pure returns (string memory) {
        if (a == StreamWorkRecordTypes.Authority.ULAN) return '"ulan"';
        if (a == StreamWorkRecordTypes.Authority.VIAF) return '"viaf"';
        if (a == StreamWorkRecordTypes.Authority.WIKIDATA) return '"wikidata"';
        return '"getty_aat"';
    }
}

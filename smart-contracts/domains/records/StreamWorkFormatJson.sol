// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./StreamRecordJson.sol";
import "../../interfaces/stream/metadata/StreamWorkRecordTypes.sol";

/// @notice Complete bounded catalog witnesses and exact digital-format declarations.
/// @dev Pure correspondence only: an authenticated consumer must compare catalogDocument
///      to the actual registered bytes. Neither a PUID nor a digest proves format detection.
library StreamWorkFormatJson {
    error InvalidWorkFormat();

    function serialize(StreamWorkRecordTypes.Format memory f) public pure returns (string memory) {
        if (f.kind == StreamWorkRecordTypes.FormatKind.CATALOG) {
            if (bytes(f.puid).length != 0 || f.formatId != f.catalog.selectedEntryId) {
                revert InvalidWorkFormat();
            }
            bytes memory document = catalogDocument(f.catalog);
            string memory mappingValue;
            for (uint256 i; i < f.catalog.entries.length; ++i) {
                if (f.catalog.entries[i].entryId == f.formatId) {
                    mappingValue = _mapping(f.catalog.entries[i]);
                }
            }
            return string.concat(
                '{"catalog":{"documentHash":',
                StreamRecordJson.hexValue(keccak256(document)),
                ',"documentId":',
                StreamRecordJson.hexValue(keccak256(bytes(f.catalog.name))),
                ',"name":',
                StreamRecordJson.quote(f.catalog.name, 128, false),
                '},"formatId":',
                StreamRecordJson.hexValue(f.formatId),
                ',"kind":"catalog","mapping":',
                mappingValue,
                "}"
            );
        }
        requireEmptyCatalog(f.catalog);
        if (f.kind == StreamWorkRecordTypes.FormatKind.NONDIGITAL) {
            if (f.formatId != 0 || bytes(f.puid).length != 0) revert InvalidWorkFormat();
            return '{"kind":"nondigital"}';
        }
        _puid(f.puid);
        if (f.formatId != keccak256(bytes(string.concat("PRONOM:", f.puid)))) {
            revert InvalidWorkFormat();
        }
        return string.concat(
            '{"formatId":',
            StreamRecordJson.hexValue(f.formatId),
            ',"kind":"pronom","puid":',
            StreamRecordJson.quote(f.puid, 32, false),
            "}"
        );
    }

    /// @notice Entire ordered supported catalog document, including every unselected entry.
    /// @dev Name belongs to registration identity; selection belongs to the work witness.
    ///      Neither belongs inside the catalog's own content commitment.
    function catalogDocument(StreamWorkRecordTypes.Catalog memory c)
        public
        pure
        returns (bytes memory)
    {
        bytes memory name = bytes(c.name);
        if (
            name.length == 0 || name.length > 128 || c.entries.length == 0 || c.entries.length > 8
                || c.selectedEntryId == 0
        ) revert InvalidWorkFormat();
        for (uint256 i; i < name.length; ++i) {
            bytes1 b = name[i];
            if (!((b >= "A" && b <= "Z") || (b >= "a" && b <= "z") || (b >= "0" && b <= "9")
                        || b == "_" || b == "." || b == "-")) {
                revert InvalidWorkFormat();
            }
        }
        string memory out = '{"entries":[';
        bool selected;
        for (uint256 i; i < c.entries.length; ++i) {
            if (c.entries[i].entryId == 0) revert InvalidWorkFormat();
            for (uint256 j; j < i; ++j) {
                if (c.entries[i].entryId == c.entries[j].entryId) revert InvalidWorkFormat();
            }
            if (c.entries[i].entryId == c.selectedEntryId) selected = true;
            out = string.concat(
                out,
                i == 0 ? "" : ",",
                '{"entryId":',
                StreamRecordJson.hexValue(c.entries[i].entryId),
                ',"mapping":',
                _mapping(c.entries[i]),
                "}"
            );
        }
        out = string.concat(out, '],"version":1}');
        if (!selected || bytes(out).length > 8192) revert InvalidWorkFormat();
        return bytes(out);
    }

    function requireEmptyCatalog(StreamWorkRecordTypes.Catalog memory c) public pure {
        if (bytes(c.name).length != 0 || c.entries.length != 0 || c.selectedEntryId != 0) {
            revert InvalidWorkFormat();
        }
    }

    function _mapping(StreamWorkRecordTypes.CatalogEntry memory e)
        private
        pure
        returns (string memory)
    {
        if (e.kind == StreamWorkRecordTypes.MappingKind.PRONOM) {
            if (bytes(e.specification.uri).length != 0 || e.specification.digest != 0) {
                revert InvalidWorkFormat();
            }
            _puid(e.puid);
            return string.concat(
                '{"kind":"pronom","puid":', StreamRecordJson.quote(e.puid, 32, false), "}"
            );
        }
        if (bytes(e.puid).length != 0 || e.specification.digest == 0) revert InvalidWorkFormat();
        StreamMetadataRenderer.requireValidUtf8ContentUri(
            "workFormat", e.specification.uri, 2048, false
        );
        return string.concat(
            '{"kind":"specification","specification":{"hash":{"algorithm":1,"canonicalizationId":',
            StreamRecordJson.hexValue(keccak256("RAW_BYTES")),
            ',"digest":',
            StreamRecordJson.hexValue(e.specification.digest),
            '},"uri":',
            StreamRecordJson.quote(e.specification.uri, 2048, false),
            "}}"
        );
    }

    function _puid(string memory value) private pure {
        bytes memory b = bytes(value);
        uint256 first;
        if (b.length >= 5 && b[0] == "f" && b[1] == "m" && b[2] == "t" && b[3] == "/") {
            first = 4;
        } else if (
            b.length >= 7 && b[0] == "x" && b[1] == "-" && b[2] == "f" && b[3] == "m" && b[4] == "t"
                && b[5] == "/"
        ) {
            first = 6;
        } else {
            revert InvalidWorkFormat();
        }
        if (b.length > 32 || b[first] < "1" || b[first] > "9") revert InvalidWorkFormat();
        for (uint256 i = first + 1; i < b.length; ++i) {
            if (b[i] < "0" || b[i] > "9") revert InvalidWorkFormat();
        }
    }
}

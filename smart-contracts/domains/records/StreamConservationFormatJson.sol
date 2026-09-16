// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./StreamConservationRecordFields.sol";

/// @notice Exact format declarations and complete supported catalog reconstruction.
/// @dev Actual consumers authenticate registered schema/profile/content. No format detection.
library StreamConservationFormatJson {
    error InvalidConservationFormat();

    function serialize(StreamConservationRecordTypes.Format memory f)
        public
        pure
        returns (string memory)
    {
        if (f.kind == StreamConservationRecordTypes.FormatKind.PRONOM) {
            if (
                bytes(f.catalog.name).length != 0 || f.catalog.entries.length != 0
                    || f.catalog.selectedEntryId != 0
            ) revert InvalidConservationFormat();
            _puid(f.puid);
            if (f.formatId != keccak256(bytes(string.concat("PRONOM:", f.puid)))) {
                revert InvalidConservationFormat();
            }
            return string.concat(
                '{"formatId":',
                StreamRecordJson.hexValue(f.formatId),
                ',"kind":"pronom","puid":',
                StreamRecordJson.quote(f.puid, 32, false),
                "}"
            );
        }
        if (bytes(f.puid).length != 0 || f.formatId != f.catalog.selectedEntryId) {
            revert InvalidConservationFormat();
        }
        bytes memory document = catalogDocument(f.catalog);
        string memory selected;
        for (uint256 i; i < f.catalog.entries.length; ++i) {
            if (f.catalog.entries[i].entryId == f.formatId) {
                selected = _mapping(f.catalog.entries[i]);
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
            selected,
            "}"
        );
    }

    /// @notice All entries are checked, ordered and committed, including unselected entries.
    function catalogDocument(StreamConservationRecordTypes.Catalog memory c)
        public
        pure
        returns (bytes memory)
    {
        bytes memory name = bytes(c.name);
        if (
            name.length == 0 || name.length > 128 || c.entries.length == 0 || c.selectedEntryId == 0
        ) {
            revert InvalidConservationFormat();
        }
        for (uint256 i; i < name.length; ++i) {
            bytes1 b = name[i];
            if (!((b >= "A" && b <= "Z") || (b >= "a" && b <= "z") || (b >= "0" && b <= "9")
                        || b == "_" || b == "." || b == "-")) revert InvalidConservationFormat();
        }
        bytes[] memory rows = new bytes[](c.entries.length);
        bytes32[] memory ids = new bytes32[](c.entries.length);
        bool found;
        for (uint256 i; i < c.entries.length; ++i) {
            bytes32 id = c.entries[i].entryId;
            if (id == 0) revert InvalidConservationFormat();
            ids[i] = id;
            if (id == c.selectedEntryId) found = true;
            rows[i] = bytes(
                string.concat(
                    '{"entryId":',
                    StreamRecordJson.hexValue(id),
                    ',"mapping":',
                    _mapping(c.entries[i]),
                    "}"
                )
            );
        }
        if (!found) revert InvalidConservationFormat();
        _unique(ids);
        return StreamConservationRecordFields.requirePayloadSize(
            bytes(
                string.concat(
                    '{"entries":', StreamConservationRecordFields.arrayJSON(rows), ',"version":1}'
                )
            )
        );
    }

    function _mapping(StreamConservationRecordTypes.CatalogEntry memory e)
        private
        pure
        returns (string memory)
    {
        if (e.kind == StreamConservationRecordTypes.MappingKind.PRONOM) {
            StreamConservationRecordFields.requireEmptyReference(e.specification);
            _puid(e.puid);
            return string.concat(
                '{"kind":"pronom","puid":', StreamRecordJson.quote(e.puid, 32, false), "}"
            );
        }
        if (bytes(e.puid).length != 0) revert InvalidConservationFormat();
        return string.concat(
            '{"kind":"specification","specification":',
            StreamConservationRecordFields.referenceJSON(e.specification),
            "}"
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
            revert InvalidConservationFormat();
        }
        if (b.length > 32 || b[first] < "1" || b[first] > "9") revert InvalidConservationFormat();
        for (uint256 i = first + 1; i < b.length; ++i) {
            if (b[i] < "0" || b[i] > "9") revert InvalidConservationFormat();
        }
    }

    function _unique(bytes32[] memory a) private pure {
        for (uint256 i = a.length / 2; i != 0;) {
            --i;
            _sift(a, i, a.length);
        }
        for (uint256 end = a.length; end > 1;) {
            --end;
            (a[0], a[end]) = (a[end], a[0]);
            _sift(a, 0, end);
        }
        for (uint256 i = 1; i < a.length; ++i) {
            if (a[i] == a[i - 1]) revert InvalidConservationFormat();
        }
    }

    function _sift(bytes32[] memory a, uint256 root, uint256 n) private pure {
        while (root < n / 2) {
            uint256 child = root * 2 + 1;
            if (child + 1 < n && a[child] < a[child + 1]) ++child;
            if (a[root] >= a[child]) return;
            (a[root], a[child]) = (a[child], a[root]);
            root = child;
        }
    }
}

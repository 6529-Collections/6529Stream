// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/// @notice Fixed framing of all 34 original Identity fields from their complete typed encodings.
/// @dev Only fixed producer stages use these internal helpers. No storage root, call target or
/// selector is inferred from bytes. Nested tuple and array offsets are never rewritten.
library StreamArtistRecoveredIdentityExportEncoding {
    function join(bytes[34] memory fields) internal pure returns (bytes memory result) {
        uint256 length = 2400;
        for (uint256 i; i < 34; ++i) {
            if (_dynamic(i)) {
                _single(fields[i]);
                length += fields[i].length - 32;
            } else if (fields[i].length != _width(i)) {
                assembly ("memory-safe") { revert(0, 0) }
            }
        }
        result = new bytes(length);
        _store(result, 0, 32);
        uint256 head = 32;
        uint256 tail = 2400;
        for (uint256 i; i < 34; ++i) {
            bytes memory field = fields[i];
            if (_dynamic(i)) {
                _store(result, head, tail - 32);
                _copy(field, 32, result, tail, field.length - 32);
                tail += field.length - 32;
            } else {
                _copy(field, 0, result, head, field.length);
            }
            head += _width(i);
        }
    }

    function replaceContinuations(bytes memory canonical, bytes memory fourArrays)
        internal
        pure
        returns (bytes memory)
    {
        bytes[34] memory fields = split(canonical);
        if (fourArrays.length < 256 || fourArrays.length % 32 != 0) {
            assembly ("memory-safe") { revert(0, 0) }
        }
        for (uint256 i; i < 4; ++i) {
            uint256 start = _word(fourArrays, i * 32);
            uint256 end = i == 3 ? fourArrays.length : _word(fourArrays, (i + 1) * 32);
            if (
                (i == 0 && start != 128) || start % 32 != 0 || end % 32 != 0
                    || end > fourArrays.length || end < start || end - start < 32
            ) assembly ("memory-safe") { revert(0, 0) }
            fields[30 + i] = new bytes(32 + end - start);
            _store(fields[30 + i], 0, 32);
            _copy(fourArrays, start, fields[30 + i], 32, end - start);
        }
        return join(fields);
    }

    function split(bytes memory canonical) internal pure returns (bytes[34] memory fields) {
        _single(canonical);
        if (canonical.length < 2400) assembly ("memory-safe") { revert(0, 0) }
        uint256[34] memory starts;
        uint256 head = 32;
        for (uint256 i; i < 34; ++i) {
            if (_dynamic(i)) {
                starts[i] = _word(canonical, head) + 32;
            } else {
                fields[i] = new bytes(_width(i));
                _copy(canonical, head, fields[i], 0, _width(i));
            }
            head += _width(i);
        }
        uint256 expected = 2400;
        for (uint256 i; i < 34; ++i) {
            if (!_dynamic(i)) continue;
            uint256 end = canonical.length;
            for (uint256 j = i + 1; j < 34; ++j) {
                if (_dynamic(j)) {
                    end = starts[j];
                    break;
                }
            }
            if (
                starts[i] != expected || end % 32 != 0 || end > canonical.length || end < expected
                    || end - expected < 32
            ) assembly ("memory-safe") { revert(0, 0) }
            fields[i] = new bytes(32 + end - expected);
            _store(fields[i], 0, 32);
            _copy(canonical, expected, fields[i], 32, end - expected);
            expected = end;
        }
    }

    /// @dev Each element is the original fixed row type's abi.encode(row), in original order.
    function array(bytes[] memory rows, bool dynamicRow)
        internal
        pure
        returns (bytes memory result)
    {
        uint256 head = dynamicRow ? 32 * rows.length : 0;
        uint256 length = 64 + head;
        for (uint256 i; i < rows.length; ++i) {
            if (dynamicRow) {
                _single(rows[i]);
            } else if (rows[i].length == 0 || rows[i].length % 32 != 0) {
                assembly ("memory-safe") { revert(0, 0) }
            }
            length += rows[i].length - (dynamicRow ? 32 : 0);
        }
        result = new bytes(length);
        _store(result, 0, 32);
        _store(result, 32, rows.length);
        uint256 tail = 64 + head;
        for (uint256 i; i < rows.length; ++i) {
            uint256 skip = dynamicRow ? 32 : 0;
            if (dynamicRow) _store(result, 64 + i * 32, tail - 64);
            _copy(rows[i], skip, result, tail, rows[i].length - skip);
            tail += rows[i].length - skip;
        }
    }

    function _dynamic(uint256 field) private pure returns (bool) {
        return field != 0 && field != 1 && field != 2 && field != 6;
    }

    function _width(uint256 field) private pure returns (uint256) {
        if (field == 1) return 128;
        if (field == 6) return 1216;
        return 32;
    }

    function _single(bytes memory value) private pure {
        if (value.length < 64 || value.length % 32 != 0 || _word(value, 0) != 32) {
            assembly ("memory-safe") { revert(0, 0) }
        }
    }

    function _word(bytes memory data, uint256 at) private pure returns (uint256 value) {
        assembly ("memory-safe") { value := mload(add(add(data, 32), at)) }
    }

    function _store(bytes memory data, uint256 at, uint256 value) private pure {
        assembly ("memory-safe") { mstore(add(add(data, 32), at), value) }
    }

    function _copy(bytes memory from, uint256 start, bytes memory to, uint256 at, uint256 length)
        private
        pure
    {
        for (uint256 i; i < length; i += 32) {
            assembly ("memory-safe") {
                mstore(add(add(to, 32), add(at, i)), mload(add(add(from, 32), add(start, i))))
            }
        }
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../metadata/StreamMetadataRenderer.sol";

/// @notice Exact primitives for closed, fixed-key JSON record profiles.
/// @dev No generic JSON parsing, Unicode normalization, floating point, or authority decision.
library StreamRecordJson {
    error InvalidJsonWitness();
    error RecordPayloadMismatch();

    function quote(string memory value, uint256 maximum, bool allowEmpty)
        public
        pure
        returns (string memory)
    {
        if (
            (!allowEmpty && bytes(value).length == 0) || bytes(value).length > maximum
                || !StreamMetadataRenderer.isValidUtf8(value)
        ) revert InvalidJsonWitness();
        return string.concat('"', StreamMetadataRenderer.escapeJsonString(value), '"');
    }

    function hexValue(bytes32 value) public pure returns (string memory) {
        return _hex(abi.encodePacked(value));
    }

    function account(address value) public pure returns (string memory) {
        if (value == address(0)) revert InvalidJsonWitness();
        return _hex(abi.encodePacked(value));
    }

    function _hex(bytes memory input) private pure returns (string memory) {
        bytes memory alphabet = "0123456789abcdef";
        bytes memory output = new bytes(4 + input.length * 2);
        output[0] = '"';
        output[1] = "0";
        output[2] = "x";
        for (uint256 i; i < input.length; ++i) {
            output[3 + i * 2] = alphabet[uint8(input[i]) >> 4];
            output[4 + i * 2] = alphabet[uint8(input[i]) & 15];
        }
        output[output.length - 1] = '"';
        return string(output);
    }

    /// @notice Canonical decimal string, preserving the complete uint256 range.
    function unsigned(uint256 value) public pure returns (string memory) {
        uint256 digits = 1;
        for (uint256 remaining = value; remaining >= 10; remaining /= 10) {
            ++digits;
        }
        bytes memory output = new bytes(digits + 2);
        output[0] = '"';
        output[digits + 1] = '"';
        do {
            output[digits--] = bytes1(uint8(48 + value % 10));
            value /= 10;
        } while (value != 0);
        return string(output);
    }

    /// @notice Exact proleptic Gregorian YYYY-MM-DD, years 0001..9999, no inferred timezone.
    function date(uint32 value) public pure returns (string memory) {
        uint256 year = value / 10000;
        uint256 month = value / 100 % 100;
        uint256 day = value % 100;
        if (year == 0 || year > 9999 || month == 0 || month > 12 || day == 0) {
            revert InvalidJsonWitness();
        }
        uint256 maximum = month == 2
            ? (year % 4 == 0 && (year % 100 != 0 || year % 400 == 0) ? 29 : 28)
            : (month == 4 || month == 6 || month == 9 || month == 11 ? 30 : 31);
        if (day > maximum) revert InvalidJsonWitness();
        bytes memory output = bytes('"0000-00-00"');
        output[1] = bytes1(uint8(48 + year / 1000));
        output[2] = bytes1(uint8(48 + year / 100 % 10));
        output[3] = bytes1(uint8(48 + year / 10 % 10));
        output[4] = bytes1(uint8(48 + year % 10));
        output[6] = bytes1(uint8(48 + month / 10));
        output[7] = bytes1(uint8(48 + month % 10));
        output[9] = bytes1(uint8(48 + day / 10));
        output[10] = bytes1(uint8(48 + day % 10));
        return string(output);
    }

    function requirePayload(bytes memory serialized, bytes memory stored)
        public
        pure
        returns (bytes32 hash)
    {
        if (
            serialized.length == 0 || serialized.length > 8192 || serialized.length != stored.length
        ) revert RecordPayloadMismatch();
        hash = keccak256(serialized);
        if (hash != keccak256(stored)) revert RecordPayloadMismatch();
        // Do not accept a witness that describes only a projection of the recorded object.
        for (uint256 i; i < stored.length; ++i) {
            if (serialized[i] != stored[i]) revert RecordPayloadMismatch();
        }
    }
}

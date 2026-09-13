// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/// @notice Verbatim pre-optimization renderer functions retained only for differential tests.
/// @dev Source: f79ddb0d smart-contracts/domains/metadata/StreamMetadataRenderer.sol.
library LegacyJsonEscapingOracle {
    function escapeJsonString(string memory raw) public pure returns (string memory) {
        bytes memory input = bytes(raw);
        bytes memory output = new bytes(input.length * 6);
        uint256 outputLength = 0;

        for (uint256 i = 0; i < input.length; i++) {
            bytes1 character = input[i];
            if (character == 0x22) {
                output[outputLength] = 0x5c;
                outputLength++;
                output[outputLength] = 0x22;
                outputLength++;
            } else if (character == 0x5c) {
                output[outputLength] = 0x5c;
                outputLength++;
                output[outputLength] = 0x5c;
                outputLength++;
            } else if (character == 0x08) {
                output[outputLength] = 0x5c;
                outputLength++;
                output[outputLength] = 0x62;
                outputLength++;
            } else if (character == 0x0c) {
                output[outputLength] = 0x5c;
                outputLength++;
                output[outputLength] = 0x66;
                outputLength++;
            } else if (character == 0x0a) {
                output[outputLength] = 0x5c;
                outputLength++;
                output[outputLength] = 0x6e;
                outputLength++;
            } else if (character == 0x0d) {
                output[outputLength] = 0x5c;
                outputLength++;
                output[outputLength] = 0x72;
                outputLength++;
            } else if (character == 0x09) {
                output[outputLength] = 0x5c;
                outputLength++;
                output[outputLength] = 0x74;
                outputLength++;
            } else if (uint8(character) < 0x20) {
                output[outputLength] = 0x5c;
                outputLength++;
                output[outputLength] = 0x75;
                outputLength++;
                output[outputLength] = 0x30;
                outputLength++;
                output[outputLength] = 0x30;
                outputLength++;
                output[outputLength] = _hexNibble(uint8(character) >> 4);
                outputLength++;
                output[outputLength] = _hexNibble(uint8(character) & 0x0f);
                outputLength++;
            } else {
                output[outputLength] = character;
                outputLength++;
            }
        }

        return string(_truncateBytes(output, outputLength));
    }

    function _truncateBytes(bytes memory input, uint256 length)
        private
        pure
        returns (bytes memory)
    {
        bytes memory output = new bytes(length);
        for (uint256 i = 0; i < length; i++) {
            output[i] = input[i];
        }
        return output;
    }

    function _hexNibble(uint8 value) private pure returns (bytes1) {
        return bytes1(value < 10 ? value + 0x30 : value + 0x57);
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./StreamMetadataRenderer.sol";
import "../../vendor/openzeppelin/Base64.sol";

/// @notice Image-only URI admission, preserving the existing external content-URI policy.
/// @dev Inline raster signatures are admission checks, not complete image decoding or renderability.
///      SVG, HTML, extra MIME parameters, whitespace and noncanonical Base64 are not admitted.
library StreamMetadataImageURI {
    function requireImageURI(string memory uri) public pure {
        StreamMetadataRenderer.requireValidUtf8Bytes(bytes32("image"), uri, 2048);
        if (StreamMetadataRenderer.isSafeContentUri(uri, true)) return;
        bytes memory value = bytes(uri);
        uint256 offset;
        uint8 kind;
        if (_prefix(value, "data:image/png;base64,")) {
            offset = 22;
            kind = 1;
        } else if (_prefix(value, "data:image/jpeg;base64,")) {
            offset = 23;
            kind = 2;
        } else if (_prefix(value, "data:image/gif;base64,")) {
            offset = 22;
            kind = 3;
        } else if (_prefix(value, "data:image/webp;base64,")) {
            offset = 23;
            kind = 4;
        } else {
            revert StreamMetadataRenderer.UnsafeMetadataURI();
        }
        bytes memory decoded = _decode(value, offset);
        bytes memory canonical = bytes(Base64.encode(decoded));
        if (value.length != offset + canonical.length) {
            revert StreamMetadataRenderer.UnsafeMetadataURI();
        }
        for (uint256 i; i < canonical.length; ++i) {
            if (canonical[i] != value[offset + i]) {
                revert StreamMetadataRenderer.UnsafeMetadataURI();
            }
        }
        bool valid;
        if (kind == 1) {
            valid = _prefix(decoded, hex"89504e470d0a1a0a");
        } else if (kind == 2) {
            valid = _prefix(decoded, hex"ffd8ff");
        } else if (kind == 3) {
            valid = _prefix(decoded, "GIF87a") || _prefix(decoded, "GIF89a");
        } else {
            valid = decoded.length >= 12 && _prefix(decoded, "RIFF") && decoded[8] == "W"
                && decoded[9] == "E" && decoded[10] == "B" && decoded[11] == "P";
        }
        if (!valid) revert StreamMetadataRenderer.UnsafeMetadataURI();
    }

    function _decode(bytes memory value, uint256 offset)
        private
        pure
        returns (bytes memory result)
    {
        uint256 length = value.length - offset;
        if (length == 0 || length % 4 != 0) revert StreamMetadataRenderer.UnsafeMetadataURI();
        uint256 padding = value[value.length - 1] == "=" ? 1 : 0;
        if (value[value.length - 2] == "=") ++padding;
        result = new bytes(length / 4 * 3 - padding);
        uint256 output;
        for (uint256 i = offset; i < value.length; i += 4) {
            uint256 word = (_digit(value[i]) << 18) | (_digit(value[i + 1]) << 12);
            if (value[i + 2] != "=") {
                word |= _digit(value[i + 2]) << 6;
            } else if (i + 4 != value.length || padding != 2) {
                revert StreamMetadataRenderer.UnsafeMetadataURI();
            }
            if (value[i + 3] != "=") {
                word |= _digit(value[i + 3]);
            } else if (i + 4 != value.length || padding == 0) {
                revert StreamMetadataRenderer.UnsafeMetadataURI();
            }
            result[output++] = bytes1(uint8(word >> 16));
            if (output < result.length) result[output++] = bytes1(uint8(word >> 8));
            if (output < result.length) result[output++] = bytes1(uint8(word));
        }
    }

    function _digit(bytes1 c) private pure returns (uint256) {
        uint8 value = uint8(c);
        if (value >= 65 && value <= 90) return value - 65;
        if (value >= 97 && value <= 122) return value - 71;
        if (value >= 48 && value <= 57) return value + 4;
        if (c == "+") return 62;
        if (c == "/") return 63;
        revert StreamMetadataRenderer.UnsafeMetadataURI();
    }

    function _prefix(bytes memory value, bytes memory prefix) private pure returns (bool) {
        if (value.length < prefix.length) return false;
        for (uint256 i; i < prefix.length; ++i) {
            if (value[i] != prefix[i]) return false;
        }
        return true;
    }
}

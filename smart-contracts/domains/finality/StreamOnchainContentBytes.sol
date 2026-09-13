// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../../vendor/openzeppelin/Base64.sol";

/// @notice Exact byte comparisons for the declared Stream inline ONCHAIN serialization.
/// @dev No generic JSON parser or JCS claim. The immutable known router emits animation last.
library StreamOnchainContentBytes {
    function matchesAnimation(bytes memory json, bytes memory animation)
        public
        pure
        returns (bool)
    {
        bytes memory suffix = abi.encodePacked(
            ',"animation_url":"data:text/html;base64,', Base64.encode(animation), '"}'
        );
        if (suffix.length > json.length) return false;
        uint256 offset = json.length - suffix.length;
        bytes32 actual;
        assembly ("memory-safe") {
            actual := keccak256(add(add(json, 32), offset), mload(suffix))
        }
        return actual == keccak256(suffix);
    }

    /// @notice Empty means absent. Nonempty images must be exact inline base64 data URI bytes.
    function matchesImage(bytes memory json, string memory imageURI, bytes memory image)
        public
        pure
        returns (bool)
    {
        bytes memory uri = bytes(imageURI);
        if (!_containsImageField(json, uri)) return false;
        if (uri.length == 0) return image.length == 0;
        if (image.length == 0 || uri.length < 20) return false;
        bytes memory requiredPrefix = bytes("data:image/");
        for (uint256 i; i < requiredPrefix.length; ++i) {
            if (uri[i] != requiredPrefix[i]) return false;
        }
        uint256 comma = requiredPrefix.length;
        while (comma < uri.length && comma < 128 && uri[comma] != bytes1(",")) ++comma;
        if (comma >= uri.length || comma >= 128 || comma <= 18) return false;
        bytes memory encoding = bytes(";base64");
        for (uint256 i; i < encoding.length; ++i) {
            if (uri[comma - encoding.length + i] != encoding[i]) return false;
        }
        for (uint256 i = requiredPrefix.length; i < comma - encoding.length; ++i) {
            uint8 c = uint8(uri[i]);
            if (!((c >= 97 && c <= 122) || (c >= 48 && c <= 57) || c == 43 || c == 45 || c == 46)) {
                return false;
            }
        }
        bytes memory expected = bytes(Base64.encode(image));
        if (uri.length != comma + 1 + expected.length) return false;
        bytes32 actual;
        assembly ("memory-safe") {
            actual := keccak256(add(add(uri, 33), comma), mload(expected))
        }
        return actual == keccak256(expected);
    }

    function _containsImageField(bytes memory json, bytes memory uri) private pure returns (bool) {
        bytes memory prefix = bytes(',"image":"');
        bytes memory field = abi.encodePacked(prefix, uri, '",');
        if (field.length > json.length) return false;
        for (uint256 i; i <= json.length - field.length; ++i) {
            if (json[i] != bytes1(",")) continue;
            bool matchPrefix = true;
            for (uint256 j = 1; j < prefix.length; ++j) {
                if (json[i + j] != prefix[j]) {
                    matchPrefix = false;
                    break;
                }
            }
            if (matchPrefix) {
                bytes32 actual;
                assembly ("memory-safe") {
                    actual := keccak256(add(add(json, 32), i), mload(field))
                }
                return actual == keccak256(field);
            }
        }
        return false;
    }
}

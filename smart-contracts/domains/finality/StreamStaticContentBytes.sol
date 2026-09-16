// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import { Base64 } from "../../vendor/openzeppelin/Base64.sol";

/// @notice Exact fields of the fixed STATIC-v1 serializer, never a generic JSON/JCS parser.
library StreamStaticContentBytes {
    function matches(bytes memory json, bytes memory html, bytes memory tokenData)
        internal
        pure
        returns (bool)
    {
        return _field(
            json,
            abi.encodePacked(
            ',"animation_url":"data:text/html;base64,', Base64.encode(html), '","metadata_state":"'
        )
        )
            && _field(
            json,
            abi.encodePacked(
            ',"token_data_base64":"', Base64.encode(tokenData), '","properties":{"stream":'
        )
        );
    }

    function _field(bytes memory json, bytes memory field) private pure returns (bool) {
        if (field.length > json.length) return false;
        bytes32 expected = keccak256(field);
        bytes32 firstWord;
        assembly ("memory-safe") { firstWord := mload(add(field, 32)) }
        for (uint256 i; i <= json.length - field.length; ++i) {
            if (json[i] != 0x2c || json[i + 1] != 0x22) continue;
            // Exact fixed serializer keys cannot occur unescaped inside a JSON string.
            bytes32 actual;
            assembly ("memory-safe") { actual := mload(add(add(json, 32), i)) }
            if (actual != firstWord) continue;
            assembly ("memory-safe") { actual := keccak256(add(add(json, 32), i), mload(field)) }
            if (actual == expected) return true;
        }
        return false;
    }
}

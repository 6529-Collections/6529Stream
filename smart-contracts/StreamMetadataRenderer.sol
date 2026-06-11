// SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

import "./Base64.sol";
import "./Strings.sol";

library StreamMetadataRenderer {
    using Strings for uint256;

    uint8 private constant _RAW_ATTRIBUTE_TRAIT_TYPE_KEY = 1;
    uint8 private constant _RAW_ATTRIBUTE_VALUE_KEY = 2;

    function onchainTokenURI(
        string memory schemaVersion,
        string memory metadataState,
        string memory name,
        string memory description,
        string memory image,
        string memory attributes,
        string memory collectionLibrary,
        string memory animationScript,
        bool includeAnimation
    ) public pure returns (string memory) {
        return string(
            abi.encodePacked(
                "data:application/json;base64,",
                Base64.encode(
                    bytes(
                        onchainMetadataJson(
                            schemaVersion,
                            metadataState,
                            name,
                            description,
                            image,
                            attributes,
                            collectionLibrary,
                            animationScript,
                            includeAnimation
                        )
                    )
                )
            )
        );
    }

    function onchainMetadataJson(
        string memory schemaVersion,
        string memory metadataState,
        string memory name,
        string memory description,
        string memory image,
        string memory attributes,
        string memory collectionLibrary,
        string memory animationScript,
        bool includeAnimation
    ) public pure returns (string memory) {
        string memory animationField = "";
        if (includeAnimation) {
            animationField = string(
                abi.encodePacked(
                    ",\"animation_url\":\"",
                    escapeJsonString(onchainAnimationURI(collectionLibrary, animationScript)),
                    "\""
                )
            );
        }

        return string(
            abi.encodePacked(
                "{\"metadata_schema_version\":\"",
                escapeJsonString(schemaVersion),
                "\",\"metadata_state\":\"",
                escapeJsonString(metadataState),
                "\",\"name\":\"",
                escapeJsonString(name),
                "\",\"description\":\"",
                escapeJsonString(description),
                "\",\"image\":\"",
                escapeJsonString(image),
                "\",\"attributes\":[",
                attributes,
                "]",
                animationField,
                "}"
            )
        );
    }

    function onchainAnimationURI(string memory collectionLibrary, string memory animationScript)
        public
        pure
        returns (string memory)
    {
        return string(
            abi.encodePacked(
                "data:text/html;base64,",
                Base64.encode(
                    abi.encodePacked(
                        "<html><head></head><body><script src=\"",
                        escapeHtmlAttribute(collectionLibrary),
                        "\"></script><script>",
                        escapeScriptElementEndTags(animationScript),
                        "</script></body></html>"
                    )
                )
            )
        );
    }

    function generativeScript(
        bytes32 tokenHash,
        uint256 tokenId,
        string memory tokenData,
        string memory dependencyScript,
        string memory collectionScript
    ) public pure returns (string memory) {
        return string(
            abi.encodePacked(
                "let hash='",
                Strings.toHexString(uint256(tokenHash), 32),
                "';let tokenId=",
                tokenId.toString(),
                ";let tokenDataRaw='",
                escapeJavaScriptSingleQuotedString(tokenData),
                "';let tokenData=JSON.parse('['+tokenDataRaw+']')",
                ";let dependencyScript='",
                escapeJavaScriptSingleQuotedString(dependencyScript),
                "';",
                collectionScript
            )
        );
    }

    function escapeHtmlAttribute(string memory raw) public pure returns (string memory) {
        bytes memory input = bytes(raw);
        bytes memory output = new bytes(input.length * 6);
        uint256 outputLength = 0;

        for (uint256 i = 0; i < input.length; i++) {
            bytes1 character = input[i];
            if (character == 0x26) {
                outputLength = _appendBytes(output, outputLength, "&amp;");
            } else if (character == 0x22) {
                outputLength = _appendBytes(output, outputLength, "&quot;");
            } else if (character == 0x27) {
                outputLength = _appendBytes(output, outputLength, "&#39;");
            } else if (character == 0x3c) {
                outputLength = _appendBytes(output, outputLength, "&lt;");
            } else if (character == 0x3e) {
                outputLength = _appendBytes(output, outputLength, "&gt;");
            } else if (uint8(character) < 0x20 || character == 0x7f) {
                output[outputLength] = 0x26;
                outputLength++;
                output[outputLength] = 0x23;
                outputLength++;
                output[outputLength] = 0x78;
                outputLength++;
                output[outputLength] = _hexNibble(uint8(character) >> 4);
                outputLength++;
                output[outputLength] = _hexNibble(uint8(character) & 0x0f);
                outputLength++;
                output[outputLength] = 0x3b;
                outputLength++;
            } else {
                output[outputLength] = character;
                outputLength++;
            }
        }

        return string(_truncateBytes(output, outputLength));
    }

    function escapeJavaScriptSingleQuotedString(string memory raw)
        public
        pure
        returns (string memory)
    {
        bytes memory input = bytes(raw);
        bytes memory output = new bytes(input.length * 6);
        uint256 outputLength = 0;

        for (uint256 i = 0; i < input.length; i++) {
            bytes1 character = input[i];
            if (character == 0x27 || character == 0x5c) {
                output[outputLength] = 0x5c;
                outputLength++;
                output[outputLength] = character;
                outputLength++;
            } else if (character == 0x0a) {
                outputLength = _appendBytes(output, outputLength, "\\n");
            } else if (character == 0x0d) {
                outputLength = _appendBytes(output, outputLength, "\\r");
            } else if (character == 0x09) {
                outputLength = _appendBytes(output, outputLength, "\\t");
            } else if (
                uint8(character) < 0x20 || character == 0x3c || character == 0x3e
                    || character == 0x26
            ) {
                output[outputLength] = 0x5c;
                outputLength++;
                output[outputLength] = 0x78;
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

    function escapeScriptElementEndTags(string memory raw) public pure returns (string memory) {
        bytes memory input = bytes(raw);
        bytes memory output = new bytes(input.length * 2);
        uint256 outputLength = 0;

        for (uint256 i = 0; i < input.length; i++) {
            if (_isScriptEndTagStart(input, i)) {
                output[outputLength] = 0x3c;
                outputLength++;
                output[outputLength] = 0x5c;
                outputLength++;
                output[outputLength] = 0x2f;
                outputLength++;
                i++;
            } else {
                output[outputLength] = input[i];
                outputLength++;
            }
        }

        return string(_truncateBytes(output, outputLength));
    }

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

    function isSafeRawAttributes(string memory raw) public pure returns (bool) {
        bytes memory input = bytes(raw);
        uint256 index = _skipRawAttributeSpaces(input, 0);
        if (index == input.length) {
            return true;
        }

        while (index < input.length) {
            bool ok;
            (ok, index) = _parseRawAttributeObject(input, index);
            if (!ok) {
                return false;
            }

            index = _skipRawAttributeSpaces(input, index);
            if (index == input.length) {
                return true;
            }
            if (input[index] != 0x2c) {
                return false;
            }
            index = _skipRawAttributeSpaces(input, index + 1);
            if (index == input.length) {
                return false;
            }
        }

        return true;
    }

    function isSafeContentUri(string memory uri, bool allowEmpty) public pure returns (bool) {
        bytes memory input = bytes(uri);
        if (input.length == 0) {
            return allowEmpty;
        }
        if (!_hasNoUriWhitespaceOrControls(input)) {
            return false;
        }
        return (_startsWith(input, "https://") && _hasHttpsHost(input))
            || (_startsWith(input, "ipfs://") && input.length > 7)
            || (_startsWith(input, "ar://") && input.length > 5);
    }

    function isSafeScriptUri(string memory uri) public pure returns (bool) {
        return isSafeScriptUri(uri, false);
    }

    function isSafeScriptUri(string memory uri, bool allowEmpty) public pure returns (bool) {
        bytes memory input = bytes(uri);
        if (input.length == 0) {
            return allowEmpty;
        }
        return _hasNoUriWhitespaceOrControls(input) && _startsWith(input, "https://")
            && _hasHttpsHost(input);
    }

    function areSafeCollectionUris(string memory baseURI, string memory libraryUrl)
        public
        pure
        returns (bool)
    {
        return isSafeContentUri(baseURI, true) && isSafeScriptUri(libraryUrl, true);
    }

    function supportsContractMarker(address target, bytes4 selector)
        public
        view
        returns (bool supported)
    {
        if (target.code.length == 0) {
            return false;
        }
        assembly {
            let ptr := mload(0x40)
            mstore(ptr, selector)
            let success := staticcall(gas(), target, ptr, 4, ptr, 32)
            supported := and(and(success, gt(returndatasize(), 31)), eq(mload(ptr), 1))
        }
    }

    function _parseRawAttributeObject(bytes memory input, uint256 index)
        private
        pure
        returns (bool, uint256)
    {
        if (index >= input.length || input[index] != 0x7b) {
            return (false, index);
        }

        index = _skipRawAttributeSpaces(input, index + 1);
        uint8 seenKeys = 0;
        bool ok;
        uint8 key;
        (ok, index, key) = _parseRawAttributePair(input, index, seenKeys);
        if (!ok) {
            return (false, index);
        }
        seenKeys |= key;

        index = _skipRawAttributeSpaces(input, index);
        if (index >= input.length || input[index] != 0x2c) {
            return (false, index);
        }

        index = _skipRawAttributeSpaces(input, index + 1);
        (ok, index, key) = _parseRawAttributePair(input, index, seenKeys);
        if (!ok) {
            return (false, index);
        }
        seenKeys |= key;

        index = _skipRawAttributeSpaces(input, index);
        if (seenKeys != (_RAW_ATTRIBUTE_TRAIT_TYPE_KEY | _RAW_ATTRIBUTE_VALUE_KEY)) {
            return (false, index);
        }
        if (index >= input.length || input[index] != 0x7d) {
            return (false, index);
        }
        return (true, index + 1);
    }

    function _parseRawAttributePair(bytes memory input, uint256 index, uint8 seenKeys)
        private
        pure
        returns (bool, uint256, uint8)
    {
        bool ok;
        uint8 key;
        (ok, index, key) = _parseRawAttributeKey(input, index);
        if (!ok || (seenKeys & key) != 0) {
            return (false, index, 0);
        }

        index = _skipRawAttributeSpaces(input, index);
        if (index >= input.length || input[index] != 0x3a) {
            return (false, index, 0);
        }

        index = _skipRawAttributeSpaces(input, index + 1);
        (ok, index) = _parseJsonStringValue(input, index);
        if (!ok) {
            return (false, index, 0);
        }
        return (true, index, key);
    }

    function _parseRawAttributeKey(bytes memory input, uint256 index)
        private
        pure
        returns (bool, uint256, uint8)
    {
        if (_matches(input, index, "\"trait_type\"")) {
            return (true, index + 12, _RAW_ATTRIBUTE_TRAIT_TYPE_KEY);
        }
        if (_matches(input, index, "\"value\"")) {
            return (true, index + 7, _RAW_ATTRIBUTE_VALUE_KEY);
        }
        return (false, index, 0);
    }

    function _parseJsonStringValue(bytes memory input, uint256 index)
        private
        pure
        returns (bool, uint256)
    {
        if (index >= input.length || input[index] != 0x22) {
            return (false, index);
        }

        index++;
        while (index < input.length) {
            uint8 value = uint8(input[index]);
            if (value < 0x20) {
                return (false, index);
            }
            if (value == 0x22) {
                return (true, index + 1);
            }
            if (value == 0x5c) {
                index++;
                if (index >= input.length) {
                    return (false, index);
                }
                if (input[index] == 0x75) {
                    if (index + 4 >= input.length) {
                        return (false, index);
                    }
                    for (uint256 offset = 1; offset <= 4; offset++) {
                        if (!_isHexDigit(input[index + offset])) {
                            return (false, index);
                        }
                    }
                    index += 5;
                } else if (_isSimpleJsonEscape(input[index])) {
                    index++;
                } else {
                    return (false, index);
                }
            } else {
                index++;
            }
        }

        return (false, index);
    }

    function _skipRawAttributeSpaces(bytes memory input, uint256 index)
        private
        pure
        returns (uint256)
    {
        while (index < input.length && input[index] == 0x20) {
            index++;
        }
        return index;
    }

    function _matches(bytes memory input, uint256 index, string memory raw)
        private
        pure
        returns (bool)
    {
        bytes memory expected = bytes(raw);
        if (index + expected.length > input.length) {
            return false;
        }
        for (uint256 i = 0; i < expected.length; i++) {
            if (input[index + i] != expected[i]) {
                return false;
            }
        }
        return true;
    }

    function _isSimpleJsonEscape(bytes1 character) private pure returns (bool) {
        return character == 0x22 || character == 0x5c || character == 0x2f || character == 0x62
            || character == 0x66 || character == 0x6e || character == 0x72 || character == 0x74;
    }

    function _isHexDigit(bytes1 character) private pure returns (bool) {
        return (character >= 0x30 && character <= 0x39) || (character >= 0x41 && character <= 0x46)
            || (character >= 0x61 && character <= 0x66);
    }

    function _isScriptEndTagStart(bytes memory input, uint256 index) private pure returns (bool) {
        if (index + 7 >= input.length || input[index] != 0x3c || input[index + 1] != 0x2f) {
            return false;
        }

        return _lowerAscii(input[index + 2]) == 0x73 && _lowerAscii(input[index + 3]) == 0x63
            && _lowerAscii(input[index + 4]) == 0x72 && _lowerAscii(input[index + 5]) == 0x69
            && _lowerAscii(input[index + 6]) == 0x70 && _lowerAscii(input[index + 7]) == 0x74;
    }

    function _hasNoUriWhitespaceOrControls(bytes memory input) private pure returns (bool) {
        for (uint256 i = 0; i < input.length; i++) {
            uint8 value = uint8(input[i]);
            if (value <= 0x20 || value == 0x7f) {
                return false;
            }
        }
        return true;
    }

    function _hasHttpsHost(bytes memory input) private pure returns (bool) {
        if (input.length <= 8) {
            return false;
        }
        bytes1 firstHostByte = input[8];
        return firstHostByte != 0x2f && firstHostByte != 0x3f && firstHostByte != 0x23;
    }

    function _startsWith(bytes memory input, string memory rawPrefix) private pure returns (bool) {
        bytes memory prefix = bytes(rawPrefix);
        if (input.length < prefix.length) {
            return false;
        }
        for (uint256 i = 0; i < prefix.length; i++) {
            if (input[i] != prefix[i]) {
                return false;
            }
        }
        return true;
    }

    function _lowerAscii(bytes1 character) private pure returns (bytes1) {
        if (character >= 0x41 && character <= 0x5a) {
            return bytes1(uint8(character) + 32);
        }
        return character;
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

    function _appendBytes(bytes memory output, uint256 outputLength, string memory raw)
        private
        pure
        returns (uint256)
    {
        bytes memory input = bytes(raw);
        for (uint256 i = 0; i < input.length; i++) {
            output[outputLength] = input[i];
            outputLength++;
        }
        return outputLength;
    }

    function _hexNibble(uint8 value) private pure returns (bytes1) {
        return bytes1(value < 10 ? value + 0x30 : value + 0x57);
    }
}

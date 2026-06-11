// SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

import "./Base64.sol";
import "./Strings.sol";

library StreamMetadataRenderer {
    using Strings for uint256;

    struct RawAttributeValidationState {
        uint256 depth;
        uint256 containerKinds;
        bool inString;
        bool escaped;
        bool sawTopLevelValue;
        bool expectingTopLevelValue;
    }

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
                schemaVersion,
                "\",\"metadata_state\":\"",
                metadataState,
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
        RawAttributeValidationState memory state = RawAttributeValidationState({
            depth: 0,
            containerKinds: 0,
            inString: false,
            escaped: false,
            sawTopLevelValue: false,
            expectingTopLevelValue: true
        });

        for (uint256 i = 0; i < input.length; i++) {
            bytes1 character = input[i];
            if (uint8(character) < 0x20) {
                return false;
            }

            if (state.inString) {
                _advanceRawAttributeStringState(state, character);
            } else if (!_advanceRawAttributeStructuralState(state, character)) {
                return false;
            }
        }

        return !(state.inString || state.escaped || state.depth != 0
                || (state.sawTopLevelValue && state.expectingTopLevelValue));
    }

    function _advanceRawAttributeStringState(
        RawAttributeValidationState memory state,
        bytes1 character
    ) private pure {
        if (state.escaped) {
            state.escaped = false;
        } else if (character == 0x5c) {
            state.escaped = true;
        } else if (character == 0x22) {
            state.inString = false;
        }
    }

    function _advanceRawAttributeStructuralState(
        RawAttributeValidationState memory state,
        bytes1 character
    ) private pure returns (bool) {
        if (character == 0x22) {
            if (state.depth == 0) {
                return false;
            }
            state.inString = true;
        } else if (character == 0x7b || character == 0x5b) {
            return _openRawAttributeContainer(state, character);
        } else if (character == 0x7d || character == 0x5d) {
            return _closeRawAttributeContainer(state, character);
        } else if (state.depth == 0) {
            return _advanceRawAttributeTopLevelSeparator(state, character);
        }
        return true;
    }

    function _openRawAttributeContainer(RawAttributeValidationState memory state, bytes1 opener)
        private
        pure
        returns (bool)
    {
        if (state.depth >= 256) {
            return false;
        }
        if (state.depth == 0) {
            if (!state.expectingTopLevelValue) {
                return false;
            }
            state.sawTopLevelValue = true;
            state.expectingTopLevelValue = false;
        }
        if (opener == 0x7b) {
            state.containerKinds |= uint256(1) << state.depth;
        } else {
            state.containerKinds &= ~(uint256(1) << state.depth);
        }
        state.depth++;
        return true;
    }

    function _closeRawAttributeContainer(RawAttributeValidationState memory state, bytes1 closer)
        private
        pure
        returns (bool)
    {
        if (state.depth == 0) {
            return false;
        }
        uint256 depthIndex = state.depth - 1;
        bool expectsObjectClose = ((state.containerKinds >> depthIndex) & 1) == 1;
        if ((closer == 0x7d) != expectsObjectClose) {
            return false;
        }
        state.containerKinds &= ~(uint256(1) << depthIndex);
        state.depth = depthIndex;
        if (state.depth == 0) {
            state.expectingTopLevelValue = false;
        }
        return true;
    }

    function _advanceRawAttributeTopLevelSeparator(
        RawAttributeValidationState memory state,
        bytes1 character
    ) private pure returns (bool) {
        if (character == 0x2c) {
            if (!state.sawTopLevelValue || state.expectingTopLevelValue) {
                return false;
            }
            state.expectingTopLevelValue = true;
        } else if (character != 0x20) {
            return false;
        }
        return true;
    }

    function _isScriptEndTagStart(bytes memory input, uint256 index) private pure returns (bool) {
        if (index + 7 >= input.length || input[index] != 0x3c || input[index + 1] != 0x2f) {
            return false;
        }

        return _lowerAscii(input[index + 2]) == 0x73 && _lowerAscii(input[index + 3]) == 0x63
            && _lowerAscii(input[index + 4]) == 0x72 && _lowerAscii(input[index + 5]) == 0x69
            && _lowerAscii(input[index + 6]) == 0x70 && _lowerAscii(input[index + 7]) == 0x74;
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

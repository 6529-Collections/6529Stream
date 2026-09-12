// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../../interfaces/stream/metadata/IStreamMetadataServingFacts.sol";
import "../../interfaces/stream/metadata/StreamMetadataRenderTypes.sol";
import "../../vendor/openzeppelin/Strings.sol";
import "../../vendor/openzeppelin/Base64.sol";
import "./StreamMetadataRenderer.sol";

/// @notice Exact deterministic Stream JSON/HTML serialization, not RFC8785/JCS canonicalization.
/// @dev Prepared fields are escaped by the router's existing fixed helper. This pure linked helper
///      makes no provider or authority calls, and preserves full uint256 decimal token identities.
library StreamMetadataTokenRenderer {
    using Strings for uint256;

    function render(
        StreamMetadataRenderTypes.Token memory token,
        IStreamMetadataServingFacts.ServingSource memory metadata,
        bytes memory artist
    ) public pure returns (string memory) {
        bool onchain = token.finalized && bytes(metadata.script).length != 0;
        string memory animation = token.finalized ? _animation(metadata, token) : "";
        bytes memory animationField = bytes(animation).length == 0
            ? bytes("")
            : abi.encodePacked(',"animation_url":"', animation, '"');
        return string(
            abi.encodePacked(
                "{",
                _identity(metadata, token),
                _properties(token, onchain),
                artist,
                animationField,
                "}"
            )
        );
    }

    /// @notice Render and encode in one frame, without copying full JSON back through the router.
    function renderURI(
        StreamMetadataRenderTypes.Token memory token,
        IStreamMetadataServingFacts.ServingSource memory metadata,
        bytes memory artist
    ) public pure returns (string memory) {
        return dataURI(render(token, metadata, artist));
    }

    function dataURI(string memory json) public pure returns (string memory) {
        return string(abi.encodePacked("data:application/json;base64,", Base64.encode(bytes(json))));
    }

    function artistFields(address artist, bytes32 identityHash, bytes32 acceptanceHash)
        public
        pure
        returns (bytes memory)
    {
        return abi.encodePacked(
            ',"artist":"',
            uint256(uint160(artist)).toHexString(20),
            '","artist_identity_hash":"',
            uint256(identityHash).toHexString(32),
            '","artist_acceptance_hash":"',
            uint256(acceptanceHash).toHexString(32),
            '"'
        );
    }

    function _identity(
        IStreamMetadataServingFacts.ServingSource memory metadata,
        StreamMetadataRenderTypes.Token memory token
    ) private pure returns (bytes memory) {
        string memory name = token.configured ? metadata.name : "6529 Stream";
        return abi.encodePacked(
            '"name":"',
            name,
            " #",
            token.serial.toString(),
            '","description":"',
            metadata.description,
            '","image":"',
            metadata.imageURI,
            '"'
        );
    }

    function _properties(StreamMetadataRenderTypes.Token memory token, bool onchain)
        private
        pure
        returns (bytes memory)
    {
        bytes memory tokenDataField = onchain
            ? bytes(',"token_data_location":"animation_url:tokenDataBase64"')
            : abi.encodePacked(',"token_data_base64":"', Base64.encode(token.tokenData), '"');
        return abi.encodePacked(
            ',"metadata_schema_version":"6529stream-v1","metadata_state":"',
            token.state,
            '","token_id":',
            token.tokenId.toString(),
            ',"collection_id":',
            token.collectionId.toString(),
            ',"collection_serial":',
            token.serial.toString(),
            ',"hash":"',
            uint256(token.seed).toHexString(32),
            '"',
            tokenDataField,
            ',"attributes":[]'
        );
    }

    function _animation(
        IStreamMetadataServingFacts.ServingSource memory metadata,
        StreamMetadataRenderTypes.Token memory token
    ) private pure returns (string memory) {
        if (bytes(metadata.script).length != 0) {
            string memory script = string(
                abi.encodePacked(
                    "const tokenId=",
                    token.tokenId.toString(),
                    ";const tokenHash='",
                    uint256(token.seed).toHexString(32),
                    "';const tokenDataBase64='",
                    Base64.encode(token.tokenData),
                    "';",
                    metadata.script
                )
            );
            return string(
                abi.encodePacked(
                    "data:text/html;base64,",
                    Base64.encode(
                        abi.encodePacked(
                            "<html><head></head><body><script>", script, "</script></body></html>"
                        )
                    )
                )
            );
        }
        if (bytes(metadata.animationBaseURI).length == 0) return "";
        return string(abi.encodePacked(metadata.animationBaseURI, token.tokenId.toString()));
    }
    error MetadataJSONLimitExceeded(uint256 bytes_, uint256 maximum);

    /// @notice Exact existing configuration escaping and aggregate bound, before storage writes.
    function prepareMetadata(
        string memory name,
        string memory description,
        string memory image,
        string memory animationBaseURI
    ) public pure returns (IStreamMetadataServingFacts.ServingSource memory) {
        name = StreamMetadataRenderer.escapeJsonString(name);
        description = StreamMetadataRenderer.escapeJsonString(description);
        image = StreamMetadataRenderer.escapeJsonString(image);
        uint256 identityBytes = bytes(name).length + bytes(description).length + bytes(image).length;
        if (identityBytes > 5120) revert MetadataJSONLimitExceeded(identityBytes, 5120);
        return IStreamMetadataServingFacts.ServingSource(
            name, description, image, StreamMetadataRenderer.escapeJsonString(animationBaseURI), ""
        );
    }

    /// @dev Escape the slash of every case-insensitive </script prefix. This preserves the
    /// JavaScript source while preventing an embedded string/comment from ending the HTML tag.
    /// Each disjoint eight-byte match adds one byte; resizing the allocation avoids a copy loop.
    function prepareScript(string memory raw) public pure returns (string memory result) {
        bytes memory source = bytes(raw);
        result = new string(source.length + source.length / 8);
        assembly ("memory-safe") {
            let cursor := add(source, 0x20)
            let end := add(cursor, mload(source))
            let output := add(result, 0x20)
            let start := output
            for { } lt(cursor, end) { cursor := add(cursor, 1) } {
                let character := byte(0, mload(cursor))
                if and(
                    iszero(gt(add(cursor, 8), end)),
                    eq(or(shr(192, mload(cursor)), 0x0000202020202020), 0x3c2f736372697074)
                ) {
                    mstore8(output, 0x3c)
                    mstore8(add(output, 1), 0x5c)
                    output := add(output, 2)
                    cursor := add(cursor, 1)
                    character := 0x2f
                }
                mstore8(output, character)
                output := add(output, 1)
            }
            mstore(result, sub(output, start))
        }
    }
}

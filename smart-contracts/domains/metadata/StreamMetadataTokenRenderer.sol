// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../../interfaces/stream/metadata/IStreamMetadataServingFacts.sol";
import "../../interfaces/stream/metadata/StreamMetadataRenderTypes.sol";
import "../../vendor/openzeppelin/Strings.sol";
import "../../vendor/openzeppelin/Base64.sol";

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
}

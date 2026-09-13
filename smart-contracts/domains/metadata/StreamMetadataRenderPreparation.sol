// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "./StreamMetadataRenderer.sol";
import "../../interfaces/stream/metadata/IStreamMetadataServingFacts.sol";
import "../../vendor/openzeppelin/Strings.sol";
import "../../vendor/openzeppelin/Base64.sol";

/// @notice Fixed serialization preparation independent of any selected/failed renderer runtime.
/// @dev These four bodies preserve the existing TokenRenderer byte preparation exactly.
library StreamMetadataRenderPreparation {
    using Strings for uint256;
    error MetadataJSONLimitExceeded(uint256 bytes_, uint256 maximum);

    function collectionURI(string memory name, string memory description, string memory image)
        public
        pure
        returns (string memory)
    {
        return dataURI(
            string(
                abi.encodePacked(
                    '{"name":"', name, '","description":"', description, '","image":"', image, '"}'
                )
            )
        );
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

    function dataURI(string memory json) public pure returns (string memory) {
        return string(abi.encodePacked("data:application/json;base64,", Base64.encode(bytes(json))));
    }
}

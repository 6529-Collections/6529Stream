// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../smart-contracts/StreamCore.sol";
import "./helpers/Assertions.sol";
import "./helpers/CharacterizationTestBase.sol";
import "./helpers/StreamFixture.sol";
// MockRandomizer.sol also defines NoopRandomizer, used here to hold pending state.
import "./mocks/MockRandomizer.sol";

contract StreamMetadataEscapingTest is CharacterizationTestBase, StreamFixture {
    using Assertions for bool;
    using Assertions for string;

    uint256 private constant COLLECTION_ID = 1;
    uint256 private constant TOKEN_ID = 10_000_000_000;
    address private constant RECIPIENT = address(0xA11CE);
    string private constant TOKEN_DATA = "1,2,3";
    uint256 private constant TOKEN_SALT = 7;
    string private constant JSON_DATA_URI_PREFIX = "data:application/json;base64,";

    function testOnchainJsonEscapesCollectionAndImageStrings() public {
        DeployedStream memory deployed = deployStream(address(0xBEEF), address(0xCAFE));
        NoopRandomizer noopRandomizer = new NoopRandomizer();
        deployed.core.addRandomizer(COLLECTION_ID, address(noopRandomizer));
        _setCollectionStringsWithJsonMetacharacters(deployed.core);
        _mintToken(deployed);
        _setImageAndAttributes(
            deployed.core,
            string(
                abi.encodePacked("ipfs://image/quote\"", bytes1(0x5c), "line", bytes1(0x0a), ".png")
            ),
            "{\"trait_type\":\"Mood\",\"value\":\"Calm\"}"
        );
        deployed.core.changeMetadataView(COLLECTION_ID, true);

        string memory decodedJson = _decodeJsonDataUri(deployed.core.tokenURI(TOKEN_ID));
        _assertJsonParses(decodedJson);

        decodedJson.assertEq(
            string.concat(
                "{\"metadata_schema_version\":\"6529stream-v1\",\"metadata_state\":\"pending\",",
                "\"name\":\"Genesis \\\"Alpha\\\"\\\\Beta #0\",",
                "\"description\":\"Line 1\\nTabbed\\tUnit\\u0001\\\"\\\\\",",
                "\"image\":\"ipfs://image/quote\\\"\\\\line\\n.png\",",
                "\"attributes\":[{\"trait_type\":\"Mood\",\"value\":\"Calm\"}]}"
            ),
            "escaped metadata JSON changed"
        );
    }

    function testRawAttributesAllowBracketsInsideJsonStrings() public {
        DeployedStream memory deployed = deployStream(address(0xBEEF), address(0xCAFE));
        NoopRandomizer noopRandomizer = new NoopRandomizer();
        deployed.core.addRandomizer(COLLECTION_ID, address(noopRandomizer));
        _mintToken(deployed);
        _setImageAndAttributes(
            deployed.core, "ipfs://image.png", "{\"trait_type\":\"Frame\",\"value\":\"[kept]\"}"
        );
        deployed.core.changeMetadataView(COLLECTION_ID, true);

        string memory decodedJson = _decodeJsonDataUri(deployed.core.tokenURI(TOKEN_ID));
        _assertJsonParses(decodedJson);
        decodedJson.assertEq(
            string.concat(
                "{\"metadata_schema_version\":\"6529stream-v1\",\"metadata_state\":\"pending\",",
                "\"name\":\"Genesis #0\",\"description\":\"Description\",",
                "\"image\":\"ipfs://image.png\",",
                "\"attributes\":[{\"trait_type\":\"Frame\",\"value\":\"[kept]\"}]}"
            ),
            "quoted attribute brackets changed"
        );
    }

    function testRawAttributesRejectBreakoutFragment() public {
        DeployedStream memory deployed = deployStream(address(0xBEEF), address(0xCAFE));
        _mintToken(deployed);

        uint256[] memory tokenIds = new uint256[](1);
        string[] memory images = new string[](1);
        string[] memory attributes = new string[](1);
        tokenIds[0] = TOKEN_ID;
        images[0] = "ipfs://image.png";
        attributes[0] = "{\"trait_type\":\"Mood\",\"value\":\"Calm\"}],\"evil\":true";

        vm.expectRevert(abi.encodeWithSelector(StreamCore.UnsafeRawAttributes.selector, TOKEN_ID));
        deployed.core.updateImagesAndAttributes(tokenIds, images, attributes);
    }

    function testRawAttributesRejectControlCharacters() public {
        DeployedStream memory deployed = deployStream(address(0xBEEF), address(0xCAFE));
        _mintToken(deployed);

        uint256[] memory tokenIds = new uint256[](1);
        string[] memory images = new string[](1);
        string[] memory attributes = new string[](1);
        tokenIds[0] = TOKEN_ID;
        images[0] = "ipfs://image.png";
        attributes[0] = string(
            abi.encodePacked("{\"trait_type\":\"Mood\",\"value\":\"Calm", bytes1(0x0a), "\"}")
        );

        vm.expectRevert(abi.encodeWithSelector(StreamCore.UnsafeRawAttributes.selector, TOKEN_ID));
        deployed.core.updateImagesAndAttributes(tokenIds, images, attributes);
    }

    function testRawAttributesRejectUnterminatedStrings() public {
        DeployedStream memory deployed = deployStream(address(0xBEEF), address(0xCAFE));
        _mintToken(deployed);

        uint256[] memory tokenIds = new uint256[](1);
        string[] memory images = new string[](1);
        string[] memory attributes = new string[](1);
        tokenIds[0] = TOKEN_ID;
        images[0] = "ipfs://image.png";
        attributes[0] = "{\"trait_type\":\"Mood\",\"value\":\"Calm}";

        vm.expectRevert(abi.encodeWithSelector(StreamCore.UnsafeRawAttributes.selector, TOKEN_ID));
        deployed.core.updateImagesAndAttributes(tokenIds, images, attributes);
    }

    function testRawAttributesRejectTopLevelLiteralAndTrailingComma() public {
        DeployedStream memory deployed = deployStream(address(0xBEEF), address(0xCAFE));
        _mintToken(deployed);

        uint256[] memory tokenIds = new uint256[](1);
        string[] memory images = new string[](1);
        string[] memory attributes = new string[](1);
        tokenIds[0] = TOKEN_ID;
        images[0] = "ipfs://image.png";

        attributes[0] = "not-json";
        vm.expectRevert(abi.encodeWithSelector(StreamCore.UnsafeRawAttributes.selector, TOKEN_ID));
        deployed.core.updateImagesAndAttributes(tokenIds, images, attributes);

        attributes[0] = "{\"trait_type\":\"Mood\",\"value\":\"Calm\"},";
        vm.expectRevert(abi.encodeWithSelector(StreamCore.UnsafeRawAttributes.selector, TOKEN_ID));
        deployed.core.updateImagesAndAttributes(tokenIds, images, attributes);
    }

    function _setCollectionStringsWithJsonMetacharacters(StreamCore core) private {
        string[] memory scripts = new string[](1);
        scripts[0] = "function draw(){}";
        core.updateCollectionInfo(
            COLLECTION_ID,
            "Genesis \"Alpha\"\\Beta",
            "6529",
            string(
                abi.encodePacked(
                    "Line 1", bytes1(0x0a), "Tabbed", bytes1(0x09), "Unit", bytes1(0x01), "\"\\"
                )
            ),
            "https://6529.io",
            "CC0",
            "ipfs://base/",
            "https://cdn.example/script.js",
            bytes32(0),
            FULL_COLLECTION_UPDATE_INDEX,
            scripts
        );
    }

    function _mintToken(DeployedStream memory deployed) private {
        vm.prank(address(deployed.minter));
        deployed.core.mint(TOKEN_ID, RECIPIENT, TOKEN_DATA, TOKEN_SALT, COLLECTION_ID);
    }

    function _setImageAndAttributes(StreamCore core, string memory image, string memory attributes)
        private
    {
        uint256[] memory tokenIds = new uint256[](1);
        string[] memory images = new string[](1);
        string[] memory attributeValues = new string[](1);
        tokenIds[0] = TOKEN_ID;
        images[0] = image;
        attributeValues[0] = attributes;
        core.updateImagesAndAttributes(tokenIds, images, attributeValues);
    }

    function _decodeJsonDataUri(string memory tokenUri) private pure returns (string memory) {
        bytes memory uri = bytes(tokenUri);
        bytes memory prefix = bytes(JSON_DATA_URI_PREFIX);
        require(uri.length >= prefix.length, "short data uri");

        for (uint256 i = 0; i < prefix.length; i++) {
            require(uri[i] == prefix[i], "wrong data uri");
        }

        bytes memory encoded = new bytes(uri.length - prefix.length);
        for (uint256 i = 0; i < encoded.length; i++) {
            encoded[i] = uri[prefix.length + i];
        }

        return string(_decodeBase64(encoded));
    }

    function _assertJsonParses(string memory json) private pure {
        bytes memory parsed = vm.parseJson(json);
        (parsed.length != 0).assertTrue("decoded JSON did not parse");
    }

    function _decodeBase64(bytes memory input) private pure returns (bytes memory) {
        require(input.length % 4 == 0, "invalid base64 length");
        if (input.length == 0) {
            return "";
        }

        uint256 padding = 0;
        if (input[input.length - 1] == 0x3d) {
            padding++;
        }
        if (input[input.length - 2] == 0x3d) {
            padding++;
        }

        bytes memory output = new bytes((input.length * 3) / 4 - padding);
        uint256 outputIndex = 0;

        for (uint256 i = 0; i < input.length; i += 4) {
            uint256 combined = (uint256(_base64Value(input[i])) << 18)
                | (uint256(_base64Value(input[i + 1])) << 12)
                | (input[i + 2] == 0x3d ? 0 : uint256(_base64Value(input[i + 2])) << 6)
                | (input[i + 3] == 0x3d ? 0 : uint256(_base64Value(input[i + 3])));
            bytes32 decoded = bytes32(combined << 232);

            output[outputIndex] = decoded[0];
            outputIndex++;
            if (outputIndex < output.length) {
                output[outputIndex] = decoded[1];
                outputIndex++;
            }
            if (outputIndex < output.length) {
                output[outputIndex] = decoded[2];
                outputIndex++;
            }
        }

        return output;
    }

    function _base64Value(bytes1 character) private pure returns (uint8) {
        uint8 value = uint8(character);
        if (value >= 0x41 && value <= 0x5a) {
            return value - 0x41;
        }
        if (value >= 0x61 && value <= 0x7a) {
            return value - 0x61 + 26;
        }
        if (value >= 0x30 && value <= 0x39) {
            return value - 0x30 + 52;
        }
        if (value == 0x2b) {
            return 62;
        }
        if (value == 0x2f) {
            return 63;
        }
        revert("invalid base64");
    }
}

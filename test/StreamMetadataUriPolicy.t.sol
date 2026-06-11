// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../smart-contracts/StreamCore.sol";
import "../smart-contracts/StreamMetadataRenderer.sol";
import "./helpers/Assertions.sol";
import "./helpers/CharacterizationTestBase.sol";
import "./helpers/StreamFixture.sol";

contract StreamMetadataUriPolicyTest is CharacterizationTestBase, StreamFixture {
    using Assertions for bool;

    uint256 private constant COLLECTION_ID = 1;
    uint256 private constant TOKEN_ID = 10_000_000_000;
    address private constant RECIPIENT = address(0xA11CE);

    function testRendererUriPolicyHelpers() public pure {
        StreamMetadataRenderer.isSafeContentUri("https://metadata.example/base/", false)
            .assertTrue("https content uri rejected");
        StreamMetadataRenderer.isSafeContentUri("ipfs://image/10000000000.png", false)
            .assertTrue("ipfs content uri rejected");
        StreamMetadataRenderer.isSafeContentUri("ar://transaction-id", false)
            .assertTrue("ar content uri rejected");
        StreamMetadataRenderer.isSafeContentUri("", true).assertTrue("empty optional uri rejected");
        StreamMetadataRenderer.isSafeContentUri("", false)
            .assertFalse("empty required uri accepted");
        StreamMetadataRenderer.isSafeContentUri("javascript:alert(1)", false)
            .assertFalse("javascript uri accepted");
        StreamMetadataRenderer.isSafeContentUri("https:///missing-host", false)
            .assertFalse("hostless https uri accepted");
        StreamMetadataRenderer.isSafeContentUri("https://metadata.example/bad path", false)
            .assertFalse("whitespace uri accepted");
        StreamMetadataRenderer.isSafeScriptUri("https://cdn.example/script.js")
            .assertTrue("https script uri rejected");
        StreamMetadataRenderer.isSafeScriptUri("ipfs://dependency/script.js")
            .assertFalse("ipfs script uri accepted");
    }

    function testProductionTokenImagePolicyAcceptsAllowedUris() public {
        DeployedStream memory deployed = deployStream(address(0xBEEF), address(0xCAFE));
        _mintToken(deployed);

        _updateTokenImage(deployed.core, "https://image.example/token.png");
        _updateTokenImage(deployed.core, "ipfs://image/10000000000.png");
        _updateTokenImage(deployed.core, "ar://image-transaction-id");
    }

    function testTokenImageRejectsUnsafeProductionUris() public {
        DeployedStream memory deployed = deployStream(address(0xBEEF), address(0xCAFE));
        _mintToken(deployed);

        vm.expectRevert(abi.encodeWithSelector(StreamCore.UnsafeMetadataURI.selector));
        _updateTokenImage(deployed.core, "");

        vm.expectRevert(abi.encodeWithSelector(StreamCore.UnsafeMetadataURI.selector));
        _updateTokenImage(deployed.core, "javascript:alert(1)");

        vm.expectRevert(abi.encodeWithSelector(StreamCore.UnsafeMetadataURI.selector));
        _updateTokenImage(deployed.core, "https://image.example/bad path.png");
    }

    function _mintToken(DeployedStream memory deployed) private {
        vm.prank(address(deployed.minter));
        deployed.core.mint(TOKEN_ID, RECIPIENT, "1,2,3", 7, COLLECTION_ID);
    }

    function _updateTokenImage(StreamCore core, string memory image) private {
        uint256[] memory tokenIds = new uint256[](1);
        string[] memory images = new string[](1);
        string[] memory attributes = new string[](1);
        tokenIds[0] = TOKEN_ID;
        images[0] = image;
        attributes[0] = "{\"trait_type\":\"Mood\",\"value\":\"Calm\"}";
        core.updateImagesAndAttributes(tokenIds, images, attributes);
    }
}

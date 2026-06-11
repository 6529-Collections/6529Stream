// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../smart-contracts/StreamCore.sol";
import "./helpers/CharacterizationTestBase.sol";
import "./helpers/StreamFixture.sol";

contract StreamCoreCustomErrorsTest is CharacterizationTestBase, StreamFixture {
    uint256 private constant COLLECTION_ID = 1;
    address private constant ARTIST = address(0xA11CE);
    address private constant UNAUTHORIZED = address(0xBAD);

    function testFunctionAdminRequiredUsesCustomError() public {
        DeployedStream memory deployed = deployStream(address(0xBEEF), address(0xCAFE));

        vm.expectRevert(abi.encodeWithSelector(StreamCore.FunctionAdminUnauthorized.selector));
        vm.prank(UNAUTHORIZED);
        deployed.core.changeMetadataView(COLLECTION_ID, true);
    }

    function testArtistSignatureUsesCustomErrorForWrongSignerAndDuplicateSignature() public {
        DeployedStream memory deployed = deployStream(address(0xBEEF), address(0xCAFE));

        vm.expectRevert(abi.encodeWithSelector(StreamCore.ArtistSignatureUnauthorized.selector));
        deployed.core.artistSignature(COLLECTION_ID, "not-artist");

        vm.prank(ARTIST);
        deployed.core.artistSignature(COLLECTION_ID, "artist-signature");

        vm.expectRevert(abi.encodeWithSelector(StreamCore.ArtistSignatureUnauthorized.selector));
        vm.prank(ARTIST);
        deployed.core.artistSignature(COLLECTION_ID, "second-signature");
    }

    function testUpdateImagesAndAttributesUsesCustomErrorForMismatchedArrayLengths() public {
        DeployedStream memory deployed = deployStream(address(0xBEEF), address(0xCAFE));
        uint256[] memory tokenIds = new uint256[](1);
        string[] memory images = new string[](0);
        string[] memory attributes = new string[](1);

        vm.expectRevert(abi.encodeWithSelector(StreamCore.InvalidTokenMetadataInput.selector));
        deployed.core.updateImagesAndAttributes(tokenIds, images, attributes);
    }

    function testSetFinalSupplyUsesCustomErrorBeforeFinalSupplyWindowEnds() public {
        DeployedStream memory deployed = deployStream(address(0xBEEF), address(0xCAFE));

        vm.expectRevert(abi.encodeWithSelector(StreamCore.FinalSupplyTimeNotPassed.selector));
        deployed.core.setFinalSupply(COLLECTION_ID);
    }
}

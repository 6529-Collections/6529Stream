// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../smart-contracts/StreamCore.sol";
import "./helpers/Assertions.sol";
import "./helpers/CharacterizationTestBase.sol";
import "./helpers/StreamFixture.sol";

contract StreamArtistSignatureTest is CharacterizationTestBase, StreamFixture {
    using Assertions for bool;
    using Assertions for bytes32;
    using Assertions for string;

    uint256 private constant COLLECTION_ID = 1;
    address private constant ARTIST = address(0xA11CE);

    function testArtistSignatureStoresStateBoundApprovalHash() public {
        DeployedStream memory deployed = deployStream(address(0xBEEF), address(0xCAFE));

        vm.prank(ARTIST);
        deployed.core.artistSignature(COLLECTION_ID, "artist-approved-genesis");

        deployed.core.artistSigned(COLLECTION_ID).assertTrue("artist signature flag not stored");
        deployed.core.artistsSignatures(COLLECTION_ID)
            .assertEq("artist-approved-genesis", "artist signature text not stored");
        (deployed.core.artistApprovalHashes(COLLECTION_ID) != bytes32(0))
            .assertTrue("artist approval hash not stored");
    }

    function testArtistApprovalHashTracksCollectionStateChanges() public {
        DeployedStream memory deployed = deployStream(address(0xBEEF), address(0xCAFE));
        vm.prank(ARTIST);
        deployed.core.artistSignature(COLLECTION_ID, "artist-approved-genesis");
        bytes32 beforeUpdate = deployed.core.artistApprovalHashes(COLLECTION_ID);

        DeployedStream memory changed = deployStream(address(0xBEEF), address(0xCAFE));

        changed.core.setCollectionData(COLLECTION_ID, ARTIST, 9, 10, 2 days);

        string[] memory scripts = new string[](1);
        scripts[0] = "function draw(){return 1;}";
        changed.core
            .updateCollectionInfo(
                COLLECTION_ID,
                "Genesis",
                "6529",
                "Description",
                "https://6529.io",
                "CC0",
                "ipfs://new-base/",
                "https://cdn.example/script.js",
                bytes32(0),
                FULL_COLLECTION_UPDATE_INDEX,
                scripts
            );

        vm.prank(ARTIST);
        changed.core.artistSignature(COLLECTION_ID, "artist-approved-updated");
        bytes32 afterUpdate = changed.core.artistApprovalHashes(COLLECTION_ID);
        (afterUpdate != beforeUpdate).assertTrue("approval hash ignored collection state");
    }

    function testArtistSignatureStillRequiresConfiguredArtistAndSingleUse() public {
        DeployedStream memory deployed = deployStream(address(0xBEEF), address(0xCAFE));

        vm.expectRevert(abi.encodeWithSelector(StreamCore.ArtistSignatureUnauthorized.selector));
        deployed.core.artistSignature(COLLECTION_ID, "not-the-artist");

        vm.prank(ARTIST);
        deployed.core.artistSignature(COLLECTION_ID, "artist-approved-genesis");

        vm.expectRevert(abi.encodeWithSelector(StreamCore.ArtistSignatureUnauthorized.selector));
        vm.prank(ARTIST);
        deployed.core.artistSignature(COLLECTION_ID, "second-signature");
    }
}

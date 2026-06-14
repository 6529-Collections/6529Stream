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

    event ArtistApprovalRecorded(
        uint256 indexed _collectionID,
        address indexed artist,
        bytes32 indexed approvalHash,
        string signature
    );

    uint256 private constant COLLECTION_ID = 1;
    address private constant ARTIST = address(0xA11CE);

    function testArtistSignatureStoresStateBoundApprovalHash() public {
        DeployedStream memory deployed = deployStream(address(0xBEEF), address(0xCAFE));
        bytes32 expectedApprovalHash = deployed.core.previewArtistApprovalHash(COLLECTION_ID);

        vm.expectEmit(true, true, true, true);
        emit ArtistApprovalRecorded(
            COLLECTION_ID, ARTIST, expectedApprovalHash, "artist-approved-genesis"
        );
        vm.prank(ARTIST);
        deployed.core.artistSignature(COLLECTION_ID, "artist-approved-genesis");

        deployed.core.artistSigned(COLLECTION_ID).assertTrue("artist signature flag not stored");
        deployed.core.artistsSignatures(COLLECTION_ID)
            .assertEq("artist-approved-genesis", "artist signature text not stored");
        deployed.core.artistApprovalHashes(COLLECTION_ID)
            .assertEq(expectedApprovalHash, "artist approval hash not stored");
        deployed.core.previewArtistApprovalHash(COLLECTION_ID)
            .assertEq(expectedApprovalHash, "current approval hash changed unexpectedly");
    }

    function testArtistApprovalPreviewTracksCollectionStateChanges() public {
        DeployedStream memory deployed = deployStream(address(0xBEEF), address(0xCAFE));
        bytes32 beforeUpdate = deployed.core.previewArtistApprovalHash(COLLECTION_ID);

        deployed.core.setCollectionData(COLLECTION_ID, ARTIST, 9, 10, 2 days);
        bytes32 afterSupplyPolicyUpdate = deployed.core.previewArtistApprovalHash(COLLECTION_ID);
        (afterSupplyPolicyUpdate != beforeUpdate).assertTrue("approval hash ignored supply policy");

        string[] memory scripts = new string[](1);
        scripts[0] = "function draw(){return 1;}";
        deployed.core
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

        bytes32 afterMetadataUpdate = deployed.core.previewArtistApprovalHash(COLLECTION_ID);
        (afterMetadataUpdate != afterSupplyPolicyUpdate)
        .assertTrue("approval hash ignored collection metadata");
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

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../smart-contracts/StreamArtistApprovals.sol";
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
    uint256 private constant ARTIST_PRIVATE_KEY = 0xA11CE;

    function testArtistSignatureStoresStateBoundApprovalHash() public {
        DeployedStream memory deployed = deployStream(address(0xBEEF), address(0xCAFE));
        bytes32 expectedApprovalHash = deployed.core.hashArtistApproval(COLLECTION_ID);

        vm.prank(ARTIST);
        deployed.core.artistSignature(COLLECTION_ID, "artist-approved-genesis");

        deployed.core.artistSigned(COLLECTION_ID).assertTrue("artist signature flag not stored");
        deployed.core.artistsSignatures(COLLECTION_ID)
            .assertEq("artist-approved-genesis", "artist signature text not stored");
        deployed.core.artistApprovalHashes(COLLECTION_ID)
            .assertEq(expectedApprovalHash, "artist approval hash not stored");
        deployed.core.hashArtistApproval(COLLECTION_ID)
            .assertEq(expectedApprovalHash, "current approval hash changed unexpectedly");
    }

    function testArtistApprovalHashTracksCollectionStateChanges() public {
        DeployedStream memory deployed = deployStream(address(0xBEEF), address(0xCAFE));
        bytes32 beforeUpdate = deployed.core.hashArtistApproval(COLLECTION_ID);

        deployed.core.setCollectionData(COLLECTION_ID, ARTIST, 9, 10, 2 days);
        bytes32 afterSupplyPolicyUpdate = deployed.core.hashArtistApproval(COLLECTION_ID);
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

        bytes32 afterMetadataUpdate = deployed.core.hashArtistApproval(COLLECTION_ID);
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

    function testEIP712ArtistSignatureStoresApprovalFromRelayer() public {
        DeployedStream memory deployed = deployStream(address(0xBEEF), address(0xCAFE));
        address signingArtist = vm.addr(ARTIST_PRIVATE_KEY);
        deployed.core.setCollectionData(COLLECTION_ID, signingArtist, 5, 10, 1 days);
        bytes32 expectedApprovalHash = deployed.core.hashArtistApproval(COLLECTION_ID);
        bytes memory artistProof = _signArtistApproval(deployed.core, ARTIST_PRIVATE_KEY);

        deployed.core.artistSignature(COLLECTION_ID, "typed-artist-approval", artistProof);

        deployed.core.artistSigned(COLLECTION_ID).assertTrue("artist signature flag not stored");
        deployed.core.artistApprovalHashes(COLLECTION_ID)
            .assertEq(expectedApprovalHash, "typed approval hash not stored");
    }

    function testEIP712ArtistSignatureRejectsWrongSigner() public {
        DeployedStream memory deployed = deployStream(address(0xBEEF), address(0xCAFE));
        address signingArtist = vm.addr(ARTIST_PRIVATE_KEY);
        deployed.core.setCollectionData(COLLECTION_ID, signingArtist, 5, 10, 1 days);
        bytes memory wrongProof = _signArtistApproval(deployed.core, 0xB0B);

        vm.expectRevert(
            abi.encodeWithSelector(StreamArtistApprovals.ArtistSignatureInvalid.selector)
        );
        deployed.core.artistSignature(COLLECTION_ID, "typed-artist-approval", wrongProof);
    }

    function testEIP712ArtistSignatureRejectsStaleCollectionState() public {
        DeployedStream memory deployed = deployStream(address(0xBEEF), address(0xCAFE));
        address signingArtist = vm.addr(ARTIST_PRIVATE_KEY);
        deployed.core.setCollectionData(COLLECTION_ID, signingArtist, 5, 10, 1 days);
        bytes memory staleProof = _signArtistApproval(deployed.core, ARTIST_PRIVATE_KEY);

        deployed.core.setCollectionData(COLLECTION_ID, signingArtist, 8, 10, 1 days);

        vm.expectRevert(
            abi.encodeWithSelector(StreamArtistApprovals.ArtistSignatureInvalid.selector)
        );
        deployed.core.artistSignature(COLLECTION_ID, "typed-artist-approval", staleProof);
    }

    function _signArtistApproval(StreamCore core, uint256 privateKey)
        private
        returns (bytes memory)
    {
        (uint8 v, bytes32 r, bytes32 s) =
            vm.sign(privateKey, core.hashArtistApproval(COLLECTION_ID));
        return abi.encodePacked(r, s, v);
    }
}

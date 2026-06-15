// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../smart-contracts/StreamArtistApprovals.sol";
import "../smart-contracts/StreamCore.sol";
import "../smart-contracts/StreamMetadataRenderer.sol";
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
    bytes32 private constant _FREEZE_COLLECTION_STATE_TYPEHASH = keccak256(
        "6529StreamFreezeCollectionState(bool onchainMetadata,bytes32 collectionInfoHash,bytes32 dependencyKey,uint256 dependencyVersion,bytes32 dependencyContentHash,bytes32 collectionScriptHash)"
    );
    bytes32 private constant _COLLECTION_INFO_TYPEHASH = keccak256(
        "6529StreamCollectionInfo(bytes32 nameHash,bytes32 artistHash,bytes32 descriptionHash,bytes32 websiteHash,bytes32 licenseHash,bytes32 baseURIHash,bytes32 libraryHash)"
    );
    bytes32 private constant _LIVE_TOKEN_METADATA_AGGREGATE_TYPEHASH =
        keccak256("6529StreamLiveTokenMetadataAggregate(bytes32 accumulator,uint256 liveSupply)");
    bytes32 private constant _ARTIST_APPROVAL_SUPPLY_STATE_TYPEHASH = keccak256(
        "6529StreamArtistApprovalSupplyState(uint256 maxCollectionPurchases,uint256 circulationSupply,uint256 collectionTotalSupply,uint256 reservedMinTokenId,uint256 reservedMaxTokenId,uint256 finalSupplyDelay,uint256 burnCount)"
    );
    bytes32 private constant _FREEZE_INTEGRATION_STATE_TYPEHASH = keccak256(
        "6529StreamFreezeIntegrationState(uint256 randomizerEpoch,address randomizer,address dependencyRegistry)"
    );

    function testArtistSignatureStoresStateBoundApprovalHash() public {
        DeployedStream memory deployed = deployStream(address(0xBEEF), address(0xCAFE));
        bytes32 expectedApprovalHash = _artistApprovalDigest(deployed.core, COLLECTION_ID);

        vm.prank(ARTIST);
        deployed.core.artistSignature(COLLECTION_ID, "artist-approved-genesis");

        deployed.core.artistSigned(COLLECTION_ID).assertTrue("artist signature flag not stored");
        deployed.core.artistsSignatures(COLLECTION_ID)
            .assertEq("artist-approved-genesis", "artist signature text not stored");
        deployed.core.artistApprovalHashes(COLLECTION_ID)
            .assertEq(expectedApprovalHash, "artist approval hash not stored");
        _artistApprovalDigest(deployed.core, COLLECTION_ID)
            .assertEq(expectedApprovalHash, "current approval hash changed unexpectedly");
    }

    function testArtistApprovalHashTracksCollectionStateChanges() public {
        DeployedStream memory deployed = deployStream(address(0xBEEF), address(0xCAFE));
        bytes32 beforeUpdate = _artistApprovalDigest(deployed.core, COLLECTION_ID);

        deployed.core.setCollectionData(COLLECTION_ID, ARTIST, 9, 10, 2 days);
        bytes32 afterSupplyPolicyUpdate = _artistApprovalDigest(deployed.core, COLLECTION_ID);
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

        bytes32 afterMetadataUpdate = _artistApprovalDigest(deployed.core, COLLECTION_ID);
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
        bytes32 expectedApprovalHash = _artistApprovalDigest(deployed.core, COLLECTION_ID);
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
            vm.sign(privateKey, _artistApprovalDigest(core, COLLECTION_ID));
        return abi.encodePacked(r, s, v);
    }

    function _artistApprovalDigest(StreamCore core, uint256 collectionId)
        private
        view
        returns (bytes32)
    {
        return StreamArtistApprovals.hashApprovalDigest(
            collectionId,
            core.retrieveArtistAddress(collectionId),
            _freezeCollectionStateHash(core, collectionId),
            _artistApprovalSupplyStateHash(core, collectionId),
            _liveTokenMetadataHash(core, collectionId),
            _freezeIntegrationStateHash(core, collectionId),
            address(core),
            block.chainid
        );
    }

    function _freezeCollectionStateHash(StreamCore core, uint256 collectionId)
        private
        view
        returns (bytes32)
    {
        (bytes32 dependencyKey, uint256 dependencyVersion, bytes32 dependencyContentHash,) =
            core.collectionDependencyVersionState(collectionId);
        return keccak256(
            abi.encode(
                _FREEZE_COLLECTION_STATE_TYPEHASH,
                core.onchainMetadata(collectionId),
                _collectionInfoHash(core, collectionId),
                dependencyKey,
                dependencyVersion,
                dependencyContentHash,
                _collectionScriptHash(core, collectionId)
            )
        );
    }

    function _collectionInfoHash(StreamCore core, uint256 collectionId)
        private
        view
        returns (bytes32)
    {
        (
            string memory name,
            string memory artist,
            string memory description,
            string memory website,
            string memory license,
            string memory baseURI
        ) = core.retrieveCollectionInfo(collectionId);
        (string memory libraryUrl,,) = core.retrieveCollectionLibraryAndScript(collectionId);
        return keccak256(
            abi.encode(
                _COLLECTION_INFO_TYPEHASH,
                keccak256(bytes(name)),
                keccak256(bytes(artist)),
                keccak256(bytes(description)),
                keccak256(bytes(website)),
                keccak256(bytes(license)),
                keccak256(bytes(baseURI)),
                keccak256(bytes(libraryUrl))
            )
        );
    }

    function _collectionScriptHash(StreamCore core, uint256 collectionId)
        private
        view
        returns (bytes32)
    {
        (,, string[] memory scripts) = core.retrieveCollectionLibraryAndScript(collectionId);
        return StreamMetadataRenderer.collectionScriptHash(scripts);
    }

    function _artistApprovalSupplyStateHash(StreamCore core, uint256 collectionId)
        private
        view
        returns (bytes32)
    {
        (
            ,
            uint256 maxCollectionPurchases,
            uint256 circulationSupply,
            uint256 collectionTotalSupply,
            uint256 finalSupplyDelay,
        ) = core.retrieveCollectionAdditionalData(collectionId);
        return keccak256(
            abi.encode(
                _ARTIST_APPROVAL_SUPPLY_STATE_TYPEHASH,
                maxCollectionPurchases,
                circulationSupply,
                collectionTotalSupply,
                core.viewTokensIndexMin(collectionId),
                core.viewTokensIndexMax(collectionId),
                finalSupplyDelay,
                core.burnAmount(collectionId)
            )
        );
    }

    function _liveTokenMetadataHash(StreamCore core, uint256 collectionId)
        private
        view
        returns (bytes32)
    {
        return keccak256(
            abi.encode(
                _LIVE_TOKEN_METADATA_AGGREGATE_TYPEHASH,
                bytes32(0),
                core.totalSupplyOfCollection(collectionId)
            )
        );
    }

    function _freezeIntegrationStateHash(StreamCore core, uint256 collectionId)
        private
        view
        returns (bytes32)
    {
        (,,, address dependencyRegistry) = core.collectionDependencyVersionState(collectionId);
        return keccak256(
            abi.encode(
                _FREEZE_INTEGRATION_STATE_TYPEHASH,
                core.viewRandomizerEpoch(collectionId),
                core.viewCollectionRandomizerContract(collectionId),
                dependencyRegistry
            )
        );
    }
}

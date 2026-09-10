// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./helpers/StreamSaleTestBase.sol";

contract CollectionArtist1271 {
    bytes32 public approved;

    function approve(bytes32 digest) external {
        approved = digest;
    }

    function isValidSignature(bytes32 digest, bytes calldata) external view returns (bytes4) {
        return digest == approved ? bytes4(0x1626ba7e) : bytes4(0xffffffff);
    }
}

contract StreamCollectionArtistRegistryTest is StreamSaleTestBase {
    StreamCollectionArtistRegistry private attributionRegistry;

    function setUp() public {
        _setUpSaleFixture();
        attributionRegistry = new StreamCollectionArtistRegistry(
            address(core),
            address(this),
            keccak256("deploy"),
            "urn:test:artist-attribution",
            keccak256("artist module")
        );
        attributionRegistry.nominateArtist(1, artist, keccak256("identity"));
    }

    function testUnfundedArtistAcceptsThroughRelayerAndBecomesImmutable() public {
        require(attributionRegistry.acceptedArtist(1) == address(0), "nomination is not consent");
        bytes32 nomination = attributionRegistry.attribution(1).nominationHash;
        uint64 deadline = uint64(block.timestamp + 1 days);
        bytes32 digest = attributionRegistry.acceptanceDigest(1, nomination, 0, deadline);
        bytes memory proof = _signAcceptance(digest, ARTIST_KEY);
        require(artist.balance == 0, "artist is unfunded");
        vm.recordLogs();
        vm.prank(address(0x123));
        attributionRegistry.acceptArtist(1, nomination, 0, deadline, proof);
        IStreamCollectionArtistRegistry.Attribution memory record =
            attributionRegistry.attribution(1);
        require(
            record.artist == artist && record.acceptanceHash == digest, "accepted actual identity"
        );
        require(attributionRegistry.acceptanceNonces(artist) == 1, "nonce consumed");
        Vm.Log[] memory logs = vm.getRecordedLogs();
        require(logs.length == 1 && logs[0].topics[3] == digest, "acceptance evidence event");
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamCollectionArtistRegistry.ArtistRegistryAttributionImmutable.selector, 1
            )
        );
        attributionRegistry.nominateArtist(1, platform, keccak256("replacement"));
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamCollectionArtistRegistry.ArtistRegistryAttributionImmutable.selector, 1
            )
        );
        attributionRegistry.acceptArtist(1, nomination, 0, deadline, proof);
    }

    function testReplacementAndNonceCancellationInvalidateOldAcceptance() public {
        bytes32 nomination = attributionRegistry.attribution(1).nominationHash;
        uint64 deadline = uint64(block.timestamp + 1 days);
        bytes memory proof = _signAcceptance(
            attributionRegistry.acceptanceDigest(1, nomination, 0, deadline), ARTIST_KEY
        );
        attributionRegistry.nominateArtist(1, artist, keccak256("new identity"));
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamCollectionArtistRegistry.ArtistRegistryInvalidAcceptance.selector
            )
        );
        attributionRegistry.acceptArtist(1, nomination, 0, deadline, proof);
        nomination = attributionRegistry.attribution(1).nominationHash;
        proof = _signAcceptance(
            attributionRegistry.acceptanceDigest(1, nomination, 0, deadline), ARTIST_KEY
        );
        vm.prank(artist);
        attributionRegistry.invalidateAcceptanceNonce(10);
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamCollectionArtistRegistry.ArtistRegistryInvalidAcceptance.selector
            )
        );
        attributionRegistry.acceptArtist(1, nomination, 0, deadline, proof);
    }

    function testWrongSignerDomainDeadlineAndUnauthorizedNominationFail() public {
        bytes32 nomination = attributionRegistry.attribution(1).nominationHash;
        uint64 deadline = uint64(block.timestamp + 1 days);
        bytes32 digest = attributionRegistry.acceptanceDigest(1, nomination, 0, deadline);
        bytes memory wrong = _signAcceptance(digest, PLATFORM_KEY);
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamCollectionArtistRegistry.ArtistRegistryInvalidSignature.selector, artist
            )
        );
        attributionRegistry.acceptArtist(1, nomination, 0, deadline, wrong);
        bytes memory proof = _signAcceptance(digest, ARTIST_KEY);
        vm.chainId(block.chainid + 1);
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamCollectionArtistRegistry.ArtistRegistryInvalidSignature.selector, artist
            )
        );
        attributionRegistry.acceptArtist(1, nomination, 0, deadline, proof);
        vm.warp(uint256(deadline) + 1);
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamCollectionArtistRegistry.ArtistRegistryAcceptanceExpired.selector, deadline
            )
        );
        attributionRegistry.acceptArtist(1, nomination, 0, deadline, proof);
        vm.prank(artist);
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamCollectionArtistRegistry.ArtistRegistryUnauthorized.selector, artist
            )
        );
        attributionRegistry.nominateArtist(1, artist, keccak256("unauthorized"));
        require(attributionRegistry.acceptedArtist(1) == address(0), "no invalid acceptance");
    }

    function testERC1271AcceptanceAndWrongContractResponse() public {
        CollectionArtist1271 signer = new CollectionArtist1271();
        attributionRegistry.nominateArtist(1, address(signer), keccak256("contract identity"));
        bytes32 nomination = attributionRegistry.attribution(1).nominationHash;
        uint64 deadline = uint64(block.timestamp + 1 days);
        bytes32 digest = attributionRegistry.acceptanceDigest(1, nomination, 0, deadline);
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamCollectionArtistRegistry.ArtistRegistryInvalidSignature.selector,
                address(signer)
            )
        );
        attributionRegistry.acceptArtist(1, nomination, 0, deadline, "contract proof");
        signer.approve(digest);
        attributionRegistry.acceptArtist(1, nomination, 0, deadline, "contract proof");
        require(
            attributionRegistry.acceptedArtist(1) == address(signer), "contract artist accepted"
        );
    }

    function testCannotBackfillArtistAfterFirstMintAndCoreInstallsRealInterface() public {
        _install(
            keccak256("ARTIST_REGISTRY"),
            address(attributionRegistry),
            type(IStreamCollectionArtistRegistry).interfaceId
        );
        require(
            core.pointerState(keccak256("ARTIST_REGISTRY")).target == address(attributionRegistry),
            "actual Core installs artist module"
        );
        require(
            attributionRegistry.supportsInterface(type(IStreamModule).interfaceId)
                && !attributionRegistry.supportsInterface(0xffffffff),
            "canonical module interface"
        );
        bytes32 nomination = attributionRegistry.attribution(1).nominationHash;
        vm.prank(address(manager));
        core.mintFromManager(1, artist, "token", keccak256("token"), keccak256("commitment"));
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamCollectionArtistRegistry.ArtistRegistryCollectionStarted.selector, 1
            )
        );
        vm.prank(artist);
        attributionRegistry.acceptArtist(1, nomination, 0, uint64(block.timestamp + 1 days), "");
    }

    function _signAcceptance(bytes32 digest, uint256 key) private returns (bytes memory) {
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(key, digest);
        return abi.encodePacked(r, s, v);
    }
}

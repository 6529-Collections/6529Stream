// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../../regression/legacy/helpers/CharacterizationTestBase.sol";
import "../../../smart-contracts/domains/artist/StreamCollectionArtistRegistry.sol";
import "../../../smart-contracts/interfaces/stream/artist/IStreamArtistMintConsent.sol";

/// @dev Explicit collection-state boundary for the earlier attribution-only registry.
///      It is not the current Core and supplies no mint authorization.
contract AttributionCollectionStateFixture {
    uint256 public mintedEver;
    bool public frozen;

    function supportsInterface(bytes4 interfaceId) external pure returns (bool) {
        return interfaceId == 0x80ac58cd || interfaceId == 0x01ffc9a7;
    }

    function collectionExists(uint256 collectionId) external pure returns (bool) {
        return collectionId == 1;
    }

    function collectionMintedEver(uint256) external view returns (uint256) {
        return mintedEver;
    }

    function collectionFreezeStatus(uint256) external view returns (bool) {
        return frozen;
    }

    function setCollectionState(uint256 mintedEver_, bool frozen_) external {
        mintedEver = mintedEver_;
        frozen = frozen_;
    }
}

contract CollectionArtist1271 {
    bytes32 public approved;

    function approve(bytes32 digest) external {
        approved = digest;
    }

    function isValidSignature(bytes32 digest, bytes calldata) external view returns (bytes4) {
        return digest == approved ? bytes4(0x1626ba7e) : bytes4(0xffffffff);
    }
}

/// @dev Domain tests for the flat attribution registry; current artist consent uses the modular suite.
contract StreamCollectionArtistRegistryTest is CharacterizationTestBase {
    uint256 private constant ARTIST_KEY = 0xB0B;
    uint256 private constant PLATFORM_KEY = 0xA11CE;
    AttributionCollectionStateFixture private collectionState;
    address private artist;
    address private platform;
    StreamCollectionArtistRegistry private attributionRegistry;

    function setUp() public {
        artist = vm.addr(ARTIST_KEY);
        platform = vm.addr(PLATFORM_KEY);
        collectionState = new AttributionCollectionStateFixture();
        attributionRegistry = new StreamCollectionArtistRegistry(
            address(collectionState),
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

    function testCannotBackfillArtistAfterFirstMintAndAdvertisesOnlyAttribution() public {
        require(
            attributionRegistry.supportsInterface(type(IStreamModule).interfaceId)
                && attributionRegistry.supportsInterface(
                    type(IStreamCollectionArtistRegistry).interfaceId
                )
                && !attributionRegistry.supportsInterface(
                    type(IStreamArtistMintConsent).interfaceId
                ) && !attributionRegistry.supportsInterface(0xffffffff),
            "attribution module does not supply current mint consent"
        );
        bytes32 nomination = attributionRegistry.attribution(1).nominationHash;
        collectionState.setCollectionState(1, false);
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamCollectionArtistRegistry.ArtistRegistryCollectionStarted.selector, 1
            )
        );
        vm.prank(artist);
        attributionRegistry.acceptArtist(1, nomination, 0, uint64(block.timestamp + 1 days), "");
        require(
            attributionRegistry.acceptedArtist(1) == address(0),
            "started collection stays unaccepted"
        );
        require(
            attributionRegistry.acceptanceNonces(artist) == 0, "failed acceptance preserves nonce"
        );
    }

    function testFrozenUnmintedCollectionRejectsNominationAndAcceptance() public {
        bytes32 nomination = attributionRegistry.attribution(1).nominationHash;
        collectionState.setCollectionState(0, true);
        bytes memory expected = abi.encodeWithSelector(
            IStreamCollectionArtistRegistry.ArtistRegistryCollectionStarted.selector, 1
        );
        vm.expectRevert(expected);
        attributionRegistry.nominateArtist(1, platform, keccak256("replacement"));
        vm.expectRevert(expected);
        vm.prank(artist);
        attributionRegistry.acceptArtist(1, nomination, 0, uint64(block.timestamp + 1 days), "");
        require(
            attributionRegistry.attribution(1).nominationHash == nomination, "nomination unchanged"
        );
        require(
            attributionRegistry.acceptanceNonces(artist) == 0, "frozen collection preserves nonce"
        );
    }

    function _signAcceptance(bytes32 digest, uint256 key) private returns (bytes memory) {
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(key, digest);
        return abi.encodePacked(r, s, v);
    }
}

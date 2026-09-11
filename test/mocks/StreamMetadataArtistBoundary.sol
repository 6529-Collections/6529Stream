// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../../smart-contracts/interfaces/stream/artist/IStreamArtistAttribution.sol";
import "../../smart-contracts/interfaces/stream/artist/IStreamArtistContentRatification.sol";
import "../../smart-contracts/interfaces/stream/artist/IStreamArtistMintConsent.sol";

/// @dev Metadata-domain boundary: supplies attribution and ratification facts only.
///      Every mint-consent operation rejects; this fixture cannot prove artist eligibility.
contract StreamMetadataArtistBoundary is
    IStreamArtistAttribution,
    IStreamArtistContentRatification,
    IStreamArtistMintConsent,
    IERC165
{
    address public immutable override(IStreamArtistAttribution, IStreamArtistMintConsent) core;
    address public immutable mintManager;
    address private immutable fixtureOwner;
    IStreamCollectionArtistRegistry.Attribution private record;
    bytes32 private ratifiedContent;

    error MintConsentOutsideMetadataFixture();

    constructor(address core_, address manager_, address artist_) {
        core = core_;
        mintManager = manager_;
        fixtureOwner = msg.sender;
        record = IStreamCollectionArtistRegistry.Attribution({
            nominatedArtist: artist_,
            artist: artist_,
            identityHash: keccak256("metadata fixture identity"),
            nominationHash: keccak256("metadata fixture binding"),
            acceptanceHash: keccak256("metadata fixture acceptance"),
            nominationRevision: 1,
            acceptedAt: uint64(block.timestamp)
        });
    }

    function supportsInterface(bytes4 id) external pure returns (bool) {
        return id == type(IStreamArtistAttribution).interfaceId
            || id == type(IStreamArtistContentRatification).interfaceId
            || id == type(IStreamArtistMintConsent).interfaceId || id == type(IERC165).interfaceId;
    }

    function acceptedArtist(uint256 collectionId) external view returns (address) {
        return collectionId == 1 ? record.artist : address(0);
    }

    function attribution(uint256 collectionId)
        external
        view
        returns (IStreamCollectionArtistRegistry.Attribution memory value)
    {
        if (collectionId == 1) value = record;
    }

    function setRatification(bytes32 contentHash) external {
        require(msg.sender == fixtureOwner && contentHash != 0, "fixture ratification");
        ratifiedContent = contentHash;
    }

    function firstReleaseRatification(uint256 collectionId)
        external
        view
        returns (bool ratified, bytes32 contentHash, bytes32 recordHash)
    {
        if (collectionId == 1 && ratifiedContent != 0) {
            return (
                true,
                ratifiedContent,
                keccak256(abi.encode("metadata fixture ratification", ratifiedContent))
            );
        }
    }

    function consentMode(uint256) external pure returns (uint8) {
        revert MintConsentOutsideMetadataFixture();
    }

    function isPolicyConsented(uint256, bytes32, bytes32) external pure returns (bool, bytes32) {
        revert MintConsentOutsideMetadataFixture();
    }

    function requireMintConsent(uint256, bytes32, bytes32) external pure {
        revert MintConsentOutsideMetadataFixture();
    }
}

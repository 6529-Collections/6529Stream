// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../../vendor/openzeppelin/IERC165.sol";

/// @notice Implemented collection attribution, separate from the proposed multi-owner V2 suite.
interface IStreamCollectionArtistRegistry is IERC165 {
    struct Attribution {
        address nominatedArtist;
        address artist;
        bytes32 identityHash;
        bytes32 nominationHash;
        bytes32 acceptanceHash;
        uint64 nominationRevision;
        uint64 acceptedAt;
    }

    error ArtistRegistryUnauthorized(address caller);
    error ArtistRegistryInvalidConfiguration();
    error ArtistRegistryInvalidNomination(uint256 collectionId);
    error ArtistRegistryAttributionImmutable(uint256 collectionId);
    error ArtistRegistryCollectionStarted(uint256 collectionId);
    error ArtistRegistryInvalidAcceptance();
    error ArtistRegistryAcceptanceExpired(uint64 deadline);
    error ArtistRegistryInvalidSignature(address artist);
    error ArtistRegistryArtistMismatch(uint256 collectionId, address accepted, address supplied);

    event CollectionArtistNominated(
        uint16 schemaVersion,
        uint256 indexed collectionId,
        address indexed artist,
        bytes32 indexed nominationHash,
        bytes32 identityHash,
        uint64 revision
    );
    event CollectionArtistAccepted(
        uint16 schemaVersion,
        uint256 indexed collectionId,
        address indexed artist,
        bytes32 indexed acceptanceHash,
        bytes32 nominationHash,
        uint256 nonce
    );
    event ArtistAcceptanceNonceInvalidated(
        uint16 schemaVersion, address indexed artist, uint256 oldNonce, uint256 newNonce
    );

    function core() external view returns (address);
    function acceptedArtist(uint256 collectionId) external view returns (address);
    function attribution(uint256 collectionId) external view returns (Attribution memory);
    function acceptanceNonces(address artist) external view returns (uint256);
    function nominateArtist(uint256 collectionId, address artist, bytes32 identityHash) external;
    function acceptanceDigest(
        uint256 collectionId,
        bytes32 nominationHash,
        uint256 nonce,
        uint64 deadline
    ) external view returns (bytes32);
    function acceptArtist(
        uint256 collectionId,
        bytes32 nominationHash,
        uint256 nonce,
        uint64 deadline,
        bytes calldata signature
    ) external;
    function invalidateAcceptanceNonce(uint256 newNonce) external;
    function requireArtist(uint256 collectionId, address artist) external view;
}

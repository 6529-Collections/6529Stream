// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../../vendor/openzeppelin/IERC165.sol";

/// @notice Collection and default ERC-2981 disclosure through immutable split wallets.
interface IStreamRoyaltyResolver is IERC165 {
    /// @dev The first five fields fit one storage slot for bounded marketplace reads.
    struct RoyaltyConfig {
        address wallet;
        uint16 royaltyBps;
        bool configured;
        bool frozen;
        uint64 revision;
        bytes32 profileId;
    }

    error InvalidRoyaltyConfiguration();
    error InvalidRoyaltyCollection(uint256 collectionId);
    error InvalidRoyaltySplitProfile(bytes32 profileId);
    error RoyaltyConfigurationFrozen(uint256 collectionId);

    event RoyaltyConfigured(
        uint256 indexed collectionId,
        bytes32 indexed profileId,
        address indexed wallet,
        uint16 royaltyBps,
        uint64 revision
    );
    event RoyaltyFrozen(
        uint256 indexed collectionId,
        bytes32 indexed profileId,
        address indexed wallet,
        uint16 royaltyBps,
        uint64 revision
    );

    /// @notice Exact Core resolver ABI; Core supplies authoritative retained token identity.
    /// @dev Returns basis points, not a computed amount. No external calls are made.
    function royaltyReceiverAndBps(
        address core,
        uint256 tokenId,
        uint256 salePrice,
        uint256 mappedCollectionId,
        bool hasMappedCollection
    ) external view returns (address receiver, uint16 royaltyBps);

    function configureDefaultRoyalty(bytes32 profileId, uint16 royaltyBps) external;
    function configureCollectionRoyalty(uint256 collectionId, bytes32 profileId, uint16 royaltyBps)
        external;
    function freezeDefaultRoyalty() external;
    function freezeCollectionRoyalty(uint256 collectionId) external;
    function defaultRoyalty() external view returns (RoyaltyConfig memory);
    function collectionRoyalty(uint256 collectionId) external view returns (RoyaltyConfig memory);
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../../../vendor/openzeppelin/IERC165.sol";

/// @notice Actual bounded serving facts for the current router's deterministic presentation profile.
/// @dev This is a source description, never a finality or complete artist-display conformance claim.
interface IStreamMetadataServingFacts is IERC165 {
    struct ArtistPresentation {
        bool locked;
        address registry;
        bytes32 registryCodeHash;
        bytes32 artistId;
        uint64 bindingGeneration;
        bytes32 bindingHash;
        address nominatedArtist;
        bytes32 identityRecordHash;
        bytes32 acceptanceRecordHash;
        uint64 acceptedAt;
        uint64 lockedAt;
        bytes32 snapshotHash;
    }

    struct ServingFacts {
        bytes32 presentationProfile;
        bool configured;
        bytes32 mode;
        address renderer;
        bytes32 rendererCodeHash;
        bytes32 scriptHash;
        uint32 scriptBytes;
        bytes32 imageURIHash;
        bytes32 animationBaseURIHash;
        bool scriptLocked;
        bool mediaLocked;
        bool baseURILocked;
        bool dependenciesLocked;
        bool artistIdentityLocked;
        bool displayMetadataLocked;
        bool coreFrozen;
    }

    struct ServingSource {
        string name;
        string description;
        string imageURI;
        string animationBaseURI;
        string script;
    }

    struct LiveArtistStatus {
        address registry;
        bytes32 artistId;
        uint64 bindingGeneration;
        bytes32 bindingHash;
        uint8 attributionState;
        uint8 authorityStatus;
        address currentAuthority;
    }

    /// @notice One-way snapshot by the router's configured authority, including after Core freeze.
    /// @dev Captures accepted/sanctioned binding evidence; never freezes registry lifecycle or keys.
    function lockArtistIdentity(uint256 collectionId) external returns (bytes32 snapshotHash);

    /// @notice One-way configured-name/description lock by the router's authority, after freeze too.
    /// @dev Independent of artist content freeze classes; image/base URI/script retain their own locks.
    function lockDisplayMetadata(uint256 collectionId) external;

    /// @notice Local historical facts; unknown/unlocked collections return the all-zero tuple.
    function artistPresentation(uint256 collectionId)
        external
        view
        returns (ArtistPresentation memory);

    /// @notice Mode is keccak256("ONCHAIN") for nonempty stored script, else keccak256("OFFCHAIN").
    /// @dev This profile does not infer HYBRID mode. Core freeze is distinct from every explicit lock.
    function collectionServingFacts(uint256 collectionId)
        external
        view
        returns (ServingFacts memory);

    /// @notice Exact original stored UTF-8 bytes, before renderer escaping.
    /// @dev Field byte bounds are 256, 2048, 2048, 2048, and 8192 respectively.
    function collectionServingSource(uint256 collectionId)
        external
        view
        returns (ServingSource memory);

    /// @notice Current canonical artist facts, separate from the immutable historical presentation.
    /// @dev Failed/unavailable canonical reads revert; they are never translated into another state.
    function collectionLiveArtistStatus(uint256 collectionId)
        external
        view
        returns (LiveArtistStatus memory);

    /// @notice Deterministic JSON used by tokenURI for a live token; also permits retained burned identity.
    /// @dev Requires MINTED/BURNED lifecycle and the original coordinator's finalized seed.
    ///      This never changes ERC721 tokenURI's burned-token rejection. The profile identifies the
    ///      exact bytes hashed by callers; it does not silently remove fields from the public JSON.
    ///      Uses retained token identity and current stored collection content; finality callers must
    ///      check the explicit content locks, rather than infer a past content snapshot from this name.
    function historicalTokenMetadataJSON(address core, uint256 tokenId)
        external
        view
        returns (string memory);
}

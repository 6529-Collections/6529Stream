// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/// @notice Direct, storage-only views over the original validated history/import namespaces.
/// @dev These facts grant no authority and create no checkpoint, cache or import path.
interface IStreamStaticArtistLineageFacts {
    struct Lineage {
        bool isSealed;
        address successor;
        uint64 sealedAt;
        uint256 bindingCount;
        address predecessor;
        uint64 snapshotBlock;
        bytes32 importRoot;
        bytes32 manifestHash;
        bytes32 predecessorCodeHash;
        uint256 predecessorCount;
        bytes32 originHash;
        bytes32 importCommitment;
        uint64 importedAtRevision;
        uint8 ownerIndex;
        bytes32 originProfile;
    }
    function authorityHydrationCommitment() external view returns (bytes32);
    /// @dev A zero query requests only the history fields. A nonzero query also requires the
    /// raw original imported-only origin facts; the fixed consumer validates all five fields.
    function staticArtistLineage(bytes32 originHash) external view returns (Lineage memory);
}

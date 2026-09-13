// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/// @notice Exact fields of the versioned, flat ABI scope-membership manifest.
/// @dev scopeId is derived from the authenticated Metadata record hash after publication.
struct StreamScopeMembershipManifest {
    uint16 version;
    uint256 chainId;
    address core;
    uint256 collectionId;
    uint8 scopeType;
    uint256 tokenCount;
    bytes32 tokenListHash;
    bytes32[] chunkHashes;
}

/// @notice Eight static words shared by authoritative scope consumers.
/// @dev COLLECTION uses the current complete inventory prefix and zero record/manifest/list
///      hashes. TOKEN has one member and no manifest/record/inventory-prefix fields. Scoped
///      published subsets keep zero inventory-prefix fields so later parent mints cannot
///      change their immutable membership commitment. These facts are not finality readiness.
struct StreamScopeMembershipFacts {
    bytes32 scopeSubject;
    bytes32 scopeManifestHash;
    bytes32 sourceRecordHash;
    uint256 tokenCount;
    bytes32 tokenListHash;
    bytes32 membershipHash;
    uint256 inventoryCount;
    bytes32 inventoryPrefixHash;
}

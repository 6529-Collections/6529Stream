// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../../interfaces/stream/metadata/StreamTokenContentTypes.sol";

/// @notice Canonical ordered content tree specified by [CMC-CONTENT-ROOT].
/// @dev This library checks the commitment's structure only. A publishing host must validate
///      actual scope membership, rendered bytes, schema, entropy, authority and preservation.
library StreamTokenContentTree {
    bytes32 internal constant LEAF_DOMAIN =
        0x61d75cd1a57d24657b860f99f77c15e5f8556fb725b56a96dd770205f9352b0d;
    bytes32 internal constant NODE_DOMAIN =
        0x7239fc0713b7ccc92b7eef3087150a1f32037aff6ab05f5bf78db4f8ab71a6ea;

    error EmptyContentTree();
    error InvalidContentLeaf(uint256 index, uint256 tokenId);
    error ContentTokensNotAscending(uint256 index, uint256 previous, uint256 tokenId);

    function leafHash(uint256 chainId, address core, StreamTokenContentLeaf memory leaf)
        internal
        pure
        returns (bytes32)
    {
        return keccak256(
            abi.encode(
                LEAF_DOMAIN,
                chainId,
                core,
                leaf.tokenId,
                leaf.metadataHash,
                leaf.imageHash,
                leaf.animationHash,
                leaf.contentHash,
                leaf.tokenDataHash
            )
        );
    }

    function nodeHash(bytes32 left, bytes32 right) internal pure returns (bytes32) {
        return keccak256(abi.encode(NODE_DOMAIN, left, right));
    }

    /// @notice Computes the root without sorting, duplicating odd nodes or modifying leaves.
    function root(uint256 chainId, address core, StreamTokenContentLeaf[] memory leaves)
        internal
        pure
        returns (bytes32)
    {
        uint256 count = leaves.length;
        if (count == 0) revert EmptyContentTree();
        bytes32[] memory level = new bytes32[](count);
        uint256 previous;
        for (uint256 i; i < count; ++i) {
            StreamTokenContentLeaf memory leaf = leaves[i];
            if (leaf.tokenId == 0 || leaf.metadataHash == bytes32(0)) {
                revert InvalidContentLeaf(i, leaf.tokenId);
            }
            if (i != 0 && leaf.tokenId <= previous) {
                revert ContentTokensNotAscending(i, previous, leaf.tokenId);
            }
            previous = leaf.tokenId;
            level[i] = leafHash(chainId, core, leaf);
        }
        while (count > 1) {
            uint256 next;
            for (uint256 i; i < count; i += 2) {
                level[next++] = i + 1 < count ? nodeHash(level[i], level[i + 1]) : level[i];
            }
            count = next;
        }
        return level[0];
    }
}

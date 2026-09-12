// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/// @notice One token's content commitments under [CMC-CONTENT-ROOT].
/// @dev Optional asset hashes are zero only when the governing schema declares that asset
///      absent. A hash is a commitment, not evidence of availability or finalized entropy.
struct StreamTokenContentLeaf {
    uint256 tokenId;
    bytes32 metadataHash;
    bytes32 imageHash;
    bytes32 animationHash;
    bytes32 contentHash;
    bytes32 tokenDataHash;
}

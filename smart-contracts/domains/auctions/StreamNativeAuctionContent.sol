// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../../vendor/openzeppelin/MerkleProof.sol";

/// @notice Original auction artwork versus exact token bytes, using permanent content domains.
/// @dev The fixed linked caller is the sale adapter in both domains. The host must supply its
/// saved sale/commitment/root, retain the original manifest, bind its actual phase gate/root and
/// cap-one content counter, and carry the returned selection into its signed settlement intent.
/// This byte proof confers no publication, mint, payment or double-sale authority by itself.
library StreamNativeAuctionContent {
    bytes32 private constant LEAF = keccak256("6529STREAM_CONTENT_LEAF_V1");
    bytes32 private constant CONTEXT = keccak256("6529STREAM_CONTENT_CONTEXT_V1");

    struct Selection {
        bytes32 contentId;
        bytes32 tokenDataHash;
        bytes32[] proof;
    }

    struct Verified {
        bytes32 actualTokenDataHash;
        bytes32 contentSelectionHash;
        bytes32 contentContextHash;
    }

    error AuctionArtworkMismatch();
    error InactiveContentSelection();

    /// @notice Double-hashed SSA-CONTENT leaf; contentId zero is an ordinary valid identifier.
    function leaf(bytes32 saleId, bytes32 contentId, bytes32 tokenDataHash)
        public
        view
        returns (bytes32)
    {
        return keccak256(
            bytes.concat(
                keccak256(
                    abi.encode(LEAF, block.chainid, address(this), saleId, contentId, tokenDataHash)
                )
            )
        );
    }

    function contextHash(bytes32 saleId, bytes32 contentId) public view returns (bytes32) {
        return keccak256(abi.encode(CONTEXT, block.chainid, address(this), saleId, contentId));
    }

    /// @notice Verify the original exact-data or curated-leaf commitment against all supplied bytes.
    /// @dev Empty token bytes are real bytes with a nonzero hash. A single-leaf tree has an empty
    /// proof. Root zero denotes exact-data mode and accepts no inactive leaf/proof fields.
    function requireArtwork(
        bytes32 saleId,
        bytes32 artworkCommitment,
        bytes32 contentManifestRoot,
        bytes memory tokenData,
        Selection memory selected
    ) public view returns (Verified memory result) {
        if (saleId == 0 || artworkCommitment == 0) {
            revert AuctionArtworkMismatch();
        }
        result.actualTokenDataHash = keccak256(tokenData);
        if (contentManifestRoot == 0) {
            if (
                selected.contentId != 0 || selected.tokenDataHash != 0 || selected.proof.length != 0
            ) {
                revert InactiveContentSelection();
            }
            if (artworkCommitment != result.actualTokenDataHash) revert AuctionArtworkMismatch();
            result.contentSelectionHash = artworkCommitment;
            return result;
        }
        if (selected.tokenDataHash != result.actualTokenDataHash) revert AuctionArtworkMismatch();
        bytes32 selectedLeaf = leaf(saleId, selected.contentId, selected.tokenDataHash);
        if (
            selectedLeaf != artworkCommitment
                || !MerkleProof.verify(selected.proof, contentManifestRoot, selectedLeaf)
        ) {
            revert AuctionArtworkMismatch();
        }
        result.contentSelectionHash = selectedLeaf;
        result.contentContextHash = contextHash(saleId, selected.contentId);
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    StreamPreservationInventoryTypes as T
} from "../../interfaces/stream/preservation/StreamPreservationInventoryTypes.sol";

/// @notice Domain-separated finite ordered inventory chains; no caller list gains authority here.
library StreamPreservationInventoryChains {
    bytes32 internal constant ITEM_DOMAIN = keccak256("6529STREAM_PRESERVATION_ITEM_V1");
    bytes32 internal constant LINK_DOMAIN = keccak256("6529STREAM_PRESERVATION_ITEM_LINK_V1");
    bytes32 internal constant SEGMENT_DOMAIN = keccak256("6529STREAM_PRESERVATION_SEGMENT_V1");

    function itemHash(T.Item memory item) public pure returns (bytes32) {
        return keccak256(abi.encode(ITEM_DOMAIN, item));
    }

    function link(bytes32 key, uint64 count, uint64 index, T.Item memory item, bytes32 next)
        public
        pure
        returns (bytes32)
    {
        if (key == 0 || count == 0 || index >= count || (index + 1 == count) != (next == 0)) {
            revert T.InvalidInventorySegment();
        }
        return keccak256(abi.encode(LINK_DOMAIN, key, count, index, itemHash(item), next));
    }

    /// @dev A zero-item segment is an explicit source-derived applicability result, never an
    /// independently sufficient inventory. The producer authenticates its sourceWitnessHash.
    function segment(bytes32 key, bytes32 witnessHash, T.Item[] memory items)
        public
        pure
        returns (T.Segment memory result)
    {
        if (key == 0 || witnessHash == 0 || items.length > type(uint64).max) {
            revert T.InvalidInventorySegment();
        }
        result.key = key;
        result.itemCount = uint64(items.length);
        result.sourceWitnessHash = witnessHash;
        for (uint256 i = items.length; i != 0;) {
            --i;
            result.firstLink = link(key, result.itemCount, uint64(i), items[i], result.firstLink);
        }
    }

    /// @dev Identical chain construction without a large cross-library array ABI copy.
    function segmentInMemory(bytes32 key, bytes32 witnessHash, T.Item[] memory items)
        internal
        pure
        returns (T.Segment memory result)
    {
        if (key == 0 || witnessHash == 0 || items.length > type(uint64).max) {
            revert T.InvalidInventorySegment();
        }
        result.key = key;
        result.itemCount = uint64(items.length);
        result.sourceWitnessHash = witnessHash;
        // Items (including aliased strings/bytes) and the returned segment are already
        // allocated below this pointer. link returns only a scalar hash; none of its
        // temporary ABI buffers escape. Reuse that scratch for the next link and caller.
        uint256 scratch;
        assembly ("memory-safe") { scratch := mload(0x40) }
        for (uint256 i = items.length; i != 0;) {
            --i;
            result.firstLink = link(key, result.itemCount, uint64(i), items[i], result.firstLink);
            assembly ("memory-safe") { mstore(0x40, scratch) }
        }
    }

    function append(bytes32 previous, uint64 index, T.Segment memory value)
        public
        pure
        returns (bytes32)
    {
        if (
            value.key == 0 || value.sourceWitnessHash == 0
                || (value.itemCount == 0) != (value.firstLink == 0)
        ) {
            revert T.InvalidInventorySegment();
        }
        return keccak256(abi.encode(SEGMENT_DOMAIN, previous, index, value));
    }
}

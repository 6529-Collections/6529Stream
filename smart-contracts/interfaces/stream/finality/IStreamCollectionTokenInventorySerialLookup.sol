// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/// @notice Exact actual-serial membership alongside the inventory's dense ordinal reads.
/// @dev Incident-aborted allocations leave gaps. The original inventory interface is unchanged.
interface IStreamCollectionTokenInventorySerialLookup {
    /// @notice Returns the indexed token for an actual Core collection serial, or zero if absent.
    /// @dev Burned completed tokens remain indexed; aborted and unindexed serials return zero.
    function collectionTokenBySerial(uint256 collectionId, uint256 collectionSerial)
        external
        view
        returns (uint256 tokenId);
}

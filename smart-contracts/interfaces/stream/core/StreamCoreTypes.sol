// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/// @notice Permanent token lifecycle values returned by StreamCore.
/// @dev Numeric values are pinned: UNKNOWN=0, PREPARED_INCOMPLETE=1,
///      MINTED=2, BURNED=3.
enum StreamTokenLifecycle {
    UNKNOWN,
    PREPARED_INCOMPLETE,
    MINTED,
    BURNED
}

/// @notice Public part of the singleton prepared-mint record.
struct StreamPreparedMintRecord {
    bool exists;
    bytes32 operationId;
    uint256 collectionId;
}

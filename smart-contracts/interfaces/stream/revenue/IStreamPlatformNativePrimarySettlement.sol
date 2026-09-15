// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/// @notice Additive declaration-bound prepared primary capability; original settlement ABI retained.
interface IStreamPlatformNativePrimarySettlement {
    event PlatformPreparedPrimaryBound(
        uint16 schemaVersion,
        bytes32 indexed settlementKey,
        bytes32 indexed saleKey,
        bytes32 indexed declarationHash,
        uint8 mode,
        bytes32 beneficiaryHash,
        address poster,
        bytes32 currentPrimaryPolicyHash
    );
    function isStreamPlatformNativePrimarySettlement() external pure returns (bool);
}

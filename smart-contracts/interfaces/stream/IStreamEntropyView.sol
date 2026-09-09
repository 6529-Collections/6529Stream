// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../../vendor/openzeppelin/IERC165.sol";

/// @notice Numeric values follow the permanent entropy specification.
enum StreamEntropyStatus {
    NONE,
    DISABLED,
    NOT_REQUIRED,
    REGISTERED,
    REQUESTED,
    FINALIZED,
    STALE,
    FAILED
}

interface IStreamEntropyView is IERC165 {
    function tokenSeed(uint256 tokenId) external view returns (bytes32 seed, bool finalized);
    function tokenEntropyStatus(uint256 tokenId) external view returns (StreamEntropyStatus status);
    function tokenEntropy(uint256 tokenId)
        external
        view
        returns (
            StreamEntropyStatus status,
            bytes32 seed,
            address provider,
            uint32 providerEpoch,
            bytes32 providerConfigHash,
            bytes32 requestKey,
            uint256 providerRequestId,
            uint16 requestAttempt
        );
}

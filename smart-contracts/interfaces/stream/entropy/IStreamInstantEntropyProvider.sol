// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/// @notice Permanent synchronous read boundary; called only after mint registration.
/// @dev LOW_SECURITY only. Block-dependent output permits request-timing selection.
interface IStreamInstantEntropyProvider {
    function instantEntropy(bytes32 requestKey, bytes calldata context)
        external
        view
        returns (bytes32 rawRandomness, bytes32 provenanceHash);
}

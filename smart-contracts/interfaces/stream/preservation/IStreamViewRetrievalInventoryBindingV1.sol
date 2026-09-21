// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/// @notice Exact immutable satellite on the selected VIEW inventory, never a caller resolver.
interface IStreamViewRetrievalInventoryBindingV1 {
    function retrievalWitnessBinding()
        external
        view
        returns (address witness, bytes32 witnessCodeHash);
}

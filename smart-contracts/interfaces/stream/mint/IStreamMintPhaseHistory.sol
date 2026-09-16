// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/// @notice Monotonic history; disabling a phase never makes a collection unregistered again.
interface IStreamMintPhaseHistory {
    function hasRegisteredPhasePolicy(uint256 collectionId) external view returns (bool);
}

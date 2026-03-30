// SPDX-License-Identifier: MIT
//
// =============================================================================
// INextGenCore — ELI5
// =============================================================================
// Narrow interface used by legacy NextGen randomizers (subset of core ops).
// Here: only changeTokenData is exposed; real StreamCore has many more methods.
// =============================================================================

pragma solidity ^0.8.19;

interface INextGenCore {

    function changeTokenData(uint256 _tokenId, string memory newData) external;

}
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "./StreamArtworkFinalityTypes.sol";

interface IStreamFinalityTokenScopeInventory {
    function tokenScopeCount(uint256 tokenId) external view returns (uint256);
    function tokenScopeAt(uint256 tokenId, uint256 index)
        external
        view
        returns (StreamFinalityScope memory scope, bool complete);
}

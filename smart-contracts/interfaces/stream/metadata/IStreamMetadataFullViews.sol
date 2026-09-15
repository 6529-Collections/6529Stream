// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/// @notice Complete selected onchain output, including retained burned tokens.
interface IStreamMetadataFullViews {
    function tokenHTML(uint256 tokenId) external view returns (string memory);
    function tokenJSON(uint256 tokenId) external view returns (string memory);
}

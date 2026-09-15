// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/// @notice Complete selected onchain output, including retained burned tokens.
interface IStreamMetadataFullViews {
    function tokenHTML(uint256 tokenId) external view returns (string memory);
    function tokenJSON(uint256 tokenId) external view returns (string memory);
}

/// @notice Full archival serialization with the original stable historical lifecycle state.
/// @dev Public tokenJSON still discloses current burned state. This read preserves content-root bytes.
interface IStreamMetadataHistoricalFullView {
    function historicalFullTokenMetadataJSON(address core, uint256 tokenId)
        external
        view
        returns (string memory);
}

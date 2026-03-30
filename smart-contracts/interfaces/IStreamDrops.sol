// SPDX-License-Identifier: MIT
//
// =============================================================================
// IStreamDrops — ELI5
// =============================================================================
// What the auction contract needs from drops: poster, reserve price, drop id lookups,
// and who "executed" the drop for settlement edge cases.
// =============================================================================

pragma solidity ^0.8.19;

interface IStreamDrops {

    function retrieveAuctionPoster(uint256 _tokenid) external view returns(address);

    function retrieveAuctionPrice(uint256 _tokenid) external view returns(uint256);

    function retrieveTokenID(bytes32 _dropID) external view returns(uint256);

    function retrieveDropID(uint256 _tokenid) external view returns(bytes32);

    function retrieveExecutionAddress(uint256 _tokenid) external view returns(address);

}
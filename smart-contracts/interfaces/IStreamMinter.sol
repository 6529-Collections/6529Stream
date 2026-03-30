// SPDX-License-Identifier: MIT
//
// =============================================================================
// IStreamMinter — ELI5
// =============================================================================
// What StreamDrops and StreamAuctions call: mint batches, mint-to-auction, read
// phase end time, and auction timer/status per token.
// =============================================================================

pragma solidity ^0.8.19;

interface IStreamMinter {

    // retrieve if the contract is minter contract
    function isMinterContract() external view returns (bool);

    // retrieve the public end time of a sale
    function getEndTime(uint256 _collectionID) external view returns (uint);

    // retrieve auction end time
    function getAuctionEndTime(uint256 _tokenId) external view returns (uint);

    // retrieve auction status
    function getAuctionStatus(uint256 _tokenId) external view  returns (bool);

    // airdrop function
    function mint(address[] memory _recipients, string[] memory _tokenData, uint256[] memory _saltfun_o, uint256 _collectionID, uint256[] memory _numberOfTokens) external returns (uint256);

    // mint and auction function
    function mintAndAuction(address _recipient, string memory _tokenData, uint256 _saltfun_o, uint256 _collectionID, uint _auctionEndTime) external returns(uint256);

    // update auction endtime
    function updateAuctionEndTime(uint256 _tokenId, uint256 _auctionEndTime) external;
}
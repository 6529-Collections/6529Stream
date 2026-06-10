// SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

interface IStreamAuctions {
    function registerAuction(
        bytes32 _dropId,
        uint256 _tokenid,
        uint256 _collectionId,
        address _poster,
        uint256 _reservePrice,
        uint256 _auctionEndTime
    ) external;
}

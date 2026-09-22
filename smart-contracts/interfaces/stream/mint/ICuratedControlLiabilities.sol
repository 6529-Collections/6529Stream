// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

interface ICuratedControlLiabilities {
    function totalBuyerLiabilities() external view returns (uint256);
}

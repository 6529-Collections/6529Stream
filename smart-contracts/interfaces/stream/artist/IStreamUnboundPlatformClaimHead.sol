// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

interface IStreamUnboundPlatformClaimHead {
    function attributionClaims(uint256 id) external view returns (uint256, bytes32);
}

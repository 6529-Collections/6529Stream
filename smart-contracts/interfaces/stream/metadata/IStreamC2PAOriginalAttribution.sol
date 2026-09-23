// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

interface IStreamC2PAOriginalAttribution {
    function core() external view returns (address);
    function router() external view returns (address);
    function artist() external view returns (address);
    function attribution(uint256 collection, uint256 token) external view returns (bytes memory);
}

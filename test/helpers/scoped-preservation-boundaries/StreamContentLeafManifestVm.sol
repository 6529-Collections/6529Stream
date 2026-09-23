// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

interface LeafManifestVm {
    function mockCall(address target, bytes calldata input, bytes calldata output) external;
    function getNonce(address target) external view returns (uint64);
    function computeCreateAddress(address target, uint256 nonce) external pure returns (address);
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

interface IStreamMintPhaseFreezeBinding {
    function core() external view returns (address);
    function mintLedger() external view returns (address);
    function governanceAuthority() external view returns (address);
    function owner() external view returns (address);
}

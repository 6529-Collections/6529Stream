// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/// @dev Exact existing escrow getter ABI; not a spending or arbitrary execution interface.
interface IStreamSaleEscrowBinding {
    function splitFactory() external view returns (address);
    function assetPolicyRegistry() external view returns (address);
    function factoryCodeHash() external view returns (bytes32);
    function walletCodeHash() external view returns (bytes32);
}

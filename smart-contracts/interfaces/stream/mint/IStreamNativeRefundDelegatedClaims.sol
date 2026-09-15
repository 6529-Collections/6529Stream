// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "../parameters/IStreamGasParameterHost.sol";

/// @notice Optional live NFTDelegation triggers for native buyer credits (SSA-DELEGATE.9).
/// @dev Delegates can pay only the credited account. The account's original claim keeps its chosen recipient.
interface IStreamNativeRefundDelegatedClaims {
    struct DelegationWitness {
        bool walletWide;
        uint256 index;
    }

    struct DelegationDeployment {
        address registry;
        uint256 usecase;
        bytes32 baseManifestHash;
        IStreamGasParameterHost.GasParameterConfig gas;
    }

    struct DelegationConfiguration {
        uint256 chainId;
        address core;
        address registry;
        bytes32 registryCodeHash;
        uint256 usecase;
        bytes32 baseManifestHash;
        address moduleRegistry;
        bytes32 moduleRegistryCodeHash;
    }
    function refundDelegationConfiguration() external view returns (DelegationConfiguration memory);
    function refundDelegationManifest() external view returns (bytes memory);
    function refundDelegationManifestHash() external view returns (bytes32);
    function claimRefundFor(bytes32 saleId, address account, DelegationWitness calldata witness)
        external
        returns (uint256 amount);
}

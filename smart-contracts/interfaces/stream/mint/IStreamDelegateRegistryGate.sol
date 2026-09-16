// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./IStreamMintGate.sol";

/// @notice Deliver-to-vault mint eligibility through a pinned delegate.xyz v2 registry.
interface IStreamDelegateRegistryGate is IStreamMintGate {
    /// @dev Encoded as abi.encode(vault, nonce) in the existing gateData field.
    struct DelegationProof {
        address vault;
        bytes32 nonce;
    }

    error DelegationConfigurationInvalid();
    error DelegationManagerMismatch(address manager);
    error DelegationPhaseMismatch();
    error DelegationRouteInvalid();
    error DelegationProofInvalid();
    error DelegationNotFound(address vault, address delegate);
    error DelegationRegistryUnavailable(address registry);
    error DelegationReadGas(uint256 available, uint256 required);
    error DelegationReadFailed(address registry);
    error DelegationReadMalformed(address registry, uint256 length);

    function core() external view returns (address);
    function delegateRegistry() external view returns (address);
    function delegateRegistryCodeHash() external view returns (bytes32);
    function delegationUsecase() external view returns (bytes32);
    function gateConfigHash() external view returns (bytes32);
    function moduleManifest() external view returns (bytes memory);
    function moduleManifestHash() external view returns (bytes32);
    function collectionDelegationRights(uint256 collectionId) external view returns (bytes32);
    /// @notice False for absent authority; unavailable or malformed registry reads revert.
    function isDelegated(address vault, address delegate, uint256 collectionId)
        external
        view
        returns (bool);
}

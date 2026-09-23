// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/// @notice Explicit governed capabilities for typed permit paths, separate from ACTIVE admission.
interface IStreamAssetPermitPolicy {
    /// @dev Capability bits: 1 = canonical EIP-2612, 2 = pinned Permit2 SignatureTransfer.
    ///      Allowance mode 1 decrements every allowance; 2 preserves uint256.max only.
    ///      Both modes require every finite allowance to decrease by the exact spend.
    struct AssetPermitPolicy {
        uint8 capabilities;
        uint8 permit2AllowanceMode;
        address permit2;
        bytes32 permit2CodeHash;
        bytes32 assetCodeHash;
        bytes32 assetPolicyHash;
        uint64 assetPolicyRevision;
        uint64 revision;
    }

    error InvalidAssetPermitPolicy(address asset);
    error AssetPermitPolicyUnchanged(address asset);
    error InvalidAssetPermitPolicyAction();

    event AssetPermitPolicyUpdated(
        address indexed asset,
        bytes32 indexed permitPolicyHash,
        uint16 schemaVersion,
        uint64 revision,
        bytes32 actionId
    );

    /// @notice Returns the attestation, including its bound asset-policy revision. A caller
    ///         must separately require current ACTIVE status and all live identity bindings.
    function assetPermitPolicy(address asset) external view returns (AssetPermitPolicy memory);

    function assetPolicyRevision(address asset) external view returns (uint64);

    /// @notice Class-1 semantic transition. Zero capabilities revoke the attestation.
    function setAssetPermitPolicy(
        address asset,
        uint8 capabilities,
        uint8 permit2AllowanceMode,
        address permit2,
        bytes32 expectedPermit2CodeHash
    ) external;

    function assetPermitPolicyTransitionHashes(
        address asset,
        uint8 capabilities,
        uint8 permit2AllowanceMode,
        address permit2,
        bytes32 expectedPermit2CodeHash
    ) external view returns (bytes32 scopeHash, bytes32 oldStateHash, bytes32 newStateHash);
}

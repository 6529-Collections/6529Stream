// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/// @notice Interface for deployment-wide ERC-20 asset policy decisions.
interface IStreamAssetPolicyRegistry {
    /// @notice Reverts when an asset address is zero or not a contract when a contract is required.
    error InvalidAsset(address asset);
    /// @notice Reverts when an asset policy hash is invalid for the requested status.
    error InvalidAssetPolicyHash(address asset, uint8 status, bytes32 policyHash);
    /// @notice Reverts when an unknown status value is supplied.
    error InvalidAssetStatus(uint8 status);
    /// @notice Reverts when a policy update would leave status and evidence unchanged.
    error AssetPolicyUnchanged(address asset, uint8 status, bytes32 policyHash);
    error InvalidAssetPolicyAuthority(address authority);
    error AssetPolicyNotAuthority(address caller);
    error InvalidAssetPolicyAction();
    error InvalidAssetReleaseGrace(uint64 previousGrace, uint64 suppliedGrace);
    error AssetPolicyActionAlreadyApplied(address asset, bytes32 actionId);

    /// @notice Emitted when the deployment-wide asset policy for an ERC-20 changes.
    event AssetPolicyUpdated(
        address indexed asset,
        uint8 indexed previousStatus,
        uint8 indexed status,
        uint16 schemaVersion,
        bytes32 previousPolicyHash,
        bytes32 policyHash,
        uint64 effectiveAt,
        uint64 releaseGraceUntil,
        bytes32 actionId,
        address admin
    );

    /// @notice Default-deny status for unknown or cleared assets.
    function ASSET_STATUS_UNKNOWN() external pure returns (uint8);
    /// @notice Status for approved standard ERC-20 assets that may be synced and released.
    function ASSET_STATUS_ACTIVE() external pure returns (uint8);
    /// @notice Status for reviewed assets that are not currently accepted by split wallets.
    function ASSET_STATUS_INACTIVE() external pure returns (uint8);
    /// @notice Retired for new acceptance, with observed/grace-bound sync and release exits.
    function ASSET_STATUS_DEPRECATED() external pure returns (uint8);
    /// @notice Status for explicitly unsupported assets.
    function ASSET_STATUS_UNSUPPORTED() external pure returns (uint8);
    /// @notice Returns the current policy status for an asset.
    function assetStatus(address asset) external view returns (uint8);
    /// @notice Returns the evidence hash for the current policy status.
    function assetPolicyHash(address asset) external view returns (bytes32);
    /// @notice Returns the current status, evidence hash, and effective timestamp for an asset.
    function assetPolicy(address asset)
        external
        view
        returns (uint8 status, bytes32 policyHash, uint64 effectiveAt, uint64 releaseGraceUntil);
    function assetReleaseGraceUntil(address asset) external view returns (uint64);
    function governanceAuthority() external view returns (address);
    function assetPolicyTransitionHashes(
        address asset,
        uint8 status,
        bytes32 policyHash,
        uint64 releaseGraceUntil
    ) external view returns (bytes32 scopeHash, bytes32 oldStateHash, bytes32 newStateHash);
    /// @notice Returns the timestamp for the current asset policy status.
    function assetPolicyEffectiveAt(address asset) external view returns (uint64);
    /// @notice Returns true when an asset is currently active for split-wallet sync and release.
    function isAssetActive(address asset) external view returns (bool);
    /// @notice Sets an asset policy status and evidence hash.
    function setAssetStatus(
        address asset,
        uint8 status,
        bytes32 policyHash,
        uint64 releaseGraceUntil
    ) external;
    /// @notice Marker for deployment validation.
    function isStreamAssetPolicyRegistry() external pure returns (bool);
}

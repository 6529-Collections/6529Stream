// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/// @notice Governed satellite pointers and their verified registry commitments.
interface IStreamCorePointers {
    event CoreSatellitePointerUpdated(
        uint16 schemaVersion,
        bytes32 indexed pointerType,
        bytes32 indexed actionId,
        address indexed newTarget,
        address oldTarget
    );

    event CoreSatellitePointerFrozen(
        uint16 schemaVersion,
        bytes32 indexed pointerType,
        bytes32 indexed actionId,
        address target,
        bytes32 manifestHash
    );

    /// @notice Returns the stored target, registry commitments, freeze state, and revision.
    function getSatellitePointer(bytes32 pointerType)
        external
        view
        returns (
            address target,
            bytes32 codeHash,
            bool frozen,
            bytes32 moduleType,
            bytes4 interfaceId,
            address registry,
            uint8 registryStatus,
            bytes32 moduleManifestHash,
            bytes32 deploymentManifestHash,
            uint64 revision
        );

    /// @notice Replaces an unfrozen satellite after registry and governance-transition checks.
    function updateSatellitePointer(bytes32 pointerType, address newTarget) external;

    /// @notice Permanently freezes an installed satellite pointer through terminal governance.
    function freezeSatellitePointer(bytes32 pointerType) external;
}

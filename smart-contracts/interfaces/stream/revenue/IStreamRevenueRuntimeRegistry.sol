// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/// @notice Common lifecycle source for split-factory admission and wallet runtimes.
interface IStreamRevenueRuntimeRegistry {
    struct FactoryRecord {
        uint8 status;
        bytes32 codeHash;
        bytes32 runtimeCodeHash;
        uint64 revision;
        bytes32 lastActionId;
        bytes32 incidentManifestHash;
    }

    struct RuntimeRecord {
        uint8 status;
        uint64 revision;
        bytes32 incidentManifestHash;
        bytes32 lastActionId;
    }

    error InvalidRevenueRuntimeConfiguration();
    error InvalidRevenueRuntimeTransition();
    error InvalidRevenueRuntimeAction();
    error RevenueRuntimeReadFailed(address target, bytes4 selector);
    error RevenueRuntimeUnavailable(address factory, bytes32 runtimeCodeHash, uint8 status);

    event RevenueFactoryStatusChanged(
        uint16 schemaVersion,
        address indexed factory,
        bytes32 indexed runtimeCodeHash,
        bytes32 indexed actionId,
        bytes32 factoryCodeHash,
        uint8 status,
        uint64 revision,
        bytes32 reasonHash,
        string reasonURI,
        bytes32 incidentManifestHash
    );
    event RevenueRuntimeStatusChanged(
        uint16 schemaVersion,
        bytes32 indexed runtimeCodeHash,
        bytes32 indexed actionId,
        uint8 status,
        uint64 revision,
        bytes32 reasonHash,
        string reasonURI,
        bytes32 incidentManifestHash
    );

    function isStreamRevenueRuntimeRegistry() external pure returns (bool);
    function authorityCodeHash() external view returns (bytes32);
    function assetPolicyRegistry() external view returns (address);
    function factoryRecord(address factory) external view returns (FactoryRecord memory);
    function runtimeRecord(bytes32 runtimeCodeHash) external view returns (RuntimeRecord memory);
    function factoryTransitionHashes(
        address factory,
        uint8 status,
        bytes32 reasonHash,
        string calldata reasonURI,
        bytes32 incidentManifestHash
    )
        external
        view
        returns (uint8 actionClass, bytes32 scopeHash, bytes32 oldStateHash, bytes32 newStateHash);
    function runtimeTransitionHashes(
        bytes32 runtimeCodeHash,
        uint8 status,
        bytes32 reasonHash,
        string calldata reasonURI,
        bytes32 incidentManifestHash
    )
        external
        view
        returns (uint8 actionClass, bytes32 scopeHash, bytes32 oldStateHash, bytes32 newStateHash);
    function setFactoryStatus(
        address factory,
        uint8 status,
        bytes32 reasonHash,
        string calldata reasonURI,
        bytes32 incidentManifestHash
    ) external;
    function setRuntimeStatus(
        bytes32 runtimeCodeHash,
        uint8 status,
        bytes32 reasonHash,
        string calldata reasonURI,
        bytes32 incidentManifestHash
    ) external;
}

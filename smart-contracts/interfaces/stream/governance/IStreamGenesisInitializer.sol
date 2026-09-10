// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./IStreamGovernanceExecutor.sol";

/// @notice One ordinary governance batch in an atomically sealed genesis plan.
struct GenesisBatch {
    uint8 actionClass;
    GovernanceCall[] calls;
    bytes[] callDatas;
}

/// @notice One-time deployment initialization; ordinary governance keeps its delays.
interface IStreamGenesisInitializer {
    error GenesisPlanAlreadyCommitted();
    error InvalidGenesisPlan();
    error GenesisPlanHashMismatch(bytes32 expected, bytes32 actual);
    error GenesisAlreadyInitialized();
    error GenesisDidNotSeal();
    error GenesisPreparationAlreadyBound();

    event GenesisPlanCommitted(bytes32 indexed planHash, address indexed authority);
    event GenesisInitialized(bytes32 indexed planHash, uint256 batchCount);
    event GenesisPrepared(bytes32 indexed planHash);

    function genesisPlanHash() external view returns (bytes32);
    function genesisInitialized() external view returns (bool);
    function commitGenesisPlan(bytes32 planHash) external;
    /// @notice Hash the exact ABI argument bytes for the corresponding initializer
    ///         call, domain-separated by this chain and Executor. Use the same
    ///         encoding for hashing and initialization (including any trailing bytes).
    function hashGenesisPlan(
        SystemManifestBootstrapBinding calldata binding,
        GenesisBatch[] calldata batches
    ) external view returns (bytes32);
    function initializeGenesis(
        SystemManifestBootstrapBinding calldata binding,
        GenesisBatch[] calldata batches
    ) external;

    /// @notice Optionally bind the exact committed governance catalog/lifecycle
    ///         in a separate transaction before atomic product setup and sealing.
    /// @dev Uses the identical complete plan encoding. Preparation is durable;
    ///      failed initialization leaves it available for an exact-plan retry.
    ///      No ordinary pre-seal actions may run after the plan is committed.
    function prepareGenesis(
        SystemManifestBootstrapBinding calldata binding,
        GenesisBatch[] calldata batches
    ) external;
}

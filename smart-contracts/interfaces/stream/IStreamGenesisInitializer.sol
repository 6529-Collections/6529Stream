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

    event GenesisPlanCommitted(bytes32 indexed planHash, address indexed authority);
    event GenesisInitialized(bytes32 indexed planHash, uint256 batchCount);

    function genesisPlanHash() external view returns (bytes32);
    function genesisInitialized() external view returns (bool);
    function commitGenesisPlan(bytes32 planHash) external;
    function hashGenesisPlan(
        SystemManifestBootstrapBinding calldata binding,
        GenesisBatch[] calldata batches
    ) external view returns (bytes32);
    function initializeGenesis(
        SystemManifestBootstrapBinding calldata binding,
        GenesisBatch[] calldata batches
    ) external;
}

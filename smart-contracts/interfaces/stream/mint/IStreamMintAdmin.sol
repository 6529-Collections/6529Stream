// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./IStreamMintManager.sol";

/// @notice Phase policy, execution authorization, and pause configuration.
/// @dev Caller ABI at the manager address. Use IStreamMintManager for ERC165
///      discovery and canonical nested request types; subset IDs are not advertised.
///      These methods require the manager owner. In the governed deployment that
///      owner is the Executor, whose action policy supplies the required delays.
interface IStreamMintAdmin {
    /// @notice Configures and registers a launch-static phase policy.
    function configurePhase(
        uint256 collectionId,
        bytes32 phaseId,
        IStreamMintManager.MintPhaseConfig calldata config,
        IStreamMintManager.MintGateConfig calldata gateConfig,
        bytes32[] calldata counterIds,
        IStreamMintManager.MintCounterConfig[] calldata counterConfigs
    ) external returns (bytes32 policyHash);

    /// @notice Enables or disables a caller for a configured phase.
    function setPhaseExecutor(uint256 collectionId, bytes32 phaseId, address executor, bool allowed)
        external;

    /// @notice Pauses or unpauses a configured phase.
    function setPhasePaused(uint256 collectionId, bytes32 phaseId, bool paused) external;
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./StreamGovernanceTypes.sol";

/// @notice Governance-authorized control-plane changes and one-way bootstrap operations.
/// @dev Caller ABI for the same Executor address. Discovery continues to use
///      IStreamGovernanceExecutor; this caller subset is not a new ERC165 claim.
interface IStreamGovernanceAdmin {
    /// @notice Enables or disables a proposer through a direction-checked Executor self-call.
    function registerProposer(address account, bool enabled) external;

    /// @notice Enables or disables a canceller through a direction-checked Executor self-call.
    function registerCanceller(address account, bool enabled) external;

    /// @notice Changes native-transfer receiver eligibility; catalog admission is still required.
    function setApprovedNativeReceiver(address receiver, bool approved) external;

    /// @notice Changes whether an exact target selector is an admitted tightening operation.
    function setTighteningCall(address target, bytes4 selector, bool tightening) external;

    /// @notice Registers or removes the terminal-freeze classification of a target selector.
    function registerFreezeSelector(address target, bytes4 selector, bool freeze) external;

    /// @notice Replaces the governance root with a contract matching the expected runtime hash.
    function rotateGovernanceRoot(address newRoot, bytes32 expectedCodeHash) external;

    /// @notice Registers an exact target selector requiring an atomic manifest publication tail.
    function registerSystemManifestTailTrigger(
        address triggerTarget,
        bytes4 triggerSelector,
        uint8 allowedActionClassMask
    ) external;

    /// @notice Binds the one-way genesis authority, inventory, action policy, and manifest commitments.
    function bindSystemManifestBootstrap(SystemManifestBootstrapBinding calldata binding) external;

    /// @notice Permanently seals the bound bootstrap after validating its live manifest state.
    function sealSystemManifestBootstrap() external;
}

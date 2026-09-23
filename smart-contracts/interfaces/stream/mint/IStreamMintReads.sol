// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./IStreamMintManager.sol";
import "../core/IStreamCore.sol";
import "../../../vendor/openzeppelin/IERC165.sol";

/// @notice Manager bindings, phase policy, replay state, counters, and operation previews.
/// @dev Caller ABI at the manager address. Use IStreamMintManager for ERC165
///      discovery and canonical nested request types; subset IDs are not advertised.
interface IStreamMintReads {
    /// @notice Computes the prospective policy under this Manager's immutable dependencies.
    /// @dev Sign this result before registration; pause does not alter policy identity.
    function previewPhasePolicyHash(
        uint256 collectionId,
        bytes32 phaseId,
        IStreamMintManager.MintPhaseConfig calldata config,
        IStreamMintManager.MintGateConfig calldata gateConfig,
        bytes32[] calldata counterIds,
        IStreamMintManager.MintCounterConfig[] calldata counterConfigs,
        address[] calldata executors
    ) external view returns (bytes32);

    /// @notice Permanent Core to which this manager allocates tokens.
    function core() external view returns (IStreamCore);

    /// @notice Durable replay and counter ledger used by this manager.
    function mintLedger() external view returns (IStreamMintLedger);

    /// @notice Canonical or compatibility module registry used for gate admission.
    function moduleRegistry() external view returns (IERC165);

    /// @notice Returns true for deployment validation.
    function isStreamMintManager() external view returns (bool);

    /// @notice Previews the single-step identity transcript for the current manager state.
    /// @dev Matches execution only while the nonce, phase policy/grace, and gate result stay unchanged.
    function previewSingleStepMintOperation(
        IStreamMintManager.MintBatch calldata batch,
        bytes calldata gateData
    ) external view returns (bytes32 operationRoot, bytes32[] memory operationIds);

    /// @notice Returns the first unreserved manager operation nonce.
    function nextOperationNonce() external view returns (uint256);

    /// @notice Returns immutable phase config plus existence.
    function phase(uint256 collectionId, bytes32 phaseId)
        external
        view
        returns (bool exists, IStreamMintManager.MintPhaseConfig memory config);

    /// @notice Returns the active manager policy hash for a phase.
    function phasePolicyHash(uint256 collectionId, bytes32 phaseId) external view returns (bytes32);

    /// @notice Returns manager-scoped authorization replay state independent of the caller.
    function isAuthorizationUsed(bytes32 authorizationId) external view returns (bool);

    /// @notice Returns manager-scoped nullifier replay state independent of the caller.
    function isNullifierUsed(bytes32 nullifier) external view returns (bool);

    /// @notice Returns manager-scoped operation-root replay state independent of the caller.
    function isOperationRootUsed(bytes32 operationRoot) external view returns (bool);

    /// @notice Returns the immediate predecessor policy and its grace expiry.
    function phasePolicyGrace(uint256 collectionId, bytes32 phaseId)
        external
        view
        returns (bytes32 previousPolicyHash, uint64 graceUntil);

    /// @notice Returns whether an executor may call a phase.
    function phaseExecutor(uint256 collectionId, bytes32 phaseId, address executor)
        external
        view
        returns (bool);

    /// @notice Returns the ordered counter IDs for a phase.
    function phaseCounterIds(uint256 collectionId, bytes32 phaseId)
        external
        view
        returns (bytes32[] memory);

    /// @notice Returns one manager-side counter config.
    function counterConfig(uint256 collectionId, bytes32 phaseId, bytes32 counterId)
        external
        view
        returns (IStreamMintManager.MintCounterConfig memory);

    /// @notice Returns one phase's optional gate config.
    function phaseGate(uint256 collectionId, bytes32 phaseId)
        external
        view
        returns (IStreamMintManager.MintGateConfig memory);

    /// @notice Previews the manager-derived subject key for one token/counter context.
    function previewSubjectKey(
        IStreamMintManager.CounterKeyMode keyMode,
        uint256 collectionId,
        bytes32 phaseId,
        bytes32 counterId,
        address payer,
        address recipient,
        address executor,
        address authorizer,
        bytes32 contextHash
    ) external view returns (bytes32);

    /// @notice Previews the canonical ledger value key for a derived subject.
    function previewCounterValueKey(
        uint256 collectionId,
        bytes32 phaseId,
        bytes32 counterId,
        bytes32 subjectKey
    ) external view returns (bytes32);
}

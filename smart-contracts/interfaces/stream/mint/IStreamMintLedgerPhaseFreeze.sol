// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../../../vendor/openzeppelin/IERC165.sol";

/// @notice Canonical phase freezes, inherited only through the same original Ledger.
interface IStreamMintLedgerPhaseFreeze is IERC165 {
    struct PhaseFreeze {
        bytes32 policyHash;
        bytes32 configurationHash;
    }

    error MintPhaseFreezeInvalid(address manager, uint256 collectionId, bytes32 phaseId);
    error MintPhaseFreezePolicyMismatch(address manager, uint256 collectionId, bytes32 phaseId);
    error MintPhaseFreezeLedgerMismatch(address predecessorLedger, address successorLedger);

    event MintLedgerPhaseFrozen(
        uint16 schemaVersion,
        address indexed manager,
        uint256 indexed collectionId,
        bytes32 indexed phaseId,
        bytes32 policyHash,
        bytes32 configurationHash
    );
    event MintLedgerPhaseFreezeImported(
        bytes32 indexed importRoot,
        address indexed predecessorManager,
        address indexed successorManager,
        uint256 collectionId,
        bytes32 phaseId,
        bytes32 predecessorFrozenPolicyHash,
        bytes32 successorPolicyHash,
        bytes32 configurationHash
    );

    /// @notice Only an authorized Manager may freeze its exact registered current policy.
    function freezePhase(uint256 collectionId, bytes32 phaseId, bytes32 policyHash) external;
    function phaseFreeze(address manager, uint256 collectionId, bytes32 phaseId)
        external
        view
        returns (PhaseFreeze memory);
    function frozenPhaseCount(address manager) external view returns (uint256);
    function frozenPhaseAt(address manager, uint256 index)
        external
        view
        returns (uint256 collectionId, bytes32 phaseId);
    /// @notice Remaining executor ceiling, also used to initialize an inherited frozen phase.
    function frozenPhaseExecutors(address manager, uint256 collectionId, bytes32 phaseId)
        external
        view
        returns (address[] memory);
    /// @notice Copies and validates at most 32 frozen phases before original import completion.
    function importPhaseFreezes(bytes32 importRoot, uint256 maxCount) external;
    function mintImportFreezeProgress(bytes32 importRoot)
        external
        view
        returns (uint256 imported, uint256 required);
}

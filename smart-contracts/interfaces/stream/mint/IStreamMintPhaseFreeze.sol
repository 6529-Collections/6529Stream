// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../../../vendor/openzeppelin/IERC165.sol";

/// @notice Optional one-way phase policy restriction backed by the immutable mint Ledger.
interface IStreamMintPhaseFreeze is IERC165 {
    error MintPhaseAlreadyFrozen(uint256 collectionId, bytes32 phaseId);
    error MintPhaseFrozenExecutor(uint256 collectionId, bytes32 phaseId, address executor);
    error MintPhaseFreezeGovernanceInvalid();
    error MintPhaseFreezeReadFailed(address target);

    event MintPhaseFrozen(
        uint16 schemaVersion,
        uint256 indexed collectionId,
        bytes32 indexed phaseId,
        bool frozen,
        bytes32 policyHash
    );

    /// @notice Requires the exact executing class-2 terminal-freeze governance action.
    function freezePhase(uint256 collectionId, bytes32 phaseId) external;
    function phaseFrozen(uint256 collectionId, bytes32 phaseId) external view returns (bool);
    /// @notice The actual current executor set, bounded by the unchanged Manager hard limit.
    function phaseExecutors(uint256 collectionId, bytes32 phaseId)
        external
        view
        returns (address[] memory);
    function phaseFreezeTransitionHashes(uint256 collectionId, bytes32 phaseId)
        external
        view
        returns (bytes32 scope, bytes32 oldHash, bytes32 newHash);
}

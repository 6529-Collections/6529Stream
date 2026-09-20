// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../../../vendor/openzeppelin/IERC165.sol";
import "../revenue/StreamPrimarySettlementTypes.sol";

/// @notice Optional pre-payment optimization for storing immutable authenticated evidence.
/// @dev Preparation is permissionless and never consumes a sale or records its first-sale time.
/// The original purchase entry authenticates current evidence and persists it inline when absent.
interface IStreamConservationFloorPreparation is IERC165 {
    event ConservationPrimarySalePrepared(
        bytes32 indexed preparationHash,
        address indexed recorder,
        bytes32 indexed settlementKey,
        bytes32 collectionEvidenceHash,
        bytes32 releaseEvidenceHash,
        uint16 schemaVersion
    );

    /// @notice Optionally prepare an exact result, including escrow/direct variants, before payment.
    /// Current native evidence is authenticated now and checked again at its first successful use;
    /// an older preparation cannot replace fresh valid evidence or authorize a payment.
    function preparePrimarySale(
        address recorder,
        StreamPrimarySettlementTypes.ERC20SettlementCandidate calldata candidate,
        StreamPrimarySettlementTypes.PrimarySettlementResult calldata expectedResult
    ) external returns (bytes32 preparationHash);

    function primarySalePrepared(bytes32 preparationHash) external view returns (bool);
}

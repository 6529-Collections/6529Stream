// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../../../vendor/openzeppelin/IERC165.sol";
import "./StreamDirectPrimaryConservationTypes.sol";

/// @notice Additive floor entry for genuine original direct-product paid receipts.
interface IStreamDirectPrimaryConservationFloor is IERC165 {
    error ConservationDirectSaleMismatch(address adapter, bytes32 authorizationId);

    event ConservationDirectPrimarySaleRecorded(
        bytes32 indexed directKey,
        bytes32 indexed receiptHash,
        StreamDirectPrimaryConservationTypes.Receipt receipt,
        uint16 schemaVersion
    );

    /// @notice Independently reads and authenticates the caller's exact locally stored receipt.
    /// @dev No universal candidate, consumed result or offchain preparation is synthesized.
    function recordDirectPrimarySale(bytes32 authorizationId) external returns (bytes32 receiptHash);

    /// @notice Complete immutable local evidence; unknown and universal keys return zero tuples.
    /// @dev Historical reads never call the original adapter, manager or provider.
    function directPrimarySaleFloorReceipt(bytes32 directKey)
        external
        view
        returns (StreamDirectPrimaryConservationTypes.Receipt memory);
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../../../vendor/openzeppelin/IERC165.sol";
import "./StreamDirectPrimarySaleTypes.sol";

/// @notice Additive actual-receipt capability; original product purchase interfaces stay unchanged.
interface IStreamDirectPrimarySaleReceipt is IERC165 {
    event DirectPrimarySaleRecorded(
        bytes32 indexed authorizationId,
        bytes32 indexed receiptHash,
        uint256 indexed tokenId,
        StreamDirectPrimarySaleTypes.Receipt receipt,
        uint16 schemaVersion
    );

    function directPrimaryBindings()
        external
        view
        returns (StreamDirectPrimarySaleTypes.Bindings memory);

    /// @notice Returns immutable local paid evidence, or the all-zero tuple before successful payment.
    function directPrimarySaleReceipt(bytes32 authorizationId)
        external
        view
        returns (StreamDirectPrimarySaleTypes.Receipt memory);

    /// @notice Hashes the exact local receipt in its DIRECT domain; returns zero for an unknown key.
    function directPrimarySaleReceiptHash(bytes32 authorizationId) external view returns (bytes32);
}

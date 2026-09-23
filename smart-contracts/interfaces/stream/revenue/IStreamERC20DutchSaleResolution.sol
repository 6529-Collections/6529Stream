// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../../../vendor/openzeppelin/IERC165.sol";
import "./StreamPrimarySettlementTypes.sol";

/// @notice Closed current-price resolution for an admitted standard Dutch carrier.
/// @dev The complete execution bytes contain the immutable sale request and canonical Sales
/// authorization. Resolution is read-only and does not consume either signature or mint state.
interface IStreamERC20DutchSaleResolution is IERC165 {
    function dutchResolutionProfile() external pure returns (bytes32);

    function resolveERC20DutchExecution(
        bytes32 saleId,
        bytes32 saleConfigHash,
        address executor,
        bytes calldata executionData
    ) external view returns (StreamPrimarySettlementTypes.ERC20SettlementCandidate memory);
}

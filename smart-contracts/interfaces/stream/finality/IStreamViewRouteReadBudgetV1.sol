// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import { IERC165 } from "../../../vendor/openzeppelin/IERC165.sol";

/// @notice An explicitly governed, once-bound budget for the fixed VIEW route reads.
/// @dev The selected provider must return the readGas in its full, governed
/// IStreamViewSourceBinding declaration. Pending bindings revert. This cheap
/// getter conveys no currentness verdict and must not recurse into source reads.
interface IStreamViewRouteReadBudgetV1 is IERC165 {
    function viewRouteReadBudget() external view returns (bytes32 profile, uint32 readGas);
}

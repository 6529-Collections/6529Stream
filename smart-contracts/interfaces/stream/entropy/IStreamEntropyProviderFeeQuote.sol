// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../../../vendor/openzeppelin/IERC165.sol";

/// @notice Optional capability for providers whose fee is independent of request context.
/// @dev This must equal quoteRequest(context) for every context at the same state.
///      The promise is checked against admitted implementation code; ERC165 alone is not proof.
interface IStreamEntropyProviderFeeQuote is IERC165 {
    function contextIndependentRequestFee() external view returns (uint256);
}

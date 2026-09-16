// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/// @notice Narrow current ARRNG boundary, including request and authority pin reads.
/// @dev Matches arrng/arrng-contracts fdc0286a. No callback gas limit is accepted upstream.
interface IStreamARRNGController {
    function owner() external view returns (address);
    function oracleAddress() external view returns (address);
    function arrngRequestId() external view returns (uint64);
    function minimumNativeToken() external view returns (uint128);
    function requestRandomWords(uint256 numberOfNumbers, address refundAddress)
        external
        payable
        returns (uint256 requestId);
}

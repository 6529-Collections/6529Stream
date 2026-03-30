// SPDX-License-Identifier: MIT
//
// =============================================================================
// IArrngConsumer — ELI5
// =============================================================================
// Callback Arrng invokes on your contract when random numbers are ready.
// Function: receiveRandomness(requestId, numbers).
// =============================================================================

pragma solidity 0.8.19;

interface IArrngConsumer {
  /**
   *
   * @dev receiveRandomness: receive randomness
   *
   * @param arrngRequestId_: unique ID for this request
   * @param randomNumbers_: array of random integers requested
   *
   */
  function receiveRandomness(
    uint256 arrngRequestId_,
    uint256[] calldata randomNumbers_
  ) external payable;
}
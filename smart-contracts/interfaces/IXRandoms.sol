// SPDX-License-Identifier: MIT
//
// =============================================================================
// IXRandoms — ELI5
// =============================================================================
// Word pool / weak RNG used by NextGenRandomizerNXT: randomNumber + randomWord.
// =============================================================================

pragma solidity ^0.8.19;

interface IXRandoms {

    function randomNumber() external view returns (uint256);

    function randomWord() external view returns (string memory);
    
}
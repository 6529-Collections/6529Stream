// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/// @notice Existing canonical constructor facts, read without widening their published aggregate APIs.
interface IStreamArchivalGovernanceBinding {
    function roleRegistry() external view returns (address);
    function governanceExecutor() external view returns (address);
    function owner() external view returns (address);
}

/// @notice Reciprocal artist-suite/provider pin, validated after canonical Core selection.
interface IStreamArtistArchivalBinding {
    function core() external view returns (address);
    function archivalCoverage() external view returns (address);
}

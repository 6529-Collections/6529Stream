// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

interface IStreamMetadataCurrentCompletion {
    function repeatedAncestor(
        address core,
        address original,
        address current,
        bytes calldata encodedSuite
    ) external view returns (address);
}

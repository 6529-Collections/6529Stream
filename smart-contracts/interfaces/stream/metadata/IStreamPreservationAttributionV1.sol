// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/// @notice Explicit non-sanction attribution projection; never a live AA-DISPLAY replacement.
interface IStreamPreservationAttributionV1 {
    function preservationAttributionProfile() external pure returns (bytes32);
    function core() external view returns (address);
    function router() external view returns (address);
    function liveAttribution() external view returns (address);
    function liveAttributionCodeHash() external view returns (bytes32);
    function preservationAttribution(uint256 collectionId, uint256 tokenId)
        external view returns (bytes memory);
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/// @notice Full preservation output under an explicitly admitted non-sanction profile.
/// @dev Successful reads do not prove finality, admission or that an artwork is unsanctioned.
interface IStreamPreservationRendererV1 {
    function preservationProfile() external pure returns (bytes32);
    function preservationBinding() external view returns (
        address core, address router, address liveRenderer, bytes32 liveRendererRuntimeHash,
        address preservationAttribution, bytes32 preservationAttributionRuntimeHash
    );
    function preservationTokenJSON(uint256 tokenId) external view returns (string memory);
    function preservationTokenHTML(uint256 tokenId) external view returns (string memory);
}

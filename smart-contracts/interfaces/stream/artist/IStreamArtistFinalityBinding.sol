// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/// @notice Constructor-fixed finality counterpart, exposed by the artist's fixed Coordinator.
/// @dev The facade resolves these through its immutable Coordinator address. It does not embed
///      the Coordinator runtime hash or a finality-derived configuration hash in its own runtime.
interface IStreamArtistFinalityBinding {
    function finalityRegistry() external view returns (address);
    function finalityRegistryCodeHash() external view returns (bytes32);
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/// @notice Versioned renderer input/context and external dependency-read profile.
/// @dev These declarations are interpreted only for admitted, runtime-pinned code. The read
///      itself does not prove code determinism or discover undeclared external calls.
interface IStreamMetadataRenderingProfile {
    function renderingProfile()
        external
        view
        returns (bytes32 presentationProfile, bytes32 contextHash, bytes32 dependencyReadSetHash);
}

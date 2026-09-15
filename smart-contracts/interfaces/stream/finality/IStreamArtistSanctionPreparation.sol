// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./StreamArtworkFinalityTypes.sol";
import "./StreamArtistSanctionPreparationTypes.sol";

/// @notice Validates the exact non-sanction candidate before an artist signature exists.
interface IStreamArtistSanctionPreparation {
    /// @notice Validates the actual scope, current pins, mandatory frozen non-sanction components,
    ///         authoritative discovery, complete scope evidence and independent stored manifest.
    /// @dev Callable outside an executing governance action. The ordered input excludes every
    ///      ARTIST_SANCTION entry and PLATFORM_WORKS_DECLARATION: this is an artist-bound profile.
    ///      No placeholder sanction record or caller-selected readiness value is admitted.
    ///      Finalization revalidates these facts and the actual separately recorded sanction.
    function prepareSanction(
        StreamFinalityScope calldata scope,
        StreamFinalityComponentExpectation[] calldata nonSanctionComponents,
        StreamFinalityManifestRef calldata manifest
    ) external view returns (StreamArtistSanctionPreparation memory);
}

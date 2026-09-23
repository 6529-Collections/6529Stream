// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "./IStreamArtistSanctionPreparation.sol";
import "./IStreamFinalitySanctionReview.sol";

/// @notice Complete current artist candidate and its original image facts in one preparation.
/// @dev Same scope, component, manifest and current-source gates as prepareSanction.
/// Finalization still independently revalidates its own current inputs and original sanction.
interface IStreamArtistSanctionReviewPreparation {
    function prepareSanctionWithReview(
        StreamFinalityScope calldata scope,
        StreamFinalityComponentExpectation[] calldata nonSanctionComponents,
        StreamFinalityManifestRef calldata manifest
    )
        external
        view
        returns (
            StreamArtistSanctionPreparation memory prepared,
            IStreamFinalitySanctionReview.ReviewFacts memory review
        );
}

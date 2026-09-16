// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../../interfaces/stream/finality/IStreamArtworkFinalityComponents.sol";
import "../../interfaces/stream/finality/IStreamCoreFinalityAdapter.sol";
import "../../interfaces/stream/finality/IStreamCoreFinalitySource.sol";
import "../../interfaces/stream/finality/IStreamFinalityGovernanceAuthority.sol";
import "../../interfaces/stream/finality/IStreamFinalityMetadataReads.sol";
import "../../interfaces/stream/finality/IStreamFinalitySanctionReads.sol";
import "./StreamArtworkFinalityRegistry.sol";
import "../../interfaces/stream/finality/StreamArtworkFinalityTypes.sol";

/// @notice Compatibility surface for the retired registry-local finality preview.
/// @dev Canonical preparation lives on StreamArtworkFinalityRegistry. These old result
///      tuples include a registry-local clock and cannot honestly describe its replacement.
///      The canonical preview composition is a separate pending feature (ADR 0039).
contract StreamArtworkFinalityPreview {
    error FinalityPreviewZeroAddress();
    error FinalityPreviewLegacyLifecycleRetired();

    StreamArtworkFinalityRegistry public immutable registry;
    IStreamCoreFinalitySource public immutable coreReads;
    IStreamCoreFinalityAdapter public immutable coreFinalityAdapter;
    IStreamFinalityMetadataReads public immutable metadataReads;
    IStreamFinalitySanctionReads public immutable sanctionReads;
    IStreamFinalityGovernanceAuthority public immutable governanceAuthority;
    address public immutable finalityDiscovery;

    constructor(StreamArtworkFinalityRegistry registry_) {
        if (address(registry_) == address(0)) revert FinalityPreviewZeroAddress();
        registry = registry_;
        coreReads = registry_.coreReads();
        coreFinalityAdapter = registry_.coreFinalityAdapter();
        metadataReads = registry_.metadataReads();
        sanctionReads = registry_.sanctionReads();
        governanceAuthority = IStreamFinalityGovernanceAuthority(registry_.governanceAuthority());
        finalityDiscovery = registry_.finalityDiscovery();
    }

    function previewCollectionFinality(
        uint256 collectionId,
        StreamFinalityComponentExpectation[] calldata components,
        StreamFinalityManifestRef calldata manifest
    ) external view returns (StreamFinalityPreview memory) {
        revert FinalityPreviewLegacyLifecycleRetired();
    }

    function previewArtworkScopeFinality(
        StreamFinalityScope calldata scope,
        StreamFinalityComponentExpectation[] calldata components,
        StreamFinalityManifestRef calldata manifest
    ) external view returns (StreamFinalityPreview memory) {
        revert FinalityPreviewLegacyLifecycleRetired();
    }
}

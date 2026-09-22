// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/// @notice Stable product ordinals and names without importing concrete creation templates.
/// @dev This catalogue carries no creation code. Deployment scripts retain the full
/// StreamCurrentGraphCreation catalogue and bridge these identical ordinals explicitly.
library StreamCurrentGraphKinds {
    enum Kind {
        StreamArchivalCoverage,
        StreamArtistAcceptanceLifecycle,
        StreamArtistArchiveV2,
        StreamArtistAttributionLifecycle,
        StreamArtistBindingLifecycle,
        StreamArtistCollaboratorLifecycle,
        StreamArtistConsentFinalityLifecycle,
        StreamArtistIdentityAuthority,
        StreamArtistOnboardingCoordinator,
        StreamArtistOnboardingRegistry,
        StreamArtistPayoutLifecycle,
        StreamArtistRegistryValidatorBase,
        StreamArtworkFinalityRegistry,
        StreamArweaveCheckpointVerifier,
        StreamArweaveObjectCheckpointVerifier,
        StreamAssetPolicyRegistry,
        StreamBundleArchiveCoverage,
        StreamCollectionMetadataV1,
        StreamCollectionSnapshots,
        StreamCollectionTokenInventory,
        StreamConservationRecordSelection,
        StreamContentLeafManifest,
        StreamCore,
        StreamCoreFinalityAdapter,
        StreamEntropyCoordinator,
        StreamExternalArtifactCoverage,
        StreamFinalityArtifactCoverage,
        StreamFinalityCoordinatorInventory,
        StreamFinalityCurrentDiscovery,
        StreamFinalityEntropySourceFactory,
        StreamFinalityNativeEvidenceProvider,
        StreamFinalityScopeMembership,
        StreamFinalityServingHostAdapter,
        StreamFixedPriceSaleAdapter,
        StreamGovernanceExecutor,
        StreamMetadataRouter,
        StreamMintLedger,
        StreamMintManager,
        StreamModuleRegistry,
        StreamOnchainContentCheckpoint,
        StreamReferenceRenderPublication,
        StreamRenderCriticalInventory,
        StreamRevenueEscrow,
        StreamRevenueResolver,
        StreamRightsRecordSelection,
        StreamRoleRegistry,
        StreamRoyaltyResolver,
        StreamSchemaRegistry,
        StreamSplitFactory,
        StreamSystemManifest,
        StreamWorkRecordSelection,
        StreamStaticSelectionCheckpoint,
        StreamStaticContentCheckpoint,
        StreamStaticOutputManifest,
        StreamScopedSnapshotPublication,
        StreamScopedReferencePublication,
        StreamScopedRenderCriticalInventory,
        StreamScopedBundleArchiveCoverage,
        StreamFinalityEntropyPolicySourceFactoryV2,
        StreamFinalityScopedEntropyPolicySourceFactoryV2,
        StreamPolicyPublicationFactoryV2,
        StreamScopedPolicyPublicationFactoryV2,
        StreamFinalityFullPolicyEvidenceProviderV2,
        StreamFinalityFullPolicyDiscoveryV2
    }

    function name(Kind kind) internal pure returns (string memory) {
        if (kind == Kind.StreamArchivalCoverage) return "StreamArchivalCoverage";
        if (kind == Kind.StreamArtistAcceptanceLifecycle) return "StreamArtistAcceptanceLifecycle";
        if (kind == Kind.StreamArtistArchiveV2) return "StreamArtistArchiveV2";
        if (kind == Kind.StreamArtistAttributionLifecycle) {
            return "StreamArtistAttributionLifecycle";
        }
        if (kind == Kind.StreamArtistBindingLifecycle) return "StreamArtistBindingLifecycle";
        if (kind == Kind.StreamArtistCollaboratorLifecycle) {
            return "StreamArtistCollaboratorLifecycle";
        }
        if (kind == Kind.StreamArtistConsentFinalityLifecycle) {
            return "StreamArtistConsentFinalityLifecycle";
        }
        if (kind == Kind.StreamArtistIdentityAuthority) return "StreamArtistIdentityAuthority";
        if (kind == Kind.StreamArtistOnboardingCoordinator) {
            return "StreamArtistOnboardingCoordinator";
        }
        if (kind == Kind.StreamArtistOnboardingRegistry) return "StreamArtistOnboardingRegistry";
        if (kind == Kind.StreamArtistPayoutLifecycle) return "StreamArtistPayoutLifecycle";
        if (kind == Kind.StreamArtistRegistryValidatorBase) {
            return "StreamArtistRegistryValidatorBase";
        }
        if (kind == Kind.StreamArtworkFinalityRegistry) return "StreamArtworkFinalityRegistry";
        if (kind == Kind.StreamArweaveCheckpointVerifier) return "StreamArweaveCheckpointVerifier";
        if (kind == Kind.StreamArweaveObjectCheckpointVerifier) {
            return "StreamArweaveObjectCheckpointVerifier";
        }
        if (kind == Kind.StreamAssetPolicyRegistry) return "StreamAssetPolicyRegistry";
        if (kind == Kind.StreamBundleArchiveCoverage) return "StreamBundleArchiveCoverage";
        if (kind == Kind.StreamCollectionMetadataV1) return "StreamCollectionMetadataV1";
        if (kind == Kind.StreamCollectionSnapshots) return "StreamCollectionSnapshots";
        if (kind == Kind.StreamCollectionTokenInventory) return "StreamCollectionTokenInventory";
        if (kind == Kind.StreamConservationRecordSelection) {
            return "StreamConservationRecordSelection";
        }
        if (kind == Kind.StreamContentLeafManifest) return "StreamContentLeafManifest";
        if (kind == Kind.StreamCore) return "StreamCore";
        if (kind == Kind.StreamCoreFinalityAdapter) return "StreamCoreFinalityAdapter";
        if (kind == Kind.StreamEntropyCoordinator) return "StreamEntropyCoordinator";
        if (kind == Kind.StreamExternalArtifactCoverage) return "StreamExternalArtifactCoverage";
        if (kind == Kind.StreamFinalityArtifactCoverage) return "StreamFinalityArtifactCoverage";
        if (kind == Kind.StreamFinalityCoordinatorInventory) {
            return "StreamFinalityCoordinatorInventory";
        }
        if (kind == Kind.StreamFinalityCurrentDiscovery) return "StreamFinalityCurrentDiscovery";
        if (kind == Kind.StreamFinalityEntropySourceFactory) {
            return "StreamFinalityEntropySourceFactory";
        }
        if (kind == Kind.StreamFinalityNativeEvidenceProvider) {
            return "StreamFinalityNativeEvidenceProvider";
        }
        if (kind == Kind.StreamFinalityScopeMembership) return "StreamFinalityScopeMembership";
        if (kind == Kind.StreamFinalityServingHostAdapter) {
            return "StreamFinalityServingHostAdapter";
        }
        if (kind == Kind.StreamFixedPriceSaleAdapter) return "StreamFixedPriceSaleAdapter";
        if (kind == Kind.StreamGovernanceExecutor) return "StreamGovernanceExecutor";
        if (kind == Kind.StreamMetadataRouter) return "StreamMetadataRouter";
        if (kind == Kind.StreamMintLedger) return "StreamMintLedger";
        if (kind == Kind.StreamMintManager) return "StreamMintManager";
        if (kind == Kind.StreamModuleRegistry) return "StreamModuleRegistry";
        if (kind == Kind.StreamOnchainContentCheckpoint) return "StreamOnchainContentCheckpoint";
        if (kind == Kind.StreamReferenceRenderPublication) {
            return "StreamReferenceRenderPublication";
        }
        if (kind == Kind.StreamRenderCriticalInventory) return "StreamRenderCriticalInventory";
        if (kind == Kind.StreamRevenueEscrow) return "StreamRevenueEscrow";
        if (kind == Kind.StreamRevenueResolver) return "StreamRevenueResolver";
        if (kind == Kind.StreamRightsRecordSelection) return "StreamRightsRecordSelection";
        if (kind == Kind.StreamRoleRegistry) return "StreamRoleRegistry";
        if (kind == Kind.StreamRoyaltyResolver) return "StreamRoyaltyResolver";
        if (kind == Kind.StreamSchemaRegistry) return "StreamSchemaRegistry";
        if (kind == Kind.StreamSplitFactory) return "StreamSplitFactory";
        if (kind == Kind.StreamSystemManifest) return "StreamSystemManifest";
        if (kind == Kind.StreamWorkRecordSelection) return "StreamWorkRecordSelection";
        if (kind == Kind.StreamStaticSelectionCheckpoint) return "StreamStaticSelectionCheckpoint";
        if (kind == Kind.StreamStaticContentCheckpoint) return "StreamStaticContentCheckpoint";
        if (kind == Kind.StreamStaticOutputManifest) return "StreamStaticOutputManifest";
        if (kind == Kind.StreamScopedSnapshotPublication) return "StreamScopedSnapshotPublication";
        if (kind == Kind.StreamScopedReferencePublication) {
            return "StreamScopedReferencePublication";
        }
        if (kind == Kind.StreamScopedRenderCriticalInventory) {
            return "StreamScopedRenderCriticalInventory";
        }
        if (kind == Kind.StreamScopedBundleArchiveCoverage) {
            return "StreamScopedBundleArchiveCoverage";
        }
        if (kind == Kind.StreamFinalityEntropyPolicySourceFactoryV2) {
            return "StreamFinalityEntropyPolicySourceFactoryV2";
        }
        if (kind == Kind.StreamFinalityScopedEntropyPolicySourceFactoryV2) {
            return "StreamFinalityScopedEntropyPolicySourceFactoryV2";
        }
        if (kind == Kind.StreamPolicyPublicationFactoryV2) {
            return "StreamPolicyPublicationFactoryV2";
        }
        if (kind == Kind.StreamScopedPolicyPublicationFactoryV2) {
            return "StreamScopedPolicyPublicationFactoryV2";
        }
        if (kind == Kind.StreamFinalityFullPolicyEvidenceProviderV2) {
            return "StreamFinalityFullPolicyEvidenceProviderV2";
        }
        if (kind == Kind.StreamFinalityFullPolicyDiscoveryV2) {
            return "StreamFinalityFullPolicyDiscoveryV2";
        }

        revert("unknown original product template");
    }
}

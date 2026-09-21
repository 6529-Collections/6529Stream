// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

interface NativeAssemblyArtifactVm {
    function getCode(string calldata artifact) external view returns (bytes memory);
}

/// @notice Test-only access to genuine Forge-linked production creation artifacts.
/// @dev Callers retain ordinary CREATE, constructor ABI, caller/nonces and native
/// runtime/link/immutable checks. Production contracts and deployment scripts do
/// not import this helper. Artifact owners are authenticated before execution.
library StreamNativeAssemblyCreation {
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
        StreamFinalityFullPolicyDiscoveryV2,
        StreamCurrentAuthorityRightsRecordSelection
    }

    function name(Kind kind) public pure returns (string memory) {
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
        if (kind == Kind.StreamCurrentAuthorityRightsRecordSelection) {
            return "StreamCurrentAuthorityRightsRecordSelection";
        }

        revert("unknown original product template");
    }

    function artifact(Kind kind) public pure returns (string memory) {
        if (kind == Kind.StreamArchivalCoverage) {
            return "smart-contracts/domains/preservation/StreamArchivalCoverage.sol:StreamArchivalCoverage";
        }
        if (kind == Kind.StreamArtistAcceptanceLifecycle) {
            return "smart-contracts/domains/artist/StreamArtistAcceptanceLifecycle.sol:StreamArtistAcceptanceLifecycle";
        }
        if (kind == Kind.StreamArtistArchiveV2) {
            return "smart-contracts/domains/artist/StreamArtistArchiveV2.sol:StreamArtistArchiveV2";
        }
        if (kind == Kind.StreamArtistAttributionLifecycle) {
            return "smart-contracts/domains/artist/StreamArtistAttributionLifecycle.sol:StreamArtistAttributionLifecycle";
        }
        if (kind == Kind.StreamArtistBindingLifecycle) {
            return "smart-contracts/domains/artist/StreamArtistBindingLifecycle.sol:StreamArtistBindingLifecycle";
        }
        if (kind == Kind.StreamArtistCollaboratorLifecycle) {
            return "smart-contracts/domains/artist/StreamArtistCollaboratorLifecycle.sol:StreamArtistCollaboratorLifecycle";
        }
        if (kind == Kind.StreamArtistConsentFinalityLifecycle) {
            return "smart-contracts/domains/artist/StreamArtistConsentFinalityLifecycle.sol:StreamArtistConsentFinalityLifecycle";
        }
        if (kind == Kind.StreamArtistIdentityAuthority) {
            return "smart-contracts/domains/artist/StreamArtistIdentityAuthority.sol:StreamArtistIdentityAuthority";
        }
        if (kind == Kind.StreamArtistOnboardingCoordinator) {
            return "smart-contracts/domains/artist/StreamArtistOnboardingCoordinator.sol:StreamArtistOnboardingCoordinator";
        }
        if (kind == Kind.StreamArtistOnboardingRegistry) {
            return "smart-contracts/domains/artist/StreamArtistOnboardingRegistry.sol:StreamArtistOnboardingRegistry";
        }
        if (kind == Kind.StreamArtistPayoutLifecycle) {
            return "smart-contracts/domains/artist/StreamArtistPayoutLifecycle.sol:StreamArtistPayoutLifecycle";
        }
        if (kind == Kind.StreamArtistRegistryValidatorBase) {
            return "smart-contracts/domains/artist/StreamArtistRegistryValidatorBase.sol:StreamArtistRegistryValidatorBase";
        }
        if (kind == Kind.StreamArtworkFinalityRegistry) {
            return "smart-contracts/domains/finality/StreamArtworkFinalityRegistry.sol:StreamArtworkFinalityRegistry";
        }
        if (kind == Kind.StreamArweaveCheckpointVerifier) {
            return "smart-contracts/domains/preservation/StreamArweaveCheckpointVerifier.sol:StreamArweaveCheckpointVerifier";
        }
        if (kind == Kind.StreamArweaveObjectCheckpointVerifier) {
            return "smart-contracts/domains/preservation/StreamArweaveObjectCheckpointVerifier.sol:StreamArweaveObjectCheckpointVerifier";
        }
        if (kind == Kind.StreamAssetPolicyRegistry) {
            return "smart-contracts/domains/revenue/StreamAssetPolicyRegistry.sol:StreamAssetPolicyRegistry";
        }
        if (kind == Kind.StreamBundleArchiveCoverage) {
            return "smart-contracts/domains/preservation/StreamBundleArchiveCoverage.sol:StreamBundleArchiveCoverage";
        }
        if (kind == Kind.StreamCollectionMetadataV1) {
            return "smart-contracts/domains/metadata/StreamCollectionMetadataV1.sol:StreamCollectionMetadataV1";
        }
        if (kind == Kind.StreamCollectionSnapshots) {
            return "smart-contracts/domains/metadata/StreamCollectionSnapshots.sol:StreamCollectionSnapshots";
        }
        if (kind == Kind.StreamCollectionTokenInventory) {
            return "smart-contracts/domains/finality/StreamCollectionTokenInventory.sol:StreamCollectionTokenInventory";
        }
        if (kind == Kind.StreamConservationRecordSelection) {
            return "smart-contracts/domains/metadata/StreamConservationRecordSelection.sol:StreamConservationRecordSelection";
        }
        if (kind == Kind.StreamContentLeafManifest) {
            return "smart-contracts/domains/finality/StreamContentLeafManifest.sol:StreamContentLeafManifest";
        }
        if (kind == Kind.StreamCore) {
            return "smart-contracts/core/StreamCore.sol:StreamCore";
        }
        if (kind == Kind.StreamCoreFinalityAdapter) {
            return "smart-contracts/domains/finality/StreamCoreFinalityAdapter.sol:StreamCoreFinalityAdapter";
        }
        if (kind == Kind.StreamEntropyCoordinator) {
            return
                "smart-contracts/domains/entropy/StreamEntropyCoordinator.sol:StreamEntropyCoordinator";
        }
        if (kind == Kind.StreamExternalArtifactCoverage) {
            return "smart-contracts/domains/preservation/StreamExternalArtifactCoverage.sol:StreamExternalArtifactCoverage";
        }
        if (kind == Kind.StreamFinalityArtifactCoverage) {
            return "smart-contracts/domains/preservation/StreamFinalityArtifactCoverage.sol:StreamFinalityArtifactCoverage";
        }
        if (kind == Kind.StreamFinalityCoordinatorInventory) {
            return "smart-contracts/domains/finality/StreamFinalityCoordinatorInventory.sol:StreamFinalityCoordinatorInventory";
        }
        if (kind == Kind.StreamFinalityCurrentDiscovery) {
            return "smart-contracts/domains/finality/StreamFinalityCurrentDiscovery.sol:StreamFinalityCurrentDiscovery";
        }
        if (kind == Kind.StreamFinalityEntropySourceFactory) {
            return "smart-contracts/domains/finality/StreamFinalityEntropySourceFactory.sol:StreamFinalityEntropySourceFactory";
        }
        if (kind == Kind.StreamFinalityNativeEvidenceProvider) {
            return "smart-contracts/domains/finality/StreamFinalityNativeEvidenceProvider.sol:StreamFinalityNativeEvidenceProvider";
        }
        if (kind == Kind.StreamFinalityScopeMembership) {
            return "smart-contracts/domains/finality/StreamFinalityScopeMembership.sol:StreamFinalityScopeMembership";
        }
        if (kind == Kind.StreamFinalityServingHostAdapter) {
            return "smart-contracts/domains/finality/StreamFinalityServingHostAdapter.sol:StreamFinalityServingHostAdapter";
        }
        if (kind == Kind.StreamFixedPriceSaleAdapter) {
            return "smart-contracts/domains/mint/StreamFixedPriceSaleAdapter.sol:StreamFixedPriceSaleAdapter";
        }
        if (kind == Kind.StreamGovernanceExecutor) {
            return "smart-contracts/domains/governance/StreamGovernanceExecutor.sol:StreamGovernanceExecutor";
        }
        if (kind == Kind.StreamMetadataRouter) {
            return "smart-contracts/domains/metadata/StreamMetadataRouter.sol:StreamMetadataRouter";
        }
        if (kind == Kind.StreamMintLedger) {
            return "smart-contracts/domains/mint/StreamMintLedger.sol:StreamMintLedger";
        }
        if (kind == Kind.StreamMintManager) {
            return "smart-contracts/domains/mint/StreamMintManager.sol:StreamMintManager";
        }
        if (kind == Kind.StreamModuleRegistry) {
            return "smart-contracts/domains/modules/StreamModuleRegistry.sol:StreamModuleRegistry";
        }
        if (kind == Kind.StreamOnchainContentCheckpoint) {
            return "smart-contracts/domains/finality/StreamOnchainContentCheckpoint.sol:StreamOnchainContentCheckpoint";
        }
        if (kind == Kind.StreamReferenceRenderPublication) {
            return "smart-contracts/domains/preservation/StreamReferenceRenderPublication.sol:StreamReferenceRenderPublication";
        }
        if (kind == Kind.StreamRenderCriticalInventory) {
            return "smart-contracts/domains/preservation/StreamRenderCriticalInventory.sol:StreamRenderCriticalInventory";
        }
        if (kind == Kind.StreamRevenueEscrow) {
            return "smart-contracts/domains/revenue/StreamRevenueEscrow.sol:StreamRevenueEscrow";
        }
        if (kind == Kind.StreamRevenueResolver) {
            return "smart-contracts/domains/revenue/StreamRevenueResolver.sol:StreamRevenueResolver";
        }
        if (kind == Kind.StreamRightsRecordSelection) {
            return "smart-contracts/domains/metadata/StreamRightsRecordSelection.sol:StreamRightsRecordSelection";
        }
        if (kind == Kind.StreamRoleRegistry) {
            return "smart-contracts/domains/governance/StreamRoleRegistry.sol:StreamRoleRegistry";
        }
        if (kind == Kind.StreamRoyaltyResolver) {
            return "smart-contracts/domains/revenue/StreamRoyaltyResolver.sol:StreamRoyaltyResolver";
        }
        if (kind == Kind.StreamSchemaRegistry) {
            return "smart-contracts/domains/metadata/StreamSchemaRegistry.sol:StreamSchemaRegistry";
        }
        if (kind == Kind.StreamSplitFactory) {
            return "smart-contracts/domains/revenue/StreamSplitFactory.sol:StreamSplitFactory";
        }
        if (kind == Kind.StreamSystemManifest) {
            return
                "smart-contracts/domains/governance/StreamSystemManifest.sol:StreamSystemManifest";
        }
        if (kind == Kind.StreamWorkRecordSelection) {
            return "smart-contracts/domains/metadata/StreamWorkRecordSelection.sol:StreamWorkRecordSelection";
        }
        if (kind == Kind.StreamStaticSelectionCheckpoint) {
            return "smart-contracts/domains/finality/StreamStaticSelectionCheckpoint.sol:StreamStaticSelectionCheckpoint";
        }
        if (kind == Kind.StreamStaticContentCheckpoint) {
            return "smart-contracts/domains/finality/StreamStaticContentCheckpoint.sol:StreamStaticContentCheckpoint";
        }
        if (kind == Kind.StreamStaticOutputManifest) {
            return "smart-contracts/domains/finality/StreamStaticOutputManifest.sol:StreamStaticOutputManifest";
        }
        if (kind == Kind.StreamScopedSnapshotPublication) {
            return "smart-contracts/domains/metadata/StreamScopedSnapshotPublication.sol:StreamScopedSnapshotPublication";
        }
        if (kind == Kind.StreamScopedReferencePublication) {
            return "smart-contracts/domains/preservation/StreamScopedReferencePublication.sol:StreamScopedReferencePublication";
        }
        if (kind == Kind.StreamScopedRenderCriticalInventory) {
            return "smart-contracts/domains/preservation/StreamScopedRenderCriticalInventory.sol:StreamScopedRenderCriticalInventory";
        }
        if (kind == Kind.StreamScopedBundleArchiveCoverage) {
            return "smart-contracts/domains/preservation/StreamScopedBundleArchiveCoverage.sol:StreamScopedBundleArchiveCoverage";
        }
        if (kind == Kind.StreamFinalityEntropyPolicySourceFactoryV2) {
            return "smart-contracts/domains/finality/StreamFinalityEntropyPolicySourceFactoryV2.sol:StreamFinalityEntropyPolicySourceFactoryV2";
        }
        if (kind == Kind.StreamFinalityScopedEntropyPolicySourceFactoryV2) {
            return "smart-contracts/domains/finality/StreamFinalityScopedEntropyPolicySourceFactoryV2.sol:StreamFinalityScopedEntropyPolicySourceFactoryV2";
        }
        if (kind == Kind.StreamPolicyPublicationFactoryV2) {
            return "smart-contracts/domains/finality/StreamPolicyPublicationFactoryV2.sol:StreamPolicyPublicationFactoryV2";
        }
        if (kind == Kind.StreamScopedPolicyPublicationFactoryV2) {
            return "smart-contracts/domains/finality/StreamScopedPolicyPublicationFactoryV2.sol:StreamScopedPolicyPublicationFactoryV2";
        }
        if (kind == Kind.StreamFinalityFullPolicyEvidenceProviderV2) {
            return "smart-contracts/domains/finality/StreamFinalityFullPolicyEvidenceProviderV2.sol:StreamFinalityFullPolicyEvidenceProviderV2";
        }
        if (kind == Kind.StreamFinalityFullPolicyDiscoveryV2) {
            return "smart-contracts/domains/finality/StreamFinalityFullPolicyDiscoveryV2.sol:StreamFinalityFullPolicyDiscoveryV2";
        }
        if (kind == Kind.StreamCurrentAuthorityRightsRecordSelection) {
            return "smart-contracts/domains/metadata/StreamCurrentAuthorityRightsRecordSelection.sol:StreamCurrentAuthorityRightsRecordSelection";
        }
        revert("unknown original product artifact");
    }

    function creation(Kind kind) public view returns (bytes memory code) {
        NativeAssemblyArtifactVm artifactVm =
            NativeAssemblyArtifactVm(address(uint160(uint256(keccak256("hevm cheat code")))));
        code = artifactVm.getCode(artifact(kind));
        require(code.length != 0, "missing original production creation artifact");
    }
}

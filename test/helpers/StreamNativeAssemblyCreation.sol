// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { StreamCurrentGraphCreation } from "../../script/current/StreamCurrentGraphCreation.sol";
import {
    StreamCurrentAuthorityGraphCreation
} from "../../script/current/StreamCurrentAuthorityGraphCreation.sol";

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

    /// @dev Exactly the original graph template subset; other original enum values still refuse.
    function graphArtifact(StreamCurrentGraphCreation.Kind kind)
        public
        pure
        returns (string memory)
    {
        if (kind == StreamCurrentGraphCreation.Kind.StreamArtistIdentityAuthority) {
            return artifact(Kind.StreamArtistIdentityAuthority);
        }
        if (kind == StreamCurrentGraphCreation.Kind.StreamArtistOnboardingCoordinator) {
            return artifact(Kind.StreamArtistOnboardingCoordinator);
        }
        if (kind == StreamCurrentGraphCreation.Kind.StreamArtistOnboardingRegistry) {
            return artifact(Kind.StreamArtistOnboardingRegistry);
        }
        if (kind == StreamCurrentGraphCreation.Kind.StreamArtworkFinalityRegistry) {
            return artifact(Kind.StreamArtworkFinalityRegistry);
        }
        if (kind == StreamCurrentGraphCreation.Kind.StreamArweaveObjectCheckpointVerifier) {
            return artifact(Kind.StreamArweaveObjectCheckpointVerifier);
        }
        if (kind == StreamCurrentGraphCreation.Kind.StreamBundleArchiveCoverage) {
            return artifact(Kind.StreamBundleArchiveCoverage);
        }
        if (kind == StreamCurrentGraphCreation.Kind.StreamCollectionMetadataV1) {
            return artifact(Kind.StreamCollectionMetadataV1);
        }
        if (kind == StreamCurrentGraphCreation.Kind.StreamCollectionSnapshots) {
            return artifact(Kind.StreamCollectionSnapshots);
        }
        if (kind == StreamCurrentGraphCreation.Kind.StreamCollectionTokenInventory) {
            return artifact(Kind.StreamCollectionTokenInventory);
        }
        if (kind == StreamCurrentGraphCreation.Kind.StreamConservationRecordSelection) {
            return artifact(Kind.StreamConservationRecordSelection);
        }
        if (kind == StreamCurrentGraphCreation.Kind.StreamContentLeafManifest) {
            return artifact(Kind.StreamContentLeafManifest);
        }
        if (kind == StreamCurrentGraphCreation.Kind.StreamCoreFinalityAdapter) {
            return artifact(Kind.StreamCoreFinalityAdapter);
        }
        if (kind == StreamCurrentGraphCreation.Kind.StreamExternalArtifactCoverage) {
            return artifact(Kind.StreamExternalArtifactCoverage);
        }
        if (kind == StreamCurrentGraphCreation.Kind.StreamFinalityArtifactCoverage) {
            return artifact(Kind.StreamFinalityArtifactCoverage);
        }
        if (kind == StreamCurrentGraphCreation.Kind.StreamFinalityCoordinatorInventory) {
            return artifact(Kind.StreamFinalityCoordinatorInventory);
        }
        if (kind == StreamCurrentGraphCreation.Kind.StreamFinalityCurrentDiscovery) {
            return artifact(Kind.StreamFinalityCurrentDiscovery);
        }
        if (kind == StreamCurrentGraphCreation.Kind.StreamFinalityEntropySourceFactory) {
            return artifact(Kind.StreamFinalityEntropySourceFactory);
        }
        if (kind == StreamCurrentGraphCreation.Kind.StreamFinalityNativeEvidenceProvider) {
            return artifact(Kind.StreamFinalityNativeEvidenceProvider);
        }
        if (kind == StreamCurrentGraphCreation.Kind.StreamFinalityScopeMembership) {
            return artifact(Kind.StreamFinalityScopeMembership);
        }
        if (kind == StreamCurrentGraphCreation.Kind.StreamFinalityServingHostAdapter) {
            return artifact(Kind.StreamFinalityServingHostAdapter);
        }
        if (kind == StreamCurrentGraphCreation.Kind.StreamOnchainContentCheckpoint) {
            return artifact(Kind.StreamOnchainContentCheckpoint);
        }
        if (kind == StreamCurrentGraphCreation.Kind.StreamReferenceRenderPublication) {
            return artifact(Kind.StreamReferenceRenderPublication);
        }
        if (kind == StreamCurrentGraphCreation.Kind.StreamRenderCriticalInventory) {
            return artifact(Kind.StreamRenderCriticalInventory);
        }
        if (kind == StreamCurrentGraphCreation.Kind.StreamRightsRecordSelection) {
            return artifact(Kind.StreamRightsRecordSelection);
        }
        if (kind == StreamCurrentGraphCreation.Kind.StreamSchemaRegistry) {
            return artifact(Kind.StreamSchemaRegistry);
        }
        if (kind == StreamCurrentGraphCreation.Kind.StreamWorkRecordSelection) {
            return artifact(Kind.StreamWorkRecordSelection);
        }
        if (kind == StreamCurrentGraphCreation.Kind.StreamStaticSelectionCheckpoint) {
            return artifact(Kind.StreamStaticSelectionCheckpoint);
        }
        if (kind == StreamCurrentGraphCreation.Kind.StreamStaticContentCheckpoint) {
            return artifact(Kind.StreamStaticContentCheckpoint);
        }
        if (kind == StreamCurrentGraphCreation.Kind.StreamStaticOutputManifest) {
            return artifact(Kind.StreamStaticOutputManifest);
        }
        if (kind == StreamCurrentGraphCreation.Kind.StreamScopedSnapshotPublication) {
            return artifact(Kind.StreamScopedSnapshotPublication);
        }
        if (kind == StreamCurrentGraphCreation.Kind.StreamScopedReferencePublication) {
            return artifact(Kind.StreamScopedReferencePublication);
        }
        if (kind == StreamCurrentGraphCreation.Kind.StreamScopedRenderCriticalInventory) {
            return artifact(Kind.StreamScopedRenderCriticalInventory);
        }
        if (kind == StreamCurrentGraphCreation.Kind.StreamScopedBundleArchiveCoverage) {
            return artifact(Kind.StreamScopedBundleArchiveCoverage);
        }
        if (kind == StreamCurrentGraphCreation.Kind.StreamFinalityEntropyPolicySourceFactoryV2) {
            return artifact(Kind.StreamFinalityEntropyPolicySourceFactoryV2);
        }
        if (
            kind == StreamCurrentGraphCreation.Kind.StreamFinalityScopedEntropyPolicySourceFactoryV2
        ) {
            return artifact(Kind.StreamFinalityScopedEntropyPolicySourceFactoryV2);
        }
        if (kind == StreamCurrentGraphCreation.Kind.StreamPolicyPublicationFactoryV2) {
            return artifact(Kind.StreamPolicyPublicationFactoryV2);
        }
        if (kind == StreamCurrentGraphCreation.Kind.StreamScopedPolicyPublicationFactoryV2) {
            return artifact(Kind.StreamScopedPolicyPublicationFactoryV2);
        }
        if (kind == StreamCurrentGraphCreation.Kind.StreamFinalityFullPolicyEvidenceProviderV2) {
            return artifact(Kind.StreamFinalityFullPolicyEvidenceProviderV2);
        }
        if (kind == StreamCurrentGraphCreation.Kind.StreamFinalityFullPolicyDiscoveryV2) {
            return artifact(Kind.StreamFinalityFullPolicyDiscoveryV2);
        }
        revert("unknown original product template");
    }

    function authorityArtifact(StreamCurrentAuthorityGraphCreation.Kind kind)
        public
        pure
        returns (string memory)
    {
        if (
            kind
                == StreamCurrentAuthorityGraphCreation.Kind
                .StreamCurrentAuthorityBundleArchiveCoverage
        ) {
            return "smart-contracts/domains/preservation/StreamCurrentAuthorityBundleArchiveCoverage.sol:StreamCurrentAuthorityBundleArchiveCoverage";
        }
        if (
            kind
                == StreamCurrentAuthorityGraphCreation.Kind
                .StreamCurrentAuthorityNativeEvidenceProvider
        ) {
            return "smart-contracts/domains/finality/StreamCurrentAuthorityNativeEvidenceProvider.sol:StreamCurrentAuthorityNativeEvidenceProvider";
        }
        if (kind == StreamCurrentAuthorityGraphCreation.Kind.StreamArtistArchiveOriginReads) {
            return "smart-contracts/domains/preservation/StreamArtistArchiveOriginReads.sol:StreamArtistArchiveOriginReads";
        }
        if (kind == StreamCurrentAuthorityGraphCreation.Kind.StreamArtistCurrentAuthorityResolver) {
            return "smart-contracts/domains/preservation/StreamArtistCurrentAuthorityResolver.sol:StreamArtistCurrentAuthorityResolver";
        }
        if (kind == StreamCurrentAuthorityGraphCreation.Kind.StreamLineageArtworkFinalityRegistry) {
            return "smart-contracts/domains/finality/StreamLineageArtworkFinalityRegistry.sol:StreamLineageArtworkFinalityRegistry";
        }
        if (kind == StreamCurrentAuthorityGraphCreation.Kind.StreamFinalityLineageCurrentDiscovery)
        {
            return "smart-contracts/domains/finality/StreamFinalityLineageCurrentDiscovery.sol:StreamFinalityLineageCurrentDiscovery";
        }
        if (
            kind
                == StreamCurrentAuthorityGraphCreation.Kind
                .StreamCurrentAuthorityWorkRecordSelection
        ) {
            return "smart-contracts/domains/metadata/StreamCurrentAuthorityWorkRecordSelection.sol:StreamCurrentAuthorityWorkRecordSelection";
        }
        if (
            kind
                == StreamCurrentAuthorityGraphCreation.Kind
                .StreamCurrentAuthorityConservationRecordSelection
        ) {
            return "smart-contracts/domains/metadata/StreamCurrentAuthorityConservationRecordSelection.sol:StreamCurrentAuthorityConservationRecordSelection";
        }
        if (
            kind
                == StreamCurrentAuthorityGraphCreation.Kind
                .StreamCurrentAuthorityRenderCriticalInventory
        ) {
            return "smart-contracts/domains/preservation/StreamCurrentAuthorityRenderCriticalInventory.sol:StreamCurrentAuthorityRenderCriticalInventory";
        }
        if (
            kind
                == StreamCurrentAuthorityGraphCreation.Kind
                .StreamCurrentAuthorityRightsRecordSelection
        ) {
            return "smart-contracts/domains/metadata/StreamCurrentAuthorityRightsRecordSelection.sol:StreamCurrentAuthorityRightsRecordSelection";
        }
        revert("unknown authority product template");
    }

    function scopedPolicyArtifact(string memory name_) public pure returns (string memory) {
        bytes32 key = keccak256(bytes(name_));
        if (key == keccak256("StreamCurrentAuthorityPreservationPolicyPublicationFactoryV1")) {
            return "smart-contracts/domains/finality/StreamCurrentAuthorityPreservationPolicyPublicationFactoryV1.sol:StreamCurrentAuthorityPreservationPolicyPublicationFactoryV1";
        }
        if (key == keccak256("StreamCurrentAuthorityScopedPreservationPolicyPublicationFactoryV1"))
        {
            return "smart-contracts/domains/finality/StreamCurrentAuthorityScopedPreservationPolicyPublicationFactoryV1.sol:StreamCurrentAuthorityScopedPreservationPolicyPublicationFactoryV1";
        }
        if (key == keccak256("StreamCurrentAuthorityFullPreservationPolicyEvidenceProviderV1")) {
            return "smart-contracts/domains/finality/StreamCurrentAuthorityFullPreservationPolicyEvidenceProviderV1.sol:StreamCurrentAuthorityFullPreservationPolicyEvidenceProviderV1";
        }
        if (key == keccak256("StreamCurrentAuthorityFullPreservationPolicyDiscoveryV1")) {
            return "smart-contracts/domains/finality/StreamCurrentAuthorityFullPreservationPolicyDiscoveryV1.sol:StreamCurrentAuthorityFullPreservationPolicyDiscoveryV1";
        }
        if (key == keccak256("StreamStaticSelectionCheckpoint")) {
            return "smart-contracts/domains/finality/StreamStaticSelectionCheckpoint.sol:StreamStaticSelectionCheckpoint";
        }
        if (key == keccak256("StreamStaticContentCheckpoint")) {
            return "smart-contracts/domains/finality/StreamStaticContentCheckpoint.sol:StreamStaticContentCheckpoint";
        }
        if (key == keccak256("StreamStaticOutputManifest")) {
            return "smart-contracts/domains/finality/StreamStaticOutputManifest.sol:StreamStaticOutputManifest";
        }
        if (key == keccak256("StreamScopedSnapshotPublication")) {
            return "smart-contracts/domains/metadata/StreamScopedSnapshotPublication.sol:StreamScopedSnapshotPublication";
        }
        if (key == keccak256("StreamScopedReferencePublication")) {
            return "smart-contracts/domains/preservation/StreamScopedReferencePublication.sol:StreamScopedReferencePublication";
        }
        if (key == keccak256("StreamFinalityEntropyPolicySourceFactoryV2")) {
            return "smart-contracts/domains/finality/StreamFinalityEntropyPolicySourceFactoryV2.sol:StreamFinalityEntropyPolicySourceFactoryV2";
        }
        if (key == keccak256("StreamFinalityScopedEntropyPolicySourceFactoryV2")) {
            return "smart-contracts/domains/finality/StreamFinalityScopedEntropyPolicySourceFactoryV2.sol:StreamFinalityScopedEntropyPolicySourceFactoryV2";
        }
        if (key == keccak256("StreamTerminalEntropyReadiness")) {
            return "smart-contracts/domains/finality/StreamTerminalEntropyReadiness.sol:StreamTerminalEntropyReadiness";
        }
        if (key == keccak256("StreamPolicyContentCheckpointV2")) {
            return "smart-contracts/domains/finality/StreamPolicyContentCheckpointV2.sol:StreamPolicyContentCheckpointV2";
        }
        if (key == keccak256("StreamPolicyOutputManifestV2")) {
            return "smart-contracts/domains/finality/StreamPolicyOutputManifestV2.sol:StreamPolicyOutputManifestV2";
        }
        if (key == keccak256("StreamPolicySnapshotPublicationV2")) {
            return "smart-contracts/domains/metadata/StreamPolicySnapshotPublicationV2.sol:StreamPolicySnapshotPublicationV2";
        }
        if (key == keccak256("StreamPolicyReferencePublicationV2")) {
            return "smart-contracts/domains/preservation/StreamPolicyReferencePublicationV2.sol:StreamPolicyReferencePublicationV2";
        }
        if (key == keccak256("StreamCurrentAuthorityScopedRenderCriticalInventory")) {
            return "smart-contracts/domains/preservation/StreamCurrentAuthorityScopedRenderCriticalInventory.sol:StreamCurrentAuthorityScopedRenderCriticalInventory";
        }
        if (key == keccak256("StreamCurrentAuthorityPolicyRenderCriticalInventoryV2")) {
            return "smart-contracts/domains/preservation/StreamCurrentAuthorityPolicyRenderCriticalInventoryV2.sol:StreamCurrentAuthorityPolicyRenderCriticalInventoryV2";
        }
        if (key == keccak256("StreamCurrentAuthorityScopedBundleArchiveCoverage")) {
            return "smart-contracts/domains/preservation/StreamCurrentAuthorityScopedBundleArchiveCoverage.sol:StreamCurrentAuthorityScopedBundleArchiveCoverage";
        }
        if (key == keccak256("StreamCurrentAuthorityBundleArchiveCoverage")) {
            return "smart-contracts/domains/preservation/StreamCurrentAuthorityBundleArchiveCoverage.sol:StreamCurrentAuthorityBundleArchiveCoverage";
        }
        if (key == keccak256("StreamCurrentAuthorityScopedPolicyPublicationFactoryV2")) {
            return "smart-contracts/domains/finality/StreamCurrentAuthorityScopedPolicyPublicationFactoryV2.sol:StreamCurrentAuthorityScopedPolicyPublicationFactoryV2";
        }
        if (key == keccak256("StreamCurrentAuthorityDeferredScopedPolicyEvidenceProviderV2")) {
            return "smart-contracts/domains/finality/StreamCurrentAuthorityDeferredScopedPolicyEvidenceProviderV2.sol:StreamCurrentAuthorityDeferredScopedPolicyEvidenceProviderV2";
        }
        if (key == keccak256("StreamFinalityLineageDeferredScopedPolicyDiscoveryV2")) {
            return "smart-contracts/domains/finality/StreamFinalityLineageDeferredScopedPolicyDiscoveryV2.sol:StreamFinalityLineageDeferredScopedPolicyDiscoveryV2";
        }
        revert("unknown original scoped-policy product");
    }

    function graphCreation(StreamCurrentGraphCreation.Kind kind)
        public
        view
        returns (bytes memory code)
    {
        return _creation(graphArtifact(kind));
    }

    function authorityCreation(StreamCurrentAuthorityGraphCreation.Kind kind)
        public
        view
        returns (bytes memory code)
    {
        return _creation(authorityArtifact(kind));
    }

    function scopedPolicyCreation(string memory name_) public view returns (bytes memory code) {
        return _creation(scopedPolicyArtifact(name_));
    }

    function creation(Kind kind) public view returns (bytes memory code) {
        return _creation(artifact(kind));
    }

    function _creation(string memory artifact_) private view returns (bytes memory code) {
        NativeAssemblyArtifactVm artifactVm =
            NativeAssemblyArtifactVm(address(uint160(uint256(keccak256("hevm cheat code")))));
        code = artifactVm.getCode(artifact_);
        require(code.length != 0, "missing original production creation artifact");
    }
}

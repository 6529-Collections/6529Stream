// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamStaticSelectionCheckpoint
} from "../../smart-contracts/domains/finality/StreamStaticSelectionCheckpoint.sol";
import {
    StreamStaticContentCheckpoint
} from "../../smart-contracts/domains/finality/StreamStaticContentCheckpoint.sol";
import {
    StreamStaticOutputManifest
} from "../../smart-contracts/domains/finality/StreamStaticOutputManifest.sol";
import {
    StreamScopedSnapshotPublication
} from "../../smart-contracts/domains/metadata/StreamScopedSnapshotPublication.sol";
import {
    StreamScopedReferencePublication
} from "../../smart-contracts/domains/preservation/StreamScopedReferencePublication.sol";
import {
    StreamScopedRenderCriticalInventory
} from "../../smart-contracts/domains/preservation/StreamScopedRenderCriticalInventory.sol";
import {
    StreamScopedBundleArchiveCoverage
} from "../../smart-contracts/domains/preservation/StreamScopedBundleArchiveCoverage.sol";
import {
    StreamFinalityEntropyPolicySourceFactoryV2
} from "../../smart-contracts/domains/finality/StreamFinalityEntropyPolicySourceFactoryV2.sol";
import {
    StreamFinalityScopedEntropyPolicySourceFactoryV2
} from "../../smart-contracts/domains/finality/StreamFinalityScopedEntropyPolicySourceFactoryV2.sol";
import {
    StreamPolicyPublicationFactoryV2
} from "../../smart-contracts/domains/finality/StreamPolicyPublicationFactoryV2.sol";
import {
    StreamScopedPolicyPublicationFactoryV2
} from "../../smart-contracts/domains/finality/StreamScopedPolicyPublicationFactoryV2.sol";
import {
    StreamFinalityFullPolicyEvidenceProviderV2
} from "../../smart-contracts/domains/finality/StreamFinalityFullPolicyEvidenceProviderV2.sol";
import {
    StreamFinalityFullPolicyDiscoveryV2
} from "../../smart-contracts/domains/finality/StreamFinalityFullPolicyDiscoveryV2.sol";

import {
    StreamArchivalCoverage
} from "../../smart-contracts/domains/preservation/StreamArchivalCoverage.sol";
import {
    StreamArtistAcceptanceLifecycle
} from "../../smart-contracts/domains/artist/StreamArtistAcceptanceLifecycle.sol";
import {
    StreamArtistArchiveV2
} from "../../smart-contracts/domains/artist/StreamArtistArchiveV2.sol";
import {
    StreamArtistAttributionLifecycle
} from "../../smart-contracts/domains/artist/StreamArtistAttributionLifecycle.sol";
import {
    StreamArtistBindingLifecycle
} from "../../smart-contracts/domains/artist/StreamArtistBindingLifecycle.sol";
import {
    StreamArtistCollaboratorLifecycle
} from "../../smart-contracts/domains/artist/StreamArtistCollaboratorLifecycle.sol";
import {
    StreamArtistConsentFinalityLifecycle
} from "../../smart-contracts/domains/artist/StreamArtistConsentFinalityLifecycle.sol";
import {
    StreamArtistIdentityAuthority
} from "../../smart-contracts/domains/artist/StreamArtistIdentityAuthority.sol";
import {
    StreamArtistOnboardingCoordinator
} from "../../smart-contracts/domains/artist/StreamArtistOnboardingCoordinator.sol";
import {
    StreamArtistOnboardingRegistry
} from "../../smart-contracts/domains/artist/StreamArtistOnboardingRegistry.sol";
import {
    StreamArtistPayoutLifecycle
} from "../../smart-contracts/domains/artist/StreamArtistPayoutLifecycle.sol";
import {
    StreamArtistRegistryValidatorBase
} from "../../smart-contracts/domains/artist/StreamArtistRegistryValidatorBase.sol";
import {
    StreamArtworkFinalityRegistry
} from "../../smart-contracts/domains/finality/StreamArtworkFinalityRegistry.sol";
import {
    StreamArweaveCheckpointVerifier
} from "../../smart-contracts/domains/preservation/StreamArweaveCheckpointVerifier.sol";
import {
    StreamArweaveObjectCheckpointVerifier
} from "../../smart-contracts/domains/preservation/StreamArweaveObjectCheckpointVerifier.sol";
import {
    StreamAssetPolicyRegistry
} from "../../smart-contracts/domains/revenue/StreamAssetPolicyRegistry.sol";
import {
    StreamBundleArchiveCoverage
} from "../../smart-contracts/domains/preservation/StreamBundleArchiveCoverage.sol";
import {
    StreamCollectionMetadataV1
} from "../../smart-contracts/domains/metadata/StreamCollectionMetadataV1.sol";
import {
    StreamCollectionSnapshots
} from "../../smart-contracts/domains/metadata/StreamCollectionSnapshots.sol";
import {
    StreamCollectionTokenInventory
} from "../../smart-contracts/domains/finality/StreamCollectionTokenInventory.sol";
import {
    StreamConservationRecordSelection
} from "../../smart-contracts/domains/metadata/StreamConservationRecordSelection.sol";
import {
    StreamContentLeafManifest
} from "../../smart-contracts/domains/finality/StreamContentLeafManifest.sol";
import { StreamCore } from "../../smart-contracts/core/StreamCore.sol";
import {
    StreamCoreFinalityAdapter
} from "../../smart-contracts/domains/finality/StreamCoreFinalityAdapter.sol";
import {
    StreamEntropyCoordinator
} from "../../smart-contracts/domains/entropy/StreamEntropyCoordinator.sol";
import {
    StreamExternalArtifactCoverage
} from "../../smart-contracts/domains/preservation/StreamExternalArtifactCoverage.sol";
import {
    StreamFinalityArtifactCoverage
} from "../../smart-contracts/domains/preservation/StreamFinalityArtifactCoverage.sol";
import {
    StreamFinalityCoordinatorInventory
} from "../../smart-contracts/domains/finality/StreamFinalityCoordinatorInventory.sol";
import {
    StreamFinalityCurrentDiscovery
} from "../../smart-contracts/domains/finality/StreamFinalityCurrentDiscovery.sol";
import {
    StreamFinalityEntropySourceFactory
} from "../../smart-contracts/domains/finality/StreamFinalityEntropySourceFactory.sol";
import {
    StreamFinalityNativeEvidenceProvider
} from "../../smart-contracts/domains/finality/StreamFinalityNativeEvidenceProvider.sol";
import {
    StreamFinalityScopeMembership
} from "../../smart-contracts/domains/finality/StreamFinalityScopeMembership.sol";
import {
    StreamFinalityServingHostAdapter
} from "../../smart-contracts/domains/finality/StreamFinalityServingHostAdapter.sol";
import {
    StreamFixedPriceSaleAdapter
} from "../../smart-contracts/domains/mint/StreamFixedPriceSaleAdapter.sol";
import {
    StreamGovernanceExecutor
} from "../../smart-contracts/domains/governance/StreamGovernanceExecutor.sol";
import {
    StreamMetadataRouter
} from "../../smart-contracts/domains/metadata/StreamMetadataRouter.sol";
import { StreamMintLedger } from "../../smart-contracts/domains/mint/StreamMintLedger.sol";
import { StreamMintManager } from "../../smart-contracts/domains/mint/StreamMintManager.sol";
import {
    StreamModuleRegistry
} from "../../smart-contracts/domains/modules/StreamModuleRegistry.sol";
import {
    StreamOnchainContentCheckpoint
} from "../../smart-contracts/domains/finality/StreamOnchainContentCheckpoint.sol";
import {
    StreamReferenceRenderPublication
} from "../../smart-contracts/domains/preservation/StreamReferenceRenderPublication.sol";
import {
    StreamRenderCriticalInventory
} from "../../smart-contracts/domains/preservation/StreamRenderCriticalInventory.sol";
import { StreamRevenueEscrow } from "../../smart-contracts/domains/revenue/StreamRevenueEscrow.sol";
import {
    StreamRevenueResolver
} from "../../smart-contracts/domains/revenue/StreamRevenueResolver.sol";
import {
    StreamRightsRecordSelection
} from "../../smart-contracts/domains/metadata/StreamRightsRecordSelection.sol";
import {
    StreamCurrentAuthorityRightsRecordSelection
} from "../../smart-contracts/domains/metadata/StreamCurrentAuthorityRightsRecordSelection.sol";
import {
    StreamRoleRegistry
} from "../../smart-contracts/domains/governance/StreamRoleRegistry.sol";
import {
    StreamRoyaltyResolver
} from "../../smart-contracts/domains/revenue/StreamRoyaltyResolver.sol";
import {
    StreamSchemaRegistry
} from "../../smart-contracts/domains/metadata/StreamSchemaRegistry.sol";
import { StreamSplitFactory } from "../../smart-contracts/domains/revenue/StreamSplitFactory.sol";
import {
    StreamSystemManifest
} from "../../smart-contracts/domains/governance/StreamSystemManifest.sol";
import {
    StreamWorkRecordSelection
} from "../../smart-contracts/domains/metadata/StreamWorkRecordSelection.sol";

/// @notice Test-only cache for unchanged literal, linked production creation templates.
/// @dev This large library is part of the elevated test harness, not a deployable protocol
/// product or deployment recommendation. Original products still undergo real zero-value
/// CREATE with exact constructor ABI, their own size limits and complete runtime checks.
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

    function creation(Kind kind) public pure returns (bytes memory) {
        if (kind == Kind.StreamCurrentAuthorityRightsRecordSelection) {
            return type(StreamCurrentAuthorityRightsRecordSelection).creationCode;
        }
        if (kind == Kind.StreamArchivalCoverage) return type(StreamArchivalCoverage).creationCode;
        if (kind == Kind.StreamArtistAcceptanceLifecycle) {
            return type(StreamArtistAcceptanceLifecycle).creationCode;
        }
        if (kind == Kind.StreamArtistArchiveV2) return type(StreamArtistArchiveV2).creationCode;
        if (kind == Kind.StreamArtistAttributionLifecycle) {
            return type(StreamArtistAttributionLifecycle).creationCode;
        }
        if (kind == Kind.StreamArtistBindingLifecycle) {
            return type(StreamArtistBindingLifecycle).creationCode;
        }
        if (kind == Kind.StreamArtistCollaboratorLifecycle) {
            return type(StreamArtistCollaboratorLifecycle).creationCode;
        }
        if (kind == Kind.StreamArtistConsentFinalityLifecycle) {
            return type(StreamArtistConsentFinalityLifecycle).creationCode;
        }
        if (kind == Kind.StreamArtistIdentityAuthority) {
            return type(StreamArtistIdentityAuthority).creationCode;
        }
        if (kind == Kind.StreamArtistOnboardingCoordinator) {
            return type(StreamArtistOnboardingCoordinator).creationCode;
        }
        if (kind == Kind.StreamArtistOnboardingRegistry) {
            return type(StreamArtistOnboardingRegistry).creationCode;
        }
        if (kind == Kind.StreamArtistPayoutLifecycle) {
            return type(StreamArtistPayoutLifecycle).creationCode;
        }
        if (kind == Kind.StreamArtistRegistryValidatorBase) {
            return type(StreamArtistRegistryValidatorBase).creationCode;
        }
        if (kind == Kind.StreamArtworkFinalityRegistry) {
            return type(StreamArtworkFinalityRegistry).creationCode;
        }
        if (kind == Kind.StreamArweaveCheckpointVerifier) {
            return type(StreamArweaveCheckpointVerifier).creationCode;
        }
        if (kind == Kind.StreamArweaveObjectCheckpointVerifier) {
            return type(StreamArweaveObjectCheckpointVerifier).creationCode;
        }
        if (kind == Kind.StreamAssetPolicyRegistry) {
            return type(StreamAssetPolicyRegistry).creationCode;
        }
        if (kind == Kind.StreamBundleArchiveCoverage) {
            return type(StreamBundleArchiveCoverage).creationCode;
        }
        if (kind == Kind.StreamCollectionMetadataV1) {
            return type(StreamCollectionMetadataV1).creationCode;
        }
        if (kind == Kind.StreamCollectionSnapshots) {
            return type(StreamCollectionSnapshots).creationCode;
        }
        if (kind == Kind.StreamCollectionTokenInventory) {
            return type(StreamCollectionTokenInventory).creationCode;
        }
        if (kind == Kind.StreamConservationRecordSelection) {
            return type(StreamConservationRecordSelection).creationCode;
        }
        if (kind == Kind.StreamContentLeafManifest) {
            return type(StreamContentLeafManifest).creationCode;
        }
        if (kind == Kind.StreamCore) return type(StreamCore).creationCode;
        if (kind == Kind.StreamCoreFinalityAdapter) {
            return type(StreamCoreFinalityAdapter).creationCode;
        }
        if (kind == Kind.StreamEntropyCoordinator) {
            return type(StreamEntropyCoordinator).creationCode;
        }
        if (kind == Kind.StreamExternalArtifactCoverage) {
            return type(StreamExternalArtifactCoverage).creationCode;
        }
        if (kind == Kind.StreamFinalityArtifactCoverage) {
            return type(StreamFinalityArtifactCoverage).creationCode;
        }
        if (kind == Kind.StreamFinalityCoordinatorInventory) {
            return type(StreamFinalityCoordinatorInventory).creationCode;
        }
        if (kind == Kind.StreamFinalityCurrentDiscovery) {
            return type(StreamFinalityCurrentDiscovery).creationCode;
        }
        if (kind == Kind.StreamFinalityEntropySourceFactory) {
            return type(StreamFinalityEntropySourceFactory).creationCode;
        }
        if (kind == Kind.StreamFinalityNativeEvidenceProvider) {
            return type(StreamFinalityNativeEvidenceProvider).creationCode;
        }
        if (kind == Kind.StreamFinalityScopeMembership) {
            return type(StreamFinalityScopeMembership).creationCode;
        }
        if (kind == Kind.StreamFinalityServingHostAdapter) {
            return type(StreamFinalityServingHostAdapter).creationCode;
        }
        if (kind == Kind.StreamFixedPriceSaleAdapter) {
            return type(StreamFixedPriceSaleAdapter).creationCode;
        }
        if (kind == Kind.StreamGovernanceExecutor) {
            return type(StreamGovernanceExecutor).creationCode;
        }
        if (kind == Kind.StreamMetadataRouter) return type(StreamMetadataRouter).creationCode;
        if (kind == Kind.StreamMintLedger) return type(StreamMintLedger).creationCode;
        if (kind == Kind.StreamMintManager) return type(StreamMintManager).creationCode;
        if (kind == Kind.StreamModuleRegistry) return type(StreamModuleRegistry).creationCode;
        if (kind == Kind.StreamOnchainContentCheckpoint) {
            return type(StreamOnchainContentCheckpoint).creationCode;
        }
        if (kind == Kind.StreamReferenceRenderPublication) {
            return type(StreamReferenceRenderPublication).creationCode;
        }
        if (kind == Kind.StreamRenderCriticalInventory) {
            return type(StreamRenderCriticalInventory).creationCode;
        }
        if (kind == Kind.StreamRevenueEscrow) return type(StreamRevenueEscrow).creationCode;
        if (kind == Kind.StreamRevenueResolver) return type(StreamRevenueResolver).creationCode;
        if (kind == Kind.StreamRightsRecordSelection) {
            return type(StreamRightsRecordSelection).creationCode;
        }
        if (kind == Kind.StreamRoleRegistry) return type(StreamRoleRegistry).creationCode;
        if (kind == Kind.StreamRoyaltyResolver) return type(StreamRoyaltyResolver).creationCode;
        if (kind == Kind.StreamSchemaRegistry) return type(StreamSchemaRegistry).creationCode;
        if (kind == Kind.StreamSplitFactory) return type(StreamSplitFactory).creationCode;
        if (kind == Kind.StreamSystemManifest) return type(StreamSystemManifest).creationCode;
        if (kind == Kind.StreamWorkRecordSelection) {
            return type(StreamWorkRecordSelection).creationCode;
        }
        if (kind == Kind.StreamStaticSelectionCheckpoint) {
            return type(StreamStaticSelectionCheckpoint).creationCode;
        }
        if (kind == Kind.StreamStaticContentCheckpoint) {
            return type(StreamStaticContentCheckpoint).creationCode;
        }
        if (kind == Kind.StreamStaticOutputManifest) {
            return type(StreamStaticOutputManifest).creationCode;
        }
        if (kind == Kind.StreamScopedSnapshotPublication) {
            return type(StreamScopedSnapshotPublication).creationCode;
        }
        if (kind == Kind.StreamScopedReferencePublication) {
            return type(StreamScopedReferencePublication).creationCode;
        }
        if (kind == Kind.StreamScopedRenderCriticalInventory) {
            return type(StreamScopedRenderCriticalInventory).creationCode;
        }
        if (kind == Kind.StreamScopedBundleArchiveCoverage) {
            return type(StreamScopedBundleArchiveCoverage).creationCode;
        }
        if (kind == Kind.StreamFinalityEntropyPolicySourceFactoryV2) {
            return type(StreamFinalityEntropyPolicySourceFactoryV2).creationCode;
        }
        if (kind == Kind.StreamFinalityScopedEntropyPolicySourceFactoryV2) {
            return type(StreamFinalityScopedEntropyPolicySourceFactoryV2).creationCode;
        }
        if (kind == Kind.StreamPolicyPublicationFactoryV2) {
            return type(StreamPolicyPublicationFactoryV2).creationCode;
        }
        if (kind == Kind.StreamScopedPolicyPublicationFactoryV2) {
            return type(StreamScopedPolicyPublicationFactoryV2).creationCode;
        }
        if (kind == Kind.StreamFinalityFullPolicyEvidenceProviderV2) {
            return type(StreamFinalityFullPolicyEvidenceProviderV2).creationCode;
        }
        if (kind == Kind.StreamFinalityFullPolicyDiscoveryV2) {
            return type(StreamFinalityFullPolicyDiscoveryV2).creationCode;
        }
        revert("unknown original product template");
    }
}

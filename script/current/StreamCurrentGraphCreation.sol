// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

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

/// @notice Internal literal linked creation templates for current deployment scripts.
/// @dev The simulation host embeds these bytes; this library is never broadcast. Products retain
/// their original zero-value CREATE caller, constructor ABI, size and complete runtime checks.
library StreamCurrentGraphCreation {
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
        StreamWorkRecordSelection
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
        revert("unknown original product template");
    }

    function creation(Kind kind) internal pure returns (bytes memory) {
        if (kind == Kind.StreamArtistIdentityAuthority) {
            return type(StreamArtistIdentityAuthority).creationCode;
        }
        if (kind == Kind.StreamArtistOnboardingCoordinator) {
            return type(StreamArtistOnboardingCoordinator).creationCode;
        }
        if (kind == Kind.StreamArtistOnboardingRegistry) {
            return type(StreamArtistOnboardingRegistry).creationCode;
        }
        if (kind == Kind.StreamArtworkFinalityRegistry) {
            return type(StreamArtworkFinalityRegistry).creationCode;
        }
        if (kind == Kind.StreamArweaveObjectCheckpointVerifier) {
            return type(StreamArweaveObjectCheckpointVerifier).creationCode;
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
        if (kind == Kind.StreamCoreFinalityAdapter) {
            return type(StreamCoreFinalityAdapter).creationCode;
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
        if (kind == Kind.StreamOnchainContentCheckpoint) {
            return type(StreamOnchainContentCheckpoint).creationCode;
        }
        if (kind == Kind.StreamReferenceRenderPublication) {
            return type(StreamReferenceRenderPublication).creationCode;
        }
        if (kind == Kind.StreamRenderCriticalInventory) {
            return type(StreamRenderCriticalInventory).creationCode;
        }
        if (kind == Kind.StreamRightsRecordSelection) {
            return type(StreamRightsRecordSelection).creationCode;
        }
        if (kind == Kind.StreamSchemaRegistry) return type(StreamSchemaRegistry).creationCode;
        if (kind == Kind.StreamWorkRecordSelection) {
            return type(StreamWorkRecordSelection).creationCode;
        }
        revert("unknown original product template");
    }
}

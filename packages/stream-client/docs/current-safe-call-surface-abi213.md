# Current Safe call-surface inventory (ABI213)

Source: 09f32efab40659a11353be75a1d46a3e49959bb7. The compiler bridge authenticates all 4756 source blobs. The machine file contains exact current signatures, selectors, input/output types and source/ABI hashes for 175 supported products, including the retained historical roster and explicit current full37 additions.
The selected set contains 7211 functions, 4 receive handlers and 0 fallback handlers. This is an ABI surface inventory, not Safe acceptance.

The prior 164-FQN roster is retained selection evidence, not blanket permission to omit later full-v1 products. Candidate products absent from it are separately listed below. The 6,840 compiler FQNs include interfaces, libraries, abstract contracts, tests and legacy products; presence alone does not make them independent supported Safe surfaces.
The deployment planning candidate is planning-only, has no instances and is not production-candidate/readiness evidence; no deployment receipt is included. Target/catalog membership means a committed catalog reference only. ABI read/state-changing counts and selectors describe callable shapes if deployed; they do not establish live reads, successful calls, test execution or deployment.

## Keep three questions separate

- ABI: signatures and receive/fallback handlers are enumerated from the current compiler output.
- Caller authorization: only focused current-product routes below have source-scoped caller classifications. ABI entries alone do not encode role requirements, caller identity or protocol-only boundaries; unlisted methods remain source-review-required.
- Safe runtime: not joined in this static report. Existing source-scoped attestations remain in their historical evidence records; this report neither promotes nor discards them.

## Supported roster by source family

| Family | Contracts | Functions | View/pure | State-changing | Receive | Fallback |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| artist | 30 | 1579 | 1067 | 512 | 0 | 0 |
| auctions | 2 | 172 | 119 | 53 | 0 | 0 |
| core | 1 | 61 | 37 | 24 | 0 | 0 |
| entropy | 3 | 224 | 173 | 51 | 1 | 0 |
| finality | 47 | 1355 | 1266 | 89 | 0 | 0 |
| governance | 4 | 112 | 80 | 32 | 1 | 0 |
| metadata | 25 | 950 | 825 | 125 | 0 | 0 |
| mint | 17 | 1053 | 829 | 224 | 0 | 0 |
| modules | 1 | 24 | 21 | 3 | 0 | 0 |
| preservation | 36 | 1312 | 980 | 332 | 0 | 0 |
| revenue | 9 | 369 | 281 | 88 | 2 | 0 |

## Supported contracts

| FQN | Functions | View/pure | State-changing | Payable functions | Receive | Fallback |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| smart-contracts/core/StreamCore.sol:StreamCore | 61 | 37 | 24 | 0 | 0 | 0 |
| smart-contracts/domains/artist/StreamArtistAcceptanceLifecycle.sol:StreamArtistAcceptanceLifecycle | 35 | 30 | 5 | 0 | 0 | 0 |
| smart-contracts/domains/artist/StreamArtistArchiveV2.sol:StreamArtistArchiveV2 | 14 | 12 | 2 | 0 | 0 | 0 |
| smart-contracts/domains/artist/StreamArtistAttributionLifecycle.sol:StreamArtistAttributionLifecycle | 99 | 71 | 28 | 0 | 0 | 0 |
| smart-contracts/domains/artist/StreamArtistBindingLifecycle.sol:StreamArtistBindingLifecycle | 42 | 34 | 8 | 0 | 0 | 0 |
| smart-contracts/domains/artist/StreamArtistCollaboratorLifecycle.sol:StreamArtistCollaboratorLifecycle | 37 | 33 | 4 | 0 | 0 | 0 |
| smart-contracts/domains/artist/StreamArtistConsentFinalityLifecycle.sol:StreamArtistConsentFinalityLifecycle | 76 | 55 | 21 | 0 | 0 | 0 |
| smart-contracts/domains/artist/StreamArtistConsentWriterExtension.sol:StreamArtistConsentWriterExtension | 48 | 27 | 21 | 0 | 0 | 0 |
| smart-contracts/domains/artist/StreamArtistEstateCreationPart.sol:StreamArtistEstateCreationPart | 0 | 0 | 0 | 0 | 0 | 0 |
| smart-contracts/domains/artist/StreamArtistExtensionFactory.sol:StreamArtistExtensionFactory | 7 | 5 | 2 | 0 | 0 | 0 |
| smart-contracts/domains/artist/StreamArtistGuardianAppealEvidence.sol:StreamArtistGuardianAppealEvidence | 5 | 4 | 1 | 0 | 0 | 0 |
| smart-contracts/domains/artist/StreamArtistGuardianSelectionPreparation.sol:StreamArtistGuardianSelectionPreparation | 7 | 5 | 2 | 0 | 0 | 0 |
| smart-contracts/domains/artist/StreamArtistIdentityAdjudicationExtension.sol:StreamArtistIdentityAdjudicationExtension | 34 | 30 | 4 | 0 | 0 | 0 |
| smart-contracts/domains/artist/StreamArtistIdentityAuthority.sol:StreamArtistIdentityAuthority | 234 | 171 | 63 | 0 | 0 | 0 |
| smart-contracts/domains/artist/StreamArtistIdentityCreationPart.sol:StreamArtistIdentityCreationPart | 0 | 0 | 0 | 0 | 0 | 0 |
| smart-contracts/domains/artist/StreamArtistIdentityEstateExtension.sol:StreamArtistIdentityEstateExtension | 52 | 27 | 25 | 0 | 0 | 0 |
| smart-contracts/domains/artist/StreamArtistIdentityRecoveryExtension.sol:StreamArtistIdentityRecoveryExtension | 34 | 30 | 4 | 0 | 0 | 0 |
| smart-contracts/domains/artist/StreamArtistIdentityRewindExtension.sol:StreamArtistIdentityRewindExtension | 34 | 30 | 4 | 0 | 0 | 0 |
| smart-contracts/domains/artist/StreamArtistIdentityWriterExtension.sol:StreamArtistIdentityWriterExtension | 56 | 27 | 29 | 0 | 0 | 0 |
| smart-contracts/domains/artist/StreamArtistOnboardingCoordinator.sol:StreamArtistOnboardingCoordinator | 107 | 18 | 89 | 0 | 0 | 0 |
| smart-contracts/domains/artist/StreamArtistOnboardingReads.sol:StreamArtistOnboardingReads | 24 | 24 | 0 | 0 | 0 | 0 |
| smart-contracts/domains/artist/StreamArtistOnboardingRegistry.sol:StreamArtistOnboardingRegistry | 304 | 211 | 93 | 0 | 0 | 0 |
| smart-contracts/domains/artist/StreamArtistPayoutLifecycle.sol:StreamArtistPayoutLifecycle | 43 | 37 | 6 | 0 | 0 | 0 |
| smart-contracts/domains/artist/StreamArtistRecoveryEvidence.sol:StreamArtistRecoveryEvidence | 11 | 9 | 2 | 0 | 0 | 0 |
| smart-contracts/domains/artist/StreamArtistRecoveryRewindEvidence.sol:StreamArtistRecoveryRewindEvidence | 14 | 11 | 3 | 0 | 0 | 0 |
| smart-contracts/domains/artist/StreamArtistRecoveryRewindSelection.sol:StreamArtistRecoveryRewindSelection | 14 | 11 | 3 | 0 | 0 | 0 |
| smart-contracts/domains/artist/StreamArtistRecoverySelectionPreparation.sol:StreamArtistRecoverySelectionPreparation | 8 | 6 | 2 | 0 | 0 | 0 |
| smart-contracts/domains/artist/StreamArtistRegistryFinalityReadExtension.sol:StreamArtistRegistryFinalityReadExtension | 38 | 38 | 0 | 0 | 0 | 0 |
| smart-contracts/domains/artist/StreamArtistRegistryReadExtension.sol:StreamArtistRegistryReadExtension | 110 | 110 | 0 | 0 | 0 | 0 |
| smart-contracts/domains/artist/StreamArtistRegistryValidatorBase.sol:StreamArtistRegistryValidatorBase | 1 | 1 | 0 | 0 | 0 | 0 |
| smart-contracts/domains/artist/StreamArtistRegistryWriterExtension.sol:StreamArtistRegistryWriterExtension | 91 | 0 | 91 | 0 | 0 | 0 |
| smart-contracts/domains/auctions/StreamEnglishAuctionHouse.sol:StreamEnglishAuctionHouse | 48 | 36 | 12 | 1 | 0 | 0 |
| smart-contracts/domains/auctions/StreamNativeEnglishAuction.sol:StreamNativeEnglishAuction | 124 | 83 | 41 | 13 | 0 | 0 |
| smart-contracts/domains/entropy/StreamEntropyCoordinator.sol:StreamEntropyCoordinator | 138 | 98 | 40 | 6 | 0 | 0 |
| smart-contracts/domains/entropy/StreamEntropyProviderVRF.sol:StreamEntropyProviderVRF | 34 | 30 | 4 | 1 | 0 | 0 |
| smart-contracts/domains/finality/StreamArtworkFinalityRegistry.sol:StreamArtworkFinalityRegistry | 75 | 65 | 10 | 0 | 0 | 0 |
| smart-contracts/domains/finality/StreamCollectionTokenInventory.sol:StreamCollectionTokenInventory | 25 | 22 | 3 | 0 | 0 | 0 |
| smart-contracts/domains/finality/StreamContentLeafManifest.sol:StreamContentLeafManifest | 26 | 23 | 3 | 0 | 0 | 0 |
| smart-contracts/domains/finality/StreamCoreFinalityAdapter.sol:StreamCoreFinalityAdapter | 6 | 6 | 0 | 0 | 0 | 0 |
| smart-contracts/domains/finality/StreamCurrentAuthorityDeferredScopedPolicyEvidenceProviderV2.sol:StreamCurrentAuthorityDeferredScopedPolicyEvidenceProviderV2 | 65 | 64 | 1 | 0 | 0 | 0 |
| smart-contracts/domains/finality/StreamCurrentAuthorityFullPreservationPolicyDiscoveryV1.sol:StreamCurrentAuthorityFullPreservationPolicyDiscoveryV1 | 17 | 17 | 0 | 0 | 0 | 0 |
| smart-contracts/domains/finality/StreamCurrentAuthorityFullPreservationPolicyEvidenceProviderV1.sol:StreamCurrentAuthorityFullPreservationPolicyEvidenceProviderV1 | 72 | 70 | 2 | 0 | 0 | 0 |
| smart-contracts/domains/finality/StreamCurrentAuthorityNativeEvidenceProvider.sol:StreamCurrentAuthorityNativeEvidenceProvider | 37 | 37 | 0 | 0 | 0 | 0 |
| smart-contracts/domains/finality/StreamCurrentAuthorityPreservationPolicyPublicationFactoryV1.sol:StreamCurrentAuthorityPreservationPolicyPublicationFactoryV1 | 13 | 12 | 1 | 0 | 0 | 0 |
| smart-contracts/domains/finality/StreamCurrentAuthorityScopedPolicyPublicationFactoryV2.sol:StreamCurrentAuthorityScopedPolicyPublicationFactoryV2 | 13 | 12 | 1 | 0 | 0 | 0 |
| smart-contracts/domains/finality/StreamCurrentAuthorityScopedPreservationPolicyPublicationFactoryV1.sol:StreamCurrentAuthorityScopedPreservationPolicyPublicationFactoryV1 | 13 | 12 | 1 | 0 | 0 | 0 |
| smart-contracts/domains/finality/StreamFinalityCoordinatorInventory.sol:StreamFinalityCoordinatorInventory | 16 | 14 | 2 | 0 | 0 | 0 |
| smart-contracts/domains/finality/StreamFinalityCurrentDiscovery.sol:StreamFinalityCurrentDiscovery | 16 | 16 | 0 | 0 | 0 | 0 |
| smart-contracts/domains/finality/StreamFinalityEntropyPolicySourceFactoryV2.sol:StreamFinalityEntropyPolicySourceFactoryV2 | 12 | 11 | 1 | 0 | 0 | 0 |
| smart-contracts/domains/finality/StreamFinalityEntropyPolicySourceSet.sol:StreamFinalityEntropyPolicySourceSet | 25 | 25 | 0 | 0 | 0 | 0 |
| smart-contracts/domains/finality/StreamFinalityEntropySourceFactory.sol:StreamFinalityEntropySourceFactory | 10 | 9 | 1 | 0 | 0 | 0 |
| smart-contracts/domains/finality/StreamFinalityEntropySourceSet.sol:StreamFinalityEntropySourceSet | 25 | 25 | 0 | 0 | 0 | 0 |
| smart-contracts/domains/finality/StreamFinalityFullPolicyDiscoveryV2.sol:StreamFinalityFullPolicyDiscoveryV2 | 17 | 17 | 0 | 0 | 0 | 0 |
| smart-contracts/domains/finality/StreamFinalityFullPolicyEvidenceProviderV2.sol:StreamFinalityFullPolicyEvidenceProviderV2 | 54 | 54 | 0 | 0 | 0 | 0 |
| smart-contracts/domains/finality/StreamFinalityFullPreservationPolicyDiscoveryV1.sol:StreamFinalityFullPreservationPolicyDiscoveryV1 | 17 | 17 | 0 | 0 | 0 | 0 |
| smart-contracts/domains/finality/StreamFinalityFullPreservationPolicyEvidenceProviderV1.sol:StreamFinalityFullPreservationPolicyEvidenceProviderV1 | 72 | 70 | 2 | 0 | 0 | 0 |
| smart-contracts/domains/finality/StreamFinalityLineageCurrentDiscovery.sol:StreamFinalityLineageCurrentDiscovery | 16 | 16 | 0 | 0 | 0 | 0 |
| smart-contracts/domains/finality/StreamFinalityLineageDeferredScopedPolicyDiscoveryV2.sol:StreamFinalityLineageDeferredScopedPolicyDiscoveryV2 | 17 | 17 | 0 | 0 | 0 | 0 |
| smart-contracts/domains/finality/StreamFinalityNativeEvidenceProvider.sol:StreamFinalityNativeEvidenceProvider | 37 | 37 | 0 | 0 | 0 | 0 |
| smart-contracts/domains/finality/StreamFinalityScopedEntropyPolicySourceFactoryV2.sol:StreamFinalityScopedEntropyPolicySourceFactoryV2 | 12 | 11 | 1 | 0 | 0 | 0 |
| smart-contracts/domains/finality/StreamFinalityScopeMembership.sol:StreamFinalityScopeMembership | 28 | 25 | 3 | 0 | 0 | 0 |
| smart-contracts/domains/finality/StreamFinalityServingHostAdapter.sol:StreamFinalityServingHostAdapter | 14 | 14 | 0 | 0 | 0 | 0 |
| smart-contracts/domains/finality/StreamLineageArtworkFinalityRegistry.sol:StreamLineageArtworkFinalityRegistry | 79 | 69 | 10 | 0 | 0 | 0 |
| smart-contracts/domains/finality/StreamOnchainContentCheckpoint.sol:StreamOnchainContentCheckpoint | 29 | 25 | 4 | 0 | 0 | 0 |
| smart-contracts/domains/finality/StreamPolicyContentCheckpointV2.sol:StreamPolicyContentCheckpointV2 | 34 | 31 | 3 | 0 | 0 | 0 |
| smart-contracts/domains/finality/StreamPolicyOutputManifestV2.sol:StreamPolicyOutputManifestV2 | 29 | 26 | 3 | 0 | 0 | 0 |
| smart-contracts/domains/finality/StreamPolicyPublicationFactoryV2.sol:StreamPolicyPublicationFactoryV2 | 11 | 10 | 1 | 0 | 0 | 0 |
| smart-contracts/domains/finality/StreamPreservationPolicyContentCheckpointV1.sol:StreamPreservationPolicyContentCheckpointV1 | 41 | 38 | 3 | 0 | 0 | 0 |
| smart-contracts/domains/finality/StreamPreservationPolicyContentCheckpointV2.sol:StreamPreservationPolicyContentCheckpointV2 | 41 | 38 | 3 | 0 | 0 | 0 |
| smart-contracts/domains/finality/StreamPreservationPolicyOutputManifestV1.sol:StreamPreservationPolicyOutputManifestV1 | 30 | 27 | 3 | 0 | 0 | 0 |
| smart-contracts/domains/finality/StreamPreservationPolicyOutputManifestV2.sol:StreamPreservationPolicyOutputManifestV2 | 30 | 27 | 3 | 0 | 0 | 0 |
| smart-contracts/domains/finality/StreamPreservationPolicyPublicationFactoryV1.sol:StreamPreservationPolicyPublicationFactoryV1 | 11 | 10 | 1 | 0 | 0 | 0 |
| smart-contracts/domains/finality/StreamScopedPolicyContentCheckpointV2.sol:StreamScopedPolicyContentCheckpointV2 | 38 | 35 | 3 | 0 | 0 | 0 |
| smart-contracts/domains/finality/StreamScopedPolicyOutputManifestV2.sol:StreamScopedPolicyOutputManifestV2 | 30 | 27 | 3 | 0 | 0 | 0 |
| smart-contracts/domains/finality/StreamScopedPolicyPublicationFactoryV2.sol:StreamScopedPolicyPublicationFactoryV2 | 11 | 10 | 1 | 0 | 0 | 0 |
| smart-contracts/domains/finality/StreamScopedPreservationPolicyContentCheckpointV1.sol:StreamScopedPreservationPolicyContentCheckpointV1 | 41 | 38 | 3 | 0 | 0 | 0 |
| smart-contracts/domains/finality/StreamScopedPreservationPolicyContentCheckpointV2.sol:StreamScopedPreservationPolicyContentCheckpointV2 | 41 | 38 | 3 | 0 | 0 | 0 |
| smart-contracts/domains/finality/StreamScopedPreservationPolicyPublicationFactoryV1.sol:StreamScopedPreservationPolicyPublicationFactoryV1 | 11 | 10 | 1 | 0 | 0 | 0 |
| smart-contracts/domains/finality/StreamStaticContentCheckpoint.sol:StreamStaticContentCheckpoint | 30 | 27 | 3 | 0 | 0 | 0 |
| smart-contracts/domains/finality/StreamStaticOutputManifest.sol:StreamStaticOutputManifest | 28 | 25 | 3 | 0 | 0 | 0 |
| smart-contracts/domains/finality/StreamStaticSelectionCheckpoint.sol:StreamStaticSelectionCheckpoint | 30 | 27 | 3 | 0 | 0 | 0 |
| smart-contracts/domains/finality/StreamTerminalEntropyReadiness.sol:StreamTerminalEntropyReadiness | 10 | 10 | 0 | 0 | 0 | 0 |
| smart-contracts/domains/governance/StreamGovernanceActor.sol:StreamGovernanceActor | 2 | 1 | 1 | 1 | 1 | 0 |
| smart-contracts/domains/governance/StreamGovernanceExecutor.sol:StreamGovernanceExecutor | 74 | 49 | 25 | 2 | 0 | 0 |
| smart-contracts/domains/governance/StreamRoleRegistry.sol:StreamRoleRegistry | 28 | 23 | 5 | 0 | 0 | 0 |
| smart-contracts/domains/governance/StreamSystemManifest.sol:StreamSystemManifest | 8 | 7 | 1 | 0 | 0 | 0 |
| smart-contracts/domains/metadata/StreamCollectionAttestations.sol:StreamCollectionAttestations | 52 | 48 | 4 | 0 | 0 | 0 |
| smart-contracts/domains/metadata/StreamCollectionMetadataV1.sol:StreamCollectionMetadataV1 | 88 | 73 | 15 | 0 | 0 | 0 |
| smart-contracts/domains/metadata/StreamCollectionSnapshots.sol:StreamCollectionSnapshots | 43 | 40 | 3 | 0 | 0 | 0 |
| smart-contracts/domains/metadata/StreamCollectionViews.sol:StreamCollectionViews | 43 | 39 | 4 | 0 | 0 | 0 |
| smart-contracts/domains/metadata/StreamConservationRecordSelection.sol:StreamConservationRecordSelection | 23 | 17 | 6 | 0 | 0 | 0 |
| smart-contracts/domains/metadata/StreamCurrentAuthorityConservationRecordSelection.sol:StreamCurrentAuthorityConservationRecordSelection | 25 | 19 | 6 | 0 | 0 | 0 |
| smart-contracts/domains/metadata/StreamCurrentAuthorityRightsRecordSelection.sol:StreamCurrentAuthorityRightsRecordSelection | 20 | 17 | 3 | 0 | 0 | 0 |
| smart-contracts/domains/metadata/StreamCurrentAuthorityWorkRecordSelection.sol:StreamCurrentAuthorityWorkRecordSelection | 20 | 17 | 3 | 0 | 0 | 0 |
| smart-contracts/domains/metadata/StreamMetadataRouter.sol:StreamMetadataRouter | 122 | 99 | 23 | 0 | 0 | 0 |
| smart-contracts/domains/metadata/StreamOwnerRecords.sol:StreamOwnerRecords | 70 | 55 | 15 | 0 | 0 | 0 |
| smart-contracts/domains/metadata/StreamPolicySnapshotPublicationV2.sol:StreamPolicySnapshotPublicationV2 | 31 | 28 | 3 | 0 | 0 | 0 |
| smart-contracts/domains/metadata/StreamPreservationPolicySnapshotPublicationV1.sol:StreamPreservationPolicySnapshotPublicationV1 | 32 | 29 | 3 | 0 | 0 | 0 |
| smart-contracts/domains/metadata/StreamPreservationPolicySnapshotPublicationV2.sol:StreamPreservationPolicySnapshotPublicationV2 | 32 | 29 | 3 | 0 | 0 | 0 |
| smart-contracts/domains/metadata/StreamRightsRecordSelection.sol:StreamRightsRecordSelection | 18 | 15 | 3 | 0 | 0 | 0 |
| smart-contracts/domains/metadata/StreamSchemaDocumentStore.sol:StreamSchemaDocumentStore | 4 | 3 | 1 | 0 | 0 | 0 |
| smart-contracts/domains/metadata/StreamSchemaRegistry.sol:StreamSchemaRegistry | 21 | 19 | 2 | 0 | 0 | 0 |
| smart-contracts/domains/metadata/StreamScopedPolicySnapshotPublicationV2.sol:StreamScopedPolicySnapshotPublicationV2 | 30 | 27 | 3 | 0 | 0 | 0 |
| smart-contracts/domains/metadata/StreamScopedPreservationPolicySnapshotPublicationV1.sol:StreamScopedPreservationPolicySnapshotPublicationV1 | 30 | 27 | 3 | 0 | 0 | 0 |
| smart-contracts/domains/metadata/StreamScopedPreservationPolicySnapshotPublicationV2.sol:StreamScopedPreservationPolicySnapshotPublicationV2 | 30 | 27 | 3 | 0 | 0 | 0 |
| smart-contracts/domains/metadata/StreamScopedSnapshotPublication.sol:StreamScopedSnapshotPublication | 29 | 26 | 3 | 0 | 0 | 0 |
| smart-contracts/domains/metadata/StreamWorkRecordSelection.sol:StreamWorkRecordSelection | 18 | 15 | 3 | 0 | 0 | 0 |
| smart-contracts/domains/mint/StreamDelegateRegistryGate.sol:StreamDelegateRegistryGate | 23 | 22 | 1 | 0 | 0 | 0 |
| smart-contracts/domains/mint/StreamERC20DutchSale.sol:StreamERC20DutchSale | 67 | 55 | 12 | 2 | 0 | 0 |
| smart-contracts/domains/mint/StreamERC20FixedPriceSaleAdapter.sol:StreamERC20FixedPriceSaleAdapter | 49 | 38 | 11 | 0 | 0 | 0 |
| smart-contracts/domains/mint/StreamFixedPriceSaleAdapter.sol:StreamFixedPriceSaleAdapter | 33 | 27 | 6 | 1 | 0 | 0 |
| smart-contracts/domains/mint/StreamMintLedger.sol:StreamMintLedger | 48 | 32 | 16 | 0 | 0 | 0 |
| smart-contracts/domains/mint/StreamMintManager.sol:StreamMintManager | 103 | 80 | 23 | 0 | 0 | 0 |
| smart-contracts/domains/mint/StreamMintTicketGate.sol:StreamMintTicketGate | 19 | 18 | 1 | 0 | 0 | 0 |
| smart-contracts/domains/mint/StreamNativeClaimSales.sol:StreamNativeClaimSales | 65 | 53 | 12 | 2 | 0 | 0 |
| smart-contracts/domains/mint/StreamNativeDutchSales.sol:StreamNativeDutchSales | 66 | 54 | 12 | 2 | 0 | 0 |
| smart-contracts/domains/mint/StreamNativeImmediateSales.sol:StreamNativeImmediateSales | 65 | 53 | 12 | 2 | 0 | 0 |
| smart-contracts/domains/mint/StreamUniversalAllowlistPriceSale.sol:StreamUniversalAllowlistPriceSale | 61 | 51 | 10 | 2 | 0 | 0 |
| smart-contracts/domains/mint/StreamUniversalFixedPriceSaleAdapter.sol:StreamUniversalFixedPriceSaleAdapter | 57 | 48 | 9 | 1 | 0 | 0 |
| smart-contracts/domains/modules/StreamModuleRegistry.sol:StreamModuleRegistry | 24 | 21 | 3 | 0 | 0 | 0 |
| smart-contracts/domains/preservation/StreamArchivalCoverage.sol:StreamArchivalCoverage | 45 | 35 | 10 | 0 | 0 | 0 |
| smart-contracts/domains/preservation/StreamArtistArchiveOriginReads.sol:StreamArtistArchiveOriginReads | 8 | 8 | 0 | 0 | 0 | 0 |
| smart-contracts/domains/preservation/StreamArtistCurrentAuthorityResolver.sol:StreamArtistCurrentAuthorityResolver | 5 | 5 | 0 | 0 | 0 | 0 |
| smart-contracts/domains/preservation/StreamArweaveCheckpointVerifier.sol:StreamArweaveCheckpointVerifier | 20 | 18 | 2 | 0 | 0 | 0 |
| smart-contracts/domains/preservation/StreamArweaveObjectCheckpointVerifier.sol:StreamArweaveObjectCheckpointVerifier | 20 | 18 | 2 | 0 | 0 | 0 |
| smart-contracts/domains/preservation/StreamBundleArchiveCoverage.sol:StreamBundleArchiveCoverage | 23 | 18 | 5 | 0 | 0 | 0 |
| smart-contracts/domains/preservation/StreamCurrentAuthorityBundleArchiveCoverage.sol:StreamCurrentAuthorityBundleArchiveCoverage | 28 | 23 | 5 | 0 | 0 | 0 |
| smart-contracts/domains/preservation/StreamCurrentAuthorityPolicyRenderCriticalInventoryV2.sol:StreamCurrentAuthorityPolicyRenderCriticalInventoryV2 | 48 | 30 | 18 | 0 | 0 | 0 |
| smart-contracts/domains/preservation/StreamCurrentAuthorityPreservationPolicyBundleArchiveCoverageV1.sol:StreamCurrentAuthorityPreservationPolicyBundleArchiveCoverageV1 | 30 | 25 | 5 | 0 | 0 | 0 |
| smart-contracts/domains/preservation/StreamCurrentAuthorityPreservationPolicyRenderCriticalInventoryV1.sol:StreamCurrentAuthorityPreservationPolicyRenderCriticalInventoryV1 | 50 | 31 | 19 | 0 | 0 | 0 |
| smart-contracts/domains/preservation/StreamCurrentAuthorityRenderCriticalInventory.sol:StreamCurrentAuthorityRenderCriticalInventory | 42 | 28 | 14 | 0 | 0 | 0 |
| smart-contracts/domains/preservation/StreamCurrentAuthorityScopedBundleArchiveCoverage.sol:StreamCurrentAuthorityScopedBundleArchiveCoverage | 28 | 23 | 5 | 0 | 0 | 0 |
| smart-contracts/domains/preservation/StreamCurrentAuthorityScopedPolicyRenderCriticalInventoryV2.sol:StreamCurrentAuthorityScopedPolicyRenderCriticalInventoryV2 | 46 | 28 | 18 | 0 | 0 | 0 |
| smart-contracts/domains/preservation/StreamCurrentAuthorityScopedPreservationPolicyBundleArchiveCoverageV1.sol:StreamCurrentAuthorityScopedPreservationPolicyBundleArchiveCoverageV1 | 30 | 25 | 5 | 0 | 0 | 0 |
| smart-contracts/domains/preservation/StreamCurrentAuthorityScopedPreservationPolicyRenderCriticalInventoryV1.sol:StreamCurrentAuthorityScopedPreservationPolicyRenderCriticalInventoryV1 | 47 | 28 | 19 | 0 | 0 | 0 |
| smart-contracts/domains/preservation/StreamCurrentAuthorityScopedRenderCriticalInventory.sol:StreamCurrentAuthorityScopedRenderCriticalInventory | 44 | 26 | 18 | 0 | 0 | 0 |
| smart-contracts/domains/preservation/StreamExternalArtifactCoverage.sol:StreamExternalArtifactCoverage | 38 | 31 | 7 | 0 | 0 | 0 |
| smart-contracts/domains/preservation/StreamFinalityArtifactCoverage.sol:StreamFinalityArtifactCoverage | 31 | 26 | 5 | 0 | 0 | 0 |
| smart-contracts/domains/preservation/StreamPolicyReferencePublicationV2.sol:StreamPolicyReferencePublicationV2 | 52 | 45 | 7 | 0 | 0 | 0 |
| smart-contracts/domains/preservation/StreamPolicyRenderCriticalInventoryV2.sol:StreamPolicyRenderCriticalInventoryV2 | 37 | 20 | 17 | 0 | 0 | 0 |
| smart-contracts/domains/preservation/StreamPreservationPolicyReferencePublicationV1.sol:StreamPreservationPolicyReferencePublicationV1 | 53 | 46 | 7 | 0 | 0 | 0 |
| smart-contracts/domains/preservation/StreamPreservationPolicyReferencePublicationV2.sol:StreamPreservationPolicyReferencePublicationV2 | 53 | 46 | 7 | 0 | 0 | 0 |
| smart-contracts/domains/preservation/StreamPreservationPolicyRenderCriticalInventoryV1.sol:StreamPreservationPolicyRenderCriticalInventoryV1 | 38 | 20 | 18 | 0 | 0 | 0 |
| smart-contracts/domains/preservation/StreamReferenceRenderPublication.sol:StreamReferenceRenderPublication | 49 | 42 | 7 | 0 | 0 | 0 |
| smart-contracts/domains/preservation/StreamRenderCriticalInventory.sol:StreamRenderCriticalInventory | 31 | 18 | 13 | 0 | 0 | 0 |
| smart-contracts/domains/preservation/StreamScopedBundleArchiveCoverage.sol:StreamScopedBundleArchiveCoverage | 23 | 18 | 5 | 0 | 0 | 0 |
| smart-contracts/domains/preservation/StreamScopedPolicyBundleArchiveCoverageV2.sol:StreamScopedPolicyBundleArchiveCoverageV2 | 25 | 20 | 5 | 0 | 0 | 0 |
| smart-contracts/domains/preservation/StreamScopedPolicyReferencePublicationV2.sol:StreamScopedPolicyReferencePublicationV2 | 50 | 43 | 7 | 0 | 0 | 0 |
| smart-contracts/domains/preservation/StreamScopedPolicyRenderCriticalInventoryV2.sol:StreamScopedPolicyRenderCriticalInventoryV2 | 35 | 18 | 17 | 0 | 0 | 0 |
| smart-contracts/domains/preservation/StreamScopedPreservationPolicyBundleArchiveCoverageV1.sol:StreamScopedPreservationPolicyBundleArchiveCoverageV1 | 25 | 20 | 5 | 0 | 0 | 0 |
| smart-contracts/domains/preservation/StreamScopedPreservationPolicyReferencePublicationV1.sol:StreamScopedPreservationPolicyReferencePublicationV1 | 50 | 43 | 7 | 0 | 0 | 0 |
| smart-contracts/domains/preservation/StreamScopedPreservationPolicyReferencePublicationV2.sol:StreamScopedPreservationPolicyReferencePublicationV2 | 50 | 43 | 7 | 0 | 0 | 0 |
| smart-contracts/domains/preservation/StreamScopedPreservationPolicyRenderCriticalInventoryV1.sol:StreamScopedPreservationPolicyRenderCriticalInventoryV1 | 36 | 18 | 18 | 0 | 0 | 0 |
| smart-contracts/domains/preservation/StreamScopedReferencePublication.sol:StreamScopedReferencePublication | 49 | 42 | 7 | 0 | 0 | 0 |
| smart-contracts/domains/preservation/StreamScopedRenderCriticalInventory.sol:StreamScopedRenderCriticalInventory | 33 | 16 | 17 | 0 | 0 | 0 |
| smart-contracts/domains/revenue/StreamAssetPolicyRegistry.sol:StreamAssetPolicyRegistry | 19 | 17 | 2 | 0 | 0 | 0 |
| smart-contracts/domains/revenue/StreamClaimRouter.sol:StreamClaimRouter | 2 | 0 | 2 | 0 | 0 | 0 |
| smart-contracts/domains/revenue/StreamERC20PrimarySettlementAdapter.sol:StreamERC20PrimarySettlementAdapter | 35 | 24 | 11 | 8 | 0 | 0 |
| smart-contracts/domains/revenue/StreamPrimarySaleSettlement.sol:StreamPrimarySaleSettlement | 63 | 45 | 18 | 14 | 0 | 0 |
| smart-contracts/domains/revenue/StreamRevenueEscrow.sol:StreamRevenueEscrow | 54 | 39 | 15 | 1 | 1 | 0 |
| smart-contracts/domains/revenue/StreamRevenueResolver.sol:StreamRevenueResolver | 65 | 53 | 12 | 0 | 0 | 0 |
| smart-contracts/domains/revenue/StreamRoyaltyResolver.sol:StreamRoyaltyResolver | 56 | 39 | 17 | 0 | 0 | 0 |
| smart-contracts/domains/revenue/StreamSplitFactory.sol:StreamSplitFactory | 43 | 38 | 5 | 0 | 0 | 0 |
| smart-contracts/domains/revenue/StreamSplitWallet.sol:StreamSplitWallet | 32 | 26 | 6 | 0 | 1 | 0 |
| smart-contracts/domains/entropy/StreamEntropyProviderARRNG.sol:StreamEntropyProviderARRNG | 52 | 45 | 7 | 2 | 1 | 0 |
| smart-contracts/domains/metadata/StreamGeneralAttestations.sol:StreamGeneralAttestations | 64 | 58 | 6 | 0 | 0 | 0 |
| smart-contracts/domains/metadata/StreamRendererRegistryModule.sol:StreamRendererRegistryModule | 61 | 55 | 6 | 0 | 0 | 0 |
| smart-contracts/domains/metadata/StreamRendererV1.sol:StreamRendererV1 | 36 | 35 | 1 | 0 | 0 | 0 |
| smart-contracts/domains/metadata/StreamStaticAttributionCompanion.sol:StreamStaticAttributionCompanion | 8 | 8 | 0 | 0 | 0 | 0 |
| smart-contracts/domains/mint/StreamBurnMintGate.sol:StreamBurnMintGate | 53 | 45 | 8 | 1 | 0 | 0 |
| smart-contracts/domains/mint/StreamMintManagerFallback.sol:StreamMintManagerFallback | 104 | 80 | 24 | 0 | 0 | 0 |
| smart-contracts/domains/mint/StreamNativeDutchSale.sol:StreamNativeDutchSale | 74 | 58 | 16 | 2 | 0 | 0 |
| smart-contracts/domains/mint/StreamNativeFixedPriceSaleAdapter.sol:StreamNativeFixedPriceSaleAdapter | 81 | 63 | 18 | 4 | 0 | 0 |
| smart-contracts/domains/mint/StreamPrivateSaleAdapter.sol:StreamPrivateSaleAdapter | 85 | 52 | 33 | 4 | 0 | 0 |
| smart-contracts/domains/preservation/StreamPreservationRecordsV1.sol:StreamPreservationRecordsV1 | 40 | 36 | 4 | 0 | 0 | 0 |

## Receive and fallback

| FQN | Entry | Mutability | Payable |
| --- | --- | --- | --- |
| smart-contracts/domains/governance/StreamGovernanceActor.sol:StreamGovernanceActor | receive | payable | true |
| smart-contracts/domains/revenue/StreamRevenueEscrow.sol:StreamRevenueEscrow | receive | payable | true |
| smart-contracts/domains/revenue/StreamSplitWallet.sol:StreamSplitWallet | receive | payable | true |
| smart-contracts/domains/entropy/StreamEntropyProviderARRNG.sol:StreamEntropyProviderARRNG | receive | payable | true |

## Source-backed caller route candidates

These focused classifications follow concrete caller and role checks in the current product source. Rows naming the Governance Executor or a configured role identify candidate authority routes; exact owner/authority, role-holder and Safe addresses still require a deployment join. When the target caller is the Executor, a Governance Safe must reach it through the scheduled action flow. User/artist Safe routes remain deployment-binding candidates. Protocol callbacks are source-restricted endpoints, not ordinary Safe targets. Unlisted methods remain source-review-required; none of these rows proves runtime acceptance.

| Product | Function | Selector | Caller route | Source basis | Remaining binding |
| --- | --- | --- | --- | --- | --- |
| smart-contracts/domains/revenue/StreamERC20PrimarySettlementAdapter.sol:StreamERC20PrimarySettlementAdapter | `settleERC20PrimarySaleByPayer((address,address,(bytes32,bytes32,uint8,uint256,uint256,uint256,address,address,address,uint256,bytes32),(address,uint64,uint64,uint64),(bytes32,uint256,uint8,bytes32),address,uint8,address,bytes32,bytes32,bytes32,bytes32,(bytes32,address,bytes32,bytes32,bytes32),bytes32),bytes)` | 0x3f03540c | payer-safe-or-signed-payment-intent | Direct entry binds msg.sender to payer; intent entry validates payer signature, nonce, deadline and sale/asset caps. Not an unrestricted recorder callback. | bind payer Safe or verify the signed payment intent |
| smart-contracts/domains/revenue/StreamERC20PrimarySettlementAdapter.sol:StreamERC20PrimarySettlementAdapter | `settleERC20PrimarySaleWithIntent((address,address,(bytes32,bytes32,uint8,uint256,uint256,uint256,address,address,address,uint256,bytes32),(address,uint64,uint64,uint64),(bytes32,uint256,uint8,bytes32),address,uint8,address,bytes32,bytes32,bytes32,bytes32,(bytes32,address,bytes32,bytes32,bytes32),bytes32),(address,address,uint256,bytes32,bytes32,bytes32,uint64),bytes,bytes)` | 0x01e14082 | payer-safe-or-signed-payment-intent | Direct entry binds msg.sender to payer; intent entry validates payer signature, nonce, deadline and sale/asset caps. Not an unrestricted recorder callback. | bind payer Safe or verify the signed payment intent |
| smart-contracts/domains/revenue/StreamERC20PrimarySettlementAdapter.sol:StreamERC20PrimarySettlementAdapter | `settleERC20PrimarySaleWithEIP2612Permit((address,address,(bytes32,bytes32,uint8,uint256,uint256,uint256,address,address,address,uint256,bytes32),(address,uint64,uint64,uint64),(bytes32,uint256,uint8,bytes32),address,uint8,address,bytes32,bytes32,bytes32,bytes32,(bytes32,address,bytes32,bytes32,bytes32),bytes32),(uint256,uint8,bytes32,bytes32),bytes)` | 0xa63e7389 | payer-safe-or-signed-payment-intent | Direct entry binds msg.sender to payer; intent entry validates payer signature, nonce, deadline and sale/asset caps. Not an unrestricted recorder callback. | bind payer Safe or verify the signed payment intent |
| smart-contracts/domains/revenue/StreamERC20PrimarySettlementAdapter.sol:StreamERC20PrimarySettlementAdapter | `settleERC20PrimarySaleWithPermit2((address,address,(bytes32,bytes32,uint8,uint256,uint256,uint256,address,address,address,uint256,bytes32),(address,uint64,uint64,uint64),(bytes32,uint256,uint8,bytes32),address,uint8,address,bytes32,bytes32,bytes32,bytes32,(bytes32,address,bytes32,bytes32,bytes32),bytes32),(uint256,uint256,bytes),bytes)` | 0x203e0995 | payer-safe-or-signed-payment-intent | Direct entry binds msg.sender to payer; intent entry validates payer signature, nonce, deadline and sale/asset caps. Not an unrestricted recorder callback. | bind payer Safe or verify the signed payment intent |
| smart-contracts/domains/revenue/StreamERC20PrimarySettlementAdapter.sol:StreamERC20PrimarySettlementAdapter | `settleERC20DutchSaleByPayer((address,bytes32,bytes32,bytes32,uint256,bytes))` | 0xc37b0fb0 | payer-safe-or-signed-payment-intent | Direct entry binds msg.sender to payer; intent entry validates payer signature, nonce, deadline and sale/asset caps. Not an unrestricted recorder callback. | bind payer Safe or verify the signed payment intent |
| smart-contracts/domains/revenue/StreamERC20PrimarySettlementAdapter.sol:StreamERC20PrimarySettlementAdapter | `settleERC20DutchSaleWithIntent((address,bytes32,bytes32,bytes32,uint256,bytes),(address,address,uint256,bytes32,bytes32,bytes32,uint64),bytes)` | 0xc45f4a07 | payer-safe-or-signed-payment-intent | Direct entry binds msg.sender to payer; intent entry validates payer signature, nonce, deadline and sale/asset caps. Not an unrestricted recorder callback. | bind payer Safe or verify the signed payment intent |
| smart-contracts/domains/revenue/StreamERC20PrimarySettlementAdapter.sol:StreamERC20PrimarySettlementAdapter | `settleERC20DutchSaleWithEIP2612Permit((address,bytes32,bytes32,bytes32,uint256,bytes),(uint256,(uint256,uint8,bytes32,bytes32)))` | 0xded57b2e | payer-safe-or-signed-payment-intent | Direct entry binds msg.sender to payer; intent entry validates payer signature, nonce, deadline and sale/asset caps. Not an unrestricted recorder callback. | bind payer Safe or verify the signed payment intent |
| smart-contracts/domains/revenue/StreamERC20PrimarySettlementAdapter.sol:StreamERC20PrimarySettlementAdapter | `settleERC20DutchSaleWithPermit2((address,bytes32,bytes32,bytes32,uint256,bytes),(uint256,(uint256,uint256,bytes)))` | 0x8db4f42b | payer-safe-or-signed-payment-intent | Direct entry binds msg.sender to payer; intent entry validates payer signature, nonce, deadline and sale/asset caps. Not an unrestricted recorder callback. | bind payer Safe or verify the signed payment intent |
| smart-contracts/domains/revenue/StreamPrimarySaleSettlement.sol:StreamPrimarySaleSettlement | `settleERC20PrimarySaleFromAdapter(address,(address,address,(bytes32,bytes32,uint8,uint256,uint256,uint256,address,address,address,uint256,bytes32),(address,uint64,uint64,uint64),(bytes32,uint256,uint8,bytes32),address,uint8,address,bytes32,bytes32,bytes32,bytes32,(bytes32,address,bytes32,bytes32,bytes32),bytes32))` | 0x93981479 | registered-sale-adapter-protocol-callback | Settlement entry points are adapter protocol calls validated against registered sale and replay state. | bind the configured callback address, runtime and protocol owner |
| smart-contracts/domains/revenue/StreamPrimarySaleSettlement.sol:StreamPrimarySaleSettlement | `settleERC20DutchPrimarySaleFromAdapter(address,(address,address,(bytes32,bytes32,uint8,uint256,uint256,uint256,address,address,address,uint256,bytes32),(address,uint64,uint64,uint64),(bytes32,uint256,uint8,bytes32),address,uint8,address,bytes32,bytes32,bytes32,bytes32,(bytes32,address,bytes32,bytes32,bytes32),bytes32))` | 0x251c2245 | registered-sale-adapter-protocol-callback | Settlement entry points are adapter protocol calls validated against registered sale and replay state. | bind the configured callback address, runtime and protocol owner |
| smart-contracts/domains/revenue/StreamPrimarySaleSettlement.sol:StreamPrimarySaleSettlement | `settleERC20PublicDutchPrimarySaleFromAdapter(address,(address,address,(bytes32,bytes32,uint8,uint256,uint256,uint256,address,address,address,uint256,bytes32),(address,uint64,uint64,uint64),(bytes32,uint256,uint8,bytes32),address,uint8,address,bytes32,bytes32,bytes32,bytes32,(bytes32,address,bytes32,bytes32,bytes32),bytes32))` | 0x3ebfa1e8 | registered-sale-adapter-protocol-callback | Settlement entry points are adapter protocol calls validated against registered sale and replay state. | bind the configured callback address, runtime and protocol owner |
| smart-contracts/domains/revenue/StreamPrimarySaleSettlement.sol:StreamPrimarySaleSettlement | `settleNativePrimarySaleFromAdapter((address,address,(bytes32,bytes32,uint8,uint256,uint256,uint256,address,address,address,uint256,bytes32),(uint64,uint64),(bytes32,uint256,uint8,bytes32),uint8,address,bytes32,bytes32,bytes32,bytes32,(bytes32,address,bytes32,bytes32,bytes32),bytes32))` | 0xdd95460b | registered-sale-adapter-protocol-callback | Settlement entry points are adapter protocol calls validated against registered sale and replay state. | bind the configured callback address, runtime and protocol owner |
| smart-contracts/domains/revenue/StreamPrimarySaleSettlement.sol:StreamPrimarySaleSettlement | `settleNativePublicPrimarySaleFromAdapter((address,address,(bytes32,bytes32,uint8,uint256,uint256,uint256,address,address,address,uint256,bytes32),(uint64,uint64),(bytes32,uint256,uint8,bytes32),uint8,address,bytes32,bytes32,bytes32,bytes32,(bytes32,address,bytes32,bytes32,bytes32),bytes32))` | 0xf44886f4 | registered-sale-adapter-protocol-callback | Settlement entry points are adapter protocol calls validated against registered sale and replay state. | bind the configured callback address, runtime and protocol owner |
| smart-contracts/domains/entropy/StreamEntropyProviderARRNG.sol:StreamEntropyProviderARRNG | `requestEntropy(bytes32,bytes)` | 0x50fd8523 | entropy-coordinator-protocol-callback | Requires msg.sender == the configured entropy coordinator. | bind the configured callback address, runtime and protocol owner |
| smart-contracts/domains/entropy/StreamEntropyProviderARRNG.sol:StreamEntropyProviderARRNG | `receiveRandomness(uint256,uint256[])` | 0x37f9c70d | arrng-controller-protocol-callback | Requires msg.sender == the configured ARRNG controller. | bind the configured callback address, runtime and protocol owner |
| smart-contracts/domains/entropy/StreamEntropyProviderARRNG.sol:StreamEntropyProviderARRNG | `retryCoordinatorFulfillment(uint256)` | 0xf986ba69 | permissionless-protocol-maintenance | Anyone may retry delivery of an already-authenticated retained provider result; this is not a randomness injection route. | no caller role; deployment/runtime identity remains outside this inventory |
| smart-contracts/domains/entropy/StreamEntropyProviderARRNG.sol:StreamEntropyProviderARRNG | `updateRequestPayment(uint256)` | 0x3928c2da | governance-executor-current-action | Requires the configured governance authority and matching current-action scope/state transition. | bind owner/authority and the Governance Safe to Executor action flow |
| smart-contracts/domains/entropy/StreamEntropyProviderARRNG.sol:StreamEntropyProviderARRNG | `updateControllerOwnerPin(address)` | 0x88444a3a | governance-executor-current-action | Requires the configured governance authority and matching current-action scope/state transition. | bind owner/authority and the Governance Safe to Executor action flow |
| smart-contracts/domains/entropy/StreamEntropyProviderARRNG.sol:StreamEntropyProviderARRNG | `withdrawFunds(uint256)` | 0x155dd5ee | governance-executor-current-action | Requires the configured governance authority and matching current-action scope/state transition. | bind owner/authority and the Governance Safe to Executor action flow |
| smart-contracts/domains/entropy/StreamEntropyProviderARRNG.sol:StreamEntropyProviderARRNG | `raiseGasParameter(bytes32,uint256)` | 0x5c0df7da | governance-executor-current-action | Requires the configured governance authority and matching current-action scope/state transition. | bind owner/authority and the Governance Safe to Executor action flow |
| smart-contracts/domains/mint/StreamNativeDutchSale.sol:StreamNativeDutchSale | `registerDutchSale((uint256,bytes32,(uint96,uint96,uint64,uint64,uint8,uint32,uint96),uint64,uint64,bool,bytes32))` | 0x2757232c | governance-executor-owner-action | onlyOwner for sale configuration and closure; deployment owner/Executor binding must be joined. | bind owner/authority and the Governance Safe to Executor action flow |
| smart-contracts/domains/mint/StreamNativeDutchSale.sol:StreamNativeDutchSale | `registerAllowlistDutchSale((uint256,bytes32,(uint96,uint96,uint64,uint64,uint8,uint32,uint96),uint64,uint64,bool,bytes32),bytes32)` | 0x8d0e39c3 | governance-executor-owner-action | onlyOwner for sale configuration and closure; deployment owner/Executor binding must be joined. | bind owner/authority and the Governance Safe to Executor action flow |
| smart-contracts/domains/mint/StreamNativeDutchSale.sol:StreamNativeDutchSale | `closeSale(bytes32)` | 0x45b092c8 | governance-executor-owner-action | onlyOwner for sale configuration and closure; deployment owner/Executor binding must be joined. | bind owner/authority and the Governance Safe to Executor action flow |
| smart-contracts/domains/mint/StreamNativeDutchSale.sol:StreamNativeDutchSale | `pauseAdapter(bytes32)` | 0x53cc3981 | configured-role-holder-safe-candidate | Pause and unpause methods require the configured RoleRegistry pause/unpause role; holder-to-Safe binding must be joined. | bind the RoleRegistry holder to its selected Safe |
| smart-contracts/domains/mint/StreamNativeDutchSale.sol:StreamNativeDutchSale | `unpauseAdapter(bytes32)` | 0x9469f057 | configured-role-holder-safe-candidate | Pause and unpause methods require the configured RoleRegistry pause/unpause role; holder-to-Safe binding must be joined. | bind the RoleRegistry holder to its selected Safe |
| smart-contracts/domains/mint/StreamNativeDutchSale.sol:StreamNativeDutchSale | `pauseSale(bytes32,bytes32)` | 0x565ef95f | configured-role-holder-safe-candidate | Pause and unpause methods require the configured RoleRegistry pause/unpause role; holder-to-Safe binding must be joined. | bind the RoleRegistry holder to its selected Safe |
| smart-contracts/domains/mint/StreamNativeDutchSale.sol:StreamNativeDutchSale | `unpauseSale(bytes32,bytes32)` | 0x4943a49f | configured-role-holder-safe-candidate | Pause and unpause methods require the configured RoleRegistry pause/unpause role; holder-to-Safe binding must be joined. | bind the RoleRegistry holder to its selected Safe |
| smart-contracts/domains/mint/StreamNativeDutchSale.sol:StreamNativeDutchSale | `raiseGasParameter(bytes32,uint256)` | 0x5c0df7da | governance-executor-current-action | Gas parameter update is a governed current-action operation. | bind owner/authority and the Governance Safe to Executor action flow |
| smart-contracts/domains/mint/StreamNativeDutchSale.sol:StreamNativeDutchSale | `purchase(((bytes32,bytes32,address,address,address,address,bytes32,bytes32,uint256,bytes32,uint64,bytes32,uint256),bytes,bytes,bytes))` | 0x7bd058d3 | user-or-artist-safe-executor-action | Requires msg.sender to equal the bound sale payer and Executor; sale consent also binds the artist. | bind payer/artist identity and the Executor action envelope |
| smart-contracts/domains/mint/StreamNativeDutchSale.sol:StreamNativeDutchSale | `purchaseWithAllowlist(((bytes32,bytes32,address,address,address,address,bytes32,bytes32,uint256,bytes32,uint64,bytes32,uint256),bytes,bytes,bytes),bytes)` | 0xb3c17e28 | user-or-artist-safe-executor-action | Requires msg.sender to equal the bound sale payer and Executor; sale consent also binds the artist. | bind payer/artist identity and the Executor action envelope |
| smart-contracts/domains/mint/StreamNativeFixedPriceSaleAdapter.sol:StreamNativeFixedPriceSaleAdapter | `registerPriceProgram((uint256,bytes32,uint8,uint256,uint256,uint64,uint64,uint64,uint8,bytes32,bytes32))` | 0xdd618515 | governance-executor-owner-action | onlyOwner; current deployment owner/Executor binding must be joined before planning. | bind owner/authority and the Governance Safe to Executor action flow |
| smart-contracts/domains/mint/StreamNativeFixedPriceSaleAdapter.sol:StreamNativeFixedPriceSaleAdapter | `registerAllowlistPriceProgram((uint256,bytes32,uint8,uint256,uint256,uint64,uint64,uint64,uint8,bytes32,bytes32),(bytes32,bool))` | 0xd38a156e | governance-executor-owner-action | onlyOwner; current deployment owner/Executor binding must be joined before planning. | bind owner/authority and the Governance Safe to Executor action flow |
| smart-contracts/domains/mint/StreamNativeFixedPriceSaleAdapter.sol:StreamNativeFixedPriceSaleAdapter | `closePriceProgram(bytes32)` | 0x64f97130 | governance-executor-owner-action | onlyOwner; current deployment owner/Executor binding must be joined before planning. | bind owner/authority and the Governance Safe to Executor action flow |
| smart-contracts/domains/mint/StreamNativeFixedPriceSaleAdapter.sol:StreamNativeFixedPriceSaleAdapter | `registerSale((uint256,bytes32,uint256,uint64,uint64,bytes32,bytes32))` | 0xc180defd | governance-executor-owner-action | onlyOwner; current deployment owner/Executor binding must be joined before planning. | bind owner/authority and the Governance Safe to Executor action flow |
| smart-contracts/domains/mint/StreamNativeFixedPriceSaleAdapter.sol:StreamNativeFixedPriceSaleAdapter | `cancelSale(bytes32)` | 0x0bea8985 | governance-executor-owner-action | onlyOwner; current deployment owner/Executor binding must be joined before planning. | bind owner/authority and the Governance Safe to Executor action flow |
| smart-contracts/domains/mint/StreamNativeFixedPriceSaleAdapter.sol:StreamNativeFixedPriceSaleAdapter | `setPaused(bool)` | 0x16c38b3c | governance-executor-owner-action | onlyOwner; current deployment owner/Executor binding must be joined before planning. | bind owner/authority and the Governance Safe to Executor action flow |
| smart-contracts/domains/mint/StreamNativeFixedPriceSaleAdapter.sol:StreamNativeFixedPriceSaleAdapter | `raiseGasParameter(bytes32,uint256)` | 0x5c0df7da | governance-executor-current-action | Gas parameter update is a governed current-action operation. | bind owner/authority and the Governance Safe to Executor action flow |
| smart-contracts/domains/mint/StreamNativeFixedPriceSaleAdapter.sol:StreamNativeFixedPriceSaleAdapter | `purchase(((bytes32,bytes32,address,address,address,address,bytes32,bytes32,uint256,bytes32,uint64,bytes32),bytes,bytes,bytes))` | 0x8c798cc5 | user-or-artist-safe-executor-action | Purchase path binds the payer and current Executor action; construct through the captured action envelope. | bind payer/artist identity and the Executor action envelope |
| smart-contracts/domains/mint/StreamNativeFixedPriceSaleAdapter.sol:StreamNativeFixedPriceSaleAdapter | `purchaseWithBurn(((bytes32,bytes32,address,address,address,address,bytes32,bytes32,uint256,bytes32,uint64,bytes32),bytes,bytes,bytes),uint256[])` | 0xee079314 | user-or-artist-safe-executor-action | Purchase path binds the payer and current Executor action; construct through the captured action envelope. | bind payer/artist identity and the Executor action envelope |
| smart-contracts/domains/mint/StreamNativeFixedPriceSaleAdapter.sol:StreamNativeFixedPriceSaleAdapter | `executePriceProgram(((bytes32,bytes32,address,address,address,address,bytes32,bytes32,uint256,bytes32,uint64,bytes32,uint256),uint256,bytes,bytes,bytes))` | 0xdbd33480 | user-or-artist-safe-executor-action | Purchase path binds the payer and current Executor action; construct through the captured action envelope. | bind payer/artist identity and the Executor action envelope |
| smart-contracts/domains/mint/StreamNativeFixedPriceSaleAdapter.sol:StreamNativeFixedPriceSaleAdapter | `executeBurnPurchase(((bytes32,bytes32,address,address,address,address,bytes32,bytes32,uint256,bytes32,uint64,bytes32),bytes,bytes,bytes),address,uint256,uint256[])` | 0xfe3831d4 | native-burn-gate-protocol-callback | Consumes a one-use commitment created by purchaseWithBurn; the gate address and complete purchase inputs are commitment-bound, so a direct Safe call reverts. | bind the configured burn gate and its runtime |
| smart-contracts/domains/preservation/StreamPreservationRecordsV1.sol:StreamPreservationRecordsV1 | `registerTokenSubject(uint256)` | 0x0878ff71 | permissionless-subject-registration | Derives the subject from current Core/Metadata reads; registration does not assert an artist record. | no caller role; deployment/runtime identity remains outside this inventory |
| smart-contracts/domains/preservation/StreamPreservationRecordsV1.sol:StreamPreservationRecordsV1 | `registerMediaSubject(uint256,bytes32)` | 0xa6442f54 | permissionless-subject-registration | Derives the subject from current Core/Metadata reads; registration does not assert an artist record. | no caller role; deployment/runtime identity remains outside this inventory |
| smart-contracts/domains/preservation/StreamPreservationRecordsV1.sol:StreamPreservationRecordsV1 | `recordCollectionRecordWithPayload(uint256,(bytes32,bytes32,(uint16,bytes,bytes32),string,bytes32,bytes32,(uint16,bytes,bytes32),uint64),bytes)` | 0x5e763983 | artist-safe-authorized-record-write | The record writer is msg.sender and Reads.admit checks the selected Metadata-family authority before retaining payload bytes. | bind artist Safe and current Metadata-family authority grant |
| smart-contracts/domains/preservation/StreamPreservationRecordsV1.sol:StreamPreservationRecordsV1 | `raiseGasParameter(bytes32,uint256)` | 0x5c0df7da | governance-executor-current-action | Gas parameter update is a governed current-action operation. | bind owner/authority and the Governance Safe to Executor action flow |

## Current full37 product map

This table follows the exact expression order in `StreamFullV1Candidate.capture()` and resolves every captured address expression to its concrete current product using the typed `Foundation` or `Products` field. Historical genesis labels are shown only as a separate crosswalk; they do not override the current source map. The product map proves neither deployment nor Safe acceptance.

| Position | Capture expression | Current product | Typed source field | Concrete compiler product | Roster disposition | Historical label |
| ---: | --- | --- | --- | --- | --- | --- |
| 1 | `address(f.core)` | StreamCore | Foundation.core | smart-contracts/core/StreamCore.sol:StreamCore | retained-164 | STREAM_CORE |
| 2 | `address(f.executor)` | StreamGovernanceExecutor | Foundation.executor | smart-contracts/domains/governance/StreamGovernanceExecutor.sol:StreamGovernanceExecutor | retained-164 | GOVERNANCE_LAYER |
| 3 | `address(f.registry)` | StreamModuleRegistry | Foundation.registry | smart-contracts/domains/modules/StreamModuleRegistry.sol:StreamModuleRegistry | retained-164 | MODULE_REGISTRY |
| 4 | `address(f.revenue)` | StreamRevenueResolver | Foundation.revenue | smart-contracts/domains/revenue/StreamRevenueResolver.sol:StreamRevenueResolver | retained-164 | REVENUE_RESOLVER |
| 5 | `address(f.factory)` | StreamSplitFactory | Foundation.factory | smart-contracts/domains/revenue/StreamSplitFactory.sol:StreamSplitFactory | retained-164 | SPLIT_FACTORY |
| 6 | `p.continuity.walletImplementation` | StreamSplitWallet | ContinuityProducts.walletImplementation; factory-pinned implementation | smart-contracts/domains/revenue/StreamSplitWallet.sol:StreamSplitWallet | retained-164 | SPLIT_WALLET_IMPLEMENTATION |
| 7 | `address(f.escrow)` | StreamRevenueEscrow | Foundation.escrow | smart-contracts/domains/revenue/StreamRevenueEscrow.sol:StreamRevenueEscrow | retained-164 | REVENUE_ESCROW |
| 8 | `address(f.assets)` | StreamAssetPolicyRegistry | Foundation.assets | smart-contracts/domains/revenue/StreamAssetPolicyRegistry.sol:StreamAssetPolicyRegistry | retained-164 | ASSET_POLICY_REGISTRY |
| 9 | `address(p.commerce.native.recorder)` | StreamPrimarySaleSettlement | CommerceProducts.Products.native.recorder | smart-contracts/domains/revenue/StreamPrimarySaleSettlement.sol:StreamPrimarySaleSettlement | retained-164 | PRIMARY_SALE_SETTLEMENT |
| 10 | `address(p.independent.claims)` | StreamClaimRouter | GenesisProducts.Products.claims | smart-contracts/domains/revenue/StreamClaimRouter.sol:StreamClaimRouter | retained-164 | CLAIM_ROUTER |
| 11 | `address(f.manager)` | StreamMintManager | Foundation.manager | smart-contracts/domains/mint/StreamMintManager.sol:StreamMintManager | retained-164 | MINT_MANAGER |
| 12 | `address(f.ledger)` | StreamMintLedger | Foundation.ledger | smart-contracts/domains/mint/StreamMintLedger.sol:StreamMintLedger | retained-164 | MINT_LEDGER |
| 13 | `address(p.independent.tickets)` | StreamMintTicketGate | GenesisProducts.Products.tickets | smart-contracts/domains/mint/StreamMintTicketGate.sol:StreamMintTicketGate | retained-164 | MINT_TICKET_GATE |
| 14 | `address(p.commerce.fixedSale)` | StreamNativeFixedPriceSaleAdapter | CommerceProducts.Products.fixedSale | smart-contracts/domains/mint/StreamNativeFixedPriceSaleAdapter.sol:StreamNativeFixedPriceSaleAdapter | current-role-expansion | FIXED_PRICE_SALE_ADAPTER |
| 15 | `address(p.commerce.native.house)` | StreamNativeEnglishAuction | CommerceProducts.Products.native.house | smart-contracts/domains/auctions/StreamNativeEnglishAuction.sol:StreamNativeEnglishAuction | retained-164 | ENGLISH_AUCTION_HOUSE |
| 16 | `address(p.commerce.dutch)` | StreamNativeDutchSale | CommerceProducts.Products.dutch | smart-contracts/domains/mint/StreamNativeDutchSale.sol:StreamNativeDutchSale | current-role-expansion | DUTCH_AUCTION_ADAPTER |
| 17 | `address(p.commerce.privateSale)` | StreamPrivateSaleAdapter | CommerceProducts.Products.privateSale | smart-contracts/domains/mint/StreamPrivateSaleAdapter.sol:StreamPrivateSaleAdapter | current-role-expansion | PRIVATE_SALE_ADAPTER |
| 18 | `address(p.commerce.burn)` | StreamBurnMintGate | CommerceProducts.Products.burn | smart-contracts/domains/mint/StreamBurnMintGate.sol:StreamBurnMintGate | current-role-expansion | BURN_MINT_GATE |
| 19 | `address(p.independent.delegates)` | StreamDelegateRegistryGate | GenesisProducts.Products.delegates | smart-contracts/domains/mint/StreamDelegateRegistryGate.sol:StreamDelegateRegistryGate | retained-164 | DELEGATE_REGISTRY_GATE |
| 20 | `address(p.commerce.erc20)` | StreamERC20PrimarySettlementAdapter | CommerceProducts.Products.erc20 | smart-contracts/domains/revenue/StreamERC20PrimarySettlementAdapter.sol:StreamERC20PrimarySettlementAdapter | retained-164 | ERC20_PRIMARY_SETTLEMENT_ADAPTER |
| 21 | `address(f.artists)` | StreamArtistOnboardingRegistry | Foundation.artists | smart-contracts/domains/artist/StreamArtistOnboardingRegistry.sol:StreamArtistOnboardingRegistry | retained-164 | ARTIST_REGISTRY |
| 22 | `address(f.router)` | StreamMetadataRouter | Foundation.router | smart-contracts/domains/metadata/StreamMetadataRouter.sol:StreamMetadataRouter | retained-164 | METADATA_ROUTER |
| 23 | `address(p.rendering.renderer)` | StreamRendererV1 | StaticRendererPlan.Products.renderer | smart-contracts/domains/metadata/StreamRendererV1.sol:StreamRendererV1 | current-role-expansion | RENDERER_V1 |
| 24 | `address(f.metadata)` | StreamCollectionMetadataV1 | Foundation.metadata | smart-contracts/domains/metadata/StreamCollectionMetadataV1.sol:StreamCollectionMetadataV1 | retained-164 | COLLECTION_METADATA |
| 25 | `address(f.schemas)` | StreamSchemaRegistry | Foundation.schemas | smart-contracts/domains/metadata/StreamSchemaRegistry.sol:StreamSchemaRegistry | retained-164 | SCHEMA_REGISTRY |
| 26 | `address(p.independent.owners)` | StreamOwnerRecords | GenesisProducts.Products.owners | smart-contracts/domains/metadata/StreamOwnerRecords.sol:StreamOwnerRecords | retained-164 | OWNER_RECORDS |
| 27 | `address(p.records.preservation)` | StreamPreservationRecordsV1 | RecordProducts.Products.preservation | smart-contracts/domains/preservation/StreamPreservationRecordsV1.sol:StreamPreservationRecordsV1 | current-role-expansion | PRESERVATION_RECORDS |
| 28 | `address(p.independent.attestations)` | StreamCollectionAttestations | GenesisProducts.Products.attestations | smart-contracts/domains/metadata/StreamCollectionAttestations.sol:StreamCollectionAttestations | retained-164 | COLLECTION_ATTESTATIONS |
| 29 | `address(p.independent.views)` | StreamCollectionViews | GenesisProducts.Products.views | smart-contracts/domains/metadata/StreamCollectionViews.sol:StreamCollectionViews | retained-164 | COLLECTION_VIEWS |
| 30 | `address(f.entropy)` | StreamEntropyCoordinator | Foundation.entropy | smart-contracts/domains/entropy/StreamEntropyCoordinator.sol:StreamEntropyCoordinator | retained-164 | ENTROPY_COORDINATOR |
| 31 | `address(p.vrf)` | StreamEntropyProviderVRF | Products.vrf; primary provider | smart-contracts/domains/entropy/StreamEntropyProviderVRF.sol:StreamEntropyProviderVRF | retained-164 | ENTROPY_PROVIDER_VRF |
| 32 | `address(p.arrng)` | StreamEntropyProviderARRNG | Products.arrng; configured fallback provider | smart-contracts/domains/entropy/StreamEntropyProviderARRNG.sol:StreamEntropyProviderARRNG | current-role-expansion | ENTROPY_PROVIDER_FALLBACK |
| 33 | `address(f.finality)` | StreamArtworkFinalityRegistry | Foundation.finality | smart-contracts/domains/finality/StreamArtworkFinalityRegistry.sol:StreamArtworkFinalityRegistry | retained-164 | ARTWORK_FINALITY_REGISTRY |
| 34 | `address(p.continuity.entropy)` | StreamEntropyCoordinator | ContinuityProducts.entropy; distinct backup coordinator | smart-contracts/domains/entropy/StreamEntropyCoordinator.sol:StreamEntropyCoordinator | retained-164 | ENTROPY_COORDINATOR_FALLBACK |
| 35 | `address(p.continuity.manager)` | StreamMintManagerFallback | ContinuityProducts.manager | smart-contracts/domains/mint/StreamMintManagerFallback.sol:StreamMintManagerFallback | current-role-expansion | MINT_MANAGER_FALLBACK |
| 36 | `address(f.manifest)` | StreamSystemManifest | Foundation.manifest | smart-contracts/domains/governance/StreamSystemManifest.sol:StreamSystemManifest | retained-164 | STREAM_SYSTEM_MANIFEST |
| 37 | `address(f.coreFinality)` | StreamCoreFinalityAdapter | Foundation.coreFinality | smart-contracts/domains/finality/StreamCoreFinalityAdapter.sol:StreamCoreFinalityAdapter | retained-164 | STREAM_CORE_FINALITY_ADAPTER |

## Required current support companions

These concrete contracts are constructed or selected by the current deployment's `_support` rows and related typed deployment sources. Libraries are listed separately and are not standalone Safe targets.

| Product | Current support evidence | Roster disposition |
| --- | --- | --- |
| smart-contracts/core/StreamCore.sol:StreamCore | FINALITY_CORE_READS — _support row 17; CurrentFinalityGraph construction | retained 164 |
| smart-contracts/domains/artist/StreamArtistAcceptanceLifecycle.sol:StreamArtistAcceptanceLifecycle | ARTIST_OWNER[3] — _support row 8; SuiteDeployment owners[3] | retained 164 |
| smart-contracts/domains/artist/StreamArtistArchiveV2.sol:StreamArtistArchiveV2 | ARTIST_ARCHIVE — _support row 3 | retained 164 |
| smart-contracts/domains/artist/StreamArtistAttributionLifecycle.sol:StreamArtistAttributionLifecycle | ARTIST_OWNER[4] — _support row 9; SuiteDeployment owners[4] | retained 164 |
| smart-contracts/domains/artist/StreamArtistBindingLifecycle.sol:StreamArtistBindingLifecycle | ARTIST_OWNER[0] — _support row 5; SuiteDeployment owners[0] | retained 164 |
| smart-contracts/domains/artist/StreamArtistCollaboratorLifecycle.sol:StreamArtistCollaboratorLifecycle | ARTIST_OWNER[1] — _support row 6; SuiteDeployment owners[1] | retained 164 |
| smart-contracts/domains/artist/StreamArtistConsentFinalityLifecycle.sol:StreamArtistConsentFinalityLifecycle | ARTIST_OWNER[6] — _support row 11; SuiteDeployment owners[6] | retained 164 |
| smart-contracts/domains/artist/StreamArtistIdentityAuthority.sol:StreamArtistIdentityAuthority | ARTIST_OWNER[2] — _support row 7; split identity deployment | retained 164 |
| smart-contracts/domains/artist/StreamArtistOnboardingCoordinator.sol:StreamArtistOnboardingCoordinator | ARTIST_COORDINATOR — _support row 2; suite coordinator | retained 164 |
| smart-contracts/domains/artist/StreamArtistOnboardingRegistry.sol:StreamArtistOnboardingRegistry | FINALITY_SANCTION_READS — _support row 21; CurrentFinalityGraph construction | retained 164 |
| smart-contracts/domains/artist/StreamArtistPayoutLifecycle.sol:StreamArtistPayoutLifecycle | ARTIST_OWNER[5] — _support row 10; SuiteDeployment owners[5] | retained 164 |
| smart-contracts/domains/artist/StreamArtistRegistryValidatorBase.sol:StreamArtistRegistryValidatorBase | ARTIST_VALIDATOR — _support row 4 | retained 164 |
| smart-contracts/domains/entropy/StreamEntropyProviderVRF.sol:StreamEntropyProviderVRF | BACKUP_ENTROPY_PROVIDER — _support row 16; continuity provider | retained 164 |
| smart-contracts/domains/finality/StreamFinalityCurrentDiscovery.sol:StreamFinalityCurrentDiscovery | FINALITY_DISCOVERY — _support row 22; CurrentFinalityGraph Late.DISCOVERY | retained 164 |
| smart-contracts/domains/finality/StreamFinalityNativeEvidenceProvider.sol:StreamFinalityNativeEvidenceProvider | FINALITY_SCOPE_EVIDENCE — _support row 19; CurrentFinalityGraph Late.PROVIDER | retained 164 |
| smart-contracts/domains/governance/StreamRoleRegistry.sol:StreamRoleRegistry | ROLE_REGISTRY — _support row 0 | retained 164 |
| smart-contracts/domains/metadata/StreamCollectionMetadataV1.sol:StreamCollectionMetadataV1 | FINALITY_METADATA_READS — _support row 18; CurrentFinalityGraph construction | retained 164 |
| smart-contracts/domains/metadata/StreamGeneralAttestations.sol:StreamGeneralAttestations | GENERAL_ATTESTATIONS — _support row 15; record products | added current support |
| smart-contracts/domains/metadata/StreamRendererRegistryModule.sol:StreamRendererRegistryModule | RENDERER_REGISTRY — _support row 14; renderer plan product | added current support |
| smart-contracts/domains/metadata/StreamSchemaDocumentStore.sol:StreamSchemaDocumentStore | SCHEMA_DOCUMENT_STORE — _support row 12; StreamSchemaRegistry constructor | retained 164 |
| smart-contracts/domains/metadata/StreamStaticAttributionCompanion.sol:StreamStaticAttributionCompanion | STATIC_ATTRIBUTION — _support row 13; renderer plan product | added current support |
| smart-contracts/domains/preservation/StreamFinalityArtifactCoverage.sol:StreamFinalityArtifactCoverage | FINALITY_ARTIFACT_COVERAGE — _support row 20; CurrentFinalityGraph assemblyArtifact | retained 164 |
| smart-contracts/domains/revenue/StreamRoyaltyResolver.sol:StreamRoyaltyResolver | ROYALTY_RESOLVER — _support row 1 | retained 164 |

## Historical genesis profile labels

The original 37 profile entries are retained verbatim as historical labels for traceability only.

| Historical ID | Key | Implementation mode | Names | Approved aliases |
| ---: | --- | --- | --- | --- |
| 1 | STREAM_CORE | exact | StreamCore | — |
| 2 | GOVERNANCE_LAYER | manifest_equivalent | — | — |
| 3 | MODULE_REGISTRY | exact | StreamModuleRegistry | — |
| 4 | REVENUE_RESOLVER | exact | StreamRevenueResolver | — |
| 5 | SPLIT_FACTORY | exact | StreamSplitFactory | — |
| 6 | SPLIT_WALLET_IMPLEMENTATION | exact | StreamSplitWallet | — |
| 7 | REVENUE_ESCROW | exact | StreamRevenueEscrow | — |
| 8 | ASSET_POLICY_REGISTRY | exact | StreamAssetPolicyRegistry | — |
| 9 | PRIMARY_SALE_SETTLEMENT | exact | StreamPrimarySaleSettlement | — |
| 10 | CLAIM_ROUTER | exact | StreamClaimRouter | — |
| 11 | MINT_MANAGER | exact | StreamMintManager | — |
| 12 | MINT_LEDGER | exact | StreamMintLedger | — |
| 13 | MINT_TICKET_GATE | exact | StreamMintTicketGate | — |
| 14 | FIXED_PRICE_SALE_ADAPTER | exact | StreamFixedPriceSaleAdapter | — |
| 15 | ENGLISH_AUCTION_HOUSE | exact | StreamEnglishAuctionHouse | — |
| 16 | DUTCH_AUCTION_ADAPTER | exact | StreamDutchAuctionAdapter | — |
| 17 | PRIVATE_SALE_ADAPTER | exact | StreamPrivateSaleAdapter | — |
| 18 | BURN_MINT_GATE | exact | StreamBurnMintGate | — |
| 19 | DELEGATE_REGISTRY_GATE | exact | StreamDelegateRegistryGate | — |
| 20 | ERC20_PRIMARY_SETTLEMENT_ADAPTER | role_bound | — | — |
| 21 | ARTIST_REGISTRY | exact | StreamArtistRegistry | — |
| 22 | METADATA_ROUTER | exact | StreamMetadataRouter | — |
| 23 | RENDERER_V1 | exact | StreamRendererV1 | — |
| 24 | COLLECTION_METADATA | exact | StreamCollectionMetadata | — |
| 25 | SCHEMA_REGISTRY | exact | StreamSchemaRegistry | — |
| 26 | OWNER_RECORDS | exact | StreamOwnerRecords | — |
| 27 | PRESERVATION_RECORDS | exact | StreamPreservationRecords | — |
| 28 | COLLECTION_ATTESTATIONS | exact | StreamCollectionAttestations | — |
| 29 | COLLECTION_VIEWS | exact | StreamCollectionViews | — |
| 30 | ENTROPY_COORDINATOR | exact | StreamEntropyCoordinator | — |
| 31 | ENTROPY_PROVIDER_VRF | exact | StreamEntropyProviderVRF | — |
| 32 | ENTROPY_PROVIDER_FALLBACK | one_of | StreamEntropyProviderARRNG, StreamEntropyProviderPyth | — |
| 33 | ARTWORK_FINALITY_REGISTRY | exact | StreamArtworkFinalityRegistry | — |
| 34 | ENTROPY_COORDINATOR_FALLBACK | distinct_instance | StreamEntropyCoordinator | — |
| 35 | MINT_MANAGER_FALLBACK | distinct_instance | StreamMintManager | — |
| 36 | STREAM_SYSTEM_MANIFEST | exact | StreamSystemManifest | — |
| 37 | STREAM_CORE_FINALITY_ADAPTER | exact | StreamCoreFinalityAdapter | — |

## Anchored concrete products absent from the 164 roster

Candidates below are concrete source declarations referenced by current genesis role data, the current target catalog, current deployment/creation scripts, test-source identifiers, or the production contract catalog. Abstract contracts, interfaces, libraries and legacy-only sources are excluded. Test identifiers are not evidence that a test executed. A role/script/catalog reference establishes a candidate path, not a deployed address or successful Safe call. Exact anchors and compiler ABI details are in the machine report.

| Candidate FQN | ABI functions | Catalog evidence | Test source | Anchors | Deployment status |
| --- | --- | --- | ---: | --- | --- |
| smart-contracts/domains/access/StreamAdmins.sol:StreamAdmins | 35 (22 read, 13 state-changing) | release catalog | 25 test-source reference(s) | release-contract-catalog (smart-contracts/domains/access/StreamAdmins.sol) | not established; planning candidate has no instances |
| smart-contracts/domains/artist/StreamArtistRegistryV2.sol:StreamArtistRegistryV2 | 10 (10 read, 0 state-changing) | release catalog | 1 test-source reference(s) | release-contract-catalog (smart-contracts/domains/artist/StreamArtistRegistryV2.sol) | not established; planning candidate has no instances |
| smart-contracts/domains/artist/StreamCollectionArtistRegistry.sol:StreamCollectionArtistRegistry | 21 (18 read, 3 state-changing) | current target | 1 test-source reference(s) | current-contract-target (release-artifacts/current-contracts.json) | not established; planning candidate has no instances |
| smart-contracts/domains/dependencies/DependencyRegistry.sol:DependencyRegistry | 25 (20 read, 5 state-changing) | release catalog | 13 test-source reference(s) | release-contract-catalog (smart-contracts/domains/dependencies/DependencyRegistry.sol) | not established; planning candidate has no instances |
| smart-contracts/domains/entropy/StreamEntropyProviderARRNG.sol:StreamEntropyProviderARRNG | 52 (45 read, 7 state-changing) |  | 10 test-source reference(s) | genesis-role:ENTROPY_PROVIDER_FALLBACK (release-artifacts/genesis-deployment-profile.json)<br>current-deployment-construction:133 (script/current/StreamFullV1Candidate.sol) | not established; planning candidate has no instances |
| smart-contracts/domains/metadata/StreamC2PAReconciliation.sol:StreamC2PAReconciliation | 35 (32 read, 3 state-changing) |  | 3 test-source reference(s) | current-deployment-construction:63 (script/current/StreamFullV1C2PAProducts.sol) | not established; planning candidate has no instances |
| smart-contracts/domains/metadata/StreamCollectionMetadata.sol:StreamCollectionMetadata | 70 (59 read, 11 state-changing) | release catalog | 4 test-source reference(s) | genesis-role:COLLECTION_METADATA (release-artifacts/genesis-deployment-profile.json)<br>current-deployment-construction:27 (script/current/StreamFullV1PreservationPlan.sol)<br>release-contract-catalog (smart-contracts/domains/metadata/StreamCollectionMetadata.sol) | not established; planning candidate has no instances |
| smart-contracts/domains/metadata/StreamContractMetadata.sol:StreamContractMetadata | 16 (14 read, 2 state-changing) | release catalog | 3 test-source reference(s) | release-contract-catalog (smart-contracts/domains/metadata/StreamContractMetadata.sol) | not established; planning candidate has no instances |
| smart-contracts/domains/metadata/StreamGeneralAttestations.sol:StreamGeneralAttestations | 64 (58 read, 6 state-changing) |  | 7 test-source reference(s) | current-deployment-construction:80 (script/current/StreamFullV1RecordProducts.sol) | not established; planning candidate has no instances |
| smart-contracts/domains/metadata/StreamMetadataGovernanceAdapter.sol:StreamMetadataGovernanceAdapter | 24 (21 read, 3 state-changing) |  | 1 test-source reference(s) | current-deployment-construction:26 (script/current/StreamFullV1PreservationPlan.sol) | not established; planning candidate has no instances |
| smart-contracts/domains/metadata/StreamRendererRegistryModule.sol:StreamRendererRegistryModule | 61 (55 read, 6 state-changing) |  | 6 test-source reference(s) | current-deployment-construction:115 (script/current/StreamFullV1StaticRendererPlan.sol) | not established; planning candidate has no instances |
| smart-contracts/domains/metadata/StreamRendererV1.sol:StreamRendererV1 | 36 (35 read, 1 state-changing) |  | 19 test-source reference(s) | genesis-role:RENDERER_V1 (release-artifacts/genesis-deployment-profile.json)<br>current-deployment-construction:79 (script/current/StreamFullV1C2PAProducts.sol)<br>current-deployment-construction:85 (script/current/StreamFullV1StaticRendererPlan.sol) | not established; planning candidate has no instances |
| smart-contracts/domains/metadata/StreamStaticAttributionCompanion.sol:StreamStaticAttributionCompanion | 8 (8 read, 0 state-changing) |  | 5 test-source reference(s) | current-deployment-construction:60 (script/current/StreamFullV1C2PAProducts.sol)<br>current-deployment-construction:82 (script/current/StreamFullV1StaticRendererPlan.sol) | not established; planning candidate has no instances |
| smart-contracts/domains/metadata/StreamStaticC2PAAttributionCompanion.sol:StreamStaticC2PAAttributionCompanion | 23 (22 read, 1 state-changing) |  | 3 test-source reference(s) | current-deployment-construction:72 (script/current/StreamFullV1C2PAProducts.sol) | not established; planning candidate has no instances |
| smart-contracts/domains/mint/StreamBurnMintGate.sol:StreamBurnMintGate | 53 (45 read, 8 state-changing) |  | 7 test-source reference(s) | genesis-role:BURN_MINT_GATE (release-artifacts/genesis-deployment-profile.json)<br>current-deployment-construction:77 (script/current/StreamFullV1CommerceProducts.sol) | not established; planning candidate has no instances |
| smart-contracts/domains/mint/StreamMintManagerFallback.sol:StreamMintManagerFallback | 104 (80 read, 24 state-changing) |  | 4 test-source reference(s) | current-deployment-construction:86 (script/current/StreamFullV1ContinuityProducts.sol) | not established; planning candidate has no instances |
| smart-contracts/domains/mint/StreamMintModuleRegistry.sol:StreamMintModuleRegistry | 8 (5 read, 3 state-changing) | release catalog | 5 test-source reference(s) | release-contract-catalog (smart-contracts/domains/mint/StreamMintModuleRegistry.sol) | not established; planning candidate has no instances |
| smart-contracts/domains/mint/StreamNativeDutchSale.sol:StreamNativeDutchSale | 74 (58 read, 16 state-changing) |  | 6 test-source reference(s) | current-deployment-construction:75 (script/current/StreamFullV1CommerceProducts.sol) | not established; planning candidate has no instances |
| smart-contracts/domains/mint/StreamNativeFixedPriceSaleAdapter.sol:StreamNativeFixedPriceSaleAdapter | 81 (63 read, 18 state-changing) |  | 17 test-source reference(s) | current-deployment-construction:63 (script/current/StreamFullV1CommerceProducts.sol) | not established; planning candidate has no instances |
| smart-contracts/domains/mint/StreamPrivateSaleAdapter.sol:StreamPrivateSaleAdapter | 85 (52 read, 33 state-changing) |  | 7 test-source reference(s) | genesis-role:PRIVATE_SALE_ADAPTER (release-artifacts/genesis-deployment-profile.json)<br>current-deployment-construction:76 (script/current/StreamFullV1CommerceProducts.sol) | not established; planning candidate has no instances |
| smart-contracts/domains/preservation/StreamPreservationRecords.sol:StreamPreservationRecords | 25 (23 read, 2 state-changing) | release catalog | 3 test-source reference(s) | genesis-role:PRESERVATION_RECORDS (release-artifacts/genesis-deployment-profile.json)<br>current-deployment-construction:29 (script/current/StreamFullV1PreservationPlan.sol)<br>release-contract-catalog (smart-contracts/domains/preservation/StreamPreservationRecords.sol) | not established; planning candidate has no instances |
| smart-contracts/domains/preservation/StreamPreservationRecordsV1.sol:StreamPreservationRecordsV1 | 40 (36 read, 4 state-changing) |  | 2 test-source reference(s) | current-deployment-construction:69 (script/current/StreamFullV1RecordProducts.sol) | not established; planning candidate has no instances |
| smart-contracts/domains/revenue/StreamCuratorsPool.sol:StreamCuratorsPool | 20 (13 read, 7 state-changing) | release catalog | 4 test-source reference(s) | release-contract-catalog (smart-contracts/domains/revenue/StreamCuratorsPool.sol) | not established; planning candidate has no instances |

## Root decisions and assignment queue

1. The current full37 roster and source-backed companion set are selected explicitly above. Catalog-only candidates remain unpromoted.
2. Review each selector's caller class: user Safe, artist Safe, administrator/governance Safe, permissionless, protocol-only callback, or caller-sensitive read. For Executor-owned operations, identify the required current-action envelope.
3. Attach exact local-test or deployed instance bindings and per-selector success or intentional-rejection evidence. Do not infer runtime coverage from source presence or test references.
4. Preserve receive/fallback dispatch as explicit raw-call routes. ABI213 has three receive entries in the retained roster and more in anchored candidates.

## Reproduce

node scripts/generate-safe-call-surface-abi213.mjs ABI_INPUT ABI_OUTPUT SOURCE_BRIDGE --check

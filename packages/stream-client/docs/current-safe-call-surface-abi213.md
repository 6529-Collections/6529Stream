# Current Safe call-surface inventory (ABI213)

Source: a0f92ecae8414d36aa715ae1e37d5fb222c0db97. The compiler bridge authenticates all 4698 source blobs. The machine file contains exact current signatures, selectors, input/output types and source/ABI hashes for 164 retained supported products.
The selected set contains 6553 functions, 3 receive handlers and 0 fallback handlers. This is an ABI surface inventory, not Safe acceptance.

The prior 164-FQN roster is retained selection evidence, not blanket permission to omit later full-v1 products. Candidate products absent from it are separately listed below. The 6,840 compiler FQNs include interfaces, libraries, abstract contracts, tests and legacy products; presence alone does not make them independent supported Safe surfaces.
The deployment planning candidate is planning-only, has no instances and is not production-candidate/readiness evidence; no deployment receipt is included. Target/catalog membership means a committed catalog reference only. ABI read/state-changing counts and selectors describe callable shapes if deployed; they do not establish live reads, successful calls, test execution or deployment.

## Keep three questions separate

- ABI: signatures and receive/fallback handlers are enumerated from the current compiler output.
- Caller authorization: marked source-review-required. ABI entries do not encode role requirements, caller identity or protocol-only boundaries.
- Safe runtime: not joined in this static report. Existing source-scoped attestations remain in their historical evidence records; this report neither promotes nor discards them.

## Supported roster by source family

| Family | Contracts | Functions | View/pure | State-changing | Receive | Fallback |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| artist | 30 | 1579 | 1067 | 512 | 0 | 0 |
| auctions | 2 | 172 | 119 | 53 | 0 | 0 |
| core | 1 | 61 | 37 | 24 | 0 | 0 |
| entropy | 2 | 172 | 128 | 44 | 0 | 0 |
| finality | 47 | 1355 | 1266 | 89 | 0 | 0 |
| governance | 4 | 112 | 80 | 32 | 1 | 0 |
| metadata | 21 | 781 | 669 | 112 | 0 | 0 |
| mint | 12 | 656 | 531 | 125 | 0 | 0 |
| modules | 1 | 24 | 21 | 3 | 0 | 0 |
| preservation | 35 | 1272 | 944 | 328 | 0 | 0 |
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

## Receive and fallback

| FQN | Entry | Mutability | Payable |
| --- | --- | --- | --- |
| smart-contracts/domains/governance/StreamGovernanceActor.sol:StreamGovernanceActor | receive | payable | true |
| smart-contracts/domains/revenue/StreamRevenueEscrow.sol:StreamRevenueEscrow | receive | payable | true |
| smart-contracts/domains/revenue/StreamSplitWallet.sol:StreamSplitWallet | receive | payable | true |

## Genesis role coverage (37-role source profile)

Role names in the actual genesis profile resolve only to the retained roster, anchored candidate gaps, explicit exclusions, or an unresolved manifest-equivalent decision. This is role mapping evidence, not a deployment assertion.

| Role ID | Key | Named implementation/aliases | Roster status | ABI213 products |
| ---: | --- | --- | --- | --- |
| 1 | STREAM_CORE | StreamCore | covered-by-retained-164-roster | smart-contracts/core/StreamCore.sol:StreamCore (supported-by-retained-roster) |
| 2 | GOVERNANCE_LAYER | — | manifest-equivalent-needs-root-mapping | — |
| 3 | MODULE_REGISTRY | StreamModuleRegistry | covered-by-retained-164-roster | smart-contracts/domains/modules/StreamModuleRegistry.sol:StreamModuleRegistry (supported-by-retained-roster) |
| 4 | REVENUE_RESOLVER | StreamRevenueResolver | covered-by-retained-164-roster | smart-contracts/domains/revenue/StreamRevenueResolver.sol:StreamRevenueResolver (supported-by-retained-roster) |
| 5 | SPLIT_FACTORY | StreamSplitFactory | covered-by-retained-164-roster | smart-contracts/domains/revenue/StreamSplitFactory.sol:StreamSplitFactory (supported-by-retained-roster) |
| 6 | SPLIT_WALLET_IMPLEMENTATION | StreamSplitWallet | covered-by-retained-164-roster | smart-contracts/domains/revenue/StreamSplitWallet.sol:StreamSplitWallet (supported-by-retained-roster) |
| 7 | REVENUE_ESCROW | StreamRevenueEscrow | covered-by-retained-164-roster | smart-contracts/domains/revenue/StreamRevenueEscrow.sol:StreamRevenueEscrow (supported-by-retained-roster) |
| 8 | ASSET_POLICY_REGISTRY | StreamAssetPolicyRegistry | covered-by-retained-164-roster | smart-contracts/domains/revenue/StreamAssetPolicyRegistry.sol:StreamAssetPolicyRegistry (supported-by-retained-roster) |
| 9 | PRIMARY_SALE_SETTLEMENT | StreamPrimarySaleSettlement | covered-by-retained-164-roster | smart-contracts/domains/revenue/StreamPrimarySaleSettlement.sol:StreamPrimarySaleSettlement (supported-by-retained-roster) |
| 10 | CLAIM_ROUTER | StreamClaimRouter | covered-by-retained-164-roster | smart-contracts/domains/revenue/StreamClaimRouter.sol:StreamClaimRouter (supported-by-retained-roster) |
| 11 | MINT_MANAGER | StreamMintManager | covered-by-retained-164-roster | smart-contracts/domains/mint/StreamMintManager.sol:StreamMintManager (supported-by-retained-roster) |
| 12 | MINT_LEDGER | StreamMintLedger | covered-by-retained-164-roster | smart-contracts/domains/mint/StreamMintLedger.sol:StreamMintLedger (supported-by-retained-roster) |
| 13 | MINT_TICKET_GATE | StreamMintTicketGate | covered-by-retained-164-roster | smart-contracts/domains/mint/StreamMintTicketGate.sol:StreamMintTicketGate (supported-by-retained-roster) |
| 14 | FIXED_PRICE_SALE_ADAPTER | StreamFixedPriceSaleAdapter | covered-by-retained-164-roster | smart-contracts/domains/mint/StreamFixedPriceSaleAdapter.sol:StreamFixedPriceSaleAdapter (supported-by-retained-roster) |
| 15 | ENGLISH_AUCTION_HOUSE | StreamEnglishAuctionHouse | covered-by-retained-164-roster | smart-contracts/domains/auctions/StreamEnglishAuctionHouse.sol:StreamEnglishAuctionHouse (supported-by-retained-roster) |
| 16 | DUTCH_AUCTION_ADAPTER | StreamDutchAuctionAdapter | review-required | StreamDutchAuctionAdapter: — (no-matching-concrete-ABI213-product) |
| 17 | PRIVATE_SALE_ADAPTER | StreamPrivateSaleAdapter | contains-product-absent-from-164-roster | smart-contracts/domains/mint/StreamPrivateSaleAdapter.sol:StreamPrivateSaleAdapter (anchored-candidate-gap) |
| 18 | BURN_MINT_GATE | StreamBurnMintGate | contains-product-absent-from-164-roster | smart-contracts/domains/mint/StreamBurnMintGate.sol:StreamBurnMintGate (anchored-candidate-gap) |
| 19 | DELEGATE_REGISTRY_GATE | StreamDelegateRegistryGate | covered-by-retained-164-roster | smart-contracts/domains/mint/StreamDelegateRegistryGate.sol:StreamDelegateRegistryGate (supported-by-retained-roster) |
| 20 | ERC20_PRIMARY_SETTLEMENT_ADAPTER | — | review-required | — |
| 21 | ARTIST_REGISTRY | StreamArtistRegistry | review-required | StreamArtistRegistry: — (no-matching-concrete-ABI213-product) |
| 22 | METADATA_ROUTER | StreamMetadataRouter | covered-by-retained-164-roster | smart-contracts/domains/metadata/StreamMetadataRouter.sol:StreamMetadataRouter (supported-by-retained-roster) |
| 23 | RENDERER_V1 | StreamRendererV1 | contains-product-absent-from-164-roster | smart-contracts/domains/metadata/StreamRendererV1.sol:StreamRendererV1 (anchored-candidate-gap) |
| 24 | COLLECTION_METADATA | StreamCollectionMetadata | contains-product-absent-from-164-roster | smart-contracts/domains/metadata/StreamCollectionMetadata.sol:StreamCollectionMetadata (anchored-candidate-gap) |
| 25 | SCHEMA_REGISTRY | StreamSchemaRegistry | covered-by-retained-164-roster | smart-contracts/domains/metadata/StreamSchemaRegistry.sol:StreamSchemaRegistry (supported-by-retained-roster) |
| 26 | OWNER_RECORDS | StreamOwnerRecords | covered-by-retained-164-roster | smart-contracts/domains/metadata/StreamOwnerRecords.sol:StreamOwnerRecords (supported-by-retained-roster) |
| 27 | PRESERVATION_RECORDS | StreamPreservationRecords | contains-product-absent-from-164-roster | smart-contracts/domains/preservation/StreamPreservationRecords.sol:StreamPreservationRecords (anchored-candidate-gap) |
| 28 | COLLECTION_ATTESTATIONS | StreamCollectionAttestations | covered-by-retained-164-roster | smart-contracts/domains/metadata/StreamCollectionAttestations.sol:StreamCollectionAttestations (supported-by-retained-roster) |
| 29 | COLLECTION_VIEWS | StreamCollectionViews | covered-by-retained-164-roster | smart-contracts/domains/metadata/StreamCollectionViews.sol:StreamCollectionViews (supported-by-retained-roster) |
| 30 | ENTROPY_COORDINATOR | StreamEntropyCoordinator | covered-by-retained-164-roster | smart-contracts/domains/entropy/StreamEntropyCoordinator.sol:StreamEntropyCoordinator (supported-by-retained-roster) |
| 31 | ENTROPY_PROVIDER_VRF | StreamEntropyProviderVRF | covered-by-retained-164-roster | smart-contracts/domains/entropy/StreamEntropyProviderVRF.sol:StreamEntropyProviderVRF (supported-by-retained-roster) |
| 32 | ENTROPY_PROVIDER_FALLBACK | StreamEntropyProviderARRNG, StreamEntropyProviderPyth | candidate-gap-with-unresolved-alternative | smart-contracts/domains/entropy/StreamEntropyProviderARRNG.sol:StreamEntropyProviderARRNG (anchored-candidate-gap)<br>StreamEntropyProviderPyth: — (no-matching-concrete-ABI213-product) |
| 33 | ARTWORK_FINALITY_REGISTRY | StreamArtworkFinalityRegistry | covered-by-retained-164-roster | smart-contracts/domains/finality/StreamArtworkFinalityRegistry.sol:StreamArtworkFinalityRegistry (supported-by-retained-roster) |
| 34 | ENTROPY_COORDINATOR_FALLBACK | StreamEntropyCoordinator | covered-by-retained-164-roster | smart-contracts/domains/entropy/StreamEntropyCoordinator.sol:StreamEntropyCoordinator (supported-by-retained-roster) |
| 35 | MINT_MANAGER_FALLBACK | StreamMintManager | covered-by-retained-164-roster | smart-contracts/domains/mint/StreamMintManager.sol:StreamMintManager (supported-by-retained-roster) |
| 36 | STREAM_SYSTEM_MANIFEST | StreamSystemManifest | covered-by-retained-164-roster | smart-contracts/domains/governance/StreamSystemManifest.sol:StreamSystemManifest (supported-by-retained-roster) |
| 37 | STREAM_CORE_FINALITY_ADAPTER | StreamCoreFinalityAdapter | covered-by-retained-164-roster | smart-contracts/domains/finality/StreamCoreFinalityAdapter.sol:StreamCoreFinalityAdapter (supported-by-retained-roster) |

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

1. Confirm which anchored candidates become separately supported products. Prioritize those named in the 37 genesis roles and explicit current creation sources; keep catalog-only entries distinguishable.
2. Assign caller classes per selector: user Safe, artist Safe, administrator/governance Safe, permissionless, protocol-only callback, or caller-sensitive read. For Executor-owned operations, identify the required current-action envelope.
3. Attach exact local-test or deployed instance bindings and per-selector success or intentional-rejection evidence. Do not infer runtime coverage from source presence or test references.
4. Preserve receive/fallback dispatch as explicit raw-call routes. ABI213 has three receive entries in the retained roster and more in anchored candidates.

## Reproduce

node scripts/generate-safe-call-surface-abi213.mjs ABI_INPUT ABI_OUTPUT SOURCE_BRIDGE --check

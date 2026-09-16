# Retired registry-local finality references

This directory preserves the pre-canonical finality implementation and its 79
regressions. The contract copies come from artist branch commit
`d2e9e5e2d3e746dd5a77c798502fe5e335022360`. Only contract names, imports and an
explicit historical annotation change. All original test bodies remain intact.
These tests exercise their private historical copies. Passing them does not
establish current canonical finalization, current Core integration or release
readiness.

[ADR 0039](../../../../docs/adr/0039-canonical-finality-governance-and-evidence.md)
retires the registry-local schedule, veto, cancel, expiry and pending-action
map. The immutable canonical Executor now owns that lifecycle. Artist-bound
execution additionally selects and revalidates the exact sanction archive
artifact/completion proof. No old proof-free execution test is counted as that
new path.

The current [golden vectors](../../../unit/finality/StreamFinalityDomainsGolden.t.sol)
continue to call the actual current Registry, and the current
[adapter tests](../../../unit/finality/StreamCoreFinalityAdapter.t.sol) retain
all ten original granular-state tests with the explicit three-argument provider
binding, plus two provider identity/code-drift controls. Current
[retirement tests](../../../unit/finality/StreamFinalityRetiredLifecycle.t.sol)
assert the exact errors on all five retired Registry calls and both old preview
calls. The fixture's governance, metadata provider and archival dependency are
explicit constructor/read boundaries; they cannot authorize finalization.

## Current replacements and remaining gates

The identifiers below are local acceptance ledger items, not completed roadmap
claims. Each historical test is assigned one below. Preservation of a test in
this directory never closes its pending current gate.

| ID | Guarantee and current replacement | Evidence and remaining current gate |
| --- | --- | --- |
| F-CLOCK | Schedule delay, independent veto, cancel, expiry, replay and proposer authority move to the canonical Executor; Registry validates the exact class-2 per-call transition. | Current retirement tests cover the removal of the second clock. Witness unit tests cover typed context and proposer/role decoding. Actual Executor batch/Safe lifecycle with archive-proof finalization remains required. |
| F-CONSTRUCTOR | Current Registry preserves strict code/ERC165/canonical fixed-width adapter probes and adds immutable provider, Executor/roles and artifact pins. | Current hash fixture and sanction fixture deploy the actual constructor. Full current equivalents of every adversarial old constructor vector remain required. |
| F-MANIFEST | Content-addressed staging and permanent manifest/record preimages remain; current producer also validates actual schema, bytes and complete applicable scope evidence. | Current golden vectors retain independent permanent hash equations. Actual full producer/schema/coverage joins and staging negatives remain required in canonical finalization. |
| F-SCOPE | All five scope shapes, retained token identities, collection lifecycle/supply, freeze/burn and exact leaf-count requirements remain required. | Current granular Adapter tests cover scope and burned-token facts; Golden covers all subject domains. Current artifact-proof end-to-end finalization for every scope remains required. |
| F-COMPONENT | Component order, exact discovery projection, mode-specific floor, reference render and snapshot applicability remain required under the typed evidence provider. | Sanction preparation and focused owner tests cover the first ONCHAIN artist profile. Full applicable OFFCHAIN/HYBRID/platform and all-scope producer/finalization cases remain required. |
| F-SANCTION | Current artist-bound execution requires the exact association-valid saved sanction plus selected immutable archive proof and current coverage. | Current sanction tests cover actual signature, permanent history, replay, estate/rotation/contest distinctions and late Archive rollback. Actual archive-proof finalization and permissionless operation 13 remain required; platform policy is separate. |
| F-DIAGNOSTIC | Permanent stored records/components/routes and bounded historical verification remain independent of today's Core pointer selection. | Current stored-state tests cover all five record branches, ordered events, malformed dependencies, ranges and restoration. Full actual Registry populated-history/pointer-replacement and cold gas controls remain required. |
| F-GAS | Governed component-read caps and parent reserves replace the old fixed diagnostic budget; malformed/oversized return data must fail closed. | Witness and stored diagnostics tests cover bounded failures. Full actual current nested-cap/cold maximum and all old strict/preview parity scenarios remain required. |
| F-PREVIEW | A current preview must compose canonical Registry preparation, archive selection and separate Executor authority readiness. | The old callable selectors currently revert `FinalityPreviewLegacyLifecycleRetired` and return no misleading readiness tuple. Implementing the canonical current preview is explicitly pending; preserving the historical implementation here does not complete it. |

## Every preserved test

| Historical source | Test | Replacement / pending gate |
| --- | --- | --- |
| StreamArtworkFinalityComponentFloor.t.sol | `testBaseFloorEachMandatoryTypeOmittedReverts` | F-COMPONENT |
| StreamArtworkFinalityComponentFloor.t.sol | `testBaseFloorHoldsWithMandatoryDiscovery` | F-COMPONENT |
| StreamArtworkFinalityComponentFloor.t.sol | `testOffchainDoesNotRequireScriptComponents` | F-COMPONENT |
| StreamArtworkFinalityComponentFloor.t.sol | `testOnchainRequiresScriptComponents` | F-COMPONENT |
| StreamArtworkFinalityComponentFloor.t.sol | `testHybridRequiresScriptComponents` | F-COMPONENT |
| StreamArtworkFinalityComponentFloor.t.sol | `testScopedFinalityAppliesTheFloor` | F-COMPONENT |
| StreamArtworkFinalityComponentFloor.t.sol | `testDiscoveryExactMatchStillEnforcedOnTopOfFloor` | F-COMPONENT |
| StreamArtworkFinalityComponentFloor.t.sol | `testOnchainWithoutSnapshotManifestReverts` | F-COMPONENT |
| StreamArtworkFinalityComponentFloor.t.sol | `testHybridWithoutSnapshotManifestReverts` | F-COMPONENT |
| StreamArtworkFinalityComponentFloor.t.sol | `testOffchainUnaffectedBySnapshotGate` | F-COMPONENT |
| StreamArtworkFinalityComponentFloor.t.sol | `testInvalidMetadataModeThreeCollectionFailsClosed` | F-COMPONENT |
| StreamArtworkFinalityComponentFloor.t.sol | `testInvalidMetadataModeMaxCollectionFailsClosed` | F-COMPONENT |
| StreamArtworkFinalityComponentFloor.t.sol | `testInvalidMetadataModeThreeScopedFailsClosed` | F-COMPONENT |
| StreamArtworkFinalityComponentFloor.t.sol | `testInvalidMetadataModeMaxScopedFailsClosed` | F-COMPONENT |
| StreamArtworkFinalityFreeze.t.sol | `testScheduleRequiresFinalityAdminRole` | F-CLOCK |
| StreamArtworkFinalityFreeze.t.sol | `testScheduleEnforcesVetoFloorAndWindowFloor` | F-CLOCK |
| StreamArtworkFinalityFreeze.t.sol | `testScheduleRejectsZeroHashBadShapeAndMissingGuardian` | F-CLOCK |
| StreamArtworkFinalityFreeze.t.sol | `testScheduleRejectsDoubleSchedulingWhileLive` | F-CLOCK |
| StreamArtworkFinalityFreeze.t.sol | `testVetoOnlyGuardianOnlyDuringWindow` | F-CLOCK |
| StreamArtworkFinalityFreeze.t.sol | `testVetoWindowClosesAtNotBefore` | F-CLOCK |
| StreamArtworkFinalityFreeze.t.sol | `testVetoGuardianIsReResolvedAtVetoTime` | F-CLOCK |
| StreamArtworkFinalityFreeze.t.sol | `testCancelRequiresRoleAndLiveAction` | F-CLOCK |
| StreamArtworkFinalityFreeze.t.sol | `testExpiryMaterializationAndRestaging` | F-CLOCK |
| StreamArtworkFinalityFreeze.t.sol | `testScheduleAutoMaterializesOverdueAction` | F-CLOCK |
| StreamArtworkFinalityFreeze.t.sol | `testFinalizeRevertsWithoutStagedActionAndOutsideWindow` | F-CLOCK |
| StreamArtworkFinalityFreeze.t.sol | `testFinalizeRejectsStagedHashMismatch` | F-CLOCK |
| StreamArtworkFinalityFreeze.t.sol | `testExecutionBlockedIfGuardianClearedAfterScheduling` | F-CLOCK |
| StreamArtworkFinalityFreeze.t.sol | `testVetoedActionBlocksExecutionForever` | F-CLOCK |
| StreamArtworkFinalityFreeze.t.sol | `testFreezeModeLifecyclePerScope` | F-SCOPE |
| StreamArtworkFinalityFreeze.t.sol | `testScheduleBlockedOnceScopeFinalized` | F-CLOCK |
| StreamArtworkFinalityRegistry.t.sol | `testConstructorBindsActualCoreMetadataAdapterAndMandatoryDiscovery` | F-CONSTRUCTOR |
| StreamArtworkFinalityRegistry.t.sol | `testConstructorRejectsZeroMandatoryDiscovery` | F-CONSTRUCTOR |
| StreamArtworkFinalityRegistry.t.sol | `testConstructorRejectsCodelessMandatoryDiscovery` | F-CONSTRUCTOR |
| StreamArtworkFinalityRegistry.t.sol | `testConstructorRejectsAdapterCoreBindingMismatch` | F-CONSTRUCTOR |
| StreamArtworkFinalityRegistry.t.sol | `testConstructorRejectsAdapterMetadataBindingMismatch` | F-CONSTRUCTOR |
| StreamArtworkFinalityRegistry.t.sol | `testConstructorRejectsNonAdapterContract` | F-CONSTRUCTOR |
| StreamArtworkFinalityRegistry.t.sol | `testConstructorRequiresCanonicalERC165InvalidInterfaceResponse` | F-CONSTRUCTOR |
| StreamArtworkFinalityRegistry.t.sol | `testConstructorRejectsOversizedInterfaceAndAddressReturns` | F-CONSTRUCTOR |
| StreamArtworkFinalityRegistry.t.sol | `testConstructorRejectsNoncanonicalAddressReturn` | F-CONSTRUCTOR |
| StreamArtworkFinalityRegistry.t.sol | `testConstructorRejectsLegacyNoncanonicalAndSemanticAdapterPayloads` | F-CONSTRUCTOR |
| StreamArtworkFinalityRegistry.t.sol | `testManifestStagingContentAddressedAndBounded` | F-MANIFEST |
| StreamArtworkFinalityRegistry.t.sol | `testCollectionLifecycleArtistBound` | F-SANCTION |
| StreamArtworkFinalityRegistry.t.sol | `testCollectionLifecyclePlatformWorks` | F-SCOPE |
| StreamArtworkFinalityRegistry.t.sol | `testTokenScopeLifecycle` | F-SCOPE |
| StreamArtworkFinalityRegistry.t.sol | `testReleaseSeasonViewScopeLifecycles` | F-SCOPE |
| StreamArtworkFinalityRegistry.t.sol | `testScopedEntryRejectsCollectionScopeAndBadShapes` | F-SCOPE |
| StreamArtworkFinalityRegistry.t.sol | `testScopedGatesCollectionExistenceAndTokenLifecycle` | F-SCOPE |
| StreamArtworkFinalityRegistry.t.sol | `testTokenScopeRequiresExactlyOneLeaf` | F-SCOPE |
| StreamArtworkFinalityRegistry.t.sol | `testFinalizeRequiresFinalityAdmin` | F-CLOCK |
| StreamArtworkFinalityRegistry.t.sol | `testCollectionGatesExistenceClosedBurnBlockAndFreeze` | F-SCOPE |
| StreamArtworkFinalityRegistry.t.sol | `testCollectionStatusAndSupplyModeDomainsFailClosed` | F-SCOPE |
| StreamArtworkFinalityRegistry.t.sol | `testScopedCollectionStatusAndSupplyModeDomainsMatchExecutionAndPreview` | F-SCOPE |
| StreamArtworkFinalityRegistry.t.sol | `testContentRootGates` | F-SCOPE |
| StreamArtworkFinalityRegistry.t.sol | `testCollectionMintedSupplyAboveUint64FailsClosedWithoutDowncast` | F-SCOPE |
| StreamArtworkFinalityRegistry.t.sol | `testManifestGates` | F-MANIFEST |
| StreamArtworkFinalityRegistry.t.sol | `testComponentListShapeGates` | F-COMPONENT |
| StreamArtworkFinalityRegistry.t.sol | `testSanctionComponentGates` | F-SANCTION |
| StreamArtworkFinalityRegistry.t.sol | `testLiveComponentVerificationGates` | F-COMPONENT |
| StreamArtworkFinalityRegistry.t.sol | `testExpectedRecordHashMismatchBlocks` | F-MANIFEST |
| StreamArtworkFinalityRegistry.t.sol | `testMandatoryDiscoveryGate` | F-COMPONENT |
| StreamArtworkFinalityRegistry.t.sol | `testDiscoveryComponentAtExact224ByteReturnPassesExecutionAndPreview` | F-COMPONENT |
| StreamArtworkFinalityRegistry.t.sol | `testDiscoveryFactFailuresRejectExecutionAndFailClosedInPreview` | F-COMPONENT |
| StreamArtworkFinalityRegistry.t.sol | `testDiscoveryComponentAtFailuresRejectExecutionAndFailClosedInPreview` | F-COMPONENT |
| StreamArtworkFinalityRegistry.t.sol | `testSlowDiscoveryReadsPassStrictAndPreviewButExceedDiagnosticBudget` | F-GAS |
| StreamArtworkFinalityRegistry.t.sol | `testComponentReadBombsFailClosedAcrossStrictPreviewAndDiagnostics` | F-GAS |
| StreamArtworkFinalityRegistry.t.sol | `testSlowComponentReadPassesStrictAndPreviewButExceedsDiagnosticBudget` | F-GAS |
| StreamArtworkFinalityRegistry.t.sol | `testScopedDiscoveryComponentAtFailuresFailClosedInDiagnosticsAndPreview` | F-COMPONENT |
| StreamArtworkFinalityRegistry.t.sol | `testScopedDiscoveryReadFailuresRejectExecutionAndFailClosedInPreview` | F-COMPONENT |
| StreamArtworkFinalityRegistry.t.sol | `testVerifyFinalityDetectsPostFinalizationDiscoveryDrift` | F-DIAGNOSTIC |
| StreamArtworkFinalityRegistry.t.sol | `testVerifyScopedFinalityDetectsPostFinalizationDiscoveryDrift` | F-DIAGNOSTIC |
| StreamArtworkFinalityRegistry.t.sol | `testVerifyFinalityDiscoveryFailuresDegradeWithoutReverting` | F-DIAGNOSTIC |
| StreamArtworkFinalityRegistry.t.sol | `testVerifyFinalityGasBurningDiscoveryPreservesParentGas` | F-GAS |
| StreamArtworkFinalityRegistry.t.sol | `testVerifyFinalityDegradesWithoutReverting` | F-DIAGNOSTIC |
| StreamArtworkFinalityRegistry.t.sol | `testVerifyFinalityRangePaginatesAndDetectsDrift` | F-DIAGNOSTIC |
| StreamArtworkFinalityRegistry.t.sol | `testScopedDiagnosticsUseScopedReads` | F-DIAGNOSTIC |
| StreamArtworkFinalityRegistry.t.sol | `testCalldataCapBlocksOversizedSubmissions` | F-GAS |
| StreamArtworkFinalityRegistry.t.sol | `testPreviewParityAcrossGates` | F-PREVIEW |
| StreamArtworkFinalityRegistry.t.sol | `testScopedPreviewMatchesScopedExecution` | F-PREVIEW |
| StreamArtworkFinalityRegistry.t.sol | `testPreviewStagedFreezeMirrorsGuardianGate` | F-PREVIEW |

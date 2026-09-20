# Current full-v1 construction candidate

[`StreamFullV1Candidate`](../../script/current/StreamFullV1Candidate.sol) captures
37 distinct, nonzero original role products on one current Core, plus 25 required
direct support entries. It checks constructor relationships and retains runtime
hashes and byte lengths. A construction inventory is not an activated deployment,
a complete transitive dependency inventory, or release acceptance.

The source assembly starts from the completed original current foundation and
modular Artist/finality graph. It does not change the shared deployment script or
the generated genesis profile. Its semantic role bindings follow the current
integration plan; historical RC1 artifacts remain unchanged.

## Exact assembly sequence

1. Complete the existing current foundation and Artist/finality phases. Retain
   the actual Core, Executor, registry, primary Manager/Ledger, economic hosts,
   Artist Registry, Router, MetadataV1, SchemaRegistry/store, primary entropy,
   SystemManifest and original Core Finality Adapter. Complete the primary
   Manager's ordinary ownership handoff to the actual Executor.
2. Fill `Foundation` with those existing products. Use
   [`StreamFullV1CommerceProducts.deploy`](../../script/current/StreamFullV1CommerceProducts.sol)
   to construct the original recorder/English-auction pair, native fixed sale,
   native Dutch sale, private custody sale, native burn gate and ERC20 first-pull
   adapter. The primary Manager's prepared recorder must still be unbound.
   Auction and Dutch input recorder fields are zero; independent copies receive
   the newly constructed recorder. All remaining input bindings are checked.
3. Construct the six [independent products](../../script/current/StreamFullV1GenesisProducts.sol)
   and [current record products](current-record-genesis.md) on the same foundation.
   Keep both independent-class5 and General v2 attestation hosts.
4. Construct the [STATIC renderer, attribution companion and registry](current-static-genesis.md)
   using the two original planner stages. Supply the reviewed original target
   inventory; the helper's direct-target check is not transitive analysis.
5. `deployProviders` constructs the actual VRF and ARRNG adapters on the primary
   Coordinator from explicit upstream configurations. Actual deployment must
   supply reviewed service identities and funding/subscription configuration.
6. [`StreamFullV1ContinuityProducts.deploy`](../../script/current/StreamFullV1ContinuityProducts.sol)
   constructs the original full `StreamMintManagerFallback`, a distinct ordinary
   entropy Coordinator, and its own VRF adapter. It hands the new Manager's owner
   authority to the original Executor. The backup adapter's input Coordinator is
   zero and a copied configuration receives the new backup address.
7. Capture and retain `Foundation`, `Configuration`, `Products` and `Inventory`
   together with exact source, compiler/link inputs and constructor transactions.
   `constructionHash` binds the complete saved input/product tuple;
   `inventoryHash` commits the inventory, and `requireUnchanged` reconstructs it
   against the same saved products. Observed runtime hashes alone are not
   independent compiler or deployment authentication.

The shared launcher's integration seam is these seven steps after its original
graph completion and before product activation. The launcher owner must persist
the stage outputs and feed original governance plans with observed state. No
new bootstrap bypass, runtime replacement, temporary admin or extra Core pointer
is introduced.

## Role positions

Array positions are the following IDs minus one. The source builds this array
from typed products; callers cannot supply arbitrary role rows or placeholders.

| IDs | Original products |
| --- | --- |
| 1–5 | Core; Executor with RoleRegistry support; ModuleRegistry; RevenueResolver with RoyaltyResolver support; SplitFactory |
| 6–10 | Factory's actual version4 wallet implementation; RevenueEscrow; AssetPolicyRegistry; PrimarySaleSettlement; ClaimRouter |
| 11–15 | Primary Manager; canonical Ledger; MintTicketGate; NativeFixedPriceSaleAdapter; NativeEnglishAuction |
| 16–20 | NativeDutchSale; PrivateSaleAdapter; BurnMintGate; DelegateRegistryGate; ERC20PrimarySettlementAdapter |
| 21–25 | Original modular Artist Registry and required suite; MetadataRouter; RendererV1 and required companions; CollectionMetadataV1; SchemaRegistry/store |
| 26–30 | OwnerRecords; full-byte PreservationRecordsV1; independent CollectionAttestations plus General v2; CollectionViews; primary EntropyCoordinator |
| 31–35 | Actual VRF adapter; actual ARRNG adapter; ArtworkFinalityRegistry; distinct ordinary backup EntropyCoordinator; distinct ordinary/recovery MintManagerFallback |
| 36–37 | SystemManifest; original CoreFinalityAdapter |

Role6 is read from the original factory's `splitWalletImplementation()` and
matching runtime-hash getter. The helper checks version4, original factory
binding, locked initialization and zero profile ID. It never deploys an unused
wallet implementation. The current construction test additionally checks the
actual profile wallet's 52-byte clone runtime and deterministic factory address.

The support entries retain the actual RoleRegistry, RoyaltyResolver, Artist
Coordinator/archive/validator/seven owners, schema store, STATIC attribution and
renderer registry, General v2, backup-specific VRF adapter, six direct finality
dependencies, and the linked General payload and SnapshotManifestBytes libraries.
The latter two must match the new General v2 native link references in final
acceptance. This direct inventory does not replace full compiler closure or
transitive finality/renderer analysis.

## Activation remains explicit

Construction does not register all modules, configure sale phases, grant writers,
bind the shared recorder, publish the canonical schema catalog or admit a STATIC
version. Consume the existing catalog/registration/manifest-tail planners, exact
Artist consent, phase execution, asset/runtime admission and role procedures.
Role17 here is the original secondary custody private sale; additional primary
offer, curated and ERC20 burn products remain separately inventoried feature
products. Having 37 role addresses does not prove complete full-v1 behavior.

For the Manager reserve, use `mintConfiguration` with the actual common recorder
and the original [fallback plan](../../script/current/StreamMintFallbackPlan.sol).
Register the standing Manager, admit its ordinary operating and class3 recovery
policies, grant its actual Ledger writer and bind the same original recorder to
both Managers. Include the Ledger import and class0 retirement policies. Execute
`retirementClassificationCall` as its isolated delayed class1 self-call before
operational exposure; a catalog row alone does not establish that classifier.
The actual snapshot/import/retirement sequence remains required before cutover.

For the entropy reserve, use the original
[continuity plan](entropy-coordinator-continuity.md). Register both backup and
backup-specific provider, admit/activate the provider, configure actual collection
and reveal policies and retain the historical subject inventory. It is an
ordinary configured backup, not a cheaper registration-only mode.
`configuredReserveCheckpoint` checks the original standing Manager reserve,
shared recorder/writer, retirement classifier, ACTIVE Coordinator and supplied
configured collection/provider tuples. Complete catalog-policy evidence,
historical inventory completeness and migration execution are separate gates.

## Evidence boundary

[`StreamCurrentFullV1CandidateTest`](../../test/current/StreamCurrentFullV1Candidate.t.sol)
authors six constructor/inventory cases over the actual current graph. They
cover all role/companion identities, the real wallet singleton and clone,
distinct fallback products, honest unconfigured-reserve refusal, missing/reused
product refusal, changed admission metadata and runtime drift. Only external VRF, ARRNG and delegation
services and the inherited upstream entropy service are doubles. STATIC document
commitments are explicit fixture values and no renderer version is admitted.

The source base `2e0c3443` includes the 24,576-byte MetadataV1 and General v2
successors. The record cohort adds a current Safe-signed General v2 three-chunk
case. Native execution of these authored cohorts remains pending. The separate
`requireRuntimeSizes` helper rejects recorded oversized role/support runtimes;
it does not cover initcode or the complete linked-library graph. No source ABI
check, role count or scoped producer pass establishes full gas, size, fuzz,
stateful, CI, audit or testnet acceptance.

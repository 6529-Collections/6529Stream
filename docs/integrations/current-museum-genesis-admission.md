# Current Museum genesis document admission

This authored recipe joins the exact Museum source plan to the original
SchemaRegistry/DocumentStore, current full-v1 construction fixture and delayed
2-of-2 Safe governance. Native execution is pending. It is not a complete
37-product activation, release manifest, JSON conformance result or deployment
receipt.

## Reviewed input and original authority

The [canonical source plan](../../schemas/museum/genesis/admission-plan.json)
contains 51 documents, 78 ordered chunk occurrences and 401,717 source bytes.
Its exact 62,014-byte artifact has SHA-256
`34d563faddc07919be05b8ede917b955b0d2430fb7cf1c16273dc1d4ba2aa700`.
The [test loader](../../test/helpers/StreamMuseumGenesisSource.sol) pins this
artifact and checks every source file's transport hash, content hash and length.
Changing the catalog requires review and an explicit loader update.

RAW_BYTES is admitted first, then RFC8785_JCS. Each later definition keeps its
supplied canonicalization, kind, predecessor, URI and chunk order. A file being
canonical JSON does not change its declared RAW_BYTES assignment. The largest
document, STREAM_OBJECT_DOSSIER_V1, keeps all 34,843 bytes in five chunks.

The [planner](../../script/current/StreamSchemaAdmissionPlan.sol) accepts a
reviewed inventory and retains its source-plan hash, chain, registry, store,
Executor and runtime hashes. `capture` rejects duplicate document names, more
than 64 documents and chunk layouts outside the original registry's limits.
The 64-document bound is a planner inventory limit, not a new registry rule.
Save and independently review `planHash` before using that plan.

1. Call `publish` with the exact source bytes for a document. It uses the
   original permissionless store, checks every ordered chunk and reads it back.
   Publication grants no schema, record or writer authority.
2. Call `next` for that document. Missing canonicalization dependencies fail
   through the original registry's transition validation. A new document yields
   one original class-1 registration call; an identical ACTIVE document yields
   an empty batch.
3. Append the reviewed publication using the existing
   [activation planner](../../script/current/StreamFullV1ActivationPlan.sol),
   retain the exact governance stage, schedule through the threshold Safe and
   wait the original Executor delay before execution.
4. Repeat in source-plan order, then call `requireRegistered`. Retain actual
   chain, block and transaction identities separately for a live deployment.

Reuse checks the entire stored specification, declaration hash, ordered chunk
list, original store bytes and reconstructed document bytes. A different
definition under the same name, retired status, changed chain/runtime, or
corrupt chunk blocks reuse. Store deduplication never removes a repeated chunk
occurrence from a document. The plan hash binds inputs; it does not authenticate
their publisher or authorize governance.

## Authored current-graph cases

The [current test](../../test/current/StreamCurrentMuseumGenesisAdmission.t.sol)
constructs the original 37-role candidate, installs the original Safe 1.4.1
2-of-2 root, and admits the two exact schema selectors into the fixture's
operating policy catalog. Registration stages include the actual SystemManifest
tail. Each successful admission checks its original event and Executor action
identity. The publication payload is explicitly a local fixture; its discovery
hashes are not a regenerated release catalog.

Eleven cases cover:

- All 51 source documents, all ordered chunks, full byte reconstruction and
  exact ACTIVE reruns without additional admissions.
- Permissionless upload, rejected direct registration and enforced Safe delay.
- RAW/JCS bootstrap dependency order.
- Changed source bytes and reordered chunk hashes.
- Changed retained metadata and chain.
- Conflicting existing definition and retired-document refusal.
- Corrupt stored bytes.
- Changed registry runtime, duplicate names and partial nonfinal chunks.
- Repeated identical chunks with one accepted store pointer and two retained
  document occurrences; this extra document is explicitly a synthetic fixture.

The full current fixture still enforces each production contract's size limit.
No cap, authority, calldata allowance or creation limit is relaxed. No native
test, gas, bytecode-size, fuzz or invariant pass is claimed by the ABI check.
Current graph size and source prerequisites must pass before this recipe can
produce runtime acceptance evidence. External entropy, VRF, ARRNG and delegation
services in the construction fixture remain explicit doubles.

## Full-v1 source audit boundary

This audit used integration source
`a86febaa49776e2700544b456c04edb2b8637c48`. Role numbers follow the
[37-product construction inventory](current-full-v1-candidate.md). Existing
recipes are source coverage, not proof that their current versions pass or that
their union forms one fully activated deployment.

| Original roles | Existing recipe or concrete gap |
| --- | --- |
| 1 Core, 2 Executor, 3 ModuleRegistry | [Safe flows](../../test/current/StreamCurrentSafe.t.sol), [Safe batch](../../test/current/StreamCurrentSafeBatch.t.sol), and [21-row activation](../../test/current/StreamCurrentFullV1Activation.t.sol) |
| 4 Resolver, 5 Factory, 6 wallet implementation, 7 Escrow, 8 AssetPolicy | [Safe commerce/revenue](../../test/current/StreamCurrentSafe.t.sol), [dynamic royalty commerce](../../test/current/StreamCurrentDynamicRoyaltyCommerce.t.sol), and [candidate singleton/clone checks](../../test/current/StreamCurrentFullV1Candidate.t.sol) |
| 9 primary recorder, 14 fixed sale, 15 English, 16 Dutch, 17 secondary private sale, 18 Burn, 19 Delegate, 20 ERC20 settlement | [English](../../test/current/StreamCurrentNativeEnglishAuction.t.sol), [Dutch](../../test/current/StreamCurrentDutchSale.t.sol), [private/delegation](../../test/current/StreamCurrentPrivateSaleDelegation.t.sol), [burn](../../test/current/StreamCurrentBurnMint.t.sol), [ERC20](../../test/current/StreamCurrentERC20Recording.t.sol), and [commerce activation](current-full-v1-activation.md); these do not substitute for additional offer/curated products |
| 10 ClaimRouter, 12 Ledger, 13 MintTicketGate | [Original genesis products](../../test/current/StreamCurrentFullV1GenesisProducts.t.sol), [tickets](../../test/current/StreamCurrentMintTicket.t.sol) and [mint setup](../../test/current/StreamCurrentMintSetup.t.sol) |
| 11 primary Manager, 34 backup coordinator, 35 fallback Manager | [Fallback](../../test/current/StreamCurrentMintFallback.t.sol), [incident continuity](../../test/current/StreamCurrentMintFallbackIncident.t.sol), and original separate-coordinator activation |
| 21 ArtistRegistry and original companions | [Safe Artist flows](../../test/current/StreamCurrentSafe.t.sol) and [C2PA composition](../../test/current/StreamCurrentC2PAComposition.t.sol); the C2PA retained read set explicitly remains partial |
| 22 MetadataRouter, 23 STATIC renderer/attribution/registry, 24 MetadataV1 | [STATIC genesis](../../test/current/StreamCurrentStaticGenesis.t.sol) and C2PA composition; complete supplied analysis, original authority inventory, goldens and full publication capacity remain separate acceptance work |
| 25 SchemaRegistry/Store | Previous activation covered a synthetic 9,000-byte document. This batch adds the exact 51-document source plan through original Safe/Executor calls |
| 26 OwnerRecords, 27 PreservationRecords, 28 Independent records/GeneralV2, 29 CollectionViews | [Owner Museum capture](../../test/current/StreamCurrentOwnerMuseumCapture.t.sol) and [genesis products](../../test/current/StreamCurrentFullV1GenesisProducts.t.sol); canonical schema admission alone does not grant families/types or prove complete institutional records |
| 30 primary entropy, 31 VRF, 32 ARRNG | [Entropy continuity](../../test/current/StreamCurrentEntropyContinuity.t.sol), [lifecycle](../../test/current/StreamCurrentEntropyLifecyclePlan.t.sol), and [ARRNG](../../test/current/StreamCurrentARRNG.t.sol); live upstream funding/callback acceptance remains distinct |
| 33 ArtworkFinality, 36 SystemManifest, 37 CoreFinalityAdapter | [Original native finality assembly](../../test/current/StreamNativeFinalityAssembly.t.sol) and current graph fixtures; complete post-activation release inventory and cross-domain finality remain separate |

The next bounded runtime slice is this eleven-case cohort after the integrator
freezes matching source and all required original products pass construction
and size checks. Retain compiler inputs, product artifacts, actual Safe actions,
failures and test receipts together. Then join the admitted definitions with
reviewed family/type permissions and actual typed record producers. Complete
STATIC admission, live services, finality, combined fuzz/invariants, gas, CI and
new testnet evidence still belong to whole-system acceptance. Preserve immutable
RC1 artifacts and previously retained failures.

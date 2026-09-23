# Current full-v1 activation plans

The [activation planner](../../script/current/StreamFullV1ActivationPlan.sol)
builds original governance calls for the retained
[37-role construction](current-full-v1-candidate.md). It takes the exact
`Foundation`, `Configuration`, `Products` and saved `inventoryHash`. It checks
their current runtimes, constructor bindings, ownership and original sealed
SystemManifest before preparing an action. It does not broadcast transactions.

A complete construction inventory, a planned batch, an executed action and an
activated product are separate observations. This helper does **not** certify
an activated 37-role deployment or release readiness. Native execution, complete
profile configuration, runtime/link provenance, cold gas measurements and the
root-owned launcher remain separate work.

## Admission inventory

`registrations` derives 21 original module records:

| Group | Rows | Meaning |
| --- | ---: | --- |
| Independent products | 5 | Ticket/delegation gates, owner records, independent attestations, views |
| Record products | 2 | Full-byte PreservationV1 and GeneralV2 |
| STATIC products | 2 | RendererV1 and RendererRegistryModule; renderer-version admission is later |
| Commerce | 7 | Recorder, English, native fixed, Dutch, secondary private custody, burn gate, ERC20 primary settlement |
| Continuity | 3 | Original fallback Manager, backup Coordinator, backup-specific VRF adapter |
| Primary entropy adapters | 2 | Original VRF and ARRNG products bound to the primary Coordinator |

ClaimRouter, the actual factory wallet implementation and the STATIC attribution
reader retain their construction-inventory identities. They receive no invented
module interface or pointer kind. Original foundation registrations are retained.
The private custody row is the secondary product, not a substitute for the
separate primary offer, curated or ERC20 sale products.

`RegistrationInputs` contains explicit proposed gate/read/commerce/provider
budgets and manifests for the four commerce products without immutable manifest
getters. Enabled fixed/Dutch/private delegation requires the original derived
delegation manifest hash. Burn/provider manifests come from the actual hosts;
continuity budgets and manifests remain bound to their construction configuration.
No test value is a measured launch default. Retain these inputs with the plan.

`pendingRegistrations` skips only exact ACTIVE records. Changed type, version,
interface, budget, runtime pin, deployment hash, module manifest or URI rejects;
deprecated/revoked records require their separately reviewed lifecycle route.
`registrationBatch` takes a caller-selected bound of 1–21 pending rows, derives
the current registry-chain transitions and appends the original same-class
SystemManifest publication. Select smaller chunks when calldata or measured
transaction gas requires them. The authored fixture uses seven short-URI rows
per stage; this is not a maximum-URI or transaction-capacity proof.

## Catalog and saved stages

The [policy planner](../../script/current/StreamFullV1ActivationPolicies.sol)
collects 62 sorted, unique, exact-target intents from the original product
planners and existing entrypoints. These include product gas raises, record and
renderer admission, reserve configuration/import/recovery, primary/backup entropy
administration and the required governance/manifest calls. It preserves the
original class-0 writer retirement and class-3 fallback recovery semantics.
It does not supply every foundation administration row or every optional sale
feature row. Direct Artist, owner, attestor and role-based operations retain
their original authorization rules.

Supply the independently verified retained genesis and executed-extension
catalog entries to `additions` or `catalogInventory`. Compatible existing keys
retain their original profile hashes. Conflicting code/value policy or duplicate
known keys reject. The Executor exposes its aggregate catalog commitment, not
enumerable historical entries: this offchain input is not authenticated merely
because the helper accepts it. Original extension and scheduling checks remain
authoritative.

Use `StreamGovernanceCatalogStagePlan.nextBatch` for each at-most-64-row extension
and its mandatory class-3 manifest tail. Observe each executed prefix before
building the next chunk. Finish actions scheduled under the old catalog before
extending it; an extension invalidates that catalog snapshot.

For every batch:

1. Supply retained manifest payload bytes and the intended complete discovery
   hashes. The helper calculates the publication transition from the actual
   current revision; it cannot authenticate the payload's prose or acceptance
   claims. Registration-only stages preserve selected module addresses.
2. Build `StreamGovernanceStagePlan.Plan`, retain its exact ABI encoding and hash,
   and publish the exact calldata.
3. Submit its scheduling call through the actual authorized governance root,
   including threshold Safe signatures where applicable. Observe the action ID
   from the receipt and verify it against the saved plan.
4. Wait the real minimum delay. Execute the saved action and perform the specific
   registry, binding, provider or document readbacks below. Local test time
   advancement does not provide a testnet shortcut.

`withManifestTail` supports the non-pointer intents in this helper. It rejects
Core, Executor and manifest intents: pointer selection needs the original
predicted-address transition planner, and classifier self-calls must be isolated.
It never selects either reserve or rewrites the foundation's selected pointers.

## Binding and provider sequence

After the catalog and exact module registrations have executed:

| Stage | Original prerequisite and readback |
| --- | --- |
| `recorderCredit` | ACTIVE original recorder; read escrow `creditProducer` enabled with its actual runtime hash |
| `custodyBinding` | Original recorder/house admission transition; read the one-way canonical custody house |
| `managerBinding(false)` | Admitted recorder and enabled escrow producer, unbound primary owned by Executor; read primary recorder address/hash/time/revision |
| `managerBinding(true)` | ACTIVE reserve Manager, original recorder admission and escrow producer; read the distinct reserve's binding to that same recorder |
| `reserveWriter` | ACTIVE reserve and no permanent retirement; read the original Ledger writer grant |
| `retirementClassifier` | Isolated class-1 Executor self-call; read the enabled Ledger retirement selector and exact Ledger runtime pin |
| `providerClassifier` | Four separate optional preparation actions for primary/backup deprecate/revoke selectors; each is an isolated class-1 self-call, in addition to its class-0 catalog row |
| `providerActivation` | ACTIVE registry records for the exact Coordinator and provider; read original provider lifecycle state/hash/revision/action ID |
| `collectionConfiguration` | Existing mutable collection, unlocked entropy configuration and ACTIVE exact provider; read the actual collection/provider/salt/public/timeout tuple |
| `revealConfiguration` | Observe that collection tuple first; the caller must currently hold `ROLE_ENTROPY_ADMIN`, while the policy names `ROLE_ENTROPY_REVEAL_OWNER`; read the declared reveal tuple |

Provider indices are fixed: `0` is primary VRF, `1` primary ARRNG, `2` backup VRF
on the backup Coordinator. A primary provider cannot stand in for the backup
adapter. Provider registration/activation does not fund or configure the upstream
VRF subscription, enroll its consumer, fund ARRNG requests or prove callbacks.
Those actual external-service operations and tests remain required.

The Ledger writer grant is revocable until permanent retirement; recorder/house
bindings are one-way. Classification does not retire the primary writer or any
provider. `StreamMintFallbackPlan.requireReserveReady` and
`StreamFullV1ContinuityProducts.configuredReserveCheckpoint` supply stronger
observed reserve checks after these stages. They still do not prove a complete
historical inventory, completed migration or full operating-policy coverage.

## Supplied Museum and STATIC stages

`schemaDocument` accepts a supplied original `DocumentSpec` and ordered chunk
hashes after exact bytes have been published to the original document store.
It uses the registry's actual registration transition. Museum owns the canonical
29-schema catalog, additional typed profiles/catalogs, names, canonicalization
choices, exact bytes and admission-plan hashes. Preserve its declared RAW/JCS
choices. Documents over 8,192 bytes require ordered chunks; every non-final chunk
uses the original store's full chunk size. Bootstrap RAW_BYTES and canonicalization
documents must precede documents that reference them. A prospective admission
plan supplies no executed registration evidence.

`recordType` and `familyWriter` accept explicit reviewed type/family/class and
scope/writer inputs. Their original MetadataV1 transitions retain the authority
boundaries; module registration grants no record-writing privilege. Do not infer
institutional, curator, estate or preservation grants from a schema name.

`staticAdmission` accepts C's supplied registration and read inventory, then
uses the original RendererRegistry transition and target-side golden checks.
Construction, a renderer manifest hash or fixture output cannot replace retained
analysis documents, complete transitive reads, reviewed goldens, version
admission and subsequent collection selection. The fixture's partial direct
inventory remains explicitly outside that acceptance claim.

## Authored validation scope

The [current Safe cohort](../../test/current/StreamCurrentFullV1Activation.t.sol)
has 11 authored cases: sorted inventory/policies, actual delayed Safe module
admission, one-way bindings/writer/classifier, missing prerequisites, exact
provider pairs and backup configuration, conflicting registrations, atomic
manifest-tail failure, stale registration plans, retained-policy/construction
drift, ordered two-chunk document retention and rejection of absent STATIC
evidence. All original products share the current graph. Only the inherited
upstream entropy service and external VRF/ARRNG/delegation services are doubles.
The 9,000-byte document is explicitly opaque fixture data, not a Museum schema.

This source batch is based on `4f479a3c`. ABI/type checking and native acceptance
are separate: no new native/codegen/runtime/size/gas result is claimed here.
The new fixture preserves that candidate's constructor recipe while root owns
shared fixture/launcher integration. Later mint grace selectors and C2PA STATIC
composition must be incorporated from their frozen source handoffs, not guessed.

# Native collection finality provider

The developing `StreamFinalityNativeEvidenceProvider` composes the ten original
finality inputs for an artist-bound ONCHAIN COLLECTION. It implements the typed
provider interfaces over the actual generic MetadataV1 host. It does not extend
this first profile to TOKEN, RELEASE, SEASON, VIEW, HYBRID or platform declarations;
those remain full-v1 delivery requirements.

## Implementation and acceptance

The concrete provider, source derivation, local metadata facts and Registry
prepared-input dispatch are implemented. The independently reviewed 27-case
cohort passes both compiler modes, with one 256-input fuzz property and an actual
two-owner Safe. Source derivation tests use explicit typed producer boundaries. They are not the complete eight-producer assembly, finalization
ceremony, deployed graph, or transaction-capacity acceptance. Producer runtime and integration acceptance are tracked separately. Full inventory
and bundle runtime validation remain pending; WORK/RIGHTS seals have focused
builder evidence and still require integration with this provider.
See [full-v1 delivery](../../ops/V1_DELIVERY.md) for current integration evidence.

## Fixed graph

The constructor takes `StreamFinalityNativeProviderReads.Config`. Its parallel
`targets` and `codeHashes` arrays use these positions:

| Positions | Fixed dependencies, in order |
| --- | --- |
| 0–5 | Core, generic MetadataV1, Router, scope membership, SchemaRegistry, document Store |
| 6–11 | ContentLeafManifest, content checkpoint, Snapshots, reference publisher, entropy factory, Artist |
| 12–17 | Original Finality Registry, Discovery, Core adapter, WORK selector, RIGHTS selector, conservation selector |
| 18–21 | Render-critical inventory, bundle archive coverage, onchain artifact coverage, external artifact coverage |

The late graph is stored once in constructor-only storage. Its expected addresses
and nonzero runtime hashes must be supplied before deployment; there is no binding
setter. Every operative complete-input call requires real matching runtimes,
reciprocal bindings and current Router/Metadata/Registry selection. Constructor
success does not establish readiness. Predicted addresses require an independently
verified deployment order; storage pins do not solve a CREATE2 initcode cycle.

The inventory's complete configuration is canonically decoded and joined to all
shared source addresses and hashes, including the original Artist. Its full
configuration hash is also pinned. Snapshot dependencies must use the same leaf
manifest, checkpoint and membership host. Snapshot and entropy discovery must
share the original coordinator inventory.

## Independent manifest

`inputManifestBytes(scope)` derives the exact independent manifest before it is
staged. Current component states, original inputs, archival coverage and the
native terminal policy must already be satisfied. Store the resulting exact bytes
in the schema Store and original Registry before calling
`requireFinalityScopeInputs(scope, manifestContentHash)`.

The public read validates all nine complete component states and their current
route identities, derives the actual ten inputs and validates the identical
registered manifest in both stores. The scope-input commitment binds the actual
generic metadata address, never the provider address. The document's own hash,
artist sanction and sanction signature are excluded from independent preimages;
finalization validates their original archives separately.

The complete inventory's current-source validation runs once per derivation.
Bundle coverage must match that exact plan, render-critical hash and item count.
Original root, snapshot and reference headers are projected from the same fixed
producers and must equal the inventory's authenticated originals. Snapshot
`manifestHash` and reference `payloadHash` are document hashes; their record hashes
are different inputs. The root's schema result is the leaf schema.

Core closure, burn blocking, configuration freeze and exact minted leaf count are
checked independently of the inventory. A nonzero archive hash cannot supply
those facts.

## Registry preparation and Safe

The optional `IStreamFinalityPreparedScopeEvidence` method accepts the component
array only from the original Registry at its constructor-pinned runtime. Both
Registry call sites first validate every complete component state and the current
routes in the same call. The provider checks current routes again, removes only
the actual artist-sanction family, and independently validates the same sources,
coverage and manifest. Public calls perform their own full component validation.
There is no persistent readiness cache.

A provider that advertises this capability cannot fall back after a failed
prepared read. Older pinned providers without it keep their existing public path.
Exact return lengths and canonical tuple encodings remain mandatory. Read budgets
are upper bounds; adaptive forwarding retains caller gas rather than requiring
an entire large configured budget for each later small getter. Full nested gas
capacity still requires the composed ceremony measurement.

Safe can call public provider reads through ordinary CALL. The prepared entry is
intentionally protocol-only, including when the external caller is a Safe. Its
restriction prevents externally supplied expectations from bypassing live-state
validation.

## Local metadata facts

The metadata component binds the original Router root, current selected WORK and
RIGHTS records, original conservation selection, exact selected-head seals,
original artist-intent lock, and snapshot receipt/locks. It uses the generic
MetadataV1 module version and module manifest. It never calls the complete input
provider or Discovery recursively and excludes sanction and manifest self-hashes.

WORK/RIGHTS selection seals are narrower than a generic record-type lock. The
compatibility `collectionRecordTypeLocked` read reports false for the current
unsealed generic MetadataV1 dossier. It does not relabel selected-head sealing as
closure of all append-only records. Named scope manifests remain unsupported in
this first collection profile.

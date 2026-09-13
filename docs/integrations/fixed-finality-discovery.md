# Fixed current finality discovery

[StreamFinalityCurrentDiscovery](../../smart-contracts/domains/finality/StreamFinalityCurrentDiscovery.sol)
derives the required component list from a fixed dependency graph. Callers cannot
omit a family or supply an alternative component list. It is a current candidate
reader; the original Finality registry retains historical finalized routes.

## Required evidence

The native ONCHAIN artist-bound profile requires nine independent components:
Metadata Router, renderer, render context, media manifest, script source,
dependency source, collection metadata, the complete original entropy source
set, and reference render. Full discovery adds the original artist sanction.
Entries are ordered by the permanent component-family identifiers and hashed
with the existing `6529STREAM_FINALITY_COMPONENTS_V1` domain and ABI encoding.

`nonSanctionDiscoveryFacts` validates the nine independent components before the
artist signs. It never reads the artist's sanction record. The selected artist
module must nevertheless be current and eligible. Full discovery additionally
requires the original artist sanction; it does not silently substitute a
platform sanction. Supported scopes remain limited by the actual producers.
The first composition target is native COLLECTION; exposing scoped interfaces
does not establish working producers for every scope or metadata mode.

## Construction

Use [Configuration](../../smart-contracts/interfaces/stream/finality/StreamFinalityDiscoveryTypes.sol)
with already-live Core, generic Metadata, Router, membership, entropy factory,
reference-render publisher, artist facade and evidence provider. Six actual
[serving adapters](../../smart-contracts/domains/finality/StreamFinalityServingHostAdapter.sol)
project the Router families; another projects collection metadata through that
same provider. The metadata host itself does not impersonate the provider API.

The provider must expose the fixed reference-render publisher, snapshots host
and entropy factory through
[IStreamFinalityDiscoverySources](../../smart-contracts/interfaces/stream/finality/IStreamFinalityDiscoverySources.sol).
Discovery checks these joins against its own graph, including the reference
publisher's Router and snapshots. Constructor admission validates code,
reciprocal bindings, canonical ERC-165 answers and exact adapter families.

The original Registry may be constructed later. Its expected address and runtime
hash are constructor-only storage in discovery, with no update method. They are
not runtime immutables, so the Registry can pin discovery's runtime without a
circular runtime-hash dependency. Operative reads require the exact live Registry
and its reciprocal Core, Metadata, provider, discovery and artist bindings.
This ordering requirement does not itself prove the complete deployment works.

## Reads and failure behavior

Count methods validate the current dependency graph and return ten structural
slots. A count is not a readiness certificate. Indexed reads validate only the
selected slot after the global dependency checks. Full hash methods and
`nonSanctionDiscoveryFacts` validate every required slot. Consumers must compare
the complete hash and perform their required live component checks; collecting
a count and one healthy entry is insufficient.

This separation avoids repeatedly evaluating every expensive producer for each
indexed read. Exact runtime, current module eligibility, frozen state, source
identity, interface, version, manifest and data commitments remain required.
Missing reference evidence, incomplete entropy inventory, malformed returns,
wrong families and changed dependencies reject. A prepared entropy child is
derived from the fixed factory's current authoritative membership plan.

## Validation boundary

Fifteen discovery cases and six retained serving-adapter cases pass in both
compiler modes, including a 256-input source-drift property. Tests use the actual
discovery contract, serving adapters and threshold Safe. Core, complete evidence
provider, membership, reference, entropy factory and artist are explicit typed
response fixtures in this cohort. These tests cover binding, ordering, negative
cases and the unsigned/full distinction; they do not prove a complete producer
graph, finalization ceremony or maximum transaction gas budget.

The separate actual Core/native entropy composition is described in
[original entropy source sets](original-entropy-source-sets.md). Complete current
assembly and all supported Safe selectors remain tracked in
[the delivery ledger](../../ops/V1_DELIVERY.md) and
[Safe acceptance](../../ops/SAFE_ACCEPTANCE.md).

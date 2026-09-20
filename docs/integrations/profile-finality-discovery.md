# Profile-aware finality source and Discovery

`StreamFinalityPolicyMultiScopeEvidenceProvider` selects the original COLLECTION
profile, the distinct TOKEN/RELEASE/SEASON STATIC profile, and COLLECTION policy
V2 at one provider address. `StreamFinalityProfileDiscovery` is a new Discovery
implementation with the original discovery/route ABI. The original
`StreamFinalityCurrentDiscovery` source and deployed identities are unchanged.
This is a source implementation with selected size checks, not a completed
Registry ceremony or current-stack deployment acceptance.

## Constructor graph

The provider constructor receives the original and scoped 22-role configurations,
the policy V2 22-role configuration, and an explicit output-manifest address and
runtime pin. Scoped roles8/9/18/19 and policy roles8/9/10/18/19 are the only
replacements. Every shared address, runtime pin, chain and gas value must match.
V2 role10 is the actual policy source factory, never a source-set address. The
original roles6/7 remain original leaf/checkpoint dependencies; V2 output and its
checkpoint/selection/source set are bound through the separate output capability.

The provider exposes the exact `IStreamPolicyOutputEvidenceBindingV2` and
`IStreamPolicyPublicationEvidenceBindingV2` getters for the immutable output,
snapshot and reference sources. Constructor-only configuration storage permits
predicted late dependencies; operative readers require their actual runtimes,
reciprocal identities and fresh evidence. Construction does not establish
readiness or transfer a prior provider's receipts.

Deploy the early sources, then the provider and adapters, then Discovery with
the provider's exact `finalitySourceConfigurationHash()`, followed by the
original Registry/Coordinator whose predicted addresses and runtime pins are
already in the configuration. The source hash is constructor-only storage in
Discovery, so it does not create a reciprocal runtime-hash equation. This order
requires a coherent deployment plan for all other original dependency cycles;
it is not a substitute for that plan.

## Acyclic source selection

`IStreamFinalityProfileSources` has three methods:

- `finalitySourceProfile(uint8)` returns an eight-word immutable profile record.
  Index0 is original COLLECTION,1 scoped STATIC,2 policy COLLECTION V2.
- `finalitySourceConfigurationHash()` commits the domain
  `6529STREAM_FINALITY_SOURCE_CONFIGURATION_V1`, chain, actual provider address,
  and complete constructor-derived selection context.
- `finalitySourcesForScope(scope)` returns exactly12 words: the complete
  four-word canonical scope followed by the selected eight-word profile.

Each profile contains its original registered snapshot profile hash, reference,
snapshot and factory addresses/runtime pins, and the hash of its entire typed
configuration. The selector uses the canonical actual Router CONTENT_ROOT head
and its V2 binding for COLLECTION. A wholly zero binding preserves the original
branch; unknown or partially populated bindings fail. V2 requires the exact
constructor-pinned output, checkpoint and source-set chain plus STATIC
activation. TOKEN/RELEASE/SEASON require their canonical full scope and actual
STATIC activation. VIEW remains a required separate adopted-view profile and
currently refuses.

Selection reads no statement, finality manifest, component state, inventory or
reference-currentness endpoint. It grants no authority and does not prove that
the selected records are current or locked.

## Independent evidence and components

The provider dispatches V2 inputs and Artist review through the new fixed V2
operations and exact V2 manifest schemas. Both prepared operations authenticate
the original Registry caller/runtime before selecting a current profile. V2
Metadata and six STATIC component families use their independent current source,
selected records and snapshot-lock checks. The collection snapshot getter keeps
its original manifest-hash meaning. All non-V2 COLLECTION operations retain the
original `super` path at the new host identity; scoped operations retain their
separate original worker paths. No receipt is cast across profiles.

Discovery pins the actual provider/runtime and all three complete reciprocal
source records during construction. Every selected12-word response must be
canonical, match the requested full scope and equal one saved record. Only the
reference and entropy-factory route identities vary with that selection. The
original component ordering, component hashes, expected interfaces, runtime and
frozen-state checks remain. New STATIC eligibility does not return a generic
frozen result. Registry independently validates the live component expectations.

## Evidence and remaining work

The exact Solidity0.8.19/viaIR/optimizer200/Paris/no-CBOR size capture has five
fitting products: provider24,574 bytes (2 bytes headroom), Discovery19,096,
selector4,730, V2 component worker2,905 and STATIC adapter2,322. Further provider
features require extraction and renewed sizing. Earlier unsupported constructor
copy and unoptimized diagnostic captures are retained separately.

Twelve new tests are authored and ABI-clean. They use actual new/original
provider constructors and actual V2 Snapshot/Metadata/Schema/Store/membership,
with explicit typed Router/reference/factory/Registry/Discovery component
boundaries. They cover literal original bytes, distinct same-ID scopes,
configuration/runtime/payload changes, Registry-first refusal, exact source
catalogue routing and frozen-component refusal/restoration. No native result is
claimed for these tests. Independent V2 source/manifest tests and prior scoped
worker tests retain their own narrower evidence.

Complete scoped inventory traversal, bundle coverage, full prepared input and
sanction/Registry execution, actual current graph/cold transaction capacity,
VIEW adoption and genuine prospective pre-sale reference remain separate work.
Changed current output/profile/annotations can invalidate current evidence;
historical retained bytes remain readable.

# Scoped full-policy entropy source factory

`StreamFinalityScopedEntropyPolicySourceFactoryV2` is an additive preparation and
discovery companion for canonical `TOKEN`, `RELEASE`, `SEASON` and `VIEW` scopes.
The original COLLECTION-only `StreamFinalityEntropyPolicySourceFactoryV2`, its
profile, source bindings and selectors are unchanged. The new factory is a
prerequisite for those scopes' full-policy evidence; it is not an output
checkpoint, VIEW renderer admission, reference publication or finality ceremony.

## Deployment and admission

The factory is a supplemental deployment beside the canonical 37 genesis roles.
It does not replace the entropy Coordinator, Membership, original Coordinator
Inventory, generic Metadata, Finality Registry or selected evidence provider.
Its runtime and linked libraries must appear in the deployment/source inventory.
Do not put a prepared source set in a factory configuration slot.

Deploy the actual Core, generic Metadata, Scope Membership and Coordinator
Inventory before constructing this factory. Its constructor takes the original
`StreamFinalityCoordinatorPolicyReadsV2.Dependencies` tuple: four addresses and
four runtime hashes in that order, chain ID, read gas and inventory gas. The
constructor and every operative read recheck those exact runtimes, Core and
membership reciprocity. The original gas floors and full parent-budget guards
remain in the fixed readers.

The companion advertises `IStreamFinalityScopedEntropyPolicySourceFactoryV2`
separately from the inherited generic factory and current entropy route
interfaces. `scopedPolicyFactoryProfile()` returns
`keccak256("6529STREAM_SCOPED_ENTROPY_POLICY_SOURCE_FACTORY_V2")`.
`dependencies()` returns the exact canonical 352-byte tuple. It does not
advertise the COLLECTION V2 companion. A matching provider and discovery profile
must pin this actual factory, its runtime, this capability/profile and its
complete dependency tuple; advertising an interface alone is insufficient.

The existing combined provider has no scoped full-policy output/reference branch
yet. Its original scoped V1 factory slot must not silently be replaced with this
factory. A new complete profile must bind this factory alongside its own genuine
output, snapshot, reference and inventory adapters and be selected by the full
canonical scope and actual Router profile. The initial VIEW provider still
refuses VIEW finality. This batch does not change those gates or turn getter-only
wiring into acceptance.

## Preparing and reading an actual source set

1. Complete the original Coordinator Inventory for the full canonical scope.
   TOKEN uses the actual completed or retained burned Core identity.
   RELEASE/SEASON/VIEW use an actual sealed membership publication; `scopeId`
   identifies that membership, not a VIEW declaration's separate `viewId`.
2. Call `currentInventoryPlan(scope)` and then `prepareSourceSet(scope)` on the
   deployed scoped factory. A missing, incomplete or substituted inventory fails.
   All original coordinators must have frozen policy evidence. Empty membership
   has no invented frozen source set and is refused by the existing SourceSet.
3. The existing fixed `StreamFinalityEntropyPolicySourceDeploymentV2` library
   executes ordinary CREATE in the actual factory context. The immutable set's
   `factory()` is this factory; no test-only constructor alias or caller-selected
   deployment target participates. Factory history binds the plan to the created
   address and runtime hash. Identical preparation is eventless and idempotent.
4. Use `requireCurrentRoute(scope)` or `requireCurrentComponent(scope)` for new
   discovery. They derive the current plan, recheck the saved runtime and actual
   `factory/core/inventoryPlan`, then require the complete current source set and
   selected eligible Metadata. A changed selection or revocation refuses new
   current admission. The returned interface is the original scoped finality
   component capability, never the unscoped COLLECTION capability.

Preparation remains permissionless. It grants no finality, curator, Artist or
governance authority. Historical factory entries and source-set commitments are
retained after currentness failure. A historical `finalityStateForScope` read is
not a substitute for the factory's current discovery checks.

## Entropy and token semantics

The set uses each token's original `coordinatorAtMint` and validates its retained
runtime and complete frozen policy. Explicit policy evidence commits all twelve
original policy words and the ordered complete source inventory. Legacy native
policy leaves retain their original V1 preimage within this distinct V2 set.
No current Coordinator pointer substitutes for an original source.

Terminal statuses 1/2 have zero seed and `finalized=false`; they never acquire the
old `tokenSeedForFinality` API. Actual asynchronous finalization has status 5 and
the real native seed. A frozen policy can still describe a pending token: policy
completeness alone is not rendered-output readiness. A consuming output profile
must enforce its actual terminal/finalized rendering rule for every token.
Retained burned members keep their real original identity and entropy; prepared
or inconsistent lifecycle identities fail. VIEW output still needs its separate
adopted source and renderer/profile proof.

## Focused validation boundary

Twelve authored cases cover actual factory CREATE, complete native inventories,
full-policy and legacy-source composition, actual asynchronous fulfillment,
burned membership, same numeric scope IDs under different kinds, incomplete
preparation rollback, runtime/factory substitutions, current Metadata selection
and revocation, full-policy drift, capability separation, empty scopes, chain
changes and exact events/idempotence.

The fixture uses actual Metadata, Schema, Store, Membership, Inventory and native
Coordinators. Core mint identity/selection, Artist consent, governance execution,
module eligibility and external entropy delivery are named typed boundaries.
ABI3 checks 222 sources without errors. The selected new factory measures 3,935 runtime bytes and 4,850 creation bytes with the original compiler/settings. Test bodies are authored, not yet native
runtime evidence; no complete provider ceremony, cold transaction capacity or
full deployment acceptance is claimed.

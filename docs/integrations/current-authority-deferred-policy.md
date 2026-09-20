# Original current-authority policy sources

This guide covers the new original deployment profiles. Source compilation and
review are separate from native execution, deployment-size checks, gas
measurement and a complete scoped STATIC finality ceremony. The protocol remains
[pre-audit](../status.md).

The strict `StreamCurrentAuthorityScopedPolicyEvidenceProviderV2` and
`StreamFinalityLineageScopedPolicyProfileDiscoveryV2` keep three constructor-pinned
source profiles. Their seven-child scoped-policy factory uses the existing
[publication recipe](scoped-policy-preservation-v2.md), the original Artist
archive dependencies and an explicit current-authority resolver. Recipe and
graph tuple encodings remain unchanged; their new domains include the resolver
and original archive dependencies. Original contracts retain their own profiles.

## Why the deferred sibling exists

The strict Discovery constructor admits real sources for all three fixed
profiles. The collection-policy snapshot requires an actual immutable entropy
policy source set; that source set requires complete, nonempty token inventory
and frozen native policies. In a fresh deployment, the Artist Coordinator needed
for minting itself requires the original Finality registry. A fabricated source
set or an unrelated collection cannot close this cycle.

`StreamCurrentAuthorityDeferredScopedPolicyEvidenceProviderV2` and
`StreamFinalityLineageDeferredScopedPolicyDiscoveryV2` make this one missing
capability explicit. They deploy before the original Finality registry and
Coordinator, with collection-policy admission pending. The native collection,
scoped V1 and genuine scoped-policy graph branches retain their independent
requirements. Pending is never represented by a valid-looking empty policy
profile.

## Fixed capability and one-time binding

`IStreamCurrentAuthorityDeferredPolicyBindingV2` exposes a constructor-fixed
capability. It commits the provider address and chain, original and scoped
configuration hashes, the initialized scoped-policy factory configuration, and
the original Metadata host's actual Governance Executor and runtime hash.
Neither Artist succession nor the binding changes those anchors.

The only new state transition is a terminal seal from pending to bound. The
candidate may replace precisely the following original provider roles:

| Role | Bound value |
| --- | --- |
| 8 | Collection-policy snapshot and runtime |
| 9 | Collection-policy reference publication and runtime |
| 10 | Collection-policy entropy factory and runtime |
| 18 | Current-authority collection-policy inventory and runtime |
| 19 | Matching collection bundle coverage and runtime |
| Separate output pin | Collection-policy output manifest and runtime |

The remaining roles, chain and read budgets must match the original
configuration. The inventory dependency hash must match the new exact tuple,
including the original archive dependencies and current-authority resolver.

Before writing any policy field, candidate validation authenticates the actual
hosts, full constructor dependencies, profile and interface markers, current
original-authority selection, source-set scope, nonempty frozen policy inventory,
and the entropy factory's real source-set receipt. It checks the snapshot,
reference, output, checkpoint and terminal-readiness relationships. There is no
temporary publication to satisfy a callback to a policy getter.

`bindingTransition(policy, output, outputHash)` returns the exact scope, old-state
and new-state hashes for the original Governance action path. Schedule, register
and execute `bindCollectionPolicy` using class 2, `TERMINAL_FREEZE`, with its
ordinary delay and independent veto requirements. Calling from the Executor
without the exact active action context is insufficient. This class applies to
the irreversible catalogue seal; it does not change the rules for parameter
raises or other activations.

The executed action ID is stored in the final receipt, outside the precomputed
proposal state hash. This avoids requiring an action to commit its own ID. The
receipt hash binds both the proposal and executed action. A revert leaves the
entire capability pending, allowing the exact valid proposal to be retried. A
successful binding has no reset, unbind or replacement path, including for an
identical second proposal.

## Reads and discovery

`policyBindingHash()` is zero while pending. `requirePolicyBinding()`, fixed
catalogue index 2 and policy-specific publication/output getters revert with
`CollectionPolicyPending()`. An explicit policy Router binding cannot fall back
to the native profile because policy admission is pending or invalid.

`finalitySourceConfigurationHash()` remains fixed. It commits the deferred
capability and independent original profiles; the separately domain-separated
bound receipt commits the eventual policy sources. Consumers must authenticate
both where policy evidence is required.

The new Discovery admits catalogue entries 0 and 1 during construction. For a
collection-policy selection, it authenticates the provider's canonical bound
receipt and exact selected profile, then rechecks actual runtime, reciprocal and
interface pins. Discovery has no binding setter. Scoped-policy references remain
limited to the genuine seven-child factory graph. Current evidence, preservation,
sanction and finality checks still run in their respective stages.

## Actual deployment recipe

The [source graph](../../script/current/StreamCurrentAuthorityScopedPolicySourceGraph.sol)
constructs the real scoped V1 selection/checkpoint/output/snapshot/reference
prefix and both policy entropy factories without a minted collection. The
[deferred graph](../../script/current/StreamCurrentAuthorityDeferredScopedPolicyGraph.sol)
then installs the original provider, resolver, Discovery, Finality registry and
Coordinator in dependency order. Original selectors and scoped preservation
hosts follow; their predicted runtime and constructor hashes are checked against
actual CREATE results.

Once actual minting and the frozen coordinator inventory exist, the recipe asks
the real collection-policy factory to prepare its source set and constructs the
strict policy source and preservation hosts. It returns a concrete candidate for
the governed binding; preparing those sources grants no publication or finality
authority. The simulation's explicitly supplied gas envelopes require measurement
before use as deployment parameters.

The [actual graph cases](../../test/current/StreamCurrentAuthorityDeferredScopedPolicyGraph.t.sol)
exercise pending minting, the scheduled one-time binding and binding after Artist
succession. The [scoped child cases](../../test/current/StreamCurrentAuthorityScopedPolicyChildren.t.sol)
construct all seven children for TOKEN, RELEASE and SEASON using actual Metadata
membership, coordinator inventories and entropy factory receipts while collection
policy admission remains pending. They also check the original anchors and
content root remain fixed. These construction and binding cases do not substitute
for complete STATIC publication, archival coverage and finality execution. That
composed validation, the ratification-history integration, and
the independently tracked sanction/render currentness cycle remain separate
work until their actual evidence is recorded.

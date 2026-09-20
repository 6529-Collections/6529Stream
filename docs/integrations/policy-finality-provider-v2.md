# COLLECTION V2 finality provider adapters

These fixed libraries supply the statement, metadata, Artist review and current
input reads for a combined provider that selects the explicit-policy COLLECTION
V2 profile. They consume the actual canonical Router root and admitted V2 records.
They do not select a provider, register a finality statement or grant authority.
The combined provider and its matching discovery routes must call these adapters
before the complete profile can be accepted.

## Matched dependency graph

The adapters use the original 22-role `StreamFinalityNativeProviderReads.Config`.
Only these roles change together for this profile:

| Role | Required V2 source |
| --- | --- |
| 8 | `StreamPolicySnapshotPublicationV2` |
| 9 | `StreamPolicyReferencePublicationV2` |
| 10 | `StreamFinalityEntropyPolicySourceFactoryV2` |
| 18 | `StreamPolicyRenderCriticalInventoryV2` |
| 19 | A separate `StreamBundleArchiveCoverage` bound to that inventory |

Original roles 6 and 7 retain their original leaf and checkpoint sources. The V2
output manifest, checkpoint and selection come from the provider's immutable V2
binding and the actual snapshot's 832-byte dependency tuple. They are not placed
in an unrelated original role. All eleven snapshot runtime pins, the complete
1,344-byte inventory dependencies, the bundle's reciprocal binding and every
configured runtime are checked.

Role 10 is the actual factory, never its SourceSet. The factory's 352-byte
dependencies bind Core, Metadata, Membership and CoordinatorInventory. Current
reads require its current plan, saved SourceSet/runtime and current route to
agree with the exact SourceSet used by the canonical root and snapshot. The
SourceSet's factory, Core, profile, complete inventory and frozen policy chain
are independently joined. A current interface response alone is insufficient.

## Fixed operations and current records

`StreamFinalityPolicyProviderOperationsV2` provides `manifest`, `inputs`, `review`
and `prepared`. The host supplies its constructor-owned configuration. `prepared`
checks the original Registry caller and runtime before source or scope reads;
the other methods derive the current component set through the original route
validation. Every path checks the selected provider's original Router candidate
guard. Supported scope is canonical COLLECTION only: nonzero collection ID,
zero token ID and zero scope ID.

`StreamFinalityPolicyProviderReadsV2` joins current inventory evidence (608 bytes),
fresh bundle coverage (160 bytes), V2 snapshot (544 bytes), V2 reference (672
bytes), canonical Router binding (544 bytes), original Core freeze facts and
the complete policy set. Each header remains a projection of its producer's
independently authenticated current record. Old V1 receipts are not decoded as
V2 records.

`StreamPolicyReferencePublicationV2.finalityState(collectionId)` supplies the
original COLLECTION component interface expected by the Registry. It constructs
the canonical scope and shares the same current-record and class-2 lock checks
as `finalityStateForScope`. Both return the same V2 retained receipt/lock
commitment; each identifies its actual interface. The original scoped entry and
its hash domain remain unchanged.

`StreamFinalityPolicyMetadataFactsV2` retains the original selected WORK, RIGHTS,
intent and Core freeze requirements. It additionally joins the current V2 root,
independently authenticated full snapshot/source projection and exact class-2
snapshot lock. Its distinct component domain commits these complete facts. It
does not obtain them recursively from the finality statement or inventory.

## Exact statement and retained bytes

The new statement keeps the original ten `ScopeInputs`, Core facts, scope,
content root and leaf count, snapshot/reference identities and nine ordered
non-sanction component expectations. Its explicit entropy tuple commits the
SourceSet and runtime, SourceSet profile, complete inventory plan/hash, complete
policy chain/count and admitted snapshot/reference profiles. Full twelve-word
policies resolve from those exact retained producers. DISABLED and NOT_REQUIRED
remain terminal zero-seed, nonfinalized facts; they are not fabricated finalized
entropy.

The statement is canonical Solidity ABI, bounded to 8,192 bytes. Both new
definitions must be ACTIVE with their exact RAW_BYTES documents:

- [Statement definition](../schemas/finality/policy-input-manifest-v2.definition.json)
- [ABI definition](../schemas/finality/policy-input-manifest-abi-v2.definition.json)

The document IDs are `6529STREAM_FINALITY_POLICY_INPUT_MANIFEST_V2` and
`6529STREAM_FINALITY_POLICY_INPUT_MANIFEST_ABI_V2`. The Solidity schema constants
and portable files contain identical bytes. Original V1 definitions are unchanged.
Both the original Store copy and Registry staging copy must match the complete
canonical statement. Neither copy substitutes for the other. Missing, stale,
alternate-offset or trailing-byte documents cannot be relabeled as this profile.

The original `6529STREAM_FINALITY_SCOPE_INPUTS_V1` hash over chain, Core, Metadata,
scope and ten inputs remains exact for the Registry bridge. The new statement's
own schema/profile and complete source identities distinguish its interpretation.
Its policy bytes allow only no artwork-byte exception and actual Artist sanction.

`StreamFinalityPolicySanctionReviewV2` uses the original V2 reference reader,
complete retained capture objects and Archive coverage. It supports the current
BYTE_EXACT V2 reference profile. It does not reinterpret Mode/PERCEPTUAL evidence
or create Artist consent. Multi-Artist review still requires the corresponding
real profile catalogue and all original review requirements.

## Validation and remaining acceptance

The seven affected products fit the recorded Solidity 0.8.19, via-IR,
optimizer-200, Paris size capture. The V2 reference host is 22,119 runtime bytes;
the six provider/schema workers range from 5,234 to 18,099 bytes. This establishes
selected bytecode size only, not transaction gas or complete deployment identity.

Seventeen focused manifest tests pass, including 256 fuzz iterations. They use
actual Schema, Store and the official Safe with explicit typed Core, Metadata,
Registry staging and action-context boundaries. The checks include literal ABI,
both retained copies, independent definitions/status, all policy identities,
canonical components/scope, parent-gas refusal and exact retry. Their large
fixture gas envelope is not a production-cap acceptance claim.

Seven provider graph tests and three actual-reference component tests are authored
and type-checked. The former use typed fact tables to challenge exact source and
configuration joins. The latter use the actual V2 reference/snapshot and retained
record contracts with the inherited explicit typed source boundaries. They have
not been executed in this batch. The earlier 22-case snapshot/reference run is
separate evidence and predates the added COLLECTION component entry.

Complete combined-provider dispatch, multi-profile Discovery, current component
evaluation, full inventory materialization and finality acceptance remain joined
work. None follows from these adapter getters or the focused manifest passes.

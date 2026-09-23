# COLLECTION V2 inventory and provider dependencies

`StreamPolicyRenderCriticalInventoryV2` materializes complete ordered evidence
for the current COLLECTION V2 snapshot and BYTE_EXACT reference profile. It uses
the original Item, Segment and bundle coverage vocabulary under a distinct V2
plan and evidence domain. The original V1 snapshot and reference receipt fields
in the internal common-record projection remain zero.

Preparation is permissionless. It cannot create Artist consent, grant publication
authority, lock a component or assert finality. The sources must already be the
actual current canonical Router V2 root, complete policy/output checkpoint,
covered output manifest, admitted snapshot and reference records.

## Fixed dependencies

The inventory constructor takes the original 1,344-byte
`StreamRenderCriticalSourceTypes.Dependencies`. Its twelve targets remain Core,
Metadata, Schema, Store, Router, snapshot, reference, work descriptions, rights,
conservation, native artifact coverage and external artifact coverage. Snapshot
and reference are the new V2 publishers. The five Artist suite pins and original
Content owner pin remain explicit; no current-pointer replacement is inferred.

The matched combined-provider configuration changes these roles together:

| Role | V2 dependency |
| --- | --- |
| 8 | `StreamPolicySnapshotPublicationV2` |
| 9 | `StreamPolicyReferencePublicationV2` |
| 10 | `StreamFinalityEntropyPolicySourceFactoryV2` |
| 18 | `StreamPolicyRenderCriticalInventoryV2` |
| 19 | A fresh `StreamBundleArchiveCoverage` pinned to that inventory |

The original V1 configuration retains its original factory, records, readers and
identities. A SourceSet address cannot fill factory role 10. The V2 factory has
the original factory/current-route selectors plus the explicit profile
`6529STREAM_ENTROPY_POLICY_SOURCE_FACTORY_V2`. Its constructor and `dependencies()`
use the canonical 352-byte V2 policy dependency tuple: four targets and runtime
hashes for Core, Metadata, Membership and CoordinatorInventory, then chain ID,
read gas and inventory gas. It accepts only canonical COLLECTION scopes.

The factory derives the actual current original inventory plan and constructs an
immutable V2 policy SourceSet through a fixed linked creation worker. Normal
CREATE retains the factory as the SourceSet's immutable factory. A repeated plan
reuses the same set only after current-policy checks. Current routing checks the
recorded runtime, factory, Core and plan binding. Missing, stale or mismatched
sets cannot become eligible through a caller-supplied list or an interface claim.

The provider must join snapshot dependency 10 to the actual factory's current
plan and `sourceSetForPlan` result, matching the SourceSet address, runtime,
factory, Core and inventory plan. Factory Membership/CoordinatorInventory pins
must match the original scope producers. Full frozen policy evidence is required;
terminal entropy keeps zero seed and nonfinalized status.

## Ordered materialization

Call `beginInventory(collectionId)` for the current source context. The plan ID
commits the complete V2 snapshot/reference/source and original common record
context, chain, inventory host and fixed dependencies. Repeating the same context
returns the same plan; a changed current source creates a different identity.

Append native snapshot/output/policy evidence, reference/environment/archive
evidence, work, rights, intent or its waiver, interview or its waiver, and original
Artist CONTENT_ROOT authorization in that order. Root authorization authenticates
the original operation 17 Archive record and the exact historical scoped
aggregate witness. A later grant or a supplied aggregate grants no authority.

Append all 31 required original-common and V2 definitions. Then, for every
authoritative membership ordinal, append full output, script, library, every
renderer row and every current-profile row in order. Only completion of the final
profile row advances to the next token. Token ID and serial come from actual Core
and Membership reads; an ordinal is never treated as a serial.

The per-token reads use full current `tokenJSON`, `tokenHTML` and raw token data.
They join retained config and source bytes, selection/output rows and the original
coordinator. The checkpoint source hash uses the original static ten-word
TokenReadiness tuple; its encoded byte carrier is not a substitute in that
preimage. Terminal output requires its exact independently admitted profile and
complete declared reads. Nonterminal output uses its own current citation or
original profile evidence. Selected runtime, analysis, schema, golden evidence,
complete read sets and script/library chunks are included by their actual roles.

Each append retains the ordered segment commitment. Repeated document occurrences
remain in that order, while current document facts are deduplicated by document ID.
Sealing rederives the complete current context, checks all tokens and stages, and
rechecks every retained document's current facts. A later document-status or source
change invalidates currentness without rewriting historical segments.

## Reads and finality

`requireCurrent(collectionId)` and `inventoryEvidence(planId)` return the original
608-byte Evidence shape. `inventorySegment(planId,index)` returns the original
128-byte Segment shape. The profile getter returns the hash of
`6529STREAM_POLICY_COLLECTION_RENDER_CRITICAL_V2`. The unchanged bundle contract's
160-byte coverage result is usable only with its fresh constructor binding to
this inventory and its exact complete evidence/segments.

`StreamFinalityPolicyStaticSourceV2` is the nonrecursive component-source adapter.
It authenticates the actual current V2 snapshot, full canonical payload, complete
dependency pins and exact source hash before projecting scope, selected checkpoint,
membership/root/count and locked Artist snapshot to the fixed STATIC component
worker. Its profile is the admitted snapshot profile hash. It reads no reference,
inventory, finality manifest or component array. The component worker must still
verify every original selection row and frozen source independently.

The combined provider must use these matched dependencies in its actual statement,
component, snapshot, inventory and bundle dispatch. Getter availability or this
materialization host alone does not establish a selected-provider ceremony.

## Validation boundary

The first host layout exceeded the runtime limit. Fixed typed workers now hold
the original begin, current/seal, context and native/reference/root stage bodies;
the measured host is 9,311 bytes. The original eleven workers and four extraction
workers fit in their recorded selected captures. The final selected measurement
also fits the corrected token reader (22,893 bytes), V2 factory (4,085), fixed
creation worker (17,887) and STATIC source projection (11,384). These are selected
Solidity 0.8.19, via-IR, optimizer-200, Paris measurements; they do not establish
transaction gas or a complete deployment's linked runtime identities.

Ten inventory tests, six factory tests and four STATIC source-projection tests are
authored and type-checked. They cover independent domains and ABI shapes, actual
Schema/Store document retention and status changes, exact token source preimages,
factory/runtime/current-policy binding and retained snapshot payload/currentness.
Their Core/Artist/Router/renderer and governance boundaries are documented in each
fixture. Inherited original policy tests remain separately identifiable. These
facts are not native test passes, full inventory materialization, browser capture,
transaction-cap acceptance or complete combined-provider finality acceptance.

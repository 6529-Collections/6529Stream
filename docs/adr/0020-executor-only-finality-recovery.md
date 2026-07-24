# ADR 0020: Executor-Only Append-Only Artwork Finality Recovery

## Status

Proposed.

This ADR is review material only. Until it is independently reviewed and
explicitly marked Accepted:

- the existing `docs/stream-long-term-architecture.md` `[LTA-FINALITY]`
  lifecycle and selectors remain authoritative;
- `docs/launch-conformance-matrix.md` `[LCM-GOLDEN]` gate 17 remains
  authoritative;
- no source, ABI, event catalog, release artifact, deployment profile, or
  readiness claim may rely on this proposal; and
- no legacy recovery selector is deprecated or removed by this document.

Acceptance and normative reconciliation are a later, separate change-control
slice. They are blocked on independent security review, exact integration with
the merged outcomes of #670, #688, #654, and #685, an installable
`StreamOwnerRecords`-hosted owner-recovery-evidence target, and the exact Core
pointer plus metadata-router serving integration defined below. No owner-
evidence implementation issue is assigned as of this proposal; acceptance and
source authorization remain blocked until that ownership is explicit.

## Metadata

| Field | Value |
| --- | --- |
| Date proposed | 2026-07-24 |
| Issue | [#667](https://github.com/6529-Collections/6529Stream/issues/667) |
| Related issues | [#654](https://github.com/6529-Collections/6529Stream/issues/654), [#670](https://github.com/6529-Collections/6529Stream/issues/670), [#685](https://github.com/6529-Collections/6529Stream/issues/685), [#688](https://github.com/6529-Collections/6529Stream/issues/688) |
| Related ADR | [ADR 0004](0004-admin-governance.md) `[GOV-ACTION-ID]`, `[GOV-BATCH]`, `[GOV-V2-CUTOVER]` |
| Proposed affected contracts | New replaceable recovery companion and auxiliary interfaces; later #654 Core pointer/emitter authorization and metadata-router serving integration are explicit dependencies |
| Permanent interface impact | None; `IStreamArtworkFinalityRegistry` remains unchanged |
| Work type | Pre-genesis incompatible auxiliary-interface proposal |

## Problem

The Draft Finality Recovery specification pins a second local governance
lifecycle inside the finality registry:

- collection and scoped schedule functions;
- collection and scoped cancellation functions;
- locally stored `SCHEDULED`, `CANCELLED`, and `EXECUTED` states;
- caller-supplied recovery IDs and execution times; and
- permissionless execution after the locally stored delay.

Accepted Governance V2 already owns scheduling, cancellation, terminal-freeze
guardian veto, expiry, retry, action IDs, atomic batches, and target-side
per-call transition commitments. Implementing both lifecycles would create two
authorities and two pending-action records that could disagree about whether a
recovery is executable.

The Draft recovery text also cannot be executed safely without additional
decisions:

- its recovery ID is not the Governance V2 action ID;
- its manifest does not mechanically bind the exact replacement route;
- artist and owner evidence can arise during the notice window but lacks a
  pinned execution-time snapshot rule;
- original finality and recovered-route lineage are not separated in storage;
- collection recovery inheritance versus exact scoped finality is not
  deterministic;
- equal component-reported `dataHash` is not proof that served artwork bytes
  are equivalent;
- the Core refresh dependency has no exact installable interface requirement;
  and
- the old-registry zero-incomplete assertion and pointer update require
  Governance V2 batch-policy enforcement outside the recovery target.

This is a pre-genesis design conflict. No production deployment used either
surface.

## Decision Proposed For Acceptance

If this ADR is later Accepted, the protocol will make an incompatible
pre-genesis replacement of the Draft auxiliary recovery ABI. It will not add
legacy wrappers.

1. Governance V2 is the sole authority and state owner for
   `SCHEDULED`, `CANCELLED`, `VETOED`, `EXPIRED`, and retryable recovery
   actions. The recovery companion stores no pending-action lifecycle.
2. The companion has one state-changing recovery transition. It accepts only
   its immutable Governance Executor while `currentAction()` reports an active,
   nonzero, class-`TERMINAL_FREEZE` (`2`) action with the exact per-call scope,
   old-state, and new-state commitments.
3. `currentAction().actionId` is the recovery ID. Exactly one
   `executeFinalityRecovery` call is permitted in a Governance action batch.
   A successful execution consumes that ID once. A reverted execution consumes
   nothing. A second recovery append, even for another scope or companion,
   makes the batch invalid; multiple recoveries require distinct Governance
   actions and action IDs.
4. The companion is discovered through a new Core satellite pointer family,
   `ARTWORK_FINALITY_RECOVERY`. It does not replace
   `ARTWORK_FINALITY_REGISTRY`. The current metadata router is the
   authoritative onchain consumer of its recovery-aware route-resolution read.
5. The original finality registry, its records, component arrays, and permanent
   interface never change. The companion appends executed recovery records and
   maintains a separate exact-scope head and monotonic generation.
6. A request commits its canonical scope, original finality record hash,
   predecessor recovery ID, old route hash, exact replacement component
   expectation, recovery manifest, reason hash, and reason URI.
7. Canonical staged manifest bytes bind the executable intent. The manifest
   content hash must equal the hash of those bytes; route, scope, reason, or
   lineage substitution therefore invalidates both the manifest and artist
   approval.
8. Artist and owner evidence are read from separately owned append-only
   targets and snapshotted at execution. The scheduled action identity does not
   contain mutable evidence values.
9. Every route replacement is fail-closed as
   `artworkBytesChanged = true`. A component's self-reported `dataHash` is not a
   generic byte-equivalence proof. A non-artwork-changing class requires a
   separately accepted and versioned equivalence verifier.
10. Route selection is, in order: exact-scope recovery, exact-scope permanent
    finality, collection recovery, then collection permanent finality. A first
    exact-scope recovery over inherited collection finality starts a new exact
    chain at predecessor zero and generation one; it never treats the
    collection recovery head as its predecessor.
11. Each exact scope has one append-only predecessor chain. Competing
    Governance actions may wait concurrently, but after one executes, every
    action committing the stale predecessor or old route fails before mutation.
12. Execution creates or supersedes one bounded refresh plan. Permissionless
    continuation advances exactly one chunk of at most 5,000 IDs, calls Core
    exactly once, and relies on transaction atomicity to roll back cursor,
    count, and events if Core rejects.
13. The global incomplete-plan count and zero-count assertion retain their
    existing selectors. Governance action policy, not the companion, must
    enforce the predecessor assertion immediately before the exact
    `ARTWORK_FINALITY_RECOVERY` pointer update with no intervening-call or
    generic-path bypass.
14. No wrapper preserves the old local schedule, cancel, execute, record,
    active-route, plan, or continuation selector. A wrapper would preserve the
    duplicate local authority this ADR exists to remove.

## Topology, Discovery, And Serving Authority

This proposal chooses a new pointer and Core caller-authentication seam. It
rejects making the companion a façade for the permanent finality registry:
forwarding that registry's state-changing ABI would either change its authority
model or introduce another writer. The exact new pointer identity is:

```text
pointer name: ARTWORK_FINALITY_RECOVERY
pointer key:  keccak256("ARTWORK_FINALITY_RECOVERY")
              = 0xead6d91d79d13e47343aa9d24c2198c5e4fcd612fdd9531d8b2549bab7651474
module type:  keccak256("STREAM_ARTWORK_FINALITY_RECOVERY")
              = 0x50e132608386d4b0bf237635eb7bfd9473f667085fa7d7b18f81c5045c289050
interface:    IStreamArtworkFinalityRecovery
interface ID: 0x83685f5c
```

If this ADR is Accepted, the reconciliation train must add
`ARTWORK_FINALITY_RECOVERY` to the closed Core pointer inventory. The target
must be nonzero, code-bearing, registered under the exact module type, advertise
IERC-165 and `0x83685f5c`, reject `0xffffffff`, and bind the same Core,
Governance Executor, permanent original finality registry, artist-evidence
target, and owner-evidence target named by the deployment profile. The
`ARTWORK_FINALITY_REGISTRY` pointer continues to name the unchanged permanent
registry. `getSatellitePointer(ARTWORK_FINALITY_RECOVERY)` is the only canonical
discovery read; companion addresses must not come from a router-local allowlist
or operator configuration.

The current metadata router is the authoritative onchain serving consumer. For
every frozen route component it resolves, it:

1. reads the current recovery companion from Core;
2. verifies the pointer's exact module/interface facts;
3. calls both `resolvedFinalityRoute(routeType, scope)` and
   `finalityRecoveryRouteStatus(routeType, scope)` on that companion, requiring
   identical `pinned`, `componentRouteHash`, and `recoveryId` facts; and
4. serves through the returned `module` only when `pinned` and
   `currentRouteMatches` are both true.

The companion resolves both original and recovered components, so after this
pointer is installed the router does not fall back directly to permanent
`verifyFinality` or component reads. A zero pointer, wrong interface, unreadable
companion, malformed return, `pinned = false` for a supposedly finalized route,
`currentRouteMatches = false`, inconsistent resolver/status results, or
inconsistent original-registry binding fails closed for that frozen serving
route. This avoids a split brain in which some callers serve the original route
while others observe recovery.

#654 owns the Core consequences: adding the pointer family and admitting the
current `ARTWORK_FINALITY_RECOVERY` target, in addition to the already accepted
callers, to the restricted batch-refresh emitter. #667 makes no Core edit; it
owns the companion and the exact route-resolution behavior. #685 owns
closed-world Governance classification and the adjacent old-companion
zero-incomplete assertion followed by
`updateSatellitePointer(ARTWORK_FINALITY_RECOVERY, successor)`. Metadata-router
serving integration is a source-authorization prerequisite and must be assigned
to an implementation owner before this ADR can be Accepted.

## Exact Function Migration

### Draft local-lifecycle functions proposed for removal

| Draft signature | Selector | Proposed replacement |
| --- | --- | --- |
| `scheduleFinalityRecovery(uint256,bytes32,bytes32,(string,bytes32,bytes32,bytes32,bytes32),bytes32,uint64,bool,bytes32,string)` | `0x8eedec3a` | Governance V2 schedules exact companion calldata and per-call commitments. |
| `cancelFinalityRecovery(uint256,bytes32,bytes32,string)` | `0x9934f0ef` | Governance V2 cancellation, terminal veto, and expiry. |
| `executeFinalityRecovery(uint256,bytes32)` | `0xb94d5a59` | Unified executor-only typed request, `0x4cf90f05`. |
| `finalityRecoveryRecord(uint256,bytes32)` | `0xa9695211` | Unified action-ID-keyed executed record, `0x9d2aafcb`. |
| `activeFinalityRecoveryRoute(uint256)` | `0xd9b8e3af` | Unified head and route-resolution reads. |
| `finalityRecoveryRefreshPlan(uint256,bytes32)` | `0x2f72acb6` | Unified action-ID-keyed plan, `0x85155250`. |
| `continueFinalityRecoveryRefresh(uint256,bytes32)` | `0x617c9142` | Unified scope continuation, `0xbf72235d`. |
| `scheduleScopedFinalityRecovery((uint8,uint256,uint256,bytes32),bytes32,bytes32,(string,bytes32,bytes32,bytes32,bytes32),bytes32,uint64,bool,bytes32,string)` | `0x152fd366` | Governance V2 schedules the exact scoped request. |
| `cancelScopedFinalityRecovery((uint8,uint256,uint256,bytes32),bytes32,bytes32,string)` | `0xf2c524f7` | Governance V2 cancellation, terminal veto, and expiry. |
| `executeScopedFinalityRecovery((uint8,uint256,uint256,bytes32),bytes32)` | `0xf67099ee` | Unified executor-only typed request, `0x4cf90f05`. |
| `scopedFinalityRecoveryRecord((uint8,uint256,uint256,bytes32),bytes32)` | `0x40fb0d81` | Unified action-ID-keyed executed record, `0x9d2aafcb`. |
| `activeScopedFinalityRecoveryRoute((uint8,uint256,uint256,bytes32))` | `0x066e33a4` | Unified head and route-resolution reads. |
| `scopedFinalityRecoveryRefreshPlan((uint8,uint256,uint256,bytes32),bytes32)` | `0x3d075555` | Unified action-ID-keyed plan, `0x85155250`. |
| `continueScopedFinalityRecoveryRefresh((uint8,uint256,uint256,bytes32),bytes32)` | `0x12ffdb0d` | Unified scope continuation, `0xbf72235d`. |

### Proposed unified auxiliary interface

The table below uses canonical ABI tuple spellings. The Solidity source may use
the named `StreamFinalityScope` and `StreamFinalityRecoveryRequest` structs, but
struct names do not enter selectors.

| Signature | Selector | Purpose |
| --- | --- | --- |
| `stageFinalityRecoveryManifest(bytes)` | `0x3f91cd56` | Permissionless bounded content-addressed staging. |
| `finalityRecoveryManifestStored(bytes32)` | `0x479e091f` | Staged-content existence. |
| `finalityRecoveryManifestBytes(bytes32)` | `0xa575698f` | Exact staged bytes. |
| `finalityRecoveryIntentBytes(((uint8,uint256,uint256,bytes32),bytes32,bytes32,bytes32,(bytes32,address,bytes4,bytes32,bytes32,bytes32,bytes32),(string,bytes32,bytes32,bytes32,bytes32),bytes32,string))` | `0x4b19e884` | Canonical executable intent bytes. |
| `executeFinalityRecovery(((uint8,uint256,uint256,bytes32),bytes32,bytes32,bytes32,(bytes32,address,bytes4,bytes32,bytes32,bytes32,bytes32),(string,bytes32,bytes32,bytes32,bytes32),bytes32,string))` | `0x4cf90f05` | Executor-only append transition. |
| `finalityRecoveryRecord(bytes32)` | `0x9d2aafcb` | Executed record by action ID. |
| `activeFinalityRecovery((uint8,uint256,uint256,bytes32))` | `0xb5445861` | Exact-scope head, route hash, generation. |
| `resolvedFinalityRoute(bytes32,(uint8,uint256,uint256,bytes32))` | `0x73e8e6b7` | Exact-then-collection selected route. |
| `finalityRecoveryRouteStatus(bytes32,(uint8,uint256,uint256,bytes32))` | `0x95fe772f` | Historical pin plus current live-match status. |
| `finalityRecoveryRefreshPlan(bytes32)` | `0x85155250` | Unified refresh plan by action ID. |
| `continueFinalityRecoveryRefresh((uint8,uint256,uint256,bytes32),bytes32)` | `0xbf72235d` | Permissionless one-chunk continuation. |
| `incompleteFinalityRecoveryRefreshPlanCount()` | `0xa76ed63d` | Existing global incomplete count. |
| `assertNoIncompleteFinalityRecoveryRefreshPlans()` | `0x955d14fb` | Existing zero-count assertion. |
| `finalityRecoveryScopeHash((uint8,uint256,uint256,bytes32))` | `0x27eb3773` | Governance per-call scope helper. |
| `finalityRecoveryOldValueHash(((uint8,uint256,uint256,bytes32),bytes32,bytes32,bytes32,(bytes32,address,bytes4,bytes32,bytes32,bytes32,bytes32),(string,bytes32,bytes32,bytes32,bytes32),bytes32,string))` | `0x1a58a89d` | Governance per-call pre-state helper. |
| `finalityRecoveryNewValueHash(((uint8,uint256,uint256,bytes32),bytes32,bytes32,bytes32,(bytes32,address,bytes4,bytes32,bytes32,bytes32,bytes32),(string,bytes32,bytes32,bytes32,bytes32),bytes32,string))` | `0xa26d5f0c` | Governance per-call post-state helper. |

The exact named-field order underlying the request tuple is:

```text
StreamFinalityScope
  1. scopeType: uint8
  2. collectionId: uint256
  3. tokenId: uint256
  4. scopeId: bytes32

StreamFinalityComponentExpectation
  1. componentType: bytes32
  2. component: address
  3. interfaceId: bytes4
  4. codeHash: bytes32
  5. moduleVersion: bytes32
  6. manifestHash: bytes32
  7. dataHash: bytes32

StreamFinalityManifestRef
  1. uri: string
  2. uriHash: bytes32
  3. contentHash: bytes32
  4. schemaId: bytes32
  5. canonicalizationHash: bytes32

StreamFinalityRecoveryRequest
  1. scope: StreamFinalityScope
  2. expectedOriginalFinalityRecordHash: bytes32
  3. expectedPredecessorRecoveryId: bytes32
  4. expectedOldRouteHash: bytes32
  5. replacementRoute: StreamFinalityComponentExpectation
  6. recoveryManifest: StreamFinalityManifestRef
  7. reasonHash: bytes32
  8. reasonURI: string
```

Therefore the canonical request ABI tuple is exactly
`((uint8,uint256,uint256,bytes32),bytes32,bytes32,bytes32,(bytes32,address,bytes4,bytes32,bytes32,bytes32,bytes32),(string,bytes32,bytes32,bytes32,bytes32),bytes32,string)`.

### Exact return schemas

Return types do not enter function selectors. They are nevertheless normative
ABI and indexer facts. `StreamFinalityRecoveryArtistEvidenceKind` has ABI type
`uint8`. The remaining returned structs have these exact ordered fields:

```text
StreamFinalityRecoveryEvidenceSnapshot
  1. artistEvidenceKind: uint8
  2. artistEvidenceHash: bytes32
  3. artistSigner: address
  4. artistId: bytes32
  5. artistAuthorityClass: uint8
  6. artistNoticeEndsAt: uint64
  7. ownerEvidenceHash: bytes32
  8. ownerEvidenceRevision: uint64
  9. ownerAcknowledgementCount: uint32
 10. ownerObjectionCount: uint32

StreamFinalityRecoveryRecord
  1. executed: bool
  2. recoveryId: bytes32
  3. scope: StreamFinalityScope
  4. originalFinalityRecordHash: bytes32
  5. predecessorRecoveryId: bytes32
  6. generation: uint64
  7. oldRouteHash: bytes32
  8. recoveryRouteHash: bytes32
  9. artworkBytesChanged: bool
 10. replacementRoute: StreamFinalityComponentExpectation
 11. recoveryManifest: StreamFinalityManifestRef
 12. evidence: StreamFinalityRecoveryEvidenceSnapshot
 13. reasonHash: bytes32
 14. reasonURI: string
 15. executedAt: uint64

StreamFinalityRecoveryRefreshPlan
  1. exists: bool
  2. complete: bool
  3. superseded: bool
  4. manifestContentHash: bytes32
  5. supersededByRecoveryId: bytes32
  6. lastAllocatedTokenIdAtExecution: uint256
  7. rangeStart: uint256
  8. rangeEnd: uint256
  9. processedThrough: uint256
 10. chunksEmitted: uint256
```

The exact function outputs are:

| Function | Exact outputs |
| --- | --- |
| `stageFinalityRecoveryManifest` | `(bytes32 contentHash)` |
| `finalityRecoveryManifestStored` | `(bool stored)` |
| `finalityRecoveryManifestBytes` | `(bytes manifestBytes)` |
| `finalityRecoveryIntentBytes` | `(bytes intentBytes)` |
| `executeFinalityRecovery` | no return data |
| `finalityRecoveryRecord` | `(StreamFinalityRecoveryRecord record)`, ABI tuple `(bool,bytes32,(uint8,uint256,uint256,bytes32),bytes32,bytes32,uint64,bytes32,bytes32,bool,(bytes32,address,bytes4,bytes32,bytes32,bytes32,bytes32),(string,bytes32,bytes32,bytes32,bytes32),(uint8,bytes32,address,bytes32,uint8,uint64,bytes32,uint64,uint32,uint32),bytes32,string,uint64)` |
| `activeFinalityRecovery` | `(bytes32 recoveryId, bytes32 recoveryRouteHash, uint64 generation)` |
| `resolvedFinalityRoute` | `(bool pinned, address module, bytes32 componentRouteHash, bytes32 originalFinalityRecordHash, bytes32 recoveryId)` |
| `finalityRecoveryRouteStatus` | `(bool pinned, bool currentRouteMatches, bytes32 componentRouteHash, bytes32 recoveryId)` |
| `finalityRecoveryRefreshPlan` | `(StreamFinalityRecoveryRefreshPlan plan)`, ABI tuple `(bool,bool,bool,bytes32,bytes32,uint256,uint256,uint256,uint256,uint256)` |
| `continueFinalityRecoveryRefresh` | no return data |
| `incompleteFinalityRecoveryRefreshPlanCount` | `(uint256 count)` |
| `assertNoIncompleteFinalityRecoveryRefreshPlans` | no return data |
| `finalityRecoveryScopeHash` | `(bytes32 scopeHash)` |
| `finalityRecoveryOldValueHash` | `(bytes32 oldValueHash)` |
| `finalityRecoveryNewValueHash` | `(bytes32 newValueHash)` |

For both route reads, the first `bytes32` input is named `routeType` and is the
exact `StreamFinalityComponentExpectation.componentType` to resolve. It is not
an original-record hash or recovery ID. `componentRouteHash` is the hash of the
one selected component expectation; it is distinct from the composite
`recoveryRouteHash` stored on an executed record.

The proposed auxiliary ERC-165 ID is `0x83685f5c`. The input and output tuple
spellings above are the proposed exact ABI pin; acceptance must prove the
reviewed Solidity ABI matches them without drift. This proposal does not alter
the permanent `IStreamArtworkFinalityRegistry` interface or ID.

## Exact Event Migration

### Draft events proposed for removal

| Signature | Topic zero | Indexed fields | Replacement fact owner |
| --- | --- | --- | --- |
| `FinalityRecoveryScheduled(uint16,uint256,bytes32,bytes32,bytes32,bytes32,uint64,bool,bytes32,string)` | `0x5eacad2f2b4cd90dec4e8423cd7763e6b7d1e56e4d3e938cc98b4e20ece678e7` | `collectionId`, `recoveryId` | Governance V2 action scheduling. |
| `FinalityRecoveryCancelled(uint16,uint256,bytes32,bytes32,string)` | `0x7f1c519f00d849398bd9099202fd70f775eb8cce80f93791251e4e6bd0f136b4` | `collectionId`, `recoveryId` | Governance V2 cancellation/veto/expiry. |
| `ScopedFinalityRecoveryScheduled(uint16,uint8,uint256,bytes32,uint256,bytes32,bytes32,bytes32,bytes32,uint64,bool,bytes32,string)` | `0x486dcd2908143a12a1a590387b71ccebaf437a28c1256088e14db3c3908ae270` | `scopeType`, `collectionId`, `recoveryId` | Governance V2 action scheduling. |
| `ScopedFinalityRecoveryCancelled(uint16,uint8,uint256,bytes32,uint256,bytes32,bytes32,string)` | `0x670e6e8d4719351cbff1edca167546e3641082922cb73c7e70d780db7e0f74e3` | `scopeType`, `collectionId`, `recoveryId` | Governance V2 cancellation/veto/expiry. |

### Retained signatures and topics

| Signature | Topic zero | Indexed fields |
| --- | --- | --- |
| `FinalityRecoveryExecuted(uint16,uint256,bytes32,bytes32,bytes32,bool,bytes32,string)` | `0x401e51a7e648b6033fa4faf9e39d3b0c9ef8a45733f75ccb57ae3cbd44dd0a72` | `collectionId`, `recoveryId` |
| `ScopedFinalityRecoveryExecuted(uint16,uint8,uint256,bytes32,uint256,bytes32,bytes32,bytes32,bool,bytes32,string)` | `0x58cacbca9c07add9edaef7ec32e6200d97698a71daf977c6eadf79816470438c` | `scopeType`, `collectionId`, `recoveryId` |
| `FinalityRecoveryRefreshPlanCreated(uint16,uint256,bytes32,bytes32,uint256,uint256,uint256,bool)` | `0x5590436c7dbb2ed0938facf5ae98e65e85124a2e13e00beb6ec8074977862d84` | `collectionId`, `recoveryId`, `manifestContentHash` |
| `FinalityRecoveryRefreshProgress(uint16,uint256,bytes32,bytes32,uint256,uint256,uint256,uint256,bool)` | `0x8f59fcbfe19db77744f74c21e2ba799373890d37c0188d5647dc4d839c738e71` | `collectionId`, `recoveryId`, `manifestContentHash` |
| `FinalityRecoveryRefreshPlanSuperseded(uint16,uint256,bytes32,bytes32,bytes32,uint256,uint256)` | `0x46cf3a686b05af5842dbce8ee594d7d79150f32709b696f3e2ac8fabb3b90b1b` | `collectionId`, `recoveryId`, `supersededByRecoveryId` |
| `ScopedFinalityRecoveryRefreshPlanCreated(uint16,uint8,uint256,bytes32,uint256,bytes32,bytes32,uint256,uint256,uint256,bool)` | `0x3dbc37ab6a915fb474ed929e21cc48c06e610215c7a1b8d8e4b78a4504b4228c` | `scopeType`, `collectionId`, `recoveryId` |
| `ScopedFinalityRecoveryRefreshProgress(uint16,uint8,uint256,bytes32,uint256,bytes32,bytes32,uint256,uint256,uint256,uint256,bool)` | `0x1f06d8cfd3bd35dbf2bd5e6b034faeab82e1a42696ee769c4112c2004158ab04` | `scopeType`, `collectionId`, `recoveryId` |
| `ScopedFinalityRecoveryRefreshPlanSuperseded(uint16,uint8,uint256,bytes32,uint256,bytes32,bytes32,bytes32,uint256,uint256)` | `0xf01128046f729a9423b6f9ebc2799e09a7608d6df6d35d5383a2e077c7d2a386` | `scopeType`, `collectionId`, `recoveryId` |

Their signatures remain byte-identical, but `recoveryId` becomes the verified
Governance action ID rather than a caller-supplied local preimage.

### Proposed new append/evidence events

| Signature | Topic zero | Indexed fields |
| --- | --- | --- |
| `FinalityRecoveryManifestStaged(uint16,bytes32,uint256,address)` | `0x96e23e9d953aadb6216d8b8836ac606a796a56148a5adec007e25e57d9e869cf` | `manifestContentHash` |
| `FinalityRecoveryLineageRecorded(uint16,bytes32,bytes32,bytes32,uint64,bytes32,bytes32)` | `0xaeb5797308416112ddc363bbc8df6684801ed02091d25986526320bb98568643` | `recoveryId`, `predecessorRecoveryId`, `originalFinalityRecordHash` |
| `FinalityRecoveryEvidenceSnapshotted(uint16,bytes32,uint8,bytes32,address,bytes32,uint8,uint64,bytes32,uint64,uint32,uint32)` | `0xce92effcd0a486c77e4176ac15f40c90bd9fccd7104511f90831c4e88f0ae4ea` | `recoveryId` |

Acceptance must add these facts to the generated event catalog and remove the
four local lifecycle facts. This Proposed slice changes neither catalog.

## State And Storage Migration

### Draft record

The Draft model stores a mutable record keyed separately by collection/scoped
identity and caller-supplied recovery ID:

```text
status: NONE | SCHEDULED | CANCELLED | EXECUTED
oldFinalityRecordHash
recoveryManifest
recoveryRouteHash
executeAfter
artworkBytesChanged
reasonHash
reasonURI
```

Its local authority schedules/cancels, and a permissionless caller executes
after the local timestamp.

### Proposed executed record

The companion stores only successful append facts, keyed by the Governance
action ID:

```text
executed
recoveryId
scope
originalFinalityRecordHash
predecessorRecoveryId
generation
oldRouteHash
recoveryRouteHash
artworkBytesChanged
replacementRoute
recoveryManifest
evidence
reasonHash
reasonURI
executedAt
```

`artworkBytesChanged` is always true in this version. The evidence snapshot
contains:

```text
artistEvidenceKind: NONE | APPROVAL | UNAVAILABILITY
artistEvidenceHash
artistSigner
artistId
artistAuthorityClass
artistNoticeEndsAt
ownerEvidenceHash
ownerEvidenceRevision
ownerAcknowledgementCount
ownerObjectionCount
```

Separate storage tracks consumed action IDs, exact-scope active recovery IDs,
route hashes, generations, route-type overrides, route-to-recovery links,
content-addressed manifest bytes, refresh plans, the global incomplete count,
and a refresh reentrancy guard.

There is no storage migration from a production system. If accepted
pre-genesis, repository history is the archive of the superseded Draft shape.

## Commitments And Preimages

Proposed domain constants:

| String preimage | Hash |
| --- | --- |
| `6529STREAM_FINALITY_RECOVERY_SCOPE_V1` | `0x52a7e432a96f70f1eea1a0d69c9f1ab494af7898747ad6f19d9cc1be7ae73224` |
| `6529STREAM_FINALITY_RECOVERY_OLD_STATE_V1` | `0xf0a4f7b55f872b0fff01a4b90874c9b55d64b23f668c5c12de5b6873bceee87b` |
| `6529STREAM_FINALITY_RECOVERY_NEW_STATE_V1` | `0x40edf628dd8547ae3f17b0288b0968e99ecd7b7f7e7a9e23782ef728a185e311` |
| `6529STREAM_FINALITY_RECOVERY_INTENT_V1` | `0x570ae9ce4087aaa984ebbe2832d4ae780239512e44cfb784e4956c4eb6e5929a` |

Scope:

```solidity
keccak256(abi.encode(
    FINALITY_RECOVERY_SCOPE_DOMAIN,
    block.chainid,
    address(recoveryCompanion),
    request.scope
))
```

The storage lineage key used by the old-state commitment is not the Governance
scope hash. It is exactly:

```solidity
bytes32 scopeKey = keccak256(abi.encode(
    uint8(request.scope.scopeType),
    request.scope.collectionId,
    request.scope.tokenId,
    request.scope.scopeId
));
```

Old state:

```solidity
keccak256(abi.encode(
    FINALITY_RECOVERY_OLD_STATE_DOMAIN,
    scopeKey,
    originalFinalityRecordHash,
    predecessorRecoveryId,
    oldGeneration,
    oldRouteHash
))
```

New state:

```solidity
keccak256(abi.encode(
    FINALITY_RECOVERY_NEW_STATE_DOMAIN,
    block.chainid,
    address(recoveryCompanion),
    newGeneration,
    request
))
```

Canonical staged intent:

```solidity
bytes.concat(
    abi.encode(
        FINALITY_RECOVERY_INTENT_DOMAIN,
        block.chainid,
        address(recoveryCompanion),
        request.scope,
        request.expectedOriginalFinalityRecordHash
    ),
    abi.encode(
        request.expectedPredecessorRecoveryId,
        request.expectedOldRouteHash,
        request.replacementRoute,
        request.reasonHash,
        keccak256(bytes(request.reasonURI))
    )
)
```

The recovery manifest reference is intentionally excluded from its own intent
bytes to avoid a content-hash fixed point. Its `contentHash` must equal
`keccak256(intentBytes)`. Its canonical bytes must already be staged; its URI
hash must match; and its schema and canonicalization hashes must be nonzero.

This replaces both Draft local recovery-ID preimages. Governance V2's
`STREAM_GOVERNANCE_ACTION_V2` action ID is authoritative.

### Component and recovered-route hashes

The hash of one original or replacement component route is:

```solidity
bytes32 componentRouteHash = keccak256(abi.encode(
    StreamFinalityComponentExpectation({
        componentType: route.componentType,
        component: route.component,
        interfaceId: route.interfaceId,
        codeHash: route.codeHash,
        moduleVersion: route.moduleVersion,
        manifestHash: route.manifestHash,
        dataHash: route.dataHash
    })
));
```

Because `abi.encode(route)` uses the same seven ordered fields, implementations
may write `keccak256(abi.encode(route))`. `oldRouteHash`,
`expectedOldRouteHash`, `replacementRouteHash`, and the
`componentRouteHash` returned by route reads all use this formula.

The composite executed-record `recoveryRouteHash` uses the existing collection
and scoped recovery domain strings, now over an exact append preimage rather
than a caller-supplied opaque value:

| Scope class | String preimage | Domain hash |
| --- | --- | --- |
| `COLLECTION` | `6529STREAM_FINALITY_RECOVERY_V1` | `0x521e8df5a00a793a5b47409e1e7711b4b8857ba9e6c833fe59a48dfa865b19ac` |
| `TOKEN`, `RELEASE`, `SEASON`, or `VIEW` | `6529STREAM_SCOPED_FINALITY_RECOVERY_V1` | `0x7111cd2afae740dbddcd349ab0b8b9269b6a81c331cef7ca8d542e87308bc54a` |

```solidity
bytes32 routeDomain =
    request.scope.scopeType == StreamFinalityScopeType.COLLECTION
    ? STREAM_FINALITY_RECOVERY_V1
    : STREAM_SCOPED_FINALITY_RECOVERY_V1;

bytes32 recoveryRouteHash = keccak256(bytes.concat(
    abi.encode(
        routeDomain,
        block.chainid,
        address(recoveryCompanion),
        recoveryId,
        originalFinalityRecordHash,
        predecessorRecoveryId,
        newGeneration
    ),
    abi.encode(
        request.scope,
        request.replacementRoute,
        request.recoveryManifest.contentHash,
        evidence,
        request.reasonHash
    )
));
```

Here `evidence` is the exact ten-field
`StreamFinalityRecoveryEvidenceSnapshot` tuple above. The staged manifest
content hash transitively binds the full canonical intent, including the
reason-URI hash. `recoveryRouteHash` therefore identifies the executed append
and its evidence; it is not interchangeable with the hash of the one selected
component route.

## Authorization, Replay, Timing, And Revert Semantics

1. Direct calls reject. The immutable Executor is the only mutation caller.
2. A false execution flag or zero action ID rejects as missing context.
3. An action class other than terminal freeze rejects.
4. A wrong action scope, old value, or new value rejects before mutation.
5. Canonical scope shape rejects collection/token/scope-ID ambiguity.
6. Missing or mismatched original finality rejects.
7. A stale predecessor or stale old route rejects, so competing actions have a
   deterministic first-valid-execution winner.
8. Governance policy permits exactly one `executeFinalityRecovery` call in the
   full `GovernanceCall[]` for an action. A second append targeting the same or
   another recovery companion or scope rejects at scheduling/classification;
   it is not deferred to an inevitably reverting atomic execution. Other
   policy-compatible calls may coexist in the batch.
9. A consumed action ID rejects replay.
10. A missing, malformed, unstaged, or intent-mismatched recovery manifest
   rejects before evidence or state.
11. A missing, type-mismatched, duplicated/ambiguous, code-drifted, reverting,
    malformed, unfrozen, or state-mismatched replacement route rejects.
12. Required artist evidence that reverts, is short, oversized, malformed,
    invalid, zero-identity, or still inside the action-bound unavailability
    notice rejects.
13. Required owner evidence that reverts, is short, oversized, malformed,
    invalid, zero-hash, or zero-revision rejects.
14. Artist approval deadlines and nonce/digest revocation are submission-time
    admission gates only. Once recorded, approval does not later expire or
    become invalid through revocation. Only explicit adjudicated supersession
    under the artist identity rules may invalidate it.
15. Governance V2 supplies the terminal-freeze delay, cancellation, veto,
    expiry, and retry behavior. The artist-unavailability notice is an
    additional execution-time timestamp gate and its exact end is snapshotted.
16. A successful append activates exactly one route generation. Any revert
    leaves the action unconsumed and every head, record, plan, and count
    unchanged.
17. Refresh state advances before the Core call under a reentrancy guard, but
    transaction rollback restores every field and suppresses progress events
    when Core rejects.
18. Missing, wrong-scope, complete, superseded, inactive, or manifest-mismatched
    plans reject continuation.

## Proposed Error Catalog

| Error | Selector |
| --- | --- |
| `FinalityRecoveryActionClassInvalid(uint8)` | `0x49df07fb` |
| `FinalityRecoveryActionConsumed(bytes32)` | `0x8bb6ca36` |
| `FinalityRecoveryArtistEvidenceInvalid()` | `0xe1b6cff5` |
| `FinalityRecoveryArtistEvidenceUnreadable()` | `0x1ad3dc58` |
| `FinalityRecoveryCalldataTooLarge(uint256,uint256)` | `0x851c21d6` |
| `FinalityRecoveryCallerNotExecutor(address)` | `0x1476bae7` |
| `FinalityRecoveryDependencyHasNoCode(address)` | `0xb9f3830f` |
| `FinalityRecoveryDependencyInterfaceUnsupported(address,bytes4)` | `0x8fe3d887` |
| `FinalityRecoveryExecutionContextMissing()` | `0x5953c622` |
| `FinalityRecoveryGenerationOverflow(bytes32)` | `0x687a1706` |
| `FinalityRecoveryManifestBytesInvalid()` | `0x7b1d6399` |
| `FinalityRecoveryManifestBytesMissing(bytes32)` | `0x6bc022a8` |
| `FinalityRecoveryManifestIntentMismatch(bytes32,bytes32)` | `0x3e7d673f` |
| `FinalityRecoveryManifestInvalid()` | `0xc08b2f3d` |
| `FinalityRecoveryOldRouteMismatch(bytes32,bytes32)` | `0x137354f1` |
| `FinalityRecoveryOriginalRecordMismatch(bytes32,bytes32)` | `0xed17a2ba` |
| `FinalityRecoveryOriginalRecordMissing(bytes32)` | `0x6bbf39b8` |
| `FinalityRecoveryOwnerEvidenceInvalid()` | `0xf17d89ad` |
| `FinalityRecoveryOwnerEvidenceUnreadable()` | `0x781ae739` |
| `FinalityRecoveryPredecessorMismatch(bytes32,bytes32)` | `0x0ec06b7e` |
| `FinalityRecoveryReasonHashZero()` | `0xc5387390` |
| `FinalityRecoveryRecordMissing(bytes32)` | `0xa6859b78` |
| `FinalityRecoveryRefreshPlanComplete(bytes32)` | `0x1abf597e` |
| `FinalityRecoveryRefreshPlanInactive(bytes32,bytes32)` | `0x01bb61f5` |
| `FinalityRecoveryRefreshPlanMismatch(bytes32)` | `0x2dc681ca` |
| `FinalityRecoveryRefreshPlanMissing(bytes32)` | `0x7352a53e` |
| `FinalityRecoveryRefreshReentrancy()` | `0x5815b1ed` |
| `FinalityRecoveryReplacementTypeMismatch(bytes32,bytes32)` | `0x6cc1f5d0` |
| `FinalityRecoveryReplacementUnreadable(bytes32,address)` | `0xc5b847b8` |
| `FinalityRecoveryRouteAmbiguous(bytes32)` | `0x21817bdc` |
| `FinalityRecoveryRouteMissing(bytes32)` | `0xca1179da` |
| `FinalityRecoveryScopeShapeInvalid()` | `0x43f6b879` |
| `FinalityRecoveryTransitionContextMismatch()` | `0x2481c9eb` |
| `FinalityRecoveryUnavailabilityNoticeOpen(uint64)` | `0x60f912eb` |
| `FinalityRecoveryZeroAddress()` | `0x252d6657` |
| `IncompleteFinalityRecoveryRefreshPlans(uint256)` | `0x0b37b37c` |

The four existing refresh/count errors whose signatures remain present keep
their selectors. All other error compatibility is intentionally broken if this
ADR is Accepted.

The exact Draft error migration is:

| Draft error | Selector | Proposed disposition |
| --- | --- | --- |
| `RecoveryManifestContentHashZero()` | `0x0d5f7f65` | Remove; typed manifest invalid/missing/intent-mismatch errors replace it. |
| `FinalityRecoveryRefreshPlanMissing(bytes32)` | `0x7352a53e` | Retain unchanged. |
| `FinalityRecoveryRefreshPlanComplete(bytes32)` | `0x1abf597e` | Retain unchanged. |
| `FinalityRecoveryRefreshPlanInactive(bytes32,bytes32)` | `0x01bb61f5` | Retain unchanged. |
| `FinalityRecoveryRefreshPlanMismatch(bytes32)` | `0x2dc681ca` | Retain unchanged. |
| `IncompleteFinalityRecoveryRefreshPlans(uint256)` | `0x0b37b37c` | Retain unchanged. |

## Route Resolution And Refresh Semantics

Historical finality and current route health are separate facts:

- `resolvedFinalityRoute` selects an exact recovery first, then exact permanent
  finality, then an inherited collection recovery, then inherited collection
  permanent finality.
- A stored route is historically pinned even if its component later loses
  code, changes codehash, reverts, returns malformed/oversized data, reports
  unfrozen state, or drifts from the stored expectation.
- `finalityRecoveryRouteStatus` reports both the historical pin and current
  exact live match. It does not rewrite history.
- Original component types must be unique for a recoverable route. A duplicate
  type fails closed rather than guessing which historical route to replace.

The exact selection and append matrix is:

| Requested scope state | Selected route before a new exact append | `originalFinalityRecordHash` | `predecessorRecoveryId` / old generation | Mutation on success |
| --- | --- | --- | --- | --- |
| `COLLECTION` with collection recovery head | Collection recovery override for `routeType`, otherwise the collection permanent component | Collection permanent record | Collection head / collection generation | Append and replace collection head |
| `COLLECTION` without recovery head | Collection permanent component | Collection permanent record | zero / `0` | Append collection generation `1` |
| Non-collection scope with exact recovery head | Exact recovery override for `routeType`, otherwise the permanent component belonging to that exact lineage | Original record captured by the exact lineage | Exact head / exact generation | Append and replace only the exact head |
| Non-collection scope with exact permanent finality and no exact recovery | Exact permanent component | Exact permanent record | zero / `0` | Append exact generation `1` |
| Non-collection scope without exact permanent finality or recovery, but with collection recovery | Inherited collection recovery override for `routeType`, otherwise the collection permanent component | Collection permanent record | zero / `0`; the collection head is not a predecessor | Append exact generation `1`; collection head is unchanged |
| Non-collection scope without exact permanent finality or recovery and without collection recovery | Inherited collection permanent component | Collection permanent record | zero / `0` | Append exact generation `1`; collection state is unchanged |
| No exact or collection permanent finality | none | zero | n/a | Reject `FinalityRecoveryOriginalRecordMissing(scopeKey)` |

For every row, `oldRouteHash` is the `componentRouteHash` of the selected route
immediately before mutation. A request replacing component type `T` must carry
the hash selected for `T`; it cannot substitute another component type. When an
exact lineage began from collection inheritance, every successor keeps that
lineage's original collection finality-record hash. The later appearance of a
different exact permanent record does not silently rebase the recovery chain:
it is a base-record mismatch requiring separately reviewed migration semantics.

Read selection uses the same order but does not treat a broader collection head
as an exact predecessor. An exact permanent record suppresses collection
inheritance even when the collection has a newer recovery. Conversely, an exact
recovery begun from inherited collection finality remains the selected exact
route until explicitly superseded in its exact chain.

Every accepted replacement creates a refresh plan because this version always
classifies it artwork-affecting:

- `TOKEN` covers exactly its one token ID.
- Collection, release, season, and view cover
  `[1, lastAllocatedTokenIdAtExecution]`.
- A zero high-water mark creates an already-complete plan.
- Nonempty plans increment the global incomplete count once.
- One continuation emits at most 5,000 IDs and calls Core once.
- Completion decrements the count once.
- A successor marks an active incomplete predecessor plan superseded,
  decrements once, then creates a fresh full plan under the successor manifest
  and increments once when nonempty.
- A superseded plan cannot resume.

## Indexer And Integrator Migration

If Accepted, this is a pre-genesis breaking migration:

1. Schedulers stop calling the fourteen local collection/scoped lifecycle and
   read selectors. They schedule the exact companion calldata and transition
   commitments through Governance V2.
2. Indexers reconstruct pending, cancellation, veto, expiry, and retry state
   only from Governance V2 action records/events.
3. Indexers key executed recovery records by Governance action ID and join
   execution, lineage, evidence, and refresh events on that ID.
4. Scheduled and cancelled recovery events disappear from the recovery target.
   Execution and refresh topics remain, while manifest-staged, lineage, and
   evidence-snapshot topics are added.
5. Collection and scoped plan/read paths collapse into unified scope-aware
   calls. The current companion is discovered only through Core's
   `ARTWORK_FINALITY_RECOVERY` pointer. The current metadata router uses its
   `resolvedFinalityRoute(routeType, scope)` result as the serving route.
6. Permanent-registry `verifyFinality` and `verifyArtworkScopeFinality` remain
   diagnostics of the immutable original finality record and original component
   set. They do not report a recovered serving route. Indexers that need serving
   truth join those historical reads with the companion's exact
   `resolvedFinalityRoute`, `finalityRecoveryRouteStatus`, record, and lineage
   outputs.
7. Consumers must distinguish historical `pinned` from
   `currentRouteMatches`; an active recovery record is not proof that the live
   component still conforms.
8. A route index is keyed by `(pointer revision, routeType, canonical
   scopeKey)`. It records `componentRouteHash`,
   `originalFinalityRecordHash`, and the route-specific `recoveryId`. A zero
   `recoveryId` means the companion selected the permanent original component;
   it does not mean the companion was bypassed.
9. ABI, error, event, domain, numeric-ID, pointer, interface, monitoring,
   state-export,
   acquisition/condition, and deployment catalogs must all migrate together.
10. Repository history is the only archive of the superseded pre-genesis Draft
   interface. No onchain state migration exists.

## Dependencies And Non-Goals

Dependencies before acceptance or source authorization:

- #670 must publish the canonical artist recovery-evidence interface and
  installable target. The proposed consumer only reads and snapshots it.
- #688 must settle the canonical Governance action identity/context consumed
  by this target.
- #654 must add the exact `ARTWORK_FINALITY_RECOVERY` pointer family, admit
  only its current target to the recovery batch-refresh caller set, implement
  the real Core refresh emitter, and advertise the exact recovery Core
  interface:
  `lastAllocatedTokenId()` `0x254b22bc` XOR
  `emitBatchMetadataUpdate(uint256,uint256,bytes32)` `0x908c18bd`, ERC-165 ID
  `0xb5c73a01`, with `0xffffffff` rejected.
- #685 must enforce exactly one recovery append per Governance action, the
  closed-world action policy, and the exact adjacent old-companion
  zero-count/`ARTWORK_FINALITY_RECOVERY` pointer-update batch shape.
- An installable `StreamOwnerRecords`-hosted target must advertise IERC-165 and
  the one-selector `IStreamFinalityRecoveryOwnerEvidence` interface before
  acceptance or source authorization:

  ```solidity
  function verifyRecoveryOwnerEvidence(
      StreamFinalityScope calldata scope,
      bytes32 recoveryId,
      bytes32 recoveryManifestHash
  )
      external
      view
      returns (
          bool valid,
          bytes32 evidenceHash,
          uint64 revision,
          uint32 acknowledgementCount,
          uint32 objectionCount
      );
  ```

  Its canonical selector and interface ID are both `0x20279cd8`. The target
  owns append-only owner acknowledgements, objections, accumulator/hash, and
  revision semantics; #667 only performs an exact-size read and snapshots the
  returned revision. Missing code, missing IERC-165/`0x20279cd8`, `0xffffffff`
  acceptance, revert, malformed return, `valid = false`, zero evidence hash, or
  zero revision fails before mutation. No implementation owner or tracker is
  assigned yet, so this is an explicit acceptance and source blocker rather
  than a production-only follow-up.
- The metadata-router serving integration defined under topology must have an
  explicit implementation owner and real-target tests before acceptance or
  source authorization. An offchain convention or deployment promise is not a
  serving integration.

Non-goals:

- no Governance V2 redesign or action-policy edit in this ADR;
- no Core or metadata-router implementation or bytecode change in this
  Proposed ADR, and no Core edit in #667;
- no artist-registry write, authority, nonce, revocation, or storage change;
- no owner-records implementation;
- no change to the permanent finality interface or original finality storage;
- no legacy compatibility wrapper;
- no claim that mocks prove installability or deployment completeness;
- no state-export publisher from #668;
- no production, public-beta, audit-complete, deployment, or release-readiness
  claim.

## Normative Reconciliation Inventory

This Proposed slice does not edit any row below. If ADR 0020 is later Accepted,
the separate acceptance/reconciliation slice must disposition every row
explicitly; it may not relabel the old blocks silently.

| Normative file / anchor | Required later disposition |
| --- | --- |
| `docs/stream-long-term-architecture.md` `[LTA-FINALITY]`, access-control rules 3-5 | Replace local finality-admin schedule/cancel and permissionless local-delay execution with Governance V2 action authority while retaining the artist gate. |
| `docs/stream-long-term-architecture.md` `[LTA-FINALITY]`, scoped-finality scope rules 7-8 | Replace the separate scoped status machine and legacy scoped recovery-ID preimage; retain exact-scope identity and deterministic broader-record coexistence. |
| `docs/stream-long-term-architecture.md` `[LTA-FINALITY]`, “Scoped recovery mirrors collection recovery” | Remove or mark superseded every separate scoped schedule/cancel/execute/record/active/plan/continue signature and scheduled/cancelled event. |
| `docs/stream-long-term-architecture.md` `[LTA-FINALITY]`, “Finality Recovery” functions/events/selectors and rules 1-18 | Reconcile local status/storage, legacy recovery-ID preimage, authority/timing, caller-supplied artwork-change class, selector and exact-return block, evidence, route resolution, permanent-verify compatibility, refresh, supersession, count, monitoring, and pointer-cutover wording to the accepted interface. |
| `docs/stream-long-term-architecture.md` `[LTA-POINTERS]` inventory and pointer lifecycle | Add the exact `ARTWORK_FINALITY_RECOVERY` key/module/interface family and change the old-companion drain assertion adjacency without replacing `ARTWORK_FINALITY_REGISTRY`. |
| `docs/launch-v1-target-architecture.md`, artwork-recovery invalidation mirror | Replace separate continuation selectors and document the exact Core auxiliary dependency without adding Core bytecode in #667. |
| `docs/metadata-router-and-renderer.md` `[MRR-FINALITY]` and `[MRR-REFRESH-EMITTERS]` | Make the current recovery pointer the frozen-route serving resolver and add its current target to the exact Core batch-emitter caller set through #654; retain the permanent registry as original-history owner. |
| `docs/launch-conformance-matrix.md` `[LCM-GOLDEN]` gate 17 | Replace local scheduling and split continuation/read goldens; add action-context, one-append-per-action cardinality, exact return schemas, manifest-intent, lineage/evidence, inherited-route, serving-pointer, fail-closed artwork-change, and exact dependency gates. |
| `docs/adr/0004-admin-governance.md` `[GOV-ACTION-ID]` | Cite recovery action ID ownership and exact target-side scope/old/new commitments. |
| `docs/adr/0004-admin-governance.md` `[GOV-BATCH]` | Pin exactly one recovery append per batch plus the exact adjacent predecessor assertion/pointer update and bypass negatives through #685's accepted policy. |
| `docs/adr/0004-admin-governance.md` `[GOV-V2-CUTOVER]` | Add the recovery companion to the exact accepted Governance V2 host/cutover inventory after dependency acceptance. |
| `docs/stream-artist-authority.md` `[AA-RECOVERY]` | Cite the canonical manifest-bound execution read and preserve append-only recorded-approval semantics; keep artist writes and authority in #670. |
| `docs/collection-metadata-contract.md`, owner-record recovery-response rules and acquisition/condition surfaces | Pin the owner evidence read/snapshot and downstream display/export fields without moving owner writes into #667. |
| `docs/spec-policy.md` event/domain/interface catalog requirements and `docs/launch-conformance-matrix.md` `[LCM-EVENTS]` | Reconcile generated one-fact/one-owner events, topic/indexed masks, interface IDs, and domain tables only after acceptance. |

Maturity documents and release artifacts are downstream evidence rather than
normative authority. They remain unchanged in this Proposed slice and must
continue to report the missing production dependencies if a later accepted
train updates them.

## Alternatives

### Preserve local wrappers

Rejected by this proposal. Schedule/cancel wrappers require local authority and
pending state or become misleading aliases for Governance actions. Either form
preserves a second lifecycle or an ABI whose event/state meaning no longer
matches its signature.

### Keep separate collection and scoped companions

Rejected by this proposal. One canonical scope tuple gives identical
authorization, lineage, evidence, and refresh behavior while making
exact-versus-inherited precedence explicit.

### Treat equal `dataHash` as byte-equivalent

Rejected. Component-owned `dataHash` schemas do not generically prove that two
component addresses, code hashes, versions, manifests, and served bytes are
equivalent.

### Mutate the original finality record

Rejected. Recovery must preserve the historical statement and append the
current serving route separately.

### Implement before change control

Rejected. The existing LTA/LCM exact pins remain authoritative until an
Accepted ADR and an explicit reconciliation slice supersede them.

## Security And Bytecode Impact

The proposed single authority removes schedule/cancel state divergence and
binds every append to Governance V2's current action and exact transition
commitments. Manifest-bound intent prevents an artist-approved manifest from
being paired with a different route, scope, reason, or lineage. Append-only
heads and consumed action IDs prevent replay and stale overwrite. Exact-size
dependency reads, live route matching, and mandatory evidence fail closed.

Residual risks requiring review:

- the proposed companion is a large security-sensitive contract;
- route-type uniqueness intentionally makes some historically valid duplicate
  component sets unrecoverable through this version;
- a global-ID refresh superset may invalidate unrelated IDs but is safer than
  missing affected non-enumerable members;
- operator/indexer migration is breaking;
- missing real owner, artist, Core pointer/emitter, metadata-router serving,
  and Governance policy integrations prevent acceptance, source authorization,
  and production proof; and
- predecessor zero-count/pointer adjacency is outside the companion and must be
  enforced by the accepted Governance action policy.

No Core bytecode is added by this Proposed ADR or by #667. #654 owns the
required Core pointer and caller-set change. Any future source PR must rebase
the then-current main, measure optimized runtime size, and run a live canonical
Slither semantic comparison. It cannot rely on a static-analysis artifact
generated before the new Solidity exists.

## Release Impact

This Proposed ADR changes no release artifact.

If later Accepted, the change is a pre-genesis MAJOR auxiliary-interface
cutover. The acceptance/reconciliation and source train must update, in
documented generator order:

- the LTA and protocol-v1 mirrors;
- LCM gate 17 and traceability;
- ABI, selector, error, event, interface-ID, and domain goldens;
- generated interface and event catalogs;
- the Core pointer inventory, module registry, metadata-router serving
  bindings, and deployment profile;
- monitoring, indexer, state-export, acquisition, and condition-report
  migration notes;
- the deployment candidate only after its real dependencies are installable;
- Slither baseline/fingerprint/disposition for the actual new Solidity; and
- downstream release notes, manifest, bytecode proof, lockfile, and checksums.

The implementation train is ordered after the currently authorized #658 train.
Any source authorization must rebase current main and either own the new
static-analysis/release deltas in its tight PR or enter a separately serialized
#658 follow-up. Earlier evidence is not proof for later Solidity.

## Test Plan

Before acceptance:

- independent architecture and security review of every selector, event,
  commitment, evidence boundary, transition, and migration consequence;
- reconcile the exact ABI against merged #670, #688, #654, and #685 outcomes,
  the installable owner-evidence target, and the metadata-router serving
  integration;
- prove no permanent finality interface change and no legacy wrapper;
- prove exact pointer discovery, one recovery append per Governance action, and
  no direct-original serving fallback after companion installation;
- decide whether duplicate component types require a versioned route-identity
  model before acceptance.

After acceptance and source authorization:

- golden tests for every function/error selector, event topic/indexed mask,
  interface ID, domain hash, canonical intent, action scope, old-state, and
  new-state preimage;
- direct caller, missing/zero/wrong action context, wrong class, stale
  predecessor, replay, scope/old/new substitution, malformed scope, original
  mismatch, manifest substitution, route drift, and ambiguous route tests;
- approval, unavailability, owner evidence, short/oversized/malformed return,
  post-record deadline/revocation, and adjudicated supersession tests against
  real merged targets;
- exact scoped precedence and inherited collection recovery tests;
- empty, token, 5,000-boundary, multi-chunk, final-short-chunk, Core rollback,
  completion, supersession, inactive-plan, count, and reentrancy tests;
- exact-target Governance schedule/cancel/veto/expiry/retry and action-ID
  integration tests, including rejection of two recovery append calls in one
  batch and acceptance of distinct actions for distinct recoveries;
- predecessor zero-count/pointer adjacency and bypass-negative tests;
- metadata-router exact/inherited/original/recovered serving selection and
  missing/wrong/unreadable recovery-pointer fail-closed tests;
- optimized bytecode measurement, full Foundry suite, canonical Slither
  semantic comparison, repository check, deployment rehearsal, and release
  currentness.

Mocks may establish component behavior during development. They are not
deployment proof.

## Rollout

1. Merge this ADR only as Proposed review material.
2. Complete independent/security review and dependency reconciliation.
3. In a separate PR, either reject the proposal or mark ADR 0020 Accepted and
   explicitly supersede/reconcile every listed LTA, LCM, protocol-v1, catalog,
   and migration surface.
4. Only after that accepted reconciliation, authorize a new source branch from
   then-current `origin/main`.
5. Land the canonical dependency implementations, owner-evidence target,
   metadata-router serving integration, and exact Governance policy before any
   exact-target deployment candidate or readiness claim.
6. Regenerate static-analysis and release evidence from the final merged source.

This ADR does not authorize merge of any implementation, deployment, release,
or readiness promotion.

## Accepted Risks

No risk is accepted while this ADR remains Proposed.

If later Accepted, the protocol owner would accept:

- intentional pre-genesis ABI and indexer incompatibility;
- inability to recover an ambiguous duplicate-component-type route through
  this interface version;
- broad but bounded ERC-4906 invalidation supersets;
- permanent loss of a recovery action after its Governance window expires,
  requiring a new action ID and fresh review;
- mandatory dependency availability for artist, owner, Core, and Governance
  policy checks; and
- a larger replaceable companion plus a narrow Core pointer/caller-set and
  metadata-router integration surface in exchange for keeping the permanent
  finality registry and its interface unchanged.

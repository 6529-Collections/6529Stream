# Permanent WORK and RIGHTS selection seals

`StreamWorkRecordSelection` and `StreamRightsRecordSelection` can permanently
seal one `(collectionId, subjectId)` selected head. The local seal retains the
original record, selection revision and complete selection commitment. There is
no unlock or replacement route. Unknown or empty selected heads cannot be sealed.

This supplies a selected-head lock for CMC-LOCKS and the finality metadata input.
Core freeze alone does not supply it. Generic Metadata dossiers remain appendable;
later author records cannot replace a sealed authoritative selection. Other keys
remain independent. Existing WORK/CURATOR and RIGHTS grants retain their original
selection authority, but cannot bypass the seal.

## Preparing and executing a seal

Both hosts advertise the separate ERC165 `IStreamRecordSelectionLock` interface:

```solidity
selectionLockTransition(uint256 collectionId, bytes32 subjectId,
    bytes32 expectedRecord, uint64 expectedRevision)
    returns (bytes32 scopeHash, bytes32 oldValueHash, bytes32 newValueHash);

lockSelection(uint256 collectionId, bytes32 subjectId,
    bytes32 expectedRecord, uint64 expectedRevision);

selectionLock(uint256 collectionId, bytes32 subjectId)
    returns (SelectionLock memory);
```

Read the transition for the actual current head, then schedule that exact
`lockSelection` calldata and returned hashes under the canonical Executor's
`TERMINAL_FREEZE` class 2. The action policy catalog must admit the selector's
actual address, runtime and method as a zero-value class-2 target.

Preparation and execution recheck the original current-selection dependencies,
active interpretation definitions and applicable WORK association/catalog. They
also join the Metadata-fixed Executor and runtime to Core's MODULE_REGISTRY
pointer, its target runtime/interface and concrete `governanceExecutor()` getter.
The full canonical pointer tuple, current root runtime and root revision enter
the scheduled scope. Executor `owner()` must equal that root. Changing committed
pointer or root facts makes a prepared transition stale.

Execution requires the exact active per-call class-2 scope and old/new hashes,
plus the actual stored EXECUTED action and its root proposer. A batch's first
target may differ from the selector; the active per-call context identifies the
seal call. A direct root/Safe call or registered non-root proposer is insufficient.

The Executor owns delay, action policy and independent terminal guardian veto.
The guard preserves its genesis semantics: class 2 alone does not prove an elapsed
post-bootstrap 72-hour interval. The separate sealed-governance test profile
exercises that interval and veto. No second governance timer is introduced.

## Commitments and historical reads

The fixed 18-word `SelectionLock` tuple is, in order: `locked`, `recordHash`,
`revision`, `selectionHash`, `executor`, `executorCodeHash`, `moduleRegistry`,
`moduleRegistryCodeHash`, `modulePointerHash`, `governanceRoot`,
`governanceRootCodeHash`, `governanceRootRevision`, `actionId`, `scopeHash`,
`oldValueHash`, `newValueHash`, `lockedAt`, `lockHash`. Narrow fields retain their
declared ABI types. Unknown keys return the canonical empty tuple.

Original recorder, selector and grant facts remain in the original selection.
Seal authority is separate. `RecordSelectionLockedPermanently` indexes collection,
subject and original record and emits the full seal.

`scopeHash` uses domain `6529STREAM_RECORD_SELECTION_LOCK_SCOPE_V1` and commits
chain, selector, Core, Metadata, family, key, Executor/runtime, full pointer hash
and root/runtime/revision. `oldValueHash` and `newValueHash` use domain
`6529STREAM_RECORD_SELECTION_LOCK_STATE_V1`, the respective false/true flag,
and the exact five-field head. Action ID and execution time are absent from the
scheduling preimage.

`lockHash` uses domain `6529STREAM_RECORD_SELECTION_LOCK_RECORD_V1` and commits
chain, selector, Core, Metadata, family, key and the complete seal, with only its
own `lockHash` field zero while hashing. Families are `WORK_DESCRIPTION` and
`RIGHTS_STATEMENT`. Domains and families are keccak256 of the literal names;
structured preimages use `abi.encode`.

The lock getter and original raw history require no current grant, root,
ModuleRegistry, definition or provider liveness. Revocation never removes a seal.
`requireCurrent` retains its original checks for new consumption; sealing does
not freeze every external definition or association. Finality consumers must
bind the actual selection and matching seal alongside the remaining scope,
schema, authority and dependency facts.

Both WORK entrypoints and both RIGHTS witness routes check the same local lock
before any new selection. A later failure in a governance batch reverts the seal,
event and earlier writes atomically, leaving no partial permanent lock.

## Evidence boundaries

Selector fixtures deploy actual Metadata, Schema Registry, Store, selectors and
threshold Safe contracts; Core, artist owners and terminal Executor responses
remain explicit boundaries. A separate cohort uses the actual sealed Executor,
RoleRegistry and ModuleRegistry with the exact linked guard; Core, Metadata
identity and selected-head admission are explicit boundaries. These complementary
cohorts do not establish one complete deployed governance/Artist/Metadata/finality
assembly or maximum-transaction capacity.

Original interfaces, constructors, selection commitments and storage prefixes
are preserved. Each selector appends one lock map and advertises an additive
interface. Static dependency reads use the actual Metadata governed dependency
cap and parent-gas admission before the call. No Core operation, genesis role or
Artist operation is added.

# ADR 0018: Batch Operation Root And Token Identity

## Status

Accepted for pre-genesis implementation on 2026-07-26 under
[issue #688](https://github.com/6529-Collections/6529Stream/issues/688).
The conforming atomic manager/ledger/Core source cutover described below is
implemented in the current Solidity and generated as-built surfaces. This
implementation does not accept ADR 0019, close typed primary-settlement or
repeated-sale replay blockers, satisfy the final Core production-headroom
target, or provide production-readiness evidence.

This ADR amends the legacy paid-mint operation binding delegated by ADR 0008,
the prepared-mint identity decisions recorded by ADR 0012 decision T6, and the
paid-mint correlation language recorded by ADR 0014 decision V5. It does not
change their retained requirements for atomic settlement, exact Core
prepared-operation matching, or domain-separated structured hashing.

## Problem

The target specification describes one batch `operationRoot` and distinct
per-token `operationId` values, but also says that every state-changing
participant receives the same operation ID. Those statements cannot both hold
for a batch.

The current implementation exposes the same structural gap:

- one `StreamMintLedger.consume(...)` call accounts for the whole batch;
- `StreamMintManager` calls the ledger before deriving the batch root;
- the ledger neither receives nor stores the root or a token operation ID; and
- `StreamCore` compensates with an unbounded lifetime mapping of every prepared
  token operation ID.

That arrangement leaves no durable batch replay owner outside byte-constrained
Core, gives indexers no exact join from ledger accounting to prepared-token
events, and makes the target Core replay-state removal unsafe.

## Decision

### Cardinality And Domains

Every successful manager batch of quantity `N > 0`, whether it uses
`PRE_REVENUE_SINGLE_STEP` or `PREPARED_MINT`, has exactly:

- one nonzero `operationRoot`; and
- `N` nonzero, pairwise-distinct per-token `operationId` values.

The normative derivation lives in
[`docs/mint-policy-and-accounting.md`](../mint-policy-and-accounting.md)
`[MPA-OPERATION]`. It uses the final generic mint domains
`MINT_REQUEST_COMMITMENT_DOMAIN`, `MINT_OPERATION_ROOT_DOMAIN`, and
`MINT_TOKEN_OPERATION_ID_DOMAIN`, canonical validation-result, counter-
consumption, and nullifier domains, plus an exact execution-path constant for
the selected paid-mint orchestration path.

The manager reserves a contiguous nonce range
`[firstOperationNonce, firstOperationNonce + N)` before ledger consumption.
The root binds `firstOperationNonce` and `N`. Token `i` binds
`firstOperationNonce + i`, `i`, its token-data hash, and its mint commitment.
The manager advances `nextOperationNonce` by `N`. Any later revert unwinds that
reservation.

### Commitment Boundary

The request commitment binds the typed payer, `batch.authorizer`, recipient,
beneficiary, token-data-array, mint-commitment-array, and canonical
validated-result hashes in the exact order pinned by `[MPA-OPERATION]`. The
validated-result hash binds the gate address and canonical gate result,
ascending duplicate-free nullifiers, and the exact counter-order/token-index-
order `CounterConsumption[]` passed to the ledger; projected increments are
aggregated separately by `(counterId, valueKey)` for the pre-ledger cap check,
without changing that array preimage. Each consumption's `resolutionHash`
binds its canonical typed counter-resolver result. The outer root then binds
chain, manager, Core, ledger,
execution path, collection, phase, `currentPolicyHash`, `boundPolicyHash`,
authorization, request commitment, context, manager executor, nonce range, and
quantity. The request commitment also binds
`batch.expectedPolicyHash`; this deliberate redundancy prevents the accepted
request policy from being lost inside normalization while the root separately
commits live config identity. Each token operation ID
binds root, reserved token nonce, token index, token-data hash, and mint
commitment.

The manager entrypoints are nonpayable and asset-agnostic. They accept only
`MintBatch` plus presentation-only `gateData`; they expose no generic
settlement bytes, callback target, selector, value, or delegatecall.
`MintBatch.authorizationId` is a required nonzero typed request field. A
configured gate must return the same value, return
`GateResult.authorizer == batch.authorizer`, and return an authorizer kind valid
for that same address; an ungated phase consumes the
explicit request value, never an ID inferred from the root, context, or
presentation bytes. Raw
signature, Merkle-proof, and resolver-proof encodings may be excluded from the
root only because their canonical validated values/results are bound. Two
equivalent presentations that produce the same canonical result derive the
same operation identity; changing any state- or economics-affecting typed value
or validated result inside the manager/ledger mint boundary changes it. The
decision deliberately does not synthesize a primary-settlement result field;
ADR 0019 / issue #694 must bind that component's exact typed result and
execution key under its accepted ABI.

Signed sale authority is separate from root uniqueness. The accepted
`SALE_AUTHORIZATION_TYPEHASH` additionally binds `tokenDataArrayHash` and
`mintCommitmentsHash`; a unique root cannot authorize content the signer did
not commit.

`MintBatch.expectedPolicyHash` appears immediately before `authorizationId`.
The manager accepts it only as the nonzero current registered policy hash or
the exact unexpired immediate predecessor, where the ledger stores
`previousPolicyHash`, `previousPolicyRevision`, and
`previousPolicyGraceUntil`, the revision is current minus one, and
`block.timestamp <= previousPolicyGraceUntil`. A second rotation overwrites
that tuple and invalidates the older predecessor. The manager then defines
`boundPolicyHash = batch.expectedPolicyHash`. A configured gate and its signed
payload bind that same value; configured and ungated phases accept the current
or valid immediate-predecessor identity, while ungated authorizer
normalization remains the exact zero/NONE tuple. The operation root explicitly
binds `currentPolicyHash` then `boundPolicyHash`; the preview returns identities
whose root commits both. `MintBatchExecuted` and the central
`MintLedgerOperationRootConsumed` carry both hashes. Child ledger counter,
authorization, and nullifier events carry `boundPolicyHash` and join through
the root; configuration and consent events carry current identity. Current
consent, modules, counter policies, caps, and increments govern execution even
when the predecessor identity is accepted. ADR 0019 / issue #694 owns exact
sale/settlement propagation of both where applicable.

### Identity Ownership

Identity follows the scope of the state transition:

| Participant | Identity it owns or verifies |
| --- | --- |
| Sale adapter | Batch `operationRoot`; a token `operationId` only for a token-scoped settlement record |
| Mint manager | Root derivation, nonce-range reservation, all token operation IDs, and batch/token events |
| Mint ledger | Manager-scoped durable `operationRoot` replay; no token operation-ID storage |
| Core prepare/complete/abort | Current token's `operationId`; no batch root and no lifetime replay mapping |
| Revenue resolver snapshot | Batch root plus the current token operation ID |
| Primary settlement or escrow | Batch root, plus the token operation ID when the settlement record is token-scoped |
| Entropy registration | Core token ID and `mintCommitment`; no batch root or operation-ID replay ownership |

Core's prepared ABI remains token-scoped. The root is deliberately not added to
Core storage, Core events, or Core external mint selectors. Entropy registration
also remains keyed by authoritative Core token identity and mint commitment.
Those exclusions are part of the decision, not missing propagation.

### Ledger ABI And Replay

The final argument order is:

```solidity
function consume(
    uint256 collectionId,
    bytes32 phaseId,
    CounterConsumption[] calldata consumptions,
    bytes32 authorizationId,
    bytes32[] calldata nullifiers,
    bytes32 boundPolicyHash,
    bytes32 operationRoot
) external;
```

The ledger stores:

```solidity
mapping(address manager => mapping(bytes32 operationRoot => bool))
    private _operationRootUsed;
```

It exposes the caller-independent read:

```solidity
function isManagerOperationRootUsed(address manager, bytes32 operationRoot)
    external
    view
    returns (bool);
```

The ledger rejects a zero root and a root already used in the calling manager's
scope before any ledger write. The same raw root may be used once by each of two
different authorized managers; correctly derived roots already bind the
manager address, but storage scoping does not rely on that cryptographic fact.

The manager passes the exact batch `collectionId` and `phaseId`; the ledger
uses `msg.sender` as manager scope and independently loads
`currentPolicyHash` from
`registeredPhasePolicyHashes[msg.sender][collectionId][phaseId]`. A zero or
missing registration fails before writes. The caller never supplies
`currentPolicyHash`, and the ledger never infers phase identity from counter
rows or calls the manager.

The ledger accepts nonzero `boundPolicyHash` only as the loaded current hash or
the exact stored immediate predecessor with adjacent revision and unexpired
grace. Every counter row must match the explicit collection/phase tuple, and
current registered counter policies, caps, and increments always govern.
`consumptions` may be empty: the ledger still validates and consumes the root
plus any authorization/nullifiers and emits one
`MintLedgerOperationRootConsumed` with loaded current plus supplied bound hash,
but emits no counter or counter-context event. The ledger validates caller
scope, phase registration, policy continuity, root, authorization, nullifiers,
counter keys, increments, aggregation, and caps before writing any of them. An
unregistered phase, cross-phase row, invalid bound hash, replay, counter
mismatch, or downstream manager, Core, resolver, settlement, entropy, or
receiver failure reverts all ledger writes, events, and the manager nonce
reservation.

### Single-Step Identity

`PRE_REVENUE_SINGLE_STEP` uses the same
one-root-plus-`N`-token-operation-ID model. Its
distinct execution-path constant prevents a prepared operation and a
single-step operation with otherwise identical inputs from sharing an
identity.

A sale adapter that records a deposit before entering the manager first calls:

```solidity
function previewSingleStepMintOperation(
    MintBatch calldata batch,
    bytes calldata gateData
) external view returns (
    bytes32 operationRoot,
    bytes32[] memory operationIds
);
```

The preview is manager-owned, is safe for a `STATICCALL`, uses its `msg.sender`
as executor, calls the configured gate and resolvers from the manager, shares
byte-identical normalization and derivation code with execution, reads the
current `nextOperationNonce`, and returns exactly `batch.beneficiaries.length`
token operation IDs. It emits and writes nothing, consumes no replay state,
and exposes no callback, settlement, value, or delegatecall surface. Because
the adapter calls it, the executor term is exactly the adapter's
`address(this)`; it is never an external caller, payer, relayer, or `tx.origin`.
Direct and relayed adapter calls carrying the same valid signed request
therefore preview the same identity. The adapter records that root with the
settlement, calls the manager in the same top-level transaction, and compares
the returned root and token operation ID vector with the preview. A caller
substitution, nonce race, changed policy/gate/resolver result, any request
mutation, or vector mismatch reverts the whole transaction, including the
earlier deposit. The generic `canMint` helper is non-authoritative for operation
identity. Free or executor-only single-step batches still derive and consume
the root even when no settlement record exists.

The immediate Core `mintFromManager` selector does not gain an operation-ID
argument. The manager's per-token event is the canonical root-to-token join for
single-step mints.

### Settlement Invariant And Open Blocker

This decision does not invent or freeze ADR 0019 / issue #694's typed
primary-settlement callback. It pins only the invariant required by operation
identity:

- prepared execution verifies the explicit manager/root through the ledger and
  the current Core token operation ID before any resolver or settlement effect;
- single-step execution preserves preview -> settlement -> manager-return
  comparison with whole-transaction rollback; and
- no generic bytes/target/selector/value/delegatecall callback enters the
  manager ABI.

The current revenue `settlementKey` also collides for repeated otherwise
identical purchases because it lacks an execution ID. `operationRoot` is not a
universal key: non-mint custody transfers have no root, while one batch root may
cover multiple token-scoped facts. ADR 0019 / issue #694 must define the exact
typed invocation, hostile callback cases, and execution-ID-bound distinct-key
and replay tests. Until then, settlement integration and repeated-sale
correlation/replay are explicit production blockers and are not closed by ADR
0018.

### Events

The mint-policy and revenue specifications pin the final event signatures. The
required facts are:

1. one ledger root-consumption event per batch;
2. the root on each ledger counter, authorization, and nullifier consumption
   event;
3. one manager batch event keyed by the root;
4. one path-specific manager completion event per element keyed by its
   operation ID and joined to the root — `MintTokenExecuted` for single-step
   or `PreparedMintCompleted` for prepared;
5. the root on the distinct prepared-start event;
6. root and token operation ID on token-scoped resolver and settlement facts;
   and
7. token ID and mint commitment, not a synthetic operation identity, on the
   entropy registration boundary.

The generated event catalog is an as-built artifact and publishes these rows
only because the atomic implementation cutover now defines them in Solidity.
ADR text alone never authorizes a spec-only PR to publish unimplemented ABI or
event rows.

`TokenRoyaltySnapshotted` is a newly introduced event, so its declaration
starts with `uint16 schemaVersion`. Its token operation ID, token ID, and root
remain indexed. The snapshot hook is `PREPARED_MINT`-only and verifies both
ledger manager/root replay and the current Core prepared-record operation ID
before writing. A `PRE_REVENUE_SINGLE_STEP` policy requiring a token-level
primary or royalty snapshot is rejected; no third snapshot proof is introduced.

### Atomic Cutover And Core Replay Removal

The implementation cutover is one deployable transition, even if developed in
multiple commits:

1. add the ledger root storage, explicit read, validation, and final events;
2. update the manager to derive all identities and reserve the nonce range
   before calling the final ledger ABI;
3. remove the superseded `mint(MintBatch,bytes)` manager entry, migrate every
   manager, sale, resolver, settlement, test, and monitoring call site to the
   nonpayable two-entry root/token ownership model, and do not support a co-live
   final manager ABI;
4. prove zero/reused root rejection, manager scoping, cardinality, event joins,
   and whole-transaction rollback;
5. remove Core's lifetime prepared-operation replay mapping while retaining
   only the current `PreparedMintRecord.operationId` equality lock; and
6. regenerate ABI, event, protocol-surface, bytecode, release, lockfile, and
   checksum artifacts from the final source state.

No commit, release candidate, deployment, or supported mixed mode may combine
the old ledger ABI with a Core that has already removed lifetime replay state.
Because 6529Stream has no production deployment, this is a pre-genesis source
cutover, not an in-place storage migration.

## Alternatives Considered

### One Shared Operation ID For The Whole Batch

Rejected. Core's prepared lock and token-scoped resolver work require distinct
identities, and one shared value cannot unambiguously identify `N` token
transitions.

### Ledger Stores Every Token Operation ID

Rejected. The ledger consumes one batch and owns batch replay. Storing `N`
token operation IDs duplicates manager/Core token facts, increases permanent storage,
and provides no stronger replay guarantee than one consumed root.

### Core Retains Lifetime Replay Storage

Rejected for the production target. It spent permanent Core bytecode and one
storage slot per prepared token to compensate for missing batch replay at the
ledger boundary. The atomic cutover removes that lifetime mapping after the
ledger assumes manager-scoped root replay; Core retains only current
prepared-pair equality.

### Authorization ID Is The Batch Replay Key

Rejected. Authorization and operation identities have different lifecycles.
An authorization may cover policy and signer replay while the operation root
also binds manager, Core, ledger, executor, path, nonce range, quantity, and the
listed typed request/value/result digests.

### Prepared Mints Alone Get Operation Identity

Rejected. Single-step settlement needs an exact batch join and the ledger must
have one uniform replay rule for every consuming manager path.

## Security And Bytecode Impact

Manager-scoped ledger replay closes the gap that currently makes Core lifetime
replay storage load-bearing. Per-token operation IDs remain collision-separated by root,
nonce, index, token data, and mint commitment. Explicit execution-path binding
prevents cross-path identity confusion. Validation-before-write and EVM atomic
rollback preserve counters, authorizations, nullifiers, manager nonces,
prepared state, revenue, and entropy state on every downstream failure.

The decision text itself changed no Solidity bytecode. Its atomic
implementation adds ledger/manager code and removes Core replay code. Any Core
size claim comes from deterministic release-bytecode evidence after all
mandatory hooks compile together. The exact production requirement remains at
least 2,000 bytes of EIP-170 headroom (`StreamCore` runtime at or below 22,576
bytes), with restoration to the approved 22,184-byte baseline as the objective.

## Release Impact

This is an accepted pre-genesis MAJOR target correction. No production
deployment used the superseded prepared-only domains, rootless ledger ABI, or
ambiguous shared-operation language.

The earlier acceptance slice updated the ADR/spec/checker and planning inputs
without changing contract bytecode. The atomic implementation cutover now
regenerates every ABI-, event-, source-, bytecode-, protocol-surface-,
release-, lockfile-, and checksum-dependent artifact from the canonical
generators in documented order.

## Test Plan

- Spec checker tests recompute every identity-domain hash and fail on drift in
  the root cardinality, full normalized request/result/root/token preimage
  sequences, ledger ABI order, replay read, mutability/callback ownership, and
  Core ownership statements.
- Quantity `N` produces exactly one nonzero root and `N` nonzero pairwise
  distinct token operation IDs.
- Token operation IDs change when the root, reserved token nonce, token index,
  token-data hash, or mint commitment changes.
- Zero roots and reused roots fail before ledger writes.
- The same raw root is isolated by manager scope; one manager cannot consume or
  pre-consume another manager's root.
- Single-step and prepared batches with otherwise identical inputs derive
  different roots.
- Direct and relayed adapter calls with the same signed request derive the same
  preview because the executor is adapter `address(this)`; payer, relayer,
  external-caller, and `tx.origin` substitutions fail.
- Preview is `external view`, staticcall-safe, state- and event-free, and
  returns exactly `N` token operation IDs. Changed caller, nonce, expected
  policy, gate/resolver result, request field, or vector length changes the
  preview or makes execution fail; any preview/execution race rolls back the
  deposit.
- Configured and ungated execution accept the current or one unexpired
  immediate-predecessor policy identity; expired, non-immediate, substituted,
  zero, and gate-mismatched hashes fail. Missing current-policy artist consent
  fails even when predecessor identity is valid. Boundary tests cover one
  second before, exactly at, and one second after
  `previousPolicyGraceUntil`, and a second rotation invalidates the older
  predecessor.
- Current consent, modules, counter policies, caps, and increments govern
  predecessor-bound execution. The root commits `currentPolicyHash` and
  `boundPolicyHash`; central ledger/root and manager/batch events carry both;
  child counter, authorization, and nullifier events carry the bound hash and
  join through the root. Preview/execution mutation, substitution, omission,
  and rotation races prove these facts.
- Configured gates reject authorizer/address-kind disagreement, zero or
  mismatched authorizers, `CALLER_ADAPTER` inconsistency, and any result that
  differs from `batch.authorizer`; ungated normalization remains the exact
  zero/NONE tuple.
- Every typed request, validated-result, root, and token preimage field has a
  mutation negative. Equivalent signature/Merkle/resolver proof encodings with
  the same canonical result preserve identity; a changed result does not.
- Manager ABI negatives reject `payable`, generic settlement bytes, callback
  target/selector/value, and delegatecall absent later accepted change control.
- Sale-authorization negatives reject token-data-array or mint-commitment-array
  drift. ADR 0019 / #694 later owns distinct repeated-purchase keys and hostile
  typed-settlement callback tests.
- Ledger root, counter, authorization, and nullifier events join to the manager
  batch event; each manager token event joins one token operation ID to that
  root.
- Resolver and token-scoped settlement reject a mismatched root or token
  operation ID. Entropy registration proves its token-ID/mint-commitment
  boundary without acquiring replay ownership.
- `snapshotTokenRoyaltyAtMint` succeeds only on `PREPARED_MINT` with the
  existing prepared-record proof; single-step rejects snapshot-required
  policies before any deposit, ledger, token, or snapshot effect.
- Counter failure, authorization/nullifier failure, Core prepare/completion
  failure, resolver failure, settlement failure, entropy-registration failure,
  receiver rejection, and a later-token failure all roll back root use,
  counters, authorization/nullifiers, manager nonce, token identities,
  prepared state, revenue/snapshots, and entropy state for the whole batch.
- After lifetime Core replay removal, a reused token operation ID remains
  impossible through a fresh ledger-accepted root, and the current prepared
  pair still rejects zero or mismatched IDs.
- Focused checks run first, followed by the proportional full validation and
  deterministic release-artifact ladder.

## Rollout

Implement the atomic cutover from a fresh `origin/main` branch, run focused
behavioral tests, then the full Foundry/check/release validation ladder.
Independent review must verify the final diff and generated-artifact scope
before a review-ready PR is handed to the merge coordinator.

This rollout authorizes no merge, deployment, release, live-chain action, or
readiness claim.

## Non-Goals

- No typed primary-settlement callback or execution-ID-bound repeated-sale key.
- No new Core external selector or Core event.
- No entropy replay or settlement-policy redesign.
- No governance/gas work owned by issues `#684`, `#685`, `#669`, `#671`, or
  `#673`.
- No production-readiness or audit-completion claim.

## Known Risks

- Pre-manager single-step root preview can race another transaction; the safe
  outcome is full transaction revert and caller retry.
- Manager and ledger storage grow outside Core to preserve the smaller
  permanent Core boundary.
- Exact typed primary settlement and execution-ID-bound repeated-sale replay
  remain ADR 0019 / issue #694 blockers.
- The final complete Core build still must include every mandatory hook and
  measure at or below 22,576 bytes; this cutover alone is not production-size
  conformance.

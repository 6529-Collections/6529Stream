# ADR 0018: Batch Operation Root And Token Identity

## Status

Accepted for the pre-genesis production target on 2026-07-24 under explicit
protocol-owner direction in
[issue #688](https://github.com/6529-Collections/6529Stream/issues/688).

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
events, and makes the proposed Core replay-state removal unsafe.

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
`MINT_TOKEN_OPERATION_ID_DOMAIN`, plus an exact execution-path constant for
the selected paid-mint orchestration path.

The manager reserves a contiguous nonce range
`[firstOperationNonce, firstOperationNonce + N)` before ledger consumption.
The root binds `firstOperationNonce` and `N`. Token `i` binds
`firstOperationNonce + i`, `i`, its token-data hash, and its mint commitment.
The manager advances `nextOperationNonce` by `N`. Any later revert unwinds that
reservation.

### Identity Ownership

Identity follows the scope of the state transition:

| Participant | Identity it owns or verifies |
| --- | --- |
| Sale adapter | Batch `operationRoot`; a token `operationId` only for a token-scoped settlement record |
| Mint manager | Root derivation, nonce-range reservation, all token IDs, and batch/token events |
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
    CounterConsumption[] calldata consumptions,
    bytes32 authorizationId,
    bytes32[] calldata nullifiers,
    bytes32 policyHash,
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

The ledger validates caller scope, registered policy, root, authorization,
nullifiers, counter keys, increments, aggregation, and caps before writing any
of them. It then consumes the root, counters, authorization, and nullifiers in
one call. A downstream manager, Core, resolver, settlement, entropy, or
receiver failure reverts all ledger writes and the manager nonce reservation.

### Single-Step Identity

`PRE_REVENUE_SINGLE_STEP` uses the same one-root-plus-`N`-token-ID model. Its
distinct execution-path constant prevents a prepared operation and a
single-step operation with otherwise identical inputs from sharing an
identity.

A sale adapter that records a deposit before entering the manager computes the
root from the signed request and the manager's current
`nextOperationNonce`, records that root with the settlement, and calls the
manager in the same top-level transaction. The manager independently derives
the exact root from the same request, caller, path, and nonce and returns it
with the per-token IDs. The adapter compares those returned identities with its
preview before returning from the top-level call. A nonce race or any mismatch
reverts the whole transaction, including the earlier deposit. Free or
executor-only single-step batches still derive and consume the root even when
no settlement record exists.

The immediate Core `mintFromManager` selector does not gain an operation-ID
argument. The manager's per-token event is the canonical root-to-token join for
single-step mints.

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

The generated event catalog remains an as-built artifact until the atomic
implementation cutover. This ADR and its owning specs define the target; they
do not cause a spec-only PR to publish unimplemented ABI or event rows.

### Atomic Cutover And Core Replay Removal

The implementation cutover is one deployable transition, even if developed in
multiple commits:

1. add the ledger root storage, explicit read, validation, and final events;
2. update the manager to derive all identities and reserve the nonce range
   before calling the final ledger ABI;
3. update every manager, sale, resolver, settlement, test, and monitoring call
   site to the exact root/token ownership model;
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
token IDs duplicates manager/Core token facts, increases permanent storage,
and provides no stronger replay guarantee than one consumed root.

### Core Retains Lifetime Replay Storage

Rejected for the production target. It spends permanent Core bytecode and one
storage slot per prepared token to compensate for missing batch replay at the
ledger boundary. The mapping remains in current source until the complete
cutover proof exists.

### Authorization ID Is The Batch Replay Key

Rejected. Authorization and operation identities have different lifecycles.
An authorization may cover policy and signer replay while the operation root
also binds manager, Core, ledger, executor, path, nonce range, quantity, and
exact request contents.

### Prepared Mints Alone Get Operation Identity

Rejected. Single-step settlement needs an exact batch join and the ledger must
have one uniform replay rule for every consuming manager path.

## Security And Bytecode Impact

Manager-scoped ledger replay closes the gap that currently makes Core lifetime
replay storage load-bearing. Per-token IDs remain collision-separated by root,
nonce, index, token data, and mint commitment. Explicit execution-path binding
prevents cross-path identity confusion. Validation-before-write and EVM atomic
rollback preserve counters, authorizations, nullifiers, manager nonces,
prepared state, revenue, and entropy state on every downstream failure.

This ADR itself changes no Solidity bytecode. The later implementation is
expected to add ledger/manager code and remove Core replay code. Any Core size
claim must come from deterministic release-bytecode evidence after all
mandatory hooks compile together. The exact production requirement remains at
least 2,000 bytes of EIP-170 headroom (`StreamCore` runtime at or below 22,576
bytes).

## Release Impact

This is an intentional pre-genesis MAJOR target correction. No production
deployment used the superseded prepared-only domains, rootless ledger ABI, or
ambiguous shared-operation language.

The spec slice updates the ADR/spec/checker and planning inputs and therefore
regenerates the risk register, release notes, release manifest, bytecode release
proof, release-candidate lockfile, and checksum bundle in documented order.
The bytecode proof refreshes release linkage only; contract bytecode is
unchanged. This slice does not rewrite the generated current-as-built ABI,
event catalog, protocol surface, release-build bytecode, or source-verification
inputs as though the contract cutover had landed.

The later implementation cutover must regenerate all ABI-, event-, source-,
bytecode-, protocol-surface-, release-, lockfile-, and checksum-dependent
artifacts from canonical generators.

## Test Plan

- Spec checker tests recompute every identity-domain hash and fail on drift in
  the exact root cardinality, ledger ABI order, replay read, and Core ownership
  statements.
- Quantity `N` produces exactly one nonzero root and `N` nonzero pairwise
  distinct token operation IDs.
- Token operation IDs change when the root, reserved token nonce, token index,
  token-data hash, or mint commitment changes.
- Zero roots and reused roots fail before ledger writes.
- The same raw root is isolated by manager scope; one manager cannot consume or
  pre-consume another manager's root.
- Single-step and prepared batches with otherwise identical inputs derive
  different roots.
- Ledger root, counter, authorization, and nullifier events join to the manager
  batch event; each manager token event joins one token operation ID to that
  root.
- Resolver and token-scoped settlement reject a mismatched root or token
  operation ID. Entropy registration proves its token-ID/mint-commitment
  boundary without acquiring replay ownership.
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

Merge this ADR/spec slice before implementation. After merge, implement the
atomic cutover from a fresh `origin/main` branch, run focused behavioral tests,
then the full Foundry/check/release validation ladder. Independent review must
verify the final diff and generated-artifact scope before a review-ready PR is
handed to the merge coordinator.

This rollout authorizes no merge, deployment, release, live-chain action, or
readiness claim.

## Non-Goals

- No Solidity implementation in this ADR/spec slice.
- No new Core external selector or Core event.
- No entropy replay or settlement-policy redesign.
- No governance/gas work owned by issues `#684`, `#685`, `#669`, `#671`, or
  `#673`.
- No production-readiness or audit-completion claim.

## Accepted Risks

- Until the implementation cutover lands, current source still lacks ledger
  root replay and retains Core lifetime replay storage.
- Pre-manager single-step root preview can race another transaction; the safe
  outcome is full transaction revert and caller retry.
- Manager and ledger storage grow outside Core to preserve the smaller
  permanent Core boundary.
- Generated current-as-built catalogs intentionally lag the target spec until
  the source cutover is atomic.

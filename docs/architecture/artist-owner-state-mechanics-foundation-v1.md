# Artist owner-state mechanics foundation v1

Status: **Proposed foundation only; pre-audit and source-blocked.**

This packet selects a bounded outer storage and commitment shape for future
semantic-owner packets. It does **not** accept `owner_storage`,
`owner_snapshots`, or `replay_keys`; authorize Solidity or interfaces; bind
a deployment; or grant audit or readiness credit. The accepted shared-mechanics
register remains byte-exact at three accepted and sixteen unresolved decisions.

Machine-readable surfaces:

- [foundation packet](artist-owner-state-mechanics-foundation-v1.json)
- [Draft 2020-12 schema](artist-owner-state-mechanics-foundation-v1.schema.json)
- [independent checker](../../scripts/check_artist_owner_state_mechanics_foundation.py)
- [hostile tests](../../scripts/test_artist_owner_state_mechanics_foundation.py)

## Selected outer mechanics

Each future owner reserves the same fixed prefix:

1. slot 0 packs `OwnerHeaderV2 { uint64 revision; uint64 recordSequence; }`;
2. slots 1 and 2 hold `stateRoot` and `recordChainTip`;
3. slot 3 is `mapping(bytes32 => ReplayCellV2) replay`; and
4. typed, domain-owned state begins at slot 4.

The replay kind and status enums describe capabilities only. No one of the 64
replay surfaces is assigned a kind, lifecycle, or typed scope commitment here.
All seven domain layout rows and all 64 replay rows therefore remain explicit,
null, unresolved, and source-blocking.

The constructor-captured `deploymentChainId`, Registry, Coordinator, ArchiveV2,
and domain identity are immutable bindings that consume no storage slots in the
common prefix. The owner address is bound as `address(this)` in every outer
commitment. Live `block.chainid` is never consulted after construction, so a
fork cannot silently rekey existing state. Mutation is Coordinator-only; owners
do not call external collaborators, route generic calldata, or cross-write
another owner's state. The exact composite construction-binding preimage remains
unresolved.

The snapshot return is exactly
`(bytes32 domainId, uint64 revision, bytes32 stateRoot, bytes32 recordChainTip)`.
Genesis roots are nonzero and identity-bound. A successful owner action
increments the checked `uint64` revision exactly once and commits the prior
root, so transition history cannot be erased by converging current state.
Record sequence advances only by the bounded number of records written by that
action. Replay deletion or reopening, root or tip rewind, and successful no-op
mutations are forbidden.
Checked counter overflow and any action failure revert the entire owner action,
including header, roots, replay cells, typed state, records, and events.

## Replay-key boundary

The outer key is
`keccak256(abi.encode(REPLAY_KEY_DOMAIN, deploymentChainId, registry,
coordinator, archiveV2, owner, domainId, surfaceId, scopeCommitment))`. The
`bytes32 scopeCommitment` type is fixed, but its per-surface typed preimage is
deliberately null until an owner-domain packet can choose it. This prevents a
generic hash envelope from masquerading as a resolved replay policy.

## Owner-side recomputation

The typed owner, not Coordinator or another caller, must recompute the action,
next-domain-state, replay-delta, and record-delta commitments. Recalculation is
bound to the accepted recipe and action identities, original caller, exact typed
calldata, prior owner storage, and the replay and record transitions actually
performed. Opaque Coordinator- or externally supplied commitment words are
forbidden. The four exact inner preimages remain null and source-blocking; this
packet freezes the recomputation boundary, not those missing schemas.

## Mechanics-only vectors

The packet supplies independently checked fixed vectors for the snapshot
commitment, state and record genesis commitments, state and record transitions,
and replay key. Every vector uses the same immutable identity prefix and
`abi.encode`. Inner commitment words in transition fixtures are test inputs for
the outer accumulator only and do not resolve or stand in for their null typed
preimages.

## Bounded-work evidence

The bound matrix contains 57 operations, 85 owner actions, one to five owner
actions per operation, one to seven snapshots per operation, at most four replay
writes per owner action, and at most two record writes per owner action. Future
owners may not enumerate historical data or make external calls. ArchiveV2
remains the evidence-only append/read surface.

Inventory digests use UTF-8 JSON with keys sorted, no insignificant whitespace,
and no ASCII escaping; row order remains significant.

## Alternatives considered

- Generic hash-only envelopes were rejected because they conceal incompatible
  typed state and replay semantics.
- A sparse tree for all owner state was rejected because no accepted consumer
  needs proofs sufficient to justify the gas and denial-of-service surface.
- A full append-only owner log was rejected because it duplicates ArchiveV2 and
  invites unbounded owner-local history.
- Premature full-hybrid acceptance was rejected because domain structs, replay
  scopes/lifecycles, action and record commitments, construction bindings,
  events, errors, and collaborator mechanics are still unresolved.

The chosen typed-mapping plus transition-accumulator foundation gives later
packets a deterministic prefix and authenticated history without inventing
those missing semantics.

## Explicit remaining decisions

Per-domain structs and state commitments; every replay scope and lifecycle;
action and record commitment schemas; the construction binding preimage;
entrypoint ABI; normative owner events; provider reads; role and signer
authority; recipe, evidence, and composite-manifest commitments; operation
locking; errors; and gas/call discipline all remain source-blocking.

No contract, catalog, deployment, candidate, release-tail, shared-readiness, or
issue-closure surface is changed by this packet.

# STATIC selection checkpoints

`StreamStaticSelectionCheckpoint` enumerates the entire selected scope from its
constructor-pinned `StreamFinalityScopeMembership`. Callers provide a scope and a
batch size, never an alleged complete token list. COLLECTION uses the actual
complete token inventory; TOKEN uses the permanent Core identity; RELEASE,
SEASON and VIEW use the original complete Metadata-published membership.

This is the selection-source prerequisite for the STATIC finality profile under
MRR Artwork Finality and MRR-FINALITY. It is not a token content root, an opcode
conformance report, an artwork finality record, or an authorization to publish
one. Existing inline and chunked content checkpoint domains remain unchanged.

## Inputs and progress

The constructor captures Core, Router, membership and the membership host's
original Metadata/runtime identities. Every operative call checks those pins
and the actual selected Router pointer including module/interface/registry
commitments. The read cap is a normal governed monotonic forwarding parameter;
there is no silent larger fallback budget.

`begin(scope)` binds the exact current authoritative membership hash/count and
a coarse collection input hash: original activation/default revision and override
history, actual resolved collection config, and raw current Router source. Plans
are deterministic and permissionless. `append(id, maximumTokens)` reads the next
1â€“16 original `scopeTokenAt` entries itself. All progress rolls back if a later
member fails. Pending prefixes are readable historical computation, but
`requireCurrentCheckpoint` accepts only the completed original count.

Every token row independently binds:

- The complete original config-record preimage and actual resolved token override.
- A frozen config and its nonzero, retained Router source snapshot; the actual
  raw source/config return must match that exact snapshot and original config.
- The saved renderer registry/runtime, version, renderer/runtime, registration,
  schema, context and declared read-set identity. Deprecated versions remain
  valid retained sources; their version facts must still match the original row.
- All six concrete RendererV1 source addresses/runtime hashes, including the
  original Core `coordinatorAtMint` and the membership host's Metadata. Optional
  absent sources must have both zero address and zero code hash.

`TokenSelection` is retained and emitted in full. All three persistent progress
events carry explicit schema version 1. The ordered accumulator is
`keccak256(abi.encode(CHAIN_DOMAIN, previousRoot, originalIndex, rowHash))`, where
`rowHash` is `keccak256(abi.encode(ROW_DOMAIN, chainId, core, router, row))`.
It is explicitly an ordered selection commitment, not the canonical artwork
content Merkle root.

## Current versus historical evidence

Every append and completed-current read rechecks the complete membership,
collection input hash and every distinct recorded source runtime, including a
renderer used only by a token override. No collection default substitutes for
those rows. A changed mint inventory, config/override history, raw collection
source, selected Router or captured runtime invalidates the current candidate.

The coarse collection pin is deliberately conservative even for a smaller
scope: changing an unrelated collection input can require a new candidate.
Rebuilding preserves the original frozen per-token snapshots. A later parent
mint does not change a published subset's membership. Historical plan and row
getters retain the original computation and do not assert current liveness.

This is not a frozen-output consumer. A future accepted finality record must
bind this exact checkpoint plus actual content/preservation/entropy/Artist
inputs, then apply its original frozen/recovery semantics; it must not call a
new current candidate an old finality snapshot. The finite dependency list is
complete and checked in a current read, but arbitrary numbers of distinct
renderer versions are not claimed to fit one gas budget. Oversize or unavailable
reads fail rather than truncate membership or source declarations.

The legacy Router evidence provider now validates the selected collection
presentation before its otherwise immutable render-context/dependency fast
paths. Explicit STATIC activation is rejected there just as in the other
legacy serving families. Valid inline/chunked hash preimages stay unchanged;
these legacy families do not accept the new checkpoint implicitly.

## Validation boundary

Nine authored cases use actual Router, RendererV1, Metadata, SchemaRegistry,
byte store, token inventory, scope membership and threshold Safe. They cover
ordered mixed token overrides, complete and published-subset membership,
mutation invalidation, retained snapshots, deprecated versions, runtime drift,
original coordinator identity, late append rollback/identical Safe retry and
legacy-profile refusal. Core, Artist content permissions, version admission and
governance are explicit typed boundaries, not genuine current-stack acceptance.
The eleven original routing test bodies are unchanged in a shared fixture.
ABI/type checks passed; native runtime, size and whole-program STATIC analysis
remain pending the integrator's combined campaign.

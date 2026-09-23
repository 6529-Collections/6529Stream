# Scoped description and interview stage capacity

The scoped V2 description and interview libraries reuse the fixed
`StreamScopedPolicyRenderCriticalStageGuardV2` library. The original public
entrypoints still decode their arguments first, validate the same stage and
complete current context, authenticate the same original rows, then append
and advance the same host plan.

This extraction changes only the private stage wrapper call and adds explicit
original error declarations where the compiler would otherwise omit them.
`State.State` remains the original compiler-owned storage reference. The fixed
library call uses the host delegate context, including the original plan hash's
`address(this)`. It accepts no arbitrary target. The original append implementation,
segment domains, item order, event and final phase assignments remain in each
stage's original call order. No public method, storage layout or profile changes.

The baseline is `ea4cf6b0a2cfa7bba529284a3cfe46bb19b6604b`. Its genuine native
part007 capture measured Description runtime 32,545 bytes / creation 32,580,
and Interview runtime 27,178 / creation 27,213. Both exceed the original
24,576-byte production runtime limit. The fixed guard is a shared dependency
owned by the separate Record/Token stage repair; this batch does not replace
that worker or modify the other stage families.


The repaired native capture uses Solidity 0.8.19, viaIR, optimizer 200, Paris,
no CBOR and no metadata bytecode hash, matching the failed capture. Its one
199-source / three-product run completed in 47.95 seconds:

| Product | Runtime bytes | Creation bytes | Constructor arguments |
| --- | ---: | ---: | ---: |
| Description stages | 22,027 | 22,062 | 0 |
| Interview stage | 16,201 | 16,235 | 0 |
| Shared fixed guard | 7,434 | 7,466 | 0 |

All three fit the unchanged runtime and full-initcode limits. The capture
includes genuine same-pass AST, metadata and complete creation/runtime bytecode
for each selected product. This is selected library capacity evidence, not a
linked deployment or whole-graph capacity result.

The focused `StreamScopedDescriptionInterviewGuard.t.sol` regressions cover:

- All four original entrypoints' stage and current-context guards, plus decoder
  precedence and refusal to re-enter a completed plan.
- Literal full plan, item, link, segment and event preimages in two separate
  host storage contexts, including canonical zero fields in the waiver row.
- Drift refusal followed by the identical restored request, and a late checked
  segment-counter overflow that rolls back tentative segment and chain writes.
- TOKEN/RELEASE/SEASON context variation with bounded fuzz inputs.

The fixture uses the actual original State layout, both stage libraries and
fixed guard. Its complete `Sources.current` response is explicitly mocked;
it does not prove an admitted scoped source graph, source gas budget, Artist
provenance or a finality ceremony. These cases are authored/type-checked and
runtime execution remains pending. Exact capacity measurements and source
pins are recorded in the batch handoff; no runtime, creation or transaction
limit is raised.

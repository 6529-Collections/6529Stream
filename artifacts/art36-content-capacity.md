# Recovered content library capacity refactor

Base: `ad707f8569c4a9a712ce6a854847c69c443c560e`.
Branch: `codex/recovered-content-capacity`.

## Reason and scope

The integrator's retained `recovered-content-nine-size105-20260920` capture
measured ContentConsentHydration at31,141 runtime bytes and ContentConsentFacts
at28,333 bytes. Both exceed24,576. Those measurements describe the base source,
not this refactor. The same capture's oversized Prepared library and Coordinator
are owned by separate integration tasks.

The refactor keeps the supported511 graph, all original17/20/21 proof limits,
the original Request and consent entry points, and the exact encoded Bundle and
inventory preimages. It does not add a supported history or change original
writer authorization, storage layout, replay admission or commit order.

## Fixed linked workers

ContentConsentHydration retains selection, canonical encode/decode and both
storage-import phases. Its collector calls ContentConsentReads.collectRows,
then the existing validate facade, then ContentConsentReads.requireHeads in
the original order. ContentConsentValidation owns the complete original pure
row, native journal, era and replay-alias checks. Workers refer to the facade
only for unchanged Solidity types; neither calls it at runtime.

ContentConsentFacts keeps its source-level validate call shape as an internal
projection adapter. A separate ContentConsentFactRows linked worker receives
only the Identity artist/signature/delegation rows, the content consent scope
and17/20/21 rows, and the complete original provenance. No field used by the
original validator is removed. The validation and chronology checks retain
their original order. No unrelated Identity or base-consent history is decoded
at this worker boundary.

Original20 still lacks signer/nonce/time/deadline preimages. Its source-backed
scope map, native/replay coordinates, retained Identity evidence and complete
grant accounting remain the proof; this refactor makes no stronger rehash claim.

## Authored evidence

Mechanical source comparisons preserve the codec's selection, canonical bytes,
storage imports and every extracted read/validation body after type qualification.
Independent source review covers the extraction and its runtime call direction.
The existing19 component cases remain; one added positive regression uses the
actual mixed12-row original-writer fixture to compare worker/facade rows, literal
schema/version framing, exact envelope bytes, both import phases, latest heads
and unchanged source state. This is not a frozen historical Bundle-layout vector.
Existing negative and rollback cases remain the behavioral regression suite.

## Validation boundary

This lane performs ABI-only compilation, scoped formatting, documentation and
Windows-aware whitespace checks. The first ABI capture caught Solidity's ban
on a qualified external self-call in a library; the corrected design uses a
separate row-validation library. No native compilation, test execution, code
generation, size measurement, gas run or release generation runs in this lane.

The integrator must measure the facade and every new linked worker, including
ContentConsentReads, ContentConsentValidation and ContentConsentFactRows, and
their affected caller products. ABI success is not deployment-capacity evidence.
Runtime regression, full-v1 completion and release acceptance remain pending.

Final ABI-only capture `recovered-content-capacity-v2` covers1,141 sources with
zero errors, including all recovered test hosts and their production imports.
Solidity0.8.19 uses optimizer200, viaIR, Paris and no CBOR, with ABI-only output.
Input SHA256:
`afb60425a160fac8e4cac5d138d7d069321de2d161ba80a205f73df831967ba3`;
output SHA256:
`73b041ead19f30338d1010dfd1d878ce1cbc8abad93fb5d6e1d9f890efb228ce`.
The failed first capture is retained separately. Scoped formatting and
Windows-aware whitespace checks pass. Markdown link unit tests pass17/17;
link and changelog checks pass. Untracked compiler captures are excluded.

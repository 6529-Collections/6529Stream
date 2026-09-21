# Scoped preservation reference reader frames

The scoped reference reader retains its original public ABI and both original
and V2 family interpretations for TOKEN, RELEASE and SEASON. The exact
`a2973d360f6ab18881c04d58193f855704ec56d3` Provider12 native capture failed during
compilation in its five-argument `original` function, before any tests executed.
The failed capture remains separate evidence.

`StreamFinalityScopedPreservationPolicyReferenceOriginalV1` now owns the complete
original-record read through a fixed linked library. The caller context and
original nominal dependency struct remain unchanged. Validation still proceeds
through family/definition, dependency pins, subject, bounded dynamic read and
canonical decoding, full receipt predicates, and the normalized complete record
hash. A private decoder limits the lifetime of the large temporary decoding
frame. The receipt copy still clears only `observation.recordHash` and
`observation.recordChainHash` before hashing.

The scoped interface selector, all `F.*(..., true)` interpretations, canonical
TOKEN/RELEASE/SEASON shapes and original errors remain. COLLECTION and VIEW
remain refused. Current-head, lock and component bodies are byte-exact. No
schema, gas cap, storage, authority or mutable dispatch changes are introduced.
The worker imports the reader's type but has no executable link back to it.

## Bounded evidence

Native Solidity 0.8.19, optimizer 200, via-IR, Paris and the original metadata
settings compiled exactly the two affected products in 13.07 seconds:

| Product | Runtime bytes | Creation bytes |
| --- | ---: | ---: |
| Scoped reference reader | 19,483 | 19,515 |
| Fixed original-record worker | 12,316 | 12,348 |

Both libraries have no constructor arguments and satisfy the original runtime
and full-initcode limits. The selected input contains 453 sources, preserving
every other source from the failed Provider12 capture. Its SHA256 is
`4a0e93a75e3f4b07ecedfabe3c1f66a54269c4932ff7026dc653318ad9815444`.
All 16 original ABI rows, 10 method identifiers and empty storage layout match.
Nine retained function declarations and bodies are exact; inverse-inlining the
private decoder reproduces the original validation and hash tokens.

Six authored regressions cover both families across all three supported scopes,
full dynamic return bytes, the publisher-observed caller, current/lock joins,
canonical refusal, error order, normalized hash and exact read restoration,
scope-shape rejection and dynamic-tail fuzzing. Their typed publisher and five
dependency roles are explicit fixture boundaries. All six typecheck in the
454-source ABI capture. The isolated 45-source native build completed in 33.36
seconds; all six tests passed, including 256 fuzz runs. Its genuine build-info
and artifacts were checked for ABI, native AST, metadata, source hashes,
bytecode, links and immutables before cached execution. Every non-test product
passed the original size limits, and execution left sources and artifacts
unchanged.

This evidence establishes the bounded compiler repair and product sizes. It
does not establish gas parity, Provider12 execution, publication admission or a
complete Finality ceremony. The extra fixed delegatecall has separate overhead.
Local captures and the inverse proof are under
`.tmp-scoped-reference-read-codegen`; the handoff records their hashes.

# Preservation reference reader frames

The collection preservation reference reader retains its existing public ABI
and both original/V2 interpretations. Its full dynamic publication decoder had
a reproducible Solidity 0.8.19 via-IR stack-depth failure, including when the
reader was the only selected bytecode product.

The fixed `StreamFinalityPreservationPolicyReferenceOriginalV1` library now owns
the complete original-record read. It preserves the validation sequence:
definition and family, pinned dependencies, subject, bounded publisher read and
canonical decoding, complete tuple predicates, then the original normalized
receipt/publication hash. Its private decoder ends that large temporary frame
before the predicates. Current-head, lock and component checks remain in
`StreamFinalityPreservationPolicyReferenceReadsV1` with their original bodies.

Both workers execute through fixed library delegation. The publisher sees the
same caller, and the original dependency struct remains declared in the reader.
The new library imports that nominal type but has no runtime links back to the
reader. The sole new runtime link is reader to original-record worker. There is
no mutable dispatch, constructor, storage change, new profile, relaxed read cap
or altered definition/record preimage. The original error ABI is retained.

## Bounded evidence

The source base is `e93cb09169dd90fe3b63cb32e93fe1a8955a0ee1`. Native solc
0.8.19, optimizer 200, via-IR, Paris and the original no-CBOR settings produced:

| Selected boundary | Result |
| --- | --- |
| Exact original reader | Original Yul stack-depth failure, 29.24 seconds |
| Private decoder only | Compiles; 36,560-byte runtime exceeds the original limit |
| Final reader | 19,833-byte runtime; 19,865-byte creation |
| Fixed original-record worker | 12,901-byte runtime; 12,933-byte creation |

The final capture contains 445 sources, with bytecode selected for exactly the
two changed products and ABI-only output for the new test file. Its input SHA256
is `fa54cb74816653e6eb8040d9413b420b467f623a176ef5c696703aa56e29117e`;
the native output SHA256 is
`52bfd813c06560755d3cbab58dcba0ee900df32cbd4414bffd23c6532563df17`.
All 16 original ABI entries, 10 method identifiers and storage layout match.
Nine retained function declarations/bodies are byte-exact; the moved functions
and inverse-inlined decoder reproduce the original predicate and hash tokens.

Five focused test bodies cover both families' full nested return bytes, exact
publisher caller, current/lock joins, error order, trailing-byte canonical
refusal, normalized hash rejection, restoration and dynamic-tail fuzzing. These
tests use explicit typed publisher and dependency boundaries; they do not prove
publisher admission, Archive coverage or the complete Finality ceremony.
They are authored and typechecked at this handoff, not executed. Existing actual
publication and V2 family tests remain unchanged. This capture makes no gas
parity or complete provider execution claim.

Local immutable captures and the source inverse proof are under
`.tmp-preservation-reference-read-codegen`; the handoff identifies their hashes.

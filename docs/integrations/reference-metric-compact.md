# Compact same-call metric validation

This page records the compact transport boundary and its later member-lookup
optimization. The [metric-local byte reader](reference-metric-byte-reads.md) and
[canonical publication parser](reference-metric-publication-input.md) retain
these commitments inside fixed worker frames. Historical measurements below
apply only to their recorded source.

The fixed metric workers now keep the complete authenticated Publication and
Evidence in the currentness worker's memory frame. They pass the exact fields
used by the metric proof through a fixed typed projection, then decode the
original Supplement once in a separate fixed proof worker. This avoids repeated
large ABI encodings without replacing any live source or publication checks.

The original compact implementation ran the full `requireCurrentDecoded`
sequence in `StreamReferenceMetricCurrent.requireInput`; the later canonical
parser preserves that source-check sequence with exact encoded transport. The publication worker then performs the original lock
and writer checks before the supplement's duplicate, authority, definition,
proof, canonical-byte and Store checks. The read worker authenticates current
source facts before checking the actual retained supplement and original
receipt. The projection is private transport between fixed workers. It is not
an evidence endpoint or persistent cache.

## Complete package commitment

The fresh environment's ordered package rows are scanned in full. A row belongs
to the metric prefix only when its path is longer than seven bytes and begins
with the exact bytes `metric/`, preserving the original predicate. Starting at
`keccak256("6529STREAM_METRIC_COMPLETE_PREFIX_V1")`, each matching row folds:

```solidity
keccak256(abi.encode(previous, keccak256(bytes(path)), byteSize, sha256Digest))
```

The original `uint64 byteSize` is not narrowed. The final commitment folds the
complete matching count. The proof independently validates the runtime's
strict ordering, required members and all original path/size/digest facts,
then compares its complete fold and count. This neither permits a subset nor
turns a claimed package list into authenticated source evidence.

The projection also retains the original scalar metric and environment
commitments, viewport, pixel ratio, full current context hash and actual capture
count. At most two digest pairs are copied into its fixed array. Zero or excess
captures still fail at the original input-manifest stage after the runtime
checks, preserving error precedence. Other publication and environment fields
remain authenticated by the full current context.

## Compatibility and verification

The original public full-proof, projected-proof and Storage entrypoints remain
available. The original full proof is the independent differential oracle.
Publication host ABI/storage, schema/profile bytes, receipt/event fields,
record/hash domains, staged carriers, standalone currentness semantics and
governed budgets are unchanged.

Focused tests compare full, projected, compact and encoded paths using the
retained 1,048 package rows and 102 platform prerequisites. They cover exact
canonical bytes, runtime/replay/receipt hashes, prefix boundaries and all three
member fields, order/count substitutions, capture-count precedence, malformed
canonical bytes, fresh source drift, lock/writer denial and Store rollback.
Random digest/size inputs exercise the prefix fold independently.

The fixture uses the actual immutable Store and original retained replay bytes,
with explicitly mocked source/facts/definition reads and a typed writer grant.
Its rebound context is synthetic. It does not establish a new archived-runtime
execution, actual publisher authority, cold full-graph behavior or transaction
capacity. Fresh-frame gas diagnostics share warmed dependencies and exclude
transaction intrinsic cost.

The selected original-settings size gate covers Current, EncodedProof, write
and read execution, Proof, Storage, Preparation and the publication host. All
eight fit; original Proof, Storage, Preparation and host sizes are unchanged.
Runtime test results and exact source/artifact pins are recorded separately in
the frozen capture handoff. The 137-source capture passes all 25 tests, including
three 256-case fuzz cohorts. All 145 artifact metadata records and 3,253 source
Keccak comparisons match; all eight native sizes match the selected gate. The
four original Proof, Storage, Preparation and host ABIs and semantic storage
layouts are unchanged, including all 98 host ABI entries.

The isolated publication diagnostic falls from the prior same-call 20,627,939
to 18,197,110 gas; its reader falls from 25,059,552 to 17,218,427. Both remain
above the 16,777,216 transaction limit before intrinsic cost, and the reader is
above its original 14m validation budget. An unchanged cached trace reproduced
the diagnostic without code generation. It does not close either actual
publisher capacity failure.

## Compact member lookup and allocation

The compact runtime proof now reuses one allocated four-word memory frame for
its ordered prefix fold. Its 128-byte preimage is exactly the original
`abi.encode(previous, pathHash, uint64Size, digest)`; the final count fold is
unchanged. The frame belongs to allocated memory, not EVM free-pointer scratch.

Only after the complete strict-order and count/hash checks pass, required
members use a lower-bound search over that same sorted runtime. Each lookup
still requires an exact path, nonzero size/digest, and the original expected
size/digest when applicable. The six exact source/index/parameter lookups and
both executable lookups retain their original order. The public full proof and
its linear search remain unchanged as the independent oracle.

Nine additional independent tests use both the original complete corpus and
small, jointly rebuilt package/runtime fixtures. They cover paired field
mutations that reach member lookup, missing members, zero executable fields,
valid changed executable fields, ordering, path boundaries and a literal prefix
fuzz oracle. Source review and ABI checks pass; the frozen original 25 plus nine
new native cases are running. No measured savings or native acceptance is
claimed for this optimization yet.

## Actual publisher remains a separate gate

The native17 actual publisher capture, before this compact-proof change, passes
eight of nine original cases. Full admission, consumer validation, original
class-two lock and identical Safe retry pass. Final supplement binding still
exhausts its original transaction budget in the encoded-proof frame. The only
source delta from native16 is the accepted two-file publication parser; its
original tests, fixture bytes, gas caps, cooling and intrinsic checks remain.

That historical graph retains explicit typed Core/Artist/governance boundaries
and an oversized older Router. It does not establish full-current deployability
or release acceptance. The compact member optimization requires a fresh exact
source overlay and the unchanged nine-case actual publisher campaign.

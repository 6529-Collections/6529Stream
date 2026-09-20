# Metric-local immutable byte reads

The fixed metric workers now read the original immutable Store manifests in
their own memory frame. The shared `StreamSnapshotManifestBytes` and the
original full currentness/proof entrypoints remain unchanged. This removes
large library argument and return copies without adding a cache or accepting
caller-supplied storage locations.

`StreamReferenceMetricBytes` preserves the original 524,288-byte limit,
pointer/hash counts, ordered 8,192-byte chunks, exact carrier code length,
STOP prefix, each chunk hash and the final whole-payload hash. One reusable
8,193-byte scratch allocation checks each carrier. The final short chunk uses
its actual remaining length; trailing scratch bytes are neither hashed nor
copied. The original errors and first-failure order remain.

The fixed Current worker follows the original publication/evidence read and
decode, canonical evidence, fresh source, full context, mode, saved facts and
payload-integrity sequence. It then produces the existing private compact
projection. Publication still checks the original lock and writer before
supplement acceptance. The read path passes the actual compiler-typed manifest
storage reference to `EncodedProof.requireStored`, where complete retained
bytes are checked before the unchanged canonical supplement proof. No checked
currentness value survives the call.

## Compatibility and verification

The publication host retains all 98 original ABI entries and identical semantic
storage. Original Proof, Storage and Preparation ABIs/storage are also unchanged.
Schemas, hashes, receipts, events, governed budgets and original manifest roots
are unchanged. The original public byte reader and full proof remain independent
differential oracles.

The bounded corpus covers lengths 1, 31, 32, 8,191, 8,192, 8,193, 16,385 and
524,288, plus the retained 219 KB supplement and complete 1,048 package rows.
Controls exercise count/length/order/hash errors, absent and corrupted carrier
code, STOP changes, wrong manifest namespace and exact restore. A forced static
call rejects an attempted write while reading the correct original namespace.
That intentional write-denial test uses a 3m harness limit; it changes no
production budget.

The first frozen run retained 31 passes and one failure in the added namespace
test. Its source reads behaved correctly, but the test compared a receipt-only
return with a stored bytes-plus-receipt pair. An unchanged cached trace located
that assertion. The successor corrects only the expected shape, independently
retaining the original receipt and full payload comparisons. The cached successor
compiled that one changed test file and passes all 32 tests, including four
256-case fuzz cohorts. The failed capture and diagnostic trace remain retained.

All nine selected products fit the original compiler limits. Eight have serving
or storage bodies; the internal-only byte library has a four-byte runtime. The
largest affected product remains Preparation at 24,307 bytes; the host is
22,561 bytes. Both native captures' 139 sources, three fixtures, 149 artifact
metadata records and 3,286 source Keccak comparisons match exactly. All native
production sizes match the selected gate.

## Capacity remains an actual-publisher gate

The unchanged isolated fresh-frame diagnostic measures 14,883,823 gas for supplement
publication and 10,655,194 for its reader, down from the compact predecessor's
18,197,110 and 17,218,427. The fixture shares warmed dependencies and has explicit
mocked source/facts/definition and typed writer boundaries. These numbers exclude
transaction intrinsic cost and do not establish actual publisher, cold graph,
current authority or original transaction-envelope acceptance.

The retained actual native14 result remains seven passes and two supplement-stage
failures. Its reference publication passed at 15,664,912 gas including intrinsic
cost. This source batch does not relabel the failed supplement read and binding
as passing. An actual retry needs its own exact predecessor overlay and evidence.

The earlier [compact transport](reference-metric-compact.md) evidence is retained
at its original source boundary.

The later [canonical Publication input](reference-metric-publication-input.md)
keeps these byte checks while changing the metric-only Current interpretation
and moving its final integrity check to the existing fixed manifest worker.
Its separate source, parity and capacity qualifications are recorded there.

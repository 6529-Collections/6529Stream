# Canonical Publication input for metric currentness

The metric Current worker interprets the original retained Publication bytes
without materializing and re-encoding its complete Environment tuple. It still
checks every canonical field and retains the full captures and Environment in
the original context preimage. This is an internal transport change; the
original full Preparation, context and proof entrypoints remain available.

## Source and byte authority

The host chooses the Publication manifest from its original compiler-owned
record storage. Its only writers retain `abi.encode(p)` from either the original
monolithic publication or the authenticated prepared-publication path. Prepared
bindings remain once-only, with the existing mixed-state and partial-binding
refusals. No external caller can supply a parser result or select a manifest
for currentness.

The metric byte reader first checks the complete original manifest: total
length, pointer and hash counts, ordered chunk lengths, carrier code length,
STOP prefix, every chunk digest and the whole Publication hash. The parser
then independently checks canonical nested encoding; an immutable hash alone
does not establish canonical or semantic validity.

Publication has a twelve-word head after its outer offset. Its captures,
Environment and final manifest URI must occupy exactly ordered, contiguous
tails. Capture decoding and re-encoding must reproduce the exact saved bytes.
Environment has a twenty-four-word head, eleven string tails and two complete
PackageFile arrays. Every relative offset, scalar width, boolean, row shape,
length and padding byte is checked, including platform rows that do not enter
the metric-member fold. The original 524,288-byte limit is unchanged.

The complete `metric/` prefix fold retains the original length-greater-than-seven
predicate, original row order, full path bytes, uint64 size and digest, followed
by its original count commitment. Invalid capture counts retain their original
semantic rejection position; canonical transport alone does not admit an empty
capture or Environment.

## Exact currentness sequence

Current performs these operations in the original order:

1. Read and canonically interpret the complete retained Publication.
2. Read and canonically decode its original mode evidence.
3. Check the actual fresh source with the original source worker.
4. Hash the original context and validate the original projected mode evidence.
5. Compare the source commitment and complete saved mode facts.
6. Verify the complete retained payload and compare its original hash.
7. Return the private compact metric input for the same call.

The context retains the original twenty-three-word static head, including the
actual delegate host, chain, all seven targets and runtime pins, collection,
reference and snapshot identities. Its dynamic tails are the entire original
Capture array and Environment, with the original offsets. Fields outside this
context keep their original meaning in source, receipt or evidence validation.

The final payload integrity check calls the existing fixed
`StreamReferenceModeManifestAdoption.requireIntact` worker. It checks the same
original typed storage manifest and complete byte commitment in a separate
memory frame. Source or saved-facts mismatch still short-circuits before this
read. The metric execution host still checks known record/head/revision first,
then fresh currentness, lock and writer authority before supplement acceptance.

## Linking and compatibility

There is no new constructor argument, storage root, schema, receipt, public
host selector or governed gas setting. `StreamReferenceMetricPublicationInput`
is internal-only and is inlined into Current. Current now links the existing
ManifestAdoption worker as well as its original source and mode workers.
Deployment tooling must link these actual fixed products normally; changed
runtime identities must be retained in any new source or replay evidence.
An old deployment or evidence pin does not become valid merely because public
ABI shapes are unchanged.

The selected original-settings gate measures Current at 17,515 runtime bytes
and the reused ManifestAdoption worker at 2,085. Both fit the original limits.
The internal-only parser has no independently deployed serving product. Other
unchanged products retain their separately pinned predecessor measurements.

## Verification scope

The parser oracles independently compare literal original context bytes,
original source/evidence projections and the original complete compact proof.
They cover the retained 1,048 package rows and 102 platform rows, all Environment
and Capture field changes, arbitrary paths and digests, full-width sizes,
empty and maximum encodings, malformed offsets, counts, widths and padding.
The existing byte-reader controls also compare the actual fixed integrity
worker, corruption and exact retry, adjacent typed manifests and forced-static
mutation refusal.

The first high-level row parser passed nine tests, including 256 fuzz cases,
but its measured context sequence regressed from 4,309,103 to 5,731,205 gas.
That failed performance candidate is retained. The successor uses a bounded
row cursor, validates each complete row before reading or hashing it, and
folds through its own four-word scratch allocation.

The frozen successor passes all 44 tests across five suites, including five
256-case fuzz cohorts. Its 141 sources, three fixtures, 153 artifact metadata
records and 3,689 source Keccak comparisons match exactly, with no line-ending
normalization. Native sizes match the selected gate. A separate cached timing
case skipped compilation and retained all 155 artifact files byte-for-byte.

In that fresh-frame corpus comparison the original decode/context/fold sequence
costs 4,311,016 gas and the successor costs 2,146,667, saving 2,164,349. Reserved
free-memory-pointer space falls from 878,880 to 521,696 bytes; this is not an
exact EVM peak-memory measurement. The existing whole-operation diagnostic
measures 12,669,925 for supplement publication and 8,438,796 for its reader,
compared with the predecessor's 14,883,823 and 10,655,194.

These tests use explicit typed or mocked source, definition and grant
boundaries with warmed dependencies. They exclude transaction intrinsic cost
and do not establish actual publisher, cold graph, original transaction-cap
or complete finality acceptance. Native16 remains seven passes and two metric
capacity failures: its unrestricted write and standalone reader measured
21,188,229 and 16,882,369 execution gas. No actual retry or capacity closure is
part of this source change.

See the earlier [metric byte-reader evidence](reference-metric-byte-reads.md)
and [compact transport](reference-metric-compact.md) for their original scopes.

# Covered complete VIEW output manifest V2

`StreamViewPolicyOutputManifestV2` verifies every output row of one complete
adopted VIEW V2 checkpoint using ordered covered parts and a covered index. It is
a supplemental product. The original Router op17 head, tag, consent and history
remain the sole adoption authority. Preparation grants no publication or finality
authority, and the archive artist label must still be joined by an authoritative
downstream consumer.

## Deployment and exact API

Deploy after the actual checkpoint, Core, original ArtifactCoverage and Schema
Registry. Configuration pins all four runtimes, chain, the checkpoint's actual
configuration hash and bounded read/checkpoint budgets. The constructor also
pins its two fixed compiler-linked workers. It has no per-plan SourceSet,
renderer or future-provider constructor cycle. This is an explicit companion to
the existing genesis role roster, not another canonical role with an old identity.

1. Prepare and archive exact `STREAM_VIEW_POLICY_OUTPUT_PART_V2` bytes with the
   matching `STREAM_ABI_VIEW_POLICY_OUTPUT_PART_V2` interpretation. Call
   `preparePart(checkpointId, first, artifactHash, coverageHash, artistId)`.
   `first` is a multiple of 64; each part contains exactly 64 full rows except the
   final remainder. Every supplied row is compared with the original checkpoint
   `outputAt` result. A caller-supplied part hash or descriptor is never accepted.
2. Build the index from the returned verified part records and their exact
   descriptors, preserving order. Archive its exact
   `STREAM_VIEW_POLICY_OUTPUT_MANIFEST_V2` / ABI canonicalization bytes. Call
   `beginManifest` with the checkpoint and original artifact/coverage identities.
3. Call `verifyNextPart(plan, partRecord)` for each consecutive part. The verifier
   authenticates the same full checkpoint/header and artist label, exact first
   index/count and strictly increasing real token identities across boundaries.
   The last call atomically verifies the complete index, all current covered
   part bytes and the full current checkpoint before creating a record.
4. `requireCurrentManifest(record, artistId)` repeats the complete checkpoint,
   schema, index and all part integrity/current-coverage joins. `manifestRecord`,
   `manifestPart` and `partRecord` are historical getters, not current admission.

Identical part/begin preparation returns the same id without another event.
Completed records cannot be extended or replaced. A failed final check rolls
back its final progress and record writes so the exact call can be retried after
restoring a genuine dependency.

## Canonical bytes

All structured values use canonical Solidity ABI. Header is the twelve-word
tuple `(checkpointId, checkpointStateHash, fullScope, adoptionRecord,
sourceContextHash, membershipHash, policyChainHash, uint64 tokenCount, outputRoot)`;
the complete four-word scope remains inline. Its state hash is the exact original
`keccak256(abi.encode(Checkpoint.Plan))`.

Part bytes are `abi.encode(partSchema, chainId, core, checkpoint,
checkpointConfigurationHash, Header, uint64 first, Output[] rows)`. The array
offset is 608; including its count the header is 640 bytes. Each complete static
Output is 31 words/992 bytes. The largest 64-row part is 64,128 bytes.

Index bytes are `abi.encode(indexSchema, chainId, core, checkpoint,
checkpointConfigurationHash, Header, artistId, Descriptor[] parts)`. It has the
same 608-byte head and 640-byte header/count. Each descriptor is nine words:
record, artifact, coverage, content hash, uint64 byte length, uint64 first,
uint16 count, first token and last token. The original maximum 16,384 members
requires 256 parts and a 74,368-byte index. Every carrier retains the original
524,288-byte ceiling and ordered 8,192-byte Store chunks; no bound is raised.

Every exact carrier joins original current ArtifactCoverage, two distinct archive
families, schema/canonicalization, artist, content hash/length, chunk count,
pointer runtime/length/STOP and whole-byte hash. Its immutable part record binds
actual host/chain/configuration and the complete authenticated Header/carrier.
Index plan, ordered part chain and verified record use distinct new VIEW V2
domains; no original COLLECTION or finalized-only V1 domain is reused.

Rows preserve all full entropy facts and the explicit current-live versus
retained-burned serving-kind distinction. Terminal does not mean finalized.
These are preserved commitments, not complete rendered JSON/HTML, media bytes or
browser execution: those still require separate actual archive/reference work.

## Validation and remaining capacity

Thirteen authored focused tests use actual Manifest, Schema, Store and original
ArtifactCoverage with explicit typed checkpoint, Archive-family, Finality and
governance boundaries. They include independent literal encoding/record domains,
64/65 boundaries, complete index ordering, substitutions/trailing bytes, current
drift, real carrier corruption, late rollback/exact retry and codec fuzz. ABI
checking passes over the 180-source test closure. One original-settings selected
41-source gate measures host 12,512, read worker 13,624 and encoder 2,847 runtime
bytes; all three fit.

The frozen 180-source manifest capture subsequently passed all thirteen focused
cases and 256 fuzz runs. Its 97.703-second genuine build verified 24 selected
artifacts and 22 nonempty production products; EVM tests took 1.391 seconds,
skipped compilation and preserved source, settings and artifacts. The actual
test-embedded manifest has a 12,183-byte runtime and 13,915-byte creation including
384 constructor argument bytes. Its creation is authenticated inside the genuine
parent test artifact and its compiler-declared library links match the deployed
libraries. The separate selected 12,512-byte host is a different genuine optimizer
context, not byte-equivalent; the failed template comparison is retained. No
artifact or compiler output was rewritten or substituted.

This evidence exercises actual Manifest, Schema, Store and ArtifactCoverage with
the typed boundaries above. The largest test bodies perform multiple operations
and are not per-transaction capacity measurements. The 16,384-row case checks the
final-part and complete-index codec bounds, not full-scope runtime acceptance.
Current governance, complete adopted checkpoint-to-manifest integration and the
remaining snapshot/reference/provider/finality ceremony are not established.

Parts solve carrier completeness. They do not make a cold 16,384-token checkpoint
seal/current call fit the unchanged 16,777,216 transaction budget. The current
checkpoint re-renders every row, including live Artist annotations. No complete
producer-owned mutation/expiry commitment exists in the current attribution
interface, so a policy epoch alone cannot safely authorize staged freshness.
The full read remains mandatory and fails if its budget is insufficient. Large-
scope onchain currentness is an explicit unresolved capacity obligation; small
typed cases must not be presented as universal acceptance. A future staged
freshness protocol must authenticate every output-affecting producer mutation
and time boundary, exact current route/profile/root and complete scope.

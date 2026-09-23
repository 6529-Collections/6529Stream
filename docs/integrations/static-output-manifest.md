# Preserved STATIC output manifests

`StreamStaticOutputManifest` verifies the exact complete output-row inventory from a
`StreamStaticContentCheckpoint` against bytes retained by the existing
`StreamFinalityArtifactCoverage`. It preserves the original six-field leaf and its content
root, plus the separate selection, source and full-output commitments. It does not change
or relabel the original inline/chunked leaf-manifest schema.

The constructor pins the checkpoint and coverage hosts and verifies their common Core.
The coverage host supplies the pinned SchemaRegistry. Both new interpretation documents
must be registered and ACTIVE with their exact literal bytes from
`StreamStaticOutputSchemas.document`: `STREAM_STATIC_OUTPUT_MANIFEST_V1` and
`STREAM_ABI_STATIC_OUTPUT_MANIFEST_V1`. The verifier checks document kind, versioned name,
RAW_BYTES interpretation, length, content hash and full canonical stored bytes. A caller
cannot substitute another interpretation under a matching label or pass only a schema ID.

The canonical artifact is:

```solidity
abi.encode(
    schemaId, chainId, core, checkpoint, checkpointHash,
    keccak256(abi.encode(completeCheckpointPlan)), scope,
    contentRoot, outputRoot, uint64(tokenCount), Output[] rows
)
```

The four-word scope is inlined. The array offset is exactly 448 bytes, its count ends the
480-byte header, and each original `Output` occupies 288 bytes. Rows are in the complete
checkpoint order. Alternate offsets, changed counts, extra or omitted rows, different scope
identities and trailing bytes are refused. `beginManifest` takes a completed, currently valid
checkpoint and an actual two-family artifact-coverage completion. The caller supplies no
replacement membership list, row hashes or roots.

`verifyNextOutputs` compares up to sixteen complete rows per call against the original
checkpoint's saved `outputAt` values. Rows may cross 8,192-byte archival chunks; both chunk
runtime and expected exact length are checked before copying. On completion the verifier
revalidates the whole original checkpoint, exact interpretation documents and current
archival completion. The resulting record binds the original checkpoint plan, artist-labeled
coverage, schema and artifact, full scope, token count, byte length and both roots. Events use
schema version 1. Late failure rolls back that entire verification call; a partial cursor is
never presented as a completed manifest.

`requireCurrentManifest` repeats those current checks. `manifestRecord` retains completed
historical facts when later output or archival state changes. It does not infer that a
historical manifest is currently valid. The coverage's artist ID is an explicit source fact;
this computation does not prove that the Artist is associated with the collection or has
publication authority. The later publication consumer must join those original authorities.

This artifact contains hashes and commitments, not full JSON, HTML, image or token-data
bytes. The exact complete outputs need a separate retained-byte profile. The existing
coverage limit remains 64 chunks of 8,192 bytes, so this profile accepts at most 1,818 rows
(`480 + 288 * tokenCount <= 524288`). Larger inventories and multi-artifact full-output
preservation remain separate work; no truncation or supplied subset is accepted as complete.

The single new class-2 parameter `STATIC_OUTPUT_MANIFEST_READ_GAS` admits the full configured
STATICCALL budget with an EIP-150 allowance and local reserve. Its deployment value must cover
the original checkpoint's full nested render/read admission and complete scope. A small typed
fixture value is not a production default. The verifier does not increase the checkpoint,
Router, renderer or archival budgets. Insufficient gas fails without a successful partial
current result.

Nine focused tests pass, including two properties with 256 inputs each. They cover exact registered schema bytes, complete roots and scope, row
partitioning including a cross-chunk row, two field-mutation properties, old-schema and
trailing-byte refusal, retirement and historical reads, runtime/definition corruption, and
an actual threshold Safe's late-coverage rollback and identical signed retry. SchemaRegistry,
document store, artifact coverage and manifest verification are real contracts. A ninth recipe
uses the actual RendererV1 and corrected content producer to form, cover and verify original
output rows, then invalidates current acceptance after a live attribution change while retaining
the historical manifest. Core, route/selection, Artist display, original archive-family receipts
and selected Finality remain explicit fixture boundaries. The focused 194-source ABI check
passes, and the frozen native capture passes all nine cases. A full current-contract join remains
pending. The selected verifier
measures 14,789 runtime bytes with the pinned settings. No finality-mode acceptance or transitive
renderer conformance is claimed.

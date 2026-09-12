# Preserved content leaf manifests

`StreamContentLeafManifest` checks that an archived manifest contains every
field of every leaf in a completed [onchain content checkpoint](onchain-content-checkpoints.md).
It reads the actual stored bytes and advances in bounded transactions. A
completed verification is permanent evidence of the manifest's contents.
Publishing the authoritative root still requires the collection's publication
authority and applicable artist consent.

Use the [caller interface](../../smart-contracts/interfaces/stream/finality/IStreamContentLeafManifest.sol).
The verifier pins one Core, checkpoint contract, artifact coverage contract,
their relevant runtime hashes and the deployment chain. Both dependencies must
identify the same Core. The fixed deployment must admit the actual checkpoint
and artifact producers; an interface declaration alone is not that admission.

## Exact byte format

The schema ID is `keccak256("STREAM_TOKEN_CONTENT_LEAF_MANIFEST_V1")` and the
canonicalization ID is
`keccak256("STREAM_ABI_TOKEN_CONTENT_LEAF_MANIFEST_V1")`. The canonical bytes are
the ordinary Solidity ABI encoding of this tuple:

```solidity
abi.encode(
    schemaId,             // bytes32: the exact schema ID above
    chainId,              // uint256: checkpoint deployment chain
    core,                 // address
    checkpoint,           // address: the fixed checkpoint producer
    checkpointHash,       // bytes32: completed checkpoint plan ID
    collectionId,         // uint256
    contentRoot,          // bytes32: the checkpoint's actual root
    tokenCount,           // uint64: complete applicable inventory
    leaves                // StreamTokenContentLeaf[], in checkpoint order
)
```

There are nine 32-byte head words. The ninth is the dynamic array offset, exactly
288. The next word is the array length, exactly `tokenCount`. Each subsequent
leaf has six 32-byte words: token ID, metadata hash, image hash, animation hash,
content hash and token data hash. Total length is exactly
`320 + 192 * tokenCount`; alternative offsets, padding, trailing bytes, missing
leaves and changed field values are rejected. Integer values retain their full
precision. This binary encoding is not JSON or JCS.

The checkpoint profile defines what each hash means, including absent assets.
The verifier compares all six fields byte for byte with the checkpoint's stored
leaves. It does not accept a caller's separately supplied token list or replace
the existing ordered content tree with the manifest hash.

These identifiers specify the implemented encoding. Governed schema and
canonicalization registration, exact definition checks at authoritative root
publication, and the artist association remain delivery requirements. A
permissionless artifact carrying these identifiers does not satisfy them.

## Preserve, verify and consume

1. Complete the checkpoint and reconstruct the exact tuple above from its
   retained leaves. Split the bytes into canonical 8,192-byte chunks, with only
   the last chunk allowed to be shorter.
2. Publish those chunks to the document store and record the whole artifact
   through `StreamFinalityArtifactCoverage`. Complete actual current coverage
   under two independent archival families for every chunk.
3. Call `beginManifest(checkpointHash, artifactHash, coverageHash, artistId)`.
   This checks the complete current checkpoint, original coverage completion,
   schema identifiers, exact length and all header fields. Repeating an identical
   request returns the same plan without replacing progress.
4. Read `manifestPlan(planHash).nextIndex`, then call
   `verifyNextLeaves(planHash, count)` for one to sixteen consecutive leaves.
   Verification reads the preserved chunks, including leaves crossing chunk
   boundaries. Concurrent submitters can share progress.
5. The last batch rechecks the current checkpoint and current archival coverage
   before emitting `LeafManifestVerified`. A failure rolls back that entire
   batch. Earlier successful progress remains available for retry.
6. An authoritative consumer calls `requireCurrentManifest(recordHash, artistId)`
   and establishes that artist's actual collection association and its own
   publication permission. `manifestRecord` instead returns historical evidence
   even after a later mint, pointer change or stale archival validation.

The record binds the original stable coverage completion. Refreshing archival
validation does not change that identity or the verified manifest. A caller
cannot substitute the mutable validation-cache head for original evidence.

Anyone can begin and advance verification, including a threshold Safe. The
`CONTENT_LEAF_MANIFEST_READ_GAS` parameter uses the existing governed gas host
and an explicit parent-gas precheck. A zero governance authority fixes it after
construction; otherwise only its configured governance execution can raise it.
Batch limits do not establish a deployment's maximum gas consumption.

## Current limits and tests

The existing artifact producer supports at most 64 chunks, or 524,288 bytes.
This exact manifest encoding therefore supports at most 2,729 leaves per
artifact. Larger collection manifests need a composed archival representation;
this implementation does not impose a new collection supply limit or close
larger-collection finality requirements.

Focused tests use actual checkpoint, inventory, document store, whole-artifact
coverage aggregator and manifest verifier contracts. Core/router/entropy reads,
archival families and receipts, schema admission and finality selection are
explicit test boundaries. Real Safe 1.4.1 calls exercise both writes and all
public reads; the immutable fixture's gas mutation is rejected for a Safe
caller. Tests cover every header and leaf field with fuzzing, chunk crossings,
batch partitioning, tampered bytecode, stale coverage and its refresh, late
failure rollback, and current versus historical reads. Full current-stack
finality and actual archival receipt composition remain separate acceptance.

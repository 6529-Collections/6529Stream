# Metadata record payloads

`StreamCollectionMetadataV1` accepts complete canonical record payloads from 1 to
24,576 bytes. Catalog, schema, subject, direct grant and native Artist authority
remain the original admission requirements. This implements the generic payload
capacity in CMC-RECORD-PAYLOAD and the limit in
[`collection-metadata-contract.md`](../collection-metadata-contract.md).

## Original and multi-chunk records

Payloads through 8,192 bytes keep the original Store chunk, pointer inventory key,
fourteen-word record hash, receipt, chain and read path. A larger payload uses two
or three ordered chunks in that same immutable Store. The appended manifest binds
the full Keccak hash, byte length, each segment hash and each pointer. The last
segment may be shorter; all preceding segments are exactly 8,192 bytes.

`recordPayload(recordHash)` and `collectionRecordPayload(...)` continue returning
the complete canonical bytes. For a multi-chunk record their address return is
**only the first chunk pointer**. That pointer neither contains nor independently
commits the whole payload. `IStreamCollectionRecordPayloadChunks` adds the
ordered `recordPayloadChunkCount` and `recordPayloadChunkAt` reads. These require
an accepted record. Reconstruct the payload in position order, verify each segment
hash and the full hash in the original record. Repeated chunk positions remain
present even though the existing per-family accepted pointer inventory deduplicates
equal chunk hashes. Historical multi-chunk reads use retained immutable pointers;
they do not depend on current schema, grants or Store runtime.

## Native Artist publication

1. Construct the original complete record and its original `P.Publication` tuple.
2. Call `prepareRecordPayload(payload)` before requesting the original op24 Artist
   attestation. Preparation is permissionless and binds only bytes. Its companion
   `preparedRecordPayloadChunkCount/At` reads expose the resulting carrier.
3. Obtain the original current Artist authorization for that exact candidate.
   No signature domain, nonce, authority class, statement or candidate hash changes.
4. Call the original `recordArtistCollectionRecordWithPayload` with the same full
   payload and authorization, directly or through a Safe CALL. Only this successful
   admitted write consumes authorization and adds record/history/inventory state.

The preparation may also happen inside the final publication transaction. It must
already exist when an earlier Artist candidate read needs to authenticate large
bytes. Direct writers do not need a separate preparation transaction.

A missing prepared manifest follows the original one-chunk Store lookup/error
path. An advertised malformed or corrupt manifest fails; it never silently falls
back to another carrier. A reverted admitted write rolls back its own chunk
creation, manifest, inventory, receipt and replay writes. Separately prepared bytes
remain permissionless historical bytes and do not acquire authority from a failed
publication. The original Safe transaction can be retried if its nonce and all
original authorization conditions remain valid.

## Validation boundary

The focused native run passes all 23 cases (15 original and eight capacity cases),
including two properties with 256 fuzz inputs each. It covers 8,192/8,193/24,576-byte direct records, 24,577-byte refusal,
literal original hash/chain, state-only reconstruction, preparation/admission
separation, corrupt/missing carriers, and unchanged signed Safe retry after a
second-chunk failure. These use actual Metadata, SchemaRegistry, Store and a real
2-of-2 Safe; Core, Artist and governance in that small fixture are explicit typed
boundaries.

Five separate actual Artist/owners/Archive/Safe cases are authored for the original
op24 publication path and governed candidate read, including each size boundary
and retry. Their Core/governance/router remain explicit fixture boundaries. Native
execution of that larger suite remains pending at this source handoff. No full
current graph, renderer adoption, finality authority or publication transaction gas
limit is inferred from the source or selected product-size checks.

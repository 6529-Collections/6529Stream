# Full-byte preservation records

`StreamPreservationRecordsV1` is the additive current role-27 producer. Its
companion `IStreamPreservationRecordsV1` identifies this implementation; the
legacy `StreamPreservationRecords` constructor, ABI and historical record
identities remain unchanged. The new host uses the original fourteen-word
`6529stream.preservation-record.v2` preimage with its own actual address.

The constructor pins the actual Core, selected MetadataV1 authority, schema
registry and shared chunk store. Each new publication requires both record
host and Metadata host to be ACTIVE in Core's selected module registry.
It reads Metadata's original admitted record policy and collection-specific
or collection-zero family grant. It never accepts a caller-supplied class.
ARCHIVE, FIXITY, C2PA, IIIF, MEDIA_RELATIONSHIP and AGENT retain their original
per-family numeric classes. Other families use their original dedicated hosts.
All signatures are zero on this direct operator-asserted surface; a Safe CALL
records the Safe itself. This is not a detached-signature authorization API.

Submit the original `CollectionRecord` and its exact nonempty canonical bytes
to `recordCollectionRecordWithPayload`. Algorithm 1 and the complete Keccak
must match, and schema/canonicalization documents must be active. Maximum
payload size is 24,576 bytes. The host publishes up to three exact 8,192-byte
chunks to the original Store and retains their immutable ordered pointers.
Standalone uploads confer no record authority. Receipt, state history and
event retain the original author, class, grant scope/revision, schema hashes,
index, timestamp and original record-chain commitment. Failed publication
rolls back newly uploaded chunks, indexes, record and Safe nonce atomically.

The collection subject is canonical without registration. Register an actual
minted or burned token subject before publishing a token record; incomplete
prepared tokens are refused. `registerMediaSubject` records only canonical
Core/collection/object identity, and does not prove the media object's physical
existence or archival status. A different collection or free-form subject is
refused. Release, season and view scope admission is not implemented here.

Read `recordChainHash` and `recordHashAt` to recover the complete lane without
events. Latest records remain isolated by author. `recordPayload` returns the
first chunk pointer plus the complete hash-checked bytes; old one-chunk shapes
are unchanged in meaning. `recordPayloadChunkCount/At` gives exact full-payload
ordering. `payloadPointerCount/At` enumerates deduplicated accepted chunks by
collection/family/hash; each row's hash commits that chunk, not a concatenation.
Historical recovery uses original pointers and survives current host changes,
schema retirement and Store replacement. Display freeze does not stop
append-only preservation publication; this batch adds no lock authority.

The generic host binds bytes and attributed assertions. It does not validate
arbitrary JSON schema meaning, certify a performed fixity operation, satisfy
dual-family archive coverage, supply Artist consent, adopt renderer content,
or establish finality. Dedicated producers and consumers retain those checks.

The focused 100-source native run passes 9/9 cases, including 256 fuzz inputs, under Solidity 0.8.19, viaIR, 200 optimizer runs and Paris. Independent bounded production source review is clear. The focused fixture uses actual
MetadataV1, SchemaRegistry, Store and upstream 2-of-2 Safe; Core, Artist,
module-registry selection and Executor are explicit typed boundaries. Full
current genesis activation remains separate. Per-test gas includes deployment and is not a publication transaction-cap acceptance claim.

# Artist state-carried reconstruction

`IStreamArtistReconstruction` adds three reads to the current Artist facade and
its fixed Archive: `recordPreimageBytes(bytes32)`, `storedPayloadCount()` and
`storedPayloadAt(uint256)`. The last read returns `(pointer, payloadType,
payloadHash)`. This implements the retained-byte surface in AA-RECORDS 6–7;
AA-RECON 4 separately governs broader mirrored event-history reconstruction.

The catalog is append-only. Read indices from zero to count minus one, then
read each pointer using SSTORE2 (skip the leading STOP byte) and verify
`keccak256(payload) == payloadHash`. Rows are deduplicated by type and content
hash; different records may legitimately share a signature or document payload.
Indices and first published pointers never move. The catalog is discoverability
evidence and grants no authority, replay permission, current selection or finality.

The four AA-DOMAINS tags are `keccak256("ARTIST_IDENTITY_DOCUMENT")`,
`keccak256("ARTIST_SIGNATURE_BUNDLE")`,
`keccak256("ARTIST_DIRECTIVE_PAYLOAD")` and
`keccak256("ARTIST_RECORD_PREIMAGE")`. The implementation additionally catalogs
actual retained publication statements, sanction archives and original operation
envelopes under `ARTIST_PUBLICATION_STATEMENT`, `ARTIST_SANCTION_ARCHIVE` and
`ARTIST_OPERATION_EVIDENCE`, respectively. These are distinct content families;
an operation-envelope hash is never presented as an authority record hash.

The original Identity, Attribution and Consent owners write local immutable
carriers alongside their existing byte storage. At the end of a successful
Coordinator operation, a fixed library registers only previously unseen rows
with the fixed Archive. The Coordinator keeps its operation lock throughout.
Archive registration remains restricted to its immutable Coordinator, verifies
the physical SSTORE2 bytes and adds no semantic decision. A failure rolls back
the full original operation, its owner roots, nonce use, Archive envelopes,
carriers and cursor changes. Catalog state occupies separate fixed namespaces;
original ordinary storage fields and semantic record-chain preimages are unchanged.

| Executed authority record | Exact bytes stored |
| --- | --- |
| Rotation (32) | Original rotation domain, chain, registry, artist, old/new addresses, reason, old nonce, staged time and contest deadline |
| Identity recovery (35) | Original recovery domain, chain, registry and all original permanent `RecordFields` |
| Estate activation (40) | Original request domain, chain, registry, artist, successor, evidence, successor nonce, request time and notice deadline |
| Dormancy completion (43) | Original completion domain, chain, registry, actual Identity owner and original terminal tuple with its self-hash field zero |

`recordPreimageBytes` checks the stored bytes against the requested immutable
record hash. Unknown records and staged but unexecuted rotations/estate requests
revert. Execution facts that were never part of the old rotation or estate hash
remain available through the original typed records; they are not inserted into
those permanent preimages. Cancelled or superseded records retain their original
stored history, while only actual executions enter this authority-preimage family.

Existing document, signature, directive, attestation, sanction and Archive reads
are preserved. The catalog does not turn an opaque referenced narrative hash into
available bytes, rebuild unretained events, enumerate arbitrary typed child-state
records as if they were byte payloads, or authenticate a claim merely because its
bytes are stored. Broader history import, event mirroring and finality requirements
remain separate protocol surfaces.

The source batch also extracts existing activity-delta, estate mutation,
identity-return encoding/read dispatch and profile/payout logic into fixed linked libraries to
address measured Artist size limits. Original host selectors, storage layouts,
caller/operation checks, signature domains, replay keys, mutation ordering and
single host commits remain unchanged. Library addresses must be linked as actual
construction dependencies, including deployment-helper products.

`StreamArtistReconstructionActual.t.sol` adds six authored cases for all four
permanent preimages, pre-execution refusal, the original three byte families,
stable indexes, unauthorized Archive registration, late catalog rollback with
identical retry and corrupted-byte refusal with exact restoration. Its inherited
Artist/Safe/Archive recipes retain typed Core/governance and aggregate execution
boundaries. ABI/type checks and selected production code generation are recorded
separately; no native behavioral pass or whole-graph deployability is claimed by
this source guide.

# Complete chunked collection snapshots

`StreamChunkedCollectionSnapshots` publishes the explicit
`STREAM_CHUNKED_ONCHAIN_SNAPSHOT_V1` schema and
`STREAM_CHUNKED_ONCHAIN_SNAPSHOT_JSON_PROFILE_V1` interpretation. Its canonical
JSON has literal `version: 2`. The original `StreamCollectionSnapshots` inline
schema, serializer and default record/source/chain preimages remain unchanged.

This profile embeds every ordered logical script chunk and, when selected,
every immutable library chunk as canonical Base64. Each carries its index,
exact byte length and raw Keccak-256 hash; the enclosing payload carries its
whole byte length/hash and bundle ID. The full selected ScriptManifest and
pinned registry-version facts are included. A library registry's typed rolling
content commitment is distinct from the whole library byte hash. An absent
library is explicit JSON `null`. UTF8 code points may cross logical chunk
boundaries; no text normalization or URI fetch reconstructs them.

The maximum is 32 logical chunks of 24,576 bytes for each SSTORE2 payload.
INLINE_CHUNKS and registry-backed libraries retain their original 8,192-byte
logical limit. The separate snapshot envelope is bounded at 3,000,000 bytes,
stored in original 8,192-byte document-store segments. `snapshotManifestChunkAt`
and `snapshotManifestChunkCount` let readers recover the retained bytes without
requesting one large response. Publishing still assembles the whole canonical
document and validates preuploaded segments atomically. These are source bounds;
maximum transaction gas, deployment size and RPC capacity have not been measured
for this new producer.

## Publication and source authority

Deploy the new producer with the same nine fixed source roles and original
governed read/source/evidence/inventory caps as the inline producer. Independently
register the two generated definitions and the existing RFC8785 definition in
the actual selected schema registry. No constructor registration or default
writer grant is implied.

The inherited publication path requires both current SNAPSHOT and IDENTITY_DISPLAY
grants for the actual publisher. It preserves the original expected-head/revision,
unique snapshot label, source commitment, reason and effective-time checks, events,
locks and receipt layout. The new source, record and chain domains explicitly name
`CHUNKED_SNAPSHOT`; a caller cannot obtain this profile by changing an inline label.

The source reader authenticates the current Core/Metadata/Router pointers and
code hashes, actual saved bundle/manifest, chunk renderer, all six content locks
and original locked Artist presentation. It requires the actual published content
root, complete verified leaf manifest, explicit chunked checkpoint, complete
original-at-mint coordinator inventory and every frozen native entropy policy.
It preserves their original attribution; publication does not create an Artist
signature, archive coverage or historical entropy proof. Script and library bytes
are read from that authenticated bundle owner and independently rehashed before
serialization. Current checks retain original source/profile/byte validation;
historical stored manifests remain readable independently of later source drift.

`StreamFinalitySnapshotReads.requireCurrentChunked` and `requireLockedChunked`
are explicit consumer entries with the new definition/record/input domains and
envelope bound. Original `requireCurrent` and `requireLocked` remain inline-only.
Choosing these consumer entries in another aggregate provider or deployment is
separate integration work; this source change does not silently replace an
existing provider's snapshot owner or policy.

## Offline validation and export

Generate or check the registered interpretation bytes:

```sh
python -m tools.metadata.chunked_snapshot_profile --check
```

Validate a recovered canonical manifest and write a new local export directory:

```sh
python -m tools.metadata.chunked_snapshot_profile --manifest snapshot.json --output snapshot-export
```

The exporter rejects missing or unknown fields, duplicate JSON keys, noncanonical
bytes/Base64, invalid UTF8, bad order/limits, wrong payload hashes, wrong bundle and
typed ScriptManifest preimages, inconsistent library relationships and wrong
registry rolling commitments. It writes the original `snapshot.json`, exact
`script.js`, optional exact `library.js`, and a hash/qualification report. It
never overwrites an existing export. The two payload files remain separate;
rendering combines them using the selected renderer's original semantics.

An offline self-consistent document is not evidence of chain publication or
institutional acceptance. Retain the actual captured record/receipt, verified
owner/source provenance and storage segments when composing a recorded museum
package. Compact token JSON references are never treated as complete script
exports. Arbitrary web dependencies, browser execution closure, full media/custom
metadata export and reference render evidence remain separate requirements.

## Validation boundary

Focused source cases cover actual Metadata/Router/bundle/checkpoint/root and
native frozen policy composition, direct publication, independent record hashing,
explicit consumer separation, source-byte drift/restoration, revision history and
real Safe missing-chunk rollback with an identical retry. Core, Executor, Artist
and archive facts use the existing explicitly typed fixture boundaries. The new
contract cases have been typechecked but not executed. Offline tests cover complete
payload export, both full-size payloads, malformed input and unchanged inline
interpretation; synthetic cases are not relabeled as recorded captures.

See [chunked script rendering](../chunked-script-profile.md) and
[chunked checkpoints](onchain-content-checkpoints.md) for the source producers.

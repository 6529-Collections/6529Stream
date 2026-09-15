# Chunk-backed script and library profile

The current MetadataV1/Router source adds an explicit
`6529STREAM_ROUTER_CHUNKED_PRESENTATION_V1` profile alongside the existing
8,192-byte stable presentation. A collection selects a completed typed
manifest through the original `setCollectionScriptManifest` authority,
Artist SCRIPT consent, replay, evolution and lock checks. Permissionless
payload publication cannot select content for a collection.

## Publish and select

1. Call MetadataV1 `beginScriptBundle` with the full payload Keccak hash,
   source type, ordered per-chunk Keccak hashes and byte lengths. Use
   `INLINE_CHUNKS` for chunks up to 8,192 bytes or `SSTORE2` for chunks up
   to 24,576 bytes. There are at most 32 logical chunks, allowing exactly
   786,432 script bytes. A library bundle is marked `libraryOnly` and has no
   library of its own; scripts may pin one already-finalized library bundle.
2. Call `appendScriptBundle` in index order with each exact byte payload.
   Matching repeated appends are idempotent. Incorrect bytes, omitted indices,
   invalid UTF-8 and replacement attempts fail. Streaming UTF-8 validation
   allows a code point to span chunks and bounds validation work per append.
3. Call `finalizeScriptBundle`. This requires every append, a complete UTF-8
   sequence and the independently verified whole assembled payload hash.
   Finalization reconstructs in memory; it does not store another whole copy.
4. Build `ScriptManifest` with `scriptHash` equal to the payload hash,
   `rendererCompatibility` equal to the chunked profile, matching source type
   and chunk count, `application/javascript`, and `executable=true`.
   `sourcePointer` is the lowercase, 66-character `0x` bundle ID.
   Optional `scriptURI` and `libraryURI` are source references only. A library
   URI requires a pinned library bundle; no URI is executed or downloaded.
5. Use the existing Router `previewArtistScriptManifestState` to obtain the
   exact content-family consent value, then select with
   `setCollectionScriptManifest`. The typed manifest hash is distinct from
   both this consent value and the payload hash. Its new domain is
   `6529STREAM_CHUNKED_SCRIPT_MANIFEST_V1`; it commits chain, Core, metadata
   owner, Router/code hash, collection, bundle ID, all bundle facts and the
   complete typed manifest. The existing small-profile domains stay unchanged.

Each logical SSTORE2 chunk normally uses one immutable STOP-prefixed blob.
A full 24,576-byte logical payload uses a 24,575-byte blob plus a one-byte
blob so neither deployed runtime exceeds EIP-170. Reads check the prefix,
physical sizes, logical length and payload hash. No monolithic script or
prepared-script copy is added to Router storage. Old raw script storage remains
separate; selecting a bundle does not relabel those bytes. Setting a raw script
clears an active bundle even when that raw string equals the retained old value.

## Libraries and reconstruction

Libraries can use the same local immutable chunks, shared by many scripts.
`beginRegistryLibrary` also supports an explicit version of the existing
`DependencyRegistry`: callers supply its address/code hash, original dependency
key, nonzero version and canonical typed content hash. Registration checks the
original rolling typed chunk-hash sequence. Ordered appends verify the declared
bytes against that pinned version; finalization checks the assembled payload
hash. Reads use that exact version and code hash, never `latest`. No registry
bytes are silently copied or replaced when the source becomes unavailable.
This adapter does not upgrade the legacy registry's administration or claim a
new governed/finality-aware registry implementation.

`scriptChunk(collectionId,index)` and `scriptChunkCount(collectionId)` resolve
the current selected manifest. `scriptBundleChunk(bundleId,index)` reads an
immutable logical chunk after a selection changes. `scriptBundleChunks` returns
up to four consecutive chunks per page. `dependencyChunk(libraryBundleId,index)`
reads a finalized library. `dependencyManifest(libraryBundleId)` returns its
actual payload hash, source type, canonical local library key and pointer,
JavaScript MIME type, and pinned version when applicable. The separately typed
`scriptBundleRegistry` record provides the original registry address, code hash,
key, version and typed content hash; the human-readable version alone is never
an authority or integrity check.

## Serving

Router `tokenHTML(tokenId)` reconstructs pinned library bytes, a newline/semicolon
separator, and script bytes, then escapes script-closing tags across the complete
payload. It adds the original token ID, entropy hash and token-data context.
`tokenJSON(tokenId)` includes the full animation data URI and explicit token
bytes. Both serve retained burned identities; JSON discloses
`properties.stream.render_state="burned"`, and HTML has a matching
`data-stream-render-state` attribute. Ordinary ERC-721 serving still rejects
burned tokens. Unfinalized entropy cannot produce a full executable view.
The existing stable default render selector and serialization remain unchanged.
An authenticated older Metadata host that explicitly lacks the bundle ERC165
capability retains that stable branch. Malformed or reverting capability reads,
or failures after advertising bundle support, are terminal.

The chunked default is compact JSON, with `properties.views` pointing to the
actual `tokenHTML` and `tokenJSON` methods. It stays below the 24,576-byte data-URI
envelope without loading the whole executable payload. Full display fields and
attribution are retained in `tokenJSON`; an unusually large default moves those
fields to the explicitly disclosed full-view location instead of fabricating
an attribution-unavailable result. The two assembled views have their own
bounded output profile, and paged bytes remain available when RPC execution or
response limits prevent a single large call.

Live serving joins current Core metadata and Router pointers. Frozen serving
uses the original durable finality anchor and independently authenticated
companion routes. A chunked script source must be locked and match its saved
manifest/bundle/hash/length; the selected dependency source must pin the same
library on the same metadata owner/code. Current-pointer replacement never
selects fresh bytes for a frozen work. Original small-script frozen routes keep
their existing branch; unsupported mixed render/context profiles fail closed.
The original finality and archival/snapshot admission requirements still apply.

Router adds `ROUTER_BUNDLE_READ_GAS`, `ROUTER_BUNDLE_RENDER_GAS` and
`ROUTER_FULL_VIEW_GAS` to its canonical host-owned GGP inventory. The original
four rows retain their indices and commitments. Registry reads use MetadataV1's
existing `METADATA_DEPENDENCY_READ_GAS`. Bounded view calls reserve return gas;
configured caps are maxima, and nested reads may forward less when the caller
provides less gas. New floors are implementation values, not measured collector
or all-cold gas conformance.

## Component evidence and archival roots

The fixed Router evidence helper recognizes an explicitly selected chunked
bundle and uses `6529STREAM_CHUNKED_ROUTER_COMPONENT_EVIDENCE_V1`. Original
stable-profile preimages remain unchanged. Script facts bind the exact saved
manifest and finalized bundle; dependency facts additionally bind the actual
library and pinned registry version. An unavailable registry cannot silently
replace library bytes, and does not prevent independent media or script
commitment reads. Renderer/context facts identify the actual chunk renderer,
while metadata facts retain the actual locked display and artist presentation.

The [explicit chunked checkpoint](integrations/onchain-content-checkpoints.md)
computes full-artwork roots using `historicalFullTokenMetadataJSON(core,tokenId)`.
That archival view retains historical lifecycle and locked artist bytes after a
burn, including when authenticated finality selects the original frozen source.
Public full views retain their current burn disclosure. The current snapshot
serializer still accepts only its separately declared stable inline profile;
complete chunked snapshot/export composition remains required.

## Validation boundary

Thirteen authored cases cover maximum logical capacity, physical blobs, paged/full
reconstruction, UTF-8 boundaries, missing/wrong bytes, cross-chunk escaping,
original content consent/locks and clearing, pointer drift, burned output,
actual legacy version pinning, an actual Safe's identical failed-call retry,
selected frozen/proof-drift behavior, legacy capability dispatch and unique full-JSON fields. The suite uses actual MetadataV1,
Router, fixed workers, blob deployment, DependencyRegistry and Safe contracts;
Core, Artist, Executor and historical finality admission are explicit typed
boundaries. ABI/type checking and selected-product bytecode sizing do not claim
these test bodies passed. Focused native runtime and combined current-stack
validation remain pending, as do the broader snapshot/export, diagnostic status,
renderer-vector and gas-conformance requirements.

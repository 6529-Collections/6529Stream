# Current typed collection manifests

`IStreamCollectionManifestReads` adds typed ScriptManifest and MediaManifest
reads on the actual current `COLLECTION_METADATA` owner. Artist attestation
kinds 2 and 3 use `bytes32(collectionId)` as the subject and the corresponding
`scriptManifestHash` or `mediaManifestHash` as its current state. These are full
manifest commitments. They are different from a raw script digest, a Router
family commitment, and a referenced external media manifest digest.

The source model follows the [manifest home](collection-metadata-contract.md).
The current executable profile binds the Router's actual nonempty UTF-8 script,
up to its existing 8,192-byte limit, with one logical inline chunk, the existing
stable renderer compatibility ID, `application/javascript`, and no independently
loaded library or alternate source pointer. The metadata owner preserves those
exact bytes in its existing write-once blob store. `scriptChunk(collectionId,0)`
reconstructs and verifies them. Source archives, larger chunked scripts and
other execution profiles return `UnsupportedCollectionManifest`; this batch
does not pretend they were run by the current renderer.

Media descriptors bind the actual shared image URI. Asset entries support
explicit IPFS, Arweave and HTTPS source types, nonempty MIME types and nonzero
hash commitments; NONE has no URI, MIME or hash. Reference manifests and
alternates likewise require both a URI and its declared hash. These are signed
content commitments, not claims that the contract downloaded or verified
external file bytes. Content and optional animation descriptors are retained
facts; they do not automatically add new fields to the current token renderer.
A nonempty animation base URI is a token-URL recipe, so it cannot be relabelled
as one shared animation asset. That profile requires an absent animation entry.

To select either manifest, the Router authority calls
`setCollectionScriptManifest` or `setCollectionMediaManifest`. Both are admitted
as ordinary class-1 selectors in the current fixture and deployment policies.
The same existing Core freeze, content-family locks, current Artist consent,
consent consumption and ratification-continuity checks apply. The metadata
storage entry point only accepts the actual current Router; calling it directly
cannot bypass those gates. An exact selected no-op consumes no additional
consent. This adds no Artist attestation automatically.

Preview tools use `previewArtistScriptManifestState` and
`previewArtistMediaManifestState` to obtain the exact resulting family hash for
Artist consent. The canonical manifest hash is:

```text
keccak256(abi.encode(domain, chainId, core, metadataHost, router,
    router.codehash, collectionId, servingSourceHash, fullTypedManifest))
```

The domains are `6529STREAM_CURRENT_SCRIPT_MANIFEST_V1` and
`6529STREAM_CURRENT_MEDIA_MANIFEST_V1`. `servingSourceHash` is respectively
`keccak256(bytes(script))` or `keccak256(abi.encode(imageURI,animationBaseURI))`.
The enclosing family and full-content commitments include the selected host,
code hash and manifest hash. Collections with no selected manifests preserve
all original commitment bytes. Changing the actual raw script or media fields
clears the corresponding selection through the same content authorization;
changing a name alone does not. No-op raw previews retain the selected wrapper.

A zero current hash means no selected manifest. Missing, changed, unselected or
malformed dependencies revert instead of supplying guessed metadata. Full
current reads join the Router's selection to an immutable record of the same
kind, collection and Router. `recordedScriptManifest` and
`recordedMediaManifest` retain earlier records after selection changes. Their
existence is not a claim that they remain the current selection.

Seven focused source cases cover independent full-hash/event oracles, script
byte reconstruction, media binding, no-op and raw invalidation, wrong
collection/family authority, direct-host rejection, content/Core locks, missing
facts, pointer drift and a real threshold Safe's identical signed retry after
missing Artist approval. Core, Artist authority and Executor in these cases
are explicitly typed fixtures. ABI-only checks are separate from deferred
native runtime, bytecode sizes, full current-stack transactions and finality
artifact/export integration. The existing large-script and broader media
rendering requirements remain outstanding; no full manifest conformance is
claimed here.

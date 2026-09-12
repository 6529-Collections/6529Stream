# Stable router presentation and serving evidence

`IStreamMetadataServingFacts` describes the implemented router's stored
content and deterministic public presentation. It supplies facts for a
separate finality provider; it does not decide finality, schema registration,
offchain media fixity, or complete artist display conformance.

The original Core-facing `IStreamMetadataRouter` interface stays unchanged.
The new serving interface is additive. Its two locks require the router's
configured `authority` caller. They can be set after Core collection freeze:
Core freeze does not set either lock. Neither operation edits the stored
script, media URI, name or description.
Every successful operator lock emits `CollectionMetadataLocked` with
`authorityClass = 0` and `freezeAuthorizationHash = 0`. Repeated locking
reverts, preserving the first accepted snapshot.

`lockArtistIdentity` reads the Core's actual selected artist facade, checks
its runtime commitment and same Core, and joins its composed attribution
state to its nomination and acceptance facts. Only accepted or sanctioned
associations are admitted. It saves the artist ID, binding generation and
hash, ratified identity-document hash, original acceptance record and time,
and the binding's nominated artist address. The nominated address is not
necessarily the acceptance signer: authority can rotate before acceptance.
`ArtistPresentationLocked` publishes the full saved tuple and its versioned
snapshot hash. `artistPresentation` reads only that local immutable history.

After this lock, the public JSON's existing `artist`, `artist_identity_hash`,
and `artist_acceptance_hash` fields use those retained presentation facts.
If authority already rotated, applying the lock deliberately changes the
presented address from that live authority to the ratified nominated address;
the operator must apply the lock before fixing the corresponding content root.
The lock freezes the binding reference, not any authority key or registry
lifecycle. `collectionLiveArtistStatus` separately reads current attribution,
authority status and authority address. It fails on unavailable or malformed
canonical reads instead of inventing a replacement status. The two state
namespaces remain distinct. Authorization of new artist actions continues
through the actual artist registry.

This bounded profile does not implement the full AA disputed, revoked,
sanctioned, estate, or degraded-response overlays. Its historical presentation
must not be described as a statement of current authority or current dispute
truth. A finality provider must explicitly identify the adopted presentation
profile and the separate live diagnostics. It must not silently remove fields
from served artwork to make a content root verify.

`lockDisplayMetadata` seals the configured collection name and description.
It requires an existing configured collection. An identical name and
description may still accompany a separately authorized image/base URI
change. Media, base URI and script keep their existing artist-content locks
and consent checks; the operator display lock grants no artist authority.

`collectionServingFacts` reports the following actual facts:

- `configured`, separately from the stored script's presence.
- `mode = keccak256("ONCHAIN")` for a nonempty stored script, otherwise
  `keccak256("OFFCHAIN")`. This is the current router profile's inference;
  it does not claim HYBRID support.
- The fixed linked JSON renderer address and its actual runtime code hash,
  original script hash and length, and image/base URI hashes.
- Each explicit script, media, base URI, artist-identity and display lock,
  with Core freeze reported separately.
- `dependenciesLocked = true` means the renderer assignment is immutable.
  It does not assert availability or immutability of external media servers,
  Core pointers, entropy providers, or the entire dependency graph.

`collectionServingSource` returns the exact original UTF-8 name,
description, image URI, animation base URI and script. The respective stored
byte bounds are 256, 2,048, 2,048, 2,048 and 8,192. These reads do not resolve
remote media. Empty-field hashes are Keccak-256 of empty bytes, not a claim
that an absent asset has a nonzero content-root leaf. Consumers apply their
declared leaf schema to distinguish source URI hashes from media-byte hashes.

`historicalTokenMetadataJSON` accepts a permanent MINTED or BURNED Core token
identity and requires finalized entropy from its original coordinator. It
uses the same serializer as the live public JSON, including every field and
full uint256 decimal value. Ordinary Core and router `tokenURI` still reject
burned tokens. The historical read combines retained token identity/data
with the router's currently stored collection content; it does not invent a
past collection-content snapshot. A finality verifier must check the explicit
locks and exact source/dependency commitments it promises.

The presentation profile is
`keccak256("6529STREAM_ROUTER_STABLE_PRESENTATION_V1")`. Its deterministic
Stream serialization is **not RFC8785/JCS**: existing key order and uint256
number literals are preserved. A canonicalization document must describe
these exact bytes and lossless integer parsing, or an explicitly validated
value-preserving transform. Changing or rounding a value is not canonicalization.

Deployment links the new `StreamMetadataArtistPresentation` and
`StreamMetadataTokenRenderer` libraries in addition to the existing
`StreamMetadataRenderer` escaping helper. The finality provider must pin the
actual router runtime and complete helper/source closure. The new artist
reader copies only exact fixed-size results and uses available gas for the
trusted immutable Core and its actual selected facade; this is not a new
unmeasured signature or arbitrary-provider gas allowance.

Focused tests cover malformed association rejection and retry, explicit locks,
independent golden JSON/data-URI bytes, full-width integer serialization,
burned identity and finalized-seed boundaries, and actual threshold Safe
calls. These focused tests use explicit Core/artist/entropy read fixtures.
The separate actual-current rotation/burn composition and retained
Core/entropy rendering regressions are required handoff evidence; their
acceptance is tracked separately from the focused source and product builds.

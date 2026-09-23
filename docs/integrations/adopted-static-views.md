# Artist-adopted STATIC views

This additive profile provides an explicitly selected alternate rendering of an
actual token. It retains a complete named view payload and authenticates its
adoption through the original Router and Artist operation 17. Existing collection
rendering, URI selectors and original collection record domains keep their prior
meaning. The profile is `6529STREAM_STATIC_ADOPTED_VIEW_V1`.

The implementation is a first VIEW source/adoption/rendering batch. It does not
yet provide VIEW output checkpoints, reference publication, complete render
inventory or a VIEW finality ceremony. The new provider retains the prior refusal
for those unfinished VIEW finality operations. Terminal entropy V2 is also a
separate required successor: this renderer requires an actual original
Coordinator FINALIZED status and never manufactures a token, serial or seed.

## Two different identifiers

`Input.scope` is the full canonical VIEW scope: `(VIEW, collectionId, 0, scopeId)`.
The original Membership producer must supply its complete sealed membership.
`scopeId` identifies that membership. `Input.viewId` identifies the original
CollectionViews declaration. These values are independent and are both retained.
An empty sealed membership may be adopted before mint; rendering still requires
an actual token included by the original membership producer.

The selected Finality provider advertises `IStreamViewSourceBinding` and returns
immutable constructor-bound Views and Membership addresses, runtime hashes and
read budgets. Router source preparation checks the actual selected provider,
Core, Metadata, Artist, Finality, SchemaRegistry, Store and both source hosts.
The derived `StreamFinalityViewEvidenceProvider` adds this binding to the combined
provider. It is a new deployment identity; an old provider receipt is not a receipt
of this new provider. The existing original collection operations keep their
inherited behavior at the new host.

## Complete payload and renderer admission

The declaration uses `STREAM_STATIC_VIEW_PAYLOAD_V1`, RAW_BYTES and
`application/octet-stream`. Its canonical payload is exactly
`abi.encode(contextVersion, name, description, imageURI, script)`, represented by
`StreamViewAdoptionTypes.Payload`. `contextVersion` is
`keccak256("STREAM_ADOPTED_VIEW_CONTEXT_V1")`. Limits are 40,960 complete bytes,
128 name bytes, 8,192 description bytes, 2,048 image URI bytes and 24,576 script
bytes. Text and script require valid UTF-8; image URIs use the original URI
validator. Complete original definition bytes are in `StreamViewPayloadV1`.

Adoption validates the actual current CollectionViews head, complete declaration
receipt, original generic collection-record preimage, definition documents,
manifest carrier, full payload and every original Store chunk. A record retains
the exact payload hash, length and up to five ordered chunk pointers and hashes.
This is complete byte retention, not a URI or a claim based on sampled content.

`StreamViewRendererV1` has its own version, context and output schema. It must be
admitted by the actual governed RendererRegistry with its own analysis, complete
declared read set and golden document under the existing admission rules.
Original renderer admission is not automatically admission of this profile.
Source preparation verifies the exact selected version, runtime, complete
manifest, registration/read-set commitments and `requireAssignable` result.
The empty registration vector is explicitly an unconfigured golden; it cannot
establish conformance of an actual token or the complete dependency graph.

The direct STATIC serving roster includes the new Router head and 96-byte
`viewAdoptionCarrier` getter, original Core token identity/lifecycle/metadata,
original Coordinator render facts, retained renderer-registry reads, Membership
and the original live attribution companion. Immutable Store carrier code is
read with EXTCODECOPY after length, STOP and digest checks. Serving does not call
the public delegate-library full-byte getter. A reviewed transitive roster and
actual governed golden execution remain deployment evidence obligations.

## Original consent and aggregate state

`previewViewAdoption(input, actor)` returns the prospective RENDERER_CONFIG family
state and source hash. The writer obtains original Artist content consent for
that prospective family state and calls `adoptView(input)` with a nonzero exact
`expectedSourceHash`. `expectedPrevious` must be the current head for the complete
VIEW scope. The original selected Metadata grants determine the writer: exact
IDENTITY_DISPLAY authority class 7 is preferred, then global publisher class 8.
Collection-specific grants precede global grants within each class.

Every VIEW adoption requires a nonzero original operation-17 consent, including
pre-mint adoption. The original permissive pre-ratification branch remains in
the old authorization entry point; the new closed entry disables that entire
branch. Ratification, evolved current-state checks, the one-use consent map and
application bookkeeping remain the original Router mechanisms. VIEW creates no
parallel consent book. Source, grant and prospective state are checked again
before the immutable record and head commit.

The appended compiler-owned namespace holds per-scope heads, immutable record
carriers and a per-collection aggregate. Every successful VIEW write advances
the aggregate revision and transition chain in constant time. At revision zero,
RENDERER_CONFIG has its exact old family hash. After the first adoption, all
original RENDERER_CONFIG state calculations include the aggregate; later default
STATIC configuration changes cannot discard it. Original Router storage roots
are not moved. The original collection freeze, Artist RENDERER_CONFIG lock and
exact or inherited artwork VIEW freeze refuse a new adoption.

## Current and historical rendering

`tokenJSONForView(tokenId, scopeId)` and `tokenHTMLForView(tokenId, scopeId)` select
the current adopted head, require the current original view declaration and
selected source graph, and reject burned tokens. Actual token identity, serial,
membership, Coordinator-at-mint, finalized seed and complete tokenData enter
rendering. HTML exposes these facts and the exact view/adoption/source identities
in `window.STREAM_VIEW`; script end tags are escaped without changing other
script text.

`historicalTokenJSONForView(tokenId, adoptionHash)` and the corresponding HTML
entry select a retained immutable adoption directly. They permit a genuinely
burned original member using its actual burned lifecycle. Historical selection
does not require that adoption to remain the live head. Retained runtime and
carrier integrity, actual identity and membership still apply. Original live
Artist attribution remains live: a later standing conflict can change JSON.
Historical record retention is not a promise that live annotations freeze.

`viewAdoptionEncoded(recordHash)` returns complete original canonical record
bytes, while `viewAdoptionCarrier` supplies the exact pointer/hash/length for
STATIC consumers. A carrier alone proves nothing until its complete bytes and
record identity are checked. Neither getter asserts current source eligibility.
The new Router render entries forward only four fixed selectors to their pinned
STATIC worker; adoption/preview decoders likewise accept only their exact
original selectors. No caller-selected worker or generic target dispatch exists.

## Original Router read compatibility

The Router keeps its original token and collection selectors, storage roots,
guards and budgets. Two existing read bodies now run in the fixed compiler-linked
`StreamMetadataRouterReadFacade`. The actual Router supplies its original typed
storage references and immutable source identities. An activated STATIC token
still returns before the original serving-anchor refusal; collection Core and
existence checks still occur in the host first. This is a read-only extraction:
source selection, retention, consent and writes remain in their original owners.
The new facade is an explicit linked deployment/read dependency. Cold gas and a
complete admitted transitive roster remain separate integration evidence.

## Evidence boundary

The frozen focused successor passes 21 cases, including two 256-run fuzz cases:
14 VIEW transport/rendering cases and seven original read-facade equivalence
cases. The tests use the actual Store, immutable record producer, new renderer,
original authorization and fixed transport workers with explicit typed source
and Artist boundaries. They cover original pre-mint behavior versus required
consent, ratification/replay, independent family/record preimages, two scoped
heads, history, actual token fields, burned identity, payload corruption and live
attribution drift. The read-facade cases preserve frozen original body oracles,
exact refusal order, delegate caller/storage arguments and literal collection
JSON. The STATIC positive executes the real internal route against typed pinned
sources; its allowBurned loop uses an unburned token.

These cases do not execute full original Artist operation 17, governed
RendererRegistry admission, actual Membership sealing or a VIEW finality
ceremony. The read-only extraction's additional cold frame/storage cost and a
production transaction envelope remain unmeasured. Initial joined Router size
failures are retained. The final affected-pair measurement has Router runtime
21,320 bytes and fixed read facade 7,693 bytes. All distinct original ABI entries
and all original storage roots are preserved. Two duplicate identical inferred
error rows each collapse from two copies to one, without removing either error
signature. Restoring the one otherwise missing error declaration leaves both
creation/runtime objects byte-identical.

The first focused run's 20-pass/one-failure result is retained: its new STATIC
test incorrectly tried to replace an internal inlined helper. The successor
supplies the real route's required typed inputs and independently compares the
full renderer request. An intervening cache attempt was rejected by the strict
compiler selector before code generation because Forge supplied a narrower
source roster. The final capture uses an exact frozen 228-source graph, genuine
native selected outputs, full artifact verification and unchanged test budgets.
These bounded results do not establish the complete current deployment graph.

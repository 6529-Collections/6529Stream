# Complete original living Artist multiplicity

`IStreamArtistMultipleAuthorityHydration.hydrateMultipleArtistAuthority(Request)`
selects `6529STREAM_ARTIST_MULTIPLE_LIVING_HYDRATION_V1` under operation 60 and
its original seven-owner mask `0x7f`. It implements the next AA-PERM/AA-IMPORT
slice: multiple original living Artists, multiple accepted generation-one
collections, and more than one such collection using the same Artist identity.
The earlier single-Artist selectors retain their exact ABI and restrictions.

## Caller inputs and completeness

The request contains the original binding index (zero), strictly increasing
`artistIds`, strictly increasing collection IDs with their actual Artist and
policy phase/hash selectors, seven complete source checkpoints and every
original replay surface/scope in source inventory order. Policy selectors for
each collection follow that collection's original operation-14 receipt order;
the global Consent journal may interleave different collections.

The fixed worker authenticates the selected predecessor runtime, completed
original operation-57 seal, one reciprocal source binding, all eight unchanged
non-Artist dependencies and all seven fixed owners. Each supplied Artist and
collection must have its own exact permanently latched final lane. Caller
lists are not a completeness assertion: every native receipt in every owner
is visited, each identity registration must match its actual original
registration ordinal and predecessor-domain Artist ID, and the actual global
registration allocator must equal the complete identity count. Each Artist
must occur in at least one accepted collection in this profile.

The only source record families admitted are original registration/proposal
(1), acceptance (2), direct PRIMARY_ONLY policy consent (14) and authorization
revocation (54). Exact per-owner revision totals additionally reject operations
with no native receipt. The complete typed nonce index inventory must contain
exactly one original identity kind-1 index per supplied Artist, in any actual
source insertion order. Every sparse prefix and all 32 ancestor words are
copied for that Artist, with the original exhaustion value and nonce hint.
All replay cells, exact digest revocations and logical scope preimages are
preserved and rekeyed by the existing successor-owner domain recipe. The
predecessor's operation-57 latch remains historical, as in ADR 0047.

## Typed import and one transaction

The additive Identity read `authorityLivingIdentityHydrationState(Query)`
exports the existing original identity/document/signature/activity shape with
its actual global registration allocator; it does not grant authority. All
other exports use the existing fixed-owner baseline reads.

`6529STREAM_ARTIST_MULTIPLE_LIVING_STATE_V1` tags deterministic `abi.encode`
row envelopes. Collection rows carry exact original binding, acceptance,
attribution and policy state. Identity rows separately carry each Artist's
original document, retained signature bytes, activity counters and full nonce
prefixes. Empty Collaborator and Payout owners remain explicitly empty.
Unsupported records, corrections, grants, timing changes, C2PA/attestation
heads or previous imports cause refusal before any destination owner write.

The existing guarded `applyArtistAuthorityHydration` transport still runs once
per owner, installs one common completion commitment, and makes one original
owner state commit. The Identity fixed worker activates each Artist lane once
and every supplied collection lane once, including shared-Artist collections.
No partial authority can survive a revert: all cells, lane activation, global
allocator, completion markers, Archive append and payload synchronization are
one transaction. Historical record/signature domains remain the predecessor's;
fresh successor consent requires a new successor-domain signature or a real
authenticated direct Safe call. Future registration uses the carried global
allocator without rederiving imported IDs.

The original Archive envelope and `ArtistAuthorityHydrated` anchor event remain;
this profile additionally emits `MultipleArtistAuthorityHydrated` with all
ordered Artist and collection IDs. The Archive payload contains all tagged
rows, source headers and guards, allowing independent reconstruction of the
complete profile commitment. The anchor identifies the first collection, not
an assertion that the profile contains only one identity.

## Bounds, validation and remaining profiles

Bounds remain 128 native receipts per owner, 512 replay cells per owner,
128 selected Artists/collections, and 256 nonce prefixes in total. The complete
encoded evidence must fit the original 24,575-byte Archive carrier before any
write. These are admission bounds, not a promise that every combination fits
one transaction or this evidence carrier. No cap or carrier limit is raised.

The authored `StreamArtistMultipleAuthorityHydration.t.sol` cases use actual
Registry, Coordinator, seven-owner, Archive and threshold-Safe contracts with
the existing explicit typed Core/governance boundary. They cover independent
and shared identity collections, exact Archive/codec/header/nonce/event oracles,
fresh forward writes and allocator continuity, omissions/duplicates/foreign
scope, source runtime drift, old signature domains, per-Artist revocations,
late Archive rollback and identical Safe retry, and strict original-selector
compatibility. Source ABI validation is separate from runtime, deployability,
transaction-capacity and current-Core cutover acceptance.

Additional corrected generations, pending/refused bindings, delegated and
collaborator policies, payout/economics/readiness/publication/finding combinations,
advanced authority histories, repeated imports and larger/paged evidence remain
full-v1 obligations. Existing supported single-identity advanced profiles remain
available separately; this profile never silently drops their extra records.

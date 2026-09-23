# Complete living records across Artists and collections

`hydrateMultipleArtistAuthorityWithRecords(MR.Request)` is one additive capability
using original operation 60. It carries the original `MH.Request` plus one
`CollectionWitness` for every collection, in the same ascending collection-ID
order. Each witness has the original economics consent terms and original
attestation terms/nonce, ordered by that collection's receipts in the complete
fixed-owner journal. Empty arrays explicitly mean no records of that family.

The profile is `6529STREAM_ARTIST_MULTIPLE_LIVING_RECORDS_V1`. This request is
needed because original op15/op24 stores do not retain every signed preimage
field. Witnesses never establish completeness: all seven original journals,
registration allocator, owner revision equations, both nonce kinds, every
replay/revocation cell and the sealed/latch-verified original history establish
the complete set first. Missing, extra, duplicate, foreign or reordered witnesses
fail before an owner write. Old baseline/multiple/delegation selectors and
encodings retain their previous supported histories and rejection boundaries.

The finite profile supports original living class1 generation1 bindings in
consent modes1/2, with complete original ops1/2/14/15/16/17/18/24/25/26/27/52/54.
Policy and sale records may use original recorded delegates. Expired, revoked,
replaced or exhausted grants remain historical facts; complete use totals across
all collections, exact recorded grant associations and nonce trees are carried.
The additional economics/content/publication records are the existing direct
class1 profile. They do not become delegated records through import.

Payout chains remain per Artist; the last original designation and absence of a
pending transition are checked. Economics records retain exact original payload
and binding associations plus consumed cells. Ratifications and content-consent
records retain their complete original terms and last-key heads. Original op24
records retain terms, nonce, signer/class, statement, association, publication
envelope and saved host runtime. Their original predecessor domain is rehashed;
successor signatures still use the successor domain.

Attribution records are imported in the global original owner order. This is
necessary for one Artist's C2PA credential chain spanning several collections.
Every credential record, per-Artist final credential head and per-collection
personhood head are checked independently. Detached publication kinds7/8 retain
their full evidence; Metadata's existing consumed authorization map remains in
the original Metadata host and is neither copied nor reset by operation60.

All state is prepared before the original seven-owner commit. The exact source
headers and suite are checked again after the writes and before the one original
Archive append. The original multiple-hydration event then emits the exact
predecessor, commitment and complete ordered Artist/collection lists. The Archive retains its original 24,575-byte evidence maximum.
An overlarge complete profile refuses atomically; no subset import or raised cap
is supported. Small authored shapes fit by independent ABI size arithmetic, which
is not transaction execution or capacity acceptance.

Corrected/pending bindings, advanced authority/guardian histories, delegated
attestations/content/economics, collaborator quorum, freezes, findings, repeated
imports and larger evidence carriers remain separate required profiles. The new
`keccak256("6529STREAM_ENTROPY_CONFIGURATION_V1")` op17 family specifically refuses
until its new policy dependency joins are implemented. Original metadata and
host-bound entropy recovery consent terms remain within the supported profile.

Focused tests use actual Artist facades/seven fixed owners, original history
operations, Archive and threshold Safes. Core, governance action facts, candidate
Metadata host and content-state reads remain explicit typed unit boundaries,
except the dedicated consumption case, which uses the original actual Metadata
host and checks its unchanged receipt/payload/consumed-authorization cell.
These authored cases are not a current-graph or native execution claim. The
pre-existing Attribution deployment-size blocker remains outside this batch.

Source validation: 902-source ABI12 is clean; 635 prior ABI entries and recursive
storage layouts are retained. Final size3 and size4-workers captures fit all 17 selected new/changed/paired
products,
including Registry 24,575 bytes (one-byte margin) and Coordinator 24,083 bytes.
Twenty regression cases are authored; native execution remains pending. Final
joined capacity must be remeasured after independent facade changes integrate.

# Native Artist review selection

This additive profile admits exact review statements from selected native Artist
records. It binds each review to the original assertion, native publication
scope and historical authority. Different Artist IDs and different signing
accounts can supply an explicitly selected review. They do not establish
independent people, professional qualifications or institutional authority.

The [earlier native attribution profile](museum-native-attribution.md) and its
registered bytes retain their original meaning. General notarizations,
independent-account records, curator labels and institution labels do not
become Artist reviews through this adapter.

## Native publication compatibility

The Metadata producer and raw catalogue reader require
`ARTIST_SEMANTIC_ASSERTION` records to use the original
`STREAM_SEMANTIC_ASSERTION_V1` schema. Its bytes and embedded
`STREAM_MUSEUM_SEMANTIC_PROFILE_V1` envelope identifier stay exact. The new
interpretation is an explicit **profile hash** opt-in by both original and
review records, with separately registered profile, review-body, policy,
crosswalk and export documents. Reusing an assertion schema does not reinterpret
records committed to an older profile hash.

The profile retains the complete original Native Attribution document set,
original dependency bytes, canonicalization identifiers and explicit predecessor
edges. The new profile does not add typed entity continuation to the V1 assertion
wire. The generator prepares prospective documents; it does not register them.

## Exact original authority and chronology

`NativeArtistReviewSource` requires the concrete `ArtistAttestationSource`.
The unchanged native reader authenticates every Artist backlink in the supplied
complete Metadata collection: original receipt and record hashes, signed
publication candidate, op24 Archive identity and bytes, submitting actor,
historical signer, original delegation terms and use, original binding generation,
identity registration, nonce and publication consumption.

The sequence is the original op24 event, its Archive event, the Metadata
publication and consumption. Review eligibility additionally requires the
review's Metadata publication to follow the original assertion's publication.
Claimed `createdAt`, signed time, current identity and current binding cannot
replace those original block, transaction and log positions.

The new review body commits to:

- The complete original Metadata assertion selector, revision hash, profile
  hash, mapping rule and disposition.
- Chain, Core, collection, Artist registry and Metadata host.
- Original Artist ID, signer, authority class, binding hash and generation,
  attestation hash, op24 evidence ID and byte hash, actor and grant hash.

The source retains the complete native witness and current observations
separately. A relayer's account does not replace the signer. Later rotation,
revocation, expiry or dispute does not rewrite the original signature or grant.
None of this grants present signing permission.

## Selection boundary

The public `select_artist_reviews` entry accepts a concrete source and an
externally pinned policy. The policy commits to the source snapshot, exact
interpretation profile hash, source assertion selectors and reviewer assertion
selectors. It also declares single-valued relations and SELF-review opt-in.
Source and reviewer sets are disjoint; a review-envelope assertion cannot also
be selected as an ordinary source claim.

Same original Artist identity **or** same historical signing account is labelled
SELF, including a signer rotation within one Artist identity. SELF requires
explicit policy opt-in. A distinct Artist and signer can provide selected
account-level review; requesting proof of independent human review fails.

Direct statements do not need review. Mappings require a selected eligible
approval. A selected eligible rejection withholds that mapping, including when
an approval is also selected; recency does not pick a winner. Disputed or
withdrawn review revisions do not count as approvals. A reviewer cannot veto an
otherwise selected direct statement.

All native originals are authenticated. Unsupported or invalid semantic records
remain in the source with diagnostics. Review bodies are interpreted only when
their exact selectors are selected as reviewers. An unselected malformed body,
forged target or forged revision cannot veto a selected claim. Selecting an
invalid review fails rather than treating it as approval. A recorder-supplied
backlink never replaces the reviewer's own original statement.

Conflicting selected values remain explicit. Identical entity text in different
native subjects does not merge those subjects into one conflict or identity.

## APIs and verification

```python
profile = NativeArtistReviewProfile(expected_hash=profile_hash)
source = NativeArtistReviewSource(artist_source, transport, profile=profile)
snapshot = source.snapshot()
body = review_body(source, exact_assertion_selector, "reviewed")
literal = review_literal(body)  # unsigned content; no publication or authority grant
result = select_artist_reviews(source, selection_bytes, selection_hash)
```

```powershell
.\.venv-museum\Scripts\python.exe -m tools.museum.native_artist_review_profile --check
.\.venv-museum\Scripts\python.exe -m unittest tools.museum.test_native_artist_review_profile tools.museum.test_native_artist_review_selection tools.museum.test_native_artist_review_publication tools.museum.test_native_artist_review_source
```

The focused source fixtures are explicitly synthetic RPC histories. They
construct full native-shaped records and original op24 evidence and exercise
the unchanged raw reader before interpretation and selection. Offline replay
checks exact transcripts without network access. These tests do not demonstrate
contract execution, a public-chain deployment, institutional acceptance or the
latest whole-stack readiness.

# Artist C2PA reconciliation

This implements a finite AA-C2PA and CMC-C2PA profile. It preserves original
operation 24 and separates Artist credential declarations, a selected verifier's
report, and current attribution consistency. It does not implement a C2PA
cryptographic engine or establish the quality of a trust anchor, a human identity,
or an external media host. Unsupported crypto, identity or credential profiles
produce `unevaluated`; a supplied `valid` string is not protocol authority.

## Original Artist credential publication

Use the original `recordAttestation` operation, subject kind 10 and schema
`keccak256("6529STREAM_ARTIST_C2PA_CREDENTIALS_V1")`. The statement is canonical
`abi.encode(StreamArtistC2PATypes.Payload)`, version 1. It binds the artist,
operative identity-document hash and previous credential record. Up to 48
credentials are sorted strictly by `keccak256(abi.encode(Credential))`.
Kind 1 is a SHA-256 SPKI fingerprint; kind 2 is a SHA-256 DER certificate
fingerprint. Other nonzero kinds are retained as opaque declarations. Validity
is start-inclusive and end-exclusive; end zero has no declared upper bound.
An empty list explicitly withdraws the enumeration and never falls back to an
older nonempty list.

The original signer, class, nonce, digest, record hash, owner commit, event and
atomic Archive update remain in force. A companion event records the complete
new head after the original attestation event. Credential records cannot satisfy
the personhood floor, and do not erase a previously recorded personhood
attestation. The original generic subject-10 last-record read remains available;
the personhood requirement now uses its separate retained head.

The fixed Attribution owner implements `IStreamArtistC2PAReads`:

* `c2paCredentialHead(artistId)` returns the latest declared credential head.
* `c2paCredentialRecord(recordHash)` returns an immutable historical head.
* `personhoodAttestation(collectionId, artistId)` returns the original personhood
  record, with a compatible fallback for older histories without the new index.

Resolve that owner from the actual Artist Coordinator's suite and authenticate
its reciprocal Core, Registry and Coordinator bindings and runtime. These are
owner reads; no convenience forwards or new interface advertisement were added
to the Registry. No new Artist authority operation is introduced.

The existing complete readiness/publication hydration profiles reconstruct these
indices from every original ordered op24 receipt, compare each credential head
with its source and check the final credential/personhood heads. Their original
receipt, revision, nonce and replay inventories remain required. This extends
those existing profiles only: it does not admit new multi-collection, rotation,
estate, delegated or collaborator-policy history permutations. A descriptor that
omits a new credential receipt cannot pass the original complete receipt count
and hash inventory. Original source domains remain historical after import.

## Offline report preparation

`tools.artist.c2pa_reconciliation` provides `credential_statement` and
`build_report`. It reuses the repository's canonical JSON and strict ABI codecs.
Supply actual identity, media, selected-verifier observation and trust-anchor
bytes; context supplied to this tool is not authenticated chain evidence.

The supported identity document retains the required
`6529STREAM_ARTIST_IDENTITY_V1` fields, including `payoutAccounts`. It declares
`extensions.c2paReconciliationProfile` as
`6529STREAM_ARTIST_C2PA_KEY_HISTORY_JSON_V1`. Its `publicKeyHistory` rows contain
exact `keyId`, `spkiSha256`, `validFrom`, `validUntil` fields. Its
`c2paCredentials` rows contain `kind`, `fingerprint`, `keyId`, `validFrom`,
`validUntil`. Integers in those JSON inputs are decimal strings. All fingerprints
and identifiers use full `0x` hexadecimal values; duplicate key IDs or credentials
are rejected. This is an explicit interpretation of the extensible identity
document, not an assertion that other identity shapes lack authorship.

The canonical observation profile is
`6529STREAM_C2PA_VALIDATOR_OBSERVATION_V1`. It records manifest, claim and claim
signature hashes; media hard-binding hash; signer and SPKI fingerprints; key ID
and signed time; validation status and authorship assertion; validator identity,
software, trust-anchor hash and crypto/trust profile. The implemented trust
profile is `SELECTED_VERIFIER_ARCHIVED_TRUST_V1`. That name expresses which
verifier's statement is being consumed; it is not independent proof that the
verifier ran correctly. A different profile remains unevaluated. Certificate
matching requires both the declared certificate and its selected verifier's SPKI
key match. Original identity and credential validity windows are both checked.

`build_report(context, identity_bytes, statement_or_none, observation_bytes,
trust_anchor_bytes, media_bytes)` returns the typed report and canonical
`abi.encode(Report)` bytes. Use no statement when the authenticated current
credential head is zero; otherwise supply its exact original statement, even
when it is empty. The media bytes must match the selected manifest commitment.
A claim's hard binding to different media makes validation invalid. A lack of
enumeration or unsupported key/trust shape is unevaluated, not consistent.

## Selected-verifier receipt and adoption

Deploy `StreamC2PAReconciliation` with explicit Core, original Metadata record
host, Artist Registry, Metadata Router, verifier recorder and canonical gas
governance authority. It pins those runtimes plus the original Store and Artist
Coordinator/Identity/Binding/Attribution owners. Its raisable
`C2PA_DEPENDENCY_READ_GAS` row governs bounded source reads with full-cap parent
gas checks. Constructor and serving source selection must use the actual graph.

Register the exact schema document at
`schemas/records/6529STREAM_C2PA_RECONCILIATION_REPORT_V1.json`; its definition
hash is `0x9c896dc177954cc145f240cbcd4097a3b953b0121360c7f2acef053bc17e68cb`.
Use the original Metadata `C2PA_VALIDATION` record type and C2PA family, with
`RAW_BYTES` canonicalization and an exact typed report payload. The original
receipt must name the constructor-selected recorder and authorization class 4
or 6. Class 8 is deliberately insufficient, even for the same account. It is not
an Artist op24 authorization and cannot change the Artist signer or identity.

Retain the exact normalized validation report and contemporaneous trust-anchor
bytes in the original Store (each at most 8192 bytes for this profile). The
report binds their hashes, the actual selected media manifest/slot/hash,
operative identity document, key-history hash, credential enumeration and
original credential head. The verifier owns interpretation of its observation;
adoption independently checks current chain, source/runtime, original receipt,
payload, recorder head, Artist binding/generation/identity/head, declared
credential matching, selected media and retained report/anchor bytes.

Anyone can call `adopt(collection, subject, record, previousSelection,
expectedRevision)` with those verifiable facts. It appends a typed immutable
selection and, for divergent authorship, a divergence event. It does not add
authority. Supersession is explicit and monotone; an already selected record
cannot be selected again. `selectionAt` retains each historical result.

`display` rechecks current recorder head, graph runtimes, selected Core pointers,
Artist binding/generation/operative identity/credential head and selected media
manifest. Any unavailable or changed source makes both statuses unevaluated,
while preserving historical record/selection identifiers. A successor Artist
or Metadata deployment requires an explicitly configured new companion; this
companion does not silently follow replacement authority. Validation and
authorship consistency are separate enum fields. Consistent means reconciliation
under this explicit selected-verifier profile, not universal cryptographic or
human-authorship truth.

## Optional STATIC rendering

The original attribution companion and its old renderer output remain unchanged
when the new capability is absent. To opt in, deploy
`StreamStaticC2PAAttributionCompanion` with the exact original attribution
companion and reconciliation companion. Their Core, Router and Artist must
agree. The wrapper pins both runtimes and has the original governed-gas
mechanics for `C2PA_STATIC_ARTIST_GAS` and `C2PA_STATIC_REPORT_GAS`.

Its additive capability is `IStreamStaticC2PAAttribution.attributionWithC2PA`:
original attribution bytes, six-word typed `Display`, and the exact subject.
A token report takes precedence, including a stale token report; collection
fallback occurs only when no token report exists. The Renderer detects the
optional interface once at construction, retains source pins, then validates
the complete bounded ABI response, including offsets, enums, booleans, padding
and trailing bytes. The new JSON fields are generated only from those typed
facts. No report text or URI is inserted as JSON, and no report can replace the
original Artist attribution object.

The fixed Encoding worker's `Prepared` tuple is extended, so its linked
`render` selector and runtime change. Deploy and register the new Renderer and
Encoding together with their exact new read-roster entries. Existing Renderer
instances keep their original immutable Encoding address; this is not an
in-place code replacement. The public original Renderer ABI and source methods
remain available.

Fields are siblings under `properties.provenance`: `c2pa_validation_status`,
`c2pa_authorship_status`, `c2pa_attribution_divergence` (null when unevaluated),
`c2pa_basis`, `c2pa_report_current`, `c2pa_read_unavailable`, `c2pa_record` and
`c2pa_subject`. Absent evidence adds no fields. A failed optional read produces
an explicit unavailable/unevaluated display. C2PA never changes executable HTML.

The admitted renderer read roster must explicitly include the new wrapper,
reconciliation companion and their runtimes/selectors, the unchanged original
attribution companion's full transitive roster, current Core pointer reads,
Artist `staticDisplayRead` with its original owner roster, the direct Attribution
credential head, Metadata `latestCollectionRecordHashFor`, and Router
`staticRenderSource`. Constructor pins are not a substitute for the transitive
analysis report or actual golden-vector admission. Adoption's historical receipt,
Store and payload reads are not on the STATIC serving path. Parent/callee GGP
budgets must be calibrated through the actual composed route; merely increasing
a fixture budget is not transaction-cap acceptance.

## Evidence boundary and remaining work

The offline tests exercise exact report preparation and refusal semantics.
Authored Solidity tests use genuine Artist/Archive/Safe and Metadata/Schema/Store
where stated, with explicit inherited Core/governance/Router boundaries; report
observations are synthetic. Separate tests cover typed STATIC transport, malformed
responses, frozen old-encoding byte parity and current optional fields. They do
not claim an external validator, genuine complete current graph, public trust
service, full archival evidence dossier or universal hydration coverage.

At base `8d1672ac`, Attribution was already over the runtime limit (29,556 bytes).
This feature retains that separately held repair boundary; new heads add further
code. Registry forwarding was removed so its original source/ABI/storage remain
exact. Final selected sizes and source/type results belong to the handoff, and
full Artist runtime acceptance remains blocked until the existing owning size
repair is integrated. Original transaction gas and deployment limits are not
relaxed by this feature.

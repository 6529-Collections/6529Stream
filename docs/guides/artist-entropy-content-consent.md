# Artist consent for entropy recovery

The additive `IStreamArtistContentHostEvidence` returns the original op17 content
consent record for an explicit host. `recordContentConsent` retains its original
Consent tuple, EIP-712 domain, nonce, signature, authority checks and Archive
recipe. `metadataContract` in that tuple is the actual content host address.

The only new host admission is the exact current Core `ENTROPY_COORDINATOR`
pointer, its pinned runtime and matching `core()`, for the family
`keccak256("6529STREAM_ENTROPY_RECOVERY_V1")`. The host must return a canonical
64-byte `(supported, currentStateHash)` from `artistContentFamilyState`, and a
nonzero current commitment even before its first recovery. New host reads have
exact lengths and use the original finite Artist read gas parameter. A failed,
malformed, unsupported or zero-state host cannot authorize a consent. The
original metadata-only reads remain metadata-only; op21 freeze admission is
unchanged.

The entropy host must independently construct the requested `newStateHash` from
the exact token or scope, original request/commitment and intended resulting
recovery state and policy. It calls
`contentConsentEvidenceForHost(collectionId, address(this), familyId, newStateHash)`
against the selected Artist, checks all of its own incident/governance/source
conditions and consumes the returned record once atomically with the recovery.
The Artist reader verifies the current accepted binding and exact stored terms;
it does not interpret an opaque target hash, execute recovery or consume it.

Unavailability remains a separate integration seam. The current
`StreamArtistRecoveryAdmission.intent` selects `ARTWORK_FINALITY_RECOVERY`, binds
the immutable original Finality registry, and requires the original nonzero
Finality record and recovery manifest through `IStreamArtistRecoveryIntent`.
An entropy incident cannot be relabeled as a Finality record. An explicit typed
entropy recovery-intent adapter and canonical target evidence are still needed
before entropy can use that fallback.

The authored tests exercise actual Artist/Safe/owners/Archive with typed Core
and entropy host boundaries. They cover original independent digest/record and
Archive bytes, token-versus-scope consent separation, pointer/runtime/core drift,
malformed and failed reads, retained metadata/freeze boundaries, current binding
generation, changed signed target and late Archive rollback with byte-identical
Safe retry. They are ABI/typechecked source; no native execution, product size,
actual entropy recovery or joined current-stack acceptance is claimed here.

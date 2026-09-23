# Current conservation evidence for finality

`StreamFinalityConservationReads` joins the actual conservation selector to its
original Metadata receipts. It supplies current input facts for the separate
finality provider; it does not establish finality readiness.

## Fixed inputs and API

A consuming contract fixes `Dependencies` at construction: Core, generic
Metadata, SchemaRegistry, document store and conservation selector, their five
runtime hashes, chain ID, a positive ordinary read budget and a separate
current-selection budget. The selector can be a predicted late deployment, but
no operative read succeeds before its actual code and every reciprocal binding
match. The linked library does not make a caller-provided graph authoritative;
production hosts must never forward user-selected dependency values.

`requireCurrent(dependencies, scope)` returns the fixed 64-word
`StreamFinalityConservationEvidence`. `requireLocked` additionally requires the
exact current original-artist intent lock. Both validate the full canonical
scope shape and derive its subject without collection-to-token inheritance.
Actual scope membership and complete finality scope enumeration remain separate.

The reader accepts only the selected `ARTIST_INTENT` origin. Exactly one of
`intentRecordHash` and `intentWaiverRecordHash` is nonzero. Missing heads,
estate-only heads and unsupported implicit absence fail. Estate additions remain
readable through their own selector lineage; they are never a fallback for an
artist-signed intent or intent waiver. An interview retains its own original
authority class and author, including an estate-authored interview explicitly
referenced by an original artist parent. This is attributed provenance, not an
inference about participants, historical statements or the truth of the content.

## Original evidence and current eligibility

The reader requires the exact 50-word selected tuple and independently recomputes
its original selector commitment. A bounded call to the selector's
`requireCurrent` must return exactly the same bytes. That existing selector
rechecks the current selected graph, accepted/sanctioned association, nine full
registered definition documents and every complete selected format catalog.
The consumer does not replace those checks with an untrusted readiness flag.

For the parent and each PRESENT interview, the reader rejoins the actual
nine-word Metadata receipt, receipt hash, original lane index/hash and consumed
op24 authorization backlink. It preserves the original publication signer,
class, capability, association and saved complete publication evidence hash.
The original full generic record hash, payload serialization and original
artist operation were authenticated by the pinned selector at adoption; this
reader does not replay signatures or reconstruct the old generic URI tuple.
Current key rotation does not rewrite or reauthorize the original author.

This is a **current eligibility** API. Definition retirement, changed source
code or a changed association may block a new read. They do not erase saved
selection history or prior finality evidence. Historical finalized inputs must
use their retained evidence, rather than rerun this current API.

## Interview status commitment

`interviewEvidenceHash` uses one of these distinct versioned domains:

- `keccak256("6529STREAM_FINALITY_PRESENT_INTERVIEW_V1")`
- `keccak256("6529STREAM_FINALITY_WAIVED_INTERVIEW_V1")`

Its exact preimage is `abi.encode(domain, chainId, targets, scope, scopeSubject,
selected, INTERVIEW_SCHEMA_ID, INTERVIEW_PROFILE_HASH)`, using the complete
retained Selection including its selection hash. `targets` is the ordered
five-address array above. `selected` binds the complete parent record/payload,
artist association, status, original interview evidence, full ABI Reference
hash, correspondence class and complete catalog commitment.

For PRESENT, the selected interview must be an actual authenticated interview
original under the exact supported schema/profile. Local JCS Keccak-256 or
SHA-256 correspondence remains distinguished from `UNVERIFIED_REFERENCE` for
other algorithms or canonicalizations. All six reference algorithms remain
supported; resolving the original interview does not verify an opaque external
digest, URI availability or archive delivery.

For WAIVED, every actual-interview field, the ABI Reference hash and the
correspondence class must be canonical zero. The nonzero status commitment
binds the **full authenticated parent payload**, which contains the mandatory
explicit interview-waiver Reference. It does not invent an interview record,
extract a standalone waiver Reference/subobject hash or assert archival proof.
Intent waiver and interview waiver are independent tagged declarations. An
intent waiver can also reference a PRESENT interview.

`archiveRequirement` is always
`DUAL_FAMILY_REFERENCES_AND_SIGNATURE_BUNDLES`. The subsequent archival consumer
must establish complete referenced payload and signature-bundle coverage,
including exact waiver statements, named intent references, actual interviews,
transcripts/captures, participant/instrument references and format dependencies.
Known local digest correspondence does not discharge this requirement. No
`bundleCoverageHash`, archive receipt or finality-ready Boolean is manufactured.

## Locks and remaining policy

An unlocked result has an entirely empty `IntentLock`. A locked result must
match the exact selected head/revision/artist/identity/binding, with the original
locker and lock time. The status commitment remains stable when that independent
lock is added; the returned lock evidence is separate and must be committed by
the aggregate provider's policy. Core configuration freeze is not an intent lock.

`requireCurrent` intentionally reports unlocked facts. Authentic lifetime
predecessor chains can be materialized after succession without pretending that
new estate statements are lifetime artist intent. The aggregate must enforce
its explicit lock/exception and sanction rules before using these inputs for
new finality. `requireLocked` offers the narrower lock requirement without
claiming that it resolves all exceptions, archives or other finality inputs.

The full ten-input provider, actual current Core/artist/registry composition,
all scope branches and complete archival/finality acceptance remain separate.

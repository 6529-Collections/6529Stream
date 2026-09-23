# General-attestation semantic reviews

`STREAM_MUSEUM_GENERAL_SEMANTIC_REVIEW_PROFILE_V1` is a prospective,
separately named interpretation profile. It makes authenticated General-to-General
reviews usable by a concrete source and a deterministic graph selection policy.
The existing General semantic V1 profile, schemas, direct-only selection and
packages are unchanged. This batch implements part of
[MSM-ASSERTIONS](museum-semantic-mapping.md); it does not claim complete Museum
conformance or on-chain registration.

## Native authority and publication

`GeneralSemanticSourceV2` accepts one concrete `GeneralAttestationSourceV2`, its
exact `GeneralPublicationAdapterV1`, and a bounded definition reader. The native
source reconstructs all four original lanes, complete payloads, nonces, retained
signature preimages, native hashes, heads and supersession before interpretation.
Unsupported records remain in the original sidecar.

Institutional and estate statements retain their historical signed recorder and
attester. A curatorial statement instead retains its actual operator, separate
from its unsigned attester and DID labels. The adapter requires a successful
Metadata receipt containing the exact enabled `MetadataFamilyWriterChanged`
event for that recorder, collection, CURATOR family, class 3 and saved grant
revision. That event must precede the General publication. The immutable General
receipt authenticates that revision's use at recording; a later revocation stays
visible and does not rewrite the historical statement. No current grant lookup
substitutes for this evidence.

Publication hints contain all original General record hashes and transaction
hashes plus one grant transaction hint per original curatorial record. Hints
are locators, not authority. The adapter verifies the full
`GeneralAttestationRecorded` event against the native record and receipt,
canonical host pins, successful receipts, transaction inclusion, exact log
coordinates, and parent-linked headers back from the pinned anchor. It rejects
missing or duplicate publications, removed logs, inconsistent log ranges and
unmatched events in declared complete lanes. Review and documentary ordering
uses `(blockNumber, transactionIndex, logIndex)`. Equal timestamps or a claimed
`createdAt` never establish ordering. A grant and publication, or assertion and
review, may be in one transaction only when their actual log positions prove
strict order.

This is the existing caller-admitted trusted-RPC model, with strict transcript
replay. It does not provide a receipt-trie proof, consensus verification or a
new execution of historical signatures. Synthetic fixtures remain labelled
synthetic; a synthetic transport cannot construct a trusted source.

## Separate General review wire

The new assertion schema is `STREAM_GENERAL_SEMANTIC_ASSERTION_V1`; its profile
schema is `STREAM_MUSEUM_GENERAL_SEMANTIC_REVIEW_SCHEMA_V1`. General selectors
retain chain, host, family, subject, recorder, verification class, authority
qualification, schema/hash, canonicalization, original index/chain and field
pointer. They never use Metadata authorization-class labels.

`STREAM_GENERAL_SEMANTIC_REVIEW_BODY_V1` uses the adopted
`urn:6529stream:semantic-review:v1` relation and
`urn:6529stream:datatype:semantic-review:v1` datatype. Its canonical body binds:

- The complete original General assertion selector and exact assertion hash.
- The original interpretation profile and mapping rule.
- The historical principal, collection, subject, family, General authority
  classes and grant revision.
- A `reviewed` or `rejected` disposition.

The enclosing later direct statement supplies the authenticated reviewer and
claimed review time, and identifies the original assertion as its subject. Its
own record selector is excluded from its body. An optional later backlink must
resolve to that exact published review; names and payload status cannot replace
it. The source checks every claimed supported envelope, assertion, review and
backlink. Writer-supplied malformed JSON/envelopes or invalid shared
entity/documentary context remain original record diagnostics. Within a valid
envelope, each malformed assertion, asserting principal, review or backlink is
isolated to its exact selector; valid sibling assertions remain usable. Invalid
semantics cannot be selected. It cannot block unrelated valid selected claims; ineligibility
propagates to reviews or backlinks that depend on it. Native receipt, header,
signature-preimage and registered-definition tampering still rejects capture.
The review and target must share the same original native subject tuple; a token
B publication cannot approve token A or collection scope. A backlink must follow
its review in that same native scope. Disputed and withdrawn originals remain
visible.
All registered interpretation documents must match exact profile commitments;
generic General receipts keep their original zero profile-definition field.

This first cohort admits only General documentary sources and General review
targets. General-to-Artist, Artist-to-General, Metadata, independent and other
cross-family review composition remain explicit subsequent work. Existing Artist
review and qualified-account profiles are separate. `own_signed_statement`,
external retrieval and document-page/media-time evidence remain unsupported in
this profile; exact earlier General bytes and resolving JSON Pointers are used.
No old profile or source family is silently upgraded.

## Selection and replay

`general_review_selection.select` requires the concrete new source and an
externally hashed policy naming its exact snapshot. Each selected source and
reviewer entry binds the full selector and independently derived historical
principal/family/scope. It selects eligible direct statements and mappings with
an admitted positive review. Disputed or withdrawn originals stay withheld;
disputed or withdrawn reviews cannot qualify. A selected rejecting review
withholds its exact target. Unselected reviews cannot veto a selected claim.
Conflicting selected single-valued claims are all withheld without recency
preference. Author self-review needs explicit policy opt-in and is labelled as
author confirmation. Different admitted accounts never prove independent humans.

`build(source, policy_bytes, policy_hash, disclosure="public")` returns a scoped
replayable graph bundle: complete source and definition transcripts, anchor,
publication hints/receipts/headers, original native/semantic snapshots, policy,
selected/withheld claims, original profile and graph/provenance bytes. Each
selected original assertion becomes an occurrence-qualified LinguisticObject;
its exact original content and every graph field's source, mapping, authority
and reviews are retained. The model validator runs before output.
`replay(files, policy_hash, provenance=..., disclosure="public")` reconstructs
all three concrete readers and compares every bundle byte. This scoped bundle
is not a full object-dossier or archival package conformance claim.

## Focused verification

```powershell
python -B -m unittest tools.museum.test_general_semantic_review -v
python -B -m tools.museum.general_review_profile_v1 --check
```

The tests exercise concrete validators using synthetic RPC responses: signed
estate/institution and curator authority, exact grant/event mutations, same-block
and same-transaction ordering, exact revision/profile/scope, impersonation,
self-review, rejection, withdrawal, conflicts, selection pins, definition
substitution, offline graph replay and preserved originals. They do not claim
actual chain publication or deployed-signature execution. Existing General and
publication cohorts are run separately as regression evidence.

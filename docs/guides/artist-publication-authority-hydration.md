# Importing detached Artist publication history

`IStreamArtistPublicationAuthorityHydration.hydrateArtistAuthorityWithPublications`
selects `6529STREAM_ARTIST_LIVING_PUBLICATION_HYDRATION_V1`, an explicit
operation-60 profile. Its request is the existing readiness request: complete
economics inputs and every original attestation's terms and nonce in Attribution
native receipt order. At least one kind-7/8 publication record is required.
The earlier baseline, payout, economics and readiness selectors keep their
existing scope. In particular, the readiness selector still rejects kinds 7/8.

The complete living generation-1 profile retains original operations 1, 2, 14,
15, 17, 18, 24, 52 and optional authorization revocations 54, with the original
operation-55 binding, two verified lanes and completed predecessor cutover 57.
All seven fixed owner headers, native journals, revision counts, nonce prefixes,
replay origins and cells remain mandatory. Operation 60 retains mask `0x7f` and
its one atomic Archive boundary. No authority is enabled by partial row import.

For every attestation, the source export and target import reconstruct the
original predecessor-domain record from exact signed terms, nonce, signer,
class and signed time. Original statement bytes, signatures, association and
latest subject heads remain available. The publication rows additionally retain
the complete `IStreamArtistRecordPublicationOwner.Record`: original Publication,
nine-word Evidence and captured Metadata runtime hash. The worker independently
decodes the exact 416-byte version-1 statement and joins the collection, subject,
payload commitment, URI, candidate hash, binding, signer/class, required
capability, signed time and publication hash. Kind 7 keeps its original intent
capability 64; kind 8 keeps capability 1. A present authenticated association
must name that same host and runtime. An exactly empty association is accepted
for the original direct publication callback that predates association storage;
its full publication evidence is still required. Unknown class, delegation,
missing evidence, foreign binding or mismatched original terms fail.

The Coordinator independently compares every retained row and complete
publication record with the selected fixed source owner. It reuses the entire
readiness dependency check, including current source heads and policy, payout,
economics, ratification and content guards. Source owner checkpoints are checked
again after destination writes. Original statements and signatures enter the
same permanent payload catalog only after the atomic operation succeeds.

Hydration retains historical evidence. It neither replaces Metadata's canonical
record/payload store nor copies or resets its `consumedArtistAuthorization` map.
The external payload remains at the original Metadata/byte owner; the Artist
statement commits those bytes but is not itself the external publication payload.
Already published records retain their original receipt and authority provenance.
The original host's consumed guard continues to reject a second publication.

An unused imported approval must still pass `requireRecordPublication` against
the current binding, principal/class/capability, selected Metadata runtime and
actual candidate. A historical runtime hash does not bypass current selection.
A fresh successor attestation uses the successor's existing signing domain and
nonce guards; an original-domain signature does not become a fresh successor
signature. The separate Metadata successor-selection bridge must also verify
complete seven-owner hydration before calling the selected Artist facade.
This profile does not grant Metadata authority through a lane proof alone.

Seven authored cases in `StreamArtistPublicationAuthorityHydration.t.sol` use
actual source/successor Artist suites, Archive contracts and Safe cryptography.
They cover both publication kinds and replaced heads, fresh successor signing,
strict old selector and omissions, independent original-evidence reads, altered
binding/capability/runtime facts, current host changes, and late Archive rollback
with byte-identical Safe retry. One case performs original publication through
the actual Metadata/Schema/byte contracts and checks the original payload,
receipt and consumed guard after hydration. Fresh current publication validation
uses the explicit candidate-host unit boundary; genuine post-cutover Metadata
publication through its separate bridge remains integration work. Core and
governance are typed unit boundaries. Original hydration test files are unchanged.

This batch has ABI/type validation only. Native execution, composed read-gas,
deployment sizes and maximum complete-profile capacity await the integrator's
consolidated validation. The existing inline Archive preflight remains absolute;
an oversized complete profile fails before mutation. Collaborator, delegated,
corrected, transitioned and repeated-import histories remain separate full-v1
profiles. No recovery or freeze eligibility changes are included.

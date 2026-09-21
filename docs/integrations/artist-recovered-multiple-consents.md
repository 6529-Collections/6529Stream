# Recovered multiple-Artist consent history

This developing operation-60 composition preserves complete original consent and
delegation histories across multiple recovered Artists and collections. It uses
the existing `hydrateRecoveredArtistAuthority` request. Sources with royalty
freeze records use the existing `hydrateRecoveredArtistAuthorityWithConsents`
entry and provide every original royalty-freeze term in global owner-6 journal
order. No signature or new authorization is required for hydration.

## Supported graph

The distinct feature bit is **524288** (`MULTIPLE_CONSENTS`), with canonical tag
`6529STREAM_ARTIST_RECOVERED_MULTIPLE_CONSENTS_V1` and version 1. The allowed
feature mask is **524671**: the original recovered class/history bits 1–16,
economics 32, delegation 64, content consent 256 and this profile bit. The seven
owners advertise combined supported capabilities **1048575**. The previous
singleton codecs, `MULTIPLE_BASE` bit 262144 and its tag remain separate.

The complete selected graph contains recovered class-1/class-3 Artists and
accepted generation-one PRIMARY_ONLY collections, with original consent mode 1
or 2. It carries direct or delegated policy 14, economics 15, sale 16 and royalty
freeze 20; content consent 17 and content freeze 21 retain their original
undelegated authority rules. Original Identity grant 26 and revocation 27 records
are retained, including unused, replaced, revoked and earlier-epoch versions.
Supported recovery, guardian, timing, payout and Identity sanction-grant histories
remain governed by the original recovered Identity/Payout validators.

Additional generations, corrections, ratifications, disputes, collection sanction
history, Platform histories, operation-24 attestations and collaborator/class-4
graphs reject this profile. Aggregate support for those families is subsequent
work. The distinct tag never turns an omitted family into an empty history.

## Complete request and original evidence

Every Artist and collection must appear exactly once in canonical selector
order. Per-collection policy selectors cover every original policy scope. Query
record arrays keep their original ordering and multiplicity. Every owner header,
replay inventory, nonce tree, provenance era and publication catalog remains
complete; validators receive the original global provenance and coordinates.

Economics witnesses are grouped by collection in selector order, and each
collection's terms follow its original operation-15 occurrence order. Only
collections with economics records have a witness row. Attestation witness
arrays must be empty. Royalties are provided in the full owner-6 operation-20
order and partitioned internally without changing the provenance certificate.
Original source associations, record hashes, signer classes, signature bytes and
Registry domains are carried unchanged. Hydration does not re-sign old terms,
re-authorize old grants, or infer fields absent from original records.

Grant usage is checked once per original Artist and grant version after counting
every matching policy, economics, sale and royalty occurrence across all selected
collections. A source slice cannot reset the count. The kind-2 nonce lane retains
the original `6529STREAM_ARTIST_DELEGATE_NONCE_LANE_V1` domain and Artist/delegate
key. Used nonce bits must equal all retained versions' total uses for that lane.
The complete per-Artist inventories form a disjoint union of the original global
nonce inventory, preserving order, prefixes, all 32 tree words, exhaustion and
the original hints. Reusing one delegate across Artists does not merge lanes.

All bundles agree on the one global registration nonce and timing state. Active
authority addresses remain unique. Shared original record/document bytes may
repeat when their authentic occurrences do; record hashes are not globally
deduplicated into fabricated provenance.

## Atomic owner application

One complete source admission supplies every fixed typed stage. Collection
validation, global grant conservation, complete source heads and inventory checks
finish before owner imports. Each owner applies the whole aggregate once and
commits once under its original admission and snapshot guards. Identity installs
the global nonce inventory, timing and registration state once, then activates
the verified Artist and collection lanes once. The original Archive and payload
catalog tail remains in the same transaction. A late failure rolls back all
principal, consent, delegation, replay and activation state.

The Coordinator and its Request ABI are unchanged. New work executes in fixed
linked libraries. The original observation merge is shared by both aggregate
profiles, with the same read order and explicit returned arrays. Memory context
packing changes internal call frames only; no mutable delegate target, raw user
decoder, synthetic owner checkpoint or relaxed singleton guard is introduced.

## Validation boundary

Seven actual-owner scenarios and six focused nonce cases are authored and
type-checked. They cover complete direct/delegated families, a shared grant across
collections, mixed recovered classes and threshold Safe execution, original
signatures, revoked/exhausted and unused grants, stale headers, repeated imports,
global nonce separation and late Archive rollback. The focused nonce trees are
explicit synthetic byte-preservation fixtures; they do not claim source
admission or importer acceptance.

Native EVM execution, extra linked-call gas, the final joined deployment-capacity
check and current-stack acceptance remain pending. Source/ABI checks and selected
native product captures are distinct evidence. This profile does not establish
full-v1 completion, audit or deployment readiness.

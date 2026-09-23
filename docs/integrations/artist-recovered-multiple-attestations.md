# Recovered multiple-Artist attestation composition

This developing operation-60 profile joins complete original operation-24
attestations to recovered consent and delegation histories across multiple Artists
and collections. It uses the existing recovered Request. When original royalty
freeze records exist, the existing `hydrateRecoveredArtistAuthorityWithConsents`
entry receives their complete original term sequence.

## Tagged scope

The feature bit is **1048576** (`MULTIPLE_ATTESTATIONS`), with tag
`6529STREAM_ARTIST_RECOVERED_MULTIPLE_ATTESTATIONS_V1` and version 1. The allowed
mask is **1049087**: recovered class/history bits 1–16, economics 32, delegation
64, attestations 128, content consent 256 and this profile bit. All seven owners
advertise the combined known mask **2097151**. The new tag requires actual op24
history and both its own feature bit and bit 128; it does not set either older
aggregate profile bit. Existing singleton, base and consent tags remain strict.

The complete graph contains recovered class-1/class-3 Artists and accepted
generation-one PRIMARY_ONLY collections with original consent mode 1 or 2.
Original attestation kinds 1–10 join complete policy14, economics15, sale16,
content17, royalty20 and content-freeze21 histories. Retained delegation26 and
revocation27 records include every unused, replaced, revoked and earlier-epoch
version. Original17/21 remain undelegated. Existing complete Identity, Payout,
guardian, recovery, timing and Identity sanction-grant validators remain in force.

Corrections, further generations, ratifications, disputes, collection sanction
history, Platform history and collaborator/class-4 graphs are outside this tag.
They are rejected rather than represented by empty projected histories.

## Whole-owner carrier and witnesses

Every Artist and collection appears once in canonical selector order. Every
owner retains its complete original provenance, journal coordinates, aliases,
nonce inventory and publication catalog. Admission keeps complete per-Artist and per-collection record queries. A fixed
typed projection copies that scope and replaces only owner4 collection record
arrays with the complete op24 occurrences in original global journal order.
Source validation, attestation facts and the owner4 semantic envelope use that
projection. Consent validation, all other owner envelopes and the cross-owner
anchor keep the original queries; no owner provenance or original clock is
filtered. Copies from calldata prevent returned nested arrays from aliasing the
admission certificate. Authentic repeated Identity records and shared documentary
bytes are not globally deduplicated.

The semantic envelope is
`abi.encode(tag, uint16(1), uint8(owner), M.State, bytes auxiliary)`.
`M.State.rows` contains canonical complete Identity/Payout rows per Artist or
collection rows per collection; the collaborator row array is empty. Owner4 rows
are the original `StreamArtistRecoveredAttestationHydration.Bundle` encoding.
Only owner4 has nonempty auxiliary data: canonical
`abi.encode(StreamArtistRecoveredMultipleAttestationClocks.Inventory)`, containing
one complete original Archive catalogue and selected original operation envelopes.
Every other owner's auxiliary bytes must be empty. The entire envelope remains
covered by the original semantic inventory and guarded owner header.

Collection witnesses appear only for collections with economics15 or op24
history, in collection selector order. Each witness contains every original
economics term and attestation term/nonce in that collection's original occurrence
order. Royalty20 terms retain the full owner6 journal order. Collectors obtain
original records, signer classes, associations, statements, publication carriers
and personhood summaries directly from the authenticated source owners.

## Original clocks and global conservation

An owner0 proposal revision is never treated as an owner4 revision. The clock
worker reuses the complete original Archive catalogue and canonical operation1/2
payload decoders. It authenticates each proposal/acceptance's actual owner4
transition preimage and original snapshot limits, joins the source-phase envelopes
to the full owner0/owner3 native occurrences, and retains their exact owner4
points. Every collection must have exactly one proposal and acceptance in the
same original era. The two non-native commits plus all original op24 points cover
the complete owner4 revision count without overlap. Each attestation must follow
its own collection's acceptance using the same-owner chronology.

The saved catalogue is checked again at the owner4 import boundary against the
original Archive, metadata, immutable payload bytes and original cutoffs. It is
not an invented proposal order, filtered provenance or current reauthorization.

Consent and attestation workers return increments per authentic Artist and
retained grant version. One equality compares their sum with each original
version's use count after every selected collection is included. Global delegate
nonce popcounts still equal all-version use totals, and the exact original
Artist/delegate domain, ordered inventory, every tree word, exhaustion and hints
remain intact. Shared registration nonce and timing are compared globally and
installed once.

C2PA predecessors are joined per Artist in the complete owner4 journal order,
including interleaved collections and original Registry eras. Every saved
credential record and final Artist head is compared to the real source getter.
Personhood remains a separate per-collection head, with original summaries and
Registry provenance. Latest subject maps and publication carriers retain their
original values; documentary transport grants no new publication permission.

## Atomic import and validation status

Preparation performs one complete source admission, full owner4 source/clock
validation, source-head comparisons and global grant conservation before any
owner import. Fixed typed libraries retain the original guarded host entry,
storage roots, one whole-owner apply/commit and final Archive sequence. Owner4
checks all collection, record, subject, statement, summary and credential target
cells before writes, then replays its documentary maps in global journal order.
Identity installs shared nonce/timing/registration state and activates every
selected lane once. A late failure rolls back all owners and heads atomically.

Ten actual-owner composition cases are authored and type-checked. They cover
shared cross-family grants, direct and class-3 Safe calls, independent personhood
and C2PA heads, global use refusal, stale complete headers and witnesses, original
Archive clock refusal, late rollback and repeated import with a fresh successor
credential. Independent Artists retain their original delegation lanes when the
same delegate consumes the same numeric nonce. Direct assertions and rollback
readback cover every original delegated op24 nonce, including new bits 4/5. A
projection regression preserves complete admission records, original op24 order,
policies and anchor while rejecting duplicate or unselected occurrences. The
source-head refusal uses an explicit getter override only in its
negative test. Core and scheduled governance retain the original typed fixture
boundaries; successful paths use real owners, Registry, Coordinator and Archive.

The separately developed pure attestation facts worker has its own 14 executed
cases and 256 fuzz inputs at its recorded source. That evidence does not execute
this new full composition. Actual composition execution, linked-call gas,
joined-current capacity and deployment acceptance remain pending. No full-v1,
audit or release-readiness claim follows from these source and type checks.

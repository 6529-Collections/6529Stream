# Importing original living-Artist payout history

`IStreamArtistPayoutAuthorityHydration.hydrateArtistAuthorityWithPayout(Request)`
selects the explicit `6529STREAM_ARTIST_LIVING_PAYOUT_HYDRATION_V1` profile of
operation 60. Its request fields, seven-owner mask, source seal, source runtime
checks, lane latches, complete guard inventory and atomic Archive composition
are the [baseline hydration contract](artist-authority-hydration.md). The
original `hydrateArtistAuthority` selector stays strict: it rejects a source
with payout history.

The extension admits original operation-18 records in addition to the baseline
registration, acceptance, policies and revocations. It still requires one
original living class-1/status-1 Artist, one accepted generation-1 collection,
no collaborators, unchanged timing configuration and no previous import or
authority transition. The source Payout owner's complete native receipt list
must be a nonempty linear chain from zero to its actual current head. Every
record must name this Artist, a nonzero changed payout account and the exact
previous record. Every provisional association and abandonment reference must
be empty, and no pending candidate may exist.

The importer independently joins exported records to their actual receipt
positions, original `designationRecord` reads and `payoutCandidates` state.
The one mutable `designation_chain` replay cell must have kind 3/status 1 and
commit the same current head. The original record hashes and retained signature
bytes are copied unchanged; the fixed source producer supplies historical
admission. This does not reconstruct a missing historical signature or recover
an unretained signing tuple from its record hash.

The successor stores all designation terms and the exact current account/head.
The complete Identity nonce/digest/revocation inventory remains mandatory, and
the source's original mutable cell remains available by source key. A later
successor payout update must pass the original current-principal signature,
nonce, time, changed-account and exact previous-designation checks. It receives
a new successor-domain record hash while keeping the imported source record as
its immutable parent. No signing-address payout fallback is added.

The four authored `StreamArtistPayoutAuthorityHydration.t.sol` cases use actual
two-registry/seven-owner/Safe/Archive graphs with typed Core and governance.
They cover full linear history and a fresh Safe update, strict baseline refusal,
stale mutable-header refusal, inconsistent export and provisional-association
refusal, plus all-owner rollback and byte-identical Safe retry after a late
Archive failure. The seven original baseline cases are retained unchanged.
ABI/type checks pass. Native execution, bytecode sizes, whole-call capacity and
actual current-stack cutover remain pending consolidated validation.

Rotated, pending, abandoned or otherwise provisional payout histories require
their complete authority-transition profiles. Multi-Artist, repeated imports,
collaborator, economics/content and other historical families remain full-v1
implementation obligations. Neither a lane proof nor this limited profile
grants authority for them.

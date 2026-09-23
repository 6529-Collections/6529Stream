# Recovered signed dispute and repudiation histories

This additive operation-60 profile retains original attribution-dispute and
repudiation history for one recovered living Artist and one accepted collection,
across original and imported owner eras. The current attribution can be accepted,
openly disputed, or revoked. It does not turn those states into fresh authority.

## Capability and codec

All seven owner headers require `DISPUTE_HISTORY` (8192). No new facade selector,
operation number, signing domain, native receipt shape, or owner storage field is
introduced. The request remains `hydrateRecoveredArtistAuthority(RH.Request)`.
The additional canonical version-1 tags are:

- `6529STREAM_ARTIST_RECOVERED_DISPUTE_BINDINGS_V1` for owner 0.
- `6529STREAM_ARTIST_RECOVERED_DISPUTE_ACCEPTANCES_V1` for owner 3.
- `6529STREAM_ARTIST_RECOVERED_DISPUTE_HISTORY_V1` for owner 4.
- `6529STREAM_ARTIST_RECOVERED_DISPUTE_CONSENTS_V1` for owner 6.

The complete journals and original global allocator select the profile; caller
lists cannot select a history subset. Existing supported profiles keep their old
tags and tuple encodings. A complete original governed-revocation/correction path
still selects the earlier accepted-generation profile when it fits that profile.

## Retained evidence

Original 44/45/61 records retain full Standing, signer, class, nonce, original
environment and signatures. Their original Identity authorization commits have
zero native record. Resolution 46 retains its original governance action, exact
opening/counter/evidence, previous resolution, minimum class and replay cells;
it also has no fabricated native receipt. Withdrawals copy the original opening
outcome without deleting the counter chain or reopening it.

Original 47 records retain the original authority head, guardian set, window,
nonce and signed bytes. Pending, vetoed, cancelled, executed and invalidated
terminal states remain distinct. Original 48 imports exactly the existing
adjacent Identity Contest and Cause pair. Automatic invalidation shares its
original opening/stage mutation; it creates neither a receipt nor a revision.
Pending cohort counts and latest heads are checked against the actual source.

Complete previous accepted generations retain their original 1/2 records and
fresh class-2 correction approval. Executed-repudiation and arbiter-resolution
causes are joined to their full retained original records, rather than to a
current status or replacement approval.

A never-accepted pending generation revoked by original class-2 resolution also
retains its exact single Binding proposal mutation. No acceptance, refusal or
withdrawal is synthesized for it; the next correction binds that exact cause.

Required 14/15/16 history is included across those generations. Original economics
witnesses remain ordered and exhaustive; each saved association keeps its actual
binding generation and hash. Original policy records do not store a generation,
deadline or signer preimage: the fixed owner's immutable record and original
grant association are retained without inventing missing fields. Every delegation
use is reconciled across base consent and signed dispute records. Revoked,
exhausted and replaced grants remain historical, not newly live authority.

## Import and refusal boundaries

The original owner checks precede the new fixed workers. Full source journals,
nonce inventories, original consumed digests, replay aliases in every later era,
and all seven headers are checked before semantic import. The existing final
source reread, seven owner commits, original operation-60 Archive payload and
transaction rollback remain in place. The Identity point importer adds only
the original 48 Contest/Cause occurrence to its existing typed path.

The already integrated canonical import pipeline validates the complete original
source decoder before its fixed stages. It retains the original order: principal,
records, authority including Estate, recovery, continuations, nonces, timing,
heads and artifact points. The existing capacity repair and its Records component
tests remain intact; this batch only admits the original operation-48 artifact
point. No caller selects a phase or target. The exporter uses the separately
preserved typed stages, adding only the paired operation-48 rows.
Consent validation runs in a fixed pure worker;
the original typed consent-map import writes are unchanged.

This batch does not compose Platform declarations, native attestation 24,
confirmation 13/state 3, content/freeze/ratification journals or broader
multi-Artist/collection history.
Those histories fail before writes and remain required follow-up compositions.
It does not change the existing 24,575-byte carrier limit, governed gas caps or
deployment limits.

## Evidence scope

Twenty-three new authored actual-owner/Safe cases cover original signed/direct records,
live and revoked state, terminals and automatic invalidation, paired 48 evidence,
historical grants, generation corrections, prior-era consents, repeated imports,
source drift, malformed inventory and late Archive failure with two counted
attempts of the identical Safe envelope. The original supported codec has a
separate literal-byte preservation oracle. Three successor-domain write cases
exercise imported consumed nonces and separately revoked or exhausted grants,
check exact original refusal and unchanged owner/nonce/Archive state, and then
exercise fresh principal authorization or an independently recorded replacement grant.

The fixture uses actual Artist owners, Store, Archive and Safe. Core, governance
execution, module/sale facts and documentary coverage remain named typed fixture
boundaries. Source/ABI and selected product measurements do not establish native
execution, cold gas capacity, maximum carrier capacity or full-current acceptance.
Those conclusions require separately frozen execution evidence.

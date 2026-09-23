# Recovered Artist ratification histories

This operation-60 profile retains original operation-52 content ratifications
alongside a supported recovered Artist's complete consent and authority history.
It closes the ratification gap in a seven-owner migration after living recovery.
It does not create new ratification authority, change the original operation-52
signature domain, or claim complete support for every recovery or binding history.

The normative record obligation is [AA-CONTENT requirement 6](../stream-artist-authority.md),
including append-only ratifications and the latest operative record. The older
direct-living readiness profile in [ADR 0047](../adr/0047-complete-artist-authority-hydration.md)
remains separate and unchanged.

## Capability and wire format

Call the existing `hydrateRecoveredArtistAuthority(RH.Request)`, or the existing
`hydrateRecoveredArtistAuthorityWithConsents(RH.Request, RoyaltyFreeze[])` when
original operation-20 witnesses are present. There is no new Registry selector,
Request field, signature, nonce, or public record getter.

Every destination owner advertises `RATIFICATIONS = 1024`; the known feature mask
is `2047`. Existing named feature aggregates retain their earlier values. A
complete source Consent journal containing operation 52 selects this profile and
sets bit 1024 in all seven sealed headers. A caller cannot select a subset or
force the profile by supplying a flag. Content bit 256 is present only for actual
17/20/21 occurrences, generation bit 512 only for a later generation, and the
existing delegation bit is selected from original mode/grant/sale facts.

The owner-6 semantic bytes are the canonical Solidity encoding:

```solidity
abi.encode(
    keccak256("6529STREAM_ARTIST_RECOVERED_RATIFICATION_CONSENTS_V1"),
    uint16(1),
    uint64(bindingGeneration),
    uint8(consentMode),
    Bundle(originalContentConsentBundle, orderedRatificationRecords)
)
```

The embedded `StreamArtistRecoveredContentConsentHydration.Bundle` is unchanged.
Each `RatificationRecord` is the original three-field tuple: `recordHash`,
`contentStateHash`, and `metadataContract`. Generation and mode are authenticated
against the actual current Binding and the complete supported generation history.
This is a distinct codec; older bare, base-only, content, generation and delegated
encodings remain unchanged when no operation 52 is present.

## Complete source and import joins

The fixed preparation workers authenticate all original seven-owner provenance,
then read each 52 record from the original Consent owner's `ratificationRecord`.
The ordered array must match every operation-52 occurrence in that owner's full
journal exactly, with no missing, duplicate, reordered or foreign records. The
actual `firstReleaseRatification` must equal the last complete row. An original
52 record cannot claim a delegation association in this supported producer profile.

The new validator counts 52 together with all original 14/15/16/17/20/21 rows. It
checks the same per-era revision equation, replay counts, ultimate environment
coordinates and replay aliases. Its ratification replay surface is the original
`consent_finality.replay.ratification_key`, scoped by
`keccak256(abi.encode(collectionId, recordHash))`.

Original 52 has no Identity native receipt and does not retain a separate
signer/nonce/timestamp preimage in `RatificationRecord`. The importer does not
invent one or reauthorize historical bytes against a current principal. It uses
the authenticated original record maps/journal and complete Identity source,
nonce and replay inventory, requiring exactly one saved signature row for every
ratification. An empty signature from the actual direct Safe producer is still
an explicit retained row. Original historical grant-use reconciliation for
14/16/20/24 remains complete; operation 52 consumes no grant in this profile.

The original fixed Consent owner performs its ordinary operation-60 guards, then
imports the original base/content rows in their prior order. The additive fixed
worker prechecks both existing ratification mappings, writes every original
historical row, and rebuilds the current head in journal order. No new storage
slot or independent writer is introduced. The original all-seven-owner commit,
late source reread, original Archive pages and transaction rollback remain.

Repeated A-to-B-to-C imports keep original hashes, signatures, replay cells and
environment coordinates. Fresh B or C ratifications use that successor's actual
original signing domain. Import never authorizes a fresh use of an old signature.

## Validation and remaining scope

Ten authored tests use actual Artist owners, original op52, living recovery,
threshold Safe execution and seven-owner operation60. They cover direct mode1 without invented grant/content capabilities, two distinct
mode2 ratifications, repeated imports, capability/source drift, malformed inventories,
current-head and false-delegation refusal, missing/duplicate signature rows,
old-domain refusal with same-nonce retry, and counted late Archive failure followed
by the identical Safe retry. Core, governance scheduling, sale facts and Metadata
content remain explicit inherited typed boundaries. This is not a full-current
native or deployment acceptance claim.

The source/type and selected-product size results are recorded in the handoff.
A fixed read-only consent-selection worker retains the original branch and call
order while reducing the preparation library; all imports remain in their owners.
Native execution, cold gas and maximum evidence-carrier capacity remain separate.
The supported scope is one Artist/collection with the existing complete recovered
Identity profile, modes 1/2 and supported historical generations. Newly governed
post-revocation correction histories, accepted/corrected Platform generations,
multiple recovered Artists/collections, and other unsupported journals still
require their own complete joins. Historical pending-generation encodings remain
readable; that does not authorize bypassing the newer governed proposal ingress.

The new entropy configuration family is explicitly refused until its dependency
joins are implemented. Held collaborator changes and other pending profiles are
not enabled by the new bit. The original Metadata ratification/evolution state,
one-use content authorizations and mint-readiness checks remain independent;
copying Artist records does not replace them or automatically approve a successor
deployment.

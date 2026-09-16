# Importing original direct economics approvals

`IStreamArtistEconomicsAuthorityHydration.hydrateArtistAuthorityWithEconomics`
takes a request containing the original operation-60 `authority` request and
an `economics` array of original `EconomicsConsent` payloads. This selects
`6529STREAM_ARTIST_LIVING_ECONOMICS_HYDRATION_V1`. The baseline and payout-only
selectors remain strict and do not silently select this profile.

The profile includes the complete [living payout history](artist-payout-authority-hydration.md)
and its [baseline authority](artist-authority-hydration.md). It admits original
direct operation-15 records alongside operation-14 policy records. Policies and
economics records may interleave in the original Consent owner's journal; each
supplied selector list follows its own original receipt order. The full journal,
exact owner revisions, all replay entries, Identity nonce hierarchy and both
sealed predecessor lane tips remain mandatory. A missing, repeated or foreign
selector cannot substitute for another receipt.

The fixed Consent export reads each original payload lookup, record association,
association lookup and delegation marker. Each economics record must belong to
the same accepted generation-1 binding, with an empty delegation marker and an
association whose original record is itself. The coordinator independently joins
those typed values to the actual op15 receipt, original lookup, binding-specific
lookup and association read. Its original consent-key cell must contain that
record with the producer's exact kind 1/status 2. The resolver must be one of the
unchanged, pinned primary or royalty providers in both suites.

The importer stores original records and associations under their original
payload keys. It retains signature bytes in Identity under the original record
hashes and carries nonce, digest-revocation and replay guards. It does not change
Resolver assignments, sign an approval, or treat the imported signature as a
successor-domain authorization. Source owner admission remains the historical
authority evidence; this profile does not invent a signing tuple or independently
reconstruct a record preimage whose full tuple was not retained in these maps.

After hydration, the original facade's binding-specific economics read finds the
old approval. A different binding generation does not. A fresh nonce cannot
approve the same consumed payload again; a genuinely new assignment approval
still uses the original current/prerequisite checks, Safe authority, digest,
record and Archive recipes. Original payout checks remain applicable to any
current or prospective economics operation.

The economics state uses a distinct tagged encoder in a fixed worker. Existing
baseline policy-state bytes and old public selectors are unchanged. All seven
owner commits and the normal operation-60 Archive append remain atomic. Original
Archive capacity is checked before mutation; this is not a paged-import or
unbounded-history capacity claim.

Four authored `StreamArtistEconomicsAuthorityHydration.t.sol` cases use real
Registry/Coordinator/seven-owner/Safe/Archive graphs with typed Core/governance.
They cover both original Resolver approvals, interleaved policy history, exact
associations/signatures, duplicate refusal followed by a fresh Safe approval,
missing/duplicate selections, altered source associations/lookups, and complete
rollback with byte-identical Safe retry after a late Archive failure. The seven
baseline and four payout cases remain unchanged. ABI/type checks pass; native
execution, linked sizes, complete call capacity and actual current-Core cutover
remain pending consolidated validation.

Corrected bindings, delegates, collaborators, provisional payout histories,
authority transitions and repeated-import generations require complete additional
profiles. Content, attestation and other retained historical families also remain
full-v1 obligations. A lane proof or a partial economics export does not activate
them.

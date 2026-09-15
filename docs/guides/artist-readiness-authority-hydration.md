# Importing collection content and attestation readiness

`IStreamArtistReadinessAuthorityHydration.hydrateArtistAuthorityWithReadiness`
selects `6529STREAM_ARTIST_LIVING_READINESS_HYDRATION_V1`, an explicit operation-60
profile. Its request includes the [economics profile request](artist-economics-authority-hydration.md)
and every original direct attestation's signed terms and nonce, ordered by the
Attribution owner's native receipt index. Existing baseline, payout and economics
selectors remain strict.

This profile includes complete original living authority, policy, payout and
economics dependencies plus original operation 52 ratifications, operation 17
content consents and operation 24 attestations. Ratification is operation 52;
operation 16 remains the unrelated original sale-consent recipe. The seven-owner
mask and original operations 1–59 are unchanged. At least one ratification and
one attestation are required; content-consent history may be empty.

The fixed Content worker exports every actual ratification and content-consent
record from the source journal. It checks the current ratification and every
final content key against the actual source heads. Import preserves all records,
including replaced heads, and rebuilds the original latest maps in original
receipt order. The coordinator independently joins the original typed getters,
receipt positions and consumed replay cells. The original metadata/content host
keeps its own mutation-consumption state; hydration does not reset or import a
second copy of that state.

The fixed Attestation worker admits direct class-1 records for kinds 1–6, 9 and
10 at the same accepted generation-1 binding. Every supplied term and nonce is
checked by reconstructing the original predecessor-domain record hash from the
stored signer, class and signed time. This binds the subject selector and exact
statement URI, rather than guessing them from a current head. Callers can obtain
those original inputs from retained operation evidence; incomplete or different
inputs fail. Stored statements, signature bytes, signing class, historical owner
facts and binding associations remain exact. Unknown signing class does not
default to living Artist. A missing legacy association is accepted only for the
original kinds 9/10 callbacks that did not carry one. Generic subject records
require their full originally admitted association.

The worker carries all immutable records, reconstructs latest subject heads by
receipt order, and retains statement bytes in the original payload catalog.
It checks source head reads after reconstruction. Historical owner facts remain
historical; the importer does not pretend that a past provider runtime or subject
hash is current. Detached publication attestations of kinds 7/8 are excluded:
their predecessor-registry publication admission needs a separate consumer
bridge. Collaborator, delegated, corrected and transitioned authority histories
also remain explicit additional completeness profiles.

An old deployment attestation approves the old registry's deployment hash. It
must not approve the successor deployment. Import preserves that historical
record; the original successor `requireMintConsent` continues to reject it. A
fresh original op24 Safe approval of the actual successor deployment is required.
Personhood, policy, economics and ratification reads then use their carried
records and original current-state checks. Content mutation still uses the
unchanged host-aware consent API and the host's own one-use guard.

Six authored `StreamArtistReadinessAuthorityHydration.t.sol` cases exercise actual
source/successor Registry, Coordinator, seven-owner, Safe and Archive contracts.
Core, governance and content-host application remain explicitly typed unit
boundaries. The source pair uses a fresh actual source suite with a short lawful
identity URI; the shared fixture's maximum-URI stress profile is unchanged. Cases
cover fresh deployment approval followed by the full facade mint read, replaced
ratification/content heads and the original consumed host guard, an actual generic
economics subject, incomplete/forged original inputs, unknown class or changed
source bytes/heads, and late Archive rollback with byte-identical Safe retry.
Original statement/signature payload catalog entries become visible only after
the successful atomic operation. The fifteen prior authored hydration cases are
unchanged.

ABI/type validation is available for this source batch. Native execution, linked
runtime/deployment sizes, actual current-Core cutover, and maximum-size capacity
remain pending consolidated validation. The original finite Archive preflight
still rejects an oversized complete profile before any mutation; no chunked or
unbounded hydration capacity is claimed. Statements and authority are not
activated piecemeal to work around that limit.

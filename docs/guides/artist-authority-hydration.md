# Artist successor authority hydration

`IStreamArtistAuthorityHydration.hydrateArtistAuthority(Request)` is operation
60. The caller is permissionless; the imported facts are not. The predecessor
must be the exact governed operation-55 binding with unchanged runtime and
fixed suite. Complete operation 57 on that predecessor after Core selects the
successor, and permanently verify both complete lane tips with operation 56.
The [ADR](../adr/0047-complete-artist-authority-hydration.md) and
[matrix](../architecture/artist-operation60-authority-hydration.json) preserve
the original 55–57 boundaries.

Read all seven `authorityCheckpoint` values after the seal. For every
`authorityReplayAt` index, supply its original replay surface and scope
preimage in the same order; the importer independently derives the original
key and reads the actual cell. Supply policy phase/hash selectors in the
Consent owner's native receipt order. The importer reads every nonce prefix
directly from the fixed Identity owner. Do not derive a rolling update root
from current cells, omit consumed digests, or substitute a source envelope hash
for its canonical record.

The first profile supports one original living Artist and one accepted,
generation-1 collection with no collaborators, plus original policy consents
and authorization revocations. Its complete source receipt/revision checks
exclude any other history and changed Identity timing configuration. Both
suites use the same Core, Manager, roles, metadata, resolvers and validator.
The successor must have no native records or earlier hydration: exactly one
import binding and two tip verifications precede the operation. Bounds are
128 receipts per source owner, 512 replay cells per owner and 256 Identity
nonce prefixes. The complete encoded envelope must also fit the unchanged Archive carrier,
checked before mutation. These are profile limits, not measured whole-call capacity.

Success carries current identity/document, binding terms, acceptance,
attribution, policies, original signature bytes, activity counters and all
applicable nonce/revocation/replay guards into the actual fixed owners.
`authorityHydrationCommitment` on each owner identifies the common completed
profile. `importedAuthorityReplayCell` reads original source-key cells.
Historical signatures are available as historical bytes; successor writes
need a new signature in the original domain recipe using the successor
registry, or an actual authenticated direct Safe call. An old-domain signature
is never treated as freshly authorized. Exact revoked digest bytes remain
revoked; a newly signed different successor-domain digest is a different
authorization. Revoked nonces and already-used policy keys remain unavailable.

All owner activation, normal Archive append and payload catalog sync are
atomic. Retrying byte-identical Safe calldata after a reverted late append
does not reuse a successful operation. New native history extends the latched
prefix with the original accumulator; historical indices keep their original
source hashes. The predecessor's own terminal latch remains historical so it
does not prevent a later successor cutover.

The authored `StreamArtistAuthorityHydration.t.sol` scenarios use actual two
registries, Coordinators, all seven owners, Safes and Archives with typed unit
Core/governance boundaries. ABI/type checks are complete source evidence;
native execution, deployed product sizes and actual current-stack cutover
remain pending consolidated validation. Multi-identity, collaborator,
economics/content, historical authority and subsequent-import profiles remain
explicit full-v1 obligations. No lane proof alone activates them.

## Additional explicit profile

[Living-Artist payout history](artist-payout-authority-hydration.md) is available
through a separate additive entrypoint. The original baseline selector and
request ABI remain unchanged. This extension does not relax provisional or
historical-authority dependency requirements.

The [explicit direct economics profile](artist-economics-authority-hydration.md)
adds complete op15 associations and their payout dependencies while preserving
this baseline selector. It has separate source-only validation.

The [collection readiness profile](artist-readiness-authority-hydration.md)
adds complete original ratification/content and direct attestation histories;
old deployment approval remains historical and the successor needs a fresh op24.

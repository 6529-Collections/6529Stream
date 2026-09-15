# Artist display facts and permissionless attribution claims

`IStreamArtistDisplayFacts` is additive. Existing interface IDs, signed
attestation payloads, permanent record hashes and `T.AttestationRecord` ABI stay
unchanged. Metadata projections should authenticate the selected Artist facade
and this capability, then use its fixed-owner reads.

`displayBinding(collectionId)` returns the raw stored binding, including claimed,
disputed or revoked generations. It does not assert acceptance. Pair it with
the attribution state and display unaccepted proposed consent modes as unverified.
`artistAttestationStatus(collectionId, kind, subjectId, currentHash)` returns the
specified five values: status, record hash, attested hash, actual signing class
and signed time. The subject's current owning contract supplies `currentHash`;
this getter does not call it, search history or reconstruct a subject.

An absent record returns five zero values. Existing disputed attribution returns
status 3. Generation drift, a revoked/nonaccepted attribution state, or a changed
live subject hash returns stale 2; otherwise it returns current 1. Freeform kind8
does not compare a live hash, but binding-state/generation rules still apply.
Each lookup uses a fixed number of owner storage reads, including invalid/absent
subjects. A broken facade dependency is an infrastructure failure for the caller
to report as unavailable, not an absent attestation.

Both actual attestation producers persist the precise signing authority class
in an appended per-record mapping. No old record is rewritten. Older publication
records can expose their exact already-saved publication class; old records with
no saved class return 0, never an invented class 1. `attestationAuthorityClass`
provides the same historical distinction by record hash. A conformant renderer
must not label a nonzero unknown-class record as a living Artist approval.

`deploymentAttestation(collectionId)` supplies the latest kind9/Core-subject
record, class and signed time as a historical reference. It is not a content
attestation or a freshness assertion. For deployment status, call the five-value
getter with kind9, `bytes32(uint256(uint160(core)))`, and the actual canonical
deployment facts from the binding/Core/chain. Revocation makes that record stale
even if a caller supplies its former hash.

## Supported attestation writers

The existing actual writers currently cover deployment9, operative identity10,
and the detached publication profiles7/8. Kind7 signs an explicitly supplied
nonzero publication subject and the exact candidate metadata record hash for
ARTIST_INTENT or ARTIST_INTENT_WAIVER. After publication the selected metadata
host's `latestCollectionRecordHashFor(collectionId, recordType, subjectId)` is
the matching live value. Kind8 publication families sign stateHash0 and have no
staleness comparison. Neither is a collection snapshot/content attestation.

Generic collection-snapshot1, script2, media3, finality4, phase-policy5 and
economics6 writers remain missing. The current ordinary writers support actual
living and activated estate authorities; steward/delegated submission remains
separate work. These reads grant none of those missing write capabilities.
The renderer must use NONE for absent actual records and unavailable for a
missing owning read, rather than invent a current subject hash.

## Attribution claims

`IStreamArtistAttributionClaims.fileAttributionClaim` implements original
operation10 with the original caller recorded. Any existing collection can
receive a claim, regardless of attribution/consent/Platform state. No Artist
signature, current acceptance, incumbent cooperation or arbiter standing is
required. The permissionless record grants none of those authorities and does
not change mint eligibility or the attribution state. Counts describe allegations,
not their truth. The total and latest display read includes original Platform
claims after correction. Both canonical record histories remain separate; both
actual producers update one combined latest pointer, including same-block order.
Original Platform-only histories remain readable before the additive pointer
exists. No timestamp sorting or rewriting of either old record domain occurs.

Evidence and reason use the same canonical 160-byte commitment-document profile
as Platform claims. Their wrappers name the collection, use a zero initial claim
reference, agree on a proposed author, and are actually stored by the selected
metadata byte store with current dual-family collection archival coverage.
`narrativeHash` remains an opaque commitment: narrative bytes, availability,
content and truth are not independently read or proved. This is not an anonymous
or unbacked state-changing dispute.

`attributionClaims` returns combined count/latest. `attributionClaimRecord`
returns the immutable op10 tuple, claimant, URI, proposed author and previous
record/index. A combined latest hash may instead name an original op9 record,
read through `platformWorksClaimRecord`; authenticate the returned hash and
collection rather than treating an absent op10 record as evidence loss.
The permanent record uses the original ATTRIBUTION_CLAIM_RECORD_DOMAIN. The same
claimant/evidence/reason tuple cannot replay by changing URI or waiting. Another
claimant can file the same evidence under their own identity. Original operation10
Archive evidence retains the exact stored/coverage facts and before/after owner
snapshots. A late Archive failure rolls back the count, record and replay key.

`displaySanction(scope)` forwards the existing current binding-associated sanction
reader. It retains exact scope/artist/generation/binding joins and returns the
complete saved record and signing class. It does not select the saved Platform
finality component or claim that the current source is finalized. The renderer
resolves applicable token/phase/collection scope precedence separately.

## Validation boundary

`StreamArtistDisplayFacts.t.sol` adds five source scenarios for actual living and
estate signatures, historical unknown-class and typed disputed/revoked read
controls, stale comparison, raw claimed binding, and identical signed rollback
retry, plus an actual stored sanction and class read.
`StreamArtistAttributionClaims.t.sol` adds four source scenarios using
actual accepted/refused Artist generations, current covered documents, original
record/Archive reconstruction, same-block combined claim ordering, permissionless
history, rejected actor-forged callbacks and atomic retry.

The existing fixtures use actual Artist, threshold Safe, Archive and preservation
contracts with typed Core/metadata-selection/governance boundaries. Disputed
state is an explicitly injected read control; no new actual arbitration producer
is claimed. These tests are ABI/type checked, not executed. Copy all inherited
JSON fixture inputs for the eventual consolidated run. Full linked product sizes,
native runtime, current renderer composition and transaction gas remain pending.

```powershell
python scripts/dev.py test --suite unit --match-path test/unit/artist/StreamArtistDisplayFacts.t.sol --via-ir --code-size-limit 2000000 --gas-limit 1000000000 --memory-limit 1073741824
python scripts/dev.py test --suite unit --match-path test/unit/artist/StreamArtistAttributionClaims.t.sol --via-ir --code-size-limit 2000000 --gas-limit 1000000000 --memory-limit 1073741824
```

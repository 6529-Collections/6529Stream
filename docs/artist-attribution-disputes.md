# Artist attribution disputes (operations 44–46 and 61)

This implementation supplies the original OPEN, COUNTER_STATEMENT and governed
resolution recipes from [AA-DISPUTE](stream-artist-authority.md#disputed-and-revoked-attribution-aa-dispute).
It preserves operations 1–60 and the original signature, record and replay domains.
Source and authored regression coverage are available; native execution, changed
product sizes, and a current Core/Executor integration run remain separate gates.

## Caller surface

Use the additive `IStreamArtistAttributionDisputes` ERC-165 capability. The facade
keeps all original interface IDs. It exposes:

```solidity
openAttributionDispute(Filing filing, Standing standing, Authorization authorization)
recordCounterStatement(Filing filing, Standing standing, Authorization authorization)
resolveAttributionDispute(ResolutionRequest request)
```

The first two return the original nonzero `DISPUTE_RECORD_DOMAIN` hash. Resolution
returns the actual governance action ID; it creates no invented signed dispute
record. `attributionDispute(collectionId, generation)` selects the opening,
latest counter-statement and latest resolution. `attributionDisputeRecord(hash)`
and `attributionDisputeResolution(actionId)` return immutable full records.
`attributionDisputeDigest` uses the original `StreamArtistAttributionDispute`
payload and `6529StreamArtistRegistry` / `1` domain. The signer does not sign a
new transport-specific payload.

`Filing.disputeAction` is exactly 1 for operation 44 and exactly 3 for operation
45. Action 2 is accepted only by the additive operation-61
`IStreamArtistDisputeWithdrawal.withdrawAttributionDispute(Filing, Standing, Authorization)`
selector; OPEN continues to reject it. The immutable signed opener must still be
authorized in its original standing and current authority/delegation lane.
`attributionDisputeWithdrawal(openingRecordHash)` returns the immutable outcome
with the latest counterstatement and restored state. See the
[withdrawal recipe](adr/0050-attribution-dispute-withdrawal.md). Original operations 47–50
now have the separate [staged repudiation implementation](artist-attribution-repudiation.md),
with its own explicit source and validation scope.

A direct authority call uses an empty signature and the exact current Identity
nonce hint; direct delegate calls use the original delegate lane hint. Relayed
filings use the original EOA/ERC-1271 signature checker and a live nonzero
deadline. All successful non-arbiter filings consume the existing nonce,
revocation and delegated use guards. Failed coverage or late Archive admission
rolls those changes back with the entire transaction.

## Standing and defensive authority

An accepted or sanctioned generation admits its current bound authority, an
exact accepted collaborator identity, or the current authority of an earlier
accepted generation of this collection. `Standing` identifies the claimed
identity and generation; collaborator standing additionally identifies the exact
stored row index. The fixed Binding and Collaborator owners supply the original
binding/row/acceptance facts. A receipt alone supplies no standing.

Current bound-authority delegation additionally requires the original live grant,
scope, delegation epoch, nonce lane, deadline, remaining uses, revocation state,
and `CAP_DISPUTE = 16`. The supported delegation grant mask adds only that
canonical bit to the prior mask. Existing constraints remain in force; arbitrary
capabilities are not admitted. The immutable dispute record retains the grant
hash in `standing.delegation`. Use that typed association when reading disputes.

Counter-statements belong to the bound authority or its valid delegate. Accepted
collaborator standing to OPEN does not make that collaborator the primary artist's
spokesperson. Current binding creation admits PRIMARY_ONLY, so this counter
profile implements that policy and explicitly rejects non-primary policies.
ALL/THRESHOLD/QUORUM creation and policy evaluation remain full-scope work, as does
ARTIST_DELEGATED consent mode 2. The historical earlier-generation standing
reader is exact; this batch does not invent a missing corrective rebind producer.

Identity status `IDENTITY_CONTESTED` retains defensive OPEN and COUNTER rights.
A defensive filing never dismisses compromise or clears attribution's disputed
state. Existing appointed successor/steward capability checks remain required;
this batch introduces no authority-class transition. Successful authenticated
activity uses the existing unavailability/dormancy cancellation hooks.

## Evidence bytes

Each evidence and reason hash identifies a canonical 192-byte commitment document:

```solidity
Evidence(
    uint16 schemaVersion,       // 1
    uint256 collectionId,
    uint64 bindingGeneration,
    bytes32 bindingHash,
    bytes32 disputeRecordHash,
    bytes32 narrativeHash
)
```

The document is stored in the exact chunk store of the current Core-selected
`COLLECTION_METADATA` owner, with reciprocal Core and runtime checks. The
collection-scoped archival coverage owner proves the complete wrapper bytes under
its original independent-family coverage rules. This uses the collection subject,
not a fabricated Artist identity. Both evidence and reason hashes are nonzero;
each can refer to the same complete document.

The first OPEN document has a zero parent. A later opening names the previous
opening; a counter or resolution names the current opening. The wrapper and
nonzero narrative commitment must be exact. `narrativeHash` is an opaque
commitment: narrative bytes, availability, content and truth are not independently
read or proved. A newly wrapped claim is not an adjudication of truth.

## Governed outcomes and immutable history

`attributionDisputeOpeningContext` and `attributionDisputeResolutionContext`
return the exact scope, old-state hash, intended-state hash and required class.
A governed OPEN comes through the canonical Executor with an actual executed
class-1-or-2 action whose proposer has `ROLE_ATTRIBUTION_ARBITER`. Its record
class is 0 (governance recorder), not Artist class 1. Only that branch may open a
CLAIMED generation or reopen an ARBITER_REVOKED generation.

Ordinary UPHELD requires DELAYED class 1 or stricter. REVOKE and an UPHELD
reinstatement after arbiter revocation require TERMINAL_FREEZE class 2. The
original Executor remains responsible for actual scheduling, independent veto,
selector admission and timing. The role's appeal tier remains the original
staged-action cancellation mechanism; this contract supplies no cheaper route.
These rules implement ADR 0011 R7.7, ADR 0012 T4 and ADR 0013 U4/U5.

A resolution must name the actual latest counter-statement, or zero if none.
A new counter changes both old-state and intended-state commitments, invalidating
a previously staged resolution. UPHELD restores the saved pre-dispute state;
reopened UPHELD restores the original pre-revocation state. REVOKE sets state 5
and reason 4. Refused, withdrawn and repudiated generations cannot enter this
reopening branch. Every OPEN needs a previously unused evidence document hash
for the generation. All prior opening, counter and resolution records remain
readable after later opinions.

While disputed, existing accepted-state consumers deny mint consent and new
sanctions, policy/economics/sale/content consents, ratifications and attestations.
New collection-scoped delegation grants are also denied. Identity-global grants
retain their original independent scope; grants do not bypass a collection's
write admission. Operational mint-layer pause and executed finality are unchanged.

## Fixed ownership, reconstruction and validation scope

Binding, Identity and Attribution use the original semantic snapshot masks
44 = `0x15`, 45 = `0x17`, 46 = `0x11`. Operations 44/45 mutate Identity and
Attribution for signed filings; the arbiter branch only mutates Attribution.
Operation 46 only mutates Attribution. Archive remains the original atomic tail
outside the seven-owner mask. Original replay surface names are unchanged.

New dispute storage is a namespaced structure inside the actual fixed Attribution
owner. Ordinary owner storage layout is unchanged. All writes still pass the
pinned Coordinator/snapshot check and one semantic commit per participating owner.
Original events remain exact. An additive schema-1 context companion names the
chain, registry, binding, standing identity, original parent, grant and governance
action for independent reconstruction. Original record preimages and signature
bytes enter the existing permanent payload catalog; OPEN/COUNTER append typed
native receipts in their original owner lane. Resolution appends its original
operation Archive evidence and immutable action-keyed read without claiming a
new signed record hash.

Existing operation-60 profiles do not import dispute/withdrawal storage or its dependency
history. They must continue to reject those source receipts/revisions. Complete
dispute hydration is a remaining explicit profile, not inferred from lane proof.

The new test suite authors actual Artist/owners/threshold Safe/Archive and actual
dual-family coverage calls, including independent digest/record/event assertions,
accepted collaborator standing, delegate use/revocation/exhaustion, defensive
identity contest, staged-counter drift, class-2 revocation/reinstatement, authority
and nonce rejection, and exact Safe retry after missing coverage or late Archive
failure. Its Core, metadata-host getters, roles and governance action facts are
explicit unit boundaries. It does not claim actual current Executor delay/veto or
current-stack mint execution. Authored and ABI-clean is distinct from executed.

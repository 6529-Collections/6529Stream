# Recovered Artist authority hydration

## Implementation status

The developing operation-60 profile 10 adds the explicit
`hydrateRecoveredArtistAuthority(StreamArtistRecoveredHydrationTypes.Request)`
entry point. Its seven-owner masks remain `0x7f`. Existing hydration selectors
keep their existing profiles and exclusions.

This is a source implementation with ABI-only checks. The seven concrete owners
advertise feature mask 127 for these graphs; the base owner stays disabled. The positive
import scenarios are authored but have not run. Safe execution, current-stack
integration, bytecode size, gas, invariants and release acceptance remain pending.

The first graph is one recovered class-1 or class-3 Artist, one accepted
generation-one PRIMARY_ONLY collection, no collaborators, base Attribution,
and complete direct operation-14 policy history. An explicit economics extension
also carries complete direct operation-15 history for that same binding.
The delegation extension carries all original grant versions and revocations with
complete direct/delegated operations 14/15/16, and admits consent modes 1 and 2.
Complete Identity and Payout histories are transported together. Class 4,
multiple Artists or collections,
collaborator graphs, corrected generations and broader collection histories
remain separate full-v1 obligations. A capability bit does not bypass these
typed source restrictions.

| Feature bit | Required source state |
| --- | --- |
| 1 | Current or retained recovery class 1 |
| 2 | Current or retained recovery class 3 |
| 4 | Retained V2 preparation evidence |
| 8 | Retained V3 evidence or recovery continuations |
| 16 | More than one retained import era |
| 32 | Complete economics history, selected by actual native operation 15; delegated records also require bit 64 |
| 64 | Retained grants, consent mode 2 or native sale-consent operation 16; complete mixed consent history |

Every source and destination owner must support the combined required mask.
Pending requests, compromised status and unused preparations are included in
the typed graph; feature bits do not silently discard them.
These transport feature bits grant no Artist permissions. An original estate
authority capability mask, including a zero mask, remains unchanged.

## Request and source admission

`Request.records.authority` supplies the complete Artist and collection
selectors, expected source checkpoints and logical replay-key preimages. Without
economics history, `records.witnesses` must remain empty. A source with
operation-15 records requires exactly one witness for the selected collection,
containing all economics terms in original operation-15 order and no attestations.
Missing, extra, duplicate or reordered terms reject. Empty wrappers also reject.
The request also names every expected source capability, the exact prior import
commitment, and a nonzero expected semantic inventory.

The fixed Coordinator authenticates the current governed predecessor and its
seven-owner suite. The source must be sealed by its actual operation 57 naming
this destination. The destination must have its genuine operation 55 binding
and operation 56 verified lanes before hydration. A lane proof alone does not
install authority. The non-Artist dependencies must still match.

`StreamArtistRecoveredHydrationPrepared.prepare` constructs the read-only
certificate and performs the same source checks used by the mutation path.
`inventory` hashes its complete provenance, query, seven owner payloads, timing
checkpoint and external guard observations. The caller supplies this identifier
as `expectedSemanticInventory`. The mutation route uses `collect`, which
rejects a zero or changed identifier. This helper is a fixed Solidity library;
the Registry does not expose a separate preparation endpoint.

## Retained records and clocks

Historical record bodies, signatures, hashes and stored local revisions remain
unchanged. Each retained native occurrence carries its original environment,
owner index, admitted owner revision and original native index. Repeated
secondary operation 35 receipts retain distinct occurrences even when their
record hashes are equal. Preparations and execution operations 32/40 have
original mutation points, not synthetic native receipts.

Each destination stores a flat immutable prefix plus its own actual native
suffix. An A→B→C transport carries A's original coordinates and B's original
coordinates directly. Runtime readers compare authenticated era order before
comparing revisions within the same owner and era; they never compare A's raw
revision to B's raw revision. A copied record with a large old revision cannot
be treated as a new destination record merely because that number exceeds the
destination import revision.

An owner imports only its own typed state, provenance slice, nonce inventory
and publication catalog. The Coordinator performs the full seven-owner join,
including Payout's original Identity35 and nonce dependencies. Fixed typed
adapters authenticate auxiliary creation points from actual producer state.
Missing imported origin metadata is an error.

## Replay, nonces and retained dependencies

All indexed nonce kinds, keys, prefixes and words are carried. Current replay
cells are authenticated against the actual source checkpoint and their logical
surface/scope preimages. Rekeyed live cells retain their original mutation
point until an actual destination write updates them. Historical source 55 and
source 56 cells remain recorded. Genuine destination 56 latches retain their
local cells; source 57 stays historical so the destination can later seal its
own cutover.

Original document and signature carriers retain their SSTORE2 pointers and
bytes. The complete source catalogs are admitted before semantic imports;
the normal Coordinator payload synchronization registers them with the new
Archive. Full timing configuration and timing-action history are inventoried
separately from the original owner checkpoint.

Governance actions, finality recovery records and entropy observations remain
on their original pinned hosts. Their exact observations are bound into the
certificate and checked again after destination writes. Hydration does not
reset an external consumed guard or turn an old preparation into a current
execution authorization. New authorizations use the destination's existing
signer and governance domains; retained history is read under its original
producer domain.

## Direct economics composition

The economics extension requires capability bit 32 on every source and destination
owner. The complete original Consent-owner journal must contain only direct
operations 14 and 15. Economics terms are limited to the original fixed primary
or royalty resolver, generation 1 and the exact accepted Artist/binding pair.
Delegated economics additionally require the delegation extension below;
corrected-generation economics remain separate work.

The fixed source authenticates each economics record through its original payload
lookup, exact binding association, native occurrence and consumed replay cell.
All three economics maps survive import. The retained row does not contain the
signer, nonce, observed time or historical payout hash, so the importer does not
invent those fields or reconstruct the record from current facts. The complete
Identity export separately retains the original signature and nonce admissions;
the complete Payout export retains its own history. Their revisions are separate
owner clocks and are never equated.

Every old economics replay cell remains consumed in every later import era, with
its original admission point. Historical approvals remain recorded when current
payouts or assignments change. Import does not rerun mutable assignment checks.
Fresh operation 15 still checks the current principal, signature domain, payout
and assignment; class-3 authority still needs its original economics permission.

## Delegation and mixed consent composition

Actual grant history, consent mode 2 or operation 16 selects feature bit 64 on all
seven source and destination owners. The complete Consent journal must contain
only operations 14/15/16; the extension preserves every policy, economics and sale
record, its original grant association, and the latest sale lookup. An unused,
revoked, expired or old-epoch grant remains part of the complete Identity history.
Original grant versions, current heads, revocations, epochs, uses and all delegate
nonce words survive import. Economics witnesses retain the same complete ordered
request shape above. Policy selectors remain exact; sale selectors are derived
from the complete flattened native journal.

Each grant hash and grant authorization digest uses its original environment.
Revocation records retain their original native occurrence and one-way replay
cell; missing reason/time preimages are not invented. Delegate nonce lanes use
the original tagged nonce domain, which differs from the current-grant lookup
key. Every consumed delegate nonce bit must correspond to a recorded grant use,
and every use must be accounted for by the selected collection's consent history.
Unsupported delegated record families cannot be silently omitted.

The Coordinator joins grant scope and capability with each original consent.
Sale records retain a delegate nonce, so their authorization point is additionally
checked after grant creation and before revocation or replacement in Identity's
original chronology. Policy and economics rows lack these preimages: their exact
fixed-source association, original occurrence, replay state and complete use
counts authenticate history. Raw Identity and Consent revisions are never ordered
against each other. No historical approval is reauthorized using today's grant
status or principal.

Fresh grants and delegated actions retain the original class-1-only rule. A
class-3 import may retain earlier living grants and consents, but does not gain
permission to create or use a grant. Recovery's original delegation epoch still
invalidates older grants. An old-epoch grant can also reserve the same delegate
slot until it is genuinely revoked, expired or exhausted; hydration does not
change the original replacement rule. New signatures use the current Registry
domain. The old no-delegation/no-sale/mode-1 paths retain their existing encoding.

## Atomicity and transport bounds

Each original owner import commits exactly once at its actual revision + 1.
Hydration adds no original native record. The source provenance, publications,
timing and external guards are rechecked after all seven writes. The
Coordinator then appends paged evidence and the canonical operation 60 header,
followed by the existing history and payload synchronization. Any propagated
failure rolls back the entire transaction.

Transport is finite: at most 16 source eras, 4,096 total native occurrences,
8,192 replay aliases, 128 indexed nonce lanes per owner and 256 prefixes per
lane. Evidence uses at most 128 pages of 20,480 bytes. These bounds reject an
oversized new import; they do not cap future original writes or runtime reads
after a successful import. A destination may operate with the maximum imported
prefix plus its own additional current era.
The economics extension admits at most 128 complete operation-15 records and
128 direct policy selectors for the selected collection.
The mixed consent extension separately admits at most 128 policies, 128 economics
records and 128 sale records within the same complete transport bounds.

## Validation boundary

Authored cases cover provenance and replay guards, full nonce payloads,
publication preservation, separate timing, external observations and precise
auxiliary origins. The actual class-1 fixture uses the original seven owners,
Registry, Coordinator, Archive and Safe. It covers A→B→C, unchanged original
operation-35 evidence, fresh guardian writes, C operations 29/30/32, governed
C operation 33, current V2 preparation and recovery, stale source rejection,
and exact late Archive rollback/retry. Four additional class-3 cases retain
original activation40 and recovery35, preserve a zero estate capability mask and an
unused scheduled action, and author fresh successor rotation and recovery.
Two V3 cases transport the original mixed rewind plan across all six
non-guardian families and its guardian exclusion. They check complete retained
records, statuses, operative heads and continuations, stale Payout rejection
with identical retry, and fresh operations 25/18 consuming the original
continuations under genuine destination clocks. The source retirement remains
contested, so fresh operation 51 must retain its exact original rejection;
these cases do not establish a positive operation-51 flow.
Additional V3 scenarios transport class-3 authority with a fresh signed operation
25, and import A→B→C after B consumes A's revision and payout continuations. C keeps
those cells spent and authors ordinary current-chain writes after the original
recovery window matures.
Three economics cases author genuine mature recovery, signed payout and mixed
primary/policy/royalty consents before import. They cover A→B→C with a fresh
prospective economics consent in B, retained approvals under C's current domain,
exact replay rejection with nonce rollback, malformed witnesses, and a late
Archive failure followed by an identical Safe retry. Thirteen component cases
cover the economics codec, maps, complete journal, aliases, counters and old/new
feature dispatch; their typed coordinator and synthetic second-era cases do not
establish full-host authorization. A separate capability case rejects economics
imports on any owner advertising only the first-graph features.
Four delegated-consent cases use actual owners, Registry, Coordinator, Archive
and Safe. They retain mixed policy/economics/sale records, exhausted and revoked
grants, sparse spent delegate nonces and an old-epoch grant. They cover A→B→C,
fresh successor-domain writes, exact stale-domain rejection, malformed complete
witnesses, and late Archive/Safe rollback followed by an identical retry. Each
source snapshot freezes its own inventory before a successor appends records.
These cases establish no additional class-3 delegated or operation-54 runtime
coverage. Twelve Identity, nine cross-owner and sixteen Consent component cases
cover complete grants, origins, replay cells, nonce lanes, use reconciliation,
map preservation and malformed transport. Their synthetic era certificates and
typed coordinator do not establish original signer authorization or seven-owner
execution. Separate controls require feature64 on every owner and for mode-2
binding import.
Core and governance fixtures remain explicitly typed unit boundaries.

ABI-only compilation establishes source and type compatibility. It does not
establish that these transactions execute, fit deployment limits or meet the
protocol's gas and security acceptance criteria.

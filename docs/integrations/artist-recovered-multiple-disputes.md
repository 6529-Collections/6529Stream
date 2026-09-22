# Recovered dispute and repudiation multiplicity

This development profile imports supported original dispute and repudiation
histories across multiple recovered Artists or collections in one operation 60.
It extends the [generation composition](artist-recovered-multiple-generations.md)
and preserves the [singleton authority decision](../adr/0047-complete-artist-authority-hydration.md).
Authored tests and source/type checks are separate from runtime, gas, contract
capacity and release acceptance.

## Selection and compatibility

The feature is `MULTIPLE_DISPUTE_HISTORY = 16777216`, declared in
`StreamArtistExtendedHydrationFeatures`. The canonical owner envelope is:

```solidity
abi.encode(
    keccak256("6529STREAM_ARTIST_MULTIPLE_DISPUTE_HISTORY_V1"),
    uint16(1), ownerIndex, scope, auxiliary
)
```

`scope` has the existing `StreamArtistRecoveredMultipleTypes.State` shape.
The allowed feature mask is `16956415`. Every owner envelope requires the new
feature and the original `DISPUTE_HISTORY` family bit. Each concrete owner adds
only the implemented new feature to its existing advertisement. The shared
known-bit decoder does not grant support to an owner that has not advertised it.
Historical feature constants, tags, Request tuples, selectors and operation
numbers retain their existing meanings.

Preparation selects this profile when the complete original Attribution journal
contains signed44,45,47 or61, or a governed opening that the old generation
profile cannot represent. The old profile still handles its original governed
opening/revocation/correction scope. Unsupported combinations fail admission.

## Complete owner inventory

| Owner | Semantic rows | Auxiliary |
| --- | --- | --- |
| 0 Binding | Every original binding, terms, terminal and correction | Complete generation/Archive inventory |
| 1 Collaborator | Empty under this profile | Empty |
| 2 Identity | Complete original recovered Identity bundle for every Artist | Empty |
| 3 Acceptance | Every original accepted generation | Original generation matrix |
| 4 Attribution | Original dispute-history bundle and original attestation bundle per collection | Same complete generation/Archive inventory as owner0 |
| 5 Payout | Complete original Payout bundle per Artist | Empty |
| 6 Consent | Original generation-aware consent rows per collection | Empty |

Owner4 retains original44/45/61 records, immutable withdrawal outcomes,47 records,
48/49/50 terminal records,46 resolutions and all original heads. Original op24
records retain their full signatures, publication bodies, associations and
per-Artist C2PA order across collections. Historical signed authority is proved
from the original signature, nonce, grant and source inventories; it is not
re-authorized against today's principal or grant head.

The complete original provenance remains global. Collection projections never
renumber receipts or manufacture filtered owner provenance. Binding and
Attribution each prove their own original mutation coordinates. Non-native
resolution46 and terminal48/49/50 coordinates come from the retained replay
aliases and authentic Archive envelopes. They are never inferred as an opening
revision plus one. Complete original Archive catalogs and all seven cutoffs are
checked again after owner imports, including histories without op24.

Original accepted, refused and withdrawn generations can precede the final
accepted generation. An arbiter-revoked pending generation has no invented
acceptance or completion: its original resolution and the following correction
cause must match. Executed repudiation and arbiter revocation corrections retain
their exact cause data. The current Attribution state may be accepted, disputed
or revoked within the admitted scope.

## Global accounting and atomicity

Principal and delegate nonce projections form the exact original global union
in original index order. A numeric nonce can occur in two distinct Artists'
lanes; it cannot be reassigned to another lane. Grant use counts reconcile once
per original grant across all selected consents, attestations and signed dispute
records. Veto48 preserves the original Identity Contest/Cause pair and checks
the global pair count once across all collections. Pending repudiation counts
are summed across every selected collection sharing the same Artist and captured
authority head.

Target keys are checked before map installation. Each owner imports and commits
once; shared timing, registration and nonce state are installed once. Final
currentness checks and Archive append remain in the same transaction. A late
failure must roll back all seven owners, semantic maps, nonce words, grants,
lane activation, events and the calling Safe's transaction nonce.

## Explicit scope and validation

This profile supports recovered class1/class3 Artists, PRIMARY_ONLY bindings
with empty collaborator sets, original supported Identity/Payout histories,
consent14/15/16/17/20/21, delegation26/27 and attestation24. Binding history is
limited to128 generations per collection and retains existing provenance,
catalog, payload and carrier bounds. It does not add Platform, primary-change,
collaborator, sanction/confirmed-state, ratification or class4 composition.
Those families require their own complete admission and import proofs.

`StreamArtistRecoveredMultipleDisputeWorkers.t.sol` authors12 focused cases for
global nonce/Identity facts, original alias completeness and interleaved clocks.
`StreamArtistRecoveredMultipleDisputeActual.t.sol` authors14 actual-owner/Safe
cases: two-Artist signed chains, original interleaved resolutions, reopen,
pending/cancel, one and two vetoes, executed repudiation correction, revoked
pending-generation correction, independent delegate lanes, cross-family grant
accounting, final Archive cutoff drift, late-append rollback/identical retry and
repeated import with fresh successor history and exact original occurrence positions.
The fixtures use actual Artist owners, threshold Safes and Archive with explicit
Core, governance, immutable sale-fact and documentary coverage unit boundaries.
These are authored scenarios; native execution and current-Executor acceptance
remain pending.

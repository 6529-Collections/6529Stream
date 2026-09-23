# Recovered dispute and repudiation histories

This client carries supported original dispute and repudiation histories across
multiple recovered Artists or collections through the existing Request and
operation 60. It preserves the original signed records, terminal outcomes,
owner clocks and replay inventories.

The separate profile uses version 1 and tag
`6529STREAM_ARTIST_MULTIPLE_DISPUTE_HISTORY_V1`. Its feature bit is `16777216`
and its allowed mask is `16956415`. Every owner envelope requires both the new
bit and the original `DISPUTE_HISTORY` bit `8192`, a minimum of `16785408`.
Other family bits describe the actual retained history. A collection with
multiple generations also needs `BINDING_GENERATIONS` bit `512`.

The original known-feature constant remains `2097151`; the extended vocabulary
recognizes `33554431`. Knowing a bit does not advertise or admit its profile.
Earlier clients retain their own tags, domains and closed feature masks.

See the [contract integration guide](../../../docs/integrations/artist-recovered-multiple-disputes.md),
[ADR 0047](../../../docs/adr/0047-complete-artist-authority-hydration.md) and
[ADR 0048](../../../docs/adr/0048-attribution-repudiation-identity-effects.md)
for the original admission and Identity-effect rules.

## Select the complete graph

Select more than one Artist or more than one collection. Each collection keeps
the same recovered class-1 or class-3 Artist throughout its PRIMARY_ONLY binding
history, with empty collaborator sets and a final accepted binding. Current
Attribution may be accepted, disputed or revoked within this profile.

The supported histories include:

- Original dispute opening 44, counter-statement 45 and signed withdrawal 61,
  including immutable withdrawal outcomes and later reopening.
- Governed resolution 46 at its authentic original owner coordinate.
- Repudiation staging 47, veto 48, cancellation 49 and execution 50, including
  their original authority heads, guardian facts and terminal bodies.
- Accepted, refused and withdrawn binding generations; executed-repudiation
  or arbiter-revocation corrections retain the exact original cause data.
- Supported Identity and Payout histories, consent 14/15/16/17/20/21,
  delegation 26/27 and attestation 24 with complete publication and signature
  evidence.

An arbiter-revoked pending generation has no invented acceptance or completion.
Its original resolution and following correction must agree. Platform histories,
primary changes, collaborators, ratification, collection sanctions and selected
class-4 Artists remain outside this profile.

## Preserve every owner inventory

Each inner semantic envelope has five flat ABI arguments:

```text
abi.encode(tag, uint16(1), uint8(owner), M.State scope, bytes auxiliary)
```

The enclosing recovered ExportHeader and Payload keep their original shapes.
All owners retain the complete admitted scope and global original provenance.

| Owner | Semantic rows | Auxiliary bytes |
| --- | --- | --- |
| 0: Binding | Every original binding, terms, terminal and correction | Complete generation and Archive inventory |
| 1: Collaborator | Empty for PRIMARY_ONLY | Empty |
| 2: Identity | Complete recovered authority bundle per Artist | Empty |
| 3: Acceptance | Every original accepted generation | Original generation matrix |
| 4: Attribution | Original dispute-history and attestation bundles per collection | Same complete inventory as owner 0 |
| 5: Payout | Complete original payout bundle per Artist | Empty |
| 6: Consent | Original generation-aware consent rows per collection | Empty |

Each collection's attestation projection retains its original operation-24
occurrences. Collection selection never filters or renumbers the owner's global
journal. Attestation predecessors form one C2PA chain per Artist across all
selected collections, generations and retained origins.

## Keep independent clocks and original authority

Binding and Attribution mutations use their own original coordinates. Resolution
46 and terminal operations 48/49/50 have authentic replay aliases and Archive
envelopes; their positions cannot be inferred as an opening revision plus one.
Other collections may write between those operations.

Complete Archive catalogues authenticate all seven owner cutoffs. Their
currentness check remains required when the history contains no attestations.
Each imported origin keeps its complete catalogue, immutable prefix and original
lane/cutover evidence. Fresh successor activity uses its own producer domain.

Retain original signatures, consumed digests, nonce words and saved grant
associations. Historical records omit some authorization preimages, including
deadlines; the client must not invent those values or reconstruct a signature
under the destination domain. Present principal or grant liveness cannot replace
the original historical authority facts.

## Reconcile shared state once

Principal and delegate nonce projections must form the exact global union in
original index order. Equal numeric nonces in distinct Artist or delegate lanes
remain distinct. Each original grant version reconciles the sum of consent,
attestation and dispute uses across all selected collections and generations.

Every veto 48 retains its original Identity Contest and Cause pair. The complete
Identity native inventory contains exactly two such rows per retained veto,
counted once across the whole graph. Cancellation 49 preserves its original
activity effects without manufacturing a new signed nonce or native record.

Pending repudiation counts are grouped by Artist and captured authority head,
then summed across all selected collections. The terminal phases retain their
separate meanings:

| Phase | Meaning | Retained terminal evidence |
| --- | --- | --- |
| 1 | Pending | Empty terminal body and no terminal mutation point |
| 2 | Vetoed | Original actor, reason, time and Identity effects |
| 3 | Cancelled | Original staging signer and cancellation time |
| 4 | Executed | Original reason, executable time and mutation point |
| 5 | Invalidated | Original invalidation cause and time; no invented terminal operation |

The original contract checks destination keys before installing state. Each
owner applies and commits once; shared timing, registration and nonce state
are installed once. Client evidence does not independently prove atomic rollback.

## Capture, simulate and reconcile

The client allows at most 16 retained eras, 128 Artists, 128 collections and
128 generations per collection. Economics, royalty and attestation witness
families each have an aggregate ceiling of 128. Pure owner blobs and calldata
are bounded at 2,621,440 bytes. Clock validation applies that same limit to the
supplied Archive-envelope total; standalone dispute validation checks a 16 MiB
aggregate and 24,575 bytes per envelope. Workflow operational calldata is
bounded at 2,097,152 bytes. Prepared and aggregate allocation checks use 16 MiB.
Source collection allows 16,384 catalogue rows
and 64 MiB of operation-carrier bytes. Some contract-supported histories can
exceed these client limits.

```js
const input = { request, royaltyFreezes };
const captured = await captureArtistRecoveredMultipleDisputeHydration(
  provider, deployment, caller, input, { blockTag, gasLimit }
);
const checked = await simulateArtistRecoveredMultipleDisputeHydration(
  provider, captured, { blockTag: laterBlock, gasLimit }
);
```

The original two-argument preparation and
`hydrateRecoveredArtistAuthority(Request)` route remain available without royalty
terms. Supplied royalty terms use the original three-argument preparation and
`hydrateRecoveredArtistAuthorityWithConsents(Request, RoyaltyFreeze[])` route.
Both produce a zero-value Registry CALL under operation 60.

Capture copies caller-supplied values before asynchronous reads and pins the
source, destination and preparation dependencies. Simulation rechecks the source
graph and exact calldata from the intended caller. The original Registry and
Prepared calls remain responsible for contract admission, signatures and private
state checks. A successful simulation does not reserve future state.

```js
const result = await reconcileArtistRecoveredMultipleDisputeHydrationReceipt(
  provider, checked.capture, transactionHash,
  { execution: "safe", expectedSafeTxHash, nonce, safeCodeHash }
);
```

Use `{ execution: "direct" }` for a direct receipt. The Safe route keeps the same
target, zero value and calldata as an ordinary CALL. It checks signed transaction
fields, the expected Safe digest and runtime, the matching success event and one
nonce advance. It does not independently verify or execute Safe owner signatures.

Receipt readback keeps immutable original records, nonzero withdrawal outcomes
and final repudiation terminals comparable after later destination activity.
Captured pending terminals and absent withdrawal outcomes can legitimately
advance. Mutable heads, pending pointers and shared counts are checked at the
exact imported owner revision. Original grant terms, grantor and nonce remain
comparable after later Identity activity; a captured active grant can gain uses
or its first revocation, while an already revoked grant keeps its final row.
Complete original source catalogue evidence must
also match at the mined block; a later same-block source append needs separate
attribution and is conservatively refused by this workflow.

Historical inspection records what was imported. Current inspection reads and
simulates the current graph. Neither renews an old principal's authority or
proves private lane activation independently of the original contract.

## Source and execution boundaries

The semantic and compiler evidence is pinned to
`b3ed602bcad94f09ee95f7abc1017d88df8178ba` and ABI189. The client checkout starts
from integration commit `7d414ed34f3d71424f40bb9448c992e8fa1b110d`, which also
contains later interface-path relocations and the unbound Platform client.
Frozen compiler source paths and current checkout paths remain distinct evidence.

ABI189 contains 4,406 source literals matching that commit's raw Git bytes and
has zero compiler errors. Its result's generic normalization wording is separate
from the observed byte identity. The compact profile and deterministic check
identify the retained declarations and exact source relationships without
invoking a compiler or rewriting earlier fixtures.

The frozen production closure contains 1,140 sources. The compact supplement
reuses 1,005 source files and retains 28 changed and 107 added files relative to
its recorded earlier fixture. It compares all 1,182 retained declarations and
supplements one ordinary interface and 109 nominal library declarations,
including the 37 new dispute-composition libraries. Compiler tuple witnesses
and source-derived aggregate wrappers retain their distinct roles.

The checkout closure has 1,152 sources. Its separate comparison records 39
interface-declaration moves and a later unbound Platform helper extraction;
it does not claim that the two complete source trees are identical. All 37
new producer libraries match the frozen compiler source, while ten integrated
owner or transport files also contain the previously integrated unbound profile.

Client tests use supplied provider replies and synthetic receipts. They prove
encodings, supplied-data checks and client refusal behavior. Actual contract or
Safe execution, private admission, atomic rollback, linked-call gas, bytecode
capacity and release acceptance require separate integration evidence.

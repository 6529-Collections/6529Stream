# Multiple recovered attestation histories

The MULTIPLE_ATTESTATIONS client joins original operation-24 attestations to
complete consent and delegation histories across recovered Artists and
collections. It uses source `bd4a291e9e159cbbb5079a9a2a418fb151a8c01b`, tree
`466dac5d504c33a8a0bf4275997c33c851d65dd0`, and the frozen ABI12 capture.
All 1,430 compiler input literals match that commit's raw Git bytes.

The [BASE aggregate](current-artist-recovered-multiple-hydration.md),
[consent aggregate](current-artist-recovered-multiple-consent-hydration.md),
[original singleton](current-artist-recovered-hydration.md), and
[singleton content](current-artist-recovered-consent-hydration.md) clients retain
their own source pins and closed profiles.

## Profile and complete scope

The tag is `keccak256("6529STREAM_ARTIST_RECOVERED_MULTIPLE_ATTESTATIONS_V1")`,
version 1. Required features include bit `1048576` and attestation bit `128`.
The allowed mask is `1049087`; the original owners advertise `2097151` known
features. Advertised features do not independently admit a history. Neither
older aggregate bit belongs to this profile, and actual operation-24 history
is required.

There are 1–128 Artists and 1–128 collections, with at least one dimension
greater than one, and at most 128 policy selectors in total. Each Artist has
recovered class-1/class-3 history and a selected collection. Each collection is
an accepted generation-one PRIMARY_ONLY binding in consent mode 1 or 2.
The existing [finite transport limits](current-artist-recovered-hydration.md#finite-transport-and-validation)
also apply. A protocol-valid graph can exceed those client limits.

Original attestation kinds 1–10 join policy14, economics15, sale16, content17,
royalty20 and content-freeze21 history. Original17/21 remain undelegated.
Delegation26/revocation27 preserve every version, including unused, replaced,
revoked and earlier-epoch grants. Complete Identity/Payout, guardian, rotation,
estate, recovery, timing and Identity sanction-grant rules remain in force.

Corrections, additional generations, ratifications, disputes, collection
sanctions, Platform history and collaborator/class-4 graphs remain outside
this profile. Omitting their records does not make the complete graph eligible.

## Full admission and owner4 projection

The original Request preserves every Artist, collection, policy selector,
checkpoint, capability, replay origin and prior import commitment. Complete
per-Artist and per-collection record queries remain the admission certificate.
Original journal indices, provenance, aliases and publication catalogues remain
whole; authentic repeated Identity records are not globally deduplicated.

Only the owner4 semantic envelope projects collection record arrays to the
operation-24 occurrences for that collection, in original global journal order.
Other owners, consent validation and the cross-owner anchor use the full
admission queries. An attestation projection cannot replace the original
admission scope.

Each owner carries
`abi.encode(tag, uint16(1), uint8(owner), M.State, bytes auxiliary)`.
`M.State` contains `artists`, `collections` and `rows`. Identity/Payout have one
complete row per Artist; collection owners have one per collection;
Collaborator has no rows. Owner4 rows are canonical original
`StreamArtistRecoveredAttestationHydration.Bundle` values. Owner6 rows retain
the complete raw `ContentH.Bundle` consent and content histories.

Only owner4 has nonempty auxiliary bytes: canonical
`StreamArtistRecoveredMultipleAttestationClocks.Inventory`. It retains the
original Archive catalogue commitments, counts and cutoffs for each era, plus
selected operation evidence coordinates. The workflow scans the catalogue rows
and reads the corresponding immutable payload bytes and metadata; the auxiliary
value alone is not proof of a live Archive read.

Collection witnesses appear for collections with economics15 or operation24,
in collection selector order. Each contains all original economics terms and
attestation terms/nonces in that collection's original occurrence order.
Royalty20 terms remain separately ordered by the complete owner6 journal.
The existing original two- and three-argument preparation routes are preserved.

## Completion clocks, credentials and grant totals

Each collection has exactly one original proposal and acceptance in the same
era. Their original operation1/2 Archive envelopes establish the actual owner4
completion point through canonical payloads and transition preimages. The
source reads also join those envelopes to the original owner0/owner3 native
occurrences. Revisions belonging to different owners are never ordered against
one another.

Every operation24 must follow its own collection's owner4 acceptance point.
The proposal/acceptance commits and complete operation24 history must cover
the original owner4 revision counts without overlap. Catalogue commitments,
snapshot limits, operation metadata and STOP-prefixed immutable payload bytes
are checked against the original source at the pinned block.

C2PA has one evolving predecessor chain per Artist across all its collections
and original eras. Interleaving another Artist does not change that chain.
Each saved credential and final Artist head keeps its source-defined payload,
identity reference, key and validity fields. Personhood remains a distinct
per-collection head and summary with original Registry provenance. Latest
subject and publication records keep their original values. Transporting these
documents grants no new publication authority.

Consent and attestation use counts are added per original Artist and grant
version, then compared once with that version's saved total. Kind-2 nonce
popcounts include uses from every retained version. The original Artist/delegate
key, global insertion order, prefixes, all 32 tree words, exhaustion and local
hints remain intact. A shared delegate still has a distinct lane per Artist.
Shared registration and timing state is compared globally and imported once.

## Capture and simulate

```js
const input = { request, royaltyFreezes };
const captured = await captureArtistRecoveredMultipleAttestationHydration(
  provider, deployment, caller, input, { blockTag, gasLimit }
);
const checked = await simulateArtistRecoveredMultipleAttestationHydration(
  provider, captured, { blockTag: laterBlock, gasLimit }
);
```

Without royalty terms, the plan calls the original
`hydrateRecoveredArtistAuthority(Request)`. With royalty terms it calls
`hydrateRecoveredArtistAuthorityWithConsents(Request, RoyaltyFreeze[])`.
Both are zero-value Registry calls under operation60. Original historical
signatures, signer classes, record domains and associations are retained.
Hydration does not re-sign records or reauthorize historical signers.

Capture copies caller inputs before asynchronous reads and pins source,
destination, preparation-library and linked-runtime observations to an explicit
block. It checks original source records, heads and Archive clock evidence.
Simulation revalidates the saved capture and submits the exact call to
`eth_call` from the intended caller; it does not reserve state.

The fixed Prepared producer and Registry remain responsible for complete
private Identity/Payout semantic admission and installation. Pure checks and
source getter reads do not establish private target emptiness or historical
signature validity. Runtime observations must be matched to reviewed deployment
evidence by the caller.

## Direct and Safe receipts

```js
const result = await reconcileArtistRecoveredMultipleAttestationHydrationReceipt(
  provider, checked.capture, transactionHash,
  { execution: "safe", expectedSafeTxHash, nonce, safeCodeHash }
);
```

Use `{ execution: "direct" }` for direct receipts. Safe transport preserves
zero-value CALL and binds every signed transaction field, the original nonce,
expected Safe transaction hash, reviewed runtime and matching execution event.
The review-plan hash remains distinct from the Safe transaction digest.

Safe reconciliation requires nonempty outer signature bytes, bounded at 16,384
bytes, but does not independently validate owner signatures. The prior-block
nonce must advance exactly once by the receipt block; multiple Safe executions
in that block are outside this bounded receipt profile. Failure, ambiguous
execution events, missing Archive pages or reordered owner commits reject.
Receipt readback also requires the saved original catalogue at the mined block.
A later same-block append to that source Archive needs separate attribution
and is conservatively refused by this workflow.

One whole-owner application commits each owner once before the final operation60
Archive sequence. Historical receipt evidence is separate from current import
eligibility. Receipt readback checks immutable attestation rows even after later
owner4 activity; it checks mutable heads only at the exact import revision.
Private lane activation, complete private installation, Safe implementation and
signature validity, and actual transaction rollback require their own evidence.

## Evidence boundary

The retained fixture keeps complete ordinary compiler ABIs, separate nominal
library ABIs/selectors, the full selected source closure, exact documents and
producer handoff. Expanding a nominal library tuple into a wallet ABI does not
give the compiler's library selector. Only immutable ABI schemas may be reused;
caller values, hashes and live read observations are checked on every operation.

Build and strict TypeScript checks pass. The 19 pure-client groups, 11 compiler
oracles and 26 RPC/Safe workflow groups pass, with workflows run in finite named
partitions. The 95 retained BASE/255/511/MULTIPLE_CONSENTS pure-client and oracle
cases also pass. Failed initial runs and focused repair evidence remain retained;
the C2PA test repair leaves the other 18 pure-test bodies unchanged.

Compiler-shaped mock RPC/Safe tests do not execute Solidity or a deployed Safe.
Actual contract execution, rollback, linked-call gas, joined deployment capacity,
full-current validation and release acceptance remain separate integration work.

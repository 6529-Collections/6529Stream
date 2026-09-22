# Recovered Artist histories across binding generations

This client handles the supported `MULTIPLE_GENERATIONS` profile through the
original recovered-authority Request and operation 60. It preserves each
original record, signature, replay scope and owner coordinate while carrying
complete histories for multiple Artists or collections.

The profile has tag `6529STREAM_ARTIST_RECOVERED_MULTIPLE_GENERATIONS_V1`,
version 1 and feature bit `2097152`. Its allowed feature mask is `2276351`;
the selected contract suite advertises the combined mask `4194303`. A broad
owner capability advertisement does not make every history valid for this
profile. Earlier recovered clients retain their own closed profiles.

## Supported histories

Select more than one Artist or more than one collection. Every selected
collection must have a complete, currently accepted PRIMARY_ONLY binding, and
at least one collection must be at generation 2–128. Each collection retains
the same original recovered class-1 or class-3 Artist through all generations.

Every earlier generation must have its original completion:

- An unaccepted proposal may end with refusal 3 or withdrawal 4.
- An accepted generation must have its authentic governed dispute opening 44
  and class-2 revocation resolution 46 before the next corrective proposal 1
  and its eventual completion.

Signed or reopened disputes, ratification 52, collection sanctions, Platform
declarations and corrections, changes of primary Artist, collaborators and
selected class-4 Artists are outside this profile. Existing supported Identity
sanction grants remain part of the retained authority history.

See the [contract integration guide](../../../docs/integrations/artist-recovered-multiple-generations.md)
and [ADR 0047](../../../docs/adr/0047-complete-artist-authority-hydration.md)
for the original contract boundary.

## Keep the complete owner inventories

Each owner semantic envelope contains five flat ABI arguments:

```text
abi.encode(tag, uint16(1), uint8(owner), M.State, bytes auxiliary)
```

The canonical Artist and collection queries remain the complete admitted
scope. The enclosing owner payload keeps its original full provenance,
journal, aliases, nonces and publication inventory.

| Owner | Semantic rows | Auxiliary bytes |
| --- | --- | --- |
| 0: Binding | Complete original binding and correction bundles per collection | Complete `G.Inventory` |
| 1: Collaborator | Empty for PRIMARY_ONLY | Empty |
| 2: Identity | Complete canonical authority rows per Artist | Empty |
| 3: Acceptance | Original acceptance histories per collection | Complete `Generation[][]` matrix |
| 4: Attribution | `G.Attribution`: original revocation history and attestation rows | The same complete `G.Inventory` as owner 0 |
| 5: Payout | Complete canonical payout rows per Artist | Empty |
| 6: Consent | `G.Consents`: original consent rows and complete binding inventory | Empty |

`G.Inventory` contains the original Archive catalogues, operation-evidence
locators and commitments, binding/correction bundles and generation points.
The workflow retrieves and authenticates the original envelope bytes while
checking that inventory. Owner 4 alone copies each
collection query's record list and projects it to that collection's original
operation-24 occurrences. Artist record lists, the cross-owner anchor and
the original provenance remain complete. A filtered owner journal is not a
valid substitute for that projection.

## Preserve original clocks and preimages

Collections can write between another collection's proposal and completion.
Keep independent collection cursors over the original global owner revisions.
Never replace those revisions with a per-collection counter.

Original Archive proposal and completion evidence binds all seven owner
cutoffs. A governed opening has a native operation-44 receipt. Its resolution
uses the authentic RESOLVE and governance aliases; another collection may
write before resolution, so the resolution point is not opening plus one.

Every attestation retains its saved binding generation and association. It
must occur after that generation's actual owner-4 acceptance completion and
before the next proposal. C2PA predecessors form one chain per Artist across
all selected collections, generations and retained eras.

Consent records keep their original distinctions:

- Operation 14 has no saved generation. Do not invent one. Its retained
  delegated authority needs an authentic accepted historical mode-2 binding.
- Saved-generation delegated sale consent 16 uses its exact accepted mode-2
  binding.
- Identical economics terms may occur in different accepted generations.
  Retain every original operation-15 occurrence, its per-binding association,
  the original first-record terms lookup and its continuation replay domain.
- Sale consent uniqueness includes terms, generation and binding hash.
  Repeated terms across generations retain distinct records and the original
  latest lookup.
- Content, royalty and freeze records retain their own saved generations and
  original source lookups.

Do not rewrite signatures or recompute an old record under the destination's
domain. The new aggregate tag identifies the carrier, not a new authorization
scheme.

## Replay and grant conservation

Keep the complete original nonce union, bitmap words, popcounts, exhaustion
state, nonce hints and insertion order. Equal numeric nonces in distinct
delegated lanes remain distinct lanes.

Consent and attestation use counts are reconciled together across every
selected collection, generation and retained grant version. Comparing only
the latest generation or one consent family can miss a consumed use. Shared
registration and timing state is installed once; each owner applies and
commits its complete state once.

## Capture and simulate

The client retains bounded inputs: at most 16 original eras, 128 Artists,
128 collections and 128 generations per collection. Economics, royalty and
attestation witness families each have an aggregate client ceiling of 128.
Some contract-supported histories can exceed these client limits.

Original owner blobs, ordinary calldata and the supplied clock-envelope total
are bounded at 2,621,440 bytes; Prepared and aggregate allocation checks use
16 MiB. Source catalogue reads allow at most 16,384 rows and 64 MiB of
operation-carrier bytes. Retained per-record signatures are bounded at 4,096
bytes. These bounds do not replace the original semantic checks.

```js
const input = { request, royaltyFreezes };
const captured = await captureArtistRecoveredMultipleGenerationHydration(
  provider, deployment, caller, input, { blockTag, gasLimit }
);
const checked = await simulateArtistRecoveredMultipleGenerationHydration(
  provider, captured, { blockTag: laterBlock, gasLimit }
);
```

Without royalty terms, preparation retains the original
`hydrateRecoveredArtistAuthority(Request)` call. With royalty terms it uses
`hydrateRecoveredArtistAuthorityWithConsents(Request, RoyaltyFreeze[])`.
Both are zero-value Registry calls under operation 60.

Capture copies the supplied values before asynchronous reads and pins source,
destination and preparation dependencies to the requested block. Simulation
rechecks that capture and calls the exact Registry calldata from the intended
caller. It does not reserve state for a later transaction.

## Currentness and receipt evidence

Current preparation reads the complete admitted source graph. The original
Registry and Prepared calls remain the contract admission boundary for
authority, signatures and private state checks. A successful simulation
describes that concrete observation; source changes can require recapture.

The generation currentness path always runs, including when there are no
operation-24 records. It rechecks the canonical owner-4 envelope, original
anchor, exact full provenance, aggregate chronology and complete Archive
catalogue against all seven cutoffs. Omitting attestations does not remove
the generation evidence obligation.

Receipt reconciliation retains the original operation-60 calldata, owner
commits, imported lanes and Archive evidence. A Safe submits the same
zero-value ordinary CALL through the established Safe transport checks.
Client reconciliation does not independently execute Safe owner signatures
or prove private activation state.

```js
const result = await reconcileArtistRecoveredMultipleGenerationHydrationReceipt(
  provider, checked.capture, transactionHash,
  { execution: "safe", expectedSafeTxHash, nonce, safeCodeHash }
);
```

Use `{ execution: "direct" }` for a direct receipt. Safe reconciliation checks
every signed transaction field, the expected Safe digest, reviewed runtime,
matching execution event and a single nonce advance across the mined block.
Nonempty outer signature bytes are required and bounded at 16,384 bytes;
the client does not independently verify those signatures. The review-plan
hash remains separate from the Safe transaction digest.

Receipt readback checks immutable generation, consent and attestation rows.
It checks mutable heads only at the exact imported owner revision. It also
requires the complete original source catalogue at the mined block. A later
same-block append to that source Archive needs separate attribution and is
conservatively refused by this workflow.

Historical records and retained Archive bytes can establish what was
imported. They do not establish that an old principal, grant or source suite
is still authorized. Current and historical observations keep those claims
separate.

## Source and execution boundaries

The client source profile is pinned to integration commit
`45828ad0db2a6d52c6b0c7aad8d25dd4ba866c65`. It includes the integrated
multiple-generation producer and typed BindingDecode repair. Selected compiler
evidence and the source comparison identify the exact surfaces they cover;
they do not establish whole-suite linked bytecode or a live deployment.

The compact source profile retains 38 new library declarations from ABI178
at compiler-source commit `d823d82c971fdf63906895852a7c6bd6543d5982`.
All 4,321 input source literals match that commit's raw Git bytes; no line-ending
normalization was needed. The selected 1,078-source production closure also
matches the separately pinned client target. The earlier compiler fixture
remains unchanged, and its retained declarations are reused only after exact
full-ABI and nominal method-map comparisons.

The compiler supplies nominal tuple witnesses for `G.Inventory`, `G.Timeline`
and `G.Consents`. The `G.Attribution` wrapper and five-field envelope are
derived from the pinned source. Expanded library value tuples do not define
ordinary wallet-call selectors. The source profile generator checks retained
artifacts; it does not rerun the compiler.

Client tests use supplied provider responses and synthetic receipts. They
check encodings, source joins and client refusal behavior. Actual contract
execution, Safe execution, rollback, gas, deployment size and release
acceptance require their separate integration evidence.

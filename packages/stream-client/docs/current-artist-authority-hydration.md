# Artist authority hydration

Operation 60 imports a complete, approved living-Artist authority profile from
the sealed predecessor into its designated successor. The client preserves the
original requests, records, signature domains, source checkpoints and replay
evidence. A successful plan or receipt does not authorize unrelated Artist
operations or establish mint readiness.

## Explicit profiles

| Client profile | Original Registry method | Capability ID |
| --- | --- | --- |
| Baseline single Artist | `hydrateArtistAuthority` | `0x1f51c336` |
| Multiple Artists and collections | `hydrateMultipleArtistAuthority` | `0x4739d03d` |
| Single Artist with delegation history | `hydrateArtistAuthorityWithDelegations` | `0xe17666b4` |

Each is a separate ERC-165 interface with its original selector. All use
operation 60 and the seven-owner mask `0x7f`. Hydration is permissionless; the
caller supplies verifiable selectors and source headers, not a new signature
or an assertion of authority.

Baseline and multiple profiles admit original registration/proposal (1),
acceptance (2), direct policy consent (14) and authorization revocation (54).
The delegation profile additionally carries living identity revisions (25),
delegation grants (26), revocations (27) and sale consent (16), including their
original historical grant associations. Exact revision totals also exclude
unsupported changes that did not append native records.

All three profiles require original living class-1/status-1 Artists, accepted
generation-one collections and `PRIMARY_ONLY` collaborator policy. Baseline and
multiple use signed consent mode 1; delegation allows modes 1 and 2 and the
original delegation epoch zero. The multiple profile includes collections that
share one Artist identity. Its ordered Artist and collection lists must account
for the whole admitted source.

The separate payout, economics, readiness, publication and entropy-finding
selectors are not composed implicitly into these profiles. The existing
entropy-authority helper retains its explicit entropy-finding path. Combined
multiple-Artist delegation, corrected or pending bindings, collaborator
policies, advanced authority histories and repeated imports require their own
accepted profiles.

## Plan, revalidate and inspect

```js
const prepared = prepareArtistAuthorityHydrationCall(registry, caller, {
  kind: "baseline", // or "multiple" / "delegation"
  request: originalRequest,
});
const captured = await captureArtistAuthorityHydration(
  provider, deployment, prepared, { blockTag: captureBlock }
);
const checked = await simulateArtistAuthorityHydration(
  provider, captured, { blockTag: laterBlock }
);

// After submitting checked.prepared.call and obtaining its transaction hash:
const receipt = await inspectArtistAuthorityHydrationReceipt(
  provider, checked, transactionHash, { execution: "direct" }
);
```

All protocol integers use bigint. The baseline and delegation requests have
`bindingIndex`, `artistId`, `collectionId`, seven `expectedSource` checkpoints,
seven ordered `replayOrigins` arrays, and `policies`. The multiple request has
`bindingIndex`, ordered `artistIds` and `collections`, the seven checkpoints
and seven origin arrays. Its collection rows retain their own policy selectors.
The client checks the request supplied for review and never silently replaces
stale headers or drops an unsupported record.

`deployment` contains a chain ID and separate source/destination suite pins.
Each suite has `registry`, `coordinator` and 16 `components`, all with reviewed
address/runtime hashes. Component order is the seven owners, Registry, Archive,
Core, Manager, roles, metadata, primary resolver, royalty resolver and validator.
Captures use concrete block numbers, copy inputs before asynchronous reads and
reject changed block hashes or noncanonical RPC bytes.

Solidity string fields are represented as Unicode text. Original document and
signature payloads remain opaque bytes.

The prepared call carries `factsVerified: false`. Capture reconstructs the
complete evidence and simulates the actual zero-value Registry call from the
retained caller. Its `simulated` flag applies to that captured block. Revalidation
checks the saved historical capture and the chosen later block; changed source
or destination facts require a new capture. The client does not sign or submit.

For a Safe caller, compose `checked.prepared.call` with the existing
`createSafeCallPlan` and `CURRENT_ARTIST_AUTHORITY_HYDRATION_ABI`. Receipt
inspection uses `{ execution: "safe" }` for the original single-call
`execTransaction` with operation zero. It checks the exact inner call and the
Safe outcome alongside the complete hydration receipt. Nested batches and
delegatecall are outside this receipt profile.

## Complete source evidence

The source must have completed its original operation-57 seal naming this
successor. The successor must have exactly one original history binding at
index zero. Every relevant Artist and collection lane must already have its
permanent final-lane proof. A lane proof alone installs no authority.

The source and destination suites retain eight identical non-Artist
dependencies. Their Registry, Coordinator, Archive and seven fixed owners are
bound to reviewed runtime hashes and reciprocal configuration. Source headers
include each owner's state snapshot, replay root and count, and nonce root and
index count. The inspector checks the exact supplied headers against those
fixed owners. Current replay cells cannot independently reconstruct rolling
historical update roots.

Replay origins retain the source's inventory order. Policy selectors retain
each collection's original policy-receipt order. All native records, replay
cells and typed nonce indexes are accounted for. Every selected sparse nonce
prefix retains its 32 ancestor words and exhaustion value. The original
contract call remains responsible for admitting the complete profile.

Multiple-profile Artist IDs are checked against their original registration
ordinals, which follow the source Identity journal rather than sorted Artist
IDs. The carried global registration allocator must match the full identity
count. Every Artist must participate in at least one admitted collection.

Delegation imports preserve every grant version, replacement head, use count,
revocation and recorded historical grant association. Expiration, exhaustion
or later revocation does not erase a consent already recorded under that grant.
Replacement grants share the original delegate nonce lane. Fresh successor
writes still require their original current authorization checks and successor
signature domain.

## Original commitments and receipts

The common hydration commitment binds the profile, chain, successor Registry
and actual Coordinator, predecessor Registry and Coordinator, original baseline
request, query and all seven owner-data rows. The actor is bound separately by
the operation evidence ID and owner transitions.

The multiple profile synthesizes its baseline commitment request from the
first collection. That collection's Artist need not be the first sorted Artist
ID. Its full ordered inventory remains committed inside the tagged owner
bundles and the multiple-profile event. Hashing the public multiple request as
though it were the baseline request would produce a different commitment.

The Archive retains the original eight-field evidence envelope:

```text
schemaVersion, configurationHash, operationId, actor, commitment,
before[7], after[7], profileBytes
```

The single transaction applies all seven owners, rechecks the authenticated
source, appends this evidence and synchronizes retained payload catalogs.
Every owner advances once using its original state-transition recipe. Hydration
does not duplicate old semantic records. The predecessor's terminal cutover
latch is retained as historical evidence rather than consuming the successor's
own future latch.

A receipt must match the original call and actor, all seven transitions, the
Coordinator events and exact Archive append. Completion markers alone are not
a receipt or proof of readiness. Hydration is one-shot: a failed call can be
retried with its original bytes, but an eventless successful retry is not an
alternative completion path.

Inspection first reproduces the saved historical capture. The receipt must
come from a strictly later block, and both block hashes are checked again
after inspection.

Receipt inspection also reconstructs the retained Identity document and
signature payload inventory, including empty bundles, duplicates and delegation
revision documents. It checks the expected new catalog entries, events and
immutable carrier bytes in both Identity and Archive. Omitting both copies of
an expected payload event does not pass. Later owner state may have advanced;
the exact hydration transition remains the one recorded in its Archive evidence.

## Original bounds

The approved profiles retain at most 128 native receipts per owner, 512 replay
cells per owner and 256 nonce prefixes in total. Multiple profiles admit up to
128 selected Artists and collections. Delegation admits at most 128 nonce
indexes. The complete evidence must fit the original 24,575-byte Archive
carrier before any owner writes. These limits do not imply that their maximum
combinations fit one carrier or transaction.

The inspector separately bounds each RPC response to 1,048,576 bytes, pinned
runtime code to 131,072 bytes, transaction calldata to 2,097,152 bytes, and the
captured payload catalogs to 1,024 rows per host. Receipts permit at most 2,048
logs with four topics and 65,536 data bytes per log. These are client inspection
bounds; they do not enlarge the protocol's evidence carrier.

## Frozen evidence

The additive fixture uses `parallel-feature-batch67-20260920` at
`be359669d736843e7f0c8a85eed6f06ec9521464`. All 2,311 literal compiler inputs
match that Git commit. The selected fixture retains 172 ABI entries, 376
dependency-source hashes and 66 source texts. The Artist source and approved
profile guides are unchanged through integration `1f47d711`.

Compiler-exposed tuples retain their original types and field order. Internal
state envelopes without a compiler ABI witness are explicitly derived from
the retained Solidity declarations. Earlier fixtures and the operation coverage
snapshot retain their original source pins.

```sh
node scripts/generate-current-artist-authority-hydration-fixture.mjs \
  /path/to/abi-input.json /path/to/abi-output.json --check
```

Client and mocked-RPC tests do not establish native current-stack, actual Safe,
gas, genesis or release acceptance. The integrator owns that separate evidence.

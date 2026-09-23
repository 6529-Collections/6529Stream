# Recovered content and freeze consent hydration

The ART36 client prepares the additive
`hydrateRecoveredArtistAuthorityWithConsents(Request, RoyaltyFreeze[])` call.
It carries complete original content and freeze consent history under recovered
operation 60, profile 10, alongside the existing Identity, Payout, delegation,
economics and attestation inventories.

Its source is ABI106 at `836b9c64e1f0630d4e79e6cee831450059616fd7`, tree
`2fcb2562f0f58780fbd7d77918df0afd505b7dd7`. The
[original recovered client](current-artist-recovered-hydration.md) retains its
ABI104 source, selectors, public API and 31/63/127/255 feature qualifications.
Shared private code binds each public client to its fixed supported profile.

This remains the singleton class-1/class-3 graph: one recovered Artist, one
accepted generation-one PRIMARY_ONLY collection and no collaborators.
Generation feature bit 512, advertised mask 1023 and the later Prepared capacity
worker extraction are outside this source snapshot.

## Complete content history

Every owner must support the complete required feature set. Mask 511 is the
known advertised capability shape for ART36; the actual source history selects
required bit 256 whenever owner 6 has operation 17, 20 or 21. The original
31/63/127/255 labels retain their meanings. Capability bits carry transport
support and leave the Artist's original authority permissions intact.

| Original operation | Retained content | Caller selectors |
| --- | --- | --- |
| 17 | Every content-consent record and latest head for its exact terms. Repeated terms with different original authorizations remain valid. | Read from the complete source journal. |
| 20 | Every royalty-freeze record, its original scope and any original delegation association. | Every `RoyaltyFreeze` term in filtered operation-20 journal order. |
| 21 | Every content-freeze record and latest head for each Metadata/lock-class scope. Overlapping lock sets update only their included locks. | Read from the complete source journal. |

The original `Request` is unchanged. It still carries the complete Artist and
collection selectors, seven exact source checkpoints and capabilities, all
logical replay-origin witnesses, the prior import commitment and the expected
semantic inventory. Its collection witness rules for operations 15 and 24
remain unchanged.

The separate `royaltyFreezes` array contains `{ resolver, collectionId,
revenueClass, expectedAssignmentHash }` for every original operation-20 row.
The revenue class is the original `ROYALTY_ERC2981` value. Preserve journal
order; sorting by scope changes the request. Missing, extra, duplicate or
reordered scopes reject. An empty array is required when no operation-20 row
exists. Content operations 17 and 21 can still require bit 256 in that case.

The new entry point also supports admitted histories without content records,
using their original codec and an empty royalty array. The historical 255
client retains its explicit rejection of content-feature certificates.

## Prepare and simulate

```js
const input = { request, royaltyFreezes };
const captured = await captureArtistRecoveredConsentHydration(
  provider, deployment, caller, input, { blockTag, gasLimit }
);
const checked = await simulateArtistRecoveredConsentHydration(
  provider, captured, { blockTag: laterBlock, gasLimit }
);
```

The caller is permissionless and nonzero; native value is zero. A draft can use
zero `expectedSemanticInventory` only while collecting the read-only certificate.
The final mutation carries the exact nonzero identifier. A supplied nonzero
expectation must match the collected inventory.

Collection calls the original three-argument
`StreamArtistRecoveredHydrationPrepared.prepare` library with the same ordered
royalty terms used in the final Registry call. Its compiler-authenticated
nominal selector is `0x4925300f`; an ordinary tuple ABI produces a different
library selector. The original two-argument preparation stays separate.

Deployment inputs require reviewed source and destination suites, the exact
preparation library runtime and its linked dependency pins. These pins must
come from reviewed deployment/link metadata for this source. A caller-supplied
address/hash pair alone cannot establish its implementation. The six original
Prepared selector witnesses in the fixture do not establish deployment size or
runtime acceptance of later library implementations.

Capture verifies both complete preparation responses and the original source
inventories at an explicit block. It joins the content records, royalty scopes,
delegation associations and latest content/lock heads through the fixed Consent
owner. The simulation step separately executes the exact final Registry call
from the intended caller at a concrete block. It does not reserve state or
guarantee gas sufficiency inside a Safe.

## Original domains and current eligibility

Royalty terms enter the complete owner-6 typed payload. The existing semantic
inventory, combined commitment and paged profile evidence already bind that
payload. The Request, operation header and hash recipes keep their original
schemas.

Original operations 17, 20 and 21 omit some authorization preimages, including
signer, nonce or observed time. The client preserves the original producer's
authenticated records, signatures, complete Identity inventory and original
replay/nonce state. It does not invent missing fields to reconstruct a digest.
The original producer performs the complete cross-owner semantic admission.

Historical Metadata and Resolver addresses, assignments and grants remain in
their original terms and domains. Their current mutable state cannot replace
the retained facts. Delegated operation 20 participates in the complete original
14/15/16/20/24 use inventory. Cross-era order uses authenticated provenance;
Identity and Consent revisions within one era are separate owner clocks.

Fresh successor actions still use the successor's original signature domain,
current authority and grant rules. Importing a freeze authorization leaves
execution of the actual Metadata or Royalty Resolver freeze as a separate action.
Operation 21 is content-freeze authorization; publication intent remains
operation 24, kind 7.

## Direct and Safe receipts

```js
const plan = createSafeCallPlan(chainId, "Import recovered content history", [{
  safe: caller,
  intent: "Recovered Artist authority with complete consent history",
  call: checked.capture.prepared.call,
  abi: CURRENT_ARTIST_RECOVERED_CONSENT_HYDRATION_ABI,
}]);

const receipt = await reconcileArtistRecoveredConsentHydrationReceipt(
  provider, checked.capture, transactionHash,
  { execution: "safe", expectedSafeTxHash }
);
```

Direct execution uses `{ execution: "direct" }`. Safe reconciliation requires
the independent Safe transaction hash and exact ordinary single CALL, including
the royalty array. The shared plan review hash is a different identifier.

The original seven-owner commits, immutable imported prefixes, complete
publication catalogs, ordered Archive pages and canonical operation-60 header
remain one atomic transaction. Failed calls and propagated late failures cannot
produce an accepted complete receipt. The new readback also checks imported
content records and royalty associations. Latest-head equality applies at the
exact Consent import revision; later writes can legitimately advance those
heads while the immutable historical records remain available.

Receipt checks reproduce the reviewed and immediately prior blocks, then join
the receipt block's original evidence. Their result proves the historical import
and explicitly makes no claim about current authority or eligibility.

## Bounds and evidence

Each operation-17/20/21 family permits at most 128 records. Each operation-21
record contains a nonempty, strictly increasing set of at most 16 lock classes.
The complete original provenance, nonce, publication and paged evidence limits
remain applicable, along with the shared client's explicit
[allocation and gas bounds](current-artist-recovered-hydration.md#finite-transport-and-validation).

The retained fixture contains full selected ABIs, nominal selector witnesses,
the source import closure and original documents. Build, strict TypeScript,
compiler comparisons and mocked RPC tests establish client behavior within this
source profile. Actual contract/Safe execution, linked deployment capacity,
whole-system gas and release acceptance remain integration work.

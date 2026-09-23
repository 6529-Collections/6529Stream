# Multiple recovered consent histories

The MULTIPLE_CONSENTS client carries complete original consent and delegation
histories across recovered Artists and collections under operation 60. Its
source is `c636a5f176c5765d80d15ee20f41355a8911ea9c`, tree
`7f52167006283928e96919fcea03b7434e61b257`, using the frozen ABI11 capture.
All 1,408 compiler input literals match that commit's raw Git bytes.

The [BASE aggregate client](current-artist-recovered-multiple-hydration.md),
[original singleton client](current-artist-recovered-hydration.md), and
[singleton content client](current-artist-recovered-consent-hydration.md)
retain their source pins and supported profiles. This client does not accept
later operation-24 aggregate profiles or reinterpret their feature bits.

## Profile and complete scope

The distinct tag is
`keccak256("6529STREAM_ARTIST_RECOVERED_MULTIPLE_CONSENTS_V1")`, version 1.
Required bit `524288` selects this profile. The allowed required-feature ceiling
is `524671`; the seven original owners advertise `1048575`. An advertised bit
does not independently admit that history through this client. Every owner
header must agree on the actual complete graph's required features.

The graph contains 1–128 Artists and 1–128 collections, with at least one
dimension greater than one. Each Artist has actual recovered class-1/class-3
history and at least one selected collection. Collections are accepted
generation-one PRIMARY_ONLY bindings in consent mode 1 or 2, without
collaborators. The original complete Identity/Payout, recovery, guardian,
rotation, estate, timing and continuation rules still apply.

There are at most 128 policy selectors in total. The existing
[provenance, allocation and gas bounds](current-artist-recovered-hydration.md#finite-transport-and-validation)
also apply; a protocol-valid graph can exceed the client's finite limits.

| Original operation | Preserved history |
| --- | --- |
| 14 | Direct or delegated policy consent and original scope heads. |
| 15 | Direct or delegated economics consent, original associations and supplied terms. |
| 16 | Direct or delegated sale consent and original authorization records. |
| 17 | Undelegated content consent records and exact latest heads. |
| 20 | Direct or delegated royalty-freeze records, original associations and supplied terms. |
| 21 | Undelegated content-freeze records and per-lock heads. |
| 26/27 | Original grants, replacements, revocations, versions, epochs and uses. |

The original source chooses this profile for grant/revocation history, a consent
operation beyond direct policy, or a mode-2 binding. A graph containing only
the admitted BASE histories retains its original BASE tag. Unused, revoked,
replaced and earlier-epoch grants remain part of the complete retained history.

Additional generations, corrections, ratifications, disputes, collection
sanctions, Platform history, operation-24 attestations and collaborator/class-4
graphs are outside this profile. The tag does not make omitted history empty.

## Global partitions and witnesses

The original Request carries every Artist and collection exactly once in
selector order, complete policy selectors, seven checkpoints and capabilities,
replay origins, the prior import commitment and expected semantic inventory.
Journal occurrence order, duplicate records, original native indices and owner
clocks remain intact. A filtered journal with new indices is not an original
provenance certificate.

The aggregate State keeps `artists`, `collections` and `rows`. Identity and
Payout have one full row per Artist; Binding, Acceptance, Attribution and Consent
have one per collection; Collaborator has no rows. Each Consent row is the raw
canonical `ContentH.Bundle`, with its complete original consent sub-bundle and
content/freeze histories. It is not the singleton outer content envelope.

Economics witnesses include only collections with operation-15 records, in
collection selector order. Each row contains every economics term in that
collection's original operation-15 occurrence order, with no attestation
witnesses. The resolver must be the original primary or royalty resolver.
The complete graph permits at most 128 economics terms.

The separate `royaltyFreezes` array contains every original operation-20 term
in the full owner-6 journal order, at most 128 entries. Each term retains
`resolver`, `collectionId`, `revenueClass` and `expectedAssignmentHash`.
Per-collection partitioning must not reorder the original global terms.

Grant usage is conserved per original Artist and grant version across all
collections and direct/delegated policy, economics, sale and royalty rows.
One delegate shared by two Artists still has two distinct kind-2 nonce lanes:
the key uses the original `6529STREAM_ARTIST_DELEGATE_NONCE_LANE_V1` domain,
Artist ID and delegate. All retained grant versions contribute their original
uses; a source slice cannot reset the count.

Every Artist's local nonce lanes form a disjoint union of the one original
global Identity inventory. Preserve global insertion order, prefixes, all 32
tree words, exhaustion and local hints. Principal, rotation-acceptance and
estate-activation keys keep their distinct original recipes. Registration and
the full timing bundle are shared across all Artists, and current authority
addresses are nonzero and unique.

## Prepare and simulate the original call

```js
const input = { request, royaltyFreezes };
const captured = await captureArtistRecoveredMultipleConsentHydration(
  provider, deployment, caller, input, { blockTag, gasLimit }
);
const checked = await simulateArtistRecoveredMultipleConsentHydration(
  provider, captured, { blockTag: laterBlock, gasLimit }
);
```

With no royalty terms, the plan uses the original
`hydrateRecoveredArtistAuthority(Request)` call and two-argument Prepared
entry. With royalty terms it uses
`hydrateRecoveredArtistAuthorityWithConsents(Request, RoyaltyFreeze[])` and
the original three-argument Prepared entry. Native value is zero. Nominal
library selectors come from the compiler's method identifiers; expanding
library tuples into a wallet ABI does not produce the correct library selector.

Capture copies caller inputs before asynchronous reads and pins source,
destination, preparation-library and linked-dependency runtime observations to
an explicit block. It checks complete source inventories and original heads.
Simulation revalidates the saved capture and calls the exact Registry plan
from the intended caller. It does not reserve state or guarantee later execution.

Original signatures, signer classes, associations and Registry domains remain
historical data. Hydration does not re-sign terms, re-authorize historical grants
or invent absent authorization fields. Full original Identity/Payout semantic
admission remains the fixed Prepared producer's and Registry's responsibility.

## Direct and Safe receipts

The receipt path checks the exact captured call, caller and zero value. Safe
transport additionally binds all signed fields, original nonce, expected Safe
hash, reviewed runtime and the matching success event. A successful outer
transaction cannot replace successful target-call evidence.

```js
const receipt = await reconcileArtistRecoveredMultipleConsentHydrationReceipt(
  provider, checked.capture, transactionHash,
  { execution: "safe", expectedSafeTxHash, nonce, safeCodeHash }
);
```

Direct receipts use `{ execution: "direct" }`. Safe transport requires nonempty
outer signature bytes, capped at 16,384 bytes; the client does not independently
verify the owner signatures.

Safe reconciliation requires its immediately prior-block nonce and exactly one
nonce advance by the receipt block. Multiple Safe executions in that block fall
outside this bounded receipt profile. The planner's review hash remains distinct
from the Safe transaction digest.

One aggregate application produces one commitment per owner and one operation-60
commit, with complete imported prefixes, global nonce/registration state and
the ordered Archive pages. Safe success follows the original application
evidence. Failure, duplicate execution events, missing pages, changed pointers
or reordered commits are refusals.

Historical import evidence remains separate from fresh import eligibility and
current authority. Private lane activation, complete private semantic
installation and owner signatures are not independently proved by client
readback; their result qualifications remain explicit.

## Evidence boundary

The fixture retains complete ordinary and nominal compiler ABIs separately,
the full selected source closure, producer evidence and exact profile documents.
Only private immutable ABI schemas are reused; caller values, payload hashes
and live observations are validated on each operation.

Build and strict TypeScript checks pass. The 19 pure-client groups, nine compiler
oracles and 17 RPC/Safe workflow groups pass, with workflows run in bounded named
partitions. Standalone evidence decoding also has a regression that fails before
the retained-guard repair and passes afterward. The 67 retained BASE/255/511
pure-client and oracle cases pass. Compiler-encoded mocks do not execute Solidity
or a deployed Safe.
Actual contract/Safe execution, transaction rollback, runtime provenance, joined
deployment capacity, gas and release acceptance remain separate integration work.

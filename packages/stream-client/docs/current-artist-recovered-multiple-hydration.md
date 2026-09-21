# Multiple recovered Artists and collections

The MULTIPLE_BASE client prepares the original
`hydrateRecoveredArtistAuthority(Request)` operation 60 for a complete graph
containing more than one Artist or more than one collection. The Request,
Registry entry point, seven-owner mask and profile-10 evidence remain unchanged.
Each owner receives one aggregate payload and commits once.

This client is pinned to ABI167, source
`99e9503020ea713b558835ac6fe1a034e36994a2`, tree
`21c4a573e18deea66f8030fcea5def18b792af66`. Its two Artist source directories
match producer `28ef1f012b414f8a215a96708066ce13549e4dd0` exactly. The
[original recovered client](current-artist-recovered-hydration.md) and
[content-consent client](current-artist-recovered-consent-hydration.md) retain
their separate source pins and feature limits.

## Admitted history

Every selected Artist must have actual retained recovery history. Current and
historical recovery classes are limited to class 1 and class 3. Each selected
Artist owns at least one selected collection. Collections are accepted
generation-one PRIMARY_ONLY collections without collaborators. The aggregate
can retain supported Identity and Payout recovery, guardians, rotations, estate,
dormancy, timing, auxiliary records and continuation history across prior imports.
Base Attribution and complete direct operation-14 policy history are included.

Required bit `262144` identifies MULTIPLE_BASE. The actual required mask also
includes the class and continuation bits derived from the complete retained
history. `262175` is the accepted feature ceiling; it is not an exact required
mask. The source advertises `KNOWN_FEATURES = 524287`, which does not admit
additional combinations through this client. All seven payload feature headers
must agree and all seven owners must support the actual required features.
Estate permissions remain exactly as retained, including a zero permission mask.

The aggregate rejects retained delegations, including unused grants; economics;
sale, content, freeze and ratification consent; operation 24; corrections and
multiple generations; disputes, collection sanctions and Platform history.
Class 4 and collaborators are also outside this profile. One Artist with one
collection belongs to a singleton profile.

## Complete owner partitions

Each semantic payload has the tag
`keccak256("6529STREAM_ARTIST_RECOVERED_MULTIPLE_BASE_V1")`, version 1 and its
original owner index. Its State contains `artists`, `collections` and `rows`.
Artists and collections are strictly ordered by their original IDs. Artist
queries have no collection scope; collection queries name their exact Artist,
binding and complete policy selectors. The anchor copies the first collection's
scope and its Artist's records without changing either original query.

| Owner | Aggregate rows |
| --- | --- |
| Binding, index 0 | One original Binding row per collection. |
| Collaborator, index 1 | No rows, with the complete zero-history certificate. |
| Identity, index 2 | One complete recovered Identity bundle per Artist. |
| Acceptance, index 3 | One original Acceptance row per collection. |
| Attribution, index 4 | One base state and original proposal origin per collection. |
| Payout, index 5 | One complete recovered Payout bundle per Artist. |
| Consent, index 6 | One complete direct-policy bundle per collection. |

Every journal occurrence must belong to a selected Artist and, when collection
scoped, its selected collection. Original global order, duplicate occurrences,
native indices and owner clocks remain intact. Filtering a journal and
renumbering it does not produce a valid partition. Global document/signature
maps may share identical content; conflicting content rejects.

Only Identity carries the global nonce inventory. Each Artist's local lanes map
exactly once into that inventory in increasing global insertion order. The union
preserves every indexed prefix and all 32 ancestor words. Local lanes can be
empty when the complete union still matches. Principal, rotation-acceptance and
estate-activation keys retain their original, distinct ABI hash recipes.

All Identity rows agree on the full timing bundle and registration counter.
Current authority addresses are nonzero and distinct. The global registration
counter equals the number of Artists. These shared values are installed once,
and every unique Artist and collection lane is activated once by the contract.

Pure tuple, partition and nonce checks are local validation. The original
Prepared producer and Registry execution remain responsible for complete
cross-owner semantic admission, including historical authorizations.

## Prepare and simulate

```js
const capture = await captureArtistRecoveredMultipleHydration(
  provider, deployment, caller, request, { blockTag, gasLimit }
);
const checked = await simulateArtistRecoveredMultipleHydration(
  provider, capture, { blockTag: laterBlock, gasLimit }
);
```

The caller is nonzero and permissionless; native value is zero. A draft may use
zero semantic inventory only while collecting the read-only certificate. The
final mutation contains the exact computed inventory. An existing nonzero
expectation must match and cannot be silently replaced.

Deployment inputs pin both original suites and the complete reviewed preparation
library/dependency roster. The two-argument Prepared library selector is
`0x72c84763`, retained from the nominal compiler witness. It is a library call,
not a new ordinary wallet entry point. Caller-supplied runtime hashes are trust
inputs; their presence alone does not authenticate deployed source or link maps.

Capture retains complete source inventories, provenance, publications, replay
aliases, nonce lanes, timing and external guards at an explicit block. Every
Artist and collection needs its genuine destination history/lane proof. The
source needs its original seal naming the successor. Registry simulation is a
separate call against the exact finalized Request. It does not reserve state or
guarantee execution gas, including inside a Safe.

`inspectArtistRecoveredMultipleHydrationCurrent` performs a fresh capture and
simulation for current import eligibility. A completed import is not eligible
for replay. This read does not establish enduring post-import Artist authority.

## Historical receipts and Safe transport

```js
const receipt = await reconcileArtistRecoveredMultipleHydrationReceipt(
  provider, checked.capture, transactionHash,
  { execution: "safe", expectedSafeTxHash, nonce, safeCodeHash }
);
```

Direct execution uses `{ execution: "direct" }`. Safe execution requires the
exact ordinary single CALL with zero outer and inner value. Reconciliation
checks all ten Safe transaction fields, the independent transaction digest,
runtime pin and immediately prior/end-block nonce. Multiple Safe nonce changes
in the same block fall outside this bounded receipt profile. The shared Safe
planner's review hash is a separate identifier from the Safe transaction digest.
Safe implementation and owner signatures are not independently verified here.

`inspectArtistRecoveredMultipleHydrationHistory` exposes the same historical
receipt check. It reproduces the retained capture and prior-block import context,
then joins the exact operation-60 header, ordered Archive pages and seven owner
transitions at the receipt block. The reviewed source and preparation runtime
roster is checked again at that block. Today's source authorizations do not
replace original historical facts.

Immutable imported prefixes can establish the original import even when later
writes in the receipt block advance an owner's revision. Registration counter
and nonce-index equality apply at the exact Identity import revision. The result
does not claim current authority. Private lane activation and complete private
semantic installation have no independently verified readback in this client;
their result flags remain false. No synthetic native receipt is created for an
original preparation or execution mutation that lacked one.

## Bounds and evidence

The aggregate permits 1–128 Artists, 1–128 collections and at most 128 policy
selectors in total, with at least one dimension greater than one. Existing
[provenance, allocation and gas bounds](current-artist-recovered-hydration.md#finite-transport-and-validation)
also apply. A protocol-valid graph can exceed the client's finite limits.

The retained fixture authenticates every ABI167 input literal against raw Git
and keeps complete ordinary ABIs, nominal library objects, source closure and
profile documents. Nominal enum-to-value adapters have separate ordinary ABI
witnesses; nominal library selectors are never relabeled as wallet selectors.
Fixture inclusion does not itself broaden supported client behavior.

Build, strict TypeScript, pure-client and compiler checks pass for this batch.
The 20 RPC/Safe workflow groups pass in bounded named partitions against client
implementation `4cd89d360`. These use compiler-encoded mock responses and do not
execute Solidity or a deployed Safe. Actual contract/Safe execution, runtime
provenance, transaction rollback, linked deployment capacity, whole-system gas
and release acceptance remain separate integration work.

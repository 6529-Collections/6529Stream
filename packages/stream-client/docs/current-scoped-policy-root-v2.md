# Scoped full-policy roots and original Artist consent

This additive client profile targets ABI129 source
`896899f7ca4130f86e066587f780a3b1f755a25d`, tree
`743efae1136e5742cb57c9e477080bd1c6aca5aa`. It follows the
[root-free scoped publication](current-scoped-policy-publication-v2.md) for
TOKEN, RELEASE and SEASON. It prepares original Artist operation-17 consent
and adoption of the exact scoped V2 root by the original Metadata Router.
Reference publication, render-critical inventory, archive coverage and finality
remain separate ceremonies.

## Client sequence

The package exports the pure helpers from `current-scoped-policy-root-v2` and
the observed workflows from `current-scoped-policy-root-v2-workflow`.
`prepareScopedPolicyRootV2Call` prepares either original write from supplied
facts and returns `factsVerified=false`. Use the workflow to read and bind the
actual source, publisher, Artist authority and replay state.

For signing before capture, prepare its `recordContentConsent` request with
`newFamilyStateHash: preview.nextFamily`, the reviewed signer/authority class,
nonce and deadline. The returned `consent.payload` contains the original
EIP-712 signing fields and `consent.digestCall` targets the original Registry.
Supply the resulting signature to consent capture; that step checks the
Registry digest and current authority/replay facts.

Supply a `ScopedPolicyRootV2Deployment` with the actual chain ID; Core, Router,
Metadata, Finality and provider runtime pins; the original
`CurrentArtistDeployment`; and reviewed linked-library pins grouped as `root`,
`snapshot` and `artist`. Artist components retain their original sixteen-entry
order. Zero-based component 9 is Core and component 12 is the Router. Pins require reviewed
deployment and link evidence; values supplied by the caller do not prove it.

The snapshot endpoint is selected through the actual Finality/provider route.
This root workflow authenticates that route, the snapshot's `requireCurrent`
and its retained publication bytes. The complete-graph requirement of the
earlier publication workflow is not an additional root-adoption requirement.

```ts
import {
  previewScopedPolicyRootV2,
  captureScopedPolicyRootV2Consent,
  captureScopedPolicyRootV2,
  simulateScopedPolicyRootV2,
  reconcileScopedPolicyRootV2Receipt,
} from "@6529/stream-client";

// Deployment pins, callers, publication and block numbers come from reviewed
// deployment evidence and the intended transaction. All reads use a concrete block.
const preview = await previewScopedPolicyRootV2(
  provider, deployment, publisher, publication, { blockTag: previewBlock },
);
// Review preview.nextFamily, then authorize that exact collection-wide value.
const consent = await captureScopedPolicyRootV2Consent(
  provider, preview, consentCaller, { signer, nonce, deadline, signature },
);
await simulateScopedPolicyRootV2(provider, consent, {
  blockTag: consentSimulationBlock, gasLimit: consentGasLimit,
});
// Submit consent.prepared.call through the selected wallet/Safe outside this client.
await reconcileScopedPolicyRootV2Receipt(provider, consent, consentTransactionHash, {
  execution: "direct",
});

// Capture again after the original consent is mined; any changed family needs review.
const root = await captureScopedPolicyRootV2(
  provider, deployment, publisher, publication, { blockTag: rootBlock },
);
await simulateScopedPolicyRootV2(provider, root, {
  blockTag: rootSimulationBlock, gasLimit: rootGasLimit,
});
// Submit root.prepared.call, then reconcile the independently observed transaction.
const mined = await reconcileScopedPolicyRootV2Receipt(provider, root, rootTransactionHash, {
  execution: "safe", expectedSafeTxHash,
});
```

Choose `execution: "direct"` or `execution: "safe"` for each actual transaction.
Safe reconciliation additionally requires its independently obtained transaction
hash. Neither capture nor simulation sends a transaction. Both stages recheck
the saved observation and refuse changed facts; a successful `eth_call` remains
simulation evidence only. The provider must support historical calls and code
reads at the requested concrete blocks.

## Original calls and roles

| Host | Call | Purpose |
| --- | --- | --- |
| Router | `previewScopedPolicyContentRootPublication(publication, publisher)` | Read the exact next collection-wide CONTENT_ROOT family |
| Artist Registry | `contentConsentDigest(terms, authorization)` | Read the original operation-17 digest |
| Artist Registry | `recordContentConsent(terms, authorization)` | Record the Artist's original content consent |
| Router | `publishScopedPolicyContentRootPublication(publication)` | Consume that exact stored consent and append the root |

Both writes are zero-value CALLs. The Artist signer, actual consent caller and
root publisher have separate roles. A Safe can occupy one or more of those
roles, but its transaction envelope does not supply a missing grant or consent.

The root publisher needs an enabled original Metadata SNAPSHOT family grant
with nonzero revision: collection class 7 first, then global class 8. The
previous snapshot publication has its own grant requirements. Root adoption
does not create or refresh the earlier snapshot.

## Authenticate the actual source

The original Core pointers select Artist, Router, Finality and Metadata.
Finality selects a pinned provider, and that provider selects the exact scoped
snapshot host and runtime hash. The publisher cannot substitute a snapshot
endpoint. The provider must advertise the original four-getter V2 snapshot
capability and correct profile; its factory-binding interface is a distinct
capability.

The Finality read budget is at least 50000 and fits uint32. The provider's
scope-validation budget is at least that read budget and also fits uint32.
The original source uses the latter budget for scope-dependent snapshot
identity reads. A getter name or matching supplied runtime hash alone does
not establish the full source identity or deployment provenance.

Adoption requires an existing unfrozen collection, artwork freeze mode NONE,
the exact current snapshot record and revision, and canonical retained snapshot
bytes. Its eleven dependency pins, complete source, covered output and genuine
source factory must agree. The current accepted or sanctioned Artist binding
must match the locked ArtistPresentation retained by the snapshot.

The source also requires the exact active RAW_BYTES output, leaf, root and
canonicalization definitions. Retained source documents and current registered
documents serve different checks. Reformatting JSON or adding a newline changes
their committed bytes.

## The consent signs a collection-wide family

The publication contains the full scope, expected predecessor, snapshot record
hash, uint64 snapshot revision and exact UTF-8 manifest URI. The URI must be
nonempty and satisfy the original safe-URI rules within 2048 bytes.

Three commitments have separate purposes:

| Commitment | Meaning |
| --- | --- |
| Root state hash | Prepared root record and V2 binding, with state hash, consent and publication time cleared |
| Next CONTENT_ROOT family | Original legacy family plus the next collection-wide scoped aggregate |
| Mined root record hash | Completed record, V2 binding and the publication's historical aggregate |

Operation 17 signs the second commitment returned by the actual Router preview.
An individual root state hash is not a substitute. Another scope's root or a
legacy collection root can change that family while this scope's head stays the
same. Recapture and review the resulting family before signing or publishing.

The original EIP-712 domain is the actual Artist Registry, name
`6529StreamArtistRegistry`, version `1`, and the actual chain ID. The
`StreamArtistContentConsent` fields are Core, metadata contract, collection ID,
family ID, new state hash, nonce and uint64 deadline. Here the metadata contract
is the actual Router and family ID is `keccak256("CONTENT_ROOT")`.

Nonce zero is valid. The deadline is inclusive. Direct authorization means the
actual caller is the current signer and the signature is empty; that path also
requires the original next-unused nonce. An empty ERC-1271 proof can be relayed
where the original contract admits it. Signature validation remains an original
contract decision. This client bounds the signature at 4096 bytes.

The scoped root consumer accepts original consent authority classes 1 and 3.
The coherent root client restricts consent preparation to those classes.
Consent and write capture require an accepted binding in consent mode 1 or 2,
with the original simple collaborator policy: mode 0, threshold 0, at most 32
collaborators and every collaborator accepted. Richer collaborator policies
need their separate client flow. Class 3 requires current CONTENT capability
128 when preparing new consent.
The original operation-17 creation surface has additional authority behavior
outside this root workflow. No new delegated operation or replay map is created.

## Preserve original Artist records and replay

The original Onboarding Registry and Coordinator retain their seven-owner
suite. Operation 17 observes the original owner mask `0x57` and mutates Identity
and Consent under mask `0x44`. Archive evidence does not become authority.

Consent reconciliation must join the original signer/binding/terms, actual
mined observation time, native owner records, payload catalogs, replay state
and Archive entry. An authorization deadline is not the recorded observation
time. Living-authority activity and dormancy events follow their actual source
conditions.

Identity advances once for operation 17 while its record-chain tip remains
unchanged. A conditional dormancy cancellation can add native operation 42 at
that same revision. Estate and unavailability activity events can also precede
Consent's operation-17 record. These conditional effects do not create another
owner commit or Archive operation. The client exposes
`privateIdentityActivityIndependentlyReconstructed=false`; it does not claim to
reconstruct private activity counters independently.

Before root publication, the exact stored consent must still be consumable for
the current binding and family. The Router preserves its original
`firstReleaseRatification`, content-evolution and consumed-consent accounting.
The Registry's ratification getter and Consent owner's same-selector getter
have different output layouts and must be decoded with their respective ABIs.

The root worker checks its source twice around authorization. It refuses a
changed prepared record, binding or next family. Its commit requires nonzero
consent, including when the generic content-authority worker has an earlier
pre-mint shortcut.

## Mined receipts and historical roots

The original root event sequence is:

1. `ScopedContentRootPublished`, schema 2, with completed record and historical
   collection aggregate.
2. `ScopedPolicyContentRootBindingPublished`, schema 2, with the exact V2 binding.
3. `ArtistContentConsentApplied`, schema 1, with the resulting complete Router
   content state.

Root publication creates no new Store payload. Safe receipt evidence additionally
joins the exact inner CALL and independently obtained Safe transaction hash to
a successful execution event after the original protocol events.

Reconciliation attributes the transaction against the saved capture, preceding
block and end-of-transaction-block observations. It deliberately refuses
unrelated same-block owner or root progress that makes that attribution
ambiguous. Failure to reconcile is not itself proof that a transaction failed.
The receipt block must be strictly later than the capture block.

The root record getter does not return its historical aggregate. Retain the
original publication event and its transaction/log location. A later aggregate
getter cannot reconstruct the hash of an earlier record.

`inspectScopedPolicyRootV2History(reader, historyDeployment, recordHash,
{ transactionHash, logIndex }, { blockTag })` authenticates the retained record,
its original inner state hash and the event's historical aggregate. Its separate
deployment includes chain ID, Core and Artist Registry addresses, the Router
runtime pin and linked dependencies. It checks the event transaction/block and
the V2 companion binding event where applicable, without requiring today's
publisher grant or source route. It returns `currentnessChecked=false`.

`inspectScopedPolicyRootV2Current(reader, deployment, scope, { blockTag })`
authenticates the current V2 head, full recorded scope, snapshot and binding,
then checks the actual provider's `scopedContentRoot` result. It returns
`currentnessChecked=true` and `historicalAggregateAuthenticated=false`; use the
historical inspector with the original event location for the latter check.
Neither inspection establishes finality.

V1 and V2 share the original scoped head and collection aggregate while retaining
their own record interpretations. An all-zero V2 binding can identify V1 only
after the root record is known to exist. Unknown nonzero profile tags refuse
interpretation. Full recorded scope equality matters because TOKEN's subject
formula omits the collection ID.

Historical evidence remains distinct from current admission. A retained record
can survive later source, authority or grant changes. Historical checks must
not silently rerun today's authorization or decode a V1 snapshot as V2.
Current producer admission does not establish finality.

## Client bounds and refusal evidence

The pure client permits a 2048-byte UTF-8 URI, 4096-byte signature and
16384-byte encoded value or call. The workflow bounds ordinary RPC bytes at
2097152, outer transaction calldata including a Safe envelope at 81920,
runtime code at 131072 and receipt logs at 4096. Each log has at most four
topics and 65536 data bytes, with at most 1048576 data bytes across the receipt.
Payload catalogs are bounded at 16384 entries. Simulation gas must be positive
and at most 100000000. Each linked-dependency list allows at most 256 entries;
definition bytes are bounded at 8192, Archive evidence at 24575 and its
STOP-prefixed carrier at 24576. These are explicit client limits, not new
protocol limits.

`observeScopedPolicyRootV2Refusal` revalidates the saved capture, then observes
the exact call at a requested later block and gas limit. It distinguishes an
execution revert from an RPC failure and reports whether retained state reads
were unchanged. Its `rollbackProven=false` flag remains false: read-only calls
cannot prove rollback of a mined transaction.

## Evidence boundary

The fixture retains complete ordinary compiler ABIs, unchanged raw nominal
library ABIs, exact imported source closure and interpretation documents from
the same frozen commit. Library functions are source/type witnesses, not wallet
endpoints. Every compiler input literal matches its Git blob without line-ending
normalization.

Client checks and mocked RPC/Safe envelopes establish only their stated scope.
Actual native execution, actual Safe behavior, rollback, gas/capacity, deployment
and finality acceptance need their own evidence. The integrator's newer
preservation architecture remains separate from this explicit original profile.

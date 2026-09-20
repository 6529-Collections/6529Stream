# Tagged full-policy VIEW adoption

This additive client profile targets ABI125 source
`00686b799ccf60713a0a30e1e81fca0c7281912d`, tree
`1778378447b903f7d5ebef38d77782881438e656`. It follows the actual Metadata
Router's full-policy VIEW adoption and serving methods. Original V1 documents,
records, renderer domains and previously published client evidence retain
their original interpretation.

## Existing deployment prerequisites

Use the selected Core, Metadata, Router, Artist, finality Registry and its
actual provider. The provider owns the original declaration/membership binding
and the supplemental scoped-policy factory binding. A caller-supplied source
set cannot replace those facts.

Complete the original VIEW membership and ordered coordinator inventory, then
prepare the genuine source set through the scoped-policy factory. Deploy the
matching V2 renderer and its fixed formatter. Its constructor retains the full
ordered coordinator policies and the exact 23-word policy binding. Constructor
success, an ERC165 response or a binding getter does not establish governed
STATIC renderer admission. The original Registry version, manifest, read-set,
output evidence and active interpretation documents remain prerequisites.

The source factory supports VIEW. At this source revision, the scoped-policy
snapshot, reference, render-critical inventory and archive publication paths
support TOKEN, RELEASE and SEASON. Substituting the VIEW enum into those
publication calls does not create a VIEW publication workflow. VIEW checkpoint
serving and the complete VIEW finality ceremony remain separate source work.

## Exact adoption and authority

The V2 writer keeps the original seven-field Input:

| Field | Meaning |
| --- | --- |
| `scope` | Full VIEW scope, with nonzero collection and scope ID and zero token ID |
| `viewId` | The declared alternate view, distinct from the membership scope ID |
| `viewRecordHash` | The exact original declaration |
| `expectedPrevious` | The authenticated shared scope head |
| `rendererRegistry` | The actual governed renderer Registry |
| `rendererVersionKey` | The admitted exact renderer version |
| `expectedSourceHash` | The original V2 commitment to source facts and full policy binding |

`previewPolicyViewAdoption(input, actor)` returns the prospective original
RENDERER_CONFIG family state and authenticated source hash. Preview may start
with a zero expected source hash; `adoptPolicyView(input)` requires the resolved
nonzero hash. The writer is nonpayable. A Safe CALL makes the Safe the actor;
its signers do not replace that caller.

The actor needs the Metadata IDENTITY-family writer grant selected by the
original precedence: class 7 before class 8, collection-specific before global
within each class. That grant is separate from Artist consent. Adoption also
requires already-recorded original Artist operation-17 consent for the actual
Router and the exact prospective family state, plus the original evolution,
ratification and consumed-record checks. A consent row must satisfy the
consumer's authority checks; its existence alone is insufficient.

`taggedPolicyViewV2ConsentTerms` returns the original consent terms only. The
existing [`prepareArtistContentConsent` helper](../src/current-manifests.ts)
retains its own principal signing and call profile; its actual Registry digest,
nonce and authority need separate verification. This workflow observes the
stored consent used by adoption. Adoption emits the original
content-application evidence; it does not create a new Artist Archive consent
record. A delegated-only ceremony must not be substituted for a principal
consent path.

Adoption checks source and mutable state, performs original op17 authorization,
then checks source and family state again before committing. A callback or
late failure cannot legitimately leave a partial new record, tag, scope head,
aggregate or consent application. Client simulations and retained-state
observations need to state their scope; they do not establish complete EVM
rollback by themselves.

## Developer workflow

The public helpers are exported from `@6529/stream-client`. Reads use an ethers
provider with explicit numeric block tags. Runtime pins must come from reviewed
deployment and library-link metadata for this source profile. Matching a
caller-supplied hash proves consistency with that pin, not its provenance.

| Helper | Result |
| --- | --- |
| `preflightTaggedPolicyViewV2` | Selected route, declaration, governed renderer, complete policy source, actual writer grant and original preview; returns the consent terms |
| `captureTaggedPolicyViewV2` | Preflight plus the already-recorded op17 evidence, current content state and continuity facts; returns exact caller, target, zero value and calldata |
| `simulateTaggedPolicyViewV2` | Revalidates the saved and requested blocks, then calls the actual `adoptPolicyView` with the captured caller and explicit gas limit |
| `reconcileTaggedPolicyViewV2Receipt` | Verifies a mined direct or Safe transaction against the capture and original stored results |
| `observeTaggedPolicyViewV2Refusal` | Observes the captured call's refusal and selected retained state at one block; distinguishes an execution revert from an RPC failure |
| `inspectTaggedPolicyViewV2History` | Authenticates an exact retained V1 or V2 record and STOP carrier without querying current admission |
| `renderTaggedPolicyViewV2` | Executes one of the four original current or historical Router output methods |

For an existing deployment and recorded consent:

```ts
const capture = await captureTaggedPolicyViewV2(
  provider, deployment, actor, input, { blockTag: reviewedBlock }
);
const simulation = await simulateTaggedPolicyViewV2(provider, capture, {
  blockTag: simulationBlock,
  gasLimit: reviewedGasLimit,
});
// Review capture.prepared.caller and capture.prepared.call before submission.
// A simulation result does not reserve the source, grant or consent.
```

The adoption deployment includes pins for Core, Router, Artist facade,
operation coordinator, consent owner, finality Registry, provider, Metadata,
Schemas, Store, Views, membership, module and renderer registries, renderer,
policy factory, source set, inventory, formatter and live attribution.
`linkedDependencies` adds the reviewed fixed library dependencies. History has
a smaller deployment shape: chain ID, Core address, Router pin and fixed
history-reader dependencies. Serving adds the Core runtime hash and actual
fixed routing dependencies. These lists must reflect the deployed links;
supplying an incomplete list cannot establish their completeness.

Captures own and freeze their inputs. Revalidation authenticates the original
saved block header and requires the captured state to equal the requested
block's state. Receipt reconciliation uses the block immediately before the
transaction and exact end-block head, aggregate, family and content state.
The receipt block must be strictly later than the captured block.
Consequently, a legitimate intervening update or later same-block adoption or
content change may cause refusal. Re-capture and review such activity; a failed
reconciliation is not by itself evidence that the transaction failed.

Safe reconciliation requires `execution: "safe"` and an independently obtained
`expectedSafeTxHash`. The outer transaction must target the captured Safe; its
inner operation must be the exact zero-value CALL. Both original legacy and
indexed Safe success-event forms are supported. Direct reconciliation uses
`execution: "direct"`. Neither helper broadcasts a transaction.

## One history with two explicit profiles

V1 and V2 share the original scope heads, immutable carrier records and
collection aggregate. `viewAdoptionProfile(recordHash)` first requires an
existing carrier. Only then does zero mean V1. The accepted nonzero V2 tag is
`keccak256("6529STREAM_STATIC_ADOPTED_POLICY_VIEW_V2")`; other nonzero tags
refuse. An unknown record is never an implicit V1 record.

The V2 payload context is
`keccak256("STREAM_ADOPTED_POLICY_VIEW_CONTEXT_V2")`. V2 source, prepared-state,
aggregate-transition and record hashes have their own domains and explicitly
bind the tag. The enclosing original RENDERER_CONFIG family wrapper stays
unchanged. Before the first VIEW write, it returns the original family hash.

Authenticate the full canonical outer record under its saved profile before
reading its revision or interpreting payload bytes. Recompute its hash with
the record's own hash field zeroed. V1 to V2 to V1 remains one lineage; a V1
successor does not decode its V2 predecessor's executable payload as V1.

Scope revision and collection aggregate revision are distinct: another scope
can advance the collection aggregate without advancing this scope's history.
Likewise, the approved next family hash differs from the full resulting content
state recorded by `ArtistContentConsentApplied`. Receipt verification must join
the correct original values rather than substitute one for another.

## Separate currentness and rendering checks

Adoption eligibility, full source eligibility and serving answer different
questions. Adoption requires the writer grant and the original mutable-state
and Artist checks. Full source eligibility checks the current genuine factory,
set and ordered policies. Rendering uses its retained renderer and the original
serving predicates; it does not rerun adoption authority or silently add a
current factory-selection requirement.

The four original Router output calls are `tokenJSONForView`,
`tokenHTMLForView`, `historicalTokenJSONForView` and
`historicalTokenHTMLForView`. Current calls take the membership scope ID and
select its current head. Historical calls take an exact retained record hash.
The Router chooses the closed V1/V2 decoder from its stored tag; the caller
cannot supply an arbitrary renderer or decoder.

Current serving rejects burned tokens. Historical serving may retain an
original burned token's identity and source. Existing completed or burned
tokens must have the original permanent collection serial and matching
lifecycle; prepared, unknown and foreign tokens refuse. Code identity and
scope membership still matter when reading history.

The coordinator is the token's original `coordinatorAtMint`, with its retained
runtime and policy. Replacing the collection's current coordinator does not
rewrite that fact. Explicit-policy rendering checks all twelve original policy
words. Terminal DISABLED or optional ASYNC NOT_REQUIRED output keeps zero seed
and request key and reports terminal, not finalized. Required asynchronous
status 5 reports finalized. The legacy branch requires its original finalized
status and reports no invented full policy. Live Artist attribution stays live.

## Finite client limits

The workflow permits up to 256 linked dependencies, 256 coordinator policies,
128 renderer targets and 128 renderer reads. General RPC results are capped at
1 MiB and pinned runtime reads at 128 KiB. Receipts allow 4,096 logs, at most
four topics and 64 KiB per log, and 1 MiB of aggregate log data. Outer receipt
calldata is capped at 1 MiB plus 16 KiB. The explicit execution gas limit must
be positive and no more than 100 million; this client bound does not establish
the deployment's accepted transaction gas ceiling.

Original payload bounds remain 40,960 bytes across five 8,192-byte chunks;
retained records and interpretation documents are capped at 8,192 bytes.
Each STOP carrier runtime adds its one-byte prefix, for a cap of 8,193 bytes.
Payload name, description, image URI and script limits are respectively 128,
8,192, 2,048 and 24,576 bytes. Rendered output is capped at 262,144 UTF-8 bytes
and its ABI envelope at 262,208 bytes. Oversized or noncanonical responses
refuse before being treated as evidence.

## Compiler and execution evidence

The fixture retains complete ordinary compiler ABIs, the exact source import
closure and frozen interpretation documents. Its generator checks all 3,146
ABI125 input literals against their exact committed Git blobs. No line-ending
normalization is performed during that comparison.

Fixed Solidity libraries have nominal method signatures. Their compiler ABIs
and method identifiers are retained separately without rewriting them into
ordinary contract tuples. Test helpers expose only their original event
fragments for delegate-emitted event decoding. Wallet plans target the actual
Router, not those library methods. Formatter code and its admitted transitive
read-set remain part of the real deployed configuration.

Direct and Safe receipts must join the original caller, zero native value,
exact calldata, independently obtained Safe transaction hash, event order,
immutable carrier bytes, profile, record hash, head, aggregate and consent
application. Historical delivery does not itself prove current source
eligibility or complete finality. Source/ABI checks and mocked RPC/Safe-envelope
tests qualify client behavior; native execution, actual Safe behavior, complete
rollback, deployed gas limits and release acceptance remain separate evidence.

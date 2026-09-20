# Full-policy construction and staged publication

This recipe constructs the actual current 37-role graph with original COLLECTION,
scoped STATIC V1, COLLECTION full-policy V2, and TOKEN/RELEASE/SEASON full-policy V2
sources. VIEW uses its separate implementation. Construction and source selection
do not establish completed archival coverage or finality.

The source batch adds actual-current construction tests. Native execution, product
sizes, cold call budgets, complete publication and finality acceptance remain
pending. Do not use the provisional test budgets as launch settings.

The additive [publication ceremony fixture](full-policy-publication-v2.md) uses
complete STATIC output with explicitly larger fixture-only budgets. It records
the transaction-envelope constraint and a live-sanction/output dependency cycle;
the construction-only caps below do not establish complete-output acceptance.

## Why COLLECTION needs a factory

The original COLLECTION policy source set requires a nonempty minted inventory
and frozen original entropy policies. Its runtime commits those actual facts;
the checkpoint commits that runtime, and the output manifest commits the
checkpoint runtime. A fixed output runtime cannot generally be derived before
the first mint merely by predicting addresses. Actual mint consent already needs
the real Artist Coordinator, Finality Registry and evidence provider.

`StreamPolicyPublicationFactoryV2` breaks this construction dependency by fixing
the entire recipe before any mint. Its seven later children are the original
COLLECTION readiness, checkpoint, output, snapshot, reference, inventory and
bundle products. It accepts no implementation address from the caller. Empty
policy inventories remain invalid.

## Constructor sequence

Use [StreamCurrentFullPolicyGraph](../../script/current/StreamCurrentFullPolicyGraph.sol)
with the existing [current graph helper](../../script/current/StreamCurrentFinalityGraph.sol).
The original default helper still builds its original provider and discovery.
The additive helper selects its literal linked creation templates before any
late runtime is calculated.

1. Construct the actual foundation, Artist facade and owners, Router, Metadata,
   SchemaRegistry, Store, membership and coordinator inventory. Reserve the
   original Registry, Coordinator, selectors, inventory and bundle CREATE slots.
2. Construct original source hosts and real Artifact/External coverage hosts.
   Artifact construction pins the reserved Registry; operative coverage still
   requires that actual Registry to be selected by Core.
3. Derive the provider, adapter, discovery, Registry, Coordinator and selector
   runtimes from the native compiler artifacts, exact library links and all
   immutable values. The provider's factory bindings are constructor-only
   storage and therefore do not introduce another reciprocal runtime cycle.
4. Construct the genuine STATIC selection/checkpoint/output hosts, scoped V1
   snapshot/reference/inventory/bundle hosts, both entropy source factories,
   and both publication factories. Their recipes retain exact predicted late
   Coordinator/selector pins. They perform no inventory or publication reads.
5. Deploy the new provider, Core adapter, serving adapters, new discovery, actual
   Registry and actual Coordinator through the original verified CREATE slots.
   Discovery receives the provider's computed bindings and configuration hash.
6. Complete the original governed selections and deploy original selectors,
   inventory and bundle. Compare all actual dependencies to their predicted
   full runtimes. Retain the original graph checkpoint and the companion
   checkpoint before proceeding.

The STATIC V1 configuration has its own actual output/checkpoint at roles 6/7,
in addition to its snapshot/reference/inventory/bundle replacements. The new
inheritance base admits those exact differences. The original provider bases
and their behavior remain unchanged.

Both creation owners use identical appended product identifiers; existing enum
values remain stable. The native preparation roster includes the new products.
The original helper enforces argument-inclusive initcode at 49,152 bytes and
actual runtime at 24,576 bytes. A successful ABI check cannot prove those limits.

## Provisional nested read budgets

The new helper uses the existing current-graph 3,000,000 render cap for both
STATIC checkpoints. An 8,000,000 render cap cannot sit behind an output reader
that forwards at most 4,000,000 or 8,000,000: the checkpoint reserves
`childCap + childCap / 63 + 100,000` before the nested render. The 3,000,000
choice removes that definite failure; it is not a measured rendering allowance.
The Router's internal renderer helper clamps its larger nominal cap to available
gas, so that nominal cap is not a strict minimum at this edge.

The following values are millions of gas. They apply only to this new recipe;
original graph defaults remain unchanged.

| Boundary | Scoped STATIC V1 | COLLECTION/scoped full-policy V2 |
| --- | --- | --- |
| Checkpoint ordinary read / render | 2 / 3 | 6 / 3 |
| Output read into the complete checkpoint | 4 | 8 |
| Snapshot source read into output | 6 | 12 |
| Reference read into snapshot | 8 | 14 |
| Inventory read into snapshot / reference | 10 / 14 | 16 / 20 |
| Provider component / complete source | 16 / 24 | 16 / 24 |

The policy source factory's 3,000,000 inventory cap encloses the original
Coordinator inventory's 2,000,000 membership cap. The publication recipe reads
the source factory with 8,000,000; the graph binding supplies 12,000,000 and the
discovery provider call supplies 20,000,000. The actual Registry uses its original
30,000,000 configured component budget, including the Router's output-validation
path. The new provider reader derives the current inventory plan with its
aggregate 24,000,000 source budget, not its 500,000 scalar-getter budget.

These numbers clear the immediate strict forwarding inequalities. For example,
a nested 20,000,000 read needs more than 20,417,460 gas before that call. They do
not prove that preceding work, repeated rows, large returned bytes, cold storage,
or the entire transaction fit. Completion rerenders finite retained inventories;
larger histories can still fail closed. Governed increases of a child budget may
also require increases at its callers. Measure the complete intended graph before
choosing launch budgets; constructor admission and ABI checks are insufficient.

## Factory-mode catalogue and root admission

`IStreamFinalityFactoryProfileSourcesV2` has a distinct capability and explicit
profile discriminator. Only indexes 0 and 1 are fixed host entries. COLLECTION
policy V2 resolves through `collectionPolicyPublicationBinding()`; scoped V2
resolves through `scopedPolicyPublicationBinding()`. Neither factory is presented
as a snapshot or reference host. The old three-static-profile capability and
no-argument output binding retain their original meaning on the old providers.

The six-field COLLECTION binding stores the factory address/runtime, recipe
hash, source-factory dependency hash, graph read budget and provider-computed
configuration hash. The constructor input configuration hash is zero. Read back
the complete accepted binding after construction and supply it to discovery.

For COLLECTION root publication, the Router explicitly checks the new binding
capability and resolves the canonical `COLLECTION(collectionId, 0, 0)` graph.
An advertised capability that fails never falls back to the fixed-output path.
The resolver rechecks the exact current plan, original source mapping, graph ID,
scope and all seven child runtimes. It does not read the root it will publish.
The existing output/checkpoint/profile/archive/schema/Artist route checks then
run unchanged. The root publication fields, 17-word binding, operation-17 consent,
lineage and signing preimages retain their existing encodings.

## Governance and Safe activation

Keep the [full-v1 candidate](../../script/current/StreamFullV1Candidate.sol) at 37
roles. These factories and source hosts are explicit companion products; do not
invent numbered roles or register non-module helpers as modules.

Use [StreamFullV1ActivationPlan](../../script/current/StreamFullV1ActivationPlan.sol)
and [StreamFullV1ActivationPolicies](../../script/current/StreamFullV1ActivationPolicies.sol)
for the existing 21 module admissions and applicable configuration transitions.
Preserve exact runtime, interface, version and manifest rows. Use
[StreamGovernanceStagePlan](../../script/current/StreamGovernanceStagePlan.sol)
to save each observed batch before the actual threshold Safe publishes and
schedules it. Enforce the real delay, include the required SystemManifest tail,
and verify the action against the saved plan before execution or resumption.

Admit the exact existing profile/schema documents and narrowly scoped family
grants needed by the chosen publishers. Do not replace document bytes with
labels or substitute an unregistered profile. Publication and signing authority
remain separate from permissionless source indexing and child construction.

## Recoverable publication order

Save transaction receipts and each returned plan/record ID. Re-read current
eligibility before the next step; a saved historical ID is not a readiness cache.

| Stage | Actual operation | Resume condition |
| --- | --- | --- |
| Membership | Complete genuine mint/entropy lifecycle, then `scanCollectionTokens` and `beginInventory`/`appendInventory` | Current complete membership and original coordinator plan still match |
| Source set | Original policy factory `prepareSourceSet(scope)` | Exact `sourceSetForPlan` runtime and current selection; nonempty frozen policies |
| Children | Publication factory `prepareGraph(scope, maximumChildren)` in batches of 1–7 | Saved `graphForPlan` count/identities match; after seven, `requireCurrentGraph` succeeds |
| STATIC selection | Original selection checkpoint `begin(scope)` and bounded `append` | Exact current selection and frozen original configurations |
| Current output | Child checkpoint `begin(selectionId, salt)` and bounded `append` of actual bytes | `requireCurrentCheckpoint` re-renders every original row |
| Output archive | Store exact bytes; record actual Artifact/External receipts and fixity; complete output manifest verification | Current matching archive coverage and `requireCurrentManifest` |
| COLLECTION root | Existing Router preparation and exact Artist operation-17 publication | Current output graph, expected predecessor, publisher grant and consent |
| COLLECTION snapshot | Child `previewSnapshot`/`publishSnapshot`, then governed `lockSnapshot` | Exact root/output/source plan, saved receipt/revision and original lock |
| Scoped snapshot/root | Existing scoped V2 snapshot publication followed by its Artist-approved Router root | Exact scope-specific snapshot and root binding; no COLLECTION receipt cast |
| Reference | Prepare exact file inventory, publish the original reference observation, then governed lock | Current locked snapshot, complete original sample/package/archive checks |
| Preservation | Materialize the child's ordered render-critical inventory and complete its bundle coverage | Exact original record inventory and matching covered bytes |
| Finality | Original registered input manifest, Artist review/sanction, independently derived components and Registry flow | Every original current/frozen evidence gate, including Core and record locks |

Partial child creation is append-only and idempotent. A failed transaction rolls
back its child CREATEs and progress. Changed membership produces a different
plan and a new child graph; historical graphs remain readable. Never overwrite
old graph identities or treat `graphForPlan` as today's `requireCurrentGraph`.

The complete bytes, archival witnesses and Artist signatures for later stages
are external inputs to this construction recipe. The recipe does not fabricate
them or label a constructed child as a completed publication.

## Validation boundary

The new current cohort inherits eleven real 2-of-2 Safe activation scenarios
and adds six cases for acyclic construction, genuine empty-inventory refusal,
first paid mint and staged children, membership change, TOKEN separation, and
the explicit catalogue. Core, Finality, Artifact, Artist and the seven child
products are actual contracts; the fixture's external randomness, VRF, ARRNG and
delegation services remain declared doubles. These cases do not complete the
output archive/root/snapshot/reference/finality ceremony.

Separate focused cases cover the factory and provider/discovery boundaries.
Their typed substitutes are listed in their test comments. The older frozen
27-case run belongs to the previous scoped provider commit; it is not execution
evidence for this construction successor.

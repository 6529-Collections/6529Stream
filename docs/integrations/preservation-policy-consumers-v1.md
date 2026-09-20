# Preservation policy consumers V1

This additive source implements checkpoints, covered output manifests, snapshots,
references and render-critical inventories
of [ADR 0054](../adr/0054-explicit-non-sanction-preservation-rendering.md).
Native execution, product size checks and the composed publication ceremony
remain pending. Existing `Policy*V2` contracts, definitions and historical
full-output commitments retain their original meanings.

## Output and admission

The consumer reads the public `preservationTokenJSON` and
`preservationTokenHTML` methods of an explicitly admitted producer. The profile
excludes only the sanction lookup and its derived displayed state, record hash
and authority class. Artwork, executable code, token data, image, citation,
C2PA, entropy and other Artist facts remain part of the output. Live output
continues to expose sanction information separately.

The two new checkpoint hosts share one engine:

- `StreamPreservationPolicyContentCheckpointV1`: complete COLLECTION.
- `StreamScopedPreservationPolicyContentCheckpointV1`: complete TOKEN, RELEASE
  or SEASON, including the original scoped factory registration and current route.

Each payload names a preservation producer for its actual selected renderer.
This choice grants no authority: the original selected Registry must have the
exact immutable admission for that version, producer and fixed profile. Every
output row retains the complete producer binding and admission. Currentness
reuses the saved producer and rejects any changed binding or output. Different
members may use different admitted renderers; every original member remains
required in the same authoritative order.

`StreamPreservationPolicyOutputTypesV1.Binding` is exactly nine ABI words:

| Order | Field |
| --- | --- |
| 0–2 | Producer address, runtime hash, preservation profile |
| 3–4 | Core and Router |
| 5–6 | Original selected live renderer and runtime hash |
| 7–8 | Preservation attribution companion and runtime hash |

The binding domain is `6529STREAM_PRESERVATION_OUTPUT_BINDING_V1`. Its hash is
`keccak256(abi.encode(domain, binding))`. The first producer profile is
`6529STREAM_PRESERVATION_RENDER_V1`.

Every observed row calls its actual selected RendererRegistry:

```solidity
requirePreservation(versionKey, producer, profile)
```

The canonical 512-byte result contains the nine-word binding followed by the
seven-word admission: Registry address, Registry runtime, version key,
registration hash, read-set hash, analysis hash and golden-vector hash. The
consumer compares these identities to the actual selected row and observed producer.
The Registry must enforce original governed admission and the complete new
source/read roster. A capability claim, caller-supplied hash or original live
renderer analysis cannot substitute for that record.

Different tokens can retain different producers, renderers and Registry/version
admissions. Each output row therefore includes its own complete nine-word
producer binding and seven-word admission. Currentness reads it again and rejects changed evidence.

## Canonical sizes

| Value | Exact ABI size |
| --- | ---: |
| Producer binding | 288 bytes |
| Per-row admission | 224 bytes |
| Checkpoint Plan | 448 bytes |
| Output row | 1,152 bytes |
| Retained output Manifest | 608 bytes |
| Covered manifest header, including array count | 640 bytes |

The covered document is exactly `640 + 1152 * tokenCount` bytes. Its dynamic
array offset is exactly 608. The verified document binds the common Core, Router and preservation profile,
then every complete producer binding, admission and output row in authoritative
order. Alternate offsets,
trailing bytes, missing members and a V2 document relabeled as preservation
output are rejected.

The byte definitions are
[manifest schema](../schemas/preservation/preservation-policy-output-manifest-v1.schema.json),
[ABI encoding](../schemas/preservation/preservation-policy-output-manifest-v1.abi.json)
and [leaf interpretation](../schemas/preservation/preservation-policy-token-content-leaf-v1.schema.json).
The matching Solidity definitions register these exact UTF-8 bytes.

All current reads retain the complete original selection, membership, frozen
policy, retained identity and terminal/finalized entropy checks. They observe
every completed row again. Burned tokens remain members through their retained
identity; preservation serving does not assert current ERC-721 ownership. The
original image, full HTML and token-data byte joins remain required. Parent gas
starvation fails closed without reducing a configured dependency budget.

## Snapshots and publication order

The snapshot consumers preserve both existing dependency orders:

1. COLLECTION: output manifest → original Artist-authorized root → snapshot →
   reference → inventory → provider.
2. TOKEN/RELEASE/SEASON: output manifest → snapshot → original Artist-authorized
   root → reference → inventory → provider.

The integrator owns the shared Router and CONTENT_ROOT dispatcher. New root
bindings commit the common Router and preservation profile, complete ordered
output root and distinct schema/profile identities and retain the original operation-17 authorization, canonical
histories and consumed-content rules. The output root commits every complete per-row producer binding and admission. No existing locked root or profile is reinterpreted.

`StreamPreservationPolicySnapshotPublicationV1` authenticates the current
COLLECTION root and its complete 19-word preservation binding before publishing
the snapshot. `StreamScopedPreservationPolicySnapshotPublicationV1` authenticates
the complete current TOKEN, RELEASE or SEASON output and original scoped source
factory before its subsequent root exists. Neither accepts the other scope
family or an original full-output profile.

Both retain the original dual SNAPSHOT/IDENTITY grants, per-subject history,
immutable payload chunks and class-2 lock behavior. Their dependencies remain
832 bytes and receipts remain 544 bytes; distinct capabilities, domains and
schema bytes identify the new interpretation. The current manifest authenticates
every producer row through the complete output root. Historical payload access
does not imply that the same snapshot remains current.

New factory and provider binding interfaces identify the matching preservation
graph explicitly. Concrete factories create the seven matching children from
fixed recipes, with bounded resumable construction and runtime pins.

## References and inventories

The new COLLECTION and scoped reference publishers retain the exact snapshot,
current canonical root, original policies, runtime environment, ordered package
members and external capture coverage. Each sample retains the full nine-word
producer binding and seven-word admission. Its reader rejoins the original
Registry admission and current producer binding before comparing that saved
producer's JSON/HTML bytes. A reference sample is not complete membership.

Both new inventories preserve all five original token stages: output,
script, library, renderer and current citation/terminal profile. A mandatory
sixth stage retains the preservation binding, admission, full registration,
complete declared reads and original target roster, producer/attribution
runtimes, schema/analysis/golden documents and every target runtime. The token
cursor advances only after the last row of this stage. Roles identify the new
preservation JSON, HTML and image interpretation explicitly.

The original source, policy, membership, artwork, description, rights,
conservation, Artist authorization and archive requirements remain present.
Current reads and sealing retain complete current source checks and selected
document facts. Neither a typed boundary test nor a passed ABI check proves
the complete six-stage inventory or actual sanction ceremony.

Provider and graph-factory profiles must select only these matching consumers.

## Fixed graph and provider selection

`StreamFinalityFullPreservationPolicyEvidenceProviderV1` and its discovery
catalogue select the new COLLECTION or scoped factory through explicit
preservation capabilities. Root bindings carry 19 or 25 words, including the
common Router and preservation output profile. Unknown nonzero profiles,
malformed responses, foreign graphs and stale runtime pins fail closed.
Original static routes retain their original base-provider implementation.

Separate COLLECTION and scoped input manifest documents identify the new
interpretation. The provider retains all nine non-sanction component families,
the complete ten input joins, original entropy policy and full membership.
Sanction and archive evidence remain independently derived. Provider selection
does not authorize a producer outside its actual Registry admission.

The Collection graph uses the original generic bundle host. The scoped graph
uses a separate preservation bundle profile with the same complete ordered
occurrence coverage. Shared archive correspondence must include the exact new
snapshot and reference schema/canonicalization tuples. Construction and typed
boundary tests do not establish actual full-ceremony acceptance.

## One-time VIEW source binding

The same provider starts with VIEW pending. Its original COLLECTION and scoped
configuration stays fixed. After Finality and the actual preservation renderer,
VIEW checkpoint, covered manifest and root-free snapshot exist, the original
governance authority can bind that VIEW source exactly once through class-2
governance. This ordering avoids a constructor cycle between provider, Finality
and attribution without changing the original constructors.

The binding commits the snapshot, checkpoint and manifest addresses and runtime
hashes, a validation budget, the exact initial snapshot dependencies and the
executed action receipt. Validation checks all ten snapshot sources, their
runtime pins, common Core/Metadata/Router/schema/store/membership/coverage and
original authority. It does not require an existing current snapshot.

The three VIEW source getters fail while pending. Once bound, they authenticate
the bound capability, runtime pins and source identity. They are not complete
currentness verdicts. The source cannot be replaced.
Original governed snapshot gas increases remain bounded by the admitted
validation budget; they do not replace the recorded initial dependency tuple.
The independent COLLECTION/scoped source-configuration hash does not change.

Validation rejects nested caps that cannot satisfy the original strict call
forwarding margin (`outer > inner + inner / 63 + 10000`). This is a necessary
configuration check; repeated reads, return data and complete scope capacity
still require execution measurements. The three source getters themselves
retain their admission-specific checks and need measured caller read budgets.

The same governed proposal also commits the original six-word declaration
binding: Views, Membership, their runtime hashes and read/source budgets.
`viewSourceBinding()` returns that authenticated immutable roster with immediate
runtime pins; original adoption and current readers revalidate the selected
routes, module eligibility and complete source reciprocities before use. Views
is an eligible module selected by this binding, not a Core satellite pointer.
The VIEW policy factory is the exact constructor-pinned scoped factory from the
preservation recipe, with its original dependency commitment.

The advertised `IStreamViewRouteReadBudgetV1` profile returns the declaration's
signed read budget directly after binding. The integrator's fixed route readers
validate its exact profile, range, equality to the declaration and original
global Finality upper bound. An advertised pending or invalid capability fails.
Existing providers without the new capability retain their original budget.
This separates the VIEW route's scalar budget from the larger COLLECTION
component budget without weakening either scope's source checks.

### Capability checks and complete currentness

The provider validates the entire source graph when governance binds it. Its
three snapshot capability getters retain the exact receipt, original authority,
chain, initial dependency identity, bounded monotonic gas policy, five worker
pins, canonical configurations and configuration hashes. The fixed consumers
perform the following source checks before using the capability:

| Check | Required current consumer |
| --- | --- |
| Selected Metadata/Router, schema/store/membership/coverage reciprocities, checkpoint and serving identity, manifest profile | `Snapshot.requireCurrent` calls its source reconstruction, then `StreamViewPreservationSnapshotSourceReadsV1.current` calls `bindings` before reading evidence. |
| Manifest runtime, coverage/schema pins, checkpoint configuration | `Sources.current` calls `Manifest.requireCurrentManifest`; that method calls `_fresh`, which calls `StreamViewPreservationManifestReadsV1.pins`. |
| Original declared VIEW, adopted head, selected provider, full declaration binding, eligibility and policy source | Snapshot source reconstruction and manifest verification use `Checkpoint.currentSource`; its original policy reader reconstructs the actual adopted route and compares the complete source. |

The capability getters retain immediate declaration source runtime pins rather
than rerunning `Declaration.validate`. The actual constructor-fixed source
contracts retain their reciprocal identities; the original current route
rechecks mutable module selection and eligibility and the complete declaration
before use. Complete declaration validation remains mandatory at binding.

The duplicate `Sources.bindings` and `ManifestReads.pins` graph validations are
also extracted from the capability getter path; complete bind validation remains. A getter result must
not be treated as evidence that an adopted VIEW, output, snapshot or root is
current. No mutable currentness result is cached.

The actual recipe must declare and adopt the VIEW and publish its snapshot/root
before the original Artist STATIC lock and Core freeze. A separate genuinely
admitted renderer Registry can include the late VIEW serving contract in its
fixed roster; an earlier Registry's roster is not rewritten. The
[actual current VIEW recipe](current-view-preservation-ceremony.md) authors this
declaration/adoption, checkpoint, snapshot and root sequence, with an explicit
supplied-observation reference entry. Runtime acceptance, complete inventory,
finality and gas acceptance remain separate work.

The original full-output ceremony remains intact as the sanction-cycle
regression. A new ceremony must separately prove unchanged preservation
commitments through actual sanction, its exact archive join, original
finalization and confirmation. Legitimate non-sanction changes must still
invalidate currentness. None of these source additions proves that ceremony,
whole-scope gas acceptance, staged freshness or immutable current output.

# Adopted VIEW preservation output V1

This additive profile implements the VIEW producer and observational portion of
ADR0054. It is not the old live VIEW profile. Source and focused regression
recipes are authored; full governance, sanction/finalize/confirm, snapshot,
CONTENT_ROOT, reference and finality integration remain separate work.

## Public producer and independent admission

`StreamViewPreservationRendererV1` pins stable Core, Router and the preservation
attribution companion. It deliberately does not constructor-pin a future
per-plan VIEW renderer or source set. Each call derives the actual renderer,
version, runtime, complete scope, adoption record and source from the Router's
immutable tagged adoption history. `preservationViewBinding(record)` returns
that record's Core, Router, live renderer and runtime, preservation attribution
and runtime. A binding read alone is not currentness or admission.

The current methods `preservationViewJSON(scope,token)` and
`preservationViewHTML(scope,token)` return the actual adoption record and output.
The two `historicalPreservationView*` methods take the retained record and return
its full scope and output. VIEW membership `scopeId` is distinct from declaration
`viewId`. Historical output authenticates completed/burned permanent identity;
it does not assert current selection or freeze the other live Artist facts.

The actual retained live renderer performs its original mode-3 HTML, payload,
at-mint coordinator, full-policy, identity and lifecycle checks. The new JSON
uses that complete HTML, the same retained payload strings and original fixed
formatter with `preservationAttribution(collection,token)`. The companion skips
only sanction lookup and its derived display fields. All other artwork,
token data, entropy and non-sanction Artist facts remain live. Empty, failed,
malformed or wrong-source attribution cannot produce fallback evidence.

The fixed producer worker and formatter execute through direct bounded STATICCALL,
with exact canonical returns. Identity binding authenticates immutable Router
carrier/tag/preimages and source pins; it is clock-free and does not itself
assert time eligibility. The checkpoint retains the original current/time
reader. The producer does not call the Registry that will admit it. This avoids a
self-referential immutable Registry runtime in the STATIC read roster. Consumer
admission remains mandatory: the new checkpoint revalidates the original
current adopted source and then calls the actual selected Registry's
`requirePreservation(versionKey,producer,profile)`. It joins all nine producer
binding words and all seven admission words to the actual per-record renderer.
The admission hashes are committed into the checkpoint source context. Producer
serving is not an alternative to admission; original live Router/Registry paths
are unchanged.

The explicit output profile is
`keccak256("6529STREAM_ADOPTED_POLICY_VIEW_PRESERVATION_V1")`. The companion must
advertise `6529STREAM_NON_SANCTION_ATTRIBUTION_V1`, with actual Core/Router/live
attribution reciprocity. Its API and the common Registry admission interface
are separately owned companion dependencies, not new canonical genesis roles.

## Complete checkpoint and content tree

`StreamViewPreservationContentCheckpointV1` retains the original sequential
begin/append/seal/current semantics under distinct source, row, plan and output
domains. Preparation is permissionless and grants no publication authority.
Each append verifies the next actual complete member and both exact output
bytes. Every seal and current read re-observes every member and its full JSON
and HTML. It rejects omitted, duplicated, reordered or changed rows.

Each output is the complete 31-word typed row, including actual global token
identity, collection serial, lifecycle, burned/serving discriminator, token-data
hash, original-at-mint coordinator and full policy, actual status/seed, and both
output hashes and lengths. Status 1/2 terminal output is distinct from status-5
finalized output. A burned member uses the explicitly historical serving path
under the still-current complete adoption.

The new `contentRoot` is distinct from the ordered `outputRoot`. Its leaf is
`keccak256(abi.encode(LEAF,OUTPUT_PROFILE,chainId,Core,fullScope,adoptionRecord,row))`,
where LEAF is `6529STREAM_VIEW_PRESERVATION_CONTENT_LEAF_V1`. Nodes hash
`abi.encode(NODE,left,right)` using `6529STREAM_VIEW_PRESERVATION_CONTENT_NODE_V1`.
Rows remain strictly ordered by actual token ID, with exact zero-based index.
Pairs preserve left/right order; an odd node is promoted unchanged. No sorting,
duplication or old six-field CMC leaf reinterpretation is allowed. The checkpoint
incrementally maintains the tree frontier but never uses it to skip current
output validation.

## Covered parts and complete index

`StreamViewPreservationOutputManifestV1` verifies 64-row parts, with only the
last part shortened, and an index covering every part in order. The complete
thirteen-word Header binds the checkpoint/state, full scope, adoption, source,
membership, policy, count, output root and content root. Original ArtifactCoverage
must cover each exact canonical carrier through two independent archive families.

The part encoding is
`abi.encode(PART,chainId,Core,checkpoint,checkpointConfigHash,Header,uint64 first,Output[] rows)`.
Its dynamic array offset is 640, and byte length is `672 + 992 * count`.
The index uses the same header followed by the archive Artist label and an
ordered Descriptor array; its length is `672 + 288 * partCount`. The label is
not Artist content consent. Five exact ACTIVE documents define part/schema,
part/canonicalization, index/schema, index/canonicalization and the content leaf.

At the existing 16,384-member vocabulary bound, there are 256 complete parts;
a full part is 64,160 bytes and the full index is 74,400 bytes. The original
524,288-byte carrier limit is unchanged. These format bounds do not prove the
complete source/currentness call fits the original transaction limit.

## Authority and remaining integration

Deploy the stable preservation companion/producer, checkpoint and manifest
before the prospective per-plan VIEW renderer. Admit the actual renderer, declare/adopt the VIEW through original op17
RENDERER_CONFIG, then admit the preservation producer against that actual
renderer version and adopted-record golden vectors. The two admissions retain
separate exact read analysis and goldens. Observe and cover
the complete output, then publish its root-free snapshot. Genuine CONTENT_ROOT
authorization uses a separate original op17 consent in the same consumed book
and scoped history. Adoption is not CONTENT_ROOT authority.

The pending typed VIEW root stores a distinct closed binding in its new state
hash; the shared original scoped outer record, head and collection aggregate
retain their original domains. Existing non-VIEW and live VIEW profiles remain
unchanged. Full selected provider/component/discovery and original finality
ceremony acceptance are not implied by these observational producers.

The new recipes use actual State/Store/Renderer/checkpoint/manifest and actual
Schema/ArtifactCoverage where stated, with explicit typed Core, original Artist,
Registry admission, archive-family and finality boundaries. The sanction
separation control changes typed display replies; it is not an actual op12,
finalization or op13 composition test. The pure tree and maximum part/index
cases are encoding evidence, not universal gas evidence.

## Staged freshness remains unresolved

No complete output-invalidation epoch exists across every mutable producer and
time-dependent fact. Adoption/source hash equality alone omits lifecycle/data,
live Artist and derivative C2PA/standing facts. This implementation retains full
re-observation and does not claim that all 16,384 cold rows fit one transaction.
No cap increase, sampling or partial preparation is accepted as current evidence.

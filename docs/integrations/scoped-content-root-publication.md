# Scoped CONTENT_ROOT adoption

`IStreamScopedContentRootPublication` is an additive front door on the original
`StreamMetadataRouter`. It adopts a current `StreamScopedSnapshotPublication`
record for a canonical TOKEN, RELEASE or SEASON scope. It does not reinterpret
COLLECTION records or enable VIEW. VIEW still requires its separate selected-view,
renderer and Artist-adoption profile.

The selected finality registry's pinned evidence provider must explicitly expose
`IStreamScopedContentRootEvidenceBinding`: the scoped snapshot address, its saved
runtime hash and its validation budget. The publisher cannot select an alternative
snapshot host. This batch declares that additive capability; it does not add a
scoped finality ceremony or modify the original collection provider configuration.
A provider without the capability cannot admit this write.

## Exact authority and source

Call `previewScopedContentRootPublication(publication, publisher)` using the actual
publisher (including a Safe). The returned value is the prospective original
CONTENT_ROOT family state for Artist operation 17. Apply the original Artist
authorization, then call `publishScopedContentRootPublication` from that publisher.
The write uses the Router's existing `consumedArtistContentConsent`, ratification
and evolution maps. No separate consent book or independent authoritative content
host is introduced.

Preparation checks current Core selection, original Artist/finality bindings,
pinned provider and snapshot runtimes, selected Metadata and its exact SNAPSHOT
class-7 collection or class-8 global writer grant. The snapshot must revalidate its
complete current source and return the exact requested scope/head/revision. Its
original canonical payload hash/length, source hash, locked Artist generation and
binding, output root/count and output-manifest hash are retained. A locked snapshot
is not assumed current merely because it is locked.

Core collection freeze and both EXACT and INHERITED artwork-scope freeze refuse
publication. Preparation runs again after original Artist consent consumption;
any source, writer, lineage or prospective-state change rolls the entire call back.
The existing Artist lock and ratification rules continue through their original
entry points. This adapter invents no new Artist lock class.

## Append-only state and compatibility

One compiler-declared `StreamMetadataScopedContentState.State` is appended after
the original Router fields. It contains immutable records, canonical subject
heads, and a per-collection revision/transition-chain pair. Updating one scope is
constant work with respect to prior history. The transition commits the chain,
Router, Core, collection, preceding chain, next revision, exact subject, previous
scope record and new complete prepared state hash.

Before the first scoped write, the CONTENT_ROOT family and overall content hashes
are byte-for-byte the original formulas. Afterwards the family commits both the
unchanged legacy collection state and the scoped aggregate. An original collection
write therefore previews and authorizes the wrapped family state while retaining
the original collection record, state hash and schema bytes. An older consent that
omits an intervening scoped transition cannot authorize the new aggregate.

The common content hash includes the aggregate before the existing STATIC-config
wrapper. Script, media, manifest and STATIC updates consequently retain all live
scoped authority state in original ratification/evolution accounting. Their own
family-specific authorization remains unchanged.

The original common worker's nine-root layout is unchanged. The new scoped worker
receives the appended typed storage reference directly from the Router. Common
content hashing uses the fixed State worker, which makes a self-only STATICCALL to
`scopedContentRootAggregate(uint256)`, capped at 50,000 gas and exactly 64 returned
bytes. That Router getter performs only two compiler-owned mapping reads: no
dependency calls, delegated reads, fallback or recursive content hashing. This
paired Router/worker read must appear in any complete dependency/read-set roster.
It is not a claim of renderer opcode conformance.

The fixed `StreamMetadataRouterContentState` worker holds the original common,
script, media and family-state formulas. Existing private wrappers retain their
original caller checks and delegate context. This is a code-size split of those
same reads, not another state container or authority surface.

`ScopedContentRootPublished` has schema version 1 and includes the complete record
and resulting aggregate. The canonical record/domain description is
`schemas/records/STREAM_SCOPED_CONTENT_ROOT_RECORD_ABI_V1.json`; this describes the
host's ABI record and is not an assertion of a SchemaRegistry admission. Existing
snapshot schema/profile admissions remain enforced by the actual snapshot source.

## Reads and evidence limits

`scopedContentRootHead`, `scopedContentRootRecord`,
`scopedContentRootAggregate` and `scopedTokenContentRoot` expose original stored
history. The root read returns the existing six-field leaf schema identity. These
reads do not independently revalidate current snapshot/render/archive evidence or
prove full retained output bytes. The consumer must perform its required current
source checks rather than promote a historical head to finality.

The seven authored tests use actual Router, STATIC configuration, Metadata grants,
SchemaRegistry, Store and official threshold Safe. Core, Artist signature/lifecycle,
validated snapshot and finality/provider reads are explicit boundaries. They cover
two scopes, exact transition preimages, stale consent, legacy collection writes,
script/media/STATIC preservation, freeze denial, grant/binding/current-source
denial, historical reads and late-failure byte-identical Safe retry. ABI validation
has passed; these new test bodies have not been executed. Actual Artist op17,
scoped snapshot composition, current Core and finality ceremony remain separate
integration work. Router deployment size remains a recorded blocker; no held
Router cache or storage-extraction proposal was applied for this batch.

The selected six-product check measures Router 40,944 bytes (oversized), common
Content 22,880, common ContentState 3,473, scoped transport 6,500, scoped Source
12,079 and scoped State 4,538. All five workers fit; this does not clear the
Router's deployment gate. The 226-source ABI check preserves all 134 original
Router ABI entries and all 15 original storage rows recursively, appending only
the new compiler-owned state at slot 17.

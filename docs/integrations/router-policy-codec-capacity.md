# Router policy codec capacity checkpoint

The Router at production commit `b84700ef877285a25807ce633e5f874438fd1438`
fits the original runtime and initcode limits. The frozen source at test-repair
commit `3e43c38a19cdea8327ab65ae4133f2e426ff9dfa` passes all 100 focused
Router cases. Its four production files are unchanged from `b84700ef`.
This is source-specific capacity and regression evidence; it does not establish
acceptance of the complete current Artist/Core commerce graph.

## Implementation boundaries

The existing fixed `StreamMetadataRouterRootCodec` handles V2 preview and
publication as well as the original legacy/scoped operations. The Router keeps
its original collection guard. V2 publication preserves preparation, current
family selection, content authorization, policy-root publication/recheck and
application recording in their original order and Router storage/caller context.
The policy-root implementation itself is unchanged.

Content-root records and V2 bindings share a selector-dispatched read encoder.
Nine existing struct-return wrappers and the V2 binding wrapper use `calldata`
return declarations only where the wrapper unconditionally returns the complete
encoded bytes with EVM `RETURN`. This preserves the external ABI without a
second compiler-generated struct encoder. It adds no storage or cached record.

`StreamMetadataRenderPreparation` contains the original default contract JSON
and attributed collection serialization. Original Core, collection, finality
and live-attribution reads retain their ordering in the Router. The new bundle
scalar helper calls the original complete `selection` function before selecting
its bundle ID, retaining runtime, capability, read-bound and gas checks. Four
identical collection-existence checks share one private guard at their original
call sites. Protected STATIC configuration getters remain direct Router reads.

## Matched compiler evidence

The paired baseline is `13be0020a31af948582784a532a484c3fc16766a`, including
the original V2 publication surface. Both selected builds use the same 281
source names and compiler settings: Solidity 0.8.19, via-IR, optimizer 200,
Paris, no CBOR metadata and no bytecode hash. The 282-source native test closure
adds the pure serialization test. The current profile's only capture-specific
change selects `test` instead of `test/current`; production limits and compiler
settings remain unchanged.

| Product or measure | Baseline bytes | Candidate bytes |
| --- | ---: | ---: |
| Router runtime | 28,600 | 24,290 |
| Router creation code | 34,212 | 29,860 |
| Router initcode with the fixture's 288-byte arguments | 34,500 | 30,148 |
| RootCodec runtime | 4,559 | 6,729 |

The Router saves 4,310 runtime bytes and has 286 bytes of headroom below 24,576.
Its tested initcode is below 49,152. All 117 nonempty production artifacts in
this focused closure fit the runtime limit and creation-code limit before
constructor arguments; only the Router's complete initcode is measured here.
This closure does not include every product in the full application graph.

The full Router ABI (144 entries), all 97 method identifiers and normalized
16-field storage layout match the baseline. The native layout also matches
the frozen reference facade. Across 287 common production contract/library
ABIs, only the intentional additions to the internal BundleRenderer and
RenderPreparation library APIs differ.

## Native regression evidence

The first immutable `b84700ef` native build completed in 645.193 seconds and
ran 98 passing cases with two failures in new test oracles. The minimal reference
facade lacked the original scoped-aggregate self-read; the standalone bundle
probe lacked the original namespaced display gas parameters. Test-only commit
`3e43c38a` restores the exact aggregate getter and initializes the probe's real
display parameters. Independent source review confirmed both repairs preserve
the original production checks.

The second capture byte-copies the first capture's genuine Forge output/cache,
records those hashes, and runs ordinary Forge to rebuild the four affected
files. That build completed in 462.336 seconds. No synthetic native artifact
or compiler-output adapter is used. The cached test run completes in 7.546
seconds with 100 passes, no failures, and unchanged artifact/cache hashes.
Nine fuzz properties each execute 256 cases with seed `0x6529`.

| Suite | Passing cases |
| --- | ---: |
| Legacy content roots | 13 |
| Metadata serving | 15 |
| V2 policy content roots | 10 |
| Bounded reader sharing | 8 |
| Codec parity | 13 |
| Pure collection encoding | 2 |
| Scoped content roots | 7 |
| Script bundles | 13 |
| Bundle return shape | 4 |
| Current STATIC admission boundary | 3 |
| STATIC routing | 12 |

The successful V2 reference comparison preserves runtime pinning: current and
reference previews receive their own approvals, and their distinct route/state
commitments produce independently derived record hashes. Binding bytes and
remaining record fields match. Existing lineage, events, late-dependency
failure and Safe retry assertions remain. Canonical invalid requests preserve
exact errors; malformed ABI inputs follow the previously accepted requirement
that both implementations refuse atomically, without requiring identical
malformed-input error bytes.

## Local evidence identity and remaining work

The ignored local capture is `out/router-v2-native-3e43c38a`. It records all
282 committed Solidity source bindings, 1,364 captured input file hashes,
toolchain pins, original cache provenance, full build-info, size/ABI/layout
audits and native test JSON. Its manifest SHA-256 is
`16ed385e482204fe05379953660ed0ba4b6097348b61ea7809c621ad191169c2`;
test JSON SHA-256 is
`dd5fdb21f2d30312d3ffb61ab110bf2b6b01e608534c6e243f0875243c566f7c`.
These are local evidence records, not a published release bundle.

Actual-current Terminal/INSTANT acceptance requires a separately frozen fitting
joined graph. Full CI, invariants, worst-case transaction gas, release artifact
regeneration and deployment acceptance remain open. The small Router headroom
must be remeasured after later changes. Earlier oversize checkpoints in
[Router codec factoring](router-codec-factoring.md) retain their historical
scope and results.

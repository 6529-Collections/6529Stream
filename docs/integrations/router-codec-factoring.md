# Router codec factoring

The Router retains its original public signatures and storage while fixed
workers handle selected input decoding and complete collection-return encoding.
This experimental branch targets facade bytecode size. Both native checkpoints
fail the production size gate; the revised focused cohort passes 70 cases.
This does not establish deployment acceptance. Native results below belong to
their exact captured source and do not establish current-stack acceptance.

## Boundaries

`StreamMetadataRouterConfigCodec` receives the original calldata for default,
collection and token configuration writes and configuration preview. The Router
keeps its original collection, selected-Artist and token-identity guards.
The existing configuration worker still owns authority, freeze, configuration,
consent and history checks and all writes.

`StreamMetadataRouterRootCodec` receives the old collection/scoped publication
calldata after the original Router guards. Legacy publication keeps the same
prepare, wrapped-family computation, authorization, publish/recheck and
application-recording order. Scoped publication invokes the original worker.
The codec also returns the complete original content-root record ABI bytes.
No encoded-record cache, new owner mapping or replacement consent state exists.

`StreamMetadataRouterCollectionReads` now assembles and encodes the complete
collection metadata, Artist presentation, serving facts/source, live Artist
status and selected bundle results. The Router returns those ABI bytes directly.
Zero-record reads remain distinct from the reads that require an existing
collection. Facts preserve legacy, bundle and activated STATIC precedence;
the reported renderer addresses are supplied by the Router's own fixed links.

All delegation is to fixed linked workers. Storage references come from the
original compiler-derived roots; the nine-field content layout is unchanged.
The original caller and Router address remain the authorization/hash context.
This does not add arbitrary routing or another public Router selector.

## Preserved direct paths

The STATIC routing implementation, identity dispatch, configuration getters,
raw/frozen source getters and scoped aggregate read remain in the Router.
Their existing bounds, errors, source selection and snapshot checks are
unchanged. Configuration getters used by current STATIC selection/content
checkpoints are not moved into delegated read workers. The constructor,
storage declarations, namespaced state, serving anchors, self-only attribution
frame, original scope membership and derived preparation hook are retained.

The six token-serving entry points package their existing burned-token and
output-mode choices into a memory-only `TokenViewOptions` struct. The shared
internal serving function reads those two values before its original body.
This prevents the optimizer from emitting six specialized copies of that
body, including its STATIC selection. It adds no external call or storage
field. The existing mode mappings and serving body remain unchanged. The
focused regression cohort below covers selected behavior; it does not establish
complete mode/state or worst-case gas coverage.

This batch does not contain the separately developed V2 CONTENT_ROOT entries.
Any joined version needs its own compiler and size evidence.

## Focused regression scope

`StreamRouterCodecParityTest` compares canonical refusal bytes, malformed-input
failure and collection read returns with method bodies frozen from integration commit
`e0eb03c38fefab405a3b14f259c0b75de2994a05`. Its test-only reference retains the
original storage order and relevant method bodies, qualifying shared struct
types and omitting unrelated methods. Snapshot-scoped code substitution keeps
the same target address, storage and caller for that comparison.

The reference is a decoder/read oracle. The typed Core boundary reports the
current code hash dynamically, so the comparison does not prove production
pinning, successful authorization, deployment or code-identity equivalence.
Some collection-read comparisons intentionally compare identical refusals.
Positive Artist presentation/live status and bundle behavior come from the
existing serving and script-bundle suites.

The selected cohort also includes existing STATIC configuration, legacy root
publication and scoped root publication suites. Their independent record/hash,
event, consent, rollback and Safe retry assertions cover the actual updated
Router with explicitly named surrounding typed boundaries. These tests do not
replace actual-current Terminal10/Instant8 acceptance, transitive STATIC review,
full CI, worst-case collector gas or release validation.

## Native checkpoint: `feefb7d8`

The immutable 257-source capture at
`feefb7d84a8b0feaafe06695272440b86ce3d129` compiled with Solidity 0.8.19,
via-IR, optimizer 200 and the original Paris settings. Original Router ABI,
method identifiers and normalized storage layout match the baseline. Runtime
is 38,305 bytes, above the unchanged 24,576-byte production cap. Creation code
is 44,022 bytes; the tested 288-byte constructor arguments bring initcode to
44,310 bytes. Other nonempty production products fit their original limits.

The six-host cohort produced 58 passes and nine failures. Five failures expose
malformed-calldata error-byte differences in the configuration/publication
codecs. Both implementations reverted in all five observed cases. Memory
decoding changes nested-offset errors and can produce allocation panic `0x41`
where the old calldata path reverted with empty data. These are not observed
canonical-input or successful-write differences. The initial corpus stopped at
the first difference, so later mutations were not exercised.

The integrator accepted different error bytes for malformed ABI inputs that
both paths reject atomically. The revised tests retain exact canonical error
checks, add typed-field fuzz cases, and require malformed inputs to fail on
both implementations. Configuration, root and collection state is compared
before restoring the current implementation's test snapshot. The existing
authorization, consumption and exact-retry tests remain required.

Four other failures concern existing rendering expectations: two complete
goldens omit citation fields, a burned-state substring assumes no following
citation, and an anchor test compares live attribution with a locked historical
snapshot despite a fixture lacking the live display method. These observations
come from source comparison and native failure traces; no baseline native run
has been claimed. Test-only corrections use exact citation goldens with an
explicit fixture context, compare the same historical method before and after
facade loss, and independently check the burned JSON state and citation. The
revised tests pass at the later checkpoint; the recorded 58/9 result is unchanged.

## Native checkpoint: `28f46de8`

The immutable 257-source capture at
`28f46de88b7850d572932c2abb522e40f93a289f` compiled successfully with the
same compiler, optimizer and EVM settings. Optimized IR contains one shared
serving implementation instead of six. The original public ABI and method
identifiers match exactly; normalized storage matches the frozen reference.
All captured input hashes remain unchanged after compilation.

Router runtime is 26,754 bytes, a reduction of 11,551 bytes from the previous
checkpoint. It remains 2,178 bytes above the original 24,576-byte cap. Creation
code is 32,345 bytes; the current graph's 288-byte constructor arguments bring
initcode to 32,633 bytes, below the original 49,152-byte cap. All other nonempty
production artifacts in this capture fit the runtime cap and the creation-code
cap before constructor arguments.

The cached six-host cohort passes all 70 cases, including the revised decoder
oracles and rendering assertions: legacy roots 13, scoped roots seven, STATIC
11, serving 15, bundles 13 and codec parity 11. Five fuzz cases each run 256
times with seed `0x6529`. The run took 6.452 seconds and changed no native
artifact or cache hashes. The integrator explicitly authorized this functional
regression run despite the known size failure; the existing fixture profile
and production limits remain unchanged. It is not deployment acceptance.

A comparison of 54 unchanged, successful unit cases outside the revised parity
host shows a largest execution-gas increase of 2,128 gas (0.0254%) in the real
STATIC renderer/context/dispute case. Some cases deploy contracts or make
multiple calls, so these totals are not per-call or worst-case gas evidence.
Actual-current Terminal10/Instant8, the separately developed V2 CONTENT_ROOT
join, full CI and release evidence remain pending.

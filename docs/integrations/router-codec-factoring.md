# Router codec factoring

The Router retains its original public signatures and storage while fixed
workers handle selected input decoding and complete collection-return encoding.
This experimental branch targets facade bytecode size. The first native
checkpoint fails the production size gate and the initial exact-error corpus;
it is not an accepted integration candidate. Native results below belong to
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
revised tests require a new native result; the recorded 58/9 result is unchanged.

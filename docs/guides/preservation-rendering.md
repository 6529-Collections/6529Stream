# Explicit preservation rendering

The preservation API produces fresh, complete MARKETPLACE artwork output with an
explicit non-sanction attribution projection. The original live token JSON,
HTML and token URI methods are unchanged. This API does not rename archival
bytes as a live token URI and does not strip strings after rendering.

## Attribution and request authority

`StreamPreservationAttributionCompanion` is constructed from the original STATIC
attribution companion, its actual live attribution source and the governed gas
executor. It retains the original Core, Router, Artist, source, chain and runtime
checks. If the live source is the original C2PA wrapper, its original companion
and reconciliation runtime are also pinned and checked on every read.

The shared Artist object keeps its existing state-3-to-state-2 normalization and
all original identity, binding, claim, correction, collaborator, attestation and
adverse-state reads. Only the final sanction enumeration is excluded. The new
profile is `6529STREAM_NON_SANCTION_ATTRIBUTION_V1`; the public live object still
performs that enumeration.

`StreamPreservationRendererV1` is constructed from the actual live renderer, the
new attribution companion, the original executor and two governed gas configs.
It binds the original renderer's full source and fixed encoding/validation
workers. `preservationTokenJSON(token)` and `preservationTokenHTML(token)` derive
the request from the actual Core identity/lifecycle, Router selection and
original-at-mint entropy. Callers cannot supply a renderer, configuration or
request. Finalized entropy and the original terminal full-policy path remain
separate. Existing retained burned-token semantics are preserved. A missing or
malformed required source refuses; it is never successful preservation fallback.

The six-word `preservationBinding` and profile identify the producer. They do not
attest admission. The producer does not call the admitting Registry, avoiding an
immutable producer/Registry runtime cycle. Every accepting consumer must perform
the independent admission below for the actual selected row.

## Separate governed admission

`IStreamPreservationRegistryV1` adds a separate immutable registration to the
original Renderer Registry. The key is the ABI hash of the literal
`6529STREAM_PRESERVATION_KEY_V1` domain, original version key, producer and profile.
The declaration also binds the original version registration, chain, Registry,
schema Registry and runtime, target catalogue, new schema/analysis/golden
identities and complete declared reads. Registration uses the original class-1
authority, exact prior/next context and insertion/event ordering.

The original live version must already be admitted and assignable when the new
registration is created. The new sorted read set preserves every original read
and adds the required preservation calls. Its registered analysis is an explicit
publisher assertion: genuine complete transitive read/opcode analysis remains
an admission obligation. The new schema is not covered by the old renderer's
analysis or golden vectors. Golden validation actually calls the new producer
and checks the real token and selected version; VIEW vectors also bind the exact
adoption record and full scope.

`requirePreservation(versionKey, producer, profile)` returns exactly 512 bytes:

- Nine producer words: producer/runtime, profile, Core, Router, original live
  renderer/runtime, preservation attribution/runtime.
- Seven admission words: Registry/runtime, actual version key, registration,
  read-set, analysis and golden hashes.

The fixed pinned STATIC worker reads the host's direct compiler-owned records,
checks the original live version, chain and every declared target runtime, and
rechecks the producer binding. Retirement does not rewrite historical evidence.
A consumer separately checks its current selection and any VIEW adoption binding.
Different rows may select different registries or version keys even with the same
producer. Consumers must retain the complete admission for each row.

The constructor catalogue accepts the closed new labels
`PRESERVATION_RENDERER`, `PRESERVATION_ATTRIBUTION` and
`PRESERVATION_COMPANION`; it does not add a genesis role. Existing catalogue
labels and old sequential storage remain unchanged. New records occupy only the
fixed preservation namespace and have no update, removal or arbitrary-slot API.

## Original admission capacity

Original renderer admission now calls one fixed linked validation worker after
its unchanged governance check and before its unchanged immutable insertion.
The worker retains manifest, read-set, analysis, document and golden checks in
the original order. Delegate execution preserves the Registry address and the
Registry caller seen by renderer/schema STATICCALLs. Governed gas values are
read through the original host getter at the same predicate positions. Original
serving methods do not enter this admission worker.

## Evidence and remaining integration

The frozen source has a clean 369-source ABI check. All 287 prior ABI entries and
selectors across Registry, Registry Module, both original attribution companions
and the live renderer are retained; their recursive compiler storage layouts are
unchanged. Forty retained Registry function bodies and six extracted-body inverse
comparisons are exact, apart from declared type/context substitutions and one
formatter-only brace pair.

Selected native runtime sizes are Registry 21,927 bytes, Module 22,121, original
admission worker 8,063, preservation registration worker 6,540, preservation
admission worker 14,936, token producer 21,284 and attribution companion 20,386.
These are selected products, not an assertion that the whole reached deployment
or a cold transaction fits. Constructor argument bounds and full linked closure
must be checked for each deployment.

Twenty preservation cases and four original golden-validator parity cases are
authored and typechecked. The fixtures use actual producers, Router, Registry,
Schema and Store with explicitly typed surrounding Artist/Core/entropy/governance
boundaries. Their synthetic analysis documents do not establish transitive STATIC
conformance. The four original golden-validator parity cases passed with nine
frozen sources and four independently verified genuine native artifacts; execution
changed no source or artifact and invoked no compiler. The twenty preservation
cases remain authored/typechecked. This batch does not claim an actual
op12/finalization/op13 ceremony, whole finality graph or gas budget.

Remaining required work includes genuine profile admission evidence, consumer
checkpoint/root/snapshot/reference/inventory/finality integration, and preservation
through an authenticated Artist-suite successor lineage. The original live
companion's current-Artist relation remains enforced. VIEW has a separate producer
and profile. Complete staged VIEW freshness still requires full re-observation or
a separately proven producer-owned invalidation commitment; skipping sanctions
alone does not establish that property.

# Current C2PA product construction and source inventory

This batch composes the original current Core/Artist graph with the optional
C2PA products and standing-conflict successor from frozen Artist source
`e21d58e4` on `3f1a0680`. The earlier fifteen-edge construction batch `4d1838e8`
and its eleven-case ABI capture remain historical evidence against `3f1a0680`
plus integration input `a65145ea`. Local dependency commit `64746fb5` adds the
frozen successor without changing that historical capture. The separate
[finite Artist/C2PA target profile](static-artist-c2pa-profile.md) names sources
without admitting a renderer or granting authority.

The successor helpers and thirteen current-graph tests are source/type checked.
Native execution, gas measurement, complete STATIC admission, actual current-graph
verifier-report adoption and current-full output acceptance remain pending.
The production Router and Artist size blockers remain; the current fixture
still enforces production deployment-size checks.

## Construct the original products

Use explicit named imports from
[`StreamFullV1C2PAProducts.sol`](../../script/current/StreamFullV1C2PAProducts.sol)
and [`StreamC2PAStaticReadPlan.sol`](../../script/current/StreamC2PAStaticReadPlan.sol).

1. Supply the actual current Core, Executor, Router, MetadataV1, SchemaRegistry,
   entropy coordinator, Artist registry and original finality addresses in
   `Configuration.base`. An optional dependency registry remains explicit.
   Supply the deployment commitment and exact new renderer manifest.
2. Select the verifier explicitly and supply the reconciliation, wrapper Artist,
   wrapper report, renderer read and renderer attribution gas configurations.
   A verifier address is a configured evidence source, not proof of C2PA
   cryptographic correctness or an automatic Metadata writer grant.
3. `deploy` constructs the original attribution companion, original
   reconciliation companion, optional attribution wrapper and matching new
   Renderer. The renderer links the new Encoding worker whose `Prepared` tuple
   includes the C2PA display and token/collection conflict fields. Reusing an
   older Encoding selector/runtime is invalid.
4. Retain the returned product identities, configuration commitment, six
   product/worker runtime observations, and four original Artist source pins.
   `validate` checks the chain, original reciprocal bindings, selected verifier,
   schema authority, fixed Artist owner addresses, wrapper, renderer and Encoding.
   Both `c2paAttributionEnabled` and `c2paConflictsEnabled` must be true, and the
   wrapper must advertise the exact `IStreamStaticC2PAConflicts` capability.
5. Retain native compiler/link artifacts independently. The helper's compiled
   `StreamArtistStaticDisplay` address is an expected fixed worker; authenticating
   that the deployed original Artist facade links that exact worker is a native
   provenance obligation. Live code hashes and getters alone do not prove it.

`rendererRegistration` proposes exactly one original `RENDERER` module row.
The two optional companions have no invented registry module kind.
`operatingPolicies` proposes three exact class-1 `raiseGasParameter` rows for
reconciliation, wrapper and renderer; merge and sort them through the original
delayed catalog process. These functions do not execute admission, writer
grants or governance actions, or replace the full 37-role candidate inventory.

The nested gas budgets must allow the wrapper to enter its original attribution
and report frames. The tests use explicit fixture values with room for the
callee's bounded-call prechecks. Those values are not launch gas measurements.

## Preserve the full source graph

`delta` supplies the following seventeen edges at the frozen successor. Runtime
hashes bind their actual targets. `SERVING` means the edge serves the renderer;
`AUDIT` identifies the separate historical credential read.

| Exact source | Selector | Return bound in bytes | Use |
| --- | --- | ---: | --- |
| Optional wrapper | `attributionWithC2PA` | 33,056 maximum | SERVING |
| Original attribution companion | `attribution` | 32,832 maximum | SERVING |
| Reconciliation | `display` | 192 exact | SERVING |
| Reconciliation self-call | `requireCurrent` | 0 exact | SERVING |
| Current Core | `getSatellitePointer` | 320 exact | SERVING |
| Original MetadataV1 | `latestCollectionRecordHashFor` | 32 exact | SERVING |
| Original Router | `staticRenderSource` | 32,768 maximum | SERVING |
| Original Artist facade | `staticDisplayRead` | 704 maximum | SERVING |
| Fixed Artist display worker | `read` | 704 maximum | SERVING |
| Original Artist coordinator | `suiteConfiguration` | 544 exact | SERVING |
| Identity owner 2 | `staticIdentityMetadata` | 352 maximum | SERVING |
| Binding owner 0 | `binding` | 320 exact | SERVING |
| Attribution owner 4 | `c2paCredentialHead` | 320 exact | SERVING |
| Attribution owner 4 | `c2paCredentialRecord` | 320 exact | AUDIT |
| Matching new Encoding worker | `render` | 16,777,280 maximum | SERVING |
| Optional wrapper | `attributionC2PAConflicts` | 384 exact | SERVING |
| Reconciliation | `standingConflict` | 192 exact | SERVING |

The Encoding bound covers the maximum full-view string plus its raw ABI envelope.
The head and historical record are direct fixed-owner reads: this source has no
facade forward for either selector. Adoption-only reads, such as credential
statement bytes, media manifests and retained verifier artifacts, have their
own evidence requirements and are not misreported as serving calls.

The two new serving edges read the original reconciliation instance's local
standing-conflict state. The original six-word `Display` remains 192 bytes, and
`attributionWithC2PA` retains its 33,056-byte bound. Token and collection standing
tuples are returned independently in that order; report precedence cannot hide
a collection conflict. The `StreamC2PAConflicts` worker executes only during
adoption, narrative construction or acknowledgement, not these serving reads.
Retain its compiler-link provenance without inventing a new STATIC target role.
Complete historical conflict reconstruction additionally needs audit reads such
as `conflictRecord` (384 bytes), `conflictResolution` (160 bytes), `conflictAt`
(32 bytes), and the exact retained narrative. This serving delta does not claim
that separate complete history inventory.

Supply the separately reviewed original attribution roster and its retained
`keccak256(abi.encode(rows))` commitment to `compose`. It retains every supplied
row, combines identical duplicate edges, rejects conflicting duplicates, and
sorts by `keccak256(abi.encode(target, selector, use))`. Each target has one
semantic role. The returned inventory binds the chain, construction, original
roster commitment and complete combined row list. Retain `inventoryHash`;
`requireUnchanged` checks that exact inventory, live runtimes and every required
incremental edge again before reuse.

This commitment authenticates supplied input, not its completeness. The
unchanged original attribution closure includes its Core/finality/snapshot
dependencies and original Artist owners, including collaborator-record owner 1,
acceptance owner 3 and sanction owner 6. Preserve them alongside owners 0/2/4,
the coordinator and worker. The rest of the Renderer graph also remains required.
The test's four-row original roster is explicitly a partial union fixture;
deduplication yields twenty combined rows in this successor.

The semantic inventory is not a `RendererRegistry.Read[]` adapter. The current
registry disallows zero-byte declarations and caps declarations at 16,777,216;
the self-call and full-view Encoding envelope above therefore cannot be cast
literally into its current shape. No cap is reduced to hide that mismatch, no
registry limit is enlarged here, and no complete admission is claimed.

## Evidence and behavior boundaries

The current tests construct the actual current graph and actual threshold
Artist/verifier/governor Safes. Only the inherited upstream entropy service is
a double. They author coverage for original bindings and proposed module/GGP
rows; absent-report attribution; original Safe-signed op24 credential history,
head events and personhood preservation; stale/malformed update rollback;
read-inventory union and omissions; and runtime/configuration drift refusal.
Credential record hashes are independently recomputed in the original domain.
Two successor cases add exact absent-evidence Standing/Display/paired tuple
checks and expected original token/collection read calls, plus omission and
wrong-cap refusal for each new edge. They do not inject a divergent report or
simulate a successful original op46 acknowledgement.

Manifest/schema commitments used by the constructor tests are explicitly
synthetic and unregistered. No test presents a performed opcode analysis,
complete transitive read roster or normative golden corpus. No actual C2PA
validator, key-history JSON interpretation or trust-anchor judgment is performed.
For report adoption, follow the original receipt, class-4/class-6 verifier,
exact schema, media, key history and retained-artifact requirements in
[Artist/C2PA reconciliation](artist-c2pa-reconciliation.md).

Live adverse provenance is mandatory. A changed live annotation can change the
full rendered bytes; preserve an older full-output hash as historical evidence
and mark its current-full check stale. This helper does not introduce a separate
stable-artwork/live-annotation output profile. The standing-conflict API and exact
original-op46 historical acknowledgement are frozen in `e21d58e4`. This successor
updates the matched construction, Encoding selector and serving inventory for
that source. Actual current-graph divergence, acknowledgement and current-full
checkpoint flows still need composed execution; the small upstream native cohort
and the separate thirteen-case Registry unit pass do not establish those flows.

Native Foundry execution and current graph preparation are coordinated by the
integrator after the feature batch stabilizes. Keep this batch's ABI capture
separate from later native, fuzz, gas, CI and release evidence.

# Artist fixture artifact deployment prototype

This test-only prototype replaces direct production `new` expressions in ArtistOnboardingFixture with ArtistArtifactCreate. The helper fetches the current compiled creation artifact, appends the original ABI-encoded constructor arguments, and executes zero-value CREATE in the original fixture context. It bubbles the original constructor revert data.

The fixture's constructor order, CREATE caller and nonce, predicted registry and coordinator addresses, Safe deployment, real extension factory calls, child birth receipts, and factory runtime size checks remain in place. Production Solidity and the checkpoint test bodies are unchanged. The existing fixture retains its documented typed Core/governance boundaries; this change does not establish complete current-stack integration.

## Foundry artifact and library behavior

Use a fully qualified source.sol:Contract key. Under verified Forge 1.7.1 commit 4072e48705af9d93e3c0f6e29e93b5e9a40caed8, getCode first resolves the runner's available artifacts. The runner links compiled artifacts and deploys their libraries from its separate library deployer before the test. The helper introduces no library deployment under the fixture's CREATE nonce.

A physical .json filename takes a different getCode path and can contain unresolved library placeholders. The helper uses logical artifact names. Production imports remain present, so the normal compiler continues to produce those artifacts and invalidate changed dependencies. Missing or ambiguous artifacts fail rather than selecting arbitrary old bytes.

See the official [getCode documentation](https://getfoundry.sh/cheatcodes/get-code), the installed-version [artifact lookup implementation](https://github.com/foundry-rs/foundry/blob/4072e48705af9d93e3c0f6e29e93b5e9a40caed8/crates/cheatcodes/src/fs.rs), and [Forge runner linking](https://github.com/foundry-rs/foundry/blob/4072e48705af9d93e3c0f6e29e93b5e9a40caed8/crates/forge/src/multi_runner.rs).

No etch, substituted runtime, bypassed constructor, additional mock, production factory replacement or dynamic test-linking option is used. Original Safe artifact loading remains unchanged.

## Bounded validation

The first small probe compiled the actual current StreamArtistArchiveV2 and its linked payload library. It loaded the artifact without any embedded new reference, executed normal CREATE at the expected caller/nonce, checked original immutable bindings, and appended/read exact bytes through the actual linked payload catalog. It passed with seven compiler inputs in 1.81 seconds.

The checkpoint experiment uses a separate project copied from current integration source. A historical output/cache is only a seed: changed current sources must recompile normally before any behavioral claim. The frozen historical capture and root's current seven-suite input are never modified. Production size checks remain separate from permissive aggregate test limits.

The original seven-suite compilation took 2,737 seconds. A one-suite prototype with changed production dependencies is not an equal-workload speed benchmark. Report its measured compiler time, resulting test creation size and unchanged test behavior separately; do not extrapolate full-suite speed or release acceptance from this bounded experiment.

### First checkpoint result

Prototype base: f6d66d8b2ba27f900caf848ac34ec175f2f462f2.
The unchanged case was
testCheckpointIncludesSparseConsumedAndRevokedNoncesAndExactDigestGuard
in StreamArtistAuthorityCheckpointTest.

| Observation | Result |
| --- | --- |
| Current fixture closure | 728 Solidity files; exactly one test source |
| Cache invalidation | 126 files rebuilt after current-source replacement |
| Compiler/build wall time | 1,318.709 seconds |
| Retained older checkpoint creation code | 574,021 bytes |
| Prototype checkpoint creation code | 188,254 bytes |
| Bounded runtime | 1 unique case passed; no failures/skips; compilation skipped |
| Cache during runtime | Unchanged |
| Setup trace | Original factory and constructor path retained; MetadataV1 not invoked |

The 67.2% size difference compares the older 708-source artifact with this
current prototype. Production repairs also differ between those captures:
neither that percentage nor the 2,737-to-1,319-second comparison isolates the
fixture change. A matched current-source benchmark remains future work.

The case first passed normally, then passed again with the setup trace to
resolve a report-reader UTF-8 error and inspect the creation path. An earlier
over-anchored CLI filter selected no tests; that zero-body attempt is not
runtime evidence. The final literal filter was independently listed as exactly
the one named case.

The selected-cache size check found 445 nonempty production products. All
except StreamCollectionMetadataV1 fit runtime/base-creation limits. MetadataV1
was 24,846 runtime bytes (270 over EIP-170); it was not invoked or deployed by
this checkpoint case. That separate failure is retained and precludes an
all-product deployability claim. No production factory size check was bypassed.

The final helper has only a whitespace-formatting difference from its measured
copy. Reversing the 23 constructor substitutions restores the original fixture
token-for-token, including constructor arguments, comments and strings. No
production Solidity or checkpoint test body changed.

## Migration fixture extension

The next test-only batch also replaces 60 direct production constructors in
six migration fixtures: authority, payout, economics and readiness hydration,
history import, and the shared publication hydration fixture. Each replacement
uses the same helper with the original constructor arguments and evaluation
order. Every pre-format source is exactly reconstructed by reversing only its
ten substitutions. Production contracts, factory checks, predicted addresses
and assertions are unchanged.

The combined 782-source ABI/type check, including the new Artist/entropy join,
passes. Native behavior and a matched-source timing comparison remain pending.
The active eleven-suite migration capture contains the earlier fixture version;
its source and compiler process are preserved. Run the expanded fixtures in the
next capture after that result is collected.

## Current-stack fixture extension

The current-stack fixture now uses the same artifact-CREATE helper for its 17
ordinary constructor expressions: 16 production deployments (including three
GovernanceActors) and the existing external entropy-provider test double. All
array allocations are unchanged. The original constructor arguments, zero
value, fixture caller, CREATE order, intervening initialization and failure
propagation remain intact. Logical source:contract artifact keys resolve the
current compiled products; production imports and factory/size checks remain.

The shared fixture inherits the helper directly. The isolated dynamic royalty
commerce fixture removes only its redundant helper import and base; it obtains
the same helper through the shared fixture. Its test and deployment recipes do
not change. Reversing each substitution reconstructs the prior fixture token
stream. The 1,132-source ABI check covering current-stack descendants passes
in 6.41 seconds; native behavior
and a matched-source compilation-time comparison for this extension remain
pending the next integrator-owned capture. No speedup is inferred here.

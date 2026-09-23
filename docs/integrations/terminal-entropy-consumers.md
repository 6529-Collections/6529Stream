# Explicit terminal entropy consumers

This additive consumer profile recognizes the original Coordinator's explicit
`DISABLED` and asynchronous `NOT_REQUIRED` token states. Both retain their full
collection-policy hash and frozen policy record. Neither is a finalized random
seed. Existing V1 entropy-policy, renderer, reference-publication and archived
output definitions are unchanged.

The token's source is always `Core.coordinatorAtMint(tokenId)`. Selecting a new
Coordinator for later mints does not replace a previous token's source.

## Current metadata

Ordinary current metadata emits the explicit entropy status, declared security
class, full policy hash, original content-state hash, mode and render requirement.
It emits `entropy_finalized: false` and `entropy_seed_present: false`, without a
`hash`, `seed` or executable animation field. The original opaque token data and
canonical work citation remain present. An ordinary terminal HTML request fails
because this batch does not admit ordinary executable terminal programs.

An activated STATIC configuration requires separate governed admission before
current terminal rendering. It cannot borrow its original random-seed profile's
analysis or goldens. `IStreamTerminalEntropyRegistry` retains a once-only
registration under `6529STREAM_TERMINAL_ENTROPY_RENDER_V1`, using the original
class-1 governance mechanism. The registration binds:

- The original registered renderer/runtime and exact `renderTerminal` selector.
- The fixed terminal encoder and validator runtimes, all original read-set rows,
  and the additional actual Core/Coordinator reads with exact bounds.
- Its own canonical analysis document, including an explicit attributed
  `entropyIndependent` assertion, and original registration/read-set hashes.
- Its own canonical golden document covering modes 0, 1, 2 and 3, checked against
  actual output bytes at admission.

This is retained governance analysis evidence. Setting the boolean is not an
onchain proof of whole-program independence or complete STATIC conformance.
Deployment acceptance still needs the exact source-bound analysis and complete
transitive read roster for the admitted program and dependencies.

The terminal context uses `stream-render-context-terminal-v1` and omits the old
random hash/seed and JavaScript `hash` alias. The encoder identifies its profile;
it does not claim that a direct renderer call itself establishes admission.
Router serving checks the separate Registry admission before choosing this entry.
Missing evidence, a foreign profile, a runtime change, or invalid terminal facts
fails without switching to an old executable profile.

Historical Router selectors and the original renderer entries continue to use
their original profile. A terminal token cannot acquire an old finalized-seed
history through the new current-only admission. Literal current-output evidence,
including the existing STATIC content checkpoint's full JSON/HTML hashes, becomes
noncurrent when its current bytes change; immutable prior records are retained.

## Direct STATIC producer read

The separately advertised `IStreamEntropyTerminalFacts` capability and selector
are `0x40016975`. `staticTerminalEntropyFacts(tokenId)` returns exactly 512 bytes:
the original subject collection, all twelve original policy words, token status,
seed and request key. Its producer reads original storage directly. The consumer
verifies canonical encoding, actual Core identity, original Coordinator/runtime,
Core reciprocity, frozen explicit policy, full hash/content-state join, supported
mode/status pairing, zero seed and zero request key.

The original `tokenSeed` implementation derives `finalized` solely from status;
terminal status therefore means false. The original `tokenEntropy` implementation
returns request ID and attempt zero when the same subject request key is zero.
No synthetic provider, epoch, request, or seed is supplied to the renderer.

Ordinary metadata and policy-evidence reads retain the original live getters.
Those getters may use fixed linked workers. Their EVM `STATICCALL` execution alone
does not establish the protocol's stricter transitive STATIC read constraint.

## Versioned policy and readiness evidence

`StreamFinalityCoordinatorPolicyReadsV2` validates the existing complete original
Coordinator inventory. Legacy rows retain their original V1 component preimage.
Explicit rows use `6529STREAM_ENTROPY_COMPONENT_EVIDENCE_V2` and the complete
twelve-word policy record; the original five-word policy API must be all-zero for
that explicit policy. No V1 provider/epoch/salt surrogate is manufactured.

`StreamFinalityEntropyPolicySourceSet` retains the complete frozen policy set and
original membership facts under `6529STREAM_ENTROPY_POLICY_SOURCE_SET_V2`.
Current reads revalidate the full set. Historical token reads remain confined to
their original membership and source; later inventory expansion does not silently
extend the captured prefix. Its `tokenEntropyReadiness` distinguishes terminal,
pending and finalized states. It deliberately does not expose the old
`tokenSeedForFinality` selector or old source-set interface.

`StreamTerminalEntropyReadiness` joins this versioned source set to the actual
frozen ONCHAIN Router configuration and separately admitted terminal renderer
profile. Its evidence commits the policy chain, original source/runtime, config,
renderer, Registry and admission hashes. This is a readiness adapter for an
explicitly selected graph, not rendered-output proof or a new publication,
writer, Artist, or finality authority.

## Validation and remaining scope

The finite tests cover actual Coordinator registration and consumers, malformed
facts, original-source preservation, truthful JSON/HTML, exact Registry evidence,
threshold-two Safe rollback/retry, current routing refusal, and mixed V1/V2
complete inventories. Fixtures identify typed Core, Artist, governance, provider,
renderer and admission boundaries; separate suites exercise the genuine parts.
The retained fifth focused capture passes all 28 cases across these five suites.
Its 329 Solidity inputs and 421 artifacts are source-bound, including the exact
direct-storage Coordinator dependency. All eleven selected consumer products fit
under the captured Solidity 0.8.19, via-IR, optimizer-200, Paris profile. The same
native graph still includes the existing oversized Router; this is not whole-graph
deployment or current-stack acceptance. Earlier failing fixture captures remain
retained separately.

The following remain outside this finite batch:

- An admitted ordinary executable terminal-program profile.
- INSTANT rendering and any new entropy/security mode.
- A V2 reference publication and finality consumer accepting these adapters.
- Full actual-current mint/Artist/governance composition and operational gas
  acceptance for this exact joined source graph.
- Complete source-bound STATIC conformance evidence for a deployment. Synthetic
  fixture analysis and goldens must not be used as that evidence.

No archived artifact, original schema, previous golden or V1 receipt is rewritten.

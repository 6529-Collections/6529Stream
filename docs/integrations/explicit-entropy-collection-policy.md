# Explicit collection entropy policy

The additive `IStreamEntropyCollectionPolicy` capability declares collection
entropy mode, security class and a collection-wide token render requirement.
It preserves the original Coordinator configuration, request and subject
storage tuples and permanent interfaces. Existing configurations remain the
legacy ASYNC / HIGH_ASSURANCE / REQUIRED profile.

This implementation batch provides configuration and terminal token records.
Nonrandom metadata rendering, distribution, finality and reference capture
require their separate consumer profiles. The presence of a terminal status
does not establish that those integrations are complete. The separate
[instant provider capability](instant-entropy.md) admits INSTANT only for
LOW_SECURITY collections with an authenticated synchronous provider.

## Setup order

1. Select the actual Coordinator and Artist Registry through Core. The selected
   module registry must identify the Coordinator's immutable governance authority.
2. If needed, use the original configuration and reveal/recovery setup before
   Artist binding. That path retains its original ASYNC semantics.
3. Complete Artist binding and acceptance. The initial explicit policy capability
   requires an already-bound Artist; it does not silently supply consent for an
   earlier configuration or infer an unbound authority.
4. Before any token mint or local scope registration, construct the complete
   `PolicyInput` and call `collectionEntropyPolicyTransition`.
5. Record original Artist operation-17 consent using the Coordinator as the
   content host, `keccak256("6529STREAM_ENTROPY_CONFIGURATION_V1")` as the family,
   and the transition's fourth word as `newStateHash`.
6. Execute the exact class-1 governance action with the returned scope, old state
   and new state hashes. Configuration consumes both action and Artist evidence.
7. To freeze before public mint, obtain `freezeCollectionEntropyPolicyTransition`,
   record its separate operation-17 consent and execute its exact class-2 action.
   The first token or scope registration also locks the policy under the retained
   registration rule.

This is the supported setup order for this capability, not a claim that the
full protocol forbids every unbound collection configuration. Initial V2
configuration after any Core lifetime mint is refused, including on a new
Coordinator. Successor policy initialization needs its own authenticated
continuity recipe; this batch does not backfill it.

## Modes and token records

| Mode | Token render requirement | Configuration | Token status | Scope entropy |
| --- | --- | --- | --- | --- |
| DISABLED (0) | NOT_REQUIRED (1) | Provider, salt, request and reveal/recovery fields are zero | DISABLED (1) | Refused |
| ASYNC (2) | REQUIRED (0) | Active pinned provider and declared reveal policy | REGISTERED (3) | Supported |
| ASYNC (2) | NOT_REQUIRED (1) | Active pinned provider and declared reveal policy | NOT_REQUIRED (2) | Supported |
| INSTANT (1) | REQUIRED (0) | LOW_SECURITY, pinned instant provider, zero async reveal/recovery fields | REGISTERED (3), later synchronous request | Refused |
| INSTANT (1) | NOT_REQUIRED (1) | Same explicit instant policy | NOT_REQUIRED (2) | Refused |

The render requirement is an explicit content declaration. It is never inferred
from STATIC, a renderer name, a metadata mode or a zero seed. All tokens in this
initial profile use the collection declaration. Mixed per-token requirements
are not implemented by this capability.

The existing Core hook retains its identity, original Coordinator and duplicate
checks. It records collection, mint commitment, registration block and policy
lock before receiver delivery. For DISABLED/NOT_REQUIRED it writes the terminal
status directly, without a provider call, request, seed finalization or pending
and nonterminal counter increment. Original registration events are retained;
an additive `TokenEntropyPolicyRegistered` event binds the full policy hash.
Receiver failure reverts the transaction, including these writes.

`tokenSeed` still returns `(bytes32(0), false)` for nonrandom tokens. Consumers
must read the explicit status from the original `coordinatorAtMint`; false is
not a terminal-readiness signal. Ordinary requests and request-based recovery
cannot turn a nonrandom terminal record into randomness. ASYNC scopes retain
their original request, input commitment and recovery behavior independently
of whether tokens require entropy.

## Capability and exact commitments

Interface: `IStreamEntropyCollectionPolicy`, ERC-165 ID `0x4583f7e1`.

| Method | Selector |
| --- | --- |
| `collectionEntropyPolicy` | `0x48ff96eb` |
| `collectionEntropyPolicyTransition` | `0xd0782f94` |
| `configureCollectionEntropyPolicy` | `0xe6781f9e` |
| `freezeCollectionEntropyPolicy` | `0x58173aef` |
| `freezeCollectionEntropyPolicyTransition` | `0x636b6bef` |

The input tuple is
`(uint8,uint8,uint8,address,bytes32,bool,uint64,(bool,uint8,bytes32,uint64,uint256),uint16,bytes32)`.
The nested tuple is the original declared reveal policy. Provider configuration
and code hashes and the frozen recovery-policy hash are read and authenticated
by the producer; they are not caller-provided replacements.

The read returns twelve ABI words, in order: configured, explicitPolicy, frozen,
mode, securityClass, renderRequirement, revision (`uint64`), providerEpoch
(`uint32`), policyHash, contentStateHash, lastActionId, artistConsentRecord.
Both transitions return scope, oldHash, newHash, artistContentStateHash.

For executable STATIC consumers, `IStreamEntropyTerminalFacts` adds
`staticTerminalEntropyFacts(uint256)`, selector/interface ID `0x40016975`.
The direct host getter returns exactly sixteen words (512 bytes): collection ID,
the complete twelve-word policy record above, status (`uint8`), seed and request
key. It reads the original subject, config, epoch and namespaced policy directly,
without external or delegated calls. An absent explicit revision reverts with
`ExplicitCollectionPolicyRequired`; it does not synthesize a legacy policy.

This getter reports stored facts for any explicit token status. A terminal
consumer must separately authenticate Core collection identity and original
`coordinatorAtMint`, then admit the intended status. For DISABLED/NOT_REQUIRED,
the direct subject seed and request key are zero, `tokenSeed` is unfinalized,
and the original request ID and attempt are zero by the unchanged read equations.
The getter preserves full H, security class, render requirement, freeze and
Artist/action evidence. Its presence alone does not admit executable metadata.

The content hash is Keccak-256 of Solidity `abi.encode` with these exact fields:

```text
keccak256("6529STREAM_ENTROPY_COLLECTION_POLICY_V2"),
chainId, coordinator, core, collectionId,
mode, securityClass, renderRequirement,
provider, providerCodeHash, providerConfigHash, providerEpoch, collectionSalt,
publicRequests, timeoutBlocks,
reveal.declared, reveal.requestMode, reveal.revealOwnerRole, reveal.requestSLOBlocks,
recoveryPolicyId, recoveryPolicyHash, maxFreshRecoveryAttempts
```

The Artist content state is
`keccak256(abi.encode(keccak256("6529STREAM_ENTROPY_CONFIGURATION_V1"), policyHash, frozen))`.
Its distinct frozen value prevents reuse of configuration consent for explicit
freeze. The family hash is
`0x0d9d63287ae079e8c4867d6a82952c694dccd17190f625997cfcf8dccbe9bcb2`.
Original operation-17 signing and record domains are unchanged.

The semantic hash excludes operational reveal fee, escrow balance, governed
time/gas overlays, live provider availability, revision, action and consent IDs.
The governance transition separately commits to the fee being written and the
exact original and resulting configuration/recovery revisions. Provider or
provider-configuration changes and recovery binding changes advance the
provider epoch once per atomic policy update. Other content changes advance
policy revision and change the content hash. Freeze changes neither content
hash nor provider epoch. A fresh providerless DISABLED declaration has epoch
zero; removing a prior provider never resets an existing epoch.

## Compatibility and custody

Legacy setter and commitment bytes remain the legacy profile when no explicit
declaration exists. Once V2 is declared, original configuration/reveal/recovery
setters cannot overwrite its content. Operational fee retuning keeps its
existing dedicated path and does not change the content hash.

For every explicit V2 declaration, `entropyPolicyFrozen` deliberately returns
its original all-zero unavailable tuple. The old five-word commitment cannot
prove the new mode and render requirement. New finality consumers must use the
typed V2 producer; they must not treat the old unavailable result as evidence
that the explicit configuration is absent.

DISABLED conversion refuses a nonzero existing reveal escrow before clearing
the declaration. Existing treasury withdrawal remains available under its
original conditions; the new setter never withdraws funds or resets live
request obligations. Any previous token/scope lock prevents content replacement,
including when all tokens are already terminal. Action replay is tracked per
collection, allowing separate collections in the same authorized batch; Artist
consent records are consumed globally once.

The content family is narrowly admitted by the original Artist host checks.
Existing metadata and ENTROPY_RECOVERY families keep their behavior. Hydration
must explicitly support this new family's external-policy dependency before
claiming it can import such records.

## Validation boundary

The new focused tests use the actual Coordinator and fixed workers with typed
Core, provider, Artist-evidence and executing-governance boundaries; separate Artist tests use
the actual seven-owner suite, Archive and threshold Safe with typed Core and
entropy host. They do not establish an executed current-stack composition.
Quick ABI and selected production-size evidence is captured separately from
runtime acceptance. No Core hook, production size cap or held payment patch is
changed by this batch.

Selected compilation retains all 202 original Coordinator ABI entries and all
22 original storage entries, with no appended ordinary storage. The original
Artist Registry and Coordinator ABI/storage are unchanged. The formatted
twelve-product collection-policy-only capture placed the entropy Coordinator at 24,555 runtime
bytes and 28,936 creation bytes; 21 runtime bytes remained below EIP-170.
All selected products fit, but this is not a complete deployment size proof.
The later INSTANT/direct-facts batch has its own updated
[selected size evidence](instant-entropy.md#read-budget-and-bytecode-checks).

The source-inventory generator currently refuses to write because of 22 existing
layout diagnostics. Each diagnostic was confirmed in the integration base
`3879d3e1b38f802a6936235582efefe7c74d0177`: 21 inline interface placements and
one stale tooling path. This batch leaves the generator and inventory unchanged;
inventory reconciliation remains pending with the integrated source batch.

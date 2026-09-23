# Explicit collection entropy policy

This client reads and prepares the additive collection policy implemented at
`d7fb42128cdef9dd9716d1f955ee3aba610f085b`. It preserves the original entropy
configuration, reveal-fee, request and Artist signing domains. Its new capability
is ERC-165 interface `0x4583f7e1`.

Configuration uses Governance V2 class 1. Explicit freeze uses class 2. Both need
original Artist operation-17 content consent for their exact resulting content
state. A role grant alone cannot substitute for that governance action or consent.

## Supported modes

| Declaration | Provider and reveal policy | Token registration | Scope requests |
| --- | --- | --- | --- |
| DISABLED | Provider, salt, request, reveal and recovery fields are zero; reveal is undeclared | Terminal DISABLED | Unsupported |
| ASYNC / REQUIRED | Active pinned provider and a declared reveal policy | Original REGISTERED flow | Supported |
| ASYNC / NOT_REQUIRED | Active pinned provider and a declared reveal policy, including its fee | Terminal NOT_REQUIRED | Supported |
| INSTANT | Unsupported at this frozen producer, for either security class | Unsupported | Unsupported |

DISABLED requires `NOT_REQUIRED`; either declared security-class enum remains
legal. A zero fee in ASYNC still needs a declared reveal policy and its provider
quote. The render requirement never comes from a renderer name, metadata mode or
zero seed. `tokenSeed(...).finalized == false` does not identify a nonrandom
terminal token: consumers need the original Coordinator's explicit status.

These helpers do not establish that metadata, distribution, finality or successor
consumers support nonrandom tokens. They do not infer a future INSTANT profile.

## Exact read and transition surfaces

| Method | Selector |
| --- | --- |
| `collectionEntropyPolicy` | `0x48ff96eb` |
| `collectionEntropyPolicyTransition` | `0xd0782f94` |
| `configureCollectionEntropyPolicy` | `0xe6781f9e` |
| `freezeCollectionEntropyPolicy` | `0x58173aef` |
| `freezeCollectionEntropyPolicyTransition` | `0x636b6bef` |

The complete `PolicyInput` contains mode, security class, render requirement,
provider, collection salt, public-request flag, timeout, the original five-field
reveal tuple, maximum fresh-recovery attempts and recovery policy ID.

The read is twelve words: configured, explicitPolicy, frozen, mode, securityClass,
renderRequirement, revision (`uint64`), providerEpoch (`uint32`), policyHash,
contentStateHash, lastActionId and artistConsentRecord. Both transitions return
scope, oldHash, newHash and artistContentStateHash. The fourth word is the exact
operation-17 `newStateHash`; it is not the raw policy hash or governance newHash.

### Legacy configurations

A legacy original configuration reads as ASYNC / HIGH_ASSURANCE / REQUIRED.
Its public record may advertise the original legacy manifest hash; an undeclared
reveal policy or zero provider instead yields a zero policy hash. The private
policy entry is still absent: its revision, enum fields and policy hash are zero.
Transition hashing must retain that distinction. Even a completely unconfigured
record has the synthetic ASYNC mode and a hashed content state; it is not twelve
zero words.

The original `entropyPolicyFrozen` five-word read is deliberately all-zero for
every explicit policy. It cannot prove the new mode or render requirement, and
its unavailable result does not mean the explicit policy is absent.

## Content and governance commitments

The semantic policy hash binds original chain, Coordinator, Core and collection;
mode/security/render requirement; provider address, code and configuration hashes,
epoch and salt; request settings; declared reveal mode, role and SLO; and frozen
recovery binding. Its Artist content state is:

```text
keccak256(abi.encode(
  keccak256("6529STREAM_ENTROPY_CONFIGURATION_V1"), policyHash, frozen
))
```

Operational reveal fee, escrow balance, live provider availability, governed gas
and timing overlays, revision, action and consent IDs stay outside the semantic
hash. The governance state separately binds the fee, full original configuration
and resulting policy/recovery revisions. Pure plans retain `factsVerified: false`.

Provider address, provider configuration or recovery-binding changes advance the
epoch once per atomic update. A code-hash-only change does not itself advance the
epoch. Other content changes advance the policy revision. Freeze advances that
revision and locks configuration while preserving the policy hash, epoch and
recovery binding. It uses a distinct frozen Artist content state and fresh consent.

A fresh providerless DISABLED policy has epoch zero. Removing a prior provider
does not reset an existing epoch. Fee-only changes to an explicit policy must use
the original operational fee path; this client does not disguise them as content
updates. DISABLED conversion requires the original reveal escrow to be empty.

## Workflow and original Artist consent

1. Capture a concrete block with explicit deployment and runtime pins. Authenticate
   Core's selected Coordinator, Artist Registry and ModuleRegistry, plus the
   Coordinator's immutable Executor. Retain the original configuration, reveal,
   recovery, provider epoch and complete policy record.
2. Inspect a configure or freeze plan. Configuration requires the collection to
   exist and have no lifetime mint, Core freeze or local token/scope policy lock.
   Authenticate proposed ASYNC provider, exact fee quote and any frozen recovery
   policy. Freeze requires an already-explicit mutable policy.
3. Prepare original content consent with the Coordinator as host, family
   `6529STREAM_ENTROPY_CONFIGURATION_V1`, and the transition's fourth word.
   Capture current Artist authority, binding, nonce and original suite evidence;
   simulate with the actual submitting caller and reconcile its receipt.
4. Prepare and publish the exact governance calldata, then schedule with the
   reviewed proposer and class. After the execution window opens, revalidate and
   simulate the original Executor call with the intended caller.
5. Reconcile the policy event, original governance events, direct or Safe CALL
   transport and resulting retained state.

The original Artist path supports its source-admitted authority classes and
binding modes. Empty signature bytes select direct execution only when the actual
caller is the Artist authority; an Artist Safe must perform that CALL itself.
Other signatures remain opaque EOA/ERC-1271 proofs checked by the original host.
The verifying contract is the original Artist Registry. Explicit policy freeze
still uses operation 17, not the separate content-freeze operation 21.

The original Archive evidence retains its eight-field envelope and complete
operation-17 payload. Recording consent does not execute the policy or establish
that governance will admit it. The original Artist host can admit some creation
authority classes that this entropy consumer cannot use: retained host evidence
requires class 1 or 3. A successful creation therefore still needs the explicit
host-evidence check. Configuration consent cannot be reused for freeze.

The new policy event schema is 2. Configuration does not emit synthetic copies of
legacy configuration, epoch or recovery events. Class-2 simulation invokes the
original freeze-classifier checks; schedule receipts join the guardian commitment
and membership events in their original order. The minimum scheduling delays are
48 hours for class 1 and 72 hours for class 2, with at least seven days open and
the original 365-day lifetime limit.

Action replay is collection-scoped, while consumed Artist consent is global to
the Coordinator. Those maps have no public getter in this profile. The actual
original execution simulation checks replay and executing-action context; a
direct call from an address merely labeled as Executor cannot prove them.

No helper signs, submits, grants roles, changes classifiers or withdraws escrow.
Use the returned unsigned calls with the existing [Safe plans](safe-call-plans.md).

```ts
const capture = await captureEntropyCollectionPolicy(
  provider, deployment, collectionId, { blockTag: reviewedBlock },
);
const inspection = await inspectEntropyCollectionPolicy(provider, capture, {
  kind: "configure", input: policyInput,
});
const consent = prepareEntropyCollectionPolicyArtistConsent(
  inspection.plan, deployment.artist.registry.address,
  artistCaller, artistSigner, authorization,
);
const consentCapture = await captureEntropyCollectionPolicyConsent(
  provider, inspection, consent,
);
const simulation = await simulateEntropyCollectionPolicyConsent(
  provider, consentCapture, { blockTag: simulationBlock },
);
```

For freeze, inspect `{ kind: "freeze" }` and obtain its separate consent. After
recording usable consent, `prepareEntropyCollectionPolicyGovernance` takes the
inspection, proposer and window. `prepareEntropyCollectionPolicyOperation`
selects `"publish"`, `"schedule"` or `"execute"` with an explicit caller;
`simulateEntropyCollectionPolicyOperation` rechecks that exact stage.
Use `inspectEntropyCollectionPolicyConsentReceipt` for the original Artist
operation and `inspectEntropyCollectionPolicyReceipt` for governance stages,
passing the exact prepared object, transaction hash and direct/Safe execution mode.

## Bounded client profile

The RPC workflow uses concrete numbered blocks, sealed ordinary governance and
the original 16-component Artist suite. Its limits are client bounds, not new
protocol declarations.

| Observation | Limit |
| --- | --- |
| Ordinary RPC return / runtime code | 32,768 / 65,536 bytes |
| Governance catalog | 1–1,024 entries |
| Recovery steps / simple collaborators | At most 64 / 32 |
| Scoped / global guardian counts | At most 64 each; at least two global guardians |
| Signature input / reason URI | 65,536 bytes / 2,048 UTF-8 bytes |
| Published calldata carrier | 24,576 bytes including STOP prefix |
| Artist Archive evidence | 24,575 bytes, plus its carrier's STOP prefix |
| Receipt calldata | 524,288 bytes |
| Receipt logs | At most 256; at most four topics and 65,536 data bytes per log |

Archive and original host admission can impose a smaller usable signature bound
than the transport limit. A direct RPC observation does not prove equivalent gas
forwarding inside the original nested call.

Receipt blocks must be strictly later than the reviewed capture. Publication
checks require the pinned Executor in the preceding block; an eventless repeat
also needs the same retained pointer there. Scheduling and execution require the
reviewed catalog to match the receipt block's catalog.

Policy receipts require the exact prepared configuration, reveal policy, epoch,
recovery and policy entry at block end, with the executed action and consent IDs.
A later transaction in the same block that locks policy through mint or scope
registration, retunes its fee or changes the policy is outside this receipt
profile. Artist consent receipts likewise require the retained nonce and digest
to remain unrevoked, plus the captured binding and previous content state in the
Archive payload. A valid operation followed by such a change can be rejected by
these checks. Later live provider or Artist admission is not used to erase an
otherwise matching historical receipt.

## Frozen evidence and limits

The additive fixture retains the exact 1,034-source
`entropy-collection-policy-abi-final-1` capture. All input literals match the
frozen Git commit. Its concrete Executor and Bootstrap compiler evidence comes
from the separately identified retained ABI65 capture: their entire selected
35-source dependency set also matches that same frozen commit byte for byte.
No other ABI65 products are projected into this fixture.

```sh
node scripts/generate-current-entropy-collection-policy-fixture.mjs \
  /path/to/policy-abi-input.json /path/to/policy-abi-output.json \
  /path/to/abi65-input.json /path/to/abi65-output.json --check
```

The generator performs no compilation and does not refresh earlier fixtures.
Source-derived private entry and Archive envelopes remain distinguished from
public compiler ABI witnesses. Client tests and mocked RPC responses establish
client behavior, not native current-stack execution or equivalent nested-call
gas. The producer authored 29 focused cases; its handoff records runtime execution
as pending. Full protocol integration, actual Safe execution, gas and release
acceptance remain separate evidence.

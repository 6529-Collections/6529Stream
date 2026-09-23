# LOW_SECURITY INSTANT entropy

This separate client profile follows frozen producer
`b4bbd262a77d122d35065a6b7b8b9606323361e5`. The earlier
[collection policy client](current-entropy-collection-policy.md) remains pinned
to its original producer, where INSTANT is unsupported. Its ASYNC behavior and
compiler fixture are unchanged.

The bundled provider uses the preceding block hash. Its output is predictable,
subject to validator influence and selectable by request timing: a caller can
simulate candidate blocks and submit only a favorable request. It does not
provide VRF assurance. Policy must explicitly select INSTANT and LOW_SECURITY
with original Artist consent and governance authorization.

## Policy and provider identity

INSTANT configuration uses the original five-method collection policy interface
`0x4583f7e1`, full twelve-word policy record, semantic hash and transition domains.
Configuration is governance class 1; explicit freeze is class 2. Both use original
Artist operation 17 and the transition's fourth return word as the exact new
Artist content state. Freezing requires separate consent for that frozen state.

The provider, collection salt and public-request flag are explicit inputs.
Timeout, reveal declaration, every reveal field, recovery policy and recovery
attempts must be zero. Conversion also requires empty reveal escrow. Clearing an
old recovery binding follows the original recovery revision and provider epoch
rules; this does not silently reset history. HIGH_ASSURANCE cannot select INSTANT.

The permanent instant read interface is `0x5d42f023`; its additive identity
interface is `0xb8bedf9e`. Only `DELAYED_BLOCKHASH` mode 1 is admitted here.
COMMIT_REVEAL and DETERMINISTIC_TEST_ONLY remain unsupported. The original
provider lifecycle must admit the exact active runtime and configuration.

The contract can admit other providers with the required interfaces, mode 1 and
nonzero identity and assumptions commitments. The bundled
`StreamEntropyProviderInstant` has a more specific family, version, Coordinator
binding, assumptions text and configuration formula. Its raw-randomness and
provenance formulas apply only to that concrete profile. A mode number alone
does not establish those formulas for another provider.

## Registration and request are separate operations

| Policy and status | Meaning |
| --- | --- |
| INSTANT / REQUIRED, REGISTERED | Mint recorded the subject; no provider read or seed yet |
| INSTANT / REQUIRED, FINALIZED | A later request obtained the static result and stored its seed |
| INSTANT / NOT_REQUIRED | Explicit terminal declaration; no randomness request or seed |
| DISABLED | Explicit terminal declaration; no provider request |

Mint registration preserves the original mint commitment and registration block.
An INSTANT request must be in a strictly later block, even when the caller is
otherwise authorized. The actual Core token must still be MINTED and its original
`coordinatorAtMint` must equal the request host. A later change to Core's selected
Coordinator does not replace that original host. Burned tokens cannot request.

Request authority comes from the Coordinator authority, a configured requester,
the collection's public-request flag or a live `ROLE_ENTROPY_ADMIN` grant. Token
ownership alone grants no permission. The ASYNC reveal-owner role and matured
reveal SLO do not authorize an INSTANT request. Entropy scopes and fresh recovery
remain ASYNC-only.

The request snapshot's `inputsHash` is zero for INSTANT. Context and seed use
that same zero, while the original subject commitment remains available for
audit. This prevents changing the mint commitment from changing the instant
outcome; it does not remove request-timing selection.

## Exact request and output commitments

The original token request-key domain, chain, Coordinator, Core, collection,
token, provider, epoch, provider configuration and attempt remain unchanged.
The initial attempt is 1. The provider request ID is allocated by the Coordinator:

```text
uint256(keccak256(abi.encode(
  keccak256("6529STREAM_INSTANT_PROVIDER_REQUEST_V1"),
  requestKey, uint16(1), provider, providerEpoch, providerConfigHash
)))
```

The static-call context is:

```text
abi.encode(uint16(1), core, collectionId, tokenId, bytes32(0),
           providerEpoch, providerConfigHash, uint16(1), bytes32(0))
```

For the bundled provider, source block is the request block minus one. Raw
randomness commits to request key, context hash, source block and its block hash.
Provenance additionally commits to provider configuration and assumptions. The
seed uses the original token seed recipe, including allocated provider request
ID, raw randomness, collection salt and zero `inputsHash`.

An earlier simulation can have a different raw result and seed from the mined
request. The mined predecessor block is the evidence needed to reconstruct the
bundled provider's output. Request key and allocated ID remain tied to their
original request inputs. Raw zero is valid and does not mean a missing result.

## Credit, events and metadata

Provider fee is zero. Every supplied wei becomes the actual caller's existing
pull credit. No reveal escrow is drawn and no ETH is paid to the provider. When
a Safe makes the call, that Safe is the caller credited. A failed, malformed or
gas-exhausted provider read reverts the whole request, including credits and
request identity; the same request inputs can be retried.

The Coordinator stores REQUESTED, the complete request and policy snapshot,
both provider request-ID directions and pending obligations before the static
provider reads. Success stores the result and FINALIZED state in the same
transaction. Event order is:

1. `EntropyFeeCredited`, when supplied value is positive.
2. Original `EntropyRequested`.
3. Coordinator `InstantEntropyProduced`, including mode and assumptions.
4. Original `EntropyFinalized`.
5. Metadata notification, including its failure event when needed.

Metadata notification failure preserves entropy finalization. The original
notification retry does not request or read randomness again. There is no
ordinary repeat request, asynchronous callback or instant scope reroll.

## Direct sixteen-word facts

`staticTerminalEntropyFacts(uint256)` has selector/interface ID `0x40016975`.
It returns collection ID, the complete twelve-word policy record, actual status,
seed and request key: exactly sixteen words, or 512 bytes. Its implementation
reads local storage without calling a linked or external dependency.

Despite the method name, the getter also returns REGISTERED and other explicit
subject states. A successful read alone proves neither terminal status nor
artwork finality. Consumers authenticate collection identity and the original
Coordinator against Core, then interpret the returned status. The status enum is
NONE 0, DISABLED 1, NOT_REQUIRED 2, REGISTERED 3, REQUESTED 4, FINALIZED 5,
STALE 6 and FAILED 7. A false `tokenSeed(...).finalized` flag cannot distinguish
nonrandom terminal declarations from unfinalized subjects.

The getter requires an explicit policy. It is not a replacement for the earlier
legacy policy reader. STATIC rendering, distribution, finality and successor
admission remain separate consumer responsibilities.

## Client workflow

For policy changes, use `captureEntropyInstantPolicy` and
`inspectEntropyInstantPolicy` with the full pinned policy deployment. The
`prepareEntropyInstantPolicyArtistConsent`, `captureEntropyInstantPolicyConsent`
and `simulateEntropyInstantPolicyConsent` helpers retain the original signing
and Archive path. Reconcile that transaction with
`inspectEntropyInstantPolicyConsentReceipt`.

Then use `prepareEntropyInstantPolicyGovernance` and
`prepareEntropyInstantPolicyOperation` for publication, scheduling and execution.
`simulateEntropyInstantPolicyOperation` and `inspectEntropyInstantPolicyReceipt`
check the original governance calls and direct or Safe CALL receipts. Existing
Artist authority-class, guardian, catalog, timing and end-of-block policy bounds
from the [collection policy workflow](current-entropy-collection-policy.md)
still apply. The INSTANT policy resolution additionally retains provider mode
and assumptions.

Token requests use a smaller deployment description: chain ID plus Core and
original Coordinator runtime pins. They do not require today's selected
Coordinator or today's Artist/governance readiness merely to use the original
mint host.

```ts
const requestDeployment = {
  chainId,
  core: { address: coreAddress, codeHash: coreRuntimeHash },
  coordinator: { address: originalCoordinator, codeHash: coordinatorRuntimeHash },
  providerProfile: "bundled-blockhash" as const,
};
const request = await captureEntropyInstantRequest(
  provider, requestDeployment, tokenId, actualCaller, suppliedValue,
  { blockTag: reviewedBlock },
);
const simulation = await simulateEntropyInstantRequest(
  provider, request, { blockTag: simulationBlock },
);
// Submit request.plan.call through the chosen signer or Safe outside these helpers.
const receipt = await inspectEntropyInstantRequestReceipt(
  provider, request, { transactionHash, execution: "safe" },
);
const state = await readEntropyInstantTerminalFacts(
  provider, requestDeployment, tokenId, { blockTag: observedBlock },
);
```

`providerProfile` defaults to `"source-delayed"`. That profile authenticates the
admitted provider and retains its reported mode and assumptions. It treats mined
raw randomness and provenance as exact event/storage facts. The optional
`"bundled-blockhash"` profile additionally checks the bundled identity and
reconstructs its result from the actual predecessor block.

Select that bundled profile only after reviewing the pinned provider runtime as
the bundled implementation. Matching identity getters alone cannot establish its
call-free behavior or randomness formula.

The workflow requires provider identity and assumptions to be readable before
the request and to match the mined event. Providers whose identity reads require
temporary REQUESTED state, or whose assumptions change during submission, are
outside that observation profile even if the contract can admit them.

Original request simulation checks the real caller, value, nested provider reads
and returned request key/ID. It cannot return a generic provider's raw result:
the provider can observe REQUESTED state during the nested call, while a separate
standalone read would observe different state. Only the bundled profile exposes
the reconstructed pinned-block result. A future mined result still requires
receipt reconciliation. An `admin-role-simulation-required` capture label records
unresolved caller authority; it is not a granted role.

No helper signs or sends transactions. Returned unsigned calls compose with
the existing [Safe plans](safe-call-plans.md), using ordinary CALL and the actual
Safe as caller. Delegatecall transport is outside this profile.

### Receipt and observation bounds

All RPC reads use concrete numbered blocks and recheck their hashes. Runtime
pins, canonical calldata and exact event order are required. Receipt blocks must
be later than capture. The direct facts workflow requires an existing original
registered token and reports its actual status; its codec preserves the original
enum without inferring finality.

Request receipts reconcile the stored subject, complete request/policy snapshot,
both request-ID directions, original token view and direct facts. They require
the reviewed explicit policy at block end. Current provider activity and the
current selected Coordinator do not invalidate historical request evidence;
the original host and runtime pins must still match. The bundled profile checks
the mined predecessor hash, not the earlier simulation's prediction.

The credited amount comes from this transaction's exact caller-credit event.
Returned balances, counters and metadata-notification flag describe block end.
Other requests, credit claims or notification retries in that block can affect
those observations, so they are not presented as isolated transaction deltas.
A notification failure event remains part of the receipt even if a later retry
clears the pending flag.

The inherited client limits include 32,768-byte ordinary RPC returns,
65,536-byte runtime code, 524,288-byte receipt calldata, and at most 256 logs with
four topics and 65,536 data bytes each. Policy governance retains a catalog of
1–1,024 entries; Archive evidence is limited to 24,575 bytes plus its STOP prefix.
These are client bounds, not broader protocol or gas-capacity guarantees.

## Evidence boundary

The additive fixture projects the retained
`entropy-instant-static-abi-final-1` compiler capture. All 1,044 literal sources
match the frozen Git commit. Concrete Executor and Bootstrap evidence comes
from the separately identified retained ABI65 capture; their entire selected
35-source dependency set also matches the same frozen commit byte for byte.

```sh
node scripts/generate-current-entropy-instant-fixture.mjs \
  /path/to/instant-abi-input.json /path/to/instant-abi-output.json \
  /path/to/abi65-input.json /path/to/abi65-output.json --check
```

The generator performs no compilation and does not update earlier fixtures.
Source-derived internal preimages remain distinct from compiler public-ABI
evidence. Pure plans, client tests and mocked RPC responses do not establish
native contract execution, actual Safe composition or nested-call gas capacity.

The source's governed INSTANT read cap starts at 100,000 gas and requires the
full cap under its EIP-150 parent-gas precheck. Those values are implementation
facts, not measured gas acceptance. Source input authentication, optimized-IR
inspection and the retained runtime opcode scan each have their own scope;
none substitutes for current-stack execution. Full consumer admission, deployment
inventory, gas and release acceptance remain separate work.

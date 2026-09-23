# LOW_SECURITY instant entropy

`StreamEntropyProviderInstant` implements the optional previous-block-hash
profile. It is predictable, susceptible to validator influence and permits
request-timing selection: a caller can simulate candidate blocks and submit
only a favorable request. It does not provide VRF assurance. Collection policy
must explicitly declare INSTANT and LOW_SECURITY, with original Artist consent
and exact executing governance authorization. There is no default provider.

This source batch implements the provider and Coordinator path. Focused runtime,
current-stack composition, collection metadata/provenance disclosure, commerce,
full deployment-role inclusion and release acceptance remain separate work.
The historical genesis provider set still excludes instant providers under ADR
0009; that exclusion does not complete or remove a separately required full-v1
deployment task.

## Capabilities and policy

The permanent `IStreamInstantEntropyProvider` interface remains one method:
`instantEntropy(bytes32,bytes) returns (bytes32,bytes32)`, interface ID
`0x5d42f023`. It returns raw randomness and a provenance hash through a view
call. It never calls back into `fulfillEntropy`.

The additive `IStreamInstantEntropyProviderIdentity`, ID `0xb8bedf9e`, supplies
the instant marker, provider family/version/configuration hash, and
`instantEntropyProfile() returns (uint8,bytes32)` for mode and assumptions hash.
Modes are COMMIT_REVEAL (0), DELAYED_BLOCKHASH (1) and DETERMINISTIC_TEST_ONLY (2).
Only DELAYED_BLOCKHASH is admitted by this implementation. The provider exposes
both capabilities and ERC-165, and does not advertise the asynchronous provider
interface or invent asynchronous callback/result records.

Activate the exact runtime through the original governed provider lifecycle.
Then use [explicit collection policy](explicit-entropy-collection-policy.md)
with INSTANT, LOW_SECURITY, the active provider, a collection salt and the
chosen public-request flag. Timeout, reveal declaration and every reveal field,
recovery policy and recovery attempts must be zero. Conversion refuses existing
reveal escrow, preserving custody. HIGH_ASSURANCE cannot select INSTANT.
Legacy ASYNC setters and fresh-recovery steps require asynchronous providers.

NOT_REQUIRED remains an explicit terminal token declaration even with INSTANT.
No request or seed is created for such a token. Entropy scopes remain ASYNC-only.

## Registration and request

For REQUIRED tokens, mint registration stores REGISTERED, the original mint
commitment, registration block, policy lock and nonterminal count. It performs
no provider call. A request must occur in a later block than registration,
preventing synchronous provider execution during mint delivery. It still checks
the original `coordinatorAtMint`, token lifecycle and ordinary request authority.
The ASYNC reveal-SLO remedy does not apply to an undeclared instant reveal policy.

The original token request-key domain and seed domain remain unchanged.
For INSTANT only, the request snapshot's `inputsHash` is zero; both the context
and final seed use that zero value. The original subject commitment remains
available for audit. This prevents an executor from choosing instant outcomes
by varying `mintCommitment`. It does not prevent block-to-block request timing.

The context is Solidity `abi.encode` of:

```text
uint16(1), core, collectionId, tokenId, bytes32(0),
providerEpoch, providerConfigHash, uint16(1), bytes32(0)
```

The Coordinator allocates the provider request ID as the uint256 form of:

```text
keccak256(abi.encode(
  keccak256("6529STREAM_INSTANT_PROVIDER_REQUEST_V1"),
  requestKey, requestAttempt, provider, providerEpoch, providerConfigHash
))
```

Before the provider read, the Coordinator stores REQUESTED, both request-ID
directions, the complete request/policy snapshot, pending count and continuity
obligation. It then makes a bounded static call and accepts exactly 64 return
bytes. Failure or malformed return data reverts the whole transaction, including
credits, request identity and counters; it creates no successful request event.

On success, the Coordinator stores raw randomness, derives the seed using its
original seed recipe, marks FINALIZED, closes the obligation and counters, and
attempts metadata notification. Raw zero is valid. Notification failure preserves
finality and the existing retry path; retry never reads randomness again.
No ordinary repeat, callback reroll or instant scope request is admitted.

The provider fee is zero. All supplied ETH becomes the caller's existing pull
credit; no reveal escrow is drawn and no ETH is sent to the provider.

## Provider preimages and disclosure

The adapter constructor pins its Coordinator. Its configuration is:

```text
keccak256(abi.encode(
  keccak256("6529STREAM_INSTANT_BLOCKHASH_CONFIG_V1"),
  coordinator, uint8(1), assumptionsHash
))
```

For `sourceBlock = block.number - 1`, it returns:

```text
raw = keccak256(abi.encode(
  keccak256("6529STREAM_INSTANT_BLOCKHASH_RAW_V1"),
  requestKey, keccak256(context), sourceBlock, blockhash(sourceBlock)
))
provenance = keccak256(abi.encode(
  keccak256("6529STREAM_INSTANT_BLOCKHASH_PROVENANCE_V1"),
  configHash, requestKey, keccak256(context), sourceBlock,
  blockhash(sourceBlock), assumptionsHash
))
```

`assumptionsHash` commits to the literal disclosure string in the adapter.
Constructor event `InstantEntropyAssumptions` records its mode and assumptions.
Because the request function is view, the **Coordinator** emits
`InstantEntropyProduced` with request key, allocated ID, raw value, provenance,
mode and assumptions. Original requested/finalized events remain present.
Collection metadata and provenance consumers must expose the same LOW_SECURITY
and timing-selection disclosure before a production-conformance claim.

## Read budget and bytecode checks

The Coordinator owns `GGP_ENTROPY_INSTANT_READ_GAS_LIMIT`, derived from
`6529STREAM_GGP_ENTROPY_INSTANT_READ_GAS_LIMIT`:
`0x0ffe9e35d72ecbd51f67a4de70a029c50bdf219e8c7d0a12e4cbc22a9649cb20`.
Its implementation floor and initial value are 100,000 gas, failure class 2
(FAIL_CLOSED_PRECHECK), revision 1. Each read checks that parent gas can forward
the complete current cap under EIP-150, with an overflow-safe 10,000-gas reserve.
It uses the original delayed, monotonic,
at-most-double raise mechanism. It does not borrow the asynchronous incident
probe budget. Final measured gas and closed-world launch inventory reconciliation
remain release work; the implementation constant is not measurement evidence.

The exact-runtime checker authenticates compiler inputs and provider metadata,
then rejects external-call, creation, state-write, selfdestruct and log opcodes
in runtime code. It skips PUSH immediate data and validates immutable ranges;
constructor-only disclosure is separate. This is required in current-stack CI.
An adversarial test provider that reads Coordinator state proves call ordering
only and cannot substitute for the production provider's call-free proof.

The selected ten-product compile including the direct terminal-facts getter
places the Coordinator at 24,252 runtime bytes and 29,023 creation bytes,
with 324 runtime bytes below EIP-170. The instant provider is 1,378 runtime
bytes; its exact runtime passes the opcode scan. All selected products fit.
The Coordinator retains all 217 parent ABI entries and all 22 original storage
entries. These selected checks are not a complete deployment or executed
current-stack acceptance result.

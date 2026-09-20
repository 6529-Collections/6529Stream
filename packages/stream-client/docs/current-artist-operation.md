# Current Artist operation callers

The first ART39 extension adds five principal public calls. Existing acceptance,
collaborator, policy, economics, payout, attestation, content-consent and
ratification payloads remain in their original client modules.

| Original operation | Public facade method | Purpose |
| --- | --- | --- |
| 3 | `refuseArtistBinding` | Refuse an exact pending generation and binding hash. |
| 16 | `recordSaleConsent` | Record approval of an exact current sale configuration. |
| 20 | `authorizeArtistRoyaltyFreeze` | Authorize the specified royalty assignment freeze. |
| 21 | `authorizeArtistContentFreeze` | Authorize specified metadata locks at an exact state. |
| 54 | `revokeArtistAuthorization` | Revoke one unused digest or nonzero nonce. |

Operations 20 and 21 record authorization. The corresponding resolver or metadata
operation must still perform the freeze. The delegated royalty-freeze selector
is a separate pending caller requirement.

The [coverage register](current-artist-operation-coverage.json) tracks every
original operation 1–60, the existing operation 61 dispute withdrawal, current
method variants, and three additional public configuration/checkpoint methods.
An operation ID is not a claim that all its variants have client workflows.
Operation 36 is historically named `designateSuccessor`; its actual facade method
is `recordSuccessorDesignation`. New C2PA and delegated policy/sale interfaces
remain outside this frozen source until their source handoffs.

## Payload and caller review

`currentArtistOperationTypedData` reconstructs the permanent EIP-712 schema.
`prepareCurrentArtistAction` retains the complete request, typed payload,
original write calldata and read-only digest call. Its exact request contains
`kind`, `chainId`, `registry`, `caller`, `signer`, `artistId`, `mode`, `signature`,
`message` and `details`. The five kind names are `bindingRefusal`, `saleConsent`,
`royaltyFreeze`, `contentFreeze` and `authorizationRevocation`.

The signing domain is `6529StreamArtistRegistry`, version `1`, with the actual
chain and `StreamArtistOnboardingRegistry` facade address. Coordinator, owner,
extension and configuration-directory addresses are not signing hosts.

Every integer is a bigint. These five schemas use a deadline; execution records
use the transaction block timestamp. Refusal's `details.reasonURI` is reviewed
calldata outside the signed schema, limited to 2,048 UTF-8 bytes. Other details
objects are empty. This client accepts Unicode URI text; it does not represent
arbitrary non-UTF-8 Solidity string bytes. Content-freeze lock classes retain their supplied order and
must be 1–16 strictly increasing, nonzero bytes32 values. Their signed commitment
hashes packed words; the record preimage retains the original dynamic array.

`mode: "direct"` requires caller equal to signer and empty signature bytes.
`mode: "signature"` retains opaque EOA or ERC-1271 proof bytes. An empty proof
from a distinct relayer can be valid for an ERC-1271 wallet; signature length
alone does not determine the lane. The original authorization path limits proofs
to 4,096 bytes. No helper asks a wallet to sign or submits
a transaction. EIP-7702 signers follow contract signature validation; deployment
components must match the reviewed immutable runtime pins.

## Authority and execution

`captureCurrentArtistOperation(provider, deployment, request, { blockTag })`
requires a concrete block number. Deployment pins contain the Registry,
Coordinator and the Coordinator's exact 16-component order: seven owners,
Registry, Archive, Core, Manager, roles, metadata, primary resolver, royalty
resolver and validator. The caller supplies independently reviewed code hashes.

Capture checks the chain, runtime hashes, component bindings, current Registry,
authority, operation capability, binding, deadline, original digest and replay
lane. Direct execution uses the current nonce hint. Signed execution can use
another unused nonce. Revocation reads the target separately from the nonce
authorizing the revocation. Captures are immutable and reconstructed before
asynchronous work.

A capture is an observation and carries `simulationRequired: true`.
`simulateCurrentArtistCall` rechecks its historical observation, refreshes at the
chosen block and calls the original write with the actual caller. That write
establishes the operation-specific sale-adapter, metadata or royalty admission
at the simulated block. A changed binding or authority requires a new capture.
State can still change before mining; simulation reserves neither authority nor
a nonce.

`createCurrentArtistSafePlan` preserves the supplied order and creates ordinary,
zero-value Safe CALLs. It accepts only these five original public methods through
reconstructed requests. It rejects repeated authorization nonces and known
revocation conflicts in the same Registry/Artist lane. Each entry is a separate transaction. When one action
changes the next action's nonce or other state, mine it and capture the dependent
action again. The [review example](../examples/current-artist-operation.mjs)
combines capture, exact-call simulation and a one-step plan. Its request already
contains the intended direct or signed authorization.

## Receipt evidence

`inspectCurrentArtistReceipt` checks a successful direct transaction or an
ordinary Safe `execTransaction`, its exact caller/calldata, original semantic
owner events, record hash and durable record/replay reads. Archive evidence must
match the original operation envelope and request, and follow the owner events.
Both Safe success-event layouts are admitted; success must follow the operation
evidence. Captures must precede the receipt block.

Client receipt inspection is bounded to 512 logs, 65,536 bytes per log and
524,288 transaction-calldata bytes; decoded Archive/read data is bounded to
262,144 bytes. A receipt outside these inspection limits requires a separate
review rather than a successful result from this helper.

Receipt verification concerns that transaction and its retained records. Later
same-block state is not proof that the consent remains applicable. For example,
historical sale-consent existence does not replace current adapter/configuration
validation. Protocol-only owner/Coordinator methods are not user-call targets.

## Frozen source and limits

The fixture uses the retained `parallel-feature-batch49-20260920` ABI capture at
commit `18be311bc33e8007841f963f218ac8290e271015`. All 2,172 literal input sources
were verified byte-for-byte against that commit. It retains 298 production
closure hashes, selected original ABI entries and six original hash-library
texts for independent preimage tests. Verify without compiling Solidity:

```sh
node scripts/generate-current-artist-operation-fixture.mjs \
  /path/to/abi-input.json /path/to/abi-output.json --check
```

These are client encoding, mocked RPC and source/ABI checks. They do not establish
deployed Artist or Safe execution, gas acceptance, completed ceremonies, genesis
readiness or release readiness. The remaining register entries and variants are
explicitly pending; ART39 is not complete.

# Current Artist operation callers

The ART39 extension adds the following principal public calls. Existing acceptance,
collaborator, policy, economics, payout, attestation, content-consent and
ratification payloads remain in their original client modules.

| Original operation | Public facade method | Purpose |
| --- | --- | --- |
| 3 | `refuseArtistBinding` | Refuse an exact pending generation and binding hash. |
| 16 | `recordSaleConsent` | Record approval of an exact current sale configuration. |
| 20 | `authorizeArtistRoyaltyFreeze` | Authorize the specified royalty assignment freeze. |
| 21 | `authorizeArtistContentFreeze` | Authorize specified metadata locks at an exact state. |
| 25 | `recordIdentityRevision` | Extend the operative document with exact document bytes. |
| 26 | `grantArtistDelegation` | Grant the original scoped capabilities and use/window limits. |
| 27 | `revokeArtistDelegation` | Revoke an exact grant using its stored grantor. |
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
`message` and `details`. The kind names are `bindingRefusal`, `saleConsent`,
`royaltyFreeze`, `contentFreeze`, `authorizationRevocation`, `identityRevision`,
`delegationGrant` and `delegationRevocation`.

The signing domain is `6529StreamArtistRegistry`, version `1`, with the actual
chain and `StreamArtistOnboardingRegistry` facade address. Coordinator, owner,
extension and configuration-directory addresses are not signing hosts.

Every integer is a bigint. Refusal, consent, freezes and both revocation schemas
use a deadline; their records use the transaction block timestamp. Refusal's `details.reasonURI` is reviewed
calldata outside the signed schema, limited to 2,048 UTF-8 bytes. Identity revision
details are described below; the other details objects are empty. This client accepts Unicode URI text; it does not represent
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

## Identity and delegation

Identity revision signs the Artist ID, previous and revised document hashes,
nonce and `signedAt`. The previous hash is the operative document hash. Details
retain the URI, actual document bytes and display name; the document must be
1–8,192 bytes and hash to the signed revised value. The URI is at most 2,048
UTF-8 bytes and the display name is 1–256 bytes. Both are Unicode text inputs;
arbitrary non-UTF-8 contract strings are outside this client. URI and display name are
supplemental calldata outside the permanent signed schema.

A direct revision with `signedAt: 0n` keeps that submitted sentinel in calldata.
The contract replaces it with the execution timestamp before hashing and replay
consumption. Capture retains the submitted and block-specific effective digest;
receipt inspection recomputes the digest at the mined timestamp. An explicit
direct time must equal the execution timestamp. A relayed revision uses its
explicit nonzero time, which cannot be later than execution.

Delegation grants sign Core, delegate, collection, capabilities, start/end times,
maximum uses, constraints and nonce. The Artist ID remains in the original
request and record; it is not added to the permanent signature. Authorization
time is exactly zero, with no invented deadline. Collection zero is global,
maximum uses zero is unlimited, and zero constraints hash is permitted. The
original capability mask is `117` (`1 | 4 | 16 | 32 | 64`). A future grant still
reserves its Artist/delegate key until revoked, expired or exhausted.

Grant revocation resolves the stored grantor independently from current Artist
authority. An expired, exhausted or replaced historical grant may still be
explicitly revoked if it is not already revoked. Zero reason hash is permitted.
These three operations consume the shared Artist nonce lane; delegated action
consumption uses a separate lane and remains a pending extension.

Receipt verification preserves the original storage and event formats. Revision
storage reports authority class `1` even where its record hash and event use the
actual class. The delegation-revoked event omits the resulting revocation hash,
so verification joins the original preimage, Archive and grant record. Later
document revisions, grant uses or revocation do not erase the historical action.

## Authority and execution

`captureCurrentArtistOperation(provider, deployment, request, { blockTag })`
requires a concrete block number. Deployment pins contain the Registry,
Coordinator and the Coordinator's exact 16-component order: seven owners,
Registry, Archive, Core, Manager, roles, metadata, primary resolver, royalty
resolver and validator. The caller supplies independently reviewed code hashes.

Capture checks the chain, runtime hashes, component bindings, current Registry,
authority, operation capability, binding, operation timing, original digest and replay
lane. Direct execution uses the current nonce hint. Signed execution can use
another unused nonce. Revocation reads the target separately from the nonce
authorizing the revocation. Captures are immutable and reconstructed before
asynchronous work.

A capture is an observation and carries `simulationRequired: true`.
`simulateCurrentArtistCall` rechecks its historical observation, refreshes at the
chosen block and calls the original write with the actual caller. That write
establishes the operation-specific sale-adapter, metadata or royalty admission
at the simulated block. It also checks revision provisional-child occupancy,
live or future delegation-key conflicts and estate-directive restrictions.
A changed binding or authority requires a new capture.
State can still change before mining; simulation reserves neither authority nor
a nonce.

`createCurrentArtistSafePlan` preserves the supplied order and creates ordinary,
zero-value Safe CALLs. It accepts only supported original public methods through
reconstructed requests. It rejects repeated authorization nonces, repeated grant
revocation targets and known authorization-revocation conflicts in the same lane.
The future effective digest of a direct zero-time revision is unknown and is not
treated as a known digest conflict. Refresh timing and replay before execution.
Each entry is a separate transaction. When one action
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
closure hashes, selected original ABI entries and eleven original source
texts for independent preimage tests. Verify without compiling Solidity:

```sh
node scripts/generate-current-artist-operation-fixture.mjs \
  /path/to/abi-input.json /path/to/abi-output.json --check
```

These are client encoding, mocked RPC and source/ABI checks. They do not establish
deployed Artist or Safe execution, gas acceptance, completed ceremonies, genesis
readiness or release readiness. The remaining register entries and variants are
explicitly pending; ART39 is not complete.
